import SpriteKit
import UIKit

/// The near sea, the hero of every frame. It is one filled polygon from Core's samples, with these layers:
/// - a depth gradient fill (7 eased stops, ART-S4) whose stroke is the foam line;
/// - a soft sub-surface band;
/// - lit strips on the faces turned toward the sun ahead;
/// - glints on the crests near the sun, and a few dash glints in the water.
///
/// Everything is in world-local coordinates (a child of the scene's world node).
///
/// The surface is built over a range wider than the screen. It is rebuilt only when:
/// - the view leaves that range;
/// - the zoom drifts by 25 %;
/// - the origin re-bases;
/// - the storm's chop zone is on screen and the front has moved (QA-2 P2-2: not merely because the storm is "near").
///
/// The caller passes a reused sample buffer (`SeaProfile.samples(into:)`), so a rebuild allocates nothing new. The
/// fill's gradient is pinned to fixed sea heights through an off-screen speck, so a rebuild never shifts its colours.
@MainActor
final class SceneSeaView {
    let root: SKNode
    private let fill: SKShapeNode
    private let band: SKShapeNode
    private let litWide: SKShapeNode
    private let litNarrow: SKShapeNode
    private var crests: [SKSpriteNode] = []
    private var crestSeaX: [Double] = []
    private var crestActive = 0
    private var twinkles: [SKSpriteNode] = []
    private var lace: [SKSpriteNode] = []
    private var pts: [CGPoint] = []
    private var step: CGFloat = 1
    private var builtLo: Double = 1
    private var builtHi: Double = 0
    private var builtZoom: CGFloat = 1
    private var builtStormX: Double = 0
    private var builtCalm: Double = 1
    private var builtCloseness: Double = 0
    private var builtOrigin: Double = .nan
    private var lineZoom: CGFloat = 0
    /// Rebuilds since the scene was made (tests, tuning).
    private(set) var rebuildCount = 0

    init() {
        root = SKNode()
        fill = SKShapeNode()
        band = SKShapeNode()
        litWide = SKShapeNode()
        litNarrow = SKShapeNode()
        fill.zPosition = 0
        fill.fillColor = .white
        fill.lineJoin = .round
        fill.isAntialiased = true
        for (n, z) in [(litWide, CGFloat(0.3)), (litNarrow, CGFloat(0.35)), (band, CGFloat(0.5))] {
            n.zPosition = z
            n.fillColor = .clear
            n.lineJoin = .round
            n.lineCap = .round
        }
        root.addChild(fill)
        root.addChild(litWide)
        root.addChild(litNarrow)
        root.addChild(band)
        for _ in 0..<SceneLook.crestGlintCount {
            let s = SKSpriteNode(texture: SceneTextures.streak, size: CGSize(width: 74, height: 7))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.zPosition = 1
            s.isHidden = true
            root.addChild(s)
            crests.append(s)
            crestSeaX.append(0)
        }
        for _ in 0..<SceneLook.seaSparkleCount {
            let s = SKSpriteNode(texture: SceneTextures.dash, size: CGSize(width: 18, height: 2))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.zPosition = 1.2
            s.isHidden = true
            root.addChild(s)
            twinkles.append(s)
        }
        for _ in 0..<SceneLook.laceCount {
            let s = SKSpriteNode(texture: SceneTextures.dash, size: CGSize(width: 80, height: 1.5))
            s.colorBlendFactor = 1
            s.zPosition = 0.8
            s.isHidden = true
            root.addChild(s)
            lace.append(s)
        }
        pts.reserveCapacity(400)
    }

