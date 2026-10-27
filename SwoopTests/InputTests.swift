import Foundation
import Testing
import UIKit
@testable import Swoop

/// A fake Duo hinge for tests: the hand's angle as a function of time, reported like the real hinge (≤ 30 Hz, and only
/// when it moved at least `step` degrees: nothing while still), with display frames at 120 Hz.
@MainActor
private final class FakeHinge {
    let source: HingeTuckSource
    private(set) var time: Double = 100
    private var lastReported: Double?
    private var nextReport: Double = 0
    static let frame = 1.0 / 120
    static let reportInterval = 1.0 / 30
    static let step = 0.25

    init(source: HingeTuckSource) {
        self.source = source
    }

    /// Runs for `duration` s; `angle` gives the hand's angle at local time 0…duration. Returns the last tuck and
    /// collects every frame's tuck into `tucks`. `frames: false` asks no tuck (the resume hold); `snap` calls
    /// `snapCalibration` every frame (the countdown and the resume hold).
    @discardableResult
    func run(_ duration: Double, frames: Bool = true, snap: Bool = false, home: Bool = false,
             angle: (Double) -> Double) -> Double {
        let start = time
        let steps = Int((duration / Self.frame).rounded())
        var tuck: Double = 0
        tucks.removeAll()
        for _ in 0..<steps {
            time += Self.frame
            let local = time - start
            if time >= nextReport {
                let a = angle(local)
                var moved = true
                if let previous = lastReported { moved = abs(a - previous) >= Self.step }
                if moved {
                    source.ingest(angleDegrees: a, at: time)
                    lastReported = a
                }
                nextReport = time + Self.reportInterval
            }
            // The App snaps before it asks for the tuck (GameController.advance); the resume hold asks no tuck.
            if snap { source.snapCalibration(at: time) }
            if home { source.homeCalibrate(at: time) }
            if frames {
                tuck = source.tuck(at: time)
                tucks.append(tuck)
            }
        }
        return tuck
    }

    private(set) var tucks: [Double] = []
}

@MainActor
struct InputTests {
    // MARK: Tuck mapping

    @Test func tuckMappingRunsFromTheOpenAngleTo36DegreesBelow() {
        let open = 160.0
        #expect(HingeTuckSource.tuck(forAngle: open, open: open) == 0)
        #expect(abs(HingeTuckSource.tuck(forAngle: open - 36, open: open) - 1) < 1e-12)
        #expect(HingeTuckSource.tuck(forAngle: open - 60, open: open) == 1)
        #expect(abs(HingeTuckSource.tuck(forAngle: open - 18, open: open) - 0.5) < 1e-9)
        #expect(HingeTuckSource.tuck(forAngle: open + 8, open: open) == 0)
        // Flat (≥ 175°) always reads as fully open.
        #expect(HingeTuckSource.tuck(forAngle: 176, open: 172) == 0)
        #expect(HingeTuckSource.tuck(forAngle: 180, open: 172) == 0)
        #expect(HingeTuckSource.tuck(forAngle: Double.nan, open: open) == 0)
        // Monotonic: folding further never tucks less.
        var previous: Double = -1
        var angle: Double = 180
        while angle >= 90 {
            let u = HingeTuckSource.tuck(forAngle: angle, open: open)
            #expect(u >= previous)
            #expect(u >= 0 && u <= 1)
            previous = u
            angle -= 0.5
        }
        #expect(HingeTuckTuning.stroke == 36)
    }

    @Test func noHingeMeansNoTuck() {
        let source = HingeTuckSource(logs: false)
        #expect(source.hasHinge == false)
        #expect(source.angle == nil)
        #expect(source.tuck(at: 1) == 0)
        #expect(source.isClosing == false)
        #expect(source.openAngle == HingeTuckTuning.initialOpen)
    }

    // MARK: Feel

