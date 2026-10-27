import SpriteKit
import UIKit

/// One swell's stretch of sea (sea x): its crest (`from`) and its trough (`to`).
struct SceneSwell: Equatable {
    var from: Double
    var to: Double
}

/// A Flight School guide drawn on the water (ART-ROUND-9 §1B–§1C, SR2–SR3). Positions are sea x. Gold = fold,
/// teal = open; no words.
enum SceneGuide: Equatable {
    case none
    /// Step 3 ("Down"): the fold zone from the crest (`from`) toward the trough (`to`): a gold band on the foam line that
    /// paints solid behind a folded bird (and greys out if it opens early), fold chevrons running down it, and the
    /// closing mini book at the crest.
    case foldPath(from: Double, to: Double)
    /// Step 4 ("Up"): the opening mini book at the launch point just past the trough at `at`, with lift chevrons.
    case openMark(at: Double)
    /// Step 4 ("land"): the landing ring on the downslope at `at` (respawned on the next downslope after a miss).
    case landing(at: Double)
    /// Step 5 ("Rhythm"): every swell carries its fold zone, fold book and open book; a done swell leaves a gold bead.
    case rhythm(swells: [SceneSwell])
    /// The same, placed by the scene on the sea ahead of the bird on the next frame (then fixed in place).
    case foldPathAhead
    case openMarkAhead
    case landingAhead
    case rhythmAhead(count: Int)
}

/// The guides' nodes (world-local: sea x − the scene's origin), under the bird and over the sea. Cue sizes follow
/// the bird's zoom resistance (0.7); the ring keeps its screen size (it is the Perfect window).
@MainActor
final class SceneGuides {
    let root: SKNode
    private var cues: [SceneSwellCue] = []
    private let ring: SceneLandingRing
    private var active: SceneGuide = .none
    /// Reduce Motion: the books stand still (closed 110° / open 170°), the chevrons and the ring don't move.
    var reduceMotion = false
    /// The guide shown now (resolved to sea positions), for tests.
    var shown: SceneGuide { active }
    /// Whether any guide is drawn at all this frame.
    var isDrawing: Bool { ring.isDrawing || cues.contains { $0.isDrawing } }
    /// The live ring's centre (sea x, the water's y there), nil when no ring is up.
    var ringCenter: CGPoint? { ring.liveCenter }
    /// R12: the live ring's sea x from the moment it is placed (the camera frames it on that same frame).
    var ringX: Double? { ring.liveX }
    /// R12: how far the ring has faded in (0 … 1); it is only named once it is plainly drawn.
    var ringLevel: CGFloat { ring.shownLevel }
    /// Set when a missed ring has faded out: the scene places it again on the next downslope ahead.
    private(set) var ringNeedsRespawn = false
    /// R12 (ROUND-12 P0-1): the storm step's ring (`.landingAhead`) keeps coming back: after a Perfect in it, another
    /// is placed ahead `ringRepeatDelay` later, so "Land in the gold ring" always has a ring to name.
    private(set) var repeatsRing = false
    private var repeatTimer: Double?
    /// R12 (ROUND-12 P0-3): where the bird opened too soon in each live fold zone (sea x), marked by a gold tick.
    var missMarks: [Double] { cues.compactMap { $0.missMarkX } }
    /// The fold zones' paint (tests): how far it has got (sea x), whether a stretch was flown open, whether done.
    var foldPaint: [(painted: Double, missed: Bool, done: Bool)] {
        cues.filter { $0.fold && $0.isLive }.map { ($0.paintedTo, $0.missFrom != nil, $0.done) }
    }

    init() {
        root = SKNode()
        ring = SceneLandingRing()
        root.addChild(ring.root)
        for _ in 0..<3 {
            let c = SceneSwellCue()
            root.addChild(c.root)
            cues.append(c)
        }
    }

    func apply(foam: UIColor) {}

