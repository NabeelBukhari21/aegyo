import Network
import SwiftUI

/// Watches the network and lets debug builds force "offline" with the `-offline` launch flag.
@MainActor
final class Reachability: ObservableObject {
    static let shared = Reachability()

    @Published private(set) var isOnline = true
    /// Debug: simulate being offline.
    @Published var forcedOffline = false { didSet { update() } }

    private let monitor = NWPathMonitor()
    private var pathOnline = true

    private init() {
        #if DEBUG
        forcedOffline = ProcessInfo.processInfo.arguments.contains("-offline")
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.pathOnline = path.status == .satisfied
                self?.update()
            }
        }
        monitor.start(queue: DispatchQueue(label: "aegyo.reachability"))
    }

    private func update() {
        let now = pathOnline && !forcedOffline
        guard now != isOnline else { return }
        isOnline = now
        if now { Task { await Session.shared.cameOnline() } }
    }
}

/// Thin banner that slides in under the status bar when offline.
struct OfflineBanner: View {
    @ObservedObject private var reach = Reachability.shared
    var pending: Int = 0

    var body: some View {
        VStack {
            if !reach.isOnline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash").font(.aegyo(12, .semibold))
                    Text(pending > 0 ? "Offline · \(pending) waiting to send" : "Offline · sends will go out when you're back")
                        .font(.aegyo(12.5, .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(red: 1, green: 0.85, blue: 0.4), in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Offline. Sends will go out when you're back online.")
            }
            Spacer()
        }
        .padding(.top, 4)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: reach.isOnline)
        .allowsHitTesting(false)
    }
}
