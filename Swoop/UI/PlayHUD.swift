import QuartzCore
import SwiftUI
import UIKit

// MARK: - Book pose (and every landscape phone)

/// The play overlay (UX §3 "Play HUD"): the bird page is *now* (pause, meter, the Daily tag, hints, the callout), the
/// far page is *next* (distance, the one pill, "Best in", toasts, cards). Positions come from `PlayLayout` (fold-clear).
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControl
    @State private var touching = false
    @State private var ripple: CGPoint?
    @State private var rippleSerial = 0

    private var paused: Bool { controller.isUserPaused || controller.isClosingPaused }
    private var c: Bool { info.isCompact }

    var body: some View {
        let l = PlayLayout.make(info)
        ZStack(alignment: .topLeading) {
            if controller.usesTouch && !paused && !hud.caught {
                touchLayer
            } else if (voiceOver || switchControl) && !paused && !hud.caught {
                // QA-2 P2-7: the accessible wing exists in every input mode while VoiceOver / Switch Control runs.
                accessibleWing
            }
            if hud.caught {
                // UX-A2: a tap skips the calm ending 0.6 s after the catch.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { controller.skipCaught() }
                    .accessibilityLabel("Skip to results")
                    .accessibilityAddTraits(.isButton)
            }
            if controller.usesTouch && !info.hasFold {
                TouchWingFeedback(controller: controller, info: info, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
            }
            if let ripple {
                RippleMark(serial: rippleSerial)
                    .position(ripple)
                    .allowsHitTesting(false)
            }
            if hud.schoolSea {
                // Flight School's practice sea: only a quiet pause (the way out); no meter, chip or distance.
                SwoopIconButton(systemName: "pause.fill", size: 44, compact: true, label: "Pause") { controller.pause() }
                    .position(x: l.pause.midX, y: l.pause.midY)
                if hud.schoolStormHUD {
                    // Step 7 (Scene SC1): the meter and the first lighthouse fade in as the storm arrives.
                    Group {
                        LeadMeter(lead: hud.lead, stormClose: false, mirrored: info.mirrored)
                            .frame(width: l.meter.width, height: l.meter.height)
                            .position(x: l.meter.midX, y: l.meter.midY)
                        GoalChip(index: 0, metersLeft: RouteRules.meters(0), mirrored: info.mirrored, compact: c)
                            .position(x: l.meter.midX, y: l.meter.maxY + 34)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
                }
            } else {
                HUDView(hud: hud, layout: l, info: info, tag: controller.hudTag, mirrored: info.mirrored,
                        onPause: { controller.pause() })
                ReachedStage(hud: hud, info: info, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
            }
            PerfectCalloutView(hud: hud, info: info, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
            SplashMarkView(hud: hud, info: info, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
            HintStage(hud: hud, touch: controller.hintTouchWording, info: info, fixed: l.hint)
                .allowsHitTesting(false)
                .opacity(hud.caught ? 0 : 1)
            CenterStage(hud: hud, touch: controller.hintTouchWording, compact: c, reduceMotion: reduceMotion,
                        dailyTitle: controller.dailyBannerTitle, readyTotal: controller.readyTotal)
                .frame(width: l.center.width, height: l.center.height)
                .position(AppRules.stageCenter(usual: CGPoint(x: l.center.midX, y: l.center.midY),
                                               sun: hud.sunPoint.map { info.screenPoint($0) }, height: info.size.height))
                .animation(.easeInOut(duration: 0.4), value: hud.sunPoint)
                .allowsHitTesting(false)
            if hud.nudgeOffer && !paused {
                // R5 P1-8 (Feel): a rest too low for any open angle never starts tucked; touch is offered instead.
                SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(c), compact: c,
                            action: { controller.switchToTouch() }) {
                    Label("Fly with touch", systemImage: "hand.point.up.left.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: min(l.center.width, 280))
                .position(x: l.center.midX, y: min(l.center.maxY + 36, info.bottom - 36))
                .transition(.opacity)
            }
            ToastStage(hud: hud, compact: c, reduceMotion: reduceMotion)
                .frame(width: l.toast.width, height: l.toast.height, alignment: .top)
                .position(x: l.toast.midX, y: l.toast.midY)
                .allowsHitTesting(false)
                .opacity(hud.caught ? 0 : 1)
            cards(l)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .background(paused ? SwoopTheme.abyss.opacity(0.45) : Color.clear)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.isUserPaused)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.isClosingPaused)
        .animation(.easeOut(duration: 0.3), value: hud.caught)
        // A hold that starts near the bottom edge must tuck, not go Home mid-flight.
        .defersSystemGestures(on: paused ? [] : .all)
        .onChange(of: paused) { _, now in
            if now && touching {
                touching = false
                controller.touchEnded()
            }
        }
    }

    @ViewBuilder
    private func cards(_ l: PlayLayout) -> some View {
        if controller.deckReturnPrompt {
            BookPromptCard(compact: c, onFold: { controller.flyWithFold() }, onTouch: { controller.keepTouch() })
                .frame(width: min(l.card.width, 400))
                .position(x: l.card.midX, y: l.card.midY)
                .transition(.opacity)
        } else if controller.isUserPaused {
            if controller.schoolSeaRun {
                SchoolPauseCard(compact: c, onResume: { controller.resume() }, onSkip: { controller.skipSchool() },
                                onHome: { controller.goHome() })
                    .frame(width: min(l.card.width, 400))
                    .position(x: l.card.midX, y: l.card.midY)
                    .transition(.opacity)
            } else {
            PauseCard(meters: controller.currentMeters, compact: c, canRestart: !controller.isScoredDaily,
                      scoredDaily: controller.isScoredDaily,
                      offersTouch: controller.input == .hinge && controller.hasHinge,
                      goalLine: controller.currentGoalLine,
                      objectiveLine: controller.showsObjectiveLine,
                      onResume: { controller.resume() },
                      onRestart: { controller.flyAgain() },
                      onHome: { controller.goHome() },
                      onTouch: { controller.switchToTouch() })
                .frame(width: min(l.card.width, 400))
                .position(x: l.card.midX, y: l.card.midY)
                .transition(.opacity)
            }
        } else if controller.isClosingPaused {
            ClosingCard(meters: controller.currentMeters, compact: c, onResume: { controller.resumeFromClosing() })
                .frame(width: min(l.card.width, 380))
                .position(x: l.card.midX, y: info.size.height / 2)
                .transition(.opacity)
        }
    }

    private var touchLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !touching else { return }
                        touching = true
                        controller.touchBegan()
                        // UX §10: a soft ripple marks the touch on the first 3 runs.
                        if controller.store.data.runs < 3 && !reduceMotion {
                            rippleSerial += 1
                            ripple = value.startLocation
                        }
                    }
                    .onEnded { _ in
                        touching = false
                        controller.touchEnded()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Wings")
            .accessibilityValue(touching ? "Tucked" : "Spread")
            .accessibilityHint("Touch and hold to tuck and dive. Let go to open and soar. "
                               + "With VoiceOver, swipe down to tuck and up to open.")
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .decrement: controller.accessibleTuck(true)
                case .increment: controller.accessibleTuck(false)
                @unknown default: break
                }
            }
            .accessibilityAction { controller.accessibleToggle() }
    }

    /// The hinge run's accessible wing: no touch area (grip thumbs must never tuck), only the VoiceOver / Switch Control
    /// element, paired with the hinge (the larger tuck wins).
    private var accessibleWing: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityLabel("Wings")
            .accessibilityHint("Fold your Duo to tuck, or swipe down to tuck and up to open.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .decrement: controller.accessibleTuck(true)
                case .increment: controller.accessibleTuck(false)
                @unknown default: break
                }
            }
            .accessibilityAction { controller.accessibleToggle() }
    }
}