    /// Shows a resolved guide (sea positions); `.none` fades everything out. `repeatsRing`: the ring came from
    /// `.landingAhead` (the storm step), so a Perfect in it brings the next one ahead.
    func show(_ g: SceneGuide, repeatsRing repeats: Bool = false) {
        active = g
        ringNeedsRespawn = false
        repeatsRing = repeats
        repeatTimer = nil
        var swells: [(SceneSwell, Bool, Bool)] = []
        switch g {
        case .foldPath(let from, let to): swells = [(SceneSwell(from: from, to: to), true, false)]
        case .openMark(let x): swells = [(SceneSwell(from: x - 400, to: x), false, true)]
        case .rhythm(let list): swells = list.prefix(3).map { ($0, true, true) }
        case .landing(let x): ring.place(at: x)
        case .none, .foldPathAhead, .openMarkAhead, .landingAhead, .rhythmAhead: break
        }
        if case .landing = g {} else { ring.retire() }
        for (i, c) in cues.enumerated() {
            if i < swells.count {
                c.place(swells[i].0, fold: swells[i].1, open: swells[i].2)
            } else {
                c.retire()
            }
        }
    }

    /// The ring after a miss, on the next downslope ahead (`x`, sea), or gone (nil).
    func respawnRing(at x: Double?) {
        ringNeedsRespawn = false
        guard let x = x else {
            ring.retire()
            return
        }
        active = .landing(at: x)
        ring.place(at: x)
    }

    func clear() {
        active = .none
        ringNeedsRespawn = false
        repeatsRing = false
        repeatTimer = nil
        ring.clear()
        for c in cues { c.clear() }
    }

    /// A Perfect at sea x `x`: if it is in the live ring, the ring becomes the real Perfect (the caller adds the
    /// burst). Returns the ring's centre (sea x) when it landed in it.
    func perfectLanded(at x: Double, zoom z: CGFloat) -> Double? {
        guard let rx = ring.hit(x: x, zoom: z) else { return nil }
        if repeatsRing {
            repeatTimer = SceneLook.ringRepeatDelay
        } else {
            active = .none
        }
        return rx
    }

    /// Any other touchdown near or past the ring: a miss (the ring fades over 0.3 s, then respawns ahead).
    func missedRing(birdX x: Double, zoom z: CGFloat) {
        ring.miss(x: x, zoom: z)
    }

    /// Per frame. `height`: the sea surface at a sea x. `birdX` / `birdY` / `tuck`: the player's bird (the fold zones
    /// paint behind it; the ring brightens under it).
    func update(dt: CGFloat, time t: Double, zoom z: CGFloat, originX: Double, birdX: Double, birdY: Double,
                tuck: Double, height: (Double) -> Double) {
        let zz = max(z, 0.01)
        let resist = pow(zz, -SceneLook.birdZoomResist)
        for c in cues {
            c.update(dt: dt, time: t, zoom: zz, resist: resist, originX: originX, birdX: birdX, tuck: tuck,
                     still: reduceMotion, height: height)
        }
        ring.update(dt: dt, time: t, zoom: zz, originX: originX, birdX: birdX, birdY: birdY, still: reduceMotion,
                    height: height)
        if ring.wantsRespawn {
            ring.wantsRespawn = false
            ringNeedsRespawn = true
        }
        if let left = repeatTimer {
            let next = left - Double(dt)
            if next <= 0 {
                repeatTimer = nil
                ringNeedsRespawn = true
            } else {
                repeatTimer = next
            }
        }
    }

    // MARK: Glyph art (pure)

