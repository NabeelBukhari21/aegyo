import SwiftUI

// MARK: - 1. Love Wrapped

/// "Our love, wrapped": your year as a story card made for Instagram/TikTok.
struct WrappedView: View {
    @EnvironmentObject private var love: LoveService
    @State private var page = 0

    var body: some View {
        FeatureSheet(title: "Love Wrapped", subtitle: "Your story so far, ready to post.") {
            WrappedCard(stats: .init(love))
                .scaleEffect(0.86)
                .frame(height: 560)
                .frame(maxWidth: .infinity)
                .shadow(color: Opal.mint.opacity(0.2), radius: 30)
            ShareCardButton(title: "Share to your story", name: "Our love, wrapped") { WrappedCard(stats: .init(love)) }
        }
    }
}

struct WrappedStats {
    var total: Int, streak: Int, longest: Int, peakHour: Int?, tier: GemTier, km: Int?, days: Int?
    @MainActor init(_ love: LoveService) {
        total = love.totalSent + love.totalReceived
        streak = love.streakDays
        longest = love.longestStreak
        peakHour = love.peakHour
        tier = love.tier
        km = love.distanceKm
        days = Profile.togetherSince.map { Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 0 }
    }
}

struct WrappedCard: View {
    let stats: WrappedStats

    var body: some View {
        StoryCanvas {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                Spacer()
                StaticGem(width: 120, palette: stats.tier.palette).frame(maxWidth: .infinity)
                Spacer()
                Text("Our love,\nwrapped.")
                    .font(.system(size: 40, weight: .semibold)).tracking(-1.5)
                    .lineSpacing(-4)
                Spacer().frame(height: 22)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                    GridRow {
                        big("\(stats.total)", "moments shared")
                        big("\(stats.longest)", "day longest streak")
                    }
                    GridRow {
                        big(stats.peakHour.map(hourText) ?? "—", "when I miss you most")
                        big(stats.km.map { $0.formatted() } ?? (stats.days.map { "\($0)" } ?? "∞"), stats.km != nil ? "km apart, still close" : "days together")
                    }
                }
                Spacer().frame(height: 22)
                HStack {
                    Text("\(Doki.name): \(stats.tier.name)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Opal.mint)
                    Spacer()
                    Text("aegyo.app").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func big(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 30, weight: .light)).tracking(-1).monospacedDigit()
            Text(label.uppercased()).font(.system(size: 9.5, weight: .medium)).tracking(1).foregroundStyle(.white.opacity(0.55))
        }
    }

    private func hourText(_ h: Int) -> String {
        let d = Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now) ?? .now
        return d.formatted(.dateTime.hour())
    }
}

// MARK: - 7. Love Pass (boarding pass, from the FocusFlight reference)

struct ReceiptView: View {
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var unfolded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            DotMap(fromCode: code(love.data.myPlace?.name, "YOU"), toCode: code(love.data.herPlace?.name, "HER"))
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                }
                .padding(20)
                Spacer()
            }
            VStack(spacing: 14) {
                LovePass(pass: passData, unfolded: unfolded)
                    .onTapGesture { Haptics.tap(); withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { unfolded.toggle() } }
                if unfolded {
                    ShareCardButton(title: "Check in & share", name: "Love Pass") {
                        LovePass(pass: passData, unfolded: true).frame(width: 340).padding(20).background(Color.black)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Haptics.tick()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { unfolded = true }
            }
        }
    }

    private var passData: LovePass.Data {
        let meet = Profile.meetDate
        return .init(
            from: code(love.data.myPlace?.name, "YOU"), to: code(love.data.herPlace?.name, "HER"),
            fromName: love.data.myPlace?.name ?? Profile.myName, toName: love.data.herPlace?.name ?? Profile.partnerName.capitalized(with: nil),
            passenger: Profile.partnerName.capitalized(with: nil),
            distance: love.distanceKm.map { "\($0.formatted()) km" } ?? "Any distance",
            boarding: meet.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "Soon",
            daysLeft: meet.map { max(0, Calendar.current.dateComponents([.day], from: .now, to: $0).day ?? 0) },
            moments: love.todayEvents().filter { $0.kind.countsAsLove }.count)
    }

    private func code(_ name: String?, _ fallback: String) -> String {
        guard let n = name?.filter(\.isLetter), n.count >= 3 else { return fallback }
        return String(n.prefix(3)).uppercased()
    }
}

