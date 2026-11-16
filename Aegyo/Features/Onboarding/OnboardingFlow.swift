import AuthenticationServices
import PhotosUI
import SwiftUI

/// First-run flow, in Opal's style: Doki at the top, one question per screen, a line of copy that
/// fades in, and a soft-gradient Continue pill. Steps: welcome story → sign up → setup → permissions → pair → done.
struct OnboardingFlow: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var love: LoveService

    enum Step: Int, CaseIterable { case story, signUp, name, partnerName, photo, birthday, city, anniversary, notifications, pair, done }

    @State private var step: Step = .story
    @State private var storyBeat = 0
    @State private var draft = Draft()
    @State private var busy = false
    @State private var error: String?
    @State private var thump = 0

    struct Draft {
        var name = ""
        var partnerName = ""
        var email = ""
        var photo: UIImage?
        var birthday: Date?
        var city = ""
        var anniversary: Date?
        var appleUserID: String?
    }

    private let beats = [
        ("Some hearts beat for someone far away.", "TAP TO CONTINUE"),
        ("Distance makes every \"I miss you\" louder.", "TAP TO CONTINUE"),
        ("Aegyo turns a tap into a heartbeat on their phone.", "TAP TO CONTINUE"),
        ("Right in the Dynamic Island. No typing. Just feeling.", "TAP TO BEGIN"),
    ]

    var body: some View {
        ZStack {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.22))
            if step == .story { StarField(density: 70).ignoresSafeArea().opacity(0.6) }

            VStack(spacing: 0) {
                header
                Group {
                    switch step {
                    case .story: story
                    case .signUp: EmptyView()
                    case .name: nameStep
                    case .partnerName: partnerStep
                    case .photo: photoStep
                    case .birthday: birthdayStep
                    case .city: cityStep
                    case .anniversary: anniversaryStep
                    case .notifications: notificationsStep
                    case .pair: PairStep(onDone: { advance() })
                    case .done: doneStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
        }
        .preferredColorScheme(.dark)
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-onboardStep"), i + 1 < args.count, let n = Int(args[i + 1]), let s = Step(rawValue: n) {
                draft.name = "Nabeel"; draft.partnerName = "Jagi"
                try? await Task.sleep(for: .milliseconds(300))
                step = s
            }
            if let i = args.firstIndex(of: "-storyBeat"), i + 1 < args.count, let n = Int(args[i + 1]) { storyBeat = n }
        }
        #endif
        .sheet(isPresented: Binding(get: { step == .signUp }, set: { if !$0 && step == .signUp { step = .story } })) {
            SignUpSheet(draft: $draft, busy: $busy, error: $error) { method in
                Task { await signIn(method) }
            }
        }
        .alert("Hmm", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    // MARK: Header: Doki + progress

    private var header: some View {
        VStack(spacing: 6) {
            if step != .story && step != .done {
                HStack(spacing: 4) {
                    ForEach(Step.allCases.filter { $0 != .story && $0 != .signUp && $0 != .done }, id: \.rawValue) { s in
                        Capsule().fill(s.rawValue <= step.rawValue ? Color.white : Color.white.opacity(0.18)).frame(height: 3)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 10)
                .animation(.smooth, value: step)
            }
            if step != .pair {
                Heart3DView(tint: GemTier.opal.heartTint, thump: thump, interactive: false, reveal: step == .story)
                    .frame(height: step == .story ? 300 : 170)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: step)
            }
        }
    }

    // MARK: Story

    private var story: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(beats[storyBeat].0)
                .font(.aegyo(22, .semibold)).tracking(-0.3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .id(storyBeat)
                .transition(.opacity.combined(with: .offset(y: 8)))
            Spacer()
            Text(beats[storyBeat].1)
                .font(.aegyo(11, .semibold)).tracking(1.6)
                .foregroundStyle(Opal.mint.opacity(0.9))
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            thump += 1
            if storyBeat < beats.count - 1 { withAnimation(.smooth(duration: 0.5)) { storyBeat += 1 } } else { step = .signUp }
        }
        .animation(.smooth(duration: 0.5), value: storyBeat)
        .accessibilityElement()
        .accessibilityLabel(beats[storyBeat].0)
        .accessibilityHint("Double tap to continue")
    }

    // MARK: Steps

    private func question(_ prompt: String, _ title: String, @ViewBuilder content: () -> some View, canContinue: Bool, skip: Bool = false, onContinue: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            FadeInText(prompt).padding(.top, 6)
            Text(title).font(.aegyo(22, .semibold)).foregroundStyle(.white)
            content()
            Spacer(minLength: 0)
            ContinuePill(enabled: canContinue, loading: busy, action: onContinue)
            if skip {
                Button { Haptics.tap(); advance() } label: {
                    Text("Skip for now").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
    }

    private var nameStep: some View {
        question("Hi, I'm \(Doki.name). I'll carry your love across.", "First, what's your name?", content: {
            OnboardField(text: $draft.name, placeholder: "Your name", capitalization: .words, keyboard: .default)
        }, canContinue: draft.name.trimmingCharacters(in: .whitespaces).count >= 2) {
            Task { await session.updateProfile { $0.name = draft.name.trimmingCharacters(in: .whitespaces) } }
            advance()
        }
    }

    private var partnerStep: some View {
        question("Nice to meet you, \(draft.name.isEmpty ? "you" : draft.name).", "And what do you call them?", content: {
            OnboardField(text: $draft.partnerName, placeholder: "Their name or nickname", capitalization: .words, keyboard: .default)
            Text("You can change this later. If you pair, their real name comes across.")
                .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.45))
        }, canContinue: !draft.partnerName.trimmingCharacters(in: .whitespaces).isEmpty) {
            AppGroup.defaults.set(draft.partnerName.trimmingCharacters(in: .whitespaces), forKey: Profile.partnerNameKey)
            advance()
        }
    }

    @State private var photoItem: PhotosPickerItem?
    private var photoStep: some View {
        question("A face for the Dynamic Island.", "Add a photo of you", content: {
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        Circle().fill(.white.opacity(0.08)).frame(width: 140, height: 140)
                        Circle().stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])).frame(width: 140, height: 140)
                        if let p = draft.photo {
                            Image(uiImage: p).resizable().scaledToFill().frame(width: 140, height: 140).clipShape(Circle())
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill").font(.aegyo(26)).foregroundStyle(.white.opacity(0.8))
                                Text("Choose").font(.aegyo(13, .medium)).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .buttonStyle(PressStyle())
                .onChange(of: photoItem) {
                    guard let photoItem else { return }
                    Task { if let d = try? await photoItem.loadTransferable(type: Data.self) { draft.photo = UIImage(data: d) } }
                }
                Spacer()
            }
            .padding(.top, 10)
        }, canContinue: true, skip: draft.photo == nil) {
            if let p = draft.photo { AvatarStore.save(p, for: .me) }
            advance()
        }
    }

    private var birthdayStep: some View {
        question("For your star sign and your love forecast.", "When's your birthday?", content: {
            DatePicker("", selection: Binding(get: { draft.birthday ?? Calendar.current.date(byAdding: .year, value: -24, to: .now)! },
                                              set: { draft.birthday = $0; Haptics.tick() }),
                       in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark)
                .frame(maxWidth: .infinity)
        }, canContinue: true, skip: draft.birthday == nil) {
            let b = draft.birthday ?? Calendar.current.date(byAdding: .year, value: -24, to: .now)!
            AppGroup.defaults.set(b.timeIntervalSince1970, forKey: Profile.myBirthdayKey)
            Task { await session.updateProfile { $0.birthday = b } }
            advance()
        }
    }

    private var cityStep: some View {
        question("So we can show the sky above you both.", "Where are you right now?", content: {
            OnboardField(text: $draft.city, placeholder: "City, e.g. Toronto", capitalization: .words, keyboard: .default)
            Text("Used for the distance between you and local time. Never shared beyond your partner.")
                .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.45))
        }, canContinue: !draft.city.trimmingCharacters(in: .whitespaces).isEmpty, skip: true) {
            busy = true
            Task {
                await love.setPlace(draft.city, mine: true)
                if let p = love.data.myPlace { await session.updateProfile { $0.city = p } }
                busy = false
                advance()
            }
        }
    }

    private var anniversaryStep: some View {
        question("Every day counts. Let's count them.", "When did you two get together?", content: {
            DatePicker("", selection: Binding(get: { draft.anniversary ?? Calendar.current.date(byAdding: .month, value: -6, to: .now)! },
                                              set: { draft.anniversary = $0; Haptics.tick() }),
                       in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark)
                .frame(maxWidth: .infinity)
        }, canContinue: true, skip: draft.anniversary == nil) {
            if let a = draft.anniversary { AppGroup.defaults.set(a.timeIntervalSince1970, forKey: Profile.togetherSinceKey) }
            advance()
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            FadeInText("One last thing before we begin.").padding(.top, 6)
            Text("Let \(Doki.name) reach you").font(.aegyo(22, .semibold)).foregroundStyle(.white)
            VStack(spacing: 10) {
                permissionRow("capsule.inset.filled", "Dynamic Island", "Their love shows up right at the top of your screen, with a soft chime.")
                permissionRow("bell.badge.fill", "Gentle reminders", "One nudge a day if you haven't said it yet. Never spam.")
                permissionRow("phone.fill", "Ring", "When they really need you, your phone rings like a call.")
            }
            Text("You can change all of this in Settings any time.")
                .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 0)
            ContinuePill(title: "Allow notifications", loading: busy) {
                busy = true
                Task {
                    await love.requestNotificationPermission()
                    busy = false
                    advance()
                }
            }
            Button { Haptics.tap(); advance() } label: {
                Text("Not now").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
    }

    private func permissionRow(_ icon: String, _ title: String, _ line: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.aegyo(18, .semibold)).foregroundStyle(Love.pink)
                .frame(width: 42, height: 42).background(Love.pink.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.aegyo(15, .semibold)).foregroundStyle(.white)
                Text(line).font(.aegyo(13)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(20)
    }

    private var doneStep: some View {
        VStack(spacing: 18) {
            Spacer()
            SuccessMoment(title: "You're all set, \(draft.name.isEmpty ? Profile.myName : draft.name)",
                          message: session.isPaired ? "You and \(Profile.partnerName) are connected." : "Pair with \(Profile.partnerName) whenever you're ready. Until then, every tap previews on your phone.")
            Spacer()
            ContinuePill(title: "Meet \(Doki.name)") {
                Haptics.gemPress()
                session.completeOnboarding()
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: Flow

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        Haptics.tick()
        thump += 1
        withAnimation { step = next }
    }

    private func signIn(_ method: SignInMethod) async {
        busy = true
        defer { busy = false }
        do {
            try await session.signIn(method)
            if case .apple(_, let name, _) = method, let name, !name.isEmpty { draft.name = name }
            if case .email(let name, _) = method { draft.name = name }
            withAnimation { step = draft.name.isEmpty ? .name : .partnerName }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Pieces

/// A line of copy that fades up like Opal's "I'll help protect your focus."
struct FadeInText: View {
    let text: String
    @State private var on = false
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.aegyo(15)).foregroundStyle(.white.opacity(0.55))
            .opacity(on ? 1 : 0).offset(y: on ? 0 : 6)
            .onAppear { withAnimation(.easeOut(duration: 0.6).delay(0.15)) { on = true } }
    }
}

struct OnboardField: View {
    @Binding var text: String
    var placeholder: String
    var capitalization: TextInputAutocapitalization = .never
    var keyboard: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
            .font(.aegyo(17))
            .foregroundStyle(.white)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .focused($focused)
            .padding(.horizontal, 18).frame(height: 54)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(focused ? Love.pink.opacity(0.7) : .white.opacity(0.12), lineWidth: 1))
            .animation(.smooth, value: focused)
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focused = true } }
    }
}

