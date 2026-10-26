import Foundation

// MARK: - Flocks: 15 ranks (GAME-DESIGN §8)
//
// Round 2: 15 ranks, as in the design. Ranks are 0…14 ("Fledgling" … "Storm Rider"); the player starts at rank 0
// and every rank below the top has a flock of 3 goals (14 flocks, 42 goals). Completing a flock moves up one rank, and
// every rank from 1 to 14 unlocks something (`rewards(forRank:)`): a bird, a sky or a trail. The UI shows
// "RANK r + 1 OF maxRank + 1" = "of 15".
// Every goal is something the player can see happen (Round 2 dropped the m/s speed goals, REVIEW-1 P1-8).
// Round 3 (UX-C4, UX-SPEC §4): r9 and r12 lifetime goals are 400 km and 1,000 km, and the ladder is re-paced with
// `tools/goal-cadence.js` (a player who is casual for 12 days at 5 runs a day, then half casual, half expert):
// Round 5 (ROUND-5 P1-9): goals the player's bests already meet complete at once (`GoalEvaluator.alreadyMet`), so a
// strong player climbs fast instead of being handed "Fly 3 km" after a 12 km flight. That needs a pace that bests
// can't skip, so every flock now carries a lifetime-distance goal (5 km … 3,600 km), and ranks 7, 10 and 13 each need
// a Daily flown at that rank (`dailyRunGoalIDs`). `tools/goal-cadence.js` (with auto-complete and cascading rank-ups):
// an expert from run 1 reaches the top at run ~59 (5 runs a day); the improving player reaches ranks 3/6/10/14 at
// runs 6/13/41/124 (UX targets 8/20/50/105: the top is ~4 days later than UX asked, the price of the expert floor).
// The one-flight goals sit at casual p75–p95 up to r9; r11–r13 need expert flying (clouds, chain 25, 105 Perfects).
// Past the top, `starGoals(n:)`. Lighthouses stand at 4, 9, 15, 22, 30, 38, 46… km.

public enum GoalCatalog {

    /// The top rank (Storm Rider). Ranks are 0…maxRank: 15 ranks.
    public static let maxRank: Int = 14

    /// Exactly 3 goals for rank 0…maxRank − 1; [] at maxRank and beyond.
    public static func goals(forRank rank: Int) -> [Goal] {
        if rank < 0 || rank >= ladder.count || rank >= maxRank { return [] }
        return ladder[rank]
    }

    /// "Fledgling" (rank 0) … "Storm Rider" (rank 14, the top).
    public static func rankTitle(_ rank: Int) -> String {
        let i: Int = min(max(rank, 0), titles.count - 1)
        return titles[i]
    }

    /// What reaching `rank` unlocks (birds, then skies, then trails). Empty for rank 0 (the starting kit) and beyond
    /// the top.
    public static func rewards(forRank rank: Int) -> [RankReward] {
        if rank <= 0 || rank > maxRank { return [] }
        var out: [RankReward] = []
        for b in BirdCatalog.all where b.unlockRank == rank { out.append(.bird(b.id)) }
        for s in SkyCatalog.all where s.unlockRank == rank { out.append(.sky(s.id)) }
        for t in TrailCatalog.all where t.unlockRank == rank { out.append(.trail(t.id)) }
        return out
    }

    /// Whether a goal counts within one flight or adds up over every flight (REVIEW-3 P0-1). Every goal's text
    /// says which: "… in one flight" or "… in total". The App can show "4 / 4 in total" or "best 3 of 4 in one flight".
    public static func scope(of goal: Goal) -> GoalScope {
        switch goal.kind {
        case .totalMeters, .dailyPlayed: return .total
        default: return .oneFlight
        }
    }

    /// Daily goals met only by flying a Daily while the goal is current (UX-C2): "Fly 1 more Daily Flight" at ranks 7,
    /// 10 and 13 is not met by a Daily flown long ago. Other `.dailyPlayed` goals (rank 2) accept any Daily ever played.
    public static let dailyRunGoalIDs: Set<String> = ["r7-daily", "r10-daily", "r13-daily"]

    // MARK: Star flocks (UX-SPEC §4): past the top, 3 rotating goals at 1.5 × the top flock's targets.