// MARK: - The split deck (UX-D2)

/// The seated Duo's deck (and "Keep flying here" on the cover): distance, meter and chain in a top row, then the big
/// touch pad, pause at the outer corner; cards and the countdown sit on the pad.
struct DeckPlayView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touching = false

    private var paused: Bool { controller.isUserPaused || controller.isClosingPaused }

    var body: some View {
        let page = info.farPage
        let rowH: CGFloat = 64
        let padTop = rowH + 16
        ZStack(alignment: .topLeading) {
            // The top row.
            HStack(spacing: 12) {
                SwoopIconButton(systemName: "pause.fill", compact: true, label: "Pause") { controller.pause() }
                    .opacity(hud.caught ? 0 : 1)
                LeadMeter(lead: hud.lead, stormClose: hud.stormClose, mirrored: info.mirrored)
                    .frame(height: PlayLayout.meterHeight)
                    .allowsHitTesting(false)
                HUDDistance(meters: hud.meters, compact: true, alignTrailing: true)
                    .opacity(hud.countdown == nil && hud.countdownWord == nil ? 1 : 0)
                ChainPill(chain: hud.chain, tailwind: hud.tailwind > 0, lost: nil, compact: true, teach: hud.chainTeach)
            }
            .frame(width: page.width, height: rowH)
            .position(x: page.midX, y: rowH / 2 + 8)
            // The pad.
            let pad = CGRect(x: page.minX, y: padTop, width: page.width, height: max(info.bottom - padTop, 80))
            ZStack {
                RoundedRectangle(cornerRadius: SwoopTheme.cardRadius(true), style: .continuous)
                    .fill(SwoopTheme.surfaceRaised.opacity(touching ? 0.95 : 0.7))
                    .overlay(RoundedRectangle(cornerRadius: SwoopTheme.cardRadius(true), style: .continuous)
                        .stroke(SwoopTheme.stroke, lineWidth: 1))
                VStack(spacing: 10) {
                    if let n = hud.countdown {
                        Text("\(n)").font(SwoopType.countdown(true)).foregroundStyle(SwoopTheme.foam)
                    } else if let word = hud.countdownWord {
                        Text(word).font(SwoopType.countdown(true)).foregroundStyle(SwoopTheme.foam)
                            .scaleEffect(CenterStage.wordScale)
                    } else if let ready = hud.ready {
                        ReadyRing(remaining: ready, total: controller.readyTotal, compact: true)
                    } else {
                        DartGlyph(tuck: touching ? 1 : 0)
                            .fill(touching ? SwoopTheme.gold : SwoopTheme.foam.opacity(0.7))
                            .frame(width: 72, height: 40)
                            .animation(.easeOut(duration: 0.12), value: touching)
                        Text("Hold to dive · let go to soar")
                            .font(SwoopType.headline(true))
                            .foregroundStyle(SwoopTheme.mist)
                    }
                }
            }
            .frame(width: pad.width, height: pad.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !touching, !paused else { return }
                        touching = true
                        controller.touchBegan()
                    }
                    .onEnded { _ in
                        touching = false
                        controller.touchEnded()
                    }
            )
            .position(x: pad.midX, y: pad.midY)
            .accessibilityElement()
            .accessibilityLabel("Wings")
            .accessibilityHint("Touch and hold to tuck and dive. Let go to open and soar.")
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .decrement: controller.accessibleTuck(true)
                case .increment: controller.accessibleTuck(false)
                @unknown default: break
                }
            }
            if hud.caught {
                Color.clear.contentShape(Rectangle()).onTapGesture { controller.skipCaught() }
            }
            if controller.isUserPaused {
                PauseCard(meters: controller.currentMeters, compact: true, canRestart: !controller.isScoredDaily,
                          scoredDaily: controller.isScoredDaily, offersTouch: false,
                          onResume: { controller.resume() }, onRestart: { controller.flyAgain() },
                          onHome: { controller.goHome() }, onTouch: {})
                    .frame(width: min(page.width, 400))
                    .position(x: page.midX, y: info.size.height / 2)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.isUserPaused)
        .onChange(of: paused) { _, now in
            if now && touching {
                touching = false
                controller.touchEnded()
            }
        }
    }
}

// MARK: - The HUD

