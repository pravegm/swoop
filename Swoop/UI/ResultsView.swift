import SwiftUI

/// The results card on the far half (the calm bird stays visible, bobbing in the rain, on its own half): distance huge,
/// best, Perfects, longest chain, lighthouses, the near-miss hook, the three goals ticking up, the rank-up banner, then
/// Fly again / Home / Share. "Fly again" restarts in well under a second.
///
/// REVIEW-1 P0-6: on short cards (every iPhone in landscape, 667 × 375 up to Pro Max) the stat tiles fold into one
/// inline line and the buttons into one row, so the lighthouse line and the goals show without scrolling; the content
/// still scrolls if a rank-up banner needs the room, with Fly again pinned.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var goalsShown = false

    private var result: RunResult { summary.result }
    private var outcome: RecordOutcome { summary.outcome }

    /// Cards shorter than this use the compact layout.
    static let compactCardHeight: CGFloat = 480

    var body: some View {
        let card = ResultsLayout.card(info)
        let compact = card.height < Self.compactCardHeight
        ZStack(alignment: .topLeading) {
            VStack(spacing: compact ? 8 : 12) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: compact ? 8 : 14) {
                        header(compact: compact)
                        if compact { inlineStats } else { stats }
                        hookLines(compact: compact)
                        if let rankUp = outcome.rankUp {
                            RankUpBanner(rankUp: rankUp, compact: compact)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        if !outcome.goals.isEmpty { goals(compact: compact) }
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                buttons(compact: compact)
            }
            .swoopCard(padding: compact ? 14 : 20)
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

    /// "First flight!" on the very first run, "New best!" when a best was beaten (REVIEW-1 P2).
    private var chip: String? {
        if outcome.showsNewBest { return "New best!" }
        if outcome.isNewBest && outcome.previousBest <= 0 { return "First flight!" }
        return nil
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(summary.title.uppercased())
                .font(SwoopTheme.text(compact ? 12 : 13, .heavy))
                .kerning(1.2)
                .foregroundStyle(SwoopTheme.gold)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ShareText.km(result.meters))
                    .font(SwoopTheme.display(compact ? 44 : 70))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let chip {
                    SwoopPill(text: chip, fontSize: compact ? 13 : 15)
                }
            }
            Text(outcome.showsNewBest ? "Previous best \(ShareText.km(outcome.previousBest))"
                                      : "Best \(ShareText.km(outcome.best))")
                .font(SwoopTheme.text(compact ? 14 : 16, .bold))
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// The compact stat line: "23 Perfects · chain 4 · 2 lighthouses". Pure; tested.
    nonisolated static func inlineStatsText(perfects: Int, chain: Int, lighthouses: Int) -> String {
        let l = lighthouses == 1 ? "1 lighthouse" : "\(lighthouses) lighthouses"
        return "\(ShareText.perfects(perfects)) · chain \(chain) · \(l)"
    }

    private var inlineStats: some View {
        Text(Self.inlineStatsText(perfects: result.perfects, chain: result.bestChain, lighthouses: result.lighthouses))
            .font(SwoopTheme.text(16, .heavy))
            .foregroundStyle(SwoopTheme.foam)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat(value: "\(result.perfects)", label: result.perfects == 1 ? "Perfect" : "Perfects")
            stat(value: "\(result.bestChain)", label: "Longest chain")
            stat(value: "\(result.lighthouses)", label: result.lighthouses == 1 ? "Lighthouse" : "Lighthouses")
        }
    }

    /// "Past Halcyon Point" and the near-miss hook "0.6 km short of Saltlight" (REVIEW-1 P2: one more go).
    @ViewBuilder
    private func hookLines(compact: Bool) -> some View {
        let past = result.lastLighthouseName.trimmingCharacters(in: .whitespaces)
        let next = AppRules.nextLighthouseLine(meters: result.meters, lighthousesPassed: result.lighthouses,
                                               seed: result.seed)
        if !past.isEmpty || next != nil {
            HStack(spacing: 6) {
                LighthouseGlyph()
                    .fill(SwoopTheme.goldLight)
                    .frame(width: 12, height: 16)
                Text(Self.hookText(past: past, next: next))
                    .font(SwoopTheme.text(compact ? 13 : 14, .bold))
                    .foregroundStyle(SwoopTheme.goldLight)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.75)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "Past X · 0.6 km short of Y", either half alone, or "". Pure; tested.
    nonisolated static func hookText(past: String, next: String?) -> String {
        var parts: [String] = []
        if !past.isEmpty { parts.append("Past \(past)") }
        if let next { parts.append(next) }
        return parts.joined(separator: " · ")
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

    private func goals(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            Text("FLOCK GOALS")
                .font(SwoopTheme.text(compact ? 11 : 12, .heavy))
                .kerning(1)
                .foregroundStyle(SwoopTheme.mist)
            ForEach(outcome.goals) { row in
                GoalProgressRow(goal: row.goal, progress: goalsShown ? row.after : row.before,
                                done: goalsShown ? row.isMet : row.before >= 1, justMet: goalsShown && row.justMet,
                                compact: compact)
            }
        }
    }

    @ViewBuilder
    private func buttons(compact: Bool) -> some View {
        if compact {
            HStack(spacing: 8) {
                SwoopButton(kind: .primary, height: 56, action: { controller.flyAgain() }) {
                    Label("Fly again", systemImage: "arrow.clockwise")
                        .font(SwoopTheme.title(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .layoutPriority(1)
                SwoopButton(kind: .quiet, height: 56, action: { controller.goHome() }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .heavy))
                }
                .frame(width: 64)
                .accessibilityLabel("Home")
                ShareLink(item: summary.share) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .heavy))
                }
                .buttonStyle(SwoopButtonStyle(kind: .secondary, height: 56))
                .frame(width: 64)
                .accessibilityLabel("Share")
            }
        } else {
            VStack(spacing: 10) {
                SwoopButton(kind: .primary, height: 66, action: { controller.flyAgain() }) {
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
}

/// One goal: its text, a slate → gold bar and a check that pops when met.
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
                    .fill(done ? SwoopTheme.gold : SwoopTheme.abyss.opacity(0.6))
                    .overlay(Circle().stroke(SwoopTheme.gold.opacity(0.6), lineWidth: 1.5))
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
                    .font(SwoopTheme.text(compact ? 14 : 16, .bold))
                    .foregroundStyle(done ? SwoopTheme.goldLight : SwoopTheme.foam)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.75)
                SwoopProgressBar(value: progress, height: compact ? 6 : 8, done: done)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.text), \(done ? "done" : "\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")")
    }
}

