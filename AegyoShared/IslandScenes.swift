import SwiftUI


/// Picks the richest scene for each kind: duet timeline, neon arc, neon heartbeat, or an LED pixel scene.
struct IslandScene: View {
    let state: LoveAttributes.ContentState
    let sender: String
    var compact = true

    var body: some View {
        switch state.kind {
        case .missYou, .thinkingOfYou: DuetTimeline(state: state, sender: sender)
        case .light: NeonArc(state: state)
        case .tapCode: NeonHeartbeat(state: state)
        case .mood: MoodIsland(state: state)
        default: LEDPanel(state: state, cols: compact ? 46 : 52, rows: 9, dot: 3.3).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Soft coloured glow along the bottom of the island, like light leaking from under glass.
struct BottomGlow: View {
    var color: Color
    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0)], center: .center, startRadius: 0, endRadius: 160))
            .frame(height: 70)
            .blur(radius: 18)
            .offset(y: 40)
            .allowsHitTesting(false)
    }
}

// MARK: - You vs her, today (inspired by the heart-rate duet)

struct DuetTimeline: View {
    let state: LoveAttributes.ContentState
    let sender: String
    private let you = Color(red: 1, green: 0.36, blue: 0.56)
    private let her = Color(red: 0.55, green: 0.55, blue: 1)

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                label(sender, state.mineToday ?? state.count, you, leading: true)
                Spacer()
                hearts
                Spacer()
                label("You", state.hersToday ?? 0, her, leading: false)
            }
            Canvas { g, size in
                let slots = 24
                let w = size.width / CGFloat(slots)
                for i in 0..<slots {
                    let r = CGRect(x: CGFloat(i) * w + 0.75, y: 0, width: w - 1.5, height: size.height)
                    g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(.white.opacity(0.05)))
                }
                let entries = state.timeline ?? [Calendar.current.component(.hour, from: state.sentAt) * 2]
                var stack: [Int: Int] = [:]
                for e in entries {
                    let hour = e / 2, fromHer = e % 2 == 1
                    let n = stack[e, default: 0]; stack[e] = n + 1
                    let h = size.height / 2 - 3
                    let y = fromHer ? size.height / 2 + 1 + CGFloat(n % 2) * 2 : CGFloat(n % 2) * 2 + 2
                    let r = CGRect(x: CGFloat(hour) * w + 0.75, y: y, width: w - 1.5, height: h - 2)
                    let c = fromHer ? her : you
                    g.fill(Path(roundedRect: r.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 3), with: .color(c.opacity(0.25)))
                    g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(c))
                }
                let nowX = CGFloat(Calendar.current.component(.hour, from: .now)) * w + w / 2
                g.fill(Path(CGRect(x: nowX - 0.5, y: 0, width: 1, height: size.height)), with: .color(.white.opacity(0.5)))
            }
            .frame(height: 34)
        }
    }

    private var hearts: some View {
        HStack(spacing: -4) {
            ForEach(0..<min(max(state.count, 1), 3), id: \.self) { _ in
                Image(systemName: "heart.fill").font(.system(size: 13)).foregroundStyle(you)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.white.opacity(0.1), in: Capsule())
    }

    private func label(_ who: String, _ n: Int, _ c: Color, leading: Bool) -> some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 0) {
            HStack(spacing: 3) {
                if leading { Image(systemName: "heart.fill").font(.system(size: 8)) }
                Text(who).font(.system(size: 11, weight: .semibold))
                if !leading { Image(systemName: "heart.fill").font(.system(size: 8)) }
            }
            .foregroundStyle(c)
            Text("\(n) today").font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
        }
    }
}

// MARK: - Same Sky as a neon line (inspired by the glowing chart)

struct NeonArc: View {
    let state: LoveAttributes.ContentState
    private let neon = Color(red: 1, green: 0.84, blue: 0.6)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { g, size in
                let a = CGPoint(x: 8, y: size.height - 8), b = CGPoint(x: size.width - 8, y: size.height - 8)
                let c = CGPoint(x: size.width / 2, y: -size.height * 0.55)
                var arc = Path(); arc.move(to: a); arc.addQuadCurve(to: b, control: c)
                var glow = g
                glow.addFilter(.blur(radius: 5))
                glow.stroke(arc, with: .color(neon.opacity(0.8)), lineWidth: 5)
                g.stroke(arc, with: .color(neon), lineWidth: 2)
                let u = 0.62, v = 1 - u
                let sp = CGPoint(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x, y: v * v * a.y + 2 * v * u * c.y + u * u * b.y)
                g.stroke(Path { $0.move(to: sp); $0.addLine(to: CGPoint(x: sp.x, y: size.height)) }, with: .color(neon.opacity(0.35)), lineWidth: 1)
                glow.fill(Path(ellipseIn: CGRect(x: sp.x - 9, y: sp.y - 9, width: 18, height: 18)), with: .color(neon))
                g.fill(Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)), with: .color(.white))
                for (p, col) in [(a, neon), (b, Color(red: 1, green: 0.62, blue: 0.74))] {
                    glow.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(col))
                    g.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(col))
                }
            }
            .frame(height: 46)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text((state.distanceKm ?? 0).formatted()).font(.system(size: 22, weight: .semibold)).monospacedDigit()
                Text("km").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            .foregroundStyle(.white)
            .offset(x: 2, y: 16)
            .opacity(state.distanceKm == nil ? 0 : 1)
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Heartbeat as a neon ECG

struct NeonHeartbeat: View {
    let state: LoveAttributes.ContentState
    private let neon = Color(red: 1, green: 0.4, blue: 0.6)

    var body: some View {
        Canvas { g, size in
            let beats = (state.detail ?? "").split(separator: ",").compactMap { Double($0) }.map { CGFloat($0 / 5000) }
            let mid = size.height * 0.6
            var p = Path()
            p.move(to: CGPoint(x: 0, y: mid))
            for b in beats.sorted() {
                let x = 6 + b * (size.width - 24)
                p.addLine(to: CGPoint(x: x - 6, y: mid))
                p.addLine(to: CGPoint(x: x - 3, y: mid + 4))
                p.addLine(to: CGPoint(x: x, y: 4))
                p.addLine(to: CGPoint(x: x + 4, y: size.height - 4))
                p.addLine(to: CGPoint(x: x + 8, y: mid))
            }
            p.addLine(to: CGPoint(x: size.width, y: mid))
            var glow = g
            glow.addFilter(.blur(radius: 4))
            glow.stroke(p, with: .color(neon.opacity(0.9)), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
            g.stroke(p, with: .color(neon), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            if let last = beats.max() {
                let x = 6 + last * (size.width - 24)
                glow.fill(Path(ellipseIn: CGRect(x: x - 7, y: -3, width: 14, height: 14)), with: .color(neon))
                g.fill(Path(ellipseIn: CGRect(x: x - 4, y: 0, width: 8, height: 8)), with: .color(.white))
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Mood: the jelly character itself

struct MoodIsland: View {
    let state: LoveAttributes.ContentState
    var body: some View {
        let mood = Mood(rawValue: (state.detail ?? "").lowercased()) ?? .loving
        HStack(spacing: 14) {
            MoodCharacter(mood: mood, size: 58, idle: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("FEELING").font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(.white.opacity(0.5))
                Text(mood.name).font(.system(size: 26, weight: .bold)).foregroundStyle(moodColor(mood.rawValue))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
    }
}
