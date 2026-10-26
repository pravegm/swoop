import SwiftUI

/// The results card on the far half (the calm bird stays visible, bobbing in the rain, on its own half): distance huge,
/// best, Perfects, longest chain, lighthouses, the three goals ticking up, the rank-up banner, then Fly again / Home /
/// Share. "Fly again" restarts in well under a second.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var goalsShown = false

    private var result: RunResult { summary.result }
    private var outcome: RecordOutcome { summary.outcome }

    var body: some View {
        let card = ResultsLayout.card(info)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 12) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        stats
                        if let rankUp = outcome.rankUp {
                            RankUpBanner(rankUp: rankUp)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        if !outcome.goals.isEmpty { goals }
                    }
                    .padding(.top, 4)
                }
                buttons
            }
            .swoopCard(padding: info.isCompact ? 16 : 20)
            .frame(width: card.width, height: card.height)
            .position(x: card.midX, y: card.midY)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : (info.mirrored ? -30 : 30))
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
        .onAppear {
            withAnimation(SwoopTheme.settle(reduceMotion)) { appeared = true }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.9).delay(0.35)) {
                goalsShown = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title.uppercased())
                .font(SwoopTheme.text(13, .heavy))
                .kerning(1.2)
                .foregroundStyle(SwoopTheme.gold)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ShareText.km(result.meters))
                    .font(SwoopTheme.display(info.isCompact ? 54 : 70))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if outcome.showsNewBest {
                    SwoopPill(text: "New best!", fontSize: 15)
                }
            }
            Text(outcome.showsNewBest ? "Previous best \(ShareText.km(outcome.previousBest))"
                                      : "Best \(ShareText.km(outcome.best))")
                .font(SwoopTheme.text(16, .bold))
                .foregroundStyle(SwoopTheme.mist)
        }
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat(value: "\(result.perfects)", label: result.perfects == 1 ? "Perfect" : "Perfects")
            stat(value: "\(result.bestChain)", label: "Longest chain")
            stat(value: "\(result.lighthouses)", label: result.lighthouses == 1 ? "Lighthouse" : "Lighthouses")
        }
        .padding(.bottom, result.lastLighthouseName.isEmpty ? 0 : 22)
        .overlay(alignment: .bottomLeading) {
            if !result.lastLighthouseName.isEmpty {
                HStack(spacing: 6) {
                    LighthouseGlyph()
                        .fill(SwoopTheme.goldLight)
                        .frame(width: 12, height: 16)
                    Text("Past \(result.lastLighthouseName)")
                        .font(SwoopTheme.text(14, .bold))
                        .foregroundStyle(SwoopTheme.goldLight)
                        .lineLimit(1)
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SwoopTheme.number(28))
                .foregroundStyle(SwoopTheme.foam)
            Text(label)
                .font(SwoopTheme.text(12, .bold))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SwoopTheme.sea.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FLOCK GOALS")
                .font(SwoopTheme.text(12, .heavy))
                .kerning(1)
                .foregroundStyle(SwoopTheme.mist)
            ForEach(outcome.goals) { row in
                GoalProgressRow(goal: row.goal, progress: goalsShown ? row.after : row.before,
                                done: goalsShown ? row.isMet : row.before >= 1, justMet: goalsShown && row.justMet)
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            SwoopButton(kind: .primary, height: info.isCompact ? 58 : 66, action: { controller.flyAgain() }) {
                Label("Fly again", systemImage: "arrow.clockwise")
                    .font(SwoopTheme.title(22))
            }
            HStack(spacing: 10) {
                SwoopButton(kind: .quiet, height: 56, action: { controller.goHome() }) {
                    Label("Home", systemImage: "house.fill")
                        .lineLimit(1)
                }
                ShareLink(item: summary.share) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .lineLimit(1)
                }
                .buttonStyle(SwoopButtonStyle(kind: .secondary, height: 56))
            }
        }
    }
}

/// One goal: its text, a slate → gold bar and a check that pops when met.
struct GoalProgressRow: View {
    let goal: Goal
    let progress: Double
    let done: Bool
    var justMet: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? SwoopTheme.gold : SwoopTheme.abyss.opacity(0.6))
                    .overlay(Circle().stroke(SwoopTheme.gold.opacity(0.6), lineWidth: 1.5))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(SwoopTheme.ink)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 30, height: 30)
            .scaleEffect(justMet ? 1.12 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.text)
                    .font(SwoopTheme.text(16, .bold))
                    .foregroundStyle(done ? SwoopTheme.goldLight : SwoopTheme.foam)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                SwoopProgressBar(value: progress, height: 8, done: done)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.text), \(done ? "done" : "\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")")
    }
}

/// "Rank up!" with the new title and what it unlocked.
struct RankUpBanner: View {
    let rankUp: AppRankUp

    /// "New: Tern, Rose Dusk" (empty when nothing unlocked). Pure; tested.
    nonisolated static func unlockLine(birds: [String], skies: [String]) -> String {
        let all = birds + skies
        guard !all.isEmpty else { return "" }
        return "New: " + all.joined(separator: ", ")
    }

    var body: some View {
        let line = Self.unlockLine(birds: rankUp.birds.map { BirdCatalog.bird($0).name },
                                   skies: rankUp.skies.map { SkyCatalog.sky($0).name })
        HStack(spacing: 14) {
            Image(systemName: "bird.fill")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(SwoopTheme.ink)
                .frame(width: 50, height: 50)
                .background(Circle().fill(SwoopTheme.gold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Rank up! You're a \(GoalCatalog.rankTitle(rankUp.to))")
                    .font(SwoopTheme.title(19))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !line.isEmpty {
                    Text(line)
                        .font(SwoopTheme.text(14, .bold))
                        .foregroundStyle(SwoopTheme.gold)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [SwoopTheme.tide, SwoopTheme.sea], startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SwoopTheme.gold.opacity(0.7), lineWidth: 2))
        )
        .accessibilityElement(children: .combine)
    }
}
