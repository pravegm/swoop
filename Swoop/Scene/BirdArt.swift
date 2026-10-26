import CoreGraphics
import Foundation

/// The bird drawn with CoreGraphics only, so SwiftUI (the title, the Birds screen) and SpriteKit share one art source
/// (ARCHITECTURE "Scene API"). Pure functions: no UIKit, no SpriteKit, no actor isolation (safe inside `Shape.path(in:)`).
///
/// Coordinate conventions:
/// - `path(for:tuck:flap:)` and the other side-view paths: a unit box, centre origin, **y up** (SpriteKit / maths), the
///   bird facing +x. The body is about 0.9 long (tail tip −0.47 … beak tip +0.47); the spread near wing reaches about
///   0.52 × `bird.span` × the species' length. In SwiftUI flip it: `BirdArt.flippedVertically(path)`.
/// - `titlePath(for:tuck:width:height:)` and `titleDetail(...)`: a `width × height` box, origin top-left, **y down**.
///
/// The look (ART-DIRECTION §4): a long narrow wing with a visible wrist bend and a pointed hand, held low in a shallow
/// "check-mark" lifted up and back when spread (never straight up), half-folded at tuck 0.5, a dart at tuck 1. Each
/// species has its own wing (sickle swift, long straight albatross, stubby round puffin…).
enum BirdArt {
    // MARK: Side-view tunables (unit box; angles in radians; ART §4 table)

    /// Wing elevation above the backward horizontal with the wings spread (0.42: a long, shallow check-mark).
    static let spreadElevation: CGFloat = 0.42
    /// …fully tucked: the wing lies along the back.
    static let tuckedElevation: CGFloat = 0.04
    /// Idle flap swing at tuck 0 (± around the spread elevation).
    static let flapAmplitude: CGFloat = 0.45
    /// The far wing is held a little higher so it peeks above the body behind the near wing.
    static let farWingLift: CGFloat = 0.10
    /// The hand (outer wing) sweeps back from the arm by this much when spread (× the species' sweep).
    static let handSweep: CGFloat = 0.34
    /// The arm (inner wing) leans forward of the wing's mean direction by this much when spread (× the species' lead).
    static let armLead: CGFloat = 0.14
    /// The spread near wing's length: (this + 0.10 × pointiness) × span × species length.
    static let spreadLengthBase: CGFloat = 0.46
    /// Folded, the wing keeps this fraction of its spread chord.
    static let tuckedChord: CGFloat = 0.42

    // MARK: Title tunables (ART §7)

    /// The spread wingtips stop this far (fraction of the width) from the canvas edges: a 92 % span.
    static let titleEdgeMargin: CGFloat = 0.04
    /// Fully tucked, the dart's bow is aimed 0.99 × this fraction of the width out from the centre line
    /// (a dart about 27 % wide, above the App's 25 % refit threshold)…
    static let titleTuckedTipX: CGFloat = 0.16
    /// (kept for reference: the R3 tucked tip depth as a fraction of the body; R4 puts the tip 0.18 h behind the tail.)
    static let titleTuckedTipY: CGFloat = 1.10
    /// Dihedral: +6° from the shoulder to the wrist, −3° on the hand (a gull's "M", not a plank).
    static let titleArmDihedral: CGFloat = 6 * CGFloat.pi / 180
    static let titleHandDihedral: CGFloat = 3 * CGFloat.pi / 180
    /// The forward wrist kink sits at this fraction of the span.
    static let titleWrist: CGFloat = 0.38
    /// Chord taper: 0.16 h at the shoulder to 0.05 h at the tip; tucked it keeps ≥ 62 %.
    static let titleChordRoot: CGFloat = 0.16
    static let titleChordTip: CGFloat = 0.05
    static let titleTuckedChord: CGFloat = 0.62
    /// The white trailing band (fraction of the chord) and the black primaries (fraction of the span from the tip).
    static let titleTrailingBand: CGFloat = 0.10
    static let titlePrimaries: CGFloat = 0.18

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

