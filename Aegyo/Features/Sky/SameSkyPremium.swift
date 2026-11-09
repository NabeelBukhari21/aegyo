import SwiftUI

/// Same Sky, premium: both skies side by side (live colours for each local time),
/// distance that counts up, the time gap, a travelling light, and hold-to-send.
struct SameSkyPremium: View {
    @EnvironmentObject private var love: LoveService
    @State private var burstAt: Date?
    @State private var shownKm: Double = 0
    @State private var lastHeld: Double?
    @State private var setup = false

    var body: some View {
        VStack(spacing: 14) {
            if let me = love.data.myPlace, let her = love.data.herPlace {
                HStack(spacing: 10) {
                    SkyWindow(title: "You", place: me)
                    SkyWindow(title: Profile.partnerName.capitalized(with: nil), place: her)
                }
                Card(padding: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            CapsLabel(text: "Between you")
                            Spacer()
                            CapsLabel(text: timeGap(me, her))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Int(shownKm).formatted())
                                .font(.system(size: 60, weight: .ultraLight)).tracking(-3).monospacedDigit()
                                .contentTransition(.numericText(value: shownKm))
                            Text("km").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                        }
                        .foregroundStyle(.white)
                        .padding(.top, 6)

                        TwoLightsArc(burstAt: burstAt)
                            .frame(height: 150)
                            .padding(.top, 4)

                        HStack(spacing: 10) {
                            stat("Lights sent", "\(love.data.events.filter { $0.kind == .light && $0.outgoing }.count)")
                            stat("Received", "\(love.totalReceived)")
                            stat("Last from her", agoText(love.lastReceivedAt))
                        }
                        .padding(.top, 8)

                        HoldToSendButton(title: "Hold to send a light", holdingTitle: "Charging your light…", systemImage: "sparkle", duration: 1.2) { held in
                            lastHeld = held
                            love.playSentChime()
                            Task { await love.send(.light) }
                        }
                        .padding(.top, 18)

                        if let lastHeld {
                            Text("A \(String(format: "%.1f", lastHeld))-second light is on its way to \(her.name).")
                                .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .onAppear {
                    shownKm = 0
                    withAnimation(.spring(response: 1.8, dampingFraction: 1).delay(0.15)) { shownKm = Double(love.distanceKm ?? 0) }
                }
            } else {
                Card(padding: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "globe.asia.australia.fill").font(.system(size: 30)).foregroundStyle(Opal.mint)
                            .symbolEffect(.rotate, options: .repeating)
                        Text("How far is your love travelling?").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        Text("Add your two cities to see both skies, your distance and her local time.")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        Button { setup = true } label: {
                            WhitePill(title: "Add cities", systemImage: "mappin.and.ellipse", height: 50).frame(maxWidth: .infinity).background(.white, in: Capsule())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
        .onChange(of: love.sendPulse) { burstAt = .now }
        .sheet(isPresented: $setup) { SettingsView() }
    }

    private func timeGap(_ a: Place, _ b: Place) -> String {
        let diff = (b.timeZone.secondsFromGMT() - a.timeZone.secondsFromGMT()) / 3600
        if diff == 0 { return "Same time zone" }
        return diff > 0 ? "She's \(diff)h ahead" : "She's \(-diff)h behind"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            CapsLabel(text: label).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 18, weight: .medium)).monospacedDigit().foregroundStyle(.white)
                .contentTransition(.numericText()).animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A little window onto someone's sky right now: colour by local hour, sun or moon on its arc, stars at night.
struct SkyWindow: View {
    let title: String
    let place: Place

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let hour = localHour(ctx.date)
            let night = hour < 6 || hour >= 19.5
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: SkyPalette.colors(hour), startPoint: .top, endPoint: .bottom)
                if night { StarField(density: 26, drift: false).opacity(0.9) }
                GeometryReader { g in
                    // sun 6→18, moon 18→6, both on a gentle arc
                    let p = night ? ((hour >= 18 ? hour - 18 : hour + 6) / 12) : (hour - 6) / 12
                    let x = g.size.width * (0.1 + 0.8 * p)
                    let y = g.size.height * (0.62 - 0.42 * sin(.pi * p))
                    Group {
                        if night {
                            RealPhase(phase: Astro.moonPhase(), size: 22)
                        } else {
                            Circle().fill(RadialGradient(colors: [.white, Color(red: 1, green: 0.85, blue: 0.5)], center: .center, startRadius: 0, endRadius: 12))
                                .frame(width: 22, height: 22)
                                .shadow(color: Color(red: 1, green: 0.8, blue: 0.4), radius: 14)
                        }
                    }
                    .position(x: x, y: y)
                }
                VStack(alignment: .leading, spacing: 2) {
                    CapsLabel(text: "\(title) · \(place.name)")
                    Text(ctx.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: place.timeZone)))
                        .font(.system(size: 24, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(.white)
                    Text(status(hour)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                }
                .padding(14)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            .animation(.smooth(duration: 1.2), value: hour)
        }
    }

    private func localHour(_ d: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = place.timeZone
        let c = cal.dateComponents([.hour, .minute], from: d)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private func status(_ h: Double) -> String {
        switch h {
        case 0..<6: "Probably asleep"
        case 6..<9: "Waking up"
        case 9..<17: "Daytime"
        case 17..<21: "Evening"
        default: "Winding down"
        }
    }
}

/// Sky colours through the day, blended smoothly between keyframes.
enum SkyPalette {
    private static let keys: [(Double, [Color])] = [
        (0, [Color(red: 0.03, green: 0.04, blue: 0.13), Color(red: 0.09, green: 0.09, blue: 0.25)]),
        (5, [Color(red: 0.07, green: 0.08, blue: 0.24), Color(red: 0.25, green: 0.2, blue: 0.42)]),
        (6.5, [Color(red: 0.25, green: 0.3, blue: 0.6), Color(red: 0.98, green: 0.6, blue: 0.52)]),
        (9, [Color(red: 0.22, green: 0.52, blue: 0.9), Color(red: 0.62, green: 0.82, blue: 1)]),
        (16, [Color(red: 0.25, green: 0.55, blue: 0.92), Color(red: 0.7, green: 0.85, blue: 1)]),
        (18.5, [Color(red: 0.28, green: 0.2, blue: 0.5), Color(red: 0.98, green: 0.5, blue: 0.4)]),
        (20.5, [Color(red: 0.06, green: 0.06, blue: 0.2), Color(red: 0.2, green: 0.14, blue: 0.36)]),
        (24, [Color(red: 0.03, green: 0.04, blue: 0.13), Color(red: 0.09, green: 0.09, blue: 0.25)]),
    ]

    static func colors(_ hour: Double) -> [Color] {
        guard let i = keys.lastIndex(where: { $0.0 <= hour }), i + 1 < keys.count else { return keys[0].1 }
        let (h0, c0) = keys[i], (h1, c1) = keys[i + 1]
        let t = (hour - h0) / (h1 - h0)
        return zip(c0, c1).map { a, b in mix(a, b, t) }
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(t)
        return Color(red: r1 + (r2 - r1) * f, green: g1 + (g2 - g1) * f, blue: b1 + (b2 - b1) * f)
    }
}
