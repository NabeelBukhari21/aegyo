import SwiftUI

/// Three spotlight callouts on first launch: Doki, the + orb, the tab bar. Shown once.
struct GuidedTour: View {
    @Binding var shown: Bool
    @State private var index = 0
    @State private var appeared = false

    private struct Stop { let title: String; let line: String; let anchor: UnitPoint; let radius: CGFloat; let calloutBelow: Bool }

    private var who: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "them" : n
    }

    private var stops: [Stop] {
        [
            Stop(title: "This is \(Doki.name)", line: "Tap to tell \(who) you miss them. It lands in their Dynamic Island with a soft chime.", anchor: UnitPoint(x: 0.5, y: 0.33), radius: 170, calloutBelow: true),
            Stop(title: "Reach them any way", line: "The glowing orb opens hugs, photos, moods, letters, heartbeats and the Ring.", anchor: UnitPoint(x: 0.5, y: 0.935), radius: 54, calloutBelow: false),
            Stop(title: "Sky, Moments, Us", line: "Tonight's moon and your star signs, your shared photos and moods, and everything about you two.", anchor: UnitPoint(x: 0.5, y: 0.935), radius: 200, calloutBelow: false),
        ]
    }

    static let seenKey = "tourSeen"

    var body: some View {
        let s = stops[index]
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width * s.anchor.x, y: geo.size.height * s.anchor.y)
            ZStack {
                // dim everything except the spotlight
                Color.black.opacity(0.72)
                    .mask {
                        Rectangle().overlay(
                            Circle().frame(width: s.radius * 2, height: s.radius * 2).position(center).blendMode(.destinationOut)
                        )
                        .compositingGroup()
                    }
                    .ignoresSafeArea()
                Circle().stroke(Love.pink.opacity(0.8), lineWidth: 1.5)
                    .frame(width: s.radius * 2, height: s.radius * 2).position(center)
                    .shadow(color: Love.pink.opacity(0.6), radius: 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(0..<stops.count, id: \.self) { i in
                            Capsule().fill(i == index ? Color.white : Color.white.opacity(0.25)).frame(width: i == index ? 18 : 6, height: 6)
                        }
                    }
                    Text(s.title).font(.aegyo(20, .semibold)).foregroundStyle(.white)
                    Text(s.line).font(.aegyo(14)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button { finish() } label: { Text("Skip").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.55)) }
                        Spacer()
                        Button {
                            Haptics.tick()
                            if index < stops.count - 1 { withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { index += 1 } } else { finish() }
                        } label: {
                            WhitePill(title: index < stops.count - 1 ? "Next" : "Got it", height: 40)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.09)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                .position(x: geo.size.width / 2, y: s.calloutBelow ? center.y + s.radius + 120 : center.y - s.radius - 110)
                .id(index)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: index)
            .opacity(appeared ? 1 : 0)
            .onAppear { withAnimation(.smooth(duration: 0.5).delay(0.8)) { appeared = true } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Guided tour. \(s.title). \(s.line)")
    }

    private func finish() {
        Haptics.tap()
        AppGroup.defaults.set(true, forKey: Self.seenKey)
        withAnimation(.smooth(duration: 0.4)) { shown = false }
    }
}
