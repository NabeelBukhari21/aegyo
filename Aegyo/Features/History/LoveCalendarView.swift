import SwiftUI

/// A month of you two: love dots per day, the anniversary, the next meet-up, full moons. Tap a day for its moments.
struct LoveCalendarView: View {
    @EnvironmentObject private var love: LoveService
    @State private var month: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var selected: Date? = Calendar.current.startOfDay(for: .now)
    private let cal = Calendar.current

    private var cells: [Date?] {
        let range = cal.range(of: .day, in: .month, for: month)!
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: month)! }
    }

    private func marks(_ d: Date) -> (anniversary: Bool, meet: Bool, fullMoon: Bool) {
        let anniv = Profile.togetherSince.map { cal.component(.month, from: $0) == cal.component(.month, from: d) && cal.component(.day, from: $0) == cal.component(.day, from: d) && d >= cal.startOfDay(for: $0) } ?? false
        let meet = Profile.meetDate.map { cal.isDate($0, inSameDayAs: d) } ?? false
        let p = Astro.moonPhase(cal.date(bySettingHour: 20, minute: 0, second: 0, of: d) ?? d)
        return (anniv, meet, abs(p - 0.5) < 0.017)
    }

    var body: some View {
        FeatureSheet(title: "Calendar", subtitle: "Your months, marked with love.") {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36).background(.white.opacity(0.08), in: Circle()) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36).background(.white.opacity(0.08), in: Circle()) }
            }
            .foregroundStyle(.white)
            .buttonStyle(PressStyle())

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(cal.veryShortWeekdaySymbols, id: \.self) { s in
                        Text(s).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                        if let d { dayCell(d) } else { Color.clear.frame(height: 50) }
                    }
                }
            }
            .padding(12).glass(24)

            legend

            if let selected {
                let items = love.data.events.filter { cal.isDate($0.date, inSameDayAs: selected) }.sorted { $0.date > $1.date }
                VStack(alignment: .leading, spacing: 8) {
                    CapsLabel(text: selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).padding(.leading, 4)
                    if items.isEmpty {
                        Text(selected > .now ? "Not yet. Something to look forward to." : "A quiet day.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 4)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(items) { e in
                                TimelineRow(event: e, who: e.outgoing ? Profile.myName : partnerName)
                                if e.id != items.last?.id { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 60) }
                            }
                        }
                        .glass(22)
                    }
                }
                .id(selected)
                .transition(.opacity)
            }
        }
    }

    private func dayCell(_ d: Date) -> some View {
        let n = love.loveCount(on: d)
        let m = marks(d)
        let isToday = cal.isDateInToday(d)
        let isSel = selected.map { cal.isDate($0, inSameDayAs: d) } ?? false
        return Button {
            Haptics.tick()
            withAnimation(.snappy) { selected = cal.startOfDay(for: d) }
        } label: {
            VStack(spacing: 3) {
                Text(d.formatted(.dateTime.day())).font(.system(size: 14, weight: isToday ? .bold : .medium)).foregroundStyle(d > .now ? .white.opacity(0.35) : .white)
                HStack(spacing: 2) {
                    if n > 0 { Circle().fill(Love.pink).frame(width: 5, height: 5).opacity(0.5 + min(0.5, Double(n) / 8)) }
                    if m.anniversary { Image(systemName: "heart.fill").font(.system(size: 6)).foregroundStyle(Opal.mint) }
                    if m.meet { Image(systemName: "airplane").font(.system(size: 6)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4)) }
                    if m.fullMoon { Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5) }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isSel ? Color.white.opacity(0.12) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isToday ? Love.pink.opacity(0.7) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(d.formatted(.dateTime.month().day())), \(n) moments")
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) { Circle().fill(Love.pink).frame(width: 6, height: 6); Text("Love") }
            HStack(spacing: 5) { Image(systemName: "heart.fill").font(.system(size: 7)).foregroundStyle(Opal.mint); Text("Anniversary") }
            HStack(spacing: 5) { Image(systemName: "airplane").font(.system(size: 7)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4)); Text("Meet-up") }
            HStack(spacing: 5) { Circle().fill(.white.opacity(0.8)).frame(width: 6, height: 6); Text("Full moon") }
        }
        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
        .frame(maxWidth: .infinity)
    }

    private var partnerName: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "Them" : n.capitalized(with: nil)
    }

    private func shift(_ by: Int) {
        Haptics.tick()
        withAnimation(.snappy) { month = cal.date(byAdding: .month, value: by, to: month)! }
    }
}
