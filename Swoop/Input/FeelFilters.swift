import Foundation

// Smoothing building blocks for the hinge → tuck pipeline. Ported from Brim's `Input/TiltFilters.swift` (itself from
// Squish's real-Duo `HingeTracker` / `Filters`), unchanged in behaviour except where noted. Pure value types with
// explicit times, so every one of them is unit-testable without a device.

/// Small pure helpers for the Input and Feedback modules.
enum FeelMath {
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// 0…1, NaN → 0.
    static func clamp01(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    /// Hermite smoothstep of `x` clamped to 0…1: 3x² − 2x³ (zero slope at both ends).
    static func smoothstep(_ x: Double) -> Double {
        let u = clamp01(x)
        return u * u * (3 - 2 * u)
    }
}

/// One-Euro filter (Casiez et al., CHI 2012): heavy smoothing while the input is slow, low lag while it moves fast.
/// Squish's tuning for the Duo hinge: minCutoff 2.0, β 0.12, dCutoff 1.5; dt clamped to 1/240…0.2 s.
/// At a 60°/s squeeze the cutoff is ≈ 9 Hz (≈ 17 ms, under 1° of lag).
struct OneEuroSmoother {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double

    private(set) var value: Double?
    /// Filtered derivative of the input (units per second).
    private(set) var derivative: Double = 0
    private var lastTime: Double?

    init(minCutoff: Double = 2.0, beta: Double = 0.12, dCutoff: Double = 1.5) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    mutating func reset() {
        value = nil
        derivative = 0
        lastTime = nil
    }

    mutating func filter(_ x: Double, at time: Double) -> Double {
        guard x.isFinite else { return value ?? 0 }
        guard let previous = value, let previousTime = lastTime else {
            value = x
            lastTime = time
            derivative = 0
            return x
        }
        let dt = min(max(time - previousTime, 1.0 / 240.0), 0.2)
        let rawDerivative = (x - previous) / dt
        derivative += (rawDerivative - derivative) * Self.alpha(cutoff: dCutoff, dt: dt)
        let cutoff = minCutoff + beta * abs(derivative)
        let filtered = previous + (x - previous) * Self.alpha(cutoff: cutoff, dt: dt)
        value = filtered
        lastTime = time
        return filtered
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }
}

/// The hold stabiliser (Brim REVIEW-2 "hinge noise"). After the One-Euro, it filters harder while the hand is holding
/// still and gets completely out of the way while it moves, so a deliberate squeeze has zero added lag but hand
/// tremor at rest never flutters the wings.
///
/// Intent is read from the NET speed of the raw reports over the last `window` (tremor and quantisation cancel out,
/// a deliberate move doesn't), or from a deviation larger than `escape`. Held: a first-order low-pass at the rest
/// cutoff (Swoop: chosen per frame by `HingeTuckSource`, heaviest near the open angle). Moving (≥ `moveSpeed`):
/// pass-through. A short `hangover` keeps it open just after a move stops, so the settle isn't smeared.
struct HoldStabiliser {
    /// Default rest cutoff (Hz) while held.
    static let restCutoff = 0.6
    /// Net speed (°/s) at or below which the hand counts as holding still.
    static let restSpeed = 6.0
    /// Net speed (°/s) at or above which it is a deliberate move (pass-through).
    static let moveSpeed = 20.0
    static let window = 0.25
    /// A deviation from the held value larger than this many degrees also opens the filter.
    static let escape = 4.0
    static let hangover = 0.12
    static let capacity = 12
    /// The Duo's report interval while moving (25–30 Hz).
    static let nominalInterval = 1.0 / 30

    private var times: [Double] = []
    private var angles: [Double] = []
    private(set) var value: Double?
    /// 0 = held (full smoothing) … 1 = moving (pass-through).
    private(set) var motion = 0.0
    private var lastTime = 0.0

    init() {}

    mutating func reset() {
        times.removeAll()
        angles.removeAll()
        value = nil
        motion = 0
    }

