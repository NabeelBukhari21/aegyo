import SwiftUI

/// Settings hub (The Outsiders style): a big header for the two of you, then grouped rows.
struct SettingsView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Profile.partnerNameKey, store: AppGroup.defaults) private var partnerName = ""
    @State private var pairing = false
    @State private var path = NavigationPath()

    enum Page: String, Hashable { case profile, partner, reminders, sounds, doki, dates, appearance, privacy, help, feedback, about, legalPrivacy, legalTerms, account }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    group("You two") {
                        link("Your profile", icon: "person.crop.circle.fill", tint: Love.pink) { MyProfileView() }
                        link("\(partnerDisplay)'s profile", icon: "heart.circle.fill", tint: Love.violet) { PartnerProfileView() }
                        button("Pairing", icon: "link", tint: Opal.mint, value: pairingValue) { pairing = true }
                    }

                    group("Preferences") {
                        link("Reminders", icon: "bell.badge.fill", tint: Color(red: 1, green: 0.8, blue: 0.4)) { RemindersSettings() }
                        link("Sounds & haptics", icon: "speaker.wave.2.fill", tint: Color(red: 0.5, green: 0.8, blue: 1)) { SoundsSettings() }
                        link("\(Doki.name)'s name", icon: "heart.fill", tint: Love.pink, value: Doki.name) { DokiNameSettings() }
                        link("Dates", icon: "calendar", tint: Love.peach) { DatesSettings() }
                        link("Appearance & motion", icon: "sparkles", tint: Love.violet) { AppearanceSettings() }
                        link("Privacy", icon: "lock.fill", tint: Opal.mint) { PrivacySettings() }
                    }

                    PlusTeaserCard()

                    group("Support") {
                        link("Help & support", icon: "questionmark.circle.fill", tint: .white) { HelpView() }
                        link("Send feedback", icon: "paperplane.fill", tint: .white) { FeedbackView() }
                        link("About Aegyo", icon: "info.circle.fill", tint: .white) { AboutView() }
                    }

                    group("Legal") {
                        link("Privacy Policy", icon: "hand.raised.fill", tint: .white.opacity(0.7)) { LegalView(document: .privacy) }
                        link("Terms of Use", icon: "doc.text.fill", tint: .white.opacity(0.7)) { LegalView(document: .terms) }
                    }

                    group("Account") {
                        link("Sign out, unpair, or delete", icon: "exclamationmark.triangle.fill", tint: Color(red: 1, green: 0.55, blue: 0.5)) { AccountDangerView() }
                    }

                    Text("Aegyo \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · made with love")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(OpalBackground(focus: UnitPoint(x: 0.5, y: 0.1)))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold).tint(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .profile: MyProfileView()
                case .partner: PartnerProfileView()
                case .reminders: RemindersSettings()
                case .sounds: SoundsSettings()
                case .doki: DokiNameSettings()
                case .dates: DatesSettings()
                case .appearance: AppearanceSettings()
                case .privacy: PrivacySettings()
                case .help: HelpView()
                case .feedback: FeedbackView()
                case .about: AboutView()
                case .legalPrivacy: LegalView(document: .privacy)
                case .legalTerms: LegalView(document: .terms)
                case .account: AccountDangerView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.black)
        .sheet(isPresented: $pairing) { PairSheet().aegyoSheet([.large]) }
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-settingsPage"), i + 1 < args.count, let p = Page(rawValue: args[i + 1]) {
                try? await Task.sleep(for: .milliseconds(400)); path.append(p)
            }
        }
        #endif
    }

    private var partnerDisplay: String { partnerName.isEmpty ? "Partner" : partnerName.capitalized(with: nil) }

    private var pairingValue: String {
        switch session.pairing {
        case .paired(let p): "Paired with \(p.name)"
        case .waiting: "Waiting"
        case .partnerLeft: "Partner left"
        case .notPaired: "Not paired"
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            HStack(spacing: -12) {
                AvatarView(who: .me, name: Profile.myName, size: 60)
                AvatarView(who: .partner, name: partnerDisplay, size: 60)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Profile.myName) & \(partnerDisplay)").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    if session.isPaired { PresenceDot() }
                    Text(pairingValue).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
        }
        .padding(16)
        .glass(24)
    }

    // MARK: Row builders

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: title).padding(.leading, 4)
            VStack(spacing: 0) { content() }.glass(22)
        }
    }

    private func link<D: View>(_ title: String, icon: String, tint: Color, value: String? = nil, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: { row(title, icon: icon, tint: tint, value: value) }
            .buttonStyle(RowStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.tick() })
    }

    private func button(_ title: String, icon: String, tint: Color, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button { Haptics.tick(); action() } label: { row(title, icon: icon, tint: tint, value: value) }
            .buttonStyle(RowStyle())
    }

    private func row(_ title: String, icon: String, tint: Color, value: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            Spacer()
            if let value { Text(value).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).lineLimit(1) }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14).frame(height: 54)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60) }
    }
}

/// Subtle row highlight on press.
struct RowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Color.white.opacity(0.06) : .clear)
    }
}

/// Shared scaffold for every settings sub-screen.
struct SettingsPage<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Headline(title: title, subtitle: subtitle)
                content
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(OpalBackground(focus: UnitPoint(x: 0.5, y: 0.1)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

/// A toggle row in Aegyo's style.
struct ToggleRow: View {
    var title: String
    var line: String? = nil
    var key: String
    var defaultOn = true
    var onChange: ((Bool) -> Void)? = nil
    @State private var on = false

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                if let line { Text(line).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5)) }
            }
        }
        .tint(Love.pink)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .onAppear { on = AppGroup.defaults.object(forKey: key) as? Bool ?? defaultOn }
        .onChange(of: on) { _, v in
            AppGroup.defaults.set(v, forKey: key)
            Haptics.tick()
            onChange?(v)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
    }
}

struct SettingsGroup<Content: View, Footer: View>: View {
    var title: String?
    let content: Content
    let footer: Footer

    init(title: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title; self.content = content(); self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { CapsLabel(text: title).padding(.leading, 4) }
            VStack(spacing: 0) { content }.glass(22)
            footer.font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 4)
        }
    }
}

extension SettingsGroup where Footer == EmptyView {
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, content: content, footer: { EmptyView() })
    }
}
