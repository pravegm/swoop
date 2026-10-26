import SwiftUI

/// The play overlay: the hold-anywhere touch control (touch input only), the HUD, hints, countdown, toasts and the
/// pause / closing / Ready cards. Positions come from `PlayLayout` (fold-clear).
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touching = false

    private var paused: Bool { controller.isUserPaused || controller.isClosingPaused }

    var body: some View {
        let l = PlayLayout.make(info)
        ZStack(alignment: .topLeading) {
            if controller.usesTouch && !paused {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !touching else { return }
                                touching = true
                                controller.touchBegan()
                            }
                            .onEnded { _ in
                                touching = false
                                controller.touchEnded()
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Wings")
                    .accessibilityHint("Touch and hold to tuck and dive. Let go to open and soar.")
                    .accessibilityAddTraits(.allowsDirectInteraction)
            }
            HUDView(hud: hud, layout: l, info: info, onPause: { controller.pause() })
            HintBubble(hint: hud.hint, touch: controller.usesTouch, info: info)
                .frame(width: l.hint.width, height: l.hint.height)
                .position(x: l.hint.midX, y: l.hint.midY)
                .allowsHitTesting(false)
            CenterStage(hud: hud, touch: controller.usesTouch, reduceMotion: reduceMotion)
                .frame(width: l.center.width, height: l.center.height)
                .position(x: l.center.midX, y: l.center.midY)
                .allowsHitTesting(false)
            if controller.isUserPaused {
                PauseCard(canRestart: !controller.isScoredDaily,
                          onResume: { controller.resume() },
                          onRestart: { controller.flyAgain() },
                          onHome: { controller.goHome() })
                    .frame(width: min(l.card.width, 400))
                    .position(x: l.card.midX, y: l.card.midY)
                    .transition(.opacity)
            } else if controller.isClosingPaused {
                ClosingCard(info: info)
                    .transition(.opacity)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .background(paused ? SwoopTheme.abyss.opacity(0.45) : Color.clear)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.isUserPaused)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.isClosingPaused)
        // A hold that starts near the bottom edge must tuck, not go Home mid-flight.
        .defersSystemGestures(on: paused ? [] : .all)
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
    let onPause: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            SwoopIconButton(systemName: "pause.fill", label: "Pause", action: onPause)
                .position(x: layout.pause.midX, y: layout.pause.midY)
            LeadMeter(lead: hud.lead, stormClose: hud.stormClose, mirrored: info.mirrored)
                .frame(width: layout.meter.width, height: layout.meter.height)
                .position(x: layout.meter.midX, y: layout.meter.midY)
                .opacity(hud.countdown == nil ? 1 : 0.5)
            distance
                .frame(width: layout.distance.width, height: layout.distance.height,
                       alignment: info.mirrored ? .topLeading : .topTrailing)
                .position(x: layout.distance.midX, y: layout.distance.midY)
                .allowsHitTesting(false)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    private var distance: some View {
        VStack(alignment: info.mirrored ? .leading : .trailing, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(ShareText.grouped(hud.meters))
                    .font(SwoopTheme.number(info.isCompact ? 40 : 50))
                    .foregroundStyle(SwoopTheme.foam)
                    .contentTransition(.numericText())
                Text("m")
                    .font(SwoopTheme.title(info.isCompact ? 18 : 22))
                    .foregroundStyle(SwoopTheme.mist)
            }
            .swoopLegible()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(hud.meters) metres")
            HStack(spacing: 8) {
                if hud.tailwind > 0 {
                    TailwindBadge(seconds: hud.tailwind)
                        .transition(.scale.combined(with: .opacity))
                }
                ChainPips(chain: hud.chain, tailwind: hud.tailwind > 0)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hud.tailwind > 0)
        }
    }
}

