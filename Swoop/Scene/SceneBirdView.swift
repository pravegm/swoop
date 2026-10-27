import SpriteKit
import UIKit

/// One wing pose's paths, already scaled to canvas points.
struct SceneWingPose {
    var near: CGPath
    var far: CGPath
    var nearTip: CGPath
    var farTip: CGPath
    var leadingEdge: CGPath
}

/// The bird (from `BirdArt`), its contact shadow and its slipstream. The root sits on the physics point (the belly)
/// and turns with the body angle. Everything is in world-local coordinates.
///
/// R3 (ART-DIRECTION §4, ART-S8):
/// - **Size:** 107 pt per unit, so the body is 96 pt on the Duo.
/// - **Light birds** get a 1.25 pt ink contour at 55 %. **Dark birds** get the key rim at 1.5 pt, plus a soft halo of
///   the horizon colour over the sea. In Monsoon every bird gets the contour.
/// - **A key rim** in the sky's `birdKeyRim` runs along the back line and the near wing's leading edge.
/// - **The belly's** lower third is 12 % darker.
/// - **Motion:** a 6 % stretch and 8 % thinning at full tuck, and a 90 ms touchdown squash.
/// - **A contact shadow** while skimming.
///
/// The trail is one continuous ribbon: three nested tapered fills, each starting further along, so the alpha fades
/// toward the tail with no seams (ART-S10). An additive glow surrounds it. During a Tailwind, two wobbling gold
/// strands are added.
@MainActor
final class SceneBirdView {
    let root: SKNode
    /// The slipstream (core, glow, Tailwind strands), under the bird.
    let trailRoot: SKNode
    /// The contact shadow on the water (the scene adds it to the world just above the sea).
    let shadow: SKSpriteNode
    private let art: SKNode
    private let halo: SKSpriteNode
    private let farWing: SKShapeNode
    private let farTip: SKShapeNode
    private let body: SKShapeNode
    private let belly: SKShapeNode
    private let backLine: SKShapeNode
    private let beak: SKShapeNode
    private let eye: SKShapeNode
    private let nearWing: SKShapeNode
    private let nearTip: SKShapeNode
    private let leadingEdge: SKShapeNode
    private var coreLayers: [SKShapeNode] = []
    private let glow: SKShapeNode
    private let strandA: SKShapeNode
    private let strandB: SKShapeNode
    private var trailPoints: [CGPoint] = []
    private var trailTimes: [Double] = []
    private var drawPoints: [CGPoint] = []
    private var strandPoints: [CGPoint] = []
    /// The trail colour blended to gold in 21 steps (cached per bird).
    private var trailTints: [UIColor] = []
    private var tintIndex = -1
    private let goldTint = ScenePaint.ui(ScenePaint.gold)
    private var glowGold = false
    /// The head taper's length this frame (world units), so the ribbon narrows into the tail instead of ending square.
    private var headTaper: CGFloat = 24
    private var wingCache: [Int: SceneWingPose] = [:]
    private var poseKey = -1
    private var bird: Bird = SceneDefaults.bird
    private var squashAge: CGFloat = 1
    private var isDark = false
    private var wetLevel: CGFloat = 0
    private(set) var angle: CGFloat = 0
    private(set) var scale: CGFloat = 1
    /// Wing paths built since the scene was made (tests, tuning).
    private(set) var wingBuilds = 0
    /// Whether this bird draws the dark-bird key rim and halo (tests).
    var usesKeyRimOutline: Bool { isDark }

