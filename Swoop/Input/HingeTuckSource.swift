import Foundation

/// Every number of the hinge → tuck mapping (GAME-DESIGN §3), in one place and outside the main actor, so pure code
/// and tests can read it.
enum HingeTuckTuning {
    /// Degrees from "open" to "fully tucked" (θ_full = θ_open − 36°).
    static let stroke = 36.0
    /// Initial open angle before any calibration.
    static let initialOpen = 160.0
    /// The open angle is always kept inside this range.
    static let openMin = 150.0
    static let openMax = 172.0
    /// At or above this the phone is (nearly) flat: wings fully spread.
    static let flatAngle = 175.0
    /// Only angles inside this band teach the calibration (flat and deep folds never do).
    static let calibrationLow = 140.0
    static let calibrationHigh = 178.0
    /// Time constant (s) of the calibration average.
    static let calibrationTau = 4.0
    /// The average learns at full rate below this tuck, fading to nothing at `calibrationMaxTuck` (≈ 9° under open).
    static let calibrationFullTuck = 0.08
    static let calibrationMaxTuck = 0.15
    /// Slow "settle" path: a player whose resting angle sits well under the current open angle (e.g. rests at 150°
    /// when we started at 160°, a permanent tuck of ~0.2) is learned too, but only after the hinge has been held
    /// still for `settleDelay` s, only while the tuck is under `settleMaxTuck` (a real dive is far deeper), and slowly.
    static let settleDelay = 2.5
    static let settleTau = 12.0
    static let settleMaxTuck = 0.4
    /// Net report speed (°/s) under which the hinge counts as held still.
    static let stillSpeed = 3.0
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
/// `openAngle` calibrates itself to the player's resting book angle (`calibrate`): an exponential average with
/// τ = 4 s, only while the wings are nearly open, so holding a dive never drags "open" toward the tucked angle.
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

    // MARK: Calibration

    /// The open angle follows the player's own resting angle (GAME-DESIGN §3).
    /// - Fast path (τ 4 s): only while the tuck is under 0.15 (≈ 9° under open) and the angle is in 140…178°.
    ///   Upward it simply follows; downward it can only creep within those 9°, so a held dive (deeper) never moves it.
    /// - Settle path (τ 12 s): a resting angle more than 9° under open (tuck 0.15…0.4) is learned only after the hinge
    ///   has been held perfectly still for 2.5 s.
    private func calibrate(angle: Double, tuck: Double, time: TimeInterval, dt: Double) {
        let still = stabiliser.speed(at: time) < T.stillSpeed
        if still {
            if stillSince == nil { stillSince = time }
        } else {
            stillSince = nil
        }
        guard dt > 0, angle >= T.calibrationLow, angle <= T.calibrationHigh else { return }
        var rate: Double = 0
        if tuck < T.calibrationMaxTuck {
            let fade = FeelMath.smoothstep((tuck - T.calibrationFullTuck) / (T.calibrationMaxTuck - T.calibrationFullTuck))
            rate = (1 - fade) / T.calibrationTau
        }
        if let since = stillSince, time - since >= T.settleDelay, tuck < T.settleMaxTuck, angle < openAngle {
            rate = max(rate, 1 / T.settleTau)
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
