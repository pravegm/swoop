import SwiftUI

/// The App Store icon: a white seabird with its wings raised in a V, gliding over a golden swell on a deep night-blue
/// sea, with a warm glow on the horizon and the faintest Duo fold down the middle.
///
/// Pure vector in a 1024-unit design space (no text, no symbols, no images), full-bleed, opaque and square-cornered:
/// the system applies the mask. Rendered to Documents/AppIcon-1024.png by demo `screen=icon` (IconExport).
struct AppIconArt: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                let scale = min(size.width, size.height) / 1024
                context.scaleBy(x: scale, y: scale)
                AppIconPainter.paint(&context)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum AppIconPainter {
    static let night = Color(swoopHex: 0x061A30)
    static let deep = Color(swoopHex: 0x0B2C4D)
    static let dusk = Color(swoopHex: 0x1C4A73)
    static let glow = Color(swoopHex: 0xFFC765)
    static let goldTop = Color(swoopHex: 0xFFD978)
    static let gold = Color(swoopHex: 0xF2B140)
    static let goldDeep = Color(swoopHex: 0xB8741E)
    static let farSwell = Color(swoopHex: 0x163E63)
    static let white = Color(swoopHex: 0xFBFDFF)
    static let shade = Color(swoopHex: 0xC9D9E6)
    static let beak = Color(swoopHex: 0xF6A33C)

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        stars(&ctx)
        fold(&ctx)
        farSwells(&ctx)
        goldenSwell(&ctx)
        bird(&ctx)
    }

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .linearGradient(
            Gradient(stops: [
                .init(color: night, location: 0),
                .init(color: deep, location: 0.5),
                .init(color: dusk, location: 0.72),
                .init(color: night, location: 1),
            ]),
            startPoint: CGPoint(x: 512, y: 0), endPoint: CGPoint(x: 512, y: 1024)))
        // The warm glow of the clear sky on the horizon.
        ctx.fill(all, with: .radialGradient(
            Gradient(colors: [glow.opacity(0.55), glow.opacity(0.12), glow.opacity(0)]),
            center: CGPoint(x: 560, y: 700), startRadius: 0, endRadius: 560))
    }

    static func stars(_ ctx: inout GraphicsContext) {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (132, 140, 5), (248, 86, 3.5), (402, 168, 4), (612, 92, 3), (760, 150, 5), (890, 230, 3.5),
            (84, 330, 3), (930, 96, 4), (340, 262, 2.5), (690, 260, 2.5),
        ]
        for (x, y, r) in points {
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                     with: .color(white.opacity(0.55)))
        }
    }

    /// The Duo's fold: a faint vertical glint down the middle.
    static func fold(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 496, y: 0, width: 32, height: 1024)), with: .linearGradient(
            Gradient(colors: [white.opacity(0), white.opacity(0.06), white.opacity(0)]),
            startPoint: CGPoint(x: 496, y: 0), endPoint: CGPoint(x: 528, y: 0)))
    }

    static func farSwells(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 742))
        p.addCurve(to: CGPoint(x: 420, y: 700), control1: CGPoint(x: 140, y: 720), control2: CGPoint(x: 300, y: 690))
        p.addCurve(to: CGPoint(x: 1024, y: 690), control1: CGPoint(x: 620, y: 716), control2: CGPoint(x: 860, y: 664))
        p.addLine(to: CGPoint(x: 1024, y: 1024))
        p.addLine(to: CGPoint(x: 0, y: 1024))
        p.closeSubpath()
        ctx.fill(p, with: .linearGradient(Gradient(colors: [farSwell, night]),
                                          startPoint: CGPoint(x: 512, y: 680), endPoint: CGPoint(x: 512, y: 1000)))
    }

    /// The swell the bird rides: a long golden face rising to a crest on the right.
    static func swellPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -20, y: 900))
        p.addCurve(to: CGPoint(x: 600, y: 746), control1: CGPoint(x: 200, y: 900), control2: CGPoint(x: 420, y: 760))
        p.addCurve(to: CGPoint(x: 1044, y: 830), control1: CGPoint(x: 780, y: 734), control2: CGPoint(x: 900, y: 790))
        p.addLine(to: CGPoint(x: 1044, y: 1044))
        p.addLine(to: CGPoint(x: -20, y: 1044))
        p.closeSubpath()
        return p
    }

    static func goldenSwell(_ ctx: inout GraphicsContext) {
        let p = swellPath()
        ctx.fill(p, with: .linearGradient(Gradient(stops: [
            .init(color: goldTop, location: 0),
            .init(color: gold, location: 0.35),
            .init(color: goldDeep, location: 1),
        ]), startPoint: CGPoint(x: 600, y: 740), endPoint: CGPoint(x: 600, y: 1024)))
        // The crest's foam line.
        var crest = Path()
        crest.move(to: CGPoint(x: 150, y: 870))
        crest.addCurve(to: CGPoint(x: 600, y: 746), control1: CGPoint(x: 300, y: 836), control2: CGPoint(x: 440, y: 758))
        crest.addCurve(to: CGPoint(x: 960, y: 800), control1: CGPoint(x: 760, y: 736), control2: CGPoint(x: 880, y: 770))
        ctx.stroke(crest, with: .color(white.opacity(0.75)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        // A soft sheen across the face.
        var sheen = Path()
        sheen.move(to: CGPoint(x: 330, y: 880))
        sheen.addCurve(to: CGPoint(x: 760, y: 820), control1: CGPoint(x: 470, y: 840), control2: CGPoint(x: 620, y: 812))
        ctx.stroke(sheen, with: .color(white.opacity(0.22)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        // REVIEW-1 P2: water, not a dune — wave lines on the face and a curling foam lip at the crest.
        for (i, y) in [CGFloat(905), 950, 990].enumerated() {
            var line = Path()
            let x0 = 120 + CGFloat(i) * 70
            line.move(to: CGPoint(x: x0, y: y))
            line.addCurve(to: CGPoint(x: x0 + 520, y: y - 40), control1: CGPoint(x: x0 + 170, y: y - 30),
                          control2: CGPoint(x: x0 + 340, y: y - 10))
            ctx.stroke(line, with: .color(goldDeep.opacity(0.55)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        var lip = Path()
        lip.move(to: CGPoint(x: 500, y: 762))
        lip.addQuadCurve(to: CGPoint(x: 640, y: 732), control: CGPoint(x: 560, y: 726))
        lip.addQuadCurve(to: CGPoint(x: 694, y: 772), control: CGPoint(x: 690, y: 736))
        lip.addQuadCurve(to: CGPoint(x: 652, y: 758), control: CGPoint(x: 670, y: 752))
        lip.addQuadCurve(to: CGPoint(x: 500, y: 762), control: CGPoint(x: 572, y: 748))
        lip.closeSubpath()
        ctx.fill(lip, with: .color(white.opacity(0.92)))
        let drops: [(CGFloat, CGFloat, CGFloat)] = [(712, 760, 7), (730, 778, 5), (700, 790, 4), (676, 724, 5)]
        for (x, y, r) in drops {
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                     with: .color(white.opacity(0.85)))
        }
    }

    /// The right wing (from the shoulder up and out to the tip, a gull's gentle M); the left is its mirror.
    static func rightWing() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 534, y: 452))
        // Leading edge: shoulder → wrist → tip
        p.addCurve(to: CGPoint(x: 700, y: 392), control1: CGPoint(x: 590, y: 420), control2: CGPoint(x: 650, y: 384))
        p.addCurve(to: CGPoint(x: 902, y: 236), control1: CGPoint(x: 780, y: 360), control2: CGPoint(x: 860, y: 280))
        // Trailing edge: tip → back to the body
        p.addCurve(to: CGPoint(x: 730, y: 446), control1: CGPoint(x: 866, y: 330), control2: CGPoint(x: 800, y: 420))
        p.addCurve(to: CGPoint(x: 540, y: 500), control1: CGPoint(x: 660, y: 470), control2: CGPoint(x: 590, y: 476))
        p.closeSubpath()
        return p
    }

    static func bird(_ ctx: inout GraphicsContext) {
        let right = rightWing()
        let mirror = CGAffineTransform(translationX: 1024, y: 0).scaledBy(x: -1, y: 1)
        let left = right.applying(mirror)
        // Shadow on the swell below.
        ctx.fill(Path(ellipseIn: CGRect(x: 392, y: 772, width: 240, height: 26)),
                 with: .color(goldDeep.opacity(0.35)))
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12))
            // White wings that darken smoothly to slate primaries at the tips (no hard-edged tip band: REVIEW-1 P2).
            let tipGradient = Gradient(stops: [
                .init(color: white, location: 0),
                .init(color: shade, location: 0.62),
                .init(color: Color(swoopHex: 0x3B4F63), location: 1),
            ])
            layer.fill(right, with: .linearGradient(tipGradient, startPoint: CGPoint(x: 540, y: 470),
                                                    endPoint: CGPoint(x: 902, y: 236)))
            layer.fill(left, with: .linearGradient(tipGradient, startPoint: CGPoint(x: 484, y: 470),
                                                   endPoint: CGPoint(x: 122, y: 236)))
            // Body: a soft front-on teardrop.
            var body = Path()
            body.move(to: CGPoint(x: 512, y: 402))
            body.addCurve(to: CGPoint(x: 548, y: 500), control1: CGPoint(x: 542, y: 410), control2: CGPoint(x: 552, y: 460))
            body.addCurve(to: CGPoint(x: 512, y: 578), control1: CGPoint(x: 546, y: 540), control2: CGPoint(x: 530, y: 570))
            body.addCurve(to: CGPoint(x: 476, y: 500), control1: CGPoint(x: 494, y: 570), control2: CGPoint(x: 478, y: 540))
            body.addCurve(to: CGPoint(x: 512, y: 402), control1: CGPoint(x: 472, y: 460), control2: CGPoint(x: 482, y: 410))
            body.closeSubpath()
            layer.fill(body, with: .color(white))
            // Head
            layer.fill(Path(ellipseIn: CGRect(x: 486, y: 378, width: 52, height: 52)), with: .color(white))
        }

        // Beak, pointing down at us.
        var bill = Path()
        bill.move(to: CGPoint(x: 500, y: 416))
        bill.addLine(to: CGPoint(x: 524, y: 416))
        bill.addLine(to: CGPoint(x: 512, y: 446))
        bill.closeSubpath()
        ctx.fill(bill, with: .color(Self.beak))
    }
}
