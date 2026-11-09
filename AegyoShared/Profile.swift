import Foundation
import UIKit

/// Shared storage between the app and the widget extension (App Group).
/// Note: with a free Personal Team there is no App Group, so the widget can't see the app's files;
/// everything still works inside the app.
enum AppGroup {
    static let id = "group.com.nabeelbukhari.aegyo"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }

    /// Shared folder for photo thumbnails (nil without the App Group entitlement).
    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static func photoURL(_ id: String) -> URL? {
        container?.appendingPathComponent("Photos", isDirectory: true).appendingPathComponent("\(id).jpg")
    }

    static func loadPhoto(_ id: String?) -> UIImage? {
        guard let id, let url = photoURL(id) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

enum Profile {
    static let myNameKey = "myName"
    static let partnerNameKey = "partnerName"
    static let togetherSinceKey = "togetherSince"
    static let myCityKey = "myCity"
    static let partnerCityKey = "partnerCity"
    static let meetDateKey = "meetDate"
    static let myBirthdayKey = "myBirthday"
    static let herBirthdayKey = "herBirthday"
    static let defaultMyName = "Nabeel"
    static let defaultPartnerName = "her"

    static var myName: String {
        let v = AppGroup.defaults.string(forKey: myNameKey) ?? ""
        return v.isEmpty ? defaultMyName : v
    }

    static var partnerName: String {
        let v = AppGroup.defaults.string(forKey: partnerNameKey) ?? ""
        return v.isEmpty ? defaultPartnerName : v
    }

    /// The day you got together (nil until set in Settings).
    static var togetherSince: Date? {
        let v = AppGroup.defaults.double(forKey: togetherSinceKey)
        return v > 0 ? Date(timeIntervalSince1970: v) : nil
    }

    /// The next time you'll see each other (nil until set).
    static var meetDate: Date? {
        let v = AppGroup.defaults.double(forKey: meetDateKey)
        return v > 0 ? Date(timeIntervalSince1970: v) : nil
    }
}
