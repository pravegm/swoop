import Foundation

// MARK: - Every tunable number of the Core simulation, in one place (GAME-DESIGN §4–§6).
//
// Units: sea points (pt; 10 pt = 1 m), seconds, pt/s, pt/s², degrees where the name says so.
// The numbers were tuned with the Node port of Core in `tools/balance-sim.js` (keep the two in sync!). Its predicted
// run lengths (20 seeds, dt 1/120): novice ~50 s, casual ~115 s, expert ~5.5 min, perfect ~10 min (always ends).
// Feel numbers to try first on a held Duo are marked FEEL.

public enum Tuning {

    // MARK: Integration

    /// Largest simulation sub-step (s). `FlightSession.step` splits every frame into sub-steps no longer than this.
    public static let maxSubstep: Double = 1.0 / 240.0
    /// Largest frame dt the session accepts (s). The driver clamps to 1/30; this only guards a debugger pause.
    public static let maxFrameDt: Double = 0.25

    // MARK: Gravity, tuck, lift, drag

    /// Gravity (pt/s²).
    public static let gravity: Double = 1500
    /// FEEL. Skimming: gravity along the slope is g · (1 + tuckGravityFactor · u). Tucked = heavier = a downslope
    /// accelerates 2.9×, which is the whole "pump" of the game.
    public static let tuckGravityFactor: Double = 1.9
    /// FEEL. Airborne: gravity is g · (1 + airTuckGravityFactor · u) — tucking in the air is a dive.
    public static let airTuckGravityFactor: Double = 1.9
    /// FEEL. Spread-wing lift while descending: (1 − u) · min(liftMaxFraction · g, liftCoefficient · vx²).
    /// GAME-DESIGN §5 said 0.5 g; 0.65 g gives a calmer glide (the balance harness lands more often with it).
    public static let liftMaxFraction: Double = 0.65
    public static let liftCoefficient: Double = 0.012
    /// The lift acts at right angles to the velocity (true: a glider's lift does no work, so a dive pulled out by
    /// open wings turns into forward speed instead of being thrown away). Never makes the bird climb: its vertical
    /// part is ≤ liftMaxFraction · g < g.
    public static let liftPerpendicular: Bool = true
    /// Air drag: dv/dt = −airDrag · v (1/s), applied in the air and on the water (off during a Tailwind).
    public static let airDrag: Double = 0.04
    /// Extra water friction while skimming (1/s): 0.2 % per second.
    public static let waterFriction: Double = 0.002

    // MARK: Speed limits

    /// Minimum forward speed (pt/s). The bird never stalls: the Scene shows a little flap instead.
    public static let minSpeed: Double = 260
    /// Maximum speed (pt/s); ×(1 + tailwindSpeedBoost) during a Tailwind.
    public static let maxSpeed: Double = 2600

    // MARK: Launch and touchdown

    /// A crest launches the bird when the curvature needs a downward pull larger than
    /// g_eff · cos φ · (1 + launchMargin). The margin stops marginal micro-hops.
    public static let launchMargin: Double = 0.04
    /// After touching down the bird skims at least this long before it can launch again (s): no double Perfects
    /// from a re-launch off the same concave shoulder.
    public static let launchGrace: Double = 0.10
    /// Lifted this far off the water at launch (pt), so the first airborne sub-step doesn't re-touch.
    public static let launchLift: Double = 0.25
    /// FEEL. Perfect skim: angle between velocity and surface ≤ perfectAngleDeg AND the surface going downhill
    /// (φ < perfectSlopeDeg).
    public static let perfectAngleDeg: Double = 14
    public static let perfectSlopeDeg: Double = -4
    /// Good landing: angle ≤ goodAngleDeg (keeps cos α of the speed). Above it: a splash.
    public static let goodAngleDeg: Double = 30
    /// Perfect: keep 100 % of the speed plus this boost.
    public static let perfectBoost: Double = 0.06
    /// Splash: keep cos α · splashKeep of the speed.
    public static let splashKeep: Double = 0.75

    // MARK: The storm (GAME-DESIGN §6)

