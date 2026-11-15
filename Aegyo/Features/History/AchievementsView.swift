import SwiftUI

/// Badges for days together and love sent. Locked ones show what unlocks them.
struct AchievementsView: View {
    @EnvironmentObject private var love: LoveService

    struct Badge: Identifiable {
        let id: String, title: String, line: String, icon: String, tint: Color, unlocked: Bool, progress: Double
    }

    private var daysTogether: Int {
        Profile.togetherSince.map { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: .now)).day ?? 0 } ?? 0
    }

    private var badges: [Badge] {
        let total = love.totalSent + love.totalReceived
        let photos = love.data.photos.count
        let letters = love.data.letters.count
        var b: [Badge] = []
        for m in [7, 30, 100, 365, 730, 1000] {
            b.append(Badge(id: "d\(m)", title: m == 365 ? "One year" : m == 730 ? "Two years" : "Day \(m)", line: "\(m) days together", icon: "flag.checkered", tint: Opal.mint,
                           unlocked: daysTogether >= m, progress: min(1, Double(daysTogether) / Double(m))))
        }
        for (n, name) in [(1, "First heartbeat"), (10, "Ten taps"), (50, "Rose Quartz"), (150, "Moonstone"), (400, "Aurora"), (1000, "Diamond")] {
            b.append(Badge(id: "l\(n)", title: name, line: "\(n) moments shared", icon: "heart.fill", tint: Love.pink, unlocked: total >= n, progress: min(1, Double(total) / Double(n))))
        }
        b.append(Badge(id: "streak7", title: "Seven in a row", line: "A 7-day streak", icon: "flame.fill", tint: Color(red: 1, green: 0.6, blue: 0.3), unlocked: love.longestStreak >= 7, progress: min(1, Double(love.longestStreak) / 7)))
        b.append(Badge(id: "streak30", title: "Thirty in a row", line: "A 30-day streak", icon: "flame.fill", tint: Color(red: 1, green: 0.45, blue: 0.3), unlocked: love.longestStreak >= 30, progress: min(1, Double(love.longestStreak) / 30)))
        b.append(Badge(id: "photo", title: "Say cheese", line: "First photo sent", icon: "camera.fill", tint: Color(red: 0.6, green: 0.8, blue: 1), unlocked: photos >= 1, progress: min(1, Double(photos))))
        b.append(Badge(id: "letter", title: "Sealed with Doki", line: "First Open-When letter", icon: "envelope.fill", tint: Love.peach, unlocked: letters >= 1, progress: min(1, Double(letters))))
        b.append(Badge(id: "night", title: "Night owl", line: "Love sent after midnight", icon: "moon.stars.fill", tint: Love.violet,
                       unlocked: love.data.events.contains { $0.outgoing && Calendar.current.component(.hour, from: $0.date) < 5 }, progress: 0))
        b.append(Badge(id: "early", title: "Early bird", line: "Love sent before 7am", icon: "sunrise.fill", tint: Color(red: 1, green: 0.8, blue: 0.4),
                       unlocked: love.data.events.contains { $0.outgoing && (5..<7).contains(Calendar.current.component(.hour, from: $0.date)) }, progress: 0))
        return b
    }

    var body: some View {
        let all = badges
        let n = all.filter(\.unlocked).count
        FeatureSheet(title: "Achievements", subtitle: "\(n) of \(all.count) unlocked.") {
            ProgressBar(value: Double(n) / Double(all.count))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(all) { b in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(b.unlocked ? b.tint.opacity(0.18) : .white.opacity(0.05)).frame(width: 54, height: 54)
                            if !b.unlocked && b.progress > 0 {
                                Circle().trim(from: 0, to: b.progress).stroke(b.tint.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90)).frame(width: 54, height: 54)
                            }
                            Image(systemName: b.unlocked ? b.icon : "lock.fill").font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(b.unlocked ? b.tint : .white.opacity(0.3))
                        }
                        .shadow(color: b.unlocked ? b.tint.opacity(0.5) : .clear, radius: 10)
                        Text(b.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(b.unlocked ? .white : .white.opacity(0.5)).multilineTextAlignment(.center).lineLimit(2)
                        Text(b.line).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity).frame(height: 136)
                    .padding(.horizontal, 6)
                    .glass(20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(b.title), \(b.line), \(b.unlocked ? "unlocked" : "locked")")
                }
            }
        }
    }
}