    /// The mini book (ART-ROUND-9 §1B): two 14 × 20 pt panels on a 2 pt spine, opening angle `angle` (degrees), in a
    /// 3/4 view with §1D's exaggerated display angle φd = min(1.6 · (180° − θ) / 2, 60°); centred on the origin, y up.
    nonisolated static func bookPath(angle: Double) -> CGPath {
        let theta = min(max(angle.isFinite ? angle : 180, 100), 180)
        let phi = CGFloat(min(1.6 * (180 - theta) / 2, 60) * Double.pi / 180)
        let w = SceneLook.bookPanelWidth * cos(phi)
        let h = SceneLook.bookPanelHeight * 0.5
        let outer = h * (1 + 0.18 * sin(phi))
        let spine: CGFloat = 1
        let p = CGMutablePath()
        for side in [CGFloat(-1), CGFloat(1)] {
            let sx = side * spine, ox = side * (spine + w)
            p.move(to: CGPoint(x: sx, y: -h))
            p.addLine(to: CGPoint(x: ox, y: -outer))
            p.addLine(to: CGPoint(x: ox, y: outer))
            p.addLine(to: CGPoint(x: sx, y: h))
            p.closeSubpath()
        }
        p.addRect(CGRect(x: -spine, y: -h - 1, width: spine * 2, height: h * 2 + 2))
        return p
    }

    /// A chevron pointing +x (y up), `length` along its direction and `span` across it.
    nonisolated static func chevronPath(length: CGFloat, span: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -length * 0.5, y: span * 0.5))
        p.addLine(to: CGPoint(x: length * 0.5, y: 0))
        p.addLine(to: CGPoint(x: -length * 0.5, y: -span * 0.5))
        return p
    }

    /// The book's angle over its 1.2 s cycle: closing 170° → 110° (or opening, the reverse), holding, then easing
    /// back. Reduce Motion: still at 110° (closing) or 170° (opening).
    nonisolated static func bookAngle(time t: Double, closing: Bool, still: Bool) -> Double {
        if still { return closing ? 110 : 170 }
        let c = SceneLook.bookCycle
        let k = ((t.truncatingRemainder(dividingBy: c) + c).truncatingRemainder(dividingBy: c)) / c
        var e: Double
        if k < 0.6 {
            let q = k / 0.6
            e = q * q * (3 - 2 * q)
        } else if k < 0.85 {
            e = 1
        } else {
            let q = (k - 0.85) / 0.15
            e = 1 - q * q * (3 - 2 * q)
        }
        e = min(max(e, 0), 1)
        return closing ? 170 - 60 * e : 110 + 60 * e
    }
}

/// One swell's cues: the fold zone band (+ glow) with its fold chevrons, the lift chevrons at the launch, and the done
/// bead. R11 (ROUND-11 P0-4): no book glyphs on the water any more. The fold book at the crest sat on the waiting gull's
/// back as a second fold diagram (s1-05, s1-06); the App's diagram is the one tuck indicator. (`bookPath` and
/// `bookAngle` stay as pure art helpers.)
@MainActor
final class SceneSwellCue {
    let root: SKNode
    private let band: SKNode
    private var segments: [SKSpriteNode] = []
    private var glows: [SKSpriteNode] = []
    private var foldChevrons: [SKShapeNode] = []
    private var liftChevrons: [SKShapeNode] = []
    private let bead: SKNode
    /// R12 (ROUND-12 P0-3): the gold tick where the bird opened too soon.
    private let missTick: SKNode
    private var tickLevel: CGFloat = 0
    private(set) var swell = SceneSwell(from: 0, to: 0)
    private(set) var fold = false
    private(set) var opens = false
    private var level: CGFloat = 0
    private var on = false
    private(set) var paintedTo: Double = 0
    private(set) var missFrom: Double?
    private(set) var done = false
    private var beadLevel: CGFloat = 0
    var isDrawing: Bool { level > 0.002 || beadLevel > 0.002 }
    var isLive: Bool { on }
    /// R12: where the bird opened too soon in this live fold zone (sea x), nil when it hasn't.
    var missMarkX: Double? { fold && on && !done ? missFrom : nil }
    private let gold = ScenePaint.ui(ScenePalette.rewardGold)
    private let mist = ScenePaint.ui(SceneLook.mist)
    private let teal = ScenePaint.ui(SceneLook.openTeal)