struct HUDView: View {
    @ObservedObject var hud: HUDState
    let layout: PlayLayout
    let info: AppCanvas
    /// "DAILY #298" during a Daily (nil for a Flight): on the bird page under the meter (UX-A8).
    let tag: String?
    let mirrored: Bool
    let onPause: () -> Void

    var body: some View {
        let c = info.isCompact
        ZStack(alignment: .topLeading) {
            // QA-1 P1-1: no pause once the storm has caught the bird (the run is over).
            if !hud.caught {
                SwoopIconButton(systemName: "pause.fill", compact: c, label: "Pause", action: onPause)
                    .position(x: layout.pause.midX, y: layout.pause.midY)
                    .transition(.opacity)
            }
            Group {
                LeadMeter(lead: hud.lead, stormClose: hud.stormClose, mirrored: mirrored, showsLabels: hud.meterLabel)
                    .frame(width: layout.meter.width, height: layout.meter.height)
                    .position(x: layout.meter.midX, y: layout.meter.midY)
                    .allowsHitTesting(false)
                tagLine
                    .frame(width: layout.tagLine.width, height: layout.tagLine.height,
                           alignment: mirrored ? .trailing : .leading)
                    .position(x: layout.tagLine.midX, y: layout.tagLine.midY)
                    .allowsHitTesting(false)
                // R6 (ART AP8): the chain / Tailwind pill lives on the bird page, by the meter it pushes back.
                ChainPill(chain: hud.chain, tailwind: hud.tailwind > 0, lost: nil, compact: c, teach: hud.chainTeach)
                    .frame(width: layout.meter.width, alignment: mirrored ? .leading : .trailing)
                    .position(x: layout.meter.midX, y: layout.meter.maxY + (hud.meterLabel ? 66 : 34))
                    .allowsHitTesting(false)
            }
            .opacity(hud.caught ? 0 : 1)
            VStack(alignment: mirrored ? .leading : .trailing, spacing: 6) {
                // UX R3 P2-3: no "0 m" during the countdown; the distance fades in at Go.
                HUDDistance(meters: hud.meters, compact: c, alignTrailing: !mirrored)
                    .opacity(hud.countdown == nil && hud.countdownWord == nil ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: hud.countdownWord)
                Group {
                    // R6 (UX §4.2): the sea page carries WHERE: the distance, the goal chip, "Best in".
                    if hud.goalVisible {
                        VStack(alignment: mirrored ? .leading : .trailing, spacing: 2) {
                            if hud.goalOverline { SwoopOverline(text: "Your goal", compact: c) }
                            GoalChip(index: hud.goalIndex, metersLeft: hud.goalMetersLeft, mirrored: mirrored,
                                     compact: c)
                        }
                        .transition(.opacity)
                    }
                    if let left = hud.bestIn {
                        Text("Best in \(ShareText.distance(left, roundUp: true))")
                            .font(SwoopType.caption(c))
                            .foregroundStyle(SwoopTheme.mist)
                            .swoopLegible()
                            .transition(.opacity)
                    }
                }
                .opacity(hud.caught ? 0 : 1)
            }
            .frame(width: layout.distance.width, height: layout.distance.height,
                   alignment: mirrored ? .topLeading : .topTrailing)
            .position(x: layout.distance.midX, y: layout.distance.midY)
            .allowsHitTesting(false)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.3), value: hud.caught)
    }

    @ViewBuilder
    private var tagLine: some View {
        if hud.meterLabel {
            // The meter labels itself now ("Storm" / "You"); the tag line stays clear under them.
            Color.clear.frame(height: 1)
        } else if let teach = hud.teachLine {
            Text(teach)
                .font(SwoopType.caption(info.isCompact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .swoopLegible()
                .transition(.opacity)
        } else if let tag {
            Text(tag)
                .font(SwoopType.chip(info.isCompact))
                .kerning(SwoopType.chipKerning(info.isCompact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .swoopChip(info.isCompact)
        }
    }
}

/// The distance: metres, then "4.06 km" (the hundredths at 70 %, the unit at 45 % in `mist`, ART §6).
struct HUDDistance: View {
    let meters: Int
    let compact: Bool
    var alignTrailing: Bool = true

    var body: some View {
        let shown = ShareText.hudDistance(Double(meters))
        let parts = shown.value.split(separator: ".", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.first ?? shown.value)
                .font(SwoopType.hud(compact))
                .foregroundStyle(SwoopTheme.foam)
            if parts.count > 1 {
                Text("." + parts[1])
                    .font(SwoopType.hud(compact))
                    .foregroundStyle(SwoopTheme.foam.opacity(0.7))
            }
            Text("\u{2009}" + shown.unit)
                .font(SwoopType.hudUnit(compact))
                .foregroundStyle(SwoopTheme.mist)
        }
        .swoopLegible()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shown.value) \(shown.unit == "km" ? "kilometres" : "metres")")
    }
}

/// The lead meter: a storm cloud at the behind end, a thin bar slate (the storm) → gold (the clear sky), and the bird
/// riding the knob at the lead (R4 P1-7: the sqrt curve, `AppRules.meterLead`). A fixed coral danger zone covers the
/// first 17 % (the knob entering it is the warning: positional, never colour alone); a 3 pt coral outline pulses while
/// the storm is close, also when it is close as the meter appears (QA-2 P2-5).
struct LeadMeter: View {
    let lead: Double
    let stormClose: Bool
    let mirrored: Bool
    /// R5 (UX R4 P2-2): the first run's "Storm" (under the cloud) and "You" (under the knob), after Go, for 3 s.
    var showsLabels: Bool = false

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let iconW: CGFloat = 22
            let w = max(geo.size.width - iconW - 6, 1)
            let h = geo.size.height
            let v = CGFloat(min(max(lead, 0), 1))
            let markerX = mirrored ? w * (1 - v) : w * v
            HStack(spacing: 6) {
                if !mirrored { stormIcon.frame(width: iconW) }
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SwoopTheme.abyss.opacity(0.55))
                    HStack(spacing: 0) {
                        if mirrored { Spacer(minLength: 0) }
                        Capsule()
                            .fill(LinearGradient(colors: mirrored ? [SwoopTheme.gold, SwoopTheme.slate]
                                                                  : [SwoopTheme.slate, SwoopTheme.gold],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(w * v, h))
                        if !mirrored { Spacer(minLength: 0) }
                    }
                    // UX R4 P2-1: the coral danger zone sits ABOVE the fill (you see the cliff edge coming), with a
                    // 2 pt tick at its edge.
                    let zone = w * CGFloat(AppRules.meterDangerZone)
                    HStack(spacing: 0) {
                        if mirrored { Spacer(minLength: 0) }
                        ZStack(alignment: mirrored ? .leading : .trailing) {
                            Rectangle().fill(SwoopTheme.coral.opacity(0.4))
                            Rectangle().fill(SwoopTheme.coral).frame(width: 2)
                        }
                        .frame(width: zone)
                        if !mirrored { Spacer(minLength: 0) }
                    }
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                    // Juror R4 #16: the knob is the mark at 20 pt on a 24 pt navy dot (it read as a tick at 14).
                    let knobX = min(max(markerX, h / 2), w - h / 2)
                    ZStack {
                        Circle().fill(Color(swoopHex: Contrast.scrim))
                            .overlay(Circle().stroke(SwoopTheme.foam.opacity(0.9), lineWidth: 1.5))
                            .frame(width: 24, height: 24)
                        YouGlyph(facingLeft: mirrored)
                            .fill(SwoopTheme.foam)
                            .frame(width: 20, height: 13)
                    }
                    .position(x: knobX, y: h / 2)
                    if showsLabels {
                        // D4 (UX §5 Meter): the coral end zone's label on the first 3 runs.
                        Text("Too close")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(SwoopTheme.coral)
                            .fixedSize()
                            .swoopLegible()
                            .position(x: mirrored ? w - zone / 2 : zone / 2, y: h / 2 + 40)
                        Text("You")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(SwoopTheme.foam)
                            .fixedSize()
                            .swoopLegible()
                            .position(x: knobX, y: h / 2 + 24)
                    }
                }
                .frame(width: w, height: h)
                .overlay(
                    Capsule()
                        .stroke(SwoopTheme.coral.opacity(stormClose ? (pulse ? 0.95 : 0.35) : 0), lineWidth: 3)
                )
                if mirrored { stormIcon.frame(width: iconW) }
            }
        }
        .animation(.easeOut(duration: 0.25), value: lead)
        .onAppear { setPulse(stormClose) }
        .onChange(of: stormClose) { _, close in setPulse(close) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lead over the storm, \(Int((lead * 100).rounded())) percent")
    }

    private func setPulse(_ close: Bool) {
        if close {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { pulse = false }
        }
    }

    private var stormIcon: some View {
        Image(systemName: "cloud.bolt.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(stormClose ? SwoopTheme.coral : SwoopTheme.mist)
            .offset(x: stormClose && pulse ? 1.5 : 0)
            .swoopLegible()
            .overlay(alignment: .top) {
                if showsLabels {
                    Text("Storm")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(SwoopTheme.foam)
                        .fixedSize()
                        .swoopLegible()
                        .offset(y: 26)
                }
            }
    }
}

