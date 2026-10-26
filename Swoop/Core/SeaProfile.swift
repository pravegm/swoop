import CoreGraphics
import Foundation

// MARK: - The sea (GAME-DESIGN §4)
//
// An infinite, deterministic, C¹-smooth height field h(x) (pt above the mean water level).
//
// The sea is a chain of "sets". Each set is the sum of three sine swells A_k · sin(θ_k(x)) (a component may have
// A = 0, so a set has 2–3 components). Between two sets there is a `Tuning.seaBlendWidth` crossfade in which every
// component's amplitude and frequency morph with a smoothstep, and its phase is the exact integral of the morphing
// frequency. So h and h' are continuous everywhere, and the slope in a blend never jumps (a height crossfade between
// unrelated swells would add a Δh / width slope spike). Every set keeps Σ 2πA/λ ≤ `seaSetSlopeBudget`, and every blend
// is checked numerically against `seaBlendSlopeCap` when it is generated (scaled down, else the previous set simply
// continues), so |h'| ≤ 1.1 everywhere.
//
// Round 2: before the last tutorial knot the sea is the fixed intro (`Tuning.tutorialKnots`: half-cosine segments
// between extrema, C¹), the same for every seed; it guarantees the first Perfects. Set 0 is the sine that continues
// from that knot up to `Tuning.tutorialEnd` (also fixed); the seeded sets follow and get bigger every `seaTierLength` (3 km), with the odd rogue set. Sets are generated lazily (only ever forward) and
// cached in an array; a query walks from the last index used, so sequential queries are O(1) amortised.

/// One sine component: A · sin(phase + 2π·freq·(x − set.bodyStart)) in a set's body.
struct CoreSwell {
    var amp: Double
    var freq: Double
    var phase: Double
}

struct CoreSeaSet {
    /// Centre of the blend from the previous set (unused for set 0).
    var centre: Double
    /// Where the blend ends and this set's own formula starts (phase reference).
    var bodyStart: Double
    /// Where the next set's blend starts.
    var end: Double
    var s0: CoreSwell
    var s1: CoreSwell
    var s2: CoreSwell
    var rogue: Bool

    func swell(_ k: Int) -> CoreSwell {
        switch k {
        case 0: return s0
        case 1: return s1
        default: return s2
        }
    }

    mutating func setAmp(_ k: Int, _ a: Double) {
        switch k {
        case 0: s0.amp = a
        case 1: s1.amp = a
        default: s2.amp = a
        }
    }

    mutating func setPhase(_ k: Int, _ p: Double) {
        switch k {
        case 0: s0.phase = p
        case 1: s1.phase = p
        default: s2.phase = p
        }
    }
}

public final class SeaProfile {
    public let seed: UInt64

    private var rng: SeededRandom
    private var sets: [CoreSeaSet] = []
    private var lastIndex: Int = 0
    /// Diagnostics (tests): how often a blend had to be scaled down / fell back to continuing the previous set.
    private(set) var blendScaleCount: Int = 0
    private(set) var blendFallbackCount: Int = 0

    static let tau: Double = Double.pi * 2

    /// The intro knots and where they end (the sine set 0 takes over there).
    private let knots: [(x: Double, y: Double)]
    private let introEnd: Double

    public init(seed: UInt64) {
        self.seed = seed
        self.rng = SeededRandom(seed: seed ^ 0x5EA_5EA5_EA5E_A5EA)
        var k: [(x: Double, y: Double)] = Tuning.tutorialKnots
        if k.count < 2 {
            k = [(x: -2400, y: 0), (x: 0, y: 0)]
        }
        self.knots = k
        let last: (x: Double, y: Double) = k[k.count - 1]
        self.introEnd = last.x
        // The sine continues from the last knot (an extremum): amplitude |y|, a crest or a trough there.
        let f0: Double = 1.0 / Tuning.tutorialWavelength
        let theta0: Double = last.y >= 0 ? Double.pi / 2 : -Double.pi / 2
        let phase0: Double = SeaProfile.wrap(theta0 - SeaProfile.tau * f0 * last.x)
        let tutorial = CoreSeaSet(
            centre: -1e12, bodyStart: 0, end: max(Tuning.tutorialEnd, last.x + 300),
            s0: CoreSwell(amp: abs(last.y), freq: f0, phase: phase0),
            s1: CoreSwell(amp: 0, freq: 1.0 / 560.0, phase: 0),
            s2: CoreSwell(amp: 0, freq: 1.0 / 420.0, phase: 0),
            rogue: false)
        sets.append(tutorial)
    }

