import SwiftUI

/// Shown after she answers a Ring (CallKit draws the incoming-call screen itself).
struct RingView: View {
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var sentBack = false

    var body: some View {
        ZStack {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.3))

            VStack(spacing: 0) {
                ZStack {
                    RippleField(size: 190)
                    GemView(width: 168, beating: !sentBack, speed: 1.4)
                }
                .frame(height: 340)
                .padding(.top, 40)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text(name.capitalized(with: nil))
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-0.8)
                    Text(sentBack ? "Love sent back" : "rang just to say they miss you")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .contentTransition(.opacity)
                }
                .foregroundStyle(.white)
                .padding(.top, 12)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                Spacer()

                MergeBar(secondary: "Later", primary: "Miss you too", doneTitle: "Love sent back", onSecondary: { dismiss() }) {
                    LoveService.shared.playSentChime()
                    Task { await LoveService.shared.send(.missYou) }
                    withAnimation(.smooth) { sentBack = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { appeared = true }
            Haptics.heartbeat(beats: 3)
        }
    }
}

#Preview { RingView(name: "Nabeel") }