    /// The title bird, seen from above and behind (ART §7), its wings spanning 92 % of the canvas width (y down,
    /// origin top-left): the left wing on the left half, the right wing on the right half, the body's centre line
    /// exactly on w / 2 (the fold). Spread: a gull's "M" (+6° arm, −3° hand), a forward wrist kink, a chord tapering
    /// from 0.16 h to 0.05 h and a smooth trailing edge. As tuck → 1 the wings sweep back into a straight-edged dart
    /// about a third of the width, the tips past the tail, keeping ≥ 62 % of the chord.
    static func titlePath(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat)
        -> (body: CGPath, leftWing: CGPath, rightWing: CGPath) {
        let f = titleFrame(for: bird, tuck: tuck, width: width, height: height)
        let left = CGMutablePath()
        appendTitleWing(left, f, chordFrom: 0, chordTo: 1, spanFrom: 0, spanTo: 1)
        return (f.body, left, mirrored(left, width: f.w))
    }

    /// The title bird's detail layers for the App (ART §7, A7), in the same box as `titlePath`:
    /// - the white trailing band (the inner 82 % of the span, the last 10 % of the chord);
    /// - the black primaries (the outer 18 %);
    /// - the two white mirrors on each hand (empty past half tuck, so the dart never shows "feet");
    /// - the two-tone beak: the beak, its darker spot, and the darker lower mandible;
    /// - a head contour (an open path to stroke).
    struct TitleDetail {
        var leftBand: CGPath
        var rightBand: CGPath
        var leftPrimaries: CGPath
        var rightPrimaries: CGPath
        var leftMirrors: CGPath
        var rightMirrors: CGPath
        var beak: CGPath
        var beakSpot: CGPath
        var beakLower: CGPath
        var headContour: CGPath
    }

