import SpriteKit
import UIKit

/// One cosmetic particle (spray droplet, foam fleck, sparkle, puff). Simulated by the scene, never by Core.
struct SceneParticle {
    var position: CGPoint = .zero
    var velocity: CGVector = CGVector(dx: 0, dy: 0)
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
    var gravity: CGFloat = 0
    var drag: CGFloat = 0
    /// Dies when falling below this y (droplets back into the water).
    var floorY: CGFloat = -1_000_000
    var spin: CGFloat = 0
    /// Stretch along the velocity (droplets in flight).
    var stretch: Bool = false
    var shrink: Bool = true
    /// Grows by this factor over its life (foam spreading, puffs billowing).
    var growth: CGFloat = 0
    /// Peak opacity.
    var alphaScale: CGFloat = 1
    var active: Bool = false
}

/// A fixed pool of sprites (one blend mode; textures swapped per spawn). Nothing is allocated per frame.
@MainActor
final class SceneParticlePool {
    let root: SKNode
    private var sprites: [SKSpriteNode] = []
    private var parts: [SceneParticle] = []
    private var cursor = 0

    init(capacity: Int, texture: SKTexture, blend: SKBlendMode) {
        root = SKNode()
        for _ in 0..<capacity {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 6, height: 6))
            s.colorBlendFactor = 1
            s.blendMode = blend
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            parts.append(SceneParticle())
        }
    }

    var activeCount: Int {
        var n = 0
        for p in parts where p.active { n += 1 }
        return n
    }

    func clear() {
        for i in 0..<parts.count {
            parts[i].active = false
            sprites[i].isHidden = true
        }
    }

    /// Re-base after the world origin moved by `dx`.
    func shift(dx: CGFloat) {
        for i in 0..<parts.count where parts[i].active {
            parts[i].position.x += dx
            sprites[i].position.x += dx
        }
    }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<parts.count where parts[i].active {
            var p = parts[i]
            p.life -= dt
            p.velocity.dy -= p.gravity * dt
            if p.drag > 0 {
                let k = max(0, 1 - p.drag * dt)
                p.velocity.dx *= k
                p.velocity.dy *= k
            }
            p.position.x += p.velocity.dx * dt
            p.position.y += p.velocity.dy * dt
            let s = sprites[i]
            if p.life <= 0 || (p.velocity.dy < 0 && p.position.y < p.floorY) {
                p.active = false
                s.isHidden = true
                parts[i] = p
                continue
            }
            let k = max(0, min(1, p.life / max(p.maxLife, 0.001)))
            s.position = p.position
            s.alpha = min(1, k * 3) * p.alphaScale
            var scale: CGFloat = p.shrink ? (0.35 + 0.65 * k) : 1
            if p.growth > 0 { scale *= 1 + p.growth * (1 - k) }
            if p.stretch {
                let speed = hypot(p.velocity.dx, p.velocity.dy)
                s.zRotation = atan2(p.velocity.dy, p.velocity.dx)
                s.xScale = scale * (1 + min(speed / 900, 1.2))
                s.yScale = scale
            } else {
                s.zRotation += p.spin * dt
                s.setScale(scale)
            }
            parts[i] = p
        }
    }

    func spawn(_ p: SceneParticle, size: CGFloat, color: UIColor, texture: SKTexture) {
        let n = parts.count
        guard n > 0 else { return }
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if !parts[idx].active {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        var q = p
        q.active = true
        q.maxLife = max(q.life, 0.01)
        parts[slot] = q
        let s = sprites[slot]
        if s.texture !== texture { s.texture = texture }
        s.size = CGSize(width: size, height: size)
        s.color = color
        s.colorBlendFactor = 1
        s.position = q.position
        s.zRotation = 0
        s.setScale(1)
        s.alpha = q.alphaScale
        s.isHidden = false
    }
}

/// An expanding ring on the water (Perfect), animated by the scene's FX clock (so it freezes with a pause).
@MainActor
final class SceneRingFX {
    let node: SKShapeNode
    var age: CGFloat = 0
    var duration: CGFloat = 0.6
    var delay: CGFloat = 0
    var startScale: CGFloat = 0.2
    var endScale: CGFloat = 1
    var peakAlpha: CGFloat = 1
    /// R10: when `fade` > 0 the ring grows at full alpha, holds `hold` s at full size, then fades over `fade` s (the
    /// Perfect's peak is the ring at full size). 0 = the old grow-and-fade.
    var hold: CGFloat = 0
    var fade: CGFloat = 0
    var active = false
    /// Rides with the bird (the Perfect ring), or stays where it was dropped (the ripple).
    var rides = false

    init() {
        // Drawn at a 200-pt width (a 1 : 0.32 ellipse lying on the water) and scaled, so the stroke thickens as it grows.
        node = SKShapeNode(ellipseOf: CGSize(width: 200, height: 200 * SceneLook.ringAspect))
        node.fillColor = .clear
        node.lineWidth = 7
        node.isHidden = true
    }
}
