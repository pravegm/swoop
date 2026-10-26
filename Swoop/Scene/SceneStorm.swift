import SpriteKit
import UIKit

/// The storm front chasing the bird (GAME-DESIGN §6, ART-DIRECTION §3), in canvas u-space (u = 0 at the behind edge).
///
/// R3 (ART-S6/S7):
/// - **The wall** is a shelf cloud, not stacked tyres: an anvil whose front lobes vary in size (0.6–1.4×, never
///   alternating). It is one static vector path, only moved and scaled.
/// - **Its fill** has three value bands: a dark top shelf, the body, and a rain-curtain base that feathers into the
///   far sea over 140 pt.
/// - **A crisp 3 pt sunlit rim** runs along the anvil's upper edge.
/// - **It sits behind the far sea**, so its base is never a hard rectangle.
/// - **The sky darkens before the sea:** a sky shade in the storm-top colour reaches 0.45 w past the edge (α 0.10 + 0.40
///   c, capped at 0.5 at the bird).
/// - **Under the wall:** soft-ended rain sheets, slanting rain, and a grey wash over the sea.
/// - **Lightning** comes more often and stronger as the gap closes; Reduce Motion gives a cloud glow only.
/// - **Caught:** the world goes 30 % grey (the far page takes only 60 % of it), and the rain covers both pages.
@MainActor
final class SceneStorm {
    /// In the backdrop, between the sky and the far sea (the scene adds it at z −16).
    let backRoot: SKNode
    /// Over the near sea, under the bird.
    let shadeRoot: SKNode
    /// Over everything.
    let frontRoot: SKNode
    var reduceMotion = false
    /// Thermal / Low Power: the share of the rain drops drawn (UX-D5).
    var rainScale: CGFloat = 1

    /// The anvil path's nominal height (base y = 0 … top y = this); the node is scaled to the wanted height.
    static let anvilHeight: CGFloat = 640
    /// The front lobes: (x, y) of each lobe's end and its bulge (× 38 pt), varied, never alternating.
    static let lobes: [(CGFloat, CGFloat, CGFloat)] = [(64, 490, 1.0), (18, 430, 0.7), (58, 352, 1.3), (30, 300, 0.6),
                                                       (70, 214, 1.4), (12, 150, 0.8), (46, 70, 1.1), (8, 0, 0.9)]

    private let skyShade: SKSpriteNode
    private let wall: SKShapeNode
    private let rim: SKShapeNode
    private let wallGlow: SKSpriteNode
    private let bolt: SKShapeNode
    private let boltHalo: SKShapeNode
    private let shade: SKSpriteNode
    private let flash: SKSpriteNode
    private let calm: SKSpriteNode
    private var sheets: [SKSpriteNode] = []
    private var drops: [SKSpriteNode] = []
    private var dropPos: [CGPoint] = []
    private var dropSpeed: [CGFloat] = []
    private var rng = SceneRNG(seed: 0x570B_33)
    private var clock: Double = 0
    private var nextStrike: Double = 2.5
    private var flashLevel: CGFloat = 0
    private var glowLevel: CGFloat = 0
    private var boltLife: CGFloat = 0
    private var edge: CGFloat = -1000
    private var wallTop: CGFloat = 600
    private var lead: CGFloat = 1
    private var rimScale: CGFloat = 0
    private var canvas = CGSize(width: 952, height: 670)
    private var horizon: CGFloat = 300
    /// How many strikes have flashed (tests, tuning).
    private(set) var strikeCount = 0
    /// The wall's front edge (u-space) this frame, and the sky shade's alpha at the bird (tests).
    private(set) var edgeU: CGFloat = 0
    private(set) var skyShadeAtBird: CGFloat = 0

