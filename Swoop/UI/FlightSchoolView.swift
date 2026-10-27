import QuartzCore
import SwiftUI

// R9 (UX-ROUND-9 §1, ART-ROUND-9 §1, AR1/AR2): Flight School taught by the world. No cards, no overline, no praise or
// failure sentences, no Faster! bar or rhythm bar. The guide gull (Scene, from Core's ghost path) flies each move
// first, the live wing diagram rides the bird and shows the move as a dashed ghost pose, and at most three words sit
// beside their cue (never on the bird, never in the fold band). Progress is one row of dots at the bottom.

/// Where the school's pieces go (screen points). Pure; tested (fold-clear on every canvas, both bird sides).
struct SchoolLayout: Equatable {
    /// The progress dots: one row, bottom centre of the bird page (y = h − 22).
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
    /// Skip: the sea page's bottom outer corner.
    var skip: CGRect

    /// R8 P1-9 (kept for the fallback places): true when the bird (+ 60 pt) is under the usual place. Pure; tested.
    nonisolated static func usesLowPrompt(usual: CGRect, low: CGRect, bird: CGPoint?, radius: CGFloat = 44,
                                         wasLow: Bool) -> Bool {
        guard let bird else { return wasLow }
        let r = CGRect(x: bird.x - radius - 60, y: bird.y - radius - 60, width: 2 * (radius + 60),
                       height: 2 * (radius + 60))
        if wasLow { return !r.intersects(low) || r.intersects(usual) }
        return r.intersects(usual) && !r.intersects(low)
    }

    static func make(_ c: AppCanvas) -> SchoolLayout {
        let bp = c.birdPage
        let fp = c.farPage
        let compact = c.isCompact
        let dots = CGRect(x: bp.midX - 60, y: c.size.height - 22 - 6, width: 120, height: 12)
        // ART #46: on iPhone the title bird gets y 24 and 0.30 h (it was crammed into the top 95 pt).
        let birdH = compact ? c.size.height * 0.30 : min(max(c.size.height * 0.30, 70), 210)
        let foldMid = (c.foldMinX + c.foldMaxX) / 2
        let half = max(min(foldMid - 12, c.size.width - 12 - foldMid), 0)
        let titleBird = CGRect(x: foldMid - half, y: max(c.insets.top, 0) + (compact ? 24 : 10), width: half * 2,
                               height: birdH)
        let dSize = WingDiagram.size(compact: compact)
        let diagram = CGRect(x: bp.midX - dSize.width / 2, y: titleBird.maxY + 24, width: dSize.width,
                             height: dSize.height)
        let pw = min(300, bp.width)
        let ph: CGFloat = 44
        let prompt = CGRect(x: bp.midX - pw / 2, y: min(diagram.maxY + 12, dots.minY - ph - 8), width: pw, height: ph)
        let chromeBottom = PlayLayout.make(c).pause.maxY + 8
        let seaPrompt = CGRect(x: bp.midX - pw / 2, y: max(c.size.height * 0.16, chromeBottom), width: pw, height: ph)
        let seaPromptLow = CGRect(x: bp.midX - pw / 2, y: max(dots.minY - ph - 12, seaPrompt.maxY + 8), width: pw,
                                  height: ph)
        let meter = PlayLayout.make(c).meter
        let stormPrompt = CGRect(x: bp.midX - pw / 2, y: max(meter.maxY + 20, seaPrompt.minY), width: pw, height: ph)
        let skipW: CGFloat = 96
        let skipX = c.mirrored ? fp.minX + 8 : fp.maxX - skipW - 8
        let skip = CGRect(x: skipX, y: c.bottom - AppCanvas.minTap, width: skipW, height: AppCanvas.minTap)
        return SchoolLayout(dots: dots, titleBird: titleBird, diagram: diagram, prompt: prompt, seaPrompt: seaPrompt,
                            stormPrompt: stormPrompt, seaPromptLow: seaPromptLow, skip: skip)
    }
}

/// The step dots: 6 pt, done foam, current reward gold, to do white at 25 %. Bottom centre of the bird page.
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

