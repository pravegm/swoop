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
    /// The grace bridged a missed day ("Calm sea: streak kept").
    var dailyGraceKept = false
    /// A star flock was finished past the top rank (its ★ count is `ProgressData.starFlocks`).
    var starEarned = false
    /// R6: this run reached a lighthouse the route had never reached ("New on your route").
    var newOnRoute = false
    /// R11 P1-10: how many lighthouses were new on the route ("2 new lighthouses").
    var newOnRouteCount = 0
    /// R8 P0-4: after a rank-up, the new rank's goals as this run leaves them (already-met ones ticked now).
    var nextGoals: [GoalRowOutcome] = []
    /// Lighthouses entered in the logbook for the first time by this run.
    var newLogbook: [String] = []
    /// Achievements this run earned for the first time.
    var newAchievements: [String] = []

    /// "New best!" only when an earlier best was beaten (never on the very first run).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
}

/// Everything the game remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly.
struct ProgressData: Codable, Equatable {
    /// v2 (R2): 15 ranks and new goal targets under reused ids, so v1 saves are migrated (QA-2 P2-1).
    static let currentVersion = 2

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
    /// R1/R2 flag (kept so old saves decode): true = the first-run hints were done. Migrated into `learnedHints`.
    var hintsLearned = false
    /// Hints retired by success (UX-A5): "fold", "open", "land", "storm".
    var learnedHints: Set<String> = []
    /// Home destinations opened at least once (the gold dot leaves): "daily", "goals", "birds".
    var seenDestinations: Set<String> = []
    /// Lighthouse names ever passed (the logbook, UX §4).
    var logbook: Set<String> = []
    /// The latest day a Daily was played (QA-2 P2-8: a clock set back never gives another scored try).
    var lastDailyDay = Int.min
    /// Results that showed "or fold and open" (UX-A3: the first 5).
    var foldToFlyShown = 0
    /// The long-flight line (UX §9): hinge seconds flown on `hingeDay`, and the day the line last showed.
    var hingeDay = Int.min
    var hingeSeconds: Double = 0
    var restLineDay = Int.min
    /// Star flocks finished past the top rank (UX §4: "Storm Rider ★2").
    var starFlocks = 0
    /// R5 P1-9 (Core `PlayerBests`): the best clean distance, cloud touches and speed in one flight.
    var bestCleanMeters: Double = 0
    var bestCloudTouchesInRun = 0
    var bestSpeed: Double = 0
    /// R6 (UX §1.4): Flight School.
    var flightSchool: FlightSchoolState = .notStarted
    /// R6 (UX U2): the most lighthouses passed in one run, in any mode: the route's progress.
    var routeReached = 0
    init() {}