    init() {
        root = SKNode()
        band = SKNode()
        bead = SKNode()
        missTick = SKNode()
        root.addChild(band)
        let tex = SceneTextures.ribbon
        for _ in 0..<20 {
            let g = SKSpriteNode(texture: tex)
            g.blendMode = .add
            g.colorBlendFactor = 1
            g.color = gold
            g.zPosition = 0
            band.addChild(g)
            glows.append(g)
            let s = SKSpriteNode(texture: tex)
            s.colorBlendFactor = 1
            s.color = gold
            s.zPosition = 0.1
            band.addChild(s)
            segments.append(s)
        }
        let chevron = SceneGuides.chevronPath(length: SceneLook.cueChevronHeight, span: SceneLook.cueChevronWidth)
        for i in 0..<6 {
            let n = SKShapeNode(path: chevron)
            n.fillColor = .clear
            n.strokeColor = i < 3 ? gold : teal
            n.lineWidth = SceneLook.cueChevronStroke
            n.lineCap = .round
            n.lineJoin = .round
            n.zPosition = 0.3
            root.addChild(n)
            if i < 3 { foldChevrons.append(n) } else { liftChevrons.append(n) }
        }
        let ink = ScenePaint.ui(ScenePalette.ink, alpha: 0.4)
        let r = SceneLook.beadSize * 0.5
        let disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = gold
        disc.strokeColor = ink
        disc.lineWidth = 1
        bead.addChild(disc)
        let tick = CGMutablePath()
        tick.move(to: CGPoint(x: -r * 0.45, y: 0))
        tick.addLine(to: CGPoint(x: -r * 0.1, y: -r * 0.35))
        tick.addLine(to: CGPoint(x: r * 0.5, y: r * 0.35))
        let tickNode = SKShapeNode(path: tick)
        tickNode.strokeColor = ScenePaint.ui(ScenePalette.ink)
        tickNode.lineWidth = 2
        tickNode.lineCap = .round
        tickNode.lineJoin = .round
        tickNode.fillColor = .clear
        bead.addChild(tickNode)
        bead.zPosition = 0.5
        root.addChild(bead)
        // The early-open tick: a short gold stroke across the foam line on an ink underlay (it reads on the pale face
        // and on the grey miss band alike).
        let tickPath = CGMutablePath()
        tickPath.move(to: CGPoint(x: 0, y: -SceneLook.missTickHeight * 0.5))
        tickPath.addLine(to: CGPoint(x: 0, y: SceneLook.missTickHeight * 0.5))
        let under = SKShapeNode(path: tickPath)
        under.strokeColor = ScenePaint.ui(ScenePalette.ink, alpha: 0.55)
        under.lineWidth = SceneLook.missTickWidth + 3
        under.lineCap = .round
        under.fillColor = .clear
        missTick.addChild(under)
        let mark = SKShapeNode(path: tickPath)
        mark.strokeColor = gold
        mark.lineWidth = SceneLook.missTickWidth
        mark.lineCap = .round
        mark.fillColor = .clear
        mark.zPosition = 0.1
        missTick.addChild(mark)
        missTick.zPosition = 0.6
        missTick.isHidden = true
        root.addChild(missTick)
        root.isHidden = true
    }

    func place(_ s: SceneSwell, fold f: Bool, open o: Bool) {
        if s != swell || f != fold || o != opens || !on {
            paintedTo = s.from
            missFrom = nil
            done = false
            beadLevel = 0
        }
        swell = s
        fold = f
        opens = o
        on = true
    }

    func retire() { on = false }

    func clear() {
        on = false
        level = 0
        beadLevel = 0
        tickLevel = 0
        done = false
        missFrom = nil
        root.isHidden = true
    }

