import QuartzCore
import SwiftUI

/// Home (GAME-DESIGN §9–§10): the attract flight runs behind; the big front-on title bird spans both halves, across
/// the fold, and tucks LIVE with the hinge ("These are your wings"); the wordmark and caption sit on the bird's half,
/// the menu on the other half (`HomeLayout`, fold-clear, every button ≥ 56 pt).
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Re-read every 30 s so the Daily rolls over at midnight while Home stays open.
    @State private var today = DailySeed.dayNumber(for: Date())
    /// Press-and-hold on the title bird (phones): the touch control's feel, taught on Home.
    @State private var heldSince: Double?
    @State private var releasedAt: Double?
    /// "Sign in to Game Center…" after a tap while signed out.
    @State private var gameCenterHint = false

    /// The navy scrim behind the wordmark and caption.
    static let textScrimOpacity: Double = 0.38

    private var layout: HomeLayout { HomeLayout.make(info) }

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
            // Legibility: a soft night scrim behind the menu half.
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(SwoopTheme.abyss.opacity(0.42))
                .frame(width: l.menuPanel.width, height: l.menuPanel.height)
                .position(x: l.menuPanel.midX, y: l.menuPanel.midY)
                .opacity(appeared ? 1 : 0)
            // REVIEW-1 P1-2: a feathered night scrim keeps the wordmark and caption readable over the attract bird,
            // its trail and spray.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(SwoopTheme.abyss.opacity(Self.textScrimOpacity))
                .frame(width: l.textBlock.width + 28, height: l.textBlock.height + 20)
                .blur(radius: 14)
                .position(x: l.textBlock.midX, y: l.textBlock.midY)
                .allowsHitTesting(false)
            titleBird(l.bird)
            SwoopWordmark(size: l.wordmark.height * 0.72)
                .frame(width: l.wordmark.width, height: l.wordmark.height,
                       alignment: info.mirrored ? .trailing : .leading)
                .position(x: l.wordmark.midX, y: l.wordmark.midY)
                .swoopLegible()
            caption
                .frame(width: l.caption.width, height: l.caption.height,
                       alignment: info.mirrored ? .topTrailing : .topLeading)
                .position(x: l.caption.midX, y: l.caption.midY)
            menu(l)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
            SwoopIconButton(systemName: "gearshape.fill", label: "Settings") { controller.show(.settings) }
                .position(x: l.settings.midX, y: l.settings.midY)
            SwoopIconButton(systemName: "gamecontroller.fill", label: "Game Center") {
                // QA-1 P1-5: never a dead button. Signed out with no sheet to offer: say how to sign in.
                if GameCenterManager.shared.showDashboard() == .signedOut { showSignInHint() }
            }
            .position(x: l.gameCenter.midX, y: l.gameCenter.midY)
            if gameCenterHint {
                Text("Sign in to Game Center in iOS Settings to see leaderboards.")
                    .font(SwoopTheme.text(14, .bold))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(SwoopTheme.abyss.opacity(0.9))
                        .overlay(Capsule().stroke(SwoopTheme.gold.opacity(0.4), lineWidth: 1.5)))
                    .frame(width: max(info.birdPage.width, 120))
                    .position(x: info.birdPage.midX, y: max(l.gameCenter.minY - 34, 20))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gameCenterHint)
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .onAppear {
            withAnimation(SwoopTheme.pop(reduceMotion).delay(0.05)) { appeared = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                let now = DailySeed.dayNumber(for: Date())
                if now != today { today = now }
            }
        }
    }

    // MARK: The title bird (live with the hinge)

    private func titleBird(_ rect: CGRect) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion && !controller.hasHinge)) { _ in
            let now = CACurrentMediaTime()
            let tuck = reduceMotion && !controller.hasHinge
                ? TitleTuck.idleRest
                : controller.titleTuck(now: now, heldSince: heldSince, releasedAt: releasedAt)
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
        .accessibilityLabel("Your bird, \(controller.bird.name). Its wings fold as you fold your Duo.")
    }

    private var caption: some View {
        let duo = controller.hasHinge || info.hasFold
        let first = duo ? "Hold your Duo like a book. These are your wings." : "Press and hold the bird. That's a tuck."
        let second = duo ? "Fold to dive. Open to soar." : "Hold to dive. Let go to soar."
        return VStack(alignment: info.mirrored ? .trailing : .leading, spacing: 6) {
            Text(controller.homeFolded ? second : first)
                .font(SwoopTheme.title(info.isCompact ? 17 : 21))
                .foregroundStyle(controller.homeFolded ? SwoopTheme.goldLight : SwoopTheme.foam)
                .multilineTextAlignment(info.mirrored ? .trailing : .leading)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .id(controller.homeFolded)
                .transition(.opacity)
            if store.data.bestMeters > 0 {
                Text("Best \(ShareText.km(store.data.bestMeters))")
                    .font(SwoopTheme.text(info.isCompact ? 14 : 16, .heavy))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
            }
        }
        .swoopLegible()
        .animation(.easeInOut(duration: 0.4), value: controller.homeFolded)
    }

    // MARK: The menu (the far half)

    private func menu(_ l: HomeLayout) -> some View {
        ZStack(alignment: .topLeading) {
            flyButton(l.fly)
            dailyButton(l.daily)
            SwoopButton(kind: .quiet, height: l.flocks.height, action: { controller.show(.goals) }) {
                twoLine("Flocks", icon: "bird.fill", detail: GoalCatalog.rankTitle(store.data.rank))
            }
            .frame(width: l.flocks.width, height: l.flocks.height)
            .position(x: l.flocks.midX, y: l.flocks.midY)
            .accessibilityLabel("Flocks, rank \(GoalCatalog.rankTitle(store.data.rank))")
            SwoopButton(kind: .quiet, height: l.birds.height, action: { controller.show(.birds) }) {
                twoLine("Birds", icon: "sparkles", detail: BirdCatalog.bird(store.activeBird).name)
            }
            .frame(width: l.birds.width, height: l.birds.height)
            .position(x: l.birds.midX, y: l.birds.midY)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    private func flyButton(_ r: CGRect) -> some View {
        SwoopButton(kind: .primary, height: r.height, action: { controller.fly() }) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: r.height > 64 ? 24 : 20, weight: .heavy))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fly")
                        .font(SwoopTheme.display(r.height > 64 ? 30 : 25))
                    Text(store.data.bestMeters > 0 ? "Outfly the storm · best \(ShareText.km(store.data.bestMeters))"
                                                   : "Outfly the storm")
                        .font(SwoopTheme.text(13, .bold))
                        .foregroundStyle(SwoopTheme.ink.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .accessibilityLabel("Fly")
    }

    private func dailyButton(_ r: CGRect) -> some View {
        let streak = store.data.dailyStreak(today: today)
        return SwoopButton(kind: .secondary, height: r.height, action: { controller.playDaily() }) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(SwoopTheme.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Flight #\(today)")
                        .font(SwoopTheme.title(19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(Self.dailyStatus(record: store.data.dailyRecord(day: today),
                                          attempted: store.hasDailyAttempt(day: today), streak: streak))
                        .font(SwoopTheme.text(13, .bold))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .accessibilityLabel("Daily Flight number \(today)\(streak > 0 ? ", streak \(streak) days" : "")")
    }

    /// The Daily button's second line. Pure; tested.
    /// QA-1 P1-2: a try that was started (even if the app died before anything was filed) is spent.
    nonisolated static func dailyStatus(record: DailyRecord?, attempted: Bool, streak: Int) -> String {
        let flame = streak > 0 ? " · \(ShareText.fire) \(streak)" : ""
        if let record { return "Flown · \(ShareText.km(record.meters)) · practice\(flame)" }
        if attempted { return "Tried · practice\(flame)" }
        return "Everyone's sea today · one try\(flame)"
    }

    private func twoLine(_ title: String, icon: String, detail: String) -> some View {
        VStack(spacing: 2) {
            Label(title, systemImage: icon)
                .font(SwoopTheme.text(18, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(SwoopTheme.text(12, .bold))
                .foregroundStyle(SwoopTheme.gold.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
