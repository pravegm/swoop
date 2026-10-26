import Foundation
import QuartzCore

/// Every number of the hinge → tuck mapping (GAME-DESIGN §3), in one place and outside the main actor, so pure code
/// and tests can read it.
enum HingeTuckTuning {
    /// Degrees from "open" to "fully tucked" (θ_full = θ_open − 36°).
    static let stroke = 36.0
    /// Initial open angle before any calibration.
    static let initialOpen = 160.0
    /// The open angle is always kept inside this range.
    static let openMin = 145.0
    static let openMax = 172.0
    /// At or above this the phone is (nearly) flat: wings fully spread.
    static let flatAngle = 175.0
    /// Only angles inside this band teach the calibration (flat and deep folds never do).
    static let calibrationLow = 140.0
    static let calibrationHigh = 178.0
    /// Time constant (s) of the calibration average, downward (the player relaxing a little below "open").
    static let calibrationTau = 4.0
    /// Round 2 (QA-1 P1-3, the upward ratchet): upward, the average learns slowly and only from angles at most
    /// `upwardWindow` degrees above the current open angle, and never from above `upwardCeiling`. A few seconds of the
    /// wings opened wide ("open to soar", or flat) therefore can't drag "open" up to 172° and turn the normal rest into
    /// a half tuck.
    static let upwardTau = 10.0
    static let upwardWindow = 6.0
    static let upwardCeiling = 168.0
    /// The average learns at full rate below this tuck, fading to nothing at `calibrationMaxTuck` (≈ 9° under open).
    static let calibrationFullTuck = 0.08
    static let calibrationMaxTuck = 0.15
    /// Slow "settle" path: a player whose resting angle sits well under the current open angle (e.g. rests at 150°
    /// when we started at 160°, a permanent tuck of ~0.2) is learned too, but only after the hinge has been held
    /// still for `settleDelay` s, only while the tuck is under `settleMaxTuck` (a real dive is far deeper), and slowly.
    static let settleDelay = 2.5
    static let settleTau = 12.0
    static let settleMaxTuck = 0.4
    /// The settle path also works upward (a resting angle more than `upwardWindow` above open, e.g. after a low
    /// ready-pose snap), at `settleTau`, but only up to `upwardCeiling` and only after `settleDelay` s held still.
    /// Net report speed (°/s) under which the hinge counts as held still (calibration and the ready-pose snap).
    static let stillSpeed = 3.0
    /// The ready-pose snap needs a still hinge: the raw reports of the last `snapStillWindow` s (plus the one before)
    /// span at most `snapStillSpread` degrees. A spread, not a net speed, so a fidget's turnaround never counts as
    /// still; a resting Duo sends nothing at all, which reads as a spread of 0.
    static let snapStillWindow = 0.3
    static let snapStillSpread = 1.5
    /// Round 3 (UX §9, flat pose): the phone counts as flat from 175° (entry) until it is back under `flatExit` (a
    /// little hysteresis, so a ±1° reading around 175° never restarts the flat timer).
    static let flatExit = 173.0
    /// Hold-stabiliser rest cutoff (Hz) near the open angle (heavy: tremor at rest never flutters the wings) and deep
    /// in a dive (lighter: small trims mid-dive still answer quickly).
    static let nearOpenRestCutoff = 0.6
    static let deepRestCutoff = 1.6
    /// Degrees under the open angle where the stabiliser starts to lighten, and where it is fully light.
    static let nearOpenSpan = 10.0
    static let deepSpan = 22.0
    /// `SWOOP-T tuck` lines: at most one per this many seconds (4/s).
    static let tuckLogInterval = 0.25
    /// `SWOOP-T calib` lines: when the open angle moved more than this since the last line.
    static let calibrationLogStep = 2.0

    /// Tuck for a hinge angle: smoothstep((open − θ) / 36°). 0 at and above `open` (and always at ≥ 175°, flat),
    /// 1 at and below open − 36°. NaN → 0.
    static func tuck(forAngle angle: Double, open: Double) -> Double {
        guard angle.isFinite, open.isFinite else { return 0 }
        if angle >= flatAngle { return 0 }
        return FeelMath.smoothstep((open - angle) / stroke)
    }
}

