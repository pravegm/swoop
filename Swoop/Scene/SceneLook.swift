import CoreGraphics
import Foundation

/// The scene's own colours per sky (ART-DIRECTION §2, ART-S1). Every value is a designed stop, never a mix of two
/// complementary colours (blue + orange = grey, teal + gold = khaki). Core's `Sky` stays as it is, for tiles and tints.
struct ScenePalette: Equatable {
    // Sky: five fixed stops at 0, 0.45, 0.80, 0.96, 1.0 (top → horizon).
    var zenith: RGBA
    var mid: RGBA
    var low: RGBA
    var horizon: RGBA
    var sunline: RGBA
    // Sun.
    var sunDisk: RGBA
    var sunGlow: RGBA
    /// Monsoon: a veiled sun (the disk at 40 %, the glow 1.6×).
    var sunDiskAlpha: CGFloat
    var sunGlowScale: CGFloat
    // Sea, far to near.
    var farBack: RGBA
    var farFront: RGBA
    var nearCrest: RGBA
    var nearMean: RGBA
    var nearDeep: RGBA
    var foam: RGBA
    // Storm.
    var stormBody: RGBA
    var stormTop: RGBA
    var stormRim: RGBA
    var rain: RGBA
    // Bird and accents.
    var birdKeyRim: RGBA
    var cloud: RGBA
    var glitter: RGBA
    /// Low-contrast skies (Monsoon): every bird gets the dark contour.
    var darkContourForAll: Bool

    /// The reward gold, the same in every sky: core, highlight, deep.
    static let rewardGold = RGBA(hex: 0xFFD45E)
    static let rewardHighlight = RGBA(hex: 0xFFF3C4)
    static let rewardDeep = RGBA(hex: 0xE8A93A)
    /// The light bird's contour ink (1.25 pt at 55 %), the gutter / vignette ink.
    static let ink = RGBA(hex: 0x0E2438)
    static let gutter = RGBA(hex: 0x04121F)

    static func palette(_ id: SkyID) -> ScenePalette {
        func c(_ hex: UInt32) -> RGBA { RGBA(hex: hex) }
        switch id {
        case .goldenHour:
            return ScenePalette(zenith: c(0x2B4F8F), mid: c(0x8C7CB6), low: c(0xF0A07A), horizon: c(0xFFD18C),
                                sunline: c(0xFFE3A8), sunDisk: c(0xFFF3D1), sunGlow: c(0xFFC46B), sunDiskAlpha: 1,
                                sunGlowScale: 1, farBack: c(0x8FB0C8), farFront: c(0x4F86A6), nearCrest: c(0x3D8FB0),
                                nearMean: c(0x1C5A7C), nearDeep: c(0x0A2B44), foam: c(0xFFF6E6), stormBody: c(0x3A4252),
                                stormTop: c(0x262C38), stormRim: c(0xFFD9A6), rain: c(0xA9B6C6), birdKeyRim: c(0xFFE2A8),
                                cloud: c(0xF6C7A6), glitter: c(0xFFF0C2), darkContourForAll: false)
        case .roseDusk:
            return ScenePalette(zenith: c(0x2E2A5E), mid: c(0x7A5C9E), low: c(0xE68A9A), horizon: c(0xFFC2A8),
                                sunline: c(0xFFD6C0), sunDisk: c(0xFFE7DA), sunGlow: c(0xFF9E8A), sunDiskAlpha: 1,
                                sunGlowScale: 1, farBack: c(0xA79BC4), farFront: c(0x6A6AA0), nearCrest: c(0x6F79B5),
                                nearMean: c(0x3A3F78), nearDeep: c(0x171A3E), foam: c(0xFFEFF2), stormBody: c(0x3B3550),
                                stormTop: c(0x252136), stormRim: c(0xFFC9C0), rain: c(0xB3A9C9), birdKeyRim: c(0xFFD3C2),
                                cloud: c(0xF2B4BE), glitter: c(0xFFE0D6), darkContourForAll: false)
        case .northernLights:
            return ScenePalette(zenith: c(0x060D22), mid: c(0x0C1F3A), low: c(0x12384A), horizon: c(0x1D5E60),
                                sunline: c(0x2A7A70), sunDisk: c(0xDFFFF0), sunGlow: c(0x59F0B8), sunDiskAlpha: 1,
                                sunGlowScale: 1, farBack: c(0x24525A), farFront: c(0x163E4C), nearCrest: c(0x1E5868),
                                nearMean: c(0x0C2836), nearDeep: c(0x040F18), foam: c(0xCFFAF0), stormBody: c(0x232C3A),
                                stormTop: c(0x151B26), stormRim: c(0x7CF5C8), rain: c(0x8FB8C0), birdKeyRim: c(0xBFFFE6),
                                cloud: c(0x1C3A4E), glitter: c(0xA8FFE0), darkContourForAll: false)
        case .monsoon:
            return ScenePalette(zenith: c(0x4E6470), mid: c(0x7F959A), low: c(0xB9C8C2), horizon: c(0xE4ECE2),
                                sunline: c(0xEEF3EA), sunDisk: c(0xFFFBEA), sunGlow: c(0xF4F1D8), sunDiskAlpha: 0.4,
                                sunGlowScale: 1.6, farBack: c(0x9FB5B0), farFront: c(0x6E8F8A), nearCrest: c(0x5E8A82),
                                nearMean: c(0x2E5650), nearDeep: c(0x12302C), foam: c(0xF4F8F2), stormBody: c(0x2F3A40),
                                stormTop: c(0x1E262B), stormRim: c(0xE8F0E6), rain: c(0xC2CEC9), birdKeyRim: c(0xFFFFFF),
                                cloud: c(0xD5DED8), glitter: c(0xFFFFFF), darkContourForAll: true)
        case .moonrise:
            return ScenePalette(zenith: c(0x0A1230), mid: c(0x16224A), low: c(0x2A3C6E), horizon: c(0x4A6296),
                                sunline: c(0x5A74A8), sunDisk: c(0xF4F1E6), sunGlow: c(0x9DB4FF), sunDiskAlpha: 1,
                                sunGlowScale: 1, farBack: c(0x3A5288), farFront: c(0x26396A), nearCrest: c(0x2E4A80),
                                nearMean: c(0x12224A), nearDeep: c(0x060D22), foam: c(0xE2EAFF), stormBody: c(0x1E2436),
                                stormTop: c(0x121626), stormRim: c(0xC9D6FF), rain: c(0x8C9CC4), birdKeyRim: c(0xDDE6FF),
                                cloud: c(0x3C4E7E), glitter: c(0xE6ECFF), darkContourForAll: false)
        }
    }
}