/// Stores profile photos on disk (you and your partner).
enum AvatarStore {
    enum Who: String { case me, partner }
    private static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func save(_ image: UIImage, for who: Who) {
        if let d = image.resized(maxSide: 600).jpegData(compressionQuality: 0.85) {
            try? d.write(to: dir.appendingPathComponent("\(who.rawValue).jpg"), options: .atomic)
            NotificationCenter.default.post(name: .avatarChanged, object: nil)
        }
    }
    static func load(_ who: Who) -> UIImage? { UIImage(contentsOfFile: dir.appendingPathComponent("\(who.rawValue).jpg").path) }
    static func delete(_ who: Who) { try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(who.rawValue).jpg")) }
}

extension Notification.Name { static let avatarChanged = Notification.Name("aegyo.avatarChanged") }

/// Circular avatar with initials fallback.
struct AvatarView: View {
    var who: AvatarStore.Who
    var name: String
    var size: CGFloat = 44
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: who == .me ? [Love.pink, Love.rose] : [Love.violet, Color(red: 0.4, green: 0.5, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(String(name.prefix(1)).uppercased()).font(.aegyo(size * 0.42, .semibold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        .onAppear { image = AvatarStore.load(who) }
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in image = AvatarStore.load(who) }
        .accessibilityLabel("\(name)'s photo")
    }
}
