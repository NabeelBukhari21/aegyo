import MessageUI
import SwiftUI

// MARK: - Help & support

struct HelpView: View {
    @State private var open: Int? = 0
    private let faqs: [(String, String)] = [
        ("Why doesn't my partner get anything yet?", "Taps only reach another phone once you're paired. Open Settings → Pairing, create a link and share the six-digit code. Until then, every tap previews on your own phone so you can see exactly what they'll get."),
        ("Nothing shows in the Dynamic Island.", "Make sure Live Activities are allowed: iOS Settings → Aegyo → Live Activities. Then tap Doki and swipe home. Long-press the island to expand it."),
        ("The Ring doesn't ring.", "Ring behaves like a phone call. Check that Aegyo is allowed in iOS Settings → Phone → Call Blocking & Identification, and that a Focus mode isn't silencing calls."),
        ("I don't hear the chime.", "The chime follows the silent switch and Focus. Flip the switch, or allow Aegyo under Focus → Allowed Apps."),
        ("Can I change Doki's name?", "Yes: Settings → Doki's name. Pick one of the ideas or type your own."),
        ("What does Clingy include?", "Unlimited photos and the photo widget, Open-When letters, voice notes, heartbeats, share cards, Doki's forms, star signs, Same Sky, your timeline and milestones."),
        ("How do I delete my account?", "Settings → Account → Delete account. It removes everything on this phone and unpairs you. It can't be undone."),
    ]

    var body: some View {
        SettingsPage(title: "Help & support", subtitle: "Quick answers, and a human if you need one.") {
            VStack(spacing: 8) {
                ForEach(Array(faqs.enumerated()), id: \.offset) { i, f in
                    Button {
                        Haptics.tick()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { open = open == i ? nil : i }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(f.0).font(.aegyo(15, .semibold)).foregroundStyle(.white).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.down").font(.aegyo(12, .semibold)).foregroundStyle(.white.opacity(0.4))
                                    .rotationEffect(.degrees(open == i ? 180 : 0))
                            }
                            if open == i {
                                Text(f.1).font(.aegyo(14)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(20)
                    }
                    .buttonStyle(PressStyle(scale: 0.99))
                    .accessibilityAddTraits(open == i ? [.isButton, .isSelected] : .isButton)
                }
            }
            NavigationLink { FeedbackView() } label: {
                PinkPill(title: "Still stuck? Message us", systemImage: "paperplane.fill") {}
                    .allowsHitTesting(false)
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
        }
    }
}

// MARK: - Feedback

struct FeedbackView: View {
    @State private var kind = "Something's broken"
    @State private var text = ""
    @State private var sent = false
    @State private var showMail = false
    private let kinds = ["Something's broken", "An idea", "Just saying hi"]

    var body: some View {
        SettingsPage(title: "Send feedback", subtitle: "Read by a person. Replies within a couple of days.") {
            PillSegmented(options: kinds.map { ($0, $0) }, selection: $kind)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.3)), axis: .vertical)
                .lineLimit(5...10).font(.aegyo(16)).foregroundStyle(.white)
                .padding(16).glass(22)
            Text("Device: \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion) · Aegyo \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.aegyo(12)).foregroundStyle(.white.opacity(0.4))
            if sent {
                SuccessMoment(title: "Thanks", message: "We got it.").frame(maxWidth: .infinity).padding(.top, 10)
            } else {
                MorphSendButton(title: "Send", systemImage: "paperplane.fill") {
                    await MainActor.run { send() }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
        }
        .sheet(isPresented: $showMail) {
            MailComposer(subject: "Aegyo feedback: \(kind)", body: text + "\n\n—\n\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)") { sent = true }
        }
    }

    private var prompt: String {
        switch kind {
        case "An idea": "What should Aegyo do next?"
        case "Just saying hi": "Hi!"
        default: "What happened, and what did you expect?"
        }
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() {
            showMail = true
        } else {
            // No mail account: hand the text to the share sheet instead (opens on the next run loop).
            let av = UIActivityViewController(activityItems: ["Aegyo feedback: \(kind)\n\n\(text)"], applicationActivities: nil)
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController?.present(av, animated: true)
            withAnimation { sent = true }
        }
    }
}

struct MailComposer: UIViewControllerRepresentable {
    var subject: String
    var body: String
    var onSent: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["hello@aegyo.app"])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposer
        init(_ p: MailComposer) { parent = p }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if result == .sent { parent.onSent() }
            parent.dismiss()
        }
    }
}

