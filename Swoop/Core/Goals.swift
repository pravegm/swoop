import Foundation

// MARK: - Flocks: 15 ranks (GAME-DESIGN §8)
//
// Round 2: 15 ranks, as in the design. Ranks are 0…14 ("Fledgling" … "Storm Rider"); the player starts at rank 0
// and every rank below the top has a flock of 3 goals (14 flocks, 42 goals). Completing a flock moves up one rank, and
// every rank from 1 to 14 unlocks something (`rewards(forRank:)`): a bird, a sky or a trail. The UI shows
// "RANK r + 1 OF maxRank + 1" = "of 15".
// Every goal is something the player can see happen (Round 2 dropped the m/s speed goals, REVIEW-1 P1-8).
// Paced against tools/balance-sim.js (Round 2 tuning): a first run flies ~3–5 km with ~2 Perfects; a casual run
// ~23 km, ~30 Perfects, a chain of ~11, ~8 Tailwinds and 3–4 lighthouses; an expert run ~80 km with chains of 30+ and
// a handful of cloud touches. Lighthouses stand at 4, 9, 15, 22, 30, 38, 46… km.

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
        [g("r3-perfects", .perfectsInRun, 8, "8 Perfects in one flight"),
         g("r3-tailwind", .tailwinds, 1, "Catch a Tailwind"),
         g("r3-total", .totalMeters, 30000, "Fly 30 km in total")],
        // 4 Swell Rider → Crest Hopper (Aurora trail)
        [g("r4-reach", .reachMeters, 8000, "Fly 8 km"),
         g("r4-chain", .chain, 4, "Chain 4 Perfects"),
         g("r4-clean", .cleanMeters, 4000, "Fly 4 km without a splash")],
        // 5 Crest Hopper → Gull Wing (Northern Lights)
        [g("r5-lighthouses", .lighthouses, 2, "Pass 2 lighthouses"),
         g("r5-perfects", .perfectsInRun, 15, "15 Perfects in one flight"),
         g("r5-tailwinds", .tailwinds, 2, "2 Tailwinds in one flight")],
        // 6 Gull Wing → Tern Turner (Swift)
        [g("r6-reach", .reachMeters, 15000, "Fly 15 km"),
         g("r6-chain", .chain, 6, "Chain 6 Perfects"),
         g("r6-total", .totalMeters, 100000, "Fly 100 km in total")],
        // 7 Tern Turner → Tailwinder (Ember trail)
        [g("r7-lighthouses", .lighthouses, 3, "Pass 3 lighthouses"),
         g("r7-clean", .cleanMeters, 8000, "Fly 8 km without a splash"),
         g("r7-daily", .dailyPlayed, 1, "Fly the Daily Flight again")],
        // 8 Tailwinder → Lantern Seeker (Monsoon)
        [g("r8-perfects", .perfectsInRun, 30, "30 Perfects in one flight"),
         g("r8-tailwinds", .tailwinds, 5, "5 Tailwinds in one flight"),
         g("r8-cloud", .cloudTouches, 1, "Touch a cloud")],
        // 9 Lantern Seeker → Cloud Brusher (Albatross)
        [g("r9-reach", .reachMeters, 25000, "Fly 25 km"),
         g("r9-chain", .chain, 10, "Chain 10 Perfects"),
         g("r9-total", .totalMeters, 250000, "Fly 250 km in total")],
        // 10 Cloud Brusher → Gale Glider (Storm Petrel)
        [g("r10-lighthouses", .lighthouses, 4, "Pass 4 lighthouses"),
         g("r10-clean", .cleanMeters, 15000, "Fly 15 km without a splash"),
         g("r10-tailwinds", .tailwinds, 10, "10 Tailwinds in one flight")],
        // 11 Gale Glider → Headland Hunter (Moonrise)
        [g("r11-perfects", .perfectsInRun, 60, "60 Perfects in one flight"),
         g("r11-clouds", .cloudTouches, 3, "Touch the clouds 3 times in one flight"),
         g("r11-chain", .chain, 15, "Chain 15 Perfects")],
        // 12 Headland Hunter → Sky Diver (Night Heron)
        [g("r12-reach", .reachMeters, 50000, "Fly 50 km"),
         g("r12-lighthouses", .lighthouses, 6, "Pass 6 lighthouses"),
         g("r12-total", .totalMeters, 600000, "Fly 600 km in total")],
        // 13 Sky Diver → Storm Rider (Golden Gannet, Storm Gold trail)
        [g("r13-reach", .reachMeters, 80000, "Fly 80 km"),
         g("r13-chain", .chain, 25, "Chain 25 Perfects"),
         g("r13-clouds", .cloudTouches, 6, "Touch the clouds 6 times in one flight")],
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
            var played: Bool = dailyPlayed
            if case .daily = run.mode { played = true }
            value = played ? goal.target : 0
        }
        if !(goal.target > 0) { return 1 }
        if !value.isFinite { return 0 }
        return min(max(value / goal.target, 0), 1)
    }
}
