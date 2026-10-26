import CoreHaptics
import Foundation
import os
import QuartzCore
import UIKit

/// One haptic note: a transient tap or a short continuous buzz (times relative to the cue's start).
struct FeelHapticNote: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case transient, continuous }
    var kind: Kind
    var time: Double
    var intensity: Float
    var sharpness: Float
    var duration: Double

    static func tap(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> FeelHapticNote {
        FeelHapticNote(kind: .transient, time: time, intensity: intensity, sharpness: sharpness, duration: 0)
    }

    static func buzz(_ intensity: Float, _ sharpness: Float, at time: Double = 0, duration: Double) -> FeelHapticNote {
        FeelHapticNote(kind: .continuous, time: time, intensity: intensity, sharpness: sharpness, duration: duration)
    }
}

/// One point of an intensity-control curve.
struct FeelHapticPoint: Sendable, Equatable {
    var time: Double
    var value: Float
}

/// A haptic cue: notes plus an optional intensity-control curve (ramps and fades).
struct FeelHapticCue: Sendable, Equatable {
    var notes: [FeelHapticNote]
    /// Intensity-control points (time, 0…1 multiplier) applied across the cue (≤ 16); empty = none.
    var curve: [FeelHapticPoint]

    init(notes: [FeelHapticNote], curve: [FeelHapticPoint] = []) {
        self.notes = notes
        self.curve = curve
    }

    /// The end of the last note (s).
    var length: Double {
        notes.map { $0.time + $0.duration }.max() ?? 0
    }
}

/// The haptic vocabulary of Swoop (GAME-DESIGN §7). Pure data, so it is testable.
enum FeelHapticBook {
    // MARK: The continuous rumble

    /// Rumble intensity for a speed (0…1): `rumbleRest` at the minimum speed up to `rumbleTop` at full speed; 0 when
    /// not playing. Kept modest: it runs the whole flight.
    static let rumbleRest: Float = 0.06
    static let rumbleTop: Float = 0.5
    static func rumbleLevel(speed: Double, playing: Bool) -> Float {
        guard playing else { return 0 }
        let s = FeelSoundBook.speedUnit(speed)
        return rumbleRest + (rumbleTop - rumbleRest) * Float(pow(s, 1.2))
    }

    /// Rumble sharpness follows the tuck: soft and round with spread wings, tighter and keener in a dive.
    static func rumbleSharpness(tuck: Double) -> Float {
        Float(0.15 + 0.6 * FeelMath.clamp01(tuck))
    }

    /// The skim texture: a fine, sharp, light buzz while skimming, a little stronger with speed.
    static func skimLevel(speed: Double, skimming: Bool, playing: Bool) -> Float {
        guard playing, skimming else { return 0 }
        return Float(0.1 + 0.25 * FeelSoundBook.speedUnit(speed))
    }

    // MARK: Moments

    /// Launch: one firm tap, scaled by speed, with a tiny lift after.
    static func launch(speed: Double) -> FeelHapticCue {
        let s = Float(FeelSoundBook.speedUnit(speed))
        return FeelHapticCue(notes: [.tap(0.5 + 0.45 * s, 0.55), .buzz(0.2 + 0.15 * s, 0.4, at: 0.01, duration: 0.05)])
    }

