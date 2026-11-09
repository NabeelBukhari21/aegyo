import SwiftUI

enum AppTab: Int, CaseIterable {
    case home, sky, moments, us

    var icon: String {
        switch self {
        case .home: "heart"
        case .sky: "moon.stars"
        case .moments: "photo.on.rectangle.angled"
        case .us: "sparkles"
        }
    }
    var title: String {
        switch self {
        case .home: "Doki"
        case .sky: "Sky"
        case .moments: "Moments"
        case .us: "Us"
        }
    }
    /// Slot in the 5-wide bar (centre slot is the + orb).
    var slot: Int { [0, 1, 3, 4][rawValue] }
}

/// Floating Liquid Glass bar. A liquid blob stretches between tabs (two springs merged by a metaball filter),
/// and the centre orb opens the action sheet.
struct LiquidTabBar: View {
    @Binding var tab: AppTab
    var plusOpen: Bool
    var onPlus: () -> Void

    @State private var lead: CGFloat = 0
    @State private var trail: CGFloat = 0

    private let height: CGFloat = 72

    var body: some View {
        GeometryReader { geo in
            let slotW = geo.size.width / 5
            let x = { (t: AppTab) in slotW * (CGFloat(t.slot) + 0.5) - geo.size.width / 2 }
            ZStack {
                glass
                // liquid blob
                Love.glow
                    .mask {
                        Canvas { ctx, size in
                            ctx.addFilter(.alphaThreshold(min: 0.5, color: .white))
                            ctx.addFilter(.blur(radius: 9))
                            ctx.drawLayer { l in
                                for id in 0..<2 {
                                    if let s = ctx.resolveSymbol(id: id) { l.draw(s, at: CGPoint(x: size.width / 2, y: size.height / 2)) }
                                }
                            }
                        } symbols: {
                            Capsule().frame(width: slotW * 1.02, height: 52).offset(x: lead).tag(0)
                            Circle().frame(width: 34, height: 34).offset(x: trail).tag(1)
                        }
                    }
                    .shadow(color: Love.pink.opacity(0.55), radius: 14)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    tabButton(.home)
                    tabButton(.sky)
                    PlusOrb(open: plusOpen, action: onPlus).frame(width: slotW)
                    tabButton(.moments)
                    tabButton(.us)
                }
            }
            .onAppear { lead = x(tab); trail = x(tab) }
            .onChange(of: tab) { _, t in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { lead = x(t) }
                withAnimation(.spring(response: 0.62, dampingFraction: 0.68)) { trail = x(t) }
            }
        }
        .frame(height: height)
    }

    @ViewBuilder private var glass: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.35)).interactive(), in: Capsule())
        } else {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(.black.opacity(0.35)))
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func tabButton(_ t: AppTab) -> some View {
        let on = tab == t
        return Button {
            guard tab != t else { return }
            Haptics.tick()
            tab = t
        } label: {
            VStack(spacing: 3) {
                Image(systemName: on ? t.icon + ".fill" : t.icon)
                    .font(.system(size: 19, weight: on ? .semibold : .regular))
                    .symbolEffect(.bounce.up.byLayer, value: on)
                    .contentTransition(.symbolEffect(.replace))
                Text(t.title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(on ? .white : .white.opacity(0.55))
            .scaleEffect(on ? 1.06 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: on)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.86))
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The glowing centre orb. Its gradient slowly turns; the + rotates into × when the sheet is open.
private struct PlusOrb: View {
    var open: Bool
    var action: () -> Void
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        Button(action: { Haptics.gemPress(); action() }) {
            // Rotation and pulse run as render-server animations: no per-frame view rebuilds.
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [Color(red: 1, green: 0.35, blue: 0.55), Color(red: 0.95, green: 0.2, blue: 0.6), Color(red: 0.7, green: 0.4, blue: 1),
                                                   Color(red: 1, green: 0.55, blue: 0.5), Color(red: 1, green: 0.35, blue: 0.55)], center: .center))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.55), .clear], center: UnitPoint(x: 0.32, y: 0.25), startRadius: 0, endRadius: 30))
                Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(open ? 135 : 0))
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: open)
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())
            .scaleEffect(pulse ? 1.03 : 0.97)
            .shadow(color: Love.pink.opacity(0.7), radius: 16, y: 4)
            .onAppear {
                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { spin = true }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        .buttonStyle(PressStyle(scale: 0.85))
        .offset(y: -10)
        .accessibilityLabel("Reach her")
    }
}
