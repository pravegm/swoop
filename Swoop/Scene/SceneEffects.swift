import SpriteKit
import UIKit

/// The pooled world-space FX (GAME-DESIGN §7): skim spray and wake, launch burst, Perfect rings and sparkles, Splash,
/// cloud puffs, Tailwind shedding. Positions are world-local (sea x − the scene's origin); sizes are given in canvas
/// px and divided by the zoom at spawn. Everything runs on the scene's FX clock (the simulation's, plus wall time
/// through a short hit-stop).
@MainActor
final class SceneEffects {
    /// On the water, under the bird (rings, foam).
    let waterRoot: SKNode
    /// Droplets and puffs (normal blend), under the bird.
    let root: SKNode
    /// Sparkles (additive), over the bird.
    let glowRoot: SKNode
    var reduceMotion = false
    /// Thermal / Low Power: the share of particles spawned (UX-D5: 0.7 at .serious or in Low Power).
    var particleScale: CGFloat = 1
    /// Where the Perfect ring rides this frame: the water under the bird, a little behind it (world-local).
    var followPoint: CGPoint = .zero

    private let spray: SceneParticlePool
    private let foam: SceneParticlePool
    private let glow: SceneParticlePool
    private var rings: [SceneRingFX] = []
    private var ringCursor = 0
    private var rng = SceneRNG(seed: 0x5F00_D5)
    private var sprayCarry: CGFloat = 0
    private var wakeCarry: CGFloat = 0
    private var shedCarry: CGFloat = 0
    private let dotTexture: SKTexture
    private let softTexture: SKTexture
    private let sparkTexture: SKTexture
    /// The Perfect's gold bloom on the water.
    private let bloom: SKSpriteNode
    private var bloomAge: CGFloat = 1
    private var bloomSize: CGFloat = 0
    private let goldColor = ScenePaint.ui(ScenePaint.gold)
    private let paleGoldColor = ScenePaint.ui(ScenePaint.paleGold)
    private let whiteColor = UIColor.white
    /// Ring tiers (ROUND-4 P1-8): foam #F2F7FA, gold #F7C75B, reward gold #FFD45E.
    private let ringFoam = ScenePaint.ui(RGBA(hex: 0xF2F7FA))
    private let ringGold = ScenePaint.ui(RGBA(hex: 0xF7C75B))
    private let ringReward = ScenePaint.ui(ScenePalette.rewardGold)
    /// The last Perfect's ring colour tier: 0 foam, 1 gold, 2 reward gold (tests).
    private(set) var lastRingTier = -1

    init() {
        waterRoot = SKNode()
        root = SKNode()
        glowRoot = SKNode()
        dotTexture = SceneTextures.drop
        softTexture = SceneTextures.soft
        sparkTexture = SceneTextures.sparkle
        bloom = SKSpriteNode(texture: SceneTextures.glow)
        spray = SceneParticlePool(capacity: 240, texture: SceneTextures.drop, blend: .alpha)
        foam = SceneParticlePool(capacity: 120, texture: SceneTextures.soft, blend: .alpha)
        glow = SceneParticlePool(capacity: 110, texture: SceneTextures.sparkle, blend: .add)
        waterRoot.addChild(foam.root)
        root.addChild(spray.root)
        glowRoot.addChild(glow.root)
        bloom.blendMode = .add
        bloom.colorBlendFactor = 1
        bloom.color = ScenePaint.ui(ScenePaint.gold)
        bloom.isHidden = true
        bloom.zPosition = -0.5
        waterRoot.addChild(bloom)
        for _ in 0..<6 {
            let r = SceneRingFX()
            waterRoot.addChild(r.node)
            rings.append(r)
        }
    }

    func clear() {
        spray.clear()
        foam.clear()
        glow.clear()
        for r in rings {
            r.active = false
            r.node.isHidden = true
        }
        bloom.isHidden = true
        bloomAge = 1
        sprayCarry = 0
        wakeCarry = 0
        shedCarry = 0
    }

    func shift(dx: CGFloat) {
        spray.shift(dx: dx)
        foam.shift(dx: dx)
        glow.shift(dx: dx)
        for r in rings where r.active { r.node.position.x += dx }
        bloom.position.x += dx
    }

    var activeParticles: Int { spray.activeCount + foam.activeCount + glow.activeCount }

