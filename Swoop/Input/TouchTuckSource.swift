import Foundation
import QuartzCore

/// The ramp shape of the touch tuck (pure, so it is testable).
///
/// Round 3 (UX-SPEC §10, "touch has to feel native"): each ramp is an ease-out from wherever the wings are now to the
/// target, `value = start + (target − start) · (1 − (1 − x)²)` with x = elapsed / duration. A press answers at once (44 %
/// of the way in 30 ms, where R1's smoothstep had barely moved) and lands softly: "rewards snap, the world eases"
/// (ART §5). The duration scales with the distance left, so a full stroke takes exactly `attack` (in) or `release`
/// (out), and reversing mid-ramp is continuous (no jump).
enum TouchTuckRamp {
    static func easeOut(_ x: Double) -> Double {
        let u = FeelMath.clamp01(x)
        return 1 - (1 - u) * (1 - u)
    }

    /// The tuck `elapsed` s after a ramp from `start` toward `target` began, with `fullDuration` for a 0 → 1 stroke.
    static func value(start: Double, target: Double, elapsed: Double, fullDuration: Double) -> Double {
        let from = FeelMath.clamp01(start)
        let to = FeelMath.clamp01(target)
        let duration = max(fullDuration, 0.001) * abs(to - from)
        guard duration > 0.0005, elapsed.isFinite else { return to }
        return from + (to - from) * easeOut(max(elapsed, 0) / duration)
    }
}

/// The touch fallback (GAME-DESIGN §3, UX-SPEC §10): press and hold anywhere to tuck. The tuck ramps to 1 in
/// `attack` s and back to 0 in `release` s (0.12 / 0.10 by default; UX asks the founder to also try
/// `phoneAttack` 0.09 on iPhone), so a hold feels like folding rather than a switch.
///
/// Round 3 (F3, Switch Control / VoiceOver): with `tapToggles` on ("Tuck by: Tapping"), each press toggles the tuck
/// (tap to dive, tap to soar) with the same ramps, and a release does nothing. `setTucked(_:at:)` and `toggle(at:)`
/// drive it directly (a VoiceOver adjustable or a Switch Control "select").
///
/// Everything is computed from the event times, so the answer never depends on how often frames asked in between.
@MainActor
final class TouchTuckSource: TuckSource {
    /// Default seconds from fully open to fully tucked while held (UX §10).
    static let defaultAttack: Double = 0.12
    /// The quicker attack UX asks to test on iPhone (UX §10: "test 0.09 / 0.10").
    static let phoneAttack: Double = 0.09
    /// Default seconds from fully tucked to fully open after release.
    static let defaultRelease: Double = 0.10

    /// Seconds for a full 0 → 1 tuck (used from the next event on).
    var attack: Double
    /// Seconds for a full 1 → 0 release (used from the next event on).
    var release: Double

    /// "Tuck by: Tapping": a press toggles the tuck and a release does nothing. Switching it while tucked releases the
    /// wings, so a tuck can never get stuck on.
    var tapToggles = false {
        didSet {
            guard oldValue != tapToggles, isHolding else { return }
            setTucked(false, at: max(CACurrentMediaTime(), anchorTime))
        }
    }

    /// True while the tuck is wanted (between `began` and `ended`, or toggled on).
    private(set) var isHolding = false
    /// The ramp in progress: where it started and when.
    private var anchorValue: Double = 0
    private var anchorTime: TimeInterval = 0

    /// Defaults: `defaultAttack` 0.12 s and `defaultRelease` 0.10 s (literals here, so the default arguments need no
    /// actor isolation).
    init(attack: Double = 0.12, release: Double = 0.10) {
        self.attack = attack.isFinite && attack > 0 ? attack : TouchTuckSource.defaultAttack
        self.release = release.isFinite && release > 0 ? release : TouchTuckSource.defaultRelease
    }

    /// A finger went down (time = `CACurrentMediaTime()`, like the frames). Holding: tuck. Tapping: toggle.
    func began(at time: TimeInterval) {
        guard time.isFinite else { return }
        if tapToggles {
            setTucked(!isHolding, at: time)
        } else {
            setTucked(true, at: time)
        }
    }

    /// The finger went up (or the gesture was cancelled). Holding: release. Tapping: nothing.
    func ended(at time: TimeInterval) {
        guard time.isFinite, !tapToggles else { return }
        setTucked(false, at: time)
    }

    /// Same as `ended(at:)`.
    func cancelled(at time: TimeInterval) {
        ended(at: time)
    }

    /// Toggle the tuck (a Switch Control "select").
    func toggle(at time: TimeInterval) {
        setTucked(!isHolding, at: time)
    }

    /// Tuck or spread the wings from `time` (a VoiceOver adjustable: decrement = tuck, increment = spread). Leaving
    /// play should call `setTucked(false, …)` so a toggled tuck never survives into the next run.
    func setTucked(_ tucked: Bool, at time: TimeInterval) {
        guard time.isFinite, tucked != isHolding else { return }
        let stamp = max(time, anchorTime)
        anchorValue = value(at: stamp)
        anchorTime = stamp
        isHolding = tucked
    }

    func tuck(at time: TimeInterval) -> Double {
        guard time.isFinite else { return 0 }
        return value(at: time)
    }

    /// The tuck at `time` (a query older than the last event reads the value at that event).
    private func value(at time: TimeInterval) -> Double {
        let elapsed = max(time - anchorTime, 0)
        if isHolding {
            return TouchTuckRamp.value(start: anchorValue, target: 1, elapsed: elapsed, fullDuration: attack)
        }
        return TouchTuckRamp.value(start: anchorValue, target: 0, elapsed: elapsed, fullDuration: release)
    }
}

/// Two tuck sources at once: the larger tuck wins (QA-2 P2-7). For a VoiceOver or Switch Control player flying a Duo
/// by hinge, the App can pair the hinge with the accessible wing control (a `TouchTuckSource` fed by the adjustable)
/// so either can tuck. Don't use it for plain touch in hinge mode: grip thumbs would tuck by accident (UX §9).
@MainActor
final class CombinedTuckSource: TuckSource {
    let primary: TuckSource
    let assist: TuckSource

    init(primary: TuckSource, assist: TuckSource) {
        self.primary = primary
        self.assist = assist
    }

    func tuck(at time: TimeInterval) -> Double {
        let a = primary.tuck(at: time)
        let b = assist.tuck(at: time)
        return FeelMath.clamp01(max(a.isFinite ? a : 0, b.isFinite ? b : 0))
    }
}