/// "Rank up!" with the new title and what it unlocked (birds, skies, trails).
struct RankUpBanner: View {
    let rankUp: AppRankUp
    var compact: Bool = false

    /// "New: Tern, Rose Dusk" (empty when nothing unlocked). Pure; tested.
    nonisolated static func unlockLine(birds: [String], skies: [String], trails: [String] = []) -> String {
        let all = birds + skies + trails
        guard !all.isEmpty else { return "" }
        return "New: " + all.joined(separator: ", ")
    }

    var body: some View {
        let line = Self.unlockLine(birds: rankUp.birds.map { BirdCatalog.bird($0).name },
                                   skies: rankUp.skies.map { SkyCatalog.sky($0).name },
                                   trails: rankUp.trailNames)
        HStack(spacing: compact ? 10 : 14) {
            Image(systemName: "bird.fill")
                .font(.system(size: compact ? 18 : 26, weight: .heavy))
                .foregroundStyle(SwoopTheme.ink)
                .frame(width: compact ? 36 : 50, height: compact ? 36 : 50)
                .background(Circle().fill(SwoopTheme.gold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Rank up! You're a \(GoalCatalog.rankTitle(rankUp.to))")
                    .font(SwoopTheme.title(compact ? 16 : 19))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !line.isEmpty {
                    Text(line)
                        .font(SwoopTheme.text(compact ? 13 : 14, .bold))
                        .foregroundStyle(SwoopTheme.gold)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 14)
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