    func update(_ dt: CGFloat) {
        spray.update(dt)
        foam.update(dt)
        glow.update(dt)
        guard dt > 0 else { return }
        if !bloom.isHidden {
            bloomAge += dt
            let k = min(bloomAge / 0.45, 1)
            bloom.alpha = 0.85 * (1 - k) * (1 - k)
            bloom.setScale(0.6 + 0.6 * k)
            if k >= 1 { bloom.isHidden = true }
        }
        for r in rings where r.active {
            if r.rides { r.node.position = followPoint }
            r.age += dt
            let t = r.age - r.delay
            if t < 0 {
                r.node.isHidden = true
                continue
            }
            let k = min(t / max(r.duration, 0.01), 1)
            // Ease-out cubic growth; the alpha eases in to 0.
            let e = 1 - (1 - k) * (1 - k) * (1 - k)
            r.node.isHidden = false
            r.node.setScale(r.startScale + (r.endScale - r.startScale) * e)
            r.node.alpha = r.peakAlpha * (1 - k * k)
            if k >= 1 {
                r.active = false
                r.node.isHidden = true
            }
        }
    }

    // MARK: Continuous

    /// Skimming: spray thrown up and back off the wingtip trailing in the water. `back` is the unit vector opposite
    /// the motion; `k` 0…1 is the speed.
    func skim(tip: CGPoint, waterY: CGFloat, back: CGVector, k: CGFloat, zoom z: CGFloat, color: UIColor, dt: CGFloat) {
        sprayCarry += (SceneLook.skimSprayRate + SceneLook.skimSprayRateFast * k) * dt * (reduceMotion ? 0.6 : 1) * particleScale
        var n = 0
        while sprayCarry >= 1 && n < 10 {
            sprayCarry -= 1
            n += 1
            var p = SceneParticle()
            p.position = CGPoint(x: tip.x + rng.range(-4, 4) / z, y: waterY + 1 / z)
            let along = rng.range(60, 200 + 380 * k)
            let up = rng.range(80, 220 + 380 * k)
            p.velocity = CGVector(dx: back.dx * along, dy: back.dy * along + up)
            p.life = rng.range(0.28, 0.5 + 0.15 * k)
            p.gravity = 1700
            p.floorY = waterY - 40
            p.stretch = true
            spray.spawn(p, size: rng.range(2.6, 4.6 + 2.6 * k) / z, color: color, texture: dotTexture)
        }
        if sprayCarry > 4 { sprayCarry = 0 }
    }

