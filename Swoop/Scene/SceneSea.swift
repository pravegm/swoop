import SpriteKit
import UIKit

/// The near sea, the hero of every frame: one filled polygon from Core's samples with a depth gradient fill whose
/// stroke is the foam line, a lit band just under the surface, glints on the crests and twinkles in the water.
/// World-local coordinates (child of the scene's world node).
///
/// R2 (QA-1 P1-6): the surface is built over a range wider than the screen and rebuilt only when the view leaves it,
/// the zoom drifts by 25 %, the storm's chop moves, or the origin re-bases, a few times a second instead of every
/// frame. The camera transform (the world node) does the rest. The fill's gradient is pinned to fixed sea heights
/// (`seaFillTop` … `seaFillBottom`, via an off-screen marker), so a rebuild never shifts its colours.
@MainActor
final class SceneSeaView {
    let root: SKNode
    private let fill: SKShapeNode
    private let band: SKShapeNode
    private var crests: [SKSpriteNode] = []
    private var crestActive = 0
    private var twinkles: [SKSpriteNode] = []
    private var pts: [CGPoint] = []
    private var step: CGFloat = 1
    private var builtLo: Double = 1
    private var builtHi: Double = 0
    private var builtZoom: CGFloat = 1
    private var builtStormX: Double = 0
    private var builtCalm: Double = 1
    private var builtOrigin: Double = .nan
    private var lineZoom: CGFloat = 0
    /// Rebuilds since the scene was made (tests, tuning).
    private(set) var rebuildCount = 0

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
            let s = SKSpriteNode(texture: SceneTextures.streak, size: CGSize(width: 74, height: 7))
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
        pts.reserveCapacity(400)
    }

    func apply(sky: Sky) {
        let near = sky.seaNear
        let crest = ScenePaint.lighter(near, 0.20).mixed(with: sky.horizon, 0.20)
        // Stops over the fixed extent 700 … −1400 sea pt: crests (≈ +150) light, the mean line seaNear, troughs and the
        // deep darker.
        fill.fillTexture = SceneTextures.verticalGradient(
            key: "sea2-\(sky.id.rawValue)",
            colors: [ScenePaint.ui(crest), ScenePaint.ui(crest), ScenePaint.ui(near),
                     ScenePaint.ui(ScenePaint.darker(near, 0.3)), ScenePaint.ui(ScenePaint.darker(near, 0.62))],
            locations: [0, 0.24, 0.34, 0.50, 1])
        fill.strokeColor = ScenePaint.ui(sky.foam, alpha: 0.95)
        band.strokeColor = ScenePaint.ui(ScenePaint.lighter(near, 0.32).mixed(with: sky.horizon, 0.35), alpha: 0.36)
        let glint = ScenePaint.ui(sky.foam.mixed(with: sky.sun, 0.45))
        for s in crests { s.color = glint }
        for s in twinkles { s.color = glint }
    }

    /// Forces a rebuild on the next frame (reset, layout).
    func invalidate() {
        builtLo = 1
        builtHi = 0
        builtOrigin = .nan
    }

    /// The sea range and step to sample when the cached surface no longer covers the view, else nil.
    func rebuildRequest(visibleLo: Double, visibleHi: Double, zoom z: CGFloat, stormX: Double, stormNear: Bool,
                        calm: Double, originX: Double) -> (lo: Double, hi: Double, step: Double)? {
        var stale = originX != builtOrigin || visibleLo < builtLo || visibleHi > builtHi
        if z / max(builtZoom, 0.01) > SceneLook.seaRebuildZoomDrift { stale = true }
        if stormNear && abs(stormX - builtStormX) > SceneLook.seaRebuildStormMove { stale = true }
        if abs(calm - builtCalm) > 0.15 { stale = true }
        guard stale else { return nil }
        let v = max(visibleHi - visibleLo, 1)
        let s = max(3.0, v / SceneLook.seaSegmentsPerScreen)
        return (visibleLo - SceneLook.seaBuildBehind * v, visibleHi + SceneLook.seaBuildAhead * v, s)
    }

    /// Rebuilds the surface from Core's samples (sea space), adding the storm's static chop near `stormX`.
    func rebuild(samples: [CGPoint], lo: Double, hi: Double, zoom z: CGFloat, stormX: Double, calm: Double,
                 originX: Double) {
        guard samples.count >= 3 else { return }
        rebuildCount += 1
        builtLo = lo
        builtHi = hi
        builtZoom = z
        builtStormX = stormX
        builtCalm = calm
        builtOrigin = originX
        pts.removeAll(keepingCapacity: true)
        for p in samples {
            let sx = Double(p.x)
            var y = Double(p.y)
            let k = min(max(1 - (sx - stormX) / SceneLook.chopReach, 0), 1) * calm
            if k > 0 {
                y += k * SceneLook.chopAmp * (0.6 * sin(sx * 0.083) + 0.4 * sin(sx * 0.041 + 1.1))
            }
            pts.append(CGPoint(x: CGFloat(sx - originX), y: CGFloat(y)))
        }
        guard let first = pts.first, let last = pts.last else { return }
        step = max((last.x - first.x) / CGFloat(pts.count - 1), 0.001)

        let fp = CGMutablePath()
        fp.move(to: CGPoint(x: first.x, y: SceneLook.seaFillBottom))
        for p in pts { fp.addLine(to: p) }
        fp.addLine(to: CGPoint(x: last.x, y: SceneLook.seaFillBottom))
        fp.closeSubpath()
        // An off-screen speck at the fixed top, so the gradient's box (and so its colours) never moves.
        fp.move(to: CGPoint(x: first.x - 20, y: SceneLook.seaFillTop))
        fp.addLine(to: CGPoint(x: first.x - 19, y: SceneLook.seaFillTop))
        fp.addLine(to: CGPoint(x: first.x - 20, y: SceneLook.seaFillTop - 1))
        fp.closeSubpath()
        fill.path = fp

        let d = SceneLook.bandDepth / z
        let bp = CGMutablePath()
        bp.move(to: CGPoint(x: first.x, y: first.y - d))
        for i in 1..<pts.count {
            bp.addLine(to: CGPoint(x: pts[i].x, y: pts[i].y - d))
        }
        band.path = bp
        setLineWidths(z)
        placeCrests()
    }

    /// Per frame: line widths (only when the zoom moved > 4 %), crest glints and twinkles. No path work.
    func animate(zoom z: CGFloat, time t: Double, visibleLo: Double, visibleHi: Double, originX: Double) {
        guard pts.count >= 3 else {
            root.isHidden = true
            return
        }
        root.isHidden = false
        if lineZoom <= 0 || abs(z / lineZoom - 1) > 0.04 { setLineWidths(z) }
        let inv = 1 / max(z, 0.01)
        for i in 0..<crestActive {
            let s = crests[i]
            let seaX = Double(s.position.x) + originX
            s.setScale(inv)
            s.alpha = CGFloat(0.42 + 0.22 * sin(t * 2.6 + seaX * 0.011))
        }
        updateTwinkles(zoom: z, time: t, visibleLo: visibleLo, visibleHi: visibleHi, originX: originX)
    }

    private func setLineWidths(_ z: CGFloat) {
        lineZoom = z
        fill.lineWidth = SceneLook.foamLineWidth / z
        band.lineWidth = SceneLook.bandWidth / z
    }

    /// A glint on every crest: a sample that is the highest within ±40 pt.
    private func placeCrests() {
        let n = pts.count
        let w = max(2, Int((40 / step).rounded(.up)))
        var used = 0
        var i = 1
        while i < n - 1 && used < crests.count {
            let b = pts[i]
            if b.y >= pts[i - 1].y && b.y > pts[i + 1].y {
                var isTop = true
                var j = max(0, i - w)
                let hi = min(n - 1, i + w)
                while j <= hi {
                    if pts[j].y > b.y {
                        isTop = false
                        break
                    }
                    j += 1
                }
                if isTop {
                    let s = crests[used]
                    used += 1
                    s.isHidden = false
                    s.position = CGPoint(x: b.x, y: b.y - 1.5 / builtZoom)
                    i += w
                    continue
                }
            }
            i += 1
        }
        crestActive = used
        while used < crests.count {
            crests[used].isHidden = true
            used += 1
        }
    }

    /// Twinkles at stable pseudo-random spots in the water (one per 150-pt cell), each flashing on its own beat.
    private func updateTwinkles(zoom z: CGFloat, time t: Double, visibleLo: Double, visibleHi: Double,
                                originX: Double) {
        guard let first = pts.first else { return }
        let cell = SceneLook.seaSparkleCell
        var ci = Int((max(visibleLo, Double(first.x) + originX) / cell).rounded(.down))
        var g = 0
        while g < twinkles.count && Double(ci) * cell < visibleHi {
            let h1 = SceneRNG.hash(ci, 11)
            let h2 = SceneRNG.hash(ci, 23)
            let seaX = (Double(ci) + Double(h1)) * cell
            ci += 1
            let lx = CGFloat(seaX - originX)
            let idx = (lx - first.x) / step
            if idx < 0 || idx >= CGFloat(pts.count - 1) { continue }
            let i0 = Int(idx)
            let f = idx - CGFloat(i0)
            let y = pts[i0].y + (pts[i0 + 1].y - pts[i0].y) * f
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