    func update(dt: CGFloat, time t: Double, zoom z: CGFloat, resist r: CGFloat, originX: Double, birdX: Double,
                tuck: Double, still: Bool, height: (Double) -> Double) {
        if on {
            level = min(1, level + dt / SceneLook.cueFadeIn)
        } else {
            level = max(0, level - dt / SceneLook.cueFadeOut)
            beadLevel = max(0, beadLevel - dt / SceneLook.cueFadeOut)
        }
        root.isHidden = level <= 0.002 && beadLevel <= 0.002
        guard !root.isHidden else { return }
        let from = swell.from, to = swell.to
        let zoneEnd = from + (to - from) * SceneLook.foldZoneEnd

        // The progress paint (fold zones only): covered folded → solid; the first open stretch greys the rest.
        if fold && on && !done {
            if birdX < from - 1 {
                // Back at (or behind) the crest: a fresh attempt (a rewind, or the ghost's re-fly).
                paintedTo = from
                missFrom = nil
            } else if birdX <= zoneEnd {
                if tuck >= SceneLook.foldedTuck && missFrom == nil {
                    paintedTo = max(paintedTo, birdX)
                } else if tuck < SceneLook.foldedTuck && missFrom == nil && birdX > from + 20 {
                    missFrom = birdX
                }
            } else if missFrom == nil && paintedTo >= from + (zoneEnd - from) * 0.7 {
                paintedTo = zoneEnd
                done = true
            }
        }
        if done && on { beadLevel = min(1, beadLevel + dt / SceneLook.cueFadeIn) }
        let a = level

        // The band and its glow.
        band.isHidden = !fold || a <= 0.002
        if !band.isHidden {
            let n = segments.count
            let span = zoneEnd - from
            for k in 0..<n {
                let t0 = Double(k) / Double(n), t1 = Double(k + 1) / Double(n)
                let x0 = from + span * t0, x1 = from + span * t1
                let y0 = height(x0), y1 = height(x1)
                let dx = CGFloat(x1 - x0), dy = CGFloat(y1 - y0)
                let mid = CGPoint(x: CGFloat((x0 + x1) * 0.5 - originX), y: CGFloat((y0 + y1) * 0.5))
                let angle = atan2(dy, dx)
                let length = hypot(dx, dy) + 1.5 / z
                let m = (x0 + x1) * 0.5
                var alpha = SceneLook.foldBandAlpha
                var grey = false
                if m <= paintedTo && paintedTo > from {
                    alpha = SceneLook.foldBandDoneAlpha
                } else if let mf = missFrom, m >= mf {
                    alpha = SceneLook.foldBandMissAlpha
                    grey = true
                }
                let s = segments[k], g = glows[k]
                s.position = mid
                s.zRotation = angle
                s.size = CGSize(width: length, height: SceneLook.foldBandWidth * r)
                s.alpha = alpha * a
                s.color = grey ? mist : gold
                g.position = mid
                g.zRotation = angle
                g.size = CGSize(width: length, height: (SceneLook.foldBandWidth + 2 * SceneLook.foldBandGlow) * r)
                g.alpha = grey ? 0 : SceneLook.foldBandGlowAlpha * a
            }
        }

        // Fold chevrons running down the zone.
        let showFold = fold && a > 0.002 && !done
        let zoneLength = max(zoneEnd - from, 1)
        for (i, c) in foldChevrons.enumerated() {
            c.isHidden = !showFold
            guard showFold else { continue }
            let speed = Double(SceneLook.foldChevronSpeed / z)
            let gap = Double(SceneLook.foldChevronGap / z)
            var d = (still ? 0 : t * speed) + Double(i) * gap
            d = d.truncatingRemainder(dividingBy: zoneLength)
            let x = from + d
            let slope = (height(x + 2) - height(x - 2)) / 4
            c.position = CGPoint(x: CGFloat(x - originX), y: CGFloat(height(x)) + SceneLook.foldChevronLift * r)
            c.zRotation = CGFloat(atan(slope))
            c.setScale(r)
            // Fade in at the top of the zone and out at its end.
            let edge = min(d / (zoneLength * 0.12), (zoneLength - d) / (zoneLength * 0.12), 1)
            c.alpha = SceneLook.cueChevronAlpha * a * CGFloat(max(edge, 0))
        }
        // The lift chevrons at the launch (just past the trough), where the open book used to stand.
        let showOpen = opens && a > 0.002
        let launchX = to + 60
        for (i, c) in liftChevrons.enumerated() {
            c.isHidden = !showOpen
            guard showOpen else { continue }
            let lift = SceneLook.bookLift + SceneLook.bookPanelHeight * 0.5 + 14 + SceneLook.liftChevronGap * CGFloat(i)
            c.position = CGPoint(x: CGFloat(launchX - originX), y: CGFloat(height(launchX)) + lift * r)
            c.zRotation = CGFloat.pi / 2
            c.setScale(r)
            let ph: Double = still ? 1 : 0.5 + 0.5 * sin(2 * Double.pi * (t - 0.15 * Double(i)) / 0.9)
            c.alpha = SceneLook.cueChevronAlpha * a * CGFloat(0.35 + 0.65 * ph)
        }

        // R12 (ROUND-12 P0-3): the early open, marked on the wave where it happened.
        if let mx = missMarkX {
            tickLevel = min(1, tickLevel + dt / SceneLook.missTickFadeIn)
            missTick.position = CGPoint(x: CGFloat(mx - originX), y: CGFloat(height(mx)))
            let slope = (height(mx + 2) - height(mx - 2)) / 4
            missTick.zRotation = CGFloat(atan(slope))
            missTick.setScale(r)
        } else {
            tickLevel = 0
        }
        missTick.isHidden = tickLevel <= 0.002 || a <= 0.002
        if !missTick.isHidden { missTick.alpha = tickLevel * a }

        // The done bead over the crest (it stays with the sea).
        bead.isHidden = beadLevel <= 0.002
        if !bead.isHidden {
            bead.position = CGPoint(x: CGFloat(from - originX), y: CGFloat(height(from)) + SceneLook.beadLift * r)
            bead.setScale(r)
            bead.alpha = beadLevel
        }
    }
}

