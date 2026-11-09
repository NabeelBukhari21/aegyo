import CoreHaptics
import UIKit

/// Every touch in Aegyo has a feel. Generators are kept warm so feedback is instant.
enum Haptics {
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notify = UINotificationFeedbackGenerator()

    private static var engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let e = try? CHHapticEngine()
        e?.isAutoShutdownEnabled = true
        e?.resetHandler = { try? e?.start() }
        return e
    }()

    /// Any tap anywhere.
    static func touch() { soft.impactOccurred(intensity: 0.45) }
    /// A button going down.
    static func press() { rigid.impactOccurred(intensity: 0.55) }
    /// A soft confirmation tap.
    static func tap() { light.impactOccurred(intensity: 0.8) }
    /// Detents on sliders, pickers, tabs.
    static func tick() { selection.selectionChanged() }
    static func success() { notify.notificationOccurred(.success) }

    /// A soft "lub-dub" heartbeat. `beats` repeats it every 1.2 s.
    static func heartbeat(beats: Int = 1) {
        guard let engine else { rigid.impactOccurred(); return }
        var events: [CHHapticEvent] = []
        for i in 0..<beats {
            let base = Double(i) * 1.2
            events.append(transient(at: base, intensity: 1.0, sharpness: 0.25))
            events.append(transient(at: base + 0.18, intensity: 0.65, sharpness: 0.15))
        }
        play(events, on: engine)
    }

    /// The heart's squeeze: a quick swell then a deep thump, then an echo.
    static func gemPress() {
        guard let engine else { rigid.impactOccurred(); return }
        let swell = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [.init(parameterID: .hapticIntensity, value: 0.35), .init(parameterID: .hapticSharpness, value: 0.1)],
                                  relativeTime: 0, duration: 0.12)
        play([swell, transient(at: 0.12, intensity: 1, sharpness: 0.3), transient(at: 0.30, intensity: 0.55, sharpness: 0.15)], on: engine)
    }

    /// Rising buzz for hold-to-send buttons (0…1).
    static func charge(_ level: Double) {
        rigid.impactOccurred(intensity: 0.2 + 0.8 * min(1, max(0, level)))
    }

    /// A long rumble that fades (screen shake, ring answered).
    static func rumble(duration: Double = 0.45) {
        guard let engine else { rigid.impactOccurred(); return }
        let e = CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [.init(parameterID: .hapticIntensity, value: 0.7), .init(parameterID: .hapticSharpness, value: 0.2)],
                              relativeTime: 0, duration: duration)
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                          controlPoints: [.init(relativeTime: 0, value: 1), .init(relativeTime: duration, value: 0)], relativeTime: 0)
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: [e], parameterCurves: [fade]))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { rigid.impactOccurred() }
    }

    private static func transient(at t: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [.init(parameterID: .hapticIntensity, value: intensity), .init(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: t)
    }

    private static func play(_ events: [CHHapticEvent], on engine: CHHapticEngine) {
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { rigid.impactOccurred() }
    }
}