/// The one pill (UX §3): "✦ ×5" from a chain of 2, "✦ ×5 · TAILWIND" while a Tailwind blows, and "×4 lost" (slate,
/// shaking 6 pt, fading over 0.8 s) when a splash breaks a chain of 3+. On `surface` at 62 % with a gold glyph.
struct ChainPill: View {
    let chain: Int
    let tailwind: Bool
    let lost: HUDChainLost?
    let compact: Bool
    /// D4 (UX §5): the run that first chains reads "✦ ×2 in a row".
    var teach: Bool = false

    @State private var shake: CGFloat = 0

    /// The pill's text, or nil when hidden. Pure; tested.
    nonisolated static func text(chain: Int, tailwind: Bool, teach: Bool = false) -> String? {
        guard chain >= 2 else { return nil }
        if tailwind { return "×\(chain) · TAILWIND" }
        return teach ? "×\(chain) in a row" : "×\(chain)"
    }

    var body: some View {
        ZStack {
            if let lost {
                Text("×\(lost.chain) lost")
                    .font(SwoopType.chip(compact).monospacedDigit())
                    .foregroundStyle(SwoopTheme.mist)
                    .swoopChip(compact, opacity: 0.8)
                    .offset(x: shake)
                    .id(lost.serial)
                    .onAppear {
                        withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) { shake = 6 }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 320_000_000)
                            shake = 0
                        }
                    }
                    .transition(.opacity)
            } else if let text = Self.text(chain: chain, tailwind: tailwind, teach: teach) {
                HStack(spacing: 5) {
                    Image(systemName: tailwind ? "wind" : "sparkle")
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(SwoopTheme.rewardGold)
                    Text(text)
                        .font(SwoopType.chip(compact).monospacedDigit())
                        .kerning(SwoopType.chipKerning(compact))
                        .foregroundStyle(SwoopTheme.foam)
                }
                .swoopChip(compact)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: chain)
        .animation(.easeOut(duration: 0.8), value: lost)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chain >= 2 ? "Perfect chain \(chain)\(tailwind ? ", tailwind" : "")" : "")
    }
}

// MARK: - The callout (UX-A1, ART A5)

/// "Perfect ×N" anchored to the bird where it happened: pop 0.6 → 1.12 → 1, hold 0.25 s, rise 24 pt, fade over the
/// last 0.25 s. Reduce Motion: fades in place. A demo freeze holds it fully on screen.
struct PerfectCalloutView: View {
    @ObservedObject var hud: HUDState
    let info: AppCanvas
    let reduceMotion: Bool