    @Test func aDeliberateSqueezeAnswersImmediately() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1.0) { _ in 160 }
        #expect(source.hasHinge)
        // A 36° squeeze in 0.4 s (90°/s).
        hinge.run(0.2) { t in 160 - 90 * t }
        // Ideal tuck at 142° is 0.5; allow only a couple of degrees of lag.
        #expect(source.lastTuck > 0.35)
        let end = hinge.run(0.2) { t in 142 - 90 * t }
        #expect(end > 0.9)
        let settled = hinge.run(0.15) { _ in 124 }
        #expect(settled > 0.97)
        // Opening again is just as quick.
        hinge.run(0.4) { t in 124 + 90 * t }
        let open = hinge.run(0.2) { _ in 160 }
        #expect(open < 0.05)
    }

    @Test func handTremorAtRestDoesNotFlutterTheWings() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        // The player settles at 158° (the calibration follows), then holds it with a little two-handed tremor.
        hinge.run(8.0) { _ in 158 }
        hinge.run(4.0) { t in 158 + 1.5 * sin(2 * Double.pi * 6 * t) }
        let tucks = hinge.tucks.suffix(360)
        let spread = (tucks.max() ?? 0) - (tucks.min() ?? 0)
        #expect(spread < 0.02)
        #expect((tucks.max() ?? 1) < 0.03)
    }

    // MARK: Calibration

    @Test func calibrationDoesNotDriftWhileATuckIsHeld() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1.0) { _ in 160 }
        #expect(abs(source.openAngle - 160) < 0.5)
        // Squeeze to 130° and hold the dive for 20 s, with hand tremor.
        hinge.run(0.4) { t in 160 - 30 * min(t / 0.3, 1) }
        let held = hinge.run(20) { t in 130 + 0.6 * sin(2 * Double.pi * 3 * t) }
        #expect(abs(source.openAngle - 160) < 0.5)
        #expect(held > 0.8)
        // And a dead-still hold (no reports at all) doesn't move it either.
        let still = hinge.run(20) { _ in 130 }
        #expect(abs(source.openAngle - 160) < 0.5)
        #expect(still > 0.8)
    }

    @Test func calibrationFollowsAHigherRestingAngle() {
        // Round 2: upward learning is slow (τ 10 s within 6° of open, τ 12 s beyond once held still).
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(30) { _ in 168 }
        #expect(source.openAngle > 167)
        #expect(source.openAngle <= 168.01)
        #expect(source.lastTuck == 0)
    }

    /// QA-1 P1-3: a wide-open glide used to drag "open" up to 170°+, so the normal 150° rest then read as a 0.6 tuck.
    @Test func calibrationDoesNotRatchetUpAfterAWideOpenGlide() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1) { _ in 150 }
        source.snapCalibration(at: hinge.time)
        #expect(abs(source.openAngle - 150) < 0.05)
        hinge.run(6) { _ in 176 }
        let rest = hinge.run(10) { _ in 150 }
        #expect(abs(source.openAngle - 150) < 1)
        #expect(rest < 0.05)
        // Not from 166° either (well above open + 6°, and moving in and out like a glide, never still for long).
        hinge.run(8) { t in 158 + 8 * sin(2 * Double.pi * 0.4 * t) }
        hinge.run(4) { _ in 150 }
        #expect(source.openAngle < 152)
    }

    @Test func upwardCalibrationIsSlowAndNearOpenOnly() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1) { _ in 150 }
        source.snapCalibration(at: hinge.time)
        hinge.run(10) { _ in 154 }
        // τ 10 s: about 63 % of the 4° after 10 s (the still-settle path is slower, so it doesn't change that).
        #expect(source.openAngle > 151.5)
        #expect(source.openAngle < 153.5)
        hinge.run(30) { _ in 154 }
        #expect(source.openAngle > 153.5)
        #expect(source.openAngle <= 154.01)
    }

    @Test func calibrationLearnsALowerRestingAngle() {
        let near = HingeTuckSource(logs: false)
        FakeHinge(source: near).run(30) { _ in 154 }
        #expect(abs(near.openAngle - 154) < 0.5)
        // Further down (a permanent tuck of ~0.19 at first): the slow settle path learns it while held still.
        let far = HingeTuckSource(logs: false)
        FakeHinge(source: far).run(30) { _ in 150 }
        #expect(far.openAngle < 152)
        #expect(far.openAngle >= HingeTuckTuning.openMin)
        #expect(far.lastTuck < 0.05)
    }

    /// Duo CI run 40318165524: a player resting at 146.7° during the countdown started 31 % tucked.
    @Test func readyPoseSnapsTheOpenAngle() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        // The countdown: frames ask for the tuck, and the App snaps on every one of them.
        hinge.run(1, snap: true) { _ in 146.7 }
        #expect(abs(source.openAngle - 146.7) < 0.05)
        #expect(source.lastTuck < 0.02)
        // Never from a fold (a player already diving during the hold; under the 125° learning floor).
        hinge.run(1) { t in 146.7 - 31.7 * min(t / 0.3, 1) }
        hinge.run(1, snap: true) { _ in 115 }
        // (The fold itself nudges it a hair on the way through the near-open band.)
        #expect(abs(source.openAngle - 146.7) < 0.3)
        // Below the range it clamps to openMin, above to openMax.
        let low = HingeTuckSource(logs: false)
        FakeHinge(source: low).run(1, snap: true) { _ in 128 }
        #expect(low.openAngle == HingeTuckTuning.openMin)
        let high = HingeTuckSource(logs: false)
        FakeHinge(source: high).run(1, snap: true) { _ in 174 }
        #expect(high.openAngle == HingeTuckTuning.openMax)
        // No hinge yet: nothing to snap to (the App's default-argument call compiles and does nothing).
        let none = HingeTuckSource(logs: false)
        none.snapCalibration()
        #expect(none.openAngle == HingeTuckTuning.initialOpen)
    }

    /// QA-1 P1-4: the resume hold snapped to raw, mid-reopen angles. Now only a still hinge, filtered, defines "open".
    @Test func resumeSnapIgnoresAHandStillReopening() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1, snap: true) { _ in 150 }
        #expect(abs(source.openAngle - 150) < 0.05)
        hinge.run(1) { t in 150 - 30 * min(t / 0.4, 1) }
        // The resume hold: no tuck is asked, the App snaps every frame, and the hand reopens slowly to 162°.
        hinge.run(2.5, frames: false, snap: true) { t in 120 + 42 * t / 2.5 }
        #expect(abs(source.openAngle - 150) < 0.3)
        // Once the hand rests, the snap lands on the rest.
        hinge.run(0.5, frames: false, snap: true) { _ in 162 }
        #expect(abs(source.openAngle - 162) < 0.8)
        // A fidget in the countdown (a hand still moving, 152°…172°) never snaps to a turnaround (±10°); only the
        // ordinary calibration nudges it a little.
        hinge.run(1.5, snap: true) { t in 162 - 10 * sin(2 * Double.pi * 1.2 * t) }
        #expect(abs(source.openAngle - 162) < 1.5)
    }

    @Test func calibrationStaysInsideItsRange() {
        // Round 2 (QA-1 P1-3): near-flat (177°) and flat (180°) rests never teach "open" at all; they read as open.
        let flat = HingeTuckSource(logs: false)
        FakeHinge(source: flat).run(20) { _ in 177 }
        #expect(flat.openAngle == HingeTuckTuning.initialOpen)
        #expect(flat.lastTuck == 0)
        let flatter = HingeTuckSource(logs: false)
        FakeHinge(source: flatter).run(10) { _ in 180 }
        #expect(flatter.openAngle == HingeTuckTuning.initialOpen)
        #expect(flatter.lastTuck == 0)
        // A low rest (146°, a tuck of 0.36 at first) is learned by the still-settle path, never below openMin.
        let low = HingeTuckSource(logs: false)
        FakeHinge(source: low).run(60) { _ in 146 }
        #expect(low.openAngle >= HingeTuckTuning.openMin)
        #expect(low.openAngle < 147)
    }

    // MARK: Closing (Round 4's gate; founder's Duo test, 27 Oct: 55° / 65°, a 0.2 s dwell, instant under 40°)

    @Test func closingGateDwellsInstantClosesAndHasHysteresis() {
        var gate = FeelClosingGate()
        gate.update(angle: 120, at: 0)
        #expect(gate.isClosing(at: 0) == false)
        // Under 55° for less than 0.2 s: still open.
        gate.update(angle: 53, at: 1.0)
        let early = gate.isClosing(at: 1.15)
        gate.update(angle: 57, at: 1.15)
        let afterBounce = gate.isClosing(at: 1.3)
        #expect(early == false)
        #expect(afterBounce == false)
        // Under 55° for 0.2 s: closed, and the dwell matures with time alone.
        gate.update(angle: 50, at: 2.0)
        let matured = gate.isClosing(at: 2.21)
        #expect(matured)
        // Hysteresis: 60° keeps it closed, 65.5° opens it.
        gate.update(angle: 60, at: 2.3)
        let held = gate.isClosing(at: 2.3)
        gate.update(angle: 65.5, at: 2.4)
        let reopened = gate.isClosing(at: 2.4)
        #expect(held)
        #expect(reopened == false)
        // Under 40°: closed at once.
        gate.update(angle: 35, at: 3.0)
        let slam = gate.isClosing(at: 3.0)
        #expect(slam)
        var instant = FeelClosingGate()
        instant.instant(angle: 45, at: 0)
        let notYet = instant.isClosing(at: 1)
        instant.instant(angle: 39, at: 1)
        let now = instant.isClosing(at: 1)
        instant.update(angle: Double.nan, at: 2)
        let stays = instant.isClosing(at: 2)
        #expect(notYet == false)
        #expect(now)
        #expect(stays)
        #expect(FeelClosingGate.closeBelow == 55)
        #expect(FeelClosingGate.reopenAbove == 65)
        #expect(FeelClosingGate.instantBelow == 40)
    }

    @Test func hingeSourceReportsClosingBelow55AndReopensAbove65() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1.0) { _ in 160 }
        #expect(source.isClosing == false)
        hinge.run(1.0) { t in 160 - 115 * min(t / 0.7, 1) }
        #expect(source.isClosing)
        hinge.run(1.0) { t in 45 + 15 * min(t / 0.6, 1) }
        #expect(source.isClosing)
        hinge.run(1.0) { t in 60 + 15 * min(t / 0.4, 1) }
        #expect(source.isClosing == false)
        // The hinge is never forgotten.
        #expect(source.hasHinge)
    }

    /// Founder, real Duo (27 Oct): folding "about halfway" (≈ 90°) to dive paused the run. A deep dive fold held well
    /// past halfway keeps flying, fully tucked.
    @Test func aDeepDiveFoldPastHalfwayKeepsFlying() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1, snap: true) { _ in 150 }
        let tuck = hinge.run(0.6) { t in 150 - 80 * min(t / 0.4, 1) }
        let deep = hinge.run(2.0) { _ in 70 }
        #expect(source.isClosing == false)
        #expect(source.closing(at: hinge.time + 1) == false)
        #expect(tuck > 0.95)
        #expect(deep > 0.95)
    }

    /// REVIEW-3-duo P1-2: an excited squeeze that overshoots full tuck for a moment must not pause the dive.
    @Test func aBriefOvershootDoesNotPauseButAHeldCloseAndASlamDo() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1, snap: true) { _ in 132 }
        hinge.run(0.25) { t in 132 - 82 * t / 0.25 }
        hinge.run(0.4) { t in 50 + 20 * min(t / 0.1, 1) }
        #expect(source.isClosing == false)
        // Held under 55°: paused once the dwell has passed.
        hinge.run(0.15) { t in 70 - 20 * min(t / 0.1, 1) }
        hinge.run(0.5) { _ in 50 }
        #expect(source.isClosing)
        #expect(source.closing(at: hinge.time + 1))
        // A slam under 40° pauses at once.
        let slam = HingeTuckSource(logs: false)
        let fast = FakeHinge(source: slam)
        fast.run(1) { _ in 150 }
        fast.run(0.15) { t in max(150 - 1500 * t, 25) }
        #expect(slam.isClosing)
    }

    // MARK: Round 4: hinge comfort (REVIEW-3-duo P1-1, P1-2, P1-5)

    @Test func strokeShortensForLowRests() {
        #expect(HingeTuckTuning.openMin == 132)
        #expect(HingeTuckTuning.calibrationLow == 125)
        #expect(HingeTuckTuning.stroke(forOpen: 160) == 36)
        #expect(HingeTuckTuning.stroke(forOpen: 136) == 36)
        #expect(HingeTuckTuning.stroke(forOpen: 134) == 34)
        #expect(HingeTuckTuning.stroke(forOpen: 132) == 32)
        #expect(HingeTuckTuning.stroke(forOpen: 120) == 30)
        // Open 132: full tuck at 100° (never into the 90° closing zone), half at 116°.
        #expect(abs(HingeTuckSource.tuck(forAngle: 100, open: 132) - 1) < 1e-12)
        #expect(abs(HingeTuckSource.tuck(forAngle: 116, open: 132) - 0.5) < 1e-9)
        #expect(HingeTuckSource.tuck(forAngle: 132, open: 132) == 0)
    }

    /// A player who reads at 134° used to fly permanently tucked (0.66 at 138°). Now the ready pose sets "open" there.
    @Test func aLowRestFliesWithSpreadWings() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1, snap: true) { _ in 134 }
        #expect(abs(source.openAngle - 134) < 0.05)
        let rest = hinge.run(2) { _ in 134 }
        #expect(rest < 0.02)
        #expect(source.restIsBelowFloor(at: hinge.time) == false)
        // Resting under the floor: the App's countdown nudge ("Open a little wider").
        let under = HingeTuckSource(logs: false)
        let underHinge = FakeHinge(source: under)
        underHinge.run(1) { _ in 127 }
        #expect(under.restIsBelowFloor(at: underHinge.time))
        let full = hinge.run(1) { t in 134 - 34 * min(t / 0.4, 1) }
        #expect(full > 0.97)
        #expect(source.isClosing == false)
        // The slow calibration learns a low rest from 125° too (it used to stop at 140°): from a 140° snap, a 130°
        // rest pulls "open" down to the 132° floor.
        let slow = HingeTuckSource(logs: false)
        let slowHinge = FakeHinge(source: slow)
        slowHinge.run(1, snap: true) { _ in 140 }
        slowHinge.run(60) { _ in 130 }
        #expect(slow.openAngle < 134)
        #expect(slow.openAngle >= HingeTuckTuning.openMin)
    }

    /// P1-5 (hinge wear): a slam gains nothing over a firm squeeze: the tuck rises 0 → 1 in no less than 0.15 s.
    @Test func aSlamCannotTuckFasterThanAFirmSqueeze() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1) { _ in 160 }
        let early = hinge.run(0.075) { _ in 110 }
        #expect(early <= 0.52)
        let later = hinge.run(0.2) { _ in 110 }
        #expect(later > 0.99)
        // Opening is never held back.
        let open = hinge.run(0.3) { _ in 160 }
        #expect(open < 0.05)
    }

    /// P1-2: the end-stop detent fires once per stroke when the tuck first hits full, and re-arms on opening.
    @Test func endStopFiresOncePerStroke() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1) { _ in 160 }
        var stops = 0
        var t0 = hinge.time
        for _ in 0..<120 {
            hinge.run(1.0 / 120) { _ in max(160 - 150 * (hinge.time - t0), 120) }
            if source.consumeEndStop() { stops += 1 }
        }
        #expect(stops == 1)
        // Half-open (tuck under 0.8) re-arms; the next full squeeze ticks again.
        t0 = hinge.time
        for _ in 0..<60 {
            hinge.run(1.0 / 120) { _ in min(120 + 150 * (hinge.time - t0), 150) }
            if source.consumeEndStop() { stops += 1 }
        }
        #expect(stops == 1)
        t0 = hinge.time
        for _ in 0..<60 {
            hinge.run(1.0 / 120) { _ in max(150 - 150 * (hinge.time - t0), 120) }
            if source.consumeEndStop() { stops += 1 }
        }
        #expect(stops == 2)
        // A stop nobody consumed in time (Home, Results) is dropped, not played late.
        let stale = HingeTuckSource(logs: false)
        let other = FakeHinge(source: stale)
        other.run(1) { _ in 160 }
        other.run(1) { t in 160 - 40 * min(t / 0.3, 1) }
        #expect(stale.consumeEndStop() == false)
    }

    @Test func samplesGoingBackInTimeAreHarmless() {
        let source = HingeTuckSource(logs: false)
        source.ingest(angleDegrees: 150, at: 10)
        source.ingest(angleDegrees: 140, at: 9)
        source.ingest(angleDegrees: Double.nan, at: 10.1)
        let tuck = source.tuck(at: 10.2)
        #expect(tuck.isFinite)
        #expect(source.tuck(at: 10.1) == tuck)
    }

    // MARK: Flat pose (Round 3, UX §9)

    @Test func flatPoseIsTimedFromTheLastReading() {
        let source = HingeTuckSource(logs: false)
        #expect(source.flatDuration(at: 1) == 0)
        #expect(source.timeSinceFlat(at: 1) == Double.infinity)
        source.ingest(angleDegrees: 160, at: 1)
        #expect(source.flatDuration(at: 2) == 0)
        #expect(source.timeSinceFlat(at: 2) == Double.infinity)
        source.ingest(angleDegrees: 176, at: 3)
        // The Duo sends nothing while still: the timer runs on from the last reading.
        #expect(abs(source.flatDuration(at: 4.5) - 1.5) < 1e-9)
        #expect(source.timeSinceFlat(at: 4.5) == 0)
        #expect(source.inFlatBlurGuard(at: 4.5) == false)
        // Hysteresis: 174° is still flat (it only leaves under 173°).
        source.ingest(angleDegrees: 174, at: 5)
        #expect(abs(source.flatDuration(at: 5) - 2) < 1e-9)
        source.ingest(angleDegrees: 168, at: 6)
        #expect(source.flatDuration(at: 6.5) == 0)
        #expect(abs(source.timeSinceFlat(at: 7) - 1) < 1e-9)
        // The 2.2 s fold-blur guard after leaving flat.
        #expect(source.inFlatBlurGuard(at: 7))
        #expect(source.inFlatBlurGuard(at: 8.5) == false)
    }

    // MARK: Touch

    @Test func touchRampsUpIn120msAndDownIn100ms() {
        let touch = TouchTuckSource()
        #expect(touch.tuck(at: 10) == 0)
        touch.began(at: 10)
        #expect(touch.tuck(at: 10) == 0)
        // Round 3 (UX §10): an ease-out ramp answers at once (44 % in 30 ms) and lands softly.
        #expect(touch.tuck(at: 10.03) > 0.4)
        #expect(abs(touch.tuck(at: 10.06) - 0.75) < 1e-6)
        #expect(abs(touch.tuck(at: 10.12) - 1) < 1e-6)
        #expect(touch.tuck(at: 11) == 1)
        // A smooth, monotonic attack whose steps shrink as it lands.
        var previous: Double = -1
        var previousStep: Double = 1
        for index in 0...24 {
            let value = touch.tuck(at: 10 + 0.005 * Double(index))
            #expect(value >= previous)
            if index > 0 {
                let step = value - previous
                #expect(step <= previousStep + 1e-9)
                previousStep = step
            }
            previous = value
        }
        touch.ended(at: 11)
        #expect(abs(touch.tuck(at: 11.05) - 0.25) < 1e-6)
        #expect(touch.tuck(at: 11.1) < 1e-6)
        #expect(touch.tuck(at: 12) == 0)
        #expect(TouchTuckRamp.easeOut(0) == 0)
        #expect(TouchTuckRamp.easeOut(1) == 1)
        #expect(TouchTuckRamp.easeOut(2) == 1)
    }

    @Test func touchRepressMidReleaseCarriesOnWithoutAJump() {
        let touch = TouchTuckSource()
        touch.began(at: 20)
        let beforeRelease = touch.tuck(at: 20.03)
        touch.ended(at: 20.03)
        #expect(abs(touch.tuck(at: 20.03) - beforeRelease) < 1e-12)
        let beforePress = touch.tuck(at: 20.04)
        #expect(beforePress < beforeRelease)
        touch.began(at: 20.04)
        #expect(abs(touch.tuck(at: 20.04) - beforePress) < 1e-12)
        #expect(touch.isHolding)
        // The rest of the stroke takes the rest of the attack: fully tucked within 0.12 s.
        #expect(abs(touch.tuck(at: 20.04 + 0.12) - 1) < 1e-9)
        // Double presses and stray releases are ignored.
        touch.began(at: 20.5)
        #expect(touch.tuck(at: 20.5) == 1)
        touch.ended(at: 21)
        touch.ended(at: 21.02)
        #expect(abs(touch.tuck(at: 21.05) - 0.25) < 1e-6)
    }

    @Test func touchAttackIsTunable() {
        let phone = TouchTuckSource(attack: TouchTuckSource.phoneAttack)
        #expect(phone.attack == 0.09)
        phone.began(at: 0)
        #expect(abs(phone.tuck(at: 0.09) - 1) < 1e-6)
        #expect(phone.tuck(at: 0.045) > 0.7)
        let nonsense = TouchTuckSource(attack: 0, release: Double.nan)
        #expect(nonsense.attack == TouchTuckSource.defaultAttack)
        #expect(nonsense.release == TouchTuckSource.defaultRelease)
    }

    /// F3: "Tuck by: Tapping" (Switch Control, VoiceOver, tired hands) toggles with the same ramps.
    @Test func tapToTuckTogglesAndIgnoresReleases() {
        let touch = TouchTuckSource()
        touch.tapToggles = true
        touch.began(at: 30)
        touch.ended(at: 30.05)
        #expect(touch.isHolding)
        #expect(touch.tuck(at: 30.2) == 1)
        touch.began(at: 31)
        touch.ended(at: 31.02)
        #expect(touch.isHolding == false)
        #expect(touch.tuck(at: 31.2) == 0)
        // Direct control (a Switch Control select, a VoiceOver adjustable).
        touch.toggle(at: 32)
        #expect(abs(touch.tuck(at: 32.06) - 0.75) < 1e-6)
        touch.setTucked(false, at: 33)
        #expect(touch.tuck(at: 33.2) == 0)
        touch.setTucked(true, at: 34)
        // Switching back to holding while tucked lets go, so a tuck can never get stuck on.
        touch.tapToggles = false
        #expect(touch.isHolding == false)
    }

    @Test func combinedSourceTakesTheLargerTuck() {
        let hinge = HingeTuckSource(logs: false)
        let touch = TouchTuckSource()
        let both = CombinedTuckSource(primary: hinge, assist: touch)
        #expect(both.tuck(at: 40) == 0)
        touch.setTucked(true, at: 40)
        #expect(both.tuck(at: 40.2) == 1)
        touch.setTucked(false, at: 41)
        hinge.ingest(angleDegrees: 142, at: 41)
        let value = both.tuck(at: 41.5)
        #expect(value > 0.3)
        #expect(value < 0.7)
    }

    // MARK: Round 5: Home calibration, persistence, low rests (REVIEW-4-duo P1-A, P2-2)

    /// A player resting at 140° on Home used to see a 0.58 tuck on the title bird (open stuck at 160°).
    @Test func homeSnapsTheRestAfterAStillSixTenths() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(0.4, home: true) { _ in 140 }
        #expect(source.openAngle == HingeTuckTuning.initialOpen)
        hinge.run(0.4, home: true) { _ in 140 }
        #expect(abs(source.openAngle - 140) < 0.05)
        let title = hinge.run(0.5, home: true) { _ in 140 }
        #expect(title < 0.02)
        // Opening wider is a new rest too (upward is never a tuck).
        hinge.run(0.3, home: true) { t in 140 + 10 * min(t / 0.2, 1) }
        hinge.run(1, home: true) { _ in 150 }
        #expect(abs(source.openAngle - 150) < 0.1)
        // Relaxing a few degrees lower is still a rest.
        hinge.run(0.3, home: true) { t in 150 - 5 * min(t / 0.2, 1) }
        hinge.run(1, home: true) { _ in 145 }
        #expect(abs(source.openAngle - 145) < 0.2)
    }

    /// "Never learn from a tucked angle": a fold held still on Home (the title bird is the tutorial) stays a tuck.
    @Test func homeNeverLearnsFromAHeldFold() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1, home: true) { _ in 152 }
        #expect(abs(source.openAngle - 152) < 0.05)
        hinge.run(0.3, home: true) { t in 152 - 24 * min(t / 0.25, 1) }
        let held = hinge.run(3, home: true) { _ in 128 }
        #expect(abs(source.openAngle - 152) < 0.5)
        #expect(held > 0.6)
        // Back to the rest: still fine, and a fold held below the learning floor never counts either.
        hinge.run(0.4, home: true) { t in 128 + 24 * min(t / 0.3, 1) }
        let back = hinge.run(1, home: true) { _ in 152 }
        #expect(back < 0.02)
        #expect(abs(source.openAngle - 152) < 0.5)
        // Nothing to do without a hinge.
        let none = HingeTuckSource(logs: false)
        #expect(none.homeCalibrate(at: 5) == false)
    }

    @Test func openAnglePersistsThroughAnAPI() {
        let source = HingeTuckSource(logs: false)
        var saved: [Double] = []
        source.onCalibrated = { open in saved.append(open) }
        source.restoreOpenAngle(141)
        #expect(source.openAngle == 141)
        source.restoreOpenAngle(100)
        #expect(source.openAngle == HingeTuckTuning.openMin)
        source.restoreOpenAngle(190)
        #expect(source.openAngle == HingeTuckTuning.openMax)
        source.restoreOpenAngle(Double.nan)
        #expect(source.openAngle == HingeTuckTuning.openMax)
        // Restoring doesn't call back; a real snap does (once per move of ≥ 0.5°).
        #expect(saved.isEmpty)
        let hinge = FakeHinge(source: source)
        hinge.run(1, snap: true) { _ in 147 }
        #expect(saved.count == 1)
        #expect(abs((saved.last ?? 0) - 147) < 0.05)
        hinge.run(1, home: true) { _ in 147.2 }
        #expect(saved.count == 1)
    }

    /// P1-8: a rest under 125° must never start the run fully tucked.
    @Test func lowRestFallbackNeverStartsFullyTucked() {
        let low = HingeTuckSource(logs: false)
        let lowHinge = FakeHinge(source: low)
        lowHinge.run(1) { _ in 122 }
        #expect(low.startTuck(at: lowHinge.time) > 0.9)
        #expect(low.lowRestFallback(at: lowHinge.time) == .snappedToFloor)
        #expect(low.openAngle == HingeTuckTuning.openMin)
        #expect(low.startTuck(at: lowHinge.time) < 0.4)
        // Under 119°: no open angle is safe, so nothing changes and the App keeps holding (and offers touch).
        let lower = HingeTuckSource(logs: false)
        let lowerHinge = FakeHinge(source: lower)
        lowerHinge.run(1) { _ in 112 }
        #expect(lower.lowRestFallback(at: lowerHinge.time) == .tooLow)
        #expect(lower.openAngle == HingeTuckTuning.initialOpen)
        // A normal rest is the ready snap's job; a moving hinge waits.
        let fine = HingeTuckSource(logs: false)
        let fineHinge = FakeHinge(source: fine)
        fineHinge.run(1) { _ in 140 }
        #expect(fine.lowRestFallback(at: fineHinge.time) == .fine)
        fineHinge.run(0.1) { t in 140 - 100 * t }
        #expect(fine.lowRestFallback(at: fineHinge.time) == .moving)
        #expect(HingeTuckSource(logs: false).lowRestFallback(at: 1) == .moving)
        // The worst allowed start (119°) is a third of a tuck, never full.
        #expect(HingeTuckSource.tuck(forAngle: HingeTuckTuning.lowRestFloor, open: HingeTuckTuning.openMin) < 0.4)
    }

    // MARK: Round 6: the sharp half (D1, UX-FLIGHT-SCHOOL §2.1, F5) and the flat-open counter (D1.4, F3)

    @Test func sharpHalfDefaultsToScreenRightInTheFirstOrientation() {
        // Whichever way the Duo is first held, the default sharp half is the one on screen-right then.
        for first in FeelLandscape.allCases {
            let sharp = SharpHalf.firstRun(in: first)
            #expect(sharp.physical == .a)
            #expect(sharp.reference == first)
            #expect(sharp.screenSide(in: first) == .right)
            // A 180° turn moves that physical half to screen-left: the bird follows it.
            #expect(sharp.screenSide(in: first.turned) == .left)
            #expect(sharp.screenSide(in: first.turned.turned) == .right)
        }
    }

    @Test func sharpHalfTracksThePhysicalHalfThroughTurnsAndAnswers() {
        let sharp = SharpHalf.firstRun(in: .right)
        // The Wing check, answered "this side ←" while held landscapeRight: the other physical half.
        let answered = sharp.recording(sharpSide: .left, in: .right)
        #expect(answered.physical == .b)
        #expect(answered.reference == .right)
        #expect(answered.screenSide(in: .right) == .left)
        #expect(answered.screenSide(in: .left) == .right)
        // The same physical answer given the other way up names the same half.
        let turnedAnswer = sharp.recording(sharpSide: .right, in: .left)
        #expect(turnedAnswer == answered)
        // Each screen side maps to one physical half, and the two differ.
        for o in FeelLandscape.allCases {
            let onLeft = sharp.physicalHalf(onScreen: .left, in: o)
            let onRight = sharp.physicalHalf(onScreen: .right, in: o)
            #expect(onLeft != onRight)
            #expect(onLeft == onRight.other)
        }
        #expect(FeelScreenSide.left.opposite == .right)
        // UIKit orientations.
        #expect(FeelLandscape.from(.landscapeLeft) == .left)
        #expect(FeelLandscape.from(.landscapeRight) == .right)
        #expect(FeelLandscape.from(.portrait) == nil)
        #expect(FeelLandscape.from(.unknown) == nil)
        // The CI log line.
        #expect(answered.logLine(in: .left) == "SWOOP-T birdside right physical=b o=L")
    }

    @Test func sharpHalfPersistsAsJSON() throws {
        let sharp = SharpHalf(physical: .b, reference: .left)
        let data = try JSONEncoder().encode(sharp)
        let back = try JSONDecoder().decode(SharpHalf.self, from: data)
        #expect(back == sharp)
    }

    @Test func flatOpeningsAreCountedWithHysteresis() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(0.5) { _ in 150 }
        source.resetFlatOpenings()
        #expect(source.flatOpenings == 0)
        // Open to 175°, wobble around 172–176° (no re-arm above 166°), back to 150°: one opening.
        hinge.run(0.5) { t in 150 + 25 * min(t / 0.3, 1) }
        hinge.run(0.5) { t in 174 + 2 * sin(2 * Double.pi * 4 * t) }
        hinge.run(0.5) { t in 175 - 25 * min(t / 0.3, 1) }
        #expect(source.flatOpenings == 1)
        // Two more full openings: three, the tip's trigger.
        for _ in 0..<2 {
            hinge.run(0.4) { t in 150 + 28 * min(t / 0.3, 1) }
            hinge.run(0.4) { t in 178 - 28 * min(t / 0.3, 1) }
        }
        #expect(source.flatOpenings == 3)
        // 173° is not flat.
        hinge.run(0.4) { t in 150 + 23 * min(t / 0.3, 1) }
        hinge.run(0.4) { t in 173 - 23 * min(t / 0.3, 1) }
        #expect(source.flatOpenings == 3)
        // A new run starting already flat doesn't count until the hinge comes back under 166°.
        hinge.run(0.5) { t in 150 + 28 * min(t / 0.3, 1) }
        source.resetFlatOpenings()
        hinge.run(0.5) { _ in 177 }
        #expect(source.flatOpenings == 0)
    }

    @Test func stepZeroStillnessUsesItsOwnWindow() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(0.3) { t in 150 - 10 * t / 0.3 }
        hinge.run(0.35) { _ in 140 }
        // 0.35 s after the hand stopped: still over 0.3 s, not yet over 0.5 s.
        #expect(source.isStill(at: hinge.time))
        #expect(source.isStill(at: hinge.time, window: 0.5) == false)
        hinge.run(0.3) { _ in 140 }
        #expect(source.isStill(at: hinge.time, window: 0.5))
    }
}