/// The landing ring (ART-ROUND-9 §1C): a bright gold ellipse on the downslope, with a dotted drop marker above it.
@MainActor
final class SceneLandingRing {
    let root: SKNode
    private let glow: SKShapeNode
    private let main: SKShapeNode
    private var dots: [SKSpriteNode] = []
    private let arrow: SKShapeNode
    private var x: Double?
    private var level: CGFloat = 0
    private var on = false
    private var near: CGFloat = 0
    private var missing = false
    var wantsRespawn = false
    var isDrawing: Bool { level > 0.002 }
    /// The live ring's centre (sea x, the water's sea y), nil when none is up.
    private(set) var liveCenter: CGPoint?

    init() {
        root = SKNode()
        glow = SKShapeNode()
        main = SKShapeNode()
        arrow = SKShapeNode()
        let w = SceneLook.ringWidth
        let ellipse = CGPath(ellipseIn: CGRect(x: -w / 2, y: -w * SceneLook.ringAspect / 2, width: w,
                                               height: w * SceneLook.ringAspect), transform: nil)
        let gold = ScenePaint.ui(ScenePalette.rewardGold)
        glow.path = ellipse
        glow.fillColor = .clear
        glow.strokeColor = gold.withAlphaComponent(SceneLook.ringGlowAlpha)
        glow.lineWidth = SceneLook.ringStroke + SceneLook.ringGlow * 2
        glow.blendMode = .add
        main.path = ellipse
        main.fillColor = gold.withAlphaComponent(SceneLook.ringFillAlpha)
        main.strokeColor = gold.withAlphaComponent(SceneLook.ringAlpha)
        main.lineWidth = SceneLook.ringStroke
        root.addChild(glow)
        root.addChild(main)
        let dotTex = SceneTextures.dot
        let count = Int(SceneLook.dropHeight / SceneLook.dropDotGap)
        for i in 0..<count {
            let d = SKSpriteNode(texture: dotTex, size: CGSize(width: 3, height: 3))
            d.colorBlendFactor = 1
            d.color = gold
            d.alpha = 0.7
            d.position = CGPoint(x: 0, y: SceneLook.dropDotGap * CGFloat(i + 1))
            root.addChild(d)
            dots.append(d)
        }
        arrow.path = SceneGuides.chevronPath(length: SceneLook.dropChevron * 0.5, span: SceneLook.dropChevron)
        arrow.zRotation = -CGFloat.pi / 2
        arrow.strokeColor = gold
        arrow.fillColor = .clear
        arrow.lineWidth = 3
        arrow.lineCap = .round
        arrow.lineJoin = .round
        root.addChild(arrow)
        root.isHidden = true
    }

