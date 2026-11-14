import Foundation
import UIKit

/// A complete backend that lives in a folder on this phone.
///
/// It keeps the same shape as the server will: accounts, couples keyed by invite code, an inbox per
/// account, and an outbound queue that only drains while "online". With the debug flag `-sharedStore`
/// two simulators point at the same folder, so pairing and sending between them can be tested end to end.
final class LocalBackend: Backend {
    private struct Store: Codable {
        var accounts: [String: Account] = [:]
        var couples: [String: Couple] = [:]          // by couple id
        var codes: [String: String] = [:]            // invite code -> couple id
        var inbox: [String: [LoveEvent]] = [:]       // account id -> events waiting
        var tokens: [String: DeviceTokens] = [:]
    }

    private struct Local: Codable {
        var accountID: String?
        var outbound: [LoveEvent] = []
        var lastInboundFetch: Date?
    }

    private let storeURL: URL
    private let localURL: URL
    private var store = Store()
    private var local = Local()
    private let io = DispatchQueue(label: "aegyo.localbackend", qos: .utility)

    init() {
        let fm = FileManager.default
        let args = ProcessInfo.processInfo.arguments
        let base: URL
        if args.contains("-sharedStore"), let shared = ProcessInfo.processInfo.environment["AEGYO_SHARED_STORE"].map(URL.init(fileURLWithPath:)) {
            base = shared
        } else {
            base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Backend", isDirectory: true)
        }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        storeURL = base.appendingPathComponent("store.json")
        localURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("local.json")
        load()
    }

    // MARK: Backend

    var currentAccount: Account? {
        reload()
        return local.accountID.flatMap { store.accounts[$0] }
    }

    var currentCouple: Couple? {
        reload()
        guard let id = local.accountID else { return nil }
        return store.couples.values.first { ($0.creatorID == id || $0.partnerID == id) && $0.leftBy != id }
    }

    func signIn(_ method: SignInMethod) async throws -> Account {
        try await latency()
        let account: Account
        switch method {
        case .apple(let userID, let name, let email):
            let id = "apple:\(userID)"
            account = store.accounts[id] ?? Account(id: id, name: name ?? "", email: email)
        case .email(let name, let email):
            let id = "email:\(email.lowercased())"
            var a = store.accounts[id] ?? Account(id: id, name: name, email: email)
            if a.name.isEmpty { a.name = name }
            account = a
        }
        store.accounts[account.id] = account
        local.accountID = account.id
        save()
        return account
    }

    func signOut() async {
        local = Local()
        save()
    }

    func deleteAccount() async throws {
        try await latency()
        guard let id = local.accountID else { throw BackendError.notSignedIn }
        if var couple = currentCouple {
            couple.leftBy = id
            store.couples[couple.id] = couple
        }
        store.accounts[id] = nil
        store.inbox[id] = nil
        store.tokens[id] = nil
        local = Local()
        save()
    }

    func updateProfile(_ account: Account) async throws {
        try await latency(0.2)
        store.accounts[account.id] = account
        save()
    }

    func fetchPartner() async throws -> Account? {
        reload()
        guard let me = local.accountID, let c = currentCouple else { return nil }
        let other = c.creatorID == me ? c.partnerID : c.creatorID
        return other.flatMap { store.accounts[$0] }
    }

    func createCouple() async throws -> Couple {
        try await latency()
        guard let me = local.accountID else { throw BackendError.notSignedIn }
        if let existing = currentCouple, existing.isComplete { throw BackendError.alreadyPaired }
        var code: String
        repeat { code = String(format: "%06d", Int.random(in: 0...999_999)) } while store.codes[code] != nil
        let couple = Couple(id: UUID().uuidString, code: code, creatorID: me, partnerID: nil)
        store.couples[couple.id] = couple
        store.codes[code] = couple.id
        save()
        return couple
    }

