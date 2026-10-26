import CoreGraphics
import Foundation

/// Every tunable number of the scene in one place (ROUND-1 rule 7). Canvas sizes are in canvas points ("px" below);
/// sea sizes in sea points (10 pt = 1 m). Visual only: nothing here touches the simulation.
enum SceneLook {
    // MARK: Bird

    /// Canvas points per BirdArt unit at zoom 1 (R2, REVIEW-1 P0-4: 64 → 84; the body is ≈ 0.9 units ≈ 76 px long).
    static let birdUnit: CGFloat = 84
    /// The bird resists the zoom: its drawn size ∝ zoom^(1 − this). R2: 0.45 → 0.6, so it stays big when zoomed out.
    static let birdZoomResist: CGFloat = 0.6
    /// The rim around the bird's body and near wing (px before the bird's scale), so it reads on any sky.
    static let birdRimWidth: CGFloat = 1.5
    /// The belly sits this far (units) below the art origin, so the physics point is the belly on the water.
    static let birdBellyOffset: CGFloat = 0.068
    /// Idle flap rates (cycles/s): hovering in the countdown, near the minimum speed, and the post-launch beat.
    static let flapRateCountdown: Double = 1.5
    static let flapRateSlow: Double = 2.4
    static let flapRateLaunch: Double = 3.0
    /// Airborne below this speed (pt/s) with the wings open, the bird flaps (instead of stalling).
    static let slowFlapSpeed: Double = 430
    /// A slow launch (below this pt/s) is followed by one beat of the wings.
    static let launchFlapSpeed: Double = 800
    /// Hover bob (pt) and its rate (rad/s) during the countdown.
    static let hoverBob: Double = 7
    static let hoverRate: Double = 2.2
    /// Caught: the bird sits this deep (pt) in the water and bobs by this much, level (REVIEW-1 P1-6).
    static let caughtSink: Double = 3
    static let caughtBob: Double = 2.5
    /// Wing paths are cached at this many tuck and flap steps (no path is built twice).
    static let wingTuckSteps: Double = 48
    static let wingFlapSteps: Double = 40

    // MARK: Trail (R2, REVIEW-1 P1-3: tapered, fading, glowing; the Tailwind is two gold strands)

    static let trailLife: Double = 0.45            // s of history
    static let trailLifeTailwind: Double = 0.6
    static let trailMaxPoints: Int = 48
    static let trailSpacing: CGFloat = 9           // px between stored points
    static let trailWidth: CGFloat = 7             // px at the bird at low speed…
    static let trailWidthFast: CGFloat = 6         // …plus this at full speed
    static let trailAlpha: CGFloat = 0.85          // at the bird, fading to 0 at the tail end
    static let trailGlowWidth: CGFloat = 2.6       // × the core width, additive
    static let strandWidth: CGFloat = 0.5          // Tailwind strands, × the core width
    static let strandWobble: CGFloat = 7           // px amplitude of the strands' sine wobble
    static let strandWave: CGFloat = 0.55          // rad per segment along the strand
    static let strandSpeed: CGFloat = 9            // rad/s the wobble travels
    /// After a Perfect the trail is gold for this long (s), fading back.
    static let perfectGoldTime: CGFloat = 1.4

    // MARK: Perfect (R2, REVIEW-1 P0-3)

    /// The gold ring grows from this to this diameter (px) over `perfectRingTime`; a second ring follows on chains ≥ 2.
    static let perfectRingFrom: CGFloat = 40
    static let perfectRingTo: CGFloat = 160
    static let perfectRingTime: CGFloat = 0.35
    static let perfectRing2Delay: CGFloat = 0.08
    /// The camera punch-in: +3 %, in 0.06 s, back out over 0.35 s.
    static let punchAmount: Double = 0.03
    static let punchAttack: Double = 0.06
    static let punchRelease: Double = 0.35
    /// While the snapshot is held (the App's 35 ms hit-stop) FX keep running on wall time for up to this long; past
    /// that the frame is a pause or a demo freeze and everything holds still.
    static let hitStopWindow: Double = 0.1

    // MARK: Sea

    /// Surface segments per visible screen width (≈ 8 px each on the Duo).
    static let seaSegmentsPerScreen: Double = 120
    /// The surface is built this far beyond the visible range (in visible widths), behind and ahead, and rebuilt only
    /// when the view leaves it, the zoom drifts, or the storm moves (QA-1 P1-6).
    static let seaBuildBehind: Double = 0.25
    static let seaBuildAhead: Double = 0.9
    static let seaRebuildZoomDrift: CGFloat = 1.25
    static let seaRebuildStormMove: Double = 150
    static let seaSideMargin: Double = 70
    /// The fill's fixed vertical extent (sea y): its depth gradient is pinned to it, so a rebuild never shifts colours.
    static let seaFillTop: CGFloat = 700
    static let seaFillBottom: CGFloat = -1400
    /// The bright foam line along the surface (px).
    static let foamLineWidth: CGFloat = 2.6
    /// The lit band just under the surface: width and depth (px).
    static let bandWidth: CGFloat = 12
    static let bandDepth: CGFloat = 8
    /// Storm chop: amplitude (pt) and how far ahead of the front it reaches (pt). Static in space.
    static let chopAmp: Double = 9
    static let chopReach: Double = 520
    /// Crest glints (one per crest in the built range) and twinkles scattered on the water.
    static let crestGlintCount: Int = 16
    static let seaSparkleCount: Int = 20
    static let seaSparkleCell: Double = 150

