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
// Round 4 (re-paced after the tuck rise limit): rank 1 at run 1, rank 3 at run 6, rank 6 at run 18, rank 10 at run 46,
// rank 14 at run 86 (targets 2/8/20/50/105). Every goal text says "in one flight" or "in total" (`scope(of:)`).
// Mid-ladder goals sit at the casual p75–p95 (a casual run: ~18 km, ~22 Perfects, chain ~10, 5 Tailwinds, 3
// lighthouses, ~6.5 km clean, clouds rare); the top four need expert flying (clouds, chains of 25+, 65 km).
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

    /// Daily goals met only by flying a Daily while the goal is current (UX-C2): "Fly a Daily Flight" at rank 7 must
    /// not be met by a Daily flown long ago. Other `.dailyPlayed` goals (rank 2) accept any Daily ever played.
    public static let dailyRunGoalIDs: Set<String> = ["r7-daily"]

    // MARK: Star flocks (UX-SPEC §4): past the top, 3 rotating goals at 1.5 × the top flock's targets.

    /// The pool the star flocks rotate through: 1.5 × the top targets of each kind (r13's reach, chain and clouds;
    /// r12's Perfects and lighthouses; r11's Tailwinds; r7's clean 9 km).
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
         g("r1-chain", .chain, 2, "Chain 2 Perfects in one flight")],
        // 2 Spray Chaser → Wave Skimmer (Rose Dusk)
        [g("r2-lighthouse", .lighthouses, 1, "Reach the first lighthouse in one flight"),
         g("r2-clean", .cleanMeters, 2000, "Fly 2 km in one flight without a splash"),
         g("r2-daily", .dailyPlayed, 1, "Play 1 Daily Flight in total")],
        // 3 Wave Skimmer → Swell Rider (Puffin)
        [g("r3-perfects", .perfectsInRun, 12, "12 Perfects in one flight"),
         g("r3-tailwind", .tailwinds, 1, "Catch a Tailwind in one flight"),
         g("r3-total", .totalMeters, 150000, "Fly 150 km in total")],
        // 4 Swell Rider → Crest Hopper (Aurora trail)
        [g("r4-reach", .reachMeters, 18000, "Fly 18 km in one flight"),
         g("r4-chain", .chain, 10, "Chain 10 Perfects in one flight"),
         g("r4-clean", .cleanMeters, 7000, "Fly 7 km in one flight without a splash")],
        // 5 Crest Hopper → Gull Wing (Northern Lights)
        [g("r5-lighthouses", .lighthouses, 3, "Pass 3 lighthouses in one flight"),
         g("r5-perfects", .perfectsInRun, 25, "25 Perfects in one flight"),
         g("r5-tailwinds", .tailwinds, 6, "6 Tailwinds in one flight")],
        // 6 Gull Wing → Tern Turner (Swift)
        [g("r6-clean", .cleanMeters, 8000, "Fly 8 km in one flight without a splash"),
         g("r6-chain", .chain, 12, "Chain 12 Perfects in one flight"),
         g("r6-total", .totalMeters, 250000, "Fly 250 km in total")],
        // 7 Tern Turner → Tailwinder (Ember trail)
        [g("r7-reach", .reachMeters, 20000, "Fly 20 km in one flight"),
         g("r7-clean", .cleanMeters, 9000, "Fly 9 km in one flight without a splash"),
         g("r7-daily", .dailyPlayed, 1, "Fly 1 more Daily Flight in total")],
        // 8 Tailwinder → Lantern Seeker (Monsoon)
        [g("r8-perfects", .perfectsInRun, 27, "27 Perfects in one flight"),
         g("r8-tailwinds", .tailwinds, 7, "7 Tailwinds in one flight"),
         g("r8-chain", .chain, 14, "Chain 14 Perfects in one flight")],
        // 9 Lantern Seeker → Cloud Brusher (Albatross)
        [g("r9-reach", .reachMeters, 22000, "Fly 22 km in one flight"),
         g("r9-chain", .chain, 15, "Chain 15 Perfects in one flight"),
         g("r9-total", .totalMeters, 400000, "Fly 400 km in total")],
        // 10 Cloud Brusher → Gale Glider (Storm Petrel)
        [g("r10-lighthouses", .lighthouses, 4, "Pass 4 lighthouses in one flight"),
         g("r10-cloud", .cloudTouches, 1, "Touch a cloud in one flight"),
         g("r10-tailwinds", .tailwinds, 8, "8 Tailwinds in one flight")],
        // 11 Gale Glider → Headland Hunter (Moonrise)
        [g("r11-clouds", .cloudTouches, 4, "Touch the clouds 4 times in one flight"),
         g("r11-chain", .chain, 25, "Chain 25 Perfects in one flight"),
         g("r11-tailwinds", .tailwinds, 20, "20 Tailwinds in one flight")],
        // 12 Headland Hunter → Sky Diver (Night Heron)
        [g("r12-perfects", .perfectsInRun, 105, "105 Perfects in one flight"),
         g("r12-lighthouses", .lighthouses, 9, "Pass 9 lighthouses in one flight"),
         g("r12-total", .totalMeters, 1000000, "Fly 1,000 km in total")],
        // 13 Sky Diver → Storm Rider (Golden Gannet, Storm Gold trail)
        [g("r13-reach", .reachMeters, 65000, "Fly 65 km in one flight"),
         g("r13-chain", .chain, 32, "Chain 32 Perfects in one flight"),
         g("r13-clouds", .cloudTouches, 7, "Touch the clouds 7 times in one flight")],
    ]
}

/// See `GoalCatalog.scope(of:)`.
public enum GoalScope: String, Sendable {
    case oneFlight, total
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
