import AVFoundation
import SwiftUI

// MARK: - Reminders

struct RemindersSettings: View {
    @EnvironmentObject private var love: LoveService
    @State private var hour = Reminders.shared.nudgeHour

    var body: some View {
        SettingsPage(title: "Reminders", subtitle: "The only notifications Aegyo sends. Everything else lives in the Dynamic Island.") {
            SettingsGroup {
                ToggleRow(title: "Miss-you nudge", line: "One a day, only if you haven't sent love yet.", key: Reminders.nudgeEnabledKey) { _ in refresh() }
                HStack {
                    Text("Nudge me at").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $hour) {
                        ForEach([8, 9, 12, 15, 18, 20, 21, 22], id: \.self) { h in
                            Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h)
                        }
                    }
                    .tint(.white.opacity(0.8))
                    .onChange(of: hour) { _, h in AppGroup.defaults.set(h, forKey: Reminders.nudgeHourKey); refresh() }
                }
                .padding(.horizontal, 14).frame(height: 52)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
                ToggleRow(title: "Day before we meet", line: "“Tomorrow you see them.”", key: Reminders.meetEnabledKey) { _ in refresh() }
                ToggleRow(title: "Milestone days", line: "Day 100, day 365 and the rest.", key: Reminders.milestoneEnabledKey) { _ in refresh() }
            }
            PermissionStatusCard()
        }
    }

    private func refresh() { Reminders.shared.refresh(lovedToday: love.sentToday > 0) }
}

