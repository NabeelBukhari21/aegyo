import Foundation
import UserNotifications

/// The only notifications Aegyo sends: gentle reminders. Everything else lives in the Dynamic Island.
///  • Daily nudge: "You haven't told her you miss her today" (skipped once you've sent love that day)
///  • The day before you meet
///  • Milestone days (100, 365, 500…)
@MainActor
final class Reminders {
    static let shared = Reminders()

    static let nudgeEnabledKey = "nudgeEnabled"
    static let nudgeHourKey = "nudgeHour"
    static let meetEnabledKey = "meetReminderEnabled"
    static let milestoneEnabledKey = "milestoneReminderEnabled"

    private let center = UNUserNotificationCenter.current()
    private var d: UserDefaults { AppGroup.defaults }

    var nudgeEnabled: Bool { d.object(forKey: Self.nudgeEnabledKey) as? Bool ?? true }
    var nudgeHour: Int { d.object(forKey: Self.nudgeHourKey) as? Int ?? 20 }
    var meetEnabled: Bool { d.object(forKey: Self.meetEnabledKey) as? Bool ?? true }
    var milestoneEnabled: Bool { d.object(forKey: Self.milestoneEnabledKey) as? Bool ?? true }

    /// Rebuild every pending reminder for the next week. Call on launch and after settings change.
    func refresh(lovedToday: Bool) {
        center.removeAllPendingNotificationRequests()
        let partner = Profile.partnerName.capitalized(with: nil)
        let cal = Calendar.current

        if nudgeEnabled {
            for offset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: offset, to: .now),
                      let fire = cal.date(bySettingHour: nudgeHour, minute: 0, second: 0, of: day), fire > .now else { continue }
                if offset == 0 && lovedToday { continue }
                schedule(id: "nudge-\(DayKey.of(day))", at: fire,
                         title: "\(partner) hasn't heard from you today",
                         body: ["Tap \(Doki.name) and tell her you miss her.", "One tap. She'll feel it.", "A tiny heartbeat goes a long way."][offset % 3])
            }
        }

        if meetEnabled, let meet = Profile.meetDate,
           let eve = cal.date(byAdding: .day, value: -1, to: meet),
           let fire = cal.date(bySettingHour: 19, minute: 0, second: 0, of: eve), fire > .now {
            schedule(id: "meet-eve", at: fire, title: "Tomorrow you see \(partner)", body: "One more sleep.")
        }

        if milestoneEnabled, let start = Profile.togetherSince {
            for m in MilestonesView.marks {
                guard let day = cal.date(byAdding: .day, value: m, to: start),
                      let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day), fire > .now,
                      fire < .now.addingTimeInterval(86400 * 60) else { continue }
                schedule(id: "milestone-\(m)", at: fire, title: "Day \(m) together", body: "Open Aegyo to celebrate with \(partner).")
            }
        }
    }

    /// You sent love: no need to nudge you today.
    func lovedToday() {
        center.removePendingNotificationRequests(withIdentifiers: ["nudge-\(DayKey.of(.now))"])
    }

    private func schedule(id: String, at date: Date, title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = UNNotificationSound(named: UNNotificationSoundName("sent.caf"))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}
