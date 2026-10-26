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
// rank 1 at run 1, rank 3 at run 6, rank 6 at run 19, rank 10 at run 49, rank 14 at run 98 (targets 2/8/20/50/105).
// Mid-ladder goals sit at the casual p75–p95 (a casual run: ~20 km, ~28 Perfects, chain ~11, 7 Tailwinds, 3
// lighthouses, ~7 km clean, clouds rare); the top four need expert flying (clouds, chains of 30+, 75 km).
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

    /// Daily goals met only by flying a Daily while the goal is current (UX-C2): "Fly a Daily Flight" at rank 7 must
    /// not be met by a Daily flown long ago. Other `.dailyPlayed` goals (rank 2) accept any Daily ever played.
    public static let dailyRunGoalIDs: Set<String> = ["r7-daily"]

    // MARK: Star flocks (UX-SPEC §4): past the top, 3 rotating goals at 1.5 × the top flock's targets.

    /// The pool the star flocks rotate through: 1.5 × the top targets of each kind (r13's reach, chain and clouds;
    /// r12's Perfects and lighthouses; r11's Tailwinds; r7's clean 10 km).
    static let starPool: [(kind: GoalKind, target: Double, text: String)] = [
        (kind: .reachMeters, target: 112000, text: "Fly 112 km"),
        (kind: .chain, target: 57, text: "Chain 57 Perfects"),
        (kind: .cloudTouches, target: 14, text: "Touch the clouds 14 times in one flight"),
        (kind: .perfectsInRun, target: 195, text: "195 Perfects in one flight"),
        (kind: .lighthouses, target: 15, text: "Pass 15 lighthouses"),
        (kind: .tailwinds, target: 38, text: "38 Tailwinds in one flight"),
        (kind: .cleanMeters, target: 15000, text: "Fly 15 km without a splash"),
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
        [g("r0-reach", .reachMeters, 1000, "Fly 1 km"),
         g("r0-perfect", .perfectsInRun, 1, "Land a Perfect"),
         g("r0-total", .totalMeters, 5000, "Fly 5 km in total")],
        // 1 Puddle Hopper → Spray Chaser (Coral trail)
        [g("r1-reach", .reachMeters, 3000, "Fly 3 km"),
         g("r1-perfects", .perfectsInRun, 3, "3 Perfects in one flight"),
         g("r1-chain", .chain, 2, "Chain 2 Perfects")],
        // 2 Spray Chaser → Wave Skimmer (Rose Dusk)
        [g("r2-lighthouse", .lighthouses, 1, "Reach the first lighthouse"),
         g("r2-clean", .cleanMeters, 2000, "Fly 2 km without a splash"),
         g("r2-daily", .dailyPlayed, 1, "Play the Daily Flight")],
        // 3 Wave Skimmer → Swell Rider (Puffin)
        [g("r3-perfects", .perfectsInRun, 15, "15 Perfects in one flight"),
         g("r3-tailwind", .tailwinds, 1, "Catch a Tailwind"),
         g("r3-total", .totalMeters, 150000, "Fly 150 km in total")],
        // 4 Swell Rider → Crest Hopper (Aurora trail)
        [g("r4-reach", .reachMeters, 20000, "Fly 20 km"),
         g("r4-chain", .chain, 12, "Chain 12 Perfects"),
         g("r4-clean", .cleanMeters, 8000, "Fly 8 km without a splash")],
        // 5 Crest Hopper → Gull Wing (Northern Lights)
        [g("r5-lighthouses", .lighthouses, 4, "Pass 4 lighthouses"),
         g("r5-perfects", .perfectsInRun, 32, "32 Perfects in one flight"),
         g("r5-tailwinds", .tailwinds, 8, "8 Tailwinds in one flight")],
        // 6 Gull Wing → Tern Turner (Swift)
        [g("r6-clean", .cleanMeters, 9000, "Fly 9 km without a splash"),
         g("r6-chain", .chain, 15, "Chain 15 Perfects"),
         g("r6-total", .totalMeters, 250000, "Fly 250 km in total")],
        // 7 Tern Turner → Tailwinder (Ember trail)
        [g("r7-reach", .reachMeters, 23000, "Fly 23 km"),
         g("r7-clean", .cleanMeters, 10000, "Fly 10 km without a splash"),
         g("r7-daily", .dailyPlayed, 1, "Fly a Daily Flight")],
        // 8 Tailwinder → Lantern Seeker (Monsoon)
        [g("r8-perfects", .perfectsInRun, 34, "34 Perfects in one flight"),
         g("r8-tailwinds", .tailwinds, 9, "9 Tailwinds in one flight"),
         g("r8-chain", .chain, 16, "Chain 16 Perfects")],
        // 9 Lantern Seeker → Cloud Brusher (Albatross)
        [g("r9-reach", .reachMeters, 25000, "Fly 25 km"),
         g("r9-chain", .chain, 17, "Chain 17 Perfects"),
         g("r9-total", .totalMeters, 400000, "Fly 400 km in total")],
        // 10 Cloud Brusher → Gale Glider (Storm Petrel)
        [g("r10-lighthouses", .lighthouses, 5, "Pass 5 lighthouses"),
         g("r10-cloud", .cloudTouches, 1, "Touch a cloud"),
         g("r10-tailwinds", .tailwinds, 10, "10 Tailwinds in one flight")],
        // 11 Gale Glider → Headland Hunter (Moonrise)
        [g("r11-clouds", .cloudTouches, 6, "Touch the clouds 6 times in one flight"),
         g("r11-chain", .chain, 30, "Chain 30 Perfects"),
         g("r11-tailwinds", .tailwinds, 25, "25 Tailwinds in one flight")],
        // 12 Headland Hunter → Sky Diver (Night Heron)
        [g("r12-perfects", .perfectsInRun, 130, "130 Perfects in one flight"),
         g("r12-lighthouses", .lighthouses, 10, "Pass 10 lighthouses"),
         g("r12-total", .totalMeters, 1000000, "Fly 1,000 km in total")],
        // 13 Sky Diver → Storm Rider (Golden Gannet, Storm Gold trail)
        [g("r13-reach", .reachMeters, 75000, "Fly 75 km"),
         g("r13-chain", .chain, 38, "Chain 38 Perfects"),
         g("r13-clouds", .cloudTouches, 9, "Touch the clouds 9 times in one flight")],
    ]
}

public enum GoalEvaluator {

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
