import SwiftUI

/// Renders any SwiftUI card to an image and offers the system share sheet (Instagram Stories, TikTok, Messages…).
struct ShareCardButton<Card: View>: View {
    var title: String = "Share"
    var name: String
    @ViewBuilder var card: () -> Card
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(name, image: image)) {
                    WhitePill(title: title, systemImage: "square.and.arrow.up", height: 52)
                        .frame(maxWidth: .infinity).background(.white, in: Capsule())
                }
                .buttonStyle(PressStyle())
            } else {
                WhitePill(title: title, systemImage: "square.and.arrow.up", height: 52)
                    .frame(maxWidth: .infinity).background(.white, in: Capsule()).opacity(0.4)
            }
        }
        .task { render() }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card().environment(\.colorScheme, .dark))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}

/// Shared frame for every feature sheet: black, title, close button, scrollable content.
struct FeatureSheet<Content: View>: View {
    var title: String
    var subtitle: String?
    var glow = false
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let subtitle {
                        Text(subtitle).font(.system(size: 15)).foregroundStyle(.white.opacity(0.55))
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack {
                    OpalBackground(focus: UnitPoint(x: 0.5, y: 0.15))
                    if glow { SheetGlow().ignoresSafeArea() }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// The aegyo wordmark used on every share card.
struct Wordmark: View {
    var size: CGFloat = 18
    var body: some View {
        HStack(spacing: 6) {
            StaticGem(width: size * 0.95)
            Text("aegyo").font(.system(size: size, weight: .semibold)).tracking(-size * 0.04)
        }
        .foregroundStyle(.white)
    }
}

/// 9:16 story canvas shared by the share cards.
struct StoryCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.31, green: 0.78, blue: 0.75).opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Color(red: 0.59, green: 0.43, blue: 1).opacity(0.22), .clear], center: UnitPoint(x: 0.75, y: 0.25), startRadius: 0, endRadius: 200)
            content.padding(28)
        }
        .frame(width: 360, height: 640)
        .foregroundStyle(.white)
    }
}
