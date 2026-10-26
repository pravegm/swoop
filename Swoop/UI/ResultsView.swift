import SwiftUI

/// The results card (UX §3 "Results", UX-A6, ART A6): the far page, full height, 460 max; the calm bird stays on the
/// bird page. Order: overline → distance (counts up over 0.8 s, a tick every 0.5 km) + "New best!" → best line → hook
/// → stats (zeros dropped) → goals or the rank-up collapse → small lines → buttons. Fly again is live from frame 1.
/// The same view is the Daily card (route `.daily`, UX-A10) and the split deck's results.
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

    /// Cards shorter than this use the compact layout (every iPhone in landscape).
    static let compactCardHeight: CGFloat = 480
    /// ART §5: the distance counts up over 0.8 s, ease-out expo, one tick per 0.5 km.
    static let countUpSeconds: Double = 0.8
    static let tickMeters: Double = 500

    /// What kind of card this is: it picks the overline and the buttons.
    enum Kind: Equatable {
        case flight, firstFlight, scoredDaily, practiceDaily, dailyCard
    }

    /// Pure; tested.
    nonisolated static func classify(isDailyCard: Bool, dailyDay: Int?, practice: Bool, title: String) -> Kind {
        if isDailyCard { return .dailyCard }
        if dailyDay != nil { return practice ? .practiceDaily : .scoredDaily }
        return title == "First flight" ? .firstFlight : .flight
    }

    /// The overline (in `mist`, never gold). Pure; tested.
    nonisolated static func overline(_ kind: Kind, day: Int?) -> String {
        switch kind {
        case .flight: return "Flight"
        case .firstFlight: return "First flight"
        case .scoredDaily, .dailyCard: return "Daily Flight #\(day ?? 0)"
        case .practiceDaily: return "Daily #\(day ?? 0) · practice"
        }
    }

    /// "Best 6.4 km" / "Previous best 6.4 km"; none on a first flight. Pure; tested.
    nonisolated static func bestLine(_ kind: Kind, showsNewBest: Bool, best: Double, previousBest: Double) -> String? {
        if kind == .firstFlight { return nil }
        if showsNewBest { return previousBest > 0 ? "Previous best \(ShareText.km(previousBest))" : nil }
        return best > 0 ? "Best \(ShareText.km(best))" : nil
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
                  title: summary.title)
    }

    var body: some View {
        let card = info.singlePage
            ? CGRect(x: info.farPage.minX, y: 12, width: info.farPage.width, height: max(info.size.height - 24, 0))
            : ResultsLayout.card(info)
        let compact = card.height < Self.compactCardHeight
        ZStack(alignment: .topLeading) {
            VStack(spacing: compact ? 8 : 12) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                        header(compact: compact)
                        details(compact: compact)
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                buttons(compact: compact)
            }
            .swoopCard(padding: compact ? 14 : 20, radius: SwoopTheme.cardRadius(compact))
            .frame(width: card.width, height: card.height)
            .position(x: card.midX, y: card.midY)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared || reduceMotion ? 0 : (info.mirrored ? -30 : 30))
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

    // MARK: Header

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            SwoopOverline(text: Self.overline(kind, day: summary.dailyDay), compact: compact)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ShareText.km(shownMeters))
                    .font(SwoopType.hero(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if outcome.showsNewBest {
                    SwoopPill(text: "New best!", fill: SwoopTheme.rewardGold, fontSize: compact ? 12 : 14)
                }
            }
            if let best = Self.bestLine(kind, showsNewBest: outcome.showsNewBest, best: outcome.best,
                                        previousBest: outcome.previousBest) {
                Text(best)
                    .font(SwoopType.body(compact))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleHeader)
    }

    private var accessibleHeader: String {
        var parts = [Self.overline(kind, day: summary.dailyDay), ShareText.km(result.meters)]
        if outcome.showsNewBest { parts.append("New best") }
        if let best = Self.bestLine(kind, showsNewBest: outcome.showsNewBest, best: outcome.best,
                                    previousBest: outcome.previousBest) { parts.append(best) }
        return parts.joined(separator: ", ")
    }

    // MARK: Details

    @ViewBuilder
    private func details(compact: Bool) -> some View {
        let hook = AppRules.hookLine(meters: result.meters, best: outcome.best, previousBest: outcome.previousBest,
                                     lighthousesPassed: result.lighthouses, lastLighthouse: result.lastLighthouseName,
                                     seed: result.seed, firstFlight: kind == .firstFlight)
        if let hook {
            HStack(alignment: .top, spacing: 6) {
                LighthouseGlyph()
                    .fill(SwoopTheme.foam)
                    .frame(width: 12, height: 16)
                    .padding(.top, 2)
                Text(hook)
                    .font(SwoopType.body(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(compact ? 2 : 3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        let stats = AppRules.statsLine(perfects: result.perfects, chain: result.bestChain,
                                       lighthouses: result.lighthouses)
        if !stats.isEmpty && kind != .dailyCard {
            Text(stats)
                .font(SwoopType.body(compact).monospacedDigit())
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        if summary.dailySpentUnfiled {
            Text("Today's try is spent.")
                .font(SwoopType.body(compact))
                .foregroundStyle(SwoopTheme.mist)
        }
        if let rankUp = outcome.rankUp {
            RankUpBanner(rankUp: rankUp, compact: compact)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else if !outcome.goals.isEmpty && kind != .dailyCard {
            goals(compact: compact)
        }
        ForEach(Self.smallLines(summary), id: \.self) { line in
            Text(line)
                .font(SwoopType.caption(compact))
                .foregroundStyle(SwoopTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The small lines under the goals: the logbook, the streak grace, the star flock, the rest line. Pure; tested.
    nonisolated static func smallLines(_ s: ResultSummary) -> [String] {
        var out: [String] = []
        if !s.outcome.newLogbook.isEmpty {
            out.append("New in the logbook: " + s.outcome.newLogbook.joined(separator: ", "))
        }
        if s.outcome.dailyGraceKept { out.append("Calm sea: streak kept") }
        if s.outcome.starEarned { out.append("Star flock done ★") }
        if s.showsRestLine { out.append("Long flight. Your wings can rest; the Daily will wait.") }
        return out
    }

    private func goals(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            SwoopOverline(text: "Goals", compact: compact)
            ForEach(outcome.goals) { row in
                GoalProgressRow(goal: row.goal, progress: goalsShown ? row.after : row.before,
                                done: goalsShown ? row.isMet : row.before >= 1, justMet: goalsShown && row.justMet,
                                compact: compact)
            }
        }
    }

    // MARK: Buttons

    private var today: Int { DailySeed.dayNumber(for: Date()) }

    /// The Flight card's Daily row: today's Daily unflown, and at least one run done.
    private var showsDailyRow: Bool {
        (kind == .flight || kind == .firstFlight) && controller.store.data.runs >= 1
            && controller.store.dailyIsScorable(day: today)
    }

    @ViewBuilder
    private func buttons(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            switch kind {
            case .flight, .firstFlight:
                if showsDailyRow {
                    Button {
                        FeedbackDirector.shared.uiTap()
                        controller.playDaily()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                            Text("Daily Flight #\(today) · one try")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .font(SwoopType.body(compact))
                        .foregroundStyle(SwoopTheme.foam)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(compact), style: .continuous)
                            .fill(SwoopTheme.surfaceRaised.opacity(0.7)))
                        .frame(minHeight: AppCanvas.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SwoopPressStyle())
                }
                buttonRow(compact: compact, primary: flyAgainButton(compact: compact), secondary: [.home, .share])
                if summary.showsFoldHelper {
                    Text("or fold and open")
                        .font(SwoopType.caption(compact))
                        .foregroundStyle(SwoopTheme.mist)
                }
            case .scoredDaily:
                streakLine(compact: compact)
                buttonRow(compact: compact, primary: shareButton(compact: compact, primary: true),
                          secondary: [.freeFlight, .home])
            case .practiceDaily:
                buttonRow(compact: compact,
                          primary: primaryButton(compact: compact, title: "Practise again", icon: "arrow.clockwise") {
                              controller.practiseDaily()
                          },
                          secondary: [.home, .share])
            case .dailyCard:
                streakLine(compact: compact)
                buttonRow(compact: compact, primary: shareButton(compact: compact, primary: true),
                          secondary: [.practise, .home])
            }
        }
    }

    private enum Secondary: Hashable { case home, share, freeFlight, practise }

    @ViewBuilder
    private func buttonRow<P: View>(compact: Bool, primary: P, secondary: [Secondary]) -> some View {
        if compact {
            HStack(spacing: 8) {
                primary.layoutPriority(1)
                ForEach(secondary, id: \.self) { s in secondaryButton(s, compact: true, iconOnly: true) }
            }
        } else {
            VStack(spacing: 10) {
                primary
                HStack(spacing: 10) {
                    ForEach(secondary, id: \.self) { s in secondaryButton(s, compact: false, iconOnly: false) }
                }
            }
        }
    }

    @ViewBuilder
    private func secondaryButton(_ s: Secondary, compact: Bool, iconOnly: Bool) -> some View {
        let h = SwoopTheme.secondaryHeight(compact)
        switch s {
        case .home:
            SwoopButton(kind: .secondary, height: h, compact: compact, action: { controller.goHome() }) {
                if iconOnly { Image(systemName: "house.fill") } else { Label("Home", systemImage: "house.fill") }
            }
            .frame(width: iconOnly ? 64 : nil)
            .accessibilityLabel("Home")
        case .share:
            shareButton(compact: compact, primary: false, iconOnly: iconOnly)
                .frame(width: iconOnly ? 64 : nil)
        case .freeFlight:
            SwoopButton(kind: .secondary, height: h, compact: compact, action: { controller.freeFlight() }) {
                Label("Free flight", systemImage: "paperplane.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        case .practise:
            SwoopButton(kind: .secondary, height: h, compact: compact, action: { controller.practiseDaily() }) {
                Text("Practise today's sea")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func primaryButton(compact: Bool, title: String, icon: String,
                               action: @escaping () -> Void) -> some View {
        SwoopButton(kind: .primary, height: SwoopTheme.primaryHeight(compact), compact: compact, action: action) {
            Label(title, systemImage: icon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Fly again fills with the fold (UX-A3): the fill sweeps from the inner edge as the wings close.
    private func flyAgainButton(compact: Bool) -> some View {
        primaryButton(compact: compact, title: "Fly again", icon: "arrow.clockwise") { controller.flyAgain() }
            .overlay(FoldFillOverlay(hud: controller.hud, compact: compact).allowsHitTesting(false))
            .accessibilityHint(summary.hingeRun ? "Or fold and open your Duo." : "")
    }

    @ViewBuilder
    private func shareButton(compact: Bool, primary: Bool, iconOnly: Bool = false) -> some View {
        let h = primary ? SwoopTheme.primaryHeight(compact) : SwoopTheme.secondaryHeight(compact)
        let style = SwoopButtonStyle(kind: primary ? .primary : .secondary, height: h, compact: compact)
        Group {
            if let shareImage {
                ShareLink(item: shareImage, message: Text(summary.share),
                          preview: SharePreview("Swoop", image: shareImage)) {
                    shareLabel(iconOnly: iconOnly)
                }
            } else {
                ShareLink(item: summary.share) { shareLabel(iconOnly: iconOnly) }
            }
        }
        .buttonStyle(style)
        .accessibilityLabel("Share")
    }

    @ViewBuilder
    private func shareLabel(iconOnly: Bool) -> some View {
        if iconOnly {
            Image(systemName: "square.and.arrow.up")
        } else {
            Label("Share", systemImage: "square.and.arrow.up").lineLimit(1)
        }
    }

    @ViewBuilder
    private func streakLine(compact: Bool) -> some View {
        let streak = outcome.dailyStreak
        let next = ShareText.nextIn(seconds: ShareText.secondsToNextDaily(now: Date()))
        HStack(spacing: 6) {
            if streak >= 1 {
                Image(systemName: "flame.fill")
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

/// Fly again's fold fill (UX-A3): a gold-light wash across the button as the fold closes.
struct FoldFillOverlay: View {
    @ObservedObject var hud: HUDState
    var compact: Bool = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(compact), style: .continuous)
                .fill(SwoopTheme.rewardHighlight.opacity(0.55))
                .frame(width: geo.size.width * CGFloat(min(max(hud.foldFill, 0), 1)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.1), value: hud.foldFill)
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
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
                Text(ShareText.km(r.meters))
                    .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white)
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

    /// "Daily Flight #298 · 23 Perfects · past Saltlight" / "23 Perfects · past Saltlight". Pure; tested.
    nonisolated static func subtitle(_ s: ResultSummary) -> String {
        var parts: [String] = []
        if let day = s.dailyDay { parts.append("Daily Flight #\(day)") }
        if s.result.perfects > 0 { parts.append(ShareText.perfects(s.result.perfects)) }
        let past = s.result.lastLighthouseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !past.isEmpty { parts.append("past \(past)") }
        return parts.joined(separator: " · ")
    }
}

/// One goal: its text, a slate → mist bar (gold once done) and a check that pops when met.
struct GoalProgressRow: View {
    let goal: Goal
    let progress: Double
    let done: Bool
    var justMet: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
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
            VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                Text(goal.text)
                    .font(SwoopType.body(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.75)
                SwoopProgressBar(value: progress, height: compact ? 6 : 8, done: done)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.text), \(done ? "done" : "\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")")
    }
}

/// "Rank up! You're a Puddle Hopper" / "New: Tern" / "New goals: Fly 3 km · 3 Perfects in one flight · Chain 2": the
/// finished goals collapse into this (UX-A6; they clipped behind the buttons before).
struct RankUpBanner: View {
    let rankUp: AppRankUp
    var compact: Bool = false

    /// "New: Tern, Rose Dusk" (empty when nothing unlocked). Pure; tested.
    nonisolated static func unlockLine(birds: [String], skies: [String], trails: [String] = []) -> String {
        let all = birds + skies + trails
        guard !all.isEmpty else { return "" }
        return "New: " + all.joined(separator: ", ")
    }

    /// "New goals: A · B · C" for the rank reached (star goals past the top). Pure; tested.
    nonisolated static func newGoalsLine(rank: Int) -> String {
        let goals = ProgressRules.currentGoals(rank: rank, starFlocks: 0)
        guard !goals.isEmpty else { return "" }
        return "New goals: " + goals.map(\.text).joined(separator: " · ")
    }

    var body: some View {
        let line = Self.unlockLine(birds: rankUp.birds.map { BirdCatalog.bird($0).name },
                                   skies: rankUp.skies.map { SkyCatalog.sky($0).name },
                                   trails: rankUp.trailNames)
        let goals = Self.newGoalsLine(rank: rankUp.to)
        HStack(alignment: .top, spacing: compact ? 10 : 14) {
            Image(systemName: "bird.fill")
                .font(.system(size: compact ? 18 : 24, weight: .heavy))
                .foregroundStyle(SwoopTheme.ink)
                .frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                .background(Circle().fill(SwoopTheme.rewardGold))
            VStack(alignment: .leading, spacing: 3) {
                Text("Rank up! You're a \(GoalCatalog.rankTitle(rankUp.to))")
                    .font(SwoopType.headline(compact))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !line.isEmpty {
                    Text(line)
                        .font(SwoopType.body(compact))
                        .foregroundStyle(SwoopTheme.goldLight)
                        .lineLimit(2)
                }
                if !goals.isEmpty {
                    Text(goals)
                        .font(SwoopType.caption(compact))
                        .foregroundStyle(SwoopTheme.mist)
                        .lineLimit(3)
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
