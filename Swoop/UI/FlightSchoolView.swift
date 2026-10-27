import QuartzCore
import SwiftUI

// R9 (UX-ROUND-9 §1, ART-ROUND-9 §1, AR1/AR2): Flight School taught by the world. No cards, no overline, no praise or
// failure sentences, no Faster! bar or rhythm bar. The guide gull (Scene, from Core's ghost path) flies each move
// first, the live wing diagram rides the bird and shows the move as a dashed ghost pose, and a few words sit beside
// their cue (never on the bird, never in the fold band). Progress is one row of dots. R11: the diagram is a side-on
// hinge, its words (with a muted second line: the rule, the remedy) always under it, the dots beside Skip.

/// Where the school's pieces go (screen points). Pure; tested (fold-clear on every canvas, both bird sides).
struct SchoolLayout: Equatable {
    /// The progress dots: one row, beside Skip at the sea page's bottom corner (R11).
    var dots: CGRect
    var titleBird: CGRect
    /// The Studio's wing diagram (steps 1–2), on the bird page.
    var diagram: CGRect
    /// The Studio's words, under the diagram.
    var prompt: CGRect
    /// The Sea steps' fallback word place (top of the bird page, y 0.16 h) when there is no bird point yet.
    var seaPrompt: CGRect
    /// Step 6's words: under the meter.
    var stormPrompt: CGRect
    /// The low fallback word place on the bird page.
    var seaPromptLow: CGRect
    /// Skip: R12 P0-2 the TRAILING bottom corner, the side the bird flies away from (the bird page's outer corner:
    /// bottom-left unmirrored and on iPhone, bottom-right mirrored), never where the ring lands or the bird is going.
    var skip: CGRect
    /// R12 P0-5: the muted "Your wings" / "Your bird" caption under the big top-down gull (step 1): under its far-page
    /// wing on a Duo (never on the fold), centred under its body on an iPhone.
    var wingsCaption: CGRect = .zero

    /// R12 P0-2: the corner chrome's size: Skip, and the dots pill stacked just above it.
    static let skipWidth: CGFloat = 96
    static let dotsWidth: CGFloat = 100
    static let dotsHeight: CGFloat = 12
    static let dotsGap: CGFloat = 6

    /// R8 P1-9 (kept for the fallback places): true when the bird (+ 60 pt) is under the usual place. Pure; tested.
    nonisolated static func usesLowPrompt(usual: CGRect, low: CGRect, bird: CGPoint?, radius: CGFloat = 44,
                                         wasLow: Bool) -> Bool {
        guard let bird else { return wasLow }
        let r = CGRect(x: bird.x - radius - 60, y: bird.y - radius - 60, width: 2 * (radius + 60),
                       height: 2 * (radius + 60))
        if wasLow { return !r.intersects(low) || r.intersects(usual) }
        return r.intersects(usual) && !r.intersects(low)
    }

    /// The Studio draws the diagram this much larger than at sea.
    static func studioScale(_ compact: Bool) -> CGFloat { compact ? 1.2 : 1.5 }

    static func make(_ c: AppCanvas) -> SchoolLayout {
        let bp = c.birdPage
        let fp = c.farPage
        let compact = c.isCompact
        // R12 P0-2 (s1-08): the landing ring sat under Skip and the dots at the sea page's corner, the one the bird
        // flies TOWARD. Both move to the trailing bottom corner (the bird page's outer corner, behind the bird), the
        // dots stacked just above Skip so the pair stays in that corner, out of the bird's path, on every canvas.
        let skipW = skipWidth
        let skipX = c.mirrored ? bp.maxX - skipW - 8 : bp.minX + 8
        let skip = CGRect(x: skipX, y: c.bottom - AppCanvas.minTap, width: skipW, height: AppCanvas.minTap)
        let dots = CGRect(x: skip.midX - dotsWidth / 2, y: skip.minY - dotsGap - dotsHeight, width: dotsWidth,
                          height: dotsHeight)
        // ART #46: on iPhone the title bird gets y 24 and 0.30 h (it was crammed into the top 95 pt).
        let birdH = compact ? c.size.height * 0.30 : min(max(c.size.height * 0.30, 70), 210)
        let foldMid = (c.foldMinX + c.foldMaxX) / 2
        let half = max(min(foldMid - 12, c.size.width - 12 - foldMid), 0)
        let titleBird = CGRect(x: foldMid - half, y: max(c.insets.top, 0) + (compact ? 24 : 10), width: half * 2,
                               height: birdH)
        // R11 P0-4: the Studio's diagram at its drawn (scaled) size, and its words always under it.
        let k = studioScale(compact)
        let d0 = WingDiagram.size(compact: compact)
        let dSize = CGSize(width: d0.width * k, height: d0.height * k)
        let diagram = CGRect(x: bp.midX - dSize.width / 2, y: titleBird.maxY + (compact ? 10 : 20), width: dSize.width,
                             height: dSize.height)
        let pw = min(300, bp.width)
        let ph: CGFloat = compact ? 50 : 56
        let prompt = CGRect(x: bp.midX - pw / 2, y: min(diagram.maxY + 8, c.bottom - ph - 8), width: pw, height: ph)
        let chromeBottom = PlayLayout.make(c).pause.maxY + 8
        let seaPrompt = CGRect(x: bp.midX - pw / 2, y: max(c.size.height * 0.16, chromeBottom), width: pw, height: 44)
        let seaPromptLow = CGRect(x: bp.midX - pw / 2, y: max(c.size.height - 22 - 6 - 44 - 12, seaPrompt.maxY + 8),
                                  width: pw, height: 44)
        let meter = PlayLayout.make(c).meter
        let stormPrompt = CGRect(x: bp.midX - pw / 2, y: max(meter.maxY + 20, seaPrompt.minY), width: pw, height: 44)
        // Under the gull's far-page wing: off the middle band (both canvases keep words off it) and away from the
        // diagram and its words on the bird page.
        let cw: CGFloat = min(160, fp.width)
        let ch: CGFloat = compact ? 22 : 26
        let wingsCaption = CGRect(x: fp.midX - cw / 2, y: titleBird.maxY + 6, width: cw, height: ch)
        return SchoolLayout(dots: dots, titleBird: titleBird, diagram: diagram, prompt: prompt, seaPrompt: seaPrompt,
                            stormPrompt: stormPrompt, seaPromptLow: seaPromptLow, skip: skip,
                            wingsCaption: wingsCaption)
    }
}

