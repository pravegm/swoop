import SwiftUI

/// Draws Scene's `BirdArt` paths in SwiftUI (Home's title bird, the Birds screen), so the menus and the flight share one
/// art source.
///
/// Coordinate assumptions (design/notes/app-R1.md NEEDS): `titlePath(…width:height:)` is in a box of that size with
/// SwiftUI's origin (top-left, y down); `path(for:…)` is in a unit box with a centre origin, y up (CoreGraphics /
/// SpriteKit), facing +x. If a path comes back outside its box it is fitted into the canvas anyway.
enum BirdDrawing {
    /// Flip the side-view bird's y (unit box, y up → SwiftUI y down).
    static let sideViewFlipsY = true
    /// Flip the title bird's y (false: it is already in SwiftUI's y-down box).
    static let titleFlipsY = false

    /// A transform that fits `paths`' union into `size` (centred, ≤ `fill` of the box) only when they don't already
    /// sit inside it. Pure.
    static func fit(_ boxes: [CGRect], in size: CGSize, flipY: Bool, fill: CGFloat = 0.96) -> CGAffineTransform {
        let union = boxes.filter { !$0.isNull && !$0.isEmpty }.reduce(CGRect.null) { $0.union($1) }
        guard !union.isNull, union.width > 0, union.height > 0, size.width > 0, size.height > 0 else {
            return .identity
        }
        let tolerance = max(size.width, size.height) * 0.05
        let inside = union.minX >= -tolerance && union.minY >= -tolerance
            && union.maxX <= size.width + tolerance && union.maxY <= size.height + tolerance
            && union.width >= size.width * 0.25
        if inside && !flipY { return .identity }
        let s = min(size.width * fill / union.width, size.height * fill / union.height)
        let sy = flipY ? -s : s
        // Map the union's centre to the canvas centre.
        let cx = union.midX
        let cy = union.midY
        return CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: s, y: sy)
            .translatedBy(x: -cx, y: -cy)
    }

    static func color(_ c: RGBA) -> Color { Color(swoopRGBA: c) }
}

/// The dorsal title bird (ART §7, A7) whose wings span 92 % of the canvas, tucking with the hinge: wings shaded along the
/// chord (lit leading edge), the white trailing band, black primaries (`#2B2F36`) with two white mirrors, the gold beak
/// and its darker spot, one soft drop shadow. All layers come from Scene's `BirdArt.titlePath` / `titleDetail`.
struct TitleBirdView: View {
    let bird: Bird
    let tuck: Double

