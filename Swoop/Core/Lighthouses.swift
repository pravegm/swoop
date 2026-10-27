import Foundation

// MARK: - Lighthouses (GAME-DESIGN §6): the run's checkpoints and the share text.

public enum Lighthouses {

    /// Invented headland names, in route order (Round 6: fixed by index in every mode).
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

    /// The n-th lighthouse's name (0-based). Round 6 (UX U1): fixed by index in every mode, so each one is a place on the
    /// route: 0 Gull Point (4 km), 1 Saltlight (9 km), 2 Kestrel Head (15 km), 3 Old Harry (22 km)… The list repeats
    /// every 40.
    public static func name(index: Int) -> String {
        let count: Int = names.count
        let i: Int = ((index % count) + count) % count
        return names[i]
    }

    /// Kept for callers from before Round 6: the seed is ignored (names are fixed by index).
    public static func name(index: Int, seed: UInt64) -> String {
        return name(index: index)
    }

    /// How many lighthouses stand at or before sea x (pt): the route count for a flight that reached x (UX K3).
    public static func count(atOrBefore seaX: Double) -> Int {
        if !seaX.isFinite { return 0 }
        var n: Int = 0
        var lx: Double = Tuning.lighthouseFirstX
        while n < 100_000 && lx <= seaX {
            n += 1
            lx += min(Tuning.lighthouseMaxGap, Tuning.lighthouseFirstGap + Tuning.lighthouseGapGrowth * Double(n - 1))
        }
        return n
    }

    /// The same for a distance in metres (10 pt = 1 m), e.g. migrating `routeReached` from `bestMeters`.
    public static func count(atOrBeforeMeters meters: Double) -> Int {
        return count(atOrBefore: meters * Tuning.pointsPerMeter)
    }

    /// The index of the next lighthouse beyond a distance in metres ("Next: Saltlight · 9 km").
    public static func nextIndex(afterMeters meters: Double) -> Int {
        return count(atOrBeforeMeters: meters)
    }

    /// A lighthouse's distance in metres.
    public static func meters(index: Int) -> Double {
        return x(index: index) / Tuning.pointsPerMeter
    }

    /// The results headline's inputs (UX-ROUND-9 §2.2): the next lighthouse beyond a flight's distance and how far
    /// beyond it is, rounded up the way the copy reads it ("Kestrel Head is 2.2 km further", "Gull Point is 350 m
    /// further"). The lighthouses passed come from `RunResult.lighthouses` / `lastLighthouseName` (fixed names).
    public static func next(afterMeters meters: Double) -> (index: Int, name: String, metersFurther: Double) {
        let d: Double = meters.isFinite ? max(0, meters) : 0
        let i: Int = nextIndex(afterMeters: d)
        return (index: i, name: name(index: i), metersFurther: roundedFurther(meters: Lighthouses.meters(index: i) - d))
    }

    /// "Further" rounded UP: to 100 m (0.1 km) from 1 km, to 10 m below 1 km; never below 10 m.
    public static func roundedFurther(meters: Double) -> Double {
        if !(meters > 0) { return 10 }
        let step: Double = meters >= 1000 ? 100 : 10
        // A hair of tolerance so an exact 2.2 km doesn't round up to 2.3 km through float noise.
        return max(10, (meters / step - 1e-9).rounded(.up) * step)
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