    /// Storm speed n(t) = stormBaseSpeed + stormAccel · t until stormCruiseSpeed (t ≈ 109 s), then it keeps
    /// accelerating slowly (stormLateAccel) up to stormMaxSpeed (reached at ~13 min), so even a flawless run ends.
    public static let stormBaseSpeed: Double = 520
    public static let stormAccel: Double = 9
    public static let stormCruiseSpeed: Double = 1500
    public static let stormLateAccel: Double = 2.5
    public static let stormMaxSpeed: Double = 3200
    /// The gap bird − storm at the drop (pt).
    public static let gapStart: Double = 2400
    /// The lead meter's "full" gap (pt): lead = gap / fullLead, clamped 0…1.
    public static let fullLead: Double = 3000
    /// `stormClose` fires when lead < stormCloseLead, once per dip; it re-arms above stormRearmLead.
    public static let stormCloseLead: Double = 0.15
    public static let stormRearmLead: Double = 0.30
    /// Attract mode holds the storm this far behind the bird (pt), forever.
    public static let attractStormLag: Double = 1500

    // MARK: Perfect chains, Tailwind, lighthouses

    /// Every Perfect pushes the storm back (pt).
    public static let perfectGapBonus: Double = 120
    /// A Tailwind starts at every multiple of this chain length (3, 6, 9…).
    public static let tailwindChain: Int = 3
    /// Each chain multiple pushes the storm back this much more (pt).
    public static let tailwindGapBonus: Double = 600
    /// Tailwind length (s); every further Perfect during it refills it to this.
    public static let tailwindDuration: Double = 2.5
    /// Tailwind speed surge (+15 %, applied when it starts) and raised max speed; no drag during it.
    public static let tailwindSpeedBoost: Double = 0.15
    /// Passing a lighthouse pushes the storm back (pt).
    public static let lighthouseGapBonus: Double = 800

    // MARK: Clouds

    /// `cloudTouched` fires when the altitude reaches this (pt above the water)…
    public static let cloudHeight: Double = 900
    /// …and re-arms after dropping below this (or touching the water).
    public static let cloudRearmHeight: Double = 650

    // MARK: Easing and timing

    /// The session's own tuck easing on top of the input (s): attack (folding in) and release (opening).
    public static let tuckAttack: Double = 0.06
    public static let tuckRelease: Double = 0.08
    /// Body angle smoothing (s).
    public static let bodyAngleSmoothing: Double = 0.08
    /// Countdown before the drop (s): ticks 3, 2, 1, then `started`.
    public static let countdownDuration: Double = 3.0
    /// The calm "caught" ending before `finished` (s).
    public static let caughtDuration: Double = 1.8
    /// While caught the bird slows to a bob: drag (1/s) and the drift speed it settles at (pt/s).
    public static let caughtDrag: Double = 1.6
    public static let caughtDriftSpeed: Double = 90

    // MARK: Start state

    /// The bird hovers at x = startX, startHeight above the water, then drops at startSpeed (pt/s, level).
    public static let startX: Double = 0
    public static let startHeight: Double = 260
    public static let startSpeed: Double = 520

    // MARK: Score

    /// 10 pt = 1 m.
    public static let pointsPerMeter: Double = 10
    /// Style bonus (m) per Perfect and per Tailwind.
    public static let perfectStyleMeters: Double = 25
    public static let tailwindStyleMeters: Double = 100

    // MARK: The sea (GAME-DESIGN §4; `SeaProfile`)

