import ActivityKit
import AVFoundation
import CoreLocation
import UIKit
import UserNotifications
import WidgetKit

/// Sends love and remembers everything.
///
/// Until the two phones are paired (Phase 2: Firebase + APNs), every send plays as a
/// **preview on this phone**, exactly how it will look on hers.
@MainActor
final class LoveService: ObservableObject {
    static let shared = LoveService()

    @Published private(set) var data = LoveData()
    @Published var lastError: String?
    /// Bumps every time love is sent; views use it to fire animations (sparks, shockwaves).
    @Published private(set) var sendPulse = 0

    var isPaired: Bool { false }

    private var sentPlayer: AVAudioPlayer?
    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("aegyo.json")

    init() {
        load()
        recomputeStats()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.recomputeStats() }
        }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.recomputeStats() }
        }
        if let url = Bundle.main.url(forResource: "sent", withExtension: "caf") {
            sentPlayer = try? AVAudioPlayer(contentsOf: url)
            sentPlayer?.volume = 0.55
            sentPlayer?.prepareToPlay()
        }
    }

    // MARK: - Stats (computed once per change, not on every redraw)

    struct Stats {
        var sentToday = 0, totalSent = 0, totalReceived = 0
        var lastSentAt: Date?, lastReceivedAt: Date?
        var streakDays = 0, longestStreak = 0
        var peakHour: Int?
        /// Love per day (both directions), keyed by "yyyy-MM-dd".
        var perDay: [String: Int] = [:]
        var today: [LoveEvent] = []
    }

    @Published private(set) var stats = Stats()

    var sentToday: Int { stats.sentToday }
    var totalSent: Int { stats.totalSent }
    var totalReceived: Int { stats.totalReceived }
    var lastSentAt: Date? { stats.lastSentAt }
    var lastReceivedAt: Date? { stats.lastReceivedAt }
    var streakDays: Int { stats.streakDays }
    var longestStreak: Int { stats.longestStreak }
    var peakHour: Int? { stats.peakHour }
    var tier: GemTier { GemTier.tier(for: stats.totalSent + stats.totalReceived) }

    func todayEvents() -> [LoveEvent] { stats.today }

    /// Love on a given day (both directions).
    func loveCount(on day: Date) -> Int { stats.perDay[DayKey.of(day)] ?? 0 }

    /// One pass over the history.
    private func recomputeStats() {
        let cal = Calendar.current
        var st = Stats()
        let todayKey = DayKey.of(.now)
        var sentDays = Set<String>()
        var hours = [Int](repeating: 0, count: 24)
        for e in data.events {
            let key = DayKey.of(e.date)
            if key == todayKey { st.today.append(e) }
            guard e.kind.countsAsLove else { continue }
            st.perDay[key, default: 0] += 1
            if e.outgoing {
                st.totalSent += 1
                st.lastSentAt = max(st.lastSentAt ?? e.date, e.date)
                sentDays.insert(key)
                if key == todayKey { st.sentToday += 1 }
                if e.kind == .missYou { hours[cal.component(.hour, from: e.date)] += 1 }
            } else {
                st.totalReceived += 1
                st.lastReceivedAt = max(st.lastReceivedAt ?? e.date, e.date)
            }
        }
        // current streak (ending today or yesterday)
        var cursor = Date()
        if !sentDays.contains(DayKey.of(cursor)) { cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
        while sentDays.contains(DayKey.of(cursor)) {
            st.streakDays += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        // longest streak
        let sorted = sentDays.compactMap { DayKey.formatter.date(from: $0) }.sorted()
        var run = 0
        var prev: Date?
        for d in sorted {
            if let p = prev, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            st.longestStreak = max(st.longestStreak, run)
            prev = d
        }
        if let m = hours.max(), m > 0 { st.peakHour = hours.firstIndex(of: m) }
        stats = st
    }

    // MARK: - Photo cache

    private let imageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 60
        return c
    }()

    var distanceKm: Int? {
        guard let a = data.myPlace, let b = data.herPlace else { return nil }
        return Int((a.location.distance(from: b.location) / 1000).rounded())
    }

    // MARK: - Sending

    func send(_ kind: LoveKind, detail: String? = nil, photoID: String? = nil) async {
        record(LoveEvent(date: .now, kind: kind, outgoing: true, detail: detail, photoID: photoID))
        sendPulse += 1
        if kind.countsAsLove { Reminders.shared.lovedToday() }
        if isPaired {
            // Phase 2: Firestore couples/{id}/pings → Cloud Function → APNs push-to-start on her phone.
        } else {
            await previewOnThisPhone(kind, detail: detail, photoID: photoID)
        }
    }

    func setMood(_ mood: Mood) async {
        data.myMood = MoodStatus(mood: mood, at: .now)
        save()
        await send(.mood, detail: mood.name)
    }

    /// Saves the photo, makes a tiny thumbnail for the Dynamic Island, and sends it.
    func sendPhoto(_ image: UIImage, caption: String?) async {
        let id = UUID().uuidString
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        if let full = image.resized(maxSide: 1600).jpegData(compressionQuality: 0.85) {
            try? full.write(to: docs.appendingPathComponent("\(id).jpg"))
        }
        if let thumbURL = AppGroup.photoURL(id), let thumb = image.resized(maxSide: 240).jpegData(compressionQuality: 0.7) {
            try? FileManager.default.createDirectory(at: thumbURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? thumb.write(to: thumbURL)
        }
        data.photos.append(SentPhoto(id: id, date: .now, caption: caption))
        // In preview, your own photo stands in for hers on the Home Screen widget.
        AppGroup.defaults.set(id, forKey: "latestPhotoID")
        AppGroup.defaults.set(Profile.myName, forKey: "latestPhotoFrom")
        save()
        await send(.photo, detail: caption, photoID: id)
    }

    func photoImage(_ id: String) -> UIImage? {
        if let hit = imageCache.object(forKey: id as NSString) { return hit }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos/\(id).jpg")
        guard let img = UIImage(contentsOfFile: url.path)?.preparingForDisplay() else { return nil }
        imageCache.setObject(img, forKey: id as NSString)
        return img
    }

    // MARK: - Letters, questions, places

    func saveLetter(_ letter: Letter) async {
        data.letters.append(letter)
        save()
        await send(.letter, detail: letter.trigger.title)
    }

    func markOpened(_ letter: Letter) {
        guard let i = data.letters.firstIndex(where: { $0.id == letter.id }) else { return }
        data.letters[i].openedAt = .now
        save()
    }

    func answerToday(_ text: String) {
        data.answers[DayKey.of(.now)] = text
        save()
    }

    func setLoveLanguage(_ name: String) {
        data.loveLanguage = name
        save()
    }

    func markMilestoneCelebrated(_ day: Int) {
        data.celebratedMilestones.append(day)
        save()
    }

    /// Looks up a city name and stores its coordinates and time zone.
    func setPlace(_ city: String, mine: Bool) async {
        let trimmed = city.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            if mine { data.myPlace = nil } else { data.herPlace = nil }
            save()
            return
        }
        do {
            let marks = try await CLGeocoder().geocodeAddressString(trimmed)
            guard let m = marks.first, let loc = m.location else { throw CLError(.geocodeFoundNoResult) }
            let place = Place(name: m.locality ?? m.name ?? trimmed, lat: loc.coordinate.latitude,
                              lon: loc.coordinate.longitude, timeZoneID: m.timeZone?.identifier)
            if mine { data.myPlace = place } else { data.herPlace = place }
            save()
        } catch {
            lastError = "Couldn't find “\(trimmed)”. Try the city and country, like “Seoul, South Korea”."
        }
    }

    // MARK: - Ring

    /// Call-style ring. In preview mode it rings *this* phone after a short delay so you can lock it and watch.
    func ring(delay seconds: Double = 4) {
        if isPaired { return } // Phase 4: Firestore rings → VoIP push
        let app = UIApplication.shared
        var task: UIBackgroundTaskIdentifier = .invalid
        task = app.beginBackgroundTask { app.endBackgroundTask(task) }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            CallService.shared.reportIncomingRing(from: Profile.myName) { [weak self] error in
                Task { @MainActor in
                    if error != nil { self?.lastError = "Ringing needs a real iPhone. The Simulator can't show incoming calls." }
                    app.endBackgroundTask(task)
                }
            }
        }
    }

    // MARK: - Countdown in the Dynamic Island

    var countdownActivity: Activity<CountdownAttributes>? { Activity<CountdownAttributes>.activities.first }

    func startCountdown(to date: Date) {
        Task {
            for a in Activity<CountdownAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            do {
                _ = try Activity.request(
                    attributes: CountdownAttributes(partnerName: Profile.partnerName, startDate: .now),
                    content: ActivityContent(state: .init(meetDate: date), staleDate: date),
                    pushType: nil
                )
                objectWillChange.send()
            } catch {
                lastError = "Couldn't start the countdown: \(error.localizedDescription)"
            }
        }
    }

    func stopCountdown() {
        Task {
            for a in Activity<CountdownAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            objectWillChange.send()
        }
    }

    // MARK: - Sound & permissions

    func playSentChime() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        sentPlayer?.currentTime = 0
        sentPlayer?.play()
    }

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Preview (what she'll see)

    /// Island-first: love shows up as a Live Activity that expands in the Dynamic Island with the chime.
    /// No notification banner. Notifications are kept for reminders only (see `Reminders`).
    private func previewOnThisPhone(_ kind: LoveKind, detail: String?, photoID: String?) async {
        let sender = Profile.myName
        let headline = kind.headline(from: sender, detail: detail)
        let alert = AlertConfiguration(title: "\(headline)", body: "\(kind.subtitle(detail: detail))", sound: .named("missyou.caf"))
        let today = todayEvents().filter { $0.kind.countsAsLove }
        let timeline = today.map { Calendar.current.component(.hour, from: $0.date) * 2 + ($0.outgoing ? 0 : 1) }
        let mine = today.filter(\.outgoing).count, hers = today.count - mine

        if let activity = Activity<LoveAttributes>.activities.first(where: { $0.activityState == .active }) {
            var state = activity.content.state
            state.count = state.kind == kind ? state.count + 1 : 1
            state.kind = kind
            state.sentAt = .now
            state.replied = false
            state.photoID = photoID
            state.detail = detail
            state.distanceKm = distanceKm
            state.timeline = timeline; state.mineToday = mine; state.hersToday = hers
            await activity.update(ActivityContent(state: state, staleDate: .now + 3600), alertConfiguration: alert)
        } else {
            do {
                let state = LoveAttributes.ContentState(kind: kind, sentAt: .now, count: 1, replied: false,
                                                        photoID: photoID, detail: detail, distanceKm: distanceKm,
                                                        timeline: timeline, mineToday: mine, hersToday: hers)
                let activity = try Activity.request(
                    attributes: LoveAttributes(senderName: sender),
                    content: ActivityContent(state: state, staleDate: .now + 3600),
                    pushType: nil
                )
                // An immediate update with an alert makes the island expand and chime.
                try? await Task.sleep(for: .milliseconds(300))
                await activity.update(ActivityContent(state: state, staleDate: .now + 3600), alertConfiguration: alert)
            } catch {
                lastError = "Couldn't show it in the Dynamic Island: \(error.localizedDescription)"
            }
        }
    }

    #if DEBUG
    /// Sample data for screenshots only (launch flag -seedDemo). Never used in release builds.
    func seedDemo() {
        guard data.events.isEmpty else { return }
        let cal = Calendar.current
        for d in 0..<6 {
            let day = cal.date(byAdding: .day, value: -d, to: .now)!
            for i in 0..<[9, 4, 6, 2, 7, 3][d] {
                data.events.append(LoveEvent(date: day.addingTimeInterval(Double(-i * 1800)), kind: i % 4 == 0 ? .hug : .missYou, outgoing: i % 3 != 0))
            }
        }
        data.myPlace = Place(name: "Toronto", lat: 43.65, lon: -79.38, timeZoneID: "America/Toronto")
        data.herPlace = Place(name: "Vancouver", lat: 49.28, lon: -123.12, timeZoneID: "America/Vancouver")
        data.herMood = MoodStatus(mood: .sleepy, at: .now.addingTimeInterval(-1200))
        data.myMood = MoodStatus(mood: .loving, at: .now.addingTimeInterval(-300))
        AppGroup.defaults.set(cal.date(byAdding: .day, value: -412, to: .now)!.timeIntervalSince1970, forKey: Profile.togetherSinceKey)
        AppGroup.defaults.set(cal.date(byAdding: .day, value: 12, to: .now)!.timeIntervalSince1970, forKey: Profile.meetDateKey)
        AppGroup.defaults.set("Jagi", forKey: Profile.partnerNameKey)
        save()
    }
    #endif

    // MARK: - Persistence

    private func record(_ e: LoveEvent) {
        data.events.append(e)
        save()
    }

    private static let ioQueue = DispatchQueue(label: "aegyo.save", qos: .utility)

    private func save() {
        recomputeStats()
        let snapshot = data, url = fileURL
        Self.ioQueue.async {
            if let json = try? JSONEncoder().encode(snapshot) { try? json.write(to: url, options: .atomic) }
        }
        AppGroup.defaults.set(totalSent + totalReceived, forKey: GemTier.totalKey)
        AppGroup.defaults.set(sentToday, forKey: "sentToday")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func load() {
        guard let json = try? Data(contentsOf: fileURL), let d = try? JSONDecoder().decode(LoveData.self, from: json) else { return }
        data = d
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
