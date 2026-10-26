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
            HUDView(hud: hud, layout: l, info: info, tag: controller.hudTag, mirrored: info.mirrored,
                    onPause: { controller.pause() })
            PerfectCalloutView(hud: hud, info: info, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
            HintBubble(hint: hud.hint, done: hud.hintDone, touch: controller.hintTouchWording, info: info)
                .frame(width: l.hint.width, height: l.hint.height)
                .position(x: l.hint.midX, y: l.hint.midY)
                .allowsHitTesting(false)
                .opacity(hud.caught ? 0 : 1)
            CenterStage(hud: hud, touch: controller.hintTouchWording, compact: c, reduceMotion: reduceMotion,
                        dailyTitle: controller.dailyBannerTitle)
                .frame(width: l.center.width, height: l.center.height)
                .position(x: l.center.midX, y: l.center.midY)
                .allowsHitTesting(false)
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
            PauseCard(meters: controller.currentMeters, compact: c, canRestart: !controller.isScoredDaily,
                      scoredDaily: controller.isScoredDaily,
                      offersTouch: controller.input == .hinge && controller.hasHinge,
                      onResume: { controller.resume() },
                      onRestart: { controller.flyAgain() },
                      onHome: { controller.goHome() },
                      onTouch: { controller.switchToTouch() })
                .frame(width: min(l.card.width, 400))
                .position(x: l.card.midX, y: l.card.midY)
                .transition(.opacity)
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
                ChainPill(chain: hud.chain, tailwind: hud.tailwind > 0, lost: hud.chainLost, compact: true)
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
                        Text(word).font(SwoopType.title(true)).foregroundStyle(SwoopTheme.foam)
                    } else if let ready = hud.ready {
                        ReadyRing(remaining: ready, total: GameController.readyHold, compact: true)
                    } else {
                        BirdGlyph()
                            .fill(SwoopTheme.foam.opacity(touching ? 1 : 0.7))
                            .frame(width: 72, height: touching ? 22 : 34)
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
                LeadMeter(lead: hud.lead, stormClose: hud.stormClose, mirrored: mirrored)
                    .frame(width: layout.meter.width, height: layout.meter.height)
                    .position(x: layout.meter.midX, y: layout.meter.midY)
                    .opacity(hud.countdown == nil && hud.countdownWord == nil ? 1 : 0.5)
                    .allowsHitTesting(false)
                tagLine
                    .frame(width: layout.tagLine.width, height: layout.tagLine.height,
                           alignment: mirrored ? .trailing : .leading)
                    .position(x: layout.tagLine.midX, y: layout.tagLine.midY)
                    .allowsHitTesting(false)
            }
            .opacity(hud.caught ? 0 : 1)
            VStack(alignment: mirrored ? .leading : .trailing, spacing: 6) {
                HUDDistance(meters: hud.meters, compact: c, alignTrailing: !mirrored)
                Group {
                    ChainPill(chain: hud.chain, tailwind: hud.tailwind > 0, lost: hud.chainLost, compact: c)
                    if let left = hud.bestIn {
                        Text("Best in \(ShareText.km(left))")
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
        if let teach = hud.teachLine {
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
/// riding the knob at the lead, with headroom (Core's `leadMeterScale`). Pulses coral only while the storm is close,
/// also when it is close as the meter appears (QA-2 P2-5).
struct LeadMeter: View {
    let lead: Double
    let stormClose: Bool
    let mirrored: Bool

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
                    BirdGlyph()
                        .fill(SwoopTheme.foam)
                        .frame(width: h + 14, height: (h + 14) * 0.48)
                        .swoopLegible()
                        .position(x: min(max(markerX, h / 2), w - h / 2), y: h / 2)
                }
                .frame(width: w, height: h)
                .overlay(
                    Capsule()
                        .stroke(SwoopTheme.coral.opacity(stormClose ? (pulse ? 0.95 : 0.35) : 0), lineWidth: 2)
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
    }
}

/// The one pill (UX §3): "✦ ×5" from a chain of 2, "✦ ×5 · TAILWIND" while a Tailwind blows, and "×4 lost" (slate,
/// shaking 6 pt, fading over 0.8 s) when a splash breaks a chain of 3+. On `surface` at 62 % with a gold glyph.
struct ChainPill: View {
    let chain: Int
    let tailwind: Bool
    let lost: HUDChainLost?
    let compact: Bool

    @State private var shake: CGFloat = 0

    /// The pill's text, or nil when hidden. Pure; tested.
    nonisolated static func text(chain: Int, tailwind: Bool) -> String? {
        guard chain >= 2 else { return nil }
        return tailwind ? "×\(chain) · TAILWIND" : "×\(chain)"
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
            } else if let text = Self.text(chain: chain, tailwind: tailwind) {
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
                // Scene R3 `onBirdPoint`: already the play view's own points (y down).
                let p = CalloutPlacement.center(bird: callout.point, birdRadius: callout.radius,
                                                size: Self.size, canvas: info)
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
                .background(Capsule().fill(SwoopTheme.surface.opacity(0.62)))
                .swoopLegible()
                .id(hint)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hint)
        .animation(SwoopTheme.pop(false), value: done)
    }
}

/// The middle of the far half: 3-2-1 (or "Ready" / "Go"), the countdown line, and "Ready" after a resume.
struct CenterStage: View {
    @ObservedObject var hud: HUDState
    let touch: Bool
    let compact: Bool
    let reduceMotion: Bool
    /// A scored Daily's banner above the numeral: "Daily Flight #298" / "One scored try. Everyone flies this sea."
    var dailyTitle: String? = nil

    var body: some View {
        ZStack {
            if let n = hud.countdown {
                VStack(spacing: 4) {
                    if let dailyTitle {
                        VStack(spacing: 2) {
                            Text(dailyTitle)
                                .font(SwoopType.headline(compact))
                                .foregroundStyle(SwoopTheme.foam)
                            Text("One scored try. Everyone flies this sea.")
                                .font(SwoopType.caption(compact))
                                .foregroundStyle(SwoopTheme.mist)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                            .fill(SwoopTheme.surface.opacity(0.8)))
                        .padding(.bottom, 6)
                    }
                    Text("\(n)")
                        .font(SwoopType.countdown(compact))
                        .foregroundStyle(SwoopTheme.foam)
                        .shadow(color: SwoopTheme.ink.opacity(0.6), radius: 8, y: 2)
                        .id(n)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.scale(scale: 1.3).combined(with: .opacity))
                    countdownLine
                }
            } else if let word = hud.countdownWord {
                VStack(spacing: 4) {
                    Text(word)
                        .font(SwoopType.title(compact))
                        .foregroundStyle(SwoopTheme.foam)
                        .shadow(color: SwoopTheme.ink.opacity(0.6), radius: 8, y: 2)
                        .id(word)
                        .transition(.opacity)
                    countdownLine
                }
            } else if let ready = hud.ready {
                ReadyRing(remaining: ready, total: GameController.readyHold, compact: compact)
            }
        }
        .animation(SwoopTheme.pop(reduceMotion), value: hud.countdown)
        .animation(SwoopTheme.pop(reduceMotion), value: hud.countdownWord)
    }

    private var countdownLine: some View {
        Text(AppRules.countdownLine(touch: touch, flat: hud.flatHold))
            .font(SwoopType.body(compact))
            .foregroundStyle(hud.flatHold ? SwoopTheme.goldLight : SwoopTheme.foam)
            .swoopLegible()
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
            Text("Spread your wings")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
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

// MARK: - The iPhone wing (ART A13, UX §10)

/// Touch feedback: a 44 pt wing glyph in the bird page's lower outer corner that folds with the tuck, and a soft
/// wing-shaped vignette from both side edges (`#04121F` at 0.08 × tuck, 90 pt deep): the flat phone "closes" like a Duo.
struct TouchWingFeedback: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let reduceMotion: Bool

    static let glyphSize: CGFloat = 44
    static let vignetteDepth: CGFloat = 90
    static let vignetteAlpha: Double = 0.08

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            let u = controller.touchTuck(now: CACurrentMediaTime())
            let page = info.birdPage
            let corner = CGPoint(x: info.mirrored ? page.maxX - Self.glyphSize / 2 : page.minX + Self.glyphSize / 2,
                                 y: info.bottom - Self.glyphSize / 2)
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
                WingGlyph(tuck: u)
                    .stroke(SwoopTheme.foam.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round,
                                                                             lineJoin: .round))
                    .frame(width: Self.glyphSize, height: Self.glyphSize * 0.6)
                    .position(corner)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Two wings in a V that fold toward the body as `tuck` → 1 (2 pt rounded strokes, no fill).
struct WingGlyph: Shape {
    var tuck: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let u = CGFloat(min(max(tuck, 0), 1))
        let cx = rect.midX
        let body = CGPoint(x: cx, y: rect.minY + rect.height * 0.7)
        let reach = rect.width * (0.5 - 0.3 * u)
        let lift = rect.height * (0.65 - 0.55 * u)
        let left = CGPoint(x: cx - reach, y: body.y - lift)
        let right = CGPoint(x: cx + reach, y: body.y - lift)
        p.move(to: left)
        p.addQuadCurve(to: body, control: CGPoint(x: cx - reach * 0.4, y: body.y - lift * 0.2))
        p.addQuadCurve(to: right, control: CGPoint(x: cx + reach * 0.4, y: body.y - lift * 0.2))
        return p
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

struct PauseCard: View {
    let meters: Double
    var compact: Bool = false
    let canRestart: Bool
    var scoredDaily: Bool = false
    var offersTouch: Bool = false
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void
    var onTouch: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(SwoopType.title(compact))
                .foregroundStyle(SwoopTheme.foam)
            Text(scoredDaily ? "Leaving ends today's try." : "\(ShareText.km(meters)) · the storm waits.")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
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
            Text("Paused at \(ShareText.km(meters)).")
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
