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

/// Settings "Haptics: Off | Normal | Strong" (UX-SPEC §3, §9; Round 3 F2). Strong is the Duo default: the founder found
/// the Duo's Taptic Engine weak, so Strong turns every tap into a short, rounder burst the actuator can actually push.
enum HapticProfile: String, Codable, CaseIterable, Sendable {
    case off, normal, strong

    /// The default before the player chooses: Strong on a phone with a fold (a hinge was seen), Normal elsewhere.
    static func defaultFor(hasFold: Bool) -> HapticProfile {
        hasFold ? .strong : .normal
    }

    /// The Settings label.
    var label: String {
        switch self {
        case .off: return "Off"
        case .normal: return "Normal"
        case .strong: return "Strong"
        }
    }
}

/// The haptic vocabulary of Swoop (GAME-DESIGN §7). Pure data, so it is testable.
enum FeelHapticBook {
    // MARK: The Strong profile (UX-SPEC §9 "The weak taptic engine")

    /// Strong: continuous intensity × 1.4 (clamped), at least `strongSkimFloor` while skimming.
    static let strongContinuousGain: Float = 1.4
    static let strongSkimFloor: Float = 0.3
    /// Strong: every transient becomes a continuous burst this long, at this sharpness (rounder = more energy on a
    /// small actuator), with its intensity × `strongTapGain` (clamped).
    static let strongBurst: Double = 0.055
    static let strongBurstSharpness: Float = 0.4
    static let strongTapGain: Float = 1.15
    /// Strong Perfect: 2 × 60 ms bursts, 80 ms apart. Strong launch: one 80 ms burst.
    static let strongPerfectBurst: Double = 0.06
    static let strongPerfectGap: Double = 0.08
    static let strongLaunchBurst: Double = 0.08