    // MARK: Public queries

    /// Height above the mean water level (pt).
    public func height(at x: Double) -> Double {
        return surface(at: x).h
    }

    /// dh/dx.
    public func slope(at x: Double) -> Double {
        return surface(at: x).d
    }

    /// Surface points from x0 to x1 (inclusive) every `step` pt, for drawing.
    public func samples(from x0: Double, to x1: Double, step: Double) -> [CGPoint] {
        if !(x0.isFinite && x1.isFinite && step.isFinite) || x1 < x0 { return [] }
        let st: Double = max(step, 0.5)
        let n: Int = min(Int(((x1 - x0) / st).rounded(.down)), 100_000)
        var out: [CGPoint] = []
        out.reserveCapacity(n + 2)
        var i: Int = 0
        while i <= n {
            let x: Double = x0 + Double(i) * st
            out.append(CGPoint(x: CGFloat(x), y: CGFloat(height(at: x))))
            i += 1
        }
        let lastX: Double = x0 + Double(n) * st
        if x1 - lastX > 1e-6 {
            out.append(CGPoint(x: CGFloat(x1), y: CGFloat(height(at: x1))))
        }
        return out
    }

    /// The same points written into `buffer` (cleared first, capacity kept), so a caller can reuse one array every
    /// frame without allocating (QA-1 P1-6).
    public func samples(into buffer: inout [CGPoint], from x0: Double, to x1: Double, step: Double) {
        buffer.removeAll(keepingCapacity: true)
        if !(x0.isFinite && x1.isFinite && step.isFinite) || x1 < x0 { return }
        let st: Double = max(step, 0.5)
        let n: Int = min(Int(((x1 - x0) / st).rounded(.down)), 100_000)
        var i: Int = 0
        while i <= n {
            let x: Double = x0 + Double(i) * st
            buffer.append(CGPoint(x: CGFloat(x), y: CGFloat(height(at: x))))
            i += 1
        }
        let lastX: Double = x0 + Double(n) * st
        if x1 - lastX > 1e-6 {
            buffer.append(CGPoint(x: CGFloat(x1), y: CGFloat(height(at: x1))))
        }
    }

    // MARK: Internal queries

    /// Signed curvature numerator h'' (central difference of the analytic slope).
    func secondDerivative(at x: Double) -> Double {
        let e: Double = 2
        return (slope(at: x + e) - slope(at: x - e)) / (2 * e)
    }

    /// Height and slope at x.
    func surface(at x: Double) -> (h: Double, d: Double) {
        if !x.isFinite { return (0, 0) }
        if x < introEnd { return introSurface(x) }
        let j: Int = index(for: x)
        let s: CoreSeaSet = sets[j]
        if j > 0 && x < s.bodyStart {
            return blendSurface(sets[j - 1], s, x)
        }
        return bodySurface(s, x)
    }

    /// Number of sets generated so far (tests).
    var setCount: Int { return sets.count }

    /// Centres of every set blend up to `x` (tests: continuity is checked across these). Each blend spans
    /// centre ± seaBlendWidth / 2.
    func blendCentres(through x: Double) -> [Double] {
        _ = index(for: x)
        var out: [Double] = []
        var j: Int = 1
        while j < sets.count {
            if sets[j].centre <= x { out.append(sets[j].centre) }
            j += 1
        }
        return out
    }

    // MARK: Evaluation

    static func wrap(_ p: Double) -> Double {
        var r: Double = p.truncatingRemainder(dividingBy: tau)
        if r < 0 { r += tau }
        return r
    }

    /// The fixed intro: half-cosine segments between the knots (flat before the first knot).
    private func introSurface(_ x: Double) -> (h: Double, d: Double) {
        let first: (x: Double, y: Double) = knots[0]
        if x <= first.x { return (first.y, 0) }
        var i: Int = 0
        while i < knots.count - 2 && x >= knots[i + 1].x {
            i += 1
        }
        let a: (x: Double, y: Double) = knots[i]
        let b: (x: Double, y: Double) = knots[i + 1]
        let w: Double = max(b.x - a.x, 1e-6)
        let t: Double = (x - a.x) / w
        let dy: Double = b.y - a.y
        let h: Double = a.y + dy * (1 - cos(Double.pi * t)) / 2
        let d: Double = dy * Double.pi * sin(Double.pi * t) / (2 * w)
        return (h, d)
    }

