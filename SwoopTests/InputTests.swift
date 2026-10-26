import Foundation
import Testing
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
    func run(_ duration: Double, frames: Bool = true, snap: Bool = false, angle: (Double) -> Double) -> Double {
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
        // Never from a fold (a player already diving during the hold).
        hinge.run(1) { t in 146.7 - 21.7 * min(t / 0.3, 1) }
        hinge.run(1, snap: true) { _ in 125 }
        // (The fold itself nudges it a hair on the way through the near-open band.)
        #expect(abs(source.openAngle - 146.7) < 0.3)
        // Below the range it clamps to openMin, above to openMax.
        let low = HingeTuckSource(logs: false)
        FakeHinge(source: low).run(1, snap: true) { _ in 141 }
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

    // MARK: Closing

    @Test func closingLatchHasHysteresis() {
        // `#expect(latch.update(…))` can't call a mutating method (the macro captures `latch` immutably), so the
        // results are collected first.
        var latch = FeelClosingLatch()
        let angles: [Double] = [120, 96, 94, 98, 101.9, 102.5, 97, Double.nan]
        var results: [Bool] = []
        for angle in angles { results.append(latch.update(angle: angle)) }
        #expect(results == [false, false, true, true, true, false, false, false])
    }

    @Test func hingeSourceReportsClosingBelow95AndReopensAbove102() {
        let source = HingeTuckSource(logs: false)
        let hinge = FakeHinge(source: source)
        hinge.run(1.0) { _ in 160 }
        #expect(source.isClosing == false)
        hinge.run(1.0) { t in 160 - 70 * min(t / 0.8, 1) }
        #expect(source.isClosing)
        hinge.run(1.0) { t in 90 + 9 * min(t / 0.6, 1) }
        #expect(source.isClosing)
        hinge.run(1.0) { t in 99 + 11 * min(t / 0.4, 1) }
        #expect(source.isClosing == false)
        // The hinge is never forgotten.
        #expect(source.hasHinge)
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

    // MARK: Touch

    @Test func touchRampsUpIn120msAndDownIn100ms() {
        let touch = TouchTuckSource()
        #expect(touch.tuck(at: 10) == 0)
        touch.began(at: 10)
        #expect(touch.tuck(at: 10) == 0)
        #expect(abs(touch.tuck(at: 10.06) - 0.5) < 1e-6)
        #expect(abs(touch.tuck(at: 10.12) - 1) < 1e-6)
        #expect(touch.tuck(at: 11) == 1)
        // A smooth, monotonic attack.
        var previous: Double = -1
        for index in 0...24 {
            let value = touch.tuck(at: 10 + 0.005 * Double(index))
            #expect(value >= previous)
            previous = value
        }
        touch.ended(at: 11)
        #expect(abs(touch.tuck(at: 11.05) - 0.5) < 1e-6)
        #expect(touch.tuck(at: 11.1) < 1e-6)
        #expect(touch.tuck(at: 12) == 0)
    }

    @Test func touchRepressMidReleaseCarriesOnWithoutAJump() {
        let touch = TouchTuckSource()
        touch.began(at: 20)
        touch.ended(at: 20.03)
        #expect(abs(touch.tuck(at: 20.03) - FeelMath.smoothstep(0.25)) < 1e-6)
        touch.began(at: 20.04)
        #expect(abs(touch.tuck(at: 20.04) - FeelMath.smoothstep(0.15)) < 1e-6)
        #expect(touch.isHolding)
        #expect(abs(touch.tuck(at: 20.04 + 0.12 * 0.85 + 0.001) - 1) < 1e-9)
        // Double presses and stray releases are ignored.
        touch.began(at: 20.5)
        #expect(touch.tuck(at: 20.5) == 1)
        touch.ended(at: 21)
        touch.ended(at: 21.02)
        #expect(abs(touch.tuck(at: 21.05) - 0.5) < 1e-6)
    }
}