    /// A cue in the given profile: Normal (and Off, which never plays) unchanged; Strong as above. The curve is kept.
    static func adapt(_ cue: FeelHapticCue, to profile: HapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return cue }
        let notes: [FeelHapticNote] = cue.notes.map { (note: FeelHapticNote) -> FeelHapticNote in
            switch note.kind {
            case .transient:
                return .buzz(min(note.intensity * strongTapGain, 1), strongBurstSharpness, at: note.time,
                             duration: strongBurst)
            case .continuous:
                return .buzz(min(note.intensity * strongContinuousGain, 1), note.sharpness, at: note.time,
                             duration: note.duration)
            }
        }
        return FeelHapticCue(notes: notes, curve: cue.curve)
    }

    /// The Perfect cue for a profile (Normal: `perfect`, the two taps on the hit-stop).
    /// The ordinary-Perfect cue for a profile.
    static func perfectSoft(for profile: HapticProfile) -> FeelHapticCue {
        adapt(perfectSoft, to: profile)
    }

    /// The milestone Perfect cue for a profile.
    static func perfect(for profile: HapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return perfect }
        return FeelHapticCue(notes: [.buzz(1.0, strongBurstSharpness, duration: strongPerfectBurst),
                                     .buzz(0.85, strongBurstSharpness, at: strongPerfectGap,
                                           duration: strongPerfectBurst)])
    }

    /// The launch cue for a profile.
    static func launch(speed: Double, profile: HapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return launch(speed: speed) }
        let s = Float(FeelSoundBook.speedUnit(speed))
        return FeelHapticCue(notes: [.buzz(min(0.65 + 0.35 * s, 1), strongBurstSharpness,
                                           duration: strongLaunchBurst)])
    }

    /// The continuous rumble for a profile.
    static func rumbleLevel(speed: Double, playing: Bool, skimming: Bool, profile: HapticProfile) -> Float {
        let level = rumbleLevel(speed: speed, playing: playing)
        switch profile {
        case .off: return 0
        case .normal: return level
        case .strong:
            guard level > 0 else { return 0 }
            let strong = min(level * strongContinuousGain, 1)
            return skimming ? max(strong, strongSkimFloor) : strong
        }
    }

    /// The skim texture for a profile.
    static func skimLevel(speed: Double, skimming: Bool, playing: Bool, profile: HapticProfile) -> Float {
        let level = skimLevel(speed: speed, skimming: skimming, playing: playing)
        switch profile {
        case .off: return 0
        case .normal: return level
        case .strong: return min(level * strongContinuousGain, 1)
        }
    }

    /// iPhone touch-down (UX-SPEC §10, F4): a light, crisp click as the finger lands, the "fold" the iPhone's strong
    /// Taptic Engine can sell. Haptic only, iPhone only.
    static let touchDown = FeelHapticCue(notes: [.tap(0.42, 0.78)])
    /// The Home fold (F1): a soft swell under the title bird's first sweep into a dart.
    static let homeFold = FeelHapticCue(
        notes: [.buzz(0.4, 0.3, duration: 0.35)],
        curve: [FeelHapticPoint(time: 0, value: 0.2), FeelHapticPoint(time: 0.2, value: 1),
                FeelHapticPoint(time: 0.35, value: 0)]
    )
    /// The closing pause: a soft settling thump. Reopened: a light lift. Go: a crisp single tap.
    static let closing = FeelHapticCue(notes: [.tap(0.35, 0.3), .buzz(0.2, 0.2, at: 0.02, duration: 0.12)])
    static let reopened = FeelHapticCue(notes: [.tap(0.25, 0.6)])
    static let go = FeelHapticCue(notes: [.tap(0.5, 0.8)])
    /// Results count-up tick (every 0.5 km): the faintest tick.
    static let resultsTick = FeelHapticCue(notes: [.tap(0.18, 0.9)])

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

    /// Perfect (Round 4: milestones only): a crisp double tap that lands exactly on the App's hit-stop. The firm tap fires the instant
    /// the Perfect lands (the frame the world freezes); the lighter, keener one fires as it lets go (the punch-in's
    /// "pop"). It is prebuilt (`FeelHaptics`), so there is no pattern-building latency in front of it.
    static let perfect = FeelHapticCue(notes: [.tap(0.9, 0.85), .tap(0.55, 1.0, at: Double(FeelSoundBook.hitStop))])
    /// Round 4 (P1-8): an ordinary Perfect is one light, crisp tap; the double tap above is for the milestones
    /// (3, 5, 10, 15…), where the App holds the hit-stop.
    static let perfectSoft = FeelHapticCue(notes: [.tap(0.55, 0.9)])
    /// Round 4 (REVIEW-3-duo P1-2): the end-stop detent when the tuck first hits full: a 25 ms tick at 0.35.
    static let endStop = FeelHapticCue(notes: [.buzz(0.35, 0.5, duration: 0.025)])
    /// Good landing: a soft single tap.
    static let good = FeelHapticCue(notes: [.tap(0.4, 0.5)])
    /// Tailwind: a rising ramp that lands on a firm tap.
    static let tailwind = FeelHapticCue(
        notes: [.buzz(1.0, 0.5, duration: 0.5), .tap(0.9, 0.8, at: 0.5)],
        curve: [FeelHapticPoint(time: 0, value: 0.1), FeelHapticPoint(time: 0.25, value: 0.4),
                FeelHapticPoint(time: 0.5, value: 1.0), FeelHapticPoint(time: 0.6, value: 1.0)]
    )
    /// Splash: a heavy thud and a short wet rumble. Round 4 (P1-9): heavier and longer, the 80 ms of 0.85× time the
    /// scene slows for (ART §5), then a sag: the one moment that should feel like a mistake.
    static let splash = FeelHapticCue(
        notes: [.tap(1.0, 0.12), .buzz(0.9, 0.06, duration: 0.26), .tap(0.6, 0.2, at: 0.1)],
        curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.08, value: 0.85),
                FeelHapticPoint(time: 0.16, value: 0.45), FeelHapticPoint(time: 0.26, value: 0)]
    )
    /// Lighthouse: a soft triple, in time with the bell.
    static let lighthouse = FeelHapticCue(notes: [.tap(0.3, 0.4), .tap(0.3, 0.4, at: 0.16), .tap(0.35, 0.45, at: 0.32)])
    /// Round 6 (D3): a lighthouse reached, the run's goal. A firm tap the moment it is reached (the App's 60 ms
    /// hit-stop starts), a keen one as it lets go, then the soft pair with the bell.
    static let lighthouseReached = FeelHapticCue(notes: [.tap(0.7, 0.6),
                                                         .tap(0.45, 0.85, at: Double(FeelSoundBook.hitStop)),
                                                         .tap(0.3, 0.4, at: 0.22), .tap(0.35, 0.45, at: 0.38)])
    /// Round 6: 300 m to the lighthouse, a light glint.
    static let goalNear = FeelHapticCue(notes: [.tap(0.3, 0.9), .tap(0.25, 0.95, at: 0.08)])
    /// Round 6, Flight School: the praise tap on each step's success (light and crisp; the chime carries it too).
    static let schoolPraise = FeelHapticCue(notes: [.tap(0.45, 0.8), .tap(0.3, 0.9, at: 0.07)])
    /// The rewind to a checkpoint: a soft sag.
    static let schoolRewind = FeelHapticCue(notes: [.buzz(0.25, 0.2, duration: 0.18)],
                                            curve: [FeelHapticPoint(time: 0, value: 1),
                                                    FeelHapticPoint(time: 0.18, value: 0)])
    /// The storm's first roll-in.
    static let schoolStorm = FeelHapticCue(notes: [.buzz(0.3, 0.05, duration: 0.7)],
                                           curve: [FeelHapticPoint(time: 0, value: 0.2),
                                                   FeelHapticPoint(time: 0.25, value: 0.8),
                                                   FeelHapticPoint(time: 0.7, value: 0)])
    /// The storm closes in: a low distant roll.
    static let thunder = FeelHapticCue(
        notes: [.buzz(0.45, 0.05, duration: 0.9)],
        curve: [FeelHapticPoint(time: 0, value: 0.2), FeelHapticPoint(time: 0.2, value: 0.8),
                FeelHapticPoint(time: 0.4, value: 0.5), FeelHapticPoint(time: 0.6, value: 0.7),
                FeelHapticPoint(time: 0.9, value: 0)]
    )
    /// Caught (Round 9: the overtake): the front's roll as it passes over (1.2 s), the one thunder jolt at 0.9 s,
    /// then a long soft fade.
    static let caught = FeelHapticCue(
        notes: [.buzz(0.5, 0.15, duration: 2.0), .tap(0.6, 0.3, at: Double(FeelSoundBook.caughtStrike))],
        curve: [FeelHapticPoint(time: 0, value: 0.35), FeelHapticPoint(time: 0.5, value: 0.9),
                FeelHapticPoint(time: 1.2, value: 0.5), FeelHapticPoint(time: 2.0, value: 0)]
    )
    /// Round 9 school beats (the ghost's demos have NO haptic, by design: a touch is always the player's).
    static let schoolMorph = FeelHapticCue(notes: [.tap(0.3, 0.5, at: 0.75)])
    static let waveDone = FeelHapticCue(notes: [.tap(0.25, 0.85)])
    static let stormPushedBack = FeelHapticCue(notes: [.buzz(0.3, 0.2, duration: 0.3)],
                                               curve: [FeelHapticPoint(time: 0, value: 1),
                                                       FeelHapticPoint(time: 0.3, value: 0)])
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

