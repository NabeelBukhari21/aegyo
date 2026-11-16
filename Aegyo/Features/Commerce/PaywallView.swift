import StoreKit
import SwiftUI

/// The Outsiders-style paywall: laurels around the icon, a "made with love" ribbon, three plan cards
/// with the annual one marked best offer, a trial CTA, "Cancel anytime", restore and legal links.
struct PaywallView: View {
    var highlight: PlusFeature? = nil
    @ObservedObject private var store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Store.ProductID = .annual
    @State private var thanks = false
    @State private var appeared = false

    private let features: [(String, String)] = [
        ("envelope.fill", "Open-When letters, sealed until the right moment"),
        ("waveform", "Voice notes and tap-code heartbeats"),
        ("photo.on.rectangle.angled", "Unlimited photos, plus the Home Screen widget"),
        ("sparkles.rectangle.stack.fill", "Love Wrapped, Love Pass and milestone cards to share"),
        ("heart.fill", "\(Doki.name)'s forms: Rose Quartz, Moonstone, Aurora, Diamond"),
        ("moon.stars.fill", "Star signs, love forecast and Same Sky"),
        ("chart.bar.fill", "Your timeline, progress and calendar"),
    ]

    var body: some View {
        ZStack {
            OpalBackground(focus: UnitPoint(x: 0.5, y: 0.12))
            if thanks {
                ThankYouView { dismiss() }.transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        header.stagger(appeared, 0)
                        featureList.stagger(appeared, 1)
                        plans.stagger(appeared, 2)
                        cta.stagger(appeared, 3)
                        footer.stagger(appeared, 4)
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { Haptics.tap(); dismiss() } label: {
                        Image(systemName: "xmark").font(.aegyo(13, .bold)).foregroundStyle(.white)
                            .frame(width: 32, height: 32).background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20).padding(.top, 14)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task { try? await Task.sleep(for: .milliseconds(120)); withAnimation(.smooth(duration: 0.8)) { appeared = true } }
        .onChange(of: store.isPlus) { _, plus in if plus { withAnimation(.smooth) { thanks = true } } }
        .alert("Hmm", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.lastError ?? "") }
    }

    // MARK: Header with laurels

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Laurel(flipped: false)
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.8, blue: 0.74), Color(red: 1, green: 0.5, blue: 0.66), Color(red: 0.72, green: 0.6, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .shadow(color: Love.pink.opacity(0.5), radius: 20)
                    Image(systemName: "heart.fill").font(.aegyo(46)).foregroundStyle(.white.opacity(0.95))
                }
                Laurel(flipped: true)
            }
            .padding(.top, 36)
            Text("Aegyo Plus").font(.aegyo(30, .bold)).tracking(-0.8).foregroundStyle(.white)
            Text(highlight.map { "\($0.rawValue) is part of Plus. Everything else is too." } ?? "Every way to feel close. Because distance deserves more than a text.")
                .font(.aegyo(14.5)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 10)
            HStack(spacing: 8) {
                Image(systemName: "laurel.leading").font(.aegyo(14)).foregroundStyle(.white.opacity(0.6))
                VStack(spacing: 1) {
                    Text("Made with love by").font(.aegyo(10)).foregroundStyle(.white.opacity(0.5))
                    Text("a long-distance couple").font(.aegyo(12, .semibold)).foregroundStyle(.white.opacity(0.85))
                }
                Image(systemName: "laurel.trailing").font(.aegyo(14)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glass(18)
        }
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                HStack(spacing: 12) {
                    Image(systemName: f.0).font(.aegyo(14, .semibold)).foregroundStyle(Love.pink).frame(width: 24)
                    Text(f.1).font(.aegyo(14)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "checkmark").font(.aegyo(12, .bold)).foregroundStyle(Opal.mint)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                if i < features.count - 1 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 52) }
            }
        }
        .glass(22)
    }

    // MARK: Plans

    private var plans: some View {
        Group {
            switch store.state {
            case .loading:
                HStack(spacing: 10) { ForEach(0..<3, id: \.self) { _ in Skeleton(height: 118, radius: 18) } }
            case .unavailable:
                ErrorState(title: "Can't reach the App Store", message: "Plans will appear once you're online.") { Task { await store.load() } }
            case .ready:
                HStack(spacing: 10) {
                    ForEach(store.products, id: \.id) { p in planCard(p) }
                }
            }
        }
    }

    private func planCard(_ p: Product) -> some View {
        let id = Store.ProductID(rawValue: p.id) ?? .monthly
        let on = selected == id
        return Button {
            Haptics.tick()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = id }
        } label: {
            VStack(spacing: 6) {
                Text(id == .monthly ? "Monthly" : id == .annual ? "Annual" : "Lifetime").font(.aegyo(13, .semibold)).foregroundStyle(.white.opacity(0.75))
                Text(p.displayPrice).font(.aegyo(19, .bold)).foregroundStyle(.white).minimumScaleFactor(0.7)
                Text(id == .monthly ? "/month" : id == .annual ? "/year" : "/once").font(.aegyo(11)).foregroundStyle(.white.opacity(0.5))
                if let pm = store.perMonth(p) { Text("\(pm)/mo").font(.aegyo(10.5, .medium)).foregroundStyle(Opal.mint) }
            }
            .frame(maxWidth: .infinity).frame(height: 118)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Color.white.opacity(0.12) : Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? Love.pink : .white.opacity(0.12), lineWidth: on ? 2 : 1))
            .overlay(alignment: .top) {
                if id == .annual {
                    Text("BEST OFFER").font(.aegyo(9, .bold)).tracking(0.8).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.white, in: Capsule()).offset(y: -10)
                }
            }
            .scaleEffect(on ? 1.03 : 1)
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .accessibilityLabel("\(id == .monthly ? "Monthly" : id == .annual ? "Annual" : "Lifetime") \(p.displayPrice)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: CTA

    private var cta: some View {
        VStack(spacing: 10) {
            let product = store.product(selected)
            let trial = product.map(store.hasTrial) ?? false
            Button {
                guard let product else { return }
                Haptics.gemPress()
                Task { await store.purchase(product) }
            } label: {
                ZStack {
                    Capsule().fill(Love.glow).shadow(color: Love.pink.opacity(0.5), radius: 16, y: 4)
                    if store.purchasing { ProgressView().tint(.white) } else {
                        Text(trial ? "Start 1 week Free Trial" : selected == .lifetime ? "Get Plus forever" : "Continue")
                            .font(.aegyo(16, .semibold)).foregroundStyle(.white)
                    }
                }
                .frame(height: 56)
            }
            .buttonStyle(PressStyle())
            .disabled(product == nil || store.purchasing)
            Text(trial ? "Free for 7 days, then \(product?.displayPrice ?? "")\(selected == .monthly ? "/month" : "/year"). Cancel anytime." : selected == .lifetime ? "One payment. Yours for good." : "Cancel anytime.")
                .font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { Haptics.tap(); Task { await store.restore() } } label: {
                Text("Restore purchases").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.75))
            }
            HStack(spacing: 16) {
                NavigationLink { LegalView(document: .terms) } label: { Text("Terms").font(.aegyo(12)).foregroundStyle(.white.opacity(0.5)) }
                NavigationLink { LegalView(document: .privacy) } label: { Text("Privacy").font(.aegyo(12)).foregroundStyle(.white.opacity(0.5)) }
            }
            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Manage them in iOS Settings → Apple ID → Subscriptions.")
                .font(.aegyo(11)).foregroundStyle(.white.opacity(0.35)).multilineTextAlignment(.center)
        }
    }
}

