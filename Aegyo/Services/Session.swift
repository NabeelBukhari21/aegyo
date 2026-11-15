import SwiftUI
import UserNotifications

/// Who is signed in, who they're paired with, and where the app should route.
@MainActor
final class Session: ObservableObject {
    static let shared = Session()

    enum Route: Equatable { case loading, onboarding, app }

    @Published private(set) var route: Route = .loading
    @Published private(set) var account: Account?
    @Published private(set) var partner: Account?
    @Published private(set) var couple: Couple?
    @Published private(set) var pairing: PairingState = .notPaired
    @Published var lastError: String?
    @Published private(set) var pendingSends = 0

    let backend: LocalBackend
    private var pollTask: Task<Void, Never>?

    private static let onboardedKey = "onboardingComplete"
    var onboardingComplete: Bool {
        get { AppGroup.defaults.bool(forKey: Self.onboardedKey) }
        set { AppGroup.defaults.set(newValue, forKey: Self.onboardedKey) }
    }

    private init() {
        backend = LocalBackend()
        NotificationCenter.default.addObserver(forName: .backendCoupleChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshPairing() }
        }
        NotificationCenter.default.addObserver(forName: .backendInbound, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.pullInbound() }
        }
    }

    // MARK: Lifecycle

    func start() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetOnboarding") { onboardingComplete = false; await backend.signOut() }
        if args.contains("-onboarding") { onboardingComplete = false }
        if args.contains("-skipOnboarding") {
            _ = try? await backend.signIn(.email(name: Profile.myName, email: "demo@aegyo.local"))
            onboardingComplete = true
        }
        #endif
        account = backend.currentAccount
        await refreshPairing()
        route = (onboardingComplete && account != nil) ? .app : .onboarding
        pendingSends = backend.pendingOutbound
        startPolling()
    }

    func completeOnboarding() {
        onboardingComplete = true
        withAnimation(.smooth(duration: 0.6)) { route = .app }
    }

    // MARK: Auth

    func signIn(_ method: SignInMethod) async throws {
        let a = try await backend.signIn(method)
        account = a
        // keep the names the rest of the app reads in sync
        if !a.name.isEmpty { AppGroup.defaults.set(a.name, forKey: Profile.myNameKey) }
        await refreshPairing()
    }

    func updateProfile(_ mutate: (inout Account) -> Void) async {
        guard var a = account else { return }
        mutate(&a)
        account = a
        AppGroup.defaults.set(a.name, forKey: Profile.myNameKey)
        if let b = a.birthday { AppGroup.defaults.set(b.timeIntervalSince1970, forKey: Profile.myBirthdayKey) }
        do { try await backend.updateProfile(a) } catch { lastError = error.localizedDescription }
    }

    func signOut() async {
        await backend.signOut()
        account = nil; partner = nil; couple = nil; pairing = .notPaired
        onboardingComplete = false
        withAnimation(.smooth) { route = .onboarding }
    }

    func deleteAccount() async throws {
        try await backend.deleteAccount()
        AccountDeletion.wipeLocalData()
        account = nil; partner = nil; couple = nil; pairing = .notPaired
        onboardingComplete = false
        withAnimation(.smooth) { route = .onboarding }
    }

    // MARK: Pairing

    func createCouple() async throws -> Couple {
        let c = try await backend.createCouple()
        couple = c
        pairing = .waiting(code: c.code)
        return c
    }

    func joinCouple(code: String) async throws {
        let c = try await backend.joinCouple(code: code)
        couple = c
        await refreshPairing()
    }

    func leaveCouple() async {
        do { try await backend.leaveCouple() } catch { lastError = error.localizedDescription }
        couple = nil; partner = nil; pairing = .notPaired
        AppGroup.defaults.removeObject(forKey: Profile.partnerNameKey)
    }

    func refreshPairing() async {
        couple = try? await backend.refreshCouple()
        partner = try? await backend.fetchPartner()
        guard let c = couple else {
            // did a previous partner leave?
            pairing = .notPaired
            return
        }
        if let me = account?.id, let left = c.leftBy, left != me {
            pairing = .partnerLeft(name: partner?.name ?? Profile.partnerName)
        } else if let p = partner, c.isComplete {
            pairing = .paired(partner: p)
            AppGroup.defaults.set(p.name, forKey: Profile.partnerNameKey)
            if let b = p.birthday { AppGroup.defaults.set(b.timeIntervalSince1970, forKey: Profile.herBirthdayKey) }
            if let anniversary = c.anniversary { AppGroup.defaults.set(anniversary.timeIntervalSince1970, forKey: Profile.togetherSinceKey) }
        } else {
            pairing = .waiting(code: c.code)
        }
    }

    var isPaired: Bool { if case .paired = pairing { return true } else { return false } }

    // MARK: Love delivery

    func deliver(_ event: LoveEvent) async {
        do {
            try await backend.send(event)
        } catch BackendError.offline {
            pendingSends = backend.pendingOutbound
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cameOnline() async {
        await backend.drainOutbound()
        pendingSends = backend.pendingOutbound
        await pullInbound()
    }

    private func pullInbound() async {
        guard let events = try? await backend.fetchInbound(since: nil), !events.isEmpty else { return }
        LoveService.shared.receive(events)
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard let self else { return }
                if case .waiting = self.pairing { await self.refreshPairing() }
                await self.pullInbound()
            }
        }
    }
}

/// Removes everything the app stored on this phone.
@MainActor
enum AccountDeletion {
    static func wipeLocalData() {
        let fm = FileManager.default
        for dir in [fm.urls(for: .documentDirectory, in: .userDomainMask)[0],
                    fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                    fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]] {
            (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.forEach { try? fm.removeItem(at: $0) }
        }
        if let container = AppGroup.container {
            (try? fm.contentsOfDirectory(at: container, includingPropertiesForKeys: nil))?.forEach { try? fm.removeItem(at: $0) }
        }
        let d = AppGroup.defaults
        d.dictionaryRepresentation().keys.forEach { d.removeObject(forKey: $0) }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        LoveService.shared.resetAll()
    }
}