/// In-world words (≤ 3, no full stop): `headline` foam on a soft 0.45 navy glow, not a panel (UX-ROUND-9 §1.1 rule 2).
struct SchoolWord: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(SwoopType.headline(compact))
            .foregroundStyle(SwoopTheme.foam)
            .lineLimit(1)
            .fixedSize()
            .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.45), radius: 10)
            .shadow(color: Color(swoopHex: Contrast.scrim).opacity(0.45), radius: 4)
            .accessibilityHidden(true)
    }
}

/// Where the bird-anchored pieces go (ART-ROUND-9 §1D, UX-ROUND-9 §1.1 rule 2). Pure; tested.
enum SchoolRig {
    /// The diagram's centre: above the bird (bird + (0, −96) on a Duo, −84 on iPhone), or below it (+78 / +70) when the
    /// bird is in the top 30 % of the screen; kept inside the bird page, ≥ 28 pt off the fold band and ≥ 24 pt off the
    /// edges.
    static func diagramCenter(bird: CGPoint, canvas c: AppCanvas) -> CGPoint {
        let s = WingDiagram.size(compact: c.isCompact)
        let above = bird.y >= c.size.height * 0.30
        let dy: CGFloat = c.isCompact ? (above ? -84 : 70) : (above ? -96 : 78)
        return clamp(CGPoint(x: bird.x, y: bird.y + dy), size: s, canvas: c)
    }

    /// The words' centre for an anchor, ≥ 80 pt clear of the bird's rect (radius 44), off the fold band.
    static func wordsCenter(anchor: SchoolWordsAnchor, bird: CGPoint, canvas c: AppCanvas,
                            layout l: SchoolLayout, showsDiagram: Bool, ring: CGRect? = nil,
                            ghost: CGPoint? = nil) -> CGPoint {
        let size = CGSize(width: 180, height: 30)
        let birdRect = CGRect(x: bird.x - 44, y: bird.y - 44, width: 88, height: 88)
        func clear(_ p: CGPoint) -> CGPoint {
            var q = clamp(p, size: size, canvas: c)
            // Move up (or down) until the words' rect is 80 pt off the bird.
            let r = { (q: CGPoint) in CGRect(x: q.x - size.width / 2, y: q.y - size.height / 2, width: size.width,
                                              height: size.height) }
            // Off the guide gull too (Scene's `ghostScreenPoint`), sideways.
            if let g = ghost, r(q).insetBy(dx: -40, dy: -40).contains(g) {
                q.x += (g.x < q.x ? 1 : -1) * (size.width / 2 + 60)
                q = clamp(q, size: size, canvas: c)
            }
            if r(q).insetBy(dx: -80, dy: -80).intersects(birdRect) {
                let upY = birdRect.minY - 80 - size.height / 2
                let downY = birdRect.maxY + 80 + size.height / 2
                q.y = upY - size.height / 2 > c.top + 8 ? upY : downY
                q = clamp(q, size: size, canvas: c)
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
            let d = diagramCenter(bird: bird, canvas: c)
            let s = WingDiagram.size(compact: c.isCompact)
            let above = d.y < bird.y
            return clear(CGPoint(x: d.x, y: above ? d.y - s.height / 2 - 20 : d.y + s.height / 2 + 20))
        case .spot:
            return clear(CGPoint(x: bird.x, y: bird.y - 130))
        case .ring:
            // Beside Scene's live ring (`ringScreenRect`): just above its drop marker; else ahead of the bird.
            if let ring { return clear(CGPoint(x: ring.midX, y: ring.minY - 22)) }
            let ahead: CGFloat = c.mirrored ? -240 : 240
            return clear(CGPoint(x: bird.x + ahead, y: bird.y - 110))
        }
    }

    /// Inside the bird page (or the canvas on iPhone), ≥ 24 pt off the edges and ≥ 28 pt off the fold band.
    static func clamp(_ p: CGPoint, size s: CGSize, canvas c: AppCanvas) -> CGPoint {
        var page = c.hasFold ? c.birdPage : CGRect(origin: .zero, size: c.size)
        if c.hasFold {
            if c.mirrored {
                let minX = c.foldMaxX + 28
                if page.minX < minX { page = CGRect(x: minX, y: page.minY, width: max(page.maxX - minX, 0), height: page.height) }
            } else {
                let maxX = c.foldMinX - 28
                if page.maxX > maxX { page.size.width = max(maxX - page.minX, 0) }
            }
        }
        let inset = page.insetBy(dx: 24 + s.width / 2, dy: 24 + s.height / 2)
        guard inset.width > 0, inset.height > 0 else { return CGPoint(x: page.midX, y: page.midY) }
        return CGPoint(x: min(max(p.x, inset.minX), inset.maxX), y: min(max(p.y, inset.minY), inset.maxY))
    }
}

/// AR1: the wing diagram that rides the bird (ART-ROUND-9 §1D). A 3/4 view of the Duo, each panel turned about the
/// spine with the fold exaggerated (φd = min(1.6 · (180° − θ) / 2, 60°)), inner faces darkened, tinted gold when folded
/// and teal when open. During a demonstration it draws the ghost pose dashed; on the player's turn it is solid and live.
/// The touch variant is a landscape phone with a fingertip.
struct WingDiagram: View {
    /// The live hinge angle (θ, degrees), or the touch tuck 0…1 on iPhone.
    let angle: Double
    let tuck: Double
    /// The ghost's pose (tuck 0…1) while a demonstration plays, else nil.
    var ghostTuck: Double?
    var touch = false
    var compact = false
    var mirrored = false

