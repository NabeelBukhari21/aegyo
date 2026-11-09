import SwiftUI

// MARK: - Slide to confirm (two styles from the references)
//  .flood — colour floods the whole track, then the arrow turns into a spinner and a check (crypto "Slide to approve").
//  .glow  — dark track, glowing trail ahead of a haloed thumb, label under the track (Calm "Swipe to play").

struct SlideToConfirm: View {
    enum Style { case flood, glow }

    var title: String
    var systemImage: String = "chevron.right"
    var style: Style = .flood
    var tint: LinearGradient = Love.glow
    var glowColor: Color = Love.pink
    var height: CGFloat = 60
    var onConfirm: () -> Void

    @State private var offset: CGFloat = 0
    @State private var phase = 0 // 0 idle, 1 working, 2 done
    @State private var lastQuarter = 0
    @State private var spin = false

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let maxX = geo.size.width - height
                let p = maxX > 0 ? offset / maxX : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07))
                        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))

                    if style == .flood {
                        Capsule().fill(tint)
                            .frame(width: phase > 0 ? geo.size.width : offset + height)
                            .shadow(color: glowColor.opacity(0.5 * p), radius: 14)
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.leading, height * 0.6)
                            .opacity(phase > 0 ? 0 : 1 - p * 1.6)
                    } else {
                        // glowing trail that fades out ahead of the thumb
                        LinearGradient(colors: [glowColor.opacity(0.75), glowColor.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: max(0, (geo.size.width - offset) * (phase > 0 ? 0 : 0.75)))
                            .clipShape(Capsule())
                            .offset(x: offset + height * 0.4)
                            .blur(radius: 4)
                            .opacity(0.9)
                    }

                    ZStack {
                        Circle().fill(.white)
                            .shadow(color: glowColor.opacity(style == .glow ? 0.9 : 0.4), radius: style == .glow ? 16 : 8)
                        Group {
                            switch phase {
                            case 1:
                                Circle().trim(from: 0.1, to: 0.8)
                                    .stroke(.black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                                    .frame(width: height * 0.32, height: height * 0.32)
                                    .rotationEffect(.degrees(spin ? 360 : 0))
                                    .onAppear { withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) { spin = true } }
                                    .onDisappear { spin = false }
                            case 2:
                                Image(systemName: "checkmark").font(.system(size: height * 0.3, weight: .bold)).foregroundStyle(.black)
                                    .transition(.scale.combined(with: .opacity))
                            default:
                                Image(systemName: systemImage).font(.system(size: height * 0.28, weight: .bold)).foregroundStyle(.black)
                            }
                        }
                    }
                    .frame(width: height - 8, height: height - 8)
                    .padding(4)
                    .scaleEffect(1 + 0.07 * sin(p * .pi))
                    .offset(x: offset)
                    .gesture(DragGesture()
                        .onChanged { v in
                            guard phase == 0 else { return }
                            offset = min(maxX, max(0, v.translation.width))
                            let q = Int(offset / max(1, maxX) * 5)
                            if q != lastQuarter { lastQuarter = q; Haptics.tick() }
                        }
                        .onEnded { _ in
                            lastQuarter = 0
                            guard phase == 0 else { return }
                            if offset > maxX * 0.82 { confirm(maxX) } else {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { offset = 0 }
                            }
                        })
                }
            }
            .frame(height: height)

            if style == .glow {
                Text(phase == 2 ? "Locked in" : title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.interpolate)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onConfirm() }
    }

    private func confirm(_ maxX: CGFloat) {
        Haptics.gemPress()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { offset = maxX; phase = 1 }
        onConfirm()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Haptics.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { phase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { phase = 0; offset = 0 }
        }
    }
}

// MARK: - Hold together (Runbuds "Hold to start")
// Your bubble and hers glide down the strings toward each other while the pill's outline traces your progress.

struct HoldTogetherButton: View {
    var title: String
    var me: String
    var her: String
    var duration: Double = 1.4
    var onComplete: () -> Void