    /// The pool the star flocks rotate through: about 1.5 × the hardest one-flight targets of each kind (set in R4;
    /// R5's ladder keeps r13's 65 km, so the star reach is 98 km).
    static let starPool: [(kind: GoalKind, target: Double, text: String)] = [
        (kind: .reachMeters, target: 98000, text: "Fly 98 km in one flight"),
        (kind: .chain, target: 48, text: "Chain 48 Perfects in one flight"),
        (kind: .cloudTouches, target: 11, text: "Touch the clouds 11 times in one flight"),
        (kind: .perfectsInRun, target: 158, text: "158 Perfects in one flight"),
        (kind: .lighthouses, target: 14, text: "Pass 14 lighthouses in one flight"),
        (kind: .tailwinds, target: 30, text: "30 Tailwinds in one flight"),
        (kind: .cleanMeters, target: 14000, text: "Fly 14 km in one flight without a splash"),
    ]

    /// The n-th star flock (n = 0, 1, 2…; each one finished adds a ★ to the title): 3 goals rotating through
    /// `starPool`, with ids unique per n ("star3-chain"). Empty for n < 0.
    public static func starGoals(n: Int) -> [Goal] {
        if n < 0 { return [] }
        var out: [Goal] = []
        let count: Int = starPool.count
        var k: Int = 0
        while k < 3 {
            let item = starPool[(n * 3 + k) % count]
            out.append(Goal(id: "star\(n)-\(item.kind.rawValue)", kind: item.kind, target: item.target, text: item.text))
            k += 1
        }
        return out
    }

    static let titles: [String] = [
        "Fledgling", "Puddle Hopper", "Spray Chaser", "Wave Skimmer", "Swell Rider",
        "Crest Hopper", "Gull Wing", "Tern Turner", "Tailwinder", "Lantern Seeker",
        "Cloud Brusher", "Gale Glider", "Headland Hunter", "Sky Diver", "Storm Rider",
    ]

    private static func g(_ id: String, _ kind: GoalKind, _ target: Double, _ text: String) -> Goal {
        return Goal(id: id, kind: kind, target: target, text: text)
    }

    static let ladder: [[Goal]] = [
        // 0 Fledgling → Puddle Hopper (Tern)
        [g("r0-reach", .reachMeters, 1000, "Fly 1 km in one flight"),
         g("r0-perfect", .perfectsInRun, 1, "Land a Perfect in one flight"),
         g("r0-total", .totalMeters, 5000, "Fly 5 km in total")],
        // 1 Puddle Hopper → Spray Chaser (Coral trail)
        [g("r1-reach", .reachMeters, 3000, "Fly 3 km in one flight"),
         g("r1-perfects", .perfectsInRun, 3, "3 Perfects in one flight"),
         g("r1-total", .totalMeters, 15000, "Fly 15 km in total")],
        // 2 Spray Chaser → Wave Skimmer (Rose Dusk)
        [g("r2-lighthouse", .lighthouses, 1, "Reach the first lighthouse in one flight"),
         g("r2-daily", .dailyPlayed, 1, "Play 1 Daily Flight in total"),
         g("r2-total", .totalMeters, 40000, "Fly 40 km in total")],
        // 3 Wave Skimmer → Swell Rider (Puffin)
        [g("r3-perfects", .perfectsInRun, 12, "12 Perfects in one flight"),
         g("r3-tailwind", .tailwinds, 1, "Catch a Tailwind in one flight"),
         g("r3-total", .totalMeters, 80000, "Fly 80 km in total")],
        // 4 Swell Rider → Crest Hopper (Aurora trail)
        [g("r4-reach", .reachMeters, 18000, "Fly 18 km in one flight"),
         g("r4-chain", .chain, 10, "Chain 10 Perfects in one flight"),
         g("r4-total", .totalMeters, 130000, "Fly 130 km in total")],
        // 5 Crest Hopper → Gull Wing (Northern Lights)
        [g("r5-lighthouses", .lighthouses, 3, "Pass 3 lighthouses in one flight"),
         g("r5-perfects", .perfectsInRun, 25, "25 Perfects in one flight"),
         g("r5-total", .totalMeters, 200000, "Fly 200 km in total")],
        // 6 Gull Wing → Tern Turner (Swift)
        [g("r6-clean", .cleanMeters, 8000, "Fly 8 km in one flight without a splash"),
         g("r6-chain", .chain, 12, "Chain 12 Perfects in one flight"),
         g("r6-total", .totalMeters, 300000, "Fly 300 km in total")],
        // 7 Tern Turner → Tailwinder (Ember trail)
        [g("r7-reach", .reachMeters, 20000, "Fly 20 km in one flight"),
         g("r7-daily", .dailyPlayed, 1, "Fly 1 more Daily Flight in total"),
         g("r7-total", .totalMeters, 420000, "Fly 420 km in total")],
        // 8 Tailwinder → Lantern Seeker (Monsoon)
        [g("r8-perfects", .perfectsInRun, 27, "27 Perfects in one flight"),
         g("r8-tailwinds", .tailwinds, 7, "7 Tailwinds in one flight"),
         g("r8-total", .totalMeters, 560000, "Fly 560 km in total")],
        // 9 Lantern Seeker → Cloud Brusher (Albatross)
        [g("r9-reach", .reachMeters, 22000, "Fly 22 km in one flight"),
         g("r9-chain", .chain, 15, "Chain 15 Perfects in one flight"),
         g("r9-total", .totalMeters, 720000, "Fly 720 km in total")],
        // 10 Cloud Brusher → Gale Glider (Storm Petrel)
        [g("r10-cloud", .cloudTouches, 1, "Touch a cloud in one flight"),
         g("r10-daily", .dailyPlayed, 1, "Fly 1 more Daily Flight in total"),
         g("r10-total", .totalMeters, 900000, "Fly 900 km in total")],
        // 11 Gale Glider → Headland Hunter (Moonrise)
        [g("r11-clouds", .cloudTouches, 4, "Touch the clouds 4 times in one flight"),
         g("r11-chain", .chain, 25, "Chain 25 Perfects in one flight"),
         g("r11-total", .totalMeters, 1200000, "Fly 1,200 km in total")],
        // 12 Headland Hunter → Sky Diver (Night Heron)
        [g("r12-perfects", .perfectsInRun, 105, "105 Perfects in one flight"),
         g("r12-lighthouses", .lighthouses, 9, "Pass 9 lighthouses in one flight"),
         g("r12-total", .totalMeters, 2000000, "Fly 2,000 km in total")],
        // 13 Sky Diver → Storm Rider (Golden Gannet, Storm Gold trail)
        [g("r13-reach", .reachMeters, 65000, "Fly 65 km in one flight"),
         g("r13-daily", .dailyPlayed, 1, "Fly 1 more Daily Flight in total"),
         g("r13-total", .totalMeters, 3600000, "Fly 3,600 km in total")],
    ]
}

