import SpriteKit
import UIKit

/// The sky behind the sea, in canvas "u-space" (u = 0 at the behind edge … width at the ahead edge; the scene flips
/// the root when mirrored).
///
/// R3 (ART-DIRECTION §2–§3, ART-S1–S3): everything reads `ScenePalette`, never a mix of complementary colours.
/// - The sky is five fixed stops with dither.
/// - Stars only on dark skies; an aurora on Northern Lights.
/// - One key light: the sun ahead at u = 0.8 w, 0.16 h above the horizon, clamped under the visible top.
/// - Thin, flat-bottomed lit cloud streaks.
/// - A 60 pt horizon haze.
/// - Two thin far-sea layers (≤ 14 % of the height, amplitudes 2.5 / 5 pt, built once and slid). The front one's top
///   is hazed into the back one.
/// - A 0.12 w glitter column of dashes crossing both.
///
/// Layer z (inside the backdrop): sky −20, stars −19, aurora −18.5, sun glow −18, disk −17.5, clouds −16.5, the storm
/// group −16 (added by the scene), haze −15, far-back −14, lighthouse −12.5 (added by the scene), far-front −12, its
/// haze −11.9, far shade −11.8, glitter −11.5.
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
    private let frontHaze: SKSpriteNode
    private let farShade: SKSpriteNode
    private var clouds: [SKSpriteNode] = []
    private var builtWidth: CGFloat = 0
    private var scrollBack: CGFloat = 0
    private var scrollFront: CGFloat = 0
    private var cloudScroll: CGFloat = 0
    private var pulseLevel: CGFloat = 0
    private var starAlpha: CGFloat = 0
    private var auroraOn = false
    private var diskAlpha: CGFloat = 1
    private var glowScale: CGFloat = 1
    /// The sun's centre (u-space), for the Tailwind flare.
    private(set) var sunPosition = CGPoint(x: 760, y: 420)
    /// The far horizon line (canvas y).
    private(set) var horizonY: CGFloat = 300
    /// The far-front layer's mean line (canvas y): the lighthouse stands on it.
    private(set) var frontBaseY: CGFloat = 260
    /// The sun's current brightness 0…1 after the storm's and the caught ending's dimming (tests).
    private(set) var sunBrightness: CGFloat = 1

    /// (u as a fraction of the width, lift above the horizon as a fraction of the visible height, width, thickness,
    /// opacity): five thin streaks, 300–700 × 18–40 pt, α 0.30–0.45.
    private static let cloudSpecs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.40, 520, 26, 0.40), (0.36, 0.58, 680, 34, 0.32), (0.62, 0.30, 360, 18, 0.45),
        (0.86, 0.50, 600, 30, 0.36), (1.12, 0.66, 440, 40, 0.30),
    ]

    init() {
        root = SKNode()
        skySprite = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
        stars = SKSpriteNode(texture: SceneTextures.stars)
        aurora = SKSpriteNode(texture: SceneTextures.aurora)
        sunGlow = SKSpriteNode(texture: SceneTextures.glow)
        sunDisk = SKSpriteNode(texture: SceneTextures.disk)
        haze = SKSpriteNode(texture: SceneTextures.band)
        glitter = SKSpriteNode(texture: SceneTextures.glitter)
        farBack = SKShapeNode()
        farFront = SKShapeNode()
        frontHaze = SKSpriteNode(texture: SceneTextures.verticalGradient(
            key: "fronthaze", colors: [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0)], locations: [0, 1]))
        farShade = SKSpriteNode(texture: SceneTextures.verticalGradient(
            key: "farshade2", colors: [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 1),
                                       UIColor(white: 1, alpha: 1)], locations: [0, 0.4, 1]))

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
        sunGlow.zPosition = -18
        sunDisk.colorBlendFactor = 0.55
        sunDisk.size = CGSize(width: SceneLook.sunRadius * 2, height: SceneLook.sunRadius * 2)
        sunDisk.zPosition = -17.5
        haze.colorBlendFactor = 1
        haze.zPosition = -15
        farBack.zPosition = -14
        farBack.lineWidth = 1
        farFront.zPosition = -12
        farFront.lineWidth = 1
        frontHaze.anchorPoint = CGPoint(x: 0.5, y: 1)
        frontHaze.colorBlendFactor = 1
        frontHaze.zPosition = -11.9
        farShade.anchorPoint = CGPoint(x: 0.5, y: 1)
        farShade.colorBlendFactor = 1
        farShade.zPosition = -11.8
        glitter.anchorPoint = CGPoint(x: 0.5, y: 1)
        glitter.blendMode = .add
        glitter.colorBlendFactor = 1
        glitter.zPosition = -11.5
        for n in [skySprite, stars, aurora, sunGlow, sunDisk, haze, frontHaze, farShade, glitter] as [SKNode] {
            root.addChild(n)
        }
        root.addChild(farBack)
        root.addChild(farFront)
        let streak = SceneTextures.cloudStreak
        for spec in SceneBackdrop.cloudSpecs {
            let c = SKSpriteNode(texture: streak)
            c.size = CGSize(width: spec.2, height: spec.3)
            c.colorBlendFactor = 1
            c.alpha = spec.4
            c.zPosition = -16.5
            root.addChild(c)
            clouds.append(c)
        }
    }

    func apply(palette p: ScenePalette, sky id: SkyID) {
        skySprite.texture = SceneTextures.sky(
            key: id.rawValue,
            colors: [ScenePaint.ui(p.zenith), ScenePaint.ui(p.mid), ScenePaint.ui(p.low), ScenePaint.ui(p.horizon),
                     ScenePaint.ui(p.sunline)])
        skySprite.color = .white
        skySprite.colorBlendFactor = 0
        farBack.fillColor = ScenePaint.ui(p.farBack)
        farBack.strokeColor = ScenePaint.ui(p.horizon, alpha: 0.6)
        farFront.fillColor = ScenePaint.ui(p.farFront)
        farFront.strokeColor = ScenePaint.ui(p.farBack, alpha: 0.5)
        frontHaze.color = ScenePaint.ui(p.farBack)
        farShade.color = ScenePaint.ui(p.nearMean)
        sunDisk.color = ScenePaint.ui(p.sunDisk)
        sunGlow.color = ScenePaint.ui(p.sunGlow)
        haze.color = ScenePaint.ui(p.horizon)
        glitter.color = ScenePaint.ui(p.glitter)
        diskAlpha = p.sunDiskAlpha
        glowScale = p.sunGlowScale
        sunGlow.size = CGSize(width: SceneLook.sunGlowSize * glowScale, height: SceneLook.sunGlowSize * glowScale)
        let cloudTint = ScenePaint.ui(p.cloud)
        for c in clouds { c.color = cloudTint }
        let lum = ScenePaint.luminance(p.zenith)
        starAlpha = lum < 0.06 ? CGFloat(min(1, (0.06 - lum) / 0.04)) : 0
        stars.isHidden = starAlpha < 0.02
        auroraOn = id == .northernLights
        aurora.isHidden = !auroraOn
    }

    /// A milestone: the horizon haze brightens to 0.75 (used when there is no fold to glint).
    func pulse() { pulseLevel = 1 }

    /// `meanY`: canvas y of the near sea's mean water line. `scroll`: canvas px the world moved this frame.
    /// `visibleTop`: the top of the visible rect (iPhones crop the canvas). `sunDim` 0…1 dims the sun by that much.
    func update(width w: CGFloat, height h: CGFloat, visibleTop: CGFloat, meanY: CGFloat, zoom z: CGFloat,
                scroll: CGFloat, time t: Double, dt: CGFloat, sunDim: CGFloat, drift: Bool) {
        if abs(builtWidth - w) > 0.5 { buildSwells(width: w) }
        let period = SceneLook.farPeriod
        scrollBack = (scrollBack + scroll * SceneLook.farBackParallax).truncatingRemainder(dividingBy: period)
        scrollFront = (scrollFront + scroll * SceneLook.farFrontParallax).truncatingRemainder(dividingBy: period)
        cloudScroll += scroll * SceneLook.cloudParallax + (drift ? dt * SceneLook.cloudDrift : 0)
        let backBase = meanY + SceneLook.farBackLift0 + SceneLook.farBackLift1 * z
        let frontBase = meanY + SceneLook.farFrontLift0 + SceneLook.farFrontLift1 * z
        horizonY = backBase
        frontBaseY = frontBase
        let ampScale = 0.8 + 0.2 * z
        farBack.position = CGPoint(x: -24 - positiveMod(scrollBack, period), y: backBase)
        farBack.yScale = ampScale
        farFront.position = CGPoint(x: -24 - positiveMod(scrollFront, period), y: frontBase)
        farFront.yScale = ampScale
        frontHaze.position = CGPoint(x: w * 0.5, y: frontBase + SceneLook.farFrontAmp)
        frontHaze.size = CGSize(width: w + 8, height: SceneLook.farFrontHaze)
        frontHaze.alpha = 0.7
        farShade.position = CGPoint(x: w * 0.5, y: frontBase - 2)
        farShade.size = CGSize(width: w + 8, height: max(frontBase + 40, 40))
        farShade.alpha = SceneLook.farShadeAlpha

        // The sky: zenith at the top of the canvas, the sunline exactly at the horizon.
        let skyBottom = backBase - 2
        skySprite.position = CGPoint(x: w * 0.5, y: skyBottom)
        skySprite.size = CGSize(width: w + 8, height: max(h - skyBottom + 20, 60))

        let sunY = min(backBase + SceneLook.sunLiftFraction * h, visibleTop - SceneLook.sunTopClearance)
        sunBrightness = max(0, 1 - sunDim)
        sunPosition = CGPoint(x: w * SceneLook.sunU, y: max(sunY, backBase + 30))
        sunDisk.position = sunPosition
        sunDisk.alpha = diskAlpha * sunBrightness
        sunGlow.position = sunPosition
        sunGlow.setScale(1 + 0.03 * CGFloat(sin(t * 0.9)))
        sunGlow.alpha = sunBrightness
        haze.position = CGPoint(x: w * 0.5, y: backBase)
        haze.size = CGSize(width: w + 8, height: SceneLook.hazeHeight)
        haze.alpha = (SceneLook.hazeAlpha + (SceneLook.hazePulseAlpha - SceneLook.hazeAlpha) * pulseLevel)
            * (0.6 + 0.4 * sunBrightness)
        glitter.position = CGPoint(x: sunPosition.x, y: backBase)
        glitter.size = CGSize(width: w * SceneLook.glitterWidth, height: max(backBase - meanY + 20, 24))
        // A 3 Hz shimmer.
        glitter.alpha = CGFloat(0.7 + 0.18 * sin(t * 2 * Double.pi * 3)) * sunBrightness
        pulseLevel = max(0, pulseLevel - dt / 0.6)

        let span = w + 760
        let skyH = max(visibleTop - backBase, 60)
        for (i, c) in clouds.enumerated() {
            let spec = SceneBackdrop.cloudSpecs[i]
            let u = positiveMod(spec.0 * w - cloudScroll * (0.7 + 0.15 * CGFloat(i)), span)
            c.position = CGPoint(x: u - 380, y: backBase + spec.1 * skyH)
        }

        if !stars.isHidden {
            stars.position = CGPoint(x: w * 0.5, y: h)
            stars.size = CGSize(width: w + 8, height: h * 0.62)
            stars.alpha = starAlpha * CGFloat(0.85 + 0.15 * sin(t * 0.7))
        }
        if auroraOn {
            aurora.position = CGPoint(x: w * 0.5 + CGFloat(20 * sin(t * 0.07)), y: h)
            aurora.size = CGSize(width: w * 1.15, height: h * 0.56)
            aurora.alpha = CGFloat(0.85 + 0.15 * sin(t * 0.5))
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
        let b = SceneLook.farBackCycles, f = SceneLook.farFrontCycles
        farBack.path = swellPath(length: w + p + 48, amp: SceneLook.farBackAmp, k1: tau * b.0 / p, k2: tau * b.1 / p)
        farFront.path = swellPath(length: w + p + 48, amp: SceneLook.farFrontAmp, k1: tau * f.0 / p, k2: tau * f.1 / p)
    }

    private func swellPath(length: CGFloat, amp: CGFloat, k1: CGFloat, k2: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let step: CGFloat = 8
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