struct LovePass: View {
    struct Data { var from, to, fromName, toName, passenger, distance, boarding: String; var daysLeft: Int?; var moments: Int }
    let pass: Data
    var unfolded: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pass.from).font(.system(size: unfolded ? 44 : 30, weight: .bold, design: .monospaced))
                    if unfolded { Text(pass.fromName).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)) }
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill").font(.system(size: unfolded ? 16 : 13)).foregroundStyle(Love.pink)
                    if unfolded, let d = pass.daysLeft { Text("\(d)d").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.55)) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pass.to).font(.system(size: unfolded ? 44 : 30, weight: .bold, design: .monospaced))
                    if unfolded { Text(pass.toName).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)) }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, unfolded ? 14 : 18)

            if unfolded {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow { field("Passenger", pass.passenger); field("Distance", pass.distance, trailing: true) }
                    GridRow { field("Seat", "Next to you"); field("Boarding", pass.boarding, trailing: true) }
                    GridRow { field("Class", "First, always"); field("Moments today", "\(pass.moments)", trailing: true) }
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                // perforation
                ZStack {
                    Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.white.opacity(0.2)).frame(height: 1)
                    HStack {
                        Circle().fill(.black).frame(width: 22, height: 22).offset(x: -11)
                        Spacer()
                        Circle().fill(.black).frame(width: 22, height: 22).offset(x: 11)
                    }
                }
                .padding(.vertical, 14)

                Barcode().frame(height: 54).padding(.horizontal, 20).padding(.bottom, 18)
                    .colorInvert()
                    .transition(.opacity)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.11))
                .overlay(DotTexture().opacity(0.35).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private func field(_ k: String, _ v: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(k).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            Text(v).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
}

/// Dotted "world map" texture: a dot grid shaped by soft blobs.
struct DotTexture: View {
    var body: some View {
        Canvas { g, size in
            let step: CGFloat = 6
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let n = sin(x * 0.021 + 1.3) * cos(y * 0.035) + sin((x + y) * 0.013) * 0.8
                    if n > 0.15 { g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.8, height: 1.8)), with: .color(.white.opacity(0.35))) }
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

/// Dark dotted map with a glowing route between your city tag and hers.
private struct DotMap: View {
    let fromCode: String, toCode: String
    @State private var draw: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            let a = CGPoint(x: geo.size.width * 0.28, y: geo.size.height * 0.2)
            let b = CGPoint(x: geo.size.width * 0.66, y: geo.size.height * 0.4)
            ZStack {
                DotTexture().opacity(0.5)
                Path { p in p.move(to: a); p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + 40, y: a.y)) }
                    .trim(from: 0, to: draw)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .shadow(color: .white, radius: 4)
                tag(fromCode).position(a)
                tag(toCode).position(b).opacity(draw > 0.95 ? 1 : 0.3)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2)) { draw = 1 } }
    }
    private func tag(_ t: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill").font(.system(size: 9))
            Text(t).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(.black, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 1, green: 0.85, blue: 0.4), lineWidth: 1.5))
    }
}

struct ReceiptCard: View {
    let items: [(String, Int)]
    let partner: String
    private let ink = Color(white: 0.1)

    var body: some View {
        VStack(spacing: 10) {
            Text("AEGYO LOVE CO.").font(.system(size: 17, weight: .bold, design: .monospaced))
            Text("Order for \(partner.uppercased())").font(.system(size: 12, design: .monospaced))
            Text(Date.now.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12, design: .monospaced))
            dashed
            if items.isEmpty {
                row("Nothing yet today", "0")
            } else {
                ForEach(items, id: \.0) { row("\($0.1)× \($0.0)", "FREE") }
            }
            dashed
            row("SUBTOTAL", "\(items.reduce(0) { $0 + $1.1 }) moments")
            row("TAX", "0 (love is exempt)")
            HStack {
                Text("TOTAL").font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
                Text("PRICELESS").font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            dashed
            Text("Thank you for loving.\nNo refunds. No returns. No one else.")
                .font(.system(size: 11, design: .monospaced)).multilineTextAlignment(.center)
            Barcode().frame(height: 44).padding(.top, 6)
            Text("aegyo.app").font(.system(size: 10, design: .monospaced))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 22).padding(.vertical, 26)
        .frame(width: 320)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .mask(ZigZagEdge())
    }

    private var dashed: some View {
        Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1).foregroundStyle(ink.opacity(0.6))
    }

    private func row(_ l: String, _ r: String) -> some View {
        HStack { Text(l); Spacer(); Text(r) }.font(.system(size: 13, design: .monospaced))
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { Path { $0.move(to: CGPoint(x: 0, y: r.midY)); $0.addLine(to: CGPoint(x: r.maxX, y: r.midY)) } }
}

struct Barcode: View {
    var body: some View {
        Canvas { g, s in
            var x: CGFloat = 0
            var seed: UInt64 = 0xA5E9
            while x < s.width {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let w = CGFloat(1 + (seed >> 60) % 3)
                if (seed >> 33) % 3 != 0 { g.fill(Path(CGRect(x: x, y: 0, width: w, height: s.height)), with: .color(.black)) }
                x += w + 1
            }
        }
    }
}

/// Torn-paper top and bottom edges.
private struct ZigZagEdge: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 8, h: CGFloat = 5
        p.move(to: CGPoint(x: 0, y: h))
        var x: CGFloat = 0
        while x < r.maxX { p.addLine(to: CGPoint(x: x + step / 2, y: 0)); p.addLine(to: CGPoint(x: x + step, y: h)); x += step }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - h))
        x = r.maxX
        while x > 0 { p.addLine(to: CGPoint(x: x - step / 2, y: r.maxY)); p.addLine(to: CGPoint(x: x - step, y: r.maxY - h)); x -= step }
        p.closeSubpath()
        return p
    }
}