/// The step dots: 6 pt, done foam, current reward gold, to do white at 25 % (R11 P1-12: one count, sequential).
/// Beside Skip at the sea page's bottom corner.
struct SchoolDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Circle()
                    .fill(i < current ? SwoopTheme.foam : (i == current ? SwoopTheme.rewardGold : Color.white.opacity(0.25)))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(0.45)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flight School, step \(current + 1) of \(count)")
    }
}

/// In-world words (≤ 4, no full stop): `headline` foam on a soft 0.45 navy glow, not a panel (UX-ROUND-9 §1.1 rule 2).
/// R11 P0-3: an optional muted second line under them ("Open at the bottom", the remedy after a miss).
/// R12 P1-8 (s1-08: the sun-glint dashes ran through "Land here"): at sea the words sit on a soft navy backing, as
/// R8 P1-10's prompts did: a feathered scrim, not a panel, so no glint, spray or sky streak runs through them.
struct SchoolWord: View {
    let text: String
    var sub: String? = nil
    var compact = false
    var backed = false

    /// The backing's opacity and feather (pure; the words' contrast over the brightest glint).
    nonisolated static let backingOpacity: Double = 0.5
    nonisolated static let backingFeather: CGFloat = 8

    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(SwoopType.headline(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .fixedSize()
            if let sub {
                Text(sub)
                    .font(SwoopType.body(compact).weight(.semibold))
                    .foregroundStyle(SwoopTheme.foam.opacity(0.82))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.45), radius: 10)
        .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.45), radius: 4)
        .background {
            if backed {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(swoopHex: Contrast.scrim).opacity(Self.backingOpacity))
                    .padding(EdgeInsets(top: -8, leading: -16, bottom: -8, trailing: -16))
                    .blur(radius: Self.backingFeather)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Where the bird-anchored pieces go (ART-ROUND-9 §1D, UX-ROUND-9 §1.1 rule 2). Pure; tested.
enum SchoolRig {
    /// The gap between the diagram and its words.
    static let wordsGap: CGFloat = 6
    /// The words' block clears the bird's rect (radius 44) by this much (UX-ROUND-9 §4.4: 80 pt, + 2 for rounding).
    static let birdClear: CGFloat = 82

    /// The words' block: one line, or two with the muted second line. Pure; tested.
    static func wordsSize(compact: Bool, hasSub: Bool) -> CGSize {
        CGSize(width: compact ? 220 : 240, height: (compact ? 26 : 30) + (hasSub ? (compact ? 20 : 22) : 0))
    }

    /// R11 P0-4: the diagram's centre, with its words ALWAYS under it (the same place on every step): above the bird
    /// when the diagram and its words fit there with the words ≥ 82 pt off the bird's rect, else below the bird (the
    /// words then furthest from it); with room for neither, the side with more. Kept inside the bird page, ≥ 28 pt off
    /// the fold band and ≥ 24 pt off the edges. Pure; tested.
    static func diagramCenter(bird: CGPoint, canvas c: AppCanvas, hasSub: Bool = false) -> CGPoint {
        let s = WingDiagram.size(compact: c.isCompact)
        let w = wordsSize(compact: c.isCompact, hasSub: hasSub)
        let place = placement(bird: bird, canvas: c, hasSub: hasSub)
        let y = place.above ? bird.y - 44 - birdClear - w.height - wordsGap - s.height / 2
            : bird.y + 44 + belowGap(c) + s.height / 2
        return clamp(CGPoint(x: bird.x, y: y), size: s, canvas: c)
    }

    /// Below the bird, the diagram's gap: enough that its words (under it) clear the bird by `birdClear`.
    static func belowGap(_ c: AppCanvas) -> CGFloat {
        max(24, birdClear - WingDiagram.size(compact: c.isCompact).height - wordsGap)
    }

    /// Whether the diagram + words block goes above the bird, and whether it fits anywhere at all. Pure; tested.
    static func placement(bird: CGPoint, canvas c: AppCanvas, hasSub: Bool) -> (above: Bool, fits: Bool) {
        let s = WingDiagram.size(compact: c.isCompact)
        let block = s.height + wordsGap + wordsSize(compact: c.isCompact, hasSub: hasSub).height
        let roomAbove = (bird.y - 44 - birdClear - block) - (c.top + 24)
        let roomBelow = (c.size.height - 24) - (bird.y + 44 + belowGap(c) + block)
        let above = roomAbove >= 0 || (roomBelow < 0 && roomAbove > roomBelow)
        return (above, roomAbove >= 0 || roomBelow >= 0)
    }

    /// The muted second line shows only where the block still fits by the bird (the smallest iPhone with the bird at
    /// mid-height has room for one line). Pure; tested.
    static func showsSub(bird: CGPoint, canvas c: AppCanvas, anchor: SchoolWordsAnchor) -> Bool {
        guard anchor == .diagram else { return true }
        return placement(bird: bird, canvas: c, hasSub: true).fits
    }

    /// The words' centre for an anchor, ≥ 80 pt clear of the bird's rect (radius 44), off the fold band.
    static func wordsCenter(anchor: SchoolWordsAnchor, bird: CGPoint, canvas c: AppCanvas,
                            layout l: SchoolLayout, showsDiagram: Bool, ring: CGRect? = nil,
                            ghost: CGPoint? = nil, hasSub: Bool = false) -> CGPoint {
        let size = wordsSize(compact: c.isCompact, hasSub: hasSub)
        let birdRect = CGRect(x: bird.x - 44, y: bird.y - 44, width: 88, height: 88)
        let far = anchor == .ring
        func clear(_ p: CGPoint) -> CGPoint {
            var q = clamp(p, size: size, canvas: c, allowFar: far)
            // Move up (or down) until the words' rect is 80 pt off the bird.
            let r = { (q: CGPoint) in CGRect(x: q.x - size.width / 2, y: q.y - size.height / 2, width: size.width,
                                              height: size.height) }
            // Off the guide gull too (Scene's `ghostScreenPoint`), sideways.
            if let g = ghost, r(q).insetBy(dx: -40, dy: -40).contains(g) {
                q.x += (g.x < q.x ? 1 : -1) * (size.width / 2 + 60)
                q = clamp(q, size: size, canvas: c, allowFar: far)
            }
            if r(q).insetBy(dx: -80, dy: -80).intersects(birdRect) {
                let upY = birdRect.minY - birdClear - size.height / 2
                let downY = birdRect.maxY + birdClear + size.height / 2
                q.y = upY - size.height / 2 > c.top + 8 ? upY : downY
                q = clamp(q, size: size, canvas: c, allowFar: far)
            }
            return q
        }
        switch anchor {
        case .meter:
            return CGPoint(x: l.stormPrompt.midX, y: l.stormPrompt.midY)
        case .pages:
            return CGPoint(x: c.size.width / 2, y: c.size.height * 0.2)
        case .diagram:
            guard showsDiagram else { return clear(CGPoint(x: bird.x, y: bird.y - 130)) }
            // R11 P0-4: always under the diagram (s1-05 had "Fold" above it, s1-03 below).
            let d = diagramCenter(bird: bird, canvas: c, hasSub: hasSub)
            let s = WingDiagram.size(compact: c.isCompact)
            return clear(CGPoint(x: d.x, y: d.y + s.height / 2 + wordsGap + size.height / 2))
        case .spot:
            return clear(CGPoint(x: bird.x, y: bird.y - 130))
        case .ring:
            // R11 P0-5: next to the ring they name: just above Scene's drop marker (`ringScreenRect` covers the
            // ellipse and its chevron); else ahead of the bird. `RingPointer` draws the dotted line if they moved.
            if let ring { return clear(CGPoint(x: ring.midX, y: ring.minY - 6 - size.height / 2)) }
            let ahead: CGFloat = c.mirrored ? -240 : 240
            return clear(CGPoint(x: bird.x + ahead, y: bird.y - 110))
        }
    }

    /// R11 P0-5: the dotted line (with a chevron) from the words down to the ring, when the words could not sit right
    /// on its drop marker (nil: they do, or there is no ring). Pure; tested.
    static func ringPointer(words: CGPoint, size: CGSize, ring: CGRect?) -> (from: CGPoint, to: CGPoint)? {
        guard let ring, ring.width > 0, ring.height > 0 else { return nil }
        let from = CGPoint(x: words.x, y: words.y + size.height / 2 + 4)
        let to = CGPoint(x: ring.midX, y: ring.minY)
        let dx = to.x - from.x, dy = to.y - from.y
        return dx * dx + dy * dy > 24 * 24 ? (from, to) : nil
    }

    /// R12 P0-1: the ring the words sit by and point at: only a ring in view (fully on screen, ahead of the bird) for
    /// words that name it; nil otherwise, so no pointer ever runs off an edge or back to a ring behind. Pure; tested.
    static func pointerRing(anchor: SchoolWordsAnchor, ring: CGRect?, ringInView: Bool) -> CGRect? {
        anchor == .ring && ringInView ? ring : nil
    }

    /// R12 P1-7 (iPhone s1-12: "Gull Point" drawn through its own tower): the lighthouse's name sits above the lamp
    /// with its bottom ≥ `lampClear` over it; where the top of the screen leaves no room, beside the tower (on the
    /// side toward the screen's middle), level with the lamp. Pure; tested.
    static let lampClear: CGFloat = 22
    static func lampLabelSize(compact: Bool) -> CGSize { CGSize(width: compact ? 130 : 150, height: compact ? 26 : 30) }
    static func lampLabelCenter(lamp: CGPoint, canvas c: AppCanvas) -> CGPoint {
        let s = lampLabelSize(compact: c.isCompact)
        let above = lamp.y - lampClear - s.height / 2
        if above - s.height / 2 >= c.top { return CGPoint(x: lamp.x, y: above) }
        let towardMiddle: CGFloat = lamp.x > c.size.width / 2 ? -1 : 1
        let x = lamp.x + towardMiddle * (s.width / 2 + 18)
        return CGPoint(x: x, y: max(lamp.y, c.top + s.height / 2))
    }

    /// R10: the big "Perfect": above the bird (≥ 80 pt off it), on its page.
    static func bigWordCenter(bird: CGPoint, canvas c: AppCanvas) -> CGPoint {
        let size = CGSize(width: 260, height: 56)
        let up = CGPoint(x: bird.x, y: bird.y - 44 - 80 - size.height / 2)
        let p = up.y - size.height / 2 > c.top + 8 ? up : CGPoint(x: bird.x, y: bird.y + 44 + 80 + size.height / 2)
        return clamp(p, size: size, canvas: c)
    }

    /// Inside one page, ≥ 24 pt off the edges and ≥ 28 pt off the middle band. The iPhone is laid out as two pages
    /// as well (every screen keeps content off its middle band, `AppCanvas.isFoldClear`), so the same rule holds there.
    /// The bird page, unless `allowFar` and the point is on the far page (the ring's words may sit by the ring).
    static func clamp(_ p: CGPoint, size s: CGSize, canvas c: AppCanvas, allowFar: Bool = false) -> CGPoint {
        let mid = (c.foldMinX + c.foldMaxX) / 2
        let birdOnRight = c.birdPage.midX > mid
        let useFar = allowFar && (p.x > mid) != birdOnRight
        var page = useFar ? c.farPage : c.birdPage
        if (useFar ? !birdOnRight : birdOnRight) {
            let minX = c.foldMaxX + 28
            if page.minX < minX { page = CGRect(x: minX, y: page.minY, width: max(page.maxX - minX, 0), height: page.height) }
        } else {
            let maxX = c.foldMinX - 28
            if page.maxX > maxX { page.size.width = max(maxX - page.minX, 0) }
        }
        let inset = page.insetBy(dx: 24 + s.width / 2, dy: 24 + s.height / 2)
        guard inset.width > 0, inset.height > 0 else { return CGPoint(x: page.midX, y: page.midY) }
        return CGPoint(x: min(max(p.x, inset.minX), inset.maxX), y: min(max(p.y, inset.minY), inset.maxY))
    }
}

/// R11 P0-4: the wing diagram is a SIDE-ON HINGE: the Duo seen from its spine end, two plates meeting at the hinge.
/// "Hold it open" is the near-flat line (174°), "Fold a little" the visibly narrower wedge (135°), each drawn dashed as
/// the target (teal open, gold folded) with its wedge tinted; the live pose (the player's real tuck) moves inside it,
/// with a chevron at each tip pointing the way to move. The plates' rise is exaggerated (φd = min(1.6 · (180° − θ) / 2,
/// 60°)) so the fold reads at arm's length. During a demonstration the ghost pose plays dashed in foam; the done state
/// shows the reached pose with a gold tick. The touch variant is a fingertip pressing (no book).
struct WingDiagram: View {
    /// The live hinge angle (θ, degrees). R11: the drawing follows `tuck` (the calibrated wings), so the live plates
    /// meet the targets exactly; the angle is kept for the API.
    let angle: Double
    let tuck: Double
    /// The ghost's pose (tuck 0…1) while a demonstration plays, else nil.
    var ghostTuck: Double?
    /// R10 P0-3: the pose the step's words ask for, drawn dashed over the live diagram (gold folded, teal open).
    var target: Double?
    var touch = false
    var compact = false
    var mirrored = false
    /// R11 P0-4: the step's success: the reached pose with a tick.
    var done = false

    nonisolated static func size(compact: Bool) -> CGSize {
        compact ? CGSize(width: 96, height: 48) : CGSize(width: 124, height: 64)
    }

    /// The open ("Hold it open", wings spread) and folded ("Fold a little") targets, in hinge degrees.
    nonisolated static let openHinge: Double = 174
    nonisolated static let foldHinge: Double = 135

    /// φd (radians): each plate's drawn rise above flat for a hinge angle θ. Pure; tested.
    nonisolated static func displayAngle(hinge theta: Double) -> Double {
        let t = min(max(theta.isFinite ? theta : 180, 100), 180)
        return min(1.6 * (180 - t) / 2, 60) * Double.pi / 180
    }

    /// R12 P0-4: the pose the drawing shows. Done: the TARGET (the pose the words asked for), whatever the hands did;
    /// otherwise the live pose, clamped so it never folds past a fold target. The diagram is never a different shape
    /// from the one its words ask for. Pure; tested.
    nonisolated static func drawnTuck(live: Double, target: Double?, done: Bool) -> Double {
        let u = live.isFinite ? min(max(live, 0), 1) : 0
        guard let target, target.isFinite else { return u }
        let t = min(max(target, 0), 1)
        if done { return t }
        return t > 0.5 ? min(u, t) : u
    }

    /// The hinge angle a tuck 0…1 shows: open 174° … folded 135°. Pure; tested.
    nonisolated static func hinge(forTuck u: Double) -> Double {
        let k = u.isFinite ? min(max(u, 0), 1) : 0
        return openHinge - (openHinge - foldHinge) * k
    }

    /// The hinge (the pivot) and the two plate tips for a drawn rise `phi`, in a box of `size` (y down). Pure; tested.
    nonisolated static func plates(phi: Double, size: CGSize, lengthScale: CGFloat = 1)
        -> (hinge: CGPoint, left: CGPoint, right: CGPoint) {
        let pivot = CGPoint(x: size.width / 2, y: size.height - 10)
        let length = (size.width / 2 - 8) * lengthScale
        let c = CGFloat(cos(phi)), s = CGFloat(sin(phi))
        return (pivot, CGPoint(x: pivot.x - length * c, y: pivot.y - length * s),
                CGPoint(x: pivot.x + length * c, y: pivot.y - length * s))
    }

    var body: some View {
        let s = Self.size(compact: compact)
        Group {
            if touch {
                TouchWingDiagram(pressed: (ghostTuck ?? tuck) > 0.5, ghost: ghostTuck != nil,
                                 target: target.map { $0 > 0.5 }, done: done)
            } else {
                Canvas { ctx, size in
                    let live = Self.drawnTuck(live: ghostTuck ?? tuck, target: target, done: done)
                    let phi = Self.displayAngle(hinge: Self.hinge(forTuck: live))
                    let p = Self.plates(phi: phi, size: size)
                    let plateWidth: CGFloat = compact ? 6 : 7
                    // R12 P0-4: done draws the TARGET pose filled (its wedge, its plates solid), with the tick: the
                    // very shape the dashed target showed, never the deeper fold the hands (or the demo) made.
                    if done, let target {
                        let tphi = Self.displayAngle(hinge: Self.hinge(forTuck: target))
                        let t = Self.plates(phi: tphi, size: size, lengthScale: 1.08)
                        let colour = target > 0.5 ? SwoopTheme.rewardGold : SwoopTheme.accentOn
                        var wedge = Path()
                        wedge.move(to: t.hinge)
                        wedge.addLine(to: t.left)
                        wedge.addLine(to: t.right)
                        wedge.closeSubpath()
                        ctx.fill(wedge, with: .color(colour.opacity(0.38)))
                        var solid = Path()
                        solid.move(to: t.left)
                        solid.addLine(to: t.hinge)
                        solid.addLine(to: t.right)
                        ctx.stroke(solid, with: .color(Color(swoopHex: Contrast.scrim).opacity(0.55)),
                                   style: StrokeStyle(lineWidth: plateWidth + 3, lineCap: .round, lineJoin: .round))
                        ctx.stroke(solid, with: .color(DuoDiagram.bodyColor),
                                   style: StrokeStyle(lineWidth: plateWidth, lineCap: .round, lineJoin: .round))
                        ctx.stroke(solid, with: .color(colour),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        let r: CGFloat = compact ? 4 : 5
                        ctx.fill(Path(ellipseIn: CGRect(x: t.hinge.x - r, y: t.hinge.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(DuoDiagram.spine))
                        return
                    }
                    // The target first, under the live plates: its wedge tinted, its plates dashed.
                    if let target, !done {
                        let tphi = Self.displayAngle(hinge: Self.hinge(forTuck: target))
                        let t = Self.plates(phi: tphi, size: size, lengthScale: 1.08)
                        let colour = target > 0.5 ? SwoopTheme.rewardGold : SwoopTheme.accentOn
                        var wedge = Path()
                        wedge.move(to: t.hinge)
                        wedge.addLine(to: t.left)
                        wedge.addLine(to: t.right)
                        wedge.closeSubpath()
                        ctx.fill(wedge, with: .color(colour.opacity(0.18)))
                        var dashed = Path()
                        dashed.move(to: t.left)
                        dashed.addLine(to: t.hinge)
                        dashed.addLine(to: t.right)
                        ctx.stroke(dashed, with: .color(colour.opacity(0.95)),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [5, 4]))
                        // The way to move: a chevron at each live tip, toward the target's tip.
                        if abs(tphi - phi) > 4 * Double.pi / 180 {
                            for (tip, goal) in [(p.left, t.left), (p.right, t.right)] {
                                let dx = goal.x - tip.x, dy = goal.y - tip.y
                                let d = max(sqrt(dx * dx + dy * dy), 0.001)
                                let ux = dx / d, uy = dy / d
                                let apex = CGPoint(x: tip.x + ux * 9, y: tip.y + uy * 9)
                                var chev = Path()
                                chev.move(to: CGPoint(x: apex.x - ux * 5 - uy * 4, y: apex.y - uy * 5 + ux * 4))
                                chev.addLine(to: apex)
                                chev.addLine(to: CGPoint(x: apex.x - ux * 5 + uy * 4, y: apex.y - uy * 5 - ux * 4))
                                ctx.stroke(chev, with: .color(colour),
                                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                    var plates = Path()
                    plates.move(to: p.left)
                    plates.addLine(to: p.hinge)
                    plates.addLine(to: p.right)
                    if ghostTuck != nil {
                        // The demonstration's pose: dashed foam (watch, then your turn).
                        ctx.stroke(plates, with: .color(SwoopTheme.foam.opacity(0.75)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [5, 4]))
                    } else {
                        ctx.stroke(plates, with: .color(Color(swoopHex: Contrast.scrim).opacity(0.55)),
                                   style: StrokeStyle(lineWidth: plateWidth + 3, lineCap: .round, lineJoin: .round))
                        ctx.stroke(plates, with: .color(DuoDiagram.bodyColor),
                                   style: StrokeStyle(lineWidth: plateWidth, lineCap: .round, lineJoin: .round))
                        // The screens' faces: gold folded, teal open.
                        let face = done || live > 0.6 ? SwoopTheme.rewardGold
                            : (live < 0.2 ? SwoopTheme.accentOn : SwoopTheme.foam.opacity(0.7))
                        ctx.stroke(plates, with: .color(face),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    let r: CGFloat = compact ? 4 : 5
                    ctx.fill(Path(ellipseIn: CGRect(x: p.hinge.x - r, y: p.hinge.y - r, width: 2 * r, height: 2 * r)),
                             with: .color(DuoDiagram.spine.opacity(ghostTuck != nil ? 0.5 : 1)))
                }
                .overlay(alignment: .topTrailing) {
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: compact ? 18 : 22, weight: .bold))
                            .foregroundStyle(SwoopTheme.rewardGold)
                            .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.6), radius: 4)
                    }
                }
            }
        }
        .frame(width: s.width, height: s.height)
        .accessibilityHidden(true)
    }
}

/// R11 P0-4: the touch diagram in the same slot: a fingertip pressing (no book, no phone). Pressed, its ring grows
/// gold; the target ring (dashed) says hold (gold) or let go (teal); done shows the tick.
struct TouchWingDiagram: View {
    let pressed: Bool
    var ghost = false
    /// true: the words ask to hold; false: to let go; nil: no target.
    var target: Bool? = nil
    var done = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let ring = h * 0.92
            ZStack {
                if let target, !done {
                    Circle()
                        .stroke((target ? SwoopTheme.rewardGold : SwoopTheme.accentOn).opacity(0.95),
                                style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                        .frame(width: target ? ring : ring * 0.55, height: target ? ring : ring * 0.55)
                }
                Circle()
                    .fill((pressed || done ? SwoopTheme.rewardGold : SwoopTheme.accentOn).opacity(ghost ? 0.12 : 0.3))
                    .overlay(Circle().stroke(ghost ? SwoopTheme.foam.opacity(0.7) : SwoopTheme.foam.opacity(0.85),
                                             style: StrokeStyle(lineWidth: 2, dash: ghost ? [5, 4] : [])))
                    .frame(width: pressed || done ? ring * 0.85 : ring * 0.5, height: pressed || done ? ring * 0.85 : ring * 0.5)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: h * 0.46, weight: .semibold))
                    .foregroundStyle(SwoopTheme.foam.opacity(ghost ? 0.6 : 1))
                    .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.6), radius: 3)
                    .offset(x: h * 0.12, y: h * 0.16)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: h * 0.36, weight: .bold))
                        .foregroundStyle(SwoopTheme.rewardGold)
                        .position(x: w * 0.5 + ring * 0.5, y: h * 0.18)
                }
            }
            .frame(width: w, height: h)
        }
        .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

