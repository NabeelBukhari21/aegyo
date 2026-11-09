import SwiftUI

// MARK: - 3. Heartbeat (tap code)

/// Tap a rhythm on Doki; she feels exactly that rhythm as haptics.
struct HeartbeatView: View {
    var incomingCode: String? = nil
    @EnvironmentObject private var love: LoveService
    @State private var taps: [Double] = []
    @State private var startedAt: Date?
    @State private var pulse = 0
    @State private var playing = false
    @State private var sent = false

    private let window = 5.0

    var body: some View {
        FeatureSheet(title: "Heartbeat", subtitle: incomingCode == nil
                     ? "Tap a rhythm on \(Doki.name). She feels it, beat for beat."
                     : "\(Profile.myName) sent you this rhythm. Hold your phone.") {
            ZStack {
                ForEach(0..<pulse, id: \.self) { _ in Shockwave(size: 160, color: Love.pink) }
                Heart3DView(tint: love.tier.heartTint, thump: pulse, interactive: false)
                    .frame(width: 280, height: 260)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity).frame(height: 260)
            .contentShape(Rectangle())
            .onTapGesture { tap() }

            // the rhythm, drawn as dots on a 5-second line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 2)
                    ForEach(Array(taps.enumerated()), id: \.offset) { _, t in
                        Circle().fill(Opal.mint).frame(width: 9, height: 9)
                            .shadow(color: Opal.mint, radius: 4)
                            .offset(x: geo.size.width * t / window - 4.5)
                            .transition(.scale)
                    }
                    if let startedAt {
                        TimelineView(.animation) { ctx in
                            let p = min(1, ctx.date.timeIntervalSince(startedAt) / window)
                            Capsule().fill(.white.opacity(0.5)).frame(width: 2, height: 14)
                                .offset(x: geo.size.width * p)
                        }
                    }
                }
            }
            .frame(height: 20)

            HStack(alignment: .bottom) {
                Button { reset() } label: {
                    Text("Clear").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 90, height: 44).background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(PressStyle())
                Spacer()
                BreatheButton(label: "Feel it", systemImage: "waveform.path.ecg") { play(taps) }
                    .disabled(taps.isEmpty)
                    .opacity(taps.isEmpty ? 0.4 : 1)
                Spacer()
                Color.clear.frame(width: 90, height: 44)
            }

            if incomingCode == nil {
                Button {
                    Haptics.gemPress()
                    love.playSentChime()
                    let code = taps.map { String(Int($0 * 1000)) }.joined(separator: ",")
                    Task { await love.send(.tapCode, detail: code) }
                    withAnimation(.smooth) { sent = true }
                } label: {
                    WhitePill(title: sent ? "Sent" : "Send this heartbeat", systemImage: sent ? "checkmark" : "waveform.path.ecg", height: 52)
                        .frame(maxWidth: .infinity).background(.white, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .disabled(taps.isEmpty)
                .opacity(taps.isEmpty ? 0.4 : 1)
            }
        }
        .onAppear {
            if let code = incomingCode {
                taps = code.split(separator: ",").compactMap { Double($0).map { $0 / 1000 } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { play(taps) }
            }
        }
    }

    private func tap() {
        let now = Date()
        if startedAt == nil || now.timeIntervalSince(startedAt!) > window { startedAt = now; taps = [] }
        let t = now.timeIntervalSince(startedAt!)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { taps.append(t) }
        pulse += 1
        Haptics.tap()
        sent = false
    }

    private func play(_ times: [Double]) {
        playing = true
        for t in times {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                Haptics.heartbeat()
                pulse += 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (times.last ?? 0) + 0.5) { playing = false }
    }

    private func reset() {
        withAnimation(.snappy) { taps = []; startedAt = nil; sent = false }
    }
}

// MARK: - 8. Love Language quiz

struct LoveLanguageView: View {
    @EnvironmentObject private var love: LoveService
    @State private var index = 0
    @State private var tally: [String: Int] = [:]
    @State private var result: String?

    static let languages: [String: (symbol: String, line: String)] = [
        "Words": ("text.bubble", "You feel loved when it's said out loud. Long texts, little notes, “I'm proud of you”."),
        "Touch": ("hand.raised", "Hugs, hand-holding, leaning on each other. Distance is hardest for you."),
        "Time": ("hourglass", "Undivided attention is your love. Phones down, eyes up."),
        "Gifts": ("gift", "It's never the price. It's proof they were thinking of you."),
        "Acts": ("hands.and.sparkles", "Love is what someone does. Coffee made, problem solved, done before you asked."),
    ]

