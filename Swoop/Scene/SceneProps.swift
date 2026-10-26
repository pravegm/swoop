import SpriteKit
import UIKit

/// Props: the lighthouse on its rock (beam turning, a bright sweep when passed), the personal-best buoy with its
/// pennant, and the touchable cloud band at Core's cloud height.
///
/// The buoy and the clouds are world-local. The lighthouse (R2, REVIEW-1 P0-7) stands on the far swells in u-space,
/// a parallax depth layer placed by the scene, so it is on screen beside the bird at the moment of the pass.
@MainActor
final class SceneProps {
    /// In the backdrop, between the two far swell layers (u-space).
    let lighthouseRoot: SKNode
    /// Behind the sea fill, so the waterline cuts across the float.
    let buoyRoot: SKNode
    /// The cloud band high above the water.
    let cloudRoot: SKNode

    private let rock: SKShapeNode
    private let rockRim: SKShapeNode
    private let beam: SKSpriteNode
    private let lamp: SKSpriteNode
    private let pennant: SKShapeNode
    private var clouds: [SKSpriteNode] = []
    private var beamPhase: CGFloat = 0
    private var quiet: CGFloat = 0
    private var cheer: CGFloat = 0

    var lighthouseShown: Bool { !lighthouseRoot.isHidden }
    /// The lamp's centre in u-space this frame (the reached beam starts here).
    var lampPoint: CGPoint {
        CGPoint(x: lighthouseRoot.position.x, y: lighthouseRoot.position.y + 131 * lighthouseRoot.yScale)
    }
    /// The tower's current scale (the reached moment sizes its lamp flare to it).
    var lighthouseScale: CGFloat { lighthouseRoot.yScale }
    var buoyShown: Bool { !buoyRoot.isHidden }

