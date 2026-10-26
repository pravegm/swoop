import Combine
import Foundation

// MARK: - Stored data (pure value types; tested in SwoopTests/AppTests.swift)

/// One scored Daily Flight (the day's one counted try).
struct DailyRecord: Codable, Equatable {
    var meters: Double
    var perfects: Int
    var lighthouses: Int
    var lastLighthouseName: String
    /// False when the try was left before the storm caught the bird (the distance so far was filed).
    var finished: Bool

    init(meters: Double, perfects: Int, lighthouses: Int, lastLighthouseName: String, finished: Bool) {
        self.meters = meters
        self.perfects = perfects
        self.lighthouses = lighthouses
        self.lastLighthouseName = lastLighthouseName
        self.finished = finished
    }

    /// Tolerant: a field added later never drops the Daily history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meters = (try? c.decodeIfPresent(Double.self, forKey: .meters)) ?? 0
        perfects = (try? c.decodeIfPresent(Int.self, forKey: .perfects)) ?? 0
        lighthouses = (try? c.decodeIfPresent(Int.self, forKey: .lighthouses)) ?? 0
        lastLighthouseName = (try? c.decodeIfPresent(String.self, forKey: .lastLighthouseName)) ?? ""
        finished = (try? c.decodeIfPresent(Bool.self, forKey: .finished)) ?? true
    }
}

/// One active goal on the results card: its progress before and after the run (0…1, ≥ 1 = met).
struct GoalRowOutcome: Equatable, Identifiable {
    var goal: Goal
    var before: Double
    var after: Double
    var id: String { goal.id }
    var isMet: Bool { after >= 1 }
    var justMet: Bool { before < 1 && after >= 1 }
}

/// Completing all three goals ranked the player up.
struct AppRankUp: Equatable {
    var from: Int
    var to: Int
    var birds: [BirdID]
    var skies: [SkyID]
    /// Trail colours opened (ids from Core's catalogue, ROUND-2 Core 4).
    var trails: [String] = []

    var trailNames: [String] { trails.map { ProgressRules.trailName($0) } }
}

/// What recording a finished run changed, for the results card.
struct RecordOutcome: Equatable {
    var isNewBest = false
    var previousBest: Double = 0
    var best: Double = 0
    var goals: [GoalRowOutcome] = []
    var rankUp: AppRankUp?
    /// Daily: this run is the day's one counted try.
    var dailyCounted = false
    var dailyStreak = 0
    /// Achievements this run earned for the first time.
    var newAchievements: [String] = []

    /// "New best!" only when an earlier best was beaten (never on the very first run).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
}

/// Everything the game remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly.
struct ProgressData: Codable, Equatable {
    static let currentVersion = 1

    var version = ProgressData.currentVersion
    var bestMeters: Double = 0
    var bestScore = 0
    var bestChain = 0
    var bestPerfectsInRun = 0
    var bestLighthousesInRun = 0
    var bestTailwindsInRun = 0
    /// The last lighthouse passed on the best run (the cover card, the share line of the best).
    var bestLastLighthouse = ""
    var lifetimeMeters: Double = 0
    var runs = 0
    var totalPerfects = 0
    var totalTailwinds = 0
    var totalLighthouses = 0
    var totalCloudTouches = 0
    /// Flocks rank (0 = Fledgling … `GoalCatalog.maxRank`).
    var rank = 0
    /// Progress (0…1) of the current rank's goals by goal id. Never goes down.
    var goalProgress: [String: Double] = [:]
    /// Scored Daily Flights by day number (`DailySeed.dayNumber(for:)`).
    var daily: [Int: DailyRecord] = [:]
    /// Days whose scored try has started (left early or not): the next try that day is practice.
    var dailyAttempted: Set<Int> = []
    var bestDailyStreak = 0
    var bird: BirdID = .gull
    var sky: SkyID = .goldenHour
    /// The chosen trail colour's id (Core's `TrailID` raw value); "" or "natural" = the bird's own trail.
    var trail = ""
    /// The first-run hints ("Fold on the way down", "Open to fly") are learned after the first Perfect.
    var hintsLearned = false

    init() {}