    /// Perfect: a crisp double tap.
    static let perfect = FeelHapticCue(notes: [.tap(0.85, 0.9), .tap(0.7, 0.95, at: 0.07)])
    /// Good landing: a soft single tap.
    static let good = FeelHapticCue(notes: [.tap(0.4, 0.5)])
    /// Tailwind: a rising ramp that lands on a firm tap.
    static let tailwind = FeelHapticCue(
        notes: [.buzz(1.0, 0.5, duration: 0.5), .tap(0.9, 0.8, at: 0.5)],
        curve: [FeelHapticPoint(time: 0, value: 0.1), FeelHapticPoint(time: 0.25, value: 0.4),
                FeelHapticPoint(time: 0.5, value: 1.0), FeelHapticPoint(time: 0.6, value: 1.0)]
    )
    /// Splash: a heavy thud and a short wet rumble.
    static let splash = FeelHapticCue(
        notes: [.tap(1.0, 0.2), .tap(0.55, 0.25, at: 0.1), .buzz(0.7, 0.1, duration: 0.2)],
        curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.08, value: 0.6),
                FeelHapticPoint(time: 0.2, value: 0)]
    )
    /// Lighthouse: a soft triple, in time with the bell.
    static let lighthouse = FeelHapticCue(notes: [.tap(0.3, 0.4), .tap(0.3, 0.4, at: 0.16), .tap(0.35, 0.45, at: 0.32)])
    /// The storm closes in: a low distant roll.
    static let thunder = FeelHapticCue(
        notes: [.buzz(0.45, 0.05, duration: 0.9)],
        curve: [FeelHapticPoint(time: 0, value: 0.2), FeelHapticPoint(time: 0.2, value: 0.8),
                FeelHapticPoint(time: 0.4, value: 0.5), FeelHapticPoint(time: 0.6, value: 0.7),
                FeelHapticPoint(time: 0.9, value: 0)]
    )
    /// Caught: one long soft fade.
    static let caught = FeelHapticCue(
        notes: [.buzz(0.5, 0.15, duration: 1.6)],
        curve: [FeelHapticPoint(time: 0, value: 0.8), FeelHapticPoint(time: 0.5, value: 0.45),
                FeelHapticPoint(time: 1.6, value: 0)]
    )
    /// Countdown ticks and the drop.
    static let countdownTick = FeelHapticCue(notes: [.tap(0.35, 0.6)])
    static let started = FeelHapticCue(notes: [.tap(0.6, 0.8)])
    /// Milestone / new best: a light glint.
    static let milestone = FeelHapticCue(notes: [.tap(0.3, 0.9), .tap(0.4, 0.95, at: 0.08)])
    static let newBest = FeelHapticCue(notes: [.tap(0.4, 0.8), .tap(0.5, 0.9, at: 0.085), .tap(0.65, 0.95, at: 0.17)])
    static let cloudTouched = FeelHapticCue(notes: [.tap(0.25, 1.0)])
    static let uiTap = FeelHapticCue(notes: [.tap(0.35, 0.7)])
    static let uiConfirm = FeelHapticCue(notes: [.tap(0.5, 0.8), .tap(0.4, 0.9, at: 0.06)])
    static let celebrate = FeelHapticCue(notes: [.tap(0.5, 0.6), .tap(0.6, 0.7, at: 0.09), .tap(0.75, 0.8, at: 0.18),
                                                 .tap(1.0, 0.9, at: 0.3)])
}

