import CallKit
import UIKit

/// Shows the full-screen, call-style "Ring" using CallKit with our own soothing ringtone.
final class CallService: NSObject, CXProviderDelegate {
    static let shared = CallService()

    private let provider: CXProvider
    private var callers: [UUID: String] = [:]

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        config.ringtoneSound = "ring.caf"
        config.iconTemplateImageData = UIImage(systemName: "heart.fill")?.pngData()
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingRing(from name: String, completion: ((Error?) -> Void)? = nil) {
        let id = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: name)
        update.localizedCallerName = "\(name) 💗"
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsDTMF = false
        callers[id] = name
        provider.reportNewIncomingCall(with: id, update: update) { error in
            if let error { print("CallKit error: \(error.localizedDescription)") }
            completion?(error)
        }
    }

    // MARK: CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        callers.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        let name = callers[action.callUUID] ?? Profile.partnerName
        // For now a Ring is a "love tap", not a voice call: end it and show a sweet screen in the app.
        // (A real voice call over WebRTC can be added later.)
        provider.reportCall(with: action.callUUID, endedAt: .now, reason: .remoteEnded)
        callers[action.callUUID] = nil
        Task { @MainActor in AppState.shared.answeredRingFrom = name }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        callers[action.callUUID] = nil
        action.fulfill()
    }
}