    /// Tolerant: unknown or missing fields fall back to their defaults, never wiping the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? ProgressData.currentVersion
        bestMeters = (try? c.decodeIfPresent(Double.self, forKey: .bestMeters)) ?? 0
        bestScore = (try? c.decodeIfPresent(Int.self, forKey: .bestScore)) ?? 0
        bestChain = (try? c.decodeIfPresent(Int.self, forKey: .bestChain)) ?? 0
        bestPerfectsInRun = (try? c.decodeIfPresent(Int.self, forKey: .bestPerfectsInRun)) ?? 0
        bestLighthousesInRun = (try? c.decodeIfPresent(Int.self, forKey: .bestLighthousesInRun)) ?? 0
        bestTailwindsInRun = (try? c.decodeIfPresent(Int.self, forKey: .bestTailwindsInRun)) ?? 0
        bestLastLighthouse = (try? c.decodeIfPresent(String.self, forKey: .bestLastLighthouse)) ?? ""
        lifetimeMeters = (try? c.decodeIfPresent(Double.self, forKey: .lifetimeMeters)) ?? 0
        runs = (try? c.decodeIfPresent(Int.self, forKey: .runs)) ?? 0
        totalPerfects = (try? c.decodeIfPresent(Int.self, forKey: .totalPerfects)) ?? 0
        totalTailwinds = (try? c.decodeIfPresent(Int.self, forKey: .totalTailwinds)) ?? 0
        totalLighthouses = (try? c.decodeIfPresent(Int.self, forKey: .totalLighthouses)) ?? 0
        totalCloudTouches = (try? c.decodeIfPresent(Int.self, forKey: .totalCloudTouches)) ?? 0
        rank = max((try? c.decodeIfPresent(Int.self, forKey: .rank)) ?? 0, 0)
        goalProgress = (try? c.decodeIfPresent([String: Double].self, forKey: .goalProgress)) ?? [:]
        daily = (try? c.decodeIfPresent([Int: DailyRecord].self, forKey: .daily)) ?? [:]
        dailyAttempted = (try? c.decodeIfPresent(Set<Int>.self, forKey: .dailyAttempted)) ?? []
        bestDailyStreak = (try? c.decodeIfPresent(Int.self, forKey: .bestDailyStreak)) ?? 0
        bird = (try? c.decodeIfPresent(BirdID.self, forKey: .bird)) ?? .gull
        sky = (try? c.decodeIfPresent(SkyID.self, forKey: .sky)) ?? .goldenHour
        trail = (try? c.decodeIfPresent(String.self, forKey: .trail)) ?? ""
        hintsLearned = (try? c.decodeIfPresent(Bool.self, forKey: .hintsLearned)) ?? false
    }

    // MARK: Derived

    func dailyStreak(today: Int) -> Int { ProgressRules.streak(days: Set(daily.keys), today: today) }
    func dailyRecord(day: Int) -> DailyRecord? { daily[day] }
    func goalProgress(for goal: Goal) -> Double { min(max(goalProgress[goal.id] ?? 0, 0), 1) }
}

// MARK: - Trail colours (rank rewards, ROUND-2)

/// A trail colour the player can pick (the App's view of Core's trail catalogue).
struct AppTrail: Equatable {
    var id: String
    var name: String
    /// nil = the bird's own trail colour (Core's `Natural`).
    var color: RGBA?
    var unlockRank: Int
}

extension ProgressRules {
    /// Every trail colour, rank order. The ONLY place that reads Core's trail catalogue (design/NEEDS.md).
    static func trailOptions() -> [AppTrail] {
        TrailCatalog.all.map { AppTrail(id: $0.id.rawValue, name: $0.name, color: $0.color, unlockRank: $0.unlockRank) }
    }

    /// Trail ids whose unlock rank is in (from, to].
    static func trailUnlocks(from: Int, to: Int) -> [String] {
        trailOptions().filter { $0.unlockRank > from && $0.unlockRank <= to }.map { $0.id }
    }

    static func trailName(_ id: String) -> String {
        trailOptions().first(where: { $0.id == id })?.name ?? id
    }
}

// MARK: - The rules (pure, tested)

enum ProgressRules {
    /// Every achievement id (Game Center, docs/appstore style `swoop.ach.*`).
    static let achievementFirstFlight = "swoop.ach.first"
    static let achievementKm1 = "swoop.ach.km1"
    static let achievementKm5 = "swoop.ach.km5"
    static let achievementKm10 = "swoop.ach.km10"
    static let achievementChain5 = "swoop.ach.chain5"
    static let achievementChain10 = "swoop.ach.chain10"
    static let achievementTailwind = "swoop.ach.tailwind"
    static let achievementLighthouse = "swoop.ach.lighthouse"
    static let achievementLighthouse3 = "swoop.ach.lighthouse3"
    static let achievementCloud = "swoop.ach.cloud"
    static let achievementDaily3 = "swoop.ach.daily3"
    static let achievementAllBirds = "swoop.ach.allbirds"

