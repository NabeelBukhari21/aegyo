import SwiftUI

/// A little LED panel: a grid of round dots, lit or dim. Aegyo's Dynamic Island speaks in pixels.
struct DotMatrix: View {
    var cols: Int
    var rows: Int
    var dot: CGFloat = 3
    var gap: CGFloat = 1.6
    var dimOpacity: Double = 0.09
    /// Returns the colour of a lit dot, or nil for an unlit one.
    var pixel: (Int, Int) -> Color?

    var body: some View {
        Canvas { g, _ in
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * (dot + gap), y: CGFloat(r) * (dot + gap), width: dot, height: dot)
                    if let col = pixel(c, r) {
                        g.fill(Path(ellipseIn: rect.insetBy(dx: -dot * 0.35, dy: -dot * 0.35)), with: .color(col.opacity(0.22)))
                        g.fill(Path(ellipseIn: rect), with: .color(col))
                    } else {
                        g.fill(Path(ellipseIn: rect), with: .color(.white.opacity(dimOpacity)))
                    }
                }
            }
        }
        .frame(width: CGFloat(cols) * (dot + gap) - gap, height: CGFloat(rows) * (dot + gap) - gap)
    }
}

/// Pixel sprites and scenes for each kind of love.
enum Pixels {
    static let pink = Color(red: 1, green: 0.36, blue: 0.56)
    static let rose = Color(red: 1, green: 0.62, blue: 0.74)
    static let mint = Color(red: 0.55, green: 1, blue: 0.86)
    static let warm = Color(red: 1, green: 0.84, blue: 0.6)
    static let lilac = Color(red: 0.74, green: 0.66, blue: 1)
    static let white = Color.white

    static func sprite(_ rows: [String]) -> (Int, Int) -> Bool {
        { c, r in r >= 0 && r < rows.count && c >= 0 && c < rows[r].count && Array(rows[r])[c] == "X" }
    }

    static let heart = sprite([
        ".XX.XX.",
        "XXXXXXX",
        "XXXXXXX",
        ".XXXXX.",
        "..XXX..",
        "...X...",
    ])

    static let bigHeart = sprite([
        "..XXX...XXX..",
        ".XXXXX.XXXXX.",
        "XXXXXXXXXXXXX",
        "XXXXXXXXXXXXX",
        ".XXXXXXXXXXX.",
        "..XXXXXXXXX..",
        "...XXXXXXX...",
        ".....XXX.....",
        "......X......",
    ])

    static let envelope = sprite([
        "XXXXXXXXXXX",
        "XX.......XX",
        "X.X.....X.X",
        "X..X...X..X",
        "X...XXX...X",
        "X.........X",
        "XXXXXXXXXXX",
    ])

    static let moon = sprite([
        "..XXX..",
        ".XX....",
        "XX.....",
        "XX.....",
        "XX.....",
        ".XX....",
        "..XXX..",
    ])

    static let camera = sprite([
        "...XXX...",
        "XXXXXXXXX",
        "X..XXX..X",
        "X.X...X.X",
        "X.X...X.X",
        "X..XXX..X",
        "XXXXXXXXX",
    ])

    /// Mood faces, 9×7, drawn in the mood's colour.
    static func face(_ mood: String) -> (Int, Int) -> Bool {
        let eyes: [String], mouth: [String]
        switch mood.lowercased() {
        case "happy": eyes = [".X.....X.", "X.X...X.X"]; mouth = ["..X...X..", "...XXX..."]
        case "loving": eyes = ["XX.X.XX.X", ".X.....X."]; mouth = ["..X...X..", "...XXX..."]
        case "sleepy", "cozy": eyes = [".........", "XXX...XXX"]; mouth = [".........", "...XXX..."]
        case "excited": eyes = ["XX.....XX", "XX.....XX"]; mouth = ["..XXXXX..", "...XXX..."]
        case "sad": eyes = ["X.......X", ".X.....X."]; mouth = ["...XXX...", "..X...X.."]
        case "stressed": eyes = [".X.....X.", ".X.....X."]; mouth = ["..X.X.X..", ".X.X.X.X."]
        default: eyes = [".X.....X.", ".X.....X."]; mouth = [".........", "..XXXXX.."]
        }
        return sprite([".........", eyes[0], eyes[1], ".........", mouth[0], mouth[1], "........."])
    }

    /// Draw `sprite` at an offset inside a scene.
    static func at(_ s: @escaping (Int, Int) -> Bool, _ ox: Int, _ oy: Int) -> (Int, Int) -> Bool {
        { c, r in s(c - ox, r - oy) }
    }

    /// Deterministic "random" stars.
    static func star(_ c: Int, _ r: Int, seed: Int = 7, density: Int = 23) -> Bool {
        ((c * 73 + r * 151 + seed * 31) % density) == 0
    }

    /// A parabola from left to right (Same Sky arc).
    static func arc(_ c: Int, _ r: Int, cols: Int, rows: Int) -> Bool {
        let x = Double(c) / Double(cols - 1)
        let y = Double(rows - 2) * (1 - 4 * x * (1 - x) * 0.92)
        return abs(Double(r) - y) < 0.55 && c % 2 == 0
    }

    /// Big 3×5 digits for LED numbers.
    static let digits: [Character: [String]] = [
        "0": ["XXX", "X.X", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"], "2": ["XXX", "..X", "XXX", "X..", "XXX"],
        "3": ["XXX", "..X", "XXX", "..X", "XXX"], "4": ["X.X", "X.X", "XXX", "..X", "..X"], "5": ["XXX", "X..", "XXX", "..X", "XXX"],
        "6": ["XXX", "X..", "XXX", "X.X", "XXX"], "7": ["XXX", "..X", ".X.", ".X.", ".X."], "8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
        "9": ["XXX", "X.X", "XXX", "..X", "XXX"], "×": ["...", "X.X", ".X.", "X.X", "..."], "/": ["..X", "..X", ".X.", "X..", "X.."],
    ]

    static func text(_ s: String) -> (Int, Int) -> Bool {
        let chars = Array(s)
        return { c, r in
            let i = c / 4, x = c % 4
            guard i < chars.count, x < 3, r >= 0, r < 5, let g = digits[chars[i]] else { return false }
            return Array(g[r])[x] == "X"
        }
    }
}
