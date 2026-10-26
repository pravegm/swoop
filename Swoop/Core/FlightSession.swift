import CoreGraphics
import Foundation

// MARK: - One run (GAME-DESIGN §5–§6)
//
// Deterministic: the same mode, seed, best and tuck inputs give the same events and snapshots, bit for bit.
// `step(dt:tuck:)` splits the frame into sub-steps ≤ `Tuning.maxSubstep` and returns every event in the order it
// happened. The bird is either skimming (glued to the surface, moving along its tangent) or airborne (ballistic with
// tuck gravity, spread-wing lift while descending, and drag). See `Tuning` for every number.

public final class FlightSession {
    public let sea: SeaProfile
    public let seed: UInt64
    public let mode: RunMode
    public let bestMeters: Double
    public let bird: BirdID

    // Phase and clocks
    private var phase: FlightPhase = .countdown(remaining: Tuning.countdownDuration)
    private var countdownLeft: Double = Tuning.countdownDuration
    /// The countdown this session was built with (s) and its tick schedule (UX-C1).
    public let countdownDuration: Double
    private let tickSchedule: [(tick: Int, at: Double)]
    private var nextTickIndex: Int = 0
    private var time: Double = 0
    private var flightTime: Double = 0
    private var caughtElapsed: Double = 0

    // The bird
    private var x: Double
    private var y: Double
    private var vx: Double = 0
    private var vy: Double = 0
    private var skimming: Bool = false
    private var skimSpeed: Double = 0
    private var skimTime: Double = 0
    private var airTime: Double = 0
    private var tuckEased: Double = 0
    private var bodyAngle: Double = 0

    // The storm
    private var stormX: Double
    private var stormCloseArmed: Bool = true

    // Scoring
    private var chain: Int = 0
    private var bestChain: Int = 0
    private var perfects: Int = 0
    private var goods: Int = 0
    private var splashes: Int = 0
    private var tailwinds: Int = 0
    private var tailwindLeft: Double = 0
    /// Seconds left of the post-Tailwind ease-out (Tuning.tailwindFade).
    private var tailwindFadeLeft: Double = 0
    private var lighthouseCount: Int = 0
    private var nextLighthouseX: Double
    private var nextLighthouseName: String
    private var lastLighthouseName: String = ""
    private var cloudArmed: Bool = true
    private var cloudTouches: Int = 0
    private var nextMilestoneKm: Int = 1
    private var newBestFired: Bool = false
    private var maxSpeedSeen: Double = 0
    private var maxAltitudeSeen: Double = 0
    private var lastSplashX: Double
    private var longestCleanPt: Double = 0

    // End of run
    private var endX: Double? = nil
    private var endSeconds: Double = 0
    private var runResult: RunResult? = nil

    /// `countdown`: 3.0 for the first run of a launch (it calibrates the hinge), `Tuning.restartCountdownDuration`
    /// (1.5) for "Fly again" (UX-C1). Any value 0…10 works; 0 starts on the first step with no ticks.
    public init(mode: RunMode, seed: UInt64, bestMeters: Double, bird: BirdID,
                countdown: Double = Tuning.countdownDuration) {
        let cd: Double = countdown.isFinite ? min(max(countdown, 0), 10) : Tuning.countdownDuration
        self.countdownDuration = cd
        self.tickSchedule = FlightSession.countdownTicks(duration: cd)
        self.countdownLeft = cd
        self.phase = .countdown(remaining: cd)
        var s: UInt64 = seed
        if case .daily(let day, _) = mode {
            s = DailySeed.seed(day: day)
        }
        self.seed = s
        self.mode = mode
        self.bestMeters = max(0, bestMeters.isFinite ? bestMeters : 0)
        self.bird = bird
        let profile = SeaProfile(seed: s)
        self.sea = profile
        self.x = Tuning.startX
        self.y = profile.height(at: Tuning.startX) + Tuning.startHeight
        var storm: Double = Tuning.startX - Tuning.gapStart
        if case .attract = mode {
            storm = Tuning.startX - Tuning.attractStormLag
        }
        self.stormX = storm
        self.nextLighthouseX = Lighthouses.x(index: 0)
        self.nextLighthouseName = Lighthouses.name(index: 0, seed: s)
        self.lastSplashX = Tuning.startX
    }

    // MARK: Public state

    public var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    /// Non-nil once finished.
    public var result: RunResult? {
        return runResult
    }