    @State private var p: Double = 0
    @State private var holding = false
    @State private var done = false
    @State private var startedAt: Date?
    @State private var timer: Timer?
    @State private var burst = 0

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // the strings
                HStack(spacing: 13) {
                    ForEach(0..<9, id: \.self) { i in
                        Rectangle().fill(.white.opacity(0.16 + (i == 4 ? 0.1 : 0)))
                            .frame(width: 1)
                    }
                }
                .opacity(done ? 0 : 1 - p * 0.5)
                bubble(me, colors: [Love.pink, Love.rose])
                    .offset(x: lerp(-46, -10, ease(p)), y: lerp(-38, 0, ease(p)))
                    .opacity(done ? 0 : 1)
                bubble(her, colors: [Love.violet, Color(red: 0.4, green: 0.5, blue: 1)])
                    .offset(x: lerp(46, 10, ease(p)), y: lerp(40, 0, ease(p)))
                    .opacity(done ? 0 : 1)
                if done {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Love.glow)
                        .shadow(color: Love.pink.opacity(0.8), radius: 18)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                ForEach(0..<burst, id: \.self) { _ in Shockwave(size: 90, color: Love.pink, duration: 0.9) }
            }
            .frame(height: 150)
            .clipped()

            ZStack {
                Capsule().fill(.white.opacity(done ? 1 : 0.92))
                Text(done ? "Sent" : holding ? "Keep holding…" : title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .contentTransition(.interpolate)
                Capsule()
                    .trim(from: 0, to: p)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(-6)
                    .opacity(done ? 0 : 1)
            }
            .frame(height: 54)
            .scaleEffect(holding ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: holding)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding && !done { begin() } }
                .onEnded { _ in end() })
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(title)
            .accessibilityAction { onComplete() }
        }
    }

    private func bubble(_ name: String, colors: [Color]) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
            .shadow(color: colors[0].opacity(0.5), radius: 10)
    }

    private func begin() {
        holding = true
        startedAt = .now
        Haptics.press()
        var lastTick = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { _ in
            guard let s = startedAt else { return }
            p = min(1, Date().timeIntervalSince(s) / duration)
            let t = Int(p * 12)
            if t != lastTick { lastTick = t; Haptics.charge(p) }
            if p >= 1 { complete() }
        }
    }

    private func complete() {
        timer?.invalidate()
        startedAt = nil
        holding = false
        Haptics.gemPress()
        burst += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { done = true }
        onComplete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.smooth(duration: 0.6)) { done = false; p = 0 }
        }
    }

    private func end() {
        guard !done else { return }
        timer?.invalidate()
        startedAt = nil
        holding = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { p = 0 }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
    private func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
}

// MARK: - Merge bar (pushr): the primary action swallows the others

struct MergeBar: View {
    var secondary: String
    var primary: String
    var primaryIcon: String = "heart.fill"
    var doneTitle: String = "Sent"
    var onSecondary: () -> Void
    var onPrimary: () -> Void

    @State private var merged = false

    var body: some View {
        HStack(spacing: merged ? 0 : 12) {
            if !merged {
                Button(action: onSecondary) {
                    Text(secondary).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressStyle())
                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.2, anchor: .trailing).combined(with: .opacity)))
            }
            Button {
                guard !merged else { return }
                Haptics.gemPress()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { merged = true }
                onPrimary()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: merged ? "checkmark" : primaryIcon).contentTransition(.symbolEffect(.replace))
                    Text(merged ? doneTitle : primary).contentTransition(.interpolate)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(merged ? .white : .black)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background {
                    Capsule().fill(merged ? AnyShapeStyle(Love.glow) : AnyShapeStyle(.white))
                        .shadow(color: Love.pink.opacity(merged ? 0.6 : 0), radius: 18)
                }
            }
            .buttonStyle(PressStyle())
        }
    }
}

// MARK: - Breathe button (Tolan): a halo that swells and settles

struct BreatheButton: View {
    var label: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            Button(action: action) {
                TimelineView(.animation(minimumInterval: 1 / 40)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let b = 0.5 + 0.5 * sin(t * 2 * .pi / 4)
                    ZStack {
                        Circle().fill(.white.opacity(0.14)).scaleEffect(1.15 + 0.3 * b)
                        Circle().fill(.white.opacity(0.08)).scaleEffect(1.3 + 0.45 * b)
                        Circle().fill(.white)
                        Image(systemName: systemImage).font(.system(size: 22, weight: .semibold)).foregroundStyle(.black)
                    }
                    .frame(width: 66, height: 66)
                }
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .padding(20)
        }
    }
}

// MARK: - Ruler slider (Focus): the scale slides under a fixed centre mark

