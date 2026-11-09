import SwiftUI

/// Aegyo's colours beyond the black canvas.
enum Love {
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.50)
    static let rose = Color(red: 0.96, green: 0.18, blue: 0.38)
    static let peach = Color(red: 1.0, green: 0.62, blue: 0.55)
    static let violet = Color(red: 0.62, green: 0.45, blue: 1.0)
    static let glow = LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.62), Color(red: 0.93, green: 0.22, blue: 0.52), Color(red: 0.68, green: 0.36, blue: 1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Whole-screen effects

struct ShakeValues {
    var x: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 1
}

extension View {
    /// Shakes the whole screen like the heart's thump rattled the phone.
    func screenShake(trigger: Int) -> some View {
        keyframeAnimator(initialValue: ShakeValues(), trigger: trigger) { content, v in
            content
                .offset(x: v.x)
                .rotationEffect(.degrees(v.rotation))
                .scaleEffect(v.scale)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(-9, duration: 0.05)
                CubicKeyframe(8, duration: 0.06)
                CubicKeyframe(-6, duration: 0.06)
                CubicKeyframe(4, duration: 0.07)
                CubicKeyframe(-2, duration: 0.07)
                SpringKeyframe(0, duration: 0.25, spring: .bouncy)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(-0.6, duration: 0.06)
                CubicKeyframe(0.5, duration: 0.07)
                CubicKeyframe(-0.3, duration: 0.07)
                SpringKeyframe(0, duration: 0.3)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.985, duration: 0.08)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
        }
    }

    /// A Metal water ripple that rolls out from `origin` across this view.
    func rippleEffect(at origin: CGPoint, trigger: Int, amplitude: Double = 14) -> some View {
        modifier(RippleModifier(origin: origin, trigger: trigger, amplitude: amplitude))
    }
}

private struct RippleModifier: ViewModifier {
    var origin: CGPoint
    var trigger: Int
    var amplitude: Double

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
            view.visualEffect { v, _ in
                v.layerEffect(ShaderLibrary.Ripple(.float2(origin), .float(elapsed), .float(amplitude), .float(15), .float(7), .float(1100)),
                              maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                              isEnabled: elapsed > 0 && elapsed < 1.6)
            }
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(1.6, duration: 1.6)
        }
    }
}

/// Every tap anywhere leaves a soft ring and a tiny haptic. Doesn't block buttons or scrolling.
struct TouchFeedback: ViewModifier {
    @State private var rings: [TapRing] = []

    struct TapRing: Identifiable { let id = UUID(); let point: CGPoint }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    ForEach(rings) { r in TapRingView().position(r.point) }
                }
                .allowsHitTesting(false)
            }
            .simultaneousGesture(SpatialTapGesture().onEnded { v in
                Haptics.touch()
                let ring = TapRing(point: v.location)
                rings.append(ring)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { rings.removeAll { $0.id == ring.id } }
            })
    }

    private struct TapRingView: View {
        @State private var go = false
        var body: some View {
            ZStack {
                Circle().stroke(.white.opacity(0.5), lineWidth: 1.2)
                Circle().fill(.white.opacity(0.08))
            }
            .frame(width: 44, height: 44)
            .scaleEffect(go ? 1.6 : 0.3)
            .opacity(go ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.55)) { go = true } }
        }
    }
}

extension View {
    func touchFeedback() -> some View { modifier(TouchFeedback()) }
}

// MARK: - Morphing send button (pill → loading orb → check → pill)

struct MorphSendButton: View {
    var title: String
    var systemImage: String = "paperplane.fill"
    var height: CGFloat = 54
    var filled = true
    var action: () async -> Void

    enum Phase { case idle, sending, done }
    @State private var phase: Phase = .idle
    @State private var spin = false