    // MARK: Backdrop (canvas px, u-space: 0 = behind edge … width = ahead edge)

    static let farBackParallax: CGFloat = 0.10
    static let farFrontParallax: CGFloat = 0.24
    static let cloudParallax: CGFloat = 0.035
    static let cloudDrift: CGFloat = 7             // px/s, the far clouds drift even when hovering
    /// Far swell layers sit this far above the near sea's mean line: base + extra × zoom.
    static let farBackLift0: CGFloat = 62
    static let farBackLift1: CGFloat = 40
    static let farFrontLift0: CGFloat = 26
    static let farFrontLift1: CGFloat = 30
    /// The far swells repeat every this many px (their paths are built once and slid).
    static let farPeriod: CGFloat = 1152
    /// The sun sits ahead (u = 80 % of the width) this far above the horizon.
    static let sunU: CGFloat = 0.80
    static let sunLift: CGFloat = 108
    static let sunRadius: CGFloat = 40
    static let sunGlowSize: CGFloat = 520
    /// The crease glint: a band ±this px around the horizon, at this alpha (brighter only on milestones).
    static let creaseHalfHeight: CGFloat = 40
    static let creaseAlpha: CGFloat = 0.08
    static let creasePulseAlpha: CGFloat = 0.12

    // MARK: Storm (R2, REVIEW-1 P1-6: always on screen, scaled to the gap)

    /// Closeness 0 (far) … 1 (on the bird) runs over this many canvas widths of gap.
    static let stormRangeScreens: CGFloat = 1.5
    /// The cloud edge never sits further behind than this (px from the behind edge), far → near.
    static let stormEdgeFar: CGFloat = 70
    static let stormEdgeNear: CGFloat = 190
    /// The wall's height as a fraction of the sky above its base, far → near.
    static let stormHeightFar: CGFloat = 0.42
    static let stormHeightNear: CGFloat = 1.15
    /// The wall's opacity far → near.
    static let stormAlphaFar: CGFloat = 0.6
    static let stormAlphaNear: CGFloat = 1.0
    /// The grey wash over the sea reaches this far (px) ahead of the cloud edge; opacity far → near.
    static let stormShadeReach: CGFloat = 170
    static let stormShadeFar: CGFloat = 0.25
    static let stormShadeNear: CGFloat = 0.65
    static let rainCount: Int = 72
    static let rainVX: CGFloat = 230               // px/s, slanting away from the storm
    static let rainVY: CGFloat = 1150
    static let rainSheetCount: Int = 4
    /// Lightning interval (s) at a full lead; it shortens as the gap closes. Flash peak (QA-1 P2-15: lower).
    static let strikeIntervalMin: CGFloat = 2.4
    static let strikeIntervalMax: CGFloat = 6.5
    static let flashPeak: CGFloat = 0.14
    /// Caught: the calm grey wash (≈ 30 % desaturation), the sun dimmed by half, over 1.5 s.
    static let caughtWashAlpha: CGFloat = 0.30
    static let caughtSunDim: CGFloat = 0.5
    static let caughtEase: CGFloat = 1.5

    // MARK: Props

    /// The lighthouse stands on the far swells (R2, REVIEW-1 P0-7): a parallax depth layer, so at the moment of the
    /// pass it is beside the bird, a little ahead, and it drifts back slowly instead of vanishing behind.
    static let lighthouseParallax: CGFloat = 0.3
    static let lighthouseLead: CGFloat = 120       // px ahead of the bird at the pass
    static let lighthouseScale: CGFloat = 0.9      // × (0.55 + 0.45 zoom)
    static let beamSpeed: CGFloat = 1.3            // rad/s of the beam's turn
    static let buoyScale: CGFloat = 1.2
    /// The touchable cloud band: overlapping clouds whose bottoms sit this far under Core's cloud height (pt), so the
    /// bird is inside a cloud whenever `cloudTouched` fires, even over a trough (QA-1 P2-6).
    static let cloudBandDrop: CGFloat = 170
    static let nearCloudSpacing: Double = 480

    // MARK: FX

    static let skimSprayRate: CGFloat = 70         // droplets/s at the minimum speed…
    static let skimSprayRateFast: CGFloat = 300    // …plus this at full speed
    static let wakeRate: CGFloat = 40              // foam dots/s…
    static let wakeRateFast: CGFloat = 70
    /// Speed lines (R2, REVIEW-1 P1-8): from 900 pt/s, full strength this much faster, gold above 90 % of max speed.
    static let speedLinesFrom: Double = 900
    static let speedLinesRange: Double = 900
    static let goldSpeedFraction: Double = 0.9
    static let speedLineCount: Int = 16
    /// Above this speed the camera pulls out by up to `fastPullOut` (REVIEW-1 P1-8: 2 %).
    static let fastPullOutFrom: Double = 1800
    static let fastPullOutRange: Double = 600
    static let fastPullOut: Double = 0.02
    static let splashBump: CGFloat = 170           // px/s impulse of the Splash camera bump
    static let bumpOmega: CGFloat = 17
    static let bumpDamping: CGFloat = 0.38
    /// How often (frames) the scene re-reads the driver's bird and sky.
    static let cosmeticsCheckFrames: Int = 30
}
