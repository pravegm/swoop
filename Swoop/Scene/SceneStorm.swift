import SpriteKit
import UIKit

/// The storm front chasing the bird (GAME-DESIGN §6), in canvas u-space (u = 0 at the behind edge): a wall of slate
/// cloud whose billowing edge sits at `edgeU`, a grey wash over the sea under it, slanting rain, and the odd lightning
/// flicker (stronger as the gap closes; Reduce Motion → no flash, just a glow in the cloud). When the bird is caught
/// the rain sweeps softly over the whole canvas and a calm grey wash settles.
@MainActor
final class SceneStorm {
    /// Behind the near sea (with the backdrop).
    let backRoot: SKNode
    /// Over the near sea, under the bird.
    let shadeRoot: SKNode
    /// Over everything.
    let frontRoot: SKNode
    var reduceMotion = false

    private let wallFill: SKSpriteNode
    private let wall: SKSpriteNode
    private let wallGlow: SKSpriteNode
    private let bolt: SKShapeNode
    private let boltHalo: SKShapeNode
    private let shade: SKSpriteNode
    private let flash: SKSpriteNode
    private let calm: SKSpriteNode
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
    private var lead: CGFloat = 1
    private var canvas = CGSize(width: 952, height: 670)
    private var horizon: CGFloat = 300
    /// How many strikes have flashed (tests, tuning).
    private(set) var strikeCount = 0

