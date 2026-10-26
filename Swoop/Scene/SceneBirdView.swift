import SpriteKit
import UIKit

/// One wing pose's paths, already scaled to canvas points.
struct SceneWingPose {
    var near: CGPath
    var far: CGPath
    var nearTip: CGPath
    var farTip: CGPath
}

/// The bird (from `BirdArt`) and its slipstream. The root sits on the physics point (the belly) and turns with the
/// body angle. World-local coordinates.
///
/// R2: 30 % bigger with a rim that contrasts with the bird's own colour (REVIEW-1 P0-4); wing paths cached per
/// quantised tuck / flap (QA-1 P1-6); the trail is a chain of soft sprites through the tail's recent path, so it
/// tapers to nothing, fades out and glows without rebuilding a path, and a Tailwind adds two wobbling gold strands
/// (REVIEW-1 P1-3).
@MainActor
final class SceneBirdView {
    let root: SKNode
    /// The slipstream (core, glow, Tailwind strands), under the bird.
    let trailRoot: SKNode
    private let art: SKNode
    private let farWing: SKShapeNode
    private let farTip: SKShapeNode
    private let body: SKShapeNode
    private let beak: SKShapeNode
    private let eye: SKShapeNode
    private let nearWing: SKShapeNode
    private let nearTip: SKShapeNode
    private let core: SceneTrailStrand
    private let glow: SceneTrailStrand
    private let strandA: SceneTrailStrand
    private let strandB: SceneTrailStrand
    private var trailPoints: [CGPoint] = []
    private var trailTimes: [Double] = []
    private var drawPoints: [CGPoint] = []
    private var strandPoints: [CGPoint] = []
    /// The trail colour blended to gold in 21 steps (cached per bird).
    private var trailTints: [UIColor] = []
    private var tintIndex = -1
    private var wingCache: [Int: SceneWingPose] = [:]
    private var poseKey = -1
    private var bird: Bird = SceneDefaults.bird
    private(set) var angle: CGFloat = 0
    private(set) var scale: CGFloat = 1
    /// Wing paths built since the scene was made (tests, tuning).
    private(set) var wingBuilds = 0

    init() {
        root = SKNode()
        trailRoot = SKNode()
        art = SKNode()
        farWing = SKShapeNode()
        farTip = SKShapeNode()
        body = SKShapeNode()
        beak = SKShapeNode()
        eye = SKShapeNode()
        nearWing = SKShapeNode()
        nearTip = SKShapeNode()
        let n = SceneLook.trailMaxPoints + 1
        glow = SceneTrailStrand(count: n, blend: .add)
        core = SceneTrailStrand(count: n, blend: .alpha)
        strandA = SceneTrailStrand(count: n, blend: .add)
        strandB = SceneTrailStrand(count: n, blend: .add)
        art.position = CGPoint(x: 0, y: SceneLook.birdBellyOffset * SceneLook.birdUnit)
        root.addChild(art)
        let layers: [(SKShapeNode, CGFloat)] = [(farWing, 0), (farTip, 0.1), (body, 1), (beak, 1.1), (eye, 1.2),
                                                 (nearWing, 2), (nearTip, 2.1)]
        for (node, z) in layers {
            node.zPosition = z
            node.lineJoin = .round
            node.isAntialiased = true
            art.addChild(node)
        }
        glow.root.zPosition = 0
        core.root.zPosition = 0.5
        strandA.root.zPosition = 1
        strandB.root.zPosition = 1.1
        for s in [glow, core, strandA, strandB] { trailRoot.addChild(s.root) }
        strandA.setColor(ScenePaint.ui(ScenePaint.gold))
        strandB.setColor(ScenePaint.ui(ScenePaint.paleGold))
        trailPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        trailTimes.reserveCapacity(SceneLook.trailMaxPoints + 2)
        drawPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        strandPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        apply(bird: SceneDefaults.bird)
    }

    /// A rim that contrasts with `c`: dark on light birds, light on dark ones (so either reads on any sky).
    private static func rim(for c: RGBA) -> UIColor {
        if ScenePaint.luminance(c) > 0.42 {
            return ScenePaint.ui(ScenePaint.darker(c, 0.62), alpha: 0.85)
        }
        return ScenePaint.ui(ScenePaint.lighter(c, 0.55), alpha: 0.8)
    }

