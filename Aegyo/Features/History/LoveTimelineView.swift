import SwiftUI

/// Everything you two sent each other, newest first, grouped by day. Searchable. Swipe to delete.
struct LoveTimelineView: View {
    @EnvironmentObject private var love: LoveService
    @EnvironmentObject private var session: Session
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var deleting: LoveEvent?
    @State private var loading = true

    enum Filter: Hashable { case all, mine, theirs }

    private var events: [LoveEvent] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return love.data.events
            .filter { filter == .all || ($0.outgoing ? filter == .mine : filter == .theirs) }
            .filter { q.isEmpty || $0.kind.label.lowercased().contains(q) || ($0.detail ?? "").lowercased().contains(q) || $0.kind.headline(from: who($0), detail: $0.detail).lowercased().contains(q) }
            .sorted { $0.date > $1.date }
    }

    private var days: [(String, [LoveEvent])] {
        let grouped = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { (dayTitle($0), grouped[$0]!) }
    }

    var body: some View {
        FeatureSheet(title: "Timeline", subtitle: "Every heartbeat between you two.") {
            SearchField(text: $query, placeholder: "Search letters, moods, moments…")
            PillSegmented(options: [(.all, "All"), (.mine, "You"), (.theirs, partnerName)], selection: $filter)

            if loading {
                SkeletonCard(); SkeletonCard(lines: 2)
            } else if events.isEmpty {
                EmptyState(icon: query.isEmpty ? "heart" : "magnifyingglass",
                           title: query.isEmpty ? "Nothing here yet" : "No matches",
                           message: query.isEmpty ? "Tap \(Doki.name) and your first moment lands here." : "Try another word, or clear the search.")
            } else {
                ForEach(days, id: \.0) { title, items in
                    VStack(alignment: .leading, spacing: 8) {
                        CapsLabel(text: title).padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(items) { e in
                                TimelineRow(event: e, who: who(e))
                                    .contextMenu {
                                        Button(role: .destructive) { deleting = e } label: { Label("Delete", systemImage: "trash") }
                                    }
                                if e.id != items.last?.id { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 60) }
                            }
                        }
                        .glass(22)
                    }
                }
            }
        }
        .aegyoRefreshable { await session.refreshPairing() }
        .task { try? await Task.sleep(for: .milliseconds(350)); withAnimation(.smooth) { loading = false } }
        .sheet(item: $deleting) { e in
            ConfirmSheet(title: "Delete this moment?", message: "It disappears from your timeline and stats on this phone.", confirmTitle: "Delete") {
                love.deleteEvent(e)
            }
        }
    }

    private var partnerName: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "Them" : n.capitalized(with: nil)
    }

    private func who(_ e: LoveEvent) -> String { e.outgoing ? Profile.myName : partnerName }

    private func dayTitle(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct TimelineRow: View {
    let event: LoveEvent
    let who: String
    @EnvironmentObject private var love: LoveService

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((event.outgoing ? Love.pink : Love.violet).opacity(0.14)).frame(width: 40, height: 40)
                if event.kind == .photo, let id = event.photoID, let img = love.photoImage(id) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                } else {
                    Image(systemName: event.kind.symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(event.outgoing ? Love.pink : Love.violet)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.kind.headline(from: who, detail: event.detail)).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(line).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer()
            if event.kind == .voice, let id = event.photoID {
                VoicePlayButton(id: id, duration: parse(event.detail))
            }
            Text(event.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func parse(_ s: String?) -> TimeInterval {
        let p = (s ?? "0:00").split(separator: ":").compactMap { Double($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }

    private var line: String {
        switch event.kind {
        case .missYou: event.detail.map { "Missing \(event.outgoing ? "them" : "you") \($0)" } ?? "A heartbeat"
        case .photo: event.detail ?? "A photo"
        case .letter: event.detail ?? "A sealed letter"
        case .tapCode: "A tapped rhythm"
        case .voice: "A voice note"
        default: event.kind.subtitle(detail: event.detail)
        }
    }
}

/// Rounded search field in Aegyo's style.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 15)).foregroundStyle(.white).focused($focused).autocorrectionDisabled()
            if !text.isEmpty {
                Button { Haptics.tick(); text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4)) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(height: 46)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(focused ? Love.pink.opacity(0.6) : .white.opacity(0.1), lineWidth: 1))
        .animation(.smooth, value: focused)
    }
}