/// R11 P0-5: the s1-09 treatment for words that name a ring: a dotted gold line down to it, with a chevron at its end.
struct RingPointer: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        let dx = to.x - from.x, dy = to.y - from.y
        let d = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / d, uy = dy / d
        ZStack {
            Path { p in
                p.move(to: from)
                p.addLine(to: CGPoint(x: to.x - ux * 6, y: to.y - uy * 6))
            }
            .stroke(SwoopTheme.rewardGold.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 7]))
            Path { p in
                p.move(to: CGPoint(x: to.x - ux * 12 - uy * 8, y: to.y - uy * 12 + ux * 8))
                p.addLine(to: to)
                p.addLine(to: CGPoint(x: to.x - ux * 12 + uy * 8, y: to.y - uy * 12 - ux * 8))
            }
            .stroke(SwoopTheme.rewardGold, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.45), radius: 3)
        .accessibilityHidden(true)
    }
}

/// The bird-anchored layer of the Sea steps: the live diagram (until step 3 has passed) and the step's words.
struct SchoolBirdRig: View {
    @ObservedObject var hud: HUDState
    @ObservedObject var controller: GameController
    let display: SchoolDisplay
    let info: AppCanvas
    let layout: SchoolLayout

    var body: some View {
        let bird = hud.birdPoint ?? SceneAdapter.defaultBirdPoint(info)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let now = CACurrentMediaTime()
            // The dashed pose is the guide gull's own (Scene `ghostTuck`) while it flies; Studio steps use the script.
            let elapsed = display.frozenElapsed ?? (now - display.stepStartedAt)
            let sceneGhost = controller.ghostTuckForDiagram
            let scripted = FlightSchool.hasDemo(display.step) && elapsed < FlightSchool.ghostDemoSeconds
                && !display.isSea
            let ghostPose: Double? = sceneGhost ?? (scripted ? FlightSchool.ghostTuck(display.step, elapsed: elapsed) : nil)
            // R12 P0-1: the words name a ring (and point at it) only while it is fully on screen AHEAD of the bird.
            let ringRect = controller.ringScreenRect
            let ringInView = SchoolRingRule.ringInView(ringRect, bird: bird, screen: info.size, mirrored: info.mirrored)
            let shown = display.shownWords(ringInView: ringInView)
            let anchor = shown?.anchor ?? display.wordsAnchor
            let hasSub = shown?.sub != nil && SchoolRig.showsSub(bird: bird, canvas: info, anchor: anchor)
            ZStack(alignment: .topLeading) {
                if display.showsDiagram {
                    // R11 P0-4: the ONE wing indicator; its words always under it.
                    let p = SchoolRig.diagramCenter(bird: bird, canvas: info, hasSub: hasSub)
                    WingDiagram(angle: controller.hingeAngleForDiagram,
                                tuck: display.touch ? controller.touchTuck(now: now) : controller.diagramTuck,
                                ghostTuck: ghostPose, target: display.diagramTarget,
                                touch: display.touch, compact: info.isCompact, mirrored: info.mirrored)
                        .position(p)
                        .animation(.easeOut(duration: 0.15), value: p)
                }
                if let shown {
                    let ring = SchoolRig.pointerRing(anchor: shown.anchor, ring: ringRect, ringInView: ringInView)
                    let p = SchoolRig.wordsCenter(anchor: shown.anchor, bird: bird, canvas: info, layout: layout,
                                                  showsDiagram: display.showsDiagram,
                                                  ring: ring, ghost: controller.ghostScreenPoint, hasSub: hasSub)
                    // R11 P0-5: the words point at the ring they name when they could not sit right on it (R12: only a
                    // ring in view; never a pointer off the edge or behind the bird).
                    if let line = SchoolRig.ringPointer(words: p, size: SchoolRig.wordsSize(compact: info.isCompact,
                                                                                            hasSub: hasSub),
                                                        ring: ring) {
                        RingPointer(from: line.from, to: line.to)
                    }
                    // R12 P1-8: on the soft navy backing (the sun-glint ran through "Land here").
                    SchoolWord(text: shown.text, sub: hasSub ? shown.sub : nil, compact: info.isCompact, backed: true)
                        .position(p)
                        .animation(.easeOut(duration: 0.15), value: p)
                        .transition(.opacity)
                }
                // R10 P0-1: "Perfect", big, as the moment lands (step 4's Perfect, step 6's push).
                if let big = display.bigWord {
                    SchoolBigWord(text: big, compact: info.isCompact)
                        .position(SchoolRig.bigWordCenter(bird: bird, canvas: info))
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
                // Step 6: the in-world name by Gull Point's lamp as it rises (Scene `schoolLighthouse`).
                if display.step == .storm, let lamp = hud.lampPoint {
                    // R12 P1-7: above its lamp, or beside the tower when the top leaves no room (never through it).
                    let s = info.screenPoint(lamp)
                    SchoolWord(text: RouteRules.name(0), compact: info.isCompact)
                        .position(SchoolRig.lampLabelCenter(lamp: s, canvas: info))
                        .transition(.opacity)
                }
            }
            .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

/// Steps 1–2 (the Studio): the title bird across both halves mirroring the wings, the live wing diagram on the bird
/// page with its words, the clear-side check in step 2, the dots, the pause (from step 1) and Skip.
struct SchoolStudioView: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    @State private var heldSince: Double?
    @State private var releasedAt: Double?
    @State private var touching = false

    /// The fold the wings step asks for.
    nonisolated static let foldTarget: Double = 118

    /// The wings step's success shows the fold done (the bird fully folded, the diagram at the target). Pure; tested.
    nonisolated static func showsDoneFold(_ d: SchoolDisplay) -> Bool { d.step == .wings && d.praise != nil }

    /// R11 P1-11: the Studio's text and diagram, which the attract gull keeps under (`homeTextRects`). Pure; tested.
    nonisolated static func textRects(_ l: SchoolLayout) -> [CGRect] { [l.diagram.union(l.prompt)] }

    var body: some View {
        let l = SchoolLayout.make(info)
        let d = controller.schoolDisplay
        ZStack(alignment: .topLeading) {
            SwoopTheme.abyss.opacity(0.25)
                .frame(width: info.size.width, height: info.size.height)
                .allowsHitTesting(false)
            if d.step == .wingCheck {
                WingCheckPages(controller: controller, info: info, phase: d.wingPhase,
                               needsFlatHelp: d.wingNeedsFlatHelp, onAnswer: { controller.answerWingCheck($0) })
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                    let now = CACurrentMediaTime()
                    let doneFold = Self.showsDoneFold(d)
                    let elapsed = d.frozenElapsed ?? (now - d.stepStartedAt)
                    let demo = FlightSchool.hasDemo(d.step) && elapsed < FlightSchool.ghostDemoSeconds
                    let liveTuck = d.touch ? controller.touchTuck(now: now)
                        : controller.titleTuck(now: now, heldSince: heldSince, releasedAt: releasedAt)
                    let tuck = doneFold ? 1 : liveTuck
                    let target = d.diagramTarget
                    ZStack(alignment: .topLeading) {
                        TitleBirdView(bird: controller.bird, tuck: tuck)
                            .frame(width: l.titleBird.width, height: l.titleBird.height)
                            .position(x: l.titleBird.midX, y: l.titleBird.midY)
                        // R11 P0-4: the side-on hinge. R12 P0-4: done draws the step's TARGET pose filled with the tick
                        // (s1-04 showed the demo's full fold, deeper than "Fold a little").
                        WingDiagram(angle: doneFold ? Self.foldTarget : controller.hingeAngleForDiagram,
                                    tuck: doneFold ? 1 : (d.touch ? (touching ? 1 : 0) : liveTuck),
                                    ghostTuck: demo && !doneFold ? FlightSchool.ghostTuck(d.step, elapsed: elapsed) : nil,
                                    target: d.praise != nil ? FlightSchool.doneTarget(d.step) : target,
                                    touch: d.touch, compact: info.isCompact, mirrored: info.mirrored,
                                    done: d.praise != nil)
                            .scaleEffect(SchoolLayout.studioScale(info.isCompact))
                            .position(x: l.diagram.midX, y: l.diagram.midY)
                    }
                    .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
                }
                .allowsHitTesting(false)
                // R12 P0-5: which bird is me. Under the big top-down gull on the first step: the halves are "Your
                // wings" (Duo) / "Your bird" (touch); it fades as the step completes.
                if let caption = d.wingsCaption(hasFold: info.hasFold) {
                    Text(caption)
                        .font(SwoopType.body(info.isCompact).weight(.semibold))
                        .foregroundStyle(SwoopTheme.mist.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize()
                        .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.5), radius: 4)
                        .opacity(d.praise == nil ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: d.praise == nil)
                        .position(x: l.wingsCaption.midX, y: l.wingsCaption.midY)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if let words = d.words {
                    // The words always sit in one place: under the diagram.
                    SchoolWord(text: words, sub: d.wordsSub, compact: info.isCompact)
                        .position(x: l.prompt.midX, y: l.prompt.minY + SchoolRig.wordsSize(compact: info.isCompact,
                                                                                         hasSub: d.wordsSub != nil).height / 2)
                        .transition(.opacity)
                }
                if d.offersTouch {
                    SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(info.isCompact),
                                compact: info.isCompact, action: { controller.schoolPlayWithTouch() }) {
                        Text("Play with touch").lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(width: min(l.prompt.width, 260))
                    .position(x: l.prompt.midX, y: min(l.prompt.maxY + 40, l.dots.minY - 34))
                }
            }
            if d.showsDots {
                SchoolDots(current: d.dotIndex, count: d.stepCount)
                    .position(x: l.dots.midX, y: l.dots.midY)
            }
            // ART #11: the pause is there from step 1, in its play position and style.
            SchoolPauseButton(compact: info.isCompact) { controller.pauseSchoolStudio() }
                .position(x: PlayLayout.make(info).pause.midX, y: PlayLayout.make(info).pause.midY)
            if d.canSkip { SchoolSkipButton(compact: info.isCompact, layout: l) { controller.skipSchool() } }
            if controller.schoolStudioPaused {
                Color.black.opacity(0.35).frame(width: info.size.width, height: info.size.height)
                SchoolPauseCard(compact: info.isCompact, onResume: { controller.resumeSchoolStudio() },
                                onSkip: { controller.skipSchool() }, onHome: { controller.goHome() })
                    .frame(width: min(info.birdPage.width - 32, 400))
                    .position(x: info.birdPage.midX, y: info.size.height / 2)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        // R11 P1-11: the attract gull behind the Studio keeps under the diagram and its words (s1-03: its wing sat on
        // "Hold anywhere"). Scene's `homeTextRects` is the existing hook; set again after Home's own clear.
        .onAppear { controller.setHomeTextRects(Self.textRects(l)) }
        .task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            controller.setHomeTextRects(Self.textRects(SchoolLayout.make(info)))
        }
        .onChange(of: info) { _, _ in controller.setHomeTextRects(Self.textRects(SchoolLayout.make(info))) }
        .onDisappear { controller.setHomeTextRects([]) }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard d.touch, !touching, !controller.schoolStudioPaused else { return }
                    touching = true
                    heldSince = CACurrentMediaTime()
                    controller.touchBegan()
                }
                .onEnded { _ in
                    guard touching else { return }
                    touching = false
                    releasedAt = CACurrentMediaTime()
                    controller.touchEnded()
                }
        )
    }
}

