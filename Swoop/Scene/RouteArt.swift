import CoreGraphics
import Foundation

/// The route map's art (ART-FLIGHT-SCHOOL §5, SC7) in CoreGraphics only, like `BirdArt`, so SwiftUI can draw it with
/// `Path(cgPath)`. Pure functions, no UIKit / SpriteKit / actor isolation.
///
/// Coordinates: the strip's own box, origin top-left, **y down** (SwiftUI); the coast runs along the top, the sea
/// below. x runs along the strip in content points (the App scrolls it and flips the order for the flight direction).
enum RouteArt {
    /// The coast's mean line and its two sines (§5): y = 70 + 22 sin(x / 180) + 12 sin(x / 67 + 1.3).
    static let coastBase: CGFloat = 70
    /// Each lighthouse stands on a headland bulging this far seaward, over ± this half-width (raised cosine).
    static let headlandBulge: CGFloat = 30
    static let headlandHalfWidth: CGFloat = 70
    /// The route line runs this far below the headland tips.
    static let routeDrop: CGFloat = 26
    /// The depth contours' default offsets from the coast.
    static let contourOffsets: [CGFloat] = [30, 60, 100]
    /// The lighthouses' spacing by index (not by km): Duo 150, iPhone 130.
    static let spacingDuo: CGFloat = 150
    static let spacingPhone: CGFloat = 130

    // MARK: The coast

    /// The coast's y at `x` (y down), with a headland under each lighthouse x in `headlands`.
    static func coastY(at x: CGFloat, headlands: [CGFloat]) -> CGFloat {
        var y = coastBase + 22 * sin(x / 180) + 12 * sin(x / 67 + 1.3)
        for h in headlands {
            let d = abs(x - h) / headlandHalfWidth
            if d < 1 { y += headlandBulge * 0.5 * (1 + cos(CGFloat.pi * d)) }
        }
        return y
    }

    /// The tip of the headland at `x` (where its lighthouse stands).
    static func headlandTip(x: CGFloat, headlands: [CGFloat]) -> CGPoint {
        CGPoint(x: x, y: coastY(at: x, headlands: headlands))
    }

    /// The land: from the strip's top edge (`top`) down to the coast, over `0 … width`. Fill it `#34544A → #26403A`.
    static func coastPath(width: CGFloat, headlands: [CGFloat], top: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        let w = max(width, 1)
        p.move(to: CGPoint(x: 0, y: top))
        p.addLine(to: CGPoint(x: w, y: top))
        var x = w
        while x > 0 {
            p.addLine(to: CGPoint(x: x, y: coastY(at: x, headlands: headlands)))
            x -= 4
        }
        p.addLine(to: CGPoint(x: 0, y: coastY(at: 0, headlands: headlands)))
        p.closeSubpath()
        return p
    }

    /// The coastline alone, `offset` pt seaward (0: the 3 pt cliff rim `#C9B98F`; 4: the 1.5 pt foam line). Stroke it.
    static func coastline(width: CGFloat, headlands: [CGFloat], offset: CGFloat = 0) -> CGPath {
        line(width: width) { (x: CGFloat) -> CGFloat in coastY(at: x, headlands: headlands) + offset }
    }

    /// Depth contours following the coast (1 pt white at 6 %), the headlands softening with depth.
    static func contours(width: CGFloat, headlands: [CGFloat], offsets: [CGFloat] = RouteArt.contourOffsets) -> [CGPath] {
        offsets.map { (off: CGFloat) -> CGPath in
            let soften = max(0, 1 - off / 140)
            return line(width: width) { (x: CGFloat) -> CGFloat in
                let plain = coastY(at: x, headlands: [])
                let full = coastY(at: x, headlands: headlands)
                return plain + (full - plain) * soften + off
            }
        }
    }

    // MARK: Lighthouses and the route

    /// The lighthouses' x, equally spaced by index from `startX` (the harbour end). `towardLowerX` true runs right →
    /// left (the mirrored default: the far lighthouses toward the sea page on the left).
    static func lighthouseXs(count: Int, spacing: CGFloat, startX: CGFloat, towardLowerX: Bool) -> [CGFloat] {
        guard count > 0 else { return [] }
        let dir: CGFloat = towardLowerX ? -1 : 1
        return (0..<count).map { startX + dir * spacing * CGFloat($0 + 1) }
    }

