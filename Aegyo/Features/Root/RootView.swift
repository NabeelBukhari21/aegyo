import PhotosUI
import SwiftUI

/// The app shell: four tabs, the Liquid Glass bar, sheets, deep links, screen shake and touch feedback.
struct RootView: View {
    @EnvironmentObject private var love: LoveService
    @EnvironmentObject private var appState: AppState

    @State private var tab: AppTab = .home
    @State private var sheet: HomeSheet?
    @State private var toast: String?
    @State private var shake = 0
    @State private var flash = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var pickingPhoto = false
    @State private var composing: UIImage?
    @State private var viewingPhoto: SentPhoto?
    @State private var actionsOpen = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ZStack {
                switch tab {
                case .home: HomeTab(open: { sheet = $0 }, onThump: thumpScreen, toast: show).transition(tabTransition)
                case .sky: SkyTab().transition(tabTransition)
                case .moments: MomentsTab(open: { sheet = $0 }).transition(tabTransition)
                case .us: UsTab(open: { sheet = $0 }).transition(tabTransition)
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.86), value: tab)

            // fade behind the bar
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .frame(height: 140).ignoresSafeArea().allowsHitTesting(false)

            if actionsOpen {
                ActionStack(isOpen: $actionsOpen, open: { sheet = $0 }, openPhoto: { pickingPhoto = true }, ring: {
                    love.ring(); show(love.isPaired ? "Ringing…" : "Lock your phone · it rings in 4 seconds")
                }, toast: show)
                .zIndex(2)
            }

            LiquidTabBar(tab: $tab, plusOpen: actionsOpen) { withAnimation(.spring) { actionsOpen.toggle() } }
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
                .zIndex(3)

            // pink flash on a thump
            RadialGradient(colors: [Love.pink.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 500)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .keyframeAnimator(initialValue: 0.0, trigger: flash) { v, o in v.opacity(o) } keyframes: { _ in
                    CubicKeyframe(1, duration: 0.08); CubicKeyframe(0, duration: 0.5)
                }

            if let toast {
                VStack {
                    Text(toast).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glass(20)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .scale(scale: 0.85)).combined(with: .opacity),
                                                removal: .opacity.combined(with: .scale(scale: 0.95))))
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .screenShake(trigger: shake)
        .touchFeedback()
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { s in sheetView(s) }
        .photosPicker(isPresented: $pickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let photoItem else { return }
            Task {
                if let data = try? await photoItem.loadTransferable(type: Data.self), let img = UIImage(data: data) { composing = img }
                self.photoItem = nil
            }
        }
        .sheet(item: Binding(get: { composing.map(IdentifiedImage.init) }, set: { composing = $0?.image })) { w in
            PhotoComposer(image: w.image).aegyoSheet([.large])
        }
        .fullScreenCover(item: $viewingPhoto) { PhotoViewer(photo: $0) }
        .fullScreenCover(item: Binding(get: { appState.answeredRingFrom.map(RingNote.init) },
                                       set: { appState.answeredRingFrom = $0?.name })) { RingView(name: $0.name) }
        .alert("Something went wrong", isPresented: Binding(get: { love.lastError != nil }, set: { if !$0 { love.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(love.lastError ?? "") }
        .onOpenURL(perform: handle)
        .task { await startup() }
        #if DEBUG
        .overlay { if ProcessInfo.processInfo.arguments.contains("-islandGallery") { IslandGallery() } }
        #endif
    }

    private var tabTransition: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 10)),
                    removal: .opacity.combined(with: .scale(scale: 1.02)))
    }

    private func thumpScreen() {
        shake += 1
        flash += 1
    }

    private func show(_ text: String) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { toast = text }
        let current = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if toast == current { withAnimation(.easeOut(duration: 0.3)) { toast = nil } }
        }
    }

    @ViewBuilder private func sheetView(_ s: HomeSheet) -> some View {
        switch s {
        case .quick:
            EmptyView()
        case .meet:
            MeetDatePicker(date: Binding(get: { AppGroup.defaults.double(forKey: Profile.meetDateKey) },
                                         set: { AppGroup.defaults.set($0, forKey: Profile.meetDateKey) }))
                .aegyoSheet([.large])
        case .settings: SettingsView()
        case .question: DailyQuestionView()
        case .letters: LettersView()
        case .heartbeat(let code): HeartbeatView(incomingCode: code)
        case .wrapped: WrappedView()
        case .receipt: ReceiptView()
        case .language: LoveLanguageView()
        case .milestones: MilestonesView()
        case .gem: GemCollectionView()
        case .mood: MoodPicker().aegyoSheet([.height(560)])
        }
    }

    /// aegyo://photo/<id> · aegyo://mood · aegyo://heartbeat?code= · aegyo://letters
    private func handle(_ url: URL) {
        guard url.scheme == "aegyo" else { return }
        switch url.host {
        case "photo": viewingPhoto = love.data.photos.first { $0.id == url.lastPathComponent }
        case "mood": sheet = .mood
        case "letters": sheet = .letters
        case "heartbeat":
            sheet = .heartbeat(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code" }?.value)
        default: tab = .home
        }
    }

    private func startup() async {
        #if DEBUG
        // Launch flags for automated screenshots.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedDemo") { love.seedDemo() }
        if args.contains("-demoRing") { appState.answeredRingFrom = Profile.myName }
        if args.contains("-demoLove") { await love.send(.missYou) }
        if args.contains("-tabSky") { tab = .sky }
        if args.contains("-tabMoments") { tab = .moments }
        if args.contains("-tabUs") { tab = .us }
        if args.contains("-openActions") { try? await Task.sleep(for: .milliseconds(600)); actionsOpen = true }
        let sheets: [String: HomeSheet] = ["-openWrapped": .wrapped, "-openReceipt": .receipt, "-openGem": .gem, "-openLetters": .letters, 
                                           "-openQuestion": .question, "-openMilestones": .milestones, "-openLanguage": .language, "-openMood": .mood, "-openMeet": .meet]
        for (flag, s) in sheets where args.contains(flag) { try? await Task.sleep(for: .milliseconds(600)); sheet = s }
        if args.contains("-noPrompt") { return }
        #endif
        await love.requestNotificationPermission()
        Reminders.shared.refresh(lovedToday: love.sentToday > 0)
    }
}