    func apply(bird b: Bird) {
        bird = b
        body.path = scaled(BirdArt.bodyPath(for: b))
        body.fillColor = ScenePaint.ui(b.body)
        body.strokeColor = SceneBirdView.rim(for: b.body)
        body.lineWidth = SceneLook.birdRimWidth
        beak.path = scaled(BirdArt.beakPath(for: b))
        beak.fillColor = ScenePaint.ui(b.beak)
        beak.strokeColor = ScenePaint.ui(ScenePaint.darker(b.beak, 0.35), alpha: 0.6)
        beak.lineWidth = 0.8
        let e = BirdArt.eye(for: b)
        let u = SceneLook.birdUnit
        eye.path = CGPath(ellipseIn: CGRect(x: (e.center.x - e.radius) * u, y: (e.center.y - e.radius) * u,
                                            width: e.radius * 2 * u, height: e.radius * 2 * u), transform: nil)
        eye.fillColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        eye.strokeColor = .clear
        farWing.fillColor = ScenePaint.ui(ScenePaint.darker(b.wing, 0.22))
        farWing.strokeColor = .clear
        farTip.fillColor = ScenePaint.ui(ScenePaint.darker(b.wingTip, 0.15))
        farTip.strokeColor = .clear
        nearWing.fillColor = ScenePaint.ui(b.wing)
        nearWing.strokeColor = SceneBirdView.rim(for: b.wing)
        nearWing.lineWidth = SceneLook.birdRimWidth * 0.8
        nearTip.fillColor = ScenePaint.ui(b.wingTip)
        nearTip.strokeColor = .clear
        trailTints.removeAll()
        for i in 0...20 {
            trailTints.append(ScenePaint.ui(b.trail.mixed(with: ScenePaint.gold, Double(i) / 20)))
        }
        tintIndex = -1
        wingCache.removeAll()
        poseKey = -1
    }

    /// Sets the wings for this tuck and flap phase (quantised; each pose's paths are built once and cached).
    func pose(tuck: Double, flap: Double) {
        let tq = Int((min(max(tuck, 0), 1) * SceneLook.wingTuckSteps).rounded())
        let phase = flap - floor(flap)
        let fsteps = Int(SceneLook.wingFlapSteps)
        let fq = Int((phase * SceneLook.wingFlapSteps).rounded()) % max(fsteps, 1)
        let key = tq * 1000 + fq
        if key == poseKey { return }
        poseKey = key
        let pose: SceneWingPose
        if let cached = wingCache[key] {
            pose = cached
        } else {
            let qt = Double(tq) / SceneLook.wingTuckSteps
            let qf = Double(fq) / SceneLook.wingFlapSteps
            let p = BirdArt.path(for: bird, tuck: qt, flap: qf)
            let tips = BirdArt.wingTipPaths(for: bird, tuck: qt, flap: qf)
            pose = SceneWingPose(near: scaled(p.nearWing), far: scaled(p.farWing), nearTip: scaled(tips.near),
                                 farTip: scaled(tips.far))
            if wingCache.count > 800 { wingCache.removeAll() }
            wingCache[key] = pose
            wingBuilds += 1
        }
        farWing.path = pose.far
        nearWing.path = pose.near
        farTip.path = pose.farTip
        nearTip.path = pose.nearTip
    }

    func place(at p: CGPoint, angle a: CGFloat, scale s: CGFloat) {
        root.position = p
        root.zRotation = a
        root.setScale(s)
        angle = a
        scale = s
    }

