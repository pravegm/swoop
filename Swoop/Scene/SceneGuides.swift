import SpriteKit
import UIKit

/// A Flight School guide drawn on the water (ART-FLIGHT-SCHOOL §2, SC2). Positions are sea x.
enum SceneGuide: Equatable {
    case none
    /// Step 3: a gold ribbon along the foam line from the crest (`from`) down to the trough (`to`): "fold along here".
    case foldPath(from: Double, to: Double)
    /// Step 4: three "lift" chevrons over the trough, pointing up and ahead.
    case openMark(at: Double)
    /// Step 5: a ghost Perfect ring on the downslope.
    case landing(at: Double)
    /// The same three, placed by the scene on the sea ahead of the bird at the moment they are set (and then fixed in
    /// place): the next downslope, its trough, and the middle of the next downslope.
    case foldPathAhead
    case openMarkAhead
    case landingAhead
}

/// The guides' nodes (world-local: sea x − the scene's origin), under the bird and over the sea. Sizes are screen
/// points (divided by the zoom). Each guide fades in over 0.3 s and out over 0.25 s.
@MainActor
final class SceneGuides {
    let root: SKNode
    private let ribbon: SKNode
    private var segments: [SKSpriteNode] = []
    private let chevrons: SKNode
    private var chevronNodes: [SKShapeNode] = []
    private let ring: SKShapeNode
    private var ribbonLevel: CGFloat = 0
    private var chevronLevel: CGFloat = 0
    private var ringLevel: CGFloat = 0
    private var path: (from: Double, to: Double)?
    private var markX: Double?
    private var ringX: Double?
    private var active: SceneGuide = .none
    /// The guide shown now (resolved to sea positions), for tests.
    var shown: SceneGuide { active }
    /// Whether any guide is drawn at all this frame.
    var isDrawing: Bool { ribbonLevel > 0.002 || chevronLevel > 0.002 || ringLevel > 0.002 }

