import CoreGraphics
import Foundation
import Testing
@testable import Swoop

struct CoreTests {

    // MARK: Helpers

    /// A flying session (countdown skipped and the `started` step taken).
    private func flyingSession(seed: UInt64, mode: RunMode = .flight, best: Double = 0) -> FlightSession {
        let s = FlightSession(mode: mode, seed: seed, bestMeters: best, bird: .gull)
        s.skipCountdown()
        _ = s.step(dt: 1.0 / 240.0, tuck: 0)
        return s
    }

    private func run(_ s: FlightSession, seconds: Double, dt: Double, tuck: Double) -> [FlightEvent] {
        var events: [FlightEvent] = []
        var t: Double = 0
        while t < seconds && !s.isFinished {
            events.append(contentsOf: s.step(dt: dt, tuck: tuck))
            t += dt
        }
        return events
    }

    private func count(_ events: [FlightEvent], where match: (FlightEvent) -> Bool) -> Int {
        var n: Int = 0
        for e in events where match(e) { n += 1 }
        return n
    }

    private func isCaught(_ e: FlightEvent) -> Bool {
        if case .caught = e { return true }
        return false
    }

    private func isFinishedEvent(_ e: FlightEvent) -> Bool {
        if case .finished = e { return true }
        return false
    }

    // MARK: SeededRandom

