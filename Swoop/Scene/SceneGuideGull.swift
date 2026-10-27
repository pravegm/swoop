import SpriteKit
import UIKit

/// The guide gull's moves (ART-ROUND-9 §1A, UX-ROUND-9 §1.2).
enum SceneGhostMove: Equatable {
    /// Tucks at the crest and stays tucked to the trough.
    case dive
    /// Opens at the trough and launches.
    case soar
    /// Descends wings open and lands inside the ring (a ghost Perfect: the ring in gold outline only).
    case land
    /// All three over two swells, as a leader to follow.
    case rhythm
}

extension SceneGhostMove {
    /// From the App's move names ("dive", "soar", "land", "rhythm"); nil for anything else.
    init?(name: String) {
        switch name {
        case "dive": self = .dive
        case "soar": self = .soar
        case "land": self = .land
        case "rhythm": self = .rhythm
        default: return nil
        }
    }
}

/// The guide gull's pose for one frame when the App plays Core's ghost path itself (`FlightScene.guideGhost`): sea
/// position, tuck, the body angle (radians; nil = from the motion), the move, and `landed` from the frame the ghost
/// touches down in the ring (the scene fires the ghost Perfect once).
struct SceneGhostPose: Equatable {
    var x: Double
    var y: Double
    var tuck: Double
    var bodyAngle: Double?
    var move: SceneGhostMove
    var landed: Bool = false
}

/// One point of a ghost flight: seconds from its start, sea position, and the tuck 0…1. Core's
/// `practiceGhostPath(step:)` samples map onto this one for one (`t, x, y, tuck`).
struct SceneGhostSample: Equatable {
    var t: Double
    var x: Double
    var y: Double
    var tuck: Double
}

/// A scripted stand-in for Core's ghost replay (pure, unit-tested): simple surface-riding and ballistic kinematics
/// with the move's tuck curve, so the guide gull can fly even before Core's path is wired.
enum SceneGhostFlight {
    static let step: Double = 1.0 / 60.0

    /// `birdX`: the player's sea x; `lead`: how far ahead (sea pt) the ghost starts; `ringX`: the landing ring (land).
    static func synthesize(_ move: SceneGhostMove, birdX: Double, lead: Double, ringX: Double?,
                           height: (Double) -> Double) -> [SceneGhostSample] {
        switch move {
        case .dive: return dive(birdX: birdX, lead: lead, height: height)
        case .soar: return soar(birdX: birdX, lead: lead, height: height)
        case .land: return land(birdX: birdX, ringX: ringX, height: height)
        case .rhythm: return rhythm(birdX: birdX, lead: lead, height: height)
        }
    }

    private static func slope(_ x: Double, _ h: (Double) -> Double) -> Double { (h(x + 2) - h(x - 2)) / 4 }

    /// The next trough at or after `x` (where the surface turns from falling to rising).
    static func nextTrough(after x: Double, height: (Double) -> Double) -> Double? {
        var p = x
        // Down to the bottom of whatever is ahead: skip a rise first.
        while p < x + 9000 && slope(p, height) > 0.002 { p += 8 }
        while p < x + 9000 && slope(p, height) <= 0.002 { p += 8 }
        return p < x + 9000 ? p : nil
    }

    /// The next crest at or after `x`.
    static func nextCrest(after x: Double, height: (Double) -> Double) -> Double? {
        var p = x
        while p < x + 9000 && slope(p, height) <= 0.002 { p += 8 }
        while p < x + 9000 && slope(p, height) > 0.002 { p += 8 }
        return p < x + 9000 ? p : nil
    }

    private static func dive(birdX: Double, lead: Double, height h: (Double) -> Double) -> [SceneGhostSample] {
        guard let d = SceneGuidePlacement.nextDownslope(after: birdX + lead, height: h) else { return [] }
        var out: [SceneGhostSample] = []
        var x = d.from, v = 380.0, t = 0.0
        while x < d.to && t < 4 {
            let s = slope(x, h)
            let a = 1100 * max(-s / (1 + s * s).squareRoot(), 0.05)
            v = min(v + a * step, 2600)
            out.append(SceneGhostSample(t: t, x: x, y: h(x), tuck: min(1, t / 0.25)))
            x += v * step / (1 + s * s).squareRoot()
            t += step
        }
        out.append(SceneGhostSample(t: t, x: d.to, y: h(d.to), tuck: 1))
        return out
    }

