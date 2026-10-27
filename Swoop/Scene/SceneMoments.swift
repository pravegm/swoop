import SpriteKit
import UIKit

/// "Gull Point reached!" (ART-FLIGHT-SCHOOL §4, SC4), the scene's part, in u-space (the roots flip when mirrored):
/// - t 0: the lamp's 40° beam sweeps 70° across the sea page over 0.9 s (ease-out), additive #FFF3C4 at α ≤ 0.35; the
///   lamp flares (a 140 pt reward-gold disc, α 0.55 → 0 over 0.6 s). The scene pulses the horizon haze to 0.75.
/// - t 0.05: a gust: 6 wind streaks run from the bird toward the storm ("the storm falls back", made visible).
/// - t 0.2: 12 soft gold motes rise 60–120 pt from the lamp over 1.2 s.
/// - **Fold rule:** the beam and the motes stay on the sea page, ≥ 28 pt off the crease: they fade out as the drifting
///   tower nears it (`minU`).
/// - **Reduce Motion:** no sweep, no gust, no motes; the flare fades in place.
///
/// The 60 ms hit-stop is the App's (Feel's `hitStop`): the scene's FX keep running on wall time through it.
@MainActor
final class SceneReachedMoment {
    /// In the backdrop, just over the lighthouse.
    let backRoot: SKNode
    /// Over everything (the gust and the motes).
    let frontRoot: SKNode

    private let beam: SKSpriteNode
    private let flare: SKSpriteNode
    private var gusts: [SKSpriteNode] = []
    private var gustPos: [CGPoint] = []
    private var gustSpeed: [CGFloat] = []
    private var motes: [SKSpriteNode] = []
    private var moteOffset: [CGPoint] = []
    private var moteRise: [CGFloat] = []
    private var rng = SceneRNG(seed: 0xBEA_4C0)
    private var age: Double = 10
    private var still = false
    private var birdU: CGFloat = 0
    private var birdY: CGFloat = 0
    private var gustsLaunched = false
    private var gustOnly = false
    private var motesLaunched = false
    /// The beam's angle this frame (radians from the +u axis; tests), and whether it is drawn.
    private(set) var beamAngle: CGFloat = 0
    var beamShown: Bool { !beam.isHidden }
    /// Whether the moment is still playing.
    var isPlaying: Bool { age < SceneLook.moteDelay + SceneLook.moteTime + 0.1 }

    init() {
        backRoot = SKNode()
        frontRoot = SKNode()
        beam = SKSpriteNode(texture: SceneTextures.beamWide)
        flare = SKSpriteNode(texture: SceneTextures.glow)
        beam.anchorPoint = CGPoint(x: 0, y: 0.5)
        beam.blendMode = .add
        beam.colorBlendFactor = 1
        beam.color = ScenePaint.ui(ScenePalette.rewardHighlight)
        beam.size = CGSize(width: SceneLook.reachedBeamLength, height: SceneLook.reachedBeamLength * 188 / 256)
        beam.zPosition = 0
        beam.isHidden = true
        flare.blendMode = .add
        flare.colorBlendFactor = 1
        flare.color = ScenePaint.ui(ScenePalette.rewardGold)
        flare.size = CGSize(width: SceneLook.reachedFlareSize, height: SceneLook.reachedFlareSize)
        flare.zPosition = 0.1
        flare.isHidden = true
        backRoot.addChild(beam)
        backRoot.addChild(flare)
        let streak = SceneTextures.streak
        let foam = UIColor.white
        for _ in 0..<SceneLook.gustCount {
            let s = SKSpriteNode(texture: streak, size: CGSize(width: 120, height: 2.2))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.color = foam
            // The streak's bright end leads as it runs toward the storm (−u).
            s.zRotation = CGFloat.pi
            s.isHidden = true
            frontRoot.addChild(s)
            gusts.append(s)
            gustPos.append(.zero)
            gustSpeed.append(0)
        }
        let soft = SceneTextures.soft
        for i in 0..<SceneLook.moteCount {
            let m = SKSpriteNode(texture: soft)
            m.blendMode = .add
            m.colorBlendFactor = 1
            m.color = ScenePaint.ui(i % 3 == 0 ? ScenePalette.rewardHighlight : ScenePalette.rewardGold)
            m.isHidden = true
            frontRoot.addChild(m)
            motes.append(m)
            moteOffset.append(.zero)
            moteRise.append(0)
        }
    }

    func clear() {
        age = 10
        beam.isHidden = true
        flare.isHidden = true
        for g in gusts { g.isHidden = true }
        for m in motes { m.isHidden = true }
    }

    /// The pass. `birdU` / `birdY`: the bird in u-space (the gust starts there).
    func play(birdU u: CGFloat, birdY y: CGFloat, reduceMotion: Bool) {
        gustOnly = false
        age = 0
        still = reduceMotion
        birdU = u
        birdY = y
        gustsLaunched = false
        motesLaunched = false
    }

