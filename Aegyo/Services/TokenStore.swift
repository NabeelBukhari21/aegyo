import ActivityKit
import Foundation

/// Holds the three tokens the backend needs to reach this phone.
@MainActor
final class TokenStore: ObservableObject {
    static let shared = TokenStore()

    /// Normal APNs device token (alerts, chat messages).
    @Published var apns: String?
    /// PushKit VoIP token (call-style Ring).
    @Published var voip: String?
    /// Live Activity push-to-start token (Dynamic Island "Miss you").
    @Published var liveActivityStart: String?

    private var observing = false

    func observeLiveActivityTokens() {
        guard !observing else { return }
        observing = true
        Task {
            for await token in Activity<LoveAttributes>.pushToStartTokenUpdates {
                self.liveActivityStart = token.hexString
            }
        }
    }
}