    private static func soar(birdX: Double, lead: Double, height h: (Double) -> Double) -> [SceneGhostSample] {
        guard let trough = nextTrough(after: birdX + lead * 0.5, height: h),
              let crest = nextCrest(after: trough, height: h) else { return [] }
        let rise = max(h(crest) - h(trough), 1)
        var out: [SceneGhostSample] = []
        var x = trough, v = 1500.0, t = 0.0
        // Ride up the face, opening, to 35 % of its height…
        while t < 2 && h(x) - h(trough) < 0.35 * rise && x < crest {
            let s = slope(x, h)
            out.append(SceneGhostSample(t: t, x: x, y: h(x), tuck: max(0, 1 - t / 0.2)))
            v = max(v - 600 * step, 600)
            x += v * step / (1 + s * s).squareRoot()
            t += step
        }
        // …then launch along the surface and fly a ballistic arc back down to the water.
        let s0 = slope(x, h)
        let k = 1 / (1 + s0 * s0).squareRoot()
        var vx = v * k, vy = v * s0 * k + 120
        var y = h(x)
        var air = 0.0
        while t < 4 {
            out.append(SceneGhostSample(t: t, x: x, y: y, tuck: 0.05))
            vy -= 1300 * step
            x += vx * step
            y += vy * step
            vx = max(vx - 40 * step, 300)
            air += step
            t += step
            if air > 0.2 && y <= h(x) { break }
        }
        out.append(SceneGhostSample(t: t, x: x, y: h(x), tuck: 0.1))
        return out
    }

    private static func land(birdX: Double, ringX: Double?, height h: (Double) -> Double) -> [SceneGhostSample] {
        guard let rx = ringX ?? SceneGuidePlacement.landingX(after: birdX, height: h) else { return [] }
        let x0 = rx - 650, y0 = h(x0) + 170
        let duration = 1.3, g = 900.0
        let y1 = h(rx)
        let vy0 = (y1 - y0 + 0.5 * g * duration * duration) / duration
        var out: [SceneGhostSample] = []
        var t = 0.0
        while t < duration {
            let x = x0 + 650 * t / duration
            let y = y0 + vy0 * t - 0.5 * g * t * t
            out.append(SceneGhostSample(t: t, x: x, y: max(y, h(x)), tuck: 0.1 + 0.1 * t / duration))
            t += step
        }
        out.append(SceneGhostSample(t: duration, x: rx, y: y1, tuck: 0.2))
        return out
    }

    private static func rhythm(birdX: Double, lead: Double, height h: (Double) -> Double) -> [SceneGhostSample] {
        var out: [SceneGhostSample] = []
        var x = birdX + lead, t = 0.0, tuck = 0.0
        var troughs = 0
        var wasFalling = slope(x, h) < 0
        while t < 4.5 && troughs < 3 {
            let s = slope(x, h)
            let falling = s < -0.01
            let target = falling ? 1.0 : (s > 0.01 ? 0.0 : tuck)
            tuck += (target - tuck) * min(1, step * 10)
            out.append(SceneGhostSample(t: t, x: x, y: h(x), tuck: tuck))
            if wasFalling && s > 0.01 { troughs += 1 }
            if s < -0.01 { wasFalling = true } else if s > 0.01 { wasFalling = false }
            x += 1300 * step / (1 + s * s).squareRoot()
            t += step
        }
        return out
    }

    /// The sample at time `t` (linear between neighbours; clamped to the ends).
    static func sample(_ path: [SceneGhostSample], at t: Double) -> SceneGhostSample? {
        guard let first = path.first, let last = path.last else { return nil }
        if t <= first.t { return first }
        if t >= last.t { return last }
        var lo = 0, hi = path.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if path[mid].t <= t { lo = mid } else { hi = mid }
        }
        let a = path[lo], b = path[hi]
        let k = (t - a.t) / max(b.t - a.t, 0.000_001)
        return SceneGhostSample(t: t, x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k,
                                tuck: a.tuck + (b.tuck - a.tuck) * k)
    }
}