/// See `GoalCatalog.scope(of:)`.
public enum GoalScope: String, Sendable {
    case oneFlight, total
}

/// The player's bests and totals, for completing goals they have already met (ROUND-5 P1-9). One-flight fields are
/// the best single flight; `lifetimeMeters` and `dailyPlayed` are totals. ProgressStore can keep one of these (it is
/// Codable) or build it from its own fields; a field it doesn't track can stay 0 (that goal is then simply not
/// pre-completed).
public struct PlayerBests: Codable, Equatable, Sendable {
    public var meters: Double
    public var perfectsInRun: Int
    public var chain: Int
    public var lighthousesInRun: Int
    public var tailwindsInRun: Int
    public var cloudTouchesInRun: Int
    public var cleanMeters: Double
    public var maxSpeed: Double
    public var lifetimeMeters: Double
    public var dailyPlayed: Bool

    public init(meters: Double = 0, perfectsInRun: Int = 0, chain: Int = 0, lighthousesInRun: Int = 0,
                tailwindsInRun: Int = 0, cloudTouchesInRun: Int = 0, cleanMeters: Double = 0, maxSpeed: Double = 0,
                lifetimeMeters: Double = 0, dailyPlayed: Bool = false) {
        self.meters = meters; self.perfectsInRun = perfectsInRun; self.chain = chain
        self.lighthousesInRun = lighthousesInRun; self.tailwindsInRun = tailwindsInRun
        self.cloudTouchesInRun = cloudTouchesInRun; self.cleanMeters = cleanMeters; self.maxSpeed = maxSpeed
        self.lifetimeMeters = lifetimeMeters; self.dailyPlayed = dailyPlayed
    }