    private static func smooth(_ t: Double) -> Double {
        return t * t * (3 - 2 * t)
    }

    private func bodyPhase(_ s: CoreSeaSet, _ k: Int, _ x: Double) -> Double {
        let w: CoreSwell = s.swell(k)
        return w.phase + SeaProfile.tau * w.freq * (x - s.bodyStart)
    }

    private func bodySurface(_ s: CoreSeaSet, _ x: Double) -> (h: Double, d: Double) {
        var h: Double = 0
        var d: Double = 0
        var k: Int = 0
        while k < 3 {
            let w: CoreSwell = s.swell(k)
            if w.amp != 0 {
                let th: Double = w.phase + SeaProfile.tau * w.freq * (x - s.bodyStart)
                h += w.amp * sin(th)
                d += w.amp * SeaProfile.tau * w.freq * cos(th)
            }
            k += 1
        }
        return (h, d)
    }

    /// The morph from set a into set b, for x in b's blend window.
    private func blendSurface(_ a: CoreSeaSet, _ b: CoreSeaSet, _ x: Double) -> (h: Double, d: Double) {
        let wdt: Double = Tuning.seaBlendWidth
        let x0: Double = b.centre - wdt / 2
        let t: Double = min(max((x - x0) / wdt, 0), 1)
        let sm: Double = SeaProfile.smooth(t)
        let dsm: Double = 6 * t * (1 - t) / wdt
        let integral: Double = t * t * t - t * t * t * t / 2   // ∫₀ᵗ smoothstep
        var h: Double = 0
        var d: Double = 0
        var k: Int = 0
        while k < 3 {
            let wa: CoreSwell = a.swell(k)
            let wb: CoreSwell = b.swell(k)
            let fa: Double = wa.freq
            let df: Double = wb.freq - fa
            let th: Double = bodyPhase(a, k, x0) + SeaProfile.tau * wdt * (fa * t + df * integral)
            let dth: Double = SeaProfile.tau * (fa + df * sm)
            let da: Double = wb.amp - wa.amp
            let amp: Double = wa.amp + da * sm
            let damp: Double = da * dsm
            let sn: Double = sin(th)
            let cs: Double = cos(th)
            h += amp * sn
            d += damp * sn + amp * dth * cs
            k += 1
        }
        return (h, d)
    }

    private func blendMaxSlope(_ a: CoreSeaSet, _ b: CoreSeaSet) -> Double {
        var m: Double = 0
        let x0: Double = b.centre - Tuning.seaBlendWidth / 2
        var i: Int = 0
        while i <= 120 {
            let x: Double = x0 + Tuning.seaBlendWidth * Double(i) / 120.0
            m = max(m, abs(blendSurface(a, b, x).d))
            i += 1
        }
        return m
    }

    // MARK: Indexing and generation

    private func index(for x: Double) -> Int {
        var guardCount: Int = 0
        while let last = sets.last, last.end <= x, guardCount < 100_000 {
            generateNext()
            guardCount += 1
        }
        var j: Int = min(max(lastIndex, 0), sets.count - 1)
        while j > 0 && x < sets[j].centre - Tuning.seaBlendWidth / 2 {
            j -= 1
        }
        while j < sets.count - 1 && x >= sets[j].end {
            j += 1
        }
        lastIndex = j
        return j
    }

    private static func lerpRange(_ low: ClosedRange<Double>, _ high: ClosedRange<Double>, _ g: Double) -> ClosedRange<Double> {
        let lo: Double = low.lowerBound + (high.lowerBound - low.lowerBound) * g
        let hi: Double = low.upperBound + (high.upperBound - low.upperBound) * g
        return lo...max(lo, hi)
    }

