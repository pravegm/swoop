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

/// The front-on title bird whose wings span the whole canvas width, tucking with the hinge.
struct TitleBirdView: View {
    let bird: Bird
    let tuck: Double

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let parts = BirdArt.titlePath(for: bird, tuck: min(max(tuck, 0), 1), width: size.width,
                                          height: size.height)
            let transform = BirdDrawing.fit([parts.body.boundingBoxOfPath, parts.leftWing.boundingBoxOfPath,
                                             parts.rightWing.boundingBoxOfPath],
                                            in: size, flipY: BirdDrawing.titleFlipsY)
            let left = Path(parts.leftWing).applying(transform)
            let right = Path(parts.rightWing).applying(transform)
            let body = Path(parts.body).applying(transform)
            let wing = BirdDrawing.color(bird.wing)
            let tip = BirdDrawing.color(bird.wingTip)
            let mid = size.width / 2
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8))
                layer.fill(left, with: .linearGradient(Gradient(colors: [tip, wing, wing]),
                                                       startPoint: CGPoint(x: 0, y: 0),
                                                       endPoint: CGPoint(x: mid, y: 0)))
                layer.fill(right, with: .linearGradient(Gradient(colors: [wing, wing, tip]),
                                                        startPoint: CGPoint(x: mid, y: 0),
                                                        endPoint: CGPoint(x: size.width, y: 0)))
                layer.fill(body, with: .color(BirdDrawing.color(bird.body)))
            }
            // A soft rim light on the leading edges.
            context.stroke(left, with: .color(Color.white.opacity(0.18)), lineWidth: 1.5)
            context.stroke(right, with: .color(Color.white.opacity(0.18)), lineWidth: 1.5)
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
            // QA-1 P2-5: fit once to a fixed reference pose (spread, no flap), so the bird never "breathes" as its
            // wings move.
            let ref = BirdArt.path(for: bird, tuck: 0, flap: 0)
            let transform = BirdDrawing.fit([ref.body.boundingBoxOfPath, ref.nearWing.boundingBoxOfPath,
                                             ref.farWing.boundingBoxOfPath, ref.beak.boundingBoxOfPath],
                                            in: size, flipY: BirdDrawing.sideViewFlipsY, fill: fill)
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
            }
        }
        .accessibilityHidden(true)
    }
}
