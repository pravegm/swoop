import Foundation

/// Share lines and number formats (results card, HUD, Home). Pure; tested.
/// Flight: `Swoop 7.4 km 🕊️ 23 Perfects · past Saltlight 🌅`
/// Daily:  `Swoop Daily #12 7.4 km 🕊️ 23 Perfects · past Saltlight 🌅 🔥3`
enum ShareText {
    /// 🕊️ (dove + variation selector), 🌅, 🔥 — spelled as scalars so the bytes never depend on an editor.
    static let dove = "\u{1F54A}\u{FE0F}"
    static let sunrise = "\u{1F305}"
    static let fire = "\u{1F525}"

    /// Kilometres with one decimal, rounded down (7,480 m → "7.4 km"), whatever the locale.
    static func km(_ meters: Double) -> String {
        let m = meters.isFinite ? max(meters, 0) : 0
        let tenths = Int((m / 100).rounded(.down))
        return "\(tenths / 10).\(tenths % 10) km"
    }

    /// Thousands with commas whatever the locale: 1234 → "1,234".
    static func grouped(_ value: Int) -> String {
        let digits = String(value.magnitude)
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return value < 0 ? "-" + out : out
    }

    /// Whole metres for the HUD: "1,234 m".
    static func meters(_ meters: Double) -> String {
        let m = meters.isFinite ? max(meters, 0) : 0
        return "\(grouped(Int(m.rounded(.down)))) m"
    }

    /// The HUD distance: whole metres below 1 km ("842" "m"), then kilometres with ONE decimal ("12.8" "km", R9 UX
    /// §4.2: the HUD ticks every 100 m), rounded down, whatever the locale. R11 P1-10: one format everywhere, so a
    /// whole kilometre drops its ".0" ("4 km", never "4.0 km").
    static func hudDistance(_ meters: Double) -> (value: String, unit: String) {
        let m = meters.isFinite ? max(meters, 0) : 0
        if m < 1000 { return (String(Int(m.rounded(.down))), "m") }
        let tenths = Int((m / 100).rounded(.down))
        if tenths % 10 == 0 { return (grouped(tenths / 10), "km") }
        return ("\(grouped(tenths / 10)).\(tenths % 10)", "km")
    }

    /// THE distance formatter for every on-screen distance (R9 UX §4.2): "850 m" under 1 km, then one decimal,
    /// "12.8 km". Distances flown round DOWN; `roundUp` (distances still to go: the chip, "further", "Best in") rounds
    /// UP, to 10 m under 1 km and to 0.1 km above ("2.17 km" → "2.2 km", 341 m → "350 m").
    static func distance(_ meters: Double, roundUp: Bool = false) -> String {
        var m = meters.isFinite ? max(meters, 0) : 0
        if roundUp {
            let up10 = (m / 10).rounded(.up) * 10
            m = up10 < 1000 ? up10 : (m / 100).rounded(.up) * 100
        }
        let d = hudDistance(m)
        return "\(d.value) \(d.unit)"
    }

    /// A goal target: "500 m", "3 km", "2.5 km" (whole kilometres drop the decimal).
    static func target(_ meters: Double) -> String {
        let m = meters.isFinite ? max(meters, 0) : 0
        if m >= 1000 && m.truncatingRemainder(dividingBy: 1000) == 0 { return "\(grouped(Int(m / 1000))) km" }
        return distance(m)
    }

    /// R9 glossary: the landing is "Perfect"; counted, "perfect landings".
    static func perfects(_ n: Int) -> String { n == 1 ? "1 perfect landing" : "\(n) perfect landings" }

    /// "6 h 12 m" / "12 m" (never "0 m": under a minute reads "1 m"), rounded up to the minute.
    static func nextIn(seconds: Double) -> String {
        let s = seconds.isFinite ? max(seconds, 0) : 0
        let minutes = max(Int((s / 60).rounded(.up)), 1)
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) m" }
        return "\(h) h \(m) m"
    }

    /// Home and the cover: "6 h" from an hour out, then "12 m" (never "0 m").
    static func nextInShort(seconds: Double) -> String {
        let s = seconds.isFinite ? max(seconds, 0) : 0
        if s >= 3600 { return "\(Int((s / 3600).rounded(.down))) h" }
        return "\(max(Int((s / 60).rounded(.up)), 1)) m"
    }

    /// Seconds until the next Daily (UTC midnight, `DailySeed.utc`).
    static func secondsToNextDaily(now: Date) -> Double {
        let cal = DailySeed.utc
        let start = cal.startOfDay(for: now)
        let next = cal.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
        return max(next.timeIntervalSince(now), 0)
    }

    /// The flight share line.
    static func flight(meters: Double, perfects: Int, lastLighthouse: String) -> String {
        "Swoop \(body(meters: meters, perfects: perfects, lastLighthouse: lastLighthouse))"
    }

    /// The Daily share line; `streak` ≥ 2 adds " 🔥N".
    /// `day` is the DISPLAY number (`AppRules.dailyNumber`), never the seed day.
    static func daily(day: Int, meters: Double, perfects: Int, lastLighthouse: String, streak: Int = 0) -> String {
        let flame = streak >= 2 ? " \(fire)\(streak)" : ""
        return "Swoop Daily #\(day) \(body(meters: meters, perfects: perfects, lastLighthouse: lastLighthouse))\(flame)"
    }

    /// FINAL-FIXES #13: a practice Daily's line never reads as the day's one scored try.
    static let practicePrefix = "Practice · "

    /// The line for a finished run. A practice Daily (`scored: false`) is prefixed "Practice · " and carries no streak.
    static func line(for result: RunResult, streak: Int) -> String {
        if case let .daily(day, scored) = result.mode {
            let line = daily(day: AppRules.dailyNumber(day: day), meters: result.meters, perfects: result.perfects,
                             lastLighthouse: result.lastLighthouseName, streak: scored ? streak : 0)
            return scored ? line : practicePrefix + line
        }
        return flight(meters: result.meters, perfects: result.perfects, lastLighthouse: result.lastLighthouseName)
    }

    private static func body(meters: Double, perfects: Int, lastLighthouse: String) -> String {
        let name = lastLighthouse.trimmingCharacters(in: .whitespacesAndNewlines)
        let past = name.isEmpty ? "" : " · past \(name) \(sunrise)"
        return "\(km(meters)) \(dove) \(Self.perfects(perfects))\(past)"
    }
}
