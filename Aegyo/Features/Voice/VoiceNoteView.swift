import AVFoundation
import SwiftUI

/// Record a voice note (up to 60 s) with a live waveform, listen back, send.
struct VoiceNoteView: View {
    @EnvironmentObject private var love: LoveService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = VoiceRecorder()
    @State private var sent = false
    @State private var denied = false

    var body: some View {
        FeatureSheet(title: "Voice note", subtitle: "Say it in your own voice. Up to a minute.", glow: true) {
            VStack(spacing: 18) {
                Waveform(levels: rec.levels, playhead: rec.playhead, live: rec.isRecording)
                    .frame(height: 120)
                    .padding(.horizontal, 6)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(timeText(rec.isPlaying ? rec.playTime : rec.duration)).font(.system(size: 38, weight: .light)).monospacedDigit()
                    Text("/ 1:00").font(.system(size: 14)).foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white)

                if rec.hasRecording && !rec.isRecording {
                    HStack(spacing: 12) {
                        Button { Haptics.tap(); rec.togglePlay() } label: {
                            Image(systemName: rec.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 64, height: 64).background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(rec.isPlaying ? "Pause" : "Play")
                        Button { Haptics.tick(); rec.discard() } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                                .frame(width: 64, height: 64).background(.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Record again")
                    }
                } else {
                    RecordButton(recording: rec.isRecording) {
                        if rec.isRecording { rec.stop() } else { start() }
                    }
                }

                Text(rec.isRecording ? "Tap to stop" : rec.hasRecording ? "Listen back, or send it over." : "Tap to start recording")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            if rec.hasRecording && !rec.isRecording {
                MorphSendButton(title: sent ? "Sent" : "Send to \(partner)", systemImage: "paperplane.fill") {
                    guard let url = rec.fileURL else { return }
                    love.playSentChime()
                    await love.sendVoice(url: url, duration: rec.duration, peaks: rec.levels)
                    await MainActor.run { sent = true }
                    try? await Task.sleep(for: .milliseconds(900))
                    await MainActor.run { dismiss() }
                }
            }
        }
        .alert("Microphone is off", isPresented: $denied) {
            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Allow Aegyo to use the microphone in iOS Settings to record a voice note.") }
        .onDisappear { rec.stopAll() }
    }

    private var partner: String {
        let n = AppGroup.defaults.string(forKey: Profile.partnerNameKey) ?? ""
        return n.isEmpty ? "them" : n.capitalized(with: nil)
    }

    private func start() {
        Haptics.press()
        Task {
            let ok = await rec.requestPermission()
            if ok { rec.start() } else { denied = true }
        }
    }

    private func timeText(_ t: TimeInterval) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }
}

/// Big round record button: pulses while recording.
struct RecordButton: View {
    var recording: Bool
    var action: () -> Void
    @State private var pulse = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Love.pink.opacity(0.18)).frame(width: 96, height: 96).scaleEffect(recording && pulse ? 1.25 : 1)
                Circle().fill(Love.glow).frame(width: 76, height: 76).shadow(color: Love.pink.opacity(0.6), radius: 16)
                RoundedRectangle(cornerRadius: recording ? 6 : 24, style: .continuous).fill(.white).frame(width: recording ? 26 : 24, height: recording ? 26 : 24)
            }
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: recording)
        .accessibilityLabel(recording ? "Stop recording" : "Start recording")
    }
}

/// Bars from meter levels (0…1). A playhead sweeps during playback.
struct Waveform: View {
    var levels: [Float]
    var playhead: Double = 0
    var live = false
    var tint: Color = Love.pink
    var body: some View {
        GeometryReader { geo in
            let n = max(1, levels.count)
            let w = max(2, min(5, (geo.size.width - CGFloat(n) * 2) / CGFloat(n)))
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, l in
                    Capsule()
                        .fill(Double(i) / Double(n) <= playhead || live ? tint : .white.opacity(0.25))
                        .frame(width: w, height: max(4, CGFloat(l) * geo.size.height))
                        .animation(.linear(duration: 0.05), value: l)
                }
                if levels.isEmpty {
                    Capsule().fill(.white.opacity(0.12)).frame(height: 3).frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: live ? .trailing : .center)
        }
        .accessibilityHidden(true)
    }
}

/// AVAudioRecorder with metering for the live waveform, plus playback.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var levels: [Float] = []
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var playTime: TimeInterval = 0
    @Published var hasRecording = false
    var playhead: Double { duration > 0 ? playTime / duration : 0 }
    private(set) var fileURL: URL?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    static let maxSeconds: TimeInterval = 60

    func requestPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            fileURL = url
            levels = []
            duration = 0
            isRecording = true
            hasRecording = false
            Haptics.tick()
            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            isRecording = false
        }
    }

    private func tick() {
        guard let r = recorder, isRecording else { return }
        r.updateMeters()
        let db = r.averagePower(forChannel: 0)
        let lin = max(0, min(1, (db + 50) / 50))
        levels.append(powf(lin, 1.4))
        if levels.count > 110 { levels.removeFirst() }
        duration = r.currentTime
        if duration >= Self.maxSeconds { stop() }
    }

    func stop() {
        timer?.invalidate()
        recorder?.stop()
        isRecording = false
        hasRecording = duration > 0.4
        if !hasRecording { discard() } else { Haptics.success() }
    }

    func togglePlay() {
        if isPlaying { player?.pause(); isPlaying = false; timer?.invalidate(); return }
        guard let url = fileURL else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        if player == nil { player = try? AVAudioPlayer(contentsOf: url); player?.delegate = self }
        player?.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.playTime = self?.player?.currentTime ?? 0 }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false; self.playTime = 0; self.timer?.invalidate() }
    }

    func discard() {
        stopAll()
        if let f = fileURL { try? FileManager.default.removeItem(at: f) }
        fileURL = nil; levels = []; duration = 0; playTime = 0; hasRecording = false
    }

    func stopAll() {
        timer?.invalidate()
        recorder?.stop(); player?.stop(); player = nil
        isRecording = false; isPlaying = false
    }
}

/// Plays a saved voice note inline (timeline row, Moments card).
struct VoicePlayButton: View {
    let id: String
    let duration: TimeInterval
    @EnvironmentObject private var love: LoveService
    @State private var player: AVAudioPlayer?
    @State private var playing = false

    var body: some View {
        Button {
            Haptics.tap()
            if playing { player?.stop(); playing = false; return }
            guard let url = love.voiceURL(id) else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
            playing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? duration) + 0.2) { playing = false }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: playing ? "stop.fill" : "play.fill").font(.system(size: 11, weight: .bold))
                Text(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10).frame(height: 28).background(.white, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(playing ? "Stop voice note" : "Play voice note")
    }
}
