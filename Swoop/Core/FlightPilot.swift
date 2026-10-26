import CoreGraphics
import Foundation

// MARK: - The simulated player (attract loop, CI frames, balance tests)
//
// A human-like pilot, deterministic with its seed. It only sees what a player sees: the snapshot and the sea.
// - Skimming: tuck on downslopes (looking a little ahead), open for the climb, so it opens just before the trough
//   turns into the next upslope and launches off the crest with open wings.
// - Airborne: wings open; it plans *when* to tuck so that holding the tuck until touchdown lands on a downslope at
//   the smallest angle. The plan integrates the open path with the session's own physics (Tuning) and, at each
//   candidate moment, a tucked branch to its touchdown; it aims at the centre of the widest run of Perfect landings.
//   Once it tucks in the air it holds the tuck to the water (a dive, not a twitch), unless the dive is now going to
//   splash and opening would land better: then it pulls out (Round 2; people do).
// - Planning cost is capped (`planBudget` integration steps per plan, all branches together) so the attract loop on
//   the main thread stays cheap (QA-1 P2-14).
// - Every decision is held ≥ `hold` s, and seen through a reaction lag, so it looks like a skilled human, not jitter.
// - `casual` reacts late (0.15 s lag it doesn't allow for), misjudges gravity a little and mistimes 20 % of its dives;
//   `novice` ignores the sea and folds in a crude ~0.8 s rhythm.
// Keep in sync with tools/balance-sim.js.

public enum PilotSkill: String, CaseIterable, Sendable {
    case novice, casual, expert, perfect
}

/// Per-skill behaviour.
struct CorePilotProfile {
    /// Reaction lag (s): the tuck it applies is the one it wanted this long ago.
    var lag: Double
    /// The lag it allows for when planning (s).
    var assumedLag: Double
    /// Minimum time between tuck changes (s).
    var hold: Double
    /// Skimming look-ahead (s of travel).
    var look: Double
    /// Re-plan interval while airborne (s).
    var replan: Double
    /// Gravity misjudgement (± fraction, per plan).
    var noise: Double
    /// Dive timing jitter (± s).
    var jitter: Double
    /// Chance a dive is mistimed by 0.12–0.3 s.
    var mistake: Double
    /// Ignore the sea: fold in a rhythm of rhythmMin…rhythmMax s per half-stroke.
    var rhythm: Bool

    static func profile(_ skill: PilotSkill) -> CorePilotProfile {
        switch skill {
        case .perfect:
            return CorePilotProfile(lag: 0.03, assumedLag: 0.03, hold: 0.12, look: 0.05, replan: 0.15, noise: 0,
                                    jitter: 0, mistake: 0, rhythm: false)
        case .expert:
            return CorePilotProfile(lag: 0.08, assumedLag: 0.06, hold: 0.14, look: 0.05, replan: 0.2, noise: 0.04,
                                    jitter: 0.04, mistake: 0.06, rhythm: false)
        case .casual:
            return CorePilotProfile(lag: 0.15, assumedLag: 0.05, hold: 0.16, look: 0.03, replan: 0.25, noise: 0.10,
                                    jitter: 0.08, mistake: 0.20, rhythm: false)
        case .novice:
            return CorePilotProfile(lag: 0.25, assumedLag: 0, hold: 0.20, look: 0, replan: 1, noise: 0,
                                    jitter: 0, mistake: 0, rhythm: true)
        }
    }
}

/// A point of the pilot's predicted path.
struct CorePilotState {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var u: Double
}

public struct FlightPilot {
    public let skill: PilotSkill

    /// Planning integration step (s), the dive candidates every `branchEvery` steps, how far ahead it considers a
    /// dive (s) and the longest path it integrates (s).
    static let predictDt: Double = 1.0 / 60.0
    static let branchEvery: Int = 2
    static let maxDelay: Double = 1.6
    static let maxFlight: Double = 3.0
    static let planBudget: Int = 2500
    /// Skimming: tuck when the slope ahead is below this.
    static let downslopeThreshold: Double = -0.03
    /// Novice rhythm half-stroke range (s).
    static let rhythmMin: Double = 0.55
    static let rhythmMax: Double = 1.05
    /// Mistimed dive offset range (s).
    static let mistakeMin: Double = 0.12
    static let mistakeMax: Double = 0.3

    private let profile: CorePilotProfile
    private var rng: SeededRandom
    private var target: Double = 0
    private var lastChange: Double = -1e9
    private var histTimes: [Double] = []
    private var histValues: [Double] = []
    private var histHead: Int = 0
    private var rhythmNext: Double = 0
    private var rhythmState: Double = 0
    private var committed: Bool = false
    private var tuckAt: Double = 1e18
    private var nextPlan: Double = -1e18
    private var wasSkimming: Bool = true

