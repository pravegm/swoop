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

    /// The HUD distance (REVIEW-1 P1-9): whole metres below 1 km ("842" "m"), then kilometres with the hundredths still
    /// ticking ("1.24" "km"), rounded down, whatever the locale.
    static func hudDistance(_ meters: Double) -> (value: String, unit: String) {
        let m = meters.isFinite ? max(meters, 0) : 0
        if m < 1000 { return (String(Int(m.rounded(.down))), "m") }
        let hundredths = Int((m / 10).rounded(.down))
        let whole = hundredths / 100
        let frac = hundredths % 100
        return ("\(grouped(whole)).\(frac < 10 ? "0" : "")\(frac)", "km")
    }

    static func perfects(_ n: Int) -> String { n == 1 ? "1 Perfect" : "\(n) Perfects" }

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
    static func daily(day: Int, meters: Double, perfects: Int, lastLighthouse: String, streak: Int = 0) -> String {
        let flame = streak >= 2 ? " \(fire)\(streak)" : ""
        return "Swoop Daily #\(day) \(body(meters: meters, perfects: perfects, lastLighthouse: lastLighthouse))\(flame)"
    }

    /// The line for a finished run.
    static func line(for result: RunResult, streak: Int) -> String {
        if case let .daily(day, _) = result.mode {
            return daily(day: day, meters: result.meters, perfects: result.perfects,
                         lastLighthouse: result.lastLighthouseName, streak: streak)
        }
        return flight(meters: result.meters, perfects: result.perfects, lastLighthouse: result.lastLighthouseName)
    }

    private static func body(meters: Double, perfects: Int, lastLighthouse: String) -> String {
        let name = lastLighthouse.trimmingCharacters(in: .whitespacesAndNewlines)
        let past = name.isEmpty ? "" : " · past \(name) \(sunrise)"
        return "\(km(meters)) \(dove) \(Self.perfects(perfects))\(past)"
    }
}