    static let size = CGSize(width: 240, height: 52)

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let callout = hud.callout {
                // Scene R3 `onBirdPoint` (the play view's own points, y down). It follows the bird for its 0.7 s life
                // (juror R3 #12), easing over 0.08 s.
                let bird = hud.birdPoint ?? (callout.point == .zero ? SceneAdapter.defaultBirdPoint(info) : callout.point)
                let p = CalloutPlacement.center(bird: bird, birdRadius: callout.radius, size: Self.size, canvas: info)
                Group {
                    if hud.holdFrame {
                        PerfectCalloutText.label(callout.text, compact: info.isCompact)
                    } else {
                        PerfectCalloutText(text: callout.text, compact: info.isCompact, reduceMotion: reduceMotion)
                            .id(callout.serial)
                    }
                }
                .frame(width: Self.size.width, height: Self.size.height)
                .position(p)
                .animation(.linear(duration: 0.08), value: p)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

struct PerfectCalloutText: View {
    let text: String
    let compact: Bool
    let reduceMotion: Bool

    /// The rise (pt), the pop (s), the hold (s) and the fade (s) (ART §5).
    static let rise: CGFloat = 24
    static let popSeconds: Double = 0.2
    static let holdSeconds: Double = 0.25
    static let fadeSeconds: Double = 0.25

    @State private var popped = false
    @State private var faded = false

    /// "Perfect" or "Perfect ×3". Pure; tested.
    nonisolated static func text(chain: Int) -> String {
        chain >= 2 ? "Perfect ×\(chain)" : "Perfect"
    }

    /// Black, the gold gradient `#FFE7A0` → `#F2A93B` with a 2 pt ink outline at 45 % (ART §9 "soar").
    static func label(_ text: String, compact: Bool) -> some View {
        let font = SwoopType.callout(compact)
        return ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(SwoopTheme.ink.opacity(0.45))
                .offset(x: 1.5, y: 1.5)
            Text(text)
                .font(font)
                .foregroundStyle(SwoopTheme.ink.opacity(0.45))
                .offset(x: -1.5, y: -1.5)
            Text(text)
                .font(font)
                .foregroundStyle(LinearGradient(colors: [Color(swoopHex: 0xFFE7A0), Color(swoopHex: 0xF2A93B)],
                                                startPoint: .top, endPoint: .bottom))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityHidden(true)
    }

    var body: some View {
        Self.label(text, compact: compact)
            .scaleEffect(popped || reduceMotion ? 1 : 0.6)
            .offset(y: faded && !reduceMotion ? -Self.rise : 0)
            .opacity(faded ? 0 : 1)
            .onAppear {
                if !reduceMotion {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) { popped = true }
                }
                withAnimation(.easeIn(duration: Self.fadeSeconds).delay(Self.popSeconds + Self.holdSeconds)) {
                    faded = true
                }
            }
    }
}

// MARK: - Hints, countdown, toasts

struct HintBubble: View {
    let hint: AppHint?
    var done: Bool = false
    let touch: Bool
    let info: AppCanvas

    /// The hint copy (UX §2), with the touch words and mirrored arrows. Pure; tested.
    nonisolated static func text(_ hint: AppHint, touch: Bool, mirrored: Bool = false) -> String {
        AppRules.hintText(hint, touch: touch, mirrored: mirrored)
    }

    var body: some View {
        ZStack {
            if let hint {
                HStack(spacing: 10) {
                    Text(Self.text(hint, touch: touch, mirrored: info.mirrored))
                        .font(SwoopType.headline(info.isCompact))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(SwoopTheme.rewardGold)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.surfaceAlpha)))
                .swoopLegible()
                .id(hint)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hint)
        .animation(SwoopTheme.pop(false), value: done)
    }
}

/// The middle of the far half: 3-2-1 (or "Ready" / "Go"), the countdown line, "Ready" after a resume, and the caught
/// line. R4 P0-3: every word here sits on a navy `#0B2236` disc / pill at 0.62 (4.5 : 1 for foam over the sun's core,
/// `Contrast`), in foam, with the legibility shadow.
struct CenterStage: View {
    @ObservedObject var hud: HUDState
    let touch: Bool
    let compact: Bool
    let reduceMotion: Bool
    /// A scored Daily's banner above the numeral: "Daily Flight #1" / "One scored try. Everyone flies this sea."
    var dailyTitle: String? = nil
    /// The Ready hold's length (2.8 s after a cover reopen).
    var readyTotal: Double = GameController.readyHold

    /// "Ready" / "Go" at 0.85 × the numeral (UX R3 P2-4, juror 13).
    static let wordScale: CGFloat = 0.85
    /// The disc behind the numeral / ring.
    static func discSize(_ c: Bool) -> CGFloat { c ? 132 : 156 }

    var body: some View {
        ZStack {
            if let n = hud.countdown {
                VStack(spacing: 8) {
                    if let dailyTitle { dailyBanner(dailyTitle) }
                    Text("\(n)")
                        .font(SwoopType.countdown(compact))
                        .foregroundStyle(SwoopTheme.foam)
                        .shadow(color: SwoopTheme.shadowBase.opacity(0.45), radius: 6, y: 1)
                        .id(n)
                        .transition(reduceMotion ? AnyTransition.opacity
                                    : AnyTransition.scale(scale: 1.3).combined(with: .opacity))
                        .frame(width: Self.discSize(compact), height: Self.discSize(compact))
                        .background(Circle().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.scrimAlpha)))
                    countdownLine
                }
            } else if let word = hud.countdownWord {
                VStack(spacing: 8) {
                    Text(word)
                        .font(SwoopType.countdown(compact))
                        .scaleEffect(Self.wordScale)
                        .foregroundStyle(SwoopTheme.foam)
                        .shadow(color: SwoopTheme.shadowBase.opacity(0.45), radius: 6, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .id(word)
                        .transition(reduceMotion ? AnyTransition.opacity
                                    : AnyTransition.scale(scale: 0.6).combined(with: .opacity))
                        .frame(width: Self.discSize(compact) * 1.5, height: Self.discSize(compact))
                        .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.scrimAlpha)))
                    // "Go" says it alone: no "hold steady" under it.
                    if word != "Go" { countdownLine }
                }
            } else if let ready = hud.ready {
                ReadyRing(remaining: ready, total: readyTotal, compact: compact)
            } else if hud.caught {
                // The player's R3 note: say what happened before the card.
                linePill("The storm caught you")
                    .transition(.opacity)
            }
        }
        .animation(SwoopTheme.pop(reduceMotion), value: hud.countdown)
        .animation(SwoopTheme.pop(reduceMotion), value: hud.countdownWord)
        .animation(.easeOut(duration: 0.3), value: hud.caught)
    }

    private func dailyBanner(_ title: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(SwoopType.headline(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
            Text("One scored try. Everyone flies this sea.")
                .font(SwoopType.caption(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
            .fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.surfaceAlpha)))
    }

    private var countdownLine: some View {
        linePill(AppRules.countdownLine(touch: touch, flat: hud.flatHold, nudge: hud.openNudge),
                 highlight: hud.flatHold || hud.openNudge)
    }

    private func linePill(_ text: String, highlight: Bool = false) -> some View {
        Text(text)
            .font(SwoopType.body(compact))
            .foregroundStyle(highlight ? SwoopTheme.goldLight : SwoopTheme.foam)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.scrimAlpha)))
            .swoopLegible()
    }
}

