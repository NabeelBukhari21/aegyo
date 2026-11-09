import SwiftUI

/// Sky: a 3D moon showing tonight's real phase, your star signs, and the Same Sky distance between you.
struct SkyTab: View {
    @EnvironmentObject private var love: LoveService
    enum Section: Hashable { case moon, stars, sameSky }
    @State private var section: Section = .moon
    @State private var moonKiss = 0
    @State private var sparkles: [UUID] = []
    @State private var toast: String?

    @State private var night = 0
    private var nightDate: Date { Calendar.current.date(byAdding: .day, value: night, to: .now)! }
    private var phase: Double { Astro.moonPhase(nightDate) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                PillSegmented(options: [(.moon, "Moon"), (.stars, "Stars"), (.sameSky, "Same Sky")], selection: $section)
                Group {
                    switch section {
                    case .moon: MoonSection(phase: phase).transition(.blurReplace.combined(with: .move(edge: .leading)))
                    case .stars: StarsSection().transition(.blurReplace)
                    case .sameSky: SameSkyPremium().transition(.blurReplace.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: section)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.09), .black], startPoint: .top, endPoint: .bottom)
                StarField(density: 110)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12).glass(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 4) {
            CapsLabel(text: "\(night == 0 ? "Tonight" : nightDate.formatted(.dateTime.weekday(.wide).month().day())) · \(Int((Astro.illumination(nightDate) * 100).rounded()))% lit · Moon in \(Astro.moonSign(nightDate).name)")
                .padding(.top, 8)
                .contentTransition(.interpolate)
            Text(Astro.phaseName(phase))
                .font(.system(size: 32, weight: .semibold)).tracking(-1)
                .foregroundStyle(.white)
                .contentTransition(.interpolate)
                .animation(.snappy, value: Astro.phaseName(phase))
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.6, green: 0.65, blue: 1).opacity(0.28), .clear], center: .center, startRadius: 60, endRadius: 170))
                    .frame(width: 340, height: 340)
                Moon3DView(phase: phase, spinBoost: moonKiss)
                    .frame(width: 280, height: 280)
                    .onTapGesture { kiss() }
                ForEach(sparkles, id: \.self) { _ in MoonSparkle() }
            }
            .frame(height: 300)
            TickScrubber(index: $night, count: 30) { i in
                let d = Calendar.current.date(byAdding: .day, value: i, to: .now)!
                return i == 0 ? "Tonight · \(Int((Astro.illumination(d) * 100).rounded()))%" : "\(d.formatted(.dateTime.month(.abbreviated).day())) · \(Int((Astro.illumination(d) * 100).rounded()))%"
            }
            .padding(.horizontal, 4)
            Text("Drag the moon to spin it · tap it to send a moon kiss · scrub to see any night")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    private func kiss() {
        Haptics.gemPress()
        moonKiss += 1
        let id = UUID()
        sparkles.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { sparkles.removeAll { $0 == id } }
        love.playSentChime()
        Task { await love.send(.thinkingOfYou) }
        withAnimation(.spring) { toast = "Moon kiss sent" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { toast = nil } }
    }
}

/// Gold sparkles that burst off the moon.
private struct MoonSparkle: View {
    @State private var go = false
    private let angles = (0..<14).map { _ in Double.random(in: 0..<(2 * .pi)) }
    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat(8 + i % 3 * 4)))
                    .foregroundStyle(i % 2 == 0 ? Color(red: 1, green: 0.85, blue: 0.5) : .white)
                    .offset(x: go ? cos(angles[i]) * 170 : 0, y: go ? sin(angles[i]) * 170 : 0)
                    .scaleEffect(go ? 0.3 : 1.2)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.4)) { go = true } }
        .allowsHitTesting(false)
    }
}

// MARK: - Moon

private struct MoonSection: View {
    let phase: Double
    @EnvironmentObject private var love: LoveService

