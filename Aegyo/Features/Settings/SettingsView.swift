import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var tokens: TokenStore
    @EnvironmentObject private var love: LoveService
    @State private var myCity = ""
    @State private var herCity = ""
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Profile.myNameKey, store: AppGroup.defaults) private var myName = ""
    @AppStorage(Profile.partnerNameKey, store: AppGroup.defaults) private var partnerName = ""
    @AppStorage(Profile.togetherSinceKey, store: AppGroup.defaults) private var togetherSince: Double = 0

    private var sinceBinding: Binding<Date> {
        Binding(
            get: { togetherSince > 0 ? Date(timeIntervalSince1970: togetherSince) : .now },
            set: { togetherSince = $0.timeIntervalSince1970 }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    StaticGem(width: 64)
                        .padding(.top, 8)

                    group("YOU TWO") {
                        field("Your name", text: $myName, prompt: Profile.defaultMyName)
                        divider
                        field("Her name", text: $partnerName, prompt: "Her name")
                        divider
                        HStack {
                            Text("Together since").foregroundStyle(.white)
                            Spacer()
                            DatePicker("", selection: sinceBinding, in: ...Date.now, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .frame(height: 48)
                    }

                    group("WHERE YOU ARE") {
                        cityField("Your city", text: $myCity, place: love.data.myPlace, mine: true)
                        divider
                        cityField("Her city", text: $herCity, place: love.data.herPlace, mine: false)
                    }

                    group("REMINDERS") {
                        Toggle(isOn: Binding(get: { Reminders.shared.nudgeEnabled }, set: { AppGroup.defaults.set($0, forKey: Reminders.nudgeEnabledKey); refreshReminders() })) {
                            Text("Miss-you nudge").foregroundStyle(.white)
                        }
                        .tint(Love.pink).frame(height: 48)
                        divider
                        HStack {
                            Text("Nudge me at").foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: Binding(get: { Reminders.shared.nudgeHour }, set: { AppGroup.defaults.set($0, forKey: Reminders.nudgeHourKey); refreshReminders() })) {
                                ForEach([9, 12, 15, 18, 20, 21, 22], id: \.self) { h in
                                    Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h)
                                }
                            }
                            .tint(.white.opacity(0.7))
                        }
                        .frame(height: 48)
                        divider
                        Toggle(isOn: Binding(get: { Reminders.shared.meetEnabled }, set: { AppGroup.defaults.set($0, forKey: Reminders.meetEnabledKey); refreshReminders() })) {
                            Text("Day before we meet").foregroundStyle(.white)
                        }
                        .tint(Love.pink).frame(height: 48)
                        divider
                        Toggle(isOn: Binding(get: { Reminders.shared.milestoneEnabled }, set: { AppGroup.defaults.set($0, forKey: Reminders.milestoneEnabledKey); refreshReminders() })) {
                            Text("Milestone days").foregroundStyle(.white)
                        }
                        .tint(Love.pink).frame(height: 48)
                    }

                    group("PAIRING") {
                        row("Pair with her phone", value: "Next step", icon: "link")
                    }

                    group("THIS PHONE") {
                        row("Notifications", value: tokens.apns == nil ? "Waiting" : "Ready", ok: tokens.apns != nil)
                        divider
                        row("Ring", value: tokens.voip == nil ? "Waiting" : "Ready", ok: tokens.voip != nil)
                        divider
                        row("Dynamic Island", value: tokens.liveActivityStart == nil ? "Waiting" : "Ready", ok: tokens.liveActivityStart != nil)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTION BUTTON")
                            .font(.system(size: 11, weight: .medium)).tracking(1)
                            .foregroundStyle(.white.opacity(0.45))
                        Text("Settings → Action Button → Shortcut → Send Miss You. One press and she feels it.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.black)
            .navigationTitle("You two")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold).tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.black)
        .onAppear {
            myCity = love.data.myPlace?.name ?? ""
            herCity = love.data.herPlace?.name ?? ""
        }
    }

    private func cityField(_ label: String, text: Binding<String>, place: Place?, mine: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            if place != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Opal.mint).font(.footnote) }
            TextField("", text: text, prompt: Text("e.g. Seoul").foregroundStyle(.white.opacity(0.3)))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white.opacity(0.8))
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { Task { await love.setPlace(text.wrappedValue, mine: mine) } }
        }
        .frame(height: 48)
    }

    private func refreshReminders() {
        Haptics.tick()
        Reminders.shared.refresh(lovedToday: love.sentToday > 0)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium)).tracking(1)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 16)
                .glass(20)
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.3)))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white.opacity(0.8))
                .textInputAutocapitalization(.words)
        }
        .frame(height: 48)
    }

    private func row(_ label: String, value: String, ok: Bool = false, icon: String? = nil) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            if ok { Circle().fill(Opal.mint).frame(width: 6, height: 6) }
            Text(value).foregroundStyle(ok ? Opal.mint : .white.opacity(0.4))
            if let icon { Image(systemName: icon).foregroundStyle(.white.opacity(0.3)).font(.footnote) }
        }
        .font(.system(size: 15))
        .frame(height: 48)
    }
}