    init() {
        lighthouseRoot = SKNode()
        buoyRoot = SKNode()
        cloudRoot = SKNode()
        rock = SKShapeNode()
        rockRim = SKShapeNode()
        beam = SKSpriteNode(texture: SceneTextures.beam)
        lamp = SKSpriteNode(texture: SceneTextures.glow)
        pennant = SKShapeNode()

        // The rock: a sea stack, its top at y = 0, reaching well below any trough.
        let rp = CGMutablePath()
        let rockPts: [CGPoint] = [CGPoint(x: -100, y: -320), CGPoint(x: -92, y: -60), CGPoint(x: -74, y: -16),
                                  CGPoint(x: -44, y: 2), CGPoint(x: -14, y: 9), CGPoint(x: 18, y: 7),
                                  CGPoint(x: 48, y: -1), CGPoint(x: 74, y: -16), CGPoint(x: 94, y: -54),
                                  CGPoint(x: 104, y: -320)]
        rp.addLines(between: rockPts)
        rp.closeSubpath()
        rock.path = rp
        rock.lineWidth = 0
        rock.zPosition = 0
        let rim = CGMutablePath()
        rim.addLines(between: Array(rockPts[1...8]))
        rockRim.path = rim
        rockRim.fillColor = .clear
        rockRim.lineWidth = 2.5
        rockRim.lineCap = .round
        rockRim.zPosition = 0.1
        lighthouseRoot.addChild(rock)
        lighthouseRoot.addChild(rockRim)

        // The tower (R6, ART-FLIGHT-SCHOOL §3): off-white #F4F1EA with exactly two warm-red bands #D8574A, the same
        // object as the App's lighthouse icon; a dark gallery, the lamp room and a dark cap (no third red stripe).
        let white = ScenePaint.ui(SceneLook.lighthouseWhite)
        let red = ScenePaint.ui(SceneLook.lighthouseRed)
        let dark = UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1)
        let buoyRed = UIColor(red: 0.78, green: 0.22, blue: 0.20, alpha: 1)
        func taper(_ y0: CGFloat, _ y1: CGFloat) -> CGPath {
            let w0 = 17 - 5 * (y0 / 118), w1 = 17 - 5 * (y1 / 118)
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -w0, y: y0), CGPoint(x: w0, y: y0), CGPoint(x: w1, y: y1),
                                 CGPoint(x: -w1, y: y1)])
            p.closeSubpath()
            return p
        }
        let parts: [(CGPath, UIColor, CGFloat)] = [
            (taper(4, 118), white, 1), (taper(30, 48), red, 1.1), (taper(76, 94), red, 1.1),
            (CGPath(rect: CGRect(x: -17, y: 118, width: 34, height: 5), transform: nil), dark, 1.2),
            (CGPath(rect: CGRect(x: -9, y: 123, width: 18, height: 16), transform: nil),
             UIColor(red: 1.0, green: 0.87, blue: 0.52, alpha: 1), 1.2),
        ]
        for (path, color, z) in parts {
            let n = SKShapeNode(path: path)
            n.fillColor = color
            n.strokeColor = .clear
            n.lineWidth = 0
            n.zPosition = z
            lighthouseRoot.addChild(n)
        }
        let roof = CGMutablePath()
        roof.addLines(between: [CGPoint(x: -13, y: 139), CGPoint(x: 13, y: 139), CGPoint(x: 0, y: 157)])
        roof.closeSubpath()
        let roofNode = SKShapeNode(path: roof)
        roofNode.fillColor = dark
        roofNode.strokeColor = .clear
        roofNode.zPosition = 1.2
        lighthouseRoot.addChild(roofNode)
        // Shade on the behind side of the tower (the light comes from the sun ahead).
        let shadePath = CGMutablePath()
        shadePath.addLines(between: [CGPoint(x: -17, y: 4), CGPoint(x: -6, y: 4), CGPoint(x: -4, y: 118),
                                     CGPoint(x: -12, y: 118)])
        shadePath.closeSubpath()
        let shadeNode = SKShapeNode(path: shadePath)
        shadeNode.fillColor = UIColor(white: 0, alpha: 0.20)
        shadeNode.strokeColor = .clear
        shadeNode.zPosition = 1.3
        lighthouseRoot.addChild(shadeNode)
        // Two-tone shading (ART-S13): the sun-facing side ahead +15 %.
        let litPath = CGMutablePath()
        litPath.addLines(between: [CGPoint(x: 5, y: 4), CGPoint(x: 17, y: 4), CGPoint(x: 12, y: 118),
                                   CGPoint(x: 4, y: 118)])
        litPath.closeSubpath()
        let litNode = SKShapeNode(path: litPath)
        litNode.fillColor = UIColor(white: 1, alpha: 0.15)
        litNode.strokeColor = .clear
        litNode.zPosition = 1.3
        lighthouseRoot.addChild(litNode)
        // A foam ring where the rock meets the far sea (drawn over the far-front layer).
        let foamRing = SKShapeNode(ellipseOf: CGSize(width: 214, height: 12))
        foamRing.fillColor = .clear
        foamRing.strokeColor = UIColor(white: 1, alpha: 0.55)
        foamRing.lineWidth = 2
        foamRing.position = CGPoint(x: 2, y: -4)
        foamRing.zPosition = 0.9
        lighthouseRoot.addChild(foamRing)

        lamp.blendMode = .add
        lamp.colorBlendFactor = 1
        lamp.color = UIColor(red: 1.0, green: 0.86, blue: 0.55, alpha: 1)
        lamp.size = CGSize(width: SceneLook.lampGlowSize, height: SceneLook.lampGlowSize)
        lamp.position = CGPoint(x: 0, y: 131)
        lamp.zPosition = 2
        lighthouseRoot.addChild(lamp)
        beam.anchorPoint = CGPoint(x: 0, y: 0.5)
        beam.blendMode = .add
        beam.colorBlendFactor = 1
        beam.color = UIColor(red: 1.0, green: 0.92, blue: 0.70, alpha: 1)
        beam.size = CGSize(width: 520, height: 64)
        beam.position = CGPoint(x: 0, y: 131)
        beam.zPosition = 1.9
        lighthouseRoot.addChild(beam)
        lighthouseRoot.isHidden = true

        // The buoy: a red float with a white band, a pole and a gold pennant. y = 0 is the waterline.
        let floatNode = SKShapeNode(ellipseOf: CGSize(width: 20, height: 16))
        floatNode.fillColor = buoyRed
        floatNode.strokeColor = UIColor(white: 0, alpha: 0.25)
        floatNode.lineWidth = 1
        floatNode.position = CGPoint(x: 0, y: 1)
        buoyRoot.addChild(floatNode)
        let band = SKShapeNode(rect: CGRect(x: -9, y: 2, width: 18, height: 3.5))
        band.fillColor = white
        band.strokeColor = .clear
        band.zPosition = 0.1
        buoyRoot.addChild(band)
        let pole = SKShapeNode(rect: CGRect(x: -1, y: 8, width: 2, height: 32))
        pole.fillColor = dark
        pole.strokeColor = .clear
        buoyRoot.addChild(pole)
        let pp = CGMutablePath()
        pp.addLines(between: [CGPoint(x: 0, y: 40), CGPoint(x: 20, y: 35), CGPoint(x: 0, y: 29)])
        pp.closeSubpath()
        pennant.path = pp
        pennant.fillColor = ScenePaint.ui(ScenePaint.gold)
        pennant.strokeColor = .clear
        pennant.position = CGPoint(x: 1, y: 0)
        pennant.zPosition = 0.2
        buoyRoot.addChild(pennant)
        buoyRoot.isHidden = true

        for _ in 0..<8 {
            let c = SKSpriteNode(texture: SceneTextures.cloudStreak)
            c.colorBlendFactor = 1
            cloudRoot.addChild(c)
            clouds.append(c)
        }
    }

    func apply(palette p: ScenePalette) {
        // The rock sits between the two far layers in value (ART §3), its sun-facing rim lit.
        let stone = p.farFront.mixed(with: p.nearDeep, 0.55)
        rock.fillColor = ScenePaint.ui(stone)
        rock.strokeColor = .clear
        rockRim.strokeColor = ScenePaint.ui(p.horizon, alpha: 0.7)
        let tint = ScenePaint.ui(p.cloud)
        for c in clouds { c.color = tint }
    }

    func reset() {
        quiet = 0
        cheer = 0
        lighthouseRoot.isHidden = true
        buoyRoot.isHidden = true
    }

    /// The lighthouse was reached: the turning beam goes quiet for `seconds` while the reached moment's own wide beam
    /// sweeps the sea page (ART-FLIGHT-SCHOOL §4), then fades back.
    func quietBeam(for seconds: CGFloat) {
        quiet = max(quiet, seconds)
        beamPhase = 0
    }

    /// The personal best was beaten: the pennant flutters.
    func cheerBuoy() { cheer = 1 }

    /// `p`: the rock top in u-space; `scale`: the depth layer's scale; `alpha`: the far tower fades in from 1.5 km.
    func showLighthouse(at p: CGPoint, scale: CGFloat, alpha: CGFloat = 1, dt: CGFloat) {
        lighthouseRoot.isHidden = false
        lighthouseRoot.position = p
        lighthouseRoot.setScale(scale)
        lighthouseRoot.alpha = min(max(alpha, 0), 1)
        quiet = max(0, quiet - dt)
        let calmK = min(quiet / 0.4, 1)
        beamPhase += dt * SceneLook.beamSpeed
        let c = cos(beamPhase)
        // The beam turns about the tower: long to one side, foreshortened as it faces us (the lamp flares), the other.
        // A soft cone, α ≤ 0.25 (out while the reached beam sweeps).
        beam.xScale = c
        let facing = pow(1 - abs(c), 4)
        beam.alpha = SceneLook.beamAlpha * (0.4 + 0.6 * abs(c)) * (1 - calmK)
        lamp.alpha = min(1, 0.6 + 0.4 * facing + 0.4 * calmK)
        lamp.setScale(1 + 0.6 * facing + 0.4 * calmK)
    }

    func hideLighthouse() { lighthouseRoot.isHidden = true }

    func showBuoy(at p: CGPoint, slope: CGFloat, zoom z: CGFloat, time t: Double, dt: CGFloat) {
        buoyRoot.isHidden = false
        buoyRoot.position = p
        buoyRoot.zRotation = atan(slope) * 0.8 + CGFloat(0.08 * sin(t * 1.9))
        buoyRoot.setScale(SceneLook.buoyScale * pow(z, -0.4))
        pennant.xScale = CGFloat(0.82 + 0.18 * sin(t * 7.0)) + cheer * CGFloat(0.3 * sin(t * 15.0))
        cheer = max(0, cheer - dt * 0.5)
    }

    func hideBuoy() { buoyRoot.isHidden = true }

    /// Recycles the band's clouds around the bird (stable per cell, so they never pop). The clouds overlap, and their
    /// bottoms sit `cloudBandDrop` under Core's cloud height, so a `cloudTouched` always happens inside a cloud.
    func updateClouds(birdX: Double, originX: Double) {
        let cell = SceneLook.nearCloudSpacing
        let base = Int((birdX / cell).rounded(.down))
        let bottom = CGFloat(Tuning.cloudHeight) - SceneLook.cloudBandDrop
        for (i, c) in clouds.enumerated() {
            let ci = base + i - 2
            let h1 = SceneRNG.hash(ci, 5)
            let h2 = SceneRNG.hash(ci, 9)
            let h3 = SceneRNG.hash(ci, 17)
            let seaX = (Double(ci) + 0.6 * Double(h1)) * cell
            // Long, flat-bottomed lit banks (no puffballs), overlapping, their undersides at the band's bottom.
            let height = 120 + 50 * h2
            c.size = CGSize(width: 700 + 260 * h3, height: height)
            c.position = CGPoint(x: CGFloat(seaX - originX), y: bottom + height * 0.40 + 24 * h1)
            c.alpha = 0.5 + 0.2 * h3
        }
    }
}
