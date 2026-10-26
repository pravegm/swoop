import CoreGraphics
import Foundation
import Testing
@testable import Swoop

// MARK: - Headless balance playtest
//
// Every PilotSkill flies real FlightSessions (20 seeds, dt 1/120, each run capped at 15 min of flight) and prints:
//   SWOOP-BAL skill=casual median=115.2s p10=104.8 p90=125.9 medianMeters=11270 perfects/min=2.8 ...
// The assertions are loose (targets in GAME-DESIGN §6; tools/balance-sim.js predicts novice ~50 s, casual ~115 s,
// expert ~5.5 min, perfect ~10 min). Overrides: SWOOP_BAL_SEEDS (number of seeds).
// Each skill is simulated once (memoised per skill), so the comparison test reuses the per-skill runs.

struct SwoopBalanceRun {
    var seconds: Double
    var meters: Double
    var perfects: Int
    var splashes: Int
    var capped: Bool
}

final class SwoopBalanceMemo: @unchecked Sendable {
    static let shared = SwoopBalanceMemo()

    private let locks: [PilotSkill: NSLock]
    private let dataLock = NSLock()
    private var results: [PilotSkill: [SwoopBalanceRun]] = [:]

    init() {
        var l: [PilotSkill: NSLock] = [:]
        for s in PilotSkill.allCases { l[s] = NSLock() }
        locks = l
    }

    func runs(_ skill: PilotSkill) -> [SwoopBalanceRun] {
        let lock: NSLock = locks[skill] ?? NSLock()
        lock.lock()
        defer { lock.unlock() }
        dataLock.lock()
        let cached: [SwoopBalanceRun]? = results[skill]
        dataLock.unlock()
        if let c = cached { return c }
        let computed: [SwoopBalanceRun] = SwoopBalanceHarness.simulate(skill)
        dataLock.lock()
        results[skill] = computed
        dataLock.unlock()
        return computed
    }
}

enum SwoopBalanceHarness {
    static let frameDt: Double = 1.0 / 120.0
    static let capSeconds: Double = 15 * 60

    static var seedCount: Int {
        if let raw = ProcessInfo.processInfo.environment["SWOOP_BAL_SEEDS"], let n = Int(raw), n > 0 { return n }
        return 20
    }

    static func seed(_ i: Int) -> UInt64 {
        return UInt64(1000 + i * 7919)
    }

    static func runOne(_ skill: PilotSkill, seed: UInt64) -> SwoopBalanceRun {
        let session = FlightSession(mode: .flight, seed: seed, bestMeters: 0, bird: .gull)
        session.skipCountdown()
        var pilot = FlightPilot(skill: skill, seed: seed &* 7 &+ 1)
        var perfects: Int = 0
        var splashes: Int = 0
        var frames: Int = 0
        let maxFrames: Int = Int((capSeconds + 3) / frameDt)
        while !session.isFinished && frames < maxFrames {
            let tuck: Double = pilot.tuck(for: session.snapshot, sea: session.sea)
            let events: [FlightEvent] = session.step(dt: frameDt, tuck: tuck)
            for e in events {
                if case .touchdown(let q, _, _) = e {
                    if q == .perfect { perfects += 1 }
                    if q == .splash { splashes += 1 }
                }
            }
            frames += 1
        }
        if let r = session.result {
            return SwoopBalanceRun(seconds: r.seconds, meters: r.meters, perfects: perfects, splashes: splashes,
                              capped: false)
        }
        let snap = session.snapshot
        return SwoopBalanceRun(seconds: capSeconds, meters: snap.distanceMeters, perfects: perfects, splashes: splashes,
                          capped: true)
    }

    static func simulate(_ skill: PilotSkill) -> [SwoopBalanceRun] {
        var out: [SwoopBalanceRun] = []
        var i: Int = 0
        while i < seedCount {
            out.append(runOne(skill, seed: seed(i)))
            i += 1
        }
        return out
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        if values.isEmpty { return 0 }
        let sorted: [Double] = values.sorted()
        let pos: Double = Double(sorted.count - 1) * p
        let lo: Int = Int(pos.rounded(.down))
        let hi: Int = min(sorted.count - 1, lo + 1)
        let f: Double = pos - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * f
    }

    static func report(_ skill: PilotSkill, _ runs: [SwoopBalanceRun]) -> String {
        let secs: [Double] = runs.map { (r: SwoopBalanceRun) -> Double in r.seconds }
        let meters: [Double] = runs.map { (r: SwoopBalanceRun) -> Double in r.meters }
        let ppm: [Double] = runs.map { (r: SwoopBalanceRun) -> Double in Double(r.perfects) / max(r.seconds / 60, 1e-6) }
        let spm: [Double] = runs.map { (r: SwoopBalanceRun) -> Double in Double(r.splashes) / max(r.seconds / 60, 1e-6) }
        let capped: Int = runs.filter { (r: SwoopBalanceRun) -> Bool in r.capped }.count
        return String(format: "SWOOP-BAL skill=%@ median=%.1fs p10=%.1f p90=%.1f medianMeters=%.0f perfects/min=%.1f splashes/min=%.1f capped=%d n=%d",
                      skill.rawValue, percentile(secs, 0.5), percentile(secs, 0.1), percentile(secs, 0.9),
                      percentile(meters, 0.5), percentile(ppm, 0.5), percentile(spm, 0.5), capped, runs.count)
    }

    static func median(_ skill: PilotSkill) -> Double {
        let runs: [SwoopBalanceRun] = SwoopBalanceMemo.shared.runs(skill)
        return percentile(runs.map { (r: SwoopBalanceRun) -> Double in r.seconds }, 0.5)
    }
}

struct BalanceTests {

    @Test(arguments: PilotSkill.allCases)
    func runLengths(skill: PilotSkill) {
        let runs: [SwoopBalanceRun] = SwoopBalanceMemo.shared.runs(skill)
        let line: String = SwoopBalanceHarness.report(skill, runs)
        // Unbuffered, so the line survives even if a later test crashes the runner.
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
        let med: Double = SwoopBalanceHarness.percentile(runs.map { (r: SwoopBalanceRun) -> Double in r.seconds }, 0.5)
        switch skill {
        case .novice:
            #expect(med >= 35 && med <= 110, "\(line)")
        case .casual:
            #expect(med >= 90 && med <= 260, "\(line)")
        case .expert:
            #expect(med >= 120, "\(line)")
        case .perfect:
            // The storm keeps accelerating: even flawless flying ends inside the cap.
            let capped: Int = runs.filter { (r: SwoopBalanceRun) -> Bool in r.capped }.count
            #expect(capped == 0, "\(line)")
            #expect(med >= 180, "\(line)")
        }
    }

    @Test func expertOutfliesCasual() {
        let casual: Double = SwoopBalanceHarness.median(.casual)
        let expert: Double = SwoopBalanceHarness.median(.expert)
        #expect(expert > casual, "expert \(expert) s vs casual \(casual) s")
    }
}
