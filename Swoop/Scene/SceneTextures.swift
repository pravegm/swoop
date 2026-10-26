import SpriteKit
import UIKit

/// Colour helpers on the shared `RGBA`, as plain functions (no extension on a shared type, so nothing can clash with
/// another module's helpers).
enum ScenePaint {
    static func ui(_ c: RGBA) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    static func ui(_ c: RGBA, alpha: CGFloat) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: alpha)
    }

    static func lighter(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(1, 1, 1, c.a), t) }
    static func darker(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(0, 0, 0, c.a), t) }
    static func luminance(_ c: RGBA) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    /// The reward gold (ART §2: the same in every sky): core #FFD45E, highlight #FFF3C4.
    static let gold = RGBA(hex: 0xFFD45E)
    static let paleGold = RGBA(hex: 0xFFF3C4)
    static let white = RGBA(1, 1, 1)
}

/// xorshift64 for cosmetic randomness (never the simulation's `SeededRandom`).
struct SceneRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// 0 ..< 1
    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / 9_007_199_254_740_992.0)
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }

    mutating func sign() -> CGFloat { unit() < 0.5 ? -1 : 1 }

    /// A stateless 0 ..< 1 hash of a cell index (stable decorations that don't flicker as cells scroll).
    static func hash(_ i: Int, _ salt: UInt64) -> CGFloat {
        var z = UInt64(bitPattern: Int64(i)) &+ (salt &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return CGFloat(Double(z >> 11) / 9_007_199_254_740_992.0)
    }
}

/// Stand-in cosmetics until the driver supplies its own (the scene never needs Core's catalogue).
enum SceneDefaults {
    static let bird = Bird(id: .gull, name: "Gull", blurb: "", body: RGBA(hex: 0xF5F2EC), wing: RGBA(hex: 0xB8C4CF),
                           wingTip: RGBA(hex: 0x2A2E35), beak: RGBA(hex: 0xF2B33D), trail: RGBA(hex: 0xFFFFFF),
                           span: 1.0, pointiness: 0.55, unlockRank: 0)
    static let sky = Sky(id: .goldenHour, name: "Golden Hour", zenith: RGBA(hex: 0x2D4A7E), horizon: RGBA(hex: 0xF7B56E),
                         sun: RGBA(hex: 0xFFE2A0), seaNear: RGBA(hex: 0x1D5C78), seaFar: RGBA(hex: 0x3F7F97),
                         foam: RGBA(hex: 0xF3F9FF), storm: RGBA(hex: 0x39414F), unlockRank: 0)
}

/// A gentle sea for frames drawn before the driver has a `SeaProfile` (never used for play).
enum SceneFallbackSea {
    static func height(_ x: Double) -> Double { 70 * sin(x * 0.0105) + 28 * sin(x * 0.0231 + 1.3) }
    static func slope(_ x: Double) -> Double { 70 * 0.0105 * cos(x * 0.0105) + 28 * 0.0231 * cos(x * 0.0231 + 1.3) }
}

/// Textures generated in code once and cached (no per-frame texture work).
@MainActor
enum SceneTextures {
    private static var cache: [String: SKTexture] = [:]