    var body: some View {
        GeometryReader { geo in
            Button {
                guard phase == .idle else { return }
                Haptics.gemPress()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { phase = .sending }
                Task {
                    async let work: Void = action()
                    try? await Task.sleep(for: .milliseconds(650))
                    await work
                    Haptics.success()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = .done }
                    try? await Task.sleep(for: .milliseconds(1300))
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { phase = .idle }
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(phase == .done ? AnyShapeStyle(Love.glow) : (filled ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.1))))
                        .shadow(color: phase == .done ? Love.pink.opacity(0.6) : .clear, radius: 18)
                    switch phase {
                    case .idle:
                        HStack(spacing: 8) {
                            Image(systemName: systemImage).font(.system(size: height * 0.32, weight: .semibold))
                            Text(title).font(.system(size: height * 0.31, weight: .semibold))
                        }
                        .foregroundStyle(filled ? .black : .white)
                        .transition(.blurReplace)
                    case .sending:
                        Circle()
                            .trim(from: 0.1, to: 0.8)
                            .stroke(filled ? Color.black : .white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: height * 0.42, height: height * 0.42)
                            .rotationEffect(.degrees(spin ? 360 : 0))
                            .onAppear { withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true } }
                            .onDisappear { spin = false }
                            .transition(.scale.combined(with: .opacity))
                    case .done:
                        Image(systemName: "checkmark")
                            .font(.system(size: height * 0.38, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(width: phase == .idle ? geo.size.width : height, height: height)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
        .frame(height: height)
    }
}

// MARK: - Hold to send (fills as you hold, haptics rise, bursts on completion)

struct HoldToSendButton: View {
    var title: String
    var holdingTitle: String = "Keep holding…"
    var systemImage: String = "heart.fill"
    var duration: Double = 1.1
    var height: CGFloat = 56
    var onComplete: (_ heldFor: Double) -> Void

    @State private var progress: Double = 0
    @State private var holding = false
    @State private var startedAt: Date?
    @State private var burst = 0
    @State private var done = false
    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.09))
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            GeometryReader { geo in
                Capsule()
                    .fill(Love.glow)
                    .frame(width: max(height, geo.size.width * progress))
                    .opacity(progress > 0 || done ? 1 : 0)
                    .shadow(color: Love.pink.opacity(0.5 * progress), radius: 16)
            }
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark" : systemImage)
                    .font(.system(size: height * 0.32, weight: .semibold))
                    .symbolEffect(.bounce, value: burst)
                    .contentTransition(.symbolEffect(.replace))
                Text(done ? "Sent" : holding ? holdingTitle : title)
                    .font(.system(size: height * 0.3, weight: .semibold))
                    .contentTransition(.interpolate)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            ForEach(0..<burst, id: \.self) { _ in
                Shockwave(size: height, color: Love.pink, duration: 0.7).frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .scaleEffect(holding ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: holding)
        .contentShape(Capsule())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !holding && !done { begin() } }
            .onEnded { _ in end() })
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityAction { onComplete(duration) }
    }

    private func begin() {
        holding = true
        startedAt = .now
        Haptics.press()
        var lastTick = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { _ in
            guard let s = startedAt else { return }
            let p = min(1, Date().timeIntervalSince(s) / duration)
            progress = p
            let tick = Int(p * 10)
            if tick != lastTick { lastTick = tick; Haptics.charge(p) }
            if p >= 1 { complete() }
        }
    }

    private func complete() {
        timer?.invalidate()
        let held = startedAt.map { Date().timeIntervalSince($0) } ?? duration
        startedAt = nil
        holding = false
        Haptics.gemPress()
        burst += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { done = true }
        onComplete(held)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.smooth(duration: 0.5)) { done = false; progress = 0 }
        }
    }

    private func end() {
        guard !done else { return }
        timer?.invalidate()
        startedAt = nil
        holding = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { progress = 0 }
    }
}

// MARK: - Segmented pills (WHOOP-style outlined, morphing selection)

struct PillSegmented<T: Hashable>: View {
    var options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    guard selection != value else { return }
                    Haptics.tick()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { selection = value }
                } label: {
                    Text(label)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(selection == value ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background {
                            if selection == value {
                                Capsule().fill(.white).matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Sheets

extension View {
    /// Aegyo's bottom sheet: black glass, big radius, custom grabber.
    func aegyoSheet(_ detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(40)
            .presentationBackground {
                ZStack {
                    Color.black.opacity(0.82)
                    Rectangle().fill(.ultraThinMaterial).opacity(0.5)
                }
            }
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
    }
}