    func apply(palette p: ScenePalette, sky id: SkyID) {
        let lit = p.nearCrest.mixed(with: p.nearMean, 0.4)
        let mean85 = ScenePaint.darker(p.nearMean, 0.15)
        let deep70 = ScenePaint.darker(p.nearDeep, 0.30)
        // Seven eased stops over the fixed extent 700 … −1400 sea pt: crests (≈ +150 … +320) in the lit colour, the
        // mean line (≈ −50) at `nearMean`, troughs darker, the deep beyond.
        fill.fillTexture = SceneTextures.verticalGradient(
            key: "sea3-\(id.rawValue)",
            colors: [ScenePaint.ui(p.nearCrest), ScenePaint.ui(p.nearCrest), ScenePaint.ui(lit), ScenePaint.ui(p.nearMean),
                     ScenePaint.ui(mean85), ScenePaint.ui(p.nearDeep), ScenePaint.ui(deep70)],
            locations: [0, 0.18, 0.26, 0.33, 0.40, 0.48, 1])
        fill.strokeColor = ScenePaint.ui(p.foam, alpha: 0.95)
        band.strokeColor = ScenePaint.ui(p.nearCrest, alpha: SceneLook.bandAlpha)
        litWide.strokeColor = ScenePaint.ui(p.nearCrest, alpha: SceneLook.litFaceAlpha * 0.5)
        litNarrow.strokeColor = ScenePaint.ui(p.nearCrest, alpha: SceneLook.litFaceAlpha * 0.5)
        let glint = ScenePaint.ui(p.glitter)
        for s in lace { s.color = ScenePaint.ui(p.foam) }
        for s in crests { s.color = glint }
        for s in twinkles { s.color = glint }
    }

    /// Forces a rebuild on the next frame (reset, layout).
    func invalidate() {
        builtLo = 1
        builtHi = 0
        builtOrigin = .nan
    }

    /// The sea range and step to sample when the cached surface no longer covers the view, else nil. `chopOnScreen`:
    /// the storm's chop zone (`stormX … stormX + chopReach`) overlaps the view.
    func rebuildRequest(visibleLo: Double, visibleHi: Double, zoom z: CGFloat, stormX: Double, chopOnScreen: Bool,
                        closeness: Double, calm: Double, originX: Double) -> (lo: Double, hi: Double, step: Double)? {
        var stale = originX != builtOrigin || visibleLo < builtLo || visibleHi > builtHi
        if z / max(builtZoom, 0.01) > SceneLook.seaRebuildZoomDrift { stale = true }
        if chopOnScreen && abs(stormX - builtStormX) > SceneLook.seaRebuildStormMove { stale = true }
        if chopOnScreen && abs(closeness - builtCloseness) > 0.2 { stale = true }
        if abs(calm - builtCalm) > 0.15 { stale = true }
        // Land exactly on the calm swell once the caught ending has settled.
        if calm <= 0.001 && builtCalm > 0.001 { stale = true }
        guard stale else { return nil }
        let v = max(visibleHi - visibleLo, 1)
        let s = max(3.0, v / SceneLook.seaSegmentsPerScreen)
        return (visibleLo - SceneLook.seaBuildBehind * v, visibleHi + SceneLook.seaBuildAhead * v, s)
    }

    /// Rebuilds the surface from Core's samples (sea space), adding the storm's static chop near `stormX`
    /// (9 → 14 pt as the storm closes).
    func rebuild(samples: [CGPoint], lo: Double, hi: Double, zoom z: CGFloat, stormX: Double, closeness: Double,
                 calm: Double, originX: Double) {
        guard samples.count >= 3 else { return }
        rebuildCount += 1
        builtLo = lo
        builtHi = hi
        builtZoom = z
        builtStormX = stormX
        builtCloseness = closeness
        builtCalm = calm
        builtOrigin = originX
        let amp = SceneLook.chopAmp + SceneLook.chopAmpClose * min(max(closeness, 0), 1)
        pts.removeAll(keepingCapacity: true)
        for p in samples {
            let sx = Double(p.x)
            var y = SceneSeaView.calmed(Double(p.y), x: sx, calm: calm)
            let k = min(max(1 - (sx - stormX) / SceneLook.chopReach, 0), 1) * calm
            if k > 0 {
                y += k * amp * (0.6 * sin(sx * 0.045) + 0.4 * sin(sx * 0.024 + 1.1))
            }
            pts.append(CGPoint(x: CGFloat(sx - originX), y: CGFloat(y)))
        }
        guard let first = pts.first, let last = pts.last else { return }
        step = max((last.x - first.x) / CGFloat(pts.count - 1), 0.001)

        let fp = CGMutablePath()
        fp.move(to: CGPoint(x: first.x, y: SceneLook.seaFillBottom))
        SceneSeaView.addSmooth(fp, pts, dy: 0, moveFirst: false)
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
        SceneSeaView.addSmooth(bp, pts, dy: -d, moveFirst: true)
        band.path = bp

        // Lit faces: each run of samples going down toward the sun (dh/dx < 0), as a strip just under the surface.
        let wide = CGMutablePath()
        let narrow = CGMutablePath()
        let wd = SceneLook.litFaceWidth / z
        var runStart = -1
        for i in 0..<(pts.count - 1) {
            let falling = pts[i + 1].y < pts[i].y - 0.05 * step
            if falling && runStart < 0 { runStart = i }
            if (!falling || i == pts.count - 2) && runStart >= 0 {
                let end = falling ? i + 1 : i
                if end - runStart >= 3 {
                    addStrip(wide, from: runStart, to: end, depth: wd * 0.5)
                    addStrip(narrow, from: runStart, to: end, depth: wd * 0.22)
                }
                runStart = -1
            }
        }
        litWide.path = wide
        litNarrow.path = narrow
        setLineWidths(z)
        placeCrests()
    }

