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
/// R4 (REVIEW-3: "a stack of pancakes under a flat disc"; ROUND-4 P0-2): a weather wall.
/// - **The silhouette** is a shelf cloud built in three layers, all inside one node that is only moved and scaled:
///   - a lobed core silhouette (one static path);
///   - a back layer of lighter billows;
///   - a front layer of soft-rimmed lobes (radii 0.6–1.4×, never alternating) that roll slowly, lit from the sun
///     ahead and darker below.
/// - **The anvil** overhangs about 1.4× the column's depth with a tapered lip (no disc). Its crisp 3 pt sunlit rim
///   runs along the top only.
/// - **Behind the far sea:** the core feathers into a rain-curtain base, so there is never a hard rectangle.
/// - **It visibly chases:** the edge comes from `SceneStormMap.edgeU`, the same fill the lead meter shows.
/// - **The sky darkens first:** a sky shade in the storm-top colour, capped at 0.5 at the bird.
/// - **Under the wall:** soft rain sheets, slanting rain, and a grey wash over the sea.
/// - **Lightning:** ≤ 120 ms, ≤ 2 a second; Reduce Motion gives a cloud glow only.
/// - **Caught:** a 30 % grey wash (the far page takes 60 % of it), and rain over both pages.
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

    /// The wall's nominal height (base y = 0 … anvil top ≈ this); the node is scaled to the wanted height.
    static let anvilHeight: CGFloat = 640
    /// The lobes' nominal radius (pt) before their factors.
    static let lobeRadius: CGFloat = 64
    /// The front lobes: (centre x as a fraction of their radius, centre y, radius factor), top to bottom.
    static let frontLobes: [(CGFloat, CGFloat, CGFloat)] = [(-0.25, 470, 1.3), (-0.15, 405, 0.7), (-0.25, 340, 1.1),
                                                            (-0.10, 282, 0.6), (-0.30, 212, 1.4), (-0.15, 140, 0.9),
                                                            (-0.20, 72, 1.0), (-0.10, 14, 0.8)]
    /// The back billows (lighter, behind the front lobes): (centre x, centre y, radius factor).
    static let backLobes: [(CGFloat, CGFloat, CGFloat)] = [(-95, 505, 1.2), (-120, 400, 1.35), (-85, 300, 1.1),
                                                           (-130, 190, 1.4), (-90, 90, 1.15)]

    private let wallRoot: SKNode
    private let core: SKShapeNode
    private let anvil: SKShapeNode
    private let rim: SKShapeNode
    private var front: [SKSpriteNode] = []
    private var back: [SKSpriteNode] = []
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
        wallRoot = SKNode()
        core = SKShapeNode()
        anvil = SKShapeNode()
        rim = SKShapeNode()
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
        anvil.path = SceneStorm.anvilPath()
        rim.path = SceneStorm.rimPath()
        for (n, z) in [(core, CGFloat(0)), (anvil, CGFloat(0.3)), (rim, CGFloat(0.35))] {
            n.zPosition = z
            n.isAntialiased = true
            wallRoot.addChild(n)
        }
        core.lineWidth = 0
        core.strokeColor = .clear
        core.fillColor = .white
        anvil.lineWidth = 0
        anvil.strokeColor = .clear
        anvil.fillColor = .white
        rim.fillColor = .clear
        rim.lineCap = .round
        rim.lineJoin = .round
        let lobe = SceneTextures.stormLobe
        for spec in SceneStorm.backLobes {
            let s = SKSpriteNode(texture: lobe)
            let d = SceneStorm.lobeRadius * spec.2 * 2
            s.size = CGSize(width: d, height: d)
            s.position = CGPoint(x: spec.0, y: spec.1)
            s.colorBlendFactor = 1
            s.zPosition = 0.1
            wallRoot.addChild(s)
            back.append(s)
        }
        for spec in SceneStorm.frontLobes {
            let s = SKSpriteNode(texture: lobe)
            let r = SceneStorm.lobeRadius * spec.2
            s.size = CGSize(width: r * 2, height: r * 2)
            s.position = CGPoint(x: spec.0 * r, y: spec.1)
            s.colorBlendFactor = 1
            s.zPosition = 0.2
            wallRoot.addChild(s)
            front.append(s)
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

    // MARK: The wall's shapes (nominal: front lobes near x = 0, base y = 0, anvil top ≈ 640)

    /// The core silhouette: solid far to the left, its front running through the front lobes' centres (so the lobes
    /// always cover its edge), down below the horizon (the far sea covers that).
    static func corePath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -4000, y: -300))
        p.addLine(to: CGPoint(x: -4000, y: 520))
        p.addLine(to: CGPoint(x: -60, y: 520))
        var prev = CGPoint(x: -60, y: 520)
        for spec in frontLobes {
            let r = lobeRadius * spec.2
            let q = CGPoint(x: spec.0 * r, y: spec.1)
            p.addQuadCurve(to: q, control: CGPoint(x: min(prev.x, q.x) - 8, y: (prev.y + q.y) * 0.5))
            prev = q
        }
        p.addLine(to: CGPoint(x: prev.x, y: -300))
        p.closeSubpath()
        return p
    }

    /// The anvil: a broad shelf over the column whose lip tapers to a point about 1.4× the column's depth ahead.
    static func anvilPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -4000, y: 500))
        p.addLine(to: CGPoint(x: -4000, y: 604))
        p.addLine(to: CGPoint(x: -320, y: 616))
        p.addQuadCurve(to: CGPoint(x: 250, y: 550), control: CGPoint(x: 40, y: 640))
        p.addQuadCurve(to: CGPoint(x: -30, y: 498), control: CGPoint(x: 110, y: 518))
        p.closeSubpath()
        return p
    }

    /// The sunlit rim: the anvil's top edge only.
    static func rimPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -320, y: 616))
        p.addQuadCurve(to: CGPoint(x: 250, y: 550), control: CGPoint(x: 40, y: 640))
        return p
    }

    // MARK: Cosmetics

    func apply(palette p: ScenePalette, sky id: SkyID) {
        let top = ScenePaint.ui(p.stormTop)
        let body = ScenePaint.ui(p.stormBody)
        let rain = ScenePaint.ui(p.rain)
        let lit = p.stormBody.mixed(with: p.stormRim, 0.12)
        // The core over its box (y 520 … −300): the body, darker underneath, a rain-curtain base fading out over the
        // last 140 pt above the horizon (y = 0 sits at 0.63).
        core.fillTexture = SceneTextures.verticalGradient(
            key: "stormcore4-\(id.rawValue)",
            colors: [body, top, top, rain.withAlphaComponent(0.35), rain.withAlphaComponent(0),
                     rain.withAlphaComponent(0)],
            locations: [0, 0.35, 0.46, 0.63, 0.72, 1])
        // The anvil: lit on top, the body below.
        anvil.fillTexture = SceneTextures.verticalGradient(
            key: "stormanvil4-\(id.rawValue)", colors: [ScenePaint.ui(lit), body, top], locations: [0, 0.55, 1])
        rim.strokeColor = ScenePaint.ui(p.stormRim, alpha: 0.95)
        // The lobes: lighter (sun-catching) near the top, the storm-top colour near the base.
        let n = SceneStorm.frontLobes.count
        for (i, s) in front.enumerated() {
            let k = Double(i) / Double(max(n - 1, 1))
            s.color = ScenePaint.ui(lit.mixed(with: p.stormTop, k))
        }
        for s in back { s.color = ScenePaint.ui(p.stormBody.mixed(with: p.stormRim, 0.06)) }
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

        // The wall: its base at the horizon (the far sea covers it), its height a fraction of the *visible* sky, its
        // front lobes' edge (≈ +0.6 lobe radius) at `e`.
        let baseY = horizonY - 10
        let heightFraction = SceneLook.stormHeightFar + (SceneLook.stormHeightNear - SceneLook.stormHeightFar) * c
        let wallH = max(heightFraction * (maxY - baseY), 80)
        let s = wallH / SceneStorm.anvilHeight
        wallRoot.position = CGPoint(x: e - SceneStorm.lobeRadius * 0.6 * s, y: baseY)
        wallRoot.setScale(s)
        wallRoot.alpha = SceneLook.stormAlphaFar + (SceneLook.stormAlphaNear - SceneLook.stormAlphaFar) * c
        if rimScale <= 0 || abs(s / rimScale - 1) > 0.05 {
            rimScale = s
            rim.lineWidth = SceneLook.stormRimWidth / max(s, 0.05)
        }
        rim.alpha = 0.5 + 0.5 * c
        wallTop = baseY + wallH
        // A slow roll on the lobes (≈ 4 pt/s): they churn in place rather than sit still like tyres.
        if dt > 0 && !reduceMotion {
            let ph = CGFloat(clock)
            for (i, lobe) in front.enumerated() {
                let spec = SceneStorm.frontLobes[i]
                let r = SceneStorm.lobeRadius * spec.2
                let fi = CGFloat(i)
                lobe.position = CGPoint(x: spec.0 * r + 6 * sin(ph * 0.55 + fi * 1.7),
                                        y: spec.1 + 6 * cos(ph * 0.45 + fi * 1.1))
            }
            for (i, lobe) in back.enumerated() {
                let spec = SceneStorm.backLobes[i]
                let fi = CGFloat(i)
                lobe.position = CGPoint(x: spec.0 + 8 * sin(ph * 0.35 + fi * 2.1), y: spec.1 + 5 * cos(ph * 0.3 + fi))
            }
        }

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
