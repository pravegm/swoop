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

/// The storm front chasing the bird (GAME-DESIGN §6, ART-DIRECTION §3), in canvas u-space (u = 0 at the behind edge;
/// the scene flips the roots when mirrored, so it always comes from the bird page's outer edge).
///
/// R6 (ROUND-6 "the storm", ART-FLIGHT-SCHOOL §7.3): a new technique. The wall is **one soft cumulonimbus texture**
/// rendered once from fbm noise (`SceneStormCloud`): a flat dark rain base, a billowing front face that leans back, a
/// flat anvil with a crisp sunlit rim, and a streaked rain curtain feathering out under it. No lobes, no rows.
/// - **Life:** it breathes slowly (≤ 1.2 % in height, ±3 pt), and its inside lights up: a glow every 3–6 s from
///   first sight (Reduce Motion: the glow only), plus the bolts and flashes once it is close.
/// - **It chases:** the shelf's front sits at `edgeU`, from `SceneStormMap`, the same fill the lead meter shows.
/// - **Clear of the HUD:** its top is clamped `stormHUDClearance` under the visible top.
/// - **Never in the fold band in play:** the drawn cloud ends `drawnRightU` (edge + ≤ 50 pt), far short of it.
/// - **Weather:** the sky shade (capped at 0.5 at the bird), rain sheets, slanting rain, the grey sea wash.
/// - **Caught:** a 30 % grey wash (the far page 60 % of it), and rain over both pages.
/// - **Flight School:** `presence` 0 hides all of it (the practice sea), and `rainPresence` lets step 7 start the rain
///   last.
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

    private let wallRoot: SKNode
    private let cloud: SKSpriteNode
    private let backing: SKSpriteNode
    private var glows: [SKSpriteNode] = []
    private let skyShade: SKSpriteNode
    private let bolt: SKShapeNode
    private let boltHalo: SKShapeNode
    private let shade: SKSpriteNode
    private let flash: SKSpriteNode
    private let calm: SKSpriteNode
    /// R9 caught: the warm horizon strip ahead of the front.
    private let strip: SKSpriteNode
    private var sheets: [SKSpriteNode] = []
    private var drops: [SKSpriteNode] = []
    private var dropPos: [CGPoint] = []
    private var dropSpeed: [CGFloat] = []
    private var rng = SceneRNG(seed: 0x570B_33)
    private var clock: Double = 0
    private var nextStrike: Double = 2.5
    private var nextGlow: Double = 1.0
    private var flashLevel: CGFloat = 0
    private var glowLevel: CGFloat = 0
    private var glowSpot = 0
    private var boltLife: CGFloat = 0
    private var edge: CGFloat = -1000
    /// The cloud texture's scale this frame (nominal → canvas pt).
    private(set) var cloudScale: CGFloat = 0.3
    private var shown: CGFloat = 1
    /// The wall's top this frame (canvas y): always ≥ `stormHUDClearance` under the visible top (tests).
    private(set) var wallTop: CGFloat = 600
    private var lead: CGFloat = 1
    private var canvas = CGSize(width: 952, height: 670)
    private var horizon: CGFloat = 300
    /// How many strikes have flashed, and how many glows (strikes included) have lit the cloud (tests, tuning).
    private(set) var strikeCount = 0
    private(set) var glowCount = 0
    /// The wall's front edge (u-space) this frame, and the sky shade's alpha at the bird (tests).
    private(set) var edgeU: CGFloat = 0
    private(set) var skyShadeAtBird: CGFloat = 0
    /// The rightmost u the cloud can draw at this frame (its texture is empty beyond), or −∞ when hidden (tests: the
    /// fold band).
    private(set) var drawnRightU: CGFloat = -.greatestFiniteMagnitude
    /// Whether any of the storm is drawn this frame (Flight School hides it).
    private(set) var isShown = true

    init() {
        backRoot = SKNode()
        shadeRoot = SKNode()
        frontRoot = SKNode()
        wallRoot = SKNode()
        cloud = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 10))
        backing = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 10))
        skyShade = SKSpriteNode(color: .clear, size: CGSize(width: 600, height: 670))
        bolt = SKShapeNode()
        boltHalo = SKShapeNode()
        shade = SKSpriteNode(color: .clear, size: CGSize(width: 1800, height: 670))
        flash = SKSpriteNode(color: .white, size: CGSize(width: 952, height: 670))
        calm = SKSpriteNode(color: .clear, size: CGSize(width: 952, height: 670))
        strip = SKSpriteNode(texture: SceneTextures.band)

        skyShade.anchorPoint = .zero
        skyShade.zPosition = 0.1
        backRoot.addChild(skyShade)
        wallRoot.zPosition = 0.5
        backRoot.addChild(wallRoot)
        for n in [backing, cloud] {
            n.anchorPoint = .zero
            n.colorBlendFactor = 0
            n.color = .white
            wallRoot.addChild(n)
        }
        backing.zPosition = 0
        cloud.zPosition = 0.1
        let glowColor = UIColor(red: 0.78, green: 0.84, blue: 1.0, alpha: 1)
        for i in 0..<SceneStormCloud.glowSpots.count {
            let g = SKSpriteNode(texture: SceneTextures.stormGlow(i))
            g.anchorPoint = .zero
            g.blendMode = .add
            g.colorBlendFactor = 1
            g.color = glowColor
            g.zPosition = 0.2
            g.isHidden = true
            wallRoot.addChild(g)
            glows.append(g)
        }
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
        for n in [boltHalo, bolt] as [SKNode] { backRoot.addChild(n) }

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
        strip.anchorPoint = CGPoint(x: 0, y: 0.5)
        strip.colorBlendFactor = 1
        strip.blendMode = .add
        strip.zPosition = 1.5
        strip.isHidden = true
        frontRoot.addChild(strip)

        // Rain moves +u (away from the storm, toward the bird): it is u-space, so mirrored it moves left on screen.
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

    // MARK: Cosmetics

    func apply(palette p: ScenePalette, sky id: SkyID) {
        let top = ScenePaint.ui(p.stormTop)
        let rain = ScenePaint.ui(p.rain)
        let tex = SceneTextures.stormCloud(key: id.rawValue, body: p.stormBody, top: p.stormTop, rim: p.stormRim,
                                           rain: p.rain)
        cloud.texture = tex
        backing.texture = SceneTextures.stormBacking(key: id.rawValue, of: tex)
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
        strip.color = ScenePaint.ui(p.sunline)
    }

    func clear() {
        flashLevel = 0
        glowLevel = 0
        boltLife = 0
        bolt.isHidden = true
        boltHalo.isHidden = true
        flash.isHidden = true
        for g in glows { g.isHidden = true }
        nextStrike = clock + 2.5
        nextGlow = clock + 1.0
    }

    // MARK: Frame

    /// `edgeU`: the cloud edge (u-space). `closeness` 0 (far) … 1 (on the bird) scales the wall's height, darkness and
    /// rain. `lead` 0…1 (Core's lead meter). `caughtness` 0…1 eases in the caught ending. `presence` 0…1: how much of
    /// the storm is drawn at all (Flight School); `rainPresence` 0…1 scales the rain on top of it. `birdU`: the
    /// bird's u, for the sky shade's cap.
    func update(edgeU e: CGFloat, closeness: CGFloat, lead: CGFloat, caughtness: CGFloat, presence: CGFloat = 1,
                rainPresence: CGFloat = 1, size: CGSize, minY: CGFloat, maxY: CGFloat, horizonY: CGFloat,
                birdU: CGFloat, dt: CGFloat) {
        clock += Double(dt)
        let c = min(max(max(closeness, caughtness), 0), 1)
        let pr = min(max(presence, 0), 1)
        let rainK = pr * min(max(rainPresence, 0), 1)
        shown = pr
        edge = e
        edgeU = e
        self.lead = min(max(lead, 0), 1)
        canvas = size
        horizon = horizonY
        isShown = pr > 0.005
        for n in [wallRoot, skyShade, shade] as [SKNode] where n.isHidden == isShown { n.isHidden = !isShown }

        // The wall: its base under the horizon (the far sea covers the rain curtain's foot), its height a fraction of
        // the *visible* sky but never into the HUD band, the shelf's front at `e`.
        let baseY = horizonY - 30
        let heightFraction = SceneLook.stormHeightFar + (SceneLook.stormHeightNear - SceneLook.stormHeightFar) * c
        let ceiling = max(maxY - SceneLook.stormHUDClearance - baseY, 80)
        let wallH = min(max(heightFraction * (maxY - baseY), 80), ceiling)
        let s = wallH / SceneStormCloud.height
        cloudScale = s
        wallTop = baseY + wallH
        let still = reduceMotion || dt <= 0
        let breathe: CGFloat = still ? 1 : 1 - 0.012 * CGFloat(0.5 + 0.5 * sin(clock * 0.45))
        let sway: CGFloat = still ? 0 : 3 * CGFloat(sin(clock * 0.31))
        let left = e - SceneStormCloud.edgeX * s + sway
        cloud.position = CGPoint(x: left, y: baseY)
        cloud.size = CGSize(width: SceneStormCloud.width * s, height: wallH * breathe)
        for g in glows {
            g.position = cloud.position
            g.size = cloud.size
        }
        // The storm runs on off screen behind its texture: its left columns, stretched.
        let backingWidth = left + 42
        backing.isHidden = backingWidth <= 0 || !isShown
        if !backing.isHidden {
            backing.position = CGPoint(x: -40, y: baseY)
            backing.size = CGSize(width: backingWidth + 2, height: wallH * breathe)
        }
        wallRoot.alpha = (SceneLook.stormAlphaFar + (SceneLook.stormAlphaNear - SceneLook.stormAlphaFar) * c) * pr
        let reachRight = (SceneStormCloud.drawnRight - SceneStormCloud.edgeX) * s + abs(sway)
        drawnRightU = isShown ? e + reachRight : -CGFloat.greatestFiniteMagnitude

        // The sky shade: the sky darkens before the sea does; never more than 0.5 at the bird.
        let reach = max(e + SceneLook.skyShadeReach * size.width, 10)
        skyShade.position = .zero
        skyShade.size = CGSize(width: reach, height: size.height)
        var shadeAlpha = SceneLook.skyShadeBase + SceneLook.skyShadeClose * c
        let atBird = max(0, 1 - birdU / reach)
        if shadeAlpha * atBird > SceneLook.skyShadeCapAtBird { shadeAlpha = SceneLook.skyShadeCapAtBird / atBird }
        skyShade.alpha = shadeAlpha * pr
        skyShadeAtBird = shadeAlpha * atBird * pr

        // The grey wash over the sea under it.
        shade.position = CGPoint(x: e + SceneLook.stormShadeReach, y: 0)
        shade.size = CGSize(width: 1800, height: size.height)
        shade.alpha = (SceneLook.stormShadeFar + (SceneLook.stormShadeNear - SceneLook.stormShadeFar) * c) * pr

        // Rain sheets hanging from the cloud's base down past the bottom of the screen: constant under the wall.
        let cloudBase = baseY + SceneStormCloud.baseY * s
        let sheetLength = max(cloudBase - minY + 40, 40)
        let sheetAlpha = (0.20 + 0.30 * c) * (1 + 0.4 * caughtness) * rainK
        for (i, sheet) in sheets.enumerated() {
            let fi = CGFloat(i)
            sheet.isHidden = sheetAlpha < 0.005
            if sheet.isHidden { continue }
            sheet.position = CGPoint(x: e - 30 - fi * 110 * max(s * 3, 0.5), y: cloudBase)
            sheet.size = CGSize(width: 70 + 150 * s, height: sheetLength)
            let flicker = CGFloat(0.85 + 0.15 * sin(clock * (1.3 + 0.4 * Double(i)) + Double(i)))
            sheet.alpha = sheetAlpha * flicker
        }

        // Rain: always under the cloud, onto the left half once the storm is close, everywhere when caught.
        let closeK = min(max(1 - self.lead / 0.2, 0), 1)
        var rainEdge = max(e + 50, closeK * size.width * 0.5)
        // Caught (R9): the rain covers the whole wall and leads its edge by 60 pt.
        rainEdge += (max(e + SceneLook.caughtRainLead, rainEdge) * SceneLook.caughtRainCover - rainEdge) * caughtness
        let rainAlpha = (0.24 + 0.18 * c + 0.22 * closeK) * (1 - 0.3 * caughtness) * rainK
        let raining = rainAlpha > 0.01 && rainEdge > -40
        let spawnTop = caughtness > 0.3 ? maxY + 160 : min(wallTop, maxY + 60)
        let spawnLow = min(spawnTop - 10, cloudBase + wallH * 0.3)
        let drawn = Int(CGFloat(drops.count) * min(max(rainScale, 0), 1))
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
            let on = raining && i < drawn && p.x < rainEdge
            if d.isHidden == on { d.isHidden = !on }
            if on {
                d.position = p
                d.alpha = rainAlpha
            }
        }

        // Lightning, while the run is still on (the one light allowed on the left page, ≤ 120 ms), and a glow inside
        // the cloud every 3–6 s from first sight (ART-FLIGHT-SCHOOL §7.3).
        if dt > 0 && isShown && caughtness < 0.5 {
            if c > 0.25 && clock >= nextStrike {
                strike(strength: 0.45 + 0.55 * (1 - self.lead))
            } else if pr > 0.5 && clock >= nextGlow {
                glowOnce(strength: 0.5)
            }
        }
        flashLevel = max(0, flashLevel - dt * 8.5)
        glowLevel = max(0, glowLevel - dt * (reduceMotion ? 1.0 : 2.4))
        boltLife = max(0, boltLife - dt)
        flash.isHidden = flashLevel <= 0.001 || !isShown
        if !flash.isHidden {
            flash.size = CGSize(width: size.width + 4, height: size.height + 4)
            flash.position = CGPoint(x: -2, y: -2)
            flash.alpha = flashLevel * SceneLook.flashPeak * pr
        }
        for (i, g) in glows.enumerated() {
            let on = i == glowSpot && glowLevel > 0.001 && isShown
            if g.isHidden == on { g.isHidden = !on }
            if on { g.alpha = glowLevel * 0.85 }
        }
        let boltOn = boltLife > 0 && isShown
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
        // Ahead of the caught front, the light is still out there: a warm strip on the horizon.
        let stripW = size.width - e + 40
        strip.isHidden = caughtness < 0.01 || stripW < 4
        if !strip.isHidden {
            strip.position = CGPoint(x: e - 20, y: horizonY + 24)
            strip.size = CGSize(width: max(stripW, SceneLook.caughtHorizonStrip * size.width), height: 200)
            strip.alpha = caughtness * SceneLook.caughtHorizonAlpha
        }
    }

    /// No periodic glow for the next `seconds` (step 7 names the storm with its own glow at +1.2 s).
    func deferGlows(_ seconds: Double) {
        nextGlow = clock + max(seconds, 0)
    }

    /// A glow inside the cloud with no bolt and no flash (also Flight School's step 7, which names the storm with one).
    func glowOnce(strength: CGFloat) {
        nextGlow = clock + Double(rng.range(3, 6))
        glowCount += 1
        glowSpot = Int(rng.unit() * CGFloat(max(glows.count, 1))) % max(glows.count, 1)
        glowLevel = max(glowLevel, min(max(strength, 0.2), 1))
    }

    /// R9 caught: one bolt inside the wall at u `x` (ahead of the bird: the storm is now over and ahead of it).
    func strike(strength: CGFloat, atU x: CGFloat) {
        forcedX = x
        strike(strength: strength)
        forcedX = nil
    }

    private var forcedX: CGFloat?

    /// A lightning strike now (also on `stormClose`). Reduce Motion: no flash or bolt, only a glow in the cloud.
    func strike(strength: CGFloat) {
        let interval = Double(rng.range(SceneLook.strikeIntervalMin, SceneLook.strikeIntervalMax))
        // Never more than 2 flashes a second (ART §5).
        nextStrike = clock + max(0.5, interval * Double(0.35 + 0.65 * lead))
        strikeCount += 1
        let st = min(max(strength, 0.2), 1)
        glowOnce(strength: reduceMotion ? 0.55 * st : st)
        if reduceMotion || shown < 0.5 { return }
        flashLevel = st
        guard edge > 60 else { return }
        let lo = max(12, edge - 300), hi = edge - 40
        guard hi > lo || forcedX != nil else { return }
        var x = forcedX ?? rng.range(lo, hi)
        let top = min(wallTop - 30, canvas.height + 10)
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