    /// The caught / Results sea (REVIEW-4 juror #7): as `calm` → 0 the surface blends from Core's swells into one
    /// calm swell (amplitude ≤ 60 pt, wavelength ≥ 500 pt), so the ending reads as quiet water, not a ridge. The
    /// scene uses the same function for the bird bobbing on it.
    nonisolated static func calmed(_ h: Double, x: Double, calm: Double) -> Double {
        let b = 1 - min(max(calm, 0), 1)
        if b <= 0 { return h }
        let swell = SceneLook.calmSwellAmp * sin(x * 2 * Double.pi / SceneLook.calmSwellLength)
        return h + (swell - h) * b
    }

    /// A smooth curve through `points` (quads through the midpoints, the samples as controls): no polyline corners,
    /// so a choppy stretch reads as rolling water, not a mountain ridge (REVIEW-3 juror #9).
    static func addSmooth(_ path: CGMutablePath, _ points: [CGPoint], dy: CGFloat, moveFirst: Bool) {
        guard let first = points.first else { return }
        let p0 = CGPoint(x: first.x, y: first.y + dy)
        if moveFirst { path.move(to: p0) } else { path.addLine(to: p0) }
        let n = points.count
        if n < 3 {
            for i in 1..<n { path.addLine(to: CGPoint(x: points[i].x, y: points[i].y + dy)) }
            return
        }
        for i in 1..<(n - 1) {
            let c = points[i]
            let next = points[i + 1]
            let m = CGPoint(x: (c.x + next.x) * 0.5, y: (c.y + next.y) * 0.5 + dy)
            path.addQuadCurve(to: m, control: CGPoint(x: c.x, y: c.y + dy))
        }
        let last = points[n - 1]
        path.addLine(to: CGPoint(x: last.x, y: last.y + dy))
    }

    private func addStrip(_ path: CGMutablePath, from a: Int, to b: Int, depth: CGFloat) {
        path.move(to: CGPoint(x: pts[a].x, y: pts[a].y - depth))
        var i = a + 1
        while i <= b {
            path.addLine(to: CGPoint(x: pts[i].x, y: pts[i].y - depth))
            i += 1
        }
    }

    /// Per frame: line widths (only when the zoom moved > 4 %), crest glints near the sun and the dash glints. No path
    /// work. `sunSeaX`: the sea x under the sun; `reach`: 0.30 w in canvas px; `fast` 0…1 lifts the glints at full
    /// speed; `fine` false hides them (the fold-blur guard).
    func animate(zoom z: CGFloat, time t: Double, visibleLo: Double, visibleHi: Double, originX: Double,
                 sunSeaX: Double, reach: CGFloat, fast: CGFloat, fine: Bool) {
        guard pts.count >= 3 else {
            root.isHidden = true
            return
        }
        root.isHidden = false
        if lineZoom <= 0 || abs(z / lineZoom - 1) > 0.04 { setLineWidths(z) }
        let inv = 1 / max(z, 0.01)
        let peak = SceneLook.glintAlpha + (SceneLook.glintAlphaFast - SceneLook.glintAlpha) * fast
        for i in 0..<crestActive {
            let s = crests[i]
            let dx = CGFloat(abs(crestSeaX[i] - sunSeaX)) * z
            let k = 1 - dx / max(reach, 1)
            if !fine || k <= 0 {
                s.isHidden = true
                continue
            }
            s.isHidden = false
            s.setScale(inv)
            s.alpha = peak * k * CGFloat(0.85 + 0.15 * sin(t * 2.6 + crestSeaX[i] * 0.011))
        }
        updateTwinkles(zoom: z, time: t, visibleLo: visibleLo, visibleHi: visibleHi, originX: originX,
                       sunSeaX: sunSeaX, reach: reach * 1.5, fine: fine)
        updateLace(zoom: z, visibleLo: visibleLo, visibleHi: visibleHi, originX: originX)
    }

