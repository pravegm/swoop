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
        var differs: Bool = false
        i = 0
        while i < 10 {
            if Lighthouses.name(index: i, seed: 1) != Lighthouses.name(index: i, seed: 2) { differs = true }
            i += 1
        }
        #expect(differs)
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
        _ = run(open, seconds: 0.3, dt: 1.0 / 120.0, tuck: 0)
        _ = run(tucked, seconds: 0.3, dt: 1.0 / 120.0, tuck: 1)
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
        let deg: Double = Double.pi / 180
        #expect(FlightSession.classify(velocityAngle: -30 * deg, surfaceAngle: -25 * deg) == .perfect)
        #expect(FlightSession.classify(velocityAngle: -38 * deg, surfaceAngle: -25 * deg) == .perfect)
        // Lined up but not downhill: only Good.
        #expect(FlightSession.classify(velocityAngle: -2 * deg, surfaceAngle: -2 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: 8 * deg, surfaceAngle: 5 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: -40 * deg, surfaceAngle: -15 * deg) == .good)
        #expect(FlightSession.classify(velocityAngle: -45 * deg, surfaceAngle: -10 * deg) == .splash)
        #expect(FlightSession.classify(velocityAngle: -40 * deg, surfaceAngle: 15 * deg) == .splash)
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
        let s = flyingSession(seed: 12)
        s.testPlace(x: 5000, altitude: 950, vx: 900, vy: 0)
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
        #expect(s.snapshot.gap > gapBefore + Tuning.lighthouseGapBonus - 200)
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
            #expect(b.unlockRank >= 0 && b.unlockRank < GoalCatalog.maxRank)
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
            #expect(s.unlockRank >= 0 && s.unlockRank < GoalCatalog.maxRank)
        }
    }

    @Test func goalLadderIsComplete() {
        #expect(GoalCatalog.maxRank == 15)
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
        #expect(ids.count == 45)
        #expect(GoalCatalog.goals(forRank: GoalCatalog.maxRank).isEmpty)
        #expect(GoalCatalog.goals(forRank: -1).isEmpty)
        #expect(GoalCatalog.rankTitle(0) == "Fledgling")
        #expect(GoalCatalog.rankTitle(GoalCatalog.maxRank) == "Storm Rider")
        #expect(GoalCatalog.goals(forRank: 0)[0].text == "Fly 500 m")
    }
}