    init() {
        backRoot = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
        skyShade = SKSpriteNode(color: .clear, size: CGSize(width: 600, height: 670))
        wall = SKShapeNode()
        rim = SKShapeNode()
        wallGlow = SKSpriteNode(texture: SceneTextures.glow)
        bolt = SKShapeNode()
        boltHalo = SKShapeNode()
        shade = SKSpriteNode(color: .clear, size: CGSize(width: 1800, height: 670))
        flash = SKSpriteNode(color: .white, size: CGSize(width: 952, height: 670))
        calm = SKSpriteNode(color: .clear, size: CGSize(width: 952, height: 670))

        skyShade.anchorPoint = .zero
        skyShade.zPosition = 0.1
        wall.path = SceneStorm.anvilPath()
        wall.lineWidth = 0
        wall.strokeColor = .clear
        wall.fillColor = .white
        wall.isAntialiased = true
        wall.zPosition = 0.5
        rim.path = SceneStorm.rimPath()
        rim.fillColor = .clear
        rim.lineCap = .round
        rim.lineJoin = .round
        rim.zPosition = 0.6
        wallGlow.blendMode = .add
        wallGlow.colorBlendFactor = 1
        wallGlow.color = UIColor(red: 0.78, green: 0.84, blue: 1.0, alpha: 1)
        wallGlow.zPosition = 1
        wallGlow.isHidden = true
        for b in [boltHalo, bolt] {
            b.fillColor = .clear
            b.lineCap = .round
            b.lineJoin = .round
            b.isHidden = true
        }
        boltHalo.strokeColor = UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 0.32)
        boltHalo.lineWidth = 8
        boltHalo.zPosition = 1.4
        bolt.strokeColor = UIColor(white: 1, alpha: 0.95)
        bolt.lineWidth = 2.4
        bolt.zPosition = 1.5
        for n in [skyShade, wall, rim, wallGlow, boltHalo, bolt] as [SKNode] { backRoot.addChild(n) }

        shade.anchorPoint = CGPoint(x: 1, y: 0)
        shade.zPosition = 0
        shadeRoot.addChild(shade)
        let sheetTexture = SceneTextures.rainSheet
        for _ in 0..<SceneLook.rainSheetCount {
            let s = SKSpriteNode(texture: sheetTexture)
            s.anchorPoint = CGPoint(x: 0.5, y: 1)
            s.colorBlendFactor = 1
            s.zRotation = 0.2
            s.zPosition = 0.5
            shadeRoot.addChild(s)
            sheets.append(s)
        }

        flash.anchorPoint = .zero
        flash.blendMode = .add
        flash.alpha = 0
        flash.isHidden = true
        flash.zPosition = 2
        calm.anchorPoint = .zero
        calm.alpha = 0
        calm.isHidden = true
        calm.zPosition = 1
        frontRoot.addChild(calm)
        frontRoot.addChild(flash)