    var body: some View {
        VStack(spacing: 14) {
            Card(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    CapsLabel(text: "The next 7 nights")
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { d in
                            let date = Calendar.current.date(byAdding: .day, value: d, to: .now)!
                            let p = Astro.moonPhase(date)
                            VStack(spacing: 8) {
                                Text(d == 0 ? "TONIGHT" : date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(.system(size: 9, weight: .medium)).tracking(0.5)
                                    .foregroundStyle(.white.opacity(d == 0 ? 0.9 : 0.5))
                                RealPhase(phase: p, size: 26)
                                Text("\(Int((Astro.illumination(date) * 100).rounded()))%")
                                    .font(.system(size: 11, weight: .medium)).monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                countdownTile("Full moon", Astro.nextPhase(0.5), "Watch it together")
                countdownTile("New moon", Astro.nextPhase(0.0), "Darkest sky for stars")
            }

            MoonWeek()
        }
    }

    private func countdownTile(_ title: String, _ date: Date, _ line: String) -> some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if days == 0 {
                    Text("Tonight").font(.system(size: 30, weight: .light))
                } else {
                    Text("\(days)").font(.system(size: 34, weight: .light)).monospacedDigit()
                    Text(days == 1 ? "day" : "days").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .foregroundStyle(.white)
            Text(line).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(22)
    }
}

/// A small moon disc lit like the real phase (waxing = right side lit).
struct RealPhase: View {
    var phase: Double
    var size: CGFloat
    var body: some View {
        Canvas { g, s in
            let r = s.width / 2
            let c = CGPoint(x: r, y: r)
            g.fill(Path(ellipseIn: CGRect(origin: .zero, size: s)), with: .color(Color(white: 0.12)))
            let k = cos(2 * .pi * phase)            // +1 new … -1 full
            let side: CGFloat = phase < 0.5 ? 1 : -1  // waxing: lit on the right
            let ex = r * CGFloat(abs(k))
            let bulge: CGFloat = k > 0 ? 1 : -1       // crescent bulges toward the lit side
            var lit = Path()
            let steps = 48
            for i in 0...steps { // lit limb, top → bottom
                let th = -Double.pi / 2 + Double(i) / Double(steps) * .pi
                let pt = CGPoint(x: c.x + side * r * CGFloat(cos(th)), y: c.y + r * CGFloat(sin(th)))
                i == 0 ? lit.move(to: pt) : lit.addLine(to: pt)
            }
            for i in 0...steps { // terminator, bottom → top
                let th = Double.pi / 2 - Double(i) / Double(steps) * .pi
                lit.addLine(to: CGPoint(x: c.x + side * bulge * ex * CGFloat(cos(th)), y: c.y + r * CGFloat(sin(th))))
            }
            lit.closeSubpath()
            g.fill(lit, with: .radialGradient(Gradient(colors: [Color(white: 0.97), Color(white: 0.7)]),
                                              center: CGPoint(x: r * 0.8, y: r * 0.7), startRadius: 0, endRadius: r * 1.3))
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(Astro.illumination() > 0.9 ? 0.3 : 0.1), radius: 4)
    }
}

// MARK: - Stars

private struct StarsSection: View {
    @AppStorage(Profile.myBirthdayKey, store: AppGroup.defaults) private var myBirthday: Double = 0
    @AppStorage(Profile.herBirthdayKey, store: AppGroup.defaults) private var herBirthday: Double = 0
    @State private var editing = false

    private var mine: Zodiac? { myBirthday > 0 ? Zodiac.from(Date(timeIntervalSince1970: myBirthday)) : nil }
    private var hers: Zodiac? { herBirthday > 0 ? Zodiac.from(Date(timeIntervalSince1970: herBirthday)) : nil }

    var body: some View {
        VStack(spacing: 14) {
            if let mine, let hers {
                HStack(spacing: 10) {
                    signCard(mine, owner: "You")
                    signCard(hers, owner: Profile.partnerName.capitalized(with: nil))
                }
                Card(padding: 20) {
                    HStack(spacing: 18) {
                        MatchRing(value: mine.match(with: hers))
                        VStack(alignment: .leading, spacing: 4) {
                            CapsLabel(text: "\(mine.name) × \(hers.name)")
                            Text(mine.element == hers.element ? "Same element, same rhythm." : "Different elements, magnetic pull.")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text("\(mine.element.rawValue.capitalized) meets \(hers.element.rawValue)")
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                Card(padding: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        CapsLabel(text: "Today's love forecast")
                        Text(LoveForecast.today(mine, hers))
                            .font(.system(size: 19, weight: .semibold)).tracking(-0.3)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Moon in \(Astro.moonSign().name) · \(Astro.phaseName(Astro.moonPhase()))")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                Button { editing = true } label: {
                    Text("Change birthdays").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                }
            } else {
                Card(padding: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.5))
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text("What do the stars say about you two?").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        Text("Add both birthdays for your signs, constellations, compatibility and a daily love forecast.")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        Button { editing = true } label: {
                            WhitePill(title: "Add birthdays", systemImage: "gift", height: 50).frame(maxWidth: .infinity).background(.white, in: Capsule())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $editing) {
            BirthdaySheet(myBirthday: $myBirthday, herBirthday: $herBirthday).aegyoSheet([.medium])
        }
    }

    private func signCard(_ z: Zodiac, owner: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ConstellationView(sign: z).frame(height: 110)
            CapsLabel(text: owner)
            HStack(spacing: 6) {
                Text(z.symbol).font(.system(size: 18))
                Text(z.name).font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(.white)
            Text(z.trait).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(22)
    }
}

/// Stars appear one by one, then the lines draw between them; the brightest twinkle.
struct ConstellationView: View {
    let sign: Zodiac
    @State private var draw: CGFloat = 0

    var body: some View {
        let c = sign.constellation
        GeometryReader { geo in
            let pts = c.stars.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
            ZStack {
                Path { p in for (a, b) in c.lines { p.move(to: pts[a]); p.addLine(to: pts[b]) } }
                    .trim(from: 0, to: draw)
                    .stroke(Color(red: 1, green: 0.85, blue: 0.55).opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(Array(pts.enumerated()), id: \.offset) { i, p in
                            Circle().fill(.white)
                                .frame(width: i % 3 == 0 ? 6 : 4, height: i % 3 == 0 ? 6 : 4)
                                .shadow(color: Color(red: 1, green: 0.85, blue: 0.55), radius: 5)
                                .opacity(draw > CGFloat(i) / CGFloat(pts.count) ? 0.6 + 0.4 * sin(t * 2 + Double(i)) : 0)
                                .position(p)
                        }
                    }
                }
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.8)) { draw = 1 } }
    }
}

/// Animated compatibility ring that counts up.
struct MatchRing: View {
    let value: Int
    @State private var shown: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 8)
            Circle().trim(from: 0, to: shown / 100)
                .stroke(Love.glow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Love.pink.opacity(0.5), radius: 8)
            Text("\(Int(shown))%").font(.system(size: 20, weight: .semibold)).monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: shown))
        }
        .frame(width: 84, height: 84)
        .onAppear { withAnimation(.spring(response: 1.6, dampingFraction: 0.9).delay(0.2)) { shown = Double(value) } }
    }
}

private struct BirthdaySheet: View {
    @Binding var myBirthday: Double
    @Binding var herBirthday: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            SectionHeader(title: "Your birthdays", subtitle: "Only the day and month matter for your signs.")
            row("Yours", $myBirthday)
            row(Profile.partnerName.capitalized(with: nil) + "'s", $herBirthday)
            Spacer()
            Button { Haptics.success(); dismiss() } label: {
                WhitePill(title: "Read the stars", systemImage: "sparkles", height: 52).frame(maxWidth: .infinity).background(.white, in: Capsule())
            }
            .buttonStyle(PressStyle())
        }
        .padding(22)
    }
    private func row(_ label: String, _ v: Binding<Double>) -> some View {
        HStack {
            Text(label).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: Binding(get: { v.wrappedValue > 0 ? Date(timeIntervalSince1970: v.wrappedValue) : Calendar.current.date(byAdding: .year, value: -24, to: .now)! },
                                              set: { v.wrappedValue = $0.timeIntervalSince1970; Haptics.tick() }),
                       in: ...Date.now, displayedComponents: .date)
                .labelsHidden().tint(Love.pink)
        }
        .padding(16).glass(20)
    }
}
