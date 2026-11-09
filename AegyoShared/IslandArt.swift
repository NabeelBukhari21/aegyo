import SwiftUI

func kindColor(_ s: LoveAttributes.ContentState) -> Color {
    switch s.kind {
    case .light: Pixels.warm
    case .goodnight: Pixels.lilac
    case .goodMorning: Pixels.warm
    case .tapCode: Pixels.mint
    case .mood: moodColor(s.detail)
    case .letter: Pixels.rose
    case .photo: Pixels.mint
    default: Pixels.pink
    }
}

func moodColor(_ name: String?) -> Color {
    switch name?.lowercased() {
    case "happy": Color(red: 1, green: 0.82, blue: 0.3)
    case "loving": Pixels.pink
    case "sleepy": Pixels.lilac
    case "cozy": Color(red: 1, green: 0.66, blue: 0.48)
    case "excited": Color(red: 1, green: 0.45, blue: 0.38)
    case "busy": Pixels.mint
    case "stressed": Color(red: 0.75, green: 0.95, blue: 0.35)
    case "sad": Color(red: 0.45, green: 0.66, blue: 1)
    default: Pixels.rose
    }
}


// MARK: - LED panel scenes

/// The pixel scene for each kind of love, drawn on a small LED panel.
struct LEDPanel: View {
    let state: LoveAttributes.ContentState
    var cols: Int
    var rows: Int
    var dot: CGFloat

    var body: some View {
        DotMatrix(cols: cols, rows: rows, dot: dot, gap: dot * 0.55, pixel: scene)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
    }

