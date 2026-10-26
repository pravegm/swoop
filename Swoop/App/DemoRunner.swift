#if DEBUG
import Foundation

/// Headless play for demo scenarios (DEBUG only): a session is really flown, step by step, by Core's FlightPilot (or a
/// wings-spread glide), so every seeded number on screen — chain, lead, distance, the results card — is true.
enum DemoRunner {
    /// The headless frame step (s).
    static let step: Double = 1.0 / 60.0

    /// Flies `session` with a `skill` pilot until `done` returns true, the run finishes, or `maxSeconds` of session time
    /// pass. Returns the session seconds flown. `onEvent` sees every event (e.g. to note when the drop happened).
    @discardableResult
    static func fly(_ session: FlightSession, skill: PilotSkill, seed: UInt64, maxSeconds: Double,
                    onEvent: (FlightEvent, FlightSnapshot) -> Void = { _, _ in },
                    until done: (FlightSnapshot) -> Bool) -> Double {
        var pilot = FlightPilot(skill: skill, seed: seed &+ 101)
        var flown = 0.0
        while flown < maxSeconds && !session.isFinished {
            let before = session.snapshot
            if done(before) { break }
            let tuck = pilot.tuck(for: before, sea: session.sea)
            let events = session.step(dt: step, tuck: tuck)
            if !events.isEmpty {
                let after = session.snapshot
                for event in events { onEvent(event, after) }
            }
            flown += step
        }
        return flown
    }

    /// Glides with the wings spread (tuck 0: slow, so the storm closes in) until `done`.
    @discardableResult
    static func glide(_ session: FlightSession, maxSeconds: Double,
                      onEvent: (FlightEvent, FlightSnapshot) -> Void = { _, _ in },
                      until done: (FlightSnapshot) -> Bool) -> Double {
        var flown = 0.0
        while flown < maxSeconds && !session.isFinished {
            let before = session.snapshot
            if done(before) { break }
            let events = session.step(dt: step, tuck: 0)
            if !events.isEmpty {
                let after = session.snapshot
                for event in events { onEvent(event, after) }
            }
            flown += step
        }
        return flown
    }

    /// A whole run flown to its end (the results card's run). Returns the session (finished unless `maxSeconds` hit).
    static func playToEnd(_ session: FlightSession, skill: PilotSkill, seed: UInt64, maxSeconds: Double = 900) {
        fly(session, skill: skill, seed: seed, maxSeconds: maxSeconds, until: { _ in false })
    }

    /// Whether the session is in the flying phase.
    static func isFlying(_ s: FlightSnapshot) -> Bool {
        if case .flying = s.phase { return true }
        return false
    }
}
#endif
