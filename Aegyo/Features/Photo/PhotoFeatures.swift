import PhotosUI
import SwiftUI

/// "Send a photo" — it pops open in her Dynamic Island and lands on her Home Screen widget.
struct PhotoCard: View {
    @EnvironmentObject private var love: LoveService
    @State private var item: PhotosPickerItem?
    @State private var picked: UIImage?
    @State private var viewing: SentPhoto?

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: "Moments")
                        Text("Send a photo to her Dynamic Island")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    PhotosPicker(selection: $item, matching: .images) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(PressStyle())
                }

                if love.data.photos.isEmpty {
                    PhotosPicker(selection: $item, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 18))
                            Text("Your first moment goes here").font(.system(size: 14))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity).frame(height: 88)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                } else {
                    Marquee(items: love.data.photos.reversed(), cellWidth: 88) { p in
                        Button { viewing = p } label: {
                            Group {
                                if let img = love.photoImage(p.id) { Image(uiImage: img).resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                    .frame(height: 88)
                }
            }
        }
        .onChange(of: item) {
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    picked = img
                }
                self.item = nil
            }
        }
        .sheet(item: Binding(get: { picked.map(IdentifiedImage.init) }, set: { picked = $0?.image })) { wrap in
            PhotoComposer(image: wrap.image)
                .presentationBackground(.black)
                .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $viewing) { p in PhotoViewer(photo: p) }
    }
}

struct IdentifiedImage: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

struct PhotoComposer: View {
    let image: UIImage
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var sending = false

    var body: some View {
        VStack(spacing: 18) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .top) {
                    // a tiny preview of how it lands in her Dynamic Island
                    HStack(spacing: 10) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Profile.myName) sent a photo").font(.system(size: 13, weight: .semibold))
                            Text(caption.isEmpty ? "Tap to open it" : caption).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(.black, in: Capsule())
                    .padding(12)
                    .offset(y: sending ? -500 : 0)
                }
                .scaleEffect(sending ? 0.2 : 1, anchor: .top)
                .opacity(sending ? 0 : 1)

            TextField("", text: $caption, prompt: Text("Add a little note").foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).frame(height: 52)
                .glass(26)

            Spacer(minLength: 0)

            Button {
                Haptics.gemPress()
                love.playSentChime()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { sending = true }
                Task {
                    await love.sendPhoto(image, caption: caption.isEmpty ? nil : caption)
                    try? await Task.sleep(for: .milliseconds(450))
                    dismiss()
                }
            } label: {
                WhitePill(title: "Send to her Dynamic Island", systemImage: "arrow.up", height: 54)
                    .frame(maxWidth: .infinity).background(.white, in: Capsule())
            }
            .buttonStyle(PressStyle())
        }
        .padding(20)
        .preferredColorScheme(.dark)
    }
}

struct PhotoViewer: View {
    let photo: SentPhoto
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var drag: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(0.6, abs(drag.height) / 500)).ignoresSafeArea()
            if let img = love.photoImage(photo.id) {
                Image(uiImage: img).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(12)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .offset(drag)
                    .gesture(DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { v in
                            if abs(v.translation.height) > 140 { dismiss() } else { withAnimation(.spring) { drag = .zero } }
                        })
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photo.outgoing ? "You sent" : "From \(Profile.partnerName)").font(.system(size: 15, weight: .semibold))
                        Text(photo.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40).background(.white.opacity(0.12), in: Circle())
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
                Spacer()
                if let c = photo.caption {
                    Text(c).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 14).glass(22).padding(.bottom, 30)
                }
            }
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }
}

// MARK: - Countdown

/// "Next time together" — days counter, progress, and a Dynamic Island countdown.
struct CountdownCard: View {
    @EnvironmentObject private var love: LoveService
    @AppStorage(Profile.meetDateKey, store: AppGroup.defaults) private var meetDate: Double = 0
    @State private var editing = false

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CapsLabel(text: "Next time together")
                    Spacer()
                    Button { Haptics.tap(); editing = true } label: {
                        Text(meetDate > 0 ? "Change" : "Set date").font(.system(size: 13, weight: .medium)).foregroundStyle(Opal.mint)
                    }
                }
                if meetDate > 0 {
                    let date = Date(timeIntervalSince1970: meetDate)
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(days)")
                                    .font(.system(size: 52, weight: .light)).tracking(-2).monospacedDigit()
                                    .contentTransition(.numericText(value: Double(days)))
                                Text(days == 1 ? "day to go" : days == 0 ? "today" : "days to go")
                                    .font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                            }
                            .foregroundStyle(.white)
                            ProgressBar(value: progress(to: date))
                            Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Button {
                        Haptics.tap()
                        if love.countdownActivity != nil { love.stopCountdown() } else { love.startCountdown(to: date) }
                    } label: {
                        Label(love.countdownActivity != nil ? "Remove from Dynamic Island" : "Show in Dynamic Island",
                              systemImage: love.countdownActivity != nil ? "minus.circle" : "capsule.inset.filled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                } else {
                    Text("Set the day you'll see each other and watch it count down, right in the Dynamic Island.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .sheet(isPresented: $editing) {
            MeetDatePicker(date: $meetDate).aegyoSheet([.large])
        }
    }

    private func progress(to date: Date) -> Double {
        let start = Profile.togetherSince.map { max($0, date.addingTimeInterval(-86400 * 60)) } ?? date.addingTimeInterval(-86400 * 30)
        let total = date.timeIntervalSince(start)
        return total > 0 ? min(1, max(0, Date().timeIntervalSince(start) / total)) : 1
    }
}

/// Mint gradient progress bar with a soft moving sheen.
struct ProgressBar: View {
    var value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.70, green: 0.55, blue: 1), Opal.mint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * value))
                    .overlay { Sheen().clipShape(Capsule()) }
                    .animation(.smooth(duration: 1), value: value)
            }
        }
        .frame(height: 8)
    }
}

/// A light sweeping across, run as a single repeating animation (no per-frame rebuilds).
private struct Sheen: View {
    @State private var go = false
    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 60)
                .offset(x: go ? geo.size.width + 60 : -60)
                .onAppear { withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { go = true } }
        }
    }
}
