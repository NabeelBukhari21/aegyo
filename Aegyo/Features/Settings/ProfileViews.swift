import PhotosUI
import SwiftUI

/// Your profile: photo, name, birthday, city. Saved on change.
struct MyProfileView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var love: LoveService
    @AppStorage(Profile.myNameKey, store: AppGroup.defaults) private var name = ""
    @AppStorage(Profile.myBirthdayKey, store: AppGroup.defaults) private var birthday: Double = 0
    @State private var city = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var saving = false
    @State private var saved = false

    var body: some View {
        SettingsPage(title: "Your profile", subtitle: "What \(partner) sees on their side.") {
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(who: .me, name: name.isEmpty ? Profile.defaultMyName : name, size: 110)
                        Image(systemName: "camera.fill").font(.aegyo(12, .bold)).foregroundStyle(.black)
                            .frame(width: 32, height: 32).background(.white, in: Circle())
                    }
                }
                .buttonStyle(PressStyle())
                .onChange(of: photoItem) {
                    guard let photoItem else { return }
                    Task {
                        if let d = try? await photoItem.loadTransferable(type: Data.self), let img = UIImage(data: d) { AvatarStore.save(img, for: .me); flash() }
                    }
                }
                Spacer()
            }

            SettingsGroup(title: "About you") {
                FieldRow(title: "Name", text: $name, prompt: "Your name")
                    .onChange(of: name) { _, v in Task { await session.updateProfile { $0.name = v }; flash() } }
                DateRow(title: "Birthday", value: $birthday, range: ...Date.now)
                    .onChange(of: birthday) { _, v in Task { await session.updateProfile { $0.birthday = Date(timeIntervalSince1970: v) }; flash() } }
                HStack {
                    Text("City").font(.aegyo(15, .medium)).foregroundStyle(.white)
                    Spacer()
                    if love.data.myPlace != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Opal.mint).font(.footnote) }
                    TextField("", text: $city, prompt: Text("e.g. Toronto").foregroundStyle(.white.opacity(0.3)))
                        .multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.85))
                        .textInputAutocapitalization(.words).submitLabel(.done)
                        .onSubmit { Task { saving = true; await love.setPlace(city, mine: true); if let p = love.data.myPlace { await session.updateProfile { $0.city = p } }; saving = false; flash() } }
                    if saving { ProgressView().tint(.white).scaleEffect(0.7) }
                }
                .padding(.horizontal, 14).frame(height: 52)
            } footer: {
                Text("Your city powers Same Sky and the distance between you. Only your partner sees it.")
            }

            if let a = session.account {
                SettingsGroup(title: "Account") {
                    InfoRow(title: "Signed in with", value: a.id.hasPrefix("apple:") ? "Apple" : (a.email ?? "Email"))
                    InfoRow(title: "Member since", value: a.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if saved {
                Label("Saved", systemImage: "checkmark").font(.aegyo(13, .semibold)).foregroundStyle(Opal.mint)
                    .frame(maxWidth: .infinity).transition(.opacity)
            }
        }
        .onAppear { city = love.data.myPlace?.name ?? "" }
    }

    private var partner: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "your partner" : n.capitalized(with: nil)
    }

    private func flash() {
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { saved = false } }
    }
}

/// Your partner's profile: what they shared, plus the nickname you use and their city if not paired.
struct PartnerProfileView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var love: LoveService
    @AppStorage(Profile.partnerNameKey, store: AppGroup.defaults) private var nickname = ""
    @AppStorage(Profile.herBirthdayKey, store: AppGroup.defaults) private var birthday: Double = 0
    @State private var city = ""
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        let p = session.partner
        SettingsPage(title: p?.name ?? (nickname.isEmpty ? "Your partner" : nickname.capitalized(with: nil)),
                     subtitle: p == nil ? "Fill this in until you pair. Once paired, it comes from their phone." : "Shared from their phone.") {
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(who: .partner, name: nickname.isEmpty ? "P" : nickname, size: 110)
                        if p == nil {
                            Image(systemName: "camera.fill").font(.aegyo(12, .bold)).foregroundStyle(.black)
                                .frame(width: 32, height: 32).background(.white, in: Circle())
                        }
                    }
                }
                .buttonStyle(PressStyle())
                .disabled(p != nil)
                .onChange(of: photoItem) {
                    guard let photoItem else { return }
                    Task { if let d = try? await photoItem.loadTransferable(type: Data.self), let img = UIImage(data: d) { AvatarStore.save(img, for: .partner) } }
                }
                Spacer()
            }

            SettingsGroup(title: "About them") {
                FieldRow(title: "What you call them", text: $nickname, prompt: "Nickname")
                if p == nil {
                    DateRow(title: "Birthday", value: $birthday, range: ...Date.now)
                    HStack {
                        Text("City").font(.aegyo(15, .medium)).foregroundStyle(.white)
                        Spacer()
                        if love.data.herPlace != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Opal.mint).font(.footnote) }
                        TextField("", text: $city, prompt: Text("e.g. Vancouver").foregroundStyle(.white.opacity(0.3)))
                            .multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.85))
                            .textInputAutocapitalization(.words).submitLabel(.done)
                            .onSubmit { Task { await love.setPlace(city, mine: false) } }
                    }
                    .padding(.horizontal, 14).frame(height: 52)
                } else {
                    InfoRow(title: "Birthday", value: p?.birthday?.formatted(.dateTime.month(.wide).day()) ?? "Not shared")
                    InfoRow(title: "City", value: p?.city?.name ?? "Not shared")
                    InfoRow(title: "Time zone", value: p?.city?.timeZone.identifier.replacingOccurrences(of: "_", with: " ") ?? "—")
                }
            }

            if let b = (p?.birthday ?? (birthday > 0 ? Date(timeIntervalSince1970: birthday) : nil)) {
                let z = Zodiac.from(b)
                SettingsGroup(title: "Stars") {
                    InfoRow(title: "Sign", value: "\(z.symbol) \(z.name)")
                    InfoRow(title: "Element", value: z.element.rawValue.capitalized)
                }
            }
        }
        .onAppear { city = love.data.herPlace?.name ?? "" }
    }
}

// MARK: - Row pieces

struct FieldRow: View {
    var title: String
    @Binding var text: String
    var prompt: String
    var body: some View {
        HStack {
            Text(title).font(.aegyo(15, .medium)).foregroundStyle(.white)
            Spacer()
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.3)))
                .multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.85))
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 14).frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
    }
}

struct DateRow: View {
    var title: String
    @Binding var value: Double
    var range: PartialRangeThrough<Date>? = nil
    var futureRange: PartialRangeFrom<Date>? = nil
    var body: some View {
        HStack {
            Text(title).font(.aegyo(15, .medium)).foregroundStyle(.white)
            Spacer()
            let binding = Binding(get: { value > 0 ? Date(timeIntervalSince1970: value) : .now }, set: { value = $0.timeIntervalSince1970; Haptics.tick() })
            if let range {
                DatePicker("", selection: binding, in: range, displayedComponents: .date).labelsHidden().tint(Love.pink)
            } else if let futureRange {
                DatePicker("", selection: binding, in: futureRange, displayedComponents: [.date, .hourAndMinute]).labelsHidden().tint(Love.pink)
            } else {
                DatePicker("", selection: binding, displayedComponents: .date).labelsHidden().tint(Love.pink)
            }
        }
        .padding(.horizontal, 14).frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    var body: some View {
        HStack {
            Text(title).font(.aegyo(15, .medium)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.aegyo(14)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
        }
        .padding(.horizontal, 14).frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 14) }
    }
}
