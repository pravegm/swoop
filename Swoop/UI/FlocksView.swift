import SwiftUI

/// Flocks (goals): the current rank and its three goals on the left page; the ladder of ranks and what each unlocks on
/// the right page.
struct FlocksView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    private var rank: Int { store.data.rank }
    private var goals: [Goal] { rank < GoalCatalog.maxRank ? GoalCatalog.goals(forRank: rank) : [] }

    var body: some View {
        SwoopPages(info: info, title: "Flocks", onBack: { controller.goHome() }) {
            leftPage
        } right: {
            ladder
        }
    }

    // MARK: Left: the current rank and its goals

    private var leftPage: some View {
        let done = goals.filter { store.data.goalProgress(for: $0) >= 1 }.count
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RANK \(rank + 1) OF \(GoalCatalog.maxRank + 1)")
                    .font(SwoopTheme.text(12, .heavy))
                    .kerning(1)
                    .foregroundStyle(SwoopTheme.gold)
                Text(GoalCatalog.rankTitle(rank))
                    .font(SwoopTheme.display(info.isCompact ? 30 : 38))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if goals.isEmpty {
                    Text("Every bird and every sky is yours. Fly for the leaderboards.")
                        .font(SwoopTheme.text(16, .bold))
                        .foregroundStyle(SwoopTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Complete all three goals to rank up · \(done) of \(goals.count) done")
                        .font(SwoopTheme.text(15, .bold))
                        .foregroundStyle(SwoopTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                    SwoopProgressBar(value: Double(done) / Double(max(goals.count, 1)), height: 10,
                                     done: done == goals.count)
                }
            }
            .swoopCard(padding: 18, radius: 22)
            if !goals.isEmpty {
                PageHeading(text: "Goals")
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(goals) { goal in
                        GoalProgressRow(goal: goal, progress: store.data.goalProgress(for: goal),
                                        done: store.data.goalProgress(for: goal) >= 1)
                    }
                }
                .swoopCard(padding: 18, radius: 22)
                if let next = nextUnlockText {
                    Text(next)
                        .font(SwoopTheme.text(14, .bold))
                        .foregroundStyle(SwoopTheme.goldLight)
                        .padding(.leading, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var nextUnlockText: String? {
        let opened = ProgressRules.unlocks(from: rank, to: rank + 1)
        let names = opened.birds.map { BirdCatalog.bird($0).name } + opened.skies.map { SkyCatalog.sky($0).name }
        guard !names.isEmpty else { return nil }
        return "Next rank unlocks " + names.joined(separator: " and ")
    }

    // MARK: Right: the ladder

    private var ladder: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeading(text: "The ladder")
            ForEach(0...max(GoalCatalog.maxRank, 0), id: \.self) { r in
                ladderRow(r)
            }
        }
    }

    private func ladderRow(_ r: Int) -> some View {
        let reached = r <= rank
        let current = r == rank
        let opened = ProgressRules.unlocks(from: r - 1, to: r)
        let names = opened.birds.map { BirdCatalog.bird($0).name } + opened.skies.map { SkyCatalog.sky($0).name }
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(reached ? SwoopTheme.gold : SwoopTheme.abyss.opacity(0.6))
                    .overlay(Circle().stroke(SwoopTheme.gold.opacity(reached ? 0 : 0.4), lineWidth: 1.5))
                if reached && !current {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(SwoopTheme.ink)
                } else {
                    Text("\(r + 1)")
                        .font(SwoopTheme.number(14))
                        .foregroundStyle(reached ? SwoopTheme.ink : SwoopTheme.mist)
                }
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(GoalCatalog.rankTitle(r))
                    .font(SwoopTheme.text(17, .heavy))
                    .foregroundStyle(reached ? SwoopTheme.foam : SwoopTheme.haze)
                    .lineLimit(1)
                Text(names.isEmpty ? (r == 0 ? "Gull · Golden Hour" : "A new title") : names.joined(separator: " · "))
                    .font(SwoopTheme.text(13, .bold))
                    .foregroundStyle(reached ? SwoopTheme.gold : SwoopTheme.haze)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if !reached && !names.isEmpty {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SwoopTheme.haze)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(current ? SwoopTheme.tide.opacity(0.7) : SwoopTheme.deep.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SwoopTheme.gold.opacity(current ? 0.8 : 0), lineWidth: 2))
        )
        .accessibilityElement(children: .combine)
    }
}