    func place(at sx: Double) {
        x = sx
        on = true
        missing = false
        wantsRespawn = false
    }

    func retire() { on = false }

    func clear() {
        on = false
        missing = false
        wantsRespawn = false
        level = 0
        liveCenter = nil
        root.isHidden = true
    }

    /// A Perfect at `bx`: in the ring, it turns into the real Perfect ring; returns the centre.
    func hit(x bx: Double, zoom z: CGFloat) -> Double? {
        guard on, !missing, let rx = x, level > 0.2 else { return nil }
        guard abs(bx - rx) <= SceneLandingRing.hitReach(zoom: z) else { return nil }
        on = false
        return rx
    }

    /// The Perfect window either side of the ring's centre (sea pt): 0.75 of its width at this zoom, plus 60.
    nonisolated static func hitReach(zoom z: CGFloat) -> Double {
        Double(SceneLook.ringWidth / max(z, 0.01)) * 0.75 + 60
    }

    /// The live ring's sea x (placed, not landed in, not missed), nil when none is up. Unlike `liveCenter` it is set
    /// the moment the ring is placed, so the camera can frame a ring on the frame it appears.
    var liveX: Double? { on && !missing ? x : nil }
    /// How far the ring has faded in (0 … 1).
    var shownLevel: CGFloat { level }

    /// Any other touchdown near or past the ring: fade over 0.3 s, then ask for a respawn.
    func miss(x bx: Double, zoom z: CGFloat) {
        guard on, !missing, let rx = x, bx > rx - Double(SceneLook.ringWidth / z) * 2 else { return }
        missing = true
    }

    func update(dt: CGFloat, time t: Double, zoom z: CGFloat, originX: Double, birdX: Double, birdY: Double,
                still: Bool, height: (Double) -> Double) {
        guard let rx = x else {
            root.isHidden = true
            liveCenter = nil
            return
        }
        // The bird flying past the ring without landing in it is a miss too. R12 (ROUND-12 P0-1): as soon as it is
        // beyond the Perfect window (it can no longer be landed in), not 1.5 widths + 200 pt later: R11's passed ring
        // stayed "live" behind the bird, so the storm step's words and pointer named a ring off the behind edge.
        if on && !missing && birdX > rx + SceneLandingRing.hitReach(zoom: z) { missing = true }
        if on && !missing {
            level = min(1, level + dt / SceneLook.cueFadeIn)
        } else {
            level = max(0, level - dt / (missing ? 0.3 : SceneLook.cueFadeOut))
            if missing && level <= 0.002 {
                missing = false
                on = false
                wantsRespawn = true
            }
        }
        root.isHidden = level <= 0.002
        let water = height(rx)
        liveCenter = on && !missing ? CGPoint(x: rx, y: water) : nil
        guard !root.isHidden else { return }
        // Brighter and 1.1× once the bird is within 120 pt above it.
        let half = Double(SceneLook.ringWidth / z) * 0.5
        let above = birdY - water
        let isNear = abs(birdX - rx) <= half + 40 && above >= -10 && above <= SceneLook.ringNear / Double(z)
        near += ((isNear ? 1 : 0) - near) * min(1, dt * 8)
        let breath: CGFloat = still ? 1 : CGFloat(1 + 0.04 * sin(2 * Double.pi * SceneLook.ringBreathHz * t))
        root.position = CGPoint(x: CGFloat(rx - originX), y: CGFloat(water))
        root.setScale(1 / z)
        main.setScale(breath * (1 + 0.1 * near))
        glow.setScale(breath * (1 + 0.1 * near))
        glow.alpha = 0.75 + 0.25 * near
        root.alpha = level
        // The drop marker's chevron bobs ±6 pt at 1 Hz over the dotted line.
        let bob: CGFloat = still ? 0 : CGFloat(6 * sin(2 * Double.pi * t))
        arrow.position = CGPoint(x: 0, y: SceneLook.dropHeight + SceneLook.dropChevron * 0.3 + bob)
    }
}

