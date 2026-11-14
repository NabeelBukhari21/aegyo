import SwiftUI

@main
struct AegyoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var love = LoveService.shared
    @StateObject private var tokens = TokenStore.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var session = Session.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.route {
                case .loading:
                    Color.black.ignoresSafeArea()
                case .onboarding:
                    OnboardingFlow().transition(.opacity)
                case .app:
                    RootView().transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
            .animation(.smooth(duration: 0.5), value: session.route)
            .environmentObject(love)
            .environmentObject(tokens)
            .environmentObject(appState)
            .environmentObject(session)
            .task { await session.start() }
        }
    }
}

/// Small bits of global UI state (e.g. "she rang you" sheet after answering a Ring).
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var answeredRingFrom: String?
}
