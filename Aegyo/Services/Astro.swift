import Foundation
import SwiftUI

/// Moon phase, moon sign and star-sign maths. Good to within a few hours, which is plenty for love.
enum Astro {
    static let synodicMonth = 29.530588853
    /// A known new moon: 6 Jan 2000, 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
    static func moonPhase(_ date: Date = .now) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86400
        let p = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// Fraction of the disc that's lit, 0…1.
    static func illumination(_ date: Date = .now) -> Double { (1 - cos(2 * .pi * moonPhase(date))) / 2 }

    static func phaseName(_ p: Double) -> String {
        switch p {
        case ..<0.03, 0.97...: "New Moon"
        case ..<0.22: "Waxing Crescent"
        case ..<0.28: "First Quarter"
        case ..<0.47: "Waxing Gibbous"
        case ..<0.53: "Full Moon"
        case ..<0.72: "Waning Gibbous"
        case ..<0.78: "Last Quarter"
        default: "Waning Crescent"
        }
    }

    static func nextPhase(_ target: Double, after date: Date = .now) -> Date {
        let p = moonPhase(date)
        var delta = target - p
        if delta <= 0.01 { delta += 1 }
        return date.addingTimeInterval(delta * synodicMonth * 86400)
    }

    /// The zodiac sign the Moon is passing through (approximate ecliptic longitude).
    static func moonSign(_ date: Date = .now) -> Zodiac {
        let d = date.timeIntervalSince(Date(timeIntervalSince1970: 946_728_000)) / 86400 // J2000
        let L = 218.316 + 13.176396 * d
        let M = (134.963 + 13.064993 * d) * .pi / 180
        var lon = (L + 6.289 * sin(M)).truncatingRemainder(dividingBy: 360)
        if lon < 0 { lon += 360 }
        return Zodiac.allCases[Int(lon / 30) % 12]
    }
}

