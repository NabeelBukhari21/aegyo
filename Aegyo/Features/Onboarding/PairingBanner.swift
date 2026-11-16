import SwiftUI

/// A slim card on Home (and a fuller one in Us) that reflects the pairing state and opens the pair sheet.
struct PairingBanner: View {
    @EnvironmentObject private var session: Session
    var compact = true
    var open: () -> Void

    var body: some View {
        switch session.pairing {
        case .paired(let p):
            if compact {
                EmptyView()
            } else {
                card(icon: "heart.fill", tint: Love.pink, title: "Paired with \(p.name)",
                     line: "Every tap lands on their phone.", cta: "Manage", pulse: false)
            }
        case .waiting(let code):
            card(icon: "hourglass", tint: Opal.mint, title: "Waiting for \(partnerName)",
                 line: "Share code \(code) so they can join.", cta: "Show code", pulse: true)
        case .partnerLeft(let name):
            card(icon: "heart.slash.fill", tint: Color(red: 1, green: 0.6, blue: 0.5), title: "\(name) left the pair",
                 line: "Your history is safe. Pair again whenever you're ready.", cta: "Pair again", pulse: false)
        case .notPaired:
            card(icon: "link.badge.plus", tint: Love.violet, title: "Not paired yet",
                 line: compact ? "Taps preview on this phone until you pair." : "Create a link or enter their code, and every tap lands on their phone.",
                 cta: "Pair", pulse: false)
        }
    }

    private var partnerName: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "your partner" : n.capitalized(with: nil)
    }

    private func card(icon: String, tint: Color, title: String, line: String, cta: String, pulse: Bool) -> some View {
        Button { Haptics.tap(); open() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.14)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.aegyo(16, .semibold)).foregroundStyle(tint)
                    if pulse { PulseDot().offset(x: 15, y: -15) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.aegyo(14.5, .semibold)).foregroundStyle(.white)
                    Text(line).font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                }
                Spacer(minLength: 6)
                Text(cta).font(.aegyo(12.5, .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 12).frame(height: 30).background(.white, in: Capsule())
            }
            .padding(12)
            .glass(20)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .accessibilityLabel("\(title). \(line)")
        .accessibilityHint(cta)
    }
}