    /// Attract/CI: start flying immediately (the next step fires `started`, no ticks).
    public func skipCountdown() {
        if case .countdown = phase {
            countdownLeft = 0
            nextTickIndex = tickSchedule.count
            phase = .countdown(remaining: 0)
        }
    }

    /// When the countdown ticks fire, in seconds after the session starts (UX-C1; the App and Feel align their beats
    /// with these). A countdown of 2.5 s or more ticks n…1 on the whole seconds before the drop: 3.0 → 3 at 0 s,
    /// 2 at 1 s, 1 at 2 s, `started` at 3 s. A shorter one (the 1.5 s restart) has two beats, matching UX-SPEC's
    /// "Ready · Go": `countdownTick(2)` = Ready at 0 s and `countdownTick(1)` = Go at duration / 2 (0.75 s), then
    /// `started` at the duration.
    public static func countdownTicks(duration: Double) -> [(tick: Int, at: Double)] {
        if !(duration > 0) { return [] }
        if duration < 2.5 {
            return [(tick: 2, at: 0), (tick: 1, at: duration / 2)]
        }
        let n: Int = Int((duration - 1e-9).rounded(.up))
        var out: [(tick: Int, at: Double)] = []
        var k: Int = n
        while k >= 1 {
            out.append((tick: k, at: max(0, duration - Double(k))))
            k -= 1
        }
        return out
    }

    /// The caught → finished jump for a skipped ending (UX A2): finishes the run now and returns `[.finished]`
    /// (empty unless the bird is in its `caught` phase). The result is the same as letting the 1.8 s play out.
    public func finishCaught() -> [FlightEvent] {
        guard case .caught = phase else { return [] }
        phase = .finished
        finishRun()
        return [.finished]
    }

    public var snapshot: FlightSnapshot {
        let speed: Double = (vx * vx + vy * vy).squareRoot()
        let gap: Double = x - stormX
        let lead: Double = min(max(gap / Tuning.fullLead, 0), 1)
        let alt: Double = max(0, y - sea.height(at: x))
        return FlightSnapshot(
            phase: phase, time: time,
            position: CGPoint(x: CGFloat(x), y: CGFloat(y)),
            velocity: CGVector(dx: CGFloat(vx), dy: CGFloat(vy)),
            speed: speed, bodyAngle: bodyAngle, tuck: tuckEased, skimming: skimming,
            altitude: skimming ? 0 : alt,
            distanceMeters: distanceMeters, score: score, chain: chain, bestChain: bestChain, perfects: perfects,
            tailwindRemaining: tailwindLeft, stormX: stormX, gap: gap, lead: lead,
            lighthousesPassed: lighthouseCount, nextLighthouseX: nextLighthouseX,
            nextLighthouseName: nextLighthouseName, bestMeters: bestMeters, mode: mode)
    }

    private var distanceMeters: Double {
        let xx: Double = endX ?? x
        return max(0, (xx - Tuning.startX) / Tuning.pointsPerMeter)
    }

    private var score: Int {
        let v: Double = distanceMeters + Tuning.perfectStyleMeters * Double(perfects)
            + Tuning.tailwindStyleMeters * Double(tailwinds)
        return Int(v.rounded(.down))
    }

    private var isAttract: Bool {
        if case .attract = mode { return true }
        return false
    }

    // MARK: Stepping

    /// tuck 0…1 from the input. Returns this step's events in order.
    public func step(dt: Double, tuck: Double) -> [FlightEvent] {
        var events: [FlightEvent] = []
        if isFinished { return events }
        let frame: Double = dt.isFinite ? min(max(dt, 0), Tuning.maxFrameDt) : 0
        let input: Double = tuck.isFinite ? min(max(tuck, 0), 1) : 0
        if frame <= 0 { return events }
        let n: Int = max(1, Int((frame / Tuning.maxSubstep - 1e-9).rounded(.up)))
        let h: Double = frame / Double(n)
        var i: Int = 0
        while i < n {
            substep(h, input, &events)
            if isFinished { break }
            i += 1
        }
        return events
    }