    /// A raw hinge report (degrees, receipt time).
    mutating func sample(_ angle: Double, at time: Double) {
        times.append(time)
        angles.append(angle)
        if times.count > Self.capacity {
            let extra = times.count - Self.capacity
            times.removeFirst(extra)
            angles.removeFirst(extra)
        }
    }

    /// Net speed of the raw reports (°/s) over the last `window`; 0 once the reports have stopped.
    func speed(at time: Double) -> Double {
        let count = times.count
        guard count >= 2 else { return 0 }
        let newestTime = times[count - 1]
        let newestAngle = angles[count - 1]
        if time - newestTime > Self.window { return 0 }
        var index = count - 1
        while index > 0 && newestTime - times[index - 1] <= Self.window {
            index -= 1
        }
        if index < count - 1 {
            return abs(newestAngle - angles[index]) / max(newestTime - times[index], 1.0 / 60)
        }
        // The first report after a silence: assume one nominal interval of motion (this only opens the smoothing up).
        return abs(newestAngle - angles[count - 2]) / Self.nominalInterval
    }

    /// Spread (max − min, degrees) of the raw reports over the last `window` s, counting the last report before the
    /// window too (where the hinge was when the window began). 0 when nothing arrived in the window (the Duo sends
    /// nothing while still). Unlike the net `speed`, a turnaround (a fidget's peak) never reads as still.
    func spread(over window: Double, at time: Double) -> Double {
        let count = times.count
        guard count >= 1, window > 0 else { return 0 }
        var low = Double.infinity
        var high = -Double.infinity
        var index = count - 1
        while index >= 0 {
            let angle = angles[index]
            low = min(low, angle)
            high = max(high, angle)
            if times[index] < time - window { break }
            index -= 1
        }
        return high >= low ? high - low : 0
    }

    mutating func filter(_ x: Double, at time: Double, restCutoff: Double = HoldStabiliser.restCutoff) -> Double {
        guard x.isFinite else { return value ?? 180 }
        guard let previous = value else {
            value = x
            lastTime = time
            motion = 0
            return x
        }
        let dt = FeelMath.clamp(time - lastTime, 1.0 / 240, 0.2)
        lastTime = time
        let bySpeed = FeelMath.clamp((speed(at: time) - Self.restSpeed) / (Self.moveSpeed - Self.restSpeed), 0, 1)
        let byDeviation = FeelMath.clamp((abs(x - previous) - Self.escape) / Self.escape, 0, 1)
        let u = max(bySpeed, byDeviation)
        let k = max(u * u * (3 - 2 * u), motion * exp(-dt / Self.hangover))
        motion = k
        let cutoff = restCutoff.isFinite ? max(restCutoff, 0.05) : Self.restCutoff
        let r = 2 * Double.pi * cutoff * dt
        let rest = r / (r + 1)
        let alpha = rest + (1 - rest) * k
        let out = previous + (x - previous) * alpha
        value = out
        return out
    }
}

/// Critically damped spring, integrated with the exact closed form so it is stable at any frame time.
struct FeelSpring {
    var value: Double = 0
    var velocity: Double = 0

    init(value: Double = 0) {
        self.value = value
    }

    mutating func step(toward target: Double, omega: Double, dt: Double) {
        guard dt > 0, omega > 0 else { return }
        let x0 = value - target
        let decay = exp(-omega * dt)
        let newX = (x0 + (velocity + omega * x0) * dt) * decay
        velocity = (velocity - omega * (velocity + omega * x0) * dt) * decay
        value = target + newX
    }
}

/// The hinge at display rate (Squish `HingeTracker`, unchanged in behaviour). The Duo reports 25–30 Hz while moving
/// and nothing while still, so the picture must move continuously *between* reports and never hold, then jump.
///
/// An alpha-beta tracker on the raw samples: between samples it extrapolates at the tracked velocity for about one
/// sample interval, then eases to a stop; each correction is blended in over ~40 ms; once reports stop it glides onto
/// the last raw reading. Jumps larger than `snapDegrees` snap.
struct HingePredictor {
    static let alpha = 0.75
    static let beta = 0.35
    static let maxSpeed = 900.0
    static let coast = 1.0
    static let ease = 0.3
    static let horizonMin = 0.03
    static let horizonMax = 0.2
    static let snapDegrees = 90.0
    static let restGlide = 0.05

