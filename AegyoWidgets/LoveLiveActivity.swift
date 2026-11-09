import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Her Dynamic Island: an LED pixel panel with a little scene for every kind of love.
struct LoveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LoveAttributes.self) { context in
            LockScreenLoveView(context: context)
                .activityBackgroundTint(.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(deepLink(context.state))
        } dynamicIsland: { context in
            let s = context.state
            let name = context.attributes.senderName
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LeadingArt(state: s)
                        .padding(.leading, 4).padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        if s.count > 1 {
                            DotMatrix(cols: 4 * String(min(s.count, 99)).count + 3, rows: 5, dot: 2.2, gap: 1, dimOpacity: 0) { c, r in
                                Pixels.text("×\(min(s.count, 99))")(c, r) ? Pixels.mint : nil
                            }
                        }
                        Text(s.sentAt, style: .time).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.trailing, 6).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.kind.headline(from: name, detail: s.detail))
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Text(subtitle(s))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .bottom, spacing: 10) {
                        IslandScene(state: s, sender: name)
                            .frame(maxWidth: .infinity)
                        ActionPill(state: s)
                    }
                    .padding(.top, 8)
                    .background(alignment: .bottom) { BottomGlow(color: kindColor(s)) }
                }
            } compactLeading: {
                DotMatrix(cols: 7, rows: 6, dot: 2.3, gap: 0.8, dimOpacity: 0) { c, r in Pixels.heart(c, r) ? Pixels.pink : nil }
                    .padding(.leading, 2)
            } compactTrailing: {
                if s.count > 1 {
                    DotMatrix(cols: 4 * String(min(s.count, 99)).count + 3, rows: 5, dot: 2, gap: 0.9, dimOpacity: 0) { c, r in
                        Pixels.text("×\(min(s.count, 99))")(c, r) ? Pixels.mint : nil
                    }
                } else {
                    Image(systemName: s.kind.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(kindColor(s))
                }
            } minimal: {
                DotMatrix(cols: 7, rows: 6, dot: 2.2, gap: 0.8, dimOpacity: 0) { c, r in Pixels.heart(c, r) ? Pixels.pink : nil }
            }
            .keylineTint(Pixels.pink)
            .widgetURL(deepLink(s))
        }
    }

    private func subtitle(_ s: LoveAttributes.ContentState) -> String {
        if s.replied { return "You sent love back" }
        if s.kind == .light, let km = s.distanceKm { return "Travelled \(km.formatted()) km to reach you" }
        if s.count > 1 { return "\(ordinal(s.count)) time · \(s.kind.subtitle(detail: s.detail))" }
        return s.kind.subtitle(detail: s.detail)
    }
}

func deepLink(_ s: LoveAttributes.ContentState) -> URL? {
    switch s.kind {
    case .photo: URL(string: "aegyo://photo/\(s.photoID ?? "")")
    case .mood: URL(string: "aegyo://mood")
    case .tapCode: URL(string: "aegyo://heartbeat?code=\(s.detail ?? "")")
    case .letter: URL(string: "aegyo://letters")
    default: URL(string: "aegyo://home")
    }
}

func ordinal(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .ordinal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Left-hand art: her photo, or a big pixel heart in the kind's colour.
private struct LeadingArt: View {
    let state: LoveAttributes.ContentState
    var size: CGFloat = 46

    var body: some View {
        if state.kind == .photo, let img = AppGroup.loadPhoto(state.photoID) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 0.5))
        } else {
            let color = kindColor(state)
            DotMatrix(cols: 13, rows: 9, dot: 2.6, gap: 0.9, dimOpacity: 0) { c, r in Pixels.bigHeart(c, r) ? color : nil }
                .frame(width: size, height: size)
        }
    }
}

/// The one action under each kind.
private struct ActionPill: View {
    let state: LoveAttributes.ContentState