/// Every tunable number of the scene in one place (ROUND-1 rule 7). Canvas sizes are in canvas points ("px" below);
/// sea sizes in sea points (10 pt = 1 m). Visual only: nothing here touches the simulation.
enum SceneLook {
    // MARK: Bird (ART §4, ART-S8)

    /// Canvas points per BirdArt unit at zoom 1: the 0.9-unit body is 96 pt on the Duo (10 % of the width).
    static let birdUnit: CGFloat = 107
    /// The bird resists the zoom: its drawn size ∝ zoom^(1 − this). 0.7 keeps it ≥ 66 pt fully zoomed out.
    static let birdZoomResist: CGFloat = 0.7
    /// Light birds: the ink contour (1.25 pt at 55 %). Dark birds: the key rim at 1.5 pt.
    static let birdContourWidth: CGFloat = 1.25
    static let birdContourAlpha: CGFloat = 0.55
    static let birdKeyRimWidth: CGFloat = 1.5
    static let birdKeyRimAlpha: CGFloat = 0.8
    /// Below this luminance a bird counts as dark (key rim + halo instead of the ink contour).
    static let darkBirdLuminance: Double = 0.42
    /// The dark bird's halo over the sea: radius beyond the body (px) and opacity.
    static let birdHaloRadius: CGFloat = 28
    static let birdHaloAlpha: CGFloat = 0.10
    /// The belly's lower third is this much darker.
    static let bellyDarken: Double = 0.12
    /// Fully tucked the bird stretches 6 % longer and 8 % thinner (a dart).
    static let tuckStretchX: CGFloat = 1.06
    static let tuckStretchY: CGFloat = 0.92
    /// Nose angle offsets while airborne at tuck 0 / 0.5 / 1 (rad): +4°, −6°, −10°.
    static let noseSpread: CGFloat = 0.07
    static let noseHalf: CGFloat = -0.105
    static let noseTucked: CGFloat = -0.175
    /// The touchdown squash: 0.92 × 1.08 for 90 ms, then a spring back.
    static let squashTime: CGFloat = 0.09
    static let squashX: CGFloat = 1.08
    static let squashY: CGFloat = 0.92
    /// The contact shadow while skimming: 1.2 body lengths × 6 pt in `nearDeep` at 35 %, gone by 60 pt of height.
    static let shadowLength: CGFloat = 1.2
    static let shadowHeight: CGFloat = 6
    static let shadowAlpha: CGFloat = 0.35
    static let shadowFadeHeight: Double = 60
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
    /// Caught: the bird sits this deep (pt) in the water and bobs by this much, level.
    static let caughtSink: Double = 3
    static let caughtBob: Double = 2.5
    /// Wing paths are cached at this many tuck and flap steps (no path is built twice).
    static let wingTuckSteps: Double = 48
    static let wingFlapSteps: Double = 40
    /// The bird's screen point goes to the App (its callout) at most this often (UX-S1: ≤ 30 Hz).
    static let birdPointInterval: Double = 1.0 / 30.0

