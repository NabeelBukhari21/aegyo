import SwiftUI

/// Bookmarked photos and letters.
struct SavedView: View {
    @EnvironmentObject private var love: LoveService
    @State private var viewing: SentPhoto?

    private var photos: [SentPhoto] { love.data.photos.filter { love.isSaved($0.id) }.sorted { $0.date > $1.date } }
    private var letters: [Letter] { love.data.letters.filter { love.isSaved($0.id.uuidString) }.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        FeatureSheet(title: "Saved", subtitle: "The ones you want to keep close.") {
            if photos.isEmpty && letters.isEmpty {
                EmptyState(icon: "bookmark", title: "Nothing saved yet", message: "Tap the bookmark on a photo or a letter and it lands here.")
            }
            if !photos.isEmpty {
                CapsLabel(text: "Photos").padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(photos) { p in
                        Button { Haptics.tap(); viewing = p } label: {
                            Group {
                                if let img = love.photoImage(p.id) { Image(uiImage: img).resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                            }
                            .frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            if !letters.isEmpty {
                CapsLabel(text: "Letters").padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(letters) { l in
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill").foregroundStyle(Love.peach).frame(width: 36, height: 36).background(Love.peach.opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.trigger.title).font(.aegyo(14.5, .semibold)).foregroundStyle(.white)
                                Text(l.body).font(.aegyo(12.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                            }
                            Spacer()
                            Button { Haptics.tick(); love.toggleSaved(l.id.uuidString) } label: { Image(systemName: "bookmark.fill").foregroundStyle(Love.pink) }
                                .accessibilityLabel("Remove from saved")
                        }
                        .padding(14)
                        if l.id != letters.last?.id { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 62) }
                    }
                }
                .glass(22)
            }
        }
        .fullScreenCover(item: $viewing) { PhotoViewer(photo: $0) }
    }
}

/// Bookmark toggle used on photos and letters.
struct SaveButton: View {
    let id: String
    @EnvironmentObject private var love: LoveService
    var body: some View {
        let on = love.isSaved(id)
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { love.toggleSaved(id) }
        } label: {
            Image(systemName: on ? "bookmark.fill" : "bookmark").font(.aegyo(15, .semibold))
                .foregroundStyle(on ? Love.pink : .white)
                .frame(width: 40, height: 40).background(.white.opacity(0.12), in: Circle())
                .symbolEffect(.bounce, value: on)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(on ? "Remove from saved" : "Save")
    }
}
