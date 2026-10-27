import CoreGraphics
import Foundation

// MARK: - Flight School's guide gull (Round 9, UX-ROUND-9 §1 / §9)
//
// The guide gull (a translucent "ghost" bird) demonstrates each Flight School move once on the practice sea. Its path
// is the practice sea's own physics (FlightSession.practice, run headless at 1× time) flown with a scripted ideal tuck,
// so it is exactly what the player's bird will do if they copy it. Pure and deterministic: the same step always gives
// the same samples. Positions are in sea space (the same wave the player is on); Scene draws the ghost from them
// (offset ahead as it likes), and App sequences the demos.

/// The Flight School moves the ghost can demonstrate.
public enum PracticeGhostStep: String, CaseIterable, Sendable {
    /// Step 3 "Down": waits on crest A while the tuck comes in, then slides folded to the first trough.
    case dive
    /// Step 4 "Up and land": from the trough, wings open up the face, launches off crest B and lands Perfect in the
    /// guided ring.
    case soarAndLand
    /// Step 4's retry: from the air just past crest B (where `nextGuidedSwell()` puts the bird), down into the ring.
    case guidedLanding
    /// Step 5 "Rhythm": the 3 rhythm waves, one fold down and one open up per wave.
    case rhythm
}

/// One point of the ghost's path.
public struct GhostSample: Equatable, Sendable {
    /// Seconds from the start of the demo, in sim time (scale it to the playback speed you want).
    public var t: Double
    /// Sea-space position (pt).
    public var x: Double
    public var y: Double
    /// Body angle (rad, 0 = level, positive = nose up), smoothed like the player's.
    public var bodyAngle: Double
    /// The eased tuck 0…1 (draw the wings from it; the mini diagram folds with it).
    public var tuck: Double
    /// On the water.
    public var skimming: Bool
    /// "Folded" for the fold-path fill: the tuck is at least `Tuning.practiceHeldTuck`, as the dive step counts it.
    public var folded: Bool
    /// What happened at this sample, if anything (launch, the landing quality, a finished wave).
    public var signals: [PracticeSignal]

    public init(t: Double, x: Double, y: Double, bodyAngle: Double, tuck: Double, skimming: Bool, folded: Bool,
                signals: [PracticeSignal] = []) {
        self.t = t; self.x = x; self.y = y; self.bodyAngle = bodyAngle; self.tuck = tuck
        self.skimming = skimming; self.folded = folded; self.signals = signals
    }
}

public enum PracticeGhost {

    /// Sample spacing of the paths (s, sim time).
    public static let sampleDt: Double = 1.0 / 60.0
    /// The demo keeps going this long after its last move (s), so the ghost settles instead of stopping dead.
    static let tail: Double = 0.35
    /// Safety cap on a demo's length (s).
    static let maxSeconds: Double = 8

    /// The scripted, ideal demonstration of `step` (the same every call). UX's `practiceGhostPath(step:)`.
    public static func path(step: PracticeGhostStep) -> [GhostSample] {
        let s = FlightSession.practice(bird: .gull)
        s.timeScale = 1
        switch step {
        case .dive: s.rewind(to: .crestA)
        case .soarAndLand: s.rewind(to: .trough)
        case .guidedLanding: s.rewind(to: .guided(0))
        case .rhythm: s.rewind(to: .rhythm)
        }
        var out: [GhostSample] = []
        out.append(sample(s, t: 0, signals: []))
        var t: Double = 0
        var endAt: Double = maxSeconds
        let frames: Int = 2
        let dt: Double = sampleDt / Double(frames)
        while t < min(endAt, maxSeconds) {
            var sigs: [PracticeSignal] = []
            var i: Int = 0
            while i < frames {
                let u: Double = idealTuck(step, s)
                _ = s.step(dt: dt, tuck: u)
                sigs.append(contentsOf: s.practiceSignals)
                i += 1
            }
            t += sampleDt
            out.append(sample(s, t: t, signals: sigs))
            if endAt >= maxSeconds && isDone(step, sigs, s) {
                endAt = t + tail
            }
        }
        return out
    }

    /// The ghost's sample at time `t` (linear between samples; clamped to the path's ends).
    public static func sample(_ path: [GhostSample], at t: Double) -> GhostSample? {
        guard let first = path.first, let last = path.last else { return nil }
        if t <= first.t { return first }
        if t >= last.t { return last }
        var i: Int = 1
        while i < path.count && path[i].t < t {
            i += 1
        }
        let a: GhostSample = path[i - 1]
        let b: GhostSample = path[min(i, path.count - 1)]
        let span: Double = b.t - a.t
        let f: Double = span > 0 ? (t - a.t) / span : 0
        return GhostSample(t: t, x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f,
                           bodyAngle: a.bodyAngle + (b.bodyAngle - a.bodyAngle) * f,
                           tuck: a.tuck + (b.tuck - a.tuck) * f, skimming: f < 0.5 ? a.skimming : b.skimming,
                           folded: f < 0.5 ? a.folded : b.folded, signals: [])
    }

    /// The demo's duration (s, sim time).
    public static func duration(_ path: [GhostSample]) -> Double {
        return path.last?.t ?? 0
    }

    // MARK: Script

    /// The ideal tuck for each move: fold down the dive; open up the face and glide into the ring; on the rhythm
    /// waves fold on every downslope and on the way down in the air, open on every up-face.
    static func idealTuck(_ step: PracticeGhostStep, _ s: FlightSession) -> Double {
        let snap = s.snapshot
        let x: Double = Double(snap.position.x)
        switch step {
        case .dive:
            return x < Tuning.practiceTroughX ? 1 : 0
        case .soarAndLand, .guidedLanding:
            return 0
        case .rhythm:
            if snap.skimming {
                return s.sea.slope(at: x + snap.speed * 0.05) < -0.03 ? 1 : 0
            }
            return Double(snap.velocity.dy) < 0 ? 1 : 0
        }
    }

    static func isDone(_ step: PracticeGhostStep, _ sigs: [PracticeSignal], _ s: FlightSession) -> Bool {
        for sig in sigs {
            switch (step, sig) {
            case (.dive, .diveDone): return true
            case (.soarAndLand, .landed), (.guidedLanding, .landed): return true
            case (.rhythm, .waveDone(let i)): if i >= Tuning.practiceRhythmWaveEnds.count - 1 { return true }
            default: break
            }
        }
        return false
    }

    static func sample(_ s: FlightSession, t: Double, signals: [PracticeSignal]) -> GhostSample {
        let snap = s.snapshot
        return GhostSample(t: t, x: Double(snap.position.x), y: Double(snap.position.y), bodyAngle: snap.bodyAngle,
                           tuck: snap.tuck, skimming: snap.skimming, folded: snap.tuck >= Tuning.practiceHeldTuck,
                           signals: signals)
    }
}

extension FlightSession {
    /// UX-ROUND-9 §9's name for `PracticeGhost.path(step:)`.
    public static func practiceGhostPath(step: PracticeGhostStep) -> [GhostSample] {
        return PracticeGhost.path(step: step)
    }
}
