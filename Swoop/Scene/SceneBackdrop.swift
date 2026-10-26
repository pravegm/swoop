import SpriteKit
import UIKit

/// The sky behind the sea, in canvas "u-space" (u = 0 at the behind edge … width at the ahead edge; the scene flips
/// the root when mirrored): the zenith → horizon gradient, stars / aurora on dark skies, the sun ahead with its glow,
/// haze and glitter path, soft far clouds, and two parallax layers of distant swells.
///
/// R2: the far swells read as distant sea, not dunes (REVIEW-1 P1-4): a lightened sea blue with only a touch of the
/// horizon, a sunlit 1 px crest line, a darkening haze down the near layer, and the glitter crossing both. Their paths
/// are built once (they repeat every `farPeriod` px) and slid by the parallax (QA-1 P1-6).
@MainActor
final class SceneBackdrop {
    let root: SKNode
    private let skySprite: SKSpriteNode
    private let stars: SKSpriteNode
    private let aurora: SKSpriteNode
    private let sunGlow: SKSpriteNode
    private let sunDisk: SKSpriteNode
    private let haze: SKSpriteNode
    private let glitter: SKSpriteNode
    private let farBack: SKShapeNode
    private let farFront: SKShapeNode
    private let farShade: SKSpriteNode
    private var clouds: [SKSpriteNode] = []
    private var builtWidth: CGFloat = 0
    private var scrollBack: CGFloat = 0
    private var scrollFront: CGFloat = 0
    private var cloudScroll: CGFloat = 0
    private var pulseLevel: CGFloat = 0
    private var starAlpha: CGFloat = 0
    private var auroraOn = false
    private var dim: CGFloat = 0
    /// The sun's centre (u-space), for the Tailwind flare.
    private(set) var sunPosition = CGPoint(x: 760, y: 420)
    /// The far horizon line (canvas y).
    private(set) var horizonY: CGFloat = 300
    /// The near far-swell layer's mean line (canvas y): the lighthouse stands on it.
    private(set) var frontBaseY: CGFloat = 260

