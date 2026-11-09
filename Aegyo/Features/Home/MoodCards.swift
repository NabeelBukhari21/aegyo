import SwiftUI

/// Her mood and yours, each shown by its little character.
struct MoodCards: View {
    @EnvironmentObject private var love: LoveService
    @State private var picking = false
    @State private var pokeHer = 0
    @State private var pokeMe = 0

    var body: some View {
        HStack(spacing: 10) {
            moodCard(label: "Her mood", status: love.data.herMood, empty: "Not shared yet", poke: pokeHer) { pokeHer += 1 }
            moodCard(label: "Your mood", status: love.data.myMood, empty: "Tap to share", poke: pokeMe) { pokeMe += 1; picking = true }
        }
        .sheet(isPresented: $picking) { MoodPicker().aegyoSheet([.height(560)]) }
    }

    private func moodCard(label: String, status: MoodStatus?, empty: String, poke: Int, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel(text: label)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status?.mood.name ?? "—")
                                .font(.system(size: 24, weight: .semibold)).tracking(-0.6)
                                .foregroundStyle(.white)
                                .contentTransition(.interpolate)
                            Text(status.map { "set \(agoText($0.at))" } ?? empty)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer(minLength: 0)
                        if let s = status {
                            MoodCharacter(mood: s.mood, size: 58, react: poke)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                                .frame(width: 58, height: 58)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(24)
            }
        }
        .buttonStyle(PressStyle())
    }
}

/// Pick a mood: characters bounce when you tap them, and the chosen one flies off to her.
struct MoodPicker: View {
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Mood?
    @State private var pokes: [Mood: Int] = [:]
    @State private var flying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "How are you feeling?", subtitle: "Your character shows up in her Dynamic Island.")
                .padding(.top, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(Mood.allCases) { mood in
                    Button {
                        pokes[mood, default: 0] += 1
                        Haptics.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { chosen = mood }
                    } label: {
                        VStack(spacing: 6) {
                            MoodCharacter(mood: mood, size: 56, react: pokes[mood, default: 0])
                                .offset(y: flying && chosen == mood ? -700 : 0)
                                .scaleEffect(flying && chosen == mood ? 0.4 : 1)
                            Text(mood.name).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(chosen == mood ? .white : .white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(chosen == mood ? 0.12 : 0.04))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(chosen == mood ? Love.pink.opacity(0.8) : .clear, lineWidth: 1.5))
                        }
                        .scaleEffect(chosen == mood ? 1.04 : 1)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            Spacer(minLength: 0)
            MorphSendButton(title: chosen.map { "Share “\($0.name)”" } ?? "Pick a mood", systemImage: "arrow.up") {
                guard let chosen else { return }
                await MainActor.run { withAnimation(.timingCurve(0.5, 0, 0.8, 0.4, duration: 0.6)) { flying = true } }
                love.playSentChime()
                await love.setMood(chosen)
                try? await Task.sleep(for: .milliseconds(900))
                await MainActor.run { dismiss() }
            }
            .disabled(chosen == nil)
            .opacity(chosen == nil ? 0.4 : 1)
        }
        .padding(22)
    }
}