    private var scene: (Int, Int) -> Color? {
        let C = cols, R = rows
        let col = kindColor(state)
        switch state.kind {
        case .missYou:
            let n = min(max(state.count, 1), C / 8)
            let level = Int(state.detail?.split(separator: "/").first ?? "") ?? 0
            return { c, r in
                if r == R - 1 { return level > 0 && c < level * C / 10 ? Pixels.rose : nil }
                let i = c / 8
                if i < n, Pixels.heart(c % 8, r - 1) { return i == n - 1 ? Pixels.pink : Pixels.pink.opacity(0.75) }
                return nil
            }
        case .hug:
            return { c, r in
                let mid = C / 2
                if Pixels.heart(c - (mid - 7), r - 2) { return Pixels.pink }
                if Pixels.heart(c - (mid - 1), r - 1) { return Pixels.rose }
                if Pixels.star(c, r, seed: 3, density: 29), abs(c - mid) > 9 { return Pixels.warm }
                return nil
            }
        case .thinkingOfYou:
            return { c, r in
                if Pixels.heart(c - (C - 12), r - 1) { return Pixels.pink }
                let trail = [(C - 16, 6), (C - 20, 7), (C - 23, 8)]
                if trail.contains(where: { $0.0 == c && $0.1 == r }) { return .white.opacity(0.8) }
                return nil
            }
        case .goodMorning:
            return { c, r in
                let dx = Double(c - C / 2), dy = Double(r - (R - 1))
                let d = (dx * dx * 0.6 + dy * dy).squareRoot()
                if r == R - 1 { return Pixels.warm.opacity(0.6) }
                if d < 3.2 { return Pixels.warm }
                if d > 4.2, d < 5.2, (c + r) % 2 == 0 { return Pixels.warm.opacity(0.7) }
                return nil
            }
        case .goodnight:
            return { c, r in
                if Pixels.moon(c - 2, r - 1) || Pixels.moon(c - 3, r - 1) { return Pixels.lilac }
                if c > 10, Pixels.star(c, r, seed: 5, density: 11) { return r % 2 == 0 ? .white : Pixels.lilac }
                return nil
            }
        case .light:
            let spark = Int(Double(C - 1) * 0.62)
            return { c, r in
                let x = Double(spark) / Double(C - 1)
                let sy = Int((Double(R - 2) * (1 - 4 * x * (1 - x) * 0.92)).rounded())
                if abs(c - spark) <= 1, abs(r - sy) <= 1 { return .white }
                if c <= 2, r >= R - 3 { return Pixels.warm }
                if c >= C - 3, r >= R - 3 { return Pixels.rose }
                if Pixels.arc(c, r, cols: C, rows: R) { return Pixels.warm.opacity(c < spark ? 0.9 : 0.35) }
                return nil
            }
        case .mood:
            let m = (state.detail ?? "").lowercased()
            return { c, r in
                // a round pixel face, then little mood particles drifting to the right
                let dx = c - 5, dy = r - 4
                let inHead = dx * dx + dy * dy <= 17
                if inHead {
                    let eyeL = dx == -2 && dy == -1, eyeR = dx == 2 && dy == -1
                    switch m {
                    case "sleepy", "cozy": if dy == -1 && (abs(dx + 2) <= 1 || abs(dx - 2) <= 1) { return .black }
                    case "loving": if (eyeL || eyeR) { return Pixels.pink }
                    case "excited": if (eyeL || eyeR || (dy == -2 && (dx == -2 || dx == 2))) { return .white }
                    default: if eyeL || eyeR { return .black }
                    }
                    let smile = m == "sad" || m == "stressed" ? (dy == 1 && abs(dx) == 2) || (dy == 2 && abs(dx) <= 1)
                                                               : (dy == 1 && abs(dx) == 2) || (dy == 2 && abs(dx) <= 1 && m != "sleepy") || (m == "sleepy" && dy == 2 && dx == 0)
                    if smile { return m == "sad" || m == "stressed" ? .black.opacity(0.85) : .black }
                    if dy == 1 && abs(dx) == 3 && m != "sad" { return Pixels.pink.opacity(0.9) }
                    return col
                }
                if c > 12 {
                    switch m {
                    case "sleepy":
                        let z = [(14, 6), (15, 6), (16, 6), (15, 5), (14, 4), (15, 4), (16, 4), (20, 4), (21, 4), (21, 3), (20, 2), (21, 2), (26, 2), (26, 1), (27, 0), (26, 0)]
                        if z.contains(where: { $0.0 == c && $0.1 == r }) { return Pixels.lilac.opacity(0.9) }
                    case "loving":
                        if Pixels.heart(c - 16, r - 2) || Pixels.heart(c - 30, r - 0) { return Pixels.pink.opacity(c > 28 ? 0.6 : 1) }
                    case "sad":
                        if (c % 6 == 0) && ((r + c / 6) % 3 == 0) { return Color(red: 0.45, green: 0.66, blue: 1).opacity(0.8) }
                    default:
                        if Pixels.star(c, r, seed: 11, density: 13) { return col.opacity(0.85) }
                    }
                }
                return nil
            }
        case .tapCode:
            let beats = (state.detail ?? "").split(separator: ",").compactMap { Double($0) }.map { Int($0 / 5000 * Double(C - 3)) }
            return { c, r in
                for b in beats {
                    if c == b, r >= 1, r <= R / 2 { return Pixels.mint }
                    if c == b + 1, r >= R / 2, r <= R - 2 { return Pixels.mint }
                }
                if r == R / 2 { return Pixels.mint.opacity(0.55) }
                return nil
            }
        case .letter:
            return { c, r in
                let ox = C / 2 - 5
                if Pixels.envelope(c - ox, r - 1) { return Pixels.rose }
                if (c == ox + 5 && r == 5) || (c == ox + 4 && r == 4) || (c == ox + 6 && r == 4) { return Pixels.pink }
                return nil
            }
        case .photo:
            return { c, r in
                if Pixels.camera(c - (C / 2 - 4), r - 1) { return Pixels.mint }
                if Pixels.star(c, r, seed: 9, density: 21), abs(c - C / 2) > 7 { return .white.opacity(0.8) }
                return nil
            }
        }
    }
}