    static let primaries = Color(swoopHex: 0x2B2F36)
    static let beak = Color(swoopHex: 0xF2B33D)
    static let beakSpot = Color(swoopHex: 0xD8862A)

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let u = min(max(tuck, 0), 1)
            let parts = BirdArt.titlePath(for: bird, tuck: u, width: size.width, height: size.height)
            let detail = BirdArt.titleDetail(for: bird, tuck: u, width: size.width, height: size.height)
            let transform = BirdDrawing.fit([parts.body.boundingBoxOfPath, parts.leftWing.boundingBoxOfPath,
                                             parts.rightWing.boundingBoxOfPath],
                                            in: size, flipY: BirdDrawing.titleFlipsY)
            func p(_ cg: CGPath) -> Path { Path(cg).applying(transform) }
            let left = p(parts.leftWing)
            let right = p(parts.rightWing)
            let body = p(parts.body)
            let wing = BirdDrawing.color(bird.wing)
            let shade = BirdDrawing.color(bird.wing.mixed(with: RGBA(0, 0, 0), 0.18))
            let lit = BirdDrawing.color(bird.wing.mixed(with: RGBA(1, 1, 1), 0.14))
            let box = left.boundingRect.union(right.boundingRect)
            // Vertical chord shading: the leading edge (top) catches the light, the trailing edge falls into shade.
            let chord = GraphicsContext.Shading.linearGradient(Gradient(colors: [lit, wing, shade]),
                                                               startPoint: CGPoint(x: box.midX, y: box.minY),
                                                               endPoint: CGPoint(x: box.midX, y: box.maxY))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: SwoopTheme.shadowBase.opacity(0.40), radius: 12, x: 0, y: 8))
                layer.fill(left, with: chord)
                layer.fill(right, with: chord)
                layer.fill(body, with: .color(BirdDrawing.color(bird.body)))
            }
            context.fill(p(detail.leftBand), with: .color(Color.white.opacity(0.92)))
            context.fill(p(detail.rightBand), with: .color(Color.white.opacity(0.92)))
            context.fill(p(detail.leftPrimaries), with: .color(Self.primaries))
            context.fill(p(detail.rightPrimaries), with: .color(Self.primaries))
            context.fill(p(detail.leftMirrors), with: .color(Color.white))
            context.fill(p(detail.rightMirrors), with: .color(Color.white))
            context.fill(p(detail.beak), with: .color(Self.beak))
            context.fill(p(detail.beakLower), with: .color(Self.beakSpot))
            context.fill(p(detail.beakSpot), with: .color(Self.beakSpot))
            // Scene R4: a visible head contour (ink at 45 %), and a stronger lit leading edge (juror R3 #25).
            context.stroke(p(detail.headContour), with: .color(SwoopTheme.ink.opacity(0.45)), lineWidth: 1)
            context.stroke(left, with: .color(Color.white.opacity(0.3)), lineWidth: 1.2)
            context.stroke(right, with: .color(Color.white.opacity(0.3)), lineWidth: 1.2)
        }
        .accessibilityHidden(true)
    }
}

/// The side-view bird (Birds screen tiles and preview), wings at `tuck`, idle `flap` phase.
struct BirdSideView: View {
    let bird: Bird
    var tuck: Double = 0
    var flap: Double = 0
    /// Locked birds show as a silhouette.
    var silhouette: Bool = false

    /// How much of the box the reference pose fills (room left for the wings to flap and tuck).
    var fill: CGFloat = 0.72

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let parts = BirdArt.path(for: bird, tuck: tuck, flap: flap)
            // Scene R5: one transform that fits every flap and tuck pose (the Gull's wing never clips), at most 2.2 ×
            // the in-game size, centred at 58 % of the height. Fixed per bird, so it never "breathes" (QA-1 P2-5).
            let transform = BirdArt.previewTransform(for: bird, in: size)
            let far = Path(parts.farWing).applying(transform)
            let body = Path(parts.body).applying(transform)
            let near = Path(parts.nearWing).applying(transform)
            let beak = Path(parts.beak).applying(transform)
            if silhouette {
                let shade = Color(swoopHex: 0x01070D).opacity(0.85)
                context.fill(far, with: .color(shade))
                context.fill(body, with: .color(shade))
                context.fill(near, with: .color(shade))
                context.fill(beak, with: .color(shade))
                context.stroke(body, with: .color(SwoopTheme.foam.opacity(0.12)), lineWidth: 1)
            } else {
                let wing = BirdDrawing.color(bird.wing)
                let tip = BirdDrawing.color(bird.wingTip)
                context.fill(far, with: .color(BirdDrawing.color(bird.wing.mixed(with: RGBA(0, 0, 0), 0.3))))
                context.fill(body, with: .color(BirdDrawing.color(bird.body)))
                let box = near.boundingRect
                context.fill(near, with: .linearGradient(Gradient(colors: [wing, tip]),
                                                         startPoint: CGPoint(x: box.midX, y: box.maxY),
                                                         endPoint: CGPoint(x: box.midX, y: box.minY)))
                context.fill(beak, with: .color(BirdDrawing.color(bird.beak)))
                if BirdArt.isDark(bird) {
                    // Scene R5: dark birds (the Storm Petrel) get a pale key rim so they read on navy.
                    let rim = BirdDrawing.color(BirdArt.previewKeyRim)
                    context.stroke(body, with: .color(rim), lineWidth: 1.5)
                    context.stroke(near, with: .color(rim), lineWidth: 1.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