    init() {
        backRoot = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
        wallFill = SKSpriteNode(color: .darkGray, size: CGSize(width: 2400, height: 900))
        wall = SKSpriteNode(color: .clear, size: CGSize(width: SceneLook.stormWallWidth, height: 900))
        wallGlow = SKSpriteNode(texture: SceneTextures.glow)
        bolt = SKShapeNode()
        boltHalo = SKShapeNode()
        shade = SKSpriteNode(color: .clear, size: CGSize(width: 1800, height: 670))
        flash = SKSpriteNode(color: .white, size: CGSize(width: 952, height: 670))
        calm = SKSpriteNode(color: .darkGray, size: CGSize(width: 952, height: 670))

        wallFill.anchorPoint = CGPoint(x: 1, y: 0.5)
        wallFill.zPosition = 0
        wall.anchorPoint = CGPoint(x: 1, y: 0.5)
        wall.zPosition = 0.5
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
        backRoot.addChild(wallFill)
        backRoot.addChild(wall)
        backRoot.addChild(wallGlow)
        backRoot.addChild(boltHalo)
        backRoot.addChild(bolt)

        shade.anchorPoint = CGPoint(x: 1, y: 0)
        shadeRoot.addChild(shade)

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

    func apply(sky: Sky) {
        let base = sky.storm
        let dark = ScenePaint.darker(base, 0.28)
        let light = ScenePaint.lighter(base, 0.22).mixed(with: sky.horizon, 0.15)
        wall.texture = SceneTextures.stormWall(key: sky.id.rawValue, dark: ScenePaint.ui(dark), base: ScenePaint.ui(base),
                                               light: ScenePaint.ui(light))
        wall.color = .white
        wall.colorBlendFactor = 0
        wallFill.texture = SceneTextures.verticalGradient(
            key: "stormfill-\(sky.id.rawValue)", colors: [ScenePaint.ui(dark), ScenePaint.ui(base), ScenePaint.ui(base)],
            locations: [0, 0.55, 1])
        wallFill.color = .white
        wallFill.colorBlendFactor = 0
        let wash = ScenePaint.ui(ScenePaint.darker(base, 0.1))
        shade.texture = SceneTextures.horizontalGradient(
            key: "stormshade-\(sky.id.rawValue)",
            colors: [wash, wash, wash.withAlphaComponent(0.55), wash.withAlphaComponent(0)], locations: [0, 0.72, 0.88, 1])
        shade.color = .white
        shade.colorBlendFactor = 0
        calm.color = ScenePaint.ui(base.mixed(with: sky.horizon, 0.25))
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

    /// `edgeU`: the cloud edge (u-space). `visibility` 0…1 fades the whole front. `lead` 0…1 (Core's lead meter).
    /// `caughtness` 0…1 eases in the caught ending.
    func update(edgeU: CGFloat, visibility: CGFloat, lead: CGFloat, caughtness: CGFloat, size: CGSize, minY: CGFloat,
                maxY: CGFloat, horizonY: CGFloat, dt: CGFloat) {
        clock += Double(dt)
        edge = edgeU
        self.lead = min(max(lead, 0), 1)
        canvas = size
        horizon = horizonY
        let vis = min(max(visibility, 0), 1)
        let shown = vis > 0.001 || caughtness > 0.001
        backRoot.isHidden = !shown
        shadeRoot.isHidden = !shown

        let wallH = size.height * 1.3
        wall.position = CGPoint(x: edgeU, y: size.height * 0.6)
        wall.size = CGSize(width: SceneLook.stormWallWidth, height: wallH)
        wall.alpha = vis
        wallFill.position = CGPoint(x: edgeU - SceneLook.stormWallWidth * 0.55, y: size.height * 0.6)
        wallFill.size = CGSize(width: 2400, height: wallH)
        wallFill.alpha = vis
        shade.position = CGPoint(x: edgeU + SceneLook.stormShadeReach, y: 0)
        shade.size = CGSize(width: 1800, height: size.height)
        shade.alpha = vis * SceneLook.stormShadeAlpha

        // Rain: under the cloud, onto the left half once the storm is close, everywhere when caught.
        let closeK = min(max(1 - self.lead / 0.2, 0), 1)
        var rainEdge = max(edgeU + 50, closeK * size.width * 0.5)
        rainEdge += (size.width + 80 - rainEdge) * caughtness
        let rainAlpha = max(vis, caughtness) * (0.30 + 0.30 * closeK) * (1 - 0.3 * caughtness)
        let raining = rainAlpha > 0.01 && rainEdge > -40
        for i in 0..<drops.count {
            var p = dropPos[i]
            if dt > 0 {
                p.x += SceneLook.rainVX * dropSpeed[i] * dt
                p.y -= SceneLook.rainVY * dropSpeed[i] * dt
                if p.y < minY - 30 || p.x > rainEdge + 30 {
                    p = CGPoint(x: rng.range(-60, max(rainEdge, -59)), y: rng.range(maxY, maxY + 160))
                }
                dropPos[i] = p
            }
            let s = drops[i]
            let on = raining && p.x < rainEdge
            s.isHidden = !on
            if on {
                s.position = p
                s.alpha = rainAlpha
            }
        }

        // Lightning: only while the front is on screen and the run is still on.
        if dt > 0 && vis > 0.3 && caughtness < 0.5 && clock >= nextStrike {
            strike(strength: 0.45 + 0.55 * (1 - self.lead))
        }
        flashLevel = max(0, flashLevel - dt * 6)
        glowLevel = max(0, glowLevel - dt * (reduceMotion ? 1.0 : 2.4))
        boltLife = max(0, boltLife - dt)
        flash.isHidden = flashLevel <= 0.001
        if !flash.isHidden {
            flash.size = CGSize(width: size.width + 4, height: size.height + 4)
            flash.position = CGPoint(x: -2, y: -2)
            flash.alpha = flashLevel * 0.22 * vis
        }
        wallGlow.isHidden = glowLevel <= 0.001
        if !wallGlow.isHidden {
            wallGlow.position = CGPoint(x: edgeU - 170, y: size.height * 0.68)
            wallGlow.size = CGSize(width: 720, height: 720)
            wallGlow.alpha = glowLevel * 0.75 * vis
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
        let s = min(max(strength, 0.2), 1)
        glowLevel = max(glowLevel, reduceMotion ? 0.55 * s : s)
        if reduceMotion { return }
        flashLevel = s
        // A bolt inside the cloud (only when enough of the wall is on screen).
        guard edge > 70 else { return }
        let lo = max(12, edge - 320), hi = edge - 40
        guard hi > lo else { return }
        var x = rng.range(lo, hi)
        var y = canvas.height + 10
        let bottom = horizon + rng.range(10, 60)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        let segments = 9
        var branchAt = CGPoint.zero
        for i in 1...segments {
            y = canvas.height + 10 - (canvas.height + 10 - bottom) * CGFloat(i) / CGFloat(segments)
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
