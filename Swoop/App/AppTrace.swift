import Foundation

/// The `SWOOP-T …` lines CI greps (ROUND-1 "Log lines CI greps"). They print only in DEBUG builds launched with
/// `-swoopDemo` (stdout, flushed). In Release `enabled` is false and `t(_:)` compiles to nothing, so the helper can be
/// called from anywhere in the app without `#if` guards.
enum AppTrace {
    /// True only in a DEBUG build launched with `-swoopDemo` (CI and design review).
    static let enabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-swoopDemo")
        #else
        return false
        #endif
    }()

    /// Prints one trace line (DEBUG + `-swoopDemo` only), flushed so CI sees lines in order.
    static func t(_ line: @autoclosure () -> String) {
        #if DEBUG
        guard enabled else { return }
        print(line())
        fflush(stdout)
        #endif
    }

    /// A finite Double as a rounded Int (0 for NaN / infinity), for log lines.
    static func int(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(value.rounded())
    }

    /// The part after `SWOOP-T event ` for a FlightEvent, e.g. `touchdown perfect speed=1234 chain=3`. Pure; tested.
    static func describe(_ event: FlightEvent) -> String {
        switch event {
        case let .countdownTick(n): return "countdown \(n)"
        case .started: return "started"
        case let .launched(speed): return "launched speed=\(int(speed))"
        case let .touchdown(quality, speed, chain):
            return "touchdown \(quality.rawValue) speed=\(int(speed)) chain=\(chain)"
        case .tailwindStarted: return "tailwindStarted"
        case .tailwindEnded: return "tailwindEnded"
        case let .lighthouse(index, name): return "lighthouse index=\(index) name=\(name)"
        case .cloudTouched: return "cloudTouched"
        case let .milestone(km): return "milestone km=\(km)"
        case .newBest: return "newBest"
        case .stormClose: return "stormClose"
        case .caught: return "caught"
        case .finished: return "finished"
        }
    }
}