/// Tags every haptic engine start (QA-FINAL P2-1). The engine's "stopped" signal hops to the main actor late, so it
/// can land after a newer start has already built fresh players; a stop from before the latest start began is stale
/// and ignored. A start that runs off the main thread (QA-FINAL P2-10) is tagged with a generation: its completion
/// counts only if no newer start (or a stop) superseded it. Pure, with explicit times, so it is tested.
struct FeelEngineStarts: Sendable, Equatable {
    /// An off-main start not heard back from within this long (s) no longer blocks a new attempt.
    static let pendingTimeout: Double = 2

    private(set) var generation = 0
    /// When the latest start began (the tag a stop is compared with).
    private(set) var startedAt = -Double.infinity
    /// When the latest off-main start began, while it hasn't completed.
    private(set) var pendingSince: Double?

    init() {}

    /// A start begins at `time`; returns its generation.
    mutating func begin(at time: Double, offMain: Bool) -> Int {
        generation &+= 1
        startedAt = time
        pendingSince = offMain ? time : nil
        return generation
    }

    /// The start `generation` completed. True when it is still the latest (build its players); false when stale.
    mutating func finish(_ generation: Int) -> Bool {
        guard generation == self.generation else { return false }
        pendingSince = nil
        return true
    }

    /// An off-main start is still on its way at `time`.
    func isPending(at time: Double) -> Bool {
        guard let since = pendingSince, time.isFinite else { return false }
        return time - since < Self.pendingTimeout
    }