    /// A point on the bird (BirdArt units, belly-relative y = 0 at the art origin) in world-local coordinates.
    func point(unitX ux: CGFloat, unitY uy: CGFloat) -> CGPoint {
        let k = SceneLook.birdUnit * scale
        let x = ux * k
        let y = (uy + SceneLook.birdBellyOffset) * k
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: root.position.x + x * c - y * s, y: root.position.y + x * s + y * c)
    }

    var tailPoint: CGPoint { point(unitX: -0.44, unitY: 0.0) }
    var wingtipPoint: CGPoint { point(unitX: -0.36, unitY: -0.06) }

    // MARK: Trail

    func clearTrail() {
        trailPoints.removeAll(keepingCapacity: true)
        trailTimes.removeAll(keepingCapacity: true)
        hideStrands()
    }

    private func hideStrands() {
        glow.hideAll()
        core.hideAll()
        strandA.hideAll()
        strandB.hideAll()
    }

    func shiftTrail(dx: CGFloat) {
        for i in 0..<trailPoints.count { trailPoints[i].x += dx }
    }

    /// The slipstream through the last ~0.45 s of the tail's path: faint at low speed, gold after a Perfect (`goldK`),
    /// longer with two wobbling gold strands during a Tailwind.
    func updateTrail(emit: CGPoint, show: Bool, time: Double, zoom z: CGFloat, speedK: CGFloat, goldK: CGFloat,
                     tailwind: Bool) {
        guard show else {
            clearTrail()
            return
        }
        if let last = trailPoints.last {
            if hypot(emit.x - last.x, emit.y - last.y) > SceneLook.trailSpacing / z {
                trailPoints.append(emit)
                trailTimes.append(time)
            }
        } else {
            trailPoints.append(emit)
            trailTimes.append(time)
        }
        let life = tailwind ? SceneLook.trailLifeTailwind : SceneLook.trailLife
        while let first = trailTimes.first, time - first > life || trailTimes.count > SceneLook.trailMaxPoints {
            trailTimes.removeFirst()
            trailPoints.removeFirst()
        }
        drawPoints.removeAll(keepingCapacity: true)
        drawPoints.append(contentsOf: trailPoints)
        drawPoints.append(emit)
        guard drawPoints.count >= 3 else {
            hideStrands()
            return
        }
        let ti = Int((min(max(goldK, 0), 1) * 20).rounded())
        if ti != tintIndex && ti >= 0 && ti < trailTints.count {
            tintIndex = ti
            core.setColor(trailTints[ti])
            glow.setColor(trailTints[ti])
        }
        let width = (SceneLook.trailWidth + SceneLook.trailWidthFast * speedK) / z
        let coreAlpha = SceneLook.trailAlpha * min(1, 0.35 + 0.65 * speedK + 0.5 * goldK)
        core.draw(drawPoints, width: width, alpha: coreAlpha)
        glow.draw(drawPoints, width: width * SceneLook.trailGlowWidth, alpha: 0.16 + 0.3 * goldK + 0.12 * speedK)
        if tailwind {
            let amp = SceneLook.strandWobble / z
            let phase = CGFloat(time) * SceneLook.strandSpeed
            wobble(sign: 1, amp: amp, phase: phase)
            strandA.draw(strandPoints, width: width * SceneLook.strandWidth, alpha: 0.9)
            wobble(sign: -1, amp: amp, phase: phase)
            strandB.draw(strandPoints, width: width * SceneLook.strandWidth, alpha: 0.75)
        } else {
            strandA.hideAll()
            strandB.hideAll()
        }
    }

    /// `strandPoints` = the trail offset along its normal by a travelling sine (zero at the bird, so both strands
    /// leave the tail together).
    private func wobble(sign: CGFloat, amp: CGFloat, phase: CGFloat) {
        strandPoints.removeAll(keepingCapacity: true)
        let n = drawPoints.count
        for i in 0..<n {
            let a = drawPoints[max(i - 1, 0)]
            let b = drawPoints[min(i + 1, n - 1)]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(hypot(dx, dy), 0.0001)
            let fromHead = CGFloat(n - 1 - i)
            let k = min(fromHead / 4, 1)
            let off = sign * amp * k * sin(phase - fromHead * SceneLook.strandWave)
            let p = drawPoints[i]
            strandPoints.append(CGPoint(x: p.x - dy / len * off, y: p.y + dx / len * off))
        }
    }

    private func scaled(_ path: CGPath) -> CGPath {
        let m = CGMutablePath()
        m.addPath(path, transform: CGAffineTransform(scaleX: SceneLook.birdUnit, y: SceneLook.birdUnit))
        return m
    }
}

/// A trail drawn as a chain of soft sprites, one per segment: width tapers and alpha fades toward the old end.
@MainActor
final class SceneTrailStrand {
    let root: SKNode
    private var segments: [SKSpriteNode] = []
    private var color: UIColor?

    init(count: Int, blend: SKBlendMode) {
        root = SKNode()
        let texture = SceneTextures.ribbon
        for _ in 0..<max(count, 1) {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 10, height: 4))
            s.blendMode = blend
            s.colorBlendFactor = 1
            s.isHidden = true
            root.addChild(s)
            segments.append(s)
        }
    }

    func setColor(_ c: UIColor) {
        if let old = color, old === c { return }
        color = c
        for s in segments { s.color = c }
    }

    func hideAll() {
        for s in segments where !s.isHidden { s.isHidden = true }
    }

    /// `points` oldest → newest. Width `width` and opacity `alpha` at the newest end, both to zero at the oldest.
    func draw(_ points: [CGPoint], width: CGFloat, alpha: CGFloat) {
        let n = points.count
        var used = 0
        if n >= 2 {
            let last = CGFloat(n - 1)
            for i in 0..<(n - 1) where used < segments.count {
                let a = points[i], b = points[i + 1]
                let dx = b.x - a.x, dy = b.y - a.y
                let len = hypot(dx, dy)
                if len < 0.001 { continue }
                let t = CGFloat(i + 1) / last
                let w = max(width * pow(t, 0.9), 0.2)
                let s = segments[used]
                used += 1
                s.isHidden = false
                s.position = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
                s.zRotation = atan2(dy, dx)
                s.size = CGSize(width: len * 1.15 + w * 0.3, height: w)
                s.alpha = alpha * pow(t, 1.4)
            }
        }
        while used < segments.count {
            let s = segments[used]
            if !s.isHidden { s.isHidden = true }
            used += 1
        }
    }
}
