import ActivityKit
import Foundation

/// Everything you can send. Shared by the app, the Live Activity and (later) the backend payloads.
enum LoveKind: String, Codable, Hashable, CaseIterable {
    case missYou, hug, thinkingOfYou, goodMorning, goodnight
    case photo, mood, light, tapCode, letter

    /// Short label for buttons and logs.
    var label: String {
        switch self {
        case .missYou: "Miss you"
        case .hug: "Hug"
        case .thinkingOfYou: "Thinking of you"
        case .goodMorning: "Good morning"
        case .goodnight: "Goodnight"
        case .photo: "Photo"
        case .mood: "Mood"
        case .light: "Light"
        case .tapCode: "Heartbeat"
        case .letter: "Letter"
        }
    }

    var symbol: String {
        switch self {
        case .missYou: "heart.fill"
        case .hug: "hands.and.sparkles.fill"
        case .thinkingOfYou: "bubble.left.fill"
        case .goodMorning: "sun.max.fill"
        case .goodnight: "moon.fill"
        case .photo: "photo.fill"
        case .mood: "face.smiling"
        case .light: "sparkle"
        case .tapCode: "waveform.path.ecg"
        case .letter: "envelope.fill"
        }
    }

    /// What the receiver reads, e.g. "Nabeel misses you". `detail` carries mood names etc.
    func headline(from sender: String, detail: String? = nil) -> String {
        switch self {
        case .missYou: "\(sender) misses you"
        case .hug: "\(sender) sent you a hug"
        case .thinkingOfYou: "\(sender) is thinking of you"
        case .goodMorning: "Good morning from \(sender)"
        case .goodnight: "\(sender) says goodnight"
        case .photo: "\(sender) sent a photo"
        case .mood: "\(sender) is feeling \(detail?.lowercased() ?? "something")"
        case .light: "\(sender) sent a light"
        case .tapCode: "\(sender) sent a heartbeat"
        case .letter: "\(sender) wrote you a letter"
        }
    }

    func subtitle(detail: String? = nil) -> String {
        switch self {
        case .missYou: detail.map { "Missing you \($0) right now" } ?? "Thinking about you right now"
        case .hug: "A long, warm hug"
        case .thinkingOfYou: "You crossed their mind"
        case .goodMorning: "Have a lovely day"
        case .goodnight: "Sleep well"
        case .photo: detail ?? "Tap to open it"
        case .mood: "Tap to send how you feel"
        case .light: "It travelled the whole way to you"
        case .tapCode: "Hold your phone to feel it"
        case .letter: detail ?? "Sealed until the right moment"
        }
    }

    /// Kinds that count as "love" in the stats and moon calendar.
    var countsAsLove: Bool { self != .mood }
}

/// Live Activity shown in the Dynamic Island + Lock Screen of the person receiving love.
/// NOTE: the backend's push-to-start payload uses `"attributes-type": "LoveAttributes"`, so keep this name stable.
struct LoveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kind: LoveKind
        var sentAt: Date
        /// How many times love was sent while this activity was alive ("×3").
        var count: Int
        /// True once the receiver tapped "Miss you too".
        var replied: Bool
        /// File name of a photo thumbnail in the shared App Group container (kind == .photo).
        var photoID: String? = nil
        /// Extra text: a mood name, a photo caption, a letter title.
        var detail: String? = nil
        /// Distance in km between you, for the travelling-light island.
        var distanceKm: Int? = nil
        /// Today's love on a 24-hour strip: hour * 2 (+1 if it came from her).
        var timeline: [Int]? = nil
        var mineToday: Int? = nil
        var hersToday: Int? = nil
    }

    /// Display name of the person who sent the love.
    var senderName: String
}

/// "12 days until we see each other" — a countdown that lives in the Dynamic Island.
struct CountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var meetDate: Date
    }
    var partnerName: String
    var startDate: Date
}
