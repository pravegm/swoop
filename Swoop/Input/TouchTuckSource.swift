import Foundation

/// The touch fallback (GAME-DESIGN §3): press and hold anywhere to tuck. The tuck ramps to 1 in 0.12 s and back to 0
/// in 0.10 s along a smoothstep, so a hold feels like folding rather than a switch.
///
/// A linear "progress" p (0…1) climbs at 1/0.12 per second while held and falls at 1/0.10 per second once released;
/// the tuck is smoothstep(p). p is continuous across presses, so a quick re-press mid-release carries on from where
/// the wings are (no jump). Everything is computed from the event times, so the answer never depends on how often
/// (or whether) frames asked in between.
@MainActor
final class TouchTuckSource: TuckSource {
    /// Seconds from fully open to fully tucked while held.
    static let attack: Double = 0.12
    /// Seconds from fully tucked to fully open after release.
    static let release: Double = 0.10

    /// True between `began` and `ended`.
    private(set) var isHolding = false
    /// Progress at the last press or release, and when that happened.
    private var anchorProgress: Double = 0
    private var anchorTime: TimeInterval = 0

    init() {}

    /// The finger went down (time = `CACurrentMediaTime()`, like the frames). Ignored while already holding.
    func began(at time: TimeInterval) {
        guard !isHolding, time.isFinite else { return }
        anchorProgress = progress(at: time)
        anchorTime = time
        isHolding = true
    }

    /// The finger went up (or the gesture was cancelled). Ignored while not holding.
    func ended(at time: TimeInterval) {
        guard isHolding, time.isFinite else { return }
        anchorProgress = progress(at: time)
        anchorTime = time
        isHolding = false
    }

    /// Same as `ended(at:)`.
    func cancelled(at time: TimeInterval) {
        ended(at: time)
    }

    func tuck(at time: TimeInterval) -> Double {
        guard time.isFinite else { return 0 }
        return FeelMath.smoothstep(progress(at: time))
    }

    /// Linear ramp progress 0…1 at `time` (a query older than the last event reads the anchor).
    private func progress(at time: TimeInterval) -> Double {
        let elapsed = max(time - anchorTime, 0)
        if isHolding {
            return FeelMath.clamp01(anchorProgress + elapsed / Self.attack)
        }
        return FeelMath.clamp01(anchorProgress - elapsed / Self.release)
    }
}