struct RulerSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 1...10
    var spacing: CGFloat = 44
    var words: [String] = ["a little", "a little", "quite a bit", "quite a bit", "a lot", "a lot", "so much", "so much", "unbearably", "more than words"]

    @State private var dragStart: Double?

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(value))").font(.system(size: 44, weight: .light)).monospacedDigit()
                        .contentTransition(.numericText(value: value))
                    Text("/10").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white)
                Text(words[max(0, min(words.count - 1, Int(value) - 1))])
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Love.pink)
                    .contentTransition(.interpolate)
            }
            .animation(.snappy, value: Int(value))

            GeometryReader { geo in
                let mid = geo.size.width / 2
                Canvas { g, size in
                    let lo = range.lowerBound, hi = range.upperBound
                    var v = lo
                    while v <= hi + 0.001 {
                        for minor in 0..<5 where v + Double(minor) * 0.2 <= hi + 0.001 {
                            let vv = v + Double(minor) * 0.2
                            let x = mid + CGFloat(vv - value) * spacing
                            guard x > -10, x < size.width + 10 else { continue }
                            let major = minor == 0
                            let h: CGFloat = major ? 22 : 11
                            let fade = 1 - min(1, abs(x - mid) / mid)
                            g.fill(Path(roundedRect: CGRect(x: x - (major ? 1 : 0.5), y: (size.height - h) / 2, width: major ? 2 : 1, height: h), cornerRadius: 1),
                                   with: .color(.white.opacity(0.15 + 0.6 * fade)))
                        }
                        v += 1
                    }
                }
                .overlay {
                    Capsule().fill(Love.pink).frame(width: 3, height: 34)
                        .shadow(color: Love.pink, radius: 6)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStart == nil { dragStart = value }
                        let raw = (dragStart ?? value) - Double(g.translation.width / spacing)
                        let clamped = min(range.upperBound, max(range.lowerBound, raw))
                        if Int(clamped.rounded()) != Int(value.rounded()) { Haptics.tick() }
                        value = clamped
                    }
                    .onEnded { _ in
                        dragStart = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { value = value.rounded() }
                    })
            }
            .frame(height: 40)
        }
        .accessibilityElement()
        .accessibilityLabel("Miss-o-meter")
        .accessibilityValue("\(Int(value)) of 10")
        .accessibilityAdjustableAction { dir in
            value = dir == .increment ? min(range.upperBound, value + 1) : max(range.lowerBound, value - 1)
        }
    }
}

// MARK: - Tick scrubber (Lumy): lit ticks, a glass thumb and a floating value pill

struct TickScrubber: View {
    @Binding var index: Int
    var count: Int
    var tint: Color = Color(red: 0.55, green: 0.65, blue: 1)
    var label: (Int) -> String

    var body: some View {
        GeometryReader { geo in
            let step = geo.size.width / CGFloat(count)
            let x = step * (CGFloat(index) + 0.5)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? tint : .white.opacity(0.18))
                            .frame(width: 2.5, height: i == index ? 0 : (i % 5 == 0 ? 22 : 16))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 44)
                .offset(y: 26)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                    .frame(width: 22, height: 44)
                    .shadow(color: tint.opacity(0.6), radius: 8)
                    .offset(x: x - 11, y: 26)
                Text(label(index))
                    .font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(tint.opacity(0.35), in: Capsule())
                    .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
                    .fixedSize()
                    .offset(x: min(max(0, x - 50), geo.size.width - 120), y: -18)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let i = max(0, min(count - 1, Int(g.location.x / step)))
                if i != index { Haptics.tick(); index = i }
            })
        }
        .frame(height: 96)
    }
}

// MARK: - Cascading suggestion pills (journaling sheet)

struct CascadePills: View {
    var options: [String]
    var onPick: (String) -> Void
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 10) {
            Label("suggest", systemImage: "sparkle")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                Button { Haptics.tap(); onPick(o) } label: {
                    Text(o).font(.system(size: 14.5, weight: .medium)).foregroundStyle(.black.opacity(0.85))
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(Color(white: 0.88), in: Capsule())
                }
                .buttonStyle(PressStyle())
                .opacity(i < shown ? 1 : 0)
                .offset(y: i < shown ? 0 : 14)
                .scaleEffect(i < shown ? 1 : 0.92)
            }
        }
        .onAppear {
            for i in 0..<options.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.12) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { shown = i + 1 }
                }
            }
        }
    }
}

/// A purple-pink haze rising from the bottom of a sheet.
struct SheetGlow: View {
    var color: Color = Love.violet
    var body: some View {
        // drawn as an overlay on a zero-size base so it never affects layout
        Color.clear
            .overlay(alignment: .bottom) {
                TimelineView(.animation(minimumInterval: 1 / 40)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Ellipse().fill(color.opacity(0.45)).frame(width: 520, height: 360).offset(x: CGFloat(sin(t * 0.4)) * 40, y: 160)
                        Ellipse().fill(Love.pink.opacity(0.25)).frame(width: 360, height: 260).offset(x: CGFloat(cos(t * 0.5)) * 60, y: 220)
                    }
                    .blur(radius: 60)
                }
            }
            .clipped()
            .allowsHitTesting(false)
    }
}

// MARK: - Marquee (Places): photos that drift by forever

struct Marquee<Item: Identifiable, Cell: View>: View {
    var items: [Item]
    var speed: Double = 28
    var spacing: CGFloat = 8
    var cellWidth: CGFloat
    @ViewBuilder var cell: (Item) -> Cell

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let total = CGFloat(items.count) * (cellWidth + spacing)
            let shift = total > 0 ? CGFloat((t * speed).truncatingRemainder(dividingBy: Double(total))) : 0
            HStack(spacing: spacing) {
                ForEach(0..<2, id: \.self) { _ in
                    ForEach(items) { cell($0) }
                }
            }
            .offset(x: -shift)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
    }
}
