import QuartzCore
import SwiftUI

// R6 D2 (UX-FLIGHT-SCHOOL §1–2, ART-FLIGHT-SCHOOL §1, AP2, AP3): Flight School's screens.

/// Where the school's pieces go (screen points). Everything you read sits on the sharp bird page; the far page shows
/// sea (it may blur) and the Skip link. Pure; tested (fold-clear on every canvas, both bird sides).
struct SchoolLayout: Equatable {
    var dots: CGRect
    var titleBird: CGRect
    var diagram: CGRect
    var prompt: CGRect
    /// The Sea steps' prompt (y 0.22 h on the bird page).
    var seaPrompt: CGRect
    /// R7 P0-4: step 7's prompt, under the meter and the goal chip that fade in there (they overlapped the card).
    var stormPrompt: CGRect
    /// R8 P1-9: the Sea prompt's low place on the bird page, used while the bird is under the usual one.
    var seaPromptLow: CGRect
    var skip: CGRect

    /// R8 P1-9: the card never covers the bird: the bird's rect plus a 60 pt margin. Switches to the low place when
    /// the bird is under the usual one, and back only once the bird is under the low one (no flicker). Pure; tested.
    nonisolated static func usesLowPrompt(usual: CGRect, low: CGRect, bird: CGPoint?, radius: CGFloat = 44,
                                         wasLow: Bool) -> Bool {
        guard let bird else { return wasLow }
        let r = CGRect(x: bird.x - radius - 60, y: bird.y - radius - 60, width: 2 * (radius + 60),
                       height: 2 * (radius + 60))
        if wasLow { return !r.intersects(low) || r.intersects(usual) }
        return r.intersects(usual) && !r.intersects(low)
    }

    /// The Duo diagram's drawing height (ART §1: 240 × 170); the gauge adds 66 under it.
    static let diagramDrawingHeight: CGFloat = 170

    static func make(_ c: AppCanvas) -> SchoolLayout {
        let bp = c.birdPage
        let fp = c.farPage
        let compact = c.isCompact
        let dots = CGRect(x: bp.midX - 60, y: c.top + 4, width: 120, height: 20)
        let birdH = min(max(c.size.height * (compact ? 0.26 : 0.30), 70), 210)
        let foldMid = (c.foldMinX + c.foldMaxX) / 2
        let half = max(min(foldMid - 12, c.size.width - 12 - foldMid), 0)
        let titleBird = CGRect(x: foldMid - half, y: max(c.insets.top, 0) + 10, width: half * 2, height: birdH)
        // R7 P1-9: ART's 240 × 170 phone drawing on the Duo (plus the 66 pt gauge under it); 180 × 118 on iPhone.
        let dSize = compact ? CGSize(width: 180, height: 118) : CGSize(width: 240, height: Self.diagramDrawingHeight + 66)
        let dw = min(dSize.width, bp.width)
        let diagram = CGRect(x: bp.midX - dw / 2, y: titleBird.maxY + 6, width: dw, height: dSize.height)
        let pw = min(380, bp.width)
        let ph: CGFloat = compact ? 92 : 128
        let pTop = min(diagram.maxY + 8, c.bottom - ph)
        let prompt = CGRect(x: bp.midX - pw / 2, y: pTop, width: pw, height: ph)
        // R8: clear of the pause button and the dots (they overlapped the card on the iPhone).
        let chromeBottom = max(PlayLayout.make(c).pause.maxY, dots.maxY) + 8
        let seaPrompt = CGRect(x: bp.midX - pw / 2, y: max(c.size.height * 0.22 - ph / 2, chromeBottom), width: pw,
                               height: ph)
        let seaPromptLow = CGRect(x: bp.midX - pw / 2, y: max(c.bottom - ph - 12, seaPrompt.maxY + 8), width: pw,
                                  height: ph)
        let meter = PlayLayout.make(c).meter
        let stormPrompt = CGRect(x: seaPrompt.minX, y: min(max(meter.maxY + 62, seaPrompt.minY), c.bottom - ph),
                                 width: pw, height: ph)
        let skipW: CGFloat = 120
        let skipX = c.mirrored ? fp.minX : fp.maxX - skipW
        let skip = CGRect(x: skipX, y: c.bottom - AppCanvas.minTap, width: skipW, height: AppCanvas.minTap)
        return SchoolLayout(dots: dots, titleBird: titleBird, diagram: diagram, prompt: prompt, seaPrompt: seaPrompt,
                            stormPrompt: stormPrompt, seaPromptLow: seaPromptLow, skip: skip)
    }
}