    public init(skill: PilotSkill, seed: UInt64) {
        self.skill = skill
        self.profile = CorePilotProfile.profile(skill)
        self.rng = SeededRandom(seed: seed ^ 0x91_70A7)
    }

    /// The tuck (0 spread … 1 tucked) to apply this frame.
    public mutating func tuck(for snapshot: FlightSnapshot, sea: SeaProfile) -> Double {
        let now: Double = snapshot.time
        let want: Double = desired(snapshot, sea)
        histTimes.append(now)
        histValues.append(want)
        while histHead + 1 < histTimes.count && histTimes[histHead + 1] <= now - profile.lag {
            histHead += 1
        }
        if histHead > 512 {
            histTimes.removeFirst(histHead)
            histValues.removeFirst(histHead)
            histHead = 0
        }
        let seen: Double = histValues[histHead]
        if seen != target && now - lastChange >= profile.hold {
            target = seen
            lastChange = now
        }
        if snapshot.phase != .flying {
            target = 0
        }
        return target
    }

    // MARK: Decisions

    private mutating func desired(_ snap: FlightSnapshot, _ sea: SeaProfile) -> Double {
        if snap.phase != .flying { return 0 }
        if profile.rhythm {
            if snap.time >= rhythmNext {
                rhythmState = 1 - rhythmState
                rhythmNext = snap.time + rng.range(FlightPilot.rhythmMin...FlightPilot.rhythmMax)
            }
            return rhythmState
        }
        if snap.skimming {
            wasSkimming = true
            committed = false
            tuckAt = 1e18
            let ahead: Double = Double(snap.position.x) + snap.speed * profile.look
            return sea.slope(at: ahead) < FlightPilot.downslopeThreshold ? 1 : 0
        }
        if wasSkimming {
            wasSkimming = false
            nextPlan = snap.time
            committed = false
            tuckAt = 1e18
        }
        if committed {
            // Pull out of a dive that is going to splash if opening the wings would land better.
            if snap.time >= nextPlan {
                nextPlan = snap.time + profile.replan
                let here = CorePilotState(x: Double(snap.position.x), y: Double(snap.position.y),
                                          vx: Double(snap.velocity.dx), vy: Double(snap.velocity.dy), u: snap.tuck)
                let dive = FlightPilot.landTucked(here, sea: sea, target: 1, delay: 0, gScale: 1)
                if dive.rank == 2 {
                    let open = FlightPilot.landTucked(here, sea: sea, target: 0, delay: 0, gScale: 1)
                    if open.rank < 2 {
                        committed = false
                        tuckAt = 1e18
                        return 0
                    }
                }
            }
            return 1
        }
        if snap.time >= nextPlan {
            nextPlan = snap.time + profile.replan
            let gScale: Double = 1 + (profile.noise > 0 ? rng.range(-profile.noise...profile.noise) : 0)
            let start = CorePilotState(x: Double(snap.position.x), y: Double(snap.position.y),
                                       vx: Double(snap.velocity.dx), vy: Double(snap.velocity.dy), u: snap.tuck)
            var d: Double = FlightPilot.plan(from: start, sea: sea, gScale: gScale, lag: profile.assumedLag)
            if d.isFinite {
                if profile.jitter > 0 { d += rng.range(-profile.jitter...profile.jitter) }
                if profile.mistake > 0 && rng.unit() < profile.mistake {
                    let sign: Double = rng.unit() < 0.5 ? -1 : 1
                    d += sign * rng.range(FlightPilot.mistakeMin...FlightPilot.mistakeMax)
                }
                tuckAt = snap.time + max(0, d)
            } else {
                tuckAt = 1e18
            }
        }
        if snap.time >= tuckAt {
            committed = true
            return 1
        }
        return 0
    }

    // MARK: Prediction (same laws as FlightSession; see Tuning)

    static func stepAir(_ st: inout CorePilotState, _ u: Double, _ dt: Double, _ gScale: Double) {
        let acc = Tuning.airAcceleration(u: u, vx: st.vx, vy: st.vy, drag: Tuning.airDrag, lift: true)
        let ax: Double = acc.ax
        let ay: Double = acc.ay - Tuning.airGravity(u) * (gScale - 1)
        st.x += st.vx * dt + 0.5 * ax * dt * dt
        st.y += st.vy * dt + 0.5 * ay * dt * dt
        st.vx += ax * dt
        st.vy += ay * dt
        if st.vx < Tuning.minSpeed { st.vx = Tuning.minSpeed }
    }