    private let questions: [(String, (String, String), (String, String))] = [
        ("After a long day, you'd rather…", ("Hear “I'm proud of you”", "Words"), ("Get a long hug", "Touch")),
        ("The best date is…", ("A whole day, no phones", "Time"), ("A surprise they planned", "Acts")),
        ("You'd keep forever…", ("A handwritten letter", "Words"), ("A small gift they picked", "Gifts")),
        ("When you're sick, they should…", ("Bring soup and do the dishes", "Acts"), ("Lie next to you all day", "Touch")),
        ("Long distance is hardest because…", ("You can't hold them", "Touch"), ("You can't just hang out", "Time")),
        ("The cutest thing they could do…", ("Remember something tiny you said", "Gifts"), ("Text you good morning, every day", "Words")),
    ]

    var body: some View {
        FeatureSheet(title: "Love Language", subtitle: "Six quick questions. Then send her the quiz.") {
            if let result {
                resultView(result)
            } else {
                let q = questions[index]
                ProgressBar(value: Double(index) / Double(questions.count))
                Text(q.0).font(.system(size: 26, weight: .semibold)).tracking(-0.6).foregroundStyle(.white)
                    .id(index).transition(.push(from: .trailing))
                VStack(spacing: 10) {
                    option(q.1)
                    option(q.2)
                }
                .id("o\(index)").transition(.push(from: .trailing))
            }
        }
    }

    private func option(_ o: (String, String)) -> some View {
        Button {
            Haptics.tap()
            tally[o.1, default: 0] += 1
            withAnimation(.smooth(duration: 0.45)) {
                if index + 1 < questions.count { index += 1 } else {
                    let r = tally.max { $0.value < $1.value }?.key ?? "Time"
                    result = r
                    love.setLoveLanguage(r)
                }
            }
        } label: {
            Text(o.0).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).frame(height: 64)
                .glass(20)
        }
        .buttonStyle(PressStyle())
    }

