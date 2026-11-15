import Foundation
import UIKit

// MARK: - Models the backend deals in

struct Account: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var email: String?
    var birthday: Date?
    var city: Place?
    var avatarID: String?
    var createdAt = Date()
}

/// A couple: two accounts joined by a 6-digit code.
struct Couple: Codable, Hashable, Identifiable {
    var id: String
    var code: String
    var creatorID: String
    var partnerID: String?
    var anniversary: Date?
    var createdAt = Date()
    var leftBy: String?

    var isComplete: Bool { partnerID != nil && leftBy == nil }
}

enum PairingState: Hashable {
    case notPaired
    case waiting(code: String)
    case paired(partner: Account)
    case partnerLeft(name: String)
}

enum SignInMethod: Hashable {
    case apple(userID: String, name: String?, email: String?)
    case email(name: String, email: String)
}

struct DeviceTokens: Codable, Hashable {
    var apns: String?
    var voip: String?
    var liveActivityStart: String?
}

enum BackendError: LocalizedError {
    case notSignedIn, invalidCode, codeExpired, alreadyPaired, cannotJoinOwnCouple, offline, failed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You're not signed in."
        case .invalidCode: "That code doesn't match any invite. Check the six digits and try again."
        case .codeExpired: "That invite has expired. Ask for a fresh code."
        case .alreadyPaired: "That person is already paired with someone."
        case .cannotJoinOwnCouple: "That's your own code. Send it to your partner instead."
        case .offline: "You're offline. We'll send it as soon as you're back."
        case .failed(let s): s
        }
    }
}

// MARK: - The contract every backend fulfils

/// Everything Aegyo needs from a server. `LocalBackend` runs it entirely on this phone;
/// a future `FirebaseBackend` implements the same calls against Firestore + Cloud Functions.
@MainActor
protocol Backend: AnyObject {
    var currentAccount: Account? { get }
    var currentCouple: Couple? { get }

    // Auth
    func signIn(_ method: SignInMethod) async throws -> Account
    func signOut() async
    func deleteAccount() async throws

    // Profile
    func updateProfile(_ account: Account) async throws
    func fetchPartner() async throws -> Account?

    // Pairing
    func createCouple() async throws -> Couple
    func joinCouple(code: String) async throws -> Couple
    func leaveCouple() async throws
    func refreshCouple() async throws -> Couple?

    // Love
    func send(_ event: LoveEvent) async throws
    func uploadPhoto(id: String, data: Data) async throws
    /// Events sent by the partner that haven't been delivered to this device yet.
    func fetchInbound(since: Date?) async throws -> [LoveEvent]

    // Devices
    func registerDeviceTokens(_ tokens: DeviceTokens) async throws
}

extension Notification.Name {
    static let backendCoupleChanged = Notification.Name("aegyo.backend.coupleChanged")
    static let backendInbound = Notification.Name("aegyo.backend.inbound")
}
