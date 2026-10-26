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

    /// The Perfect / Tailwind gold.
    static let gold = RGBA(1.0, 0.80, 0.32)
    static let paleGold = RGBA(1.0, 0.93, 0.66)
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

    /// The storm's cloud wall: solid on the left, a billowing edge on the right, darker at the top.
    static func stormWall(key: String, dark: UIColor, base: UIColor, light: UIColor) -> SKTexture {
        make("storm-\(key)", width: 320, height: 480, scale: 1) { ctx, s in
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: 205, height: s.height))
            linear(ctx, [dark, base, base], [0, 0.55, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            ctx.restoreGState()
            var rng = SceneRNG(seed: 0x57_0F_A1)
            var y: CGFloat = -24
            while y < s.height + 30 {
                let r = rng.range(36, 74)
                let cx = rng.range(186, 246)
                let col = y < s.height * 0.45 ? dark : base
                radial(ctx, [col, col, col.withAlphaComponent(0)], [0, 0.8, 1], center: CGPoint(x: cx, y: y), radius: r)
                // A lit upper rim on each billow.
                radial(ctx, [light.withAlphaComponent(0.35), light.withAlphaComponent(0)], [0, 1],
                       center: CGPoint(x: cx + r * 0.15, y: y - r * 0.35), radius: r * 0.55)
                y += rng.range(22, 40)
            }
            for _ in 0..<12 {
                let r = rng.range(10, 22)
                radial(ctx, [base.withAlphaComponent(0.45), base.withAlphaComponent(0)], [0, 1],
                       center: CGPoint(x: rng.range(250, 300), y: rng.range(0, s.height)), radius: r)
            }
        }
    }

    /// The sun's glitter path on the far water: short dashes, dense at the horizon.
    static var glitter: SKTexture {
        make("glitter", width: 96, height: 192, scale: 1) { ctx, s in
            var rng = SceneRNG(seed: 0x611_77E2)
            for _ in 0..<80 {
                let v = rng.unit()
                let y = v * v * s.height
                let k = y / s.height
                let w = 4 + rng.unit() * 18 * (1 - k * 0.5)
                let x = s.width / 2 + (rng.unit() - 0.5) * s.width * (0.3 + 0.7 * k)
                ctx.setFillColor(UIColor(white: 1, alpha: (1 - k) * 0.9).cgColor)
                ctx.fill(CGRect(x: x - w / 2, y: y, width: w, height: 1.6))
            }
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

    /// Aurora curtains (Northern Lights sky): green below fading to violet above.
    static var aurora: SKTexture {
        make("aurora", width: 512, height: 256, scale: 1) { ctx, _ in
            let green = UIColor(red: 0.35, green: 1.0, blue: 0.72, alpha: 0.42)
            let violet = UIColor(red: 0.62, green: 0.42, blue: 1.0, alpha: 0.22)
            for k in 0..<3 {
                let kf = CGFloat(k)
                var x: CGFloat = 0
                while x < 512 {
                    let top = 30 + 34 * kf + 24 * sin(x * 0.017 + kf * 1.9) + 10 * sin(x * 0.051 + kf)
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