/// The lead meter: a thin bar, slate (the storm, behind) → gold (the clear sky, ahead); the bird marker sits at the
/// lead. Pulses coral when the storm is close.
struct LeadMeter: View {
    let lead: Double
    let stormClose: Bool
    let mirrored: Bool

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let v = CGFloat(min(max(lead, 0), 1))
            let markerX = mirrored ? w * (1 - v) : w * v
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
                Circle()
                    .fill(SwoopTheme.foam)
                    .frame(width: h + 8, height: h + 8)
                    .shadow(color: SwoopTheme.gold.opacity(0.8), radius: 4)
                    .position(x: min(max(markerX, h / 2), w - h / 2), y: h / 2)
            }
            .overlay(
                Capsule()
                    .stroke(SwoopTheme.coral.opacity(stormClose ? (pulse ? 0.95 : 0.35) : 0), lineWidth: 2)
            )
        }
        .animation(.easeOut(duration: 0.25), value: lead)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lead over the storm, \(Int((lead * 100).rounded())) percent")
    }
}

/// Three pips toward a Tailwind (3 Perfects in a row), plus the chain count from 2.
struct ChainPips: View {
    let chain: Int
    let tailwind: Bool

    var body: some View {
        let lit = tailwind ? 3 : (chain % 3)
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < lit ? SwoopTheme.gold : SwoopTheme.abyss.opacity(0.5))
                    .overlay(Circle().stroke(SwoopTheme.gold.opacity(0.7), lineWidth: 1.5))
                    .frame(width: 12, height: 12)
                    .scaleEffect(i < lit ? 1.0 : 0.85)
            }
            if chain >= 2 {
                Text("×\(chain)")
                    .font(SwoopTheme.number(18))
                    .foregroundStyle(SwoopTheme.goldLight)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(SwoopTheme.abyss.opacity(chain > 0 ? 0.45 : 0)))
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: chain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Perfect chain \(chain)")
    }
}

struct TailwindBadge: View {
    let seconds: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wind")
                .font(.system(size: 14, weight: .heavy))
            Text("TAILWIND")
                .font(SwoopTheme.text(14, .black))
                .kerning(0.8)
        }
        .foregroundStyle(SwoopTheme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(LinearGradient(colors: [SwoopTheme.goldLight, SwoopTheme.gold, SwoopTheme.ember],
                                          startPoint: .leading, endPoint: .trailing))
                .shadow(color: SwoopTheme.gold.opacity(0.7), radius: 8)
        )
        .accessibilityLabel("Tailwind")
    }
}

// MARK: - Hints, countdown, toasts

struct HintBubble: View {
    let hint: AppHint?
    let touch: Bool
    let info: AppCanvas

    /// The hint copy (GAME-DESIGN §9), with the touch control's words on phones. Pure; tested.
    nonisolated static func text(_ hint: AppHint, touch: Bool) -> String {
        switch hint {
        case .fold: return touch ? "Hold on the way down" : "Fold on the way down"
        case .open: return touch ? "Let go to fly" : "Open to fly"
        }
    }

