import SpriteKit
import UIKit

/// Where the storm stands on screen, from the gap: one pure mapping shared with the HUD so the lead meter and the
/// picture tell the same story (ROUND-4 P0-2). Nonisolated, unit-tested.
enum SceneStormMap {
    /// The lead meter's fill (ROUND-4 P1-7): sqrt(gap / (leadMeterScale × fullLead)), 0…1. The App's meter should use
    /// this same function.
    static func meterFill(gap: Double) -> CGFloat {
        let full = max(Tuning.leadMeterScale * Tuning.fullLead, 1)
        return CGFloat(min(max(gap / full, 0), 1).squareRoot())
    }

    /// The meter fill at which `stormClose` fires (lead < 0.15 → ≈ 0.17).
    static var closeFill: CGFloat {
        meterFill(gap: Tuning.stormCloseLead * Tuning.fullLead)
    }

    /// The cloud wall's front edge (u-space px from the behind edge), monotonic in the fill:
    /// - a hint at the left edge (`hintEdge`) at a full lead;
    /// - 40 % of the bird page at the storm-close fill;
    /// - right up behind the bird (`anchorU − 36`) as the gap closes.
    static func edgeU(meterFill f: CGFloat, birdPageWidth: CGFloat, anchorU: CGFloat) -> CGFloat {
        let fill = min(max(f, 0), 1)
        let hint = SceneLook.stormHintEdge
        let close = max(SceneLook.stormCloseCover * birdPageWidth, hint + 1)
        let contact = max(anchorU - 36, close + 1)
        let fc = max(closeFill, 0.01)
        if fill >= fc {
            return hint + (close - hint) * (1 - fill) / max(1 - fc, 0.01)
        }
        return close + (contact - close) * (1 - fill / fc)
    }

    /// Closeness 0 (far) … 1 (on the bird), from the same fill: it scales the wall's height, darkness and rain.
    static func closeness(meterFill f: CGFloat) -> CGFloat {
        min(max(1 - f / SceneLook.stormFarFill, 0), 1)
    }
}