/// Where the "…Ahead" guides go (pure, unit-tested): found on the surface ahead of the bird.
enum SceneGuidePlacement {
    /// The next downslope ahead of `x` on a surface (crest → trough, sea x), searching `reach` pt ahead.
    static func nextDownslope(after x: Double, reach: Double = 9000,
                              height: (Double) -> Double) -> (from: Double, to: Double)? {
        let step = 8.0
        var p = x
        let end = x + reach
        // R12: a level stretch shorter than 40 pt (the bottom of a trough: the bird sitting in one found nothing ahead,
        // so the storm step's ring was never placed) is skipped and the search goes on to the next crest.
        while p < end {
            // Climb to the next crest (or stay on it).
            while p < end && slope(p, height) > 0.002 { p += step }
            let crest = p
            // Then run down to the trough.
            while p < end && slope(p, height) <= 0.002 { p += step }
            if p < end && p - crest > 40 { return (crest, p) }
        }
        return nil
    }

    private static func slope(_ a: Double, _ height: (Double) -> Double) -> Double {
        (height(a + 2) - height(a - 2)) / 4
    }

    /// Resolves an "…Ahead" guide against the sea at the bird's x; others are returned as they are.
    static func resolve(_ g: SceneGuide, birdX: Double, height: (Double) -> Double) -> SceneGuide {
        switch g {
        case .foldPathAhead:
            if let d = nextDownslope(after: birdX, height: height) { return .foldPath(from: d.from, to: d.to) }
            return .none
        case .openMarkAhead:
            if let d = nextDownslope(after: birdX, height: height) { return .openMark(at: d.to) }
            return .none
        case .landingAhead:
            if let x = landingX(after: birdX, height: height) { return .landing(at: x) }
            return .none
        case .rhythmAhead(let count):
            var swells: [SceneSwell] = []
            var from = birdX
            let want = max(min(count, 3), 0)
            while swells.count < want {
                guard let d = nextDownslope(after: from, height: height) else { break }
                swells.append(SceneSwell(from: d.from, to: d.to))
                from = d.to + 8
            }
            return swells.isEmpty ? .none : .rhythm(swells: swells)
        case .none, .foldPath, .openMark, .landing, .rhythm:
            return g
        }
    }

    /// `ringSlopeFraction` (0.35) of the way down the next downslope that starts ahead of `x` (skipping the one the
    /// bird may be sliding down now).
    static func landingX(after birdX: Double, height: (Double) -> Double) -> Double? {
        var from = birdX
        if let d = nextDownslope(after: birdX, height: height), d.from <= birdX + 8 { from = d.to + 8 }
        if let d = nextDownslope(after: from, height: height) {
            return d.from + (d.to - d.from) * SceneLook.ringSlopeFraction
        }
        return nil
    }
}
