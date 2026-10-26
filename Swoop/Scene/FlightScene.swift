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
///     backRoot  (z −100, u-space)  sky gradient, stars/aurora, sun + glow + haze, far clouds, 2 far swell layers,
///                                  sun glitter; the storm's cloud wall, its lightning glow and bolts
///     world     (z 0, sea space)   touchable clouds −40 · lighthouse −30 · PB buoy −11 · the near sea −10…−8.8 ·
///                                  rings + foam −6 · trail 14 · spray 15 · bird 20 · sparkles 30
///     shadeRoot (z 5, u-space)     the storm's grey wash over the sea (under the bird)
///     frontRoot (z 60, u-space)    rain, the caught wash, lightning flash, speed lines, the Tailwind flare
///     crease    (z 80)             a faint horizon glint on the fold (Duo only; nothing critical there)
///
/// The world node is the camera: scaled by the zoom (x flipped when mirrored) and positioned so the bird sits at 30 %
/// (70 % mirrored). World children use sea coordinates minus `originX`, a rebased origin that keeps numbers small on
/// long flights.
@MainActor
final class FlightScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no camera bump, no lightning flash, a gentle Tailwind flare, fewer particles and speed lines.
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
    private var snapshot = FlightSnapshot()
    private var lastUpdateTime: TimeInterval?
    private var lastSimTime: Double?
    private var needsSnap = true
    private var originX: Double = 0
    private var animTime: Double = 0
    private var lastBirdX: Double?
    private var seaPoints: [CGPoint] = []
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
    private var lighthouseCacheX: Double = .nan
    private var lighthouseCacheY: Double = 0

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
        storm.backRoot.zPosition = 5
        backRoot.addChild(storm.backRoot)

        world.zPosition = 0
        addChild(world)
        props.cloudRoot.zPosition = -40
        props.lighthouseRoot.zPosition = -30
        props.buoyRoot.zPosition = -11
        seaView.root.zPosition = -10
        fx.waterRoot.zPosition = -6
        birdView.trailRoot.zPosition = 14
        fx.root.zPosition = 15
        birdView.root.zPosition = 20
        fx.glowRoot.zPosition = 30
        for n in [props.cloudRoot, props.lighthouseRoot, props.buoyRoot, seaView.root, fx.waterRoot,
                  birdView.trailRoot, fx.root, birdView.root, fx.glowRoot] {
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
        needsSnap = true
        lastSimTime = nil
        lastBirdX = nil
        caughtness = 0
        goldTimer = 0
        flapPhase = 0
        launchFlap = 0
        dripTimer = 0
        bumpY = 0
        bumpVelocity = 0
        flareLevel = 0
        creasePulse = 0
        lighthouseCacheX = .nan
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
        if let d = driver {
            if d.bird != bird || d.sky != sky { applyCosmetics(bird: d.bird, sky: d.sky) }
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
        }
        render(simDt: simDt, events: events)
    }

    // MARK: Drawing

    private func render(simDt: Double, events: [FlightEvent]) {
        let s = snapshot
        let dt = CGFloat(simDt)
        animTime += simDt
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
            caughtness = min(1, caughtness + dt / 1.2)
        } else {
            caughtness = max(0, caughtness - dt * 2)
        }

        // The bird as displayed (hover in the countdown; bobbing low in the water once caught).
        let bx = Double(s.position.x)
        var by = Double(s.position.y)
        if countdown { by += SceneLook.hoverBob * sin(t * SceneLook.hoverRate) }
        if caught { by = seaHeight(bx) - SceneLook.caughtSink + SceneLook.caughtBob * sin(t * 1.7) }
        let water = seaHeight(bx)

        // Camera.
        let birdPoint = CGPoint(x: bx, y: by)
        if needsSnap {
            viewCam.snap(bird: birdPoint, water: water)
            originX = (bx / 2048).rounded(.down) * 2048
            lastBirdX = bx
            needsSnap = false
        } else {
            viewCam.update(bird: birdPoint, water: water, dt: simDt)
        }
        if abs(bx - originX) > 4096 {
            let newOrigin = (bx / 2048).rounded(.down) * 2048
            let d = CGFloat(originX - newOrigin)
            fx.shift(dx: d)
            birdView.shiftTrail(dx: d)
            originX = newOrigin
        }
        let z = CGFloat(viewCam.zoom)
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

        // The near sea.
        let range = viewCam.visibleSeaRange(margin: SceneLook.seaSideMargin)
        let step = max(3.0, (range.hi - range.lo) / SceneLook.seaMaxSegments)
        let raw = seaSamples(from: range.lo, to: range.hi, step: step)
        seaPoints.removeAll(keepingCapacity: true)
        let calm = Double(1 - caughtness)
        for p in raw {
            let sx = Double(p.x)
            var y = Double(p.y)
            y += SceneLook.rippleA * sin(sx * 0.047 - t * 2.3) + SceneLook.rippleB * sin(sx * 0.113 + t * 3.1)
            let k = min(max(1 - (sx - s.stormX) / SceneLook.chopReach, 0), 1) * calm
            if k > 0 {
                y += k * SceneLook.chopAmp * (0.6 * sin(sx * 0.083 + t * 6.1) + 0.4 * sin(sx * 0.041 - t * 4.3))
            }
            seaPoints.append(CGPoint(x: CGFloat(sx - originX), y: CGFloat(y)))
        }
        let bottomLocal = CGFloat(viewCam.bottomY) - SceneLook.seaBottomMargin / z
        seaView.update(points: seaPoints, bottom: bottomLocal, zoom: z, time: t, originX: originX)

        // Sky and far swells.
        let meanY = CGFloat(viewCam.meanWaterScreenY) + bumpY
        backdrop.update(width: w, height: h, meanY: meanY, zoom: z, scroll: scrollPx, time: t, dt: dt)

        // The storm front.
        let anchorU = w * ScreenLayout.birdScreenFraction
        let gapPx = CGFloat(bx - s.stormX) * z
        let edgeRaw = anchorU - gapPx
        let hintRange = SceneLook.stormHintScreens * w
        let closeness = min(max((hintRange - gapPx) / max(hintRange - anchorU, 1), 0), 1)
        let hintEdge = SceneLook.stormHintMin + (SceneLook.stormHintMax - SceneLook.stormHintMin) * closeness
        // Once the front overtakes the bird its wall stops just past it; the rain and the calm wash do the rest.
        let edgeU = min(max(edgeRaw, hintEdge), anchorU + 160)
        let fadeRange = max(SceneLook.stormFadeScreens * w, 1)
        let visibility = min(max(((SceneLook.stormHintScreens * w + fadeRange) - gapPx) / fadeRange, 0), 1)
        storm.update(edgeU: edgeU, visibility: max(visibility, caughtness), lead: CGFloat(s.lead),
                     caughtness: caughtness, size: layout.size, minY: visMinY, maxY: visMaxY,
                     horizonY: backdrop.horizonY, dt: dt)

        // Props: lighthouse, personal-best buoy, the cloud band.
        updateLighthouse(s, range: range, dt: dt)
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
        updateFlap(s, countdown: countdown, caught: caught, simDt: simDt)
        birdView.pose(tuck: tuck, flap: flapPhase)
        var angle = CGFloat(s.bodyAngle)
        if countdown { angle = CGFloat(0.06 * sin(t * SceneLook.hoverRate + 0.6)) }
        if caught { angle = CGFloat(atan(seaSlope(bx)) * 0.7 + 0.05 * sin(t * 1.3)) }
        let birdScale = pow(z, -SceneLook.birdZoomResist)
        let birdLocal = CGPoint(x: CGFloat(bx - originX), y: CGFloat(by))
        birdView.place(at: birdLocal, angle: angle, scale: birdScale)

        // Trail and continuous FX.
        let speedK = CGFloat(min(max((s.speed - 300) / 1500, 0), 1))
        goldTimer = max(0, goldTimer - dt)
        let tailwind = s.tailwindRemaining > 0
        let goldK: CGFloat = tailwind ? 1 : min(1, goldTimer / SceneLook.perfectGoldTime)
        birdView.updateTrail(emit: birdView.tailPoint, show: !caught && !countdown, time: t, zoom: z, speedK: speedK,
                             goldK: goldK, tailwind: tailwind, color: bird.trail)
        let foamColor = ScenePaint.ui(sky.foam)
        if s.skimming && !caught && !countdown && dt > 0 {
            let tip = birdView.wingtipPoint
            let tipWater = CGFloat(seaHeight(Double(tip.x) + originX))
            let v = s.velocity
            let len = max(hypot(v.dx, v.dy), 1)
            let back = CGVector(dx: -v.dx / len, dy: -v.dy / len)
            let sprayColor = ScenePaint.ui(sky.foam.mixed(with: bird.trail, 0.25))
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
        speedLines.update(intensity: lineK, width: w, minY: visMinY, maxY: visMaxY, dt: dt)

        handle(events, s: s, bx: bx, birdLocal: birdLocal, zoom: z, foam: foamColor)
        fx.update(dt)
        updateFlare(dt: dt)
        updateCrease(t: t, dt: dt)
    }

    private func updateFlap(_ s: FlightSnapshot, countdown: Bool, caught: Bool, simDt: Double) {
        launchFlap = max(0, launchFlap - simDt)
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
            flapPhase += simDt * rate
            if flapPhase >= 1 { flapPhase -= floor(flapPhase) }
        } else if flapPhase > 0 {
            // Finish the beat back to the rest pose, then hold.
            flapPhase += simDt * SceneLook.flapRateSlow
            if flapPhase >= 1 { flapPhase = 0 }
        }
    }

    private func updateLighthouse(_ s: FlightSnapshot, range: (lo: Double, hi: Double), dt: CGFloat) {
        var lx: Double?
        if s.lighthousesPassed > 0 {
            let passed = Lighthouses.x(index: s.lighthousesPassed - 1)
            if s.position.x - CGFloat(passed) < CGFloat(SceneLook.lighthouseKeepBehind) { lx = passed }
        }
        if lx == nil {
            lx = s.nextLighthouseX > 0 ? s.nextLighthouseX : Lighthouses.x(index: max(s.lighthousesPassed, 0))
        }
        guard let x = lx, x > range.lo - 400, x < range.hi + 400 else {
            props.hideLighthouse()
            return
        }
        if x != lighthouseCacheX {
            // The rock top clears every crest around it.
            var top = -Double.greatestFiniteMagnitude
            var sx = x - 100
            while sx <= x + 100 {
                top = max(top, seaHeight(sx))
                sx += 12.5
            }
            lighthouseCacheX = x
            lighthouseCacheY = top + 16
        }
        props.showLighthouse(at: CGPoint(x: CGFloat(x - originX), y: CGFloat(lighthouseCacheY)), dt: dt)
    }

    // MARK: Events → FX

    private func handle(_ events: [FlightEvent], s: FlightSnapshot, bx: Double, birdLocal: CGPoint, zoom z: CGFloat,
                        foam: UIColor) {
        guard !events.isEmpty else { return }
        let waterPoint = CGPoint(x: birdLocal.x, y: CGFloat(seaHeight(bx)))
        for e in events {
            switch e {
            case .launched(let speed):
                let k = CGFloat(min(max((speed - 300) / 1800, 0), 1))
                fx.launch(at: waterPoint, velocity: s.velocity, k: k, zoom: z, color: foam)
                viewCam.pullOut(reduceMotion ? 0.03 : 0.05 + 0.06 * Double(k))
                if speed < SceneLook.launchFlapSpeed { launchFlap = 0.42 }
            case .touchdown(let quality, let speed, let chain):
                let k = CGFloat(min(max((speed - 300) / 1800, 0), 1))
                switch quality {
                case .perfect:
                    fx.perfect(at: waterPoint, chain: chain, zoom: z, foamColor: foam)
                    goldTimer = SceneLook.perfectGoldTime
                case .good:
                    fx.good(at: waterPoint, zoom: z, color: foam)
                case .splash:
                    fx.splash(at: waterPoint, k: k, zoom: z, color: foam)
                    if !reduceMotion { bumpVelocity -= SceneLook.splashBump * (0.7 + 0.6 * k) }
                    dripTimer = 0.6
                }
            case .tailwindStarted:
                flareLevel = 1
                fx.sparkles(at: birdLocal, count: 22, radius: 60, zoom: z,
                            colors: [ScenePaint.gold, ScenePaint.paleGold, ScenePaint.white])
            case .lighthouse:
                props.sweepBeam()
                if props.lighthouseShown {
                    fx.sparkles(at: props.lampPoint, count: 12, radius: 30, zoom: z,
                                colors: [ScenePaint.paleGold, ScenePaint.white])
                }
            case .cloudTouched:
                fx.cloudPuff(at: birdLocal, zoom: z, color: ScenePaint.ui(sky.horizon.mixed(with: ScenePaint.white, 0.75)))
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

    private func updateCrease(t: Double, dt: CGFloat) {
        guard layout.hasFold else {
            crease.isHidden = true
            return
        }
        crease.isHidden = false
        creasePulse = max(0, creasePulse - dt * 0.6)
        crease.position = CGPoint(x: (layout.creaseMinX + layout.creaseMaxX) * 0.5, y: backdrop.horizonY)
        crease.alpha = CGFloat(0.10 + 0.04 * sin(t * 0.8)) + 0.22 * creasePulse
    }

    // MARK: Cosmetics and layout

    private func applyCosmetics(bird b: Bird, sky k: Sky) {
        bird = b
        sky = k
        backgroundColor = ScenePaint.ui(k.horizon)
        backdrop.apply(sky: k)
        seaView.apply(sky: k)
        storm.apply(sky: k)
        props.apply(sky: k)
        birdView.apply(bird: b)
        speedLines.apply(color: ScenePaint.ui(ScenePaint.lighter(k.horizon, 0.6)))
        flare.color = ScenePaint.ui(k.sun)
        flareStreak.color = ScenePaint.ui(ScenePaint.lighter(k.sun, 0.3))
        crease.color = ScenePaint.ui(ScenePaint.lighter(k.sun, 0.5))
    }

    private func applyLayout() {
        size = layout.size
        viewCam = SceneCamera(layout: layout)
        needsSnap = true
        let flipX: CGFloat = layout.mirrored ? -1 : 1
        for r in [backRoot, shadeRoot, frontRoot] {
            r.xScale = flipX
            r.position = CGPoint(x: layout.mirrored ? layout.size.width : 0, y: 0)
        }
        let band = max(layout.creaseMaxX - layout.creaseMinX, 20)
        crease.size = CGSize(width: band * 1.6, height: layout.size.height * 0.9)
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

/// Speed lines at high speed (canvas u-space): thin streaks rushing from ahead to behind.
@MainActor
final class SceneSpeedLines {
    let root: SKNode
    private var lines: [SKSpriteNode] = []
    private var pos: [CGPoint] = []
    private var speeds: [CGFloat] = []
    private var rng = SceneRNG(seed: 0x5EED_11)

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

    func apply(color: UIColor) {
        for l in lines { l.color = color }
    }

    func clear() {
        for l in lines { l.isHidden = true }
    }

    func update(intensity: CGFloat, width: CGFloat, minY: CGFloat, maxY: CGFloat, dt: CGFloat) {
        guard intensity > 0.01 else {
            clear()
            return
        }
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
            l.size = CGSize(width: 60 + 110 * intensity * speeds[i], height: 2)
            l.alpha = 0.32 * intensity
        }
    }
}
