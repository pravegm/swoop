import Foundation

// MARK: - Lighthouses (GAME-DESIGN §6): the run's checkpoints and the share text.

public enum Lighthouses {

    /// Invented headland names (seeded order per sea).
    static let names: [String] = [
        "Gull Point", "Saltlight", "Kestrel Head", "Old Harry", "Wren Ness",
        "Lantern Rock", "Herring Bight", "Curlew Spit", "Sealfold", "Brightwater Head",
        "Tern Light", "Cormorant Stack", "Fulmar Ness", "Dunlin Point", "Shearwater Head",
        "Grey Mare", "Wicklight", "Merrow Point", "Stormhaven", "Skerry End",
        "Puffin Ledge", "Hollowcombe Head", "Amberlight", "Kittiwake Cliff", "Morrow's Tooth",
        "Sandpiper Ness", "Lowlight", "Gannet Rock", "Cinder Head", "Seawatch",
        "Foxglove Point", "Linnet Bluff", "Evenstar Head", "Rook's Lantern", "Halcyon Point",
        "Pennant Ness", "Whitethroat Head", "Selkie Rock", "Tidewell", "Farthing Light",
    ]

    /// Sea x of the n-th lighthouse (0-based): 4 km, then +5 km, +6 km… (gaps capped at +8 km).
    public static func x(index: Int) -> Double {
        let i: Int = max(0, index)
        var x: Double = Tuning.lighthouseFirstX
        var n: Int = 1
        while n <= i {
            x += min(Tuning.lighthouseMaxGap, Tuning.lighthouseFirstGap + Tuning.lighthouseGapGrowth * Double(n - 1))
            n += 1
        }
        return x
    }

    /// The n-th lighthouse's name for this sea. Every 40 lighthouses the list repeats in the same seeded order.
    public static func name(index: Int, seed: UInt64) -> String {
        let order: [Int] = permutation(seed: seed)
        let count: Int = names.count
        let i: Int = ((index % count) + count) % count
        return names[order[i]]
    }

    /// A seeded shuffle of 0..<names.count (Fisher–Yates).
    static func permutation(seed: UInt64) -> [Int] {
        var order: [Int] = Array(0..<names.count)
        var rng = SeededRandom(seed: seed ^ 0x11_6874_6F75_7365)
        var i: Int = order.count - 1
        while i > 0 {
            let j: Int = rng.int(i + 1)
            order.swapAt(i, j)
            i -= 1
        }
        return order
    }
}

// MARK: - Daily Flight seeds (GAME-DESIGN §8): the same sea for everyone, worldwide, each UTC day.

public enum DailySeed {

    /// Gregorian calendar in UTC, so the Daily Flight (and its Game Center board) is the same moment worldwide.
    public static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "UTC") {
            c.timeZone = tz
        } else if let tz = TimeZone(secondsFromGMT: 0) {
            c.timeZone = tz
        }
        return c
    }()

    /// Days since 2026-01-01 (day 0) in `calendar` (UTC by default). Negative before then.
    public static func dayNumber(for date: Date, calendar: Calendar = DailySeed.utc) -> Int {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        guard let epoch = calendar.date(from: comps) else { return 0 }
        let a: Date = calendar.startOfDay(for: epoch)
        let b: Date = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Launch day, 2026-11-24 (UTC): Daily Flight #1 (REVIEW-3, ROUND-4 #13). Day 327 since 2026-01-01.
    public static let launchDay: Int = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 24
        comps.hour = 12
        guard let d = utc.date(from: comps) else { return 327 }
        return dayNumber(for: d, calendar: utc)
    }()

    /// The number players see ("Daily Flight #12"): 1 on launch day, counting up, never below 1. The sea's seed
    /// still comes from `seed(day:)` with the raw day number, so nothing about today's sea changes.
    public static func displayNumber(day: Int) -> Int {
        return max(1, day - launchDay + 1)
    }

    /// The sea seed for a day number.
    public static func seed(day: Int) -> UInt64 {
        var rng = SeededRandom(seed: 0xDA11_F1E5_5EED_0000 ^ UInt64(bitPattern: Int64(day)))
        return rng.next()
    }
}