    /// (u as a fraction of the width, lift above the horizon px, width, height, opacity)
    private static let cloudSpecs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.10, 250, 300, 118, 0.50), (0.38, 345, 380, 140, 0.42), (0.64, 205, 260, 96, 0.55),
        (0.90, 300, 340, 128, 0.46), (1.18, 390, 420, 150, 0.36),
    ]

    init() {
        root = SKNode()
        skySprite = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
        stars = SKSpriteNode(texture: SceneTextures.stars)
        aurora = SKSpriteNode(texture: SceneTextures.aurora)
        sunGlow = SKSpriteNode(texture: SceneTextures.glow)
        sunDisk = SKSpriteNode(texture: SceneTextures.disk)
        haze = SKSpriteNode(texture: SceneTextures.glow)
        glitter = SKSpriteNode(texture: SceneTextures.glitter)
        farBack = SKShapeNode()
        farFront = SKShapeNode()
        farShade = SKSpriteNode(texture: SceneTextures.verticalGradient(
            key: "farshade", colors: [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 1)], locations: [0, 1]))

        skySprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        skySprite.zPosition = -20
        stars.anchorPoint = CGPoint(x: 0.5, y: 1)
        stars.zPosition = -19
        stars.isHidden = true
        aurora.anchorPoint = CGPoint(x: 0.5, y: 1)
        aurora.blendMode = .add
        aurora.zPosition = -18.5
        aurora.isHidden = true
        sunGlow.blendMode = .add
        sunGlow.colorBlendFactor = 1
        sunGlow.size = CGSize(width: SceneLook.sunGlowSize, height: SceneLook.sunGlowSize)
        sunGlow.zPosition = -18
        sunDisk.colorBlendFactor = 0.55
        sunDisk.size = CGSize(width: SceneLook.sunRadius * 2, height: SceneLook.sunRadius * 2)
        sunDisk.zPosition = -17.5
        haze.blendMode = .add
        haze.colorBlendFactor = 1
        haze.size = CGSize(width: 1500, height: 170)
        haze.zPosition = -17
        farBack.zPosition = -14
        farBack.lineWidth = 1
        farFront.zPosition = -12
        farFront.lineWidth = 1.2
        farShade.anchorPoint = CGPoint(x: 0.5, y: 1)
        farShade.colorBlendFactor = 1
        farShade.zPosition = -11.8
        glitter.anchorPoint = CGPoint(x: 0.5, y: 1)
        glitter.blendMode = .add
        glitter.colorBlendFactor = 1
        glitter.zPosition = -11.5
        for n in [skySprite, stars, aurora, sunGlow, sunDisk, haze, farShade, glitter] as [SKNode] { root.addChild(n) }
        root.addChild(farBack)
        root.addChild(farFront)
        for spec in SceneBackdrop.cloudSpecs {
            let c = SKSpriteNode(texture: SceneTextures.cloud)
            c.size = CGSize(width: spec.2, height: spec.3)
            c.colorBlendFactor = 1
            c.alpha = spec.4
            c.zPosition = -16
            root.addChild(c)
            clouds.append(c)
        }
    }

    func apply(sky: Sky) {
        skySprite.texture = SceneTextures.verticalGradient(
            key: "sky-\(sky.id.rawValue)",
            colors: [ScenePaint.ui(sky.zenith), ScenePaint.ui(sky.zenith.mixed(with: sky.horizon, 0.55)),
                     ScenePaint.ui(sky.horizon), ScenePaint.ui(sky.horizon.mixed(with: sky.sun, 0.35))],
            locations: [0, 0.5, 0.9, 1])
        skySprite.color = .white
        skySprite.colorBlendFactor = 0
        // Distant sea: lightened toward the haze with only a touch of the horizon's hue (mixing the hues makes khaki).
        let back = ScenePaint.lighter(sky.seaFar, 0.25).mixed(with: sky.horizon, 0.15)
        let front = sky.seaFar.mixed(with: sky.seaNear, 0.35)
        let lit = sky.horizon.mixed(with: sky.sun, 0.5)
        farBack.fillColor = ScenePaint.ui(back)
        farBack.strokeColor = ScenePaint.ui(ScenePaint.lighter(lit, 0.2), alpha: 0.8)
        farFront.fillColor = ScenePaint.ui(front)
        farFront.strokeColor = ScenePaint.ui(lit.mixed(with: sky.foam, 0.4), alpha: 0.55)
        farShade.color = ScenePaint.ui(ScenePaint.darker(sky.seaNear, 0.2))
        sunDisk.color = ScenePaint.ui(sky.sun)
        sunGlow.color = ScenePaint.ui(sky.sun)
        haze.color = ScenePaint.ui(sky.sun.mixed(with: sky.horizon, 0.4))
        glitter.color = ScenePaint.ui(ScenePaint.lighter(sky.sun, 0.3))
        let cloudTint = ScenePaint.ui(sky.horizon.mixed(with: ScenePaint.white, 0.55).mixed(with: sky.zenith, 0.12))
        for c in clouds { c.color = cloudTint }
        let lum = ScenePaint.luminance(sky.zenith)
        starAlpha = lum < 0.2 ? CGFloat((0.2 - lum) / 0.2) : 0
        stars.isHidden = starAlpha < 0.02
        auroraOn = sky.id == .northernLights
        aurora.isHidden = !auroraOn
    }

    /// A soft brightening of the horizon haze (milestones).
    func pulse() { pulseLevel = 1 }

    /// 0 … 1: dims the sun, glow, haze and glitter by up to half (the caught ending).
    func setDim(_ k: CGFloat) { dim = min(max(k, 0), 1) }

    /// `meanY`: canvas y of the near sea's mean water line. `scroll`: canvas px the world moved this frame.
    func update(width w: CGFloat, height h: CGFloat, meanY: CGFloat, zoom z: CGFloat, scroll: CGFloat, time t: Double,
                dt: CGFloat) {
        if abs(builtWidth - w) > 0.5 { buildSwells(width: w) }
        let period = SceneLook.farPeriod
        scrollBack = (scrollBack + scroll * SceneLook.farBackParallax).truncatingRemainder(dividingBy: period)
        scrollFront = (scrollFront + scroll * SceneLook.farFrontParallax).truncatingRemainder(dividingBy: period)
        cloudScroll += scroll * SceneLook.cloudParallax + dt * SceneLook.cloudDrift
        let backBase = meanY + SceneLook.farBackLift0 + SceneLook.farBackLift1 * z
        let frontBase = meanY + SceneLook.farFrontLift0 + SceneLook.farFrontLift1 * z
        horizonY = backBase
        frontBaseY = frontBase
        farBack.position = CGPoint(x: -24 - positiveMod(scrollBack, period), y: backBase)
        farBack.yScale = 0.6 + 0.4 * z
        farFront.position = CGPoint(x: -24 - positiveMod(scrollFront, period), y: frontBase)
        farFront.yScale = 0.55 + 0.45 * z
        farShade.position = CGPoint(x: w * 0.5, y: frontBase - 6)
        farShade.size = CGSize(width: w + 8, height: max(frontBase - meanY + 40, 30))
        farShade.alpha = 0.35

        let skyBottom = backBase - 40
        skySprite.position = CGPoint(x: w * 0.5, y: skyBottom)
        skySprite.size = CGSize(width: w + 8, height: max(h - skyBottom + 20, 60))

        let sunY = min(backBase + SceneLook.sunLift, h - 70)
        let bright = 1 - SceneLook.caughtSunDim * dim
        sunPosition = CGPoint(x: w * SceneLook.sunU, y: sunY)
        sunDisk.position = sunPosition
        sunDisk.alpha = bright
        sunGlow.position = sunPosition
        sunGlow.setScale(1 + 0.03 * CGFloat(sin(t * 0.9)))
        sunGlow.alpha = bright
        haze.position = CGPoint(x: w * SceneLook.sunU, y: backBase + 4)
        haze.alpha = (0.32 + 0.35 * pulseLevel) * bright
        glitter.position = CGPoint(x: sunPosition.x, y: backBase - 1)
        glitter.size = CGSize(width: 110, height: max(backBase - frontBase + 40, 24))
        glitter.alpha = CGFloat(0.55 + 0.1 * sin(t * 3.0)) * bright
        pulseLevel = max(0, pulseLevel - dt * 0.7)

        let span = w + 560
        for (i, c) in clouds.enumerated() {
            let spec = SceneBackdrop.cloudSpecs[i]
            let u = positiveMod(spec.0 * w - cloudScroll * (0.7 + 0.15 * CGFloat(i)), span)
            c.position = CGPoint(x: u - 280, y: backBase + spec.1 * (0.55 + 0.45 * z))
        }

        if !stars.isHidden {
            stars.position = CGPoint(x: w * 0.5, y: h)
            stars.size = CGSize(width: w + 8, height: h * 0.62)
            stars.alpha = starAlpha * CGFloat(0.85 + 0.15 * sin(t * 0.7))
        }
        if auroraOn {
            aurora.position = CGPoint(x: w * 0.5 + CGFloat(20 * sin(t * 0.07)), y: h)
            aurora.size = CGSize(width: w * 1.15, height: h * 0.56)
            aurora.alpha = CGFloat(0.42 + 0.14 * sin(t * 0.5))
        }
    }

    private func positiveMod(_ a: CGFloat, _ m: CGFloat) -> CGFloat {
        var r = a.truncatingRemainder(dividingBy: m)
        if r < 0 { r += m }
        return r
    }

    /// Both layers' paths, once per canvas width: one period wider than the canvas, base at y = 0, filled far down.
    private func buildSwells(width w: CGFloat) {
        builtWidth = w
        let p = SceneLook.farPeriod
        let tau = 2 * CGFloat.pi
        farBack.path = swellPath(length: w + p + 48, amp: 6, k1: tau * 6 / p, k2: tau * 14 / p)
        farFront.path = swellPath(length: w + p + 48, amp: 13, k1: tau * 4 / p, k2: tau * 9 / p)
    }

    private func swellPath(length: CGFloat, amp: CGFloat, k1: CGFloat, k2: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let step: CGFloat = 16
        let bottom: CGFloat = -1200
        var u: CGFloat = 0
        path.move(to: CGPoint(x: 0, y: bottom))
        var lastU = u
        while u <= length {
            let y = amp * (0.62 * sin(u * k1) + 0.38 * sin(u * k2 + 1.7))
            path.addLine(to: CGPoint(x: u, y: y))
            lastU = u
            u += step
        }
        path.addLine(to: CGPoint(x: lastU, y: bottom))
        path.closeSubpath()
        return path
    }
}
