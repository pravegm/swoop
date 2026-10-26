import Foundation

// MARK: - Flocks: 15 ranks × 3 goals (GAME-DESIGN §8)
//
// Paced against the balance harness (tools/balance-sim.js): a first run flies ~2–4 km, a casual run ~10 km and 2
// lighthouses, an expert run ~45 km with Tailwinds and cloud touches. Lighthouses stand at 4, 9, 15, 22, 30, 38… km.
// Speed is shown to players in m/s (10 pt = 1 m), so 1800 pt/s reads "180 m/s".

public enum GoalCatalog {

    public static let maxRank: Int = 15

    /// Exactly 3 goals for rank 0…14; [] at maxRank and beyond.
    public static func goals(forRank rank: Int) -> [Goal] {
        if rank < 0 || rank >= ladder.count { return [] }
        return ladder[rank]
    }

    /// "Fledgling" (rank 0) … "Storm Rider" (rank 15, every flock done).
    public static func rankTitle(_ rank: Int) -> String {
        let i: Int = min(max(rank, 0), titles.count - 1)
        return titles[i]
    }

    static let titles: [String] = [
        "Fledgling", "Puddle Hopper", "Spray Chaser", "Wave Skimmer", "Swell Rider",
        "Crest Hopper", "Gull Wing", "Tern Turner", "Tailwinder", "Lantern Seeker",
        "Cloud Brusher", "Gale Glider", "Sea Swallow", "Headland Hunter", "Sky Diver",
        "Storm Rider",
    ]

    private static func g(_ id: String, _ kind: GoalKind, _ target: Double, _ text: String) -> Goal {
        return Goal(id: id, kind: kind, target: target, text: text)
    }

    static let ladder: [[Goal]] = [
        // 0 Fledgling
        [g("r0-reach", .reachMeters, 500, "Fly 500 m"),
         g("r0-perfect", .perfectsInRun, 1, "Land a Perfect"),
         g("r0-total", .totalMeters, 3000, "Fly 3 km in total")],
        // 1 Puddle Hopper
        [g("r1-reach", .reachMeters, 2000, "Fly 2 km"),
         g("r1-clean", .cleanMeters, 1000, "Fly 1 km without a splash"),
         g("r1-speed", .speed, 1800, "Reach 180 m/s")],
        // 2 Spray Chaser
        [g("r2-lighthouse", .lighthouses, 1, "Reach the first lighthouse"),
         g("r2-perfects", .perfectsInRun, 3, "3 Perfects in one flight"),
         g("r2-daily", .dailyPlayed, 1, "Play the Daily Flight")],
        // 3 Wave Skimmer
        [g("r3-reach", .reachMeters, 5000, "Fly 5 km"),
         g("r3-chain", .chain, 2, "Chain 2 Perfects"),
         g("r3-total", .totalMeters, 25000, "Fly 25 km in total")],
        // 4 Swell Rider
        [g("r4-tailwind", .tailwinds, 1, "Catch a Tailwind"),
         g("r4-clean", .cleanMeters, 3000, "Fly 3 km without a splash"),
         g("r4-perfects", .perfectsInRun, 8, "8 Perfects in one flight")],
        // 5 Crest Hopper
        [g("r5-reach", .reachMeters, 10000, "Fly 10 km"),
         g("r5-lighthouses", .lighthouses, 2, "Pass 2 lighthouses"),
         g("r5-speed", .speed, 2300, "Reach 230 m/s")],
        // 6 Gull Wing
        [g("r6-cloud", .cloudTouches, 1, "Touch a cloud"),
         g("r6-chain", .chain, 3, "Chain 3 Perfects"),
         g("r6-total", .totalMeters, 100000, "Fly 100 km in total")],
        // 7 Tern Turner
        [g("r7-reach", .reachMeters, 15000, "Fly 15 km"),
         g("r7-perfects", .perfectsInRun, 15, "15 Perfects in one flight"),
         g("r7-clean", .cleanMeters, 6000, "Fly 6 km without a splash")],
        // 8 Tailwinder
        [g("r8-lighthouses", .lighthouses, 3, "Pass 3 lighthouses"),
         g("r8-tailwinds", .tailwinds, 2, "2 Tailwinds in one flight"),
         g("r8-daily", .dailyPlayed, 1, "Fly the Daily Flight again")],
        // 9 Lantern Seeker
        [g("r9-reach", .reachMeters, 25000, "Fly 25 km"),
         g("r9-chain", .chain, 4, "Chain 4 Perfects"),
         g("r9-speed", .speed, 2600, "Reach top speed (260 m/s)")],
        // 10 Cloud Brusher
        [g("r10-clouds", .cloudTouches, 3, "Touch the clouds 3 times in one flight"),
         g("r10-perfects", .perfectsInRun, 30, "30 Perfects in one flight"),
         g("r10-total", .totalMeters, 300000, "Fly 300 km in total")],
        // 11 Gale Glider
        [g("r11-lighthouses", .lighthouses, 4, "Pass 4 lighthouses"),
         g("r11-tailwinds", .tailwinds, 4, "4 Tailwinds in one flight"),
         g("r11-clean", .cleanMeters, 12000, "Fly 12 km without a splash")],
        // 12 Sea Swallow
        [g("r12-reach", .reachMeters, 40000, "Fly 40 km"),
         g("r12-chain", .chain, 5, "Chain 5 Perfects"),
         g("r12-clouds", .cloudTouches, 6, "Touch the clouds 6 times in one flight")],
        // 13 Headland Hunter
        [g("r13-lighthouses", .lighthouses, 6, "Pass 6 lighthouses"),
         g("r13-perfects", .perfectsInRun, 60, "60 Perfects in one flight"),
         g("r13-total", .totalMeters, 1000000, "Fly 1,000 km in total")],
        // 14 Sky Diver
        [g("r14-reach", .reachMeters, 60000, "Fly 60 km"),
         g("r14-chain", .chain, 6, "Chain 6 Perfects"),
         g("r14-tailwinds", .tailwinds, 8, "8 Tailwinds in one flight")],
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
