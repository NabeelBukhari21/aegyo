import SwiftUI

/// Sheets the app can open.
enum HomeSheet: Identifiable, Hashable {
    case settings, question, letters, heartbeat(String?), wrapped, receipt, language, milestones, gem, mood, quick, meet, pair, paywall, timeline, progress, achievements, calendar, saved, voice
    var id: String {
        switch self {
        case .heartbeat(let c): "heartbeat\(c ?? "")"
        default: String(describing: self)
        }
    }
}

/// The Doki tab. Her first: who you two are and where she is right now, then Doki, then today as a duet,
/// the quickest ways to reach her, the last thing she sent, and the ring.
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
    private var partnerCap: String { partner.capitalized(with: nil) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header.stagger(appeared, 0)

                coupleStrip.padding(.top, 14).stagger(appeared, 1)

                ZStack {
                    ForEach(shocks, id: \.self) { _ in Shockwave(size: 200, color: Love.pink, duration: 1.0) }
                    ForEach(floaters, id: \.self) { _ in FloatingHearts() }
                    VStack(spacing: 0) {
                        Heart3DView(tint: love.tier.heartTint, thump: love.sendPulse, reveal: true)
                            .frame(width: 320, height: 290)
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
                .padding(.top, -6)
                .stagger(appeared, 2)

                Text("Tap \(Doki.name) to tell \(partner) you miss her")
                    .font(.aegyo(13)).foregroundStyle(.white.opacity(0.45))
                    .stagger(appeared, 2)

                duetCard.padding(.top, 18).stagger(appeared, 3)

                quickRow.padding(.top, 14).stagger(appeared, 4)

                PairingBanner { open(.pair) }.padding(.top, 14).stagger(appeared, 4)

                fromHerCard.padding(.top, 14).stagger(appeared, 5)

                SlideToConfirm(title: "Slide to ring \(partnerCap)", systemImage: "phone.fill") {
                    love.ring()
                    toast(love.isPaired ? "Ringing \(partner)…" : "Lock your phone · it rings in 4 seconds")
                }
                .padding(.top, 14)
                .stagger(appeared, 5)

                todayCard.padding(.top, 14).stagger(appeared, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(.named("home"))
        .background {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.3))
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
        HStack(spacing: 10) {
            Text("aegyo").font(.aegyo(27, .semibold)).tracking(-1.1).foregroundStyle(.white).lineLimit(1).fixedSize()
            Spacer()
            Button { open(.gem) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").font(.aegyo(11, .bold)).foregroundStyle(Love.pink)
                        .symbolEffect(.breathe, options: .repeating)
                    Text("\(love.streakDays)").foregroundStyle(.white).contentTransition(.numericText())
                    Text(love.streakDays == 1 ? "day" : "days").foregroundStyle(.white.opacity(0.7))
                }
                .font(.aegyo(12.5, .semibold))
                .padding(.horizontal, 11).frame(height: 32)
                .background(.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("\(love.streakDays) day streak")
            Button { open(.settings) } label: { AvatarView(who: .me, name: Profile.myName, size: 34) }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Settings")
        }
        .padding(.top, 6)
    }

    // MARK: Couple strip

    /// Who you two are, how long it's been, and what time it is for her right now.
    private var coupleStrip: some View {
        Button { open(togetherSince == 0 ? .settings : .milestones) } label: {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                HStack(spacing: 12) {
                    HStack(spacing: -10) {
                        AvatarView(who: .me, name: Profile.myName, size: 38)
                        AvatarView(who: .partner, name: partner, size: 38)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Profile.myName.capitalized(with: nil)) & \(partnerCap)").font(.aegyo(15, .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(coupleLine).font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let m = love.data.herMood, Date().timeIntervalSince(m.at) < 86400 {
                        MoodCharacter(mood: m.mood, size: 36)
                            .accessibilityLabel("\(partner) is feeling \(m.mood.name.lowercased())")
                    } else {
                        Image(systemName: "chevron.right").font(.aegyo(12, .semibold)).foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .glass(22)
            }
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }

    private var coupleLine: String {
        var parts: [String] = []
        if togetherSince > 0 { parts.append(love.data.herPlace == nil ? "\(togetherText) together" : togetherText) }
        if let place = love.data.herPlace {
            let f = DateFormatter(); f.timeZone = place.timeZone; f.dateFormat = "h:mm a"
            parts.append("\(f.string(from: .now)) for \(partnerCap)")
        } else if togetherSince == 0 {
            parts.append("Set your anniversary")
        }
        return parts.joined(separator: " · ")
    }

    private var togetherText: String {
        guard togetherSince > 0 else { return "" }
        let comps = Calendar.current.dateComponents([.year, .day], from: Date(timeIntervalSince1970: togetherSince), to: .now)
        let y = comps.year ?? 0, d = comps.day ?? 0
        return y > 0 ? "\(y)y \(d)d" : "\(d)d"
    }

    // MARK: Today as a duet

    private var duetCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let today = love.todayEvents().filter { $0.kind.countsAsLove }
            let mine = today.filter(\.outgoing).count, hers = today.count - mine
            VStack(spacing: 12) {
                HStack {
                    CapsLabel(text: "Today")
                    Spacer()
                    Button { open(.timeline) } label: {
                        HStack(spacing: 4) {
                            Text("Timeline").font(.aegyo(12, .semibold))
                            Image(systemName: "chevron.right").font(.aegyo(10, .bold))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(PressStyle())
                }
                HStack(alignment: .firstTextBaseline) {
                    duetCount("You", mine, Love.pink, numeric: Double(mine))
                    Spacer()
                    Text(agoText(love.lastSentAt) == "—" ? "Nothing yet" : "Last touch \(agoText(love.lastSentAt))")
                        .font(.aegyo(11.5)).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    duetCount(partnerCap, hers, Love.violet, numeric: Double(hers), trailing: true)
                }
                DuetStrip(events: today).frame(height: 30)
                HStack {
                    Text("12 AM").frame(maxWidth: .infinity, alignment: .leading)
                    Text("noon")
                    Text("now").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.aegyo(9.5, .medium)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .glass(24)
        }
    }

    private func duetCount(_ who: String, _ n: Int, _ c: Color, numeric: Double, trailing: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if trailing { Text(who).font(.aegyo(12.5, .medium)).foregroundStyle(.white.opacity(0.6)) }
            Text("\(n)").font(.aegyo(26, .bold)).monospacedDigit().foregroundStyle(c)
                .contentTransition(.numericText(value: numeric))
                .animation(.snappy(duration: 0.35), value: n)
            if !trailing { Text(who).font(.aegyo(12.5, .medium)).foregroundStyle(.white.opacity(0.6)) }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Quick love

    private var quickRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                QuickChip(kind: .hug, label: "Hug") { toast("Hug sent") }
                QuickChip(kind: .thinkingOfYou, label: "Thinking of you") { toast("Sent") }
                QuickChip(kind: .goodnight, label: "Goodnight") { toast("Goodnight sent") }
                QuickChip(kind: .goodMorning, label: "Good morning") { toast("Good morning sent") }
                QuickChip(kind: .light, label: "Light") { toast("Light sent") }
                Button { Haptics.tap(); open(.mood) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "face.smiling").font(.aegyo(12, .semibold))
                        Text("Mood")
                    }
                    .font(.aegyo(13, .medium)).foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(Capsule().fill(.white.opacity(0.07)).overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .scrollClipDisabled()
    }

    // MARK: From her

    /// The last thing she sent, with a one-tap way to send the same thing back.
    private var fromHerCard: some View {
        let last = love.data.events.filter { !$0.outgoing && $0.kind.countsAsLove }.max { $0.date < $1.date }
        return Group {
            if let last {
                HStack(spacing: 12) {
                    Button { Haptics.tap(); open(.timeline) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: last.kind.symbol).font(.aegyo(17, .semibold)).foregroundStyle(Love.violet)
                                .frame(width: 44, height: 44).background(Love.violet.opacity(0.16), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(last.kind.headline(from: partnerCap, detail: last.detail)).font(.aegyo(14.5, .semibold)).foregroundStyle(.white).lineLimit(1)
                                Text(agoText(last.date) == "now" ? "Just now" : "\(agoText(last.date)) · \(last.kind.subtitle(detail: last.detail))")
                                    .font(.aegyo(12)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle(scale: 0.98))
                    if [.missYou, .hug, .thinkingOfYou, .goodMorning, .goodnight, .light].contains(last.kind) {
                        QuickChip(kind: last.kind, label: "Send back", wide: false) { toast("Sent back") }
                    } else if last.kind == .voice, let id = last.photoID {
                        VoicePlayButton(id: id, duration: Double(last.detail ?? "") ?? 0)
                    }
                }
                .padding(12)
                .glass(22)
            } else {
                HStack(spacing: 12) {
                    PresenceDot()
                    Text(love.isPaired ? "Nothing from \(partnerCap) yet. Send a hug and see what comes back." : "Pair with \(partnerCap) and everything she sends shows up here.")
                        .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glass(22)
            }
        }
    }

    // MARK: Today's question

    private var todayCard: some View {
        Button { open(.question) } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "questionmark.bubble.fill").font(.aegyo(20)).foregroundStyle(Love.pink)
                    .frame(width: 44, height: 44).background(Love.pink.opacity(0.14), in: Circle())
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel(text: "Today's question")
                    Text(DailyQuestions.today).font(.aegyo(16, .semibold)).foregroundStyle(.white)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(love.data.answers[DayKey.of(.now)] == nil ? "Tap to answer" : "Answered · waiting for \(partnerCap)")
                        .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .glass(24)
        }
        .buttonStyle(PressStyle())
    }
}

/// 24 hour slots; your sends sit on the top half in pink, hers on the bottom in violet. A thin line marks now.
struct DuetStrip: View {
    let events: [LoveEvent]
    var body: some View {
        Canvas { g, size in
            let slots = 24
            let w = size.width / CGFloat(slots)
            for i in 0..<slots {
                let r = CGRect(x: CGFloat(i) * w + 0.75, y: 0, width: w - 1.5, height: size.height)
                g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(.white.opacity(0.05)))
            }
            var stack: [Int: Int] = [:]
            for e in events {
                let hour = Calendar.current.component(.hour, from: e.date)
                let key = hour * 2 + (e.outgoing ? 0 : 1)
                let n = stack[key, default: 0]; stack[key] = n + 1
                let h = size.height / 2 - 3
                let y = e.outgoing ? CGFloat(n % 2) * 2 + 2 : size.height / 2 + 1 + CGFloat(n % 2) * 2
                let r = CGRect(x: CGFloat(hour) * w + 0.75, y: y, width: w - 1.5, height: h - 2)
                let c = e.outgoing ? Love.pink : Love.violet
                g.fill(Path(roundedRect: r.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 3), with: .color(c.opacity(0.25)))
                g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(c))
            }
            let nowX = CGFloat(Calendar.current.component(.hour, from: .now)) * w + w / 2
            g.fill(Path(CGRect(x: nowX - 0.5, y: 0, width: 1, height: size.height)), with: .color(.white.opacity(0.5)))
        }
        .accessibilityLabel("Today's sends, hour by hour")
    }
}

/// A glass chip that morphs into a check after sending.
struct QuickChip: View {
    @EnvironmentObject private var love: LoveService
    let kind: LoveKind
    let label: String
    var wide = false
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
                Image(systemName: sent ? "checkmark" : kind.symbol).font(.aegyo(12, .semibold))
                    .contentTransition(.symbolEffect(.replace))
                if !sent { Text(label).lineLimit(1).transition(.opacity.combined(with: .scale(scale: 0.8))) }
            }
            .font(.aegyo(13, .medium))
            .foregroundStyle(sent ? .black : .white.opacity(0.9))
            .padding(.horizontal, 14)
            .frame(maxWidth: wide ? .infinity : nil).frame(height: 40)
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
                    .font(.aegyo(parts[i].s))
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