    private func substep(_ dt: Double, _ input: Double, _ events: inout [FlightEvent]) {
        time += dt
        // The session's own tuck easing (also during the countdown, so the hovering bird mirrors the hinge).
        let tau: Double = input > tuckEased ? Tuning.tuckAttack : Tuning.tuckRelease
        tuckEased += (input - tuckEased) * (1 - exp(-dt / tau))

        switch phase {
        case .countdown:
            if countdownLeft > 0 {
                let elapsed: Double = countdownDuration - countdownLeft
                while nextTickIndex < tickSchedule.count && tickSchedule[nextTickIndex].at <= elapsed + 1e-9 {
                    events.append(.countdownTick(tickSchedule[nextTickIndex].tick))
                    nextTickIndex += 1
                }
                countdownLeft -= dt
            }
            if countdownLeft <= 0 {
                countdownLeft = 0
                phase = .flying
                vx = Tuning.startSpeed
                vy = 0
                events.append(.started)
            } else {
                phase = .countdown(remaining: countdownLeft)
            }
            return
        case .caught:
            caughtElapsed += dt
            physics(dt, 0, calm: true, &events)
            if !isAttract {
                stormX += Tuning.stormSpeed(atFlightTime: flightTime) * dt
            }
            updateBodyAngle(dt)
            if caughtElapsed >= Tuning.caughtDuration {
                phase = .finished
                finishRun()
                events.append(.finished)
            } else {
                phase = .caught(elapsed: caughtElapsed)
            }
            return
        case .finished:
            return
        case .flying:
            break
        }

        flightTime += dt
        physics(dt, tuckEased, calm: false, &events)
        updateBodyAngle(dt)

        if tailwindFadeLeft > 0 {
            tailwindFadeLeft = max(0, tailwindFadeLeft - dt)
        }
        if tailwindLeft > 0 {
            tailwindLeft -= dt
            if tailwindLeft <= 0 {
                tailwindLeft = 0
                tailwindFadeLeft = Tuning.tailwindFade
                events.append(.tailwindEnded)
            }
        }

        // The storm.
        if isAttract {
            stormX = x - Tuning.attractStormLag
        } else {
            let gapNow: Double = x - stormX
            stormX += (Tuning.stormSpeed(atFlightTime: flightTime) + Tuning.stormLeashSpeed(gap: gapNow)) * dt
        }

        // Lighthouses.
        var guardCount: Int = 0
        while x >= nextLighthouseX && guardCount < 8 {
            let name: String = nextLighthouseName
            let idx: Int = lighthouseCount
            lighthouseCount += 1
            lastLighthouseName = name
            if !isAttract { stormX -= Tuning.lighthouseGapBonus }
            nextLighthouseX = Lighthouses.x(index: lighthouseCount)
            nextLighthouseName = Lighthouses.name(index: lighthouseCount, seed: seed)
            events.append(.lighthouse(index: idx, name: name))
            guardCount += 1
        }

        // Milestones and the personal best.
        let meters: Double = distanceMeters
        while meters >= Double(nextMilestoneKm) * 1000 {
            events.append(.milestone(km: nextMilestoneKm))
            nextMilestoneKm += 1
        }
        if !newBestFired && bestMeters > 0 && meters > bestMeters {
            newBestFired = true
            events.append(.newBest)
        }

        // Clouds: the deck's underside sits at Tuning.cloudHeight above the MEAN water (the Scene draws it there).
        let alt: Double = skimming ? 0 : max(0, y - sea.height(at: x))
        if cloudArmed && !skimming && y >= Tuning.cloudHeight {
            cloudArmed = false
            cloudTouches += 1
            events.append(.cloudTouched)
        } else if !cloudArmed && y < Tuning.cloudRearmHeight {
            cloudArmed = true
        }

        // Stats.
        maxSpeedSeen = max(maxSpeedSeen, (vx * vx + vy * vy).squareRoot())
        maxAltitudeSeen = max(maxAltitudeSeen, alt)

        // Storm close / caught.
        if !isAttract {
            let gap: Double = x - stormX
            let lead: Double = gap / Tuning.fullLead
            if stormCloseArmed && lead < Tuning.stormCloseLead && gap > 0 {
                stormCloseArmed = false
                events.append(.stormClose)
            } else if !stormCloseArmed && lead > Tuning.stormRearmLead {
                stormCloseArmed = true
            }
            if gap <= 0 {
                if tailwindLeft > 0 {
                    tailwindLeft = 0
                    events.append(.tailwindEnded)
                }
                endX = x
                endSeconds = flightTime
                caughtElapsed = 0
                phase = .caught(elapsed: 0)
                events.append(.caught)
            }
        }
    }

