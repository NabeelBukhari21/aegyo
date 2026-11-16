import Foundation
import UIKit

/// User preferences that other services read (sounds, haptics, effects, privacy, Doki's name).
enum Prefs {
    private static var d: UserDefaults { AppGroup.defaults }

    static let soundsKey = "pref.sounds"
    static let hapticsKey = "pref.haptics"
    static let reduceEffectsKey = "pref.reduceEffects"
    static let dokiNameKey = "pref.dokiName"
    static let shareCityKey = "pref.shareCity"
    static let shareMoodKey = "pref.shareMood"
    static let analyticsKey = "pref.analytics"
    static let chimeKey = "pref.chime"

    static var soundsEnabled: Bool { d.object(forKey: soundsKey) as? Bool ?? true }
    static var hapticsEnabled: Bool { d.object(forKey: hapticsKey) as? Bool ?? true }
    static var reduceEffects: Bool { d.bool(forKey: reduceEffectsKey) || UIAccessibility.isReduceMotionEnabled }
    static var shareCity: Bool { d.object(forKey: shareCityKey) as? Bool ?? true }
    static var shareMood: Bool { d.object(forKey: shareMoodKey) as? Bool ?? true }
    static var analytics: Bool { d.object(forKey: analyticsKey) as? Bool ?? false }

    /// Which chime plays when love arrives ("missyou" is the singing bowl).
    static var chime: String { d.string(forKey: chimeKey) ?? "missyou" }

    static var dokiName: String {
        let n = d.string(forKey: dokiNameKey) ?? ""
        return n.isEmpty ? "Doki" : n
    }
}