    /// A stop that fired at `time` belongs to the latest start (not to an older one).
    func stopIsCurrent(stoppedAt time: Double) -> Bool {
        time >= startedAt
    }

    /// Whatever start is on its way no longer counts (the engine stopped, or haptics were switched off).
    mutating func cancel() {
        generation &+= 1
        pendingSince = nil
    }
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
                guard wantsStart else { return }
                if engine == nil { start() } else { restart() }
            } else {
                // QA-1 P2-12: switched off mid-session, the hardware goes to sleep at once (not at the next menu).
                let now = CACurrentMediaTime()
                setContinuous(rumble: 0, sharpness: 0.5, skim: 0, now: now, force: true)
                stopPlayers()
                perfectPlayer = nil
                // A start still on its way must not build players after this.
                let starting = starts.isPending(at: now)
                starts.cancel()
                if let engine, isRunning || starting { engine.stop(completionHandler: nil) }
                isRunning = false
            }
        }
    }

    /// Normal or Strong (Off is `enabled = false`, set by the director). Changing it rebuilds the prebuilt Perfect.
    var profile: HapticProfile = .normal {
        didSet {
            guard oldValue != profile, let engine, isRunning else { return }
            do {
                perfectPlayer = try engine.makePlayer(with: try Self.pattern(for: FeelHapticBook.perfect(for: profile)))
            } catch {
                perfectPlayer = nil
                record("Couldn't prebuild the Perfect haptic", error)
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
    /// The Perfect cue, prebuilt per engine start so it fires with no setup in front of it.
    private var perfectPlayer: CHHapticPatternPlayer?
    private var isRunning = false
    /// QA-FINAL P2-1, P2-10: every engine start is tagged (stale stops and superseded starts are ignored).
    private var starts = FeelEngineStarts()
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
            // Both handlers arrive on an engine-internal queue: hop to the main actor. The stop is stamped where it
            // fires, so a hop that lands after a newer start is recognised as stale (QA-FINAL P2-1).
            engine.stoppedHandler = { [weak self] _ in
                let stoppedAt = CACurrentMediaTime()
                guard let self else { return }
                Task { @MainActor in
                    self.engineStopped(at: stoppedAt)
                }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.engineReset()
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
        recover(offMain: false)
    }

    /// Throttled recovery from the frame loop (the director calls it only in flight, so the start runs off the main
    /// thread).
    func heal() {
        guard enabled, engine != nil, !isRunning || (!idle && rumblePlayer == nil) else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        restart(offMain: !idle)
    }

    private func recover(offMain: Bool) {
        guard supportsHaptics, enabled, wantsStart else { return }
        if engine == nil {
            start()
        } else if !isRunning || (!idle && rumblePlayer == nil) {
            restart(offMain: offMain)
        }
    }

    /// The engine stopped by itself (a stamp from `stoppedHandler`). A stop from before the latest start is stale:
    /// that start's players are live, so they stay. Otherwise the players are stopped (never just dropped) and
    /// `heal()` or the next cue starts the engine again.
    private func engineStopped(at time: CFTimeInterval) {
        guard starts.stopIsCurrent(stoppedAt: time) else { return }
        starts.cancel()
        isRunning = false
        stopPlayers()
        perfectPlayer = nil
    }

    /// The haptic server restarted: every player is dead. Start again.
    private func engineReset() {
        isRunning = false
        stopPlayers()
        perfectPlayer = nil
        restart()
    }

    /// Starts the engine and builds the players. QA-FINAL P2-1: the looping players are stopped first, never just
    /// dropped (a dropped player keeps looping at its last intensity, where `quiet()` can't reach it).
    ///
    /// QA-FINAL P2-10: `offMain` (mid-flight recovery: `heal()` and a cue finding the engine stopped) uses
    /// `start(completionHandler:)`, because the synchronous `start()` can block the main thread for tens of
    /// milliseconds, a dropped frame right on a Perfect. The players are built when it completes, on the main actor,
    /// unless a newer start or a stop superseded it. Menus, the app becoming active and leaving idle start
    /// synchronously as before, so the cue that asked for the start still plays.
    private func restart(offMain: Bool = false) {
        guard enabled, let engine else { return }
        let now = CACurrentMediaTime()
        // A recovery start already on its way: let it land (a synchronous start supersedes it).
        if offMain && starts.isPending(at: now) { return }
        stopPlayers()
        perfectPlayer = nil
        let generation = starts.begin(at: now, offMain: offMain)
        if offMain {
            engine.start(completionHandler: { [weak self] error in
                guard let self else { return }
                Task { @MainActor in
                    self.engineStarted(generation, error: error)
                }
            })
            return
        }
        var failure: Error?
        do {
            try engine.start()
        } catch {
            failure = error
        }
        engineStarted(generation, error: failure)
    }

    /// A start (`generation`) completed: build the prebuilt Perfect and, in flight, the two looping players.
    private func engineStarted(_ generation: Int, error: Error?) {
        guard starts.finish(generation) else { return }
        if let error {
            isRunning = false
            record("Couldn't start the haptic engine", error)
            return
        }
        guard enabled, let engine else { return }
        isRunning = true
        do {
            perfectPlayer = try engine.makePlayer(with: try Self.pattern(for: FeelHapticBook.perfect(for: profile)))
        } catch {
            record("Couldn't prebuild the Perfect haptic", error)
        }
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
        var rumble: Float = 0
        var skim: Float = 0
        if enabled {
            rumble = FeelHapticBook.rumbleLevel(speed: telemetry.speed, playing: telemetry.playing,
                                                skimming: telemetry.skimming, profile: profile)
            skim = FeelHapticBook.skimLevel(speed: telemetry.speed, skimming: telemetry.skimming,
                                            playing: telemetry.playing, profile: profile)
        }
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
                // In flight the start runs off the main thread (this cue is skipped); in menus it is synchronous.
                recover(offMain: !idle)
            }
        }
        guard let engine, isRunning else { return }
        if cue == FeelHapticBook.perfect(for: profile), let player = perfectPlayer {
            do {
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                perfectPlayer = nil
                record("Couldn't play the prebuilt Perfect haptic", error)
            }
        }
        do {
            let player = try engine.makePlayer(with: try Self.pattern(for: cue))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            record("Couldn't play a haptic", error)
        }
    }

    /// The Core Haptics pattern for a cue.
    private static func pattern(for cue: FeelHapticCue) throws -> CHHapticPattern {
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
        return try CHHapticPattern(events: events, parameterCurves: curves)
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
