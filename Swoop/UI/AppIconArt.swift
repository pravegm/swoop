import SwiftUI

/// The App Store icon, ART §7 concept A "two-wing fold": the square split by a soft vertical fold, storm slate on the
/// left and a sunset on the right (the sun upper right), a dorsal gull spanning 84 % of the width with its body on the
/// fold (the halves are wings; storm against sun), and the bottom 20 % sea with a foam line. No stars, eyes or glow.
///
/// Pure vector in a 1024-unit design space, full-bleed, opaque and square-cornered: the system applies the mask.
/// Rendered to Documents/AppIcon-1024.png by demo `screen=icon` (IconExport). The bird is drawn by `bird(_:)` alone so
/// it can be exported as Icon Composer's foreground layer.
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
    static let slateTop = Color(swoopHex: 0x2A3446)
    static let slateBottom = Color(swoopHex: 0x3B4558)
    static let sunsetTop = Color(swoopHex: 0xF29A62)
    static let sunsetBottom = Color(swoopHex: 0xFFD08A)
    static let sun = Color(swoopHex: 0xFFF3D1)
    static let sea = Color(swoopHex: 0x1C5A7C)
    static let seaDeep = Color(swoopHex: 0x123F59)
    static let foam = Color(swoopHex: 0xFFF6E6)
    static let mantle = Color(swoopHex: 0x9AA5B1)
    static let primaries = Color(swoopHex: 0x2B2F36)
    static let white = Color(swoopHex: 0xFBFDFF)
    static let beak = Color(swoopHex: 0xF2B33D)
    static let beakSpot = Color(swoopHex: 0xD8862A)
    static let ink = Color(swoopHex: 0x0E2438)

    /// The horizon: the sea is the bottom 20 %.
    static let horizonY: CGFloat = 1024 * 0.80
    /// R4 P1-11 (it must read at 60 and 40 px): the gull spans 88 % (the title art spans 92 % of its box), drawn
    /// 1.45× taller than the title box so the chord (≈ 0.11 of the icon at the shoulder) and the "M" read at 40 px;
    /// a 15 px ink contour; primaries over the outer 26 %; one mirror per wing; the sun with a soft added glow.
    static let birdSpan: CGFloat = 0.88
    static let birdBox = CGSize(width: 1024 * 0.88 / 0.92, height: 300)
    static let birdStretchY: CGFloat = 1.45
    static let birdTop: CGFloat = 250
    static let contour: CGFloat = 15
    static let primariesFraction: CGFloat = 0.26
    /// Test renders for the small-size check (CI `screen=icon` writes AppIcon-<n>.png for each).
    static let testSizes: [CGFloat] = [180, 60, 40]

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        seaBand(&ctx)
        fold(&ctx)
        bird(&ctx)
    }

    static func background(_ ctx: inout GraphicsContext) {
        let left = Path(CGRect(x: 0, y: 0, width: 512, height: horizonY))
        ctx.fill(left, with: .linearGradient(Gradient(colors: [slateTop, slateBottom]),
                                            startPoint: CGPoint(x: 256, y: 0), endPoint: CGPoint(x: 256, y: horizonY)))
        let right = Path(CGRect(x: 512, y: 0, width: 512, height: horizonY))
        ctx.fill(right, with: .linearGradient(Gradient(colors: [sunsetTop, sunsetBottom]),
                                             startPoint: CGPoint(x: 768, y: 0), endPoint: CGPoint(x: 768, y: horizonY)))
        // The sun, upper right, with a soft additive glow of `#FFC46B` at 0.35 out to 1.6 × its radius.
        let sunRect = CGRect(x: 760, y: 120, width: 150, height: 150)
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.fill(Path(ellipseIn: sunRect.insetBy(dx: -45, dy: -45)),
                  with: .radialGradient(Gradient(colors: [Color(swoopHex: 0xFFC46B).opacity(0.35),
                                                          Color(swoopHex: 0xFFC46B).opacity(0)]),
                                        center: CGPoint(x: sunRect.midX, y: sunRect.midY), startRadius: 60,
                                        endRadius: 120))
        ctx.fill(Path(ellipseIn: sunRect), with: .color(sun))
    }

    static func seaBand(_ ctx: inout GraphicsContext) {
        let band = Path(CGRect(x: 0, y: horizonY, width: 1024, height: 1024 - horizonY))
        ctx.fill(band, with: .linearGradient(Gradient(colors: [sea, seaDeep]),
                                            startPoint: CGPoint(x: 512, y: horizonY), endPoint: CGPoint(x: 512, y: 1024)))
        // The foam line along the horizon, a gentle swell.
        var foamLine = Path()
        // A swell: the foam line rises gently to the right.
        foamLine.move(to: CGPoint(x: 0, y: horizonY + 14))
        foamLine.addCurve(to: CGPoint(x: 1024, y: horizonY - 10), control1: CGPoint(x: 360, y: horizonY + 18),
                          control2: CGPoint(x: 700, y: horizonY - 2))
        ctx.stroke(foamLine, with: .color(foam), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    }

    /// The fold: a 6 px highlight at 12 % next to a 6 px shadow at 18 % (never a hard line).
    static func fold(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 506, y: 0, width: 6, height: 1024)), with: .color(Color.white.opacity(0.12)))
        ctx.fill(Path(CGRect(x: 512, y: 0, width: 6, height: 1024)), with: .color(Color.black.opacity(0.18)))
    }

    /// The dorsal gull (Scene's title art), its spine on the fold, with a 1.5 % ink contour so the grey wing keeps its
    /// edge on the gold half (ΔL* ≥ 18).
    static func bird(_ ctx: inout GraphicsContext) {
        let gull = BirdCatalog.bird(.gull)
        let w = birdBox.width
        let h = birdBox.height
        let parts = BirdArt.titlePath(for: gull, tuck: 0.12, width: w, height: h)
        let detail = BirdArt.titleDetail(for: gull, tuck: 0.12, width: w, height: h)
        let t = CGAffineTransform(translationX: (1024 - w) / 2, y: birdTop).scaledBy(x: 1, y: birdStretchY)
        func p(_ cg: CGPath) -> Path { Path(cg).applying(t) }
        let left = p(parts.leftWing)
        let right = p(parts.rightWing)
        let body = p(parts.body)
        let outline = StrokeStyle(lineWidth: contour * 2, lineCap: .round, lineJoin: .round)
        ctx.stroke(left, with: .color(ink), style: outline)
        ctx.stroke(right, with: .color(ink), style: outline)
        ctx.stroke(body, with: .color(ink), style: outline)
        let box = left.boundingRect.union(right.boundingRect)
        let chord = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(swoopHex: 0xB2BCC6), mantle, Color(swoopHex: 0x8D97A3)]),
            startPoint: CGPoint(x: box.midX, y: box.minY), endPoint: CGPoint(x: box.midX, y: box.maxY))
        ctx.fill(left, with: chord)
        ctx.fill(right, with: chord)
        ctx.fill(p(detail.leftBand), with: .color(white))
        ctx.fill(p(detail.rightBand), with: .color(white))
        // Bigger primaries: the outer 26 % of each wing, clipped from the wing itself.
        let tipW = box.width * primariesFraction
        var tips = ctx
        tips.clip(to: Path(CGRect(x: box.minX, y: 0, width: tipW, height: 1024)))
        tips.fill(left, with: .color(primaries))
        var tipsR = ctx
        tipsR.clip(to: Path(CGRect(x: box.maxX - tipW, y: 0, width: tipW, height: 1024)))
        tipsR.fill(right, with: .color(primaries))
        // One white mirror per wing: only the outermost of the title art's two (two read as eyes at 60 px).
        let mirrorW = box.width * 0.04
        var mirrorL = ctx
        mirrorL.clip(to: Path(CGRect(x: box.minX, y: 0, width: mirrorW, height: 1024)))
        mirrorL.fill(p(detail.leftMirrors), with: .color(white))
        var mirrorR = ctx
        mirrorR.clip(to: Path(CGRect(x: box.maxX - mirrorW, y: 0, width: mirrorW, height: 1024)))
        mirrorR.fill(p(detail.rightMirrors), with: .color(white))
        ctx.fill(body, with: .color(white))
        ctx.fill(p(detail.beak), with: .color(beak))
        ctx.fill(p(detail.beakLower), with: .color(beakSpot))
        ctx.fill(p(detail.beakSpot), with: .color(beakSpot))
        ctx.stroke(p(detail.headContour), with: .color(ink.opacity(0.45)), lineWidth: 3)
    }
}