    /// Landing quality rank (0 perfect, 1 good, 2 splash) and the assisted angle (deg), as the session judges it.
    static func rank(_ st: CorePilotState, at x: Double, sea: SeaProfile) -> (rank: Int, alpha: Double) {
        let phi: Double = atan(sea.slope(at: x))
        let assisted: Double = Tuning.assistedAngle(velocityAngle: atan2(st.vy, st.vx), surfaceAngle: phi)
        let alpha: Double = abs(assisted - phi) * 180 / Double.pi
        let phiDeg: Double = phi * 180 / Double.pi
        if alpha <= Tuning.perfectAngleDeg && phiDeg < Tuning.perfectSlopeDeg { return (0, alpha) }
        if alpha <= Tuning.goodAngleDeg { return (1, alpha) }
        return (2, alpha)
    }

    /// Fly a branch (the tuck goes to `target` after `delay`) to its touchdown. `steps` = integration steps used.
    static func landTucked(_ from: CorePilotState, sea: SeaProfile, target: Double, delay: Double,
                           gScale: Double) -> (rank: Int, alpha: Double, steps: Int) {
        var b: CorePilotState = from
        var limited: Double = from.u
        let k: Double = 1 - exp(-predictDt / Tuning.tuckAttack)
        var t: Double = 0
        var n: Int = 0
        while t < maxFlight {
            n += 1
            let tu: Double = t >= delay ? target : limited
            // The session's rise limit (Tuning.tuckMaxRise), then its easing.
            limited = tu > limited ? min(tu, limited + Tuning.tuckMaxRise * predictDt) : tu
            b.u += (limited - b.u) * k
            let px: Double = b.x
            let d0: Double = b.y - sea.height(at: px)
            let uNow: Double = b.u
            stepAir(&b, uNow, predictDt, gScale)
            let d1: Double = b.y - sea.height(at: b.x)
            if d1 <= 0 {
                let fr: Double = d0 > 0 ? min(max(d0 / (d0 - d1), 0), 1) : 1
                let lx: Double = px + (b.x - px) * fr
                let r = rank(b, at: lx, sea: sea)
                return (r.rank, r.alpha, n)
            }
            t += predictDt
        }
        return (1, Tuning.goodAngleDeg, n)
    }

    /// Seconds from now to start the dive (infinity = stay open to the water).
    static func plan(from start: CorePilotState, sea: SeaProfile, gScale: Double, lag: Double) -> Double {
        var open: CorePilotState = start
        let k: Double = 1 - exp(-predictDt / Tuning.tuckRelease)
        var ranks: [Int] = []
        var alphas: [Double] = []
        ranks.reserveCapacity(64)
        alphas.reserveCapacity(64)
        var t: Double = 0
        var step: Int = 0
        var openRank: Int = -1
        var openAlpha: Double = 1e9
        var budget: Int = planBudget
        while t <= maxDelay && budget > 0 {
            if step % branchEvery == 0 {
                let r = landTucked(open, sea: sea, target: 1, delay: lag, gScale: gScale)
                ranks.append(r.rank)
                alphas.append(r.alpha)
                budget -= r.steps
            }
            budget -= 1
            step += 1
            open.u += (0 - open.u) * k
            let px: Double = open.x
            let d0: Double = open.y - sea.height(at: px)
            let uOpen: Double = open.u
            stepAir(&open, uOpen, predictDt, gScale)
            let d1: Double = open.y - sea.height(at: open.x)
            t += predictDt
            if d1 <= 0 {
                let fr: Double = d0 > 0 ? min(max(d0 / (d0 - d1), 0), 1) : 1
                let lx: Double = px + (open.x - px) * fr
                let r = rank(open, at: lx, sea: sea)
                openRank = r.rank
                openAlpha = r.alpha
                break
            }
        }
        let dd: Double = predictDt * Double(branchEvery)
        // The widest run of Perfect dives.
        var bestLen: Int = 0
        var bestCentre: Double = -1
        var run: Int = 0
        var i: Int = 0
        while i < ranks.count {
            if ranks[i] == 0 {
                run += 1
                if run > bestLen {
                    bestLen = run
                    bestCentre = Double(i) - Double(run - 1) / 2
                }
            } else {
                run = 0
            }
            i += 1
        }
        if openRank == 0 && bestLen < 3 { return Double.infinity }
        if bestLen > 0 { return bestCentre * dd }
        // No Perfect: the smallest angle among the Good options (the open landing included).
        var bi: Int = -1
        var ba: Double = 1e9
        i = 0
        while i < ranks.count {
            if ranks[i] <= 1 && alphas[i] < ba {
                ba = alphas[i]
                bi = i
            }
            i += 1
        }
        if openRank >= 0 && openRank <= 1 && openAlpha <= ba { return Double.infinity }
        if bi >= 0 { return Double(bi) * dd }
        // Everything splashes: the smallest angle overall.
        i = 0
        while i < ranks.count {
            if alphas[i] < ba {
                ba = alphas[i]
                bi = i
            }
            i += 1
        }
        if openRank >= 0 && openAlpha <= ba { return Double.infinity }
        return bi >= 0 ? Double(bi) * dd : Double.infinity
    }
}