// MARK: - About

struct AboutView: View {
    @State private var thump = 0
    var body: some View {
        SettingsPage(title: "About Aegyo") {
            Heart3DView(tint: GemTier.opal.heartTint, thump: thump, interactive: false)
                .frame(height: 220).frame(maxWidth: .infinity)
                .onTapGesture { Haptics.gemPress(); thump += 1 }
            VStack(alignment: .leading, spacing: 10) {
                Text("Aegyo (애교) is the Korean word for the small, deliberately cute things you do to make someone you love smile.")
                    .font(.aegyo(15)).foregroundStyle(.white.opacity(0.75))
                Text("This app exists because distance makes every “I miss you” louder. One tap, and it lands in the Dynamic Island of the person who matters.")
                    .font(.aegyo(15)).foregroundStyle(.white.opacity(0.75))
            }
            .padding(16).glass(22)
            SettingsGroup(title: "Version") {
                InfoRow(title: "Aegyo", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                InfoRow(title: "Made by", value: "Syed Nabeel Raza")
                InfoRow(title: "Sounds", value: "Crystal singing bowls, synthesized")
            }
            SettingsGroup(title: "Thanks") {
                InfoRow(title: "Design references", value: "Opal, The Outsiders")
                InfoRow(title: "Built with", value: "SwiftUI, SceneKit, Metal")
            }
        }
    }
}

// MARK: - Legal

struct LegalView: View {
    enum Document { case privacy, terms }
    var document: Document

    var body: some View {
        SettingsPage(title: document == .privacy ? "Privacy Policy" : "Terms of Use", subtitle: "Last updated 15 November 2026") {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.0).font(.aegyo(16, .semibold)).foregroundStyle(.white)
                        Text(s.1).font(.aegyo(14)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18).glass(22)
        }
    }

    private var sections: [(String, String)] {
        switch document {
        case .privacy:
            return [
                ("The short version", "Aegyo is for two people. What you send goes to your partner and nowhere else. We don't sell data, we don't show ads, and we don't use trackers."),
                ("What Aegyo stores", "Your name, photo, birthday and city (if you add them); the love you send and receive (taps, moods, photos, letters, voice notes, heartbeats); your anniversary and meet-up dates; and your preferences. All of it lives on your phone. When you pair, the parts your partner needs are delivered to their phone."),
                ("What your partner sees", "Your name and photo, your city and local time (you can turn this off in Privacy), your moods, and everything you choose to send. They never see your location more precisely than your city."),
                ("Notifications and the Dynamic Island", "Love arrives as a Live Activity and reminders as notifications. Push tokens that make this possible are stored only to reach your device and are deleted when you delete your account."),
                ("Sign in with Apple", "If you sign in with Apple, we receive an anonymous identifier and, if you allow it, your name and email. We use them only to sign you in."),
                ("Purchases", "Subscriptions are handled by Apple. We never see your payment details."),
                ("Diagnostics", "Crash reports are off by default. If you turn them on, they contain no content, names or locations."),
                ("Deleting your data", "Settings → Account → Delete account removes everything on this phone and unpairs you. It cannot be undone."),
                ("Children", "Aegyo is for people 17 and over."),
                ("Contact", "hello@aegyo.app"),
            ]
        case .terms:
            return [
                ("Using Aegyo", "Aegyo is a personal app for two people in a relationship. Use it kindly. Don't use it to harass, impersonate or spam anyone, and don't pair with someone who hasn't agreed to it."),
                ("Your content", "What you send stays yours. By sending it, you let Aegyo deliver it to your partner's phone and show it there."),
                ("Clingy", "Clingy is an auto-renewing subscription (monthly or yearly) or a one-time lifetime purchase, billed through your Apple ID. Subscriptions renew unless cancelled at least 24 hours before the end of the period. Manage or cancel them in iOS Settings → Apple ID → Subscriptions. Free trials convert to a paid subscription unless cancelled before they end."),
                ("No medical or safety use", "Aegyo is not a safety, emergency or health tool. The Ring is not a replacement for a phone call in an emergency."),
                ("Availability", "We do our best to keep Aegyo running, but it's provided as is, without warranties. Features may change."),
                ("Ending things", "You can delete your account at any time. We may suspend accounts that break these terms."),
                ("Changes", "If these terms change in a way that matters, the app will tell you."),
                ("Contact", "hello@aegyo.app"),
            ]
        }
    }
}