    /// Lace (REVIEW-3 juror #8): foam streaks lying on the faces just under the surface, at stable spots (one per
    /// 260-pt cell), each along the local slope: the sea reads as moving water, not a slab.
    private func updateLace(zoom z: CGFloat, visibleLo: Double, visibleHi: Double, originX: Double) {
        guard let first = pts.first else { return }
        let cell = SceneLook.laceCell
        var ci = Int((max(visibleLo, Double(first.x) + originX) / cell).rounded(.down))
        var g = 0
        while g < lace.count && Double(ci) * cell < visibleHi {
            let h1 = SceneRNG.hash(ci, 31)
            let h2 = SceneRNG.hash(ci, 47)
            let seaX = (Double(ci) + Double(h1)) * cell
            ci += 1
            let lx = CGFloat(seaX - originX)
            let idx = (lx - first.x) / step
            if idx < 1 || idx >= CGFloat(pts.count - 2) { continue }
            let i0 = Int(idx)
            let f = idx - CGFloat(i0)
            let y = pts[i0].y + (pts[i0 + 1].y - pts[i0].y) * f
            let slope = (pts[i0 + 1].y - pts[i0].y) / max(pts[i0 + 1].x - pts[i0].x, 0.001)
            let s = lace[g]
            g += 1
            s.isHidden = false
            s.position = CGPoint(x: lx, y: y - (12 + 50 * h2) / z)
            s.zRotation = atan(slope)
            s.size = CGSize(width: (60 + 120 * h1) / z, height: 1.5 / z)
            s.alpha = SceneLook.laceAlpha * (0.6 + 0.4 * h2)
        }
        while g < lace.count {
            lace[g].isHidden = true
            g += 1
        }
    }

    private func setLineWidths(_ z: CGFloat) {
        lineZoom = z
        fill.lineWidth = SceneLook.foamLineWidth / z
        band.lineWidth = SceneLook.bandWidth / z
        litWide.lineWidth = SceneLook.litFaceWidth / z
        litNarrow.lineWidth = SceneLook.litFaceWidth * 0.44 / z
    }

    /// Glint positions on every crest (a sample that is the highest within ±40 pt); shown per frame near the sun.
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
                    s.position = CGPoint(x: b.x, y: b.y - 1.5 / builtZoom)
                    crestSeaX[used] = Double(b.x) + (builtOrigin.isNaN ? 0 : builtOrigin)
                    used += 1
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

    /// Dash glints at stable pseudo-random spots in the water (one per 150-pt cell) on the sun's side, each flashing
    /// on its own beat.
    private func updateTwinkles(zoom z: CGFloat, time t: Double, visibleLo: Double, visibleHi: Double,
                                originX: Double, sunSeaX: Double, reach: CGFloat, fine: Bool) {
        guard let first = pts.first, fine else {
            for s in twinkles where !s.isHidden { s.isHidden = true }
            return
        }
        let cell = SceneLook.seaSparkleCell
        var ci = Int((max(visibleLo, Double(first.x) + originX) / cell).rounded(.down))
        var g = 0
        while g < twinkles.count && Double(ci) * cell < visibleHi {
            let h1 = SceneRNG.hash(ci, 11)
            let h2 = SceneRNG.hash(ci, 23)
            let seaX = (Double(ci) + Double(h1)) * cell
            ci += 1
            if CGFloat(abs(seaX - sunSeaX)) * z > reach { continue }
            let lx = CGFloat(seaX - originX)
            let idx = (lx - first.x) / step
            if idx < 0 || idx >= CGFloat(pts.count - 1) { continue }
            let i0 = Int(idx)
            let f = idx - CGFloat(i0)
            let y = pts[i0].y + (pts[i0 + 1].y - pts[i0].y) * f
            let beat = sin(t * (2.0 + Double(h2) * 2.2) + Double(h1) * 6.283)
            let a = CGFloat(max(0, beat))
            let alpha = a * a * a * 0.8
            let s = twinkles[g]
            g += 1
            s.isHidden = alpha < 0.02
            s.position = CGPoint(x: lx, y: y - (4 + h2 * 26) / z)
            s.setScale((0.7 + 0.5 * h2) / z)
            s.alpha = alpha
        }
        while g < twinkles.count {
            twinkles[g].isHidden = true
            g += 1
        }
    }
}
