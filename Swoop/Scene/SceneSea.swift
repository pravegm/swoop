import SpriteKit
import UIKit

/// The near sea, the hero of every frame: one filled polygon rebuilt each frame from Core's samples (≤ 220
/// segments), a depth gradient fill whose stroke is the foam line, a lit band just under the surface, glints on the
/// crests and twinkles in the water. World-local coordinates (child of the scene's world node).
@MainActor
final class SceneSeaView {
    let root: SKNode
    private let fill: SKShapeNode
    private let band: SKShapeNode
    private var crests: [SKSpriteNode] = []
    private var twinkles: [SKSpriteNode] = []

    init() {
        root = SKNode()
        fill = SKShapeNode()
        band = SKShapeNode()
        fill.zPosition = 0
        fill.fillColor = .white
        fill.lineJoin = .round
        fill.isAntialiased = true
        band.zPosition = 0.5
        band.fillColor = .clear
        band.lineJoin = .round
        band.lineCap = .round
        root.addChild(fill)
        root.addChild(band)
        for _ in 0..<SceneLook.crestGlintCount {
            let s = SKSpriteNode(texture: SceneTextures.streak)
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.zPosition = 1
            s.isHidden = true
            root.addChild(s)
            crests.append(s)
        }
        for _ in 0..<SceneLook.seaSparkleCount {
            let s = SKSpriteNode(texture: SceneTextures.sparkle, size: CGSize(width: 16, height: 16))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.zPosition = 1.2
            s.isHidden = true
            root.addChild(s)
            twinkles.append(s)
        }
    }

    func apply(sky: Sky) {
        let near = sky.seaNear
        let top = ScenePaint.lighter(near, 0.20).mixed(with: sky.horizon, 0.20)
        fill.fillTexture = SceneTextures.verticalGradient(
            key: "sea-\(sky.id.rawValue)",
            colors: [ScenePaint.ui(top), ScenePaint.ui(near), ScenePaint.ui(ScenePaint.darker(near, 0.28)),
                     ScenePaint.ui(ScenePaint.darker(near, 0.58))],
            locations: [0, 0.13, 0.45, 1])
        fill.strokeColor = ScenePaint.ui(sky.foam, alpha: 0.95)
        band.strokeColor = ScenePaint.ui(ScenePaint.lighter(near, 0.32).mixed(with: sky.horizon, 0.35), alpha: 0.36)
        let glint = ScenePaint.ui(sky.foam.mixed(with: sky.sun, 0.45))
        for s in crests { s.color = glint }
        for s in twinkles { s.color = glint }
    }

    /// `points`: the surface, world-local, evenly spaced, left → right. `bottom`: world-local y below the screen.
    func update(points: [CGPoint], bottom: CGFloat, zoom z: CGFloat, time t: Double, originX: Double) {
        guard points.count >= 3, let first = points.first, let last = points.last else {
            root.isHidden = true
            return
        }
        root.isHidden = false
        let fp = CGMutablePath()
        fp.move(to: CGPoint(x: first.x, y: bottom))
        for p in points { fp.addLine(to: p) }
        fp.addLine(to: CGPoint(x: last.x, y: bottom))
        fp.closeSubpath()
        fill.path = fp
        fill.lineWidth = SceneLook.foamLineWidth / z

        let d = SceneLook.bandDepth / z
        let bp = CGMutablePath()
        bp.move(to: CGPoint(x: first.x, y: first.y - d))
        for i in 1..<points.count {
            bp.addLine(to: CGPoint(x: points[i].x, y: points[i].y - d))
        }
        band.path = bp
        band.lineWidth = SceneLook.bandWidth / z

        let step = max((last.x - first.x) / CGFloat(points.count - 1), 0.001)
        updateCrests(points, step: step, zoom: z, time: t, originX: originX)
        updateTwinkles(points, step: step, zoom: z, time: t, originX: originX)
    }

    /// A glint on every crest: a sample that is the highest within ±40 pt (so the visual ripples don't count).
    private func updateCrests(_ points: [CGPoint], step: CGFloat, zoom z: CGFloat, time t: Double, originX: Double) {
        let n = points.count
        let w = max(2, Int((40 / step).rounded(.up)))
        var used = 0
        var i = 1
        while i < n - 1 && used < crests.count {
            let b = points[i]
            if b.y >= points[i - 1].y && b.y > points[i + 1].y {
                var isTop = true
                let lo = max(0, i - w), hi = min(n - 1, i + w)
                var j = lo
                while j <= hi {
                    if points[j].y > b.y {
                        isTop = false
                        break
                    }
                    j += 1
                }
                if isTop {
                    let s = crests[used]
                    used += 1
                    s.isHidden = false
                    s.position = CGPoint(x: b.x, y: b.y - 1.5 / z)
                    s.size = CGSize(width: 74 / z, height: 7 / z)
                    let seaX = Double(b.x) + originX
                    s.alpha = CGFloat(0.42 + 0.22 * sin(t * 2.6 + seaX * 0.011))
                    i += w
                    continue
                }
            }
            i += 1
        }
        while used < crests.count {
            crests[used].isHidden = true
            used += 1
        }
    }

    /// Twinkles at stable pseudo-random spots in the water (one per 150-pt cell), each flashing on its own beat.
    private func updateTwinkles(_ points: [CGPoint], step: CGFloat, zoom z: CGFloat, time t: Double, originX: Double) {
        guard let first = points.first, let last = points.last else { return }
        let cell = SceneLook.seaSparkleCell
        let x0 = Double(first.x) + originX
        let x1 = Double(last.x) + originX
        var ci = Int((x0 / cell).rounded(.down))
        var g = 0
        while g < twinkles.count && Double(ci) * cell < x1 {
            let h1 = SceneRNG.hash(ci, 11)
            let h2 = SceneRNG.hash(ci, 23)
            let seaX = (Double(ci) + Double(h1)) * cell
            ci += 1
            let lx = CGFloat(seaX - originX)
            let idx = (lx - first.x) / step
            if idx < 0 || idx >= CGFloat(points.count - 1) { continue }
            let i0 = Int(idx)
            let f = idx - CGFloat(i0)
            let y = points[i0].y + (points[i0 + 1].y - points[i0].y) * f
            let beat = sin(t * (2.0 + Double(h2) * 2.2) + Double(h1) * 6.283)
            let a = CGFloat(max(0, beat))
            let alpha = a * a * a * 0.85
            let s = twinkles[g]
            g += 1
            s.isHidden = alpha < 0.02
            s.position = CGPoint(x: lx, y: y - (4 + h2 * 26) / z)
            s.setScale((0.6 + 0.6 * h2) / z)
            s.alpha = alpha
        }
        while g < twinkles.count {
            twinkles[g].isHidden = true
            g += 1
        }
    }
}
