import CoreGraphics
import Foundation

/// The bird drawn with CoreGraphics only, so SwiftUI (the title, the Birds screen) and SpriteKit share one art source
/// (ARCHITECTURE "Scene API"). Pure functions: no UIKit, no SpriteKit, no actor isolation (safe inside `Shape.path(in:)`).
///
/// Coordinate conventions:
/// - `path(for:tuck:flap:)`: a unit box, centre origin, **y up** (SpriteKit / maths), the bird facing +x. The body is
///   about 0.9 long (tail tip −0.47 … beak tip +0.47); the spread near wing reaches up to ≈ 0.6 × `bird.span`.
///   To draw it in SwiftUI (y down) flip it: `BirdArt.flippedVertically(path)` or `.scaleEffect(x: 1, y: -1)`.
/// - `titlePath(for:tuck:width:height:)`: a `width × height` box, origin top-left, **y down** (SwiftUI / UIKit).
///
/// The look: a sleek seabird silhouette (not a ball). Spread, the near wing is held up and back in a shallow V with the
/// hand swept behind the wrist; tucked, it folds flat along the back, narrow, the tip reaching past the tail. Each
/// species has its own wing (R2, REVIEW-1 P1-10): sickle swift, long straight albatross, stubby round puffin…
enum BirdArt {
    // MARK: Side-view tunables (unit box; angles in radians)

    /// Wing elevation above the backward horizontal with the wings spread. Higher = wings held up in a steeper V.
    static let spreadElevation: CGFloat = 0.82
    /// …fully tucked: the wing lies along the back.
    static let tuckedElevation: CGFloat = 0.05
    /// Idle flap swing at tuck 0 (± around the spread elevation).
    static let flapAmplitude: CGFloat = 0.62
    /// The far wing is held a little higher so it peeks above the body behind the near wing.
    static let farWingLift: CGFloat = 0.22
    /// The hand (outer wing) sweeps back from the arm by this much when spread (× the species' sweep).
    static let handSweep: CGFloat = 0.24
    /// The arm (inner wing) leans forward of the wing's mean direction by this much when spread (× the species' lead).
    static let armLead: CGFloat = 0.14
    /// Folded, the wing keeps this fraction of its spread chord.
    static let tuckedChord: CGFloat = 0.36

    // MARK: Title tunables (fractions of the canvas)

    /// The spread wingtips stop this far (fraction of the width) from the canvas edges.
    static let titleEdgeMargin: CGFloat = 0.012
    /// Fully tucked, each wingtip sits this fraction of the width out from the centre line (a dart ≈ 32 % wide).
    static let titleTuckedTipX: CGFloat = 0.15
    /// …and this far down the body (fraction of the body length from the beak): past the tail fan.
    static let titleTuckedTipY: CGFloat = 1.14

    /// A species' wing, as multipliers on the gull's.
    struct WingShape {
        var length: CGFloat
        var chord: CGFloat
        var sweep: CGFloat
        var lead: CGFloat
        /// Where the wrist sits along the wing (0…1).
        var arm: CGFloat
    }

    static func shape(for id: BirdID) -> WingShape {
        switch id {
        case .gull: return WingShape(length: 1.0, chord: 1.0, sweep: 1.0, lead: 1.0, arm: 0.40)
        case .tern: return WingShape(length: 1.05, chord: 0.85, sweep: 1.3, lead: 1.0, arm: 0.38)
        case .puffin: return WingShape(length: 0.75, chord: 1.1, sweep: 0.6, lead: 0.8, arm: 0.45)
        case .swift: return WingShape(length: 1.12, chord: 0.75, sweep: 2.1, lead: 0.6, arm: 0.30)
        case .albatross: return WingShape(length: 1.25, chord: 0.72, sweep: 0.35, lead: 0.4, arm: 0.45)
        case .petrel: return WingShape(length: 1.0, chord: 0.85, sweep: 1.6, lead: 0.9, arm: 0.36)
        case .heron: return WingShape(length: 1.08, chord: 1.2, sweep: 0.7, lead: 1.0, arm: 0.42)
        case .gannet: return WingShape(length: 1.15, chord: 0.8, sweep: 0.8, lead: 0.7, arm: 0.42)
        }
    }