    @Test func seededRandomIsDeterministicAndInRange() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var c = SeededRandom(seed: 43)
        var same: Bool = true
        var differs: Bool = false
        var i: Int = 0
        while i < 1000 {
            let x: UInt64 = a.next()
            if x != b.next() { same = false }
            if x != c.next() { differs = true }
            i += 1
        }
        #expect(same)
        #expect(differs)
        var r = SeededRandom(seed: 7)
        i = 0
        while i < 1000 {
            let u: Double = r.unit()
            #expect(u >= 0 && u < 1)
            let v: Double = r.range(2.0...5.0)
            #expect(v >= 2 && v <= 5)
            i += 1
        }
    }

    // MARK: Sea

    @Test func seaIsDeterministic() {
        let a = SeaProfile(seed: 1234)
        let b = SeaProfile(seed: 1234)
        let pa: [CGPoint] = a.samples(from: -2000, to: 60000, step: 7)
        // Query b out of order first: the cache must not change the answers.
        _ = b.height(at: 50000)
        _ = b.height(at: -1500)
        let pb: [CGPoint] = b.samples(from: -2000, to: 60000, step: 7)
        #expect(pa == pb)
        #expect(pa.count > 8000)
        let c = SeaProfile(seed: 1235)
        #expect(c.height(at: 20000) != a.height(at: 20000))
    }

    @Test func samplesAreInclusive() {
        let sea = SeaProfile(seed: 3)
        let pts: [CGPoint] = sea.samples(from: 0, to: 100, step: 30)
        #expect(pts.count == 5)
        #expect(pts.first?.x == 0)
        #expect(pts.last?.x == 100)
        #expect(sea.samples(from: 10, to: 0, step: 5).isEmpty)
        #expect(sea.samples(from: 0, to: 0, step: 5).count == 1)
    }

    @Test func seaSlopeNeverExceedsCapOver200km() {
        for seed in [UInt64(1), UInt64(987_654_321)] {
            let sea = SeaProfile(seed: seed)
            var maxSlope: Double = 0
            var x: Double = -2000
            while x <= 2_000_000 {
                maxSlope = max(maxSlope, abs(sea.slope(at: x)))
                x += 4
            }
            #expect(maxSlope <= 1.1, "seed \(seed) max slope \(maxSlope)")
            #expect(maxSlope > 0.5, "the sea should have real swells")
        }
    }

    @Test func seaIsContinuousAcrossSetBoundaries() {
        let sea = SeaProfile(seed: 77)
        let centres: [Double] = sea.blendCentres(through: 400_000)
        #expect(centres.count > 50)
        let half: Double = Tuning.seaBlendWidth / 2
        let eps: Double = 1e-6
        for c in centres {
            for edge in [c - half, c + half] {
                let h0: Double = sea.height(at: edge - eps)
                let h1: Double = sea.height(at: edge + eps)
                let d0: Double = sea.slope(at: edge - eps)
                let d1: Double = sea.slope(at: edge + eps)
                #expect(abs(h1 - h0) < 1e-3, "height jump at \(edge)")
                #expect(abs(d1 - d0) < 1e-3, "slope jump at \(edge)")
            }
        }
        // The analytic slope matches the height's finite difference everywhere (including inside blends).
        var x: Double = -1900
        var worst: Double = 0
        while x < 300_000 {
            let fd: Double = sea.height(at: x + 0.25) - sea.height(at: x - 0.25)
            worst = max(worst, abs(fd / 0.5 - sea.slope(at: x)))
            x += 61.7
        }
        #expect(worst < 2e-3, "slope vs finite difference \(worst)")
    }

    @Test func seaGetsBiggerWithDistance() {
        let sea = SeaProfile(seed: 5)
        func rms(_ a: Double, _ b: Double) -> Double {
            var s: Double = 0
            var n: Double = 0
            var x: Double = a
            while x < b {
                let h: Double = sea.height(at: x)
                s += h * h
                n += 1
                x += 10
            }
            return (s / max(n, 1)).squareRoot()
        }
        #expect(rms(200_000, 300_000) > rms(5_000, 30_000))
    }

    @Test func tutorialStartIsIdenticalForEverySeed() {
        let seas: [SeaProfile] = [SeaProfile(seed: 1), SeaProfile(seed: 2), SeaProfile(seed: 12345),
                                  SeaProfile(seed: UInt64.max)]
        var x: Double = -2000
        while x <= 1200 {
            let h: Double = seas[0].height(at: x)
            let d: Double = seas[0].slope(at: x)
            for s in seas {
                #expect(s.height(at: x) == h)
                #expect(s.slope(at: x) == d)
            }
            x += 5
        }
        // A long downslope just ahead of the start.
        #expect(seas[0].slope(at: 300) < 0)
        #expect(seas[0].slope(at: 900) < 0)
    }

    // MARK: Lighthouses and daily seeds

    @Test func lighthousePositions() {
        #expect(Lighthouses.x(index: 0) == 40_000)
        #expect(Lighthouses.x(index: 1) == 90_000)
        #expect(Lighthouses.x(index: 2) == 150_000)
        #expect(Lighthouses.x(index: 3) == 220_000)
        #expect(Lighthouses.x(index: 4) == 300_000)
        #expect(Lighthouses.x(index: 5) == 380_000)
        #expect(Lighthouses.x(index: 6) == 460_000)
    }

    @Test func lighthouseNamesAreSeededAndComplete() {
        #expect(Lighthouses.names.count >= 40)
        #expect(Set(Lighthouses.names).count == Lighthouses.names.count)
        var seen: Set<String> = []
        var i: Int = 0
        while i < Lighthouses.names.count {
            seen.insert(Lighthouses.name(index: i, seed: 9))
            i += 1
        }
        #expect(seen.count == Lighthouses.names.count)
        #expect(Lighthouses.name(index: 3, seed: 9) == Lighthouses.name(index: 3, seed: 9))
        #expect(Lighthouses.name(index: 0, seed: 9) == Lighthouses.name(index: Lighthouses.names.count, seed: 9))
        // Round 6 (UX U1): names are fixed by index in every mode; the seed is ignored.
        i = 0
        while i < 10 {
            #expect(Lighthouses.name(index: i, seed: 1) == Lighthouses.name(index: i, seed: 2))
            #expect(Lighthouses.name(index: i, seed: 77) == Lighthouses.name(index: i))
            i += 1
        }
    }

    @Test func dailySeedUsesUTCDays() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        comps.hour = 23
        comps.minute = 30
        let utc: Calendar = DailySeed.utc
        guard let lateFirst = utc.date(from: comps) else {
            Issue.record("no date")
            return
        }
        #expect(DailySeed.dayNumber(for: lateFirst) == 0)
        #expect(DailySeed.dayNumber(for: lateFirst.addingTimeInterval(3600)) == 1)
        #expect(DailySeed.dayNumber(for: lateFirst.addingTimeInterval(86400 * 10)) == 10)
        #expect(DailySeed.seed(day: 12) == DailySeed.seed(day: 12))
        #expect(DailySeed.seed(day: 12) != DailySeed.seed(day: 13))
        let s = FlightSession(mode: .daily(day: 12, scored: true), seed: 1, bestMeters: 0, bird: .gull)
        #expect(s.seed == DailySeed.seed(day: 12))
    }

    // MARK: Determinism

    @Test func sameSeedSameRun() {
        func play() -> ([FlightEvent], FlightSnapshot) {
            let s = FlightSession(mode: .flight, seed: 99, bestMeters: 120, bird: .tern)
            var pilot = FlightPilot(skill: .expert, seed: 5)
            var events: [FlightEvent] = []
            var i: Int = 0
            while i < 120 * 25 && !s.isFinished {
                let u: Double = pilot.tuck(for: s.snapshot, sea: s.sea)
                events.append(contentsOf: s.step(dt: 1.0 / 120.0, tuck: u))
                i += 1
            }
            return (events, s.snapshot)
        }
        let a = play()
        let b = play()
        #expect(a.0 == b.0)
        #expect(a.1 == b.1)
        #expect(a.0.count > 10)
    }

    // MARK: Physics sanity

    @Test func tuckingOnADownslopeAcceleratesMore() {
        let open = flyingSession(seed: 11)
        let tucked = flyingSession(seed: 11)
        open.testPlace(x: 400, altitude: 0, vx: 600, vy: 0)
        tucked.testPlace(x: 400, altitude: 0, vx: 600, vy: 0)
        #expect(open.sea.slope(at: 400) < -0.2)
        _ = run(open, seconds: 0.25, dt: 1.0 / 120.0, tuck: 0)
        _ = run(tucked, seconds: 0.25, dt: 1.0 / 120.0, tuck: 1)
        #expect(open.snapshot.skimming)
        #expect(tucked.snapshot.skimming)
        #expect(tucked.snapshot.speed > open.snapshot.speed + 100,
                "tucked \(tucked.snapshot.speed) open \(open.snapshot.speed)")
        #expect(open.snapshot.speed > 600)
    }

    @Test func openWingsDescendSlower() {
        let open = flyingSession(seed: 11)
        let tucked = flyingSession(seed: 11)
        open.testPlace(x: 400, altitude: 500, vx: 800, vy: 0)
        tucked.testPlace(x: 400, altitude: 500, vx: 800, vy: 0)
        // 0.4 s: the tuck needs ≥ 0.15 s to rise (Tuning.tuckMaxRise) before the dive gets going.
        _ = run(open, seconds: 0.4, dt: 1.0 / 120.0, tuck: 0)
        _ = run(tucked, seconds: 0.4, dt: 1.0 / 120.0, tuck: 1)
        #expect(!open.snapshot.skimming)
        #expect(!tucked.snapshot.skimming)
        #expect(open.snapshot.position.y > tucked.snapshot.position.y + 60)
        #expect(open.snapshot.velocity.dy > tucked.snapshot.velocity.dy)
    }

    @Test func liftNeverMakesTheBirdClimb() {
        let s = flyingSession(seed: 2)
        s.testPlace(x: 400, altitude: 600, vx: 2400, vy: -10)
        var i: Int = 0
        var lastY: Double = Double(s.snapshot.position.y)
        while i < 30 {
            _ = s.step(dt: 1.0 / 60.0, tuck: 0)
            let y: Double = Double(s.snapshot.position.y)
            #expect(y <= lastY + 1e-9)
            lastY = y
            i += 1
        }
    }

    @Test func neverTunnelsBelowTheWaterAtLowFrameRate() {
        let s = flyingSession(seed: 4242)
        var pilot = FlightPilot(skill: .casual, seed: 3)
        var i: Int = 0
        var worst: Double = 0
        while i < 30 * 90 && !s.isFinished {
            let u: Double = pilot.tuck(for: s.snapshot, sea: s.sea)
            // Mix in some hard dives at 30 Hz.
            let tuck: Double = (i / 20) % 3 == 0 ? 1 : u
            _ = s.step(dt: 1.0 / 30.0, tuck: tuck)
            let snap = s.snapshot
            let below: Double = s.sea.height(at: Double(snap.position.x)) - Double(snap.position.y)
            worst = max(worst, below)
            i += 1
        }
        #expect(worst < 0.5, "bird went \(worst) pt under the water")
    }

    @Test func minimumSpeedHolds() {
        let s = flyingSession(seed: 8)
        var i: Int = 0
        while i < 120 * 20 && !s.isFinished {
            _ = s.step(dt: 1.0 / 120.0, tuck: (i / 50) % 2 == 0 ? 1 : 0)
            let snap = s.snapshot
            if case .flying = snap.phase {
                #expect(snap.speed >= Tuning.minSpeed * 0.999)
            }
            i += 1
        }
    }

    // MARK: Touchdown classification

    @Test func touchdownClassification() {
        // Round 2: Perfect ≤ 18° on a slope below −2°, Good ≤ 36°, both after a 7° landing assist.
        let deg: Double = Double.pi / 180
        #expect(FlightSession.classify(velocityAngle: -30 * deg, surfaceAngle: -25 * deg) == .perfect)
        // 25° raw − 7° assist = 18°: still Perfect; 26° raw is only Good.
        #expect(FlightSession.classify(velocityAngle: -49.9 * deg, surfaceAngle: -25 * deg) == .perfect)
        #expect(FlightSession.classify(velocityAngle: -51.5 * deg, surfaceAngle: -25 * deg) == .good)
        // Lined up but not downhill enough: only Good.
        #expect(FlightSession.classify(velocityAngle: -1 * deg, surfaceAngle: -1 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: 8 * deg, surfaceAngle: 5 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: -3 * deg, surfaceAngle: -3 * deg) == .perfect)
        // 43° raw − 7° = 36°: Good; beyond: splash.
        #expect(FlightSession.classify(velocityAngle: -52.9 * deg, surfaceAngle: -10 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: -54 * deg, surfaceAngle: -10 * deg) == .splash)
        #expect(FlightSession.classify(velocityAngle: -40 * deg, surfaceAngle: 15 * deg) == .splash)
    }

    @Test func landingAssistTurnsAtMostSevenDegrees() {
        let deg: Double = Double.pi / 180
        let a: Double = Tuning.assistedAngle(velocityAngle: -40 * deg, surfaceAngle: -20 * deg)
        #expect(abs(a - (-33 * deg)) < 1e-12)
        let b: Double = Tuning.assistedAngle(velocityAngle: -22 * deg, surfaceAngle: -20 * deg)
        #expect(abs(b - (-20 * deg)) < 1e-12)
        let c: Double = Tuning.assistedAngle(velocityAngle: 10 * deg, surfaceAngle: 30 * deg)
        #expect(abs(c - (17 * deg)) < 1e-12)
    }

    @Test func perfectLandingKeepsSpeedAndPushesStorm() {
        // Drop onto the tutorial downslope (≈ −28° at x = 650) at 2° steeper than the surface, from 1 pt above it.
        let deg: Double = Double.pi / 180
        let s = flyingSession(seed: 1)
        let phi: Double = atan(s.sea.slope(at: 650))
        #expect(phi < -20 * deg)
        let beta: Double = phi - 2 * deg
        let sp: Double = 900
        s.testPlace(x: 650, altitude: 1, vx: sp * cos(beta), vy: sp * sin(beta))
        let gapBefore: Double = s.snapshot.gap
        var ev: [FlightEvent] = []
        var i: Int = 0
        while i < 120 && s.snapshot.perfects == 0 && !s.snapshot.skimming {
            ev.append(contentsOf: s.step(dt: 1.0 / 240.0, tuck: 0))
            i += 1
        }
        var found: Bool = false
        for e in ev {
            if case .touchdown(let q, let speed, let chain) = e {
                #expect(q == .perfect)
                if q == .perfect {
                    found = true
                    #expect(chain == 1)
                    #expect(speed > 800)
                }
            }
        }
        #expect(found)
        #expect(s.snapshot.perfects == 1)
        #expect(s.snapshot.chain == 1)
        #expect(s.snapshot.skimming)
        #expect(s.snapshot.speed > sp)
        #expect(s.snapshot.gap > gapBefore + Tuning.perfectGapBonus - 60)
    }

    // MARK: The storm

    @Test func stormCatchesAnIdleBird() {
        let s = FlightSession(mode: .flight, seed: 3, bestMeters: 0, bird: .gull)
        var events: [FlightEvent] = []
        var caughtAt: Double = -1
        var finishedAt: Double = -1
        var i: Int = 0
        while i < 60 * 300 && !s.isFinished {
            let ev: [FlightEvent] = s.step(dt: 1.0 / 60.0, tuck: 0)
            for e in ev {
                if isCaught(e) { caughtAt = s.snapshot.time }
                if isFinishedEvent(e) { finishedAt = s.snapshot.time }
            }
            events.append(contentsOf: ev)
            i += 1
        }
        #expect(s.isFinished)
        #expect(caughtAt > 0)
        #expect(finishedAt >= caughtAt + Tuning.caughtDuration - 1.0 / 60.0)
        #expect(count(events, where: isCaught) == 1)
        #expect(count(events, where: isFinishedEvent) == 1)
        let r: RunResult? = s.result
        #expect(r != nil)
        if let r = r {
            #expect(r.seconds > 15 && r.seconds < 150)
            #expect(r.meters > 100)
            #expect(r.longestCleanMeters <= r.meters + 0.001)
            #expect(r.score >= Int(r.meters.rounded(.down)))
            #expect(r.birdID == .gull)
        }
        // Nothing after the end.
        #expect(s.step(dt: 1.0 / 60.0, tuck: 1).isEmpty)
    }

    @Test func attractNeverFinishes() {
        let s = FlightSession(mode: .attract, seed: 21, bestMeters: 0, bird: .gull)
        s.skipCountdown()
        var caught: Int = 0
        var i: Int = 0
        while i < 30 * 600 {
            let ev: [FlightEvent] = s.step(dt: 1.0 / 30.0, tuck: 0)
            caught += count(ev, where: isCaught)
            i += 1
        }
        #expect(!s.isFinished)
        #expect(caught == 0)
        #expect(s.result == nil)
        #expect(abs(s.snapshot.gap - Tuning.attractStormLag) < 1e-6)
        #expect(abs(s.snapshot.lead - 0.5) < 1e-6)
        #expect(s.snapshot.distanceMeters > 1000)
    }

    @Test func stormCloseFiresOncePerDip() {
        let s = flyingSession(seed: 6)
        s.testSetGap(0.10 * Tuning.fullLead)
        var ev: [FlightEvent] = s.step(dt: 1.0 / 60.0, tuck: 0)
        let isClose: (FlightEvent) -> Bool = { (e: FlightEvent) -> Bool in
            if case .stormClose = e { return true }
            return false
        }
        #expect(count(ev, where: isClose) == 1)
        ev = s.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(count(ev, where: isClose) == 0)
        // Back above 30 % re-arms it.
        s.testSetGap(0.5 * Tuning.fullLead)
        _ = s.step(dt: 1.0 / 60.0, tuck: 0)
        s.testSetGap(0.12 * Tuning.fullLead)
        ev = s.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(count(ev, where: isClose) == 1)
    }

    // MARK: Events

    @Test func eventsComeInOrder() {
        let s = FlightSession(mode: .flight, seed: 31, bestMeters: 50, bird: .gull)
        var events: [FlightEvent] = []
        var i: Int = 0
        while i < 60 * 300 && !s.isFinished {
            events.append(contentsOf: s.step(dt: 1.0 / 60.0, tuck: 0))
            i += 1
        }
        #expect(events.count > 6)
        if events.count > 4 {
            #expect(events[0] == .countdownTick(3))
            #expect(events[1] == .countdownTick(2))
            #expect(events[2] == .countdownTick(1))
            #expect(events[3] == .started)
        }
        #expect(events.last == FlightEvent.finished)
        var km: Int = 0
        var sawCaught: Bool = false
        var newBests: Int = 0
        for e in events {
            switch e {
            case .milestone(let k):
                #expect(k == km + 1)
                km = k
            case .caught:
                sawCaught = true
            case .finished:
                #expect(sawCaught)
            case .newBest:
                newBests += 1
            case .launched, .touchdown, .tailwindStarted, .tailwindEnded, .lighthouse:
                #expect(!sawCaught)
            default:
                break
            }
        }
        #expect(km >= 1)
        #expect(newBests == 1)
    }

    @Test func noNewBestWithoutABest() {
        let s = FlightSession(mode: .flight, seed: 31, bestMeters: 0, bird: .gull)
        let ev: [FlightEvent] = run(s, seconds: 30, dt: 1.0 / 60.0, tuck: 0)
        #expect(!ev.contains(FlightEvent.newBest))
    }

    @Test func skipCountdownStartsImmediately() {
        let s = FlightSession(mode: .flight, seed: 1, bestMeters: 0, bird: .gull)
        s.skipCountdown()
        let ev: [FlightEvent] = s.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(ev.first == FlightEvent.started)
        #expect(!ev.contains(FlightEvent.countdownTick(3)))
        #expect(s.snapshot.phase == .flying)
        #expect(s.snapshot.speed > 500)
    }

    @Test func countdownHoversTheBird() {
        let s = FlightSession(mode: .flight, seed: 1, bestMeters: 0, bird: .gull)
        let y0: CGFloat = s.snapshot.position.y
        _ = run(s, seconds: 2.5, dt: 1.0 / 60.0, tuck: 0)
        #expect(s.snapshot.position.y == y0)
        if case .countdown(let remaining) = s.snapshot.phase {
            #expect(remaining > 0.4 && remaining < 0.6)
        } else {
            Issue.record("expected the countdown")
        }
        #expect(abs(Double(y0) - (s.sea.height(at: 0) + Tuning.startHeight)) < 1e-9)
    }

    @Test func cloudTouchedOncePerClimb() {
        // Round 2: clouds are at Tuning.cloudHeight above the MEAN water (the Scene draws them there).
        let s = flyingSession(seed: 12)
        s.testPlace(x: 5000, altitude: Tuning.cloudHeight + 50 - s.sea.height(at: 5000), vx: 900, vy: 0)
        let isCloud: (FlightEvent) -> Bool = { (e: FlightEvent) -> Bool in
            if case .cloudTouched = e { return true }
            return false
        }
        var ev: [FlightEvent] = s.step(dt: 1.0 / 120.0, tuck: 0)
        #expect(count(ev, where: isCloud) == 1)
        ev = run(s, seconds: 0.1, dt: 1.0 / 120.0, tuck: 0)
        #expect(count(ev, where: isCloud) == 0)
    }

    @Test func lighthousePushesTheStormBack() {
        let s = flyingSession(seed: 14)
        s.testPlace(x: Lighthouses.x(index: 0) - 10, altitude: 0, vx: 900, vy: 0)
        let gapBefore: Double = s.snapshot.gap
        let ev: [FlightEvent] = run(s, seconds: 0.05, dt: 1.0 / 120.0, tuck: 0)
        let expectedName: String = Lighthouses.name(index: 0, seed: s.seed)
        #expect(ev.contains(FlightEvent.lighthouse(index: 0, name: expectedName)))
        #expect(s.snapshot.lighthousesPassed == 1)
        #expect(s.snapshot.nextLighthouseX == Lighthouses.x(index: 1))
        // The R3 storm leash closes any gap beyond stormLeashGap at stormLeashRate/s, so over these 0.05 s it takes
        // back part of the bonus when the test bird is far ahead (gap ≈ 42 km here).
        let leashLoss: Double = Tuning.stormLeashSpeed(gap: gapBefore + Tuning.lighthouseGapBonus) * 0.05
        #expect(s.snapshot.gap > gapBefore + Tuning.lighthouseGapBonus - 200 - leashLoss)
    }

    @Test func snapshotIsPopulated() {
        let s = flyingSession(seed: 15, best: 321)
        _ = run(s, seconds: 2, dt: 1.0 / 60.0, tuck: 0)
        let snap = s.snapshot
        #expect(snap.phase == .flying)
        #expect(snap.speed > 0)
        #expect(snap.distanceMeters > 10)
        let style: Double = Tuning.perfectStyleMeters * Double(snap.perfects)
        #expect(snap.score == Int((snap.distanceMeters + style).rounded(.down)))
        #expect(snap.lead > 0 && snap.lead <= 1)
        #expect(snap.nextLighthouseX == Lighthouses.x(index: 0))
        #expect(!snap.nextLighthouseName.isEmpty)
        #expect(snap.bestMeters == 321)
        #expect(snap.altitude >= 0)
        #expect(abs(snap.gap - (Double(snap.position.x) - snap.stormX)) < 1e-6)
    }

    // MARK: Pilot

    @Test func pilotIsDeterministicAndHoldsItsDecisions() {
        func play() -> [Double] {
            let s = flyingSession(seed: 50)
            var pilot = FlightPilot(skill: .perfect, seed: 77)
            var out: [Double] = []
            var i: Int = 0
            while i < 120 * 40 && !s.isFinished {
                let u: Double = pilot.tuck(for: s.snapshot, sea: s.sea)
                out.append(u)
                _ = s.step(dt: 1.0 / 120.0, tuck: u)
                i += 1
            }
            return out
        }
        let a: [Double] = play()
        let b: [Double] = play()
        #expect(a == b)
        var lastChange: Int = -1000
        var changes: Int = 0
        var i: Int = 1
        while i < a.count {
            #expect(a[i] == 0 || a[i] == 1)
            if a[i] != a[i - 1] {
                #expect(Double(i - lastChange) / 120.0 >= 0.12 - 1e-9)
                lastChange = i
                changes += 1
            }
            i += 1
        }
        #expect(changes > 10)
    }

    @Test func perfectPilotLandsPerfects() {
        let s = flyingSession(seed: 60)
        var pilot = FlightPilot(skill: .perfect, seed: 1)
        var perfects: Int = 0
        var i: Int = 0
        while i < 120 * 60 && !s.isFinished {
            let u: Double = pilot.tuck(for: s.snapshot, sea: s.sea)
            for e in s.step(dt: 1.0 / 120.0, tuck: u) {
                if case .touchdown(let q, _, _) = e, q == .perfect { perfects += 1 }
            }
            i += 1
        }
        #expect(perfects >= 5)
        #expect(!s.isFinished)
    }

    // MARK: Goals

    private func result(meters: Double = 0, perfects: Int = 0, chain: Int = 0, lighthouses: Int = 0,
                        clouds: Int = 0, clean: Double = 0, tailwinds: Int = 0, speed: Double = 0,
                        mode: RunMode = .flight) -> RunResult {
        return RunResult(mode: mode, seed: 1, meters: meters, score: Int(meters), seconds: 60, perfects: perfects,
                         goods: 0, splashes: 0, bestChain: chain, tailwinds: tailwinds, lighthouses: lighthouses,
                         lastLighthouseName: "", cloudTouches: clouds, maxSpeed: speed, maxAltitude: 0,
                         longestCleanMeters: clean, birdID: .gull)
    }

    @Test func goalEvaluator() {
        let reach = Goal(id: "a", kind: .reachMeters, target: 1000, text: "")
        #expect(GoalEvaluator.progress(reach, run: result(meters: 500), lifetimeMeters: 0, dailyPlayed: false) == 0.5)
        #expect(GoalEvaluator.progress(reach, run: result(meters: 1500), lifetimeMeters: 0, dailyPlayed: false) == 1)
        let total = Goal(id: "b", kind: .totalMeters, target: 10000, text: "")
        #expect(GoalEvaluator.progress(total, run: result(meters: 10), lifetimeMeters: 2500, dailyPlayed: false) == 0.25)
        let chain = Goal(id: "c", kind: .chain, target: 4, text: "")
        #expect(GoalEvaluator.progress(chain, run: result(chain: 2), lifetimeMeters: 0, dailyPlayed: false) == 0.5)
        let daily = Goal(id: "d", kind: .dailyPlayed, target: 1, text: "")
        #expect(GoalEvaluator.progress(daily, run: result(), lifetimeMeters: 0, dailyPlayed: false) == 0)
        #expect(GoalEvaluator.progress(daily, run: result(), lifetimeMeters: 0, dailyPlayed: true) == 1)
        #expect(GoalEvaluator.progress(daily, run: result(mode: .daily(day: 3, scored: true)), lifetimeMeters: 0,
                                       dailyPlayed: false) == 1)
        let speed = Goal(id: "e", kind: .speed, target: 2000, text: "")
        #expect(GoalEvaluator.progress(speed, run: result(speed: 2600), lifetimeMeters: 0, dailyPlayed: false) == 1)
        let clean = Goal(id: "f", kind: .cleanMeters, target: 3000, text: "")
        #expect(GoalEvaluator.progress(clean, run: result(clean: 1500), lifetimeMeters: 0, dailyPlayed: false) == 0.5)
        let clouds = Goal(id: "g", kind: .cloudTouches, target: 2, text: "")
        #expect(GoalEvaluator.progress(clouds, run: result(clouds: 1), lifetimeMeters: 0, dailyPlayed: false) == 0.5)
        let lh = Goal(id: "h", kind: .lighthouses, target: 2, text: "")
        #expect(GoalEvaluator.progress(lh, run: result(lighthouses: 3), lifetimeMeters: 0, dailyPlayed: false) == 1)
        let tw = Goal(id: "i", kind: .tailwinds, target: 4, text: "")
        #expect(GoalEvaluator.progress(tw, run: result(tailwinds: 1), lifetimeMeters: 0, dailyPlayed: false) == 0.25)
        let pf = Goal(id: "j", kind: .perfectsInRun, target: 10, text: "")
        #expect(GoalEvaluator.progress(pf, run: result(perfects: 0), lifetimeMeters: 0, dailyPlayed: false) == 0)
    }

    // MARK: Catalogues

    @Test func birdCatalogIsComplete() {
        let all: [Bird] = BirdCatalog.all
        #expect(all.count == BirdID.allCases.count)
        for id in BirdID.allCases {
            #expect(BirdCatalog.bird(id).id == id)
            #expect(all.contains(where: { (b: Bird) -> Bool in b.id == id }))
        }
        #expect(BirdCatalog.bird(.gull).unlockRank == 0)
        #expect(Set(all.map { (b: Bird) -> String in b.name }).count == all.count)
        for b in all {
            #expect(b.unlockRank >= 0 && b.unlockRank <= GoalCatalog.maxRank)
            #expect(b.span > 0.5 && b.span < 1.6)
            #expect(b.pointiness >= 0 && b.pointiness <= 1)
            #expect(!b.blurb.isEmpty)
        }
    }

    @Test func skyCatalogIsComplete() {
        let all: [Sky] = SkyCatalog.all
        #expect(all.count == SkyID.allCases.count)
        for id in SkyID.allCases {
            #expect(SkyCatalog.sky(id).id == id)
        }
        #expect(SkyCatalog.sky(.goldenHour).unlockRank == 0)
        for s in all {
            #expect(s.unlockRank >= 0 && s.unlockRank <= GoalCatalog.maxRank)
        }
    }

    @Test func goalLadderIsComplete() {
        // Round 2: 15 ranks (0…14), 14 flocks of 3.
        #expect(GoalCatalog.maxRank == 14)
        var ids: Set<String> = []
        var rank: Int = 0
        while rank < GoalCatalog.maxRank {
            let goals: [Goal] = GoalCatalog.goals(forRank: rank)
            #expect(goals.count == 3, "rank \(rank)")
            for goal in goals {
                ids.insert(goal.id)
                #expect(goal.target > 0)
                #expect(!goal.text.isEmpty)
            }
            #expect(!GoalCatalog.rankTitle(rank).isEmpty)
            rank += 1
        }
        #expect(ids.count == 42)
        for goal in GoalCatalog.ladder.joined() {
            #expect(goal.kind != .speed, "speed goals can't be seen (REVIEW-1 P1-8)")
        }
        #expect(GoalCatalog.goals(forRank: GoalCatalog.maxRank).isEmpty)
        #expect(GoalCatalog.goals(forRank: -1).isEmpty)
        #expect(GoalCatalog.rankTitle(0) == "Fledgling")
        #expect(GoalCatalog.rankTitle(GoalCatalog.maxRank) == "Storm Rider")
        #expect(GoalCatalog.goals(forRank: 0)[0].text == "Fly 1 km in one flight")
        #expect(GoalCatalog.titles.count == GoalCatalog.maxRank + 1)
    }

    @Test func everyRankPaysOut() {
        #expect(GoalCatalog.rewards(forRank: 0).isEmpty)
        var rank: Int = 1
        var seen: Int = 0
        while rank <= GoalCatalog.maxRank {
            let r: [RankReward] = GoalCatalog.rewards(forRank: rank)
            #expect(!r.isEmpty, "rank \(rank) unlocks nothing")
            seen += r.count
            rank += 1
        }
        // Every bird, sky and trail except the starting ones is unlocked exactly once.
        #expect(seen == (BirdCatalog.all.count - 1) + (SkyCatalog.all.count - 1) + (TrailCatalog.all.count - 1))
        #expect(GoalCatalog.rewards(forRank: GoalCatalog.maxRank).contains(.bird(.gannet)))
    }

    @Test func trailCatalogIsComplete() {
        #expect(TrailCatalog.all.count == TrailID.allCases.count)
        for id in TrailID.allCases {
            #expect(TrailCatalog.trail(id).id == id)
        }
        #expect(TrailCatalog.trail(.natural).unlockRank == 0)
        let gull: Bird = BirdCatalog.bird(.gull)
        #expect(TrailCatalog.color(.natural, for: gull) == gull.trail)
        let coral: Bird = TrailCatalog.apply(.coral, to: gull)
        #expect(coral.trail != gull.trail)
        #expect(coral.id == .gull)
        for t in TrailCatalog.all {
            #expect(t.unlockRank >= 0 && t.unlockRank <= GoalCatalog.maxRank)
        }
    }

    // MARK: Round 2

    @Test func samplesIntoMatchesSamples() {
        let sea = SeaProfile(seed: 9)
        var buffer: [CGPoint] = []
        sea.samples(into: &buffer, from: -500, to: 9000, step: 13)
        #expect(buffer == sea.samples(from: -500, to: 9000, step: 13))
        sea.samples(into: &buffer, from: 0, to: 100, step: 30)
        #expect(buffer.count == 5)
    }

    @Test func tutorialIntroIsSmooth() {
        let sea = SeaProfile(seed: 4)
        var worst: Double = 0
        var x: Double = -3000
        while x < 6000 {
            let fd: Double = sea.height(at: x + 0.25) - sea.height(at: x - 0.25)
            worst = max(worst, abs(fd / 0.5 - sea.slope(at: x)))
            #expect(abs(sea.slope(at: x)) <= 1.1)
            x += 3.7
        }
        #expect(worst < 2e-3)
        for k in Tuning.tutorialKnots {
            #expect(abs(sea.slope(at: k.x)) < 1e-6)
            #expect(abs(sea.height(at: k.x) - k.y) < 1e-6)
        }
    }

    /// One tutorial scenario: tuck = 1 while `tuckWhen` says so. Returns the qualities of the first two touchdowns,
    /// the time of the first one, and when the bird first skims an upslope after it (the trough).
    private func tutorialRun(_ tuckWhen: (Double) -> Bool) -> (q: [TouchdownQuality], land: Double, trough: Double) {
        let s = FlightSession(mode: .flight, seed: 1, bestMeters: 0, bird: .gull)
        s.skipCountdown()
        var t: Double = 0
        var qs: [TouchdownQuality] = []
        var land: Double = -1
        var trough: Double = -1
        while t < 12 && qs.count < 2 {
            let ev: [FlightEvent] = s.step(dt: 1.0 / 120.0, tuck: tuckWhen(t) ? 1 : 0)
            t += 1.0 / 120.0
            for e in ev {
                if case .touchdown(let q, _, _) = e {
                    qs.append(q)
                    if qs.count == 1 { land = t }
                }
            }
            let snap = s.snapshot
            if land >= 0 && trough < 0 && snap.skimming && s.sea.slope(at: Double(snap.position.x)) >= 0 {
                trough = t
            }
        }
        return (qs, land, trough)
    }

    @Test func tutorialGuaranteesPerfects() {
        // Doing nothing: the drop lands Perfect, and so does the landing on the second swell.
        let idle = tutorialRun({ (_: Double) -> Bool in false })
        #expect(idle.q == [.perfect, .perfect])
        #expect(idle.land > 0 && idle.land < 3)
        #expect(idle.trough > idle.land)
        // Tucking at any point on the first downslope (for any length, released by just after the trough) still
        // lands Perfect on the second swell.
        let span: Double = idle.trough - idle.land
        var fails: [String] = []
        var f: Double = 0
        while f < 1 {
            for len in [0.15, 0.3, 0.5, 1.0, 99.0] {
                let a: Double = idle.land + f * span
                let b: Double = min(a + len, idle.trough + 0.2)
                let r = tutorialRun({ (t: Double) -> Bool in t >= a && t < b })
                if r.q.count < 2 || r.q[1] != .perfect {
                    fails.append("tuck \(a)…\(b): \(r.q)")
                }
            }
            f += 0.125
        }
        #expect(fails.isEmpty, "\(fails)")
    }

    @Test func aGoodHoldsTheChainAndASplashBreaksIt() {
        let deg: Double = Double.pi / 180
        let s = flyingSession(seed: 1)
        let phi: Double = atan(s.sea.slope(at: 650))
        func land(_ offsetDeg: Double) -> [FlightEvent] {
            let beta: Double = phi - offsetDeg * deg
            s.testPlace(x: 650, altitude: 1, vx: 900 * cos(beta), vy: 900 * sin(beta))
            var ev: [FlightEvent] = []
            var i: Int = 0
            while i < 240 && !s.snapshot.skimming {
                ev.append(contentsOf: s.step(dt: 1.0 / 240.0, tuck: 0))
                i += 1
            }
            return ev
        }
        _ = land(2)
        #expect(s.snapshot.chain == 1)
        let good: [FlightEvent] = land(32)
        let goodsAtOne: Int = count(good, where: { (e: FlightEvent) -> Bool in
            if case .touchdown(.good, _, let c) = e { return c == 1 }
            return false
        })
        #expect(goodsAtOne == 1)
        #expect(s.snapshot.chain == 1)
        #expect(s.snapshot.perfects == 1)
        _ = land(2)
        #expect(s.snapshot.chain == 2)
        _ = land(55)
        #expect(s.snapshot.chain == 0)
        #expect(s.snapshot.bestChain == 2)
    }

    @Test func tailwindEndsWithoutASpeedJolt() {
        let deg: Double = Double.pi / 180
        let s = flyingSession(seed: 1)
        let phi: Double = atan(s.sea.slope(at: 650))
        var started: Bool = false
        var k: Int = 0
        while k < 3 {
            let beta: Double = phi - 2 * deg
            let sp: Double = k == 2 ? 2900 : 900
            s.testPlace(x: 650, altitude: 1, vx: sp * cos(beta), vy: sp * sin(beta))
            var i: Int = 0
            while i < 240 && !s.snapshot.skimming {
                for e in s.step(dt: 1.0 / 240.0, tuck: 0) where e == .tailwindStarted { started = true }
                i += 1
            }
            k += 1
        }
        #expect(started)
        #expect(s.snapshot.speed > Tuning.maxSpeed * 1.05)
        // End the Tailwind on cue (a Perfect during it would refill it).
        s.testSetTailwind(0.02)
        // Fly on (tucked: heavy, fast) through the end of the Tailwind; no single frame may lose more than 1 %
        // of the speed, except at a touchdown.
        var last: Double = s.snapshot.speed
        var worst: Double = 0
        var sawEnd: Bool = false
        var after: Double = 0
        var i: Int = 0
        while i < 240 * 5 && after < 0.8 {
            let ev: [FlightEvent] = s.step(dt: 1.0 / 240.0, tuck: 1)
            var touched: Bool = false
            for e in ev {
                if e == .tailwindEnded { sawEnd = true }
                if case .touchdown = e { touched = true }
                if case .tailwindStarted = e { sawEnd = false }
            }
            let sp: Double = s.snapshot.speed
            if !touched && last > 0 { worst = max(worst, (last - sp) / last) }
            last = sp
            if sawEnd { after += 1.0 / 240.0 }
            i += 1
        }
        #expect(sawEnd)
        #expect(worst < 0.01, "worst one-frame speed loss \(worst)")
    }

    @Test func pilotPlanningIsBounded() {
        // The planner's work per plan is capped (QA-1 P2-14), whatever the state.
        let sea = SeaProfile(seed: 3)
        let start = CorePilotState(x: 5000, y: sea.height(at: 5000) + 900, vx: 2400, vy: 600, u: 0)
        let d: Double = FlightPilot.plan(from: start, sea: sea, gScale: 1, lag: 0.03)
        #expect(d >= 0)
        #expect(FlightPilot.planBudget <= 4000)
    }

    // MARK: Round 3

    @Test func countdownTickSchedules() {
        let full = FlightSession.countdownTicks(duration: 3.0)
        #expect(full.map { (e: (tick: Int, at: Double)) -> Int in e.tick } == [3, 2, 1])
        #expect(full.map { (e: (tick: Int, at: Double)) -> Double in e.at } == [0, 1, 2])
        let restart = FlightSession.countdownTicks(duration: Tuning.restartCountdownDuration)
        #expect(restart.map { (e: (tick: Int, at: Double)) -> Int in e.tick } == [2, 1])
        #expect(restart.map { (e: (tick: Int, at: Double)) -> Double in e.at } == [0, 0.75])
        #expect(FlightSession.countdownTicks(duration: 0).isEmpty)
    }

    /// Times (s since the session began) of the countdown events, at 120 Hz.
    private func countdownTimes(_ s: FlightSession) -> [(event: FlightEvent, at: Double)] {
        var out: [(event: FlightEvent, at: Double)] = []
        var i: Int = 0
        var started: Bool = false
        while i < 120 * 5 && !started {
            let before: Double = s.snapshot.time
            for e in s.step(dt: 1.0 / 120.0, tuck: 0) {
                switch e {
                case .countdownTick, .started:
                    out.append((event: e, at: before))
                    if e == .started { started = true }
                default:
                    break
                }
            }
            i += 1
        }
        return out
    }

    @Test func restartCountdownBeatsMatchReadyGo() {
        // UX-C1 + the Feel/App beat clash (NEEDS.md): Ready at 0, Go at 0.75 s, the drop at 1.5 s.
        let s = FlightSession(mode: .flight, seed: 5, bestMeters: 0, bird: .gull,
                              countdown: Tuning.restartCountdownDuration)
        #expect(s.countdownDuration == 1.5)
        if case .countdown(let remaining) = s.snapshot.phase {
            #expect(remaining == 1.5)
        } else {
            Issue.record("expected the countdown")
        }
        let ev = countdownTimes(s)
        #expect(ev.map { (e: (event: FlightEvent, at: Double)) -> FlightEvent in e.event }
                == [FlightEvent.countdownTick(2), FlightEvent.countdownTick(1), FlightEvent.started])
        if ev.count == 3 {
            #expect(ev[0].at < 0.01)
            #expect(abs(ev[1].at - 0.75) < 0.01)
            #expect(abs(ev[2].at - 1.5) < 0.01)
        }
        // The default stays the 3 s, 3-2-1 countdown on whole seconds.
        let d = FlightSession(mode: .flight, seed: 5, bestMeters: 0, bird: .gull)
        let full = countdownTimes(d)
        #expect(full.count == 4)
        if full.count == 4 {
            #expect(abs(full[1].at - 1.0) < 0.01)
            #expect(abs(full[2].at - 2.0) < 0.01)
            #expect(abs(full[3].at - 3.0) < 0.01)
        }
        // A zero countdown drops at once.
        let z = FlightSession(mode: .flight, seed: 5, bestMeters: 0, bird: .gull, countdown: 0)
        #expect(z.step(dt: 1.0 / 120.0, tuck: 0) == [FlightEvent.started])
    }

    @Test func finishCaughtSkipsTheEnding() {
        func caughtSession() -> FlightSession {
            let s = FlightSession(mode: .flight, seed: 3, bestMeters: 0, bird: .gull)
            var i: Int = 0
            while i < 60 * 300 {
                _ = s.step(dt: 1.0 / 60.0, tuck: 0)
                if case .caught = s.snapshot.phase { break }
                i += 1
            }
            return s
        }
        let skipped = caughtSession()
        let played = caughtSession()
        #expect(skipped.finishCaught() == [FlightEvent.finished])
        #expect(skipped.isFinished)
        #expect(skipped.finishCaught().isEmpty)
        var i: Int = 0
        while i < 60 * 5 && !played.isFinished {
            _ = played.step(dt: 1.0 / 60.0, tuck: 0)
            i += 1
        }
        #expect(skipped.result != nil)
        #expect(skipped.result == played.result)
        // Not caught yet: nothing happens.
        let flying = flyingSession(seed: 2)
        #expect(flying.finishCaught().isEmpty)
        #expect(!flying.isFinished)
    }

    @Test func stormLeashKeepsTheStormNear() {
        // UX-C3: a strong pilot can't bank a 30 km lead any more; the storm stays a few screens behind.
        let s = flyingSession(seed: 1000)
        var pilot = FlightPilot(skill: .perfect, seed: 1)
        var maxGap: Double = 0
        var i: Int = 0
        while i < 120 * 180 && !s.isFinished {
            _ = s.step(dt: 1.0 / 120.0, tuck: pilot.tuck(for: s.snapshot, sea: s.sea))
            maxGap = max(maxGap, s.snapshot.gap)
            i += 1
        }
        #expect(maxGap > Tuning.stormLeashGap)
        #expect(maxGap < Tuning.stormLeashGap + 11000, "max gap \(maxGap)")
        #expect(Tuning.stormLeashSpeed(gap: Tuning.stormLeashGap - 1) == 0)
        #expect(abs(Tuning.stormLeashSpeed(gap: Tuning.stormLeashGap + 1000) - 1000 * Tuning.stormLeashRate) < 1e-9)
    }

    @Test func rankSevenDailyNeedsAFreshDaily() {
        // UX-C2: rank 7's "Fly a Daily Flight" isn't met by a Daily flown long ago; rank 2's is.
        let r7: Goal = GoalCatalog.goals(forRank: 7).first(where: { (g: Goal) -> Bool in g.kind == .dailyPlayed })
            ?? Goal(id: "", kind: .dailyPlayed, target: 1, text: "")
        let r2: Goal = GoalCatalog.goals(forRank: 2).first(where: { (g: Goal) -> Bool in g.kind == .dailyPlayed })
            ?? Goal(id: "", kind: .dailyPlayed, target: 1, text: "")
        #expect(r7.id == "r7-daily")
        #expect(r7.text == "Fly 1 more Daily Flight in total")
        #expect(GoalEvaluator.progress(r7, run: result(), lifetimeMeters: 0, dailyPlayed: true) == 0)
        #expect(GoalEvaluator.progress(r7, run: result(mode: .daily(day: 40, scored: true)), lifetimeMeters: 0,
                                       dailyPlayed: true) == 1)
        #expect(GoalEvaluator.progress(r2, run: result(), lifetimeMeters: 0, dailyPlayed: true) == 1)
    }

    @Test func ladderStretchAndStarFlocks() {
        let totals: [Double] = GoalCatalog.ladder.joined().filter { (g: Goal) -> Bool in g.kind == .totalMeters }
            .map { (g: Goal) -> Double in g.target }
        // Round 5: a lifetime-distance spine, one total per flock, always rising, up to 3,600 km at the top.
        #expect(totals.count == GoalCatalog.maxRank)
        var k: Int = 1
        while k < totals.count {
            #expect(totals[k] > totals[k - 1])
            k += 1
        }
        #expect(totals.last == 3_600_000)
        #expect(GoalCatalog.starGoals(n: -1).isEmpty)
        let top: [Goal] = GoalCatalog.goals(forRank: GoalCatalog.maxRank - 1)
        var ids: Set<String> = []
        var n: Int = 0
        while n < 12 {
            let star: [Goal] = GoalCatalog.starGoals(n: n)
            #expect(star.count == 3)
            #expect(Set(star.map { (g: Goal) -> String in g.kind.rawValue }).count == 3)
            for g in star {
                ids.insert(g.id)
                #expect(!g.text.isEmpty)
                if let same = top.first(where: { (t: Goal) -> Bool in t.kind == g.kind }) {
                    #expect(g.target >= same.target * 1.49, "\(g.id) is not 1.5 × the top")
                }
            }
            n += 1
        }
        #expect(ids.count == 36)
        #expect(GoalCatalog.starGoals(n: 3) == GoalCatalog.starGoals(n: 3))
    }

    // MARK: Round 4

    @Test func everyGoalStatesItsScope() {
        // REVIEW-3 P0-1: "Pass 4 lighthouses ✓" next to "2 lighthouses" read as a contradiction. Every goal says
        // "in one flight" or "in total", and the text agrees with GoalCatalog.scope(of:).
        var all: [Goal] = Array(GoalCatalog.ladder.joined())
        var n: Int = 0
        while n < 7 {
            all.append(contentsOf: GoalCatalog.starGoals(n: n))
            n += 1
        }
        #expect(all.count == 42 + 21)
        for g in all {
            let oneFlight: Bool = g.text.contains("in one flight")
            let total: Bool = g.text.contains("in total")
            #expect(oneFlight != total, "\(g.id): \(g.text)")
            switch GoalCatalog.scope(of: g) {
            case .oneFlight: #expect(oneFlight, "\(g.id): \(g.text)")
            case .total: #expect(total, "\(g.id): \(g.text)")
            }
        }
        let lh: Goal? = GoalCatalog.goals(forRank: 5).first(where: { (g: Goal) -> Bool in g.kind == .lighthouses })
        #expect(lh?.text == "Pass 3 lighthouses in one flight")
    }

    /// Fly a skimming bird down the tutorial downslope for 1.2 s; the tuck input rises from 0 at 0.05 s by `tuckAt`.
    private func squeezeRun(_ tuckAt: (Double) -> Double) -> ([FlightEvent], FlightSnapshot, Double) {
        let s = flyingSession(seed: 21)
        s.testPlace(x: 300, altitude: 0, vx: 700, vy: 0)
        var events: [FlightEvent] = []
        var t: Double = 0
        var tuckAt100ms: Double = -1
        var i: Int = 0
        while i < 144 {
            events.append(contentsOf: s.step(dt: 1.0 / 120.0, tuck: tuckAt(t)))
            t += 1.0 / 120.0
            if tuckAt100ms < 0 && t >= 0.15 - 1e-9 { tuckAt100ms = s.snapshot.tuck }
            i += 1
        }
        return (events, s.snapshot, tuckAt100ms)
    }

    @Test func slammingTheHingeGainsNothing() {
        // REVIEW-3 Duo: very fast squeezes must gain nothing. The rise limit (Tuning.tuckMaxRise) makes any squeeze
        // faster than a full tuck in 1 / tuckMaxRise s produce exactly the same flight.
        let slam = squeezeRun({ (t: Double) -> Double in t < 0.05 ? 0 : 1 })
        let quick = squeezeRun({ (t: Double) -> Double in t < 0.05 ? 0 : min(1, (t - 0.05) / 0.05 + 0.1) })
        #expect(slam.0 == quick.0)
        #expect(slam.1 == quick.1)
        // 0.1 s after the slam the eased tuck is still well short of full (a full tuck takes ≥ 0.15 s, then eases).
        #expect(slam.2 < 0.7, "tuck 0.1 s after a slam: \(slam.2)")
        // A slower, deliberate squeeze (0.4 s) is a different flight, and not a faster one.
        let slow = squeezeRun({ (t: Double) -> Double in t < 0.05 ? 0 : min(1, (t - 0.05) / 0.4) })
        #expect(slow.1 != slam.1)
        #expect(Tuning.tuckMaxRise <= 1.0 / 0.15 + 1e-9)
    }

    @Test func dailyDisplayNumberCountsFromLaunch() {
        #expect(DailySeed.launchDay == 300)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = 28
        comps.hour = 0
        comps.minute = 30
        if let d = DailySeed.utc.date(from: comps) {
            #expect(DailySeed.dayNumber(for: d) == DailySeed.launchDay)
            #expect(DailySeed.displayNumber(day: DailySeed.dayNumber(for: d)) == 1)
        } else {
            Issue.record("no date")
        }
        #expect(DailySeed.displayNumber(day: 300) == 1)
        #expect(DailySeed.displayNumber(day: 309) == 10)
        #expect(DailySeed.displayNumber(day: 298) == 1)
        #expect(DailySeed.displayNumber(day: -5) == 1)
        // The seed is unchanged: it still uses the raw day.
        var rng = SeededRandom(seed: 0xDA11_F1E5_5EED_0000 ^ UInt64(bitPattern: Int64(336)))
        #expect(DailySeed.seed(day: 336) == rng.next())
    }

    // MARK: Round 5 (P1-9: goals the bests already meet complete at once)

    @Test func alreadyMetGoalsCompleteFromBests() {
        // A 12 km flight with 20 Perfects, a chain of 8 and 2 lighthouses; 12 km flown in all.
        let bests = PlayerBests(meters: 12_000, perfectsInRun: 20, chain: 8, lighthousesInRun: 2, tailwindsInRun: 2,
                                cleanMeters: 6_000, lifetimeMeters: 12_000)
        let r1: [Goal] = GoalCatalog.goals(forRank: 1)
        let met: [String] = GoalEvaluator.alreadyMet(goals: r1, bests: bests).map { (g: Goal) -> String in g.id }
        #expect(met == ["r1-reach", "r1-perfects"])          // "Fly 3 km" isn't handed out after 12 km…
        #expect(!met.contains("r1-total"))                   // …but 15 km in total still needs flying.
        #expect(GoalEvaluator.alreadyMet(goals: r1, bests: PlayerBests()).isEmpty)
        // Daily goals: rank 2 accepts any Daily played; the "1 more Daily" goals never come from bests.
        var daily = PlayerBests()
        daily.dailyPlayed = true
        let r2daily = GoalCatalog.goals(forRank: 2).filter { (g: Goal) -> Bool in g.kind == .dailyPlayed }
        #expect(GoalEvaluator.alreadyMet(goals: r2daily, bests: daily).count == 1)
        for id in GoalCatalog.dailyRunGoalIDs {
            let g = GoalCatalog.ladder.joined().first(where: { (x: Goal) -> Bool in x.id == id })
            #expect(g != nil, "\(id)")
            if let g = g { #expect(!GoalEvaluator.isMet(g, bests: daily)) }
        }
    }

    @Test func alreadyMetAgreesWithProgress() {
        // For every goal, meeting it from bests is the same as a flight with those stats reaching progress 1
        // (except the "1 more Daily" goals, which need a Daily flown now).
        let bests = PlayerBests(meters: 21_000, perfectsInRun: 26, chain: 13, lighthousesInRun: 3, tailwindsInRun: 7,
                                cloudTouchesInRun: 1, cleanMeters: 8_500, maxSpeed: 2_500, lifetimeMeters: 450_000,
                                dailyPlayed: true)
        let run = RunResult(mode: .flight, seed: 1, meters: bests.meters, score: 0, seconds: 100,
                            perfects: bests.perfectsInRun, goods: 0, splashes: 0, bestChain: bests.chain,
                            tailwinds: bests.tailwindsInRun, lighthouses: bests.lighthousesInRun, lastLighthouseName: "",
                            cloudTouches: bests.cloudTouchesInRun, maxSpeed: bests.maxSpeed, maxAltitude: 0,
                            longestCleanMeters: bests.cleanMeters, birdID: .gull)
        var metCount: Int = 0
        for g in GoalCatalog.ladder.joined() {
            let byRun: Bool = GoalEvaluator.progress(g, run: run, lifetimeMeters: bests.lifetimeMeters,
                                                     dailyPlayed: true) >= 1
            #expect(GoalEvaluator.isMet(g, bests: bests) == byRun, "\(g.id)")
            if byRun { metCount += 1 }
        }
        #expect(metCount > 10)
    }

    @Test func playerBestsMergeRuns() {
        let a = RunResult(mode: .flight, seed: 1, meters: 9_000, score: 0, seconds: 90, perfects: 12, goods: 0,
                          splashes: 2, bestChain: 5, tailwinds: 1, lighthouses: 1, lastLighthouseName: "",
                          cloudTouches: 0, maxSpeed: 2_000, maxAltitude: 0, longestCleanMeters: 4_000, birdID: .gull)
        let b = RunResult(mode: .daily(day: 330, scored: true), seed: 2, meters: 7_000, score: 0, seconds: 70,
                          perfects: 15, goods: 0, splashes: 1, bestChain: 3, tailwinds: 2, lighthouses: 1,
                          lastLighthouseName: "", cloudTouches: 1, maxSpeed: 1_900, maxAltitude: 0,
                          longestCleanMeters: 5_000, birdID: .gull)
        let m = PlayerBests().merged(with: a).merged(with: b)
        #expect(m.meters == 9_000)
        #expect(m.perfectsInRun == 15)
        #expect(m.chain == 5)
        #expect(m.tailwindsInRun == 2)
        #expect(m.cloudTouchesInRun == 1)
        #expect(m.cleanMeters == 5_000)
        #expect(m.maxSpeed == 2_000)
        #expect(m.lifetimeMeters == 16_000)
        #expect(m.dailyPlayed)
        #expect(!PlayerBests().merged(with: a).dailyPlayed)
    }

    @Test func strongBestsCascadeButFreshDailiesAndTotalsHoldTheLadder() {
        // A player with huge single-flight bests but little flown in total climbs only as far as the distance spine
        // lets them; with the distance too, they stop at rank 7, which needs a Daily flown at that rank.
        var star = PlayerBests(meters: 200_000, perfectsInRun: 500, chain: 200, lighthousesInRun: 30,
                               tailwindsInRun: 100, cloudTouchesInRun: 50, cleanMeters: 100_000, maxSpeed: 3_000,
                               lifetimeMeters: 20_000, dailyPlayed: true)
        #expect(GoalEvaluator.cascadedRank(from: 0, bests: star) == 2)   // 40 km in total for rank 3
        star.lifetimeMeters = 10_000_000
        #expect(GoalEvaluator.cascadedRank(from: 0, bests: star) == 7)
        #expect(GoalEvaluator.cascadedRank(from: 8, bests: star) == 10)
        #expect(GoalEvaluator.cascadedRank(from: 11, bests: star) == 13)
        #expect(GoalEvaluator.cascadedRank(from: GoalCatalog.maxRank, bests: star) == GoalCatalog.maxRank)
        #expect(GoalEvaluator.cascadedRank(from: 0, bests: PlayerBests()) == 0)
        // The spine is the only lifetime goal per flock, and every flock has exactly one.
        var rank: Int = 0
        while rank < GoalCatalog.maxRank {
            let n = GoalCatalog.goals(forRank: rank).filter { (g: Goal) -> Bool in g.kind == .totalMeters }.count
            #expect(n == 1, "rank \(rank)")
            rank += 1
        }
    }

    // MARK: Round 6 (Flight School practice sea, fixed lighthouse names)

    @Test func lighthouseNamesAreFixedPlaces() {
        #expect(Lighthouses.name(index: 0) == "Gull Point")
        #expect(Lighthouses.name(index: 1) == "Saltlight")
        #expect(Lighthouses.name(index: 2) == "Kestrel Head")
        #expect(Lighthouses.name(index: 3) == "Old Harry")
        #expect(Lighthouses.name(index: 40) == "Gull Point")
        #expect(Lighthouses.name(index: -1) == Lighthouses.name(index: 39))
        // Every mode: a Daily's first lighthouse is Gull Point too.
        let daily = FlightSession(mode: .daily(day: 400, scored: true), seed: 1, bestMeters: 0, bird: .gull)
        #expect(daily.snapshot.nextLighthouseName == "Gull Point")
        // Route helpers.
        #expect(Lighthouses.count(atOrBefore: 39_999) == 0)
        #expect(Lighthouses.count(atOrBefore: 40_000) == 1)
        #expect(Lighthouses.count(atOrBefore: 90_000) == 2)
        #expect(Lighthouses.count(atOrBeforeMeters: 16_200) == 3)
        #expect(Lighthouses.count(atOrBeforeMeters: 0) == 0)
        #expect(Lighthouses.nextIndex(afterMeters: 9_500) == 2)
        #expect(Lighthouses.meters(index: 1) == 9_000)
        var k: Int = 0
        while k < 30 {
            #expect(Lighthouses.count(atOrBefore: Lighthouses.x(index: k)) == k + 1)
            #expect(Lighthouses.count(atOrBefore: Lighthouses.x(index: k) - 1) == k)
            k += 1
        }
    }

    /// Fly a practice session: `tuckAt(x)` gives the input from the bird's x. Returns every signal, every event and
    /// the session.
    private func practiceRun(seconds: Double, _ tuckAt: (Double) -> Double) -> ([PracticeSignal], [FlightEvent], FlightSession) {
        let s = FlightSession.practice(bird: .gull)
        var signals: [PracticeSignal] = []
        var events: [FlightEvent] = []
        var i: Int = 0
        while Double(i) / 120.0 < seconds {
            events.append(contentsOf: s.step(dt: 1.0 / 120.0, tuck: tuckAt(Double(s.snapshot.position.x))))
            signals.append(contentsOf: s.practiceSignals)
            i += 1
        }
        return (signals, events, s)
    }

    @Test func practiceSessionIsCalmAndRecordsNothing() {
        let s = FlightSession.practice(bird: .tern)
        #expect(s.isPractice)
        #expect(s.sea.isPractice)
        #expect(abs(s.timeScale - Tuning.practiceTimeScale) < 1e-12)
        if case .attract = s.mode {} else { Issue.record("practice must report .attract so nothing records it") }
        // 0.8× time: 1 s of frames is 0.8 s of session time.
        var i: Int = 0
        while i < 60 {
            _ = s.step(dt: 1.0 / 60.0, tuck: 0)
            i += 1
        }
        #expect(abs(s.snapshot.time - 0.8) < 1e-6)
        // It waits on crest A until the tuck comes in.
        #expect(abs(Double(s.snapshot.position.x) - (Tuning.practiceCrestAX + 1)) < 1e-9)
        #expect(s.snapshot.speed == 0)
        // No storm: far away, and it never catches, even for minutes.
        #expect(s.snapshot.gap > Tuning.practiceNoStormGap - 1)
        let normal = FlightSession(mode: .flight, seed: 1, bestMeters: 0, bird: .gull)
        #expect(!normal.isPractice)
        #expect(normal.timeScale == 1)
        _ = normal.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(normal.practiceSignals.isEmpty)
        // The practice sea is smooth and gentle everywhere.
        var x: Double = -2000
        while x < 40_000 {
            #expect(abs(s.sea.slope(at: x)) <= 0.75)
            x += 7
        }
    }

    @Test func practiceScriptGivesTheStepSignals() {
        // Fold on crest A and hold it to the trough, then open: dive held, a clean launch, a Perfect on the guided
        // downslope, then the 3 rhythm waves; no lighthouse, milestone or best events, and it never finishes.
        let (signals, events, s) = practiceRun(seconds: 14) { (x: Double) -> Double in x < Tuning.practiceTroughX ? 1 : 0 }
        var dive: Double = -1
        var launchTuck: Double = -1
        var firstLanding: TouchdownQuality? = nil
        var waves: [Int] = []
        for sig in signals {
            switch sig {
            case .diveDone(let f): if dive < 0 { dive = f }
            case .launched(let u): if launchTuck < 0 { launchTuck = u }
            case .landed(let q): if firstLanding == nil { firstLanding = q }
            case .waveDone(let i): waves.append(i)
            }
        }
        #expect(dive >= 0.7, "held fraction \(dive)")
        #expect(launchTuck >= 0 && launchTuck <= 0.3, "tuck at launch \(launchTuck)")
        #expect(firstLanding == .perfect)
        #expect(waves == [0, 1, 2])
        for e in events {
            switch e {
            case .lighthouse, .milestone, .newBest, .stormClose, .caught, .finished:
                Issue.record("unexpected \(e) in practice")
            default:
                break
            }
        }
        #expect(!s.isFinished)
        #expect(s.result == nil)
    }

    @Test func practiceDiveOpenedEarlyIsNotHeld() {
        let (signals, _, _) = practiceRun(seconds: 4) { (x: Double) -> Double in x < 600 ? 1 : 0 }
        var dive: Double = -1
        for sig in signals {
            if case .diveDone(let f) = sig, dive < 0 { dive = f }
        }
        #expect(dive >= 0 && dive < 0.7, "held fraction \(dive)")
    }

    @Test func practiceRewindsAndRetries() {
        let s = FlightSession.practice(bird: .gull)
        _ = s.step(dt: 1.0 / 60.0, tuck: 0)
        s.rewind(to: .trough)
        #expect(abs(Double(s.snapshot.position.x) - Tuning.practiceTroughX) < 1e-9)
        #expect(s.snapshot.skimming)
        #expect(abs(s.snapshot.speed - Tuning.practiceTroughSpeed) < 1e-6)
        s.rewind(to: .rhythm)
        #expect(abs(Double(s.snapshot.position.x) - Tuning.practiceGuidedTroughX) < 1e-9)
        // A miss on the guided swell: try again from the air just past crest B, wings open → a Perfect.
        s.nextGuidedSwell()
        #expect(!s.snapshot.skimming)
        #expect(abs(Double(s.snapshot.position.x) - Tuning.practiceLaunchX) < 1e-9)
        var landed: TouchdownQuality? = nil
        var i: Int = 0
        while i < 120 * 4 && landed == nil {
            _ = s.step(dt: 1.0 / 120.0, tuck: 0)
            for sig in s.practiceSignals {
                if case .landed(let q) = sig { landed = q }
            }
            i += 1
        }
        #expect(landed == .perfect)
        // Back to crest A: it waits again until the tuck comes in.
        s.rewind(to: .crestA)
        _ = s.step(dt: 1.0 / 60.0, tuck: 0.3)
        #expect(s.snapshot.speed == 0)
        s.holdAtCrest(untilTuck: 0)
        _ = s.step(dt: 1.0 / 60.0, tuck: 0)
        _ = s.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(s.snapshot.speed > 0)
        // Step 7: the storm can be shown at a gap; it still never catches.
        s.practiceStormGap = 3000
        _ = s.step(dt: 1.0 / 60.0, tuck: 0)
        #expect(abs(s.snapshot.gap - 3000) < 1e-6)
        // Rewind and the other practice calls do nothing in a normal run.
        let normal = flyingSession(seed: 3)
        let x0: CGFloat = normal.snapshot.position.x
        normal.rewind(to: .trough)
        normal.nextGuidedSwell()
        #expect(normal.snapshot.position.x == x0)
    }

    // MARK: Round 9 (the guide gull's ghost paths, results-headline inputs)

    private func ghostSignals(_ path: [GhostSample]) -> [PracticeSignal] {
        var out: [PracticeSignal] = []
        for g in path { out.append(contentsOf: g.signals) }
        return out
    }

    @Test func ghostPathsAreDeterministicAndSmooth() {
        for step in PracticeGhostStep.allCases {
            let a: [GhostSample] = FlightSession.practiceGhostPath(step: step)
            let b: [GhostSample] = PracticeGhost.path(step: step)
            #expect(a == b, "\(step)")
            #expect(a.count > 30, "\(step)")
            let d: Double = PracticeGhost.duration(a)
            #expect(d > 0.8 && d < PracticeGhost.maxSeconds, "\(step) lasts \(d) s")
            var i: Int = 1
            while i < a.count {
                #expect(abs(a[i].t - a[i - 1].t - PracticeGhost.sampleDt) < 1e-9)
                #expect(a[i].x >= a[i - 1].x - 1e-9, "\(step) goes backwards at \(i)")
                #expect(a[i].x - a[i - 1].x < 3200 * PracticeGhost.sampleDt, "\(step) jumps at \(i)")
                #expect(a[i].tuck >= 0 && a[i].tuck <= 1)
                i += 1
            }
        }
    }

    @Test func ghostDiveIsTheIdealDive() {
        let path: [GhostSample] = PracticeGhost.path(step: .dive)
        #expect(abs((path.first?.x ?? -1) - (Tuning.practiceCrestAX + 1)) < 1e-9)
        #expect((path.last?.x ?? 0) >= Tuning.practiceTroughX)
        var held: Double = -1
        for sig in ghostSignals(path) {
            if case .diveDone(let f) = sig, held < 0 { held = f }
        }
        #expect(held >= 0.9, "held \(held)")
        // The fold-path fill: folded all the way down once the tuck is in.
        let downhill = path.filter { (g: GhostSample) -> Bool in g.x > 200 && g.x < Tuning.practiceTroughX - 50 }
        #expect(!downhill.isEmpty)
        #expect(downhill.allSatisfy { (g: GhostSample) -> Bool in g.folded && g.skimming })
    }

    @Test func ghostSoarsAndLandsPerfect() {
        for step in [PracticeGhostStep.soarAndLand, PracticeGhostStep.guidedLanding] {
            let sigs: [PracticeSignal] = ghostSignals(PracticeGhost.path(step: step))
            var landed: TouchdownQuality? = nil
            var launchTuck: Double = -1
            for sig in sigs {
                switch sig {
                case .launched(let u): if launchTuck < 0 { launchTuck = u }
                case .landed(let q): if landed == nil { landed = q }
                default: break
                }
            }
            #expect(landed == .perfect, "\(step)")
            if step == .soarAndLand {
                #expect(launchTuck >= 0 && launchTuck <= 0.3)
            }
        }
    }

    @Test func ghostRhythmRidesEachWave() {
        let path: [GhostSample] = PracticeGhost.path(step: .rhythm)
        var waves: [Int] = []
        var perfects: Int = 0
        var launches: Int = 0
        for sig in ghostSignals(path) {
            switch sig {
            case .waveDone(let i): waves.append(i)
            case .landed(let q): if q == .perfect { perfects += 1 }
            case .launched: launches += 1
            default: break
            }
        }
        #expect(waves == [0, 1, 2])
        #expect(launches >= 3)
        #expect(perfects >= 2)
        // Folded and open both appear: one fold down, one open up per wave.
        #expect(path.contains(where: { (g: GhostSample) -> Bool in g.folded }))
        #expect(path.contains(where: { (g: GhostSample) -> Bool in !g.folded && !g.skimming }))
    }

    @Test func ghostSampleInterpolates() {
        let path: [GhostSample] = PracticeGhost.path(step: .soarAndLand)
        #expect(PracticeGhost.sample([], at: 0) == nil)
        #expect(PracticeGhost.sample(path, at: -1) == path.first)
        #expect(PracticeGhost.sample(path, at: 99) == path.last)
        if path.count > 10 {
            let a = path[5], b = path[6]
            let mid = PracticeGhost.sample(path, at: (a.t + b.t) / 2)
            #expect(mid != nil)
            if let m = mid {
                #expect(abs(m.x - (a.x + b.x) / 2) < 1e-9)
                #expect(abs(m.y - (a.y + b.y) / 2) < 1e-9)
            }
        }
    }

    @Test func practiceIsUnchangedByGhosts() {
        // Building ghosts runs their own headless sessions; a live practice session is untouched.
        let live = FlightSession.practice(bird: .gull)
        _ = live.step(dt: 1.0 / 60.0, tuck: 0)
        let before = live.snapshot
        _ = PracticeGhost.path(step: .rhythm)
        #expect(live.snapshot == before)
        #expect(abs(live.timeScale - Tuning.practiceTimeScale) < 1e-12)
    }

    @Test func nextLighthouseFurther() {
        let a = Lighthouses.next(afterMeters: 2_100)
        #expect(a.index == 0 && a.name == "Gull Point" && a.metersFurther == 1_900)
        let b = Lighthouses.next(afterMeters: 12_800)
        #expect(b.index == 2 && b.name == "Kestrel Head" && b.metersFurther == 2_200)
        let c = Lighthouses.next(afterMeters: 3_650)
        #expect(c.metersFurther == 350)
        let d = Lighthouses.next(afterMeters: 9_000)
        #expect(d.name == "Kestrel Head" && d.metersFurther == 6_000)
        #expect(Lighthouses.roundedFurther(meters: 1_234) == 1_300)
        #expect(Lighthouses.roundedFurther(meters: 341) == 350)
        #expect(Lighthouses.roundedFurther(meters: 5) == 10)
        #expect(Lighthouses.roundedFurther(meters: 0) == 10)
        #expect(Lighthouses.next(afterMeters: -5).index == 0)
    }
}
