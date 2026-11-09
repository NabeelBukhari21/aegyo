import PushKit
import UIKit
import UserNotifications

/// Registers this phone with Apple for:
///  - normal push notifications (messages, "Miss you" alerts)
///  - VoIP pushes (the call-style "Ring")
///  - Live Activity push-to-start (Dynamic Island "Miss you")
/// The resulting tokens are kept in `TokenStore` and uploaded to the backend in Phase 2.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, PKPushRegistryDelegate {
    private var voipRegistry: PKPushRegistry?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        // VoIP pushes must be registered early on every launch so a Ring can wake the app.
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry

        Task { @MainActor in TokenStore.shared.observeLiveActivityTokens() }
        _ = CallService.shared
        return true
    }

    // MARK: Regular push token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in TokenStore.shared.apns = deviceToken.hexString }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // Show banners + play the chime even while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // MARK: VoIP (Ring)

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        Task { @MainActor in TokenStore.shared.voip = pushCredentials.token.hexString }
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        // Apple's rule: every VoIP push MUST immediately report an incoming call, or iOS stops delivering them.
        let from = payload.dictionaryPayload["from"] as? String ?? Profile.partnerName
        CallService.shared.reportIncomingRing(from: from) { _ in completion() }
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