    static let allAchievements: [String] = [
        achievementFirstFlight, achievementKm1, achievementKm5, achievementKm10, achievementChain5, achievementChain10,
        achievementTailwind, achievementLighthouse, achievementLighthouse3, achievementCloud, achievementDaily3,
        achievementAllBirds,
    ]

    /// Consecutive days with a scored Daily ending today, or yesterday when today's isn't flown yet (still alive).
    static func streak(days: Set<Int>, today: Int) -> Int {
        var day = days.contains(today) ? today : today - 1
        var count = 0
        while days.contains(day) {
            count += 1
            day -= 1
        }
        return count
    }

    /// The achievements `data` holds. `allBirdsRank` = the rank that unlocks the last bird.
    static func earnedAchievements(_ data: ProgressData, allBirdsRank: Int) -> Set<String> {
        var out = Set<String>()
        if data.runs > 0 { out.insert(achievementFirstFlight) }
        if data.bestMeters >= 1000 { out.insert(achievementKm1) }
        if data.bestMeters >= 5000 { out.insert(achievementKm5) }
        if data.bestMeters >= 10000 { out.insert(achievementKm10) }
        if data.bestChain >= 5 { out.insert(achievementChain5) }
        if data.bestChain >= 10 { out.insert(achievementChain10) }
        if data.totalTailwinds > 0 { out.insert(achievementTailwind) }
        if data.bestLighthousesInRun >= 1 { out.insert(achievementLighthouse) }
        if data.bestLighthousesInRun >= 3 { out.insert(achievementLighthouse3) }
        if data.totalCloudTouches > 0 { out.insert(achievementCloud) }
        if data.bestDailyStreak >= 3 { out.insert(achievementDaily3) }
        if data.runs > 0 && data.rank >= allBirdsRank { out.insert(achievementAllBirds) }
        return out
    }

    /// Records a finished run into `data`: bests, lifetime numbers, the Daily, goal progress and at most one rank up.
    /// Goals and the evaluator are injectable so the flow is testable without Core's catalogue.
    static func record(_ result: RunResult, into data: inout ProgressData, today: Int,
                       goals: (Int) -> [Goal] = { GoalCatalog.goals(forRank: $0) },
                       maxRank: Int = GoalCatalog.maxRank,
                       evaluate: (Goal, RunResult, Double, Bool) -> Double = { goal, run, lifetime, daily in
                           GoalEvaluator.progress(goal, run: run, lifetimeMeters: lifetime, dailyPlayed: daily)
                       },
                       unlocks: (Int, Int) -> (birds: [BirdID], skies: [SkyID]) = { from, to in
                           ProgressRules.unlocks(from: from, to: to)
                       },
                       trailUnlocks: (Int, Int) -> [String] = { from, to in
                           ProgressRules.trailUnlocks(from: from, to: to)
                       }) -> RecordOutcome {
        var outcome = RecordOutcome()
        if case .attract = result.mode { return outcome }
        let meters = result.meters.isFinite ? max(result.meters, 0) : 0
        let earnedBefore = earnedAchievements(data, allBirdsRank: allBirdsRankDefault())

        // Bests and lifetime numbers
        outcome.previousBest = data.bestMeters
        data.runs += 1
        data.lifetimeMeters += meters
        if meters > data.bestMeters {
            outcome.isNewBest = true
            data.bestMeters = meters
            data.bestLastLighthouse = result.lastLighthouseName
        }
        outcome.best = data.bestMeters
        data.bestScore = max(data.bestScore, result.score)
        data.bestChain = max(data.bestChain, result.bestChain)
        data.bestPerfectsInRun = max(data.bestPerfectsInRun, result.perfects)
        data.bestLighthousesInRun = max(data.bestLighthousesInRun, result.lighthouses)
        data.bestTailwindsInRun = max(data.bestTailwindsInRun, result.tailwinds)
        data.totalPerfects += max(result.perfects, 0)
        data.totalTailwinds += max(result.tailwinds, 0)
        data.totalLighthouses += max(result.lighthouses, 0)
        data.totalCloudTouches += max(result.cloudTouches, 0)

        // The Daily (only the day's scored try is filed)
        var dailyPlayed = false
        if case let .daily(day, scored) = result.mode {
            dailyPlayed = true
            if scored {
                data.daily[day] = DailyRecord(meters: meters, perfects: result.perfects, lighthouses: result.lighthouses,
                                              lastLighthouseName: result.lastLighthouseName, finished: true)
                data.dailyAttempted.insert(day)
                outcome.dailyCounted = true
            }
        }
        let currentStreak = Self.streak(days: Set(data.daily.keys), today: today)
        outcome.dailyStreak = currentStreak
        data.bestDailyStreak = max(data.bestDailyStreak, currentStreak)

        // Goals → rank up
        let rankBefore = data.rank
        let active = data.rank < maxRank ? goals(data.rank) : []
        var rows: [GoalRowOutcome] = []
        for goal in active {
            let before = min(max(data.goalProgress[goal.id] ?? 0, 0), 1)
            var now = evaluate(goal, result, data.lifetimeMeters, dailyPlayed)
            if !now.isFinite { now = 0 }
            let after = max(before, min(max(now, 0), 1))
            data.goalProgress[goal.id] = after
            rows.append(GoalRowOutcome(goal: goal, before: before, after: after))
        }
        outcome.goals = rows
        if !rows.isEmpty && rows.allSatisfy({ $0.isMet }) {
            data.rank = min(rankBefore + 1, maxRank)
            // The finished rank's goal ids are done with; the next rank starts fresh.
            for row in rows { data.goalProgress.removeValue(forKey: row.goal.id) }
            let opened = unlocks(rankBefore, data.rank)
            outcome.rankUp = AppRankUp(from: rankBefore, to: data.rank, birds: opened.birds, skies: opened.skies,
                                       trails: trailUnlocks(rankBefore, data.rank))
        }

        let earnedAfter = earnedAchievements(data, allBirdsRank: allBirdsRankDefault())
        outcome.newAchievements = earnedAfter.subtracting(earnedBefore).sorted()
        return outcome
    }