    /// The route's points: `routeDrop` below each headland tip, in order.
    static func routePoints(headlands: [CGFloat]) -> [CGPoint] {
        headlands.map { CGPoint(x: $0, y: coastY(at: $0, headlands: headlands) + routeDrop) }
    }

    /// The route's point at `x` (between two lighthouses: linear), for the "your best" pin.
    static func routePoint(at x: CGFloat, headlands: [CGFloat]) -> CGPoint {
        let pts = routePoints(headlands: headlands).sorted { $0.x < $1.x }
        guard let first = pts.first, let last = pts.last else { return CGPoint(x: x, y: coastBase + routeDrop) }
        if x <= first.x { return CGPoint(x: x, y: first.y) }
        if x >= last.x { return CGPoint(x: x, y: last.y) }
        for i in 1..<pts.count where x <= pts[i].x {
            let a = pts[i - 1], b = pts[i]
            let t = (x - a.x) / max(b.x - a.x, 0.001)
            return CGPoint(x: x, y: a.y + (b.y - a.y) * t)
        }
        return CGPoint(x: x, y: last.y)
    }

    /// The route from x `from` to x `to` (either order), through the points between. Flown: solid reward gold with a
    /// 6 pt glow at 0.25; not yet: 2 pt dashed mist at 45 % (6 / 8).
    static func routePath(headlands: [CGFloat], from x0: CGFloat, to x1: CGFloat) -> CGPath {
        let lo = min(x0, x1), hi = max(x0, x1)
        let p = CGMutablePath()
        p.move(to: routePoint(at: lo, headlands: headlands))
        for q in routePoints(headlands: headlands).sorted(by: { $0.x < $1.x }) where q.x > lo && q.x < hi {
            p.addLine(to: q)
        }
        p.addLine(to: routePoint(at: hi, headlands: headlands))
        return p
    }

    /// A scroll offset near `proposed` (content x at the view's left edge) that puts no centre inside `band` (view
    /// x; the Duo's art fold band 447 … 503): the nearest such offset, or `proposed` when it already fits.
    static func snapOffset(proposed: CGFloat, centres: [CGFloat], band: ClosedRange<CGFloat>) -> CGFloat {
        func fits(_ o: CGFloat) -> Bool { !centres.contains { band.contains($0 - o) } }
        if fits(proposed) { return proposed }
        var candidates: [CGFloat] = []
        for c in centres {
            candidates.append(c - (band.lowerBound - 0.5))
            candidates.append(c - (band.upperBound + 0.5))
        }
        let sorted = candidates.sorted { abs($0 - proposed) < abs($1 - proposed) }
        return sorted.first(where: fits) ?? proposed
    }

    // MARK: Round 9: the Route reads left to right (ART-ROUND-9 §4)

    /// The coast's base line: Duo 150, iPhone 118 (y down).
    static let coastBaseDuo: CGFloat = 150
    static let coastBasePhone: CGFloat = 118
    /// Each lighthouse stands on a seaward point: a cosine bump +34 pt, 120 pt wide.
    static let pointBulge: CGFloat = 34
    static let pointWidth: CGFloat = 120
    /// The label row sits this far under the headland tips; a colliding label drops one row of 40 pt.
    static let labelDrop: CGFloat = 64
    static let labelRowStep: CGFloat = 40
    static let labelGap: CGFloat = 16

    /// R9 coast: y = base + 20 sin(x / 170) + 10 sin(x / 61 + 1.3), plus a +34 pt point under each lighthouse, so every
    /// lighthouse stands on a point, never in a cove.
    static func coastY(at x: CGFloat, headlands: [CGFloat], base: CGFloat) -> CGFloat {
        var y = base + 20 * sin(x / 170) + 10 * sin(x / 61 + 1.3)
        let half = pointWidth * 0.5
        for h in headlands {
            let d = abs(x - h) / half
            if d < 1 { y += pointBulge * 0.5 * (1 + cos(CGFloat.pi * d)) }
        }
        return y
    }

    /// R9 land from the strip's top down to the coast (fill `#3E4466 → #2A2E4A`, sand rim 3 pt `#C9B98F`).
    static func coastPath(width: CGFloat, headlands: [CGFloat], base: CGFloat, top: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        let w = max(width, 1)
        p.move(to: CGPoint(x: 0, y: top))
        p.addLine(to: CGPoint(x: w, y: top))
        var x = w
        while x > 0 {
            p.addLine(to: CGPoint(x: x, y: coastY(at: x, headlands: headlands, base: base)))
            x -= 4
        }
        p.addLine(to: CGPoint(x: 0, y: coastY(at: 0, headlands: headlands, base: base)))
        p.closeSubpath()
        return p
    }