enum Zodiac: Int, CaseIterable, Identifiable, Codable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    var id: Int { rawValue }

    var name: String { String(describing: self).capitalized }

    var symbol: String { ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"][rawValue] }

    enum Element: String { case fire, earth, air, water }
    var element: Element { [.fire, .earth, .air, .water][rawValue % 4] }

    var dates: String {
        ["Mar 21 – Apr 19", "Apr 20 – May 20", "May 21 – Jun 20", "Jun 21 – Jul 22", "Jul 23 – Aug 22", "Aug 23 – Sep 22",
         "Sep 23 – Oct 22", "Oct 23 – Nov 21", "Nov 22 – Dec 21", "Dec 22 – Jan 19", "Jan 20 – Feb 18", "Feb 19 – Mar 20"][rawValue]
    }

    var trait: String {
        ["bold and first to say it", "steady, loyal, all-in", "playful and never boring", "soft-hearted and protective",
         "warm, loud, generous", "thoughtful in tiny ways", "romantic and fair", "intense and deeply devoted",
         "adventurous, always laughing", "patient, builds forever", "one of a kind, a little weird", "dreamy and endlessly kind"][rawValue]
    }

    static func from(month: Int, day: Int) -> Zodiac {
        let starts = [(3, 21), (4, 20), (5, 21), (6, 21), (7, 23), (8, 23), (9, 23), (10, 23), (11, 22), (12, 22), (1, 20), (2, 19)]
        let md = month * 100 + day
        for i in (0..<12).reversed() {
            let s = starts[i].0 * 100 + starts[i].1
            if i == 9 { if md >= 1222 || md < 120 { return .capricorn } else { continue } }
            if md >= s { return Zodiac(rawValue: i)! }
        }
        return .capricorn
    }

    static func from(_ date: Date) -> Zodiac {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return from(month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Simplified constellation: star positions (0…1) and the lines between them.
    var constellation: (stars: [CGPoint], lines: [(Int, Int)]) {
        func p(_ a: [(Double, Double)]) -> [CGPoint] { a.map { CGPoint(x: $0.0, y: $0.1) } }
        func chain(_ n: Int) -> [(Int, Int)] { (0..<(n - 1)).map { ($0, $0 + 1) } }
        switch self {
        case .aries: return (p([(0.1, 0.62), (0.45, 0.45), (0.7, 0.38), (0.86, 0.5)]), chain(4))
        case .taurus: return (p([(0.08, 0.2), (0.35, 0.45), (0.5, 0.55), (0.62, 0.5), (0.92, 0.25), (0.55, 0.72), (0.3, 0.88)]), [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6)])
        case .gemini: return (p([(0.2, 0.12), (0.48, 0.1), (0.25, 0.5), (0.52, 0.46), (0.18, 0.88), (0.55, 0.82), (0.8, 0.6)]), [(0, 2), (2, 4), (1, 3), (3, 5), (0, 1), (3, 6)])
        case .cancer: return (p([(0.5, 0.1), (0.52, 0.45), (0.2, 0.82), (0.82, 0.78), (0.55, 0.58)]), [(0, 1), (1, 4), (4, 2), (4, 3)])
        case .leo: return (p([(0.12, 0.66), (0.42, 0.6), (0.7, 0.66), (0.86, 0.4), (0.76, 0.18), (0.6, 0.24), (0.62, 0.42)]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 2)])
        case .virgo: return (p([(0.08, 0.3), (0.3, 0.36), (0.46, 0.5), (0.66, 0.45), (0.88, 0.6), (0.5, 0.76), (0.34, 0.92)]), [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6)])
        case .libra: return (p([(0.5, 0.14), (0.2, 0.46), (0.8, 0.46), (0.3, 0.82), (0.76, 0.8)]), [(0, 1), (0, 2), (1, 2), (1, 3), (2, 4)])
        case .scorpio: return (p([(0.08, 0.2), (0.2, 0.3), (0.35, 0.36), (0.5, 0.5), (0.55, 0.7), (0.7, 0.86), (0.86, 0.82), (0.92, 0.66)]), chain(8))
        case .sagittarius: return (p([(0.3, 0.3), (0.5, 0.24), (0.66, 0.4), (0.5, 0.56), (0.3, 0.56), (0.78, 0.72), (0.18, 0.78)]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (2, 5), (4, 6)])
        case .capricorn: return (p([(0.08, 0.3), (0.4, 0.46), (0.7, 0.34), (0.92, 0.24), (0.62, 0.78), (0.3, 0.72)]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0)])
        case .aquarius: return (p([(0.08, 0.3), (0.3, 0.42), (0.5, 0.3), (0.7, 0.46), (0.6, 0.66), (0.82, 0.82), (0.4, 0.78)]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (4, 6)])
        case .pisces: return (p([(0.08, 0.2), (0.2, 0.36), (0.36, 0.56), (0.5, 0.78), (0.66, 0.56), (0.8, 0.46), (0.92, 0.34), (0.84, 0.22)]), chain(8))
        }
    }

    /// Compatibility, 0–100, from elements (fire+air and earth+water get along; same element is easy).
    func match(with o: Zodiac) -> Int {
        let a = element, b = o.element
        var base: Int
        if a == b { base = 90 }
        else if Set([a, b]) == Set([.fire, .air]) || Set([a, b]) == Set([.earth, .water]) { base = 86 }
        else if Set([a, b]) == Set([.fire, .water]) || Set([a, b]) == Set([.air, .earth]) { base = 68 }
        else { base = 75 }
        let wobble = ((rawValue * 7 + o.rawValue * 3) % 9) - 4
        return min(99, base + wobble)
    }
}

enum LoveForecast {
    static let lines = [
        "A good night for a long voice note. Say the thing you've been saving.",
        "Small gestures land big today. Send the photo, even the blurry one.",
        "You two are in sync. Plan the next trip while the energy is high.",
        "Patience pays off. If one of you is quiet, send a heartbeat, not a question.",
        "Laughter is your love language today. Send something silly.",
        "Old memories feel close. Ask about her favourite moment of you two.",
        "A tender, slow day. Goodnight texts count double tonight.",
        "Surprises are favoured. Write an Open When letter she won't expect.",
        "Talk about the future today. Dream out loud together.",
        "The moon pulls you closer. Look up at the same time tonight.",
        "Be the first to say it today. You know what it is.",
        "Distance feels lighter today. Count down to the next hug.",
    ]
    static func today(_ a: Zodiac, _ b: Zodiac, date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return lines[(day + a.rawValue * 5 + b.rawValue * 3) % lines.count]
    }
}
