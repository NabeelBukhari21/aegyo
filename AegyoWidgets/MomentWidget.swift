import SwiftUI
import WidgetKit

/// Locket-style Home Screen / Lock Screen widget: her latest photo, or the gem with today's count.
struct MomentEntry: TimelineEntry {
    let date: Date
    let photo: UIImage?
    let sender: String
    let todayCount: Int
}

struct MomentProvider: TimelineProvider {
    func placeholder(in context: Context) -> MomentEntry { MomentEntry(date: .now, photo: nil, sender: "Nabeel", todayCount: 3) }
    func getSnapshot(in context: Context, completion: @escaping (MomentEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MomentEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(1800))))
    }

    private func entry() -> MomentEntry {
        let d = AppGroup.defaults
        return MomentEntry(date: .now,
                           photo: AppGroup.loadPhoto(d.string(forKey: "latestPhotoID")),
                           sender: d.string(forKey: "latestPhotoFrom") ?? Profile.partnerName,
                           todayCount: d.integer(forKey: "sentToday"))
    }
}

struct MomentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MomentEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("aegyo").font(.system(size: 13, weight: .semibold))
                    Text("\(entry.todayCount) moments today").font(.system(size: 12))
                }
            }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill").font(.system(size: 13))
                    Text("\(entry.todayCount)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                }
            }
        default:
            if let photo = entry.photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .overlay(alignment: .bottomLeading) {
                        Text("From \(entry.sender)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(10)
                    }
            } else {
                VStack(spacing: 10) {
                    StaticGem(width: 64)
                    Text("\(entry.todayCount) today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}

struct MomentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AegyoMoment", provider: MomentProvider()) { entry in
            MomentWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.photo != nil { Color.black } else {
                        ZStack {
                            Color.black
                            RadialGradient(colors: [Color(red: 0.31, green: 0.78, blue: 0.75).opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 90)
                        }
                    }
                }
                .widgetURL(URL(string: "aegyo://home"))
        }
        .configurationDisplayName("Her moments")
        .description("Her latest photo, or your gem and today's count.")
        .supportedFamilies([.systemSmall, .systemLarge, .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