    /// R9 (UX-ROUND-9 step 6): only the gust toward the storm (a school Perfect pushing the storm back).
    func playGust(birdU u: CGFloat, birdY y: CGFloat, reduceMotion: Bool) {
        play(birdU: u, birdY: y, reduceMotion: reduceMotion)
        gustOnly = true
    }

    /// Per frame. `lamp`: the lamp's centre in u-space (nil when the tower is off screen). `minU`: the sea page's
    /// inner limit (the fold band's far side + 28 pt; the canvas middle without a fold).
    func update(dt: CGFloat, lamp: CGPoint?, minU: CGFloat) {
        guard age < 9 else { return }
        age += Double(dt)
        let a = age
        // Fade the lamp's pieces as the tower drifts toward the fold.
        var onPage: CGFloat = 0
        if let l = lamp { onPage = SceneMoments.smooth(minU, minU + 60, l.x) }

        // The beam.
        let sweepEnd = SceneLook.reachedBeamSweep + SceneLook.reachedBeamFade
        let beamOn = !gustOnly && !still && a < sweepEnd && lamp != nil && onPage > 0.01
        beam.isHidden = !beamOn
        if beamOn, let l = lamp {
            let k = CGFloat(min(a / SceneLook.reachedBeamSweep, 1))
            let e = 1 - (1 - k) * (1 - k) * (1 - k)
            beamAngle = SceneLook.reachedBeamFrom + (SceneLook.reachedBeamTo - SceneLook.reachedBeamFrom) * e
            beam.zRotation = beamAngle
            beam.position = l
            var env = CGFloat(min(a / 0.1, 1))
            if a > SceneLook.reachedBeamSweep {
                env *= CGFloat(max(0, 1 - (a - SceneLook.reachedBeamSweep) / SceneLook.reachedBeamFade))
            }
            beam.alpha = SceneLook.reachedBeamAlpha * env * onPage
        }

        // The lamp flare.
        let flareOn = !gustOnly && a < SceneLook.reachedFlareTime && lamp != nil
        flare.isHidden = !flareOn
        if flareOn, let l = lamp {
            flare.position = l
            flare.alpha = SceneLook.reachedFlareAlpha * CGFloat(1 - a / SceneLook.reachedFlareTime) * max(onPage, 0.3)
        }

        // The gust toward the storm.
        if !still && !gustsLaunched && a >= SceneLook.gustDelay {
            gustsLaunched = true
            for i in 0..<gusts.count {
                gustPos[i] = CGPoint(x: birdU - 10 - rng.range(0, 50) + CGFloat(i) * 14, y: birdY + rng.range(-56, 56))
                gustSpeed[i] = rng.range(1500, 2100)
                gusts[i].size = CGSize(width: rng.range(80, 160), height: 2.2)
            }
        }
        for i in 0..<gusts.count {
            let g = gusts[i]
            let t = a - SceneLook.gustDelay - 0.03 * Double(i)
            let on = gustsLaunched && t >= 0 && t < 0.45
            if g.isHidden == on { g.isHidden = !on }
            guard on else { continue }
            gustPos[i].x -= gustSpeed[i] * dt
            g.position = gustPos[i]
            let fadeIn = CGFloat(min(t / 0.06, 1)), fadeOut = CGFloat(min((0.45 - t) / 0.15, 1))
            g.alpha = SceneLook.gustAlpha * fadeIn * fadeOut
        }

        // The motes rising from the lamp.
        if !gustOnly && !still && !motesLaunched && a >= SceneLook.moteDelay {
            motesLaunched = true
            for i in 0..<motes.count {
                moteOffset[i] = CGPoint(x: rng.range(-12, 12), y: rng.range(-6, 6))
                moteRise[i] = rng.range(60, 120)
                let d = rng.range(4, 7)
                motes[i].size = CGSize(width: d * 2.2, height: d * 2.2)
            }
        }
        for i in 0..<motes.count {
            let m = motes[i]
            let t = (a - SceneLook.moteDelay - 0.04 * Double(i % 4)) / SceneLook.moteTime
            let on = motesLaunched && t >= 0 && t < 1 && lamp != nil && onPage > 0.01
            if m.isHidden == on { m.isHidden = !on }
            guard on, let l = lamp else { continue }
            let k = CGFloat(t)
            let rise = moteRise[i] * (1 - (1 - k) * (1 - k))
            let drift = CGFloat(sin(Double(i) * 1.7 + t * 4)) * 6
            m.position = CGPoint(x: l.x + moteOffset[i].x + drift, y: l.y + moteOffset[i].y + rise)
            m.alpha = 0.9 * min(1, (1 - k) / 0.4) * onPage
        }
    }
}

/// Small shared maths for the moments and guides.
enum SceneMoments {
    static func smooth(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / max(b - a, 0.0001), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