    static func make(_ key: String, width: CGFloat, height: CGFloat, scale: CGFloat,
                     draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let size = CGSize(width: width, height: height)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { rc in
            draw(rc.cgContext, size)
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    static func linear(_ ctx: CGContext, _ colors: [UIColor], _ locations: [CGFloat], from a: CGPoint, to b: CGPoint) {
        guard colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { $0.cgColor } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ ctx: CGContext, _ colors: [UIColor], _ locations: [CGFloat], center: CGPoint, radius: CGFloat) {
        guard radius > 0, colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { $0.cgColor } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    private static func white(_ a: CGFloat) -> UIColor { UIColor(white: 1, alpha: a) }

    // MARK: Particles

    /// A round droplet with a soft rim.
    static var dot: SKTexture {
        make("dot", width: 32, height: 32, scale: 2) { ctx, s in
            radial(ctx, [white(1), white(1), white(0)], [0, 0.58, 1],
                   center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A very soft puff (foam, cloud puffs, plumes).
    static var soft: SKTexture {
        make("soft", width: 64, height: 64, scale: 1) { ctx, s in
            radial(ctx, [white(1), white(0.5), white(0)], [0, 0.42, 1],
                   center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A soft horizontal streak, brightest toward its right end (speed lines, rain, glints).
    static var streak: SKTexture {
        make("streak", width: 64, height: 10, scale: 2) { ctx, s in
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: 0, y: 0, width: s.width, height: s.height))
            ctx.clip()
            linear(ctx, [white(0), white(0.85), white(1), white(0)], [0, 0.6, 0.82, 1],
                   from: CGPoint(x: 0, y: s.height / 2), to: CGPoint(x: s.width, y: s.height / 2))
            ctx.restoreGState()
        }
    }

    /// A four-point twinkle with a soft halo.
    static var sparkle: SKTexture {
        make("sparkle", width: 48, height: 48, scale: 2) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            radial(ctx, [white(0.55), white(0)], [0, 1], center: c, radius: s.width * 0.32)
            let r = s.width * 0.48, k = s.width * 0.07
            ctx.move(to: CGPoint(x: c.x, y: c.y - r))
            ctx.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
            ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
            ctx.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
            ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
            ctx.closePath()
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillPath()
        }
    }

    /// A large soft radial glow (sun, flare, lamp, lightning).
    static var glow: SKTexture {
        make("glow", width: 128, height: 128, scale: 2) { ctx, s in
            radial(ctx, [white(1), white(0.42), white(0.12), white(0)], [0, 0.22, 0.55, 1],
                   center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// The sun's disk: a bright core with a soft edge.
    static var disk: SKTexture {
        make("disk", width: 96, height: 96, scale: 2) { ctx, s in
            radial(ctx, [white(1), white(1), white(0)], [0, 0.8, 1],
                   center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A puffy cloud (white, tinted by the sprite colour).
    static var cloud: SKTexture {
        make("cloud", width: 256, height: 112, scale: 1) { ctx, _ in
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(60, 66, 38), (100, 50, 48), (150, 46, 52), (196, 60, 40),
                                                        (128, 74, 42), (82, 80, 30), (176, 80, 32), (36, 78, 22),
                                                        (222, 76, 24)]
            for p in puffs {
                radial(ctx, [white(0.95), white(0.75), white(0)], [0, 0.55, 1],
                       center: CGPoint(x: p.0, y: p.1), radius: p.2)
            }
        }
    }

    /// A vertical gradient, `colors` top → bottom (sky, sea fill).
    static func verticalGradient(key: String, colors: [UIColor], locations: [CGFloat]) -> SKTexture {
        make("v-\(key)", width: 4, height: 256, scale: 1) { ctx, s in
            linear(ctx, colors, locations, from: CGPoint(x: 2, y: 0), to: CGPoint(x: 2, y: s.height))
        }
    }

    /// A horizontal gradient, `colors` left → right.
    static func horizontalGradient(key: String, colors: [UIColor], locations: [CGFloat]) -> SKTexture {
        make("h-\(key)", width: 256, height: 4, scale: 1) { ctx, s in
            linear(ctx, colors, locations, from: CGPoint(x: 0, y: 2), to: CGPoint(x: s.width, y: 2))
        }
    }

    /// A trail segment: flat along its length, soft across it (sprites chained along the path, so the trail tapers and
    /// fades without rebuilding a path).
    static var ribbon: SKTexture {
        make("ribbon", width: 32, height: 16, scale: 2) { ctx, s in
            linear(ctx, [white(0), white(0.7), white(1), white(0.7), white(0)], [0, 0.28, 0.5, 0.72, 1],
                   from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
        }
    }

    /// A rain sheet hanging from the storm's base: streaks inside a soft column with soft ends (ART §3: α 0 → 1 over
    /// the top 30 %, back to 0 over the bottom 15 %, never a hard rectangle).
    static var rainSheet: SKTexture {
        make("rainsheet2", width: 64, height: 256, scale: 1) { ctx, s in
            var rng = SceneRNG(seed: 0x5EE7_0A)
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 8, y: 0, width: s.width - 16, height: s.height))
            linear(ctx, [white(0), white(0.16), white(0.16), white(0)], [0, 0.3, 0.85, 1], from: CGPoint(x: 0, y: 0),
                   to: CGPoint(x: 0, y: s.height))
            ctx.restoreGState()
            for _ in 0..<26 {
                let x = rng.range(6, s.width - 6)
                let w = rng.range(1, 2.5)
                let y0 = s.height * rng.range(0, 0.25)
                let len = s.height * rng.range(0.5, 0.75)
                ctx.saveGState()
                ctx.clip(to: CGRect(x: x, y: y0, width: w, height: len))
                linear(ctx, [white(0), white(0.5), white(0.5), white(0)], [0, 0.3, 0.8, 1], from: CGPoint(x: 0, y: y0),
                       to: CGPoint(x: 0, y: y0 + len))
                ctx.restoreGState()
            }
        }
    }

    /// The sun's glitter column on the far water (ART §3): dashes 6–28 × 1.5 pt whose spacing grows downward.
    static var glitter: SKTexture {
        make("glitter2", width: 112, height: 160, scale: 1) { ctx, s in
            var rng = SceneRNG(seed: 0x611_77E2)
            var y: CGFloat = 1
            var gap: CGFloat = 2
            while y < s.height {
                let k = y / s.height
                let n = 1 + Int(rng.unit() * 2.5)
                for _ in 0..<n {
                    let w = 6 + rng.unit() * 22 * (1 - k * 0.6)
                    let x = s.width / 2 + (rng.unit() - 0.5) * s.width * (0.35 + 0.6 * k)
                    ctx.setFillColor(UIColor(white: 1, alpha: (1 - k) * 0.9).cgColor)
                    ctx.fill(CGRect(x: x - w / 2, y: y, width: w, height: 1.5))
                }
                y += gap + 1.5
                gap *= 1.13
            }
        }
    }

    /// The sky (ART-S1): five fixed stops (0, 0.45, 0.80, 0.96, 1.0) with ±1/255 dither against banding.
    static func sky(key: String, colors: [UIColor]) -> SKTexture {
        make("sky5-" + key, width: 32, height: 512, scale: 1) { ctx, s in
            linear(ctx, colors, [0, 0.45, 0.80, 0.96, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            var rng = SceneRNG(seed: 0xD1_7E2)
            let light = UIColor(white: 1, alpha: 1.0 / 255.0)
            let dark = UIColor(white: 0, alpha: 1.0 / 255.0)
            var y: CGFloat = 0
            while y < s.height {
                var x: CGFloat = 0
                while x < s.width {
                    let v = rng.unit()
                    if v < 0.33 {
                        ctx.setFillColor(light.cgColor)
                        ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    } else if v > 0.67 {
                        ctx.setFillColor(dark.cgColor)
                        ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                    x += 1
                }
                y += 1
            }
        }
    }

    /// A thin, flat-bottomed cloud streak lit from below (ART-S3; no puffballs, they make the mud). R4 (REVIEW-3 juror
    /// #7): a 3-stop vertical profile and long alpha ramps at both ends, so a streak never ends in a hard rectangle.
    static var cloudStreak: SKTexture {
        make("cloudstreak2", width: 400, height: 36, scale: 1) { ctx, s in
            var rng = SceneRNG(seed: 0xC10_0D5)
            let base = s.height - 6
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: s.width, height: base))
            for i in 0..<6 {
                let cx = s.width * (0.24 + 0.52 * CGFloat(i) / 5) + rng.range(-12, 12)
                let rx = rng.range(40, 64)
                let ry = rng.range(9, 14)
                ctx.saveGState()
                ctx.translateBy(x: cx, y: base)
                ctx.scaleBy(x: rx / ry, y: 1)
                radial(ctx, [white(0.75), white(0.45), white(0)], [0, 0.6, 1], center: .zero, radius: ry * 1.6)
                ctx.restoreGState()
            }
            ctx.restoreGState()
            // The lit underside.
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: base - 4, width: s.width, height: 4))
            linear(ctx, [white(0.9), white(0.9)], [0, 1], from: CGPoint(x: 0, y: base), to: CGPoint(x: s.width, y: base))
            ctx.restoreGState()
            // Feather both ends (≈ 120 pt on a 400-pt streak) and the top: multiply the alpha down.
            ctx.saveGState()
            ctx.setBlendMode(.destinationIn)
            linear(ctx, [white(0), white(1), white(1), white(0)], [0, 0.3, 0.7, 1],
                   from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            ctx.restoreGState()
        }
    }

    /// A storm lobe (REVIEW-3: billowing, not tyres): a nearly solid disc with a soft rim, lit from the upper right
    /// (the sun ahead) and darker below, so overlapping lobes read as volume. Tinted by the sprite colour.
    static var stormLobe: SKTexture {
        make("stormlobe", width: 128, height: 128, scale: 2) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            radial(ctx, [white(1), white(1), white(0.85), white(0)], [0, 0.62, 0.8, 1], center: c, radius: s.width / 2)
            ctx.saveGState()
            ctx.setBlendMode(.sourceAtop)
            linear(ctx, [UIColor(white: 1, alpha: 0), UIColor(white: 0, alpha: 0.28)], [0.35, 1],
                   from: CGPoint(x: s.width * 0.7, y: 0), to: CGPoint(x: s.width * 0.3, y: s.height))
            ctx.restoreGState()
        }
    }

    /// A hard water drop (ART §5): a crisp disc with a 1 px darker underside (the sprite colour tints it).
    static var drop: SKTexture {
        make("drop", width: 16, height: 16, scale: 2) { ctx, s in
            let r = CGRect(x: 2, y: 2, width: s.width - 4, height: s.height - 4)
            ctx.setFillColor(UIColor(white: 0.72, alpha: 1).cgColor)
            ctx.fillEllipse(in: r)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: r.insetBy(dx: 0.6, dy: 0).offsetBy(dx: 0, dy: -1.2))
        }
    }

    /// A short glint dash, 18 × 2, soft-ended (the water's glints; the 4-point stars are kept for the Perfect).
    static var dash: SKTexture {
        make("dash", width: 36, height: 6, scale: 2) { ctx, s in
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: 0, y: 1, width: s.width, height: s.height - 2))
            ctx.clip()
            linear(ctx, [white(0), white(1), white(1), white(0)], [0, 0.3, 0.7, 1],
                   from: CGPoint(x: 0, y: s.height / 2), to: CGPoint(x: s.width, y: s.height / 2))
            ctx.restoreGState()
        }
    }

    /// A soft vertical band (alpha 0 → 1 → 0 top to bottom): the horizon haze.
    static var band: SKTexture {
        make("band", width: 4, height: 64, scale: 1) { ctx, s in
            linear(ctx, [white(0), white(1), white(0)], [0, 0.5, 1], from: CGPoint(x: 0, y: 0),
                   to: CGPoint(x: 0, y: s.height))
        }
    }

    /// A lighthouse beam: a cone from its apex (left) fading out to the right.
    static var beam: SKTexture {
        make("beam", width: 256, height: 96, scale: 1) { ctx, s in
            ctx.saveGState()
            ctx.move(to: CGPoint(x: 0, y: s.height * 0.44))
            ctx.addLine(to: CGPoint(x: s.width, y: 0))
            ctx.addLine(to: CGPoint(x: s.width, y: s.height))
            ctx.addLine(to: CGPoint(x: 0, y: s.height * 0.56))
            ctx.closePath()
            ctx.clip()
            linear(ctx, [white(0.9), white(0.35), white(0)], [0, 0.45, 1],
                   from: CGPoint(x: 0, y: s.height / 2), to: CGPoint(x: s.width, y: s.height / 2))
            ctx.restoreGState()
        }
    }

    /// Stars for dark skies, denser toward the top.
    static var stars: SKTexture {
        make("stars", width: 512, height: 288, scale: 1) { ctx, s in
            var rng = SceneRNG(seed: 0x57A2_5)
            for _ in 0..<140 {
                let v = rng.unit()
                let y = v * v * s.height
                let x = rng.unit() * s.width
                let r = 0.5 + rng.unit() * 1.1
                ctx.setFillColor(UIColor(white: 1, alpha: 0.35 + 0.65 * rng.unit()).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
    }

    /// Aurora curtains (Northern Lights sky, ART §3): two additive ribbons #48E6A8 → #7A6CFF.
    static var aurora: SKTexture {
        make("aurora2", width: 512, height: 256, scale: 1) { ctx, _ in
            let green = UIColor(red: 0x48 / 255.0, green: 0xE6 / 255.0, blue: 0xA8 / 255.0, alpha: 0.5)
            let violet = UIColor(red: 0x7A / 255.0, green: 0x6C / 255.0, blue: 1.0, alpha: 0.35)
            for k in 0..<2 {
                let kf = CGFloat(k)
                var x: CGFloat = 0
                while x < 512 {
                    let top = 36 + 40 * kf + 24 * sin(x * 0.017 + kf * 1.9) + 10 * sin(x * 0.051 + kf)
                    let len = 70 + 30 * sin(x * 0.023 + kf * 2.3)
                    ctx.saveGState()
                    ctx.clip(to: CGRect(x: x, y: top, width: 3, height: len))
                    linear(ctx, [violet.withAlphaComponent(0), violet, green, green.withAlphaComponent(0)],
                           [0, 0.25, 0.75, 1], from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: top + len))
                    ctx.restoreGState()
                    x += 3
                }
            }
        }
    }

    /// The crease's horizon glint: a tall soft ellipse, brightest at its centre.
    static var creaseGlint: SKTexture {
        make("crease", width: 48, height: 256, scale: 1) { ctx, s in
            ctx.saveGState()
            ctx.scaleBy(x: 1, y: s.height / s.width)
            radial(ctx, [white(1), white(0.35), white(0)], [0, 0.4, 1],
                   center: CGPoint(x: s.width / 2, y: s.width / 2), radius: s.width / 2)
            ctx.restoreGState()
        }
    }
}
