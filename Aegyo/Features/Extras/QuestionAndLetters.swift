import SwiftUI

// MARK: - 5. Daily Question

enum DailyQuestions {
    static let all = [
        "What's a small thing I do that makes you feel loved?",
        "Where would you take me if we had one free day together?",
        "What did you think of me the first time we talked?",
        "What song makes you think of us?",
        "What's one thing you want us to do before the year ends?",
        "When did you realise you were falling for me?",
        "What's your favourite memory of us so far?",
        "What would our perfect lazy Sunday look like?",
        "What's something you've never told me?",
        "Which of my habits secretly makes you smile?",
        "If we had a house, what's the one room you'd design?",
        "What's a food that reminds you of me?",
        "What do you miss most about me right now?",
        "What's a dream you haven't said out loud yet?",
        "How do you know when I'm having a bad day?",
        "What would you name our first pet?",
        "What's one thing you're proud of me for?",
        "Where do you see us in five years?",
        "What's the best text I've ever sent you?",
        "If today had a colour, what would it be?",
        "What's a tiny thing that made you happy today?",
        "What would you cook for me tonight?",
        "Which trip should we take first?",
        "What's your favourite photo of us, and why?",
        "What's a word that describes us?",
        "What made you laugh the hardest this week?",
        "What's something you'd like me to ask you more often?",
        "Which movie should we watch together next?",
        "What does home feel like to you?",
        "What do you want to tell me right now?",
    ]
    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return all[day % all.count]
    }
}

struct DailyQuestionView: View {
    @EnvironmentObject private var love: LoveService
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var answered: String? { love.data.answers[DayKey.of(.now)] }

    var body: some View {
        FeatureSheet(title: "Daily Question", subtitle: "One question a day. Both answers unlock together.", glow: true) {
            Card(padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    CapsLabel(text: Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    Text(DailyQuestions.today)
                        .font(.system(size: 26, weight: .semibold)).tracking(-0.6)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let answered {
                answerCard(title: "You", text: answered, locked: false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                answerCard(title: Profile.partnerName.capitalized(with: nil),
                           text: "Her answer appears here the moment she answers. Until then, no peeking.", locked: true)
            } else {
                TextField("", text: $draft, prompt: Text("Your answer…").foregroundStyle(.white.opacity(0.35)), axis: .vertical)
                    .lineLimit(3...8)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .focused($focused)
                    .padding(18)
                    .glass(22)
                if draft.isEmpty {
                    CascadePills(options: ["Honestly…", "Every time you…", "That one time we…", "I've never told you this, but…"]) { starter in
                        withAnimation(.snappy) { draft = starter + " " }
                        focused = true
                    }
                    .transition(.opacity)
                }
                HoldTogetherButton(title: "Hold to lock in", me: Profile.myName, her: Profile.partnerName) {
                    guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { love.answerToday(draft) }
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
            }
        }
        .onAppear { if answered == nil { focused = true } }
    }

    private func answerCard(title: String, text: String, locked: Bool) -> some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CapsLabel(text: title)
                    Spacer()
                    if locked { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)) }
                }
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(locked ? 0.5 : 0.95))
                    .blur(radius: locked ? 0.3 : 0)
            }
        }
    }
}

// MARK: - 4. Open-When Letters

struct LettersView: View {
    @EnvironmentObject private var love: LoveService
    @State private var writing = false
    @State private var opening: Letter?

    var body: some View {
        FeatureSheet(title: "Open When…", subtitle: "Letters she can only open at the right moment.") {
            Button { Haptics.tap(); writing = true } label: {
                WhitePill(title: "Write a letter", systemImage: "pencil", height: 52)
                    .frame(maxWidth: .infinity).background(.white, in: Capsule())
            }
            .buttonStyle(PressStyle())

            if love.data.letters.isEmpty {
                Text("Write one for a hard night, a long flight, or your anniversary. It waits, sealed with \(Doki.name), until she needs it.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
            }
            ForEach(love.data.letters.reversed()) { letter in
                Button { Haptics.tap(); opening = letter } label: { EnvelopeRow(letter: letter) }
                    .buttonStyle(PressStyle())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $writing) { LetterComposer().presentationBackground(.black) }
        .fullScreenCover(item: $opening) { LetterOpenView(letter: $0) }
    }
}

private struct EnvelopeRow: View {
    let letter: Letter
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.9)).frame(width: 54, height: 40)
                EnvelopeFlap().fill(Color(white: 0.8)).frame(width: 54, height: 22).offset(y: -9)
                StaticGem(width: 18).offset(y: 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(letter.trigger.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(letter.isLocked ? "Unlocks \(letter.unlockDate!.formatted(date: .abbreviated, time: .omitted))"
                     : letter.outgoing ? "Sealed for \(Profile.partnerName)" : "From \(Profile.partnerName)")
                    .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: letter.isLocked ? "lock.fill" : "chevron.right").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .glass(20)
    }
}