    /// The tracked (alpha-beta) angle as of the last report.
    private(set) var estimate: Double?
    /// °/s, positive while the angle grows (opening).
    private(set) var velocity = 0.0
    private(set) var lastSampleTime = 0.0
    /// Smoothed time between samples (s).
    private(set) var interval = 1.0 / 30
    private var offset = 0.0
    private var offsetTime = 0.0
    private var lastReading = 180.0

    init() {}

    mutating func reset() {
        estimate = nil
        velocity = 0
        offset = 0
    }

    mutating func sample(_ angle: Double, at time: Double) {
        lastReading = angle
        guard estimate != nil else {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        let shown = self.angle(at: time)
        let dt = min(max(time - lastSampleTime, 1.0 / 240), 0.5)
        let predicted = raw(at: time)
        let tau = max(0.03, Self.ease * interval)
        let prior = velocity * exp(-max(0, (time - lastSampleTime) - 2 * horizon) / tau)
        interval += (min(dt, 0.25) - interval) * 0.3
        let surprise = angle - predicted
        if abs(surprise) > Self.snapDegrees {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        estimate = predicted + Self.alpha * surprise
        velocity = FeelMath.clamp(prior + Self.beta / dt * surprise, -Self.maxSpeed, Self.maxSpeed)
        lastSampleTime = time
        offset = shown - raw(at: time)
        offsetTime = time
    }

    var horizon: Double { FeelMath.clamp(Self.coast * interval, Self.horizonMin, Self.horizonMax) }

    private func extrapolation(at time: Double) -> Double {
        let age = max(time - lastSampleTime, 0)
        if age <= horizon { return age }
        let tau = max(0.03, Self.ease * interval)
        return horizon + tau * (1 - exp(-(age - horizon) / tau))
    }

    private func raw(at time: Double) -> Double {
        (estimate ?? 180) + velocity * extrapolation(at: time)
    }

    /// The hinge angle to use at `time` (degrees, 0…180).
    func angle(at time: Double) -> Double {
        guard estimate != nil else { return 180 }
        let blend = exp(-max(time - offsetTime, 0) / max(0.04, 0.35 * interval))
        let moving = FeelMath.clamp(raw(at: time) + offset * blend, 0, 180)
        let rest = horizon + 3 * max(0.03, Self.ease * interval)
        let age = max(time - lastSampleTime, 0)
        guard age > rest else { return moving }
        let k = 1 - exp(-(age - rest) / Self.restGlide)
        return moving + (lastReading - moving) * k
    }

    /// Reports per second, from the smoothed interval.
    var rate: Double { 1 / max(interval, 1e-3) }
}

/// The "phone is closing" latch (GAME-DESIGN §3): on below `closeBelow` (95°), off again only above `reopenAbove`
/// (102°), so a hand hovering around 95–100° never chatters pause/resume.
struct FeelClosingLatch {
    static let closeBelow = 95.0
    static let reopenAbove = 102.0

    private(set) var isClosing = false

    init() {}

    /// Feed a (filtered) hinge angle. Returns the new state.
    @discardableResult
    mutating func update(angle: Double) -> Bool {
        guard angle.isFinite else { return isClosing }
        if angle < Self.closeBelow {
            isClosing = true
        } else if angle > Self.reopenAbove {
            isClosing = false
        }
        return isClosing
    }
}

/// `SWOOP-T …` demo/timing lines for CI, only with the `-swoopDemo` launch argument, and only in DEBUG builds
/// (QA-1 P2-13: Release carries neither the check nor the string). Flushed at once.
enum FeelDemoLog {
    #if DEBUG
    static let isEnabled: Bool = ProcessInfo.processInfo.arguments.contains("-swoopDemo")
    #else
    static let isEnabled: Bool = false
    #endif

    static func emit(_ line: String) {
        guard isEnabled else { return }
        print(line)
        fflush(stdout)
    }
}
