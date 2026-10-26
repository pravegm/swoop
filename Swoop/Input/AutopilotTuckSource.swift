import Foundation

/// The autopilot (title attract loop, CI frames, `-swoopDemo autopilot=…`): Core's `FlightPilot` reads the session's
/// snapshot and the sea and decides the tuck. The closures fetch the live snapshot and sea from the App's controller
/// each frame; while either is missing (no session yet) the wings stay spread.
@MainActor
final class AutopilotTuckSource: TuckSource {
    let skill: PilotSkill
    private var pilot: FlightPilot
    private let snapshot: () -> FlightSnapshot?
    private let sea: () -> SeaProfile?
    private var lastQuery: TimeInterval?
    private var lastTuck: Double = 0

    init(skill: PilotSkill, seed: UInt64, snapshot: @escaping () -> FlightSnapshot?,
         sea: @escaping () -> SeaProfile?) {
        self.skill = skill
        self.pilot = FlightPilot(skill: skill, seed: seed)
        self.snapshot = snapshot
        self.sea = sea
    }

    func tuck(at time: TimeInterval) -> Double {
        // Asked twice for the same frame: the same answer (the pilot may keep internal timers).
        if let previous = lastQuery, time.isFinite, time <= previous { return lastTuck }
        if time.isFinite { lastQuery = time }
        guard let current = snapshot(), let profile = sea() else {
            lastTuck = 0
            return 0
        }
        let value = pilot.tuck(for: current, sea: profile)
        lastTuck = FeelMath.clamp01(value)
        return lastTuck
    }
}
