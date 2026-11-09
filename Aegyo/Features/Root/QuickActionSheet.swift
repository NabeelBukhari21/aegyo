import SwiftUI

/// The centre orb's action stack. It grows out of the orb as separate cards (like the wallet reference),
/// with the Miss-o-meter ruler on top and one card per way to reach her.
struct ActionStack: View {
    @EnvironmentObject private var love: LoveService
    @Binding var isOpen: Bool
    var open: (HomeSheet) -> Void
    var openPhoto: () -> Void
    var ring: () -> Void
    var toast: (String) -> Void

    @State private var level: Double = 7
    @State private var shown = false

    private struct Row: Identifiable { let id: String, icon: String, title: String, line: String, tint: Color, run: () -> Void }

    private var rows: [Row] {
        [
            Row(id: "photo", icon: "camera.fill", title: "Photo", line: "Lands in her Dynamic Island", tint: Opal.mint) { close { openPhoto() } },
            Row(id: "mood", icon: "face.smiling.inverse", title: "Mood", line: "Show her how you feel", tint: Color(red: 1, green: 0.8, blue: 0.4)) { close { open(.mood) } },
            Row(id: "beat", icon: "waveform.path.ecg", title: "Heartbeat", line: "Tap a rhythm she can feel", tint: Love.pink) { close { open(.heartbeat(nil)) } },
            Row(id: "letter", icon: "envelope.fill", title: "Letter", line: "Seal one for the right moment", tint: Love.peach) { close { open(.letters) } },
            Row(id: "ring", icon: "phone.fill", title: "Ring", line: "Her phone rings like a call", tint: Color(red: 0.45, green: 1, blue: 0.6)) { close { ring() } },
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture { close {} }

            VStack(spacing: 8) {
                card(index: 0) {
                    VStack(spacing: 14) {
                        RulerSlider(value: $level)
                        MorphSendButton(title: "Send “I miss you”", systemImage: "heart.fill", height: 50) {
                            love.playSentChime()
                            await love.send(.missYou, detail: "\(Int(level))/10")
                            await MainActor.run { close { toast("Missing her \(Int(level))/10 · sent") } }
                        }
                    }
                    .padding(16)
                }

                HStack(spacing: 8) {
                    quick(.hug, "Hug", 1)
                    quick(.goodnight, "Night", 2)
                    quick(.light, "Light", 3)
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    card(index: i + 4) {
                        Button(action: r.run) {
                            HStack(spacing: 14) {
                                Image(systemName: r.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(r.tint)
                                    .frame(width: 40, height: 40).background(r.tint.opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                    Text(r.line).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 14).frame(height: 62)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle(scale: 0.97))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
            .scaleEffect(shown ? 1 : 0.3, anchor: .bottom)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            Haptics.gemPress()
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) { shown = true }
        }
    }

    private func card<C: View>(index: Int, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.09)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
            .offset(y: shown ? 0 : CGFloat(30 + index * 10))
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.025), value: shown)
    }

    private func quick(_ k: LoveKind, _ title: String, _ i: Int) -> some View {
        Button {
            love.playSentChime()
            Task { await love.send(k) }
            close { toast("\(title) sent") }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: k.symbol).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.09)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .offset(y: shown ? 0 : CGFloat(30 + i * 10))
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.025), value: shown)
    }

    private func close(_ then: @escaping () -> Void) {
        Haptics.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isOpen = false
            then()
        }
    }
}
