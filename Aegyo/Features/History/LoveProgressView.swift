import Charts
import SwiftUI

/// Progress (The Outsiders style): a coloured hero with one big number and a plain-language insight,
/// then charts for the period: love per day, when you miss them most, and streaks.
struct LoveProgressView: View {
    @EnvironmentObject private var love: LoveService
    enum Period: Hashable { case week, month, halfYear }
    @State private var period: Period = .month

    private var days: Int { period == .week ? 7 : period == .month ? 28 : 182 }

    private var series: [(Date, Int, Int)] { // day, mine, theirs
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(days - 1), to: .now)!)
        var buckets: [Date: (Int, Int)] = [:]
        for e in love.data.events where e.kind.countsAsLove && e.date >= start {
            let d = cal.startOfDay(for: e.date)
            var b = buckets[d] ?? (0, 0)
            if e.outgoing { b.0 += 1 } else { b.1 += 1 }
            buckets[d] = b
        }
        return (0..<days).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let b = buckets[d] ?? (0, 0)
            return (d, b.0, b.1)
        }
    }

    private var hours: [Int] {
        var h = [Int](repeating: 0, count: 24)
        for e in love.data.events where e.kind.countsAsLove && e.outgoing { h[Calendar.current.component(.hour, from: e.date)] += 1 }
        return h
    }

    private var total: Int { series.reduce(0) { $0 + $1.1 + $1.2 } }
    private var mine: Int { series.reduce(0) { $0 + $1.1 } }
    private var activeDays: Int { series.filter { $0.1 + $0.2 > 0 }.count }

    var body: some View {
        FeatureSheet(title: "Progress", subtitle: "How your love shows up, day by day.") {
            PillSegmented(options: [(.week, "7 days"), (.month, "4 weeks"), (.halfYear, "6 months")], selection: $period)

            hero

            if total == 0 {
                EmptyState(icon: "chart.bar", title: "No data for this period", message: "Send a little love and the charts fill in.")
            } else {
                Card(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { CapsLabel(text: "Love per day"); Spacer(); legend }
                        Chart {
                            ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                                BarMark(x: .value("Day", s.0, unit: .day), y: .value("You", s.1)).foregroundStyle(Love.pink)
                                BarMark(x: .value("Day", s.0, unit: .day), y: .value("Them", s.2)).foregroundStyle(Love.violet)
                            }
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 5)) { v in
                            AxisValueLabel(format: period == .halfYear ? .dateTime.month(.abbreviated) : .dateTime.day()).foregroundStyle(.white.opacity(0.45))
                        } }
                        .chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel().foregroundStyle(.white.opacity(0.45)) } }
                        .frame(height: 170)
                    }
                }

                Card(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        CapsLabel(text: "When you miss them most")
                        HourHeatmap(hours: hours)
                        if let peak = love.peakHour {
                            Text("Your peak is around \(hourText(peak)). \(peak >= 21 || peak < 5 ? "Night owl." : peak < 11 ? "Morning person." : "Afternoons are for missing.")")
                                .font(.aegyo(13)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }

                HStack(spacing: 10) {
                    tile("\(love.streakDays)", "Current streak", "flame.fill", Love.pink)
                    tile("\(love.longestStreak)", "Longest streak", "trophy.fill", Color(red: 1, green: 0.85, blue: 0.4))
                    tile("\(activeDays)/\(days)", "Days with love", "calendar", Opal.mint)
                }
            }
        }
    }

    private var hero: some View {
        let tone: (Color, String, String) = {
            if total == 0 { return (Color(white: 0.3), "Quiet", "Nothing sent in this period yet.") }
            let perDay = Double(total) / Double(days)
            if perDay >= 3 { return (Color(red: 0.2, green: 0.8, blue: 0.5), "Glowing", "You two are in constant touch. \(mine) from you, \(total - mine) from them.") }
            if perDay >= 1 { return (Love.pink, "Warm", "Love most days. \(mine) from you, \(total - mine) from them.") }
            return (Color(red: 1, green: 0.65, blue: 0.3), "Flickering", "A few moments. One tap a day keeps the streak alive.")
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(total)").font(.aegyo(54, .bold)).tracking(-2).monospacedDigit().contentTransition(.numericText(value: Double(total)))
                Text("moments").font(.aegyo(16, .medium)).foregroundStyle(.white.opacity(0.7))
            }
            Text(tone.1).font(.aegyo(20, .semibold))
            Text(tone.2).font(.aegyo(14)).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [tone.0.opacity(0.55), tone.0.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(tone.0.opacity(0.4), lineWidth: 1))
        .animation(.smooth, value: total)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) { Circle().fill(Love.pink).frame(width: 7, height: 7); Text("You") }
            HStack(spacing: 4) { Circle().fill(Love.violet).frame(width: 7, height: 7); Text("Them") }
        }
        .font(.aegyo(11)).foregroundStyle(.white.opacity(0.55))
    }

    private func tile(_ v: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.aegyo(14, .semibold)).foregroundStyle(tint)
            Text(v).font(.aegyo(22, .bold)).monospacedDigit().foregroundStyle(.white)
            Text(label).font(.aegyo(11)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(20)
    }

    private func hourText(_ h: Int) -> String {
        (Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now) ?? .now).formatted(.dateTime.hour())
    }
}

/// 24 cells, brighter the more you reached out at that hour.
struct HourHeatmap: View {
    let hours: [Int]
    var body: some View {
        let mx = max(1, hours.max() ?? 1)
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Love.pink.opacity(0.1 + 0.9 * Double(hours[h]) / Double(mx)))
                        .frame(height: 28)
                        .accessibilityLabel("\(h):00, \(hours[h]) moments")
                }
            }
            HStack {
                ForEach(["12am", "6am", "12pm", "6pm", "11pm"], id: \.self) { t in
                    Text(t).font(.aegyo(10)).foregroundStyle(.white.opacity(0.4))
                    if t != "11pm" { Spacer() }
                }
            }
        }
    }
}
