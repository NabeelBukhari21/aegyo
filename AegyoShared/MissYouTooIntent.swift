import ActivityKit
import AppIntents
import Foundation

/// The "Miss you too 💗" button inside the Dynamic Island / Lock Screen Live Activity.
/// Runs in the app's process, so the receiver can reply without opening the app.
struct MissYouTooIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Miss you too"
    static var description = IntentDescription("Send love back from the Dynamic Island.")

    func perform() async throws -> some IntentResult {
        for activity in Activity<LoveAttributes>.activities {
            var state = activity.content.state
            state.replied = true
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(.now + 4)
            )
        }
        // Phase 3: also send a `.missYou` back to the partner through the backend.
        return .result()
    }
}