    // MARK: Public API

    /// The bird in a unit box (centre origin, y up, facing +x, span ≈ 1.0 × bird.span), wings at `tuck`
    /// (0 spread … 1 tucked) and `flap` phase 0…1 (a small idle flap; 0 = none, one cycle per unit).
    static func path(for bird: Bird, tuck: Double, flap: Double)
        -> (body: CGPath, nearWing: CGPath, farWing: CGPath, beak: CGPath) {
        let near = wingGeometry(for: bird, tuck: tuck, flap: flap, far: false)
        let far = wingGeometry(for: bird, tuck: tuck, flap: flap, far: true)
        return (bodyPath(for: bird), wingPath(near), wingPath(far), beakPath(for: bird))
    }

    /// The title bird, seen from above and behind (R2, REVIEW-1 P1-1), its wings spanning the whole canvas width
    /// (y down, origin top-left): the left wing on the left half, the right wing on the right half, the body on the
    /// centre line (the fold), head and beak up, a fanned tail down. As tuck → 1 the wings sweep back into a dart, the
    /// tips pointing down and back past the tail (the same silhouette as the tucked bird in flight).
    static func titlePath(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat)
        -> (body: CGPath, leftWing: CGPath, rightWing: CGPath) {
        let w = max(width, 1), h = max(height, 1)
        let u = CGFloat(clamp01(tuck))
        let e = u * u * (3 - 2 * u)
        let pt = CGFloat(clamp01(bird.pointiness))
        let sh = shape(for: bird.id)
        let cx = w * 0.5, cy = h * 0.5
        let bodyW = min(w * 0.085, h * 0.26)
        let bodyH = min(h * 0.70, bodyW * 2.6)
        let top = cy - bodyH * 0.52
        let body = titleBody(cx: cx, top: top, bodyW: bodyW, bodyH: bodyH)

        let shoulder = CGPoint(x: cx - bodyW * 0.30, y: top + bodyH * 0.36)
        let spreadTip = CGPoint(x: w * titleEdgeMargin, y: shoulder.y - h * 0.01)
        let tuckTip = CGPoint(x: cx - w * titleTuckedTipX, y: top + bodyH * titleTuckedTipY)
        let l0 = hypot(shoulder.x - spreadTip.x, spreadTip.y - shoulder.y)
        let a0 = atan2(spreadTip.y - shoulder.y, shoulder.x - spreadTip.x)
        let l1 = hypot(shoulder.x - tuckTip.x, tuckTip.y - shoulder.y)
        let a1 = atan2(tuckTip.y - shoulder.y, shoulder.x - tuckTip.x)
        let length = lerp(l0, l1, e)
        let tipAngle = lerp(a0, a1, e)
        // The arm is less swept than the hand: a gentle gull arch when spread, a kinked dart when tucked.
        let bend = lerp(0.07, 0.20, e) * (0.6 + 0.4 * min(sh.sweep, 1.5))
        let chord = min(bodyH * 0.40, w * 0.09) * (1.1 - 0.25 * pt) * min(max(sh.chord, 0.7), 1.25) * lerp(1, 0.78, e)

        let left = dorsalWing(shoulder: shoulder, length: length, tipAngle: tipAngle, bend: bend, chord: chord,
                              pointiness: pt, arm: sh.arm)
        let right = CGMutablePath()
        right.addPath(left, transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0))
        return (body, left, right)
    }

    // MARK: Extras for the scene (and anyone who wants them)

    /// The outer part of each wing (for the `wingTip` colour), in the same unit box as `path(for:tuck:flap:)`.
    static func wingTipPaths(for bird: Bird, tuck: Double, flap: Double) -> (near: CGPath, far: CGPath) {
        let near = wingGeometry(for: bird, tuck: tuck, flap: flap, far: false)
        let far = wingGeometry(for: bird, tuck: tuck, flap: flap, far: true)
        return (tipPath(near), tipPath(far))
    }

    /// The eye (unit box, y up).
    static func eye(for bird: Bird) -> (center: CGPoint, radius: CGFloat) {
        let pt = CGFloat(clamp01(bird.pointiness))
        let hh = bodyHalfHeight(pointiness: pt)
        return (CGPoint(x: 0.285, y: hh * 0.48), 0.013 + 0.004 * (1 - pt))
    }

    /// `path` mirrored top-to-bottom about y = 0 (y up ↔ y down), to draw the side-view bird in SwiftUI.
    static func flippedVertically(_ path: CGPath) -> CGPath {
        let m = CGMutablePath()
        m.addPath(path, transform: CGAffineTransform(scaleX: 1, y: -1))
        return m
    }

    // MARK: Side-view geometry

    /// Body half-height: chunky puffin (0.082) … sleek swift (0.060).
    static func bodyHalfHeight(pointiness pt: CGFloat) -> CGFloat {
        0.082 - 0.022 * pt
    }

    struct Wing {
        var shoulder: CGPoint
        var root: CGPoint
        var wrist: CGPoint
        var tip: CGPoint
        var lead1: CGPoint
        var lead2: CGPoint
        var tipControl: CGPoint
        var handTrail: CGPoint
        var armTrail: CGPoint
        var trail1: CGPoint
        var trail2: CGPoint
    }

    static func wingGeometry(for bird: Bird, tuck: Double, flap: Double, far: Bool) -> Wing {
        let u = CGFloat(clamp01(tuck))
        let pt = CGFloat(clamp01(bird.pointiness))
        let span = CGFloat(min(max(bird.span, 0.5), 1.8))
        let sh = shape(for: bird.id)
        let hh = bodyHalfHeight(pointiness: pt)
        let phase = CGFloat(flap - floor(flap))
        var elevation = lerp(spreadElevation, tuckedElevation, u)
            + flapAmplitude * (1 - u) * sin(2 * CGFloat.pi * phase)
        if far { elevation += farWingLift * (1 - 0.7 * u) }
        let base = CGFloat.pi - elevation
        let armAngle = base - lerp(armLead * sh.lead, 0.06, u)
        let handAngle = base + lerp(handSweep * sh.sweep, 0.03, u)
        let spreadLength = (0.40 + 0.10 * pt) * span * sh.length
        let tuckLength = (0.50 + 0.05 * (span - 1) + 0.03 * pt) * (1 + 0.3 * (sh.length - 1))
        let length = lerp(spreadLength, tuckLength, u) * (far ? 0.93 : 1)
        let chord = (0.15 - 0.05 * pt) * sh.chord * lerp(1, tuckedChord, u) * (far ? 0.9 : 1)
        let shoulder = far ? CGPoint(x: 0.10, y: hh * 0.78) : CGPoint(x: 0.08, y: hh * 0.55)
        let root = far ? CGPoint(x: -0.06, y: hh * 0.72) : CGPoint(x: -0.10, y: hh * 0.50)
        let armDir = direction(armAngle)
        let handDir = direction(handAngle)
        // Toward the trailing edge (behind the leading edge).
        let armN = direction(armAngle + CGFloat.pi / 2)
        let handN = direction(handAngle + CGFloat.pi / 2)
        let armFraction = min(max(sh.arm, 0.25), 0.5)
        let wrist = offset(shoulder, armDir, length * armFraction)
        let tip = offset(wrist, handDir, length * (1 - armFraction))
        let handTrail = offset(offset(wrist, handDir, length * (1 - armFraction) * 0.5), handN, chord * 0.80)
        let armTrail = offset(offset(wrist, armN, chord), armDir, -0.02)
        let lead1 = offset(mid(shoulder, wrist), armN, -chord * 0.18)
        // A sickle (high sweep) bows its leading edge forward.
        let lead2 = offset(mid(wrist, tip), handN, -chord * (0.10 + 0.12 * max(sh.sweep - 1, 0)))
        let roundness = 1 - pt
        let tipControl = lerpPoint(mid(tip, handTrail), offset(tip, handN, chord * 0.75), roundness * 0.8 + 0.1)
        let trail1 = offset(mid(handTrail, armTrail), handN, chord * 0.12)
        let trail2 = offset(mid(armTrail, root), armN, chord * 0.25)
        return Wing(shoulder: shoulder, root: root, wrist: wrist, tip: tip, lead1: lead1, lead2: lead2,
                    tipControl: tipControl, handTrail: handTrail, armTrail: armTrail, trail1: trail1, trail2: trail2)
    }

    static func wingPath(_ w: Wing) -> CGPath {
        let p = CGMutablePath()
        p.move(to: w.shoulder)
        p.addQuadCurve(to: w.wrist, control: w.lead1)
        p.addQuadCurve(to: w.tip, control: w.lead2)
        p.addQuadCurve(to: w.handTrail, control: w.tipControl)
        p.addQuadCurve(to: w.armTrail, control: w.trail1)
        p.addQuadCurve(to: w.root, control: w.trail2)
        p.closeSubpath()
        return p
    }

    /// The outer hand: the leading edge from 42 % of the hand to the tip (sampled on the same curve as the wing), the
    /// tip curve back to the hand's trailing point, closed across the wing.
    static func tipPath(_ w: Wing) -> CGPath {
        let p = CGMutablePath()
        let start: CGFloat = 0.42
        let steps = 6
        for i in 0...steps {
            let t = start + (1 - start) * CGFloat(i) / CGFloat(steps)
            let q = quadPoint(w.wrist, w.lead2, w.tip, t)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.addQuadCurve(to: w.handTrail, control: w.tipControl)
        p.closeSubpath()
        return p
    }

    static func bodyPath(for bird: Bird) -> CGPath {
        let pt = CGFloat(clamp01(bird.pointiness))
        let hh = bodyHalfHeight(pointiness: pt)
        let tailX: CGFloat = -0.44 - 0.05 * pt
        let forked = pt > 0.6
        let p = CGMutablePath()
        let upperTail = CGPoint(x: forked ? tailX - 0.05 * pt : tailX, y: forked ? 0.03 : 0.012)
        p.move(to: upperTail)
        // The back up to the nape.
        p.addCurve(to: CGPoint(x: 0.20, y: hh * 0.95),
                   control1: CGPoint(x: -0.26, y: hh * 0.62), control2: CGPoint(x: 0.02, y: hh * 1.06))
        // Crown and forehead.
        p.addCurve(to: CGPoint(x: 0.352, y: hh * 0.45),
                   control1: CGPoint(x: 0.27, y: hh * 1.22), control2: CGPoint(x: 0.345, y: hh * 1.0))
        // The beak base (the beak path overlaps this edge).
        p.addLine(to: CGPoint(x: 0.356, y: -hh * 0.10))
        // Chin to breast.
        p.addCurve(to: CGPoint(x: 0.14, y: -hh * 1.02),
                   control1: CGPoint(x: 0.34, y: -hh * 0.62), control2: CGPoint(x: 0.25, y: -hh * 1.02))
        // Belly to vent.
        p.addCurve(to: CGPoint(x: -0.25, y: -hh * 0.42),
                   control1: CGPoint(x: 0.0, y: -hh * 1.04), control2: CGPoint(x: -0.15, y: -hh * 0.80))
        if forked {
            // Tern / swift: a forked tail (lower fork tip, the notch, then back to the upper fork tip).
            p.addCurve(to: CGPoint(x: tailX - 0.04 * pt, y: -0.035),
                       control1: CGPoint(x: -0.33, y: -hh * 0.2), control2: CGPoint(x: tailX + 0.04, y: -0.02))
            p.addLine(to: CGPoint(x: tailX + 0.07, y: -0.002))
        } else {
            p.addCurve(to: CGPoint(x: tailX, y: -0.012),
                       control1: CGPoint(x: -0.33, y: -hh * 0.18), control2: CGPoint(x: tailX + 0.06, y: -0.02))
            p.addLine(to: CGPoint(x: tailX - 0.025, y: 0.0))
        }
        p.closeSubpath()
        return p
    }

    static func beakPath(for bird: Bird) -> CGPath {
        let pt = CGFloat(clamp01(bird.pointiness))
        let hh = bodyHalfHeight(pointiness: pt)
        let baseX: CGFloat = 0.34
        // Broad birds (puffin) get a deep beak, pointed ones (tern, gannet) a long dagger.
        let top = hh * (0.42 + 0.30 * (1 - pt))
        let bottom = -hh * (0.12 + 0.40 * (1 - pt))
        let length: CGFloat = 0.085 + 0.06 * pt
        let tipY = (top + bottom) * 0.5 - 0.006 - 0.012 * (1 - pt)
        let tip = CGPoint(x: baseX + length + 0.015, y: tipY)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: baseX, y: top))
        p.addQuadCurve(to: tip, control: CGPoint(x: baseX + length * 0.55, y: top - 0.004))
        p.addQuadCurve(to: CGPoint(x: baseX, y: bottom), control: CGPoint(x: baseX + length * 0.45, y: bottom + 0.004))
        p.closeSubpath()
        return p
    }

    // MARK: Title bird (dorsal view, y down)

    /// The body from above: beak tip at the top, the head, a slim neck, broad shoulders, the flanks and a fanned tail.
    private static func titleBody(cx: CGFloat, top: CGFloat, bodyW: CGFloat, bodyH: CGFloat) -> CGPath {
        let p = CGMutablePath()
        func r(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx + bodyW * fx, y: top + bodyH * fy) }
        func l(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx - bodyW * fx, y: top + bodyH * fy) }
        p.move(to: CGPoint(x: cx, y: top))
        // Right side: beak, head, neck, shoulder, flank, tail base, the fan's corner, across the fan's edge.
        p.addLine(to: r(0.075, 0.075))
        p.addCurve(to: r(0.19, 0.15), control1: r(0.15, 0.08), control2: r(0.20, 0.11))
        p.addCurve(to: r(0.14, 0.26), control1: r(0.18, 0.20), control2: r(0.14, 0.23))
        p.addCurve(to: r(0.50, 0.42), control1: r(0.16, 0.31), control2: r(0.47, 0.33))
        p.addCurve(to: r(0.34, 0.68), control1: r(0.53, 0.53), control2: r(0.43, 0.62))
        p.addCurve(to: r(0.16, 0.77), control1: r(0.26, 0.73), control2: r(0.19, 0.75))
        p.addLine(to: r(0.34, 0.97))
        p.addQuadCurve(to: CGPoint(x: cx, y: top + bodyH * 0.95), control: r(0.18, 1.02))
        // Left side, mirrored, back up to the beak.
        p.addQuadCurve(to: l(0.34, 0.97), control: l(0.18, 1.02))
        p.addLine(to: l(0.16, 0.77))
        p.addCurve(to: l(0.34, 0.68), control1: l(0.19, 0.75), control2: l(0.26, 0.73))
        p.addCurve(to: l(0.50, 0.42), control1: l(0.43, 0.62), control2: l(0.53, 0.53))
        p.addCurve(to: l(0.14, 0.26), control1: l(0.47, 0.33), control2: l(0.16, 0.31))
        p.addCurve(to: l(0.19, 0.15), control1: l(0.14, 0.23), control2: l(0.18, 0.20))
        p.addCurve(to: l(0.075, 0.075), control1: l(0.20, 0.11), control2: l(0.15, 0.08))
        p.closeSubpath()
        return p
    }

    /// The left wing from above. Points are placed along the wing's axis (s from the shoulder) with a chord offset
    /// (c: negative = the leading edge, toward the head; positive = trailing, toward the tail). The axis angle runs
    /// from `tipAngle − bend` along the arm to `tipAngle` along the hand (radians below the outward horizontal).
    private static func dorsalWing(shoulder: CGPoint, length: CGFloat, tipAngle: CGFloat, bend: CGFloat, chord: CGFloat,
                                   pointiness pt: CGFloat, arm: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let lead = 16
        let trail = 30
        let wrist = min(max(arm, 0.25), 0.5)
        // Leading edge, root → tip: a gentle forward bow.
        for i in 0...lead {
            let t = CGFloat(i) / CGFloat(lead)
            let c = -length * 0.025 * sin(CGFloat.pi * t) - chord * 0.05 * (1 - t)
            let q = dorsalPoint(shoulder, length, tipAngle, bend, wrist, t, c)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        // Trailing edge, tip → root: a rounded (or pointed) tip, dark primaries as finger notches on broad wings,
        // the secondaries' long straight edge back to the body.
        let capStart = lerp(0.80, 0.90, pt)
        for i in 0...trail {
            let t = 1 - CGFloat(i) / CGFloat(trail)
            var c = chord * (0.95 - 0.35 * t * t)
            if t > capStart {
                let k = (t - capStart) / (1 - capStart)
                c *= max(0, 1 - k * k).squareRoot()
            }
            if t > 0.6 && t < 0.97 {
                c -= chord * 0.10 * (1 - pt) * abs(sin(CGFloat.pi * (t - 0.6) / 0.0925))
            }
            p.addLine(to: dorsalPoint(shoulder, length, tipAngle, bend, wrist, t, max(c, 0)))
        }
        p.closeSubpath()
        return p
    }

    private static func dorsalPoint(_ shoulder: CGPoint, _ length: CGFloat, _ tipAngle: CGFloat, _ bend: CGFloat,
                                    _ wrist: CGFloat, _ t: CGFloat, _ c: CGFloat) -> CGPoint {
        // 0 along the arm, 1 along the hand, smooth across the wrist.
        let k0 = min(max((t - wrist * 0.75) / (wrist * 0.8), 0), 1)
        let k = k0 * k0 * (3 - 2 * k0)
        let a = tipAngle - bend * (1 - k)
        let s = length * t
        // Outward (left) along the axis, and the trailing normal (toward the tail / the body).
        let dx = -cos(a), dy = sin(a)
        let nx = sin(a), ny = cos(a)
        return CGPoint(x: shoulder.x + dx * s + nx * c, y: shoulder.y + dy * s + ny * c)
    }

    // MARK: Small maths (functions, not operators, so nothing can clash with another module's CGPoint operators)

    static func clamp01(_ x: Double) -> Double {
        if x.isNaN { return 0 }
        return min(max(x, 0), 1)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    private static func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }

    private static func direction(_ angle: CGFloat) -> CGPoint {
        CGPoint(x: cos(angle), y: sin(angle))
    }

    private static func offset(_ p: CGPoint, _ d: CGPoint, _ k: CGFloat) -> CGPoint {
        CGPoint(x: p.x + d.x * k, y: p.y + d.y * k)
    }

    private static func quadPoint(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let s = 1 - t
        return CGPoint(x: s * s * a.x + 2 * s * t * c.x + t * t * b.x,
                       y: s * s * a.y + 2 * s * t * c.y + t * t * b.y)
    }
}