    // MARK: The title → play morph (ART §7, UX-S3)

    static let morphTime: Double = 0.6
    /// Home's title-bird box (SwiftUI y down): y 10 … 264 across the whole width (UX §3).
    static let titleBoxTop: CGFloat = 10
    static let titleBoxHeight: CGFloat = 254

    // MARK: Trail (ART §5, ART-S10)

    static let trailLife: Double = 0.45            // s of history
    static let trailLifeTailwind: Double = 0.6
    static let trailMaxPoints: Int = 48
    static let trailSpacing: CGFloat = 9           // px between stored points
    static let trailWidth: CGFloat = 9             // px at the bird at low speed…
    static let trailWidthFast: CGFloat = 5         // …plus this at full speed (14)
    static let trailAlpha: CGFloat = 0.8           // the core at the bird
    /// The core is drawn as nested tapered ribbons starting further along (a smooth fade with no seams).
    static let trailLayers: Int = 3
    static let trailGlowWidth: CGFloat = 2.0       // × the core width, additive
    static let trailGlowAlphaLow: CGFloat = 0.12
    static let trailGlowAlphaHigh: CGFloat = 0.35
    static let strandWidth: CGFloat = 0.4          // Tailwind strands, × the core width
    static let strandWobble: CGFloat = 6           // px amplitude of the strands' sine wobble
    static let strandWave: CGFloat = 0.55          // rad per point along the strand
    static let strandSpeed: CGFloat = 9            // rad/s the wobble travels
    /// After a Perfect the trail is gold for this long (s), fading back.
    static let perfectGoldTime: CGFloat = 1.4

    // MARK: Perfect (ART §5, ART-S12)

    /// The gold ring grows 40 → 170 px (ease-out cubic) over 0.38 s, riding with the bird as a 1 : 0.32 water
    /// ellipse; a second, paler ring follows on chains ≥ 2; a faint ripple stays at the touchdown.
    static let perfectRingFrom: CGFloat = 40
    static let perfectRingTo: CGFloat = 170
    static let perfectRingTime: CGFloat = 0.38
    static let perfectRing2Delay: CGFloat = 0.08
    static let ringAspect: CGFloat = 0.32
    /// Reduce Motion: the ring appears at 120 px and fades over 0.3 s.
    static let ringStill: CGFloat = 120
    /// The ring rides this far behind the bird (px) so it stays ≥ 120 pt from the fold (ART-S15).
    static let ringBehind: CGFloat = 16
    /// The camera punch-in: +3 %, in 0.06 s, back out over 0.35 s.
    static let punchAmount: Double = 0.03
    static let punchAttack: Double = 0.06
    static let punchRelease: Double = 0.35
    /// While the snapshot is held (the App's hit-stop) FX keep running on wall time for up to this long; past that
    /// the frame is a pause or a demo freeze and everything holds still.
    static let hitStopWindow: Double = 0.1

    // MARK: Sea (ART §3, ART-S4/S5)