/// The storm front chasing the bird (GAME-DESIGN §6, ART-DIRECTION §3), in canvas u-space (u = 0 at the behind edge).
///
/// R5 (REVIEW-4: the R4 anvil read as a flat "saucer" with a hard edge behind the HUD, and the column as chimney
/// smoke): a rolling shelf cloud.
/// - **Tiers:** four horizontal tiers of soft, horizontally stretched lobes (cap, shelf, roll, low), each stepping
///   forward of the one above as a real shelf cloud does, the roll cloud furthest ahead.
/// - **Light:** every upper lobe carries a sunlit crescent on its top-right edge (the sun is ahead).
/// - **Value:** the top is lifted (storm body + 10 % white) down to the storm-top colour at the base. That makes it
///   weather, not smoke.
/// - **No hard edges:** no vector anvil, no disc. A core silhouette, hidden under the lobes, fills behind them and
///   feathers into a rain-curtain base behind the far sea.
/// - **Clear of the HUD:** the wall's top is clamped by `stormHUDClearance` under the visible top, so it never runs
///   behind the pause button or the meter.
/// - **It chases:** the edge comes from `SceneStormMap.edgeU`, the same fill the lead meter shows.
/// - **Weather:** sky shade (capped at 0.5 at the bird), rain sheets, slanting rain, the grey sea wash, and lightning
///   (≤ 120 ms, ≤ 2/s; Reduce Motion: a cloud glow only).
/// - **Caught:** a 30 % grey wash (the far page 60 % of it), and rain over both pages.
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

    /// The wall's nominal height (base y = 0 … cap top ≈ this); the node is scaled to the wanted height.
    static let anvilHeight: CGFloat = 640
    /// The roll tier's front edge sits this far right of the node's origin (nominal pt); the edge maps onto it.
    static let frontEdge: CGFloat = 51
    /// The tiers, top to bottom: (centre y, lobe radius, horizontal stretch, front lobe's centre x, spacing, value
    /// 0 lit … 1 dark, rim light). Each steps forward of the one above; the roll tier sticks out furthest.
    static let tiers: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Double, Bool)] = [
        (500, 105, 1.5, -260, 150, 0.0, true),
        (375, 92, 1.8, -150, 140, 0.3, true),
        (250, 82, 2.0, -80, 135, 0.55, true),
        (120, 72, 1.8, -100, 130, 0.8, false),
        (40, 62, 1.6, -110, 125, 0.95, false),
    ]
    /// The tiers reach back this far (nominal pt) behind the front; past that the core covers the rest.
    static let tierReach: CGFloat = 1500

    private let wallRoot: SKNode
    private let core: SKShapeNode
    private var lobes: [SKSpriteNode] = []
    private var rims: [SKSpriteNode] = []
    /// Per lobe: (rest x, rest y, tier index, phase).
    private var lobeRest: [(CGFloat, CGFloat, Int, CGFloat)] = []
    /// Per rim: the index of its lobe.
    private var rimLobe: [Int] = []
    private let skyShade: SKSpriteNode
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
    /// The wall's top this frame (canvas y): always ≥ `stormHUDClearance` under the visible top (tests).
    private(set) var wallTop: CGFloat = 600
    private var lead: CGFloat = 1
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
        wallRoot = SKNode()
        core = SKShapeNode()
        skyShade = SKSpriteNode(color: .clear, size: CGSize(width: 600, height: 670))
        wallGlow = SKSpriteNode(texture: SceneTextures.glow)
        bolt = SKShapeNode()
        boltHalo = SKShapeNode()
        shade = SKSpriteNode(color: .clear, size: CGSize(width: 1800, height: 670))
        flash = SKSpriteNode(color: .white, size: CGSize(width: 952, height: 670))
        calm = SKSpriteNode(color: .clear, size: CGSize(width: 952, height: 670))

        skyShade.anchorPoint = .zero
        skyShade.zPosition = 0.1
        backRoot.addChild(skyShade)
        wallRoot.zPosition = 0.5
        backRoot.addChild(wallRoot)
        core.path = SceneStorm.corePath()
        core.zPosition = 0
        core.isAntialiased = true
        core.lineWidth = 0
        core.strokeColor = .clear
        core.fillColor = .white
        wallRoot.addChild(core)
        let lobeTexture = SceneTextures.stormLobe
        let rimTexture = SceneTextures.stormRimLight
        var cell = 0
        for (ti, tier) in SceneStorm.tiers.enumerated() {
            var x = tier.3
            var k = 0
            while x > tier.3 - SceneStorm.tierReach {
                let h1 = SceneRNG.hash(cell, 71)
                let h2 = SceneRNG.hash(cell, 83)
                cell += 1
                let r = tier.1 * (0.85 + 0.3 * h1)
                let size = CGSize(width: r * 2 * tier.2, height: r * 2)
                let y = tier.0 + (h2 - 0.5) * 24
                let lobe = SKSpriteNode(texture: lobeTexture, size: size)
                lobe.colorBlendFactor = 1
                lobe.position = CGPoint(x: x, y: y)
                // Back tiers first; within a tier, the front lobe on top.
                lobe.zPosition = 0.1 + CGFloat(ti) * 0.02 + CGFloat(k) * -0.0005
                wallRoot.addChild(lobe)
                lobeRest.append((x, y, ti, h1 * 6.283))
                lobes.append(lobe)
                if tier.6 {
                    let rimSprite = SKSpriteNode(texture: rimTexture, size: size)
                    rimSprite.blendMode = .add
                    rimSprite.colorBlendFactor = 1
                    rimSprite.position = lobe.position
                    rimSprite.zPosition = lobe.zPosition + 0.001
                    wallRoot.addChild(rimSprite)
                    rims.append(rimSprite)
                    rimLobe.append(lobes.count - 1)
                }
                x -= tier.4 * (0.9 + 0.2 * h2)
                k += 1
            }
        }
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
        for n in [wallGlow, boltHalo, bolt] as [SKNode] { backRoot.addChild(n) }

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

    // MARK: The wall's core (nominal: the roll tier's front near x = +51, base y = 0)

    /// The core silhouette: solid far to the left, its front running through each tier's front lobe centre (so the
    /// lobes always cover its edge), its top under the cap tier, and its base below the horizon (the far sea covers
    /// it).
    static func corePath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -4000, y: -300))
        p.addLine(to: CGPoint(x: -4000, y: tiers[0].0 - 30))
        p.addLine(to: CGPoint(x: tiers[0].3, y: tiers[0].0 - 30))
        var prev = CGPoint(x: tiers[0].3, y: tiers[0].0 - 30)
        for tier in tiers.dropFirst() {
            let q = CGPoint(x: tier.3, y: tier.0)
            p.addQuadCurve(to: q, control: CGPoint(x: min(prev.x, q.x), y: (prev.y + q.y) * 0.5))
            prev = q
        }
        p.addLine(to: CGPoint(x: prev.x, y: -300))
        p.closeSubpath()
        return p
    }

    // MARK: Cosmetics

    func apply(palette p: ScenePalette, sky id: SkyID) {
        let top = ScenePaint.ui(p.stormTop)
        let body = ScenePaint.ui(p.stormBody)
        let rain = ScenePaint.ui(p.rain)
        // R5: lift the body (REVIEW-4: #4A5468 at the top to #2A3040 at the base in Golden Hour).
        let lifted = p.stormBody.mixed(with: ScenePaint.white, 0.10)
        // The core over its box (y 470 … −300): the lifted body, darker below, a rain-curtain base fading out over the
        // last 140 pt above the horizon (y = 0 sits at 0.61).
        core.fillTexture = SceneTextures.verticalGradient(
            key: "stormcore5-\(id.rawValue)",
            colors: [ScenePaint.ui(lifted), body, top, rain.withAlphaComponent(0.35), rain.withAlphaComponent(0),
                     rain.withAlphaComponent(0)],
            locations: [0, 0.25, 0.45, 0.61, 0.70, 1])
        for (i, lobe) in lobes.enumerated() {
            let rest = lobeRest[i]
            let tier = SceneStorm.tiers[rest.2]
            let jitter = Double(SceneRNG.hash(i, 97)) * 0.12
            lobe.color = ScenePaint.ui(lifted.mixed(with: p.stormTop, min(1, tier.5 + jitter)))
        }
        let rimColor = ScenePaint.ui(p.stormRim)
        for r in rims { r.color = rimColor }
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
    /// the sky shade's cap.
    func update(edgeU e: CGFloat, closeness: CGFloat, lead: CGFloat, caughtness: CGFloat, size: CGSize, minY: CGFloat,
                maxY: CGFloat, horizonY: CGFloat, birdU: CGFloat, dt: CGFloat) {
        clock += Double(dt)
        let c = min(max(max(closeness, caughtness), 0), 1)
        edge = e
        edgeU = e
        self.lead = min(max(lead, 0), 1)
        canvas = size
        horizon = horizonY

        // The wall: its base at the horizon (the far sea covers it), its height a fraction of the *visible* sky but
        // never into the HUD band, its roll tier's front at `e`.
        let baseY = horizonY - 10
        let heightFraction = SceneLook.stormHeightFar + (SceneLook.stormHeightNear - SceneLook.stormHeightFar) * c
        let ceiling = max(maxY - SceneLook.stormHUDClearance - baseY, 80)
        let wallH = min(max(heightFraction * (maxY - baseY), 80), ceiling)
        let s = wallH / SceneStorm.anvilHeight
        wallRoot.position = CGPoint(x: e - SceneStorm.frontEdge * s, y: baseY)
        wallRoot.setScale(s)
        wallRoot.alpha = SceneLook.stormAlphaFar + (SceneLook.stormAlphaNear - SceneLook.stormAlphaFar) * c
        wallTop = baseY + wallH
        // The shelf rolls (≈ 4 pt/s): each lobe churns gently in place along its tier.
        if dt > 0 && !reduceMotion {
            let ph = CGFloat(clock)
            for (i, lobe) in lobes.enumerated() {
                let rest = lobeRest[i]
                let speed = 0.4 + 0.08 * CGFloat(rest.2)
                lobe.position = CGPoint(x: rest.0 + 7 * sin(ph * speed + rest.3), y: rest.1 + 4 * cos(ph * 0.35 + rest.3))
            }
            for (j, r) in rims.enumerated() { r.position = lobes[rimLobe[j]].position }
        }
        for r in rims { r.alpha = 0.35 * (0.6 + 0.4 * c) }

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

        // Rain sheets hanging from the cloud's base down past the bottom of the screen: constant under the wall.
        let sheetTop = baseY + wallH * 0.45
        let sheetLength = max(sheetTop - minY + 40, 40)
        let sheetAlpha = (0.20 + 0.30 * c) * (1 + 0.4 * caughtness)
        for (i, sheet) in sheets.enumerated() {
            let fi = CGFloat(i)
            sheet.position = CGPoint(x: e - 20 - fi * 110 * max(s, 0.5), y: sheetTop)
            sheet.size = CGSize(width: 70 + 50 * s, height: sheetLength)
            let flicker = CGFloat(0.85 + 0.15 * sin(clock * (1.3 + 0.4 * Double(i)) + Double(i)))
            sheet.alpha = sheetAlpha * flicker
        }

        // Rain: always under the cloud, onto the left half once the storm is close, everywhere when caught.
        let closeK = min(max(1 - self.lead / 0.2, 0), 1)
        var rainEdge = max(e + 50, closeK * size.width * 0.5)
        rainEdge += (size.width + 80 - rainEdge) * caughtness
        let rainAlpha = (0.24 + 0.18 * c + 0.22 * closeK) * (1 - 0.3 * caughtness)
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