    /// Birds and skies whose unlock rank is in (from, to].
    static func unlocks(from: Int, to: Int) -> (birds: [BirdID], skies: [SkyID]) {
        let birds = BirdCatalog.all.filter { $0.unlockRank > from && $0.unlockRank <= to }.map { $0.id }
        let skies = SkyCatalog.all.filter { $0.unlockRank > from && $0.unlockRank <= to }.map { $0.id }
        return (birds, skies)
    }

    /// Everything ranks (from, to] open, by name: birds, then skies, then trails (Flocks ladder, rank-up banner).
    static func unlockNames(from: Int, to: Int) -> [String] {
        let opened = unlocks(from: from, to: to)
        return opened.birds.map { BirdCatalog.bird($0).name } + opened.skies.map { SkyCatalog.sky($0).name }
            + trailUnlocks(from: from, to: to).map { trailName($0) }
    }

    /// A goal's progress as the Flocks screen shows it: the stored best, and lifetime goals read live from the
    /// lifetime metres (QA-1 P2-9: right after a rank-up they read 0 % until the next run). 0…1.
    static func liveProgress(_ goal: Goal, data: ProgressData) -> Double {
        let stored = data.goalProgress(for: goal)
        guard goal.kind == .totalMeters, goal.target > 0, data.lifetimeMeters.isFinite else { return stored }
        return max(stored, min(max(data.lifetimeMeters / goal.target, 0), 1))
    }

    /// The rank that unlocks the last bird (the "all birds" achievement).
    static func allBirdsRankDefault() -> Int {
        BirdCatalog.all.map { $0.unlockRank }.max() ?? 0
    }

    /// A scored Daily left before the storm caught the bird (or backgrounded mid-run, QA-1 P1-2): the distance so far
    /// is the day's score (no free retry). Filed again later in the same try, the larger distance wins; a finished
    /// record is never replaced by a partial.
    static func fileDailyPartial(into data: inout ProgressData, day: Int, meters: Double, perfects: Int,
                                 lighthouses: Int, lastLighthouseName: String, today: Int) {
        data.dailyAttempted.insert(day)
        let m = meters.isFinite ? max(meters, 0) : 0
        if let existing = data.daily[day] {
            if existing.finished || existing.meters >= m { return }
        }
        data.daily[day] = DailyRecord(meters: m, perfects: perfects, lighthouses: lighthouses,
                                      lastLighthouseName: lastLighthouseName, finished: false)
        data.bestDailyStreak = max(data.bestDailyStreak, Self.streak(days: Set(data.daily.keys), today: today))
    }
}

// MARK: - The store