    init() {
        root = SKNode()
        trailRoot = SKNode()
        shadow = SKSpriteNode(texture: SceneTextures.soft)
        art = SKNode()
        halo = SKSpriteNode(texture: SceneTextures.soft)
        farWing = SKShapeNode()
        farTip = SKShapeNode()
        body = SKShapeNode()
        belly = SKShapeNode()
        backLine = SKShapeNode()
        beak = SKShapeNode()
        eye = SKShapeNode()
        nearWing = SKShapeNode()
        nearTip = SKShapeNode()
        leadingEdge = SKShapeNode()
        glow = SKShapeNode()
        strandA = SKShapeNode()
        strandB = SKShapeNode()
        art.position = CGPoint(x: 0, y: SceneLook.birdBellyOffset * SceneLook.birdUnit)
        root.addChild(art)
        halo.colorBlendFactor = 1
        halo.zPosition = -1
        halo.isHidden = true
        art.addChild(halo)
        let layers: [(SKShapeNode, CGFloat)] = [(farWing, 0), (farTip, 0.1), (body, 1), (belly, 1.05), (backLine, 1.08),
                                                 (beak, 1.1), (eye, 1.2), (nearWing, 2), (nearTip, 2.1),
                                                 (leadingEdge, 2.2)]
        for (node, z) in layers {
            node.zPosition = z
            node.lineJoin = .round
            node.lineCap = .round
            node.isAntialiased = true
            art.addChild(node)
        }
        backLine.fillColor = .clear
        leadingEdge.fillColor = .clear
        shadow.colorBlendFactor = 1
        shadow.isHidden = true
        for i in 0..<SceneLook.trailLayers {
            let n = SKShapeNode()
            n.strokeColor = .clear
            n.lineWidth = 0
            n.zPosition = 0.5 + CGFloat(i) * 0.01
            trailRoot.addChild(n)
            coreLayers.append(n)
        }
        for (n, z) in [(glow, CGFloat(0)), (strandA, CGFloat(1)), (strandB, CGFloat(1.1))] {
            n.strokeColor = .clear
            n.lineWidth = 0
            n.blendMode = .add
            n.zPosition = z
            n.isHidden = true
            trailRoot.addChild(n)
        }
        strandA.fillColor = ScenePaint.ui(ScenePaint.gold)
        strandB.fillColor = ScenePaint.ui(ScenePaint.paleGold)
        trailPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        trailTimes.reserveCapacity(SceneLook.trailMaxPoints + 2)
        drawPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        strandPoints.reserveCapacity(SceneLook.trailMaxPoints + 2)
        apply(bird: SceneDefaults.bird, palette: ScenePalette.palette(.goldenHour))
    }

    func apply(bird b: Bird, palette p: ScenePalette) {
        bird = b
        isDark = ScenePaint.luminance(b.body) < SceneLook.darkBirdLuminance && !p.darkContourForAll
        let ink = ScenePaint.ui(ScenePalette.ink, alpha: SceneLook.birdContourAlpha)
        let keyRim = ScenePaint.ui(p.birdKeyRim, alpha: SceneLook.birdKeyRimAlpha)
        body.path = scaled(BirdArt.bodyPath(for: b))
        body.fillColor = ScenePaint.ui(b.body)
        body.strokeColor = isDark ? keyRim : ink
        body.lineWidth = isDark ? SceneLook.birdKeyRimWidth : SceneLook.birdContourWidth
        belly.path = scaled(BirdArt.bellyPath(for: b))
        belly.fillColor = ScenePaint.ui(ScenePaint.darker(b.body, SceneLook.bellyDarken))
        belly.strokeColor = .clear
        backLine.path = scaled(BirdArt.backLinePath(for: b))
        backLine.strokeColor = keyRim
        backLine.lineWidth = SceneLook.birdKeyRimWidth
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
        let wingDark = ScenePaint.luminance(b.wing) < SceneLook.darkBirdLuminance && !p.darkContourForAll
        nearWing.strokeColor = wingDark ? keyRim : ink
        nearWing.lineWidth = wingDark ? SceneLook.birdKeyRimWidth : SceneLook.birdContourWidth
        nearTip.fillColor = ScenePaint.ui(b.wingTip)
        nearTip.strokeColor = .clear
        leadingEdge.strokeColor = keyRim
        leadingEdge.lineWidth = SceneLook.birdKeyRimWidth
        halo.color = ScenePaint.ui(p.horizon)
        halo.size = CGSize(width: 0.9 * u + SceneLook.birdHaloRadius * 2, height: 0.25 * u + SceneLook.birdHaloRadius * 2)
        halo.position = CGPoint(x: -0.02 * u, y: 0)
        shadow.color = ScenePaint.ui(p.nearDeep)
        trailTints.removeAll()
        for i in 0...20 {
            trailTints.append(ScenePaint.ui(b.trail.mixed(with: ScenePaint.gold, Double(i) / 20)))
        }
        tintIndex = -1
        glow.fillColor = ScenePaint.ui(b.trail)
        glowGold = false
        wingCache.removeAll()
        poseKey = -1
        wetLevel = 0
    }

