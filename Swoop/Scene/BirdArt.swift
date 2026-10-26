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
/// hand swept behind the wrist; tucked, it folds flat along the back, narrow, the tip reaching past the tail.
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
    /// The hand (outer wing) sweeps back from the arm by this much when spread.
    static let handSweep: CGFloat = 0.24
    /// The arm (inner wing) leans forward of the wing's mean direction by this much when spread.
    static let armLead: CGFloat = 0.14

    // MARK: Title tunables (fractions of the canvas)

    /// The spread wingtips stop this far (fraction of the width) from the canvas edges.
    static let titleEdgeMargin: CGFloat = 0.012
    /// Fully tucked, each wingtip sits this fraction of the half-width out from the centre.
    static let titleTuckedReach: CGFloat = 0.27

    // MARK: Public API

    /// The bird in a unit box (centre origin, y up, facing +x, span ≈ 1.0 × bird.span), wings at `tuck`
    /// (0 spread … 1 tucked) and `flap` phase 0…1 (a small idle flap; 0 = none, one cycle per unit).
    static func path(for bird: Bird, tuck: Double, flap: Double)
        -> (body: CGPath, nearWing: CGPath, farWing: CGPath, beak: CGPath) {
        let near = wingGeometry(for: bird, tuck: tuck, flap: flap, far: false)
        let far = wingGeometry(for: bird, tuck: tuck, flap: flap, far: true)
        return (bodyPath(for: bird), wingPath(near), wingPath(far), beakPath(for: bird))
    }

    /// The front-on "title" bird whose wings span the whole canvas width (y down, origin top-left): the left wing on
    /// the left half, the right wing on the right half, the body on the centre line (the fold). The wings fold down
    /// toward the body as tuck → 1.
    static func titlePath(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat)
        -> (body: CGPath, leftWing: CGPath, rightWing: CGPath) {
        let w = max(width, 1), h = max(height, 1)
        let u = CGFloat(clamp01(tuck))
        let pt = CGFloat(clamp01(bird.pointiness))
        let cx = w * 0.5, cy = h * 0.5
        let bodyW = min(w * 0.075, h * 0.24)
        let bodyH = min(h * 0.62, bodyW * 2.4)
        let top = cy - bodyH * 0.5
        let body = titleBody(cx: cx, top: top, bodyW: bodyW, bodyH: bodyH)

        let halfReach = cx - w * titleEdgeMargin
        let tipX = cx - halfReach * lerp(1.0, titleTuckedReach, u)
        let wristX = cx - halfReach * lerp(0.42, 0.19, u)
        let wristY = cy - h * lerp(0.13, 0.21, u)
        let tipY = cy + h * lerp(-0.02, 0.24, u)
        let chord = min(h * 0.17, w * 0.09) * lerp(1.0, 0.62, u) * (1.12 - 0.3 * pt)
        let rootTop = CGPoint(x: cx - bodyW * 0.36, y: top + bodyH * 0.42)
        let rootBottom = CGPoint(x: cx - bodyW * 0.30, y: top + bodyH * 0.64)
        let wrist = CGPoint(x: wristX, y: wristY)
        let tip = CGPoint(x: tipX, y: tipY)
        let handTrail = CGPoint(x: lerp(tipX, wristX, 0.42), y: lerp(tipY, wristY, 0.42) + chord * 0.95)
        let armTrail = CGPoint(x: wristX + chord * 0.15, y: wristY + chord * 1.05)
        let roundness = 1 - pt

        let left = CGMutablePath()
        left.move(to: rootTop)
        left.addCurve(to: wrist,
                      control1: CGPoint(x: rootTop.x - (rootTop.x - wristX) * 0.35, y: rootTop.y - h * 0.06),
                      control2: CGPoint(x: wristX + (rootTop.x - wristX) * 0.25, y: wristY - h * 0.012))
        left.addCurve(to: tip,
                      control1: CGPoint(x: wristX - (wristX - tipX) * 0.35, y: wristY - h * 0.005),
                      control2: CGPoint(x: tipX + (wristX - tipX) * 0.25, y: tipY - chord * 0.15))
        left.addQuadCurve(to: handTrail,
                          control: CGPoint(x: tipX + chord * 0.15, y: tipY + chord * (0.35 + 0.45 * roundness)))
        left.addCurve(to: armTrail,
                      control1: CGPoint(x: handTrail.x + (armTrail.x - handTrail.x) * 0.4, y: handTrail.y + chord * 0.05),
                      control2: CGPoint(x: armTrail.x - (armTrail.x - handTrail.x) * 0.3, y: armTrail.y + chord * 0.05))
        left.addCurve(to: rootBottom,
                      control1: CGPoint(x: armTrail.x + (rootBottom.x - armTrail.x) * 0.4, y: armTrail.y + chord * 0.05),
                      control2: CGPoint(x: rootBottom.x - bodyW * 0.3, y: rootBottom.y + h * 0.01))
        left.closeSubpath()

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
        let hh = bodyHalfHeight(pointiness: pt)
        let phase = CGFloat(flap - floor(flap))
        var elevation = lerp(spreadElevation, tuckedElevation, u)
            + flapAmplitude * (1 - u) * sin(2 * CGFloat.pi * phase)
        if far { elevation += farWingLift * (1 - 0.7 * u) }
        let base = CGFloat.pi - elevation
        let armAngle = base - lerp(armLead, 0.06, u)
        let handAngle = base + lerp(handSweep, 0.03, u)
        let spreadLength = (0.40 + 0.10 * pt) * span
        let tuckLength = 0.50 + 0.05 * (span - 1) + 0.03 * pt
        let length = lerp(spreadLength, tuckLength, u) * (far ? 0.93 : 1)
        let chord = (0.15 - 0.05 * pt) * lerp(1, 0.42, u) * (far ? 0.9 : 1)
        let shoulder = far ? CGPoint(x: 0.10, y: hh * 0.78) : CGPoint(x: 0.08, y: hh * 0.55)
        let root = far ? CGPoint(x: -0.06, y: hh * 0.72) : CGPoint(x: -0.10, y: hh * 0.50)
        let armDir = direction(armAngle)
        let handDir = direction(handAngle)
        // Toward the trailing edge (behind the leading edge).
        let armN = direction(armAngle + CGFloat.pi / 2)
        let handN = direction(handAngle + CGFloat.pi / 2)
        let wrist = offset(shoulder, armDir, length * 0.40)
        let tip = offset(wrist, handDir, length * 0.60)
        let handTrail = offset(offset(wrist, handDir, length * 0.30), handN, chord * 0.80)
        let armTrail = offset(offset(wrist, armN, chord), armDir, -0.02)
        let lead1 = offset(mid(shoulder, wrist), armN, -chord * 0.18)
        let lead2 = offset(mid(wrist, tip), handN, -chord * 0.10)
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

    // MARK: Title body (front-on, y down)

    private static func titleBody(cx: CGFloat, top: CGFloat, bodyW: CGFloat, bodyH: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let bottom = top + bodyH
        func r(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx + bodyW * fx, y: top + bodyH * fy) }
        func l(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx - bodyW * fx, y: top + bodyH * fy) }
        p.move(to: CGPoint(x: cx, y: top))
        // Right side: head, neck, shoulder, flank, tail.
        p.addCurve(to: r(0.30, 0.16), control1: r(0.18, 0), control2: r(0.30, 0.06))
        p.addCurve(to: r(0.24, 0.32), control1: r(0.30, 0.24), control2: r(0.24, 0.27))
        p.addCurve(to: r(0.50, 0.50), control1: r(0.26, 0.38), control2: r(0.50, 0.40))
        p.addCurve(to: r(0.36, 0.78), control1: r(0.50, 0.62), control2: r(0.44, 0.72))
        p.addCurve(to: CGPoint(x: cx, y: bottom), control1: r(0.26, 0.90), control2: r(0.08, 1.0))
        // Left side, mirrored, back up to the crown.
        p.addCurve(to: l(0.36, 0.78), control1: l(0.08, 1.0), control2: l(0.26, 0.90))
        p.addCurve(to: l(0.50, 0.50), control1: l(0.44, 0.72), control2: l(0.50, 0.62))
        p.addCurve(to: l(0.24, 0.32), control1: l(0.50, 0.40), control2: l(0.26, 0.38))
        p.addCurve(to: l(0.30, 0.16), control1: l(0.24, 0.27), control2: l(0.30, 0.24))
        p.addCurve(to: CGPoint(x: cx, y: top), control1: l(0.30, 0.06), control2: l(0.18, 0))
        p.closeSubpath()
        return p
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