    init() {
        root = SKNode()
        ribbon = SKNode()
        chevrons = SKNode()
        ring = SKShapeNode()
        root.addChild(ribbon)
        root.addChild(chevrons)
        root.addChild(ring)
        let gold = ScenePaint.ui(ScenePalette.rewardGold)
        let tex = SceneTextures.ribbon
        for _ in 0..<SceneLook.foldPathSegments {
            let s = SKSpriteNode(texture: tex)
            s.colorBlendFactor = 1
            s.color = gold
            ribbon.addChild(s)
            segments.append(s)
        }
        let cw = SceneLook.chevronWidth * 0.5, ch = SceneLook.chevronHeight * 0.5
        for i in 0..<3 {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -cw, y: -ch))
            p.addLine(to: CGPoint(x: 0, y: ch))
            p.addLine(to: CGPoint(x: cw, y: -ch))
            let n = SKShapeNode(path: p)
            n.strokeColor = .white
            n.fillColor = .clear
            n.lineWidth = SceneLook.chevronStroke
            n.lineCap = .round
            n.lineJoin = .round
            // Pointing up and ahead (+x, +y), stacked along that direction.
            n.zRotation = -CGFloat.pi / 4
            let step = CGFloat(i) * 11
            n.position = CGPoint(x: step * 0.7071, y: step * 0.7071)
            chevrons.addChild(n)
            chevronNodes.append(n)
        }
        let w = SceneLook.landingRingWidth
        let ellipse = CGPath(ellipseIn: CGRect(x: -w / 2, y: -w * SceneLook.ringAspect / 2, width: w,
                                               height: w * SceneLook.ringAspect), transform: nil)
        ring.path = ellipse.copy(dashingWithPhase: 0, lengths: [8, 6])
        ring.strokeColor = UIColor(white: 1, alpha: SceneLook.landingRingAlpha)
        ring.fillColor = .clear
        ring.lineWidth = SceneLook.landingRingStroke
        ring.lineCap = .round
        for n in [ribbon, chevrons, ring] as [SKNode] { n.isHidden = true }
    }

    func apply(foam: UIColor) {
        ring.strokeColor = foam.withAlphaComponent(SceneLook.landingRingAlpha)
    }

    /// Shows a resolved guide (sea positions); `.none` fades everything out.
    func show(_ g: SceneGuide) {
        active = g
        switch g {
        case .foldPath(let from, let to): path = (from, to)
        case .openMark(let x): markX = x
        case .landing(let x): ringX = x
        case .none, .foldPathAhead, .openMarkAhead, .landingAhead: break
        }
    }

    func clear() {
        active = .none
        ribbonLevel = 0
        chevronLevel = 0
        ringLevel = 0
        for n in [ribbon, chevrons, ring] as [SKNode] { n.isHidden = true }
    }

    /// A Perfect at sea x `x`: if the landing ring is up and the touchdown is in it, the ghost bursts (the caller adds
    /// the motes) and fades. Returns the ring's centre (sea) when it burst.
    func perfectLanded(at x: Double) -> Double? {
        guard case .landing(let rx) = active, ringLevel > 0.2, abs(x - rx) <= SceneLook.landingHitRange else { return nil }
        active = .none
        return rx
    }

    /// Per frame. `height`: the sea surface at a sea x. `time`: the FX clock.
    func update(dt: CGFloat, time t: Double, zoom z: CGFloat, originX: Double, height: (Double) -> Double) {
        let zz = max(z, 0.01)
        func step(_ level: inout CGFloat, on: Bool) {
            if on {
                level = min(1, level + dt / SceneLook.guideFadeIn)
            } else {
                level = max(0, level - dt / SceneLook.guideFadeOut)
            }
        }
        var ribbonOn = false, chevronOn = false, ringOn = false
        switch active {
        case .foldPath: ribbonOn = true
        case .openMark: chevronOn = true
        case .landing: ringOn = true
        case .none, .foldPathAhead, .openMarkAhead, .landingAhead: break
        }
        step(&ribbonLevel, on: ribbonOn)
        step(&chevronLevel, on: chevronOn)
        step(&ringLevel, on: ringOn)

        // The fold path: segments chained along the surface, brightest at the crest, with a shimmer running down.
        ribbon.isHidden = ribbonLevel <= 0.002 || path == nil
        if !ribbon.isHidden, let p = path {
            let n = segments.count
            let span = p.to - p.from
            for (k, s) in segments.enumerated() {
                let t0 = Double(k) / Double(n), t1 = Double(k + 1) / Double(n)
                let x0 = p.from + span * t0, x1 = p.from + span * t1
                let y0 = height(x0), y1 = height(x1)
                let dx = CGFloat(x1 - x0), dy = CGFloat(y1 - y0)
                s.position = CGPoint(x: CGFloat((x0 + x1) * 0.5 - originX), y: CGFloat((y0 + y1) * 0.5))
                s.zRotation = atan2(dy, dx)
                s.size = CGSize(width: hypot(dx, dy) + 1.5 / zz, height: SceneLook.foldPathWidth / zz)
                let along = CGFloat((t0 + t1) * 0.5)
                let wave = Double(along) * 1.5 - t / SceneLook.foldPathShimmer
                let shimmer = CGFloat(0.7 + 0.3 * sin(2 * Double.pi * wave))
                s.alpha = SceneLook.foldPathAlpha * (1 - along) * shimmer * ribbonLevel
            }
        }

        // The open mark over the trough.
        chevrons.isHidden = chevronLevel <= 0.002 || markX == nil
        if !chevrons.isHidden, let mx = markX {
            chevrons.position = CGPoint(x: CGFloat(mx - originX), y: CGFloat(height(mx)) + SceneLook.chevronLift / zz)
            chevrons.setScale(1 / zz)
            for (i, c) in chevronNodes.enumerated() {
                let ph = (t - SceneLook.chevronStagger * Double(i)) / (SceneLook.chevronStagger * 6)
                let pulse = CGFloat(0.5 + 0.5 * sin(2 * Double.pi * ph))
                c.alpha = SceneLook.chevronAlpha * (0.35 + 0.65 * pulse) * chevronLevel
            }
        }

        // The landing ring on the downslope, breathing at 1 Hz.
        ring.isHidden = ringLevel <= 0.002 || ringX == nil
        if !ring.isHidden, let rx = ringX {
            ring.position = CGPoint(x: CGFloat(rx - originX), y: CGFloat(height(rx)))
            ring.setScale(CGFloat(1 + 0.03 * sin(2 * Double.pi * t)) / zz)
            ring.alpha = ringLevel
        }
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
        // Climb to the next crest (or stay on it).
        while p < end && slope(p, height) > 0.002 { p += step }
        let crest = p
        // Then run down to the trough.
        while p < end && slope(p, height) <= 0.002 { p += step }
        guard p < end, p - crest > 40 else { return nil }
        return (crest, p)
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
            // The next downslope that starts ahead of the bird (skip the one it may be sliding down now).
            var from = birdX
            if let d = nextDownslope(after: birdX, height: height), d.from <= birdX + 8 { from = d.to + 8 }
            if let d = nextDownslope(after: from, height: height) { return .landing(at: d.from + (d.to - d.from) * 0.5) }
            return .none
        case .none, .foldPath, .openMark, .landing:
            return g
        }
    }
}