/// The hint pill (UX-A5). On a fold the hint keeps its place at 62 % of the bird page; on a phone (R4 P1-12, UX R3
/// P1-8) it rides 110 pt above the bird, flipping below it under the HUD, so the bird is never under the words.
struct HintStage: View {
    @ObservedObject var hud: HUDState
    let touch: Bool
    let info: AppCanvas
    let fixed: CGRect

    static let size = CGSize(width: 320, height: 56)

    var body: some View {
        let center: CGPoint = {
            if info.hasFold { return CGPoint(x: fixed.midX, y: fixed.midY) }
            guard let bird = hud.birdPoint else { return CGPoint(x: fixed.midX, y: fixed.midY) }
            return HintPlacement.center(bird: bird, size: CGSize(width: min(Self.size.width, info.birdPage.width),
                                                                height: Self.size.height), canvas: info)
        }()
        Group {
            if let tip = hud.tipLine, hud.hint == nil {
                // R6: the one-time lines (the storm line, the Tailwind teach, the flat tip) use the hint slot.
                Text(tip)
                    .font(SwoopType.body(info.isCompact).weight(.semibold))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.surfaceAlpha)))
                    .frame(width: min(fixed.width, 380))
                    .transition(.opacity)
            } else {
                HintBubble(hint: hud.hint, done: hud.hintDone, touch: touch, info: info)
                    .frame(width: min(fixed.width, Self.size.width + 80), height: Self.size.height)
            }
        }
        .position(center)
            .animation(.easeOut(duration: 0.4), value: center)
            .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

/// "Splash" (· "×4 lost") at the bird for 0.9 s (R4 P1-9): slate on a navy pill, drifting down and fading.
struct SplashMarkView: View {
    @ObservedObject var hud: HUDState
    let info: AppCanvas
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let mark = hud.splashMark {
                let p = SplashPlacement.center(bird: mark.point ?? SceneAdapter.defaultBirdPoint(info), canvas: info)
                // R5 P1-2: a demo freeze shows the word fully (the fade ran on wall time and was gone by the capture).
                if hud.holdFrame {
                    SplashMarkText.label(mark.text, compact: info.isCompact)
                        .position(p)
                } else {
                    SplashMarkText(text: mark.text, compact: info.isCompact, reduceMotion: reduceMotion)
                        .id(mark.serial)
                        .position(p)
                }
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

struct SplashMarkText: View {
    let text: String
    let compact: Bool
    let reduceMotion: Bool
    var hold: Bool = false

    @State private var gone = false

    /// `#E6ECF2` on a navy pill (player R4: at least 1.2 s on screen).
    static func label(_ text: String, compact: Bool) -> some View {
        Text(text)
            .font(SwoopType.headline(compact))
            .foregroundStyle(Color(swoopHex: 0xE6ECF2))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.surfaceAlpha)))
            .accessibilityHidden(true)
    }

    var body: some View {
        Self.label(text, compact: compact)
            .offset(y: gone && !reduceMotion ? 14 : 0)
            .opacity(gone ? 0 : 1)
            .onAppear {
                guard !hold else { return }
                withAnimation(.easeIn(duration: 0.4).delay(0.9)) { gone = true }
            }
    }
}
/// Toasts and the lighthouse card: the far page, top edge at 60 % height, over the sea (UX §3); on `surface` at 80 %.
struct ToastStage: View {
    @ObservedObject var hud: HUDState
    let compact: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let card = hud.lighthouse {
                LighthouseCard(toast: card, compact: compact)
                    .id(card.serial)
                    .transition(.offset(y: 16).combined(with: .opacity))
            } else if let toast = hud.toast {
                ToastPill(toast: toast, compact: compact)
                    .id(toast.serial)
                    .transition(.offset(y: 16).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                   value: hud.toast)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                   value: hud.lighthouse)
    }
}

struct ReadyRing: View {
    let remaining: Double
    let total: Double
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(SwoopTheme.foam.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(remaining / max(total, 0.01), 0), 1)))
                    .stroke(SwoopTheme.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: remaining)
                Text("Ready")
                    .font(SwoopType.headline(compact))
                    .foregroundStyle(SwoopTheme.foam)
            }
            .frame(width: 120, height: 120)
            .background(Circle().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.scrimAlpha))
                .frame(width: 152, height: 152))
            Text("Spread your wings")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(swoopHex: Contrast.scrim).opacity(Contrast.scrimAlpha)))
        }
        .swoopLegible()
    }
}