    /// These bests after one more flight: the maxima, the lifetime distance plus this run's, and Daily-played.
    public func merged(with run: RunResult) -> PlayerBests {
        var b: PlayerBests = self
        b.meters = max(b.meters, run.meters.isFinite ? run.meters : 0)
        b.perfectsInRun = max(b.perfectsInRun, run.perfects)
        b.chain = max(b.chain, run.bestChain)
        b.lighthousesInRun = max(b.lighthousesInRun, run.lighthouses)
        b.tailwindsInRun = max(b.tailwindsInRun, run.tailwinds)
        b.cloudTouchesInRun = max(b.cloudTouchesInRun, run.cloudTouches)
        b.cleanMeters = max(b.cleanMeters, run.longestCleanMeters.isFinite ? run.longestCleanMeters : 0)
        b.maxSpeed = max(b.maxSpeed, run.maxSpeed.isFinite ? run.maxSpeed : 0)
        b.lifetimeMeters += max(0, run.meters.isFinite ? run.meters : 0)
        if case .daily = run.mode { b.dailyPlayed = true }
        return b
    }
}

public enum GoalEvaluator {

    /// Whether `bests` already meet `goal` (ROUND-5 P1-9). One-flight goals by the best single flight, totals by the
    /// lifetime figures, rank 2's Daily by any Daily played. The "Fly 1 more Daily Flight" goals
    /// (`GoalCatalog.dailyRunGoalIDs`) are never met by bests: they need a Daily flown at that rank.
    public static func isMet(_ goal: Goal, bests: PlayerBests) -> Bool {
        if !(goal.target > 0) { return true }
        let value: Double
        switch goal.kind {
        case .reachMeters: value = bests.meters
        case .perfectsInRun: value = Double(bests.perfectsInRun)
        case .chain: value = Double(bests.chain)
        case .lighthouses: value = Double(bests.lighthousesInRun)
        case .cloudTouches: value = Double(bests.cloudTouchesInRun)
        case .cleanMeters: value = bests.cleanMeters
        case .tailwinds: value = Double(bests.tailwindsInRun)
        case .totalMeters: value = bests.lifetimeMeters
        case .speed: value = bests.maxSpeed
        case .dailyPlayed:
            if GoalCatalog.dailyRunGoalIDs.contains(goal.id) { return false }
            value = bests.dailyPlayed ? goal.target : 0
        }
        return value.isFinite && value >= goal.target
    }

    /// The goals in `goals` (in order) that `bests` already meet: tick them at once. Pure. To cascade after a
    /// rank-up, call it again with the next rank's goals: if all of them are met, that rank completes too.
    public static func alreadyMet(goals: [Goal], bests: PlayerBests) -> [Goal] {
        return goals.filter { (g: Goal) -> Bool in isMet(g, bests: bests) }
    }

    /// The rank a player with `bests` reaches from `rank` by completing every flock their bests already meet
    /// (ranks that need a fresh Daily stop the climb). Pure; at most `GoalCatalog.maxRank`.
    public static func cascadedRank(from rank: Int, bests: PlayerBests) -> Int {
        var r: Int = max(0, rank)
        while r < GoalCatalog.maxRank {
            let goals: [Goal] = GoalCatalog.goals(forRank: r)
            if goals.isEmpty || alreadyMet(goals: goals, bests: bests).count < goals.count { break }
            r += 1
        }
        return min(r, GoalCatalog.maxRank)
    }


    /// 0…1 progress of `goal` after `run` (lifetimeMeters includes this run). ≥ 1 means met.
    public static func progress(_ goal: Goal, run: RunResult, lifetimeMeters: Double, dailyPlayed: Bool) -> Double {
        let value: Double
        switch goal.kind {
        case .reachMeters: value = run.meters
        case .perfectsInRun: value = Double(run.perfects)
        case .chain: value = Double(run.bestChain)
        case .lighthouses: value = Double(run.lighthouses)
        case .cloudTouches: value = Double(run.cloudTouches)
        case .cleanMeters: value = run.longestCleanMeters
        case .tailwinds: value = Double(run.tailwinds)
        case .totalMeters: value = lifetimeMeters
        case .speed: value = run.maxSpeed
        case .dailyPlayed:
            // Rank 7's "Fly a Daily Flight" needs this run to be a Daily (UX-C2); the others accept any Daily played.
            var played: Bool = GoalCatalog.dailyRunGoalIDs.contains(goal.id) ? false : dailyPlayed
            if case .daily = run.mode { played = true }
            value = played ? goal.target : 0
        }
        if !(goal.target > 0) { return 1 }
        if !value.isFinite { return 0 }
        return min(max(value / goal.target, 0), 1)
    }
}
