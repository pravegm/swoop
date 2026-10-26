import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// The SpriteKit view of the flight (ARCHITECTURE "Scene API"). It draws only from snapshots, the sea and events, and
/// owns the cosmetic state (camera, spray, wake, rings, clouds, lighthouse beam, storm). It never changes game state.
///
/// Composition (canvas 952 × 670, origin bottom-left; "u-space" = canvas x measured from the behind edge, flipped
/// when `layout.mirrored`):
///
///     backRoot  (z −100, u-space)  sky gradient, stars/aurora, sun + glow + haze, far clouds, 2 far swell layers with
///                                  the lighthouse between them (a parallax depth layer), sun glitter; the storm's
///                                  anvil, its lightning glow and bolts
///     world     (z 0, sea space)   touchable clouds −40 · PB buoy −11 · the near sea −10…−8.8 · rings + foam −6 ·
///                                  trail 14 · spray 15 · bird 20 · sparkles 30
///     shadeRoot (z 5, u-space)     the storm's grey wash and rain sheets over the sea (under the bird)
///     frontRoot (z 60, u-space)    rain, the caught wash, lightning flash, speed lines, the Tailwind flare
///     crease    (z 80)             a faint glint on the fold at the horizon (Duo only; nothing critical there)
///
/// The world node is the camera: scaled by the zoom (x flipped when mirrored) and positioned so the bird sits at 30 %
/// (70 % mirrored). World children use sea coordinates minus `originX`, a rebased origin that keeps numbers small on
/// long flights.
///
/// Clocks: the camera follows the simulation's clock (it holds still when the snapshot does). FX run on an "FX clock":
/// the simulation's, plus wall time while the snapshot is held for up to `hitStopWindow` (the App's 35 ms Perfect
/// hit-stop), so the burst keeps moving through the hit-stop but a pause or a demo freeze still holds.
@MainActor
final class FlightScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no camera bump or punch-in, no lightning flash, a gentle Tailwind flare, fewer particles and
    /// speed lines.
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

    /// Frames drawn since the scene was made (CI waits for 120).
    private(set) var drawnFrames = 0
    /// The drawn zoom and the camera's display scale this frame (tests, tuning).
    private(set) var drawnZoom: CGFloat = 1
    private(set) var displayScale: CGFloat = 1
    /// Sea surface rebuilds so far (QA-1 P1-6: a few per second, not one per frame).
    var seaRebuilds: Int { seaView.rebuildCount }
    /// Whether the lighthouse is on screen, and where (u-space).
    private(set) var lighthouseU: CGFloat?

    private static let demoLogging: Bool = ProcessInfo.processInfo.arguments.contains("-swoopDemo")

    private var viewCam: SceneCamera
    private let backRoot: SKNode
    private let world: SKNode
    private let shadeRoot: SKNode
    private let frontRoot: SKNode
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

    private var bird: Bird = SceneDefaults.bird
    private var sky: Sky = SceneDefaults.sky
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
    private var fastKick: Double = 0

    init(layout: ScreenLayout) {
        self.layout = layout
        viewCam = SceneCamera(layout: layout)
        backRoot = SKNode()
        world = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
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
        // The lighthouse stands between the two far swell layers (−14 and −12 in the backdrop).
        props.lighthouseRoot.zPosition = -12.5
        backdrop.root.addChild(props.lighthouseRoot)
        storm.backRoot.zPosition = 5
        backRoot.addChild(storm.backRoot)

        world.zPosition = 0
        addChild(world)
        props.cloudRoot.zPosition = -40
        props.buoyRoot.zPosition = -11
        seaView.root.zPosition = -10
        fx.waterRoot.zPosition = -6
        birdView.trailRoot.zPosition = 14
        fx.root.zPosition = 15
        birdView.root.zPosition = 20
        fx.glowRoot.zPosition = 30
        for n in [props.cloudRoot, props.buoyRoot, seaView.root, fx.waterRoot, birdView.trailRoot, fx.root,
                  birdView.root, fx.glowRoot] {
            world.addChild(n)
        }

        shadeRoot.zPosition = 5
        addChild(shadeRoot)
        shadeRoot.addChild(storm.shadeRoot)

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

        crease.blendMode = .add
        crease.zPosition = 80
        crease.color = .white
        crease.colorBlendFactor = 1
        addChild(crease)

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
        fastKick = 0
        lighthouseU = nil
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt: Double = 1.0 / 120.0
        if let last = lastUpdateTime { dt = min(max(currentTime - last, 0), 1.0 / 30.0) }
        lastUpdateTime = currentTime
        drawnFrames += 1
        if drawnFrames == 120 && FlightScene.demoLogging {
            print("SWOOP-T frame 120")
            fflush(stdout)
        }

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
        render(simDt: simDt, fxDt: fxDt, events: events)
    }

    // MARK: Drawing

    private func render(simDt: Double, fxDt: Double, events: [FlightEvent]) {
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

        // The bird as displayed (hover in the countdown; bobbing low in the water once caught).
        let bx = Double(s.position.x)
        var by = Double(s.position.y)
        if countdown { by += SceneLook.hoverBob * sin(t * SceneLook.hoverRate) }
        if caught { by = seaHeight(bx) - SceneLook.caughtSink + SceneLook.caughtBob * sin(t * 1.7) }
        let water = seaHeight(bx)

        // Camera: framing on the simulation's clock, the punch-in and full-speed pull-out on the FX clock.
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
        var punch: Double = 0
        if !reduceMotion {
            if punchAge < SceneLook.punchAttack {
                punch = SceneLook.punchAmount * punchAge / SceneLook.punchAttack
            } else {
                let k = max(0, 1 - (punchAge - SceneLook.punchAttack) / SceneLook.punchRelease)
                punch = SceneLook.punchAmount * k * k
            }
        }
        let kickTarget = caught || countdown ? 0
            : min(max((s.speed - SceneLook.fastPullOutFrom) / SceneLook.fastPullOutRange, 0), 1)
        fastKick += (kickTarget - fastKick) * min(1, fxDt * 3)
        viewCam.setDisplayScale((1 + punch) * (1 - SceneLook.fastPullOut * fastKick))
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

        // The storm's geometry (u-space): always on screen, scaled to the gap.
        let anchorU = w * ScreenLayout.birdScreenFraction
        let gapPx = CGFloat(bx - s.stormX) * z
        let edgeRaw = anchorU - gapPx
        let closeness = min(max(1 - (gapPx - anchorU) / max(SceneLook.stormRangeScreens * w, 1), 0), 1)
        let hintEdge = SceneLook.stormEdgeFar + (SceneLook.stormEdgeNear - SceneLook.stormEdgeFar) * closeness
        // Once the front overtakes the bird its wall stops just past it; the rain and the calm wash do the rest.
        let edgeU = min(max(edgeRaw, hintEdge), anchorU + 160)

        // The near sea: rebuilt only when the cached surface no longer covers the view.
        let range = viewCam.visibleSeaRange(margin: SceneLook.seaSideMargin)
        let calm = Double(1 - caughtness)
        if let req = seaView.rebuildRequest(visibleLo: range.lo, visibleHi: range.hi, zoom: z, stormX: s.stormX,
                                            stormNear: gapPx < 1.6 * w, calm: calm, originX: originX) {
            let raw = seaSamples(from: req.lo, to: req.hi, step: req.step)
            seaView.rebuild(samples: raw, lo: req.lo, hi: req.hi, zoom: z, stormX: s.stormX, calm: calm,
                            originX: originX)
        }
        seaView.animate(zoom: z, time: t, visibleLo: range.lo, visibleHi: range.hi, originX: originX)

        // Sky and far swells.
        let meanY = CGFloat(viewCam.meanWaterScreenY) + bumpY
        backdrop.setDim(caughtness)
        backdrop.update(width: w, height: h, meanY: meanY, zoom: z, scroll: scrollPx, time: t, dt: dt)

        storm.update(edgeU: edgeU, closeness: closeness, lead: CGFloat(s.lead), caughtness: caughtness,
                     size: layout.size, minY: visMinY, maxY: visMaxY, horizonY: backdrop.horizonY, dt: dt)

        // Props: the lighthouse (depth layer), the personal-best buoy, the cloud band.
        updateLighthouse(s, bx: bx, zoom: z, anchorU: anchorU, width: w, dt: dt)
        if s.bestMeters > 0 {
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
        birdView.pose(tuck: tuck, flap: flapPhase)
        var angle = CGFloat(s.bodyAngle)
        if countdown { angle = CGFloat(0.06 * sin(t * SceneLook.hoverRate + 0.6)) }
        // Caught: level, gently rocking (REVIEW-1 P1-6: not nose-up on a slope).
        if caught { angle = CGFloat(0.04 * sin(t * 1.3)) }
        let birdScale = pow(z, -SceneLook.birdZoomResist)
        let birdLocal = CGPoint(x: CGFloat(bx - originX), y: CGFloat(by))
        birdView.place(at: birdLocal, angle: angle, scale: birdScale)

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
            if reduceMotion { lineK *= 0.4 }
        }
        speedLines.setGold(s.speed >= SceneLook.goldSpeedFraction * Tuning.maxSpeed)
        speedLines.update(intensity: lineK, width: w, minY: visMinY, maxY: visMaxY, dt: dt)

        handle(events, s: s, bx: bx, birdLocal: birdLocal, zoom: z)
        fx.update(dt)
        updateFlare(dt: dt)
        updateCrease(dt: dt)
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
                switch quality {
                case .perfect:
                    fx.perfect(at: waterPoint, chain: chain, zoom: z, foamColor: foamColor)
                    goldTimer = SceneLook.perfectGoldTime
                    punchAge = 0
                case .good:
                    fx.good(at: waterPoint, zoom: z, color: foamColor)
                case .splash:
                    fx.splash(at: waterPoint, k: k, zoom: z, color: foamColor)
                    if !reduceMotion { bumpVelocity -= SceneLook.splashBump * (0.7 + 0.6 * k) }
                    dripTimer = 0.6
                }
            case .tailwindStarted:
                flareLevel = 1
                fx.sparkles(at: birdLocal, count: 22, radius: 60, zoom: z,
                            colors: [ScenePaint.gold, ScenePaint.paleGold, ScenePaint.white])
            case .lighthouse:
                props.sweepBeam()
            case .cloudTouched:
                fx.cloudPuff(at: birdLocal, zoom: z, color: puffColor)
            case .milestone:
                backdrop.pulse()
                creasePulse = 1
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

    private func updateFlare(dt: CGFloat) {
        flareLevel = max(0, flareLevel - dt * 0.75)
        let on = flareLevel > 0.002
        flare.isHidden = !on
        flareStreak.isHidden = !on
        guard on else { return }
        let k = flareLevel
        let peak: CGFloat = reduceMotion ? 0.25 : 0.65
        let p = backdrop.sunPosition
        flare.position = p
        flare.size = CGSize(width: 260 + 520 * (1 - k), height: 260 + 520 * (1 - k))
        flare.alpha = peak * k
        flareStreak.position = p
        flareStreak.size = CGSize(width: 900 + 500 * (1 - k), height: 16)
        flareStreak.alpha = peak * 0.8 * k
    }

    /// The fold's glint: a short band at the horizon (REVIEW-1 P1-5), brighter only on a milestone.
    private func updateCrease(dt: CGFloat) {
        guard layout.hasFold else {
            crease.isHidden = true
            return
        }
        crease.isHidden = false
        creasePulse = max(0, creasePulse - dt * 0.6)
        crease.position = CGPoint(x: (layout.creaseMinX + layout.creaseMaxX) * 0.5, y: backdrop.horizonY)
        crease.alpha = SceneLook.creaseAlpha + (SceneLook.creasePulseAlpha - SceneLook.creaseAlpha) * creasePulse
    }

    // MARK: Cosmetics and layout

    private func applyCosmetics(bird b: Bird, sky k: Sky) {
        bird = b
        sky = k
        backgroundColor = ScenePaint.ui(k.horizon)
        foamColor = ScenePaint.ui(k.foam)
        sprayColor = ScenePaint.ui(k.foam.mixed(with: b.trail, 0.25))
        puffColor = ScenePaint.ui(k.horizon.mixed(with: ScenePaint.white, 0.75))
        backdrop.apply(sky: k)
        seaView.apply(sky: k)
        storm.apply(sky: k)
        props.apply(sky: k)
        birdView.apply(bird: b)
        speedLines.apply(color: ScenePaint.ui(ScenePaint.lighter(k.horizon, 0.6)),
                         gold: ScenePaint.ui(ScenePaint.gold))
        flare.color = ScenePaint.ui(k.sun)
        flareStreak.color = ScenePaint.ui(ScenePaint.lighter(k.sun, 0.3))
        crease.color = ScenePaint.ui(ScenePaint.lighter(k.sun, 0.5))
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
        let band = max(layout.creaseMaxX - layout.creaseMinX, 20)
        crease.size = CGSize(width: band * 1.6, height: SceneLook.creaseHalfHeight * 2)
        crease.isHidden = !layout.hasFold
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

    private func seaSamples(from x0: Double, to x1: Double, step: Double) -> [CGPoint] {
        if let s = driver?.sea { return s.samples(from: x0, to: x1, step: step) }
        var out: [CGPoint] = []
        var x = x0
        while x <= x1 {
            out.append(CGPoint(x: x, y: SceneFallbackSea.height(x)))
            x += step
        }
        return out
    }
}

/// Speed lines at high speed (canvas u-space): thin streaks rushing from ahead to behind, gold at full speed.
@MainActor
final class SceneSpeedLines {
    let root: SKNode
    private var lines: [SKSpriteNode] = []
    private var pos: [CGPoint] = []
    private var speeds: [CGFloat] = []
    private var rng = SceneRNG(seed: 0x5EED_11)
    private var plainColor: UIColor = .white
    private var goldColor: UIColor = .yellow
    private var gold = false

    init(count: Int) {
        root = SKNode()
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
        }
    }

    func apply(color: UIColor, gold g: UIColor) {
        plainColor = color
        goldColor = g
        let c = gold ? goldColor : plainColor
        for l in lines { l.color = c }
    }

    /// Gold streaks at full speed (REVIEW-1 P1-8: "hit full speed" is something you can see).
    func setGold(_ on: Bool) {
        guard on != gold else { return }
        gold = on
        let c = gold ? goldColor : plainColor
        for l in lines { l.color = c }
    }

    func clear() {
        for l in lines where !l.isHidden { l.isHidden = true }
    }

    func update(intensity: CGFloat, width: CGFloat, minY: CGFloat, maxY: CGFloat, dt: CGFloat) {
        guard intensity > 0.01 else {
            clear()
            return
        }
        let boost: CGFloat = gold ? 1.5 : 1
        for i in 0..<lines.count {
            var p = pos[i]
            if dt > 0 {
                p.x -= (1800 + 1400 * intensity) * speeds[i] * dt
                if p.x < -120 {
                    p = CGPoint(x: width + rng.range(20, 260), y: rng.range(minY + 20, max(maxY - 20, minY + 21)))
                }
                pos[i] = p
            }
            let l = lines[i]
            l.isHidden = false
            l.position = p
            l.size = CGSize(width: (60 + 110 * intensity * speeds[i]) * boost, height: gold ? 2.6 : 2)
            l.alpha = min(1, 0.32 * intensity * boost)
        }
    }
}