struct EnvelopeFlap: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.closeSubpath()
        }
    }
}

private struct LetterComposer: View {
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var trigger: Letter.Trigger = .missMe
    @State private var body_ = ""
    @State private var date = Date.now.addingTimeInterval(86400 * 30)
    @State private var sealing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "New letter")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Letter.Trigger.allCases) { t in
                            Button { withAnimation(.snappy) { trigger = t } } label: {
                                Text(t.title.replacingOccurrences(of: "Open ", with: "").capitalizedFirst)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(trigger == t ? .black : .white)
                                    .padding(.horizontal, 14).frame(height: 36)
                                    .background(trigger == t ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.08)), in: Capsule())
                            }
                        }
                    }
                }
                if trigger == .onDate || trigger == .anniversary {
                    DatePicker("Unlocks on", selection: $date, in: Date.now..., displayedComponents: .date).tint(Opal.mint)
                }
                ZStack {
                    TextField("", text: $body_, prompt: Text("Dear \(Profile.partnerName),").foregroundStyle(.black.opacity(0.35)), axis: .vertical)
                        .lineLimit(10...20)
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(.black)
                        .padding(22)
                        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
                        .background(Color(red: 0.98, green: 0.97, blue: 0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if sealing {
                        StaticGem(width: 90)
                            .transition(.scale(scale: 3).combined(with: .opacity))
                    }
                }
                .rotation3DEffect(.degrees(sealing ? 70 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
                .scaleEffect(sealing ? 0.6 : 1)

                Button {
                    Haptics.gemPress()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { sealing = true }
                    let letter = Letter(trigger: trigger, body: body_,
                                        unlockDate: (trigger == .onDate || trigger == .anniversary) ? date : nil)
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        await love.saveLetter(letter)
                        dismiss()
                    }
                } label: {
                    WhitePill(title: "Seal it with \(Doki.name)", systemImage: "seal.fill", height: 52)
                        .frame(maxWidth: .infinity).background(.white, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .disabled(body_.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(body_.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
    }
}

private struct LetterOpenView: View {
    let letter: Letter
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var flapOpen = false
    @State private var paperUp = false

    var body: some View {
        ZStack {
            OpalBackground()
            VStack(spacing: 24) {
                Text(letter.trigger.title).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                if letter.isLocked {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.7))
                        Text("Sealed until \(letter.unlockDate!.formatted(date: .long, time: .omitted))")
                            .font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 60)
                } else {
                    ZStack(alignment: .top) {
                        Text(letter.body)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(.black)
                            .padding(24)
                            .frame(width: 300, height: 360, alignment: .topLeading)
                            .background(Color(red: 0.98, green: 0.97, blue: 0.95), in: RoundedRectangle(cornerRadius: 14))
                            .offset(y: paperUp ? -40 : 120)
                            .opacity(paperUp ? 1 : 0)
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 14).fill(.white).frame(width: 320, height: 210)
                            EnvelopeFlap().fill(Color(white: 0.86)).frame(width: 320, height: 120)
                                .rotation3DEffect(.degrees(flapOpen ? 180 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                                .zIndex(flapOpen ? -1 : 1)
                            StaticGem(width: 44).offset(y: 96).opacity(flapOpen ? 0 : 1)
                        }
                        .offset(y: paperUp ? 280 : 160)
                        .opacity(paperUp ? 0 : 1)
                    }
                    .frame(height: 420)
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("Close").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52).background(.white.opacity(0.1), in: Capsule())
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 40)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !letter.isLocked else { return }
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.7).delay(0.4)) { flapOpen = true }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0)) { paperUp = true }
            love.markOpened(letter)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