        let streak = SceneTextures.streak
        let angle = atan2(-SceneLook.rainVY, SceneLook.rainVX)
        for _ in 0..<SceneLook.rainCount {
            let s = SKSpriteNode(texture: streak, size: CGSize(width: 38, height: 2.2))
            s.zRotation = angle
            s.colorBlendFactor = 1
            s.isHidden = true
            s.zPosition = 0
            frontRoot.addChild(s)
            drops.append(s)
            dropPos.append(CGPoint(x: rng.range(0, 952), y: rng.range(0, 700)))
            dropSpeed.append(rng.range(0.8, 1.25))
        }
    }

    // MARK: The anvil

    /// The cloud wall (front edge near x = 0, base y = 0): solid far to the left, an anvil top overhanging ahead, and a
    /// shelf of varied lobes down to (and below) the horizon.
    static func anvilPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -4000, y: -300))
        p.addLine(to: CGPoint(x: -4000, y: 640))
        p.addLine(to: CGPoint(x: -320, y: 640))
        addAnvilTop(p)
        var prev = CGPoint(x: 42, y: 546)
        for lobe in lobes {
            let q = CGPoint(x: lobe.0, y: lobe.1)
            let control = CGPoint(x: max(prev.x, q.x) + 38 * lobe.2, y: (prev.y + q.y) * 0.5)
            p.addQuadCurve(to: q, control: control)
            prev = q
        }
        p.addLine(to: CGPoint(x: 8, y: -300))
        p.closeSubpath()
        return p
    }

    /// The sunlit rim: the anvil's upper edge only (the top shelf and its tip).
    static func rimPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -320, y: 640))
        p.addQuadCurve(to: CGPoint(x: 140, y: 612), control: CGPoint(x: -60, y: 664))
        p.addQuadCurve(to: CGPoint(x: 172, y: 586), control: CGPoint(x: 178, y: 602))
        return p
    }

    private static func addAnvilTop(_ p: CGMutablePath) {
        p.addQuadCurve(to: CGPoint(x: 140, y: 612), control: CGPoint(x: -60, y: 664))
        p.addQuadCurve(to: CGPoint(x: 172, y: 586), control: CGPoint(x: 178, y: 602))
        p.addQuadCurve(to: CGPoint(x: 42, y: 546), control: CGPoint(x: 112, y: 560))
    }

    // MARK: Cosmetics

    func apply(palette p: ScenePalette, sky id: SkyID) {
        // Over the path's box (y 664 … −300): the top shelf, the body, the rain-curtain base fading out over the last
        // 140 pt above the horizon (y = 0 sits at 0.69).
        let top = ScenePaint.ui(p.stormTop)
        let body = ScenePaint.ui(p.stormBody)
        let rain = ScenePaint.ui(p.rain)
        wall.fillTexture = SceneTextures.verticalGradient(
            key: "anvil3-\(id.rawValue)",
            colors: [top, top, body, body, rain.withAlphaComponent(0.35), rain.withAlphaComponent(0.2),
                     rain.withAlphaComponent(0), rain.withAlphaComponent(0)],
            locations: [0, 0.12, 0.30, 0.52, 0.62, 0.69, 0.76, 1])
        rim.strokeColor = ScenePaint.ui(p.stormRim, alpha: 0.95)
        skyShade.texture = SceneTextures.horizontalGradient(
            key: "skyshade-\(id.rawValue)", colors: [top, top.withAlphaComponent(0.7), top.withAlphaComponent(0)],
            locations: [0, 0.5, 1])
        skyShade.color = .white
        skyShade.colorBlendFactor = 0
        let wash = ScenePaint.ui(p.stormBody)
        shade.texture = SceneTextures.horizontalGradient(
            key: "stormshade3-\(id.rawValue)",
            colors: [wash, wash, wash.withAlphaComponent(0.55), wash.withAlphaComponent(0)], locations: [0, 0.72, 0.88, 1])
        shade.color = .white
        shade.colorBlendFactor = 0
        for s in sheets { s.color = rain }
        // A neutral grey of the horizon's brightness; over the world at 30 % it reads as desaturated. The far page
        // takes 60 % of it.
        let lum = ScenePaint.luminance(p.low)
        let grey = UIColor(white: CGFloat(lum), alpha: 1)
        calm.texture = SceneTextures.horizontalGradient(
            key: "calm-\(id.rawValue)",
            colors: [grey, grey.withAlphaComponent(SceneLook.caughtWashFarPage)], locations: [0, 1])
        calm.color = .white
        calm.colorBlendFactor = 0
        for d in drops { d.color = rain }
    }

    func clear() {
        flashLevel = 0
        glowLevel = 0
        boltLife = 0
        bolt.isHidden = true
        boltHalo.isHidden = true
        flash.isHidden = true
        wallGlow.isHidden = true
        nextStrike = clock + 2.5
    }

    // MARK: Frame

    /// `edgeU`: the cloud edge (u-space). `closeness` 0 (far) … 1 (on the bird) scales the wall's height, darkness and
    /// rain. `lead` 0…1 (Core's lead meter). `caughtness` 0…1 eases in the caught ending. `birdU`: the bird's u, for
    /// the sky shade's cap. `visibleTop`: the top of the visible rect (iPhones crop the canvas).
    func update(edgeU e: CGFloat, closeness: CGFloat, lead: CGFloat, caughtness: CGFloat, size: CGSize, minY: CGFloat,
                maxY: CGFloat, horizonY: CGFloat, birdU: CGFloat, dt: CGFloat) {
        clock += Double(dt)
        let c = min(max(max(closeness, caughtness), 0), 1)
        edge = e
        edgeU = e
        self.lead = min(max(lead, 0), 1)
        canvas = size
        horizon = horizonY

        // The wall: its base at the horizon (the far sea covers it), its height a fraction of the *visible* sky.
        let baseY = horizonY - 10
        let heightFraction = SceneLook.stormHeightFar + (SceneLook.stormHeightNear - SceneLook.stormHeightFar) * c
        let wallH = max(heightFraction * (maxY - baseY), 80)
        let s = wallH / SceneStorm.anvilHeight
        wall.position = CGPoint(x: e, y: baseY)
        wall.setScale(s)
        rim.position = wall.position
        rim.setScale(s)
        if rimScale <= 0 || abs(s / rimScale - 1) > 0.05 {
            rimScale = s
            rim.lineWidth = SceneLook.stormRimWidth / max(s, 0.05)
        }
        wall.alpha = SceneLook.stormAlphaFar + (SceneLook.stormAlphaNear - SceneLook.stormAlphaFar) * c
        rim.alpha = 0.5 + 0.5 * c
        wallTop = baseY + wallH

        // The sky shade: the sky darkens before the sea does; never more than 0.5 at the bird.
        let reach = max(e + SceneLook.skyShadeReach * size.width, 10)
        skyShade.position = .zero
        skyShade.size = CGSize(width: reach, height: size.height)
        var shadeAlpha = SceneLook.skyShadeBase + SceneLook.skyShadeClose * c
        let atBird = max(0, 1 - birdU / reach)
        if shadeAlpha * atBird > SceneLook.skyShadeCapAtBird { shadeAlpha = SceneLook.skyShadeCapAtBird / atBird }
        skyShade.alpha = shadeAlpha
        skyShadeAtBird = shadeAlpha * atBird

        // The grey wash over the sea under it.
        shade.position = CGPoint(x: e + SceneLook.stormShadeReach, y: 0)
        shade.size = CGSize(width: 1800, height: size.height)
        shade.alpha = SceneLook.stormShadeFar + (SceneLook.stormShadeNear - SceneLook.stormShadeFar) * c

        // Rain sheets hanging from the cloud's lower half down past the bottom of the screen.
        let sheetTop = baseY + wallH * 0.45
        let sheetLength = max(sheetTop - minY + 40, 40)
        let sheetAlpha = (0.14 + 0.36 * c) * (1 + 0.4 * caughtness)
        for (i, sheet) in sheets.enumerated() {
            let fi = CGFloat(i)
            sheet.position = CGPoint(x: e - 30 - fi * 120 * max(s, 0.5), y: sheetTop)
            sheet.size = CGSize(width: 70 + 50 * s, height: sheetLength)
            let flicker = CGFloat(0.85 + 0.15 * sin(clock * (1.3 + 0.4 * Double(i)) + Double(i)))
            sheet.alpha = sheetAlpha * flicker
        }

        // Rain: under the cloud, onto the left half once the storm is close, everywhere when caught.
        let closeK = min(max(1 - self.lead / 0.2, 0), 1)
        var rainEdge = max(e + 50, closeK * size.width * 0.5)
        rainEdge += (size.width + 80 - rainEdge) * caughtness
        let rainAlpha = (0.18 + 0.2 * c + 0.25 * closeK) * (1 - 0.3 * caughtness)
        let raining = rainAlpha > 0.01 && rainEdge > -40
        let spawnTop = caughtness > 0.3 ? maxY + 160 : min(wallTop, maxY + 60)
        let spawnLow = min(spawnTop - 10, baseY + wallH * 0.5)
        let shown = Int(CGFloat(drops.count) * min(max(rainScale, 0), 1))
        for i in 0..<drops.count {
            var p = dropPos[i]
            if dt > 0 {
                p.x += SceneLook.rainVX * dropSpeed[i] * dt
                p.y -= SceneLook.rainVY * dropSpeed[i] * dt
                if p.y < minY - 30 || p.x > rainEdge + 30 {
                    p = CGPoint(x: rng.range(-60, max(rainEdge, -59)), y: rng.range(spawnLow, spawnTop))
                }
                dropPos[i] = p
            }
            let d = drops[i]
            let on = raining && i < shown && p.x < rainEdge
            d.isHidden = !on
            if on {
                d.position = p
                d.alpha = rainAlpha
            }
        }

        // Lightning, while the run is still on (the one light allowed on the left page, ≤ 120 ms).
        if dt > 0 && c > 0.25 && caughtness < 0.5 && clock >= nextStrike {
            strike(strength: 0.45 + 0.55 * (1 - self.lead))
        }
        flashLevel = max(0, flashLevel - dt * 8.5)
        glowLevel = max(0, glowLevel - dt * (reduceMotion ? 1.0 : 2.4))
        boltLife = max(0, boltLife - dt)
        flash.isHidden = flashLevel <= 0.001
        if !flash.isHidden {
            flash.size = CGSize(width: size.width + 4, height: size.height + 4)
            flash.position = CGPoint(x: -2, y: -2)
            flash.alpha = flashLevel * SceneLook.flashPeak
        }
        wallGlow.isHidden = glowLevel <= 0.001
        if !wallGlow.isHidden {
            wallGlow.position = CGPoint(x: e - 160 * max(s, 0.6), y: baseY + wallH * 0.6)
            wallGlow.size = CGSize(width: 720 * max(s, 0.6), height: 720 * max(s, 0.6))
            wallGlow.alpha = glowLevel * 0.75
        }
        let boltOn = boltLife > 0
        bolt.isHidden = !boltOn
        boltHalo.isHidden = !boltOn
        if boltOn {
            let k = min(1, boltLife / 0.12)
            bolt.alpha = k
            boltHalo.alpha = k
        }

        calm.isHidden = caughtness < 0.01
        if !calm.isHidden {
            calm.size = CGSize(width: size.width + 4, height: size.height + 4)
            calm.position = CGPoint(x: -2, y: -2)
            calm.alpha = caughtness * SceneLook.caughtWashAlpha
        }
    }

    /// A lightning strike now (also on `stormClose`). Reduce Motion: no flash or bolt, only a glow in the cloud.
    func strike(strength: CGFloat) {
        let interval = Double(rng.range(SceneLook.strikeIntervalMin, SceneLook.strikeIntervalMax))
        // Never more than 2 flashes a second (ART §5).
        nextStrike = clock + max(0.5, interval * Double(0.35 + 0.65 * lead))
        strikeCount += 1
        let st = min(max(strength, 0.2), 1)
        glowLevel = max(glowLevel, reduceMotion ? 0.55 * st : st)
        if reduceMotion { return }
        flashLevel = st
        guard edge > 60 else { return }
        let lo = max(12, edge - 320), hi = edge - 30
        guard hi > lo else { return }
        var x = rng.range(lo, hi)
        let top = min(wallTop - 20, canvas.height + 10)
        var y = top
        let bottom = horizon + rng.range(10, 60)
        guard top > bottom + 40 else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        let segments = 9
        var branchAt = CGPoint.zero
        for i in 1...segments {
            y = top - (top - bottom) * CGFloat(i) / CGFloat(segments)
            x += rng.range(-22, 16)
            path.addLine(to: CGPoint(x: x, y: y))
            if i == 4 { branchAt = CGPoint(x: x, y: y) }
        }
        path.move(to: branchAt)
        path.addLine(to: CGPoint(x: branchAt.x + rng.range(18, 40), y: branchAt.y - rng.range(40, 80)))
        path.addLine(to: CGPoint(x: branchAt.x + rng.range(30, 60), y: branchAt.y - rng.range(90, 140)))
        bolt.path = path
        boltHalo.path = path
        boltLife = 0.12
    }
}