/// A laurel branch drawn from leaves, mirrored on the other side.
struct Laurel: View {
    var flipped: Bool
    var body: some View {
        Canvas { g, size in
            let n = 7
            for i in 0..<n {
                let t = Double(i) / Double(n - 1)
                let angle = -0.9 + t * 1.8
                let r = size.height * 0.5
                let c = CGPoint(x: size.width * (flipped ? 0.2 : 0.8) + (flipped ? 1 : -1) * CGFloat(cos(angle)) * r * 0.9, y: size.height / 2 + CGFloat(sin(angle)) * r)
                var leaf = Path()
                leaf.move(to: c)
                leaf.addQuadCurve(to: CGPoint(x: c.x + (flipped ? 14 : -14), y: c.y - 6), control: CGPoint(x: c.x + (flipped ? 8 : -8), y: c.y - 10))
                leaf.addQuadCurve(to: c, control: CGPoint(x: c.x + (flipped ? 8 : -8), y: c.y + 2))
                g.fill(leaf, with: .color(.white.opacity(0.75)))
            }
        }
        .frame(width: 44, height: 90)
        .accessibilityHidden(true)
    }
}

/// After a purchase: the heart glows, confetti, one line, done.
struct ThankYouView: View {
    var onDone: () -> Void
    @State private var thump = 0
    var body: some View {
        ZStack {
            ConfettiBurst()
            VStack(spacing: 18) {
                Spacer()
                Heart3DView(tint: GemTier.aurora.heartTint, thump: thump, interactive: false).frame(height: 260)
                Text("Welcome to Plus").font(.aegyo(28, .bold)).tracking(-0.8).foregroundStyle(.white)
                Text("Everything is unlocked. Go make \(AppGroup.defaults.string(forKey: Profile.partnerNameKey).flatMap { $0.isEmpty ? nil : $0 } ?? "them") smile.")
                    .font(.aegyo(15)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                Spacer()
                ContinuePill(title: "Let's go") { onDone() }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        .onAppear { Haptics.heartbeat(beats: 2); thump += 1 }
    }
}

/// Subscription screen in Settings: current plan, renewal, manage, restore.
struct SubscriptionView: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false

    var body: some View {
        SettingsPage(title: "Aegyo Plus", subtitle: store.isPlus ? "Thank you for supporting a tiny app." : "More ways to feel close.") {
            SettingsGroup(title: "Your plan") {
                InfoRow(title: "Plan", value: store.activePlanName)
                if store.isPlus, let d = store.renewalDate, store.activeProductID != Store.ProductID.lifetime.rawValue {
                    InfoRow(title: store.willRenew ? "Renews" : "Expires", value: d.formatted(date: .abbreviated, time: .omitted))
                }
                if !store.isPlus {
                    InfoRow(title: "Photos today", value: "\(Store.freePhotosPerDay) free")
                }
            }
            if store.isPlus {
                PinkPill(title: "Manage subscription", systemImage: "gear") {
                    if let u = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(u) }
                }
            } else {
                PinkPill(title: "See Plus plans", systemImage: "sparkles") { showPaywall = true }
            }
            Button { Haptics.tap(); Task { await store.restore() } } label: {
                Text("Restore purchases").font(.aegyo(14, .medium)).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity)
            }
            .buttonStyle(PressStyle())
        }
        .sheet(isPresented: $showPaywall) { PaywallView().aegyoSheet([.large]) }
        .alert("Hmm", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.lastError ?? "") }
    }
}