struct LighthouseCard: View {
    let toast: HUDToast
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            LighthouseGlyph()
                .fill(LinearGradient(colors: [SwoopTheme.foam, SwoopTheme.goldLight], startPoint: .top,
                                     endPoint: .bottom))
                .frame(width: 26, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(SwoopType.headline(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(toast.detail)
                    .font(SwoopType.caption(compact))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                .fill(SwoopTheme.surface.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                    .stroke(SwoopTheme.stroke, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

struct ToastPill: View {
    let toast: HUDToast
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(toast.title)
                .font(SwoopType.title(compact))
                .foregroundStyle(toast.kind == .newBest ? SwoopTheme.rewardGold : SwoopTheme.foam)
            Text(toast.detail)
                .font(SwoopType.caption(compact))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                .fill(SwoopTheme.surface.opacity(0.8))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The iPhone wing (ART A13, UX §10; R4 P1-12)

/// Touch feedback: the bird mark, 56 pt, bottom-centre of the bird page (off the left thumb), folding with the tuck and
/// charging from foam at 0.35 α (spread) to gold `#F7C75B` at 0.9 α (full tuck), with a 1 pt `#10233A` outline so it
/// reads over the foam line; plus the soft wing-shaped vignette from both side edges (`#04121F` at 0.08 × tuck).
struct TouchWingFeedback: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let reduceMotion: Bool

    static let glyphSize: CGFloat = 56
    static let vignetteDepth: CGFloat = 90
    static let vignetteAlpha: Double = 0.08

    /// Where the glyph sits (R5): a quarter into the bird page from its outer edge, 28 pt above the bottom, below the
    /// skim line and off the left thumb. Pure; tested.
    nonisolated static func glyphCenter(birdPage: CGRect, height: CGFloat, mirrored: Bool = false) -> CGPoint {
        let x = mirrored ? birdPage.maxX - birdPage.width * 0.25 : birdPage.minX + birdPage.width * 0.25
        return CGPoint(x: x, y: height - 28)
    }

    /// The glyph's alpha with the tuck: 0.55 → 0.9 (it vanished on the sea at 0.35); 0.15 while the bird's rect + 24
    /// pt overlaps it, so it never sits on the bird. Pure; tested.
    nonisolated static func glyphAlpha(tuck: Double, birdNear: Bool = false) -> Double {
        if birdNear { return 0.15 }
        return 0.55 + 0.35 * min(max(tuck.isFinite ? tuck : 0, 0), 1)
    }

    /// Whether the bird (radius ~44 pt) plus 24 pt meets the glyph's box. Pure; tested.
    nonisolated static func birdNear(bird: CGPoint?, glyph: CGPoint) -> Bool {
        guard let bird else { return false }
        let r: CGFloat = 44 + 24
        let side: CGFloat = 56    // glyphSize
        let box = CGRect(x: glyph.x - side / 2, y: glyph.y - side * 0.3, width: side, height: side * 0.6)
        return box.insetBy(dx: -r, dy: -r).contains(bird)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            let u = controller.touchTuck(now: CACurrentMediaTime())
            let center = Self.glyphCenter(birdPage: info.birdPage, height: info.size.height, mirrored: info.mirrored)
            let near = Self.birdNear(bird: controller.hud.birdPoint, glyph: center)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    LinearGradient(colors: [SwoopTheme.shadowBase.opacity(Self.vignetteAlpha * u), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: Self.vignetteDepth)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, SwoopTheme.shadowBase.opacity(Self.vignetteAlpha * u)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: Self.vignetteDepth)
                }
                .frame(width: info.size.width, height: info.size.height)
                ZStack {
                    DartGlyph(tuck: u)
                        .stroke(Color(swoopHex: 0x10233A).opacity(0.4), lineWidth: 2)
                    DartGlyph(tuck: u)
                        .fill(u > 0.5 ? SwoopTheme.gold : SwoopTheme.foam)
                        .opacity(Self.glyphAlpha(tuck: u, birdNear: near))
                }
                .frame(width: Self.glyphSize, height: Self.glyphSize * 0.6)
                .position(center)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The bird mark folding with `tuck`: the wings sweep in toward the body and the M deepens (0 spread … 1 a dart).
struct DartGlyph: Shape {
    var tuck: Double

    var animatableData: Double {
        get { tuck }
        set { tuck = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let u = CGFloat(min(max(tuck.isFinite ? tuck : 0, 0), 1))
        let w = rect.width * (1 - 0.45 * u)
        let h = rect.height * (1 + 0.5 * u)
        let box = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        return BirdGlyph().path(in: box)
    }
}
/// The soft 0.2 s ripple that marks a touch on the first 3 runs (56 pt, foam).
struct RippleMark: View {
    let serial: Int
    @State private var grown = false

    var body: some View {
        Circle()
            .stroke(SwoopTheme.foam.opacity(grown ? 0 : 0.5), lineWidth: 2)
            .frame(width: grown ? 56 : 16, height: grown ? 56 : 16)
            .id(serial)
            .onAppear {
                grown = false
                withAnimation(.easeOut(duration: 0.2)) { grown = true }
            }
            .onChange(of: serial) { _, _ in
                grown = false
                withAnimation(.easeOut(duration: 0.2)) { grown = true }
            }
    }
}

// MARK: - Pause, closing and the book prompt

/// Flight School's pause (UX §1.1): "Paused · Flight School", Resume (back to the step's start) · Skip · Home.
struct SchoolPauseCard: View {
    var compact = false
    let onResume: () -> Void
    let onSkip: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Paused · Flight School")
                .font(SwoopType.title(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(compact), compact: compact, action: onResume) {
                Label("Resume", systemImage: "play.fill")
            }
            HStack(spacing: 10) {
                SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(compact), compact: compact,
                            action: onSkip) {
                    Text("Skip Flight School").lineLimit(1).minimumScaleFactor(0.75)
                }
                SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(compact), compact: compact,
                            action: onHome) {
                    Label("Home", systemImage: "house.fill").lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .swoopCard(radius: SwoopTheme.cardRadius(compact))
    }
}

struct PauseCard: View {
    /// "2.12 km · Gull Point in 1.9 km" (UX §5), "Leaving ends today's try." on a scored Daily. Pure; tested.
    nonisolated static func subline(meters: Double, scoredDaily: Bool, goalLine: String?) -> String {
        if scoredDaily { return "Leaving ends today's try." }
        if let goalLine { return "\(ShareText.distance(meters)) · \(goalLine)" }
        return "\(ShareText.distance(meters)) · the storm waits."
    }

    let meters: Double
    var compact: Bool = false
    let canRestart: Bool
    var scoredDaily: Bool = false
    var offersTouch: Bool = false
    /// R6: "Gull Point in 1.9 km", and the objective sentence on the first 3 runs (UX §5 Pause).
    var goalLine: String? = nil
    var objectiveLine: Bool = false
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void
    var onTouch: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(SwoopType.title(compact))
                .foregroundStyle(SwoopTheme.foam)
            Text(Self.subline(meters: meters, scoredDaily: scoredDaily, goalLine: goalLine))
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
            if objectiveLine {
                Text(RouteRules.objective)
                    .font(SwoopType.caption(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            Color.clear.frame(height: 4)
            SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(compact), compact: compact,
                        action: onResume) {
                Label("Resume", systemImage: "play.fill")
            }
            HStack(spacing: 10) {
                if canRestart {
                    SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(compact), compact: compact,
                                action: onRestart) {
                        Label("Restart", systemImage: "arrow.clockwise")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(compact), compact: compact,
                            action: onHome) {
                    Label("Home", systemImage: "house.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if offersTouch {
                SwoopButton(kind: .quiet, height: 44, compact: compact, action: onTouch) {
                    Label("Switch to touch", systemImage: "hand.point.up.left.fill")
                        .lineLimit(1)
                }
            }
        }
        .swoopCard(radius: SwoopTheme.cardRadius(compact))
    }
}

/// The Duo is closing (< 95°) mid-flight: the run holds. Opening it again resumes behind "Ready"; Resume appears after
/// 1.5 s, for a reopen iOS didn't report (QA-1 P2-3).
struct ClosingCard: View {
    let meters: Double
    var compact: Bool = false
    var onResume: () -> Void = {}

    @State private var showsResume = false

    static let resumeAfter: Double = 1.5

    var body: some View {
        VStack(spacing: 12) {
            BirdGlyph()
                .fill(SwoopTheme.foam)
                .frame(width: 70, height: 32)
            Text("Open your wings to keep flying")
                .font(SwoopType.headline(compact))
                .foregroundStyle(SwoopTheme.foam)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Paused at \(ShareText.distance(meters)).")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
            if showsResume {
                SwoopButton(kind: .quiet, height: 44, compact: compact, action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                        .lineLimit(1)
                }
                .transition(.opacity)
            }
        }
        .swoopCard(padding: 24, radius: SwoopTheme.cardRadius(compact))
        .accessibilityElement(children: .contain)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Self.resumeAfter * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.25)) { showsResume = true }
        }
    }
}

/// Back in book pose from the split deck: "Fly with the fold?" (UX-D2; never a silent mid-run swap).
struct BookPromptCard: View {
    var compact: Bool = false
    let onFold: () -> Void
    let onTouch: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Fly with the fold?")
                .font(SwoopType.title(compact))
                .foregroundStyle(SwoopTheme.foam)
            Text("You're holding it like a book again.")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
            SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(compact), compact: compact, action: onFold) {
                Text("Fly with the fold")
            }
            SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(compact), compact: compact,
                        action: onTouch) {
                Text("Keep touch")
            }
        }
        .swoopCard(radius: SwoopTheme.cardRadius(compact))
    }
}

// MARK: - The goal (R6 D3, UX §4.2–4.3, ART §3–4)

/// "← Gull Point · 1.2 km": the next lighthouse, pointing the way the bird flies, counting down; gold under 300 m.
struct GoalChip: View {
    let index: Int
    let metersLeft: Double
    let mirrored: Bool
    var compact = false

    var body: some View {
        let near = RouteRules.isNear(metersLeft: metersLeft)
        HStack(spacing: 6) {
            Image(systemName: mirrored ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(SwoopTheme.rewardGold)
            LighthouseIcon(state: .next, size: 22 * RouteRules.iconScale(metersLeft: metersLeft))
            Text(RouteRules.name(index))
                .font(.system(size: compact ? 17 : 19, weight: .bold, design: .rounded))
                .foregroundStyle(near ? SwoopTheme.rewardGold : SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("·").foregroundStyle(SwoopTheme.mist)
            Text(ShareText.distance(metersLeft, roundUp: true))
                .font(.system(size: compact ? 17 : 19, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(SwoopTheme.goldLight)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 12 : 14)
        .frame(height: compact ? 34 : 40)
        .background(Capsule().fill(SwoopTheme.surface.opacity(0.62))
            .overlay(Capsule().stroke(near ? SwoopTheme.rewardGold.opacity(0.6) : SwoopTheme.stroke, lineWidth: 1)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next lighthouse, \(RouteRules.name(index)), "
                            + "\(ShareText.distance(metersLeft, roundUp: true).replacingOccurrences(of: "km", with: "kilometres"))")
    }
}

/// "Gull Point reached!" (UX §4.3, ART §4): the sea page, y 0.40 h (0.62 h when the sun is near), for 1.9 s.
struct ReachedStage: View {
    @ObservedObject var hud: HUDState
    let info: AppCanvas
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let r = hud.reached {
                let usual = CGPoint(x: info.farPage.midX, y: info.size.height * 0.40)
                // SC4: the card also drops to 0.62 h when it would cover the lamp, so the beam is seen leaving it.
                let avoid = hud.lampPoint ?? hud.sunPoint
                let p = AppRules.stageCenter(usual: usual, sun: avoid.map { info.screenPoint($0) },
                                             height: info.size.height)
                ReachedCard(reached: r, compact: info.isCompact)
                    .frame(width: min(info.isCompact ? 320 : 380, info.farPage.width))
                    .position(p)
                    .id(r.serial)
                    .transition(reduceMotion ? AnyTransition.opacity
                                : AnyTransition.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.72),
                   value: hud.reached)
    }
}

struct ReachedCard: View {
    let reached: HUDReached
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            LighthouseIcon(state: .reached, size: 44)
            Text("\(reached.name) reached!")
                .font(SwoopType.title(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Lighthouse \(reached.index + 1) · the storm falls back")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if reached.newOnRoute {
                Text("New on your route")
                    .font(SwoopType.chip(compact))
                    .kerning(SwoopType.chipKerning(compact))
                    .foregroundStyle(SwoopTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(SwoopTheme.rewardGold))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
            .fill(SwoopTheme.surface.opacity(0.88)))
        .accessibilityElement(children: .combine)
    }
}