/// The guide gull (ART-ROUND-9 §1A, SR1): a ghost of the player's own bird, 0.9× its size, in foam with a gold outline
/// and glow, that flies each move first and leaves a dotted gold path to copy. World-local (sea x − origin).
@MainActor
final class SceneGuideGull {
    /// At the world's origin; the ghost's art moves inside it, the dots stay where they were dropped.
    let root: SKNode
    private let art: SKNode
    private let glow: SKSpriteNode
    private let farWing: SKShapeNode
    private let body: SKShapeNode
    private let nearWing: SKShapeNode
    private var dots: [SKSpriteNode] = []
    private var dotAge: [Double] = []
    private var dotCursor = 0
    private var lastDot: CGPoint?
    private var motes: [SKSpriteNode] = []
    private var moteStart: [CGPoint] = []
    private var moteRise: [CGFloat] = []
    private var moteAge: Double = 10
    private var path: [SceneGhostSample] = []
    private var age: Double = 0
    private var holdAge: Double = 0
    private var fade: CGFloat = 0
    private var cache: [Int: (CGPath, CGPath, CGPath)] = [:]
    private var cachedBird: BirdID?
    private var poseKey = -1
    /// The move being flown, nil when no ghost is up.
    private(set) var move: SceneGhostMove?
    /// Whether the ghost is flying or holding its last pose (not yet dissolved).
    private(set) var isFlying = false
    /// The ghost's sea position and tuck now (the App's diagram shows its pose dashed).
    private(set) var position: CGPoint = .zero
    private(set) var tuck: Double = 0
    /// Set on the frame the ghost touches down at the end of `land` (the scene fires the ghost Perfect).
    private(set) var landedNow = false
    /// Set on the frame the ghost dissolves (the player's turn).
    private(set) var finishedNow = false
    /// Whether the path came from Core (false: the scene's own stand-in).
    private(set) var fromCore = false
    /// R12 (ROUND-12 P1-6): whether the ghost is drawn this frame. It flies on regardless, but it (and its dotted
    /// path) is drawn only while fully on screen and ahead of or level with the bird (`SceneTargets.ghostShows`).
    private(set) var isShown = false

    init() {
        root = SKNode()
        art = SKNode()
        glow = SKSpriteNode(texture: SceneTextures.soft)
        farWing = SKShapeNode()
        body = SKShapeNode()
        nearWing = SKShapeNode()
        root.addChild(art)
        glow.blendMode = .add
        glow.colorBlendFactor = 1
        glow.color = ScenePaint.ui(ScenePalette.rewardGold)
        glow.zPosition = -1
        art.addChild(glow)
        let foam = UIColor.white
        let gold = ScenePaint.ui(ScenePalette.rewardGold, alpha: SceneLook.ghostOutlineAlpha)
        for (n, z, a) in [(farWing, CGFloat(0), SceneLook.ghostWingAlpha), (body, CGFloat(1), SceneLook.ghostBodyAlpha),
                          (nearWing, CGFloat(2), SceneLook.ghostWingAlpha)] {
            n.fillColor = foam.withAlphaComponent(a)
            n.strokeColor = gold
            n.lineJoin = .round
            n.lineCap = .round
            n.zPosition = z
            art.addChild(n)
        }
        art.isHidden = true
        let dotTex = SceneTextures.dot
        for _ in 0..<64 {
            let d = SKSpriteNode(texture: dotTex)
            d.colorBlendFactor = 1
            d.color = ScenePaint.ui(ScenePalette.rewardGold)
            d.isHidden = true
            d.zPosition = -2
            root.addChild(d)
            dots.append(d)
            dotAge.append(10)
        }
        let soft = SceneTextures.soft
        for _ in 0..<SceneLook.ghostMotes {
            let m = SKSpriteNode(texture: soft)
            m.blendMode = .add
            m.colorBlendFactor = 1
            m.color = ScenePaint.ui(ScenePalette.rewardGold)
            m.isHidden = true
            m.zPosition = 3
            root.addChild(m)
            motes.append(m)
            moteStart.append(.zero)
            moteRise.append(0)
        }
    }

    var isActive: Bool { move != nil }

    private var driven = false
    private var external: SceneGhostPose?
    private var lastLanded = false

    /// The App's pose for this frame (nil: the ghost dissolves if it was showing).
    func drive(_ pose: SceneGhostPose?) {
        if let p = pose {
            if !driven {
                path = []
                lastDot = nil
                lastLanded = false
                position = CGPoint(x: p.x, y: p.y)
            }
            driven = true
            isFlying = true
            move = p.move
            external = p
        } else if driven {
            external = nil
        }
    }

