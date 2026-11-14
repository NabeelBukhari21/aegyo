import SwiftUI

// MARK: - Empty state

/// Doki-themed empty state: a small heart, a line of copy, one action.
struct EmptyState: View {
    var icon: String = "heart"
    var title: String
    var message: String
    var action: (title: String, run: () -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Love.pink.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: icon).font(.system(size: 28, weight: .medium)).foregroundStyle(Love.pink)
                    .symbolEffect(.breathe, options: .repeating)
            }
            Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(message).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button { Haptics.tap(); action.run() } label: {
                    WhitePill(title: action.title, height: 44)
                }
                .buttonStyle(PressStyle())
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 34)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Error state

struct ErrorState: View {
    var title: String = "Something went wrong"
    var message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 26)).foregroundStyle(Color(red: 1, green: 0.75, blue: 0.4))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(message).font(.system(size: 14)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            if let retry {
                Button { Haptics.tap(); retry() } label: {
                    Label("Try again", systemImage: "arrow.clockwise").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 40).background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glass(22)
    }
}

// MARK: - Loading (skeleton shimmer)

struct Skeleton: View {
    var height: CGFloat = 18
    var radius: CGFloat = 8
    @State private var x: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.white.opacity(0.07))
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6)
                        .offset(x: x * g.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .frame(height: height)
            .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { x = 1.4 } }
            .accessibilityHidden(true)
    }
}

/// A card-shaped placeholder while content loads.
struct SkeletonCard: View {
    var lines: Int = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Skeleton(height: 12, radius: 6).frame(width: 90)
            ForEach(0..<lines, id: \.self) { i in Skeleton(height: 16).frame(maxWidth: i == lines - 1 ? 180 : .infinity) }
        }
        .padding(16)
        .glass(24)
        .accessibilityLabel("Loading")
    }
}

// MARK: - Success acknowledgement

/// A full-width moment: check draws in, title, optional line.
struct SuccessMoment: View {
    var title: String
    var message: String? = nil
    @State private var drawn = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Love.glow).frame(width: 72, height: 72).shadow(color: Love.pink.opacity(0.6), radius: 18)
                Checkmark().trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: 30, height: 24)
            }
            .scaleEffect(drawn ? 1 : 0.6)
            Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
            if let message { Text(message).font(.system(size: 14)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center) }
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { drawn = true }
        }
    }

    private struct Checkmark: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: r.minX, y: r.midY + 2))
                p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            }
        }
    }
}

// MARK: - Confirmation sheet for destructive actions

struct ConfirmSheet: View {
    var title: String
    var message: String
    var confirmTitle: String
    var destructive = true
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 8)
            Image(systemName: destructive ? "exclamationmark.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 36)).foregroundStyle(destructive ? Color(red: 1, green: 0.4, blue: 0.4) : Love.pink)
            Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(message).font(.system(size: 15)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.gemPress()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: onConfirm)
            } label: {
                Text(confirmTitle).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(destructive ? AnyShapeStyle(Color(red: 0.95, green: 0.25, blue: 0.3)) : AnyShapeStyle(Love.glow), in: Capsule())
            }
            .buttonStyle(PressStyle())
            Button { dismiss() } label: {
                Text("Cancel").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity).frame(height: 50)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 18)
        .presentationDetents([.height(380)])
        .presentationBackground(.black)
        .presentationCornerRadius(36)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Big headline (The Outsiders "First Things First")

struct Headline: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 30, weight: .bold)).tracking(-0.8).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).font(.system(size: 15)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Opal's soft-gradient Continue pill (dims when disabled).
struct ContinuePill: View {
    var title: String = "Continue"
    var enabled = true
    var loading = false
    var action: () -> Void

    var body: some View {
        Button { Haptics.tap(); action() } label: {
            ZStack {
                Capsule().fill(LinearGradient(colors: [Color(red: 0.85, green: 0.8, blue: 0.55), Color(white: 0.75), Color(red: 0.5, green: 0.75, blue: 0.8)],
                                              startPoint: .leading, endPoint: .trailing))
                    .opacity(enabled ? 1 : 0.35)
                if loading {
                    ProgressView().tint(.black)
                } else {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.black.opacity(enabled ? 0.9 : 0.5))
                }
            }
            .frame(height: 54)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled || loading)
    }
}

/// Bold pink pill (The Outsiders primary action).
struct PinkPill: View {
    var title: String
    var systemImage: String? = nil
    var enabled = true
    var action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(enabled ? AnyShapeStyle(Love.glow) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
            .shadow(color: Love.pink.opacity(enabled ? 0.4 : 0), radius: 14, y: 4)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

// MARK: - Pull to refresh helper

extension View {
    /// Pull-to-refresh with a haptic tick, on any ScrollView.
    func aegyoRefreshable(_ action: @escaping () async -> Void) -> some View {
        refreshable {
            Haptics.tick()
            await action()
            Haptics.success()
        }
    }
}
