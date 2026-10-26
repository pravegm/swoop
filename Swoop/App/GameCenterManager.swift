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
        #if DEBUG
        // Demo runs (CI) never touch Game Center. DEBUG only, so Release carries no demo strings (QA-1 P2-13).
        if ProcessInfo.processInfo.arguments.contains("-swoopDemo") {
            disabled = true
            return
        }
        #endif
        GKAccessPoint.shared.isActive = false
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            // The sign-in view controller is kept, never shown by itself: no surprise sheets over the game. It is shown
            // only when the player taps the Game Center button (QA-1 P1-5).
            Task { @MainActor in
                GameCenterManager.shared.authenticationChanged(signIn: viewController)
            }
        }
    }

    /// What Home's Game Center button did.
    enum DashboardResult: Equatable {
        /// The dashboard (leaderboards, achievements) is up.
        case shown
        /// The system sign-in sheet is up (the player asked for it with the tap).
        case signingIn
        /// Signed out with no sign-in sheet to offer: Home shows "Sign in to Game Center in Settings".
        case signedOut
    }

    /// Home's Game Center button (QA-1 P1-5: it must never do nothing).
    func showDashboard() -> DashboardResult {
        if disabled { return .signedOut }
        if GKLocalPlayer.local.isAuthenticated {
            GKAccessPoint.shared.trigger(handler: {})
            return .shown
        }
        if let signIn = signInController, let top = Self.topViewController() {
            signInController = nil
            top.present(signIn, animated: true)
            return .signingIn
        }
        return .signedOut
    }

    /// The sign-in sheet iOS handed us (shown only on the player's tap).
    private var signInController: UIViewController?

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// A scored Daily left early (or the app backgrounded after the drop): its distance so far goes to the Daily board
    /// too (QA-1 P2-10). The board keeps the best, so a later finished run replaces it.
    func reportDailyPartial(meters: Double, day: Int, progress: ProgressData) {
        guard !disabled else { return }
        let m = meters.isFinite ? Int(max(meters, 0)) : 0
        guard m > 0 else { return }
        queueScore(m, leaderboard: Leaderboard.daily, day: day)
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

    private func authenticationChanged(signIn: UIViewController?) {
        if let signIn { signInController = signIn }
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        if isAuthenticated { signInController = nil }
        GKAccessPoint.shared.isActive = false
        flush()
    }

    private func queueScore(_ score: Int, leaderboard: String, day: Int?) {
        let queue = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let entry = Self.encode(leaderboard: leaderboard, score: score, day: day, token: UUID().uuidString)
        UserDefaults.standard.set(Self.enqueue(entry, into: queue), forKey: pendingScoresKey)
        flush()
    }

    /// QA-2 P2-4: one pending Daily entry per day (the larger wins, an in-flight one is kept), and the cap of 20 never
    /// evicts a `longest` best: the oldest Daily entries go first. Pure; tested.
    nonisolated static func enqueue(_ entry: String, into queue: [String], cap: Int = 20) -> [String] {
        guard let new = parse(entry) else { return queue }
        var out = queue
        if new.leaderboard == Leaderboard.daily {
            if let i = out.firstIndex(where: { e in
                guard let p = parse(e) else { return false }
                return p.leaderboard == Leaderboard.daily && p.day == new.day
            }) {
                if let old = parse(out[i]), old.score >= new.score { return out }
                out.remove(at: i)
            }
        }
        out.append(entry)
        while out.count > cap {
            if let i = out.firstIndex(where: { parse($0)?.leaderboard != Leaderboard.longest }) {
                out.remove(at: i)
            } else {
                out.removeFirst()
            }
        }
        return out
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
            // The day rides along as the score context (QA-1 P2-10), so a Daily score names its own sea.
            GKLeaderboard.submitScore(parsed.score, context: max(parsed.day ?? 0, 0), player: GKLocalPlayer.local,
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