    static func titleDetail(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat) -> TitleDetail {
        let f = titleFrame(for: bird, tuck: tuck, width: width, height: height)
        let inner = 1 - titlePrimaries
        let band = CGMutablePath()
        appendTitleWing(band, f, chordFrom: 1 - titleTrailingBand, chordTo: 1, spanFrom: 0.04, spanTo: inner)
        let prim = CGMutablePath()
        appendTitleWing(prim, f, chordFrom: 0, chordTo: 1, spanFrom: inner, spanTo: 1)
        let mirrors = CGMutablePath()
        if clamp01(tuck) <= 0.5 {
            let r = f.w * 0.006
            for t in [CGFloat(0.895), CGFloat(0.95)] {
                let c = titleWingPoint(f, t: t, chord: 0.5)
                mirrors.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
        }
        // The beak: the top of the body silhouette, gold, with a darker spot near its tip and a darker lower mandible.
        let beak = CGMutablePath()
        let bw = f.bodyW, top = f.top, bh = f.bodyH
        beak.move(to: CGPoint(x: f.cx, y: top))
        beak.addLine(to: CGPoint(x: f.cx + bw * 0.075, y: top + bh * 0.075))
        beak.addLine(to: CGPoint(x: f.cx - bw * 0.075, y: top + bh * 0.075))
        beak.closeSubpath()
        let lower = CGMutablePath()
        lower.move(to: CGPoint(x: f.cx, y: top + bh * 0.03))
        lower.addLine(to: CGPoint(x: f.cx + bw * 0.06, y: top + bh * 0.075))
        lower.addLine(to: CGPoint(x: f.cx - bw * 0.06, y: top + bh * 0.075))
        lower.closeSubpath()
        let spot = CGMutablePath()
        let sr = bw * 0.028
        spot.addEllipse(in: CGRect(x: f.cx - sr, y: top + bh * 0.028 - sr, width: sr * 2, height: sr * 2))
        // The head's outline, neck to neck round the crown (a visible head, not a party hat).
        let head = CGMutablePath()
        let cx = f.cx
        func r(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx + bw * fx, y: top + bh * fy) }
        func l(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx - bw * fx, y: top + bh * fy) }
        head.move(to: r(0.16, 0.26))
        head.addCurve(to: r(0.20, 0.15), control1: r(0.16, 0.23), control2: r(0.19, 0.20))
        head.addCurve(to: r(0.075, 0.075), control1: r(0.21, 0.11), control2: r(0.16, 0.075))
        head.addLine(to: l(0.075, 0.075))
        head.addCurve(to: l(0.20, 0.15), control1: l(0.16, 0.075), control2: l(0.21, 0.11))
        head.addCurve(to: l(0.16, 0.26), control1: l(0.19, 0.20), control2: l(0.16, 0.23))
        return TitleDetail(leftBand: band, rightBand: mirrored(band, width: f.w), leftPrimaries: prim,
                           rightPrimaries: mirrored(prim, width: f.w), leftMirrors: mirrors,
                           rightMirrors: mirrored(mirrors, width: f.w), beak: beak, beakSpot: spot, beakLower: lower,
                           headContour: head)
    }

    // MARK: The one bird mark (REVIEW-3 juror #16)

    /// The brand mark: the icon gull's dorsal "M" as one rounded-stroke glyph (wing tip, wrist, the body's dip,
    /// wrist, tip) with a small head, in a `width × height` box, y down. Stroke it at `markLineWidth(forHeight:)`
    /// with round caps and joins. Use it everywhere outside gameplay: the cover, cards, badges, About, the touch glyph.
    static func markPath(width: CGFloat, height: CGFloat) -> CGPath {
        let w = max(width, 1), h = max(height, 1)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: w * 0.04, y: h * 0.66))
        p.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.30), control: CGPoint(x: w * 0.13, y: h * 0.36))
        p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.58), control: CGPoint(x: w * 0.43, y: h * 0.27))
        p.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.30), control: CGPoint(x: w * 0.57, y: h * 0.27))
        p.addQuadCurve(to: CGPoint(x: w * 0.96, y: h * 0.66), control: CGPoint(x: w * 0.87, y: h * 0.36))
        let r = min(w, h) * 0.07
        p.addEllipse(in: CGRect(x: w * 0.5 - r, y: h * 0.40 - r * 2.2, width: r * 2, height: r * 2))
        return p
    }

    /// The mark's stroke width: 2 pt at a 24 pt-tall glyph, scaling with it.
    static func markLineWidth(forHeight height: CGFloat) -> CGFloat {
        max(1, 2 * height / 24)
    }

    // MARK: Extras for the scene (and anyone who wants them)

    /// The outer part of each wing (for the `wingTip` colour), in the same unit box as `path(for:tuck:flap:)`.
    static func wingTipPaths(for bird: Bird, tuck: Double, flap: Double) -> (near: CGPath, far: CGPath) {
        let near = wingGeometry(for: bird, tuck: tuck, flap: flap, far: false)
        let far = wingGeometry(for: bird, tuck: tuck, flap: flap, far: true)
        return (tipPath(near), tipPath(far))
    }

    /// The near wing's leading edge (shoulder → wrist → tip), an open path for the key rim (ART §4).
    static func nearWingLeadingEdge(for bird: Bird, tuck: Double, flap: Double) -> CGPath {
        let w = wingGeometry(for: bird, tuck: tuck, flap: flap, far: false)
        let p = CGMutablePath()
        p.move(to: w.shoulder)
        p.addQuadCurve(to: w.wrist, control: w.lead1)
        p.addQuadCurve(to: w.tip, control: w.lead2)
        return p
    }

    /// The back line (tail → back → nape → crown → forehead), an open path: the key rim that catches the sun ahead.
    static func backLinePath(for bird: Bird) -> CGPath {
        let pt = CGFloat(clamp01(bird.pointiness))
        let hh = bodyHalfHeight(pointiness: pt)
        let tailX: CGFloat = -0.44 - 0.05 * pt
        let forked = pt > 0.6
        let p = CGMutablePath()
        p.move(to: CGPoint(x: forked ? tailX - 0.05 * pt : tailX, y: forked ? 0.03 : 0.012))
        p.addCurve(to: CGPoint(x: 0.20, y: hh * 0.95),
                   control1: CGPoint(x: -0.26, y: hh * 0.62), control2: CGPoint(x: 0.02, y: hh * 1.06))
        p.addCurve(to: CGPoint(x: 0.352, y: hh * 0.45),
                   control1: CGPoint(x: 0.27, y: hh * 1.22), control2: CGPoint(x: 0.345, y: hh * 1.0))
        return p
    }

    /// The belly's lower third (drawn 12 % darker): the body's own breast and belly curves closed by a soft line.
    static func bellyPath(for bird: Bird) -> CGPath {
        let pt = CGFloat(clamp01(bird.pointiness))
        let hh = bodyHalfHeight(pointiness: pt)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.30, y: -hh * 0.55))
        p.addCurve(to: CGPoint(x: 0.14, y: -hh * 1.02),
                   control1: CGPoint(x: 0.29, y: -hh * 0.80), control2: CGPoint(x: 0.25, y: -hh * 1.02))
        p.addCurve(to: CGPoint(x: -0.25, y: -hh * 0.42),
                   control1: CGPoint(x: 0.0, y: -hh * 1.04), control2: CGPoint(x: -0.15, y: -hh * 0.80))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: -hh * 0.55), control: CGPoint(x: 0.02, y: -hh * 0.62))
        p.closeSubpath()
        return p
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
        let spreadLength = (spreadLengthBase + 0.10 * pt) * span * sh.length
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

    /// Everything the title's paths are built from, for one tuck and canvas.
    struct TitleFrame {
        var w: CGFloat
        var cx: CGFloat
        var top: CGFloat
        var bodyW: CGFloat
        var bodyH: CGFloat
        var body: CGPath
        var shoulder: CGPoint
        var length: CGFloat
        var tipAngle: CGFloat
        var bend: CGFloat
        var wrist: CGFloat
        var chordRoot: CGFloat
        var chordTip: CGFloat
        var dihedral: CGFloat
        var kink: CGFloat
        var capStart: CGFloat
        /// 0 spread … 1 tucked (eased): the wing outline morphs point for point into the tucked teardrop.
        var tuckBlend: CGFloat
        var tuckLead0: CGPoint
        var tuckLead1: CGPoint
        var tuckLead2: CGPoint
        var tuckTip: CGPoint
        var tuckRoot: CGPoint
    }

    static func titleFrame(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat) -> TitleFrame {
        let w = max(width, 1), h = max(height, 1)
        let u = CGFloat(clamp01(tuck))
        let e = u * u * (3 - 2 * u)
        let pt = CGFloat(clamp01(bird.pointiness))
        let sh = shape(for: bird.id)
        let cx = w * 0.5, cy = h * 0.5
        let bodyW = min(w * 0.085, h * 0.26)
        let bodyH0 = min(h * 0.70, bodyW * 2.6)
        let top = cy - bodyH0 * 0.52
        // Tucked, the body stretches 6 % (a dart).
        let bodyH = bodyH0 * (1 + 0.06 * e)
        let body = titleBody(cx: cx, top: top, bodyW: bodyW, bodyH: bodyH)
        let shoulder = CGPoint(x: cx - bodyW * 0.30, y: top + bodyH * 0.34)
        // The spread wing (a gull's "M").
        let spreadTip = CGPoint(x: w * titleEdgeMargin, y: shoulder.y)
        let l0 = hypot(shoulder.x - spreadTip.x, spreadTip.y - shoulder.y)
        let a0 = atan2(spreadTip.y - shoulder.y, shoulder.x - spreadTip.x)
        let chordK = min(max(sh.chord, 0.8), 1.2) * (1.08 - 0.16 * pt)
        let chordRoot = min(h * titleChordRoot, bodyH0 * 0.55) * chordK
        let chordTip = min(h * titleChordTip, bodyH0 * 0.17) * chordK
        // The tucked wing (REVIEW-3 juror #5): swept back along the body into one clean teardrop dart. The leading
        // edge leaves the shoulder at 25° below horizontal, bows out to about 0.135 w from the centre line, and closes
        // to a tip 0.18 h behind the tail; the wing fills everything between it and the body (no sticks, no limbs).
        let tail = top + bodyH * 0.97
        let tip = CGPoint(x: cx - w * 0.025, y: min(tail + h * 0.18, h - 4))
        let widest = cx - w * titleTuckedTipX * 0.99
        let dx1 = widest - shoulder.x
        let lead1 = CGPoint(x: shoulder.x + dx1 * 1.15, y: shoulder.y - dx1 * 1.15 * tan(25 * CGFloat.pi / 180))
        let lead2 = CGPoint(x: widest + (cx - widest) * 0.05, y: tip.y - (tip.y - shoulder.y) * 0.30)
        let root = CGPoint(x: cx - bodyW * 0.28, y: top + bodyH * 0.62)
        return TitleFrame(w: w, cx: cx, top: top, bodyW: bodyW, bodyH: bodyH, body: body, shoulder: shoulder,
                          length: l0, tipAngle: a0, bend: 0.04,
                          wrist: min(max(sh.arm * 0.95, 0.30), 0.45), chordRoot: chordRoot, chordTip: chordTip,
                          dihedral: 1, kink: 0.14, capStart: lerp(0.86, 0.93, pt), tuckBlend: e,
                          tuckLead0: shoulder, tuckLead1: lead1, tuckLead2: lead2, tuckTip: tip, tuckRoot: root)
    }

    /// A point on the left title wing at span fraction `t` (0 shoulder … 1 tip) and chord fraction `chord`
    /// (0 leading edge … 1 trailing edge).
    static func titleWingPoint(_ f: TitleFrame, t: CGFloat, chord: CGFloat) -> CGPoint {
        let spread = spreadWingPoint(f, t: t, chord: chord)
        let e = f.tuckBlend
        if e <= 0.0001 { return spread }
        // The tucked teardrop: the leading edge a cubic from the shoulder to the tip, the inner edge the body's side.
        let s1 = 1 - t
        let b0 = s1 * s1 * s1, b1 = 3 * s1 * s1 * t, b2 = 3 * s1 * t * t, b3 = t * t * t
        let lx = b0 * f.tuckLead0.x + b1 * f.tuckLead1.x + b2 * f.tuckLead2.x + b3 * f.tuckTip.x
        let ly = b0 * f.tuckLead0.y + b1 * f.tuckLead1.y + b2 * f.tuckLead2.y + b3 * f.tuckTip.y
        let ix = f.tuckRoot.x + (f.tuckTip.x - f.tuckRoot.x) * t
        let iy = f.tuckRoot.y + (f.tuckTip.y - f.tuckRoot.y) * t
        let tx = lx + (ix - lx) * chord
        let ty = ly + (iy - ly) * chord
        return CGPoint(x: spread.x + (tx - spread.x) * e, y: spread.y + (ty - spread.y) * e)
    }

    /// The spread wing (the gull's "M"): dihedral, wrist kink and tapered chord along the axis from the shoulder.
    private static func spreadWingPoint(_ f: TitleFrame, t: CGFloat, chord: CGFloat) -> CGPoint {
        let s = f.length * t
        let sw = f.length * f.wrist
        // Dihedral, as an offset along the chord normal (negative = toward the head = up when spread).
        var lift: CGFloat
        if s <= sw {
            lift = -tan(titleArmDihedral) * s
        } else {
            lift = -tan(titleArmDihedral) * sw + tan(titleHandDihedral) * (s - sw)
        }
        lift *= f.dihedral
        // The forward kink at the wrist (leading edge only, fading toward the trailing edge).
        let dk = (t - f.wrist) / 0.11
        let kink = -f.kink * f.chordRoot * exp(-dk * dk) * (1 - chord)
        // The chord tapers to the tip, rounding off over the last few percent.
        var c = f.chordRoot + (f.chordTip - f.chordRoot) * pow(t, 0.85)
        if t > f.capStart {
            let k = (t - f.capStart) / (1 - f.capStart)
            c *= max(0, 1 - k * k).squareRoot()
        }
        let off = lift + kink + chord * c
        // Arm along `tipAngle − bend`, hand along `tipAngle`, smooth across the wrist.
        let k0 = min(max((t - f.wrist * 0.75) / (f.wrist * 0.8), 0), 1)
        let k = k0 * k0 * (3 - 2 * k0)
        let a = f.tipAngle - f.bend * (1 - k)
        let dx = -cos(a), dy = sin(a)
        let nx = sin(a), ny = cos(a)
        return CGPoint(x: f.shoulder.x + dx * s + nx * off, y: f.shoulder.y + dy * s + ny * off)
    }

    /// Appends the patch of the left wing between the two chord lines and the two span stations, as one closed
    /// polygon (the full wing is chord 0…1, span 0…1).
    private static func appendTitleWing(_ p: CGMutablePath, _ f: TitleFrame, chordFrom: CGFloat, chordTo: CGFloat,
                                        spanFrom: CGFloat, spanTo: CGFloat) {
        let n = 28
        for i in 0...n {
            let t = spanFrom + (spanTo - spanFrom) * CGFloat(i) / CGFloat(n)
            let q = titleWingPoint(f, t: t, chord: chordFrom)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        var i = n
        while i >= 0 {
            let t = spanFrom + (spanTo - spanFrom) * CGFloat(i) / CGFloat(n)
            p.addLine(to: titleWingPoint(f, t: t, chord: chordTo))
            i -= 1
        }
        p.closeSubpath()
    }

    private static func mirrored(_ path: CGPath, width w: CGFloat) -> CGPath {
        let m = CGMutablePath()
        m.addPath(path, transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0))
        return m
    }

    /// The body from above: beak tip at the top, a round head 1.25× the neck, broad shoulders, the flanks and a short
    /// fanned tail.
    private static func titleBody(cx: CGFloat, top: CGFloat, bodyW: CGFloat, bodyH: CGFloat) -> CGPath {
        let p = CGMutablePath()
        func r(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx + bodyW * fx, y: top + bodyH * fy) }
        func l(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: cx - bodyW * fx, y: top + bodyH * fy) }
        p.move(to: CGPoint(x: cx, y: top))
        // Right side: beak, head, neck, shoulder, flank, tail base, the fan's corner, across the fan's edge.
        p.addLine(to: r(0.075, 0.075))
        p.addCurve(to: r(0.20, 0.15), control1: r(0.16, 0.075), control2: r(0.21, 0.11))
        p.addCurve(to: r(0.16, 0.26), control1: r(0.19, 0.20), control2: r(0.16, 0.23))
        p.addCurve(to: r(0.50, 0.42), control1: r(0.17, 0.31), control2: r(0.47, 0.33))
        p.addCurve(to: r(0.34, 0.70), control1: r(0.53, 0.53), control2: r(0.43, 0.64))
        p.addCurve(to: r(0.15, 0.80), control1: r(0.26, 0.75), control2: r(0.18, 0.77))
        p.addLine(to: r(0.30, 0.97))
        p.addQuadCurve(to: CGPoint(x: cx, y: top + bodyH * 0.95), control: r(0.16, 1.01))
        // Left side, mirrored, back up to the beak.
        p.addQuadCurve(to: l(0.30, 0.97), control: l(0.16, 1.01))
        p.addLine(to: l(0.15, 0.80))
        p.addCurve(to: l(0.34, 0.70), control1: l(0.18, 0.77), control2: l(0.26, 0.75))
        p.addCurve(to: l(0.50, 0.42), control1: l(0.43, 0.64), control2: l(0.53, 0.53))
        p.addCurve(to: l(0.16, 0.26), control1: l(0.47, 0.33), control2: l(0.17, 0.31))
        p.addCurve(to: l(0.20, 0.15), control1: l(0.16, 0.23), control2: l(0.19, 0.20))
        p.addCurve(to: l(0.075, 0.075), control1: l(0.21, 0.11), control2: l(0.16, 0.075))
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
