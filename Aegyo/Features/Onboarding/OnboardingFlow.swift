import SwiftUI

/// Placeholder until Phase 2: lets the app route while onboarding is built.
struct OnboardingFlow: View {
    @EnvironmentObject private var session: Session
    var body: some View {
        ZStack {
            OpalBackground()
            VStack(spacing: 24) {
                Spacer()
                Text("aegyo").font(.system(size: 40, weight: .semibold)).tracking(-1.5).foregroundStyle(.white)
                Spacer()
                ContinuePill(title: "Get started") {
                    Task {
                        try? await session.signIn(.email(name: Profile.myName, email: "me@local"))
                        session.completeOnboarding()
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
}