    /// Skimming: foam flecks left on the surface behind the bird (they stay put in the sea, so they trail behind).
    func wake(at point: CGPoint, k: CGFloat, zoom z: CGFloat, color: UIColor, dt: CGFloat) {
        wakeCarry += (SceneLook.wakeRate + SceneLook.wakeRateFast * k) * dt * particleScale
        var n = 0
        while wakeCarry >= 1 && n < 6 {
            wakeCarry -= 1
            n += 1
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-12, 6) / z, y: point.y + rng.range(-3, 1) / z)
            p.velocity = CGVector(dx: rng.range(-14, 14), dy: 0)
            p.life = rng.range(0.8, 1.4)
            p.drag = 1.5
            p.shrink = false
            p.growth = 1.3
            p.alphaScale = rng.range(0.35, 0.6)
            foam.spawn(p, size: rng.range(7, 12 + 6 * k) / z, color: color, texture: softTexture)
        }
        if wakeCarry > 3 { wakeCarry = 0 }
    }

    /// Tailwind: golden motes shed from the ribbon.
    func shed(at point: CGPoint, zoom z: CGFloat, dt: CGFloat) {
        shedCarry += 34 * dt * (reduceMotion ? 0.5 : 1)
        while shedCarry >= 1 {
            shedCarry -= 1
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-6, 6) / z, y: point.y + rng.range(-6, 6) / z)
            p.velocity = CGVector(dx: rng.range(-40, 40), dy: rng.range(-20, 50))
            p.life = rng.range(0.45, 0.8)
            p.drag = 2
            p.spin = rng.range(-4, 4)
            let c = rng.unit() < 0.7 ? goldColor : paleGoldColor
            glow.spawn(p, size: rng.range(6, 11) / z, color: c, texture: softTexture)
        }
    }

    // MARK: Bursts

    /// Leaving the water off a crest: a burst of spray along the take-off line plus a little foam.
    func launch(at point: CGPoint, velocity v: CGVector, k: CGFloat, zoom z: CGFloat, color: UIColor) {
        let n = Int((reduceMotion ? 8 : 12) + (reduceMotion ? 10 : 24) * k)
        let heading = atan2(v.dy, v.dx)
        for i in 0..<n {
            // Most of it is thrown up and back off the crest; a third follows the bird out.
            let a: CGFloat = i % 3 == 0 ? heading + rng.range(-0.3, 0.3)
                                         : CGFloat.pi * 0.78 - heading * 0.3 + rng.range(-0.55, 0.55)
            let s = rng.range(140, 380 + 380 * k) * (i % 3 == 0 ? 0.6 : 1)
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-10, 6) / z, y: point.y + 2 / z)
            p.velocity = CGVector(dx: cos(a) * s * 0.7, dy: abs(sin(a)) * s + rng.range(60, 200))
            p.life = rng.range(0.4, 0.75)
            p.gravity = 1500
            p.floorY = point.y - 30
            p.stretch = true
            spray.spawn(p, size: rng.range(3, 6 + 3 * k) / z, color: color, texture: dotTexture)
        }
        foamRing(at: point, count: 6, spread: 30, zoom: z, color: color)
    }

    /// The ring tier for a chain (ROUND-4 P1-8): 0 foam (×1–4), 1 gold (×5–9), 2 reward gold with a second ring (×10+).
    nonisolated static func ringTier(chain: Int) -> Int {
        if chain >= SceneLook.ringTierReward { return 2 }
        if chain >= SceneLook.ringTierGold { return 1 }
        return 0
    }

    /// A Perfect (ART §5, ART-S12; R4 calmer): a ring that rides with the bird for 0.38 s, growing 40 → 170 px (ease-out
    /// cubic) as a 1 : 0.32 ellipse on the water, in the chain's tier colour (a second ring from ×10); a faint ripple
    /// that stays at the touchdown; a soft bloom; hard pale-gold drops at 60 % size and one mist puff (no white spiky
    /// burst); gold 4-point stars only from ×5 (≤ 6). Reduce Motion: the ring appears at 120 px and fades over 0.3 s.
    func perfect(at point: CGPoint, chain: Int, zoom z: CGFloat, foamColor: UIColor) {
        let tier = SceneEffects.ringTier(chain: chain)
        lastRingTier = tier
        let ringColor = tier == 2 ? ringReward : (tier == 1 ? ringGold : ringFoam)
        // The ring node is 200 pt wide at scale 1.
        let from = SceneLook.perfectRingFrom / 200 / z
        let to = SceneLook.perfectRingTo / 200 / z
        if reduceMotion {
            let still = SceneLook.ringStill / 200 / z
            ring(at: followPoint, color: ringColor, start: still, end: still, duration: 0.3, delay: 0, alpha: 1,
                 rides: true)
        } else {
            ring(at: followPoint, color: ringColor, start: from, end: to, duration: SceneLook.perfectRingTime, delay: 0,
                 alpha: 1, rides: true)
            if tier == 2 {
                ring(at: followPoint, color: paleGoldColor, start: from, end: to * 1.15,
                     duration: SceneLook.perfectRingTime + 0.08, delay: SceneLook.perfectRing2Delay, alpha: 0.85,
                     rides: true)
            }
        }
        // The physical ripple stays where the bird touched down.
        ring(at: point, color: foamColor, start: from, end: to * 0.9, duration: 0.8, delay: 0.02, alpha: 0.35,
             rides: false)
        bloomSize = 150 / z
        bloom.size = CGSize(width: bloomSize, height: bloomSize * 0.4)
        bloom.position = CGPoint(x: point.x, y: point.y + 4 / z)
        bloom.setScale(0.6)
        bloom.alpha = tier == 0 ? 0.25 : 0.4
        bloom.isHidden = false
        bloomAge = 0
        let stars = tier == 2 ? SceneLook.perfectStarsMax : (tier == 1 ? SceneLook.perfectStarsMid : 0)
        for i in 0..<stars {
            let a = CGFloat(i + 1) / CGFloat(stars + 1) * CGFloat.pi + rng.range(-0.12, 0.12)
            let sp = rng.range(140, 260)
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + cos(a) * 24 / z, y: point.y + 8 / z)
            p.velocity = CGVector(dx: cos(a) * sp, dy: sin(a) * sp * 0.9 + 80)
            p.life = rng.range(0.55, 0.8)
            p.drag = 2.6
            p.gravity = 120
            p.spin = rng.range(-4, 4)
            glow.spawn(p, size: rng.range(14, 20) / z, color: goldColor, texture: sparkTexture)
        }
        // Hard drops tinted pale gold at 60 % size, and one soft mist puff.
        splashDroplets(at: point, count: reduceMotion ? 5 : 9, speed: 240, zoom: z, color: paleGoldColor, sizeScale: 0.6)
        var mist = SceneParticle()
        mist.position = CGPoint(x: point.x, y: point.y + 8 / z)
        mist.velocity = CGVector(dx: 0, dy: 60)
        mist.life = 0.5
        mist.drag = 1.5
        mist.shrink = false
        mist.growth = 0.3
        mist.alphaScale = 0.5
        spray.spawn(mist, size: 90 / 1.3 / z, color: foamColor, texture: softTexture)
    }

    /// R9 caught: a rain-ring ripple on the water (an ellipse 24 → 60 pt in foam at α 0.4, 0.9 s).
    func ripple(at point: CGPoint, zoom z: CGFloat, color: UIColor) {
        let zz = max(z, 0.01)
        ring(at: point, color: color, start: 24 / 200 / zz, end: 60 / 200 / zz, duration: 0.9, delay: 0, alpha: 0.4,
             rides: false)
    }

    /// R9 guide gull: its "ghost Perfect", the ring in gold outline only (no drops, no stars), at `point`.
    func ghostPerfect(at point: CGPoint, zoom z: CGFloat) {
        let zz = max(z, 0.01)
        ring(at: point, color: ringReward, start: SceneLook.perfectRingFrom / 200 / zz,
             end: SceneLook.perfectRingTo / 200 / zz, duration: SceneLook.perfectRingTime + 0.1, delay: 0, alpha: 0.9,
             rides: false)
    }

    /// A Good landing: a modest splash.
    func good(at point: CGPoint, zoom z: CGFloat, color: UIColor) {
        splashDroplets(at: point, count: reduceMotion ? 6 : 12, speed: 300, zoom: z, color: color)
        foamRing(at: point, count: 6, spread: 26, zoom: z, color: color)
    }

    /// The mistake (ROUND-4 P1-9: it must read heavier and wetter than a Perfect): 36–48 hard drops thrown high, a
    /// 1.3× mist puff at α 0.5, a foam crater ring left on the water, and foam. The scene adds the camera dip and the
    /// bird's dunk.
    func splash(at point: CGPoint, k: CGFloat, zoom z: CGFloat, color: UIColor) {
        let span = CGFloat(SceneLook.splashDropsMax - SceneLook.splashDropsMin)
        let n = Int((CGFloat(SceneLook.splashDropsMin) + span * k) * (reduceMotion ? 0.6 : 1) * max(particleScale, 0.6))
        for _ in 0..<n {
            let a = CGFloat.pi / 2 + rng.range(-1.1, 1.1)
            let sp = rng.range(260, 620 + 260 * k)
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-18, 18) / z, y: point.y + 2 / z)
            p.velocity = CGVector(dx: cos(a) * sp * 0.75, dy: sin(a) * sp)
            p.life = rng.range(0.6, 1.0)
            p.gravity = 1500
            p.floorY = point.y - 20
            p.stretch = true
            spray.spawn(p, size: rng.range(2.5, 5.5) / z, color: color, texture: dotTexture)
        }
        var mist = SceneParticle()
        mist.position = CGPoint(x: point.x, y: point.y + 12 / z)
        mist.velocity = CGVector(dx: 0, dy: 110)
        mist.life = 0.8
        mist.gravity = 60
        mist.drag = 1.5
        mist.shrink = false
        mist.growth = 0.45
        mist.alphaScale = 0.5
        spray.spawn(mist, size: SceneLook.splashMist / 1.45 / z, color: color, texture: softTexture)
        // The crater: a quick white ring that stays on the water.
        let from = 60 / 200 / z
        ring(at: point, color: color, start: from, end: 150 / 200 / z, duration: 0.45, delay: 0, alpha: 0.7, rides: false)
        foamRing(at: point, count: 14, spread: 60, zoom: z, color: color)
    }

    /// Reaching cloud height: soft white puffs around the bird.
    func cloudPuff(at point: CGPoint, zoom z: CGFloat, color: UIColor) {
        let n = reduceMotion ? 6 : 12
        for _ in 0..<n {
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-30, 30) / z, y: point.y + rng.range(-20, 20) / z)
            p.velocity = CGVector(dx: rng.range(-140, 40), dy: rng.range(-40, 40))
            p.life = rng.range(0.9, 1.4)
            p.drag = 1.6
            p.shrink = false
            p.growth = 1.5
            p.alphaScale = rng.range(0.45, 0.7)
            spray.spawn(p, size: rng.range(40, 76) / z, color: color, texture: softTexture)
        }
    }

    /// A burst of twinkles (milestone, new best, lighthouse lamp).
    func sparkles(at point: CGPoint, count: Int, radius: CGFloat, zoom z: CGFloat, colors: [RGBA]) {
        guard !colors.isEmpty else { return }
        let n = reduceMotion ? max(1, count / 2) : count
        for i in 0..<n {
            let a = rng.range(0, 2 * CGFloat.pi)
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + cos(a) * radius * rng.unit() / z, y: point.y + sin(a) * radius * rng.unit() / z)
            p.velocity = CGVector(dx: cos(a) * rng.range(20, 90), dy: sin(a) * rng.range(20, 90) + 30)
            p.life = rng.range(0.5, 0.9)
            p.drag = 2
            p.spin = rng.range(-4, 4)
            glow.spawn(p, size: rng.range(12, 22) / z, color: ScenePaint.ui(colors[i % colors.count]),
                       texture: sparkTexture)
        }
    }

    /// After a Splash the bird shakes off water: single drops falling from it.
    func drip(at point: CGPoint, zoom z: CGFloat, color: UIColor) {
        var p = SceneParticle()
        p.position = point
        p.velocity = CGVector(dx: rng.range(-60, 60), dy: rng.range(20, 120))
        p.life = 0.6
        p.gravity = 1400
        p.stretch = true
        spray.spawn(p, size: rng.range(3, 5) / z, color: color, texture: dotTexture)
    }

    // MARK: Pieces

    private func splashDroplets(at point: CGPoint, count: Int, speed: CGFloat, zoom z: CGFloat, color: UIColor,
                                sizeScale: CGFloat = 1) {
        for _ in 0..<count {
            let a = CGFloat.pi / 2 + rng.range(-0.9, 0.9)
            let s = rng.range(speed * 0.5, speed)
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + rng.range(-8, 8) / z, y: point.y + 1 / z)
            p.velocity = CGVector(dx: cos(a) * s, dy: sin(a) * s)
            p.life = rng.range(0.35, 0.6)
            p.gravity = 1500
            p.floorY = point.y - 20
            p.stretch = true
            spray.spawn(p, size: rng.range(3, 6) * sizeScale / z, color: color, texture: dotTexture)
        }
    }

    private func foamRing(at point: CGPoint, count: Int, spread: CGFloat, zoom z: CGFloat, color: UIColor) {
        for i in 0..<count {
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            var p = SceneParticle()
            p.position = CGPoint(x: point.x + side * rng.range(0, spread) / z, y: point.y + rng.range(-2, 1) / z)
            p.velocity = CGVector(dx: side * rng.range(20, 70), dy: 0)
            p.life = rng.range(0.8, 1.3)
            p.drag = 1.8
            p.shrink = false
            p.growth = 1.2
            p.alphaScale = rng.range(0.4, 0.65)
            foam.spawn(p, size: rng.range(10, 18) / z, color: color, texture: softTexture)
        }
    }

    private func ring(at point: CGPoint, color: UIColor, start: CGFloat, end: CGFloat, duration: CGFloat,
                      delay: CGFloat, alpha: CGFloat, rides: Bool) {
        let r = rings[ringCursor % rings.count]
        ringCursor += 1
        r.active = true
        r.rides = rides
        r.age = 0
        r.delay = delay
        r.duration = duration
        r.startScale = start
        r.endScale = end
        r.peakAlpha = alpha
        r.node.strokeColor = color
        r.node.position = point
        r.node.setScale(start)
        r.node.alpha = delay > 0 ? 0 : alpha
        r.node.isHidden = delay > 0
    }
}
