import StoreKit
import SwiftUI

/// Clingy through StoreKit 2. Products come from App Store Connect in production and from
/// `Aegyo.storekit` while testing, so the whole purchase flow works without a server.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    enum ProductID: String, CaseIterable {
        case monthly = "com.nabeelbukhari.aegyo.clingy.monthly"
        case annual = "com.nabeelbukhari.aegyo.clingy.annual"
        case lifetime = "com.nabeelbukhari.aegyo.clingy.lifetime"
    }

    enum State: Equatable { case loading, ready, unavailable }

    @Published private(set) var products: [Product] = []
    @Published private(set) var state: State = .loading
    @Published private(set) var isPlus = false
    @Published private(set) var activeProductID: String?
    @Published private(set) var renewalDate: Date?
    @Published private(set) var willRenew = true
    @Published private(set) var purchasing = false
    @Published var lastError: String?

    private var updates: Task<Void, Never>?
    private var debugForcePlus = false
    private static let plusCacheKey = "store.isPlus"

    /// Free tier allowances.
    static let freePhotosPerDay = 1

    private init() {
        // Trust the last known state until StoreKit answers, so gates don't flash.
        isPlus = AppGroup.defaults.bool(forKey: Self.plusCacheKey)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-plus") { isPlus = true; debugForcePlus = true }
        #endif
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }

    func load() async {
        do {
            let p = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = p.sorted { order($0) < order($1) }
            state = products.isEmpty ? .unavailable : .ready
        } catch {
            state = .unavailable
        }
        await refreshEntitlements()
    }

    private func order(_ p: Product) -> Int {
        switch ProductID(rawValue: p.id) { case .monthly: 0; case .annual: 1; case .lifetime: 2; case nil: 3 }
    }

    func product(_ id: ProductID) -> Product? { products.first { $0.id == id.rawValue } }

    // MARK: Purchase / restore

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification else { lastError = "Apple couldn't verify that purchase."; return false }
                await t.finish()
                await refreshEntitlements()
                Haptics.success()
                return isPlus
            case .userCancelled: return false
            case .pending: lastError = "Your purchase is waiting for approval."; return false
            @unknown default: return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        purchasing = true
        defer { purchasing = false }
        do { try await AppStore.sync() } catch { lastError = error.localizedDescription }
        await refreshEntitlements()
        if !isPlus { lastError = "No Clingy purchase found for this Apple ID." }
    }

    func refreshEntitlements() async {
        var plus = false
        var active: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if ProductID(rawValue: t.productID) != nil { plus = true; active = t.productID }
        }
        isPlus = plus || debugForcePlus
        activeProductID = active
        AppGroup.defaults.set(plus, forKey: Self.plusCacheKey)
        await refreshRenewal()
    }

    private func refreshRenewal() async {
        renewalDate = nil
        willRenew = true
        guard let group = products.first(where: { $0.subscription != nil })?.subscription?.subscriptionGroupID else { return }
        if let statuses = try? await Product.SubscriptionInfo.status(for: group) {
            for s in statuses {
                guard case .verified(let info) = s.renewalInfo, case .verified(let t) = s.transaction else { continue }
                renewalDate = t.expirationDate
                willRenew = info.willAutoRenew
            }
        }
    }

    // MARK: Display helpers

    var activePlanName: String {
        switch ProductID(rawValue: activeProductID ?? "") {
        case .monthly: "Clingy Monthly"
        case .annual: "Clingy Annual"
        case .lifetime: "Clingy Lifetime"
        case nil: isPlus ? "Plus" : "Free"
        }
    }

    func hasTrial(_ p: Product) -> Bool { p.subscription?.introductoryOffer?.paymentMode == .freeTrial }

    func perMonth(_ p: Product) -> String? {
        guard let sub = p.subscription, sub.subscriptionPeriod.unit == .year else { return nil }
        let monthly = (p.price as NSDecimalNumber).doubleValue / 12
        return p.priceFormatStyle.format(Decimal(monthly))
    }
}

// MARK: - Gate

/// Features that need Clingy. The free tier keeps the daily habit; Clingy is memory and depth.
enum PlusFeature: String {
    case letters = "Open-When letters"
    case voiceNotes = "Voice notes"
    case heartbeat = "Heartbeats"
    case wrapped = "Love Wrapped"
    case lovePass = "Love Pass"
    case forms = "Doki's forms"
    case stars = "Star signs & love forecast"
    case sameSky = "Same Sky"
    case history = "Timeline & progress"
    case unlimitedPhotos = "Unlimited photos"
    case widget = "Photo widget"
    case milestones = "Milestone celebrations"
}

extension View {
    /// Shows the paywall instead of the content until the user has Plus.
    func plusGate(_ feature: PlusFeature) -> some View { modifier(PlusGateModifier(feature: feature)) }
}

private struct PlusGateModifier: ViewModifier {
    let feature: PlusFeature
    @ObservedObject private var store = Store.shared
    func body(content: Content) -> some View {
        if store.isPlus { content } else { PaywallView(highlight: feature) }
    }
}

/// Inline gate for a section inside a tab: shows a compact upsell card instead of the content.
extension View {
    func plusGateInline(_ feature: PlusFeature) -> some View { modifier(PlusInlineGate(feature: feature)) }
}

private struct PlusInlineGate: ViewModifier {
    let feature: PlusFeature
    @ObservedObject private var store = Store.shared
    @State private var paywall = false
    func body(content: Content) -> some View {
        if store.isPlus { content } else {
            Button { Haptics.tap(); paywall = true } label: {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.aegyo(26)).foregroundStyle(Love.pink)
                    Text(feature.rawValue).font(.aegyo(18, .semibold)).foregroundStyle(.white)
                    Text("Part of Clingy. Tap to see what's inside.").font(.aegyo(13)).foregroundStyle(.white.opacity(0.55))
                    WhitePill(title: "Unlock", height: 40)
                }
                .padding(24).frame(maxWidth: .infinity).glass(24)
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .sheet(isPresented: $paywall) { PaywallView(highlight: feature).aegyoSheet([.large]) }
        }
    }
}