    /// R9 coastline alone, `offset` pt seaward (0: the sand rim; 4: the foam line), and the contours (+30 / +60 / +100).
    static func coastline(width: CGFloat, headlands: [CGFloat], base: CGFloat, offset: CGFloat = 0) -> CGPath {
        line(width: width) { (x: CGFloat) -> CGFloat in coastY(at: x, headlands: headlands, base: base) + offset }
    }

    /// R9 lighthouse x by index, left to right on every device and bird side: the first at `spacing`, then every
    /// `spacing` (Duo 150, iPhone 130). The harbour quay sits at x 48 and the storm glyph behind it at x 16.
    static func lighthouseXs(count: Int, spacing: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        return (0..<count).map { spacing * CGFloat($0 + 1) }
    }

    /// The scroll offset that puts lighthouse `index` at 60 % of the view's width (then snap with `snapOffset`).
    static func focusOffset(index: Int, spacing: CGFloat, viewWidth: CGFloat) -> CGFloat {
        max(spacing * CGFloat(index + 1) - viewWidth * 0.6, 0)
    }

    /// Lays label rects out on one baseline row: a label that would come within `gap` of an earlier one drops a row
    /// (`rowStep`), up to `maxRows` rows; nothing overlaps. The rects keep their x; the result is in the same order.
    static func labelRows(_ rects: [CGRect], gap: CGFloat = RouteArt.labelGap, rowStep: CGFloat = RouteArt.labelRowStep,
                          maxRows: Int = 4) -> [CGRect] {
        var placed: [CGRect] = []
        let pad = -gap / 2
        for r in rects {
            var c = r
            var row = 0
            while row < maxRows {
                let grown = c.insetBy(dx: pad, dy: pad)
                let hit = placed.contains { $0.insetBy(dx: pad, dy: pad).intersects(grown) }
                if !hit { break }
                row += 1
                c = r.offsetBy(dx: 0, dy: rowStep * CGFloat(row))
            }
            placed.append(c)
        }
        return placed
    }

    // MARK: Glyphs (a `size` × `size` box, y down)

    /// The storm glyph: an anvil cloud (flat spreading top, tower, billowed base). Fill it with the storm body colour.
    static func stormGlyph(size s: CGFloat) -> CGPath {
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        let p = CGMutablePath()
        p.move(to: q(0.10, 0.30))
        p.addQuadCurve(to: q(0.20, 0.13), control: q(0.08, 0.17))
        p.addLine(to: q(0.84, 0.11))
        p.addQuadCurve(to: q(0.98, 0.21), control: q(0.97, 0.12))
        p.addQuadCurve(to: q(0.70, 0.30), control: q(0.86, 0.29))
        p.addQuadCurve(to: q(0.76, 0.48), control: q(0.70, 0.40))
        p.addQuadCurve(to: q(0.86, 0.64), control: q(0.90, 0.52))
        p.addQuadCurve(to: q(0.76, 0.75), control: q(0.86, 0.75))
        p.addLine(to: q(0.24, 0.75))
        p.addQuadCurve(to: q(0.13, 0.62), control: q(0.12, 0.75))
        p.addQuadCurve(to: q(0.26, 0.46), control: q(0.13, 0.48))
        p.addQuadCurve(to: q(0.32, 0.31), control: q(0.30, 0.37))
        p.closeSubpath()
        return p
    }

    /// The glyph's three rain ticks under its base (stroke 2 pt, round caps, in the rain colour).
    static func stormRainTicks(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for x in [CGFloat(0.34), 0.50, 0.66] {
            p.move(to: CGPoint(x: x * s, y: 0.82 * s))
            p.addLine(to: CGPoint(x: (x - 0.05) * s, y: 0.95 * s))
        }
        return p
    }