/// The 8 (or 7) step dots: done foam, current reward gold (10 pt), to do white at 25 % (ART §2).
struct SchoolDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Circle()
                    .fill(i < current ? SwoopTheme.foam : (i == current ? SwoopTheme.rewardGold : Color.white.opacity(0.25)))
                    .frame(width: i == current ? 10 : 7, height: i == current ? 10 : 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// The prompt panel: the overline, the prompt (≤ 2 lines), the help line, or the gold praise.
struct SchoolPrompt: View {
    let display: SchoolDisplay
    var compact = false

    /// The card's navy backing opacity (R8 P1-10).
    nonisolated static let backingOpacity: Double = 0.86

    var body: some View {
        VStack(spacing: 6) {
            SwoopOverline(text: display.overline, compact: compact)
            if let praise = display.praise {
                if let line = display.praiseLine {
                    // R7 P0-2: the big word lands, then what it means.
                    Text(praise)
                        .font(.system(size: compact ? 34 : 44, weight: .black, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(SwoopTheme.rewardGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(.scale(scale: 1.3).combined(with: .opacity))
                    Text(line)
                        .font(SwoopType.body(compact))
                        .foregroundStyle(SwoopTheme.foam)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label(praise, systemImage: "checkmark")
                        .font(SwoopType.headline(compact))
                        .foregroundStyle(SwoopTheme.rewardGold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            } else {
                // R7 P0-4: one Text whose words cross-fade in place (an `.id` swap stacked the old line on the new).
                Text(display.prompt)
                    .font(SwoopType.headline(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if let sub = display.subline {
                    Text(sub)
                        .font(SwoopType.body(compact))
                        .foregroundStyle(SwoopTheme.mist)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        // R8 P1-10: the navy backing (foam on it is ≥ 4.5 : 1 over the brightest sky; the grey faded into it).
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(swoopHex: Contrast.scrim).opacity(SchoolPrompt.backingOpacity)))
        .animation(.easeInOut(duration: 0.4), value: display.prompt)
        .animation(.easeInOut(duration: 0.3), value: display.praise)
        .accessibilityElement(children: .combine)
    }
}

/// Steps 0–2 (the Studio): the title bird across both halves mirroring the wings, the live diagram and the prompt on
/// the bird page; the Wing check's two answer cards in step 2.
struct SchoolStudioView: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    @State private var heldSince: Double?
    @State private var releasedAt: Double?
    @State private var touching = false

    var body: some View {
        let l = SchoolLayout.make(info)
        let d = controller.schoolDisplay
        ZStack(alignment: .topLeading) {
            SwoopTheme.abyss.opacity(0.35)
                .frame(width: info.size.width, height: info.size.height)
                .allowsHitTesting(false)
            if d.step == .wingCheck {
                WingCheckPages(controller: controller, info: info, phase: d.wingPhase,
                               needsFlatHelp: d.wingNeedsFlatHelp, onAnswer: { controller.answerWingCheck($0) })
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                    let now = CACurrentMediaTime()
                    // R8 P0-6: "Wings folded!" shows its answer: the title bird fully folded and the diagram and
                    // gauge at the fold target, whatever the hand does during the praise (live and in the demo).
                    let doneFold = Self.showsDoneFold(d)
                    let liveTuck = d.touch ? controller.touchTuck(now: now)
                        : controller.titleTuck(now: now, heldSince: heldSince, releasedAt: releasedAt)
                    let tuck = doneFold ? 1 : liveTuck
                    ZStack(alignment: .topLeading) {
                        TitleBirdView(bird: controller.bird, tuck: tuck)
                            .frame(width: l.titleBird.width, height: l.titleBird.height)
                            .position(x: l.titleBird.midX, y: l.titleBird.midY)
                        Group {
                            if d.touch {
                                PhoneTouchDiagram(pressed: touching || doneFold, showsFinger: d.step != .hold)
                            } else {
                                DuoDiagram(angle: doneFold ? Self.foldTarget : controller.hingeAngleForDiagram,
                                           target: d.step == .hold ? 140 : (d.step == .wings ? Self.foldTarget : nil),
                                           mirrored: info.mirrored)
                            }
                        }
                        .frame(width: l.diagram.width, height: l.diagram.height)
                        .position(x: l.diagram.midX, y: l.diagram.midY)
                    }
                    .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
                }
                .allowsHitTesting(false)
                SchoolPrompt(display: d, compact: info.isCompact)
                    .frame(width: l.prompt.width)
                    .position(x: l.prompt.midX, y: l.prompt.midY)
                if d.offersTouch {
                    SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(info.isCompact),
                                compact: info.isCompact, action: { controller.schoolPlayWithTouch() }) {
                        Text("Play with touch instead").lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(width: min(l.prompt.width, 300))
                    .position(x: l.prompt.midX, y: min(l.prompt.maxY + 34, info.bottom - 28))
                }
            }
            SchoolDots(current: d.dotIndex, count: d.stepCount)
                .position(x: l.dots.midX, y: l.dots.midY)
            if d.canSkip { skipButton(l) }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard d.touch, !touching else { return }
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

    /// The fold the wings step asks for (the diagram's target ghost).
    nonisolated static let foldTarget: Double = 118

    /// The wings step's praise shows the fold done. Pure; tested.
    nonisolated static func showsDoneFold(_ d: SchoolDisplay) -> Bool { d.step == .wings && d.praise != nil }

    private func skipButton(_ l: SchoolLayout) -> some View {
        SwoopButton(kind: .quiet, height: 44, compact: info.isCompact, action: { controller.skipSchool() }) {
            Text("Skip").lineLimit(1)
                .foregroundStyle(SwoopTheme.foam)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(0.72)))
        }
        .frame(width: l.skip.width, height: l.skip.height)
        .position(x: l.skip.midX, y: l.skip.midY)
        .accessibilityLabel("Skip Flight School")
    }
}

/// Steps 3–7 (the Sea): the prompt, the dots and Skip over the practice sea (PlayLayer draws the pause and the wings).
struct SchoolSeaChrome: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    var body: some View {
        let l = SchoolLayout.make(info)
        let d = controller.schoolDisplay
        ZStack(alignment: .topLeading) {
            SchoolBirdHUD(hud: controller.hud, info: info)
            SchoolDots(current: d.dotIndex, count: d.stepCount)
                .position(x: l.dots.midX, y: l.dots.midY)
                .allowsHitTesting(false)
            SchoolSeaPrompt(hud: controller.hud, display: d, usual: d.step == .storm ? l.stormPrompt : l.seaPrompt,
                            low: l.seaPromptLow, compact: info.isCompact)
            // R8 P1-7/P1-9: the sea teaches the dive (the fold ribbon, the Faster! fill); the mini diagram that sat
            // over the sea is cut.
            if d.canSkip {
                SwoopButton(kind: .quiet, height: 44, compact: info.isCompact, action: { controller.skipSchool() }) {
                    Text("Skip").lineLimit(1)
                .foregroundStyle(SwoopTheme.foam)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(0.72)))
                }
                .frame(width: l.skip.width, height: l.skip.height)
                .position(x: l.skip.midX, y: l.skip.midY)
                .accessibilityLabel("Skip Flight School")
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

/// The Wing check (UX §2.2, ART AP2): the instruction printed on BOTH halves (one is always sharp); then each half is
/// one full-page answer card; "Not sure · skip" at the bottom of the default bird page.
struct WingCheckPages: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let phase: WingCheckFlow.Phase
    var needsFlatHelp = false
    let onAnswer: (ScreenSide?) -> Void

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
                            answerCard(side: side, compact: c)
                                .frame(width: card.width, height: card.height)
                        }
                        .buttonStyle(SwoopPressStyle())
                        .accessibilityLabel(side == .left ? "The left half stayed sharp" : "The right half stayed sharp")
                    } else {
                        instruction(compact: c)
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
                    Text("Not sure · skip").lineLimit(1)
                }
                .frame(width: min(bp.width - 40, 220))
                .position(x: bp.midX, y: info.size.height - 40)
                .accessibilityLabel("Not sure, skip")
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func instruction(compact c: Bool) -> some View {
        VStack(spacing: 10) {
            switch phase {
            case .explain:
                Text("One quick check.").font(SwoopType.title(c)).foregroundStyle(SwoopTheme.foam)
                Text("iPhone Duo softens one half of the screen for a moment when it starts to fold from flat.")
                    .font(SwoopType.body(c)).foregroundStyle(SwoopTheme.mist)
                Text(needsFlatHelp ? "Open it all the way flat, just for this check." : "Open your Duo flat…")
                    .font(SwoopType.headline(c)).foregroundStyle(SwoopTheme.goldLight)
            case .fold:
                Text("…now fold it a little.").font(SwoopType.title(c)).foregroundStyle(SwoopTheme.goldLight)
            case .ask:
                EmptyView()
            case .confirm:
                Label("Got it. Your bird flies on the sharp side.", systemImage: "checkmark")
                    .font(SwoopType.headline(c)).foregroundStyle(SwoopTheme.rewardGold)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(4)
        .minimumScaleFactor(0.8)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SwoopTheme.surface.opacity(0.85)))
    }

    private func answerCard(side: ScreenSide, compact c: Bool) -> some View {
        VStack(spacing: 14) {
            Text("Which side stayed sharp?")
                .font(SwoopType.headline(c))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            // The sharpness test pattern: hairlines at 4 pt pitch under the wordmark (blur is obvious on it).
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
            HStack(spacing: 8) {
                if side == .left { Image(systemName: "arrow.left").font(.system(size: c ? 28 : 40, weight: .bold)) }
                Text("This side")
                if side == .right { Image(systemName: "arrow.right").font(.system(size: c ? 28 : 40, weight: .bold)) }
            }
            .font(SwoopType.headline(c))
            .foregroundStyle(SwoopTheme.foam)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(SwoopTheme.surface.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(SwoopTheme.stroke, lineWidth: 1)))
        .contentShape(Rectangle())
    }
}

/// Settings › Check again / the Home card: the Wing check on its own.
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

// MARK: - SC3: the bird-anchored practice HUD (ART-FLIGHT-SCHOOL §2, drawn by the App)

/// Step 3's "Faster!" capsule (140 × 10 at bird + (0, −46)) and step 6's rhythm bar (132 × 8 at bird + (0, +38)),
/// riding with the bird (`onBirdPoint`, 30 Hz) and kept on the bird page.
struct SchoolBirdHUD: View {
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    /// The anchor x, kept on the bird page (half the widest piece in from its edges). Pure; tested.
    nonisolated static func anchorX(birdX: CGFloat, page: CGRect, halfWidth: CGFloat = 72) -> CGFloat {
        guard page.width > 2 * halfWidth else { return page.midX }
        return min(max(birdX, page.minX + halfWidth), page.maxX - halfWidth)
    }

    var body: some View {
        let bird = hud.birdPoint ?? SceneAdapter.defaultBirdPoint(info)
        let x = Self.anchorX(birdX: bird.x, page: info.birdPage)
        ZStack(alignment: .topLeading) {
            if let fill = hud.schoolFaster {
                FasterCapsule(fill: fill, mirrored: info.mirrored, compact: info.isCompact)
                    .frame(width: 140, height: 28)
                    .position(x: x, y: bird.y - 46 - 9)
                    .transition(.opacity)
            }
            if let r = hud.schoolRhythm {
                RhythmBar(rhythm: r, mirrored: info.mirrored)
                    .frame(width: 132, height: 16)
                    .position(x: x, y: bird.y + 38)
                    .transition(.opacity)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.2), value: hud.schoolFaster == nil)
        .animation(.easeOut(duration: 0.2), value: hud.schoolRhythm == nil)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Faster!": the fill runs accentOn → reward gold as speed rises, with gold speed lines from 70 % (trailing behind,
/// against the flight direction).
struct FasterCapsule: View {
    let fill: Double
    let mirrored: Bool
    let compact: Bool

    var body: some View {
        let f = CGFloat(min(max(fill, 0), 1))
        VStack(spacing: 4) {
            Text("Faster!")
                .font(SwoopType.chip(compact))
                .foregroundStyle(f >= 0.7 ? SwoopTheme.rewardGold : SwoopTheme.foam)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(0.8)))
            ZStack(alignment: mirrored ? .trailing : .leading) {
                Capsule().fill(SwoopTheme.abyss.opacity(0.55))
                Capsule()
                    .fill(LinearGradient(colors: [SwoopTheme.accentOn, SwoopTheme.rewardGold],
                                         startPoint: mirrored ? .trailing : .leading,
                                         endPoint: mirrored ? .leading : .trailing))
                    .frame(width: max(140 * f, 10))
            }
            .frame(width: 140, height: 10)
            .overlay(alignment: mirrored ? .trailing : .leading) {
                if f >= 0.7 {
                    // Speed lines behind the capsule.
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(SwoopTheme.rewardGold.opacity(0.8 - 0.2 * Double(i)))
                                .frame(width: 10 + 6 * CGFloat(i), height: 2)
                        }
                    }
                    .offset(x: mirrored ? 26 : -26)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: fill)
    }
}

/// Step 6's bar for the wave under the bird: a pale "open" span over the up-face, a gold "fold" span over the
/// downslope (in the flight direction), and a cursor coloured by the tuck; three dots for the waves.
struct RhythmBar: View {
    let rhythm: SchoolRhythm
    let mirrored: Bool

    var body: some View {
        let f = CGFloat(min(max(rhythm.fraction, 0), 1))
        let w: CGFloat = 132
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Capsule().fill(mirrored ? SwoopTheme.rewardGold : Color.white.opacity(0.35))
                    Capsule().fill(mirrored ? Color.white.opacity(0.35) : SwoopTheme.rewardGold)
                }
                .frame(width: w, height: 8)
                Circle()
                    .fill(rhythm.tuck >= 0.5 ? SwoopTheme.rewardGold : SwoopTheme.accentOn)
                    .overlay(Circle().stroke(SwoopTheme.ink.opacity(0.6), lineWidth: 1.5))
                    .frame(width: 12, height: 12)
                    .offset(x: (mirrored ? 1 - f : f) * w - 6)
            }
            .frame(width: w, height: 12)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < rhythm.wave ? SwoopTheme.foam : (i == rhythm.wave ? SwoopTheme.rewardGold
                                                                    : Color.white.opacity(0.25)))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

/// R8 P1-9: the Sea steps' prompt, kept off the bird (`SchoolLayout.usesLowPrompt`).
struct SchoolSeaPrompt: View {
    @ObservedObject var hud: HUDState
    let display: SchoolDisplay
    let usual: CGRect
    let low: CGRect
    let compact: Bool

    @State private var isLow = false

    var body: some View {
        let r = isLow ? low : usual
        SchoolPrompt(display: display, compact: compact)
            .frame(width: r.width)
            .position(x: r.midX, y: r.midY)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.3), value: isLow)
            .onAppear { update() }
            .onChange(of: hud.birdPoint) { _, _ in update() }
    }

    private func update() {
        let next = SchoolLayout.usesLowPrompt(usual: usual, low: low, bird: hud.birdPoint, wasLow: isLow)
        if next != isLow { isLow = next }
    }
}