/// Core Haptics for Swoop: two looping advanced players carry the continuous feel (the speed rumble and the skim
/// texture, steered by dynamic parameters at ≤ 30 Hz), and every moment plays as its own short pattern. Self-healing
/// after stops and server resets (Squish's/Brim's pattern). Phones without Core Haptics fall back to
/// `UIImpactFeedbackGenerator` for the moments.
@MainActor
final class FeelHaptics {
    private static let log = Logger(subsystem: "com.pravegm.swoop", category: "haptics")

    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                if wantsStart { start() }
            } else {
                setContinuous(rumble: 0, sharpness: 0.5, skim: 0, now: CACurrentMediaTime(), force: true)
            }
        }
    }

    /// Menus and long pauses: no looping players, and the engine may shut the hardware down by itself. A cue still
    /// plays (the engine is started again for it). Off: the players are rebuilt at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                stopPlayers()
                engine?.isAutoShutdownEnabled = true
            } else {
                engine?.isAutoShutdownEnabled = false
                if engine != nil && (!isRunning || rumblePlayer == nil) { restart() }
            }
        }
    }

    private let supportsHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var rumblePlayer: CHHapticAdvancedPatternPlayer?
    private var skimPlayer: CHHapticAdvancedPatternPlayer?
    private var isRunning = false
    private var wantsStart = false
    private var lastRecovery: CFTimeInterval = 0
    private var lastSend: CFTimeInterval = 0
    private var lastRumble: Float = 0
    private var lastSharpness: Float = 0.5
    private var lastSkim: Float = 0
    private var fallbackLight: UIImpactFeedbackGenerator?
    private var fallbackMedium: UIImpactFeedbackGenerator?
    private var fallbackHeavy: UIImpactFeedbackGenerator?
    private(set) var lastError: String?

    init() {}

    /// Idempotent. Does nothing while haptics are off (it starts when they are switched on).
    func start() {
        wantsStart = true
        guard enabled else { return }
        guard supportsHaptics else {
            prepareFallback()
            return
        }
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = idle
            // Both handlers arrive on an engine-internal queue: hop to the main actor.
            engine.stoppedHandler = { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.rumblePlayer = nil
                    self.skimPlayer = nil
                }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.rumblePlayer = nil
                    self.skimPlayer = nil
                    self.restart()
                }
            }
            self.engine = engine
            restart()
        } catch {
            record("Couldn't create the haptic engine", error)
            engine = nil
        }
    }

    /// The app became active again: the system stops the engine on suspension.
    func resume() {
        guard supportsHaptics, enabled, wantsStart else { return }
        if engine == nil {
            start()
        } else if !isRunning || (!idle && rumblePlayer == nil) {
            restart()
        }
    }

    /// Throttled recovery from the frame loop.
    func heal() {
        guard enabled, engine != nil, !isRunning || (!idle && rumblePlayer == nil) else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        restart()
    }

    private func restart() {
        guard let engine else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
            record("Couldn't start the haptic engine", error)
            return
        }
        rumblePlayer = nil
        skimPlayer = nil
        // Menus have no flight: no looping players to keep the hardware awake.
        if idle { return }
        do {
            rumblePlayer = try makeLoopingPlayer(sharpness: 0.5)
            skimPlayer = try makeLoopingPlayer(sharpness: 1.0)
            lastRumble = 0
            lastSkim = 0
        } catch {
            record("Couldn't build the continuous haptics", error)
        }
    }

    private func stopPlayers() {
        if let player = rumblePlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        if let player = skimPlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        rumblePlayer = nil
        skimPlayer = nil
        lastRumble = 0
        lastSkim = 0
    }

    /// One looping continuous event at intensity 1; the intensity control scales it (starts at 0).
    private func makeLoopingPlayer(sharpness: Float) throws -> CHHapticAdvancedPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: 30
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        let zero = [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)]
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        try player.start(atTime: CHHapticTimeImmediate)
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        return player
    }

    // MARK: - Per frame

    /// The continuous feel: call every frame; sends at most ~30 times a second, ramping between values (no zipper).
    func update(telemetry: FlightTelemetry, now: CFTimeInterval) {
        let rumble = enabled ? FeelHapticBook.rumbleLevel(speed: telemetry.speed, playing: telemetry.playing) : 0
        let skim = enabled
            ? FeelHapticBook.skimLevel(speed: telemetry.speed, skimming: telemetry.skimming, playing: telemetry.playing)
            : 0
        setContinuous(rumble: rumble, sharpness: FeelHapticBook.rumbleSharpness(tuck: telemetry.tuck), skim: skim,
                      now: now, force: false)
    }

    /// Fade the continuous feel to nothing.
    func quiet(now: CFTimeInterval) {
        setContinuous(rumble: 0, sharpness: lastSharpness, skim: 0, now: now, force: false)
    }

    private func setContinuous(rumble: Float, sharpness: Float, skim: Float, now: CFTimeInterval, force: Bool) {
        guard isRunning, let rumblePlayer else { return }
        let silencing = (rumble == 0 && lastRumble > 0) || (skim == 0 && lastSkim > 0)
        let changed = abs(rumble - lastRumble) > 0.015 || abs(sharpness - lastSharpness) > 0.03
            || abs(skim - lastSkim) > 0.015
        guard force || silencing || changed else { return }
        guard force || silencing || now - lastSend >= 1.0 / 30 else { return }
        lastSend = now
        let ramp: TimeInterval = silencing ? 0.06 : 1.0 / 30
        schedule(rumblePlayer, from: lastRumble, to: rumble, ramp: ramp)
        // Sharpness control is an offset from the event's 0.5.
        try? rumblePlayer.sendParameters([CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                                   value: sharpness - 0.5, relativeTime: 0)],
                                         atTime: CHHapticTimeImmediate)
        if let skimPlayer {
            schedule(skimPlayer, from: lastSkim, to: skim, ramp: ramp)
        }
        lastRumble = rumble
        lastSharpness = sharpness
        lastSkim = skim
    }

    private func schedule(_ player: CHHapticAdvancedPatternPlayer, from start: Float, to end: Float,
                          ramp: TimeInterval) {
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: start),
                CHHapticParameterCurve.ControlPoint(relativeTime: ramp, value: end),
            ],
            relativeTime: 0
        )
        try? player.scheduleParameterCurve(curve, atTime: CHHapticTimeImmediate)
    }

    // MARK: - Moments

    func play(_ cue: FeelHapticCue) {
        guard enabled, !cue.notes.isEmpty else { return }
        guard supportsHaptics else {
            playFallback(cue)
            return
        }
        if !isRunning || engine == nil {
            let now = CACurrentMediaTime()
            if now - lastRecovery > 0.5 {
                lastRecovery = now
                resume()
            }
        }
        guard let engine, isRunning else { return }
        let events: [CHHapticEvent] = cue.notes.map { (note: FeelHapticNote) -> CHHapticEvent in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(note.intensity, 0), 1))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(note.sharpness, 0), 1))
            switch note.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness],
                                     relativeTime: note.time)
            case .continuous:
                return CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness],
                                     relativeTime: note.time, duration: max(note.duration, 0.01))
            }
        }
        var curves: [CHHapticParameterCurve] = []
        if !cue.curve.isEmpty {
            var points: [CHHapticParameterCurve.ControlPoint] = []
            for point in cue.curve.prefix(16) {
                points.append(CHHapticParameterCurve.ControlPoint(relativeTime: point.time, value: point.value))
            }
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points,
                                                 relativeTime: 0))
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            record("Couldn't play a haptic", error)
        }
    }

    // MARK: - Fallback (no Core Haptics)

    private func prepareFallback() {
        if fallbackLight == nil { fallbackLight = UIImpactFeedbackGenerator(style: .light) }
        if fallbackMedium == nil { fallbackMedium = UIImpactFeedbackGenerator(style: .medium) }
        if fallbackHeavy == nil { fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy) }
        fallbackLight?.prepare()
        fallbackMedium?.prepare()
        fallbackHeavy?.prepare()
    }

    /// Up to three notes of the cue as impacts (a buzz plays as one impact at its start).
    private func playFallback(_ cue: FeelHapticCue) {
        prepareFallback()
        let notes = Array(cue.notes.sorted { $0.time < $1.time }.prefix(3))
        for note in notes {
            let intensity = CGFloat(min(max(note.intensity, 0.05), 1))
            let generator: UIImpactFeedbackGenerator?
            if note.intensity >= 0.75 {
                generator = fallbackHeavy
            } else if note.intensity >= 0.4 {
                generator = fallbackMedium
            } else {
                generator = fallbackLight
            }
            guard let generator else { continue }
            if note.time <= 0.005 {
                generator.impactOccurred(intensity: intensity)
            } else {
                let delay = UInt64(note.time * 1_000_000_000)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
