import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// A moment's strongest beat (ROUND-10 P1-5), for the App's CI freezes: the Perfect with its ring at full size and
/// its burst out, the catch with the storm front crossing over the bird, and the school storm's recoil at its furthest.
enum ScenePeak: Equatable {
    case perfect
    case caught
    case recoil
}

/// The SpriteKit view of the flight (ARCHITECTURE "Scene API"). It draws only from snapshots, the sea and events, and
/// owns the cosmetic state: the camera, spray, wake, rings, clouds, the lighthouse beam and the storm. It never
/// changes game state.
///
/// Composition (canvas 952 × 670, origin bottom-left; "u-space" = canvas x measured from the behind edge, flipped
/// when `layout.mirrored`):
///
/// - **backRoot** (z −100, u-space): the backdrop.
///   - The sky, stars / aurora, the sun, the cloud streaks.
///   - The storm group at −16: sky shade, anvil, rim, lightning.
///   - The horizon haze, the far-back sea.
///   - The lighthouse at −12.5.
///   - The far-front sea, the haze and shade, the glitter column.
/// - **world** (z 0, sea space), back to front:
///   - the touchable clouds −40, the PB buoy −11;
///   - the near sea −10…−8.8, the contact shadow −5.9;
///   - rings and foam −6, the trail 14, spray 15, the bird 20, sparkles 30.
/// - **shadeRoot** (z 5, u-space): the storm's grey wash and rain sheets over the sea (under the bird).
/// - **frontRoot** (z 60, u-space): rain, the caught wash, the lightning flash, speed lines, the Tailwind flare.
/// - **titleRoot** (z 70): the title → play morph (UX-S3).
/// - **The fold** (z 78–80, Duo only): the gutter shade on a tuck, and the horizon glint.
///
/// **The world node is the camera.** It is scaled by the zoom (x flipped when mirrored) and positioned so the bird sits
/// at 30 % (70 % mirrored). World children use sea coordinates minus `originX`, a rebased origin that keeps numbers
/// small on long flights.
///
/// **Clocks.** The camera follows the simulation's clock. FX run on an "FX clock": the simulation's, plus wall time
/// while the snapshot is held for up to `hitStopWindow` (the App's hit-stop).
///
/// **For the App:**
/// - `onBirdPoint` reports the bird's position on screen (UX-S1, ART-S14).
/// - `playTitleMorph(tuck:)` runs the Home → play morph (UX-S3).
/// - `effectsQuality` scales particles and rain for thermal state and Low Power (UX-D5).
/// - `fineDetail` false hides fine sparkle while a fold blur may be showing (UX-D3).
@MainActor
final class FlightScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no camera bump or punch-in, no lightning flash, a gentle Tailwind flare, fewer particles, an edge
    /// vignette instead of speed lines, and a crossfade instead of the morph.
    var reduceMotion: Bool = false {
        didSet {
            fx.reduceMotion = reduceMotion
            storm.reduceMotion = reduceMotion
            guides.reduceMotion = reduceMotion
        }
    }

    var layout: ScreenLayout {
        didSet {
            if layout != oldValue { applyLayout() }
        }
    }

    /// Thermal / Low Power (UX-D5): 1 normally, about 0.7 at `.serious` or in Low Power. Scales particles; rain goes to
    /// 60 % below 0.8.
    var effectsQuality: CGFloat = 1 {
        didSet {
            fx.particleScale = min(max(effectsQuality, 0.3), 1)
            storm.rainScale = effectsQuality < 0.8 ? 0.6 : 1
        }
    }

    /// False while the App's fold-blur guard is up (UX-D3): the fine sparkle (glints, dash glints, speed lines) is
    /// hidden so a half-blurred page shows only big shapes. The scene also does this itself for the first 2 s of a
    /// run (ART §8).
    var fineDetail: Bool = true

    /// The bird's position on screen, reported at most 30 times a second (UX-S1, ART-S14). The point is in the
    /// SpriteKit view's coordinates (UIKit / SwiftUI points, y down, origin at the view's top-left) when the scene is
    /// presented; else in canvas points with y down. The App anchors the "Perfect ×N" callout to it.
    var onBirdPoint: ((CGPoint) -> Void)?
    /// The bird's position in canvas points (SpriteKit, y up), every frame.
    private(set) var birdCanvasPoint: CGPoint = .zero
    /// The same in view points (y down), as last reported.
    private(set) var birdScreenPoint: CGPoint = .zero

    /// Frames drawn since the scene was made (CI waits for 120).
    private(set) var drawnFrames = 0
    /// The drawn zoom and the camera's display scale this frame (tests, tuning).
    private(set) var drawnZoom: CGFloat = 1
    private(set) var displayScale: CGFloat = 1
    /// Sea surface rebuilds so far (QA-1 P1-6, QA-2 P2-2).
    var seaRebuilds: Int { seaView.rebuildCount }
    /// Whether the lighthouse is on screen, and where (u-space).
    private(set) var lighthouseU: CGFloat?
    /// The storm's front edge this frame (u-space), and the sun's brightness (tests).
    var stormEdgeU: CGFloat { storm.edgeU }
    var sunBrightness: CGFloat { backdrop.sunBrightness }
    /// The storm wall's top this frame (canvas y; tests: it stays clear of the HUD).
    var stormTopY: CGFloat { storm.wallTop }
    /// The morph's progress 0…1 (1 = done or not running).
    private(set) var morphProgress: CGFloat = 1
    /// The sun's centre in canvas points (SpriteKit, y up), so the App can keep text off it (UX P1-3).
    private(set) var sunCanvasPoint: CGPoint = .zero
    /// The storm's lead-meter fill this frame (`SceneStormMap.meterFill`), for tests and the HUD.
    private(set) var stormMeterFill: CGFloat = 1
    /// False in store-capture mode: no book-gutter shade (REVIEW-3 juror #26).
    var gutterEnabled: Bool = true
    /// Home (R5b, App NEEDS "attract bird crosses the wordmark"): in `.attract` the bird and its trail stay below this
    /// canvas y (SpriteKit, y up) minus `attractClearance`. nil = no limit.
    var attractCeiling: CGFloat?
    /// Home: the wordmark and caption rects in view points (y down, SwiftUI); the attract bird stays
    /// `attractClearance` below the lowest one. Empty = no limit. Combined with `attractCeiling` (the lower wins).
    var homeTextRects: [CGRect] = []
    /// The margin under the ceiling: the text rects + 24 pt, plus room for the bird's own half-height and its trail.
    static let attractClearance: CGFloat = 24 + 36

    // MARK: Flight School (ROUND-6 D2, ART-FLIGHT-SCHOOL §2, SC1–SC2)

    /// The practice sea: the "Morning practice" palette, no storm at all (no wall, sky shade, rain or chop), calmer far
    /// swells (70 %) and a higher sun (0.24 h). Set it for Flight School's Sea steps; the scene also turns it on by
    /// itself whenever the snapshot reports no storm (Core's practice sea: a gap ≥ 500,000 pt). A session starts with
    /// the look already on (no fade); later changes crossfade over 2 s.
    var practiceSea: Bool = false
    /// A guide on the water (step 3 fold path, step 4 open mark, step 5 landing ring). The "…Ahead" cases are placed
    /// on the sea ahead of the bird on the next frame, then stay put. A Perfect in the landing ring bursts it.
    var guide: SceneGuide = .none {
        didSet { pendingGuide = true }
    }
    /// Step 4's slow motion: a soft 6 % white bloom over the bird's half-page (the only visual cue of the slow time).
    var slowMoBloom: Bool = false
    /// The practice look now, 0 (the player's sky) … 1 (Morning practice), eased (tests).
    private(set) var practiceLook: CGFloat = 0
    /// Whether any of the storm is drawn this frame, and the rightmost u it can reach (tests: the fold band).
    var stormShown: Bool { storm.isShown }
    var stormDrawnRightU: CGFloat { storm.drawnRightU }
    /// Storm glows so far (strikes included; tests).
    var stormGlows: Int { storm.glowCount }
    /// The lighthouse lamp's centre in canvas points (SpriteKit, y up) while the tower is on screen, so the App can keep
    /// the reached card off the beam's source; nil when no tower shows.
    private(set) var lampCanvasPoint: CGPoint?
    /// The reached beam (tests).
    var reachedBeamShown: Bool { reached.beamShown }
    var reachedBeamAngle: CGFloat { reached.beamAngle }
    /// The guide on the water now, resolved to sea positions (tests).
    var shownGuide: SceneGuide { guides.shown }
    /// The u-space roots' x scale: −1 when mirrored, so u-space motion (rain, gusts, speed lines) flips with it (tests).
    var uSpaceXScale: CGFloat { frontRoot.xScale }

    /// Step 7 (ART-FLIGHT-SCHOOL §2): the palette crossfades to the player's sky over 2 s while the storm rolls in
    /// from the bird page's outer edge to `stormEdgeFar` (no catch); one glow inside it (no bolt, no flash) names it at
    /// +1.2 s, and the rain starts last. The App fades in the meter and the goal chip at +1.6 s.
    func rollInStorm() {
        guard rollAge == nil else { return }
        rollAge = 0
        rollGlowDone = false
        storm.deferGlows(SceneLook.rollInTime + 1)
    }

    // MARK: Round 9 (ART-ROUND-9 SR1–SR7, UX-ROUND-9 §1)

    /// SR1: the guide gull flies `move` first. Pass Core's ghost replay (`practiceGhostPath(step:)` mapped one for one
    /// onto `SceneGhostSample`: sea x / y, t from 0, tuck) when there is one; without it the scene flies its own
    /// stand-in on the sea ahead of the bird. While it flies the camera zooms to ≤ 0.78 and looks 0.22 w ahead.
    func playGhost(_ move: SceneGhostMove, path: [SceneGhostSample]? = nil) {
        if let p = path, p.count >= 2 {
            ghost.play(move, path: p, fromCore: true)
            return
        }
        let bx = Double(snapshot.position.x)
        let lead = Double(SceneLook.ghostLead) / max(Double(drawnZoom), 0.3)
        let ring = guides.ringCenter.map { Double($0.x) }
        let synth = SceneGhostFlight.synthesize(move, birdX: bx, lead: lead, ringX: ring,
                                                height: { x in self.seaHeight(x) })
        ghost.play(move, path: synth, fromCore: false)
    }

    /// SR1, App-driven: the guide gull's pose this frame (the App plays Core's `PracticeGhost` path at its own pace
    /// and maps each `GhostSample` here). Set it every frame; nil makes a showing ghost dissolve into its motes (the
    /// player's turn, `onGhostFinished`). The camera makes room as for `playGhost`.
    var guideGhost: SceneGhostPose? {
        didSet { ghost.drive(guideGhost) }
    }

    /// Takes the guide gull away at once (its dots fade on their own).
    func stopGhost() { ghost.stop() }

    /// Whether the guide gull is flying (or holding its last pose).
    var ghostActive: Bool { ghost.isActive }
    /// SR7: the guide gull's point in view points (y down, like `birdScreenPoint`), nil when none flies.
    private(set) var ghostScreenPoint: CGPoint?
    /// The guide gull's tuck now (the App's diagram draws its pose dashed during a demo).
    var ghostTuck: Double { ghost.tuck }
    /// Called once when the guide gull dissolves into its motes (the player's turn).
    var onGhostFinished: (() -> Void)?
    /// SR7: the live landing ring's rect (the ellipse with its drop marker) in view points, nil when none is up.
    private(set) var ringScreenRect: CGRect?
    /// UX-ROUND-9 step 6: while set, a dotted line flows from the storm's front to this view point (the meter's storm
    /// icon). Set it for about 1 s, then nil.
    var stormLinkTarget: CGPoint?
    /// Step 6: the first lighthouse rises on the far horizon in school (its lamp: `lampCanvasPoint`, for the name).
    var schoolLighthouse: Bool = false
    /// Defect #3: Home's menu rects (view points, y down). In `.attract` the water stays 24 pt under the lowest one
    /// (never lower than 6 % of the visible height). Empty = no limit.
    var homeMenuRects: [CGRect] = []
    /// The fold zones' paint (tests).
    var foldPaint: [(painted: Double, missed: Bool, done: Bool)] { guides.foldPaint }
    /// R10: called once on each moment's peak frame (freeze the CI frame there). `momentPeak` is the same, for the
    /// frame it happened on only.
    var onPeak: ((ScenePeak) -> Void)?
    private(set) var momentPeak: ScenePeak?
    /// R10: the school storm's recoil now, 0 … 1 (1 = shoved fully back), so the App's meter knob can jump with it.
    var stormRecoil: CGFloat { schoolPush }
    /// Seconds since the last Perfect (tests; 10 = long ago).
    private(set) var perfectAge: Double = 10

    /// Lightning strikes so far (tests).
    var stormStrikes: Int { storm.strikeCount }
    /// The camera's look-ahead shift now (canvas pt; tests).
    var cameraBias: CGFloat { CGFloat(viewCam.bias) }

    #if DEBUG
    private static let demoLogging: Bool = ProcessInfo.processInfo.arguments.contains("-swoopDemo")
    #endif

    private var viewCam: SceneCamera
    private let backRoot: SKNode
    private let world: SKNode
    private let shadeRoot: SKNode
    private let frontRoot: SKNode
    private let titleRoot: SKNode
    private let titleArt: SKNode
    private let titleBody: SKShapeNode
    private let titleWings: SKShapeNode
    private let titleTips: SKShapeNode
    private let backdrop: SceneBackdrop
    private let seaView: SceneSeaView
    private let props: SceneProps
    private let birdView: SceneBirdView
    private let fx: SceneEffects
    private let storm: SceneStorm
    private let speedLines: SceneSpeedLines
    private let flare: SKSpriteNode
    private let flareStreak: SKSpriteNode
    private let crease: SKSpriteNode
    private let gutterLeft: SKSpriteNode
    private let gutterRight: SKSpriteNode

    private var bird: Bird = SceneDefaults.bird
    private var sky: Sky = SceneDefaults.sky
    private var palette: ScenePalette = ScenePalette.palette(.goldenHour)
    private var foamColor: UIColor = .white
    private var sprayColor: UIColor = .white
    private var puffColor: UIColor = .white
    private var snapshot = FlightSnapshot()
    private var lastUpdateTime: TimeInterval?
    private var lastSimTime: Double?
    private var stallTime: Double = 0
    private var needsSnap = true
    private var originX: Double = 0
    private var animTime: Double = 0
    private var lastBirdX: Double?
    private weak var lastSea: SeaProfile?
    private var sampleBuffer: [CGPoint] = []
    private var caughtness: CGFloat = 0
    private var goldTimer: CGFloat = 0
    private var flapPhase: Double = 0
    private var launchFlap: Double = 0
    private var dripTimer: CGFloat = 0
    private var dripCarry: CGFloat = 0
    private var bumpY: CGFloat = 0
    private var bumpVelocity: CGFloat = 0
    private var flareLevel: CGFloat = 0
    private var creasePulse: CGFloat = 0
    private var punchAge: Double = 10
    private var tailwindAge: Double = 10
    private var fastKick: Double = 0
    private var flightTime: Double = 0
    private var pointClock: Double = 1
    private var morphAge: Double = 10
    private var morphStart = CGPoint.zero
    private var gutterLevel: CGFloat = -1
    private var stormEdge: CGFloat = -1
    private var dunkAge: CGFloat = 10
    private let nearGlitter: SKSpriteNode
    private let guides: SceneGuides
    private let reached: SceneReachedMoment
    private let bloom: SKSpriteNode
    private var bloomLevel: CGFloat = 0
    private var pendingGuide = false
    private var rollAge: Double?
    private var rollGlowDone = false
    private var lookSnapPending = true
    private var appliedBlendStep: CGFloat = 0
    private let ghost: SceneGuideGull
    private var linkDots: [SKSpriteNode] = []
    private var caughtAge: Double = 0
    private var caughtStartEdge: CGFloat?
    private var caughtBoltDone = false
    private var ripplesDone = 0
    private var schoolPush: CGFloat = 0
    private var schoolPushAge: Double = 10
    private var playKickAge: Double = 10
    private var caughtPeakDone = false
    private var schoolTowerAge: Double = 0

    init(layout: ScreenLayout) {
        self.layout = layout
        viewCam = SceneCamera(layout: layout)
        backRoot = SKNode()
        world = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
        titleRoot = SKNode()
        titleArt = SKNode()
        titleBody = SKShapeNode()
        titleWings = SKShapeNode()
        titleTips = SKShapeNode()
        backdrop = SceneBackdrop()
        seaView = SceneSeaView()
        props = SceneProps()
        birdView = SceneBirdView()
        fx = SceneEffects()
        storm = SceneStorm()
        speedLines = SceneSpeedLines(count: SceneLook.speedLineCount)
        flare = SKSpriteNode(texture: SceneTextures.glow)
        flareStreak = SKSpriteNode(texture: SceneTextures.streak)
        crease = SKSpriteNode(texture: SceneTextures.creaseGlint)
        let gutter = SceneTextures.horizontalGradient(
            key: "gutter", colors: [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 1)], locations: [0, 1])
        gutterLeft = SKSpriteNode(texture: gutter)
        gutterRight = SKSpriteNode(texture: gutter)
        nearGlitter = SKSpriteNode(texture: SceneTextures.glitter)
        guides = SceneGuides()
        reached = SceneReachedMoment()
        bloom = SKSpriteNode(texture: SceneTextures.glow)
        ghost = SceneGuideGull()
        super.init(size: layout.size)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FlightScene is created in code with init(layout:)")
    }

    private func setUp() {
        scaleMode = .aspectFill
        anchorPoint = .zero

        backRoot.zPosition = -100
        addChild(backRoot)
        backdrop.root.zPosition = 0
        backRoot.addChild(backdrop.root)
        // The storm sits between the sky and the far sea, so its base feathers into the far sea (ART §3).
        storm.backRoot.zPosition = -16
        backdrop.root.addChild(storm.backRoot)
        // The lighthouse stands between the two far swell layers (−14 and −12 in the backdrop).
        props.lighthouseRoot.zPosition = -12.5
        backdrop.root.addChild(props.lighthouseRoot)
        // The reached beam and lamp flare, just over the lighthouse (under the far-front swells).
        reached.backRoot.zPosition = -12.3
        backdrop.root.addChild(reached.backRoot)

        world.zPosition = 0
        addChild(world)
        props.cloudRoot.zPosition = -40
        props.buoyRoot.zPosition = -11
        seaView.root.zPosition = -10
        birdView.shadow.zPosition = -5.9
        fx.waterRoot.zPosition = -6
        birdView.trailRoot.zPosition = 14
        fx.root.zPosition = 15
        birdView.root.zPosition = 20
        fx.glowRoot.zPosition = 30
        // Flight School's guides lie on the water, under the rings and the bird.
        guides.root.zPosition = -6.2
        // The guide gull flies just under the player's bird.
        ghost.root.zPosition = 19
        for n in [props.cloudRoot, props.buoyRoot, seaView.root, guides.root, birdView.shadow, fx.waterRoot,
                  birdView.trailRoot, fx.root, ghost.root, birdView.root, fx.glowRoot] as [SKNode] {
            world.addChild(n)
        }

        shadeRoot.zPosition = 5
        addChild(shadeRoot)
        shadeRoot.addChild(storm.shadeRoot)
        // The sun's glitter column continued down the near sea (REVIEW-3 juror #8), over the water, under the bird.
        nearGlitter.anchorPoint = CGPoint(x: 0.5, y: 1)
        nearGlitter.blendMode = .add
        nearGlitter.colorBlendFactor = 1
        nearGlitter.zPosition = 1
        shadeRoot.addChild(nearGlitter)

        frontRoot.zPosition = 60
        addChild(frontRoot)
        storm.frontRoot.zPosition = 0
        frontRoot.addChild(storm.frontRoot)
        speedLines.root.zPosition = 3
        frontRoot.addChild(speedLines.root)
        flare.blendMode = .add
        flare.colorBlendFactor = 1
        flare.zPosition = 4
        flare.isHidden = true
        frontRoot.addChild(flare)
        flareStreak.blendMode = .add
        flareStreak.colorBlendFactor = 1
        flareStreak.zPosition = 4.1
        flareStreak.isHidden = true
        frontRoot.addChild(flareStreak)
        reached.frontRoot.zPosition = 5
        frontRoot.addChild(reached.frontRoot)
        bloom.blendMode = .add
        bloom.colorBlendFactor = 1
        bloom.color = .white
        bloom.zPosition = 2.5
        bloom.isHidden = true
        frontRoot.addChild(bloom)
        // The storm link (canvas space, over the HUD-free play area).
        for _ in 0..<48 {
            let d = SKSpriteNode(texture: SceneTextures.dot, size: CGSize(width: 4, height: 4))
            d.colorBlendFactor = 1
            d.color = .white
            d.isHidden = true
            d.zPosition = 75
            addChild(d)
            linkDots.append(d)
        }

        titleRoot.zPosition = 70
        titleRoot.isHidden = true
        addChild(titleRoot)
        titleArt.yScale = -1
        titleRoot.addChild(titleArt)
        for (n, z) in [(titleWings, CGFloat(0)), (titleTips, CGFloat(0.1)), (titleBody, CGFloat(0.2))] {
            n.zPosition = z
            n.lineWidth = 0
            n.strokeColor = .clear
            titleArt.addChild(n)
        }

        for g in [gutterLeft, gutterRight] {
            g.colorBlendFactor = 1
            g.zPosition = 78
            g.isHidden = true
            addChild(g)
        }
        gutterLeft.anchorPoint = CGPoint(x: 1, y: 0)
        // Mirrored: spans mid … mid + 60, darkest at the fold.
        gutterRight.anchorPoint = CGPoint(x: 1, y: 0)
        gutterRight.xScale = -1
        crease.blendMode = .add
        crease.zPosition = 80
        crease.color = .white
        crease.colorBlendFactor = 1
        addChild(crease)

        sampleBuffer.reserveCapacity(400)
        applyCosmetics(bird: bird, sky: sky)
        applyLayout()
    }

    // MARK: Public API

    /// A new session: clear the FX and snap the camera on the next frame.
    func reset() {
        fx.clear()
        storm.clear()
        speedLines.clear()
        birdView.clearTrail()
        props.reset()
        seaView.invalidate()
        needsSnap = true
        lastSimTime = nil
        lastBirdX = nil
        stallTime = 0
        caughtness = 0
        goldTimer = 0
        flapPhase = 0
        launchFlap = 0
        dripTimer = 0
        bumpY = 0
        bumpVelocity = 0
        flareLevel = 0
        creasePulse = 0
        punchAge = 10
        tailwindAge = 10
        fastKick = 0
        flightTime = 0
        pointClock = 1
        lighthouseU = nil
        stormEdge = -1
        dunkAge = 10
        reached.clear()
        guides.clear()
        ghost.clear()
        ghostScreenPoint = nil
        ringScreenRect = nil
        caughtAge = 0
        caughtStartEdge = nil
        caughtBoltDone = false
        ripplesDone = 0
        schoolPush = 0
        schoolPushAge = 10
        playKickAge = 10
        perfectAge = 10
        caughtPeakDone = false
        momentPeak = nil
        schoolTowerAge = 0
        pendingGuide = true
        rollAge = nil
        rollGlowDone = false
        lookSnapPending = true
    }

    /// The Home → play morph (ART §7, UX-S3): the dorsal title bird, as Home drew it across the top of the canvas,
    /// scales and slides to the play bird's spot over 0.6 s and crossfades into the side view at 50 %. Reduce Motion:
    /// a crossfade in place. Call it as the run starts from Home (the App hides its own title bird at that moment).
    func playTitleMorph(tuck: Double = 0) {
        let w = layout.size.width
        let parts = BirdArt.titlePath(for: bird, tuck: tuck, width: w, height: SceneLook.titleBoxHeight)
        let detail = BirdArt.titleDetail(for: bird, tuck: tuck, width: w, height: SceneLook.titleBoxHeight)
        titleBody.path = parts.body
        let wings = CGMutablePath()
        wings.addPath(parts.leftWing)
        wings.addPath(parts.rightWing)
        titleWings.path = wings
        let tips = CGMutablePath()
        tips.addPath(detail.leftPrimaries)
        tips.addPath(detail.rightPrimaries)
        titleTips.path = tips
        titleBody.fillColor = ScenePaint.ui(bird.body)
        titleWings.fillColor = ScenePaint.ui(bird.wing)
        titleTips.fillColor = ScenePaint.ui(bird.wingTip)
        // The art's own origin is the box's top-left (y down); centre it on the root.
        titleArt.position = CGPoint(x: -w * 0.5, y: SceneLook.titleBoxHeight * 0.5)
        morphStart = CGPoint(x: w * 0.5,
                             y: layout.size.height - SceneLook.titleBoxTop - SceneLook.titleBoxHeight * 0.5)
        morphAge = 0
        morphProgress = 0
        titleRoot.isHidden = false
        titleRoot.position = morphStart
        titleRoot.setScale(1)
        titleRoot.alpha = 1
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt: Double = 1.0 / 120.0
        if let last = lastUpdateTime { dt = min(max(currentTime - last, 0), 1.0 / 30.0) }
        lastUpdateTime = currentTime
        drawnFrames += 1
        #if DEBUG
        if drawnFrames == 120 && FlightScene.demoLogging {
            print("SWOOP-T frame 120")
            fflush(stdout)
        }
        #endif

        var events: [FlightEvent] = []
        var simDt = dt
        var fxDt = dt
        if let d = driver {
            // Cosmetics rarely change: look every 30 frames (the App builds them from its catalogues).
            if drawnFrames % SceneLook.cosmeticsCheckFrames == 1 {
                let b = d.bird
                let k = d.sky
                if b != bird || k != sky { applyCosmetics(bird: b, sky: k) }
            }
            let out = d.advance(dt: dt, now: CACurrentMediaTime())
            snapshot = out.0
            events = out.1
            let sea = d.sea
            if sea !== lastSea {
                lastSea = sea
                reset()
            }
            if let prev = lastSimTime {
                if snapshot.time + 0.25 < prev {
                    // The clock went backwards: a new session the App didn't announce.
                    reset()
                    simDt = 0
                } else {
                    simDt = min(max(snapshot.time - prev, 0), 1.0 / 30.0)
                }
            }
            lastSimTime = snapshot.time
            if simDt > 0 {
                stallTime = 0
                fxDt = simDt
            } else {
                stallTime += dt
                fxDt = stallTime <= SceneLook.hitStopWindow ? dt : 0
            }
        }
        render(simDt: simDt, fxDt: fxDt, wallDt: dt, events: events)
    }

    // MARK: Drawing

    private func render(simDt: Double, fxDt: Double, wallDt: Double, events: [FlightEvent]) {
        let s = snapshot
        let dt = CGFloat(fxDt)
        animTime += fxDt
        let t = animTime
        let w = layout.size.width
        let h = layout.size.height
        let visMinY = layout.visibleRect.minY
        let visMaxY = layout.visibleRect.maxY

        var countdown = false
        var caught = false
        switch s.phase {
        case .countdown: countdown = true
        case .flying: break
        case .caught, .finished: caught = true
        }
        // Flight School (R6/R9): the App's flag, or a snapshot with no storm. School is never caught (defect #5: no
        // storm, rain or caught wash in any school step).
        let gapNow = s.gap != 0 ? s.gap : Double(s.position.x) - s.stormX
        let inSchool = practiceSea || (driver != nil && gapNow >= SceneLook.noStormGap)
        if inSchool { caught = false }
        momentPeak = nil
        // R10 peaks and the recoil clocks.
        let prevPerfect = perfectAge
        perfectAge += fxDt
        if prevPerfect < SceneLook.perfectPeakTime && perfectAge >= SceneLook.perfectPeakTime { peak(.perfect) }
        let prevPush = schoolPushAge
        schoolPushAge += fxDt
        playKickAge += fxDt
        schoolPush = FlightScene.recoil(age: schoolPushAge)
        if prevPush < SceneLook.recoilHit && schoolPushAge >= SceneLook.recoilHit { storm.glowOnce(strength: 0.9) }
        let pushPeak = SceneLook.recoilHit + SceneLook.recoilRise
        if prevPush < pushPeak && schoolPushAge >= pushPeak { peak(.recoil) }
        if caught {
            caughtAge += fxDt
        } else {
            caughtPeakDone = false
            caughtAge = 0
            caughtStartEdge = nil
            caughtBoltDone = false
            ripplesDone = 0
        }
        if caught {
            caughtness = min(1, caughtness + dt / SceneLook.caughtEase)
        } else {
            caughtness = max(0, caughtness - dt * 2)
        }
        // 2.4 s ease-in-out for the caught ending's light (R9).
        let caughtEase = caughtness * caughtness * (3 - 2 * caughtness)
        if !countdown && !caught { flightTime += fxDt } else if countdown { flightTime = 0 }
        // The first 2 s of a run use only big shapes (ART §8, the fold blur), as does the App's blur guard.
        let fine = fineDetail && !countdown && flightTime > 2

        // The bird as displayed (hover in the countdown; bobbing low in the water once caught).
        let bx = Double(s.position.x)
        var by = Double(s.position.y)
        if countdown { by += SceneLook.hoverBob * sin(t * SceneLook.hoverRate) }
        // Once caught the sea settles into one calm swell; the bird rides that same surface.
        let calmNow = Double(1 - caughtness)
        let water = SceneSeaView.calmed(seaHeight(bx), x: bx, calm: calmNow)
        if caught { by = water - SceneLook.caughtSink + SceneLook.caughtBob * sin(t * 1.7) }

        // Camera: framing on the simulation's clock; the punch-in and the pull-outs on the FX clock.
        let birdPoint = CGPoint(x: bx, y: by)
        viewCam.birdCeiling = s.mode == .attract ? attractBirdCeiling().map { Double($0) } : nil
        viewCam.waterCeiling = s.mode == .attract ? homeWaterCeiling().map { Double($0) } : nil
        viewCam.practiceFraming = inSchool
        // R9: room ahead for the guide gull (≤ 0.78 zoom, 0.22 w) or a live landing ring (0.25 w).
        viewCam.zoomCap = ghost.isActive ? SceneLook.ghostMaxZoom : nil
        var bias: CGFloat = 0
        if ghost.isActive {
            bias = SceneLook.ghostCameraBias * w
        } else if let rc = guides.ringCenter, Double(rc.x) > bx {
            bias = SceneLook.ringCameraBias * w
        }
        let biasRoom = w * ScreenLayout.birdScreenFraction - SceneLook.biasEdgeClearance
        viewCam.biasTarget = Double(min(bias, max(biasRoom, 0)))
        // A jump of the bird (a rewind, a session switch, a held frame) never leaves a straight trail (defect #29).
        if let lx = lastBirdX, abs(bx - lx) > 600 { birdView.clearTrail() }
        if needsSnap {
            viewCam.snap(bird: birdPoint, water: water)
            originX = (bx / 2048).rounded(.down) * 2048
            lastBirdX = bx
            needsSnap = false
        } else {
            viewCam.update(bird: birdPoint, water: water, dt: simDt)
        }
        punchAge += fxDt
        tailwindAge += fxDt
        var punch: Double = 0
        var tailwindPull: Double = 0
        if !reduceMotion {
            if punchAge < SceneLook.punchAttack {
                punch = SceneLook.punchAmount * punchAge / SceneLook.punchAttack
            } else {
                let k = max(0, 1 - (punchAge - SceneLook.punchAttack) / SceneLook.punchRelease)
                punch = SceneLook.punchAmount * k * k
            }
            if tailwindAge < 0.5 { tailwindPull = SceneLook.tailwindPullOut * sin(Double.pi * tailwindAge / 0.5) }
        }
        let kickTarget = caught || countdown ? 0
            : min(max((s.speed - SceneLook.fastPullOutFrom) / SceneLook.fastPullOutRange, 0), 1)
        fastKick += (kickTarget - fastKick) * min(1, fxDt * 3)
        // Caught (R9 §2): a +4 % push-in toward the bird from 0.6 to 2.4 s.
        var caughtPush: Double = 0
        if caught && !reduceMotion {
            let k = min(max((caughtAge - 0.6) / 1.8, 0), 1)
            caughtPush = SceneLook.caughtPushIn * k * k * (3 - 2 * k)
        }
        viewCam.setDisplayScale((1 + punch) * (1 - SceneLook.fastPullOut * fastKick) * (1 - tailwindPull)
                                * (1 + caughtPush))
        displayScale = CGFloat(viewCam.displayScale)

        if abs(bx - originX) > 4096 {
            let newOrigin = (bx / 2048).rounded(.down) * 2048
            let d = CGFloat(originX - newOrigin)
            fx.shift(dx: d)
            birdView.shiftTrail(dx: d)
            ghost.shift(dx: d)
            originX = newOrigin
        }
        let z = CGFloat(viewCam.zoom)
        drawnZoom = z
        let dir: CGFloat = layout.mirrored ? -1 : 1
        if dt > 0 {
            let k = SceneLook.bumpOmega * SceneLook.bumpOmega
            let c = 2 * SceneLook.bumpDamping * SceneLook.bumpOmega
            bumpVelocity += (-k * bumpY - c * bumpVelocity) * dt
            bumpY += bumpVelocity * dt
        }
        world.xScale = dir * z
        world.yScale = z
        world.position = CGPoint(x: CGFloat(viewCam.anchorX) - dir * CGFloat(bx - originX) * z,
                                 y: CGFloat(viewCam.visibleMinY) - CGFloat(viewCam.bottomY) * z + bumpY)
        var scrollPx: CGFloat = 0
        if let lx = lastBirdX { scrollPx = CGFloat(min(max(bx - lx, -2000), 2000)) * z }
        lastBirdX = bx

        // The storm's geometry (u-space, ROUND-4 P0-2): its edge follows the lead meter's fill, monotonically and
        // visibly (a hint at a full lead, 40 % of the bird page at storm-close, right behind the bird at contact),
        // eased so a Tailwind or a lighthouse visibly shoves it back. Caught, it sweeps on past the fold.
        let anchorU = w * ScreenLayout.birdScreenFraction
        var gap = s.gap != 0 ? s.gap : bx - s.stormX
        if driver == nil { gap = Tuning.gapStart }

        // Flight School (ROUND-6 D2): the practice look (set by the App, or seen in a snapshot with no storm), and
        // step 7's roll-in.
        updatePracticeLook(target: inSchool && rollAge == nil ? 1 : 0, dt: fxDt)
        let lookK = practiceLook * practiceLook * (3 - 2 * practiceLook)

        let fill = SceneStormMap.meterFill(gap: gap)
        stormMeterFill = fill
        var closeness = SceneStormMap.closeness(meterFill: fill)
        let target = SceneStormMap.edgeU(meterFill: fill, birdPageWidth: layout.creaseMinX, anchorU: anchorU)
        if stormEdge < 0 {
            stormEdge = target
        } else if dt > 0 {
            stormEdge += (target - stormEdge) * min(1, dt * 3.5)
        }
        var edgeU = stormEdge
        // School before the roll-in: no storm, so nothing dims (the sun, the sea) for it either.
        if inSchool && rollAge == nil { closeness = 0 }
        var presence: CGFloat = 1 - lookK
        var rainPresence: CGFloat = 1
        if let ra = rollAge {
            rollAge = ra + fxDt
            presence = 1
            let k = CGFloat(min(ra / SceneLook.rollInTime, 1))
            rainPresence = SceneMoments.smooth(CGFloat(SceneLook.rollInRainFrom), CGFloat(SceneLook.rollInRainFull),
                                               CGFloat(ra))
            if inSchool {
                // No catch in school: the wall slides in from off screen to cover the bird page's outer 20 % (R9:
                // plainly on screen, defect #22). A school Perfect pushes it back for a moment.
                let rest = SceneLook.rollInEdge * w - SceneLook.schoolPushBack * schoolPush
                edgeU = SceneLook.rollInFrom + (rest - SceneLook.rollInFrom) * (k * k * (3 - 2 * k))
                stormEdge = edgeU
                closeness = SceneLook.rollInCloseness
            }
            if !rollGlowDone && ra >= SceneLook.rollInGlowAt {
                rollGlowDone = true
                storm.glowOnce(strength: 0.6)
            }
        }
        // R10: in a real flight a Perfect kicks the wall back a little too (rise 0.15 s, gone by 1 s).
        if !inSchool && !caught && playKickAge < 1 {
            let k = playKickAge < 0.15 ? playKickAge / 0.15 : max(0, 1 - (playKickAge - 0.15) / 0.85)
            edgeU -= SceneLook.playKick * CGFloat(k * k * (3 - 2 * k))
        }
        // Caught (R9 §2): the front sweeps past the bird to 0.10 w from the ahead edge over 1.2 s (ease-in-out).
        if caught {
            if caughtStartEdge == nil { caughtStartEdge = edgeU }
            let start = caughtStartEdge ?? edgeU
            let k = CGFloat(min(caughtAge / SceneLook.caughtSweepTime, 1))
            let caughtEdge = SceneLook.stormCaughtEdge * w
            edgeU = start + (max(start, caughtEdge) - start) * (k * k * (3 - 2 * k))
            // R10: the peak, as the front crosses over the bird: it flinches and is splashed, the wall lights up.
            let birdU = layout.mirrored ? w - CGFloat(viewCam.anchorX) : CGFloat(viewCam.anchorX)
            if !caughtPeakDone && edgeU >= birdU + SceneLook.caughtPeakPast {
                caughtPeakDone = true
                storm.glowOnce(strength: 1)
                birdView.squash()
                let p = CGPoint(x: CGFloat(bx - originX), y: CGFloat(water))
                fx.splash(at: p, k: 0.3, zoom: CGFloat(viewCam.zoom), color: foamColor)
                if !reduceMotion { bumpVelocity -= SceneLook.splashBump * 0.6 }
                peak(.caught)
            }
            // One bolt ahead of the bird, inside the wall: the storm is over it now.
            if !caughtBoltDone && caughtAge >= SceneLook.caughtBoltAt {
                caughtBoltDone = true
                storm.strike(strength: 0.8, atU: min(anchorU + 80, edgeU - 40))
            }
        }

        // The near sea: rebuilt only when the cached surface no longer covers the view (QA-2 P2-2). No chop in school.
        let range = viewCam.visibleSeaRange(margin: SceneLook.seaSideMargin)
        let calm = Double(1 - caughtness)
        let seaStormX = inSchool ? -1e12 : s.stormX
        let chopOnScreen = seaStormX + SceneLook.chopReach > range.lo
        if let req = seaView.rebuildRequest(visibleLo: range.lo, visibleHi: range.hi, zoom: z, stormX: seaStormX,
                                            chopOnScreen: chopOnScreen, closeness: Double(closeness), calm: calm,
                                            originX: originX) {
            fillSamples(from: req.lo, to: req.hi, step: req.step)
            seaView.rebuild(samples: sampleBuffer, lo: req.lo, hi: req.hi, zoom: z, stormX: seaStormX,
                            closeness: Double(closeness), calm: calm, originX: originX)
        }
        let sunSeaX = bx + Double((SceneLook.sunU * w - anchorU) / max(z, 0.01))
        let fast = CGFloat(min(max((s.speed / Tuning.maxSpeed - 0.75) / 0.15, 0), 1))
        seaView.animate(zoom: z, time: t, visibleLo: range.lo, visibleHi: range.hi, originX: originX,
                        sunSeaX: sunSeaX, reach: SceneLook.glintReach * w, fast: fast, fine: fine)

        // Sky and far swells; the sun dims 0.15 c in play and by half when caught.
        let meanY = CGFloat(viewCam.meanWaterScreenY) + bumpY
        let sunDim = SceneLook.stormSunDim * closeness * (1 - caughtEase) + SceneLook.caughtSunDim * caughtEase
        let farAlpha = 1 - (1 - SceneLook.practiceFarAlpha) * lookK
        let sunLift = SceneLook.sunLiftFraction + (SceneLook.practiceSunLift - SceneLook.sunLiftFraction) * lookK
        backdrop.update(width: w, height: h, visibleTop: visMaxY, meanY: meanY, zoom: z, scroll: scrollPx, time: t,
                        dt: dt, sunDim: sunDim, drift: !reduceMotion, farAlpha: farAlpha, sunLift: sunLift,
                        practice: lookK)

        let sunU = backdrop.sunPosition.x
        sunCanvasPoint = CGPoint(x: layout.mirrored ? w - sunU : sunU, y: backdrop.sunPosition.y)
        let sunWater = viewCam.screenPoint(CGPoint(x: sunSeaX, y: seaHeight(sunSeaX)))
        nearGlitter.position = CGPoint(x: sunU, y: CGFloat(sunWater.y) + bumpY + 2)
        nearGlitter.size = CGSize(width: w * SceneLook.glitterWidth, height: SceneLook.nearGlitterDepth)
        nearGlitter.alpha = SceneLook.nearGlitterAlpha * backdrop.sunBrightness * CGFloat(0.85 + 0.15 * sin(t * 6.0))
        storm.update(edgeU: edgeU, closeness: closeness, lead: CGFloat(s.lead), caughtness: caughtEase,
                     presence: presence, rainPresence: rainPresence, size: layout.size, minY: visMinY, maxY: visMaxY,
                     horizonY: backdrop.horizonY, birdU: anchorU, dt: dt)

        // Props: the lighthouse (depth layer), the personal-best buoy (Flight only, UX-S2), the cloud band. Neither
        // shows in school (there is no distance there).
        if inSchool && schoolLighthouse {
            showSchoolLighthouse(zoom: z, width: w, dt: fxDt)
        } else {
            schoolTowerAge = 0
            updateLighthouse(s, bx: bx, zoom: z, width: w, hide: inSchool, dt: dt)
        }
        reached.update(dt: dt, lamp: props.lighthouseShown ? props.lampPoint : nil, minU: seaPageMinU())
        if props.lighthouseShown {
            let lamp = props.lampPoint
            lampCanvasPoint = CGPoint(x: layout.mirrored ? w - lamp.x : lamp.x, y: lamp.y)
        } else {
            lampCanvasPoint = nil
        }
        if s.bestMeters > 0 && s.mode == .flight && !inSchool {
            let bxBest = s.bestMeters * 10
            if bxBest > range.lo - 80 && bxBest < range.hi + 80 {
                let bob = 1.5 * sin(t * 2.1)
                props.showBuoy(at: CGPoint(x: CGFloat(bxBest - originX), y: CGFloat(seaHeight(bxBest) - 2 + bob)),
                               slope: CGFloat(seaSlope(bxBest)), zoom: z, time: t, dt: dt)
            } else {
                props.hideBuoy()
            }
        } else {
            props.hideBuoy()
        }
        props.updateClouds(birdX: bx, originX: originX)

        // Flight School's guides on the water, and step 4's bloom.
        if pendingGuide {
            pendingGuide = false
            guides.show(SceneGuidePlacement.resolve(guide, birdX: bx, height: { x in self.seaHeight(x) }))
        }
        guides.update(dt: dt, time: t, zoom: z, originX: originX, birdX: bx, birdY: by, tuck: s.tuck,
                      height: { x in self.seaHeight(x) })
        if guides.ringNeedsRespawn {
            // A missed ring comes back on the next downslope ≥ 200 pt ahead (ART-ROUND-9 §1C).
            guides.respawnRing(at: SceneGuidePlacement.landingX(after: bx + SceneLook.ringAhead,
                                                                height: { x in self.seaHeight(x) }))
        }
        updateBloom(dt: dt, width: w, height: h)

        // The bird.
        var tuck = s.tuck
        if caught { tuck = SceneLook.caughtTuck } else if countdown { tuck = 0 }
        updateFlap(s, countdown: countdown, caught: caught, dt: fxDt)
        birdView.pose(tuck: tuck, flap: flapPhase, dt: dt)
        var angle = CGFloat(s.bodyAngle)
        if countdown { angle = CGFloat(0.06 * sin(t * SceneLook.hoverRate + 0.6)) }
        // Caught (R9): settled on the water, head down, nose −4°.
        if caught { angle = SceneLook.caughtNose + CGFloat(0.03 * sin(t * 1.3)) }
        birdView.setWet(caughtEase)
        // A splash dunks the bird (ROUND-4 P1-9): 6 pt down and nose-down for 0.3 s, then back.
        dunkAge += dt
        if dunkAge < SceneLook.splashDunkTime {
            let k = sin(CGFloat.pi * dunkAge / SceneLook.splashDunkTime)
            by -= Double(SceneLook.splashDunk * k)
            angle -= 0.22 * k
        }
        if !countdown && !caught && !s.skimming { angle += noseOffset(tuck: CGFloat(tuck)) }
        let birdScale = pow(z, -SceneLook.birdZoomResist)
        let birdLocal = CGPoint(x: CGFloat(bx - originX), y: CGFloat(by))
        birdView.place(at: birdLocal, angle: angle, scale: birdScale)
        let altitude = max(0, by - water)
        birdView.setHalo(CGFloat(max(0, 1 - altitude / 150)))
        birdView.updateShadow(water: CGPoint(x: birdLocal.x, y: CGFloat(water)), altitude: altitude, zoom: z,
                              show: !countdown && !caught)
        reportBirdPoint(birdPoint, wallDt: wallDt)
        // Caught: three rain rings around the settled bird.
        if caught && ripplesDone < SceneLook.caughtRipples.count && caughtAge >= SceneLook.caughtRipples[ripplesDone] {
            let side: CGFloat = ripplesDone % 2 == 0 ? -1 : 1
            let off = side * CGFloat(20 + 18 * ripplesDone) / max(z, 0.01)
            fx.ripple(at: CGPoint(x: birdLocal.x + off, y: CGFloat(water)), zoom: z, color: foamColor)
            ripplesDone += 1
        }
        fx.followPoint = CGPoint(x: birdLocal.x - SceneLook.ringBehind / max(z, 0.01), y: CGFloat(water))

        // Trail and continuous FX.
        let speedK = CGFloat(min(max((s.speed - 300) / 1500, 0), 1))
        goldTimer = max(0, goldTimer - dt)
        let tailwind = s.tailwindRemaining > 0
        var goldK: CGFloat = tailwind ? 1 : min(1, goldTimer / SceneLook.perfectGoldTime)
        // School (R9 §1E): the trail turns gold as the dive reaches its speed (the speed is shown in the world).
        if inSchool { goldK = max(goldK, SceneMoments.smooth(1100, 1600, CGFloat(s.speed))) }
        birdView.updateTrail(emit: birdView.tailPoint, show: !caught && !countdown, time: t, zoom: z, speedK: speedK,
                             goldK: goldK, tailwind: tailwind)
        if s.skimming && !caught && !countdown && dt > 0 {
            let tip = birdView.wingtipPoint
            let tipWater = CGFloat(seaHeight(Double(tip.x) + originX))
            let v = s.velocity
            let len = max(hypot(v.dx, v.dy), 1)
            let back = CGVector(dx: -v.dx / len, dy: -v.dy / len)
            fx.skim(tip: tip, waterY: tipWater, back: back, k: speedK, zoom: z, color: sprayColor, dt: dt)
            fx.wake(at: CGPoint(x: birdLocal.x, y: CGFloat(water)), k: speedK, zoom: z, color: foamColor, dt: dt)
        }
        if tailwind && !caught && dt > 0 { fx.shed(at: birdView.tailPoint, zoom: z, dt: dt) }
        if dripTimer > 0 && dt > 0 {
            dripTimer -= dt
            dripCarry += dt * 22
            while dripCarry >= 1 {
                dripCarry -= 1
                let ux = CGFloat.random(in: -0.3...0.25)
                fx.drip(at: birdView.point(unitX: ux, unitY: -0.03), zoom: z, color: foamColor)
            }
        }
        var lineK: CGFloat = 0
        if !caught && !countdown {
            let from = inSchool ? 600 : SceneLook.speedLinesFrom
            lineK = CGFloat(min(max((s.speed - from) / SceneLook.speedLinesRange, 0), 1))
            if tailwind { lineK = max(lineK, 0.35) }
        }
        speedLines.setGold(s.speed >= SceneLook.goldSpeedFraction * Tuning.maxSpeed)
        let birdCanvasY = CGFloat(viewCam.screenPoint(birdPoint).y)
        speedLines.update(intensity: fine ? lineK : 0, vignette: reduceMotion, width: w, height: h, birdY: birdCanvasY,
                          minY: visMinY, maxY: visMaxY, dt: dt)

        handle(events, s: s, bx: bx, birdLocal: birdLocal, zoom: z, inSchool: inSchool)
        updateGhost(dt: fxDt, zoom: z, bx: bx)
        updateRingRect(zoom: z)
        updateStormLink(edgeU: edgeU, t: t)
        fx.update(dt)
        updateFlare(dt: dt)
        updateFold(tuck: CGFloat(caught || countdown ? 0 : s.tuck), dt: dt)
        updateMorph(wallDt: wallDt)
    }

    /// The attract loop's ceiling for the bird's centre (canvas y), from `attractCeiling` and `homeTextRects`.
    func attractBirdCeiling() -> CGFloat? {
        var ceiling: CGFloat?
        if let c = attractCeiling { ceiling = c }
        for r in homeTextRects where !r.isNull && !r.isEmpty {
            // The rect's lower edge (view y down → canvas y up).
            let bottom: CGFloat
            if view != nil {
                bottom = convertPoint(fromView: CGPoint(x: r.midX, y: r.maxY)).y
            } else {
                bottom = layout.size.height - r.maxY
            }
            ceiling = min(ceiling ?? bottom, bottom)
        }
        guard let c = ceiling else { return nil }
        let floorY = layout.visibleRect.minY + layout.visibleRect.height * 0.2
        return max(c - FlightScene.attractClearance, floorY)
    }

    /// R10: the school storm's recoil envelope (0 … 1) at `age` s after the Perfect: nothing until the gust hits, a fast
    /// ease-out shove, a hold, then an ease back.
    nonisolated static func recoil(age a: Double) -> CGFloat {
        let hit = SceneLook.recoilHit, rise = SceneLook.recoilRise
        let hold = SceneLook.recoilHold, back = SceneLook.recoilBack
        if a < hit || a >= back { return 0 }
        if a < hit + rise {
            let q = (a - hit) / rise
            return CGFloat(1 - (1 - q) * (1 - q))
        }
        if a < hold { return 1 }
        let q = (a - hold) / (back - hold)
        return CGFloat(1 - q * q * (3 - 2 * q))
    }

    private func peak(_ p: ScenePeak) {
        momentPeak = p
        onPeak?(p)
    }

    /// Defect #3: the canvas y (y up) the Home water stays under: 24 pt below the lowest menu rect.
    func homeWaterCeiling() -> CGFloat? {
        var ceiling: CGFloat?
        for r in homeMenuRects where !r.isNull && !r.isEmpty {
            let bottom: CGFloat
            if view != nil {
                bottom = convertPoint(fromView: CGPoint(x: r.midX, y: r.maxY)).y
            } else {
                bottom = layout.size.height - r.maxY
            }
            ceiling = min(ceiling ?? bottom, bottom)
        }
        return ceiling.map { $0 - 24 }
    }

    /// A canvas point (SpriteKit, y up) in view points (y down), as `birdScreenPoint` reports.
    private func viewPoint(_ p: CGPoint) -> CGPoint {
        if view != nil { return convertPoint(toView: p) }
        return CGPoint(x: p.x, y: layout.size.height - p.y)
    }

    /// The guide gull: fly, report its point, fire the ghost Perfect, tell the App when it hands over.
    private func updateGhost(dt: Double, zoom z: CGFloat, bx: Double) {
        let wasActive = ghost.isActive
        ghost.update(dt: dt, zoom: z, originX: originX, bird: birdView, birdX: bx, still: reduceMotion)
        if ghost.landedNow {
            let p = ghost.position
            fx.ghostPerfect(at: CGPoint(x: p.x - CGFloat(originX), y: p.y), zoom: z)
        }
        if ghost.isActive {
            let c = viewCam.screenPoint(ghost.position)
            ghostScreenPoint = viewPoint(CGPoint(x: c.x, y: c.y + bumpY))
        } else {
            ghostScreenPoint = nil
        }
        if wasActive && ghost.finishedNow { onGhostFinished?() }
    }

    /// SR7: the live ring's rect in view points (its ellipse, widened 1.1×, with the drop marker above it).
    private func updateRingRect(zoom z: CGFloat) {
        guard let c = guides.ringCenter else {
            ringScreenRect = nil
            return
        }
        let p = viewCam.screenPoint(c)
        let w = SceneLook.ringWidth * 1.1
        let below = w * SceneLook.ringAspect * 0.5
        let above = SceneLook.dropHeight + SceneLook.dropChevron + 8
        let a = viewPoint(CGPoint(x: p.x - w * 0.5, y: p.y + bumpY + above))
        let b = viewPoint(CGPoint(x: p.x + w * 0.5, y: p.y + bumpY - below))
        ringScreenRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    /// UX-ROUND-9 step 6: dots flowing from the storm's front to the meter's storm icon.
    private func updateStormLink(edgeU: CGFloat, t: Double) {
        guard let target = stormLinkTarget, storm.isShown else {
            for d in linkDots where !d.isHidden { d.isHidden = true }
            return
        }
        let w = layout.size.width
        let fromU = max(edgeU - 30, 10)
        let from = CGPoint(x: layout.mirrored ? w - fromU : fromU, y: storm.wallTop - 30)
        let to: CGPoint
        if view != nil {
            to = convertPoint(fromView: target)
        } else {
            to = CGPoint(x: target.x, y: layout.size.height - target.y)
        }
        let length = hypot(to.x - from.x, to.y - from.y)
        let n = min(linkDots.count, max(Int(length / SceneLook.linkDotGap), 1))
        let flow = CGFloat((t * 1.5).truncatingRemainder(dividingBy: 1))
        for (i, d) in linkDots.enumerated() {
            d.isHidden = i >= n
            guard i < n else { continue }
            let k = (CGFloat(i) + flow) / CGFloat(n)
            d.position = CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k)
            d.alpha = SceneLook.linkAlpha * min(1, min(k, 1 - k) * 6)
        }
    }

    /// Step 6: the first lighthouse rises on the far horizon of the sea page (school has no distance of its own).
    private func showSchoolLighthouse(zoom z: CGFloat, width w: CGFloat, dt: Double) {
        schoolTowerAge += dt
        let k = CGFloat(min(schoolTowerAge / 1.2, 1))
        let e = k * k * (3 - 2 * k)
        let u = w * SceneLook.lighthouseFarU
        let scale = SceneLook.lighthouseScale * (0.55 + 0.45 * z) * 0.55
        lighthouseU = u
        props.showLighthouse(at: CGPoint(x: u, y: backdrop.frontBaseY + 4 - 40 * (1 - e)), scale: scale, alpha: e,
                             dt: CGFloat(dt))
    }

    /// Chain milestones (ROUND-4 P1-8): 3, 5, 10, 15, 20… get the callout, the hit-stop and the punch-in.
    nonisolated static func isChainMilestone(_ chain: Int) -> Bool {
        chain == 3 || chain == 5 || (chain >= 10 && chain % 5 == 0)
    }

    /// The nose while airborne (ART §4): +4° spread, −6° at half tuck, −10° tucked.
    private func noseOffset(tuck u: CGFloat) -> CGFloat {
        if u < 0.5 {
            return SceneLook.noseSpread + (SceneLook.noseHalf - SceneLook.noseSpread) * (u / 0.5)
        }
        return SceneLook.noseHalf + (SceneLook.noseTucked - SceneLook.noseHalf) * ((u - 0.5) / 0.5)
    }

    /// The bird's screen point for the App's callout, at most 30 times a second (UX-S1).
    private func reportBirdPoint(_ bird: CGPoint, wallDt: Double) {
        let p = viewCam.screenPoint(bird)
        birdCanvasPoint = CGPoint(x: p.x, y: p.y + bumpY)
        pointClock += wallDt
        guard pointClock >= SceneLook.birdPointInterval else { return }
        pointClock = 0
        if view != nil {
            birdScreenPoint = convertPoint(toView: birdCanvasPoint)
        } else {
            birdScreenPoint = CGPoint(x: birdCanvasPoint.x, y: layout.size.height - birdCanvasPoint.y)
        }
        onBirdPoint?(birdScreenPoint)
    }

    private func updateFlap(_ s: FlightSnapshot, countdown: Bool, caught: Bool, dt: Double) {
        launchFlap = max(0, launchFlap - dt)
        var rate: Double = 0
        if countdown {
            rate = SceneLook.flapRateCountdown
        } else if !caught {
            if launchFlap > 0 {
                rate = SceneLook.flapRateLaunch
            } else if !s.skimming && s.speed < SceneLook.slowFlapSpeed && s.tuck < 0.35 {
                rate = SceneLook.flapRateSlow
            }
        }
        if rate > 0 {
            flapPhase += dt * rate
            if flapPhase >= 1 { flapPhase -= floor(flapPhase) }
        } else if flapPhase > 0 {
            // Finish the beat back to the rest pose, then hold.
            flapPhase += dt * SceneLook.flapRateSlow
            if flapPhase >= 1 { flapPhase = 0 }
        }
    }

    /// The lighthouse is the goal (ROUND-6 D3, ART-FLIGHT-SCHOOL §4/§6). It stands on the far swells:
    /// - **Ahead, from 1.5 km:** small on the far horizon of the sea page (u = 0.90 w), fading in and growing as it
    ///   nears, so the goal chip points at something visible.
    /// - **Closer:** u = 0.76 w + (its x − the bird's) × zoom × parallax, moving in to stand on the sea page at the
    ///   pass (the reached beam sweeps from there), then drifting back slowly (REVIEW-1 P0-7).
    private func updateLighthouse(_ s: FlightSnapshot, bx: Double, zoom z: CGFloat, width w: CGFloat, hide: Bool,
                                  dt: CGFloat) {
        guard !hide else {
            lighthouseU = nil
            props.hideLighthouse()
            return
        }
        let p = SceneLook.lighthouseParallax
        let passU = w * SceneLook.lighthousePassU
        var shown: CGFloat?
        var scale = SceneLook.lighthouseScale * (0.55 + 0.45 * z)
        var alpha: CGFloat = 1
        if s.lighthousesPassed > 0 {
            let passed = Lighthouses.x(index: s.lighthousesPassed - 1)
            let u = passU + CGFloat(passed - bx) * z * p
            if u > -220 { shown = u }
        }
        if shown == nil {
            let next = s.nextLighthouseX > 0 ? s.nextLighthouseX : Lighthouses.x(index: max(s.lighthousesPassed, 0))
            let d = next - bx
            if d <= SceneLook.lighthouseAheadFrom {
                let near = passU + CGFloat(d) * z * p
                let far = w * SceneLook.lighthouseFarU
                if near <= far {
                    shown = near
                } else {
                    let join = Double((far - passU) / max(z * p, 0.001))
                    let span = max(SceneLook.lighthouseAheadFrom - join, 1)
                    let k = CGFloat(min(max((SceneLook.lighthouseAheadFrom - d) / span, 0), 1))
                    shown = far
                    scale *= SceneLook.lighthouseFarScale + (1 - SceneLook.lighthouseFarScale) * k
                    alpha = min(1, k * 8)
                }
            }
        }
        lighthouseU = shown
        guard let u = shown else {
            props.hideLighthouse()
            return
        }
        props.showLighthouse(at: CGPoint(x: u, y: backdrop.frontBaseY + 4), scale: scale, alpha: alpha, dt: dt)
    }

    /// The sea page's inner limit in u-space: the fold band's far side + its 28 pt art margin (the canvas middle
    /// without a fold). The reached beam and motes stay beyond it.
    private func seaPageMinU() -> CGFloat {
        let w = layout.size.width
        guard layout.hasFold else { return w * 0.5 }
        let mid = (layout.creaseMinX + layout.creaseMaxX) * 0.5
        return layout.mirrored ? w - (mid - SceneLook.foldArtBand) : mid + SceneLook.foldArtBand
    }

    /// The bird page's outer half-width in u-space (from the behind edge to the fold band's near side).
    private func birdPageWidthU() -> CGFloat {
        let w = layout.size.width
        guard layout.hasFold else { return w * 0.5 }
        let mid = (layout.creaseMinX + layout.creaseMaxX) * 0.5
        return layout.mirrored ? w - (mid + SceneLook.foldArtBand) : mid - SceneLook.foldArtBand
    }

    /// Eases the practice look toward `target` (snapping at a session's start), and re-tints in steps.
    private func updatePracticeLook(target: CGFloat, dt: Double) {
        if lookSnapPending {
            lookSnapPending = false
            practiceLook = target
        } else if practiceLook != target {
            let rate = CGFloat(dt / SceneLook.practiceCrossfade)
            practiceLook = target > practiceLook ? min(target, practiceLook + rate) : max(target, practiceLook - rate)
        }
        let e = practiceLook * practiceLook * (3 - 2 * practiceLook)
        let n = SceneLook.practiceBlendSteps
        let step = (e * n).rounded() / n
        if step != appliedBlendStep {
            appliedBlendStep = step
            applyCosmetics(bird: bird, sky: sky)
        }
    }

    /// Step 4's slow-motion bloom over the bird's half-page.
    private func updateBloom(dt: CGFloat, width w: CGFloat, height h: CGFloat) {
        if slowMoBloom {
            bloomLevel = min(1, bloomLevel + dt / SceneLook.guideFadeIn)
        } else {
            bloomLevel = max(0, bloomLevel - dt / SceneLook.guideFadeOut)
        }
        bloom.isHidden = bloomLevel <= 0.002
        guard !bloom.isHidden else { return }
        let page = birdPageWidthU()
        bloom.position = CGPoint(x: page * 0.5, y: h * 0.5)
        bloom.size = CGSize(width: page * 1.5, height: h * 1.3)
        bloom.alpha = SceneLook.slowMoBloomAlpha * bloomLevel
    }

    // MARK: Events → FX

    private func handle(_ events: [FlightEvent], s: FlightSnapshot, bx: Double, birdLocal: CGPoint, zoom z: CGFloat,
                        inSchool: Bool) {
        guard !events.isEmpty else { return }
        let waterPoint = CGPoint(x: birdLocal.x, y: CGFloat(seaHeight(bx)))
        for e in events {
            switch e {
            case .launched(let speed):
                let k = CGFloat(min(max((speed - 300) / 1800, 0), 1))
                fx.launch(at: waterPoint, velocity: s.velocity, k: k, zoom: z, color: foamColor)
                viewCam.pullOut(reduceMotion ? 0.03 : 0.05 + 0.06 * Double(k))
                if speed < SceneLook.launchFlapSpeed { launchFlap = 0.42 }
            case .touchdown(let quality, let speed, let chain):
                let k = CGFloat(min(max((speed - 300) / 1800, 0), 1))
                birdView.squash()
                switch quality {
                case .perfect:
                    fx.perfect(at: waterPoint, chain: chain, zoom: z, foamColor: foamColor)
                    goldTimer = SceneLook.perfectGoldTime
                    // Flight School: a Perfect in the landing ring turns it into the real one with a 12-mote burst.
                    if let rx = guides.perfectLanded(at: bx, zoom: z) {
                        let p = CGPoint(x: CGFloat(rx - originX), y: CGFloat(seaHeight(rx)) + 6 / max(z, 0.01))
                        fx.sparkles(at: p, count: 12, radius: 80, zoom: z,
                                    colors: [ScenePaint.gold, ScenePaint.paleGold])
                    }
                    // Step 6: a Perfect pushes the school's storm back, with a gust toward it.
                    perfectAge = 0
                    if !inSchool { playKickAge = 0 }
                    if inSchool && rollAge != nil {
                        // R10: an unmistakable shove: the gust hits the wall at 0.15 s and it recoils 150 pt.
                        schoolPushAge = 0
                        reached.playGust(birdU: layout.size.width * ScreenLayout.birdScreenFraction,
                                         birdY: birdCanvasPoint.y, reduceMotion: reduceMotion)
                    }
                    // The punch-in comes only at chain milestones (ROUND-4 P1-8: make Perfects special again).
                    if FlightScene.isChainMilestone(chain) { punchAge = 0 }
                case .good:
                    fx.good(at: waterPoint, zoom: z, color: foamColor)
                    guides.missedRing(birdX: bx, zoom: z)
                case .splash:
                    fx.splash(at: waterPoint, k: k, zoom: z, color: foamColor)
                    guides.missedRing(birdX: bx, zoom: z)
                    if !reduceMotion {
                        bumpVelocity -= SceneLook.splashBump * (0.7 + 0.6 * k)
                        dunkAge = 0
                    }
                    dripTimer = 0.6
                }
            case .tailwindStarted:
                flareLevel = 1
                tailwindAge = 0
                fx.sparkles(at: birdLocal, count: 22, radius: 60, zoom: z,
                            colors: [ScenePaint.gold, ScenePaint.paleGold, ScenePaint.white])
            case .lighthouse:
                // "Gull Point reached!" (ART-FLIGHT-SCHOOL §4): the beam sweep, the lamp flare, the gust toward the
                // storm, the motes; the horizon haze pulses to 0.75.
                props.quietBeam(for: 1.4)
                backdrop.pulse()
                reached.play(birdU: layout.size.width * ScreenLayout.birdScreenFraction, birdY: birdCanvasPoint.y,
                             reduceMotion: reduceMotion)
            case .cloudTouched:
                fx.cloudPuff(at: birdLocal, zoom: z, color: puffColor)
            case .milestone:
                // On a Duo the fold glints; elsewhere the horizon haze brightens (ART-S15).
                if layout.hasFold { creasePulse = 1 } else { backdrop.pulse() }
                fx.sparkles(at: birdLocal, count: 6, radius: 40, zoom: z, colors: [ScenePaint.paleGold, ScenePaint.white])
            case .newBest:
                props.cheerBuoy()
                if props.buoyShown && s.bestMeters > 0 {
                    let bxBest = s.bestMeters * 10
                    let p = CGPoint(x: CGFloat(bxBest - originX), y: CGFloat(seaHeight(bxBest) + 30))
                    fx.sparkles(at: p, count: 16, radius: 40, zoom: z, colors: [ScenePaint.gold, ScenePaint.white])
                } else {
                    fx.sparkles(at: birdLocal, count: 12, radius: 50, zoom: z, colors: [ScenePaint.gold, ScenePaint.white])
                }
            case .stormClose:
                storm.strike(strength: 1)
            case .caught, .countdownTick, .started, .tailwindEnded, .finished:
                break
            default:
                // Events added later (e.g. Flight School's) need nothing from the scene.
                break
            }
        }
    }

    /// The Tailwind's local sun flare (ART §5: ≤ 0.25 additive, never full-screen).
    private func updateFlare(dt: CGFloat) {
        flareLevel = max(0, flareLevel - dt * 2)
        let on = flareLevel > 0.002
        flare.isHidden = !on
        flareStreak.isHidden = !on
        guard on else { return }
        let k = flareLevel
        let peak: CGFloat = reduceMotion ? 0.12 : SceneLook.flarePeak
        let p = backdrop.sunPosition
        flare.position = p
        flare.size = CGSize(width: 220 + 260 * (1 - k), height: 220 + 260 * (1 - k))
        flare.alpha = peak * k
        flareStreak.position = p
        flareStreak.size = CGSize(width: 420 + 200 * (1 - k), height: 10)
        flareStreak.alpha = peak * 0.8 * k
    }

    /// The fold (Duo only, ART §8): the horizon glint (0.08, 0.12 on milestones) and the book-gutter shade that grows
    /// with the tuck (60 pt per side, α 0.10 × tuck).
    private func updateFold(tuck: CGFloat, dt: CGFloat) {
        guard layout.hasFold else {
            crease.isHidden = true
            gutterLeft.isHidden = true
            gutterRight.isHidden = true
            return
        }
        crease.isHidden = false
        creasePulse = max(0, creasePulse - dt / 0.6)
        let mid = (layout.creaseMinX + layout.creaseMaxX) * 0.5
        crease.position = CGPoint(x: mid, y: backdrop.horizonY)
        crease.alpha = SceneLook.creaseAlpha + (SceneLook.creasePulseAlpha - SceneLook.creaseAlpha) * creasePulse
        let g = gutterEnabled ? SceneLook.gutterAlpha * min(max(tuck, 0), 1) : 0
        if abs(g - gutterLevel) > 0.002 {
            gutterLevel = g
            let on = g > 0.003
            gutterLeft.isHidden = !on
            gutterRight.isHidden = !on
            gutterLeft.alpha = g
            gutterRight.alpha = g
        }
        gutterLeft.position = CGPoint(x: mid, y: 0)
        gutterRight.position = CGPoint(x: mid, y: 0)
    }

    private func updateMorph(wallDt: Double) {
        guard morphAge < SceneLook.morphTime + 0.01 else {
            if !titleRoot.isHidden { titleRoot.isHidden = true }
            if morphProgress < 1 {
                morphProgress = 1
                birdView.root.alpha = 1
                birdView.trailRoot.alpha = 1
            }
            return
        }
        morphAge += wallDt
        let k = CGFloat(min(morphAge / SceneLook.morphTime, 1))
        let e = k * k * (3 - 2 * k)
        morphProgress = k
        // Crossfade around the middle (dorsal out, side view in).
        let fade = min(max((e - 0.4) / 0.2, 0), 1)
        titleRoot.alpha = 1 - fade
        birdView.root.alpha = fade
        birdView.trailRoot.alpha = fade
        if reduceMotion {
            titleRoot.position = morphStart
            titleRoot.setScale(1)
        } else {
            let target = birdCanvasPoint
            let bodyPx = 0.9 * SceneLook.birdUnit * birdView.scale * drawnZoom
            let targetScale = max(0.05, bodyPx * 1.4 / max(layout.size.width * 0.92, 1))
            titleRoot.position = CGPoint(x: morphStart.x + (target.x - morphStart.x) * e,
                                         y: morphStart.y + (target.y - morphStart.y) * e)
            titleRoot.setScale(1 + (targetScale - 1) * e)
        }
    }

    // MARK: Cosmetics and layout

    private func applyCosmetics(bird b: Bird, sky k: Sky) {
        bird = b
        sky = k
        let real = ScenePalette.palette(k.id)
        // Flight School: the practice palette, or a step of the 2 s crossfade to the player's sky (the storm always
        // takes the player's sky: it is hidden in practice and rolls in with the real colours).
        let blend = appliedBlendStep
        var p = real
        var key: String?
        if blend >= 0.999 {
            p = ScenePalette.practice
            key = "practice"
        } else if blend > 0.001 {
            p = ScenePalette.blended(real, ScenePalette.practice, blend)
            key = "practice-\(k.id.rawValue)-\(Int((blend * SceneLook.practiceBlendSteps).rounded()))"
        }
        palette = p
        backgroundColor = ScenePaint.ui(p.horizon)
        foamColor = ScenePaint.ui(p.foam)
        sprayColor = ScenePaint.ui(p.foam.mixed(with: b.trail, 0.25))
        puffColor = ScenePaint.ui(p.cloud.mixed(with: ScenePaint.white, 0.6))
        backdrop.apply(palette: p, sky: k.id, key: key, dither: blend <= 0.001 || blend >= 0.999)
        seaView.apply(palette: p, sky: k.id, key: key)
        storm.apply(palette: real, sky: k.id)
        guides.apply(foam: foamColor)
        props.apply(palette: p)
        birdView.apply(bird: b, palette: p)
        speedLines.apply(color: ScenePaint.ui(p.foam), gold: ScenePaint.ui(ScenePaint.gold),
                         vignette: ScenePaint.ui(b.trail))
        flare.color = ScenePaint.ui(p.sunGlow)
        flareStreak.color = ScenePaint.ui(p.sunDisk)
        crease.color = ScenePaint.ui(p.horizon.mixed(with: ScenePaint.white, 0.2))
        for g in [gutterLeft, gutterRight] { g.color = ScenePaint.ui(ScenePalette.gutter) }
    }

    private func applyLayout() {
        size = layout.size
        viewCam = SceneCamera(layout: layout)
        needsSnap = true
        seaView.invalidate()
        let flipX: CGFloat = layout.mirrored ? -1 : 1
        for r in [backRoot, shadeRoot, frontRoot] {
            r.xScale = flipX
            r.position = CGPoint(x: layout.mirrored ? layout.size.width : 0, y: 0)
        }
        crease.size = CGSize(width: 80, height: SceneLook.creaseHalfHeight * 2)
        crease.isHidden = !layout.hasFold
        for g in [gutterLeft, gutterRight] {
            g.size = CGSize(width: SceneLook.gutterWidth, height: layout.size.height)
        }
        gutterLevel = -1
    }

    // MARK: The sea (Core's, or a stand-in before the first session)

    private func seaHeight(_ x: Double) -> Double {
        if let s = driver?.sea { return s.height(at: x) }
        return SceneFallbackSea.height(x)
    }

    private func seaSlope(_ x: Double) -> Double {
        if let s = driver?.sea { return s.slope(at: x) }
        return SceneFallbackSea.slope(x)
    }

    /// Fills `sampleBuffer` (reused, no allocation once grown) with the surface from x0 to x1.
    private func fillSamples(from x0: Double, to x1: Double, step: Double) {
        if let s = driver?.sea {
            s.samples(into: &sampleBuffer, from: x0, to: x1, step: step)
            return
        }
        sampleBuffer.removeAll(keepingCapacity: true)
        var x = x0
        while x <= x1 {
            sampleBuffer.append(CGPoint(x: x, y: SceneFallbackSea.height(x)))
            x += step
        }
    }
}

