import SwiftUI

/// Game Center achievement badges: one 1024 × 1024 image per achievement, in the app icon's style (AppIconArt): the
/// deep night-blue sea with a warm horizon glow, a medallion whose ring marks the tier (sea glass for the first steps,
/// gold for the big ones), and one simple white motif in the middle.
///
/// Pure vector in a 1024-unit design space, opaque, square-cornered; no text except short numerals. Rendered to
/// Documents/badges/<id>.png by demo `screen=badges` (BadgeExport in App/DemoMode.swift). Unknown ids draw the first
/// flight's bird.
struct AchievementBadge: View {
    let id: String
    var side: CGFloat = 1024

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            let scale = min(size.width, size.height) / 1024
            context.scaleBy(x: scale, y: scale)
            BadgePainter.paint(&context, id: id)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

enum BadgePainter {
    static let night = Color(swoopHex: 0x061A30)
    static let deep = Color(swoopHex: 0x0B2C4D)
    static let tide = Color(swoopHex: 0x1E5A80)
    static let glow = Color(swoopHex: 0xFFC765)
    static let gold = Color(swoopHex: 0xF2B140)
    static let goldLight = Color(swoopHex: 0xFFE3A1)
    static let goldDeep = Color(swoopHex: 0xB8741E)
    static let white = Color(swoopHex: 0xFBFDFF)
    static let slate = Color(swoopHex: 0x5B6976)

    static let center = CGPoint(x: 512, y: 512)

    enum Tier { case glass, silver, gold }

    static func tier(for id: String) -> Tier {
        switch id {
        case ProgressRules.achievementKm10, ProgressRules.achievementChain10, ProgressRules.achievementLighthouse3,
             ProgressRules.achievementAllBirds:
            return .gold
        case ProgressRules.achievementKm5, ProgressRules.achievementChain5, ProgressRules.achievementTailwind,
             ProgressRules.achievementDaily3:
            return .silver
        default:
            return .glass
        }
    }

    static func paint(_ ctx: inout GraphicsContext, id: String) {
        background(&ctx)
        medallion(&ctx, tier: tier(for: id))
        switch id {
        case ProgressRules.achievementKm1: numeral(&ctx, "1", unit: true)
        case ProgressRules.achievementKm5: numeral(&ctx, "5", unit: true)
        case ProgressRules.achievementKm10: numeral(&ctx, "10", unit: true)
        case ProgressRules.achievementChain5: chain(&ctx, links: 5)
        case ProgressRules.achievementChain10: chain(&ctx, links: 10)
        case ProgressRules.achievementTailwind: tailwind(&ctx)
        case ProgressRules.achievementLighthouse: lighthouses(&ctx, count: 1)
        case ProgressRules.achievementLighthouse3: lighthouses(&ctx, count: 3)
        case ProgressRules.achievementCloud: cloud(&ctx)
        case ProgressRules.achievementDaily3: daily(&ctx)
        case ProgressRules.achievementAllBirds: flock(&ctx)
        default: bird(&ctx, at: CGPoint(x: 512, y: 500), span: 420, color: white)
        }
    }

