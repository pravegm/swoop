import SwiftUI

/// Goals (the Flocks ladder, UX §3 "Goals", ART A6): left page "RANK 2 OF 15" / "Puddle Hopper" / "2 of 3 done", the goals
/// card and "Next rank: Tern"; right page the ladder scrolled to the current rank, then "Logbook 12 of 40". Past the top
/// the star flocks rotate. Gold only for what is done and for the current rank; overlines in `mist`.
struct FlocksView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    private var rank: Int { store.data.rank }
    private var maxed: Bool { rank >= GoalCatalog.maxRank }
    private var goals: [Goal] { store.data.currentGoals }
    private var c: Bool { info.isCompact }

    var body: some View {
        SwoopPages(info: info, title: "Goals", onBack: { controller.goHome() }, scrollRightTo: rank) {
            leftPage
        } right: {
            rightPage
        }
    }

    // MARK: Left: the current rank and its goals

    /// "RANK 2 OF 15". Pure; tested.
    nonisolated static func rankLine(rank: Int, maxRank: Int = GoalCatalog.maxRank) -> String {
        "Rank \(min(max(rank, 0), maxRank) + 1) of \(maxRank + 1)"
    }

    /// "Next rank: Tern" (what the next rank opens, else its title); nil at the top. Pure; tested.
    nonisolated static func nextRankLine(rank: Int, unlocks: [String], maxRank: Int = GoalCatalog.maxRank) -> String? {
        guard rank < maxRank else { return nil }
        if unlocks.isEmpty { return "Next rank: \(GoalCatalog.rankTitle(rank + 1))" }
        return "Next rank: " + unlocks.joined(separator: " · ")
    }

    private var leftPage: some View {
        let done = goals.filter { ProgressRules.liveProgress($0, data: store.data) >= 1 }.count
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SwoopOverline(text: Self.rankLine(rank: rank), compact: c)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(GoalCatalog.rankTitle(rank))
                        .font(SwoopType.title(c))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if maxed && store.data.starFlocks > 0 {
                        Text("★\(store.data.starFlocks)")
                            .font(SwoopType.headline(c))
                            .foregroundStyle(SwoopTheme.rewardGold)
                    }
                }
                if maxed {
                    Text("Every bird, sky and trail is yours.")
                        .font(SwoopType.body(c))
                        .foregroundStyle(SwoopTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !goals.isEmpty {
                    Text("\(done) of \(goals.count) done")
                        .font(SwoopType.body(c))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                    SwoopProgressBar(value: Double(done) / Double(max(goals.count, 1)), height: 8,
                                     done: done == goals.count)
                }
            }
            .swoopCard(padding: 18, radius: SwoopTheme.cardRadius(c))
            if !goals.isEmpty {
                PageHeading(text: maxed ? "Star flock" : "Goals", compact: c)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(goals) { goal in
                        // QA-1 P2-9: lifetime goals read live from the lifetime metres.
                        let p = ProgressRules.liveProgress(goal, data: store.data)
                        GoalProgressRow(goal: goal, progress: p, done: p >= 1, compact: c)
                    }
                }
                .swoopCard(padding: 18, radius: SwoopTheme.cardRadius(c))
                if let next = Self.nextRankLine(rank: rank,
                                                unlocks: ProgressRules.unlockNames(from: rank, to: rank + 1)) {
                    Text(next)
                        .font(SwoopType.body(c))
                        .foregroundStyle(SwoopTheme.mist)
                        .padding(.leading, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Right: the ladder, then the logbook

    private var rightPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeading(text: "The ladder", compact: c)
            ForEach(0...max(GoalCatalog.maxRank, 0), id: \.self) { r in
                ladderRow(r)
                    .id(r)
            }
            logbook
                .padding(.top, 10)
        }
    }

    private func ladderRow(_ r: Int) -> some View {
        let reached = r < rank || (r == rank && maxed)
        let current = r == rank
        let names = ProgressRules.unlockNames(from: r - 1, to: r)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(reached ? SwoopTheme.rewardGold : (current ? SwoopTheme.gold : SwoopTheme.abyss.opacity(0.6)))
                    .overlay(Circle().stroke(SwoopTheme.stroke, lineWidth: reached || current ? 0 : 1))
                if reached {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(SwoopTheme.ink)
                } else {
                    Text("\(r + 1)")
                        .font(SwoopType.caption(true).weight(.heavy).monospacedDigit())
                        .foregroundStyle(current ? SwoopTheme.ink : SwoopTheme.mist)
                }
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(GoalCatalog.rankTitle(r))
                    .font(SwoopType.body(c).weight(.heavy))
                    .foregroundStyle(reached || current ? SwoopTheme.foam : SwoopTheme.haze)
                    .lineLimit(1)
                Text(names.isEmpty ? (r == 0 ? "Gull · Golden Hour" : "A new title") : names.joined(separator: " · "))
                    .font(SwoopType.caption(c))
                    .foregroundStyle(reached || current ? SwoopTheme.mist : SwoopTheme.haze)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if !reached && !current && !names.isEmpty {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SwoopTheme.haze)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
                .fill(current ? SwoopTheme.surfaceRaised : SwoopTheme.surface.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
                    .stroke(current ? SwoopTheme.gold.opacity(0.8) : SwoopTheme.stroke, lineWidth: current ? 2 : 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(current ? "Current rank" : (reached ? "Reached" : "Locked"))
    }

    /// "Logbook 12 of 40". Pure; tested.
    nonisolated static func logbookLine(count: Int, total: Int) -> String {
        "Logbook \(min(max(count, 0), total)) of \(total)"
    }

    private var logbook: some View {
        let all = Lighthouses.names
        let seen = all.filter { store.data.logbook.contains($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LighthouseGlyph()
                    .fill(SwoopTheme.foam)
                    .frame(width: 14, height: 20)
                Text(Self.logbookLine(count: seen.count, total: all.count))
                    .font(SwoopType.headline(c))
                    .foregroundStyle(SwoopTheme.foam)
            }
            Text(seen.isEmpty ? "Every lighthouse you pass is written here." : seen.joined(separator: " · "))
                .font(SwoopType.caption(c))
                .foregroundStyle(SwoopTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
        .swoopCard(padding: 16, radius: SwoopTheme.cardRadius(c))
        .accessibilityElement(children: .combine)
    }
}