    var body: some View {
        ZStack {
            if let hint {
                HStack(spacing: 10) {
                    Image(systemName: hint == .fold ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(SwoopTheme.gold)
                    Text(Self.text(hint, touch: touch))
                        .font(SwoopTheme.title(info.isCompact ? 19 : 23))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(SwoopTheme.abyss.opacity(0.72))
                    .overlay(Capsule().stroke(SwoopTheme.gold.opacity(0.4), lineWidth: 1.5)))
                .id(hint)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hint)
    }
}

/// The middle of the far half: 3-2-1, "Ready" after a resume, the lighthouse card and the toasts.
struct CenterStage: View {
    @ObservedObject var hud: HUDState
    let touch: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            if let n = hud.countdown {
                VStack(spacing: 4) {
                    Text("\(n)")
                        .font(SwoopTheme.display(150))
                        .foregroundStyle(LinearGradient(colors: [SwoopTheme.goldLight, SwoopTheme.gold],
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: SwoopTheme.gold.opacity(0.5), radius: 20)
                        .id(n)
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.4).combined(with: .opacity))
                    Text(touch ? "Hold to tuck · let go to soar" : "Hold it like a book")
                        .font(SwoopTheme.title(20))
                        .foregroundStyle(SwoopTheme.foam)
                        .swoopLegible()
                }
            } else if let ready = hud.ready {
                ReadyRing(remaining: ready, total: GameController.readyHold)
            }
            VStack(spacing: 12) {
                if let card = hud.lighthouse {
                    LighthouseCard(toast: card)
                        .id(card.serial)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let toast = hud.toast {
                    ToastPill(toast: toast)
                        .id(toast.serial)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .animation(SwoopTheme.pop(reduceMotion), value: hud.countdown)
        .animation(SwoopTheme.pop(reduceMotion), value: hud.toast)
        .animation(SwoopTheme.pop(reduceMotion), value: hud.lighthouse)
    }
}

struct ReadyRing: View {
    let remaining: Double
    let total: Double

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
                    .font(SwoopTheme.title(24))
                    .foregroundStyle(SwoopTheme.foam)
            }
            .frame(width: 120, height: 120)
            Text("Spread your wings")
                .font(SwoopTheme.text(17, .bold))
                .foregroundStyle(SwoopTheme.mist)
        }
        .swoopLegible()
    }
}

struct LighthouseCard: View {
    let toast: HUDToast

    var body: some View {
        HStack(spacing: 12) {
            LighthouseGlyph()
                .fill(LinearGradient(colors: [SwoopTheme.foam, SwoopTheme.goldLight], startPoint: .top,
                                     endPoint: .bottom))
                .frame(width: 30, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(SwoopTheme.title(24))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(toast.detail + " · the storm falls back")
                    .font(SwoopTheme.text(13, .bold))
                    .foregroundStyle(SwoopTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SwoopTheme.abyss.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SwoopTheme.gold.opacity(0.5), lineWidth: 1.5))
        )
        .accessibilityElement(children: .combine)
    }
}

struct ToastPill: View {
    let toast: HUDToast

    var body: some View {
        VStack(spacing: 2) {
            Text(toast.title)
                .font(SwoopTheme.display(toast.kind == .newBest ? 34 : 30))
                .foregroundStyle(toast.kind == .newBest ? SwoopTheme.gold : SwoopTheme.foam)
            Text(toast.detail)
                .font(SwoopTheme.text(14, .bold))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Capsule().fill(SwoopTheme.abyss.opacity(0.6)))
        .swoopLegible()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pause and closing

struct PauseCard: View {
    let canRestart: Bool
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(SwoopTheme.display(34))
                .foregroundStyle(SwoopTheme.foam)
            Text("The storm waits for you.")
                .font(SwoopTheme.text(16, .bold))
                .foregroundStyle(SwoopTheme.mist)
                .padding(.bottom, 4)
            SwoopButton(kind: .primary, height: 64, action: onResume) {
                Label("Resume", systemImage: "play.fill")
            }
            HStack(spacing: 10) {
                if canRestart {
                    SwoopButton(kind: .secondary, height: 56, action: onRestart) {
                        Label("Restart", systemImage: "arrow.clockwise")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                SwoopButton(kind: .quiet, height: 56, action: onHome) {
                    Label("Home", systemImage: "house.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .swoopCard(padding: 22)
    }
}

/// The Duo is closing (< 95°) mid-flight: the run holds. No buttons: opening it again resumes behind "Ready".
struct ClosingCard: View {
    let info: AppCanvas

    var body: some View {
        let page = info.farPage
        VStack(spacing: 12) {
            BirdGlyph()
                .fill(SwoopTheme.foam)
                .frame(width: 70, height: 32)
            Text("Open your wings to keep flying")
                .font(SwoopTheme.title(26))
                .foregroundStyle(SwoopTheme.foam)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Paused while your Duo is closing.")
                .font(SwoopTheme.text(16, .bold))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: min(page.width, 380))
        .swoopCard(padding: 24)
        .position(x: page.midX, y: info.size.height / 2)
        .accessibilityElement(children: .combine)
    }
}
