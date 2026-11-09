import Foundation

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, loving, sleepy, cozy, excited, busy, stressed, sad
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .happy: "sun.max"
        case .loving: "heart"
        case .sleepy: "moon.zzz"
        case .cozy: "cup.and.saucer"
        case .excited: "sparkles"
        case .busy: "briefcase"
        case .stressed: "bolt"
        case .sad: "cloud.rain"
        }
    }
}

