import SpriteKit
import UIKit

/// World props: the lighthouse on its rock (beam turning, a bright sweep when passed), the personal-best buoy with its
/// pennant, and the touchable cloud band at cloud height. World-local coordinates.
@MainActor
final class SceneProps {
    /// Behind the sea (its rock rises out of the water).
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
    private var sweep: CGFloat = 0
    private var cheer: CGFloat = 0

    /// World-local lamp position (for sparkles), valid while the lighthouse is shown.
    var lampPoint: CGPoint {
        CGPoint(x: lighthouseRoot.position.x, y: lighthouseRoot.position.y + 131 * SceneLook.lighthouseScale)
    }

    var lighthouseShown: Bool { !lighthouseRoot.isHidden }
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

        // The tower: white with two red bands, a gallery, the lamp room and a red cap.
        let white = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
        let red = UIColor(red: 0.78, green: 0.22, blue: 0.20, alpha: 1)
        let dark = UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1)
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
        roofNode.fillColor = red
        roofNode.strokeColor = .clear
        roofNode.zPosition = 1.2
        lighthouseRoot.addChild(roofNode)
        // Shade on the behind side of the tower (the light comes from the sun ahead).
        let shadePath = CGMutablePath()
        shadePath.addLines(between: [CGPoint(x: -17, y: 4), CGPoint(x: -6, y: 4), CGPoint(x: -4, y: 118),
                                     CGPoint(x: -12, y: 118)])
        shadePath.closeSubpath()
        let shadeNode = SKShapeNode(path: shadePath)
        shadeNode.fillColor = UIColor(white: 0, alpha: 0.16)
        shadeNode.strokeColor = .clear
        shadeNode.zPosition = 1.3
        lighthouseRoot.addChild(shadeNode)

        lamp.blendMode = .add
        lamp.colorBlendFactor = 1
        lamp.color = UIColor(red: 1.0, green: 0.86, blue: 0.55, alpha: 1)
        lamp.size = CGSize(width: 120, height: 120)
        lamp.position = CGPoint(x: 0, y: 131)
        lamp.zPosition = 2
        lighthouseRoot.addChild(lamp)
        beam.anchorPoint = CGPoint(x: 0, y: 0.5)
        beam.blendMode = .add
        beam.colorBlendFactor = 1
        beam.color = UIColor(red: 1.0, green: 0.92, blue: 0.70, alpha: 1)
        beam.size = CGSize(width: 560, height: 70)
        beam.position = CGPoint(x: 0, y: 131)
        beam.zPosition = 1.9
        lighthouseRoot.addChild(beam)
        lighthouseRoot.isHidden = true

        // The buoy: a red float with a white band, a pole and a gold pennant. y = 0 is the waterline.
        let floatNode = SKShapeNode(ellipseOf: CGSize(width: 20, height: 16))
        floatNode.fillColor = red
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

        for _ in 0..<5 {
            let c = SKSpriteNode(texture: SceneTextures.cloud)
            c.colorBlendFactor = 1
            cloudRoot.addChild(c)
            clouds.append(c)
        }
    }

    func apply(sky: Sky) {
        let stone = ScenePaint.darker(sky.seaFar.mixed(with: sky.storm, 0.35), 0.45)
        rock.fillColor = ScenePaint.ui(stone)
        rock.strokeColor = .clear
        rockRim.strokeColor = ScenePaint.ui(ScenePaint.lighter(stone, 0.25).mixed(with: sky.sun, 0.2), alpha: 0.8)
        let tint = ScenePaint.ui(sky.horizon.mixed(with: ScenePaint.white, 0.62).mixed(with: sky.zenith, 0.08))
        for c in clouds { c.color = tint }
    }

    func reset() {
        sweep = 0
        cheer = 0
        lighthouseRoot.isHidden = true
        buoyRoot.isHidden = true
    }

    /// The lighthouse was passed: a bright, faster sweep.
    func sweepBeam() { sweep = 1 }

    /// The personal best was beaten: the pennant flutters.
    func cheerBuoy() { cheer = 1 }

    func showLighthouse(at p: CGPoint, dt: CGFloat) {
        lighthouseRoot.isHidden = false
        lighthouseRoot.position = p
        lighthouseRoot.setScale(SceneLook.lighthouseScale)
        beamPhase += dt * (SceneLook.beamSpeed + 3.2 * sweep)
        let c = cos(beamPhase)
        // The beam turns about the tower: long to one side, foreshortened as it faces us (the lamp flares), the other.
        beam.xScale = c
        let facing = pow(1 - abs(c), 4)
        beam.alpha = (0.18 + 0.55 * sweep) * (0.3 + 0.7 * abs(c))
        lamp.alpha = min(1, 0.55 + 0.45 * facing + 0.3 * sweep)
        lamp.setScale(1 + 0.5 * facing + 0.6 * sweep)
        sweep = max(0, sweep - dt * 0.4)
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

    /// Recycles the band's clouds around the bird (stable per cell, so they never pop).
    func updateClouds(birdX: Double, originX: Double) {
        let cell = SceneLook.nearCloudSpacing
        let base = Int((birdX / cell).rounded(.down))
        for (i, c) in clouds.enumerated() {
            let ci = base + i - 1
            let h1 = SceneRNG.hash(ci, 5)
            let h2 = SceneRNG.hash(ci, 9)
            let h3 = SceneRNG.hash(ci, 17)
            let seaX = (Double(ci) + 0.6 * Double(h1)) * cell
            c.position = CGPoint(x: CGFloat(seaX - originX), y: SceneLook.nearCloudHeight + h2 * 160)
            c.size = CGSize(width: 560 + 260 * h3, height: 170 + 60 * h2)
            c.alpha = 0.6 + 0.2 * h3
        }
    }
}