    private func updateBodyAngle(_ dt: Double) {
        let target: Double
        if skimming {
            target = atan(sea.slope(at: x))
        } else {
            target = atan2(vy, max(vx, 1e-6))
        }
        bodyAngle += (target - bodyAngle) * (1 - exp(-dt / Tuning.bodyAngleSmoothing))
    }

    // MARK: Physics

    private func physics(_ dt: Double, _ u: Double, calm: Bool, _ events: inout [FlightEvent]) {
        let tailwind: Bool = tailwindLeft > 0
        // 1 during a Tailwind, easing linearly to 0 over Tuning.tailwindFade after it (no speed jolt at the end).
        let tw: Double = tailwind ? 1 : min(max(tailwindFadeLeft / Tuning.tailwindFade, 0), 1)
        let vmax: Double = Tuning.maxSpeed * (1 + Tuning.tailwindSpeedBoost * tw)
        let minS: Double = calm ? 0 : Tuning.minSpeed

        if skimming {
            let p: Double = sea.slope(at: x)
            let phi: Double = atan(p)
            let g: Double = Tuning.skimGravity(u)
            var s: Double = skimSpeed
            s += -g * sin(phi) * dt
            let drag: Double = calm ? Tuning.caughtDrag : Tuning.airDrag * (1 - tw)
            s *= exp(-(drag + Tuning.waterFriction) * dt)
            if calm { s = max(s, Tuning.caughtDriftSpeed) }
            if s * cos(phi) < minS { s = minS / cos(phi) }
            s = min(s, vmax)
            x += s * cos(phi) * dt
            let p2: Double = sea.slope(at: x)
            let phi2: Double = atan(p2)
            y = sea.height(at: x)
            skimSpeed = s
            vx = s * cos(phi2)
            vy = s * sin(phi2)
            skimTime += dt
            if !calm && skimTime >= Tuning.launchGrace {
                let k: Double = sea.secondDerivative(at: x) / pow(1 + p2 * p2, 1.5)
                if k < 0 && -s * s * k > g * cos(phi2) * (1 + Tuning.launchMargin) {
                    skimming = false
                    y += Tuning.launchLift
                    airTime = 0
                    events.append(.launched(speed: s))
                }
            }
            return
        }

        // Airborne.
        let drag: Double = calm ? Tuning.caughtDrag * 0.3 : Tuning.airDrag * (1 - tw)
        let acc = Tuning.airAcceleration(u: u, vx: vx, vy: vy, drag: drag, lift: !calm)
        vx += acc.ax * dt
        vy += acc.ay * dt
        if vx < minS { vx = minS }
        if calm && vx < Tuning.caughtDriftSpeed { vx = Tuning.caughtDriftSpeed }
        let sp: Double = (vx * vx + vy * vy).squareRoot()
        if sp > vmax && sp > 0 {
            vx *= vmax / sp
            vy *= vmax / sp
        }
        let x0: Double = x
        let d0: Double = y - sea.height(at: x0)
        x += vx * dt
        y += vy * dt
        airTime += dt
        let d1: Double = y - sea.height(at: x)
        if d1 <= 0 {
            // Touch down where the path crossed the surface (never below it: no tunnelling).
            let fr: Double = d0 > 0 ? min(max(d0 / (d0 - d1), 0), 1) : 1
            x = x0 + (x - x0) * fr
            y = sea.height(at: x)
            touchdown(calm: calm, vmax: vmax, &events)
        }
    }

    /// Classify a touchdown (GAME-DESIGN §5) from the raw velocity and surface angles (radians), after the landing
    /// assist (Tuning.landingAssistDeg). Pure, for tests and the pilot.
    static func classify(velocityAngle beta: Double, surfaceAngle phi: Double) -> TouchdownQuality {
        let assisted: Double = Tuning.assistedAngle(velocityAngle: beta, surfaceAngle: phi)
        let alphaDeg: Double = abs(assisted - phi) * 180 / Double.pi
        let phiDeg: Double = phi * 180 / Double.pi
        if alphaDeg <= Tuning.perfectAngleDeg && phiDeg < Tuning.perfectSlopeDeg { return .perfect }
        if alphaDeg <= Tuning.goodAngleDeg { return .good }
        return .splash
    }

