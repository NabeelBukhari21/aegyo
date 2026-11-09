import SwiftUI

/// The living opal heart: the spectrum slowly turns inside it, a light facet sweeps across,
/// it floats and sways. `beating` adds a lub-dub pulse (Ring screen).
struct GemView: View {
    var width: CGFloat = 170
    var beating = false
    var speed: Double = 1
    var glow = true
    var palette: [Color] = Opal.spectrum

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t * 40 * speed).truncatingRemainder(dividingBy: 360))
            let height = width * 136 / 150

            ZStack {
                if glow {
                    GemFill(angle: angle, palette: palette)
                        .frame(width: width * 1.25, height: width * 1.25)
                        .clipShape(Circle())
                        .blur(radius: width * 0.24)
                        .opacity(0.5)
                }

                GemFill(angle: angle, palette: palette)
                    .frame(width: width, height: height)
                    .overlay {
                        // the facet: a soft band of light gliding across the surface
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.38),
                                    .init(color: .white.opacity(0.6), location: 0.5),
                                    .init(color: .clear, location: 0.62)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(width: width * 2.2)
                        .offset(x: sin(t * 1.4 * speed) * width * 0.75)
                        .blendMode(.overlay)
                    }
                    .clipShape(HeartShape())
                    .overlay(HeartShape().stroke(.white.opacity(0.22), lineWidth: 0.8))
            }
            .scaleEffect(beating ? Self.heartbeat(t) : 1)
            .offset(y: reduceMotion ? 0 : sin(t * 1.25) * width * 0.04)
            .rotationEffect(.degrees(reduceMotion ? 0 : sin(t * 1.25) * 1.6))
        }
        .frame(width: width, height: width * 136 / 150)
    }

    /// Lub-dub, once every 1.2 s.
    static func heartbeat(_ t: Double) -> CGFloat {
        let p = t.truncatingRemainder(dividingBy: 1.2) / 1.2
        func bump(_ c: Double, _ w: Double, _ a: Double) -> Double { a * exp(-pow((p - c) / w, 2)) }
        return 1 + CGFloat(bump(0.12, 0.05, 0.07) + bump(0.36, 0.05, 0.045))
    }
}

/// A ring of light that expands and fades. Re-trigger by changing `id`.
struct Shockwave: View {
    var size: CGFloat = 170
    var color: Color = Opal.mint
    var duration: Double = 0.9
    @State private var go = false

    var body: some View {
        Circle()
            .stroke(color.opacity(0.8), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(go ? 2.1 : 0.6)
            .opacity(go ? 0 : 0.9)
            .onAppear { withAnimation(.easeOut(duration: duration)) { go = true } }
            .allowsHitTesting(false)
    }
}

/// Continuous rings (Ring screen), staggered.
struct RippleField: View {
    var size: CGFloat = 180
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = ((t / 3.6) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Opal.mint.opacity(0.55), lineWidth: 1)
                        .frame(width: size, height: size)
                        .scaleEffect(0.7 + p * 1.4)
                        .opacity((1 - p) * 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Pure-black canvas with slow-breathing teal/violet light behind the gem.
struct OpalBackground: View {
    var focus: UnitPoint = UnitPoint(x: 0.5, y: 0.36)
    @State private var breathe = false
    var body: some View {
        ZStack {
            Color.black
            ZStack {
                RadialGradient(colors: [Color(red: 0.31, green: 0.78, blue: 0.75).opacity(0.24), .clear],
                               center: focus, startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Color(red: 0.59, green: 0.43, blue: 1).opacity(0.17), .clear],
                               center: UnitPoint(x: focus.x + 0.22, y: focus.y - 0.05), startRadius: 0, endRadius: 200)
            }
            .opacity(breathe ? 1 : 0.62)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathe = true } }
    }
}

/// Opal's frosted dark glass surface.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.11), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .background(Color(white: 0.06).opacity(0.7), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

extension View {
    func glass(_ radius: CGFloat = 22) -> some View { modifier(GlassSurface(radius: radius)) }
}

/// Press feedback: a springy squeeze.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, scale: scale)
    }

    /// Squeezes on touch-down with a tiny click, then springs back with a little overshoot.
    private struct PressBody: View {
        let configuration: Configuration
        let scale: CGFloat
        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? scale : 1)
                .brightness(configuration.isPressed ? -0.04 : 0)
                .animation(configuration.isPressed ? .spring(response: 0.18, dampingFraction: 0.9)
                                                   : .spring(response: 0.42, dampingFraction: 0.45), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, down in if down { Haptics.press() } }
        }
    }
}

/// Opal's white pill.
struct WhitePill: View {
    var title: String
    var systemImage: String?
    var height: CGFloat = 38
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: height * 0.36, weight: .semibold)) }
            Text(title).font(.system(size: height * 0.37, weight: .semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, height * 0.45)
        .frame(height: height)
        .background(.white, in: Capsule())
    }
}

/// Small all-caps label, Opal style.
struct CapsLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .medium))
            .tracking(1.1)
            .foregroundStyle(.white.opacity(0.5))
    }
}

/// Section header used down the home screen.
struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(.white.opacity(0.5)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A glass card with standard padding.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(24)
    }
}

/// A rising, fading-in entrance as a view scrolls into place.
struct ScrollReveal: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.animated(.smooth(duration: 0.5))) { c, phase in
            c.opacity(phase.isIdentity ? 1 : 0.3)
             .scaleEffect(phase.isIdentity ? 1 : 0.96)
             .blur(radius: phase.isIdentity ? 0 : 3)
        }
    }
}

extension View {
    func reveal() -> some View { modifier(ScrollReveal()) }
}

/// Short "4m ago" style text.
func agoText(_ date: Date?) -> String {
    guard let date else { return "—" }
    let s = Int(Date().timeIntervalSince(date))
    switch s {
    case ..<60: return "now"
    case ..<3600: return "\(s / 60)m ago"
    case ..<86400: return "\(s / 3600)h ago"
    default: return "\(s / 86400)d ago"
    }
}