    static let seaSegmentsPerScreen: Double = 120
    static let seaBuildBehind: Double = 0.25
    static let seaBuildAhead: Double = 0.9
    static let seaRebuildZoomDrift: CGFloat = 1.25
    static let seaRebuildStormMove: Double = 150
    static let seaSideMargin: Double = 70
    /// The fill's fixed vertical extent (sea y): its depth gradient is pinned to it, so a rebuild never shifts colours.
    static let seaFillTop: CGFloat = 700
    static let seaFillBottom: CGFloat = -1400
    static let foamLineWidth: CGFloat = 3.0
    /// The soft sub-surface band (not a second outline).
    static let bandWidth: CGFloat = 18
    static let bandDepth: CGFloat = 14
    static let bandAlpha: CGFloat = 0.18
    /// Lit faces: the faces turned toward the sun (dh/dx < 0) carry a lighter strip (two soft layers).
    static let litFaceWidth: CGFloat = 46
    static let litFaceAlpha: CGFloat = 0.12
    /// Storm chop: amplitude 9 → 14 pt as the storm closes, reaching this far (pt) ahead of the front. Static in space.
    static let chopAmp: Double = 9
    static let chopAmpClose: Double = 5
    static let chopReach: Double = 520
    /// Crest glints (74 × 7 streaks): only on crests within ±0.30 w of the sun, at α 0.55 × (1 − |dx| / 0.30 w),
    /// up to 0.85 at ≥ 90 % of max speed.
    static let crestGlintCount: Int = 16
    static let glintReach: CGFloat = 0.30
    static let glintAlpha: CGFloat = 0.55
    static let glintAlphaFast: CGFloat = 0.85
    /// Glints on the water: short dashes near the sun's half (the 4-point stars are kept for the Perfect).
    static let seaSparkleCount: Int = 12
    static let seaSparkleCell: Double = 150

    // MARK: Backdrop (ART §3, ART-S2/S3)

    static let farBackParallax: CGFloat = 0.08
    static let farFrontParallax: CGFloat = 0.22
    static let cloudParallax: CGFloat = 0.02
    static let cloudDrift: CGFloat = 6             // px/s (stops under Reduce Motion)
    /// The far layers sit this far above the near sea's mean line: base + extra × zoom (together ≤ 14 % of h).
    static let farBackLift0: CGFloat = 34
    static let farBackLift1: CGFloat = 18
    static let farFrontLift0: CGFloat = 14
    static let farFrontLift1: CGFloat = 14
    /// Amplitudes (px) and cycles per `farPeriod` of the far layers' two sines.
    static let farBackAmp: CGFloat = 2.5
    static let farFrontAmp: CGFloat = 5
    static let farPeriod: CGFloat = 1152
    static let farBackCycles: (CGFloat, CGFloat) = (14, 31)
    static let farFrontCycles: (CGFloat, CGFloat) = (9, 19)
    /// The far-front's top fades into the far-back over this many px (haze).
    static let farFrontHaze: CGFloat = 30
    static let farShadeAlpha: CGFloat = 0.5
    /// The sun sits ahead (u = 80 % of the width), 0.16 h above the horizon, its centre ≤ the visible top − 90 pt.
    static let sunU: CGFloat = 0.80
    static let sunLiftFraction: CGFloat = 0.16
    static let sunTopClearance: CGFloat = 90
    static let sunRadius: CGFloat = 40
    static let sunGlowSize: CGFloat = 520
    /// The glitter column under the sun: 0.12 w wide.
    static let glitterWidth: CGFloat = 0.12
    /// The horizon haze: 60 pt of the horizon colour at 0.5 (0.75 on a milestone when there is no fold).
    static let hazeHeight: CGFloat = 60
    static let hazeAlpha: CGFloat = 0.5
    static let hazePulseAlpha: CGFloat = 0.75
    /// The crease glint: a band ±this px around the horizon, at this alpha (brighter only on milestones). Duo only.
    static let creaseHalfHeight: CGFloat = 40
    static let creaseAlpha: CGFloat = 0.08
    static let creasePulseAlpha: CGFloat = 0.12
    /// The book-gutter shade on a tuck: 60 pt per side of the fold, α 0.10 × tuck (Duo only, ART §8).
    static let gutterWidth: CGFloat = 60
    static let gutterAlpha: CGFloat = 0.10
    /// The art fold band (±28 pt around the crease): the sun, rings and the storm's resting edge stay out of it.
    static let foldArtBand: CGFloat = 28

    // MARK: Storm (ART §3, ART-S6/S7)

