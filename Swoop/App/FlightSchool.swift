import CoreGraphics
import Foundation

// Round 6 (design/UX-FLIGHT-SCHOOL.md): Flight School, the bird's side, the route and the objective. Everything here is
// pure (no actor isolation), so AppTests drives it frame by frame.

// MARK: - The bird's side (D1, UX §2)

/// The interface orientation of a landscape canvas (UIKit's two landscape orientations).
enum InterfaceSide: String, Codable, Equatable {
    case landscapeLeft, landscapeRight

    var flipped: InterfaceSide { self == .landscapeLeft ? .landscapeRight : .landscapeLeft }
    /// Feel's name for it (`SharpHalf`).
    var feel: FeelLandscape { self == .landscapeLeft ? .left : .right }
}

enum ScreenSide: String, Codable, Equatable {
    case left, right

    var feel: FeelScreenSide { self == .left ? .left : .right }
    init(_ f: FeelScreenSide) { self = f == .left ? .left : .right }
}

/// Settings › Bird side: the sharp half (Duo default), or a fixed screen side.
enum BirdSide: String, Codable, Equatable, CaseIterable {
    case sharp, left, right

    var label: String {
        switch self {
        case .sharp: return "Sharp side"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

/// The physical sharp half, tracked through 180° turns with Feel's `SharpHalf` (ROUND-6 D1 + the correction): the
/// default is the half on SCREEN-RIGHT in whatever orientation the app first runs in on a Duo (stored then, by
/// `GameController.recordSharpHalfIfNeeded`), so the bird starts on the right whichever way it's held; the Wing check
/// refines it. Pure; tested.
enum BirdSideRule {
    /// The sharp half's screen side in orientation `o` (no stored half yet: today's orientation is the reference).
    static func sharpSide(_ sharp: SharpHalf?, orientation o: InterfaceSide) -> ScreenSide {
        ScreenSide((sharp ?? SharpHalf.firstRun(in: o.feel)).screenSide(in: o.feel))
    }

    /// The bird's screen side.
    static func birdSide(_ side: BirdSide, sharp: SharpHalf?, orientation o: InterfaceSide) -> ScreenSide {
        switch side {
        case .left: return .left
        case .right: return .right
        case .sharp: return sharpSide(sharp, orientation: o)
        }
    }

    /// The scene's `mirrored` flag: the bird on the right half flies right to left.
    static func mirrored(_ side: BirdSide, sharp: SharpHalf?, orientation o: InterfaceSide) -> Bool {
        birdSide(side, sharp: sharp, orientation: o) == .right
    }

    /// The Wing check's answer, given in orientation `o`: the stored half (its reference orientation is kept).
    static func recording(answer: ScreenSide, sharp: SharpHalf?, orientation o: InterfaceSide) -> SharpHalf {
        (sharp ?? SharpHalf.firstRun(in: o.feel)).recording(sharpSide: answer.feel, in: o.feel)
    }

    /// R3–R5 settings: "Bird on the other side" on → Right; off → the sharp side on a Duo, Left on an iPhone.
    static func migrated(oldMirrored: Bool, isDuo: Bool) -> BirdSide {
        if oldMirrored { return .right }
        return isDuo ? .sharp : .left
    }
}

// MARK: - Flight School persistence

/// `ProgressData.flightSchool` (UX §1.4).
enum FlightSchoolState: Codable, Equatable {
    case notStarted
    case skipped(atStep: Int)
    case done

    private enum Keys: String, CodingKey { case kind, step }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "notStarted"
        switch kind {
        case "done": self = .done
        case "skipped": self = .skipped(atStep: (try? c.decodeIfPresent(Int.self, forKey: .step)) ?? 0)
        default: self = .notStarted
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .notStarted: try c.encode("notStarted", forKey: .kind)
        case .done: try c.encode("done", forKey: .kind)
        case let .skipped(step):
            try c.encode("skipped", forKey: .kind)
            try c.encode(step, forKey: .step)
        }
    }
}

// MARK: - The school's steps

enum SchoolStep: Int, CaseIterable, Comparable {
    case hold = 0, wings, wingCheck, dive, soar, land, rhythm, storm

    static func < (a: SchoolStep, b: SchoolStep) -> Bool { a.rawValue < b.rawValue }

    /// Studio steps show the title bird and the diagram; Sea steps fly the practice sea.
    var isSea: Bool { self >= .dive }

    /// The demo key's names (`school=dive`).
    var key: String {
        switch self {
        case .hold: return "hold"
        case .wings: return "wings"
        case .wingCheck: return "wingcheck"
        case .dive: return "dive"
        case .soar: return "soar"
        case .land: return "land"
        case .rhythm: return "rhythm"
        case .storm: return "storm"
        }
    }

    static func from(key: String) -> SchoolStep? {
        if let n = Int(key), let s = SchoolStep(rawValue: n) { return s }
        return SchoolStep.allCases.first { $0.key == key }
    }
}

/// R9: where a step's in-world words sit: beside the diagram, at the bird's spot (≥ 80 pt off it), by the ring, by
/// the meter, or on both halves (the clear-side check).
enum SchoolWordsAnchor: Equatable { case diagram, spot, ring, meter, pages }

/// One frame of what the school sees.
struct SchoolInput: Equatable {
    var time: Double
    /// A landscape canvas (book pose on a Duo; sideways on an iPhone).
    var landscape: Bool
    /// The filtered hinge angle; nil without a hinge.
    var angle: Double?
    var still: Bool = false
    /// The wings' tuck, 0…1 (hinge or touch).
    var tuck: Double = 0
    /// Sea steps: the sea's slope under the bird (< 0 downslope), and whether the bird is skimming.
    var slope: Double = 0
    var skimming: Bool = false
    var flying: Bool = false
    var events: [FlightEvent] = []
    /// Core's practice session (K1): its step signals are authoritative for steps 3–6 (the slope heuristics are the
    /// fallback for a plain Flight sea).
    var practice: Bool = false
    var signals: [PracticeSignal] = []
}

/// The Flight School state machine (UX §1.2). Each frame: `step(_:)`; it returns what the App should do now.
struct FlightSchool: Equatable {
    enum Phase: Equatable {
        /// The prompt is up.
        case prompt
        /// "✓ praise" for `praiseSeconds`, then the next step.
        case praise
        /// Finished: the real Flight starts.
        case finished
    }

    struct Output: Equatable {
        /// Ask the App to rewind the practice sea to the current step's checkpoint.
        var rewind = false
        /// Advanced to a new step this frame.
        var advanced = false
        /// A step succeeded this frame (the chime, the haptic).
        var succeeded = false
        /// The school just finished: start the real Flight (1.5 s Ready · Go).
        var finished = false
    }

    // Timings (UX §1.1, §1.2).
    static let minPromptSeconds: Double = 1.2
    /// R9 (UX-ROUND-9 §1.1): each step first shows the move (the ghost and the diagram), then waits for the player.
    static let ghostDemoSeconds: Double = 1.8
    /// R9: no praise words; the world answers, then moves on.
    static let praiseSeconds: Double = 0.5
    /// R9 step 6: the Perfect in the storm's guided ring passes it; this long passes it anyway.
    static let stormPassAfter: Double = 15
    static let touchOfferAfter: Double = 10
    static let idleHelpAfter: Double = 6
    static let maxFails = 3
    static let stormLineSeconds: Double = 2.2
    static let rhythmSwapAfter: Double = 2.5

    let touch: Bool
    let tapping: Bool
    /// The Wing check is asked (Duo, hinge, not already done).
    let asksWingCheck: Bool

    private(set) var stepNow: SchoolStep = .hold
    private(set) var phase: Phase = .prompt
    private(set) var stepStartedAt: Double = 0
    private(set) var fails = 0
    /// The help line under the prompt ("Open it wider.", "You opened too soon…").
    private(set) var subline: String?
    /// The step-0 escape ("Play with touch instead") is offered.
    private(set) var offersTouch = false
    /// Step 0 has succeeded: Skip shows from now on.
    private(set) var canSkip = false
    /// Gold praise text while `phase == .praise`.
    private(set) var praise: String?
    /// The Wing check's own flow (step 2).
    var wingCheck = WingCheckFlow()

    private var phaseAt: Double = 0
    private var pendingSuccess = false
    private var foldHeldSince: Double?
    private var folded = false
    private var lastMoveAt: Double = 0
    private var lastTuck: Double = 0
    // Dive
    private var onDownslope = false
    private var downTime: Double = 0
    private var heldTime: Double = 0
    private var lastTime: Double?
    // Soar / land / rhythm
    private var upFace = false
    private var waves = 0
    private var landAttempts = 0
    /// R9: step 3 was missed at least once ("Stay folded" at the spot).
    private(set) var missedOnce = false
    /// Demo `school=<step>:demo|turn|fail`: the frame's moment in the step, held (the ghost demonstrating, or the
    /// player's turn).
    private(set) var frozenElapsed: Double?

    init(touch: Bool, tapping: Bool = false, asksWingCheck: Bool) {
        self.touch = touch
        self.tapping = tapping
        self.asksWingCheck = asksWingCheck && !touch
    }

    /// R9 (UX-ROUND-9 §1.2): 6 dots on a Duo asking the clear-side check, else 5. "Hold" folds into Wings (dot 1) and
    /// "Up and land" is one dot (soar + land).
    var stepCount: Int { asksWingCheck ? 6 : 5 }

    /// The dot of the current step. Pure; tested.
    var dotIndex: Int {
        let c = asksWingCheck ? 1 : 0
        switch stepNow {
        case .hold, .wings: return 0
        case .wingCheck: return 1
        case .dive: return 1 + c
        case .soar, .land: return 2 + c
        case .rhythm: return 3 + c
        case .storm: return 4 + c
        }
    }

    /// VoiceOver only (R9 cut the visible overline): "Flight School, step 3 of 6".
    var overline: String { "Flight School, step \(dotIndex + 1) of \(stepCount)" }

    /// R9: the step shows its move first (the ghost, the diagram's dashed pose), for `ghostDemoSeconds`.
    func isGhostDemo(at time: Double) -> Bool {
        guard phase == .prompt, Self.hasDemo(stepNow) else { return false }
        return elapsed(at: time) < Self.ghostDemoSeconds
    }

    /// Seconds into the step (a demo frame's held moment, else the clock).
    func elapsed(at time: Double) -> Double { frozenElapsed ?? (time - stepStartedAt) }

    static func hasDemo(_ step: SchoolStep) -> Bool {
        switch step {
        case .wings, .dive, .soar, .land, .rhythm: return true
        case .hold, .wingCheck, .storm: return false
        }
    }

    /// The demonstration's scripted tuck at `elapsed` seconds into the step (the diagram's dashed ghost; Scene's guide
    /// gull flies Core's ghost path). Pure; tested.
    static func ghostTuck(_ step: SchoolStep, elapsed e: Double) -> Double {
        let loop = 0.5 - 0.5 * cos(2 * Double.pi * max(e, 0) / 1.4)
        switch step {
        case .wings, .rhythm: return loop
        case .dive: return 1
        case .soar: return e < 0.9 ? 1 : 0
        case .hold, .wingCheck, .land, .storm: return 0
        }
    }

    /// R9: the step's in-world words (≤ 3, no full stop) and where they sit; nil = none. Pure; tested.
    func words(at time: Double) -> (text: String, anchor: SchoolWordsAnchor)? {
        let e = elapsed(at: time)
        guard phase == .prompt else { return nil }
        switch stepNow {
        case .hold:
            return touch ? nil : ("Hold it open", .diagram)
        case .wings:
            if tapping { return (folded ? "Tap again" : "Tap", .diagram) }
            if folded { return (touch ? "Now let go" : "Now open", .diagram) }
            return (touch ? "Hold anywhere" : "Fold a little", .diagram)
        case .wingCheck:
            switch wingCheck.phase {
            case .explain: return ("Open flat", .pages)
            case .fold: return ("Now fold", .pages)
            case .ask: return ("Tap clear side", .pages)
            case .confirm: return nil
            }
        case .dive:
            if missedOnce { return (touch ? "Keep holding" : "Stay folded", .spot) }
            return (tapping ? "Tap" : (touch ? "Hold" : "Fold"), .diagram)
        case .soar:
            return (tapping ? "Tap again" : (touch ? "Let go" : "Open"), .spot)
        case .land:
            return ("Land here", .ring)
        case .rhythm:
            return e < 3.5 ? ("One per wave", .spot) : nil
        case .storm:
            return ("Stay ahead", .meter)
        }
    }

    /// The live diagram rides the bird until step 3 (Down) has passed (UX-ROUND-9 §1.1 rule 6).
    var showsDiagram: Bool { stepNow <= .dive && stepNow != .wingCheck }

    /// The prompt for the current step (and, for timed steps, the moment within it).
    func prompt(at time: Double) -> String {
        FlightSchoolCopy.prompt(stepNow, touch: touch, tapping: tapping, elapsed: time - stepStartedAt)
    }

    /// Step 3's "Faster!" fill: the speed from the crest's start (Core's practice start speed) to the trough's. Pure;
    /// tested.
    static func fasterFill(speed: Double) -> Double {
        guard speed.isFinite else { return 0 }
        let lo = Tuning.practiceStartSpeed, hi = Tuning.practiceTroughSpeed
        return hi > lo ? min(max((speed - lo) / (hi - lo), 0), 1) : 0
    }

    /// Core's rhythm wave length (Round 6b: λ 2000, from the troughs at 6300, 8300, 10300).
    static var rhythmWaveLength: Double {
        let e = Tuning.practiceRhythmWaveEnds
        return e.count >= 2 ? e[1] - e[0] : 2000
    }

    /// The rhythm wave under sea x and how far along it (0 the trough before, 0.5 the crest, 1 its trough); nil outside
    /// the three waves. Pure; tested.
    static func rhythmPosition(x: Double) -> (wave: Int, fraction: Double)? {
        guard x.isFinite else { return nil }
        let l = rhythmWaveLength
        for (i, end) in Tuning.practiceRhythmWaveEnds.enumerated() where x < end {
            let start = end - l
            return x >= start ? (i, (x - start) / l) : nil
        }
        return nil
    }

    /// Where a failed sea step rewinds Core's practice sea to (nil: `nextGuidedSwell()`, step 5's next attempt).
    /// Pure; tested.
    static func checkpoint(for step: SchoolStep) -> PracticeCheckpoint? {
        switch step {
        case .hold, .wings, .wingCheck, .dive: return .crestA
        case .soar: return .trough
        case .land: return nil
        case .rhythm, .storm: return .rhythm
        }
    }

    /// The time scale the practice sea should run at (UX §1.2: 0.8×, 0.5× around the step-4 launch, 1.0 in step 7).
    var timeScale: Double {
        switch stepNow {
        case .soar: return upFace ? 0.5 : 0.8
        case .storm: return 1.0
        default: return 0.8
        }
    }

    /// Jump straight to a step (demo `school=`, the restart after a kill with the Wing check done).
    mutating func start(at step: SchoolStep, time: Double) {
        var s = step
        if s == .wingCheck && !asksWingCheck { s = .dive }
        stepNow = s
        phase = .prompt
        stepStartedAt = time
        phaseAt = time
        fails = 0
        subline = nil
        praise = nil
        pendingSuccess = false
        resetTrackers(time: time)
        canSkip = canSkip || s > .hold
    }

    private mutating func resetTrackers(time: Double) {
        foldHeldSince = nil
        folded = false
        lastMoveAt = time
        onDownslope = false
        downTime = 0
        heldTime = 0
        lastTime = nil
        upFace = false
        waves = 0
        landAttempts = 0
        missedOnce = false
        wingCheck = WingCheckFlow()
    }

    /// Demo `school=<step>:<phase>`: hold a moment of the step for a CI frame (`done` the praise, `fail` the failure
    /// help, a Wing check phase).
    mutating func demo(phase key: String?, time: Double) {
        guard let key else { return }
        switch key {
        case "done":
            phase = .praise
            phaseAt = time + 3600
            praise = FlightSchoolCopy.praise(stepNow, wingCheck: wingCheck)
        case "fail":
            subline = FlightSchoolCopy.failure(stepNow, touch: touch)
            missedOnce = true
            frozenElapsed = Self.ghostDemoSeconds + 1
        case "demo":
            frozenElapsed = Self.ghostDemoSeconds * 0.5
        case "turn":
            frozenElapsed = Self.ghostDemoSeconds + 1
            if stepNow == .wings { folded = false }
        case "1", "2", "3":
            // R7: step 7's three lines as held frames (a 2 s wall-clock capture caught the launch's portrait frame).
            let k = Double(Int(key) ?? 1)
            stepStartedAt = time - (k - 1) * Self.stormLineSeconds - (k > 1 ? 1.0 : 0.5)
        default:
            if let p = WingCheckFlow.Phase(rawValue: key) { wingCheck.force(p) }
        }
    }

    /// The player tapped "Skip" (allowed once step 0 is done).
    mutating func skip() -> Bool {
        guard canSkip, phase != .finished else { return false }
        phase = .finished
        return true
    }

    /// The Wing check's answer (or "Not sure · skip").
    mutating func answerWingCheck(_ answer: ScreenSide?, time: Double) {
        guard stepNow == .wingCheck, phase == .prompt else { return }
        wingCheck.answer(answer, time: time)
        pendingSuccess = true
    }

    /// One frame.
    mutating func step(_ input: SchoolInput) -> Output {
        var out = Output()
        let t = input.time
        switch phase {
        case .finished:
            return out
        case .praise:
            if t - phaseAt >= FlightSchoolCopy.praiseSeconds(stepNow) {
                if let next = SchoolStep(rawValue: stepNow.rawValue + 1) {
                    var n = next
                    if n == .wingCheck && !asksWingCheck { n = .dive }
                    start(at: n, time: t)
                    out.advanced = true
                } else {
                    phase = .finished
                    out.finished = true
                }
            }
            return out
        case .prompt:
            break
        }
        let elapsed = t - stepStartedAt
        let u = input.tuck.isFinite ? min(max(input.tuck, 0), 1) : 0
        if abs(u - lastTuck) > 0.05 { lastMoveAt = t }
        lastTuck = u
        let dt: Double = lastTime.map { max(t - $0, 0) } ?? 0
        lastTime = t

        switch stepNow {
        case .hold:
            if touch {
                if input.landscape { pendingSuccess = true }
                subline = input.landscape ? nil : "Turn it sideways."
            } else {
                let a = input.angle ?? 0
                if !input.landscape {
                    subline = "Turn it sideways."
                } else if a >= 174 {
                    subline = "A little less than flat."
                } else if a < 110 {
                    subline = "Open it wider."
                } else {
                    subline = nil
                    if input.still { pendingSuccess = true }
                }
                if elapsed >= Self.touchOfferAfter { offersTouch = true }
            }
        case .wings:
            if let a = input.angle, !touch, a < 95 {
                subline = "Not that far. Just a little."
            } else if u >= 0.4 || folded {
                subline = touch ? "…and let go." : "…and open again."
            } else if !touch && t - lastMoveAt >= Self.idleHelpAfter {
                subline = "Fold both halves in a little."
            } else {
                subline = nil
            }
            if u >= 0.8 {
                let since = foldHeldSince ?? t
                foldHeldSince = since
                if t - since >= 0.2 { folded = true }
            } else {
                foldHeldSince = nil
            }
            if folded && u <= 0.2 { pendingSuccess = true }
        case .wingCheck:
            if let a = input.angle { wingCheck.update(angle: a, time: t) }
            subline = nil
        case .dive where input.practice:
            for sig in input.signals {
                if case let .diveDone(fraction) = sig { judgeDive(fraction, out: &out) }
            }
        case .dive:
            if input.flying && input.skimming && input.slope < -0.05 {
                onDownslope = true
                downTime += dt
                if u >= 0.6 { heldTime += dt }
            } else if onDownslope && (input.slope >= 0 || !input.skimming) {
                onDownslope = false
                if downTime >= 0.3 { judgeDive(downTime > 0 ? heldTime / downTime : 0, out: &out) }
                downTime = 0
                heldTime = 0
            }
        case .soar where input.practice:
            if input.skimming && input.slope > 0.06 { upFace = true }
            if upFace && u > 0.3 { subline = touch ? "Let go now!" : "Open now!" }
            for sig in input.signals {
                guard case let .launched(launchTuck) = sig, !pendingSuccess else { continue }
                if launchTuck <= 0.3 {
                    pendingSuccess = true
                } else {
                    soarMissed(out: &out)
                }
            }
        case .soar:
            if input.skimming && input.slope > 0.06 { upFace = true }
            if upFace && u > 0.3 { subline = touch ? "Let go now!" : "Open now!" }
            for e in input.events {
                if case .launched = e {
                    if u <= 0.3 || fails >= Self.maxFails - 1 { pendingSuccess = true }
                }
            }
            if upFace && input.skimming && input.slope < -0.05 && !pendingSuccess { soarMissed(out: &out) }
        case .land:
            if input.flying && !input.skimming { subline = touch ? "Hold to come down, let go to glide."
                : "Fold to come down, open to glide." }
            var landings: [TouchdownQuality] = []
            if input.practice {
                for sig in input.signals { if case let .landed(q) = sig { landings.append(q) } }
            } else {
                for e in input.events { if case let .touchdown(q, _, _) = e { landings.append(q) } }
            }
            for quality in landings where !pendingSuccess {
                landAttempts += 1
                if quality == .perfect {
                    pendingSuccess = true
                } else if landAttempts >= Self.maxFails {
                    subline = "Perfect landings come with practice."
                    pendingSuccess = true
                } else {
                    subline = quality == .splash ? "Splash! Aim for the way down." : "Close! Aim for the ring."
                    // Core's practice sea: back into the air over the guided downslope for another go.
                    if input.practice { out.rewind = true }
                }
            }
        case .rhythm:
            if input.practice {
                for sig in input.signals { if case let .waveDone(i) = sig { waves = max(waves, i + 1) } }
            } else {
                for e in input.events { if case .touchdown = e { waves += 1 } }
            }
            if input.skimming && input.slope < -0.05 && u < 0.3 {
                subline = touch ? "Hold on the way down" : "Fold on the way down"
            } else if input.skimming && input.slope > 0.06 && u > 0.6 {
                subline = touch ? "Let go on the way up" : "Open on the way up"
            } else if waves > 0 {
                subline = nil
            }
            if waves >= 3 { pendingSuccess = true }
        case .storm:
            // R9: the Perfect in the next guided ring passes the storm step (3 landings, or 15 s, pass it anyway).
            for sig in input.signals { if case let .landed(q) = sig { landAttempts += 1; if q == .perfect { pendingSuccess = true } } }
            for e in input.events where !input.practice { if case let .touchdown(q, _, _) = e { landAttempts += 1; if q == .perfect { pendingSuccess = true } } }
            if landAttempts >= Self.maxFails || elapsed >= Self.stormPassAfter { pendingSuccess = true }
        }

        let minPrompt = Self.hasDemo(stepNow) ? Self.ghostDemoSeconds : Self.minPromptSeconds
        if pendingSuccess && elapsed >= minPrompt {
            pendingSuccess = false
            out.succeeded = true
            if stepNow == .hold { canSkip = true }
            if stepNow == .storm {
                phase = .finished
                out.finished = true
            } else {
                phase = .praise
                phaseAt = t
                praise = FlightSchoolCopy.praise(stepNow, wingCheck: wingCheck)
            }
        }
        return out
    }

    /// Step 3's verdict on one downslope: held ≥ 70 % of it, else the help line and a rewind (3 fails: on we go).
    private mutating func judgeDive(_ fraction: Double, out: inout Output) {
        guard !pendingSuccess else { return }
        if fraction >= 0.7 {
            pendingSuccess = true
            return
        }
        fails += 1
        missedOnce = true
        if fails >= Self.maxFails {
            subline = "Good enough. Let's fly."
            pendingSuccess = true
        } else {
            subline = FlightSchoolCopy.failure(.dive, touch: touch)
            out.rewind = true
        }
    }

    /// Step 4 missed the take-off (folded over the crest): the help line and a rewind (3 fails: on we go).
    private mutating func soarMissed(out: inout Output) {
        upFace = false
        fails += 1
        if fails >= Self.maxFails {
            pendingSuccess = true
        } else {
            subline = FlightSchoolCopy.failure(.soar, touch: touch)
            out.rewind = true
        }
    }
}

/// The Wing check (UX §2.2): explain → (flat) → fold → ask → confirm. Pure; tested.
struct WingCheckFlow: Equatable {
    enum Phase: String, Equatable { case explain, fold, ask, confirm }

    static let flatAngle: Double = 174
    static let flatHold: Double = 0.5
    static let foldDrop: Double = 8
    static let flatHelpAfter: Double = 10

    private(set) var phase: Phase = .explain
    private(set) var flatReading: Double?
    private(set) var answer: ScreenSide?
    private(set) var skipped = false
    private var flatSince: Double?
    private var startedAt: Double?

    /// "Open it all the way flat, just for this check." after 10 s without flat.
    private(set) var needsFlatHelp = false

    mutating func update(angle: Double, time: Double) {
        if startedAt == nil { startedAt = time }
        switch phase {
        case .explain:
            if angle >= Self.flatAngle {
                let since = flatSince ?? time
                flatSince = since
                flatReading = max(flatReading ?? angle, angle)
                if time - since >= Self.flatHold { phase = .fold }
            } else {
                flatSince = nil
                if let s = startedAt, time - s >= Self.flatHelpAfter { needsFlatHelp = true }
            }
        case .fold:
            if angle <= (flatReading ?? 180) - Self.foldDrop { phase = .ask }
        case .ask, .confirm:
            break
        }
    }

    /// A tap: a side, or nil for "Not sure · skip". Answers are taken in any phase (re-folding is harmless).
    mutating func answer(_ side: ScreenSide?, time: Double) {
        answer = side
        skipped = side == nil
        phase = .confirm
    }

    /// Demo: show a phase directly.
    mutating func force(_ p: Phase) { phase = p }
}

/// Flight School's words (UX §1.2), one place. Pure; tested.
enum FlightSchoolCopy {
    /// R8 P1-7/P1-8: every prompt is 7 words or fewer, and one vocabulary: "fold" / "open" on the Duo, "hold" /
    /// "let go" on iPhone (never tuck, dive or drop in an instruction). Pure; tested.
    static func prompt(_ step: SchoolStep, touch: Bool, tapping: Bool = false, elapsed: Double = 0) -> String {
        switch step {
        case .hold:
            return touch ? "Hold your iPhone sideways." : "Hold your Duo open like a book."
        case .wings:
            if tapping { return "Tap to fold. Tap to open." }
            return touch ? "Hold anywhere. The wings fold." : "These are your wings. Fold a little."
        case .wingCheck:
            return "One quick check."
        case .dive:
            if tapping { return "Tap once. Stay folded down." }
            return touch ? "Keep holding all the way down." : "Stay folded all the way down."
        case .soar:
            if tapping { return "Tap at the bottom. Fly!" }
            return touch ? "Let go at the bottom. Fly!" : "Open at the bottom. Fly!"
        case .land:
            return "Land in the ring ahead."
        case .rhythm:
            if tapping { return "Tap down, tap up, each wave." }
            if elapsed >= FlightSchool.rhythmSwapAfter { return touch ? "Hold down, let go up." : "Fold down, open up." }
            return touch ? "One hold per wave." : "One fold per wave. Never flap."
        case .storm:
            let line = FlightSchool.stormLineSeconds
            if elapsed < line { return "A storm is chasing you." }
            if elapsed < 2 * line { return "Perfect landings push the storm back." }
            return "Fly to \(RouteRules.name(0)) · \(ShareText.target(RouteRules.meters(0)))."
        }
    }

    /// The help line after a miss (UX §1.2), per step. Optional and muted.
    static func failure(_ step: SchoolStep, touch: Bool) -> String? {
        switch step {
        case .hold: return touch ? "Turn it sideways." : "A little less than flat."
        case .wings: return touch ? nil : "Not that far. Just a little."
        case .dive: return touch ? "You let go too soon. Keep holding." : "You opened too soon. Stay folded."
        case .soar: return touch ? "Let go to take off." : "Open to take off."
        case .land: return "Splash! Aim for the way down."
        case .wingCheck, .rhythm, .storm: return nil
        }
    }

    static func praise(_ step: SchoolStep, wingCheck: WingCheckFlow = WingCheckFlow()) -> String {
        switch step {
        case .hold: return "Good grip."
        case .wings: return "Wings folded!"
        case .wingCheck:
            return wingCheck.skipped ? "No problem. You can check it in Settings."
                : "Got it. Your bird flies on the sharp side."
        case .dive: return "Feel that speed?"
        case .soar: return "Lift-off!"
        case .land: return "PERFECT"
        case .rhythm: return "You've got the rhythm."
        case .storm: return ""
        }
    }
    /// R9: no praise cards; the game's own Perfect callout and ring name the Perfect in the world. Kept for the API.
    static func praiseLine(_ step: SchoolStep) -> String? { nil }

    /// How long the world pauses on a success before the next step (no words).
    static func praiseSeconds(_ step: SchoolStep) -> Double { FlightSchool.praiseSeconds }
}

// MARK: - The route and the objective (D3, UX §4)

/// Lighthouses as places on a route: fixed names by index (Core U1), their distances, and what the player has reached.
/// Pure; tested.
enum RouteRules {
    /// The framing sentence (UX §4.1).
    static let objective = "Stay ahead of the storm. Reach the lighthouses."

    /// The lighthouse's name (fixed by index in every mode).
    static func name(_ index: Int) -> String {
        Lighthouses.name(index: max(index, 0))
    }

    /// The lighthouse's distance from the start, in metres.
    static func meters(_ index: Int) -> Double {
        Lighthouses.meters(index: max(index, 0))
    }

    /// How many lighthouses lie at or before `distance` (U2's migration: from the best distance).
    static func reached(within distance: Double) -> Int {
        guard distance.isFinite, distance > 0 else { return 0 }
        return Lighthouses.count(atOrBeforeMeters: distance)
    }

    /// The goal chip (UX §4.2): "← Gull Point · 1.2 km" (the arrow points the way the bird flies).
    static func chip(nextIndex: Int, metersFlown: Double, mirrored: Bool) -> String {
        let left = max(meters(nextIndex) - (metersFlown.isFinite ? metersFlown : 0), 0)
        return "\(mirrored ? "←" : "→") \(name(nextIndex)) · \(ShareText.distance(left, roundUp: true))"
    }

    /// "Gull Point in 1.9 km" (the pause card and the cover).
    static func goalLine(nextIndex: Int, metersFlown: Double) -> String {
        "\(name(nextIndex)) in \(ShareText.distance(metersLeft(nextIndex: nextIndex, metersFlown: metersFlown), roundUp: true))"
    }

    /// The metres still to go to lighthouse `index`.
    static func metersLeft(nextIndex: Int, metersFlown: Double) -> Double {
        max(meters(nextIndex) - (metersFlown.isFinite ? metersFlown : 0), 0)
    }

    /// The chip's "near" state: under 300 m.
    static func isNear(metersLeft: Double) -> Bool { metersLeft < 300 }

    /// The lighthouse icon's scale: 0.8× at ≥ 3 km out, 1.25× at 0.
    static func iconScale(metersLeft: Double) -> CGFloat {
        let f = min(max(metersLeft / 3000, 0), 1)
        return CGFloat(1.25 - 0.45 * f)
    }

    /// Home's Fly subtitle (UX §4.5): "Next: Saltlight · 9 km · best 6.42 km", shortened to fit `maxChars`: first
    /// without the best, then "→ Saltlight · 9 km". Never an ellipsis.
    static func homeNext(routeReached: Int, best: Double, maxChars: Int = 40) -> String {
        let next = "\(name(routeReached)) · \(ShareText.target(meters(routeReached)))"
        let full = best > 0 ? "Next: \(next) · best \(ShareText.distance(best))" : "Next: \(next)"
        if full.count <= maxChars { return full }
        let short = "Next: \(next)"
        if short.count <= maxChars { return short }
        return "→ \(next)"
    }

    /// Results' headline (UX §4.6): "Reached Kestrel Head!" (and the short-of line), or "Caught 0.8 km short of
    /// Saltlight".
    static func headline(reachedThisRun: Int, meters: Double) -> (title: String, sub: String?, reached: Bool) {
        // R8 P0-3: one story. A reach is the headline and the catch is told as what happened next; with no reach, the
        // catch is the headline.
        let shortOf = ShareText.distance(metersLeft(nextIndex: reachedThisRun, metersFlown: meters), roundUp: true)
        if reachedThisRun >= 1 {
            return ("Reached \(name(reachedThisRun - 1))!",
                    "The storm caught you \(shortOf) before \(name(reachedThisRun)).", true)
        }
        return ("Caught \(shortOf) short of \(name(reachedThisRun))", nil, false)
    }

    /// The "Next time" tip (UX §4.6), the first rule that applies.
    static func nextTip(firstRealRun: Bool, perfects: Int, splashes: Int, bestChain: Int, nearBestHook: String?)
        -> String {
        // R9 glossary (UX-ROUND-9 §3): "the way down / up", "perfect landings"; the near-best line moved to the
        // card's quiet line, so `nearBestHook` is no longer used here.
        _ = nearBestHook
        if firstRealRun { return "Perfect landings push the storm back." }
        if perfects == 0 { return "Next time: land on the way down for a Perfect." }
        if splashes > perfects { return "Next time: open on the way up, so you land on the way down." }
        if bestChain < 3 { return "Next time: 3 perfect landings in a row = a Tailwind." }
        return "Next time: land Perfect after Perfect to push the storm back."
    }

    /// The route page's summary (UX §4.4).
    static func summary(routeReached: Int, best: Double) -> [String] {
        if routeReached <= 0 {
            return ["No lighthouses yet", "Next: \(name(0)) · \(ShareText.target(meters(0)))"]
        }
        var lines = [routeReached == 1 ? "1 lighthouse reached" : "\(routeReached) lighthouses reached"]
        if best > 0 { lines.append("Best \(ShareText.distance(best))") }
        lines.append("Next: \(name(routeReached)) · \(ShareText.target(meters(routeReached)))")
        let past = best - meters(max(routeReached - 1, 0))
        if best > 0 && past > 0 { lines.append("\(ShareText.distance(past)) past \(name(routeReached - 1))") }
        return lines
    }

    /// What a route node shows (UX §4.4): reached / next / after-next (name, haze) / beyond (no name).
    enum NodeState: Equatable { case reached, next, soon, unknown }

    static func nodeState(index: Int, routeReached: Int) -> NodeState {
        if index < routeReached { return .reached }
        if index == routeReached { return .next }
        if index == routeReached + 1 { return .soon }
        return .unknown
    }

    static func nodeLabel(index: Int, routeReached: Int) -> String {
        // R8 P0-1: every lighthouse by its real fixed name ("Lighthouse 5" read as a placeholder).
        name(index)
    }
}

// MARK: - R9 Results framed as progress (UX-ROUND-9 §2)

/// The far card's words, as one pure function of the flight (UX-ROUND-9 §2.2's case table): the ending is never the
/// headline (every flight ends with the storm); the headline is how far you got, in lighthouses. Pure; tested.
struct ResultsHeadline: Equatable {
    var overline: String
    var headline: String
    /// "New lighthouse" beside the headline when a new one was passed.
    var chip: String?
    /// One quiet line (two on a scored Daily).
    var lines: [String]

    struct Input: Equatable {
        var meters: Double
        /// Lighthouses passed this flight, and the last one's name.
        var passed: Int
        var lastPassed: String = ""
        var newLighthouse = false
        var previousBest: Double = 0
        var isNewBest = false
        var firstFlight = false
        var dailyTag: String?
        var dailyScored = false
        var dailyPractice = false
        var endedEarly = false
    }

    static func make(_ i: Input) -> ResultsHeadline {
        let overline: String
        if i.endedEarly { overline = "Flight ended" }
        else if let tag = i.dailyTag { overline = i.dailyPractice ? "Practice · \(tag)" : "Daily Flight · \(tag)" }
        else if i.firstFlight { overline = "Your first flight" }
        else { overline = "Flight over" }

        let flown = ShareText.distance(i.meters)
        let headline: String
        var chip: String?
        if i.endedEarly {
            headline = "You stopped at \(flown)"
        } else if i.passed >= 1 {
            let name = i.lastPassed.isEmpty ? RouteRules.name(i.passed - 1) : i.lastPassed
            headline = "You made it past \(name)" + (i.newLighthouse ? "!" : "")
            if i.newLighthouse { chip = "New lighthouse" }
        } else {
            headline = "You flew \(flown)"
        }

        let next = Lighthouses.next(afterMeters: i.meters)
        var line = "\(next.name) is \(ShareText.distance(next.metersFurther)) further."
        if i.firstFlight && i.passed == 0 { line += " You'll get there." }
        let m = i.meters.isFinite ? max(i.meters, 0) : 0
        if !i.isNewBest && i.previousBest > 0 && m < i.previousBest && i.previousBest - m <= i.previousBest * 0.10 {
            line = "Just \(ShareText.distance(i.previousBest - m, roundUp: true)) short of your best."
        }
        if i.dailyPractice { line = "Practice doesn't count for today." }
        var lines = [line]
        if i.dailyScored { lines.append("New waves tomorrow.") }
        return ResultsHeadline(overline: overline, headline: headline, chip: chip, lines: lines)
    }
}