/// Owns `ProgressData`, saves it as versioned JSON in UserDefaults. `init(inMemory:)` (demo runs) never writes.
@MainActor
final class ProgressStore: ObservableObject {
    static let key = "swoop.progress"

    @Published private(set) var data: ProgressData
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        if let raw = defaults?.data(forKey: Self.key) {
            if let decoded = Self.decode(raw) {
                data = decoded
            } else {
                // QA-1 P2-11: keep an unreadable save aside before anything overwrites it.
                defaults?.set(raw, forKey: Self.corruptKey)
                data = ProgressData()
            }
        } else {
            data = ProgressData()
        }
    }

    /// Where an unreadable save is copied before the first write (support can recover it).
    static let corruptKey = "swoop.progress.corrupt"

    init(inMemory data: ProgressData) {
        self.defaults = nil
        self.data = data
    }

    nonisolated static func encode(_ data: ProgressData) -> Data? {
        try? JSONEncoder().encode(data)
    }

    nonisolated static func decode(_ raw: Data) -> ProgressData? {
        try? JSONDecoder().decode(ProgressData.self, from: raw)
    }

    private func save() {
        guard let defaults, let raw = Self.encode(data) else { return }
        defaults.set(raw, forKey: Self.key)
    }

    // MARK: Reading

    var bestMeters: Double { data.bestMeters }
    var rank: Int { data.rank }

    func isUnlocked(_ bird: Bird) -> Bool { bird.unlockRank <= data.rank }
    func isUnlocked(_ sky: Sky) -> Bool { sky.unlockRank <= data.rank }

    /// The chosen bird while it's still unlocked (Reset progress can lock it again), else the gull.
    var activeBird: BirdID {
        BirdCatalog.bird(data.bird).unlockRank <= data.rank ? data.bird : .gull
    }

    /// The chosen trail while it's still unlocked; nil = the bird's own trail.
    var activeTrail: AppTrail? {
        guard !data.trail.isEmpty,
              let trail = ProgressRules.trailOptions().first(where: { $0.id == data.trail }),
              trail.unlockRank <= data.rank else { return nil }
        return trail
    }

    var activeSky: SkyID {
        SkyCatalog.sky(data.sky).unlockRank <= data.rank ? data.sky : .goldenHour
    }

    func hasDailyAttempt(day: Int) -> Bool { data.dailyAttempted.contains(day) || data.daily[day] != nil }

    // MARK: Writing

    func replace(with newData: ProgressData) {
        data = newData
        save()
    }

    @discardableResult
    func record(_ result: RunResult, today: Int) -> RecordOutcome {
        var copy = data
        let outcome = ProgressRules.record(result, into: &copy, today: today)
        data = copy
        save()
        return outcome
    }

    /// The scored Daily's drop happened: from now on the day's try is spent.
    func markDailyAttempt(day: Int) {
        guard !data.dailyAttempted.contains(day) else { return }
        data.dailyAttempted.insert(day)
        save()
    }

    func fileDailyPartial(day: Int, meters: Double, perfects: Int, lighthouses: Int, lastLighthouseName: String,
                          today: Int) {
        var copy = data
        ProgressRules.fileDailyPartial(into: &copy, day: day, meters: meters, perfects: perfects,
                                       lighthouses: lighthouses, lastLighthouseName: lastLighthouseName, today: today)
        data = copy
        save()
    }

    func selectBird(_ id: BirdID) {
        guard isUnlocked(BirdCatalog.bird(id)), data.bird != id else { return }
        data.bird = id
        save()
    }

    /// Picks a trail colour ("" = the bird's own). Locked ones are ignored.
    func selectTrail(_ id: String) {
        if !id.isEmpty {
            guard let trail = ProgressRules.trailOptions().first(where: { $0.id == id }),
                  trail.unlockRank <= data.rank else { return }
        }
        guard data.trail != id else { return }
        data.trail = id
        save()
    }

    func selectSky(_ id: SkyID) {
        guard isUnlocked(SkyCatalog.sky(id)), data.sky != id else { return }
        data.sky = id
        save()
    }

    func learnHints() {
        guard !data.hintsLearned else { return }
        data.hintsLearned = true
        save()
    }

    /// Settings › Reset progress: bests, ranks, goals, cosmetics and hints go; the Daily history stays (so a reset is
    /// never a free Daily retry).
    func resetProgress() {
        var fresh = ProgressData()
        fresh.daily = data.daily
        fresh.dailyAttempted = data.dailyAttempted
        data = fresh
        save()
    }
}
