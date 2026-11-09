import SwiftUI

@main
struct AegyoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var love = LoveService.shared
    @StateObject private var tokens = TokenStore.shared
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(love)
                .environmentObject(tokens)
                .environmentObject(appState)
        }
    }
}

/// Small bits of global UI state (e.g. "she rang you" sheet after answering a Ring).
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var answeredRingFrom: String?
}
