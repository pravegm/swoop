import SpriteKit
import UIKit

/// The storm front chasing the bird (GAME-DESIGN §6), in canvas u-space (u = 0 at the behind edge).
///
/// R2 (REVIEW-1 P1-6): the storm is always on screen. A crisp vector anvil (one static path, only moved and scaled,
/// never rebuilt) stands at the behind edge: a low, hazy band far away that grows into a towering slate wall with a
/// lit rim as the gap closes. Under it: rain sheets, slanting rain, and a grey wash over the sea. Lightning (bolt,
/// flash, cloud glow) comes more often and stronger as the gap closes; Reduce Motion gives the glow only. When the bird
/// is caught the rain sweeps softly over the whole canvas and a calm grey wash settles (the scene also dims the sun).
@MainActor
final class SceneStorm {
    /// Behind the near sea (with the backdrop).
    let backRoot: SKNode
    /// Over the near sea, under the bird.
    let shadeRoot: SKNode
    /// Over everything.
    let frontRoot: SKNode
    var reduceMotion = false

    /// The anvil path's nominal height (base y = 0 … top y = this); the node is scaled to the wanted height.
    static let anvilHeight: CGFloat = 640

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
    /// The wall's fill tint far (hazy, toward the horizon) → near (its own colour), in 21 steps (cached per sky).
    private var tints: [UIColor] = []
    private var tintIndex = -1
    private var rng = SceneRNG(seed: 0x570B_33)
    private var clock: Double = 0
    private var nextStrike: Double = 2.5
    private var flashLevel: CGFloat = 0
    private var glowLevel: CGFloat = 0
    private var boltLife: CGFloat = 0
    private var edge: CGFloat = -1000
    private var wallTop: CGFloat = 600
    private var lead: CGFloat = 1
    private var canvas = CGSize(width: 952, height: 670)
    private var horizon: CGFloat = 300
    /// How many strikes have flashed (tests, tuning).
    private(set) var strikeCount = 0
    /// The wall's current front edge and top (u-space, canvas y), for tests and framing checks.
    private(set) var wallFrame = CGRect.zero