/// Speed lines at high speed (canvas u-space, ART-S11): at most 10 thin tapered streaks rushing from ahead to behind,
/// only in a band of ±0.18 h around the bird and never in the top 72 pt, gold at full speed. Reduce Motion: a soft 6 %
/// edge vignette in the trail colour instead.
@MainActor
final class SceneSpeedLines {
    let root: SKNode
    private var lines: [SKSpriteNode] = []
    private var pos: [CGPoint] = []
    private var speeds: [CGFloat] = []
    private var lengths: [CGFloat] = []
    private let vignetteLeft: SKSpriteNode
    private let vignetteRight: SKSpriteNode
    private var rng = SceneRNG(seed: 0x5EED_11)
    private var plainColor: UIColor = .white
    private var goldColor: UIColor = .yellow
    private var gold = false

    init(count: Int) {
        root = SKNode()
        let edge = SceneTextures.horizontalGradient(
            key: "edgevignette", colors: [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0)], locations: [0, 1])
        vignetteLeft = SKSpriteNode(texture: edge)
        vignetteRight = SKSpriteNode(texture: edge)
        for v in [vignetteLeft, vignetteRight] {
            v.colorBlendFactor = 1
            v.isHidden = true
            v.zPosition = -0.5
            root.addChild(v)
        }
        vignetteLeft.anchorPoint = CGPoint(x: 0, y: 0)
        vignetteRight.anchorPoint = CGPoint(x: 0, y: 0)
        vignetteRight.xScale = -1
        for _ in 0..<count {
            let s = SKSpriteNode(texture: SceneTextures.streak, size: CGSize(width: 90, height: 2))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.zRotation = CGFloat.pi
            s.isHidden = true
            root.addChild(s)
            lines.append(s)
            pos.append(CGPoint(x: rng.range(0, 952), y: rng.range(100, 600)))
            speeds.append(rng.range(0.8, 1.3))
            lengths.append(rng.range(80, 220))
        }
    }

    func apply(color: UIColor, gold g: UIColor, vignette: UIColor) {
        plainColor = color
        goldColor = g
        let c = gold ? goldColor : plainColor
        for l in lines { l.color = c }
        vignetteLeft.color = vignette
        vignetteRight.color = vignette
    }

    /// Gold streaks at full speed ("hit full speed" is something you can see).
    func setGold(_ on: Bool) {
        guard on != gold else { return }
        gold = on
        let c = gold ? goldColor : plainColor
        for l in lines { l.color = c }
    }

    func clear() {
        for l in lines where !l.isHidden { l.isHidden = true }
        vignetteLeft.isHidden = true
        vignetteRight.isHidden = true
    }

    func update(intensity: CGFloat, vignette: Bool, width: CGFloat, height: CGFloat, birdY: CGFloat, minY: CGFloat,
                maxY: CGFloat, dt: CGFloat) {
        guard intensity > 0.01 else {
            clear()
            return
        }
        if vignette {
            for l in lines where !l.isHidden { l.isHidden = true }
            for v in [vignetteLeft, vignetteRight] {
                v.isHidden = false
                v.size = CGSize(width: width * 0.12, height: height)
                v.alpha = SceneLook.speedVignetteAlpha * min(1, intensity * 1.5)
            }
            vignetteLeft.position = .zero
            vignetteRight.position = CGPoint(x: width, y: 0)
            return
        }
        vignetteLeft.isHidden = true
        vignetteRight.isHidden = true
        let band = SceneLook.speedLineBand * height
        let lo = max(birdY - band, minY + 10)
        let hi = min(birdY + band, maxY - SceneLook.speedLineTopClear)
        let boost: CGFloat = gold ? 1.4 : 1
        for i in 0..<lines.count {
            var p = pos[i]
            if dt > 0 {
                p.x -= (1800 + 1400 * intensity) * speeds[i] * dt
                if p.x < -240 || p.y < lo - 1 || p.y > hi + 1 {
                    let y = hi > lo ? rng.range(lo, hi) : lo
                    p = CGPoint(x: p.x < -240 ? width + rng.range(20, 260) : p.x, y: y)
                }
                pos[i] = p
            }
            let l = lines[i]
            let on = hi > lo
            l.isHidden = !on
            if on {
                l.position = p
                l.size = CGSize(width: lengths[i] * (0.6 + 0.4 * intensity), height: gold ? 2.4 : 1.8)
                l.alpha = min(SceneLook.speedLineAlpha, SceneLook.speedLineAlpha * intensity * boost)
            }
        }
    }
}