/// The wing control on the iPhone Duo (GAME-DESIGN §3): hinge samples in (from `HingeReader`), tuck 0…1 out at
/// display rate.
///
/// Pipeline (Squish's and Brim's real-Duo lessons, research/02 §2):
///   raw reports (25–30 Hz while moving, none while still, ±5°)
///   → `HingePredictor` (alpha-beta, predicts between reports) sampled every frame
///   → One-Euro (minCutoff 2.0, β 0.12: ≈ 17 ms behind a 60°/s squeeze)
///   → `HoldStabiliser` (pass-through while the hand moves; a low-pass only while it holds still, heaviest near the
///     open angle so tremor at rest never flutters the wings, lighter deep in a dive so small trims still answer)
///   → tuck = smoothstep((open − θ) / 36°). Flat (≥ 175°) reads as fully open.
///
/// Why it feels immediate: a deliberate 30° squeeze moves at ≥ 60°/s, far above the stabiliser's 20°/s pass-through,
/// so the only lag is the One-Euro's ~1°, and the predictor removes the report-rate stepping. The smoothstep's flat
/// foot near the open angle doubles as a soft dead zone (3° under open is a tuck of 0.02).
///
/// `openAngle` is set by the ready pose (`snapCalibration`, countdown and resume hold, still hinge only) and then
/// follows the player's resting book angle (`calibrate`): τ 4 s downward while the wings are nearly open (a held dive
/// never drags it), τ 10 s upward from at most 6° above it (a wide-open glide never ratchets it).
@MainActor
final class HingeTuckSource: TuckSource {
    private typealias T = HingeTuckTuning

    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)
    private var stabiliser = HoldStabiliser()
    private var latch = FeelClosingLatch()

    /// True once any real hinge sample has arrived (never goes back to false).
    private(set) var hasHinge = false
    /// The display-rate filtered hinge angle (180 = flat); nil before any sample.
    private(set) var angle: Double?
    /// The auto-calibrated "wings spread" angle (150…172).
    private(set) var openAngle: Double = HingeTuckTuning.initialOpen
    /// The last raw reading and when it arrived (diagnostics).
    private(set) var lastRawAngle: Double?
    private(set) var lastSampleTime: TimeInterval?
    /// The tuck returned by the last `tuck(at:)`.
    private(set) var lastTuck: Double = 0

    private var lastQuery: TimeInterval?
    private var stillSince: TimeInterval?
    private var flatSince: TimeInterval?
    private var leftFlatAt: TimeInterval?
    private var lastTuckLog: TimeInterval = -Double.infinity
    private var loggedOpen: Double = HingeTuckTuning.initialOpen
    private let logs: Bool

    /// `logs` defaults to the `-swoopDemo` launch argument (tests pass false).
    init(logs: Bool = FeelDemoLog.isEnabled) {
        self.logs = logs
    }

    /// True while the phone is closing: the filtered angle fell below 95° (pause), until it is back above 102°.
    /// Updated on every report, so it works while the run is paused and nobody asks for the tuck.
    var isClosing: Bool { hasHinge && latch.isClosing }

    // MARK: Flat pose (UX-SPEC §9: "judged on the last reading plus a timer, never by waiting for an event")

    /// Seconds the hinge has been flat (≥ 175°, until < 173°) as of `time`; 0 when it isn't flat or there is no
    /// hinge. The Duo sends nothing while still, so this keeps counting from the last reading. The App uses it for
    /// "Bend it a little, like a book" (1 s), the countdown's flat hold, and "Keep a little bend" (2 s).
    func flatDuration(at time: TimeInterval = CACurrentMediaTime()) -> TimeInterval {
        guard hasHinge, time.isFinite, let since = flatSince else { return 0 }
        return max(time - since, 0)
    }

    /// Seconds since the hinge last left flat, as of `time` (the 2.2 s fold-blur guard); `.infinity` if it has never
    /// been flat, 0 while it is flat.
    func timeSinceFlat(at time: TimeInterval = CACurrentMediaTime()) -> TimeInterval {
        guard hasHinge, time.isFinite else { return .infinity }
        if flatSince != nil { return 0 }
        guard let left = leftFlatAt else { return .infinity }
        return max(time - left, 0)
    }

    /// True while the fold-blur guard holds (left flat within `window` s, 2.2 by default): queue toasts and cards.
    func inFlatBlurGuard(at time: TimeInterval = CACurrentMediaTime(), window: TimeInterval = 2.2) -> Bool {
        let since = timeSinceFlat(at: time)
        return since > 0 && since < window
    }

    private func updateFlat(raw: Double, at stamp: TimeInterval) {
        if flatSince != nil {
            if raw < T.flatExit {
                flatSince = nil
                leftFlatAt = stamp
            }
        } else if raw >= T.flatAngle {
            flatSince = stamp
        }
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`.
    func ingest(angleDegrees: Double, at time: TimeInterval) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (it would make the predictor's dt negative).
        let stamp = max(time, lastSampleTime ?? time)
        hasHinge = true
        lastRawAngle = raw
        lastSampleTime = stamp
        predictor.sample(raw, at: stamp)
        stabiliser.sample(raw, at: stamp)
        let tracked = predictor.estimate ?? raw
        latch.update(angle: tracked)
        updateFlat(raw: raw, at: stamp)
        // Keep `angle` fresh while no frame asks (menus, the pause card); frames take over again at once.
        let lastFrame = lastQuery ?? -Double.infinity
        if angle == nil || stamp - lastFrame > 0.1 {
            angle = tracked
        }
    }

    func tuck(at time: TimeInterval) -> Double {
        guard hasHinge, time.isFinite else { return 0 }
        // Asked twice for the same frame (or an older one): same answer, and the filters don't advance.
        if let previous = lastQuery, time <= previous { return lastTuck }
        var dt: Double = 0
        if let previous = lastQuery { dt = FeelMath.clamp(time - previous, 0, 0.1) }
        lastQuery = time

        let predicted = predictor.angle(at: time)
        let smoothed = smoother.filter(predicted, at: time)
        let depth = openAngle - smoothed
        let lighten = FeelMath.smoothstep((depth - T.nearOpenSpan) / (T.deepSpan - T.nearOpenSpan))
        let restCutoff = T.nearOpenRestCutoff + (T.deepRestCutoff - T.nearOpenRestCutoff) * lighten
        let filtered = stabiliser.filter(smoothed, at: time, restCutoff: restCutoff)
        angle = filtered

        let tuck = T.tuck(forAngle: filtered, open: openAngle)
        calibrate(angle: filtered, tuck: tuck, time: time, dt: dt)
        lastTuck = tuck
        log(tuck: tuck, angle: filtered, time: time)
        return tuck
    }

    /// Forget the motion history (keeps `hasHinge`, the calibration and the closing latch): e.g. after the app returns
    /// from the background.
    func reset() {
        predictor.reset()
        smoother.reset()
        stabiliser.reset()
        lastQuery = nil
        stillSince = nil
        if let raw = lastRawAngle, let stamp = lastSampleTime {
            predictor.sample(raw, at: stamp)
        }
    }

    /// Tuck for a hinge angle (see `HingeTuckTuning.tuck(forAngle:open:)`).
    nonisolated static func tuck(forAngle angle: Double, open: Double) -> Double {
        HingeTuckTuning.tuck(forAngle: angle, open: open)
    }

    /// The ready pose defines "wings spread": called every frame of the countdown and of the resume hold. Snaps the
    /// open angle to the player's current book angle (clamped to openMin…openMax), so a player resting at 147° starts
    /// with wings fully spread instead of 30 % tucked (Duo CI run 40318165524).
    ///
    /// Round 2 (QA-1 P1-4): it snaps only while the hinge is still (the last 0.3 s of reports span ≤ 1.5°; a resting
    /// Duo sends none), and only from the filtered angle, never from a raw ±5° report. So a hand still
    /// reopening after a closing pause (102° → 158° over 2–3 s) never makes a mid-reopen angle "open"; the snap lands
    /// once the hand has come to rest, and if it never rests inside the hold the previous calibration stays.
    /// Ignored when the phone is clearly being folded (below `calibrationLow`) or there is no reading yet.
    /// `time` defaults to now (`CACurrentMediaTime()`, the clock of the hinge samples); tests pass their own.
    func snapCalibration(at time: TimeInterval = CACurrentMediaTime()) {
        guard isStill(at: time) else { return }
        let target = snapAngle(at: time)
        guard target.isFinite, target >= T.calibrationLow else { return }
        openAngle = FeelMath.clamp(min(target, T.flatAngle), T.openMin, T.openMax)
        if logs && abs(openAngle - loggedOpen) > T.calibrationLogStep {
            loggedOpen = openAngle
            FeelDemoLog.emit(String(format: "SWOOP-T calib open=%.1f (ready pose)", openAngle))
        }
    }

    /// True while the hinge is still enough for the ready-pose snap (see `snapCalibration`). The App may use it to
    /// hold the resume "Ready" ring until the hand has come to rest.
    func isStill(at time: TimeInterval = CACurrentMediaTime()) -> Bool {
        guard hasHinge, time.isFinite else { return false }
        return stabiliser.spread(over: T.snapStillWindow, at: time) <= T.snapStillSpread
    }

    /// The filtered angle for the snap: the display-rate angle while frames are asking for the tuck (the countdown),
    /// otherwise the predictor (the resume hold asks no tuck), which glides onto the last reading once the hinge is still.
    private func snapAngle(at time: TimeInterval) -> Double {
        if let last = lastQuery, time - last <= 0.1, let filtered = angle { return filtered }
        return predictor.angle(at: time)
    }

    // MARK: Calibration

    /// The open angle follows the player's own resting angle (GAME-DESIGN §3), between the ready-pose snaps.
    /// - Downward, fast (τ 4 s): only while the tuck is under 0.15 (≈ 9° under open), so a held dive never moves it.
    /// - Downward, settle (τ 12 s): a resting angle further under open (tuck 0.15…0.4), only after 2.5 s held still.
    /// - Upward, slow (τ 10 s): only from angles at most 6° above open and never above 168°, so a wide-open glide
    ///   can't ratchet it up (QA-1 P1-3). A still rest further up (≤ 168°) is learned at τ 12 s after 2.5 s.
    private func calibrate(angle: Double, tuck: Double, time: TimeInterval, dt: Double) {
        let still = stabiliser.speed(at: time) < T.stillSpeed
        if still {
            if stillSince == nil { stillSince = time }
        } else {
            stillSince = nil
        }
        guard dt > 0, angle >= T.calibrationLow, angle <= T.calibrationHigh else { return }
        var settled = false
        if let since = stillSince { settled = time - since >= T.settleDelay }
        var rate: Double = 0
        if angle <= openAngle {
            if tuck < T.calibrationMaxTuck {
                let fade = FeelMath.smoothstep((tuck - T.calibrationFullTuck)
                                               / (T.calibrationMaxTuck - T.calibrationFullTuck))
                rate = (1 - fade) / T.calibrationTau
            }
            if settled && tuck < T.settleMaxTuck && angle < openAngle {
                rate = max(rate, 1 / T.settleTau)
            }
        } else if angle <= T.upwardCeiling {
            if angle <= openAngle + T.upwardWindow { rate = 1 / T.upwardTau }
            if settled { rate = max(rate, 1 / T.settleTau) }
        }
        guard rate > 0 else { return }
        let k = 1 - exp(-dt * rate)
        openAngle = FeelMath.clamp(openAngle + (angle - openAngle) * k, T.openMin, T.openMax)
        if logs && abs(openAngle - loggedOpen) > T.calibrationLogStep {
            loggedOpen = openAngle
            FeelDemoLog.emit(String(format: "SWOOP-T calib open=%.1f", openAngle))
        }
    }

    private func log(tuck: Double, angle: Double, time: TimeInterval) {
        guard logs, time - lastTuckLog >= T.tuckLogInterval else { return }
        lastTuckLog = time
        FeelDemoLog.emit(String(format: "SWOOP-T tuck %.2f angle %.1f", tuck, angle))
    }
}