    /// Flies `path` (sea; t from 0) as `move`.
    func play(_ m: SceneGhostMove, path p: [SceneGhostSample], fromCore core: Bool) {
        guard p.count >= 2 else {
            stop()
            return
        }
        move = m
        path = p
        fromCore = core
        age = 0
        holdAge = 0
        isFlying = true
        landedNow = false
        finishedNow = false
        lastDot = nil
        if let s = p.first {
            position = CGPoint(x: s.x, y: s.y)
            tuck = s.tuck
        }
    }

    /// Takes the ghost away at once (no motes); its dots fade on their own.
    func stop() {
        driven = false
        external = nil
        move = nil
        isFlying = false
        isShown = false
        path = []
        art.isHidden = true
        fade = 0
    }

    func clear() {
        stop()
        for (i, d) in dots.enumerated() {
            d.isHidden = true
            dotAge[i] = 10
        }
        for m in motes { m.isHidden = true }
        moteAge = 10
    }

    func shift(dx: CGFloat) {
        for d in dots where !d.isHidden { d.position.x += dx }
        for i in 0..<moteStart.count { moteStart[i].x += dx }
        if let l = lastDot { lastDot = CGPoint(x: l.x + dx, y: l.y) }
    }

    /// Per frame (FX clock). `bird`: the player's bird view (the species and its scale); `birdX`: the player's sea x;
    /// `visible`: whether a ghost at this sea point may be drawn (R12: fully on screen, ahead of or level with the bird).
    func update(dt: Double, zoom z: CGFloat, originX: Double, bird: SceneBirdView, birdX: Double, still: Bool,
                visible: (CGPoint) -> Bool = { _ in true }) {
        landedNow = false
        finishedNow = false
        isShown = false
        let zz = max(z, 0.01)
        // The dots fade over 1.6 s.
        for (i, d) in dots.enumerated() where !d.isHidden {
            dotAge[i] += dt
            let k = dotAge[i] / SceneLook.ghostDotLife
            if k >= 1 {
                d.isHidden = true
            } else {
                d.alpha = SceneLook.ghostDotAlpha * CGFloat(1 - k)
            }
        }
        updateMotes(dt: dt)

        // Driven by the App frame by frame (Core's ghost path at the App's pace).
        if driven {
            guard let p = external else {
                driven = false
                dissolve(at: CGPoint(x: position.x - CGFloat(originX), y: position.y), zoom: zz, still: still)
                return
            }
            age += dt
            let prev = position
            position = CGPoint(x: p.x, y: p.y)
            tuck = p.tuck
            if p.landed && !lastLanded { landedNow = true }
            lastLanded = p.landed
            let derived = atan2(Double(position.y - prev.y), max(Double(position.x - prev.x), 0.001))
            let s = SceneGhostSample(t: 0, x: p.x, y: p.y, tuck: p.tuck)
            drawPose(s, angle: p.bodyAngle ?? derived, zoom: zz, originX: originX, bird: bird, dt: dt, still: still,
                     show: visible(CGPoint(x: p.x, y: p.y)))
            return
        }
        guard isFlying, let first = path.first, let last = path.last else {
            fade = max(0, fade - CGFloat(dt) / 0.25)
            art.isHidden = fade <= 0.002
            if !art.isHidden { art.alpha = fade }
            return
        }
        age += dt
        let wasBefore = age - dt < last.t
        if age >= last.t {
            holdAge += dt
            if wasBefore && move == .land { landedNow = true }
        }
        let s = SceneGhostFlight.sample(path, at: min(age, last.t)) ?? first
        let ahead = SceneGhostFlight.sample(path, at: min(age, last.t) + 0.05) ?? s
        position = CGPoint(x: s.x, y: s.y)
        tuck = s.tuck
        // The hand-off: the ghost dissolves after holding its last pose, or as the player's bird reaches it.
        let caughtUp = age > 0.4 && birdX >= s.x - 20
        if holdAge >= SceneLook.ghostHold || caughtUp {
            dissolve(at: CGPoint(x: CGFloat(s.x - originX), y: CGFloat(s.y)), zoom: zz, still: still)
            return
        }
        let angle = atan2(ahead.y - s.y, max(ahead.x - s.x, 0.001))
        drawPose(s, angle: angle, zoom: zz, originX: originX, bird: bird, dt: dt, still: still,
                 show: visible(CGPoint(x: s.x, y: s.y)))
    }