    init() {
        backRoot = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
        wall = SKShapeNode()
        rim = SKShapeNode()
        wallGlow = SKSpriteNode(texture: SceneTextures.glow)
        bolt = SKShapeNode()
        boltHalo = SKShapeNode()
        shade = SKSpriteNode(color: .clear, size: CGSize(width: 1800, height: 670))
        flash = SKSpriteNode(color: .white, size: CGSize(width: 952, height: 670))
        calm = SKSpriteNode(color: .darkGray, size: CGSize(width: 952, height: 670))

        wall.path = SceneStorm.anvilPath()
        wall.lineWidth = 0
        wall.strokeColor = .clear
        wall.fillColor = .white
        wall.isAntialiased = true
        wall.zPosition = 0
        rim.path = SceneStorm.rimPath()
        rim.fillColor = .clear
        rim.lineWidth = 3.5
        rim.lineCap = .round
        rim.lineJoin = .round
        rim.zPosition = 0.5
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
        backRoot.addChild(wall)
        backRoot.addChild(rim)
        backRoot.addChild(wallGlow)
        backRoot.addChild(boltHalo)
        backRoot.addChild(bolt)

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
    /// billowing front column down to (and below) the horizon.
    static func anvilPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -4000, y: -300))
        p.addLine(to: CGPoint(x: -4000, y: 640))
        p.addLine(to: CGPoint(x: -320, y: 640))
        addAnvilEdge(p)
        p.addLine(to: CGPoint(x: 10, y: -300))
        p.closeSubpath()
        return p
    }

    /// The lit rim: along the anvil's top and down the upper front column.
    static func rimPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -320, y: 640))
        addAnvilEdge(p, stopBelow: 300)
        return p
    }

    private static func addAnvilEdge(_ p: CGMutablePath, stopBelow: CGFloat = -1000) {
        // The anvil top sweeping forward, its tip, and the underside back to the column.
        p.addQuadCurve(to: CGPoint(x: 140, y: 612), control: CGPoint(x: -60, y: 664))
        p.addQuadCurve(to: CGPoint(x: 172, y: 586), control: CGPoint(x: 178, y: 602))
        p.addQuadCurve(to: CGPoint(x: 42, y: 546), control: CGPoint(x: 112, y: 560))
        // The billowing front column (each lobe bulges ahead).
        let lobes: [CGPoint] = [CGPoint(x: 56, y: 480), CGPoint(x: 24, y: 412), CGPoint(x: 62, y: 342),
                                CGPoint(x: 20, y: 272), CGPoint(x: 52, y: 202), CGPoint(x: 14, y: 134),
                                CGPoint(x: 40, y: 64), CGPoint(x: 10, y: 0)]
        var prev = CGPoint(x: 42, y: 546)
        for q in lobes {
            let control = CGPoint(x: max(prev.x, q.x) + 38, y: (prev.y + q.y) * 0.5)
            p.addQuadCurve(to: q, control: control)
            prev = q
            if q.y < stopBelow { break }
        }
    }

    // MARK: Cosmetics

    func apply(sky: Sky) {
        let base = sky.storm
        let dark = ScenePaint.darker(base, 0.32)
        let low = ScenePaint.lighter(base, 0.10).mixed(with: sky.horizon, 0.12)
        wall.fillTexture = SceneTextures.verticalGradient(
            key: "anvil-\(sky.id.rawValue)",
            colors: [ScenePaint.ui(dark), ScenePaint.ui(base), ScenePaint.ui(low)], locations: [0, 0.45, 1])
        rim.strokeColor = ScenePaint.ui(ScenePaint.lighter(base, 0.35).mixed(with: sky.sun, 0.35), alpha: 0.85)
        // Far away the wall takes on the horizon's haze; near, its own slate.
        tints.removeAll()
        let haze = RGBA(1, 1, 1).mixed(with: sky.horizon, 0.55)
        for i in 0...20 {
            let c = haze.mixed(with: RGBA(1, 1, 1), Double(i) / 20)
            tints.append(ScenePaint.ui(c))
        }
        tintIndex = -1
        let wash = ScenePaint.ui(ScenePaint.darker(base, 0.1))
        shade.texture = SceneTextures.horizontalGradient(
            key: "stormshade-\(sky.id.rawValue)",
            colors: [wash, wash, wash.withAlphaComponent(0.55), wash.withAlphaComponent(0)], locations: [0, 0.72, 0.88, 1])
        shade.color = .white
        shade.colorBlendFactor = 0
        let sheetColor = ScenePaint.ui(ScenePaint.lighter(base, 0.25))
        for s in sheets { s.color = sheetColor }
        // A neutral grey of the horizon's brightness: laid over the world at 30 % it reads as desaturated.
        let lum = ScenePaint.luminance(sky.horizon.mixed(with: sky.storm, 0.5))
        calm.color = UIColor(white: CGFloat(lum), alpha: 1)
        let rain = ScenePaint.ui(ScenePaint.lighter(base, 0.55))
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
    /// rain. `lead` 0…1 (Core's lead meter). `caughtness` 0…1 eases in the caught ending.
    func update(edgeU: CGFloat, closeness: CGFloat, lead: CGFloat, caughtness: CGFloat, size: CGSize, minY: CGFloat,
                maxY: CGFloat, horizonY: CGFloat, dt: CGFloat) {
        clock += Double(dt)
        let c = min(max(max(closeness, caughtness), 0), 1)
        edge = edgeU
        self.lead = min(max(lead, 0), 1)
        canvas = size
        horizon = horizonY

        // The wall: its base under the horizon (the near sea covers it), scaled to the wanted height.
        let baseY = horizonY - 40
        let heightFraction = SceneLook.stormHeightFar + (SceneLook.stormHeightNear - SceneLook.stormHeightFar) * c
        let wallH = max(heightFraction * (size.height - baseY), 80)
        let s = wallH / SceneStorm.anvilHeight
        wall.position = CGPoint(x: edgeU, y: baseY)
        wall.setScale(s)
        rim.position = wall.position
        rim.setScale(s)
        let alpha = SceneLook.stormAlphaFar + (SceneLook.stormAlphaNear - SceneLook.stormAlphaFar) * c
        wall.alpha = alpha
        rim.alpha = 0.4 + 0.6 * c
        let ti = Int((c * 20).rounded())
        if ti != tintIndex && ti >= 0 && ti < tints.count {
            tintIndex = ti
            wall.fillColor = tints[ti]
        }
        wallTop = baseY + wallH
        wallFrame = CGRect(x: edgeU - 400 * s, y: baseY, width: 400 * s + 175 * s, height: wallH)

        // The grey wash over the sea under it.
        shade.position = CGPoint(x: edgeU + SceneLook.stormShadeReach, y: 0)
        shade.size = CGSize(width: 1800, height: size.height)
        shade.alpha = SceneLook.stormShadeFar + (SceneLook.stormShadeNear - SceneLook.stormShadeFar) * c

        // Rain sheets hanging from the cloud's lower half down past the bottom of the screen.
        let sheetTop = baseY + wallH * 0.45
        let sheetLength = max(sheetTop - minY + 40, 40)
        let sheetAlpha = (0.12 + 0.33 * c) * (1 + 0.4 * caughtness)
        for (i, sheet) in sheets.enumerated() {
            let fi = CGFloat(i)
            sheet.position = CGPoint(x: edgeU - 30 - fi * 120 * max(s, 0.5), y: sheetTop)
            sheet.size = CGSize(width: 70 + 50 * s, height: sheetLength)
            let flicker = CGFloat(0.85 + 0.15 * sin(clock * (1.3 + 0.4 * Double(i)) + Double(i)))
            sheet.alpha = sheetAlpha * flicker
        }

        // Rain: under the cloud, onto the left half once the storm is close, everywhere when caught.
        let closeK = min(max(1 - self.lead / 0.2, 0), 1)
        var rainEdge = max(edgeU + 50, closeK * size.width * 0.5)
        rainEdge += (size.width + 80 - rainEdge) * caughtness
        let rainAlpha = (0.18 + 0.2 * c + 0.25 * closeK) * (1 - 0.3 * caughtness)
        let raining = rainAlpha > 0.01 && rainEdge > -40
        // Drops start inside the cloud's lower half (from the sky's top once caught).
        let spawnTop = caughtness > 0.3 ? maxY + 160 : min(wallTop, maxY + 60)
        let spawnLow = min(spawnTop - 10, baseY + wallH * 0.5)
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
            let on = raining && p.x < rainEdge
            d.isHidden = !on
            if on {
                d.position = p
                d.alpha = rainAlpha
            }
        }

        // Lightning, while the run is still on.
        if dt > 0 && c > 0.25 && caughtness < 0.5 && clock >= nextStrike {
            strike(strength: 0.45 + 0.55 * (1 - self.lead))
        }
        flashLevel = max(0, flashLevel - dt * 6)
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
            wallGlow.position = CGPoint(x: edgeU - 160 * max(s, 0.6), y: baseY + wallH * 0.6)
            wallGlow.size = CGSize(width: 720 * max(s, 0.6), height: 720 * max(s, 0.6))
            wallGlow.alpha = glowLevel * 0.75
        }
        let boltOn = boltLife > 0
        bolt.isHidden = !boltOn
        boltHalo.isHidden = !boltOn
        if boltOn {
            let k = min(1, boltLife / 0.16)
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
        nextStrike = clock + interval * Double(0.35 + 0.65 * lead)
        strikeCount += 1
        let st = min(max(strength, 0.2), 1)
        glowLevel = max(glowLevel, reduceMotion ? 0.55 * st : st)
        if reduceMotion { return }
        flashLevel = st
        // A bolt inside the cloud (only when enough of the wall is on screen).
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
        boltLife = 0.16
    }
}
