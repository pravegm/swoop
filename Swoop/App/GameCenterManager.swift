import Foundation
import GameKit
import UIKit

/// Thin, polite Game Center wrapper (ported from Brim). Authentication is quiet: a sign-in view controller handed to
/// us is never presented. Scores and achievements earned while signed out are queued in UserDefaults and sent once a
/// player is authenticated; every failure is silent and nothing ever blocks play. The access point stays off (it would
/// sit over the flight). Skipped entirely in demo runs (`-swoopDemo`).
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    enum Leaderboard {
        /// Longest flight, in metres (classic, all-time).
        static let longest = "swoop.longest"
        /// The Daily Flight, in metres: a recurring leaderboard that resets every day.
        static let daily = "swoop.daily"
    }

    static let achievementIDs: [String] = ProgressRules.allAchievements

    private(set) var isAuthenticated = false
    private var started = false
    private var disabled = false
    private let reportedKey = "swoop.gc.reported"
    private let pendingKey = "swoop.gc.pending"
    private let pendingScoresKey = "swoop.gc.pendingScores"
    /// Scores submitted and not yet confirmed (by entry), so a second flush doesn't send them twice.
    private var inFlight: Set<String> = []

    private init() {}

    /// Called once at launch.
    func authenticate() {
        guard !started else { return }
        started = true
        if ProcessInfo.processInfo.arguments.contains("-swoopDemo") {
            disabled = true
            return
        }
        GKAccessPoint.shared.isActive = false
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // The sign-in view controller (if any) is ignored on purpose: no surprise sheets over the game.
            Task { @MainActor in
                GameCenterManager.shared.authenticationChanged()
            }
        }
    }

    /// Home's Game Center button: the system dashboard (leaderboards, achievements). Quietly nothing when signed out.
    func showDashboard() {
        guard !disabled, GKLocalPlayer.local.isAuthenticated else { return }
        GKAccessPoint.shared.trigger(handler: {
            Task { @MainActor in GKAccessPoint.shared.isActive = false }
        })
    }

    /// After a run: leaderboard scores (metres) and every achievement the progress now holds.
    func report(result: RunResult, outcome: RecordOutcome, progress: ProgressData) {
        guard !disabled else { return }
        let meters = result.meters.isFinite ? Int(max(result.meters, 0)) : 0
        switch result.mode {
        case .flight:
            if meters > 0 { queueScore(meters, leaderboard: Leaderboard.longest, day: nil) }
        case let .daily(day, scored):
            if meters > 0 { queueScore(meters, leaderboard: Leaderboard.longest, day: nil) }
            if scored && outcome.dailyCounted { queueScore(meters, leaderboard: Leaderboard.daily, day: day) }
        case .attract:
            return
        }
        unlock(ProgressRules.earnedAchievements(progress, allBirdsRank: ProgressRules.allBirdsRankDefault()))
    }

    // MARK: - Queue entries (pure; tested)

    /// One queued score: `leaderboard|score|day|token` (day -1 = not a Daily).
    struct QueuedScore: Equatable {
        var leaderboard: String
        var score: Int
        var day: Int?
        var token: String
    }

    nonisolated static func encode(leaderboard: String, score: Int, day: Int?, token: String) -> String {
        "\(leaderboard)|\(score)|\(day ?? -1)|\(token)"
    }

    nonisolated static func parse(_ entry: String) -> QueuedScore? {
        let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, let value = Int(parts[1]) else { return nil }
        var day: Int?
        if parts.count >= 3, let d = Int(parts[2]), d >= 0 { day = d }
        let token = parts.count >= 4 ? parts[3] : entry
        return QueuedScore(leaderboard: parts[0], score: value, day: day, token: token)
    }

    /// A Daily score flushed after its day ended would land on the next day's leaderboard, so it is dropped.
    nonisolated static func isStale(_ score: QueuedScore, today: Int) -> Bool {
        guard score.leaderboard == Leaderboard.daily else { return false }
        guard let day = score.day else { return true }
        return day != today
    }

    /// What still has to be sent: earned now, known, not yet confirmed. Pure; tested.
    nonisolated static func pending(earned: Set<String>, reported: Set<String>) -> Set<String> {
        earned.subtracting(reported).filter { ProgressRules.allAchievements.contains($0) }
    }

    func unlock(_ ids: Set<String>) {
        guard !disabled else { return }
        let reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        let pending = Self.pending(earned: ids, reported: reported)
        UserDefaults.standard.set(Array(pending).sorted(), forKey: pendingKey)
        flush()
    }

    // MARK: - Internals

    private func authenticationChanged() {
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        GKAccessPoint.shared.isActive = false
        flush()
    }

    private func queueScore(_ score: Int, leaderboard: String, day: Int?) {
        var queue = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        queue.append(Self.encode(leaderboard: leaderboard, score: score, day: day, token: UUID().uuidString))
        UserDefaults.standard.set(Array(queue.suffix(20)), forKey: pendingScoresKey)
        flush()
    }

    private func flush() {
        guard isAuthenticated, !disabled else { return }

        // Entries leave the queue only when Game Center confirms them; stale Dailies and unreadable ones go first.
        let today = DailySeed.dayNumber(for: Date())
        let queued = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let kept = queued.filter { entry in
            guard let parsed = Self.parse(entry) else { return false }
            return !Self.isStale(parsed, today: today)
        }
        if kept.count != queued.count { UserDefaults.standard.set(kept, forKey: pendingScoresKey) }
        for entry in kept where !inFlight.contains(entry) {
            guard let parsed = Self.parse(entry) else { continue }
            inFlight.insert(entry)
            GKLeaderboard.submitScore(parsed.score, context: 0, player: GKLocalPlayer.local,
                                      leaderboardIDs: [parsed.leaderboard]) { error in
                let ok = error == nil
                Task { @MainActor in
                    GameCenterManager.shared.didSubmit(entry, ok: ok)
                }
            }
        }

        let ids = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        guard !ids.isEmpty else { return }
        let achievements: [GKAchievement] = ids.map { id in
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(achievements) { error in
            let ok = error == nil
            Task { @MainActor in
                GameCenterManager.shared.didReport(ids, ok: ok)
            }
        }
    }

    private func didSubmit(_ entry: String, ok: Bool) {
        inFlight.remove(entry)
        guard ok else { return }
        let queue = (UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []).filter { $0 != entry }
        UserDefaults.standard.set(queue, forKey: pendingScoresKey)
    }

    private func didReport(_ ids: [String], ok: Bool) {
        guard ok else { return }
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        reported.formUnion(ids)
        UserDefaults.standard.set(Array(reported).sorted(), forKey: reportedKey)
        let pending = (UserDefaults.standard.stringArray(forKey: pendingKey) ?? []).filter { !reported.contains($0) }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }
}