    /// Draws the ghost at `s` (sea) turned to `angle`, and drops its dotted path. `show` false (R12: not fully on
    /// screen, or behind the bird): nothing is drawn and no dot dropped; it fades in afresh once it may show.
    private func drawPose(_ s: SceneGhostSample, angle: Double, zoom zz: CGFloat, originX: Double, bird: SceneBirdView,
                          dt: Double, still: Bool, show: Bool) {
        guard show else {
            art.isHidden = true
            fade = 0
            lastDot = nil
            return
        }
        isShown = true
        fade = min(1, fade + CGFloat(dt) / 0.2)

        // The art: the player's species at 0.9×, posed at the ghost's tuck.
        let b = bird.currentBird
        if cachedBird != b.id {
            cachedBird = b.id
            cache.removeAll()
            poseKey = -1
        }
        let key = Int((min(max(s.tuck, 0), 1) * 24).rounded())
        if key != poseKey {
            poseKey = key
            let paths: (CGPath, CGPath, CGPath)
            if let c = cache[key] {
                paths = c
            } else {
                let p = bird.ghostPaths(tuck: Double(key) / 24)
                paths = (p.body, p.near, p.far)
                cache[key] = paths
            }
            body.path = paths.0
            nearWing.path = paths.1
            farWing.path = paths.2
        }
        let scale = pow(zz, -SceneLook.birdZoomResist) * SceneLook.ghostScale
        let u = CGFloat(min(max(s.tuck, 0), 1))
        art.isHidden = false
        art.alpha = fade
        let belly = SceneLook.birdBellyOffset * SceneLook.birdUnit * scale
        art.position = CGPoint(x: CGFloat(s.x - originX), y: CGFloat(s.y) + belly)
        art.xScale = scale * (1 + (SceneLook.tuckStretchX - 1) * u)
        art.yScale = scale * (1 + (SceneLook.tuckStretchY - 1) * u)
        art.zRotation = CGFloat(min(max(angle, -0.6), 0.6))
        let line = SceneLook.ghostOutline / (zz * scale)
        for n in [farWing, body, nearWing] { n.lineWidth = line }
        let g = SceneLook.ghostGlow / (zz * scale)
        glow.size = CGSize(width: 0.9 * SceneLook.birdUnit + 2 * g, height: 0.3 * SceneLook.birdUnit + 2 * g)
        glow.alpha = SceneLook.ghostGlowAlpha * (still ? 1 : CGFloat(0.85 + 0.15 * sin(age * 5)))

        // The dotted path: a 4 pt dot every 14 pt along the flown line.
        let here = CGPoint(x: CGFloat(s.x - originX), y: CGFloat(s.y))
        let gap = SceneLook.ghostDotGap / zz
        if let l = lastDot {
            if hypot(here.x - l.x, here.y - l.y) >= gap { dropDot(at: here, zoom: zz) }
        } else {
            dropDot(at: here, zoom: zz)
        }
    }

    private func dropDot(at p: CGPoint, zoom z: CGFloat) {
        lastDot = p
        let d = dots[dotCursor % dots.count]
        dotAge[dotCursor % dots.count] = 0
        dotCursor += 1
        d.position = p
        d.size = CGSize(width: SceneLook.ghostDotSize / z, height: SceneLook.ghostDotSize / z)
        d.alpha = SceneLook.ghostDotAlpha
        d.isHidden = false
    }

    private func dissolve(at p: CGPoint, zoom z: CGFloat, still: Bool) {
        isFlying = false
        finishedNow = true
        move = nil
        path = []
        art.isHidden = true
        fade = 0
        guard !still else { return }
        moteAge = 0
        var rng = SceneRNG(seed: UInt64(abs(Int(p.x))) &+ 0x6057)
        for i in 0..<motes.count {
            moteStart[i] = CGPoint(x: p.x + rng.range(-30, 30) / z, y: p.y + rng.range(0, 30) / z)
            moteRise[i] = rng.range(40, 80) / z
            let size = rng.range(4, 7) * 2.2 / z
            motes[i].size = CGSize(width: size, height: size)
        }
    }

    private func updateMotes(dt: Double) {
        guard moteAge < 1 else { return }
        moteAge += dt
        let k = CGFloat(min(moteAge / 0.8, 1))
        for (i, m) in motes.enumerated() {
            m.isHidden = k >= 1
            guard k < 1 else { continue }
            let rise = moteRise[i] * (1 - (1 - k) * (1 - k))
            m.position = CGPoint(x: moteStart[i].x, y: moteStart[i].y + rise)
            m.alpha = 0.9 * (1 - k)
        }
    }
}
