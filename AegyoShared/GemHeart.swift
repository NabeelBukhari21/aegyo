import SwiftUI

/// The Aegyo heart silhouette (designed on a 150 × 136 grid).
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 150, sy = rect.height / 136
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(75, 132))
        path.addCurve(to: p(2, 40), control1: p(30, 100), control2: p(0, 70))
        path.addCurve(to: p(44, 0), control1: p(4, 14), control2: p(24, 0))
        path.addCurve(to: p(75, 20), control1: p(58, 0), control2: p(70, 8))
        path.addCurve(to: p(106, 0), control1: p(80, 8), control2: p(92, 0))
        path.addCurve(to: p(148, 40), control1: p(126, 0), control2: p(146, 14))
        path.addCurve(to: p(75, 132), control1: p(150, 70), control2: p(120, 100))
        path.closeSubpath()
        return path
    }
}

enum Opal {
    static let mint = Color(red: 0.62, green: 0.96, blue: 0.85)
    static let spectrum: [Color] = [
        Color(red: 0.50, green: 0.97, blue: 0.91),
        Color(red: 0.70, green: 0.55, blue: 1.00),
        Color(red: 1.00, green: 0.62, blue: 0.82),
        Color(red: 1.00, green: 0.90, blue: 0.63),
        Color(red: 0.62, green: 1.00, blue: 0.72),
        Color(red: 0.50, green: 0.82, blue: 1.00),
        Color(red: 0.50, green: 0.97, blue: 0.91),
    ]
}

/// The opal "material": a rotating spectrum with a soft specular highlight and a deep lower shadow.
struct GemFill: View {
    var angle: Angle
    var palette: [Color] = Opal.spectrum

    var body: some View {
        ZStack {
            AngularGradient(colors: palette, center: UnitPoint(x: 0.45, y: 0.55), angle: angle)
                .saturation(1.15)
            RadialGradient(colors: [Color(red: 0.08, green: 0.04, blue: 0.24).opacity(0.55), .clear],
                           center: UnitPoint(x: 0.70, y: 0.82), startRadius: 0, endRadius: 90)
            RadialGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                           center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: 46)
        }
    }
}

/// Non-animated gem, for the Live Activity / Dynamic Island (widgets can't run timelines).
struct StaticGem: View {
    var width: CGFloat
    var angle: Angle = .degrees(35)
    var palette: [Color] = GemTier.current.palette

    var body: some View {
        GemFill(angle: angle, palette: palette)
            .frame(width: width, height: width * 136 / 150)
            .clipShape(HeartShape())
            .overlay(HeartShape().stroke(.white.opacity(0.25), lineWidth: 0.6))
            .shadow(color: Opal.mint.opacity(0.35), radius: width / 6)
    }
}

/// The gem evolves the more love you two send. Each tier has its own light.
enum GemTier: Int, CaseIterable, Identifiable {
    case opal, roseOpal, moonstone, aurora, diamond

    var id: Int { rawValue }

    static let totalKey = "loveTotal"

    /// Total love sent (all kinds that count), shared with the widget.
    static var total: Int { AppGroup.defaults.integer(forKey: totalKey) }
    static var current: GemTier { tier(for: total) }

    static func tier(for total: Int) -> GemTier {
        allCases.last { total >= $0.threshold } ?? .opal
    }

    var threshold: Int {
        switch self {
        case .opal: 0
        case .roseOpal: 50
        case .moonstone: 150
        case .aurora: 400
        case .diamond: 1000
        }
    }

    var next: GemTier? { GemTier(rawValue: rawValue + 1) }

    var name: String {
        switch self {
        case .opal: "Blush"
        case .roseOpal: "Rose Quartz"
        case .moonstone: "Moonstone"
        case .aurora: "Aurora"
        case .diamond: "Diamond"
        }
    }

    var blurb: String {
        switch self {
        case .opal: "Where every love story starts."
        case .roseOpal: "Warmer now. You two are a habit."
        case .moonstone: "Calm, silver, always there."
        case .aurora: "Northern lights inside a heart."
        case .diamond: "A thousand moments. Unbreakable."
        }
    }

    var palette: [Color] {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch self {
        case .opal:
            return [c(1, 0.36, 0.52), c(1, 0.55, 0.62), c(0.96, 0.24, 0.45), c(0.80, 0.42, 1), c(1, 0.62, 0.55), c(1, 0.36, 0.52)]
        case .roseOpal:
            return [c(1, 0.70, 0.80), c(1, 0.86, 0.72), c(0.98, 0.55, 0.70), c(0.85, 0.62, 1), c(1, 0.78, 0.86), c(1, 0.70, 0.80)]
        case .moonstone:
            return [c(0.80, 0.86, 1), c(0.62, 0.70, 0.95), c(0.92, 0.94, 1), c(0.55, 0.82, 0.95), c(0.78, 0.74, 1), c(0.80, 0.86, 1)]
        case .aurora:
            return [c(0.12, 0.84, 0.70), c(0.42, 0.30, 1), c(1, 0.37, 0.62), c(0.20, 0.95, 0.80), c(0.50, 0.40, 1), c(0.12, 0.84, 0.70)]
        case .diamond:
            return [c(1, 1, 1), c(0.80, 0.95, 1), c(1, 0.92, 0.98), c(0.95, 1, 0.92), c(0.88, 0.88, 1), c(1, 1, 1)]
        }
    }
}