    /// The harbour's quay: a jetty deck on two piles with a bollard (one fill path).
    static func quayGlyph(size s: CGFloat) -> CGPath {
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
        }
        let p = CGMutablePath()
        p.addRect(r(0.06, 0.52, 0.88, 0.16))
        p.addRect(r(0.18, 0.68, 0.10, 0.26))
        p.addRect(r(0.70, 0.68, 0.10, 0.26))
        p.addRoundedRect(in: r(0.58, 0.34, 0.14, 0.18), cornerWidth: 0.04 * s, cornerHeight: 0.04 * s)
        p.addRoundedRect(in: r(0.54, 0.30, 0.22, 0.07), cornerWidth: 0.03 * s, cornerHeight: 0.03 * s)
        return p
    }

    // MARK: Helpers

    private static func line(width: CGFloat, _ y: (CGFloat) -> CGFloat) -> CGPath {
        let p = CGMutablePath()
        let w = max(width, 1)
        p.move(to: CGPoint(x: 0, y: y(0)))
        var x: CGFloat = 4
        while x < w {
            p.addLine(to: CGPoint(x: x, y: y(x)))
            x += 4
        }
        p.addLine(to: CGPoint(x: w, y: y(w)))
        return p
    }
}

/// The live phone diagram's geometry (ART-FLIGHT-SCHOOL §1, AP1), so the App's `DuoDiagram` can draw it with SwiftUI
/// paths. Pure; y down, in the diagram's box (Duo 240 × 170, iPhone 180 × 128).
///
/// A Duo held like a book, seen 3/4 from slightly above and in front: two panels hinged on a vertical spine, each
/// turned about the spine by φ = (180° − θ) / 2 and projected with a horizontal scale cos φ; the outer (near) edges
/// read taller by 0.18 sin φ.
enum DuoDiagramArt {
    /// The hinge range the diagram shows (degrees).
    static let minAngle: Double = 100
    static let maxAngle: Double = 180
    /// The spine: 8 pt wide, 0.86 of the box tall. The panels: 0.80 of the box tall at the spine.
    static let spineWidth: CGFloat = 8
    static let spineHeight: CGFloat = 0.86
    static let panelHeight: CGFloat = 0.80
    static let outerSkew: CGFloat = 0.18
    /// Screens sit this far inside each panel.
    static let screenInset: CGFloat = 7
    /// The angle gauge: a 140° arc (hinge 100° at its left end, 180° at its right end).
    static let gaugeSweep: Double = 140
    static let openBand: ClosedRange<Double> = 150...180
    static let tuckBand: ClosedRange<Double> = 100...122
    static let flatWarning: Double = 174

    struct Geometry {
        /// Corner order: spine top, outer top, outer bottom, spine bottom.
        var leftPanel: [CGPoint]
        var rightPanel: [CGPoint]
        var leftScreen: [CGPoint]
        var rightScreen: [CGPoint]
        var spine: CGRect
        /// The panels' turn about the spine (radians).
        var phi: CGFloat
    }

    /// R9 (ART-ROUND-9 §1D, the wing diagram riding with the bird): the exaggerated display angle
    /// φd = min(1.6 · (180° − θ) / 2, 60°), so a full tuck (122°) shows at 46° and reads at a glance.
    static func displayPhi(angle: Double) -> CGFloat {
        let theta = min(max(angle.isFinite ? angle : maxAngle, minAngle), maxAngle)
        return CGFloat(min(1.6 * (180 - theta) / 2, 60) * Double.pi / 180)
    }

    /// R9: the inner faces darken by 25 % · sin φd.
    static func innerShade(angle: Double) -> CGFloat { 0.25 * sin(displayPhi(angle: angle)) }

    /// R9: the same geometry with the exaggerated display angle (no gauge; the App's `WingDiagram`).
    static func geometry(angle: Double, box: CGSize, exaggerated: Bool) -> Geometry {
        guard exaggerated else { return geometry(angle: angle, box: box) }
        let phid = Double(displayPhi(angle: angle)) * 180 / Double.pi
        return geometry(angle: 180 - 2 * phid, box: box, clampAngle: false)
    }

    static func geometry(angle: Double, box: CGSize) -> Geometry {
        geometry(angle: angle, box: box, clampAngle: true)
    }