    private func touchdown(calm: Bool, vmax: Double, _ events: inout [FlightEvent]) {
        let phi: Double = atan(sea.slope(at: x))
        let beta: Double = atan2(vy, vx)
        // The landing assist turns the velocity toward the tangent (speed kept) before it is judged.
        let alpha: Double = abs(Tuning.assistedAngle(velocityAngle: beta, surfaceAngle: phi) - phi)
        let impact: Double = (vx * vx + vy * vy).squareRoot()
        let q: TouchdownQuality = FlightSession.classify(velocityAngle: beta, surfaceAngle: phi)
        let s: Double
        switch q {
        case .perfect: s = impact * (1 + Tuning.perfectBoost)
        case .good: s = impact * cos(alpha)
        case .splash: s = impact * cos(alpha) * Tuning.splashKeep
        }
        skimming = true
        skimTime = 0
        skimSpeed = min(max(s, calm ? 0 : Tuning.minSpeed), vmax)
        vx = skimSpeed * cos(phi)
        vy = skimSpeed * sin(phi)
        if calm { return }
        cloudArmed = true
        switch q {
        case .perfect:
            perfects += 1
            chain += 1
            bestChain = max(bestChain, chain)
            if !isAttract { stormX -= Tuning.perfectGapBonus }
            if tailwindLeft > 0 { tailwindLeft = Tuning.tailwindDuration }
            events.append(.touchdown(.perfect, speed: impact, chain: chain))
            if chain % Tuning.tailwindChain == 0 {
                if !isAttract { stormX -= Tuning.tailwindGapBonus }
                if tailwindLeft <= 0 {
                    tailwinds += 1
                    let boosted: Double = min(skimSpeed * (1 + Tuning.tailwindSpeedBoost),
                                              Tuning.maxSpeed * (1 + Tuning.tailwindSpeedBoost))
                    skimSpeed = boosted
                    vx = skimSpeed * cos(phi)
                    vy = skimSpeed * sin(phi)
                    events.append(.tailwindStarted)
                }
                tailwindLeft = Tuning.tailwindDuration
            }
        case .good:
            // Round 2 (REVIEW-1 P0-2): a Good holds the chain (it neither adds to it nor refills a Tailwind).
            goods += 1
            events.append(.touchdown(.good, speed: impact, chain: chain))
        case .splash:
            // Only a splash breaks the chain.
            chain = 0
            splashes += 1
            longestCleanPt = max(longestCleanPt, x - lastSplashX)
            lastSplashX = x
            events.append(.touchdown(.splash, speed: impact, chain: 0))
        }
    }

    // MARK: Test hooks (internal; used by SwoopTests only)

    /// Put the bird at `x`: skimming at speed |(vx, vy)| when `altitude` ≤ 0, else airborne `altitude` above the
    /// water with velocity (vx, vy). Ends the countdown (no `started` event).
    func testPlace(x newX: Double, altitude: Double, vx newVx: Double, vy newVy: Double) {
        if case .countdown = phase {
            countdownLeft = 0
            phase = .flying
        }
        x = newX
        let h: Double = sea.height(at: newX)
        if altitude <= 0 {
            let phi: Double = atan(sea.slope(at: newX))
            let s: Double = (newVx * newVx + newVy * newVy).squareRoot()
            skimming = true
            skimTime = 0
            skimSpeed = s
            vx = s * cos(phi)
            vy = s * sin(phi)
            y = h
        } else {
            skimming = false
            airTime = 0
            y = h + altitude
            vx = newVx
            vy = newVy
        }
    }

    /// Set the gap to the storm (pt).
    func testSetGap(_ gap: Double) {
        stormX = x - gap
    }

    /// Set the Tailwind's remaining time (s); only while one is running.
    func testSetTailwind(_ seconds: Double) {
        if tailwindLeft > 0 { tailwindLeft = max(seconds, 1e-6) }
    }

    // MARK: Result

    private func finishRun() {
        let xEnd: Double = endX ?? x
        let clean: Double = max(longestCleanPt, xEnd - lastSplashX)
        runResult = RunResult(
            mode: mode, seed: seed, meters: distanceMeters, score: score, seconds: endSeconds,
            perfects: perfects, goods: goods, splashes: splashes, bestChain: bestChain, tailwinds: tailwinds,
            lighthouses: lighthouseCount, lastLighthouseName: lastLighthouseName, cloudTouches: cloudTouches,
            maxSpeed: maxSpeedSeen, maxAltitude: maxAltitudeSeen,
            longestCleanMeters: max(0, clean / Tuning.pointsPerMeter), birdID: bird)
    }
}
