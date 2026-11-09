import CoreLocation
import Foundation

/// One thing that happened between you two.
struct LoveEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kind: LoveKind
    /// true = you sent it, false = she sent it.
    var outgoing: Bool
    var detail: String?
    var photoID: String?
}

struct MoodStatus: Codable, Hashable {
    var mood: Mood
    var at: Date
}

/// "Open when…" letters, sealed until the right moment.
struct Letter: Codable, Identifiable, Hashable {
    enum Trigger: String, Codable, CaseIterable, Identifiable {
        case missMe, cantSleep, badDay, needLaugh, anniversary, onDate
        var id: String { rawValue }
        var title: String {
            switch self {
            case .missMe: "Open when you miss me"
            case .cantSleep: "Open when you can't sleep"
            case .badDay: "Open when you had a bad day"
            case .needLaugh: "Open when you need a laugh"
            case .anniversary: "Open on our anniversary"
            case .onDate: "Open on a date I choose"
            }
        }
    }

    var id = UUID()
    var trigger: Trigger
    var body: String
    var unlockDate: Date?
    var createdAt = Date()
    var outgoing = true
    var openedAt: Date?

    var isLocked: Bool {
        if let unlockDate { return unlockDate > .now }
        return false
    }
}

/// A sent photo (full image in Documents, thumbnail in the App Group for the Dynamic Island).
struct SentPhoto: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var caption: String?
    var outgoing = true
}

struct Place: Codable, Hashable {
    var name: String
    var lat: Double
    var lon: Double
    var timeZoneID: String?

    var location: CLLocation { CLLocation(latitude: lat, longitude: lon) }
    var timeZone: TimeZone { timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }
}

/// Everything Aegyo remembers. Saved as JSON on this phone; the backend will sync it in Phase 2.
struct LoveData: Codable {
    var events: [LoveEvent] = []
    var myMood: MoodStatus?
    var herMood: MoodStatus?
    var letters: [Letter] = []
    var photos: [SentPhoto] = []
    /// Your daily-question answers, keyed by "yyyy-MM-dd".
    var answers: [String: String] = [:]
    var loveLanguage: String?
    var myPlace: Place?
    var herPlace: Place?
    var celebratedMilestones: [Int] = []
}

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func of(_ d: Date) -> String { formatter.string(from: d) }
}
