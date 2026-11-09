import SwiftUI

/// Sheets the app can open.
enum HomeSheet: Identifiable, Hashable {
    case settings, question, letters, heartbeat(String?), wrapped, receipt, language, milestones, gem, mood, quick, meet
    var id: String {
        switch self {
        case .heartbeat(let c): "heartbeat\(c ?? "")"
        default: String(describing: self)
        }
    }
}

/// The Doki tab: the beating 3D heart, today's numbers, quick love and slide-to-ring.
struct HomeTab: View {
    @EnvironmentObject private var love: LoveService
    @AppStorage(Profile.partnerNameKey, store: AppGroup.defaults) private var partnerName = ""
    @AppStorage(Profile.togetherSinceKey, store: AppGroup.defaults) private var togetherSince: Double = 0

    var open: (HomeSheet) -> Void
    var onThump: () -> Void
    var toast: (String) -> Void

    @State private var shocks: [UUID] = []
    @State private var ripple = 0
    @State private var heartCenter: CGPoint = CGPoint(x: 200, y: 260)
    @State private var appeared = false
    @State private var floaters: [UUID] = []

    private var partner: String { partnerName.isEmpty ? Profile.defaultPartnerName : partnerName }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header.stagger(appeared, 0)

                ZStack {
                    ForEach(shocks, id: \.self) { _ in Shockwave(size: 200, color: Love.pink, duration: 1.0) }
                    ForEach(floaters, id: \.self) { _ in FloatingHearts() }
                    VStack(spacing: 0) {
                        Heart3DView(tint: love.tier.heartTint, thump: love.sendPulse, reveal: true)
                            .frame(width: 320, height: 300)
                            .onGeometryChange(for: CGPoint.self) { g in
                                let f = g.frame(in: .named("home"))
                                return CGPoint(x: f.midX, y: f.midY)
                            } action: { heartCenter = $0 }
                            .onTapGesture(perform: thump)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Tell \(partner) you miss her")
                        Ellipse()
                            .fill(RadialGradient(colors: [Love.pink.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 80))
                            .frame(width: 180, height: 26)
                            .blur(radius: 6)
                    }
                }
                .stagger(appeared, 1)

                Text("Tap \(Doki.name) to tell \(partner) you miss her")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                    .stagger(appeared, 2)

                stats.padding(.top, 14).stagger(appeared, 2)

                quickRow.padding(.top, 18).stagger(appeared, 3)

                SlideToConfirm(title: "Slide to ring \(partner.capitalized(with: nil))", systemImage: "phone.fill") {
                    love.ring()
                    toast(love.isPaired ? "Ringing \(partner)…" : "Lock your phone · it rings in 4 seconds")
                }
                .padding(.top, 18)
                .stagger(appeared, 4)

                todayCard.padding(.top, 18).stagger(appeared, 5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(.named("home"))
        .background {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.26))
                .rippleEffect(at: heartCenter, trigger: ripple, amplitude: 16)
        }
        .onAppear { withAnimation(.smooth(duration: 0.9)) { appeared = true } }
    }

    private func thump() {
        Haptics.gemPress()
        love.playSentChime()
        ripple += 1
        onThump()
        let id = UUID(), f = UUID()
        shocks.append(id); floaters.append(f)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { shocks.removeAll { $0 == id } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { floaters.removeAll { $0 == f } }
        let before = love.tier
        Task {
            await love.send(.missYou)
            if love.tier != before { toast("\(Doki.name) evolved into \(love.tier.name)"); open(.gem) }
        }
        toast(love.isPaired ? "Sent to \(partner)" : "Swipe home to see it in your Dynamic Island")
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("aegyo").font(.system(size: 27, weight: .semibold)).tracking(-1.1).foregroundStyle(.white)
            Spacer()
            Button { open(.gem) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Love.pink)
                        .symbolEffect(.breathe, options: .repeating)
                    Text("\(love.streakDays)").foregroundStyle(.white).contentTransition(.numericText())
                    Text(love.streakDays == 1 ? "day" : "days").foregroundStyle(.white.opacity(0.7))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 11).frame(height: 30)
                .background(.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(PressStyle())
            Button { open(.settings) } label: {
                Image(systemName: "person.crop.circle").font(.system(size: 20)).foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.top, 6)
    }

    // MARK: Stats

    private var stats: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: 0) {
                stat("MISSED HER", value: "\(love.sentToday)", numeric: Double(love.sentToday))
                stat("LAST TOUCH", value: agoText(love.lastSentAt))
                Button { open(togetherSince == 0 ? .settings : .milestones) } label: { stat("TOGETHER", value: togetherText) }
                    .buttonStyle(PressStyle())
            }
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        }
    }

    private func stat(_ label: String, value: String, numeric: Double? = nil) -> some View {
        VStack(spacing: 5) {
            Text(label).font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 19, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
                .contentTransition(numeric != nil ? .numericText(value: numeric!) : .interpolate)
                .animation(.snappy(duration: 0.35), value: value)
        }
        .frame(maxWidth: .infinity)
    }

    private var togetherText: String {
        guard togetherSince > 0 else { return "Set" }
        let comps = Calendar.current.dateComponents([.year, .day], from: Date(timeIntervalSince1970: togetherSince), to: .now)
        let y = comps.year ?? 0, d = comps.day ?? 0
        return y > 0 ? "\(y)y \(d)d" : "\(d)d"
    }

    // MARK: Quick love

    private var quickRow: some View {
        HStack(spacing: 8) {
            QuickChip(kind: .hug, label: "Hug") { toast("Hug sent") }
            QuickChip(kind: .thinkingOfYou, label: "Thinking of you") { toast("Sent") }
            QuickChip(kind: .goodnight, label: "Goodnight") { toast("Goodnight sent") }
        }
    }

    // MARK: Today

    private var todayCard: some View {
        Button { open(.question) } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "questionmark.bubble.fill").font(.system(size: 20)).foregroundStyle(Love.pink)
                    .frame(width: 44, height: 44).background(Love.pink.opacity(0.14), in: Circle())
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel(text: "Today's question")
                    Text(DailyQuestions.today).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(love.data.answers[DayKey.of(.now)] == nil ? "Tap to answer" : "Answered · waiting for her")
                        .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .glass(24)
        }
        .buttonStyle(PressStyle())
    }
}