    // MARK: Background and medallion

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [night, deep, night]),
                                            startPoint: CGPoint(x: 512, y: 0), endPoint: CGPoint(x: 512, y: 1024)))
        // ART A9: no gold glow over navy; a cool lift only.
        ctx.fill(all, with: .radialGradient(Gradient(colors: [tide.opacity(0.35), tide.opacity(0)]),
                                            center: CGPoint(x: 512, y: 760), startRadius: 0, endRadius: 600))
    }

    static func medallion(_ ctx: inout GraphicsContext, tier: Tier) {
        let ring: Gradient
        switch tier {
        // ART badges P2: the rim by tier, bronze `#C98A5A`, silver `#C9D3DC`, gold `#F7C75B` (lit top, deeper bottom).
        case .glass: ring = Gradient(colors: [Color(swoopHex: 0xE2AE85), Color(swoopHex: 0xC98A5A),
                                              Color(swoopHex: 0x8F5E38)])
        case .silver: ring = Gradient(colors: [Color(swoopHex: 0xEEF2F5), Color(swoopHex: 0xC9D3DC),
                                               Color(swoopHex: 0x8E9AA6)])
        case .gold: ring = Gradient(colors: [Color(swoopHex: 0xFFE39A), Color(swoopHex: 0xF7C75B),
                                             Color(swoopHex: 0xC98A2A)])
        }
        let outer = CGRect(x: 512 - 400, y: 512 - 400, width: 800, height: 800)
        ctx.fill(Path(ellipseIn: outer.offsetBy(dx: 0, dy: 16)), with: .color(Color.black.opacity(0.3)))
        ctx.fill(Path(ellipseIn: outer), with: .linearGradient(ring, startPoint: CGPoint(x: 512, y: 112),
                                                                endPoint: CGPoint(x: 512, y: 912)))
        let inner = outer.insetBy(dx: 52, dy: 52)
        ctx.fill(Path(ellipseIn: inner), with: .linearGradient(Gradient(colors: [tide, deep, night]),
                                                                startPoint: CGPoint(x: 512, y: 164),
                                                                endPoint: CGPoint(x: 512, y: 860)))
        // A golden swell across the bottom of the disc.
        var inside = ctx
        inside.clip(to: Path(ellipseIn: inner))
        var swell = Path()
        swell.move(to: CGPoint(x: 100, y: 760))
        swell.addCurve(to: CGPoint(x: 924, y: 720), control1: CGPoint(x: 360, y: 660), control2: CGPoint(x: 640, y: 800))
        swell.addLine(to: CGPoint(x: 924, y: 924))
        swell.addLine(to: CGPoint(x: 100, y: 924))
        swell.closeSubpath()
        // Sea, not sand (REVIEW-1 P2): a teal swell with a gold-lit crest and a foam line.
        inside.fill(swell, with: .linearGradient(Gradient(colors: [Color(swoopHex: 0x2C6A8F), tide, night]),
                                                 startPoint: CGPoint(x: 512, y: 680), endPoint: CGPoint(x: 512, y: 900)))
        var foam = Path()
        foam.move(to: CGPoint(x: 100, y: 760))
        foam.addCurve(to: CGPoint(x: 924, y: 720), control1: CGPoint(x: 360, y: 660), control2: CGPoint(x: 640, y: 800))
        inside.stroke(foam, with: .linearGradient(Gradient(colors: [white.opacity(0.9), goldLight, white.opacity(0.9)]),
                                                  startPoint: CGPoint(x: 100, y: 0), endPoint: CGPoint(x: 924, y: 0)),
                      style: StrokeStyle(lineWidth: 12, lineCap: .round))
        if tier == .gold {
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * Double.pi
                let x = 512 + CGFloat(cos(a)) * 374
                let y = 512 + CGFloat(sin(a)) * 374
                ctx.fill(Path(ellipseIn: CGRect(x: x - 10, y: y - 10, width: 20, height: 20)),
                         with: .color(goldLight))
            }
        }
    }

    // MARK: Motifs

    /// A seabird from the front, wings in a V (the app icon's bird, simplified).
    static func bird(_ ctx: inout GraphicsContext, at c: CGPoint, span: CGFloat, color: Color) {
        let s = span / 400
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + 40 * s))
        p.addCurve(to: CGPoint(x: c.x + 200 * s, y: c.y - 110 * s), control1: CGPoint(x: c.x + 60 * s, y: c.y - 20 * s),
                   control2: CGPoint(x: c.x + 150 * s, y: c.y - 40 * s))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + 70 * s), control1: CGPoint(x: c.x + 150 * s, y: c.y + 10 * s),
                   control2: CGPoint(x: c.x + 60 * s, y: c.y + 30 * s))
        p.addCurve(to: CGPoint(x: c.x - 200 * s, y: c.y - 110 * s), control1: CGPoint(x: c.x - 60 * s, y: c.y + 30 * s),
                   control2: CGPoint(x: c.x - 150 * s, y: c.y + 10 * s))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + 40 * s), control1: CGPoint(x: c.x - 150 * s, y: c.y - 40 * s),
                   control2: CGPoint(x: c.x - 60 * s, y: c.y - 20 * s))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 26 * s, y: c.y - 6 * s, width: 52 * s, height: 96 * s)),
                 with: .color(color))
    }

    static func numeral(_ ctx: inout GraphicsContext, _ text: String, unit: Bool) {
        bird(&ctx, at: CGPoint(x: 512, y: 300), span: 200, color: white.opacity(0.9))
        ctx.draw(Text(text).font(.system(size: text.count > 1 ? 300 : 340, weight: .black, design: .rounded))
                    .foregroundColor(white),
                 at: CGPoint(x: 512, y: 520))
        if unit {
            ctx.draw(Text("km").font(.system(size: 96, weight: .heavy, design: .rounded)).foregroundColor(goldLight),
                     at: CGPoint(x: 512, y: 690))
        }
    }

    static func chain(_ ctx: inout GraphicsContext, links: Int) {
        // The game's gold Perfect rings, growing outward (REVIEW-1 P2: plain ovals read as nothing).
        let count = min(max(links, 1), 10) >= 10 ? 4 : 3
        for i in 0..<count {
            let r = CGFloat(150 + i * 70)
            let alpha = 1.0 - Double(i) * 0.22
            ctx.stroke(Path(ellipseIn: CGRect(x: 512 - r, y: 600 - r * 0.42, width: 2 * r, height: r * 0.84)),
                       with: .color(goldLight.opacity(alpha)), lineWidth: CGFloat(22 - i * 4))
        }
        ctx.draw(Text("\(links)").font(.system(size: 240, weight: .black, design: .rounded)).foregroundColor(white),
                 at: CGPoint(x: 512, y: 400))
    }
    static func tailwind(_ ctx: inout GraphicsContext) {
        bird(&ctx, at: CGPoint(x: 600, y: 470), span: 300, color: white)
        for (i, y) in [CGFloat(400), 480, 560].enumerated() {
            var line = Path()
            let x0 = 200 + CGFloat(i) * 30
            line.move(to: CGPoint(x: x0, y: y))
            line.addCurve(to: CGPoint(x: x0 + 260, y: y - 30), control1: CGPoint(x: x0 + 90, y: y + 30),
                          control2: CGPoint(x: x0 + 170, y: y - 40))
            ctx.stroke(line, with: .color(goldLight), style: StrokeStyle(lineWidth: 22, lineCap: .round))
        }
    }

    static func lighthouseShape(at base: CGPoint, height h: CGFloat) -> Path {
        let w = h * 0.42
        return LighthouseGlyph().path(in: CGRect(x: base.x - w / 2, y: base.y - h, width: w, height: h))
    }

    static func lighthouses(_ ctx: inout GraphicsContext, count: Int) {
        let bases: [CGPoint] = count >= 3
            ? [CGPoint(x: 330, y: 720), CGPoint(x: 512, y: 700), CGPoint(x: 694, y: 720)]
            : [CGPoint(x: 512, y: 720)]
        let height: CGFloat = count >= 3 ? 330 : 470
        // The beam.
        var beam = Path()
        let lampY = (bases.first?.y ?? 720) - height * 0.76
        beam.move(to: CGPoint(x: 512, y: lampY))
        beam.addLine(to: CGPoint(x: 900, y: lampY - 160))
        beam.addLine(to: CGPoint(x: 900, y: lampY + 40))
        beam.closeSubpath()
        // The beam stays inside the disc (ART badges P2).
        var disc = ctx
        disc.clip(to: Path(ellipseIn: CGRect(x: 512 - 348, y: 512 - 348, width: 696, height: 696)))
        disc.fill(beam, with: .linearGradient(Gradient(colors: [goldLight.opacity(0.85), goldLight.opacity(0)]),
                                             startPoint: CGPoint(x: 512, y: lampY), endPoint: CGPoint(x: 900, y: lampY)))
        for base in bases {
            ctx.fill(lighthouseShape(at: base, height: height), with: .color(white))
        }
    }

    static func cloud(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.addEllipse(in: CGRect(x: 250, y: 330, width: 260, height: 200))
        p.addEllipse(in: CGRect(x: 400, y: 260, width: 300, height: 260))
        p.addEllipse(in: CGRect(x: 600, y: 340, width: 200, height: 180))
        p.addRoundedRect(in: CGRect(x: 250, y: 420, width: 550, height: 110), cornerSize: CGSize(width: 55, height: 55))
        ctx.fill(p, with: .color(white))
        bird(&ctx, at: CGPoint(x: 512, y: 640), span: 240, color: goldLight)
    }

    static func daily(_ ctx: inout GraphicsContext) {
        // Three suns on the horizon: three days in a row.
        for (i, x) in [CGFloat(330), 512, 694].enumerated() {
            let r: CGFloat = i == 1 ? 92 : 72
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: 520 - r, width: 2 * r, height: 2 * r)),
                     with: .radialGradient(Gradient(colors: [goldLight, gold]), center: CGPoint(x: x, y: 520),
                                           startRadius: 0, endRadius: r))
        }
        ctx.draw(Text("3").font(.system(size: 120, weight: .black, design: .rounded)).foregroundColor(Color(swoopHex: 0x0E2438)),
                 at: CGPoint(x: 512, y: 520))
        bird(&ctx, at: CGPoint(x: 512, y: 330), span: 220, color: white)
    }

    static func flock(_ ctx: inout GraphicsContext) {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (512, 300, 230), (330, 420, 170), (694, 420, 170), (230, 560, 120), (794, 560, 120),
            (420, 580, 120), (604, 580, 120), (512, 680, 110),
        ]
        for (x, y, span) in spots {
            bird(&ctx, at: CGPoint(x: x, y: y), span: span, color: white)
        }
    }
}