    /// Sets the wings for this tuck and flap phase (quantised; each pose's paths are built once and cached), and the
    /// tuck's stretch (a dart: 6 % longer, 8 % thinner at full tuck) times the touchdown squash.
    func pose(tuck: Double, flap: Double, dt: CGFloat) {
        let u = CGFloat(min(max(tuck, 0), 1))
        squashAge += dt
        var sx = 1 + (SceneLook.tuckStretchX - 1) * u
        var sy = 1 + (SceneLook.tuckStretchY - 1) * u
        if squashAge < SceneLook.squashTime * 3 {
            // Squash for 90 ms, then a quick spring back.
            let k: CGFloat = squashAge < SceneLook.squashTime ? 1
                : max(0, 1 - (squashAge - SceneLook.squashTime) / (SceneLook.squashTime * 2))
            sx *= 1 + (SceneLook.squashX - 1) * k
            sy *= 1 + (SceneLook.squashY - 1) * k
        }
        art.xScale = sx
        art.yScale = sy
        let tq = Int((Double(u) * SceneLook.wingTuckSteps).rounded())
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
            let edge = BirdArt.nearWingLeadingEdge(for: bird, tuck: qt, flap: qf)
            pose = SceneWingPose(near: scaled(p.nearWing), far: scaled(p.farWing), nearTip: scaled(tips.near),
                                 farTip: scaled(tips.far), leadingEdge: scaled(edge))
            if wingCache.count > 800 { wingCache.removeAll() }
            wingCache[key] = pose
            wingBuilds += 1
        }
        farWing.path = pose.far
        nearWing.path = pose.near
        farTip.path = pose.farTip
        nearTip.path = pose.nearTip
        leadingEdge.path = pose.leadingEdge
    }

    /// R9 caught: the bird is wet, its body and wings up to `SceneLook.caughtWet` darker (`k` 0…1).
    func setWet(_ k: CGFloat) {
        let q = (min(max(k, 0), 1) * 10).rounded() / 10
        guard q != wetLevel else { return }
        wetLevel = q
        let d = Double(SceneLook.caughtWet * q)
        body.fillColor = ScenePaint.ui(ScenePaint.darker(bird.body, d))
        belly.fillColor = ScenePaint.ui(ScenePaint.darker(bird.body, SceneLook.bellyDarken + d))
        nearWing.fillColor = ScenePaint.ui(ScenePaint.darker(bird.wing, d))
        farWing.fillColor = ScenePaint.ui(ScenePaint.darker(bird.wing, 0.22 + d))
    }

    /// The bird's art paths for a ghost (the same species and pose cache key; canvas units at scale 1).
    func ghostPaths(tuck: Double) -> (body: CGPath, near: CGPath, far: CGPath) {
        let p = BirdArt.path(for: bird, tuck: tuck, flap: 0)
        return (scaled(p.body), scaled(p.nearWing), scaled(p.farWing))
    }

    /// The trail's stored points (tests: a jump starts a new strand).
    var trailPointCount: Int { trailPoints.count }

    /// The current bird (the guide gull copies its species).
    var currentBird: Bird { bird }

    /// A touchdown: the 90 ms squash.
    func squash() { squashAge = 0 }

    func place(at p: CGPoint, angle a: CGFloat, scale s: CGFloat) {
        root.position = p
        root.zRotation = a
        root.setScale(s)
        angle = a
        scale = s
    }

    /// The dark bird's halo shows only over the sea (low); `k` 0…1.
    func setHalo(_ k: CGFloat) {
        let on = isDark && k > 0.01
        halo.isHidden = !on
        if on { halo.alpha = SceneLook.birdHaloAlpha * k }
    }

    /// The contact shadow: an ellipse 1.2 body lengths × 6 pt on the water under the bird, gone by 60 pt of height.
    func updateShadow(water: CGPoint, altitude: Double, zoom z: CGFloat, show: Bool) {
        let k = show ? CGFloat(max(0, 1 - altitude / SceneLook.shadowFadeHeight)) : 0
        shadow.isHidden = k <= 0.01
        guard !shadow.isHidden else { return }
        let length = 0.9 * SceneLook.birdUnit * scale * SceneLook.shadowLength
        shadow.position = CGPoint(x: water.x - 0.05 * SceneLook.birdUnit * scale, y: water.y)
        shadow.size = CGSize(width: length, height: SceneLook.shadowHeight * 2.2 / max(z, 0.01))
        shadow.alpha = SceneLook.shadowAlpha * k
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
        hideTrail()
    }

    private func hideTrail() {
        for n in coreLayers where !n.isHidden { n.isHidden = true }
        glow.isHidden = true
        strandA.isHidden = true
        strandB.isHidden = true
    }

    func shiftTrail(dx: CGFloat) {
        for i in 0..<trailPoints.count { trailPoints[i].x += dx }
    }

    /// The slipstream through the last ~0.45 s of the tail's path: 9 → 14 pt wide with speed, tapering to nothing,
    /// gold after a Perfect (`goldK`), longer with two wobbling gold strands during a Tailwind.
    func updateTrail(emit: CGPoint, show: Bool, time: Double, zoom z: CGFloat, speedK: CGFloat, goldK: CGFloat,
                     tailwind: Bool) {
        guard show else {
            clearTrail()
            return
        }
        if let last = trailPoints.last {
            let gap = hypot(emit.x - last.x, emit.y - last.y)
            // R9 (defect #29): a jump longer than 3 spacings (a session switch, a rewind, a held frame) starts a new
            // strand, so the ribbon never draws a straight "contrail" from where the bird used to be.
            if gap > 3 * SceneLook.trailSpacing / max(z, 0.01) {
                trailPoints.removeAll(keepingCapacity: true)
                trailTimes.removeAll(keepingCapacity: true)
                trailPoints.append(emit)
                trailTimes.append(time)
            } else if gap > SceneLook.trailSpacing / z {
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
        let n = drawPoints.count
        guard n >= 3 else {
            hideTrail()
            return
        }
        let ti = Int((min(max(goldK, 0), 1) * 20).rounded())
        if ti != tintIndex && ti >= 0 && ti < trailTints.count {
            tintIndex = ti
            for layer in coreLayers { layer.fillColor = trailTints[ti] }
        }
        let width = (SceneLook.trailWidth + SceneLook.trailWidthFast * speedK) / z
        headTaper = SceneLook.trailHeadTaper / max(z, 0.01)
        // Nested ribbons: the combined alpha at the bird is `trailAlpha`, fading smoothly toward the tail.
        let layers = coreLayers.count
        let perLayer = 1 - pow(1 - SceneLook.trailAlpha, 1 / CGFloat(max(layers, 1)))
        let strength = min(1, 0.4 + 0.6 * speedK + 0.5 * goldK)
        for (i, layer) in coreLayers.enumerated() {
            let start = Int(Double(n - 2) * Double(i) / Double(layers))
            layer.path = ribbon(drawPoints, from: start, width: width)
            layer.isHidden = false
            layer.alpha = perLayer * strength
        }
        glow.isHidden = false
        glow.path = ribbon(drawPoints, from: 0, width: width * SceneLook.trailGlowWidth)
        let wantGold = goldK > 0.3
        if wantGold != glowGold {
            glowGold = wantGold
            glow.fillColor = wantGold ? goldTint : (trailTints.first ?? UIColor.white)
        }
        glow.alpha = SceneLook.trailGlowAlphaLow
            + (SceneLook.trailGlowAlphaHigh - SceneLook.trailGlowAlphaLow) * max(goldK, speedK * 0.5)
        if tailwind {
            let amp = SceneLook.strandWobble / z
            let phase = CGFloat(time) * SceneLook.strandSpeed
            wobble(sign: 1, amp: amp, phase: phase)
            strandA.path = ribbon(strandPoints, from: 0, width: width * SceneLook.strandWidth)
            strandA.isHidden = false
            strandA.alpha = 0.85
            wobble(sign: -1, amp: amp, phase: phase)
            strandB.path = ribbon(strandPoints, from: 0, width: width * SceneLook.strandWidth)
            strandB.isHidden = false
            strandB.alpha = 0.7
        } else {
            strandA.isHidden = true
            strandB.isHidden = true
        }
    }

    /// A tapered ribbon through `pts[from...]`: zero width at `from`, `width` at the newest point.
    private func ribbon(_ pts: [CGPoint], from: Int, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let n = pts.count
        let a = min(max(from, 0), max(n - 2, 0))
        let span = CGFloat(max(n - 1 - a, 1))
        // Left edge, oldest → head.
        for i in a..<n {
            let p = pts[i]
            let nrm = normal(pts, i)
            let w = width * 0.5 * pow(CGFloat(i - a) / span, 0.9) * taper(p, pts[n - 1])
            let q = CGPoint(x: p.x + nrm.x * w, y: p.y + nrm.y * w)
            if i == a { path.move(to: q) } else { path.addLine(to: q) }
        }
        // Right edge, head → oldest.
        var i = n - 1
        while i >= a {
            let p = pts[i]
            let nrm = normal(pts, i)
            let w = width * 0.5 * pow(CGFloat(i - a) / span, 0.9) * taper(p, pts[n - 1])
            path.addLine(to: CGPoint(x: p.x - nrm.x * w, y: p.y - nrm.y * w))
            i -= 1
        }
        path.closeSubpath()
        return path
    }

    /// 0.3 at the bird, rising smoothly to 1 over `headTaper`: the ribbon leaves the tail as a point.
    private func taper(_ p: CGPoint, _ head: CGPoint) -> CGFloat {
        let d = hypot(p.x - head.x, p.y - head.y)
        let k = min(d / max(headTaper, 0.001), 1)
        return 0.3 + 0.7 * k * k * (3 - 2 * k)
    }

    private func normal(_ pts: [CGPoint], _ i: Int) -> CGPoint {
        let n = pts.count
        let a = pts[max(i - 1, 0)]
        let b = pts[min(i + 1, n - 1)]
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.0001)
        return CGPoint(x: -dy / len, y: dx / len)
    }

    /// `strandPoints` = the trail offset along its normal by a travelling sine (zero at the bird, so both strands
    /// leave the tail together).
    private func wobble(sign: CGFloat, amp: CGFloat, phase: CGFloat) {
        strandPoints.removeAll(keepingCapacity: true)
        let n = drawPoints.count
        for i in 0..<n {
            let nrm = normal(drawPoints, i)
            let fromHead = CGFloat(n - 1 - i)
            let k = min(fromHead / 4, 1)
            let off = sign * amp * k * sin(phase - fromHead * SceneLook.strandWave)
            let p = drawPoints[i]
            strandPoints.append(CGPoint(x: p.x + nrm.x * off, y: p.y + nrm.y * off))
        }
    }

    private func scaled(_ path: CGPath) -> CGPath {
        let m = CGMutablePath()
        m.addPath(path, transform: CGAffineTransform(scaleX: SceneLook.birdUnit, y: SceneLook.birdUnit))
        return m
    }
}