    private func resultView(_ r: String) -> some View {
        VStack(spacing: 22) {
            LoveLanguageCard(language: r).scaleEffect(0.86).frame(height: 560)
            ShareCardButton(title: "Share my result", name: "My love language") { LoveLanguageCard(language: r) }
            Button { withAnimation { result = nil; index = 0; tally = [:] } } label: {
                Text("Retake").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

struct LoveLanguageCard: View {
    let language: String
    var body: some View {
        let info = LoveLanguageView.languages[language] ?? ("heart", "")
        StoryCanvas {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                Spacer()
                Image(systemName: info.symbol).font(.system(size: 64, weight: .light)).foregroundStyle(Opal.mint)
                Spacer().frame(height: 26)
                Text("MY LOVE LANGUAGE IS").font(.system(size: 11, weight: .medium)).tracking(1.2).foregroundStyle(.white.opacity(0.55))
                Text(language == "Acts" ? "Acts of service" : language == "Time" ? "Quality time" : language == "Touch" ? "Physical touch" : language == "Gifts" ? "Thoughtful gifts" : "Words of affirmation")
                    .font(.system(size: 40, weight: .semibold)).tracking(-1.4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 14)
                Text(info.line).font(.system(size: 16)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("What's yours? · aegyo.app").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - 9. Milestones

struct MilestonesView: View {
    @EnvironmentObject private var love: LoveService
    @State private var confetti = false

    static let marks = [7, 30, 50, 100, 150, 200, 250, 300, 365, 400, 500, 600, 700, 730, 800, 900, 1000, 1095, 1500, 2000, 2500, 3000, 3650]

    private var daysTogether: Int? {
        Profile.togetherSince.map { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: .now)).day ?? 0 }
    }

    var body: some View {
        FeatureSheet(title: "Milestones", subtitle: "Every big number you two reach, celebrated.") {
            if let days = daysTogether, let start = Profile.togetherSince {
                let next = Self.marks.first { $0 > days } ?? (days + 100)
                let nextDate = Calendar.current.date(byAdding: .day, value: next, to: start)!
                ZStack {
                    if confetti { ConfettiBurst() }
                    MilestoneCard(days: days, label: Self.marks.contains(days) ? "Today is day \(days)" : "Days together")
                        .scaleEffect(0.86).frame(height: 560)
                }
                .onAppear { if Self.marks.contains(days) { confetti = true; Haptics.heartbeat(beats: 2) } }
                ShareCardButton(title: "Share our number", name: "Days together") {
                    MilestoneCard(days: days, label: Self.marks.contains(days) ? "Today is day \(days)" : "Days together")
                }
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            CapsLabel(text: "Next milestone")
                            Text("Day \(next)").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                            Text(nextDate.formatted(.dateTime.weekday(.wide).month().day().year()))
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text("in \(next - days)d").font(.system(size: 20, weight: .light)).foregroundStyle(Opal.mint)
                    }
                }
                ForEach(Self.marks.filter { $0 <= days }.reversed(), id: \.self) { m in
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Opal.mint)
                        Text("Day \(m)").foregroundStyle(.white)
                        Spacer()
                        Text(Calendar.current.date(byAdding: .day, value: m, to: start)!.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 4)
                }
            } else {
                Text("Set the day you got together in Settings to unlock milestones.")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

struct MilestoneCard: View {
    let days: Int
    let label: String
    var body: some View {
        StoryCanvas {
            VStack(spacing: 0) {
                Wordmark().frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                StaticGem(width: 90)
                Spacer().frame(height: 30)
                Text("\(days)").font(.system(size: 110, weight: .ultraLight)).tracking(-6).monospacedDigit()
                Text(label.uppercased()).font(.system(size: 12, weight: .medium)).tracking(1.4).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(Profile.myName) & \(Profile.partnerName.capitalized(with: nil))").font(.system(size: 15, weight: .medium))
                Text("aegyo.app").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).padding(.top, 4)
            }
        }
    }
}

/// Opal-coloured confetti that drifts down once.
struct ConfettiBurst: View {
    @State private var start = Date()
    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSince(start)
                guard t < 4 else { return }
                for i in 0..<70 {
                    var seed = UInt64(i) &* 2654435761
                    func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1; return Double(seed >> 40) / Double(1 << 24) }
                    let x = rnd() * size.width + sin(t * 2 + rnd() * 6) * 20
                    let y = -20 + (t * (90 + rnd() * 120)) + rnd() * 60
                    let col = Opal.spectrum[i % Opal.spectrum.count]
                    var ctxCopy = g
                    ctxCopy.translateBy(x: x, y: y)
                    ctxCopy.rotate(by: .radians(t * 3 + rnd() * 6))
                    ctxCopy.opacity = max(0, 1 - t / 4)
                    ctxCopy.fill(Path(CGRect(x: -4, y: -2, width: 8, height: 4)), with: .color(col))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 2. Gem collection

struct GemCollectionView: View {
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var preview: GemTier?
    @State private var thump = 0

    var body: some View {
        let total = love.totalSent + love.totalReceived
        let current = love.tier
        let shown = preview ?? current
        let unlocked = total >= shown.threshold
        let days = Profile.togetherSince.map { Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 0 } ?? 0
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color(uiColor: shown.heartTint).opacity(0.25), .clear], center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 300)
                .ignoresSafeArea()
                .animation(.smooth(duration: 0.6), value: shown)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Text("\(Doki.name)'s forms").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                                .frame(width: 30, height: 30).background(.white, in: Circle())
                        }
                    }
                    .padding(.top, 18)

                    Heart3DView(tint: shown.heartTint, thump: thump)
                        .frame(height: 260)
                        .saturation(unlocked ? 1 : 0.15)
                        .opacity(unlocked ? 1 : 0.55)
                        .overlay { if !unlocked { Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.85)) } }

                    VStack(spacing: 4) {
                        Text(shown.name).font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                            .contentTransition(.interpolate)
                        Text(unlocked ? shown.blurb : "Unlocks at \(shown.threshold) moments").font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                    }
                    .animation(.snappy, value: shown)

                    // swatches
                    HStack(spacing: 12) {
                        ForEach(GemTier.allCases) { tier in
                            let open = total >= tier.threshold
                            Button {
                                Haptics.tick()
                                thump += 1
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { preview = tier }
                            } label: {
                                ZStack {
                                    Circle().fill(AngularGradient(colors: tier.palette, center: .center))
                                    Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14))
                                    if !open { Circle().fill(.black.opacity(0.5)); Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.white) }
                                }
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(.white, lineWidth: tier == shown ? 2 : 0).padding(-4))
                                .scaleEffect(tier == shown ? 1.18 : 1)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    .padding(.vertical, 6)

                    HStack(spacing: 10) {
                        tallBox("\(total)", "Moments shared")
                        tallBox("\(days)", "Days together")
                    }

                    if let next = current.next {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { CapsLabel(text: "Next form: \(next.name)"); Spacer(); CapsLabel(text: "\(total) / \(next.threshold)") }
                            ProgressBar(value: Double(total - current.threshold) / Double(next.threshold - current.threshold))
                        }
                    }

                    ShareCardButton(title: "Share \(Doki.name)", name: "Our \(Doki.name)") {
                        StoryCanvas {
                            VStack(spacing: 18) {
                                Wordmark().frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                StaticGem(width: 170, palette: current.palette)
                                Text("Our \(Doki.name) became").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6)).padding(.top, 20)
                                Text(current.name).font(.system(size: 44, weight: .semibold)).tracking(-1.5)
                                Text("\(total) moments of love").font(.system(size: 15)).foregroundStyle(Opal.mint)
                                Spacer()
                                Text("aegyo.app").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    /// Tall condensed numbers in an outlined box (Any Distance).
    private func tallBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 54, weight: .heavy, design: .default).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
            Text(label.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }
}
