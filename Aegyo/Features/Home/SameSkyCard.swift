import SwiftUI

/// The arc, the two breathing lights, an ambient drifting spark and a bright burst on send.
struct TwoLightsArc: View {
    var burstAt: Date?
    static let warm = Color(red: 1.0, green: 0.84, blue: 0.63)
    static let rose = Color(red: 1.0, green: 0.70, blue: 0.80)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let a = CGPoint(x: 26, y: size.height - 40)
                let b = CGPoint(x: size.width - 26, y: size.height - 40)
                let c = CGPoint(x: size.width / 2, y: -size.height * 0.55)
                var arc = Path()
                arc.move(to: a)
                arc.addQuadCurve(to: b, control: c)
                g.stroke(arc, with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))

                func glow(_ p: CGPoint, _ r: CGFloat, _ col: Color, _ alpha: Double = 1) {
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    g.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [.white.opacity(alpha), col.opacity(0.8 * alpha), col.opacity(0)]),
                        center: p, startRadius: 0, endRadius: r))
                }
                func point(_ u: Double) -> CGPoint {
                    let v = 1 - u
                    return CGPoint(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                                   y: v * v * a.y + 2 * v * u * c.y + u * u * b.y)
                }

                glow(a, 20 + 4 * sin(t * 2.1), Self.warm)
                glow(b, 20 + 4 * sin(t * 2.1 + 2.2), Self.rose)

                // ambient spark: every 4 s
                let p = (t / 4).truncatingRemainder(dividingBy: 1)
                if p < 0.75 {
                    let u = easeInOut(p / 0.75)
                    glow(point(u), 9, Self.warm, sin(.pi * u) * 0.9)
                }
                // burst on send: a brighter spark with a short trail
                if let burstAt {
                    let q = ctx.date.timeIntervalSince(burstAt) / 1.3
                    if q >= 0, q < 1 {
                        for k in 0..<6 {
                            let u = easeInOut(max(0, q - Double(k) * 0.035))
                            glow(point(u), 14 - CGFloat(k) * 1.8, .white, (1 - Double(k) / 6) * (q < 0.92 ? 1 : (1 - q) * 12))
                        }
                    }
                    if q >= 0.9, q < 1.6 { // landing bloom on her light
                        let f = (q - 0.9) / 0.7
                        glow(b, 22 + 30 * f, Self.rose, 1 - f)
                    }
                }
            }
            .overlay(alignment: .bottomLeading) { CapsLabel(text: "You").frame(width: 52).padding(.bottom, 4) }
            .overlay(alignment: .bottomTrailing) { CapsLabel(text: Profile.partnerName).frame(width: 52).padding(.bottom, 4) }
        }
    }

    private func easeInOut(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
}