    /// Tolerant: unknown or missing fields fall back to their defaults, never wiping the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        version = ProgressData.currentVersion
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
        learnedHints = (try? c.decodeIfPresent(Set<String>.self, forKey: .learnedHints)) ?? []
        seenDestinations = (try? c.decodeIfPresent(Set<String>.self, forKey: .seenDestinations)) ?? []
        logbook = (try? c.decodeIfPresent(Set<String>.self, forKey: .logbook)) ?? []
        lastDailyDay = (try? c.decodeIfPresent(Int.self, forKey: .lastDailyDay)) ?? Int.min
        foldToFlyShown = (try? c.decodeIfPresent(Int.self, forKey: .foldToFlyShown)) ?? 0
        hingeDay = (try? c.decodeIfPresent(Int.self, forKey: .hingeDay)) ?? Int.min
        hingeSeconds = (try? c.decodeIfPresent(Double.self, forKey: .hingeSeconds)) ?? 0
        restLineDay = (try? c.decodeIfPresent(Int.self, forKey: .restLineDay)) ?? Int.min
        starFlocks = max((try? c.decodeIfPresent(Int.self, forKey: .starFlocks)) ?? 0, 0)
        bestCleanMeters = (try? c.decodeIfPresent(Double.self, forKey: .bestCleanMeters)) ?? 0
        bestCloudTouchesInRun = (try? c.decodeIfPresent(Int.self, forKey: .bestCloudTouchesInRun)) ?? 0
        bestSpeed = (try? c.decodeIfPresent(Double.self, forKey: .bestSpeed)) ?? 0
        flightSchool = (try? c.decodeIfPresent(FlightSchoolState.self, forKey: .flightSchool)) ?? .notStarted
        if let reached = (try? c.decodeIfPresent(Int.self, forKey: .routeReached)) ?? nil {
            routeReached = max(reached, 0)
        } else {
            // U2 migration: the route from the best distance (lighthouses at or before it).
            routeReached = max(RouteRules.reached(within: bestMeters), bestLighthousesInRun)
        }
        ProgressRules.migrate(&self, fromVersion: storedVersion)
    }

    // MARK: Derived

    func dailyStreak(today: Int) -> Int { ProgressRules.streak(days: Set(daily.keys), today: today) }
    func hasLearned(_ hint: String) -> Bool { learnedHints.contains(hint) }
    func dailyRecord(day: Int) -> DailyRecord? { daily[day] }
    func goalProgress(for goal: Goal) -> Double { min(max(goalProgress[goal.id] ?? 0, 0), 1) }
    /// The player's bests as Core's `PlayerBests` (R5 P1-9).
    var bests: PlayerBests {
        PlayerBests(meters: bestMeters, perfectsInRun: bestPerfectsInRun, chain: bestChain,
                    lighthousesInRun: bestLighthousesInRun, tailwindsInRun: bestTailwindsInRun,
                    cloudTouchesInRun: bestCloudTouchesInRun, cleanMeters: bestCleanMeters, maxSpeed: bestSpeed,
                    lifetimeMeters: lifetimeMeters, dailyPlayed: !daily.isEmpty || !dailyAttempted.isEmpty)
    }

    /// The goals in play: the rank's three, or the current star flock past the top.
    var currentGoals: [Goal] { ProgressRules.currentGoals(rank: rank, starFlocks: starFlocks) }
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
    /// Brings an older save up to `ProgressData.currentVersion` (QA-2 P2-1). v1 → v2: the rank is clamped to the
    /// 15-rank ladder and goal progress is cleared (R2 reused goal ids with new targets); bests, Dailies and cosmetics
    /// stay. The old "hints learned" flag becomes the learned-hint set. Every version: the rank is clamped.
    static func migrate(_ data: inout ProgressData, fromVersion stored: Int, maxRank: Int = GoalCatalog.maxRank) {
        if stored < 2 {
            data.goalProgress = [:]
        }
        // R5 (Core changed some goal ids, e.g. r1's chain → r1-total): progress for ids that no longer exist goes.
        data.goalProgress = pruned(data.goalProgress, knownIDs: knownGoalIDs(maxRank: maxRank))
        if data.hintsLearned && data.learnedHints.isEmpty {
            data.learnedHints = [AppHint.fold.rawValue, AppHint.open.rawValue]
        }
        data.rank = min(max(data.rank, 0), max(maxRank, 0))
        data.version = ProgressData.currentVersion
    }

    /// The goals in play (Home's "1 of 3", the Flocks card): the rank's, or the star flock past the top. Tested.
    static func currentGoals(rank: Int, starFlocks: Int, maxRank: Int = GoalCatalog.maxRank) -> [Goal] {
        rank >= maxRank ? GoalCatalog.starGoals(n: max(starFlocks, 0)) : GoalCatalog.goals(forRank: rank)
    }

    /// Home's Goals line: "1 of 3 · Fledgling"; past the top "Storm Rider ★2" (no stars yet: "Storm Rider ★"). Tested.
    static func goalsLine(rank: Int, done: Int, total: Int, starFlocks: Int, maxRank: Int = GoalCatalog.maxRank)
        -> String {
        let title = GoalCatalog.rankTitle(rank)
        if rank >= maxRank { return starFlocks > 0 ? "\(title) ★\(starFlocks)" : "\(title) ★" }
        return "\(min(max(done, 0), total)) of \(total) · \(title)"
    }

    /// Every goal id the ladder uses (star flocks are matched by their "star" prefix).
    static func knownGoalIDs(maxRank: Int = GoalCatalog.maxRank) -> Set<String> {
        var ids = Set<String>()
        for r in 0..<max(maxRank, 0) { for g in GoalCatalog.goals(forRank: r) { ids.insert(g.id) } }
        return ids
    }

    /// Goal progress without the ids that are gone (and without NaN). Pure; tested.
    static func pruned(_ progress: [String: Double], knownIDs: Set<String>) -> [String: Double] {
        progress.filter { key, value in (knownIDs.contains(key) || key.hasPrefix("star")) && value.isFinite }
    }

    /// QA-2 P2-8: a scored Daily only on a day at or after the latest Daily played (a clock turned back can't replay a
    /// past sea as scored).
    static func dailyMayScore(day: Int, lastDailyDay: Int) -> Bool { day >= lastDailyDay }

    /// UX §9 fatigue: 20 minutes of hinge flying in a day.
    static let longFlightSeconds: Double = 20 * 60

    /// The streak with UX §4's grace: one missed day per rolling 7 doesn't break it ("Calm sea: streak kept").
    /// Counts back from today (or yesterday while today's isn't flown yet). FINAL-FIXES #14:
    /// - yesterday missed and today not flown yet: the streak is still alive (today's flight will bridge yesterday),
    ///   so it counts back from the day before yesterday with the grace already spent on yesterday;
    /// - `graceKept` is true only on the day the grace bridges: today is flown and the gap it bridged is yesterday
    ///   (it used to repeat on every Daily after any bridged gap).
    static func streakWithGrace(days: Set<Int>, today: Int) -> (streak: Int, graceKept: Bool) {
        var day: Int
        var lastGrace = Int.max
        if days.contains(today) {
            day = today
        } else if days.contains(today - 1) {
            day = today - 1
        } else if days.contains(today - 2) {
            day = today - 2
            lastGrace = today - 1
        } else {
            return (0, false)
        }
        var count = 0
        var bridged: Int?
        var steps = 0
        while steps < 4000 {
            steps += 1
            if days.contains(day) {
                count += 1
                day -= 1
                continue
            }
            // A single missing day, bridged only if the day before it was flown and no grace was used in the 7 days
            // after it.
            if count > 0 && days.contains(day - 1) && (lastGrace == Int.max || lastGrace - day >= 7) {
                if bridged == nil { bridged = day }
                lastGrace = day
                day -= 1
                continue
            }
            break
        }
        return (count, days.contains(today) && bridged == today - 1)
    }

    /// FINAL-FIXES #14: the longest run of consecutive Daily days with no gap at all (no grace): `swoop.ach.daily3`
    /// ("three days in a row") needs 3. Pure; tested.
    static func longestStrictStreak(days: Set<Int>) -> Int {
        var best = 0
        for start in days where start == Int.min || !days.contains(start - 1) {
            var n = 1
            var d = start
            while n < 4000 && d < Int.max && days.contains(d + 1) {
                n += 1
                d += 1
            }
            best = max(best, n)
        }
        return best
    }

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
        streakWithGrace(days: days, today: today).streak
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
        // FINAL-FIXES #14: three days in a row, strictly (a streak the grace bridged doesn't earn it).
        if data.bestDailyStreak >= 3 && longestStrictStreak(days: Set(data.daily.keys)) >= 3 {
            out.insert(achievementDaily3)
        }
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
                       },
                       stars: (Int) -> [Goal] = { GoalCatalog.starGoals(n: $0) }) -> RecordOutcome {
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
        data.bestCloudTouchesInRun = max(data.bestCloudTouchesInRun, result.cloudTouches)
        outcome.newOnRoute = result.lighthouses > data.routeReached
        outcome.newOnRouteCount = max(result.lighthouses - data.routeReached, 0)
        data.routeReached = max(data.routeReached, result.lighthouses)
        if result.longestCleanMeters.isFinite { data.bestCleanMeters = max(data.bestCleanMeters, result.longestCleanMeters) }
        if result.maxSpeed.isFinite { data.bestSpeed = max(data.bestSpeed, result.maxSpeed) }
        data.totalPerfects += max(result.perfects, 0)
        data.totalTailwinds += max(result.tailwinds, 0)
        data.totalLighthouses += max(result.lighthouses, 0)
        data.totalCloudTouches += max(result.cloudTouches, 0)

        // The Daily (only the day's scored try is filed)
        var dailyPlayed = false
        if case let .daily(day, scored) = result.mode {
            dailyPlayed = true
            data.lastDailyDay = max(data.lastDailyDay, day)
            if scored {
                data.daily[day] = DailyRecord(meters: meters, perfects: result.perfects, lighthouses: result.lighthouses,
                                              lastLighthouseName: result.lastLighthouseName, finished: true)
                data.dailyAttempted.insert(day)
                outcome.dailyCounted = true
            }
        }
        let streakInfo = Self.streakWithGrace(days: Set(data.daily.keys), today: today)
        let currentStreak = streakInfo.streak
        outcome.dailyStreak = currentStreak
        outcome.dailyGraceKept = outcome.dailyCounted && streakInfo.graceKept

        // The logbook: every lighthouse this run passed, by name.
        if result.lighthouses > 0 {
            for i in 0..<min(result.lighthouses, 200) {
                let name = Lighthouses.name(index: i, seed: result.seed)
                if !data.logbook.contains(name) {
                    data.logbook.insert(name)
                    outcome.newLogbook.append(name)
                }
            }
        }
        data.bestDailyStreak = max(data.bestDailyStreak, currentStreak)

        // Goals → rank up
        let rankBefore = data.rank
        let atTop = data.rank >= maxRank
        let active = atTop ? stars(data.starFlocks) : goals(data.rank)
        var rows: [GoalRowOutcome] = []
        for goal in active {
            let before = min(max(data.goalProgress[goal.id] ?? 0, 0), 1)
            var now = evaluate(goal, result, data.lifetimeMeters, dailyPlayed)
            if !now.isFinite { now = 0 }
            // R5 P1-9: a goal the player's bests already meet completes now (with its tick, Core's `isMet`), so a
            // strong player climbs instead of being handed "Fly 3 km" after 12 km; others start from the bests.
            now = max(now, bestProgress(goal, data: data))
            if GoalEvaluator.isMet(goal, bests: data.bests) { now = 1 }
            let after = max(before, min(max(now, 0), 1))
            data.goalProgress[goal.id] = after
            rows.append(GoalRowOutcome(goal: goal, before: before, after: after))
        }
        outcome.goals = rows
        if atTop && !rows.isEmpty && rows.allSatisfy({ $0.isMet }) {
            // A star flock: one more ★, and the next three goals.
            for row in rows { data.goalProgress.removeValue(forKey: row.goal.id) }
            data.starFlocks += 1
            outcome.starEarned = true
        } else if !rows.isEmpty && rows.allSatisfy({ $0.isMet }) {
            // R5 P1-9: then cascade through every flock the bests already meet (one banner, "+N ranks").
            var reached = min(rankBefore + 1, maxRank)
            let bests = data.bests
            while reached < maxRank {
                let next = goals(reached)
                if next.isEmpty || !next.allSatisfy({ GoalEvaluator.isMet($0, bests: bests) }) { break }
                for g in next { data.goalProgress.removeValue(forKey: g.id) }
                reached += 1
            }
            data.rank = reached
            // The finished rank's goal ids are done with; the next rank starts fresh.
            for row in rows { data.goalProgress.removeValue(forKey: row.goal.id) }
            // R8 P0-4: the rank the cascade stopped at starts from this run's bests, so a goal they already meet
            // ticks on this results screen ("Fly 3 km" is never handed out after 12.83 km).
            if data.rank < maxRank {
                outcome.nextGoals = goals(data.rank).map { g in
                    var p = bestProgress(g, data: data)
                    if GoalEvaluator.isMet(g, bests: bests) { p = 1 }
                    p = min(max(p.isFinite ? p : 0, 0), 1)
                    if p > 0 { data.goalProgress[g.id] = max(data.goalProgress[g.id] ?? 0, p) }
                    return GoalRowOutcome(goal: g, before: 0, after: p)
                }
            }
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

    /// A goal's progress from the player's stored bests (this run's are already in `data`): reach, Perfects, chain,
    /// lighthouses and Tailwinds in one flight, and the lifetime total. Kinds with no stored best read 0. Pure; tested.
    static func bestProgress(_ goal: Goal, data: ProgressData) -> Double {
        guard goal.target > 0 else { return 0 }
        let value: Double
        switch goal.kind {
        case .reachMeters: value = data.bestMeters
        case .perfectsInRun: value = Double(data.bestPerfectsInRun)
        case .chain: value = Double(data.bestChain)
        case .lighthouses: value = Double(data.bestLighthousesInRun)
        case .tailwinds: value = Double(data.bestTailwindsInRun)
        case .totalMeters: value = data.lifetimeMeters
        case .cleanMeters: value = data.bestCleanMeters
        case .cloudTouches: value = Double(data.bestCloudTouchesInRun)
        default: return 0
        }
        guard value.isFinite else { return 0 }
        return min(max(value / goal.target, 0), 1)
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

    /// Today's Daily would be scored: no try yet, and the clock isn't behind the latest Daily played (QA-2 P2-8).
    func dailyIsScorable(day: Int) -> Bool {
        !hasDailyAttempt(day: day) && ProgressRules.dailyMayScore(day: day, lastDailyDay: data.lastDailyDay)
    }

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
        guard !data.dailyAttempted.contains(day) || data.lastDailyDay < day else { return }
        data.dailyAttempted.insert(day)
        data.lastDailyDay = max(data.lastDailyDay, day)
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

    /// UX-A5: a hint retired by success ("fold", "open", "land", "storm").
    func learnHint(_ hint: String) {
        guard !data.learnedHints.contains(hint) else { return }
        data.learnedHints.insert(hint)
        save()
    }

    /// Home: a destination opened (its gold dot leaves).
    func markSeen(_ destination: String) {
        guard !data.seenDestinations.contains(destination) else { return }
        data.seenDestinations.insert(destination)
        save()
    }

    /// R6: Flight School done or skipped.
    func setFlightSchool(_ state: FlightSchoolState) {
        guard data.flightSchool != state else { return }
        data.flightSchool = state
        if state == .done {
            // U5: the school supersedes the fold / open hints.
            data.learnedHints.insert(AppHint.fold.rawValue)
            data.learnedHints.insert(AppHint.open.rawValue)
        }
        save()
    }

    func noteFoldToFlyShown() {
        data.foldToFlyShown += 1
        save()
    }

    /// Adds hinge flying time for the long-flight line; returns whether the line should show now (≥ 20 min today,
    /// once a day).
    func addHingeSeconds(_ seconds: Double, day: Int) -> Bool {
        guard seconds.isFinite, seconds > 0 else { return false }
        if data.hingeDay != day {
            data.hingeDay = day
            data.hingeSeconds = 0
        }
        data.hingeSeconds += seconds
        var show = false
        if data.hingeSeconds >= ProgressRules.longFlightSeconds && data.restLineDay != day {
            data.restLineDay = day
            show = true
        }
        save()
        return show
    }

    /// Settings › Reset progress: bests, ranks, goals, cosmetics and hints go; the Daily history stays (so a reset is
    /// never a free Daily retry).
    func resetProgress() {
        var fresh = ProgressData()
        fresh.daily = data.daily
        fresh.dailyAttempted = data.dailyAttempted
        fresh.lastDailyDay = data.lastDailyDay
        data = fresh
        save()
    }
}