/// Shows the system notification permission and deep-links to Settings if it's off.
struct PermissionStatusCard: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status == .authorized ? "checkmark.circle.fill" : "bell.slash.fill")
                .font(.system(size: 18)).foregroundStyle(status == .authorized ? Opal.mint : Color(red: 1, green: 0.7, blue: 0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(status == .authorized ? "Notifications are on" : "Notifications are off").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(status == .authorized ? "Reminders will arrive at the times above." : "Turn them on in iOS Settings to get reminders.")
                    .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if status != .authorized {
                Button { Haptics.tap(); if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } } label: {
                    Text("Open").font(.system(size: 13, weight: .semibold)).foregroundStyle(.black).padding(.horizontal, 12).frame(height: 30).background(.white, in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(14).glass(20)
        .task { status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
    }
}

// MARK: - Sounds & haptics

struct SoundsSettings: View {
    @State private var chime = Prefs.chime
    @State private var player: AVAudioPlayer?

    var body: some View {
        SettingsPage(title: "Sounds & haptics", subtitle: "Every touch has a feel. Tune it.") {
            SettingsGroup(title: "Sound") {
                ToggleRow(title: "In-app sounds", line: "The soft chime when you send.", key: Prefs.soundsKey)
                HStack {
                    Text("Arrival chime").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $chime) {
                        Text("Singing bowl").tag("missyou")
                        Text("Glass").tag("sent")
                    }
                    .tint(.white.opacity(0.8))
                    .onChange(of: chime) { _, c in AppGroup.defaults.set(c, forKey: Prefs.chimeKey); preview(c) }
                }
                .padding(.horizontal, 14).frame(height: 52)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
                Button { preview("ring") } label: {
                    HStack {
                        Text("Preview ringtone").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.system(size: 20)).foregroundStyle(Love.pink)
                    }
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(RowStyle())
            } footer: {
                Text("The chime and ringtone follow your silent switch. Ring behaves like a phone call.")
            }
            SettingsGroup(title: "Haptics") {
                ToggleRow(title: "Haptics", line: "Heartbeats, ticks and the thump when you tap \(Doki.name).", key: Prefs.hapticsKey)
                Button { Haptics.heartbeat(beats: 2) } label: {
                    HStack {
                        Text("Feel a heartbeat").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "waveform.path.ecg").font(.system(size: 17)).foregroundStyle(Love.pink)
                    }
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(RowStyle())
            }
        }
    }

    private func preview(_ name: String) {
        Haptics.tick()
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.8
        player?.play()
        if name == "ring" { DispatchQueue.main.asyncAfter(deadline: .now() + 6) { player?.stop() } }
    }
}

// MARK: - Doki's name

struct DokiNameSettings: View {
    @AppStorage(Prefs.dokiNameKey, store: AppGroup.defaults) private var name = ""
    @State private var thump = 0
    private let ideas = ["Doki", "Thump", "Dugeun", "Lub", "Bub", "Mochi", "Pip", "Nova"]

    var body: some View {
        SettingsPage(title: "\(Doki.name)'s name", subtitle: "Your heart, your name for it.") {
            Heart3DView(tint: GemTier.opal.heartTint, thump: thump, interactive: false)
                .frame(height: 200).frame(maxWidth: .infinity)
                .onTapGesture { Haptics.gemPress(); thump += 1 }
            SettingsGroup {
                FieldRow(title: "Name", text: $name, prompt: "Doki")
            } footer: {
                Text("Doki comes from “doki doki”, the sound of a racing heartbeat in Japanese.")
            }
            CapsLabel(text: "Ideas").padding(.leading, 4)
            FlowChips(items: ideas, selected: Doki.name) { Haptics.tick(); name = $0 == "Doki" ? "" : $0; thump += 1 }
        }
    }
}

struct FlowChips: View {
    var items: [String]
    var selected: String
    var pick: (String) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(items, id: \.self) { s in
                Button { pick(s) } label: {
                    Text(s).font(.system(size: 14, weight: .semibold)).foregroundStyle(s == selected ? .black : .white)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(s == selected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.08)), in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}

// MARK: - Dates

struct DatesSettings: View {
    @EnvironmentObject private var love: LoveService
    @AppStorage(Profile.togetherSinceKey, store: AppGroup.defaults) private var togetherSince: Double = 0
    @AppStorage(Profile.meetDateKey, store: AppGroup.defaults) private var meetDate: Double = 0
    @State private var pickMeet = false

    var body: some View {
        SettingsPage(title: "Dates", subtitle: "The numbers Aegyo counts for you.") {
            SettingsGroup(title: "Together since") {
                DateRow(title: "Anniversary", value: $togetherSince, range: ...Date.now)
                if togetherSince > 0 {
                    let days = Calendar.current.dateComponents([.day], from: Date(timeIntervalSince1970: togetherSince), to: .now).day ?? 0
                    InfoRow(title: "Days together", value: "\(days)")
                }
            } footer: { Text("Drives milestones, the TOGETHER counter and anniversary reminders.") }
            SettingsGroup(title: "Next time together") {
                Button { Haptics.tick(); pickMeet = true } label: {
                    HStack {
                        Text("Meet date").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Text(meetDate > 0 ? Date(timeIntervalSince1970: meetDate).formatted(date: .abbreviated, time: .shortened) : "Not set")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(RowStyle())
                if meetDate > 0 {
                    Button { Haptics.tick(); meetDate = 0; love.stopCountdown() } label: {
                        Text("Clear").font(.system(size: 15, weight: .medium)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0.5))
                            .padding(.horizontal, 14).frame(height: 48).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(RowStyle())
                }
            }
        }
        .sheet(isPresented: $pickMeet) { MeetDatePicker(date: $meetDate).aegyoSheet([.large]) }
    }
}

// MARK: - Appearance & motion

struct AppearanceSettings: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    var body: some View {
        SettingsPage(title: "Appearance & motion", subtitle: "Aegyo is always dark. Motion is up to you.") {
            SettingsGroup(title: "Motion") {
                ToggleRow(title: "Reduce effects", line: "Turns off the screen shake, water ripple and tap rings.", key: Prefs.reduceEffectsKey, defaultOn: false)
            } footer: {
                Text(systemReduceMotion ? "iOS Reduce Motion is on, so \(Doki.name) and the moon already hold still." : "Turning on Reduce Motion in iOS Accessibility also stills \(Doki.name), the moon and the stars.")
            }
            SettingsGroup(title: "Text") {
                InfoRow(title: "Text size", value: "Follows iOS")
            } footer: {
                Text("Aegyo uses Dynamic Type. Change the size in iOS Settings → Display & Brightness.")
            }
        }
    }
}

// MARK: - Privacy

struct PrivacySettings: View {
    var body: some View {
        SettingsPage(title: "Privacy", subtitle: "Everything stays between you two.") {
            SettingsGroup(title: "What your partner sees") {
                ToggleRow(title: "My city and local time", line: "Needed for Same Sky and the distance.", key: Prefs.shareCityKey)
                ToggleRow(title: "My mood", line: "Mood characters you choose to share.", key: Prefs.shareMoodKey)
            }
            SettingsGroup(title: "Diagnostics") {
                ToggleRow(title: "Share anonymous crash reports", line: "No content, names or locations. Just whether the app crashed.", key: Prefs.analyticsKey, defaultOn: false)
            }
            SettingsGroup(title: "Your data") {
                NavigationLink { LegalView(document: .privacy) } label: {
                    HStack {
                        Text("Read the Privacy Policy").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(RowStyle())
                NavigationLink { AccountDangerView() } label: {
                    HStack {
                        Text("Delete everything").font(.system(size: 15, weight: .medium)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0.5))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14).frame(height: 52).contentShape(Rectangle())
                }
                .buttonStyle(RowStyle())
            } footer: {
                Text("Aegyo has no ads, no trackers and no data brokers. Photos, letters and moods live on your phones and, once paired, travel only between them.")
            }
        }
    }
}