    private func generateNext() {
        guard let prev = sets.last else { return }
        let wdt: Double = Tuning.seaBlendWidth
        let centre: Double = prev.end + wdt / 2
        let tier: Double = max(0, (centre / Tuning.seaTierLength).rounded(.down))
        let g: Double = min(1, tier / Tuning.seaFullTier)
        let len: Double = min(Tuning.seaSetLengthCap,
                              rng.range(Tuning.seaSetLengthMin...Tuning.seaSetLengthMax) + Tuning.seaSetLengthPerTier * tier)
        var rogue: Bool = false
        if tier >= 1 && !prev.rogue {
            rogue = rng.unit() < Tuning.seaRogueChance
        }
        let twoComponents: Bool = rng.unit() < Tuning.seaTwoComponentChance
        var amps: [Double] = [0, 0, 0]
        var lams: [Double] = [0, 0, 0]
        if rogue {
            amps[0] = rng.range(Tuning.seaRogueAmplitude)
            amps[1] = rng.range(Tuning.seaRogueMidAmplitude)
            amps[2] = 0
            lams[0] = rng.range(Tuning.seaRogueWavelength)
            lams[1] = rng.range(Tuning.seaRogueMidWavelength)
            lams[2] = rng.range(Tuning.seaWavelength2)
        } else {
            amps[0] = rng.range(SeaProfile.lerpRange(Tuning.seaAmplitude0Low, Tuning.seaAmplitude0High, g))
            amps[1] = rng.range(SeaProfile.lerpRange(Tuning.seaAmplitude1Low, Tuning.seaAmplitude1High, g))
            amps[2] = twoComponents ? 0 : rng.range(SeaProfile.lerpRange(Tuning.seaAmplitude2Low, Tuning.seaAmplitude2High, g))
            lams[0] = rng.range(Tuning.seaWavelength0)
            lams[1] = rng.range(Tuning.seaWavelength1)
            lams[2] = rng.range(Tuning.seaWavelength2)
        }
        var freqs: [Double] = [0, 0, 0]
        var k: Int = 0
        while k < 3 {
            freqs[k] = 1.0 / (lams[k] * Tuning.seaWavelengthScale)
            amps[k] *= Tuning.seaAmplitudeScale
            k += 1
        }
        // The set's own slope budget.
        var sum: Double = 0
        k = 0
        while k < 3 {
            sum += SeaProfile.tau * amps[k] * freqs[k]
            k += 1
        }
        if sum > Tuning.seaSetSlopeBudget {
            let sc: Double = Tuning.seaSetSlopeBudget / sum
            k = 0
            while k < 3 {
                amps[k] *= sc
                k += 1
            }
        }
        // Phase continuity: each component's phase at bodyStart is the integral of the morphing frequency.
        let x0: Double = centre - wdt / 2
        var phases: [Double] = [0, 0, 0]
        k = 0
        while k < 3 {
            let fa: Double = prev.swell(k).freq
            phases[k] = SeaProfile.wrap(bodyPhase(prev, k, x0) + SeaProfile.tau * wdt * (fa + (freqs[k] - fa) / 2))
            k += 1
        }
        var next = CoreSeaSet(
            centre: centre, bodyStart: centre + wdt / 2, end: centre + len - wdt / 2,
            s0: CoreSwell(amp: amps[0], freq: freqs[0], phase: phases[0]),
            s1: CoreSwell(amp: amps[1], freq: freqs[1], phase: phases[1]),
            s2: CoreSwell(amp: amps[2], freq: freqs[2], phase: phases[2]),
            rogue: rogue)
        // Enforce the blend's slope cap.
        var tries: Int = 0
        while blendMaxSlope(prev, next) > Tuning.seaBlendSlopeCap {
            tries += 1
            if tries > 30 {
                // Fallback: continue the previous set exactly (a blend between identical sets is the set itself).
                blendFallbackCount += 1
                next.s0 = prev.s0
                next.s1 = prev.s1
                next.s2 = prev.s2
                next.rogue = false
                k = 0
                while k < 3 {
                    next.setPhase(k, SeaProfile.wrap(bodyPhase(prev, k, x0) + SeaProfile.tau * wdt * prev.swell(k).freq))
                    k += 1
                }
                break
            }
            blendScaleCount += 1
            k = 0
            while k < 3 {
                next.setAmp(k, next.swell(k).amp * 0.9)
                k += 1
            }
        }
        sets.append(next)
    }
}
