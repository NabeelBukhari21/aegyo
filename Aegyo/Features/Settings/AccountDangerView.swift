import SwiftUI

/// Sign out, unpair and delete account, each behind a confirmation. Delete asks you to type DELETE.
struct AccountDangerView: View {
    @EnvironmentObject private var session: Session
    @State private var confirmSignOut = false
    @State private var confirmUnpair = false
    @State private var deleting = false
    @State private var typed = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        SettingsPage(title: "Account", subtitle: "Three doors. Two of them lock behind you.") {
            SettingsGroup {
                dangerRow("Sign out", line: "Keeps everything on this phone. Sign back in any time.", icon: "rectangle.portrait.and.arrow.right", tint: .white) { confirmSignOut = true }
                if session.isPaired {
                    dangerRow("Unpair", line: "Stops taps reaching each other. Your history stays.", icon: "heart.slash.fill", tint: Color(red: 1, green: 0.7, blue: 0.4)) { confirmUnpair = true }
                }
                dangerRow("Delete account", line: "Removes everything and unpairs you. Cannot be undone.", icon: "trash.fill", tint: Color(red: 1, green: 0.45, blue: 0.45)) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { deleting = true }
                }
            }

            if deleting {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Type DELETE to confirm").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("This removes your account, every photo, letter, mood and tap on this phone, your pairing, and your subscription record on this device (your Apple subscription itself is managed in iOS Settings).")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                    OnboardField(text: $typed, placeholder: "DELETE", capitalization: .characters)
                    Button {
                        guard typed == "DELETE" else { return }
                        Haptics.rumble(duration: 0.3)
                        busy = true
                        Task {
                            do { try await session.deleteAccount() } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        ZStack {
                            Capsule().fill(typed == "DELETE" ? Color(red: 0.95, green: 0.25, blue: 0.3) : .white.opacity(0.1))
                            if busy { ProgressView().tint(.white) } else {
                                Text("Delete my account").font(.system(size: 16, weight: .semibold)).foregroundStyle(typed == "DELETE" ? .white : .white.opacity(0.4))
                            }
                        }
                        .frame(height: 54)
                    }
                    .buttonStyle(PressStyle())
                    .disabled(typed != "DELETE" || busy)
                    Button { Haptics.tap(); withAnimation { deleting = false; typed = "" } } label: {
                        Text("Keep my account").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(18).glass(22)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $confirmSignOut) {
            ConfirmSheet(title: "Sign out?", message: "Your photos, letters and history stay on this phone. You'll see the welcome screens again next time.",
                         confirmTitle: "Sign out", destructive: false) { Task { await session.signOut() } }
        }
        .sheet(isPresented: $confirmUnpair) {
            ConfirmSheet(title: "Unpair?", message: "Your taps will stop reaching each other. Pair again any time with a new code.",
                         confirmTitle: "Unpair") { Task { await session.leaveCouple() } }
        }
        .alert("Couldn't delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func dangerRow(_ title: String, line: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tick(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 32, height: 32).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(tint == .white ? .white : tint)
                    Text(line).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60) }
        }
        .buttonStyle(RowStyle())
    }
}

/// Upsell card in Settings; the paywall itself arrives in Phase 5.
struct PlusTeaserCard: View {
    @State private var showPaywall = false
    var body: some View {
        Button { Haptics.tap(); showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Love.glow).frame(width: 44, height: 44)
                    Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
                .shadow(color: Love.pink.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aegyo Plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("Letters, voice notes, Doki's forms and more.").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Love.pink.opacity(0.18), Love.violet.opacity(0.12)], startPoint: .leading, endPoint: .trailing)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Love.pink.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .sheet(isPresented: $showPaywall) { PaywallPlaceholder() }
    }
}

/// Stands in until the StoreKit paywall lands in Phase 5.
struct PaywallPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(Love.pink)
            Text("Aegyo Plus").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
            Text("The paywall is coming in the next build.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
            Spacer()
            ContinuePill(title: "Close") { dismiss() }.padding(.horizontal, 24).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(OpalBackground())
        .preferredColorScheme(.dark)
    }
}