/// ART #12: in play and school the pause is a solid `surface` disc at 0.82 with a 1 pt hairline (glass only in menus).
struct SchoolPauseButton: View {
    var compact = false
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SwoopTheme.foam)
                .frame(width: 44, height: 44)
                .background(Circle().fill(SwoopTheme.surface.opacity(0.82))
                    .overlay(Circle().stroke(SwoopTheme.stroke, lineWidth: 1)))
                .frame(width: AppCanvas.minTap, height: AppCanvas.minTap)
                .contentShape(Circle())
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel("Pause")
    }
}

/// ART #49: the tertiary Skip, on `surface` at 0.82, at the sea page's bottom outer corner.
struct SchoolSkipButton: View {
    var compact = false
    let layout: SchoolLayout
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            Text("Skip")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.foam)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule().fill(SwoopTheme.surface.opacity(0.82))
                    .overlay(Capsule().stroke(SwoopTheme.stroke, lineWidth: 1)))
                .frame(width: layout.skip.width, height: layout.skip.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(SwoopPressStyle())
        .position(x: layout.skip.midX, y: layout.skip.midY)
        .accessibilityLabel("Skip Flight School")
    }
}

/// Steps 3–6 (the Sea): the bird rig (diagram and words), the dots and Skip over the practice sea (PlayLayer draws
/// the pause).
struct SchoolSeaChrome: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    var body: some View {
        let l = SchoolLayout.make(info)
        let d = controller.schoolDisplay
        ZStack(alignment: .topLeading) {
            SchoolBirdRig(hud: controller.hud, controller: controller, display: d, info: info, layout: l)
            if d.showsDots {
                SchoolDots(current: d.dotIndex, count: d.stepCount)
                    .position(x: l.dots.midX, y: l.dots.midY)
                    .allowsHitTesting(false)
            }
            if d.canSkip { SchoolSkipButton(compact: info.isCompact, layout: l) { controller.skipSchool() } }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

/// Step 2 "Clear side" (UX-ROUND-9 §1.2): three words on BOTH halves, "Open flat" → "Now fold" → "Tap clear side";
/// at the ask each half is the button and shows Art's test pattern. "Skip" grows to a 56 pt button after 10 s.
struct WingCheckPages: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let phase: WingCheckFlow.Phase
    var needsFlatHelp = false
    let onAnswer: (ScreenSide?) -> Void

    nonisolated static func words(_ phase: WingCheckFlow.Phase) -> String? {
        switch phase {
        case .explain: return "Open flat"
        case .fold: return "Now fold"
        case .ask: return "Tap clear side"
        case .confirm: return nil
        }
    }

    var body: some View {
        let c = info.isCompact
        ZStack(alignment: .topLeading) {
            ForEach([ScreenSide.left, ScreenSide.right], id: \.self) { side in
                let page = side == .left ? info.leftPage : info.rightPage
                let card = page.insetBy(dx: 8, dy: 0)
                    .intersection(CGRect(x: 0, y: info.top + 28, width: info.size.width,
                                         height: max(info.bottom - info.top - 84, 0)))
                Group {
                    if phase == .ask {
                        Button {
                            FeedbackDirector.shared.uiTap()
                            onAnswer(side)
                        } label: {
                            testPattern(compact: c)
                                .frame(width: card.width, height: card.height)
                        }
                        .buttonStyle(SwoopPressStyle())
                        .accessibilityLabel(side == .left ? "The left half stayed clear" : "The right half stayed clear")
                    } else if let w = Self.words(phase) {
                        SchoolWord(text: w, compact: c)
                            .frame(width: card.width, height: card.height)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(SwoopTheme.rewardGold)
                            .frame(width: card.width, height: card.height)
                    }
                }
                .position(x: card.midX, y: card.midY)
            }
            if phase != .confirm {
                let bp = info.birdPage
                let big = needsFlatHelp
                SwoopButton(kind: big ? .secondary : .quiet, height: big ? 56 : 44, compact: c,
                            action: { onAnswer(nil) }) {
                    Text("Skip").lineLimit(1)
                }
                .frame(width: min(bp.width - 40, big ? 200 : 120))
                .position(x: bp.midX, y: info.size.height - 40)
                .accessibilityLabel("Not sure, skip")
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    private func testPattern(compact c: Bool) -> some View {
        VStack(spacing: 16) {
            ZStack {
                VStack(spacing: 3) {
                    ForEach(0..<(c ? 14 : 24), id: \.self) { _ in
                        Rectangle().fill(SwoopTheme.foam.opacity(0.7)).frame(height: 1)
                    }
                }
                Text("Swoop")
                    .font(.system(size: c ? 30 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(SwoopTheme.foam)
            }
            .frame(width: c ? 120 : 160, height: c ? 56 : 100)
            .clipped()
            SchoolWord(text: "Tap clear side", compact: c)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SwoopTheme.surface.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(SwoopTheme.stroke, lineWidth: 1)))
        .contentShape(Rectangle())
    }
}

/// Settings › Check again: the clear-side check on its own.
struct StandaloneWingCheckView: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    var body: some View {
        ZStack {
            SwoopTheme.abyss.opacity(0.6)
            WingCheckPages(controller: controller, info: info, phase: controller.wingCheckDisplay,
                           onAnswer: { controller.answerWingCheck($0) })
        }
        .frame(width: info.size.width, height: info.size.height)
    }
}

/// R10 P0-1: the moment's big word, gold, the way the game's Perfect callout looks (title weight, no full stop).
struct SchoolBigWord: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 40 : 52, weight: .black, design: .rounded))
            .foregroundStyle(SwoopTheme.rewardGold)
            .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.6), radius: 12)
            .fixedSize()
            .accessibilityHidden(true)
    }
}