    /// Closeness 0 (far) … 1 (on the bird) runs over this many canvas widths of gap.
    static let stormRangeScreens: CGFloat = 1.5
    /// The cloud edge never sits further behind than this (px from the behind edge), far → near.
    static let stormEdgeFar: CGFloat = 70
    static let stormEdgeNear: CGFloat = 190
    /// Caught: the sweep carries the edge to this fraction of the width (past the fold band).
    static let stormCaughtEdge: CGFloat = 0.62
    /// The wall's height as a fraction of the *visible* sky above its base, far → near.
    static let stormHeightFar: CGFloat = 0.42
    static let stormHeightNear: CGFloat = 1.15
    /// The wall's opacity far → near.
    static let stormAlphaFar: CGFloat = 0.6
    static let stormAlphaNear: CGFloat = 1.0
    /// The lit rim along the anvil's upper edge (px).
    static let stormRimWidth: CGFloat = 3
    /// The sky shade: α 0.10 + 0.40 c, reaching edge + 0.45 w, capped at 0.5 at the bird.
    static let skyShadeBase: CGFloat = 0.10
    static let skyShadeClose: CGFloat = 0.40
    static let skyShadeReach: CGFloat = 0.45
    static let skyShadeCapAtBird: CGFloat = 0.5
    /// The grey wash over the sea reaches this far (px) ahead of the cloud edge; opacity far → near.
    static let stormShadeReach: CGFloat = 170
    static let stormShadeFar: CGFloat = 0.25
    static let stormShadeNear: CGFloat = 0.65
    /// The sun dims by 0.15 c in play, and by half when caught.
    static let stormSunDim: CGFloat = 0.15
    static let rainCount: Int = 72
    static let rainVX: CGFloat = 230               // px/s, slanting away from the storm
    static let rainVY: CGFloat = 1150
    static let rainSheetCount: Int = 4
    static let strikeIntervalMin: CGFloat = 2.4
    static let strikeIntervalMax: CGFloat = 6.5
    static let flashPeak: CGFloat = 0.14
    /// Caught: the calm grey wash (≈ 30 % desaturation; the far page takes 60 % of it), the sun dimmed by half, over
    /// 1.5 s ease-in-out.
    static let caughtWashAlpha: CGFloat = 0.30
    static let caughtWashFarPage: CGFloat = 0.6
    static let caughtSunDim: CGFloat = 0.5
    static let caughtEase: CGFloat = 1.5

    // MARK: Props (ART-S13)

    static let lighthouseParallax: CGFloat = 0.3
    static let lighthouseLead: CGFloat = 120       // px ahead of the bird at the pass
    static let lighthouseScale: CGFloat = 0.9      // × (0.55 + 0.45 zoom)
    static let beamSpeed: CGFloat = 1.3            // rad/s of the beam's turn
    static let beamAlpha: CGFloat = 0.25
    static let lampGlowSize: CGFloat = 60
    static let buoyScale: CGFloat = 1.2
    static let cloudBandDrop: CGFloat = 170
    static let nearCloudSpacing: Double = 480

    // MARK: FX (ART §5)

    static let skimSprayRate: CGFloat = 70
    static let skimSprayRateFast: CGFloat = 300
    static let wakeRate: CGFloat = 40
    static let wakeRateFast: CGFloat = 70
    /// Speed lines (ART-S11): from 900 pt/s, at most 10, only within ±0.18 h of the bird and below the top 72 pt,
    /// 80–220 px long, α ≤ 0.28, gold above 90 % of max speed. Reduce Motion: a 6 % edge vignette instead.
    static let speedLinesFrom: Double = 900
    static let speedLinesRange: Double = 900
    static let goldSpeedFraction: Double = 0.9
    static let speedLineCount: Int = 10
    static let speedLineBand: CGFloat = 0.18
    static let speedLineTopClear: CGFloat = 72
    static let speedLineAlpha: CGFloat = 0.28
    static let speedVignetteAlpha: CGFloat = 0.06
    /// Above this speed the camera pulls out by up to `fastPullOut`.
    static let fastPullOutFrom: Double = 1800
    static let fastPullOutRange: Double = 600
    static let fastPullOut: Double = 0.02
    /// A Tailwind start pulls out 2 % for 0.5 s and flares the sun locally to 0.25 (never full-screen).
    static let tailwindPullOut: Double = 0.02
    static let flarePeak: CGFloat = 0.25
    /// The Splash camera bump (impulse px/s): ≤ 6 pt of travel.
    static let splashBump: CGFloat = 75
    static let bumpOmega: CGFloat = 17
    static let bumpDamping: CGFloat = 0.38
    /// Splash: 18–26 hard drops and one mist puff ≤ 90 px at α ≤ 0.5.
    static let splashDropsMin: Int = 18
    static let splashDropsMax: Int = 26
    static let splashMist: CGFloat = 90
    /// How often (frames) the scene re-reads the driver's bird and sky.
    static let cosmeticsCheckFrames: Int = 30
}