    private static func geometry(angle: Double, box: CGSize, clampAngle: Bool) -> Geometry {
        let lo = clampAngle ? minAngle : 60
        let theta = min(max(angle.isFinite ? angle : maxAngle, lo), maxAngle)
        let phi = CGFloat((180 - theta) * 0.5 * Double.pi / 180)
        let cx = box.width * 0.5, cy = box.height * 0.5
        let half = spineWidth * 0.5
        let wp = max((box.width - spineWidth) * 0.5, 1)
        let hp = box.height * panelHeight
        let proj = wp * cos(phi)
        let outerHalf = hp * 0.5 * (1 + outerSkew * sin(phi))
        func panel(_ side: CGFloat) -> [CGPoint] {
            let sx = cx + side * half, ox = cx + side * (half + proj)
            return [CGPoint(x: sx, y: cy - hp * 0.5), CGPoint(x: ox, y: cy - outerHalf),
                    CGPoint(x: ox, y: cy + outerHalf), CGPoint(x: sx, y: cy + hp * 0.5)]
        }
        let l = panel(-1), r = panel(1)
        let ui = min(screenInset / max(proj, 1), 0.45), vi = min(screenInset / max(hp, 1), 0.45)
        let spine = CGRect(x: cx - half, y: cy - box.height * spineHeight * 0.5, width: spineWidth,
                           height: box.height * spineHeight)
        return Geometry(leftPanel: l, rightPanel: r, leftScreen: inset(l, ui, vi), rightScreen: inset(r, ui, vi),
                        spine: spine, phi: phi)
    }

    /// A closed path through a quad's corners.
    static func quadPath(_ q: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = q.first else { return p }
        p.move(to: first)
        for c in q.dropFirst() { p.addLine(to: c) }
        p.closeSubpath()
        return p
    }

    /// A mitten (mist `#B6CCDA`, a 2 pt ink outline at 30 %) holding a panel's outer edge, its thumb on the front face.
    /// `outerTop` / `outerBottom`: that edge; `outward`: +1 when the edge is the right one, −1 the left one.
    static func mittenPath(outerTop: CGPoint, outerBottom: CGPoint, outward: CGFloat) -> CGPath {
        let o: CGFloat = outward >= 0 ? 1 : -1
        let midY = (outerTop.y + outerBottom.y) * 0.5
        let x = (outerTop.x + outerBottom.x) * 0.5
        let h = max(abs(outerBottom.y - outerTop.y) * 0.42, 12)
        let p = CGMutablePath()
        let hand = CGRect(x: o > 0 ? x - 6 : x - 16, y: midY - h * 0.5, width: 22, height: h)
        p.addRoundedRect(in: hand, cornerWidth: 9, cornerHeight: 9)
        let thumb = CGRect(x: x - o * 10 - 6, y: midY - h * 0.5 + 4, width: 12, height: 9)
        p.addEllipse(in: thumb)
        return p
    }

    /// The gauge angle (radians, y down) for a hinge angle: 100° → 200° (left end), 180° → 340° (right end).
    static func gaugeAngle(hinge: Double) -> CGFloat {
        let t = (min(max(hinge.isFinite ? hinge : maxAngle, minAngle), maxAngle) - minAngle) / (maxAngle - minAngle)
        return CGFloat((200 + gaugeSweep * t) * Double.pi / 180)
    }

    /// A point on the gauge (the needle's tip, a label anchor).
    static func gaugePoint(center: CGPoint, radius: CGFloat, hinge: Double) -> CGPoint {
        let a = gaugeAngle(hinge: hinge)
        return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
    }

    /// The gauge's arc between two hinge angles (stroke 6 pt: the open band in `accentOn`, the tuck band in reward gold,
    /// the rest white at 14 %).
    static func gaugeArc(center: CGPoint, radius: CGFloat, from a: Double, to b: Double) -> CGPath {
        let lo = min(a, b), hi = max(a, b)
        let p = CGMutablePath()
        p.move(to: gaugePoint(center: center, radius: radius, hinge: lo))
        var h = lo + 1
        while h < hi {
            p.addLine(to: gaugePoint(center: center, radius: radius, hinge: h))
            h += 1
        }
        p.addLine(to: gaugePoint(center: center, radius: radius, hinge: hi))
        return p
    }

    private static func inset(_ q: [CGPoint], _ u: CGFloat, _ v: CGFloat) -> [CGPoint] {
        guard q.count == 4 else { return q }
        func at(_ s: CGFloat, _ t: CGFloat) -> CGPoint {
            // s along spine → outer, t along top → bottom.
            let top = CGPoint(x: q[0].x + (q[1].x - q[0].x) * s, y: q[0].y + (q[1].y - q[0].y) * s)
            let bottom = CGPoint(x: q[3].x + (q[2].x - q[3].x) * s, y: q[3].y + (q[2].y - q[3].y) * s)
            return CGPoint(x: top.x + (bottom.x - top.x) * t, y: top.y + (bottom.y - top.y) * t)
        }
        return [at(u, v), at(1 - u, v), at(1 - u, 1 - v), at(u, 1 - v)]
    }
}