/// A glass chip that morphs into a check after sending.
struct QuickChip: View {
    @EnvironmentObject private var love: LoveService
    let kind: LoveKind
    let label: String
    var after: () -> Void
    @State private var sent = false

    var body: some View {
        Button {
            Haptics.tap()
            love.playSentChime()
            Task { await love.send(kind) }
            after()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { sent = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { withAnimation(.spring) { sent = false } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sent ? "checkmark" : kind.symbol).font(.system(size: 12, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                if !sent { Text(label).lineLimit(1).transition(.opacity.combined(with: .scale(scale: 0.8))) }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(sent ? .black : .white.opacity(0.9))
            .frame(maxWidth: .infinity).frame(height: 40)
            .background {
                Capsule().fill(sent ? AnyShapeStyle(Opal.mint) : AnyShapeStyle(.white.opacity(0.07)))
                    .overlay(Capsule().stroke(.white.opacity(sent ? 0 : 0.12), lineWidth: 1))
            }
        }
        .buttonStyle(PressStyle())
    }
}

/// Little hearts that float up from Doki when tapped.
struct FloatingHearts: View {
    @State private var go = false
    private let parts: [(x: CGFloat, s: CGFloat, d: Double)] = (0..<10).map { _ in (.random(in: -130...130), .random(in: 10...24), .random(in: 0...0.25)) }
    var body: some View {
        ZStack {
            ForEach(0..<parts.count, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: parts[i].s))
                    .foregroundStyle(i % 2 == 0 ? Love.pink : Color(red: 1, green: 0.7, blue: 0.8))
                    .offset(x: go ? parts[i].x : 0, y: go ? -220 : 20)
                    .scaleEffect(go ? 1 : 0.2)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.4).delay(parts[i].d), value: go)
            }
        }
        .onAppear { go = true }
        .allowsHitTesting(false)
    }
}

/// Softly blinking mint dot.
struct PresenceDot: View {
    @State private var dim = false
    var body: some View {
        Circle().fill(Opal.mint).frame(width: 7, height: 7)
            .shadow(color: Opal.mint, radius: 4)
            .opacity(dim ? 0.35 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { dim = true } }
    }
}

extension View {
    /// Entrance choreography: each block rises and fades in a beat after the previous one.
    func stagger(_ on: Bool, _ index: Int) -> some View {
        self
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 22)
            .blur(radius: on ? 0 : 8)
            .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(Double(index) * 0.07), value: on)
    }
}