    static func size(compact: Bool) -> CGSize { compact ? CGSize(width: 80, height: 54) : CGSize(width: 96, height: 64) }

    /// φd (radians) for a hinge angle θ. Pure; tested.
    nonisolated static func displayAngle(hinge theta: Double) -> Double {
        let t = min(max(theta.isFinite ? theta : 180, 100), 180)
        return min(1.6 * (180 - t) / 2, 60) * Double.pi / 180
    }

    /// The hinge angle a tuck 0…1 shows (open 150°, folded 118°).
    nonisolated static func hinge(forTuck u: Double) -> Double { 150 - 32 * min(max(u, 0), 1) }

    var body: some View {
        let s = Self.size(compact: compact)
        Group {
            if touch {
                TouchWingDiagram(pressed: (ghostTuck ?? tuck) > 0.5, ghost: ghostTuck != nil)
            } else {
                Canvas { ctx, size in
                    let theta = ghostTuck.map { Self.hinge(forTuck: $0) } ?? angle
                    let u = ghostTuck ?? tuck
                    let phi = CGFloat(Self.displayAngle(hinge: theta))
                    let cx = size.width / 2, cy = size.height / 2
                    let halfW = (size.width / 2 - 4) * cos(phi)
                    let h = size.height * 0.78
                    let skew = h * 0.18 * sin(phi) / 2
                    for side in [CGFloat(-1), 1] {
                        var p = Path()
                        p.move(to: CGPoint(x: cx, y: cy - h / 2))
                        p.addLine(to: CGPoint(x: cx + side * halfW, y: cy - h / 2 - skew))
                        p.addLine(to: CGPoint(x: cx + side * halfW, y: cy + h / 2 + skew))
                        p.addLine(to: CGPoint(x: cx, y: cy + h / 2))
                        p.closeSubpath()
                        if ghostTuck != nil {
                            ctx.stroke(p, with: .color(SwoopTheme.foam.opacity(0.6)),
                                       style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        } else {
                            ctx.fill(p, with: .color(DuoDiagram.bodyColor))
                            // Inner faces darken as the panels turn.
                            ctx.fill(p, with: .color(Color.black.opacity(0.25 * Double(sin(phi)))))
                            if u > 0.6 { ctx.fill(p, with: .color(SwoopTheme.rewardGold.opacity(0.35))) }
                            if u < 0.2 { ctx.fill(p, with: .color(SwoopTheme.accentOn.opacity(0.30))) }
                            ctx.stroke(p, with: .color(DuoDiagram.rim.opacity(0.4)), lineWidth: 2)
                        }
                    }
                    ctx.fill(Path(roundedRect: CGRect(x: cx - 2, y: cy - h / 2 - 2, width: 4, height: h + 4),
                                  cornerRadius: 2),
                             with: .color(DuoDiagram.spine.opacity(ghostTuck != nil ? 0.5 : 1)))
                }
            }
        }
        .frame(width: s.width, height: touch ? s.height * 0.75 : s.height)
        .accessibilityHidden(true)
    }
}

/// The touch diagram (ART-ROUND-9 §1D): a landscape phone; pressed, the screen tints gold and a ring appears.
struct TouchWingDiagram: View {
    let pressed: Bool
    var ghost = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(swoopHex: 0x1B2A3A).opacity(ghost ? 0.3 : 1))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ghost ? SwoopTheme.foam.opacity(0.6) : DuoDiagram.bodyColor,
                                style: StrokeStyle(lineWidth: 2, dash: ghost ? [5, 4] : [])))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(pressed ? SwoopTheme.rewardGold.opacity(0.35) : SwoopTheme.accentOn.opacity(0.30))
                    .padding(4)
                Circle()
                    .stroke(SwoopTheme.foam.opacity(0.6), lineWidth: 2)
                    .frame(width: pressed ? h * 0.75 : h * 0.4, height: pressed ? h * 0.75 : h * 0.4)
                    .opacity(pressed ? 1 : 0.3)
                    .position(x: w * 0.72, y: h * 0.6)
            }
        }
        .animation(.easeOut(duration: 0.15), value: pressed)
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
            ZStack(alignment: .topLeading) {
                if display.showsDiagram {
                    let p = SchoolRig.diagramCenter(bird: bird, canvas: info)
                    WingDiagram(angle: controller.hingeAngleForDiagram, tuck: controller.touchTuck(now: now),
                                ghostTuck: ghostPose,
                                touch: display.touch, compact: info.isCompact, mirrored: info.mirrored)
                        .position(p)
                        .animation(.easeOut(duration: 0.15), value: p)
                }
                if let words = display.words {
                    let p = SchoolRig.wordsCenter(anchor: display.wordsAnchor, bird: bird, canvas: info, layout: layout,
                                                  showsDiagram: display.showsDiagram,
                                                  ring: controller.ringScreenRect, ghost: controller.ghostScreenPoint)
                    SchoolWord(text: words, compact: info.isCompact)
                        .position(p)
                        .animation(.easeOut(duration: 0.15), value: p)
                        .transition(.opacity)
                }
                // Step 6: the in-world name by Gull Point's lamp as it rises (Scene `schoolLighthouse`).
                if display.step == .storm, let lamp = hud.lampPoint {
                    let s = info.screenPoint(lamp)
                    SchoolWord(text: RouteRules.name(0), compact: info.isCompact)
                        .position(x: s.x, y: max(s.y - 36, info.top + 20))
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
                    ZStack(alignment: .topLeading) {
                        TitleBirdView(bird: controller.bird, tuck: tuck)
                            .frame(width: l.titleBird.width, height: l.titleBird.height)
                            .position(x: l.titleBird.midX, y: l.titleBird.midY)
                        WingDiagram(angle: doneFold ? Self.foldTarget : controller.hingeAngleForDiagram,
                                    tuck: doneFold ? 1 : (d.touch ? (touching ? 1 : 0) : liveTuck),
                                    ghostTuck: demo ? FlightSchool.ghostTuck(d.step, elapsed: elapsed) : nil,
                                    touch: d.touch, compact: info.isCompact, mirrored: info.mirrored)
                            .scaleEffect(info.isCompact ? 1.2 : 1.5)
                            .position(x: l.diagram.midX, y: l.diagram.midY)
                    }
                    .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
                }
                .allowsHitTesting(false)
                if let words = d.words {
                    SchoolWord(text: words, compact: info.isCompact)
                        .position(x: l.prompt.midX, y: l.prompt.midY)
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
            SchoolDots(current: d.dotIndex, count: d.stepCount)
                .position(x: l.dots.midX, y: l.dots.midY)
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
            SchoolDots(current: d.dotIndex, count: d.stepCount)
                .position(x: l.dots.midX, y: l.dots.midY)
                .allowsHitTesting(false)
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
