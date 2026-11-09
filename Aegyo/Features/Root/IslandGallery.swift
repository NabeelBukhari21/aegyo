#if DEBUG
import SwiftUI

/// Debug-only: draws each Dynamic Island design in a mock island so it can be screenshotted
/// (the Simulator can't capture the real island). Launch with -islandGallery.
struct IslandGallery: View {
    private let samples: [LoveAttributes.ContentState] = [
        .init(kind: .missYou, sentAt: .now, count: 3, replied: false, detail: "8/10",
              timeline: [16, 18, 19, 26, 27, 34, 40, 41, 42], mineToday: 6, hersToday: 3),
        .init(kind: .light, sentAt: .now, count: 1, replied: false, distanceKm: 2140),
        .init(kind: .tapCode, sentAt: .now, count: 1, replied: false, detail: "200,700,1100,2300,2700,3900"),
        .init(kind: .goodnight, sentAt: .now, count: 1, replied: false),
        .init(kind: .mood, sentAt: .now, count: 1, replied: false, detail: "Sleepy"),
        .init(kind: .hug, sentAt: .now, count: 2, replied: false),
        .init(kind: .letter, sentAt: .now, count: 1, replied: false, detail: "Open when you can't sleep"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                    island(s)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 60)
        }
        .background(Color(white: 0.85).ignoresSafeArea())
    }

    private func island(_ s: LoveAttributes.ContentState) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                DotMatrix(cols: 13, rows: 9, dot: 2.6, gap: 0.9, dimOpacity: 0) { c, r in Pixels.bigHeart(c, r) ? kindColor(s) : nil }
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.kind.headline(from: "Nabeel", detail: s.detail)).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(s.kind.subtitle(detail: s.detail)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("9:41").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            }
            HStack(alignment: .bottom, spacing: 10) {
                IslandScene(state: s, sender: "Nabeel").frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill").font(.system(size: 15, weight: .semibold))
                    Text("Too").font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.black).frame(width: 58, height: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .background(alignment: .bottom) { BottomGlow(color: kindColor(s)) }
        }
        .padding(16)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    }
}
#endif
