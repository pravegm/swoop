import Foundation
import QuartzCore
import SpriteKit
import UIKit

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
    /// The morph's progress 0…1 (1 = done or not running).
    private(set) var morphProgress: CGFloat = 1
    /// The sun's centre in canvas points (SpriteKit, y up), so the App can keep text off it (UX P1-3).
    private(set) var sunCanvasPoint: CGPoint = .zero
    /// The storm's lead-meter fill this frame (`SceneStormMap.meterFill`), for tests and the HUD.
    private(set) var stormMeterFill: CGFloat = 1
    /// False in store-capture mode: no book-gutter shade (REVIEW-3 juror #26).
    var gutterEnabled: Bool = true

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
        for n in [props.cloudRoot, props.buoyRoot, seaView.root, birdView.shadow, fx.waterRoot, birdView.trailRoot,
                  fx.root, birdView.root, fx.glowRoot] as [SKNode] {
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
        if caught {
            caughtness = min(1, caughtness + dt / SceneLook.caughtEase)
        } else {
            caughtness = max(0, caughtness - dt * 2)
        }
        // 1.5 s ease-in-out for the caught ending.
        let caughtEase = caughtness * caughtness * (3 - 2 * caughtness)
        if !countdown && !caught { flightTime += fxDt } else if countdown { flightTime = 0 }
        // The first 2 s of a run use only big shapes (ART §8, the fold blur), as does the App's blur guard.
        let fine = fineDetail && !countdown && flightTime > 2

        // The bird as displayed (hover in the countdown; bobbing low in the water once caught).
        let bx = Double(s.position.x)
        var by = Double(s.position.y)
        if countdown { by += SceneLook.hoverBob * sin(t * SceneLook.hoverRate) }
        if caught { by = seaHeight(bx) - SceneLook.caughtSink + SceneLook.caughtBob * sin(t * 1.7) }
        let water = seaHeight(bx)

        // Camera: framing on the simulation's clock; the punch-in and the pull-outs on the FX clock.
        let birdPoint = CGPoint(x: bx, y: by)
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
        viewCam.setDisplayScale((1 + punch) * (1 - SceneLook.fastPullOut * fastKick) * (1 - tailwindPull))
        displayScale = CGFloat(viewCam.displayScale)

        if abs(bx - originX) > 4096 {
            let newOrigin = (bx / 2048).rounded(.down) * 2048
            let d = CGFloat(originX - newOrigin)
            fx.shift(dx: d)
            birdView.shiftTrail(dx: d)
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
        let fill = SceneStormMap.meterFill(gap: gap)
        stormMeterFill = fill
        let closeness = SceneStormMap.closeness(meterFill: fill)
        let target = SceneStormMap.edgeU(meterFill: fill, birdPageWidth: layout.creaseMinX, anchorU: anchorU)
        if stormEdge < 0 {
            stormEdge = target
        } else if dt > 0 {
            stormEdge += (target - stormEdge) * min(1, dt * 3.5)
        }
        var edgeU = stormEdge
        let caughtEdge = SceneLook.stormCaughtEdge * w
        edgeU += (max(edgeU, caughtEdge) - edgeU) * caughtEase

        // The near sea: rebuilt only when the cached surface no longer covers the view (QA-2 P2-2).
        let range = viewCam.visibleSeaRange(margin: SceneLook.seaSideMargin)
        let calm = Double(1 - caughtness)
        let chopOnScreen = s.stormX + SceneLook.chopReach > range.lo
        if let req = seaView.rebuildRequest(visibleLo: range.lo, visibleHi: range.hi, zoom: z, stormX: s.stormX,
                                            chopOnScreen: chopOnScreen, closeness: Double(closeness), calm: calm,
                                            originX: originX) {
            fillSamples(from: req.lo, to: req.hi, step: req.step)
            seaView.rebuild(samples: sampleBuffer, lo: req.lo, hi: req.hi, zoom: z, stormX: s.stormX,
                            closeness: Double(closeness), calm: calm, originX: originX)
        }
        let sunSeaX = bx + Double((SceneLook.sunU * w - anchorU) / max(z, 0.01))
        let fast = CGFloat(min(max((s.speed / Tuning.maxSpeed - 0.75) / 0.15, 0), 1))
        seaView.animate(zoom: z, time: t, visibleLo: range.lo, visibleHi: range.hi, originX: originX,
                        sunSeaX: sunSeaX, reach: SceneLook.glintReach * w, fast: fast, fine: fine)

        // Sky and far swells; the sun dims 0.15 c in play and by half when caught.
        let meanY = CGFloat(viewCam.meanWaterScreenY) + bumpY
        let sunDim = SceneLook.stormSunDim * closeness * (1 - caughtEase) + SceneLook.caughtSunDim * caughtEase
        backdrop.update(width: w, height: h, visibleTop: visMaxY, meanY: meanY, zoom: z, scroll: scrollPx, time: t,
                        dt: dt, sunDim: sunDim, drift: !reduceMotion)

        let sunU = backdrop.sunPosition.x
        sunCanvasPoint = CGPoint(x: layout.mirrored ? w - sunU : sunU, y: backdrop.sunPosition.y)
        let sunWater = viewCam.screenPoint(CGPoint(x: sunSeaX, y: seaHeight(sunSeaX)))
        nearGlitter.position = CGPoint(x: sunU, y: CGFloat(sunWater.y) + bumpY + 2)
        nearGlitter.size = CGSize(width: w * SceneLook.glitterWidth, height: SceneLook.nearGlitterDepth)
        nearGlitter.alpha = SceneLook.nearGlitterAlpha * backdrop.sunBrightness * CGFloat(0.85 + 0.15 * sin(t * 6.0))
        storm.update(edgeU: edgeU, closeness: closeness, lead: CGFloat(s.lead), caughtness: caughtEase,
                     size: layout.size, minY: visMinY, maxY: visMaxY, horizonY: backdrop.horizonY, birdU: anchorU, dt: dt)

        // Props: the lighthouse (depth layer), the personal-best buoy (Flight only, UX-S2), the cloud band.
        updateLighthouse(s, bx: bx, zoom: z, anchorU: anchorU, width: w, dt: dt)
        if s.bestMeters > 0 && s.mode == .flight {
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

        // The bird.
        var tuck = s.tuck
        if caught { tuck = 1 } else if countdown { tuck = 0 }
        updateFlap(s, countdown: countdown, caught: caught, dt: fxDt)
        birdView.pose(tuck: tuck, flap: flapPhase, dt: dt)
        var angle = CGFloat(s.bodyAngle)
        if countdown { angle = CGFloat(0.06 * sin(t * SceneLook.hoverRate + 0.6)) }
        if caught { angle = CGFloat(0.04 * sin(t * 1.3)) }
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
        fx.followPoint = CGPoint(x: birdLocal.x - SceneLook.ringBehind / max(z, 0.01), y: CGFloat(water))

        // Trail and continuous FX.
        let speedK = CGFloat(min(max((s.speed - 300) / 1500, 0), 1))
        goldTimer = max(0, goldTimer - dt)
        let tailwind = s.tailwindRemaining > 0
        let goldK: CGFloat = tailwind ? 1 : min(1, goldTimer / SceneLook.perfectGoldTime)
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
            lineK = CGFloat(min(max((s.speed - SceneLook.speedLinesFrom) / SceneLook.speedLinesRange, 0), 1))
            if tailwind { lineK = max(lineK, 0.35) }
        }
        speedLines.setGold(s.speed >= SceneLook.goldSpeedFraction * Tuning.maxSpeed)
        let birdCanvasY = CGFloat(viewCam.screenPoint(birdPoint).y)
        speedLines.update(intensity: fine ? lineK : 0, vignette: reduceMotion, width: w, height: h, birdY: birdCanvasY,
                          minY: visMinY, maxY: visMaxY, dt: dt)

        handle(events, s: s, bx: bx, birdLocal: birdLocal, zoom: z)
        fx.update(dt)
        updateFlare(dt: dt)
        updateFold(tuck: CGFloat(caught || countdown ? 0 : s.tuck), dt: dt)
        updateMorph(wallDt: wallDt)
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

    /// The lighthouse stands on the far swells: u = the bird's + `lighthouseLead` + (its x − the bird's) × zoom ×
    /// parallax. So it comes in from the right well before the pass, stands just ahead of the bird at the pass, and
    /// drifts back slowly afterwards (REVIEW-1 P0-7).
    private func updateLighthouse(_ s: FlightSnapshot, bx: Double, zoom z: CGFloat, anchorU: CGFloat, width w: CGFloat,
                                  dt: CGFloat) {
        let p = SceneLook.lighthouseParallax
        var shown: CGFloat?
        if s.lighthousesPassed > 0 {
            let passed = Lighthouses.x(index: s.lighthousesPassed - 1)
            let u = anchorU + SceneLook.lighthouseLead + CGFloat(passed - bx) * z * p
            if u > -220 { shown = u }
        }
        if shown == nil {
            let next = s.nextLighthouseX > 0 ? s.nextLighthouseX : Lighthouses.x(index: max(s.lighthousesPassed, 0))
            let u = anchorU + SceneLook.lighthouseLead + CGFloat(next - bx) * z * p
            if u < w + 220 { shown = u }
        }
        lighthouseU = shown
        guard let u = shown else {
            props.hideLighthouse()
            return
        }
        let scale = SceneLook.lighthouseScale * (0.55 + 0.45 * z)
        props.showLighthouse(at: CGPoint(x: u, y: backdrop.frontBaseY + 4), scale: scale, dt: dt)
    }

    // MARK: Events → FX

    private func handle(_ events: [FlightEvent], s: FlightSnapshot, bx: Double, birdLocal: CGPoint, zoom z: CGFloat) {
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
                    // The punch-in comes only at chain milestones (ROUND-4 P1-8: make Perfects special again).
                    if FlightScene.isChainMilestone(chain) { punchAge = 0 }
                case .good:
                    fx.good(at: waterPoint, zoom: z, color: foamColor)
                case .splash:
                    fx.splash(at: waterPoint, k: k, zoom: z, color: foamColor)
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
                props.sweepBeam()
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
        let p = ScenePalette.palette(k.id)
        palette = p
        backgroundColor = ScenePaint.ui(p.horizon)
        foamColor = ScenePaint.ui(p.foam)
        sprayColor = ScenePaint.ui(p.foam.mixed(with: b.trail, 0.25))
        puffColor = ScenePaint.ui(p.cloud.mixed(with: ScenePaint.white, 0.6))
        backdrop.apply(palette: p, sky: k.id)
        seaView.apply(palette: p, sky: k.id)
        storm.apply(palette: p, sky: k.id)
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
