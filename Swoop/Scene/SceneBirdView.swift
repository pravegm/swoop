import SpriteKit
import UIKit

/// The bird (from `BirdArt`) and its slipstream ribbon. The root sits on the physics point (the belly) and turns with
/// the body angle; wing paths are rebuilt only when the tuck or flap changes. World-local coordinates.
@MainActor
final class SceneBirdView {
    let root: SKNode
    /// The slipstream ribbon (and the Tailwind's golden glow), under the bird.
    let trailRoot: SKNode
    private let art: SKNode
    private let farWing: SKShapeNode
    private let farTip: SKShapeNode
    private let body: SKShapeNode
    private let beak: SKShapeNode
    private let eye: SKShapeNode
    private let nearWing: SKShapeNode
    private let nearTip: SKShapeNode
    private let trail: SKShapeNode
    private let trailGlow: SKShapeNode
    private var trailPoints: [CGPoint] = []
    private var trailTimes: [Double] = []
    private var lastTuck: Double = -1
    private var lastFlap: Double = -1
    private var bird: Bird = SceneDefaults.bird
    private(set) var angle: CGFloat = 0
    private(set) var scale: CGFloat = 1

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
        trail = SKShapeNode()
        trailGlow = SKShapeNode()
        art.position = CGPoint(x: 0, y: SceneLook.birdBellyOffset * SceneLook.birdUnit)
        root.addChild(art)
        let layers: [(SKShapeNode, CGFloat)] = [(farWing, 0), (farTip, 0.1), (body, 1), (beak, 1.1), (eye, 1.2),
                                                 (nearWing, 2), (nearTip, 2.1)]
        for (n, z) in layers {
            n.zPosition = z
            n.lineJoin = .round
            n.isAntialiased = true
            art.addChild(n)
        }
        trail.strokeColor = .clear
        trail.lineWidth = 0
        trail.zPosition = 0
        trailGlow.strokeColor = .clear
        trailGlow.lineWidth = 0
        trailGlow.blendMode = .add
        trailGlow.zPosition = 0.5
        trailGlow.isHidden = true
        trailRoot.addChild(trail)
        trailRoot.addChild(trailGlow)
        trailPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        trailTimes.reserveCapacity(SceneLook.trailMaxPoints + 2)
        apply(bird: SceneDefaults.bird)
    }

    func apply(bird b: Bird) {
        bird = b
        body.path = scaled(BirdArt.bodyPath(for: b))
        body.fillColor = ScenePaint.ui(b.body)
        body.strokeColor = ScenePaint.ui(ScenePaint.darker(b.body, 0.35), alpha: 0.55)
        body.lineWidth = 0.9
        beak.path = scaled(BirdArt.beakPath(for: b))
        beak.fillColor = ScenePaint.ui(b.beak)
        beak.strokeColor = ScenePaint.ui(ScenePaint.darker(b.beak, 0.3), alpha: 0.5)
        beak.lineWidth = 0.6
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
        nearWing.strokeColor = ScenePaint.ui(ScenePaint.darker(b.wing, 0.32), alpha: 0.5)
        nearWing.lineWidth = 0.8
        nearTip.fillColor = ScenePaint.ui(b.wingTip)
        nearTip.strokeColor = .clear
        lastTuck = -1
        lastFlap = -1
    }

    /// Rebuilds the wings for this tuck and flap phase (skipped when nothing visible changed).
    func pose(tuck: Double, flap: Double) {
        if abs(tuck - lastTuck) < 0.003 && abs(flap - lastFlap) < 0.003 { return }
        lastTuck = tuck
        lastFlap = flap
        let p = BirdArt.path(for: bird, tuck: tuck, flap: flap)
        let tips = BirdArt.wingTipPaths(for: bird, tuck: tuck, flap: flap)
        farWing.path = scaled(p.farWing)
        nearWing.path = scaled(p.nearWing)
        farTip.path = scaled(tips.far)
        nearTip.path = scaled(tips.near)
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
        trail.isHidden = true
        trailGlow.isHidden = true
    }

    func shiftTrail(dx: CGFloat) {
        for i in 0..<trailPoints.count { trailPoints[i].x += dx }
    }

    /// The slipstream: a tapered ribbon through the last ~0.3 s of the tail's path, faint at low speed, gold after a
    /// Perfect (`goldK`), long and glowing during a Tailwind.
    func updateTrail(emit: CGPoint, show: Bool, time: Double, zoom z: CGFloat, speedK: CGFloat, goldK: CGFloat,
                     tailwind: Bool, color: RGBA) {
        guard show else {
            clearTrail()
            return
        }
        if let last = trailPoints.last {
            if hypot(emit.x - last.x, emit.y - last.y) > 5 / z {
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
        let n = trailPoints.count + 1
        guard n >= 3 else {
            trail.isHidden = true
            trailGlow.isHidden = true
            return
        }
        let width = (SceneLook.trailWidth + SceneLook.trailWidthFast * speedK) / z
        trail.path = ribbon(head: emit, width: width)
        trail.isHidden = false
        let tint = color.mixed(with: ScenePaint.gold, Double(goldK))
        trail.fillColor = ScenePaint.ui(tint, alpha: min(0.85, 0.10 + 0.32 * speedK + 0.4 * goldK))
        if tailwind || goldK > 0.3 {
            trailGlow.isHidden = false
            trailGlow.path = ribbon(head: emit, width: SceneLook.trailGlowWidth / z * (tailwind ? 1 : 0.6))
            trailGlow.fillColor = ScenePaint.ui(ScenePaint.gold, alpha: tailwind ? 0.5 : 0.3 * goldK)
        } else {
            trailGlow.isHidden = true
        }
    }

    private func ribbon(head: CGPoint, width: CGFloat) -> CGPath {
        let count = trailPoints.count + 1
        let path = CGMutablePath()
        // Left edge, oldest → head.
        for i in 0..<count {
            let p = trailPoint(i, head)
            let nrm = normal(i, count, head)
            let w = width * 0.5 * pow(CGFloat(i) / CGFloat(count - 1), 1.2)
            let q = CGPoint(x: p.x + nrm.x * w, y: p.y + nrm.y * w)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        // Right edge, head → oldest.
        var i = count - 1
        while i >= 0 {
            let p = trailPoint(i, head)
            let nrm = normal(i, count, head)
            let w = width * 0.5 * pow(CGFloat(i) / CGFloat(count - 1), 1.2)
            path.addLine(to: CGPoint(x: p.x - nrm.x * w, y: p.y - nrm.y * w))
            i -= 1
        }
        path.closeSubpath()
        return path
    }

    private func trailPoint(_ i: Int, _ head: CGPoint) -> CGPoint {
        i < trailPoints.count ? trailPoints[i] : head
    }

    private func normal(_ i: Int, _ count: Int, _ head: CGPoint) -> CGPoint {
        let a = trailPoint(max(i - 1, 0), head)
        let b = trailPoint(min(i + 1, count - 1), head)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.0001)
        return CGPoint(x: -dy / len, y: dx / len)
    }

    private func scaled(_ path: CGPath) -> CGPath {
        let m = CGMutablePath()
        m.addPath(path, transform: CGAffineTransform(scaleX: SceneLook.birdUnit, y: SceneLook.birdUnit))
        return m
    }
}
