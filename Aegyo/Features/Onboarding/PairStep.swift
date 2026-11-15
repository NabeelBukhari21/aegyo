import CoreImage.CIFilterBuiltins
import SwiftUI

/// Pair with your partner: create a couple (you get a 6-digit code to share) or join with theirs.
/// Used inside onboarding and from Settings / the Home banner. Phase 3 extends the states.
struct PairStep: View {
    /// A code arriving from an `aegyo://pair/CODE` link, consumed by the next PairStep that appears.
    nonisolated(unsafe) static var pendingCode: String?
    var prefillCode: String? = nil
    var onDone: () -> Void
    @EnvironmentObject private var session: Session
    @State private var mode: Mode = .choose
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var celebrate = false

    enum Mode { case choose, waiting, join }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch session.pairing {
            case .paired(let p):
                pairedView(p)
            case .partnerLeft(let name) where mode == .choose:
                partnerLeftView(name)
            default:
                switch mode {
                case .choose: choose
                case .waiting: waiting
                case .join: join
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: mode)
        .onAppear {
            if case .waiting = session.pairing { mode = .waiting }
            let incoming = prefillCode ?? Self.pendingCode
            Self.pendingCode = nil
            if let incoming, incoming.count == 6 { mode = .join; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { code = incoming } }
        }
        .onChange(of: session.pairing) { _, p in if case .paired = p { Haptics.success(); celebrate = true } }
        .alert("Hmm", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    // MARK: Choose

    private var choose: some View {
        VStack(alignment: .leading, spacing: 18) {
            PairHearts(joined: false).frame(maxWidth: .infinity).frame(height: 140)
            FadeInText("Two phones, one heartbeat.")
            Text("Pair with \(Profile.partnerName.capitalized(with: nil))").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
            Text("One of you creates the link and shares a six-digit code. The other enters it. That's it.")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ContinuePill(title: "Create our link", loading: busy) {
                busy = true
                Task {
                    do { _ = try await session.createCouple(); withAnimation { mode = .waiting } } catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
            Button { Haptics.tap(); withAnimation { mode = .join } } label: {
                Text("I have a code").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54).background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(PressStyle())
            Button { Haptics.tap(); onDone() } label: {
                Text("Skip for now").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
    }

    // MARK: Waiting

    private var waiting: some View {
        let code = { if case .waiting(let c) = session.pairing { return c } else { return "" } }()
        let link = URL(string: "aegyo://pair/\(code)")!
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                FadeInText("Waiting for \(Profile.partnerName.capitalized(with: nil))…")
                Spacer()
                PulseDot()
            }
            Text("Share this code").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, ch in
                    Text(String(ch)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                }
            }
            .accessibilityElement().accessibilityLabel("Invite code \(code.map(String.init).joined(separator: " "))")

            HStack(spacing: 14) {
                if let qr = QR.image(for: link.absoluteString) {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 92, height: 92)
                        .padding(6).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("QR code for the invite link")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("They open Aegyo, choose “I have a code”, and type it in. Or they scan this.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                    Text("Codes work for 7 days.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(14).glass(20)

            Spacer(minLength: 0)

            ShareLink(item: "Pair with me on Aegyo 💗 My code is \(code). Or tap: \(link.absoluteString)") {
                HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text("Send the code") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 54).background(.white, in: Capsule())
            }
            .buttonStyle(PressStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })

            Button { Haptics.tap(); UIPasteboard.general.string = code } label: {
                Label("Copy code", systemImage: "doc.on.doc").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
            Button { Haptics.tap(); onDone() } label: {
                Text("I'll wait in the app").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
    }

    // MARK: Join

    private var join: some View {
        VStack(alignment: .leading, spacing: 18) {
            FadeInText("Almost there.")
            Text("Enter their code").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
            CodeEntry(code: $code) { submit() }
            Spacer(minLength: 0)
            ContinuePill(title: "Pair", enabled: code.count == 6, loading: busy) { submit() }
            Button { Haptics.tap(); withAnimation { mode = .choose } } label: {
                Text("Back").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
    }

    private func submit() {
        guard code.count == 6, !busy else { return }
        busy = true
        Task {
            do { try await session.joinCouple(code: code) } catch { self.error = error.localizedDescription; Haptics.rumble(duration: 0.2) }
            busy = false
        }
    }

    // MARK: Paired

    @State private var confirmUnpair = false

    private func pairedView(_ p: Account) -> some View {
        VStack(spacing: 18) {
            PairHearts(joined: true).frame(height: 160)
            HStack(spacing: -10) {
                AvatarView(who: .me, name: Profile.myName, size: 56)
                AvatarView(who: .partner, name: p.name, size: 56)
            }
            Text("You're paired with \(p.name)").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("From now on, every tap lands on their phone.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
            ContinuePill(title: "Continue") { onDone() }
            Button { Haptics.tap(); confirmUnpair = true } label: {
                Text("Unpair").font(.system(size: 14, weight: .medium)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0.5)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
        .frame(maxWidth: .infinity)
        .overlay { if celebrate { ConfettiBurst().allowsHitTesting(false) } }
        .sheet(isPresented: $confirmUnpair) {
            ConfirmSheet(title: "Unpair from \(p.name)?",
                         message: "Your taps will stop reaching each other. Your history stays on this phone, and you can pair again any time.",
                         confirmTitle: "Unpair") {
                Task { await session.leaveCouple(); mode = .choose }
            }
        }
    }

    // MARK: Partner left

    private func partnerLeftView(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PairHearts(joined: false).frame(maxWidth: .infinity).frame(height: 140).saturation(0.3)
            FadeInText("\(name) left the pair.")
            Text("Pair again?").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
            Text("Everything you two shared is still here. Create a new link or enter a code to reconnect.")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ContinuePill(title: "Create a new link", loading: busy) {
                busy = true
                Task {
                    await session.leaveCouple()
                    do { _ = try await session.createCouple(); withAnimation { mode = .waiting } } catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
            Button { Haptics.tap(); Task { await session.leaveCouple() }; withAnimation { mode = .join } } label: {
                Text("I have a code").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54).background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(PressStyle())
            Button { Haptics.tap(); onDone() } label: {
                Text("Not now").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
    }
}

// MARK: - Pieces

/// Two hearts drifting toward each other; when `joined`, they merge with a glow.
struct PairHearts: View {
    var joined: Bool
    @State private var t = false
    var body: some View {
        ZStack {
            heart(Love.pink).offset(x: joined ? -8 : (t ? -46 : -60))
            heart(Love.violet).offset(x: joined ? 8 : (t ? 46 : 60))
            if joined {
                Image(systemName: "heart.fill").font(.system(size: 54)).foregroundStyle(Love.glow)
                    .shadow(color: Love.pink.opacity(0.7), radius: 20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { t = true } }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: joined)
    }
    private func heart(_ c: Color) -> some View {
        Image(systemName: "heart.fill").font(.system(size: 40)).foregroundStyle(c).shadow(color: c.opacity(0.6), radius: 12).opacity(joined ? 0 : 1)
    }
}

struct PulseDot: View {
    @State private var on = false
    var body: some View {
        ZStack {
            Circle().fill(Opal.mint.opacity(0.3)).frame(width: 18, height: 18).scaleEffect(on ? 1.6 : 0.8).opacity(on ? 0 : 1)
            Circle().fill(Opal.mint).frame(width: 8, height: 8)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true } }
        .accessibilityHidden(true)
    }
}

/// Six boxes with one hidden text field behind them.
struct CodeEntry: View {
    @Binding var code: String
    var onComplete: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.02)
                .onChange(of: code) { _, v in
                    let clean = String(v.filter(\.isNumber).prefix(6))
                    if clean != v { code = clean }
                    if clean.count == 6 { Haptics.success(); onComplete() } else if !clean.isEmpty { Haptics.tick() }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let ch = i < code.count ? String(Array(code)[i]) : ""
                    Text(ch).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(i == code.count && focused ? Love.pink.opacity(0.8) : .white.opacity(0.14), lineWidth: 1.2))
                        .scaleEffect(i == code.count - 1 ? 1.04 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: code)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true } }
        .accessibilityElement()
        .accessibilityLabel("Six digit code")
        .accessibilityValue(code)
    }
}

enum QR {
    static func image(for string: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(string.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// PairStep inside a sheet (from Settings, the Home banner, or an `aegyo://pair/CODE` link).
struct PairSheet: View {
    var prefill: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.15))
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 32, height: 32).background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.horizontal, 20).padding(.top, 18)
                PairStep(prefillCode: prefill) { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }
}