    /// Crossfade between sets (pt). Amplitudes and wavelengths morph phase-continuously over it (C¹). 300 pt
    /// (the first plan) gave slope spikes above 1.1 when the amplitudes jumped; 600 pt never needs a fallback.
    public static let seaBlendWidth: Double = 600
    /// Each set's own slope budget Σ 2πA/λ (amplitudes are scaled down to fit).
    public static let seaSetSlopeBudget: Double = 1.0
    /// A blend whose sampled max |slope| exceeds this scales the new set down (×0.9, retried), then falls back to
    /// continuing the previous set exactly. Keeps |slope| ≤ 1.1 everywhere.
    public static let seaBlendSlopeCap: Double = 1.08
    /// Set length (pt): seaSetLengthMin…Max, + seaSetLengthPerTier per tier, capped at seaSetLengthCap.
    public static let seaSetLengthMin: Double = 1500
    public static let seaSetLengthMax: Double = 2500
    public static let seaSetLengthPerTier: Double = 200
    public static let seaSetLengthCap: Double = 3500
    /// The sea gets bigger every tier (pt): 3 km. Amplitudes reach their largest range after seaFullTier tiers.
    public static let seaTierLength: Double = 30000
    public static let seaFullTier: Double = 5
    /// FEEL. Base ranges are GAME-DESIGN §4's (λ 380–900, A 40–150); the harness wanted longer, taller swells
    /// (windows long enough to time a landing by hand at 1000–2500 pt/s), so they are scaled by these.
    public static let seaWavelengthScale: Double = 2.0
    public static let seaAmplitudeScale: Double = 1.4
    /// Base wavelength ranges (pt, before scaling) of the three components: long swell, mid swell, short swell.
    public static let seaWavelength0: ClosedRange<Double> = 620...900
    public static let seaWavelength1: ClosedRange<Double> = 460...700
    public static let seaWavelength2: ClosedRange<Double> = 380...500
    /// Base amplitude ranges (pt, before scaling) at tier 0 and at full tier (interpolated by tier).
    public static let seaAmplitude0Low: ClosedRange<Double> = 40...80
    public static let seaAmplitude0High: ClosedRange<Double> = 90...150
    public static let seaAmplitude1Low: ClosedRange<Double> = 20...50
    public static let seaAmplitude1High: ClosedRange<Double> = 50...90
    public static let seaAmplitude2Low: ClosedRange<Double> = 8...22
    public static let seaAmplitude2High: ClosedRange<Double> = 20...40
    /// Chance a set has only two components.
    public static let seaTwoComponentChance: Double = 0.3
    /// Rogue sets: chance per set from tier 1 (never two in a row): one huge long swell.
    public static let seaRogueChance: Double = 0.07
    public static let seaRogueAmplitude: ClosedRange<Double> = 140...160
    public static let seaRogueWavelength: ClosedRange<Double> = 1000...1150
    public static let seaRogueMidAmplitude: ClosedRange<Double> = 10...20
    public static let seaRogueMidWavelength: ClosedRange<Double> = 480...620
    /// The fixed tutorial train for every seed: one long swell, crest just ahead of the start, then a long
    /// downslope (the first landing), a trough and a long gentle crest (the first launch), fixed until tutorialEnd.
    public static let tutorialEnd: Double = 4000
    public static let tutorialAmplitude: Double = 150
    public static let tutorialWavelength: Double = 1800
    public static let tutorialCrestX: Double = 200

    // MARK: Lighthouses

    /// First lighthouse at 4 km, then gaps of 5, 6, 7 km…, capped at 8 km (pt).
    public static let lighthouseFirstX: Double = 40000
    public static let lighthouseFirstGap: Double = 50000
    public static let lighthouseGapGrowth: Double = 10000
    public static let lighthouseMaxGap: Double = 80000

    // MARK: Laws

    /// Storm speed (pt/s) at `t` seconds of flight.
    public static func stormSpeed(atFlightTime t: Double) -> Double {
        let cruiseT: Double = (stormCruiseSpeed - stormBaseSpeed) / stormAccel
        if t <= cruiseT { return stormBaseSpeed + stormAccel * max(0, t) }
        return min(stormMaxSpeed, stormCruiseSpeed + stormLateAccel * (t - cruiseT))
    }

    /// Skimming gravity for tuck u.
    static func skimGravity(_ u: Double) -> Double {
        return gravity * (1 + tuckGravityFactor * u)
    }

    /// Airborne gravity for tuck u.
    static func airGravity(_ u: Double) -> Double {
        return gravity * (1 + airTuckGravityFactor * u)
    }

    /// Spread-wing lift magnitude while descending (0 while climbing).
    static func lift(_ u: Double, vx: Double, vy: Double) -> Double {
        if vy >= 0 { return 0 }
        return (1 - u) * min(liftMaxFraction * gravity, liftCoefficient * vx * vx)
    }

    /// Airborne acceleration (gravity, lift, drag) for tuck u at velocity (vx, vy).
    static func airAcceleration(u: Double, vx: Double, vy: Double, drag: Double, lift useLift: Bool) -> (ax: Double, ay: Double) {
        let l: Double = useLift ? lift(u, vx: vx, vy: vy) : 0
        var lx: Double = 0
        var ly: Double = l
        if liftPerpendicular && l > 0 {
            let sp: Double = (vx * vx + vy * vy).squareRoot()
            if sp > 1e-6 {
                lx = -vy / sp * l
                ly = vx / sp * l
            }
        }
        return (lx - drag * vx, -airGravity(u) + ly - drag * vy)
    }
}