    var body: some View {
        if state.replied {
            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Pixels.mint)
                .frame(width: 44, height: 44)
        } else {
            switch state.kind {
            case .photo: Link(destination: deepLink(state)!) { pill("Open", "photo") }
            case .mood: Link(destination: URL(string: "aegyo://mood")!) { pill("Yours", "face.smiling") }
            case .tapCode: Link(destination: deepLink(state)!) { pill("Feel it", "waveform.path.ecg") }
            case .letter: Link(destination: URL(string: "aegyo://letters")!) { pill("Open", "envelope.open") }
            case .light: Button(intent: MissYouTooIntent()) { pill("Back", "sparkle") }.buttonStyle(.plain)
            default: Button(intent: MissYouTooIntent()) { pill("Too", "heart.fill") }.buttonStyle(.plain)
            }
        }
    }

    private func pill(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(.black)
        .frame(width: 58, height: 52)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LockScreenLoveView: View {
    let context: ActivityViewContext<LoveAttributes>

    var body: some View {
        let s = context.state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LeadingArt(state: s, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.kind.headline(from: context.attributes.senderName, detail: s.detail))
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(s.replied ? "You sent love back" : s.kind.subtitle(detail: s.detail))
                        .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(s.sentAt, style: .time).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            }
            HStack(alignment: .bottom, spacing: 10) {
                IslandScene(state: s, sender: context.attributes.senderName, compact: false)
                    .frame(maxWidth: .infinity)
                ActionPill(state: s)
            }
        }
        .padding(16)
        .background(alignment: .bottom) { BottomGlow(color: kindColor(s)) }
    }
}

// MARK: - Countdown island

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DotMatrix(cols: 7, rows: 6, dot: 3, gap: 1, dimOpacity: 0) { c, r in Pixels.heart(c, r) ? Pixels.pink : nil }
                    Text("Until you see \(context.attributes.partnerName)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(context.state.meetDate, style: .relative).font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Pixels.mint)
                }
                ProgressView(timerInterval: context.attributes.startDate...context.state.meetDate, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(Pixels.pink)
            }
            .padding(16)
            .activityBackgroundTint(.black.opacity(0.88))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DotMatrix(cols: 13, rows: 9, dot: 2.6, gap: 0.9, dimOpacity: 0) { c, r in Pixels.bigHeart(c, r) ? Pixels.pink : nil }
                        .padding(.leading, 4).padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.meetDate, style: .relative)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text("until you see \(context.attributes.partnerName)").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.attributes.startDate...context.state.meetDate, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(Color(red: 1, green: 0.65, blue: 0.4))
                        .scaleEffect(y: 2.4)
                        .padding(.horizontal, 6).padding(.top, 12).padding(.bottom, 4)
                        .background(alignment: .bottom) { BottomGlow(color: Color(red: 1, green: 0.6, blue: 0.35)) }
                }
            } compactLeading: {
                DotMatrix(cols: 7, rows: 6, dot: 2.3, gap: 0.8, dimOpacity: 0) { c, r in Pixels.heart(c, r) ? Pixels.pink : nil }
            } compactTrailing: {
                ProgressView(timerInterval: context.attributes.startDate...context.state.meetDate, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular).tint(Pixels.pink).frame(width: 20, height: 20)
            } minimal: {
                DotMatrix(cols: 7, rows: 6, dot: 2.2, gap: 0.8, dimOpacity: 0) { c, r in Pixels.heart(c, r) ? Pixels.pink : nil }
            }
            .keylineTint(Pixels.pink)
        }
    }
}

#Preview("Miss you", as: .dynamicIsland(.expanded), using: LoveAttributes(senderName: "Nabeel")) {
    LoveLiveActivity()
} contentStates: {
    LoveAttributes.ContentState(kind: .missYou, sentAt: .now, count: 3, replied: false, detail: "8/10")
    LoveAttributes.ContentState(kind: .light, sentAt: .now, count: 1, replied: false, distanceKm: 2140)
    LoveAttributes.ContentState(kind: .goodnight, sentAt: .now, count: 1, replied: false)
    LoveAttributes.ContentState(kind: .mood, sentAt: .now, count: 1, replied: false, detail: "Sleepy")
    LoveAttributes.ContentState(kind: .tapCode, sentAt: .now, count: 1, replied: false, detail: "0,400,700,1500,1800,2600")
}

#Preview("Lock", as: .content, using: LoveAttributes(senderName: "Nabeel")) {
    LoveLiveActivity()
} contentStates: {
    LoveAttributes.ContentState(kind: .missYou, sentAt: .now, count: 3, replied: false, detail: "8/10")
}
