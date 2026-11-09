import AppIntents

/// "Send Miss You" — assign it to the Action Button (Settings → Action Button → Shortcut),
/// or say "Hey Siri, miss you in Aegyo".
struct SendMissYouIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Miss You"
    static var description = IntentDescription("Tell your person you miss them.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Haptics.heartbeat()
        await LoveService.shared.send(.missYou)
        return .result(dialog: "Sent 💗")
    }
}

struct RingPartnerIntent: AppIntent {
    static var title: LocalizedStringResource = "Ring My Love"
    static var description = IntentDescription("Ring your person's phone with your soothing ringtone.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        LoveService.shared.ring()
        return .result(dialog: "Ringing 📞💗")
    }
}

struct AegyoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendMissYouIntent(),
            phrases: ["Miss you in \(.applicationName)", "Send love with \(.applicationName)"],
            shortTitle: "Miss You",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: RingPartnerIntent(),
            phrases: ["Ring my love with \(.applicationName)"],
            shortTitle: "Ring",
            systemImageName: "phone.fill"
        )
    }
}
