import SwiftUI

/// The results (UX §3 "Results", UX-A6, ART A6; R4 P0-1 "nothing clips"). Two cards, one per page:
/// - the far page (460 max): overline → distance (0.8 s count-up, a tick every 0.5 km) + chip → best line → hook →
///   stats → buttons. Fly again is live from frame 1;
/// - the bird page: the rank-up (or the goals), the small lines, and on Daily cards the share card and the streak row.
/// The split deck (one page) shows the far card with a one-line goals summary. `ResultsPlan` bounds every card's
/// height (each Text here has a matching line limit) and AppTests fails if any variant overflows any canvas.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var goalsShown = false
    @State private var shownMeters: Double = 0
    @State private var shareImage: Image?

    private var result: RunResult { summary.result }
    private var outcome: RecordOutcome { summary.outcome }

    /// ART §5: the distance counts up over 0.8 s, ease-out expo, one tick per 0.5 km.
    static let countUpSeconds: Double = 0.8
    static let tickMeters: Double = 500

    /// What kind of card this is: it picks the overline and the buttons.
    enum Kind: Equatable {
        /// `dailySpent`: the Daily card for a try that was started but never filed (R5 P1-4: no "0 m", no Share).
        case flight, firstFlight, scoredDaily, practiceDaily, dailyCard, dailySpent

        var isDaily: Bool { self != .flight && self != .firstFlight }
        var isDailyCardKind: Bool { self == .dailyCard || self == .dailySpent }
    }

    /// Pure; tested.
    nonisolated static func classify(isDailyCard: Bool, dailyDay: Int?, practice: Bool, title: String,
                                     spentUnfiled: Bool = false) -> Kind {
        if isDailyCard { return spentUnfiled ? .dailySpent : .dailyCard }
        if dailyDay != nil { return practice ? .practiceDaily : .scoredDaily }
        return title == "First flight" ? .firstFlight : .flight
    }

    /// The overline (in `mist`, never gold), with the Daily's display number. Pure; tested.
    nonisolated static func overline(_ kind: Kind, day: Int?) -> String {
        let tag = AppRules.dailyTag(day: day ?? AppRules.launchDay)
        switch kind {
        case .flight: return "Flight"
        case .firstFlight: return "First flight"
        case .scoredDaily, .dailyCard, .dailySpent: return "Daily Flight \(tag)"
        case .practiceDaily: return "Daily \(tag) · practice"
        }
    }

    /// "Best 6.42 km" / "Previous best 6.42 km"; none on a first flight or any Daily (a Daily over a Flight best read as
    /// an error, R4 P1-7). Pure; tested.
    nonisolated static func bestLine(_ kind: Kind, showsNewBest: Bool, best: Double, previousBest: Double) -> String? {
        if kind == .firstFlight || kind.isDaily { return nil }
        if showsNewBest { return previousBest > 0 ? "Previous best \(ShareText.distance(previousBest))" : nil }
        return best > 0 ? "Best \(ShareText.distance(best))" : nil
    }

    /// The chip by the distance: "New best!", else "Daily best!" (R4 P1-13). Pure; tested.
    nonisolated static func chip(showsNewBest: Bool, dailyBest: Bool, kind: Kind) -> String? {
        if showsNewBest { return "New best!" }
        if dailyBest && kind.isDaily { return "Daily best!" }
        return nil
    }

    /// The ease-out expo count-up at time `t` of `duration`. Pure; tested.
    nonisolated static func countUp(meters: Double, t: Double, duration: Double) -> Double {
        guard meters.isFinite, meters > 0 else { return 0 }
        guard duration > 0, t < duration else { return meters }
        let x = min(max(t / duration, 0), 1)
        let eased = x >= 1 ? 1 : 1 - pow(2, -10 * x)
        return meters * eased
    }

    private var kind: Kind {
        Self.classify(isDailyCard: summary.isDailyCard, dailyDay: summary.dailyDay, practice: summary.practice,
                      title: summary.title, spentUnfiled: summary.dailySpentUnfiled)
    }

    private var today: Int { DailySeed.dayNumber(for: Date()) }

    /// The Flight card's Daily row: today's Daily unflown, and at least one run done.
    private var dailyRowAllowed: Bool {
        controller.store.data.runs >= 1 && controller.store.dailyIsScorable(day: today)
    }

    var body: some View {
        let farSpace = ResultsLayout.far(info)
        let plan = ResultsPlan.make(summary, canvas: info, cardHeight: farSpace.height, dailyRowAllowed: dailyRowAllowed)
        let c = plan.compact
        // R5 P1-4: the far card is sized to its content and bottom-anchored (no ~190 pt void above the buttons).
        let farRect = ResultsLayout.anchored(farSpace, height: plan.farHeight())
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: c ? 8 : 12) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: c ? 8 : 12) {
                        header(plan)
                        farDetails(plan)
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                buttons(plan)
            }
            .swoopCard(padding: ResultsPlan.padding(c), radius: SwoopTheme.cardRadius(c))
            .frame(width: farRect.width, height: farRect.height)
            .position(x: farRect.midX, y: farRect.midY)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared || reduceMotion ? 0 : (info.mirrored ? -30 : 30))
            if plan.twoPages && plan.hasSideCard {
                let side = ResultsLayout.side(info)
                sideCard(plan, width: side.width)
                    .frame(width: side.width, alignment: .topLeading)
                    .frame(width: side.width, height: side.height, alignment: .top)
                    .position(x: side.midX, y: side.midY)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared || reduceMotion ? 0 : (info.mirrored ? 30 : -30))
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .onAppear {
            withAnimation(SwoopTheme.settle(reduceMotion)) { appeared = true }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.9).delay(0.35)) {
                goalsShown = true
            }
            renderShareImage()
        }
        .task(id: result.meters) { await countUp() }
    }

    // MARK: The far card

    private func header(_ plan: ResultsPlan) -> some View {
        let c = plan.compact
        let chip = Self.chip(showsNewBest: outcome.showsNewBest, dailyBest: summary.dailyBest, kind: kind)
        let head = RouteRules.headline(reachedThisRun: result.lighthouses, meters: result.meters)
        var headText: [String] = []
        if plan.headline {
            headText.append(head.title)
            if plan.headlineSub, let sub = head.sub { headText.append(sub) }
        }
        return VStack(alignment: .leading, spacing: c ? 2 : 4) {
            SwoopOverline(text: Self.overline(kind, day: summary.dailyDay), compact: c)
            // R6 D3 (UX §4.6): lead with the objective: the mini route, then "Caught 0.8 km short of Saltlight" /
            // "Reached Kestrel Head!".
            if plan.routeStrip {
                MiniRouteStrip(reachedThisRun: result.lighthouses, meters: result.meters, mirrored: info.mirrored)
                    .frame(height: ResultsPlan.stripHeight)
            }
            if plan.headline {
                // R7 P0-4: the name is never cut ("Reached Cormorant…"): the chip goes first when space runs out.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        headlineText(head.title, reached: head.reached, compact: c).fixedSize()
                        if outcome.newOnRoute { newOnRouteChip(c) }
                    }
                    headlineText(head.title, reached: head.reached, compact: c).fixedSize()
                    headlineText(head.title, reached: head.reached, compact: c)
                        .minimumScaleFactor(0.6)
                }
                if plan.headlineSub, let sub = head.sub {
                    Text(sub)
                        .font(SwoopType.body(c))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if kind == .dailySpent {
                // R5 P1-4: a spent, unfiled try never leads with "0 m".
                Text("Today's try is spent.")
                    .font(SwoopType.title(c))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ShareText.distance(shownMeters))
                        .font(SwoopType.hero(c))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let chip {
                        SwoopPill(text: chip, fill: SwoopTheme.rewardGold, fontSize: c ? 12 : 14)
                    }
                }
            }
            if let best = Self.bestLine(kind, showsNewBest: outcome.showsNewBest, best: outcome.best,
                                        previousBest: outcome.previousBest) {
                Text(best)
                    .font(SwoopType.body(c))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((headText + [accessibleHeader(chip: chip)]).joined(separator: ", "))
    }

    private func headlineText(_ s: String, reached: Bool, compact c: Bool) -> some View {
        Text(s)
            .font(SwoopType.headline(c))
            .foregroundStyle(reached ? SwoopTheme.rewardGold : SwoopTheme.foam)
            .lineLimit(1)
    }

    private func newOnRouteChip(_ c: Bool) -> some View {
        Text("New on your route")
            .font(SwoopType.chip(c))
            .foregroundStyle(SwoopTheme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(SwoopTheme.rewardGold))
            .lineLimit(1)
            .fixedSize()
    }

    private func accessibleHeader(chip: String?) -> String {
        var parts = [Self.overline(kind, day: summary.dailyDay),
                     kind == .dailySpent ? "Today's try is spent." : ShareText.distance(result.meters)]
        if let chip { parts.append(chip) }
        if let best = Self.bestLine(kind, showsNewBest: outcome.showsNewBest, best: outcome.best,
                                    previousBest: outcome.previousBest) { parts.append(best) }
        return parts.joined(separator: ", ")
    }

    /// R6 (UX §4.6): the "Next time" tip (the best hook replaces the last rule within 10 % of the best).
    private var hook: String? {
        Self.nextTip(summary)
    }

    /// Pure; tested.
    nonisolated static func nextTip(_ s: ResultSummary) -> String? {
        if s.isDailyCard { return nil }
        let r = s.result
        let o = s.outcome
        var nearBest: String?
        if o.previousBest > 0 && r.meters < o.previousBest && o.previousBest - r.meters <= o.previousBest * 0.10 {
            nearBest = "\(ShareText.distance(o.previousBest - r.meters, roundUp: true)) short of your best"
        }
        return RouteRules.nextTip(firstRealRun: s.firstRealRun, perfects: r.perfects, splashes: r.splashes,
                                  bestChain: r.bestChain, nearBestHook: nearBest)
    }

    @ViewBuilder
    private func farDetails(_ plan: ResultsPlan) -> some View {
        let c = plan.compact
        if plan.hasHook, let hook {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SwoopTheme.mist)
                    .padding(.top, 2)
                Text(hook)
                    .font(SwoopType.body(c))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(ResultsPlan.hookLines)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                // UX §4.4: the Route entry at the end of the tip line.
                Button { controller.show(.route) } label: {
                    Text("Route ›")
                        .font(SwoopType.body(c))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minHeight: AppCanvas.minTap * 0.75)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open your route")
            }
        }
        if plan.routeNote {
            // D4 (UX §5): the first results ever.
            Text("Every lighthouse you reach goes on your Route.")
                .font(SwoopType.caption(c))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        if plan.hasStats {
            Text(AppRules.statsLine(perfects: result.perfects, chain: 0, lighthouses: 0))
                .font(SwoopType.body(c).monospacedDigit())
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        if plan.spentLine {
            Text("Today's try is spent.")
                .font(SwoopType.body(c))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
        }
        if plan.deckSummary, let line = Self.deckSummary(summary) {
            Text(line)
                .font(SwoopType.caption(c))
                .foregroundStyle(SwoopTheme.goldLight)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// The split deck's one line for the bird-page content: "You ranked up! New bird: Tern · Rank 2 · Gull Wing" or
    /// "2 of 3 goals · next: Chain 12 Perfects". Pure; tested.
    nonisolated static func deckSummary(_ s: ResultSummary) -> String? {
        if let up = s.outcome.rankUp {
            let unlocks = RankUpBanner.unlockLine(birds: up.birds.map { BirdCatalog.bird($0).name },
                                                  skies: up.skies.map { SkyCatalog.sky($0).name }, trails: up.trailNames)
            return RankUpBanner.title(from: up.from, to: up.to) + (unlocks.isEmpty ? "" : " " + unlocks)
                + " · " + RankUpBanner.rankLine(rank: up.to, title: GoalCatalog.rankTitle(up.to))
        }
        let rows = s.outcome.goals
        guard !rows.isEmpty else { return nil }
        let done = rows.filter { $0.isMet }.count
        if let next = rows.first(where: { !$0.isMet }) {
            return "\(done) of \(rows.count) goals · next: \(next.goal.text)"
        }
        return "\(done) of \(rows.count) goals"
    }

    // MARK: The bird-page card

    @ViewBuilder
    private func sideCard(_ plan: ResultsPlan, width: CGFloat) -> some View {
        let c = plan.compact
        VStack(alignment: .leading, spacing: c ? 8 : 12) {
            if plan.shareThumb {
                shareThumbnail(side: ResultsPlan.thumbSide(width: width, compact: c))
                StreakDots(flown: Self.lastSevenDays(controller.store.data, today: today), today: today, compact: c)
            }
            if plan.rankUp, let rankUp = outcome.rankUp {
                RankUpBanner(rankUp: rankUp, compact: c, nextGoals: outcome.nextGoals)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if plan.goals > 0 {
                VStack(alignment: .leading, spacing: c ? 6 : 10) {
                    SwoopOverline(text: "Goals", compact: c)
                    ForEach(outcome.goals) { row in
                        GoalProgressRow(goal: row.goal, progress: goalsShown ? row.after : row.before,
                                        done: goalsShown ? row.isMet : row.before >= 1,
                                        justMet: goalsShown && row.justMet,
                                        caption: AppRules.goalCaption(row.goal, before: row.before, run: result,
                                                                      lifetime: controller.store.data.lifetimeMeters,
                                                                      done: goalsShown ? row.isMet : row.before >= 1),
                                        compact: c)
                    }
                }
            }
            ForEach(Self.smallLines(summary, limit: ResultsPlan.smallLineLimit(c)), id: \.self) { line in
                Text(line)
                    .font(SwoopType.caption(c))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .swoopCard(padding: ResultsPlan.padding(c), radius: SwoopTheme.cardRadius(c))
    }

    /// The small lines, most important first: the streak grace, the star goals,
    /// the rest line. At most `limit`. Pure; tested.
    nonisolated static func smallLines(_ s: ResultSummary, limit: Int = 4) -> [String] {
        var out: [String] = []
        if s.outcome.dailyGraceKept { out.append("Calm sea: streak kept") }
        // R6 (UX §4.6): "New in the logbook" is cut; the headline's "New on your route" chip carries it.
        if s.outcome.starEarned { out.append("Star goals done ★") }
        if s.showsRestLine { out.append("Long flight. Your wings can rest; the Daily will wait.") }
        return Array(out.prefix(max(limit, 0)))
    }

    /// The last 7 days, oldest first: true where a scored Daily was flown. Pure; tested.
    nonisolated static func lastSevenDays(_ data: ProgressData, today: Int) -> [Bool] {
        (0..<7).map { i in data.daily[today - 6 + i] != nil }
    }

    @ViewBuilder
    private func shareThumbnail(side: CGFloat) -> some View {
        Group {
            if let shareImage {
                shareImage
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                ShareCardView(summary: summary, bird: controller.bird)
                    .scaleEffect(side / ShareCardView.side)
                    .frame(width: side, height: side)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(true), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(true), style: .continuous)
            .stroke(SwoopTheme.stroke, lineWidth: 1))
        .accessibilityLabel("Share card")
    }

    // MARK: Buttons (R5 P0-1: built from `ResultsButtons`, so a test proves every one has a label and fits)

    @ViewBuilder
    private func buttons(_ plan: ResultsPlan) -> some View {
        let c = plan.compact
        let rows = ResultsButtons.rows(kind: kind, compact: c, dailyRow: plan.dailyRow, oneRow: plan.oneRow,
                                       dailyTag: AppRules.dailyTag(day: today))
        VStack(alignment: .leading, spacing: ResultsPlan.buttonGap(c)) {
            if plan.streak { streakLine(compact: c) }
            ForEach(Array(rows.enumerated()), id: \.offset) { row in
                HStack(spacing: c ? 8 : 10) {
                    ForEach(row.element, id: \.self) { b in
                        button(b, compact: c)
                    }
                }
            }
            if plan.dailyRow && plan.dailyExplain {
                Text("Daily Flight: one try a day, same sea for everyone. Not flown yet.")
                    .font(SwoopType.caption(c))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .onAppear { controller.learnHint(AppRules.dailyRowHint) }
            }
            if plan.helper {
                FoldHelperText(hud: controller.hud, compact: c)
            }
        }
    }

    @ViewBuilder
    private func button(_ b: ResultsButton, compact: Bool) -> some View {
        if b.action == .share {
            shareButton(b, compact: compact)
        } else if b.iconOnly {
            Button {
                FeedbackDirector.shared.uiTap()
                perform(b.action)
            } label: {
                Image(systemName: b.icon)
            }
            .buttonStyle(SwoopIconTileStyle(compact: compact))
            .accessibilityLabel(b.title)
        } else {
            let label = Label(b.title, systemImage: b.icon)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Group {
                if b.action == .flyAgain {
                    SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(compact), compact: compact,
                                action: { perform(b.action) }) { label }
                        .overlay(FoldFillOverlay(hud: controller.hud, compact: compact).allowsHitTesting(false))
                        .accessibilityHint(summary.hingeRun ? "Or fold and open your Duo." : "")
                } else {
                    SwoopButton(kind: b.primary ? .primary : .secondary,
                                height: b.primary ? SwoopTheme.primaryHeight(compact) : SwoopTheme.secondaryHeight(compact),
                                compact: compact, action: { perform(b.action) }) { label }
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(b.primary ? 2 : 1)
            .accessibilityLabel(b.title)
        }
    }

    private func perform(_ action: ResultsButton.Action) {
        switch action {
        case .flyAgain: controller.flyAgain()
        case .daily: controller.playDaily()
        case .home: controller.goHome()
        case .freeFlight: controller.freeFlight()
        case .practise, .practiseAgain: controller.practiseDaily()
        case .share: break
        }
    }

    @ViewBuilder
    private func shareButton(_ b: ResultsButton, compact: Bool) -> some View {
        let label = Group {
            if b.iconOnly {
                Image(systemName: b.icon)
            } else {
                Label(b.title, systemImage: b.icon)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        let link = Group {
            if let shareImage {
                ShareLink(item: shareImage, message: Text(summary.share),
                          preview: SharePreview("Swoop", image: shareImage)) { label }
            } else {
                ShareLink(item: summary.share) { label }
            }
        }
        if b.iconOnly {
            link.buttonStyle(SwoopIconTileStyle(compact: compact))
                .accessibilityLabel(b.title)
        } else {
            link.buttonStyle(SwoopButtonStyle(kind: b.primary ? .primary : .secondary,
                                              height: b.primary ? SwoopTheme.primaryHeight(compact)
                                                  : SwoopTheme.secondaryHeight(compact),
                                              compact: compact))
                .frame(maxWidth: .infinity)
                .layoutPriority(b.primary ? 2 : 1)
                .accessibilityLabel(b.title)
        }
    }

    @ViewBuilder
    private func streakLine(compact: Bool) -> some View {
        let streak = outcome.dailyStreak
        let next = ShareText.nextIn(seconds: ShareText.secondsToNextDaily(now: Date()))
        HStack(spacing: 6) {
            if streak >= 1 {
                Image(systemName: "flame.fill")
                    .font(SwoopType.caption(compact))
                    .foregroundStyle(SwoopTheme.flame)
            }
            Text(Self.streakText(streak: streak, nextIn: next))
                .font(SwoopType.caption(compact))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// "3-day streak · next Daily in 6 h 12 m" (a streak of 0 or 1 shows only the next-in). Pure; tested.
    nonisolated static func streakText(streak: Int, nextIn: String) -> String {
        streak >= 2 ? "\(streak)-day streak · next Daily in \(nextIn)" : "Next Daily in \(nextIn)"
    }

    // MARK: Count-up and share card

    private func countUp() async {
        let target = result.meters.isFinite ? max(result.meters, 0) : 0
        if reduceMotion || AppTrace.enabled {
            shownMeters = target
            return
        }
        let start = Date()
        var lastTick = 0
        while !Task.isCancelled {
            let t = Date().timeIntervalSince(start)
            let m = Self.countUp(meters: target, t: t, duration: Self.countUpSeconds)
            shownMeters = m
            let step = Int((m / Self.tickMeters).rounded(.down))
            if step > lastTick {
                lastTick = step
                FeedbackDirector.shared.cue(.resultsTick(step))
            }
            if t >= Self.countUpSeconds { break }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        shownMeters = target
    }

    private func renderShareImage() {
        let renderer = ImageRenderer(content: ShareCardView(summary: summary, bird: controller.bird))
        renderer.scale = ShareCardView.pixels / ShareCardView.side
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

// MARK: - The fit plan (R4 P0-1): pure, tested

/// What each results card holds and an upper bound of its height. The bound uses the type tokens' point sizes × 1.22
/// per line and the line limits ResultsView sets, so a variant that passes here can't clip on screen.
struct ResultsPlan: Equatable {
    var kind: ResultsView.Kind
    var compact: Bool
    /// Two pages (the book pose and every landscape iPhone): the rank-up / goals go to the bird-page card.
    var twoPages: Bool
    var hasBest = false
    /// R6: `hasHook` is the "Next time" tip (2 lines).
    var hasHook = false
    /// R6: the objective headline (and its "Caught … short of …" line after a reach), and the 56 pt mini route.
    var headline = false
    var headlineSub = false
    var routeStrip = false
    /// D4: "Every lighthouse you reach goes on your Route." under the tip on the first real run.
    var routeNote = false
    /// D4: the first time the Daily row shows, its sub-line.
    var dailyExplain = false
    var hasStats = false
    var spentLine = false
    var dailyRow = false
    var helper = false
    var streak = false
    var deckSummary = false
    var rankUp = false
    var goals = 0
    var smallLines = 0
    var shareThumb = false
    /// Short cards: Fly again, Home and Share in one row (the labelled Fly again stays the biggest control).
    var oneRow = false

    var hasSideCard: Bool { rankUp || goals > 0 || smallLines > 0 || shareThumb }

    /// Cards shorter than this use the compact layout (every iPhone in landscape, the split decks).
    static let compactCardHeight: CGFloat = 480
    static let hookLines = 2
    static let stripHeight: CGFloat = 56
    static func padding(_ c: Bool) -> CGFloat { c ? 14 : 20 }
    static func buttonGap(_ c: Bool) -> CGFloat { c ? 6 : 10 }
    static func smallLineLimit(_ c: Bool) -> Int { c ? 2 : 4 }
    static func line(_ size: CGFloat) -> CGFloat { (size * 1.22).rounded(.up) }

    // The token sizes (SwoopType).
    static func overline(_ c: Bool) -> CGFloat { c ? 11 : 12 }
    static func hero(_ c: Bool) -> CGFloat { c ? 52 : 76 }
    static func body(_ c: Bool) -> CGFloat { c ? 15 : 17 }
    static func caption(_ c: Bool) -> CGFloat { c ? 13 : 14 }
    static func headline(_ c: Bool) -> CGFloat { c ? 19 : 22 }
    /// Every button's tap height (the style never goes under 56).
    static func primary(_ c: Bool) -> CGFloat { max(SwoopTheme.primaryHeight(c), AppCanvas.minTap) }
    static let secondary: CGFloat = AppCanvas.minTap

    static func thumbSide(width: CGFloat, compact c: Bool) -> CGFloat {
        max(min(width - 2 * padding(c), c ? 180 : 260), 60)
    }

    static func make(_ s: ResultSummary, canvas: AppCanvas, cardHeight: CGFloat, dailyRowAllowed: Bool)
        -> ResultsPlan {
        let kind = ResultsView.classify(isDailyCard: s.isDailyCard, dailyDay: s.dailyDay, practice: s.practice,
                                        title: s.title, spentUnfiled: s.dailySpentUnfiled)
        let c = cardHeight < compactCardHeight
        var p = ResultsPlan(kind: kind, compact: c, twoPages: !canvas.singlePage)
        p.hasBest = ResultsView.bestLine(kind, showsNewBest: s.outcome.showsNewBest, best: s.outcome.best,
                                         previousBest: s.outcome.previousBest) != nil
        p.hasHook = kind != .dailySpent && ResultsView.nextTip(s) != nil
        p.headline = kind != .dailySpent
        p.headlineSub = p.headline && s.result.lighthouses >= 1
        p.routeStrip = p.headline && !c
        p.routeNote = p.hasHook && s.firstRealRun && !kind.isDaily
        p.dailyExplain = s.explainsDaily
        p.hasStats = kind != .dailySpent && !AppRules.statsLine(perfects: s.result.perfects, chain: 0, lighthouses: 0).isEmpty
        p.spentLine = false    // the spent card says it in its hero (R5 P1-4)
        p.dailyRow = (kind == .flight || kind == .firstFlight) && dailyRowAllowed
        p.helper = (kind == .flight || kind == .firstFlight) && s.showsFoldHelper
        p.streak = kind == .scoredDaily || kind == .dailyCard || kind == .dailySpent
        if p.twoPages {
            p.rankUp = s.outcome.rankUp != nil && !kind.isDailyCardKind
            p.goals = p.rankUp || kind.isDailyCardKind ? 0 : s.outcome.goals.count
            p.smallLines = ResultsView.smallLines(s, limit: smallLineLimit(c)).count
            // The flown Daily card's hero is its share card; a spent try has nothing to share.
            p.shareThumb = kind == .dailyCard
        } else {
            p.deckSummary = ResultsView.deckSummary(s) != nil
        }
        // R5: every button row must fit the card's width (labels never squeezed out): the Daily row goes first.
        let inner = ResultsLayout.far(canvas).width - 2 * padding(c)
        if !p.rowsFit(width: inner) { p.dailyRow = false }
        // Then fit the height by giving up, in order, the second button row (only if the one row [Fly again | Home |
        // Share] fits the width, so Fly again keeps its label), the Daily row, the hook, the stats.
        if p.farHeight() > cardHeight && c {
            var single = p
            single.oneRow = true
            if single.rowsFit(width: inner) { p = single }
        }
        if p.farHeight() > cardHeight { p.dailyRow = false }
        if p.farHeight() > cardHeight { p.routeNote = false }
        if p.farHeight() > cardHeight { p.hasHook = false }
        if p.farHeight() > cardHeight { p.hasStats = false }
        if p.farHeight() > cardHeight { p.headlineSub = false }
        if p.farHeight() > cardHeight { p.routeStrip = false }
        if p.farHeight() > cardHeight { p.headline = false }
        return p
    }

    /// Whether every button row fits `width` (tiles at 64, labels at their minimum).
    func rowsFit(width: CGFloat) -> Bool {
        ResultsButtons.rows(kind: kind, compact: compact, dailyRow: dailyRow, oneRow: oneRow,
                            dailyTag: "26 Oct")
            .allSatisfy { ResultsButtons.fits($0, width: width, compact: compact) }
    }

    /// The far card's height bound.
    func farHeight() -> CGFloat {
        let c = compact
        let s: CGFloat = c ? 8 : 12
        var h = 2 * Self.padding(c)
        h += Self.line(Self.overline(c)) + (c ? 2 : 4) + Self.line(Self.hero(c))
        if routeStrip { h += Self.stripHeight + (c ? 2 : 4) }
        if headline { h += Self.line(Self.headline(c)) + (c ? 2 : 4) }
        if headlineSub { h += Self.line(Self.body(c)) + (c ? 2 : 4) }
        if routeNote { h += s + Self.line(Self.caption(c)) }
        if hasBest { h += (c ? 2 : 4) + Self.line(Self.body(c)) }
        if hasHook { h += s + CGFloat(Self.hookLines) * Self.line(Self.body(c)) }
        if hasStats { h += s + Self.line(Self.body(c)) }
        if spentLine { h += s + Self.line(Self.body(c)) }
        if deckSummary { h += s + Self.line(Self.caption(c)) }
        h += 2 + s + buttonsHeight()
        return h
    }

    /// The button block: the streak line, the rows from `ResultsButtons`, the fold helper.
    func buttonsHeight() -> CGFloat {
        let c = compact
        let g = Self.buttonGap(c)
        let rows = ResultsButtons.rows(kind: kind, compact: c, dailyRow: dailyRow, oneRow: oneRow, dailyTag: "")
        var parts: [CGFloat] = rows.map { row in row.contains { $0.primary } ? Self.primary(c) : Self.secondary }
        if streak { parts.insert(Self.line(Self.caption(c)), at: 0) }
        if dailyRow && dailyExplain { parts.append(Self.line(Self.caption(c))) }
        if helper { parts.append(Self.line(Self.caption(c))) }
        return parts.reduce(0, +) + CGFloat(max(parts.count - 1, 0)) * g
    }

    /// The bird-page card's height bound at `width`.
    func sideHeight(width: CGFloat) -> CGFloat {
        guard hasSideCard else { return 0 }
        let c = compact
        let s: CGFloat = c ? 8 : 12
        var parts: [CGFloat] = []
        if shareThumb { parts.append(Self.thumbSide(width: width, compact: c) + s + StreakDots.height(c)) }
        if rankUp {
            parts.append(RankUpBanner.height(c))
        } else if goals > 0 {
            let row = GoalProgressRow.height(c)
            let gap: CGFloat = c ? 6 : 10
            parts.append(Self.line(Self.overline(c)) + gap + CGFloat(goals) * row + CGFloat(goals - 1) * gap)
        }
        for _ in 0..<smallLines { parts.append(2 * Self.line(Self.caption(c))) }
        let content = parts.reduce(0, +) + CGFloat(max(parts.count - 1, 0)) * s
        return content + 2 * Self.padding(c)
    }
}

// MARK: - The buttons as data (R5 P0-1): pure, tested

/// One results button: what it does, its label (also its VoiceOver label: never empty), its glyph, and whether it is
/// the primary or an icon-only 64 × 56 tile.
struct ResultsButton: Hashable {
    enum Action: Hashable { case flyAgain, daily, home, share, freeFlight, practise, practiseAgain }

    var action: Action
    var title: String
    var icon: String
    var primary = false
    var iconOnly = false

    static let tileWidth: CGFloat = 64

    /// The narrowest a labelled button can be before its label would clip: glyph + gap + text at 0.75 × (its minimum
    /// scale) + the style's 12 pt side padding. Text width is estimated at 0.56 em per character (SF Rounded).
    func minWidth(compact c: Bool) -> CGFloat {
        if iconOnly { return Self.tileWidth }
        let size: CGFloat = primary ? (c ? 18 : 20) : (c ? 15 : 17)
        return 20 + 6 + CGFloat(title.count) * size * 0.56 * 0.75 + 24
    }
}

enum ResultsButtons {
    /// The rows, top to bottom (UX R4 P1-1/P1-2, juror R4 #1/#6):
    /// - a Flight: the Daily row (Duo), Fly again full width and labelled, then [Daily · one try (compact) | Home | Share];
    ///   a very short card: one row [Fly again | Home | Share];
    /// - a scored Daily: Share, then [Free flight | Home]; the flown Daily card: Share, then [Practise | Home];
    /// - a spent, unfiled Daily: Practise today's sea, then Home (no Share: there is nothing to share);
    /// - a practice Daily: Practise again, then [Home | Share].
    /// Home and Share are icon-only tiles on compact cards, labelled on the Duo.
    static func rows(kind: ResultsView.Kind, compact c: Bool, dailyRow: Bool, oneRow: Bool, dailyTag: String)
        -> [[ResultsButton]] {
        let home = ResultsButton(action: .home, title: "Home", icon: "house.fill", iconOnly: c)
        let share = ResultsButton(action: .share, title: "Share", icon: "square.and.arrow.up", iconOnly: c)
        switch kind {
        case .flight, .firstFlight:
            let fly = ResultsButton(action: .flyAgain, title: "Fly again", icon: "arrow.clockwise", primary: true)
            if oneRow { return [[fly, home, share]] }
            if c {
                var second: [ResultsButton] = []
                if dailyRow { second.append(ResultsButton(action: .daily, title: "Daily · one try", icon: "calendar")) }
                second.append(home)
                second.append(share)
                return [[fly], second]
            }
            var rows: [[ResultsButton]] = []
            if dailyRow {
                rows.append([ResultsButton(action: .daily, title: "Daily Flight \(dailyTag) · one try", icon: "calendar")])
            }
            rows.append([fly])
            rows.append([home, share])
            return rows
        case .scoredDaily:
            return [[ResultsButton(action: .share, title: "Share", icon: "square.and.arrow.up", primary: true)],
                    [ResultsButton(action: .freeFlight, title: "Free flight", icon: "paperplane.fill"), home]]
        case .dailyCard:
            return [[ResultsButton(action: .share, title: "Share", icon: "square.and.arrow.up", primary: true)],
                    [ResultsButton(action: .practise, title: c ? "Practise" : "Practise today's sea",
                                   icon: "arrow.clockwise"), home]]
        case .dailySpent:
            return [[ResultsButton(action: .practise, title: "Practise today's sea", icon: "arrow.clockwise",
                                   primary: true)],
                    [ResultsButton(action: .home, title: "Home", icon: "house.fill")]]
        case .practiceDaily:
            return [[ResultsButton(action: .practiseAgain, title: "Practise again", icon: "arrow.clockwise",
                                   primary: true)],
                    [home, share]]
        }
    }

    /// Whether a row fits `width`: the tiles at 64, the labelled buttons at their minimum, plus the gaps. Pure; tested.
    static func fits(_ row: [ResultsButton], width: CGFloat, compact c: Bool) -> Bool {
        let gap: CGFloat = c ? 8 : 10
        let need = row.map { $0.minWidth(compact: c) }.reduce(0, +) + CGFloat(max(row.count - 1, 0)) * gap
        return need <= width + 0.5
    }
}

/// An icon-only results button (Home, Share on compact cards): the glyph centred, 20 pt, in a 64 × 56 secondary tile.
/// R5 P0-1: the glyph can never float outside its tile, whatever its neighbour takes.
struct SwoopIconTileStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(SwoopTheme.foam)
            .frame(width: ResultsButton.tileWidth, height: AppCanvas.minTap)
            .background(SwoopButtonBackground(kind: .secondary, pressed: configuration.isPressed, compact: compact))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .fixedSize()
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The last 7 days of the Daily as dots (flame where flown), oldest first, under a "Last 7 days" overline with each
/// day's weekday initial (UX R4 P2-7: the dots had no key).
struct StreakDots: View {
    let flown: [Bool]
    var today: Int = 0
    var compact: Bool = false

    nonisolated static func height(_ c: Bool) -> CGFloat {
        ResultsPlan.line(ResultsPlan.overline(c)) + 4 + (c ? 12 : 14) + 2 + ResultsPlan.line(11)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SwoopOverline(text: "Last 7 days", compact: compact)
            HStack(spacing: compact ? 8 : 10) {
                ForEach(Array(flown.enumerated()), id: \.offset) { item in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(item.element ? SwoopTheme.flame : SwoopTheme.surfaceRaised)
                            .overlay(Circle().stroke(SwoopTheme.stroke, lineWidth: 1))
                            .frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
                        Text(AppRules.weekdayInitial(day: today - (flown.count - 1) + item.offset))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(SwoopTheme.mist)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: Self.height(compact), alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dailies in the last 7 days: \(flown.filter { $0 }.count) of 7")
    }
}

/// Fly again's fold fill (UX-A3, R4 P1-14): an amber `#E8A93A` wash rising from the bottom edge and a 3 pt foam progress
/// line along the top, so the charge reads across the room; the label colour never changes.
struct FoldFillOverlay: View {
    @ObservedObject var hud: HUDState
    var compact: Bool = false

    static let amber = Color(swoopHex: 0xE8A93A)

    var body: some View {
        GeometryReader { geo in
            let u = CGFloat(min(max(hud.foldFill, 0), 1))
            let shape = RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(compact), style: .continuous)
            ZStack(alignment: .bottom) {
                // Multiply: the gold turns amber where it has charged, and the ink label stays ink.
                Rectangle()
                    .fill(Self.amber)
                    .frame(height: geo.size.height * u)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .blendMode(.multiply)
                Rectangle()
                    .fill(SwoopTheme.foam)
                    .frame(width: geo.size.width * u, height: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .clipShape(shape)
            .opacity(u > 0 ? 1 : 0)
            .animation(.easeOut(duration: 0.1), value: hud.foldFill)
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

/// "or fold and open" under Fly again; foam for 0.4 s while fold-to-fly is armed (UX R3 P1-4).
struct FoldHelperText: View {
    @ObservedObject var hud: HUDState
    var compact: Bool = false

    var body: some View {
        Text("Or fold and open to fly again")
            .font(SwoopType.caption(compact))
            .foregroundStyle(hud.foldArmed ? SwoopTheme.foam : SwoopTheme.mist)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.4), value: hud.foldArmed)
    }
}

/// The 1080 × 1080 share card (UX-A9): the sky, the dart, the distance, the line, the wordmark. No personal data.
struct ShareCardView: View {
    let summary: ResultSummary
    let bird: Bird

    static let side: CGFloat = 360
    static let pixels: CGFloat = 1080

    var body: some View {
        let r = summary.result
        ZStack {
            LinearGradient(colors: [Color(swoopHex: 0x1C4A73), Color(swoopHex: 0xF0A07A), Color(swoopHex: 0xFFD978)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color(swoopHex: 0x2C6A8F), Color(swoopHex: 0x0B2C4D)], startPoint: .top,
                           endPoint: .bottom)
                .frame(height: Self.side * 0.34)
                .frame(maxHeight: .infinity, alignment: .bottom)
            VStack(spacing: 8) {
                TitleBirdView(bird: bird, tuck: 0.35)
                    .frame(width: Self.side * 0.8, height: Self.side * 0.3)
                Text(ShareText.distance(r.meters))
                    .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: SwoopTheme.shadowBase.opacity(0.45), radius: 6, y: 2)
                Text(Self.subtitle(summary))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: SwoopTheme.shadowBase.opacity(0.45), radius: 4, y: 1)
                Spacer(minLength: 0)
                Text("SWOOP · TUCK & SOAR")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1.6)
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
        }
        .frame(width: Self.side, height: Self.side)
    }

    /// "Daily Flight #1 · 23 Perfects · past Saltlight" / "23 Perfects · past Saltlight". Pure; tested.
    nonisolated static func subtitle(_ s: ResultSummary) -> String {
        var parts: [String] = []
        if let day = s.dailyDay { parts.append("Daily Flight \(AppRules.dailyTag(day: day))") }
        if s.result.perfects > 0 { parts.append(ShareText.perfects(s.result.perfects)) }
        let past = s.result.lastLighthouseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !past.isEmpty { parts.append("past \(past)") }
        return parts.joined(separator: " · ")
    }
}

/// One goal: its text, its scope line ("This flight: 2 of 4", "In total · 48 km of 150 km", "Done in an earlier
/// flight"), a slate → mist bar (gold once done) and a check that pops when met.
struct GoalProgressRow: View {
    let goal: Goal
    let progress: Double
    let done: Bool
    var justMet: Bool = false
    var caption: String? = nil
    var compact: Bool = false

    /// The row's height bound (ResultsPlan): text (1 / 2 lines) + caption + bar.
    nonisolated static func height(_ c: Bool) -> CGFloat {
        CGFloat(c ? 1 : 2) * ResultsPlan.line(ResultsPlan.body(c)) + 2 + ResultsPlan.line(ResultsPlan.caption(c))
            + (c ? 3 : 6) + (c ? 6 : 8)
    }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 12) {
            ZStack {
                Circle()
                    .fill(done ? SwoopTheme.rewardGold : SwoopTheme.abyss.opacity(0.6))
                    .overlay(Circle().stroke(done ? SwoopTheme.rewardGold : SwoopTheme.stroke, lineWidth: 1.5))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 12 : 15, weight: .black))
                        .foregroundStyle(SwoopTheme.ink)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
            .scaleEffect(justMet ? 1.12 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.text)
                    .font(SwoopType.body(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption {
                    Text(caption)
                        .font(SwoopType.caption(compact))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                SwoopProgressBar(value: progress, height: compact ? 6 : 8, done: done)
                    .padding(.top, compact ? 3 : 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.text), \(done ? "done" : "\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")"
                            + (caption.map { ", \($0)" } ?? ""))
    }
}

/// "You ranked up!" / "New bird: Tern" / "Rank 2 · Puddle Hopper" / "New goals: Fly 3 km · 3 Perfects in one flight · Chain 2": the
/// finished goals collapse into this. Every line has a limit, so `height` bounds it (R4 P0-1).
struct RankUpBanner: View {
    let rankUp: AppRankUp
    var compact: Bool = false
    /// R8 P0-4: the new rank's goals as this run left them (met ones ticked).
    var nextGoals: [GoalRowOutcome] = []

    nonisolated static func height(_ c: Bool) -> CGFloat {
        2 * (c ? 10 : 14) + 2 * ResultsPlan.line(ResultsPlan.headline(c)) + 3 + 2 * ResultsPlan.line(ResultsPlan.body(c))
            + 3 + 3 * ResultsPlan.line(ResultsPlan.caption(c))
    }

    /// R7 P1-5 (plain words): "You ranked up!", after a cascade (R5 P1-9) "You ranked up twice!". Pure; tested.
    nonisolated static func title(from: Int, to: Int) -> String {
        switch to - from {
        case ...1: return "You ranked up!"
        case 2: return "You ranked up twice!"
        case 3: return "You ranked up three times!"
        case let n: return "You ranked up \(n) times!"
        }
    }

    /// "Rank 2 · Puddle Hopper" (the rank title is flavour, never a header alone). Pure; tested.
    nonisolated static func rankLine(rank: Int, title: String) -> String { "Rank \(rank + 1) · \(title)" }

    /// R7 P1-5: "New bird: Tern · New trail: Coral" (each reward named for what it is; empty when nothing unlocked).
    /// Pure; tested.
    nonisolated static func unlockLine(birds: [String], skies: [String], trails: [String] = []) -> String {
        var parts: [String] = []
        func add(_ names: [String], _ one: String, _ many: String) {
            guard !names.isEmpty else { return }
            parts.append((names.count == 1 ? one : many) + ": " + names.joined(separator: ", "))
        }
        add(birds, "New bird", "New birds")
        add(skies, "New sky", "New skies")
        add(trails, "New trail", "New trails")
        return parts.joined(separator: " · ")
    }

    /// R8 P0-4: "Next goals: ✓ Fly 3 km · Chain 5", the ones this run already met ticked. Pure; tested.
    nonisolated static func newGoalsLine(rows: [GoalRowOutcome]) -> String {
        guard !rows.isEmpty else { return "" }
        let all = rows.allSatisfy { $0.after >= 1 }
        let parts = rows.map { ($0.after >= 1 ? "✓ " : "") + $0.goal.text }
        return (all ? "Next goals, all done: " : "Next goals: ") + parts.joined(separator: " · ")
    }

    /// "New goals: A · B · C" for the rank reached (star goals past the top). Pure; tested.
    nonisolated static func newGoalsLine(rank: Int) -> String {
        let goals = ProgressRules.currentGoals(rank: rank, starFlocks: 0)
        guard !goals.isEmpty else { return "" }
        return "New goals: " + goals.map(\.text).joined(separator: " · ")
    }

    var body: some View {
        let title = Self.title(from: rankUp.from, to: rankUp.to)
        let unlocks = Self.unlockLine(birds: rankUp.birds.map { BirdCatalog.bird($0).name },
                                      skies: rankUp.skies.map { SkyCatalog.sky($0).name }, trails: rankUp.trailNames)
        let rank = Self.rankLine(rank: rankUp.to, title: GoalCatalog.rankTitle(rankUp.to))
        let goals = nextGoals.isEmpty ? Self.newGoalsLine(rank: rankUp.to) : Self.newGoalsLine(rows: nextGoals)
        HStack(alignment: .top, spacing: compact ? 10 : 14) {
            YouGlyph()
                .fill(SwoopTheme.ink)
                .frame(width: compact ? 22 : 28, height: compact ? 14 : 17)
                .frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                .background(Circle().fill(SwoopTheme.rewardGold))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SwoopType.headline(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if !unlocks.isEmpty {
                    Text(unlocks)
                        .font(SwoopType.body(compact))
                        .foregroundStyle(SwoopTheme.goldLight)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The rank title never stands alone: "Rank 3 · Spray Chaser".
                Text(rank)
                    .font(SwoopType.caption(compact))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !goals.isEmpty {
                    Text(goals)
                        .font(SwoopType.caption(compact))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                .fill(SwoopTheme.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(compact), style: .continuous)
                    .stroke(SwoopTheme.stroke, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}