    func joinCouple(code: String) async throws -> Couple {
        try await latency()
        reload()
        guard let me = local.accountID else { throw BackendError.notSignedIn }
        let clean = code.filter(\.isNumber)
        guard clean.count == 6, let id = store.codes[clean], var couple = store.couples[id] else { throw BackendError.invalidCode }
        if couple.creatorID == me { throw BackendError.cannotJoinOwnCouple }
        if couple.partnerID != nil && couple.partnerID != me { throw BackendError.alreadyPaired }
        if couple.createdAt < Date().addingTimeInterval(-7 * 86400) { throw BackendError.codeExpired }
        couple.partnerID = me
        couple.leftBy = nil
        store.couples[id] = couple
        save()
        NotificationCenter.default.post(name: .backendCoupleChanged, object: nil)
        return couple
    }

    func leaveCouple() async throws {
        try await latency(0.3)
        guard let me = local.accountID, var c = currentCouple else { return }
        c.leftBy = me
        store.couples[c.id] = c
        save()
        NotificationCenter.default.post(name: .backendCoupleChanged, object: nil)
    }

    func refreshCouple() async throws -> Couple? {
        reload()
        return currentCouple
    }

    func send(_ event: LoveEvent) async throws {
        reload()
        guard let me = local.accountID else { throw BackendError.notSignedIn }
        guard await Reachability.shared.isOnline else {
            local.outbound.append(event)
            save()
            throw BackendError.offline
        }
        try await deliver(event, from: me)
    }

    /// Push anything that was queued while offline.
    func drainOutbound() async {
        reload()
        guard let me = local.accountID, !local.outbound.isEmpty, await Reachability.shared.isOnline else { return }
        let pending = local.outbound
        local.outbound = []
        save()
        for e in pending { try? await deliver(e, from: me) }
    }

    var pendingOutbound: Int { local.outbound.count }

    private func deliver(_ event: LoveEvent, from me: String) async throws {
        try await latency(0.15)
        guard let c = currentCouple, c.isComplete else { return } // nobody to deliver to yet
        let to = c.creatorID == me ? c.partnerID! : c.creatorID
        var inbound = event
        inbound.outgoing = false
        store.inbox[to, default: []].append(inbound)
        save()
        NotificationCenter.default.post(name: .backendInbound, object: nil)
    }

    func uploadPhoto(id: String, data: Data) async throws {
        try await latency(0.4)
        let dir = storeURL.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent("\(id).jpg"), options: .atomic)
    }

    func fetchInbound(since: Date?) async throws -> [LoveEvent] {
        reload()
        guard let me = local.accountID else { return [] }
        let events = store.inbox[me] ?? []
        store.inbox[me] = []
        local.lastInboundFetch = .now
        save()
        return events
    }

    func registerDeviceTokens(_ tokens: DeviceTokens) async throws {
        guard let me = local.accountID else { return }
        store.tokens[me] = tokens
        save()
    }

    // MARK: Persistence

    private func latency(_ s: Double = 0.45) async throws {
        try await Task.sleep(for: .milliseconds(Int(s * 1000)))
    }

    private func load() {
        if let d = try? Data(contentsOf: storeURL), let s = try? JSONDecoder().decode(Store.self, from: d) { store = s }
        if let d = try? Data(contentsOf: localURL), let l = try? JSONDecoder().decode(Local.self, from: d) { local = l }
    }

    /// Re-read the shared store so a second simulator's writes show up.
    private func reload() {
        if let d = try? Data(contentsOf: storeURL), let s = try? JSONDecoder().decode(Store.self, from: d) { store = s }
    }

    private func save() {
        let s = store, l = local, su = storeURL, lu = localURL
        io.async {
            if let d = try? JSONEncoder().encode(s) { try? d.write(to: su, options: .atomic) }
            if let d = try? JSONEncoder().encode(l) { try? d.write(to: lu, options: .atomic) }
        }
    }
}