private struct RingNote: Identifiable {
    let name: String
    var id: String { name }
}

// MARK: - Moments tab

struct MomentsTab: View {
    var open: (HomeSheet) -> Void
    @State private var appeared = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Moments").font(.system(size: 32, weight: .semibold)).tracking(-1).foregroundStyle(.white)
                    .padding(.top, 8).stagger(appeared, 0)
                MoodCards().stagger(appeared, 1)
                PhotoCard().stagger(appeared, 2)
                CountdownCard().stagger(appeared, 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(OpalBackground(focus: UnitPoint(x: 0.3, y: 0.2)))
        .onAppear { appeared = true }
    }
}

// MARK: - Us tab

struct UsTab: View {
    @EnvironmentObject private var love: LoveService
    var open: (HomeSheet) -> Void
    @State private var appeared = false

    private struct Item: Identifiable { let id: String, sheet: HomeSheet, icon: String, title: String, line: String, tint: Color }

    private var items: [Item] {
        [
            Item(id: "w", sheet: .wrapped, icon: "sparkles.rectangle.stack.fill", title: "Love Wrapped", line: "Your story, ready to post", tint: Love.pink),
            Item(id: "g", sheet: .gem, icon: "heart.fill", title: "\(Doki.name)'s forms", line: love.tier.name, tint: Color(uiColor: love.tier.heartTint)),
            Item(id: "q", sheet: .question, icon: "questionmark.bubble.fill", title: "Daily Question", line: love.data.answers[DayKey.of(.now)] == nil ? "Today's is waiting" : "Answered", tint: Love.violet),
            Item(id: "l", sheet: .letters, icon: "envelope.fill", title: "Open When…", line: "\(love.data.letters.count) sealed", tint: Love.peach),
            Item(id: "h", sheet: .heartbeat(nil), icon: "waveform.path.ecg", title: "Heartbeat", line: "Tap a rhythm", tint: Color(red: 1, green: 0.4, blue: 0.45)),
            Item(id: "r", sheet: .receipt, icon: "airplane.departure", title: "Love Pass", line: "A ticket to her", tint: Color(red: 1, green: 0.85, blue: 0.4)),
            Item(id: "m", sheet: .milestones, icon: "flag.checkered", title: "Milestones", line: "Big numbers", tint: Opal.mint),
            Item(id: "ll", sheet: .language, icon: "heart.text.square.fill", title: "Love Language", line: love.data.loveLanguage ?? "Take the quiz", tint: Color(red: 1, green: 0.8, blue: 0.4)),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Us").font(.system(size: 32, weight: .semibold)).tracking(-1).foregroundStyle(.white)
                    Spacer()
                    Button { open(.settings) } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 17)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40).background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.top, 8)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, it in
                        Button { open(it.sheet) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Image(systemName: it.icon).font(.system(size: 22)).foregroundStyle(it.tint)
                                    .frame(width: 48, height: 48).background(it.tint.opacity(0.14), in: Circle())
                                    .symbolEffect(.bounce, value: appeared)
                                Spacer()
                                Text(it.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                Text(it.line).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).padding(.top, 3)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
                            .glass(26)
                        }
                        .buttonStyle(PressStyle())
                        .stagger(appeared, i + 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(OpalBackground(focus: UnitPoint(x: 0.7, y: 0.15)))
        .onAppear { appeared = true }
    }
}
