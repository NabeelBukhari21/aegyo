import AuthenticationServices
import SwiftUI

/// Opal's Sign Up sheet: Apple first, then email, then "Already have an account?".
struct SignUpSheet: View {
    @Binding var draft: OnboardingFlow.Draft
    @Binding var busy: Bool
    @Binding var error: String?
    var onSignIn: (SignInMethod) -> Void

    @State private var mode: Mode = .choose
    @State private var name = ""
    @State private var email = ""
    @State private var existing = false
    @Environment(\.dismiss) private var dismiss

    enum Mode { case choose, email }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.aegyo(13, .bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20)

            VStack(spacing: 6) {
                Text(existing ? "Welcome back" : "Sign Up").font(.aegyo(28, .semibold)).tracking(-0.8).foregroundStyle(.white)
                Text(existing ? "Pick up right where you left off." : "Let's get started on your love story.")
                    .font(.aegyo(14)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(.top, 10)

            Group {
                switch mode {
                case .choose: choose
                case .email: emailForm
                }
            }
            .padding(.horizontal, 24).padding(.top, 28)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: mode)

            Spacer()

            VStack(spacing: 6) {
                Text("Your data stays between you two. We never sell it, and you can delete everything in one tap.")
                    .font(.aegyo(12)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    Button("Privacy Policy") { }.font(.aegyo(12, .semibold)).foregroundStyle(.white.opacity(0.75))
                    Button("Terms") { }.font(.aegyo(12, .semibold)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 30).padding(.bottom, 26)
        }
        .presentationDetents([.height(mode == .email ? 620 : 520)])
        .presentationBackground(.black)
        .presentationCornerRadius(36)
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private var choose: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(existing ? .signIn : .signUp) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                    let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                    onSignIn(.apple(userID: cred.user, name: name.isEmpty ? nil : name, email: cred.email))
                case .failure(let e):
                    let ns = e as NSError
                    if ns.code == ASAuthorizationError.canceled.rawValue { return }
                    // Free developer teams can't use the Sign in with Apple entitlement; fall back to email.
                    error = "Sign in with Apple isn't available on this build yet. Use email for now."
                    withAnimation { mode = .email }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(Capsule())

            HStack { line; Text("or").font(.aegyo(12)).foregroundStyle(.white.opacity(0.4)); line }

            Button { Haptics.tap(); withAnimation { mode = .email } } label: {
                Label("Continue with Email", systemImage: "envelope.fill")
                    .font(.aegyo(15, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(PressStyle())

            Button { Haptics.tap(); withAnimation { existing.toggle() } } label: {
                Text(existing ? "New here? Create an account" : "Already have an account?")
                    .font(.aegyo(14, .semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 10)
        }
    }

    private var line: some View { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }

    private var emailForm: some View {
        VStack(spacing: 12) {
            if !existing { OnboardField(text: $name, placeholder: "Your name", capitalization: .words) }
            OnboardField(text: $email, placeholder: "Email", keyboard: .emailAddress)
            ContinuePill(title: existing ? "Sign in" : "Create account", enabled: valid, loading: busy) {
                onSignIn(.email(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces)))
            }
            Button { Haptics.tap(); withAnimation { mode = .choose } } label: {
                Text("Back").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var valid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        let emailOK = e.contains("@") && e.contains(".") && e.count >= 6
        return emailOK && (existing || name.trimmingCharacters(in: .whitespaces).count >= 2)
    }
}
