import QuartzCore
import SwiftUI

/// Home (UX §3 "Home", UX-A7, ART A12): the attract flight runs behind; the dorsal title bird spans both halves across
/// the fold and tucks LIVE with the hinge ("These are your wings"); the wordmark and caption sit on the bird's page over
/// a feathered scrim, the menu on the far page (`HomeLayout`, fold-clear, every button ≥ 56 pt). A fresh install shows
/// only Fly; Daily, Goals and Birds pop in after the first run with a gold dot until opened.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControl
    @State private var appeared = false
    /// Re-read every 30 s so the Daily rolls over at midnight while Home stays open.
    @State private var today = DailySeed.dayNumber(for: Date())
    @State private var now = Date()
    /// Press-and-hold on the title bird (phones): the touch control's feel, taught on Home.
    @State private var heldSince: Double?
    @State private var releasedAt: Double?
    /// "Sign in to Game Center…" after a tap while signed out.
    @State private var gameCenterHint = false
    /// Fly glows once after the first full stroke (UX §2).
    @State private var flyGlow = false
    /// Fly was tapped: the scene's title morph takes the bird from here (Scene `playTitleMorph`).
    @State private var titleHidden = false

    /// The scrim behind the wordmark and caption (ART A12): `surface` at 30 %, feathered.
    static let scrimOpacity: Double = 0.30
    static let glowSeconds: Double = 0.6

    private var layout: HomeLayout { HomeLayout.make(info) }
    private var isDuo: Bool { controller.hasHinge || info.hasFold }
    private var fresh: Bool { store.data.runs == 0 }

    private func showSignInHint() {
        gameCenterHint = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            gameCenterHint = false
        }
    }

    var body: some View {
        let l = layout
        ZStack(alignment: .topLeading) {
            // ART A12: a soft radial scrim, ending ≥ 28 pt + its feather before the crease.
            RadialGradient(colors: [SwoopTheme.surface.opacity(Self.scrimOpacity * 1.6),
                                    SwoopTheme.surface.opacity(Self.scrimOpacity), SwoopTheme.surface.opacity(0)],
                           center: .center, startRadius: 0, endRadius: max(l.scrim.width, l.scrim.height) * 0.62)
                .frame(width: l.scrim.width, height: l.scrim.height)
                .blur(radius: HomeLayout.scrimFeather)
                .position(x: l.scrim.midX, y: l.scrim.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            titleBird(l.bird)
                .opacity(titleHidden ? 0 : 1)
                .accessibilitySortPriority(1)
            SwoopWordmark(size: info.isCompact ? 52 : 72)
                .frame(width: l.wordmark.width, height: l.wordmark.height,
                       alignment: info.mirrored ? .trailing : .leading)
                .position(x: l.wordmark.midX, y: l.wordmark.midY)
                .swoopLegible()
                .accessibilitySortPriority(0)
            caption
                .frame(width: l.caption.width, height: l.caption.height,
                       alignment: info.mirrored ? .topTrailing : .topLeading)
                .position(x: l.caption.midX, y: l.caption.midY)
                .accessibilitySortPriority(0)
            menu(l)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 24)
            SwoopIconButton(systemName: "gearshape.fill", compact: info.isCompact, label: "Settings") {
                controller.show(.settings)
            }
            .position(x: l.settings.midX, y: l.settings.midY)
            .accessibilitySortPriority(5)
            SwoopIconButton(systemName: "trophy.fill", compact: info.isCompact, label: "Leaderboards") {
                // QA-1 P1-5: never a dead button. Signed out with no sheet to offer: say how to sign in.
                if GameCenterManager.shared.showDashboard() == .signedOut { showSignInHint() }
            }
            .position(x: l.gameCenter.midX, y: l.gameCenter.midY)
            .accessibilitySortPriority(4)
            if gameCenterHint {
                Text("Sign in to Game Center in Settings to see leaderboards.")
                    .font(SwoopType.caption(info.isCompact))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(SwoopTheme.surface.opacity(0.92))
                        .overlay(Capsule().stroke(SwoopTheme.stroke, lineWidth: 1)))
                    .frame(width: max(info.birdPage.width, 120))
                    .position(x: info.birdPage.midX, y: max(l.gameCenter.minY - 34, 20))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if showsTapOffer {
                tapOffer
                    .frame(width: min(info.farPage.width, 380))
                    .position(x: info.farPage.midX, y: max(l.fly.minY / 2, info.top + 90))
                    .transition(.opacity)
                    .accessibilitySortPriority(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gameCenterHint)
        .animation(SwoopTheme.settle(reduceMotion), value: showsTapOffer)
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .onAppear {
            titleHidden = false
            withAnimation(SwoopTheme.settle(reduceMotion).delay(0.05)) { appeared = true }
        }
        .onChange(of: controller.flyGlowSerial) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: Self.glowSeconds / 2)) { flyGlow = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.glowSeconds / 2 * 1_000_000_000))
                withAnimation(.easeIn(duration: Self.glowSeconds / 2)) { flyGlow = false }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                now = Date()
                let day = DailySeed.dayNumber(for: now)
                if day != today { today = day }
            }
        }
    }

    // MARK: The title bird (live with the hinge)

    private func titleBird(_ rect: CGRect) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion && !controller.hasHinge)) { _ in
            let t = CACurrentMediaTime()
            let tuck = reduceMotion && !controller.hasHinge
                ? TitleTuck.idleRest
                : controller.titleTuck(now: t, heldSince: heldSince, releasedAt: releasedAt)
            TitleBirdView(bird: controller.bird, tuck: tuck)
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard heldSince == nil else { return }
                    heldSince = CACurrentMediaTime()
                    releasedAt = nil
                    controller.noteHomeHold()
                }
                .onEnded { _ in
                    heldSince = nil
                    releasedAt = CACurrentMediaTime()
                }
        )
        .position(x: rect.midX, y: rect.midY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your bird, \(controller.bird.name). "
                            + (isDuo ? "Its wings fold as you fold your Duo." : "Press and hold to fold its wings."))
    }

    /// The caption's copy (UX §2): the first-fold line, then the fold line in gold-light; flat on a Duo, the bend line.
    /// Pure; tested.
    nonisolated static func captionText(duo: Bool, folded: Bool, flat: Bool) -> String {
        if duo && flat { return "Bend it a little, like a book." }
        if duo { return folded ? "Fold to dive. Open to soar." : "Hold your Duo like a book. These are your wings." }
        return folded ? "Hold to dive. Let go to soar." : "Press and hold the bird. That's a tuck."
    }

    private var caption: some View {
        let text = Self.captionText(duo: isDuo, folded: controller.homeFolded, flat: controller.homeFlat)
        let gold = controller.homeFolded && !(isDuo && controller.homeFlat)
        return VStack(alignment: info.mirrored ? .trailing : .leading, spacing: 8) {
            Text(text)
                .font(SwoopType.headline(info.isCompact))
                .foregroundStyle(gold ? SwoopTheme.goldLight : SwoopTheme.foam)
                .multilineTextAlignment(info.mirrored ? .trailing : .leading)
                .lineLimit(info.isCompact ? 2 : 3)
                .minimumScaleFactor(0.75)
                .id(text)
                .transition(.opacity)
            // UX §10: an iPhone's one-time line until the first flight.
            if !isDuo && fresh {
                Text("Made for iPhone Duo. Here, hold to tuck.")
                    .font(SwoopType.caption(info.isCompact))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .swoopLegible()
        .animation(.easeInOut(duration: 0.4), value: text)
    }

    // MARK: The menu (the far half)

    private func menu(_ l: HomeLayout) -> some View {
        ZStack(alignment: .topLeading) {
            flyButton(l.fly)
                .accessibilitySortPriority(10)
            if !fresh {
                dailyButton(l.daily)
                    .modifier(PopIn(shown: appeared, index: 0, reduceMotion: reduceMotion))
                    .accessibilitySortPriority(9)
                menuTile(l.flocks, title: "Goals", icon: "flag.checkered", detail: goalsLine,
                         dot: !store.data.seenDestinations.contains("goals")) { controller.show(.goals) }
                    .modifier(PopIn(shown: appeared, index: 1, reduceMotion: reduceMotion))
                    .accessibilitySortPriority(8)
                menuTile(l.birds, title: "Birds", icon: "bird.fill", detail: BirdCatalog.bird(store.activeBird).name,
                         dot: !store.data.seenDestinations.contains("birds")) { controller.show(.birds) }
                    .modifier(PopIn(shown: appeared, index: 2, reduceMotion: reduceMotion))
                    .accessibilitySortPriority(7)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    private var goalsLine: String {
        let d = store.data
        let goals = d.currentGoals
        let done = goals.filter { ProgressRules.liveProgress($0, data: d) >= 1 }.count
        return ProgressRules.goalsLine(rank: d.rank, done: done, total: max(goals.count, 3), starFlocks: d.starFlocks)
    }

    /// Fly's second line: "Outfly the storm", or "Best 6.4 km" once there is one (the caption no longer repeats it).
    /// Pure; tested.
    nonisolated static func flySubtitle(best: Double) -> String {
        best > 0 ? "Best \(ShareText.km(best))" : "Outfly the storm"
    }

    private func flyButton(_ r: CGRect) -> some View {
        let c = info.isCompact
        return SwoopButton(kind: .primary, height: r.height, compact: c, action: {
            titleHidden = true
            controller.fly()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: r.height > 64 ? 24 : 20, weight: .heavy))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fly")
                        .font(.system(size: r.height > 64 ? 30 : 25, weight: .black, design: .rounded))
                    Text(Self.flySubtitle(best: store.data.bestMeters))
                        .font(SwoopType.caption(c).weight(.bold))
                        .foregroundStyle(SwoopTheme.ink.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(c) + 6, style: .continuous)
                .fill(SwoopTheme.goldLight.opacity(flyGlow ? 0.55 : 0))
                .blur(radius: 14)
                .padding(-8)
                .allowsHitTesting(false)
        )
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .accessibilityLabel("Fly")
        .accessibilityHint(Self.flySubtitle(best: store.data.bestMeters))
    }

    private func dailyButton(_ r: CGRect) -> some View {
        let streak = store.data.dailyStreak(today: today)
        let attempted = store.hasDailyAttempt(day: today)
        let next = ShareText.nextInShort(seconds: ShareText.secondsToNextDaily(now: now))
        let status = Self.dailyStatus(record: store.data.dailyRecord(day: today), attempted: attempted, nextIn: next)
        return SwoopButton(kind: .secondary, height: r.height, compact: info.isCompact, action: {
            if attempted { controller.openDailyCard() } else { controller.playDaily() }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(SwoopTheme.foam)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Flight #\(today)")
                        .font(SwoopType.headline(true))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(status)
                        .font(SwoopType.caption(info.isCompact))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if streak >= 2 { StreakLabel(days: streak, compact: info.isCompact) }
                if !store.data.seenDestinations.contains("daily") { NewDot() }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily Flight number \(today). \(status)\(streak >= 2 ? ", \(streak)-day streak" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if attempted { controller.openDailyCard() } else { controller.playDaily() } }
    }

    /// The Daily button's second line (UX §3). Pure; tested.
    /// QA-1 P1-2: a try that was started (even if the app died before anything was filed) is spent.
    nonisolated static func dailyStatus(record: DailyRecord?, attempted: Bool, nextIn: String) -> String {
        if let record { return "Flown \(ShareText.km(record.meters)) · next in \(nextIn)" }
        if attempted { return "Tried · next in \(nextIn)" }
        return "Everyone's sea · one try"
    }

    private func menuTile(_ r: CGRect, title: String, icon: String, detail: String, dot: Bool,
                          action: @escaping () -> Void) -> some View {
        SwoopButton(kind: .secondary, height: r.height, compact: info.isCompact, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SwoopTheme.foam)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(SwoopType.body(info.isCompact).weight(.heavy))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                    Text(detail)
                        .font(SwoopType.caption(true))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if dot { NewDot() }
            }
        }
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)\(dot ? ", new" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    // MARK: The tap-to-tuck offer (UX §10)

    private var showsTapOffer: Bool {
        (voiceOver || switchControl) && !settings.tapOfferAnswered && !settings.tuckByTapping
    }

    private var tapOffer: some View {
        VStack(spacing: 12) {
            Text("Tap to tuck instead of holding?")
                .font(SwoopType.headline(info.isCompact))
                .foregroundStyle(SwoopTheme.foam)
                .multilineTextAlignment(.center)
            SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(info.isCompact), compact: info.isCompact,
                        action: {
                            settings.tuckByTapping = true
                            settings.tapOfferAnswered = true
                        }) {
                Text("Use tapping")
            }
            SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(info.isCompact),
                        compact: info.isCompact, action: { settings.tapOfferAnswered = true }) {
                Text("Keep holding")
            }
        }
        .swoopCard(radius: SwoopTheme.cardRadius(info.isCompact))
    }
}

/// The gold "new" dot on a Home destination until it is opened (UX §3).
struct NewDot: View {
    var body: some View {
        Circle()
            .fill(SwoopTheme.rewardGold)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

/// Home's pop-in after the first run: 0.4 s, 0.08 s stagger (UX §3). Reduce Motion: a fade.
struct PopIn: ViewModifier {
    let shown: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
            .animation((reduceMotion ? Animation.easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.8))
                .delay(0.08 * Double(index)), value: shown)
    }
}
