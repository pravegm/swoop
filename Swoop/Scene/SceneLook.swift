import CoreGraphics
import Foundation

/// Every tunable number of the scene in one place (ROUND-1 rule 7). Canvas sizes are in canvas points ("px" below);
/// sea sizes in sea points (10 pt = 1 m). Visual only: nothing here touches the simulation.
enum SceneLook {
    // MARK: Bird

    /// Canvas points per BirdArt unit at zoom 1 (the body is ≈ 0.9 units ≈ 58 px long).
    static let birdUnit: CGFloat = 64
    /// The bird resists the zoom: its drawn size ∝ zoom^(1 − this). 0.45 keeps it readable when zoomed out.
    static let birdZoomResist: CGFloat = 0.45
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
    /// Caught: the bird sits this deep (pt) in the water and bobs by this much.
    static let caughtSink: Double = 3
    static let caughtBob: Double = 2.5

    // MARK: Trail

    static let trailLife: Double = 0.30            // s of history in the slipstream ribbon
    static let trailLifeTailwind: Double = 0.62    // longer golden ribbon during a Tailwind
    static let trailMaxPoints: Int = 40
    static let trailWidth: CGFloat = 7             // px at the bird, at low speed…
    static let trailWidthFast: CGFloat = 6         // …plus this at full speed
    static let trailGlowWidth: CGFloat = 20        // px, the Tailwind ribbon's glow
    /// After a Perfect the trail is gold for this long (s), fading back.
    static let perfectGoldTime: CGFloat = 1.4

    // MARK: Sea

    /// The surface polygon never has more than this many segments (≈ 5 px each on the Duo).
    static let seaMaxSegments: Double = 220
    /// The fill reaches this far (px) below the visible bottom and past the sides.
    static let seaBottomMargin: CGFloat = 90
    static let seaSideMargin: Double = 70
    /// The bright foam line along the surface (px).
    static let foamLineWidth: CGFloat = 2.6
    /// The lit band just under the surface: width and depth (px).
    static let bandWidth: CGFloat = 12
    static let bandDepth: CGFloat = 8
    /// Visual-only ripples on top of Core's height field (pt; the bird never feels them).
    static let rippleA: Double = 1.4
    static let rippleB: Double = 0.8
    /// Storm chop: amplitude (pt) and how far ahead of the front it reaches (pt).
    static let chopAmp: Double = 9
    static let chopReach: Double = 520
    /// Crest glints (one per visible crest) and twinkles scattered on the water.
    static let crestGlintCount: Int = 10
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
    /// The sun sits ahead (u = 80 % of the width) this far above the horizon.
    static let sunU: CGFloat = 0.80
    static let sunLift: CGFloat = 108
    static let sunRadius: CGFloat = 40
    static let sunGlowSize: CGFloat = 520

    // MARK: Storm

    /// Within this many canvas widths a hint of the storm shows at the behind edge…
    static let stormHintScreens: CGFloat = 1.5
    /// …fading in over this much more.
    static let stormFadeScreens: CGFloat = 0.3
    /// The hint's cloud-edge position (px from the behind edge), far → near.
    static let stormHintMin: CGFloat = 25
    static let stormHintMax: CGFloat = 80
    static let stormWallWidth: CGFloat = 640
    /// The grey wash over the sea reaches this far (px) ahead of the cloud edge.
    static let stormShadeReach: CGFloat = 170
    static let stormShadeAlpha: CGFloat = 0.62
    static let rainCount: Int = 72
    static let rainVX: CGFloat = 230               // px/s, slanting away from the storm
    static let rainVY: CGFloat = 1150
    /// Lightning interval (s) at a full lead; it shortens as the gap closes.
    static let strikeIntervalMin: CGFloat = 2.4
    static let strikeIntervalMax: CGFloat = 6.5
    /// Caught: the calm grey wash over everything.
    static let caughtWashAlpha: CGFloat = 0.20

    // MARK: Props

    static let lighthouseScale: CGFloat = 1.15
    /// Keep drawing a passed lighthouse until it is this far (pt) behind.
    static let lighthouseKeepBehind: Double = 3000
    static let beamSpeed: CGFloat = 1.3            // rad/s of the beam's turn
    static let buoyScale: CGFloat = 1.2
    static let nearCloudSpacing: Double = 1150     // pt between the touchable clouds
    static let nearCloudHeight: CGFloat = 1000     // pt above the mean water (Core: cloud touch at ≥ 900)

    // MARK: FX

    static let skimSprayRate: CGFloat = 70         // droplets/s at the minimum speed…
    static let skimSprayRateFast: CGFloat = 300    // …plus this at full speed
    static let wakeRate: CGFloat = 40              // foam dots/s…
    static let wakeRateFast: CGFloat = 70
    static let speedLinesFrom: Double = 1300       // pt/s where the speed lines begin…
    static let speedLinesRange: Double = 900       // …and reach full strength this much faster
    static let speedLineCount: Int = 14
    static let splashBump: CGFloat = 170           // px/s impulse of the Splash camera bump
    static let bumpOmega: CGFloat = 17
    static let bumpDamping: CGFloat = 0.38
}
