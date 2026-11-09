import SwiftUI

/// "When will you see her?" — a rotary dial (Airbnb), the moon on that night (moon-scrubber reference),
/// time of day, and slide to lock it in.
struct MeetDatePicker: View {
    @Binding var date: Double
    @Environment(\.dismiss) private var dismiss

    enum Unit: Hashable { case days, weeks, months }
    @State private var unit: Unit = .days
    @State private var amount: Int = 7
    @State private var hour = 18
    @State private var exact = false
    @State private var exactDate = Date.now.addingTimeInterval(86400 * 7)

    private let cal = Calendar.current
    private var maxAmount: Int { unit == .days ? 60 : unit == .weeks ? 26 : 12 }

    private var target: Date {
        if exact { return cal.startOfDay(for: exactDate) }
        let comp: Calendar.Component = unit == .days ? .day : unit == .weeks ? .weekOfYear : .month
        return cal.startOfDay(for: cal.date(byAdding: comp, value: amount, to: .now)!)
    }

    var body: some View {
        ZStack {
            SheetGlow(color: Love.pink).opacity(0.6)
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text("When will you\nsee her?").font(.system(size: 30, weight: .semibold)).tracking(-1).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.top, 24)

                    PillSegmented(options: [(.days, "Days"), (.weeks, "Weeks"), (.months, "Months")], selection: Binding(
                        get: { unit },
                        set: { u in unit = u; amount = min(amount, u == .days ? 60 : u == .weeks ? 26 : 12); exact = false }))

                    Dial(amount: $amount, max: maxAmount, unitLabel: unitLabel)
                        .frame(height: 290)
                        .opacity(exact ? 0.35 : 1)
                        .disabled(exact)
                        .onChange(of: amount) { exact = false }

                    // the range, underlined like the reference
                    HStack(spacing: 8) {
                        Text("Today").underline()
                        Text("to").foregroundStyle(.white.opacity(0.5))
                        Text(target.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).underline()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.interpolate)
                    .animation(.snappy, value: target)

                    // the moon that night
                    let phase = Astro.moonPhase(target.addingTimeInterval(Double(hour) * 3600))
                    HStack(spacing: 10) {
                        RealPhase(phase: phase, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Astro.phaseName(phase)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            Text("\(Int((Astro.illumination(target) * 100).rounded()))% lit that night").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                    .animation(.snappy, value: target)

                    timeRow

                    Button {
                        Haptics.tap()
                        withAnimation(.spring) { exact.toggle() }
                    } label: {
                        Label(exact ? "Use the dial" : "Pick an exact date", systemImage: exact ? "dial.low" : "calendar")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                    }
                    if exact {
                        DatePicker("", selection: $exactDate, in: Date.now..., displayedComponents: .date)
                            .datePickerStyle(.graphical).tint(Love.pink)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .onChange(of: exactDate) { Haptics.tick() }
                    }

                    SlideToConfirm(title: "Slide to lock it in", systemImage: "heart.fill", style: .glow) {
                        date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: target)!.timeIntervalSince1970
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { dismiss() }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if date > 0 {
                let d = Date(timeIntervalSince1970: date)
                let days = max(1, cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 7)
                if days <= 60 { unit = .days; amount = days } else { unit = .weeks; amount = min(26, days / 7) }
                hour = cal.component(.hour, from: d)
            }
        }
    }

    private var unitLabel: String {
        switch unit {
        case .days: amount == 1 ? "day" : "days"
        case .weeks: amount == 1 ? "week" : "weeks"
        case .months: amount == 1 ? "month" : "months"
        }
    }

    private var timeRow: some View {
        let options = [(9, "Morning", "sun.horizon"), (13, "Afternoon", "sun.max"), (18, "Evening", "sunset"), (22, "Night", "moon.stars")]
        return HStack(spacing: 8) {
            ForEach(options, id: \.0) { h, label, icon in
                Button {
                    Haptics.tick()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { hour = h }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: icon).font(.system(size: 16)).symbolEffect(.bounce, value: hour == h)
                        Text(label).font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(hour == h ? .black : .white.opacity(0.7))
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(hour == h ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.06)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}

/// The rotary dial: drag the knob around, the arc glows, the number counts.
private struct Dial: View {
    @Binding var amount: Int
    var max: Int
    var unitLabel: String

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2 - 22
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let frac = Double(amount) / Double(max)
            let angle = Angle.degrees(frac * 360 - 90)
            ZStack {
                // soft well
                Circle().fill(RadialGradient(colors: [Color(white: 0.14), Color(white: 0.06)], center: .center, startRadius: 0, endRadius: r + 22))
                    .frame(width: (r + 22) * 2, height: (r + 22) * 2)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                // ticks
                ForEach(0..<12, id: \.self) { i in
                    Circle().fill(.white.opacity(0.3)).frame(width: 4, height: 4)
                        .offset(y: -(r - 30))
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                // glowing arc
                Circle().trim(from: 0, to: frac)
                    .stroke(AngularGradient(colors: [Color(red: 1, green: 0.4, blue: 0.55), Love.pink, Color(red: 0.75, green: 0.3, blue: 0.9)], center: .center),
                            style: StrokeStyle(lineWidth: 38, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: r * 2, height: r * 2)
                    .shadow(color: Love.pink.opacity(0.6), radius: 16)
                // inner disc with the number
                Circle().fill(Color(white: 0.1)).frame(width: (r - 46) * 2, height: (r - 46) * 2)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                VStack(spacing: 0) {
                    Text("\(amount)").font(.system(size: 64, weight: .bold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(amount)))
                    Text(unitLabel).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .animation(.snappy(duration: 0.2), value: amount)
                // knob
                Circle().fill(.white)
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .overlay(Circle().stroke(Color(white: 0.85), lineWidth: 1))
                    .offset(x: r * CGFloat(cos(angle.radians)), y: r * CGFloat(sin(angle.radians)))
            }
            .position(c)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let dx = g.location.x - c.x, dy = g.location.y - c.y
                var a = atan2(dy, dx) * 180 / .pi + 90
                if a < 0 { a += 360 }
                let v = Swift.max(1, Swift.min(max, Int((a / 360 * Double(max)).rounded())))
                // don't jump across the top seam
                if abs(v - amount) > max / 2 { return }
                if v != amount { Haptics.tick(); amount = v }
            })
        }
    }
}
