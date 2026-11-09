import SwiftUI

/// This week as a row of moons: the more love you two shared that day, the fuller the moon.
struct MoonWeek: View {
    @EnvironmentObject private var love: LoveService
    @State private var selected: Date?

    private var days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: .now) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CapsLabel(text: "Last 7 days")
                Spacer()
                if let selected {
                    CapsLabel(text: "\(selected.formatted(.dateTime.weekday(.wide))) · \(love.loveCount(on: selected)) moments")
                        .transition(.opacity)
                } else {
                    CapsLabel(text: "Full moon = 8 moments")
                }
            }
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let future = day > .now && !isToday
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { selected = selected == day ? nil : day }
                    } label: {
                        VStack(spacing: 7) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                .font(.system(size: 9.5, weight: .medium)).tracking(0.6)
                                .foregroundStyle(.white.opacity(0.5))
                            MoonPhase(fill: future ? 0 : min(1, Double(love.loveCount(on: day)) / 8), size: 22)
                                .opacity(future ? 0.35 : 1)
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isToday {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white.opacity(0.09))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .overlay(alignment: .top) {
                            if isToday { TwinkleStar().offset(y: -7) }
                        }
                    }
                    .buttonStyle(PressStyle(scale: 0.92))
                    .disabled(future)
                }
            }
            .padding(6)
            .glass(20)
        }
    }
}

/// A moon whose lit portion is `fill` (0 = new, 1 = full). The lit side sweeps in like a waxing moon.
struct MoonPhase: View {
    var fill: Double
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.96, green: 0.95, blue: 1), Color(red: 0.73, green: 0.75, blue: 0.86), Color(red: 0.44, green: 0.46, blue: 0.6)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            Circle()
                .fill(Color(red: 0.05, green: 0.06, blue: 0.1))
                .offset(x: -size * CGFloat(fill) * 1.02)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .white.opacity(fill > 0.9 ? 0.35 : 0), radius: 6)
        .animation(.smooth(duration: 0.8), value: fill)
    }
}

struct TwinkleStar: View {
    @State private var on = false
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Opal.mint)
            .scaleEffect(on ? 1 : 0.6)
            .opacity(on ? 1 : 0.4)
            .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { on = true } }
    }
}
