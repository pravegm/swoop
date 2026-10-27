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

/// R12 P0-1: words never name a target that isn't there. "Land in the gold ring", "Land here" and every pointer to a
/// ring show only while that ring is FULLY on screen and AHEAD of the bird (in the flight direction: +x, or −x when the
/// flight is mirrored). Scene reports `ringScreenRect` only for a ring ahead and on screen; this checks both again
/// against the bird, so a ring behind or half off an edge never gets words. Pure; tested.
enum SchoolRingRule {
    /// The ring (and its drop marker) must sit this far inside the screen edges to count as on screen.
    static let edgeMargin: CGFloat = 0

    static func ringInView(_ ring: CGRect?, bird: CGPoint, screen: CGSize, mirrored: Bool) -> Bool {
        guard let r = ring, !r.isNull, !r.isInfinite, r.width > 0, r.height > 0,
              r.minX.isFinite, r.minY.isFinite, r.maxX.isFinite, r.maxY.isFinite,
              bird.x.isFinite, screen.width > 0, screen.height > 0 else { return false }
        let bounds = CGRect(origin: .zero, size: screen).insetBy(dx: edgeMargin, dy: edgeMargin)
        guard bounds.contains(r) else { return false }
        return mirrored ? r.midX < bird.x : r.midX > bird.x
    }
}

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
    /// R12 P0-3: the bird's sea x (how far down the face it has gone); nil when unknown.
    var seaX: Double? = nil
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
        /// R10: step 6's Perfect pushed the storm back this frame (the meter's jump, Feel's cue).
        var pushed = false
    }

    // Timings (UX §1.1, §1.2).
    static let minPromptSeconds: Double = 1.2
    /// R9 (UX-ROUND-9 §1.1): each step first shows the move (the ghost and the diagram), then waits for the player.
    static let ghostDemoSeconds: Double = 1.8
    /// R9: no praise words; the world answers, then moves on.
    static let praiseSeconds: Double = 0.5
    /// R9 step 6: the Perfect in the storm's guided ring passes it; this long passes it anyway.
    static let stormPassAfter: Double = 15
    /// R11 P0-6: the storm step is never empty: the storm rolls in during the rhythm step's success (its praise holds
    /// `FlightSchoolCopy.praiseSeconds(.rhythm)`), so the storm, its meter and "Stay ahead" are there from frame one.
    static let stormWordsAfter: Double = 0
    /// R11: "Stay ahead" for this long, then "Land in the gold ring" by the ring.
    static let stormRingWordsAfter: Double = 3
    static let stormPushHold: Double = 2.4
    static let touchOfferAfter: Double = 10
    static let idleHelpAfter: Double = 6
    static let maxFails = 3
    static let stormLineSeconds: Double = 2.2
    static let rhythmSwapAfter: Double = 2.5
    /// R12 P0-3: a missed dive's words hold this long where the bird is (past the trough) before the rewind, so the
    /// miss is said after the dive, never back on the crest.
    static let missRewindDelay: Double = 1.2
    /// R12 P0-3: the wings opening early is seen once the bird, folded, has skimmed this far down the face (sea pt; the
    /// tutorial face runs 1500 pt from crest A to the trough). Never on the crest itself.
    static let earlyOpenAfter: Double = 300
    /// R12 P0-3: miss words not followed by Core's verdict (a face too short to judge) clear after this long.
    static let missWordsMax: Double = 3

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
    /// R10: Skip is there from the first step (tester 10 looked for it on step 1).
    private(set) var canSkip = true
    /// R10 P0-1: when step 6's Perfect pushed the storm back (the words and the meter's jump hold for a moment).
    private(set) var pushedAt: Double?
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
    /// R12 P0-3: when this attempt's miss was seen (the wings opened partway down the face, or Core's verdict at the
    /// trough); the miss words show from then until the rewind. nil: no miss to say (the bird is on the crest).
    private(set) var missedAt: Double?
    /// R12 P0-3: the deferred rewind after a missed dive (the words first, then back to the crest).
    private(set) var rewindAt: Double?
    /// Demo `dive:fail`: the miss words are held for the frame.
    private var missHeld = false
    /// Sea x where the folded bird started down this face (nil: not folded on a face yet).
    private var faceStartX: Double?
    /// Without a sea x (the plain-Flight fallback): the folded time on the face, in its place.
    private var faceTime: Double = 0
    /// Demo `school=<step>:demo|turn|fail`: the frame's moment in the step, held (the ghost demonstrating, or the
    /// player's turn).
    private(set) var frozenElapsed: Double?

    init(touch: Bool, tapping: Bool = false, asksWingCheck: Bool) {
        self.touch = touch
        self.tapping = tapping
        self.asksWingCheck = asksWingCheck && !touch
    }

    /// R11 P1-12: one count, the same on the Duo and the iPhone: 5 dots. "Hold" folds into Wings (dot 1), "Up and land"
    /// is one dot (soar + land), and the Duo's clear-side check is a question, not a lesson: it carries no dot (the
    /// dots hide while it is asked), so they never jump from 1 to 3.
    var stepCount: Int { 5 }

    /// The dot of the current step. Pure; tested.
    var dotIndex: Int {
        switch stepNow {
        case .hold, .wings, .wingCheck: return 0
        case .dive: return 1
        case .soar, .land: return 2
        case .rhythm: return 3
        case .storm: return 4
        }
    }

    /// R11 P1-12: the dots show on every lesson step (not during the clear-side check).
    var showsDots: Bool { stepNow != .wingCheck }

    /// VoiceOver only (R9 cut the visible overline): "Flight School, step 3 of 5".
    var overline: String {
        stepNow == .wingCheck ? "Flight School, one quick check" : "Flight School, step \(dotIndex + 1) of \(stepCount)"
    }

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

    /// R9: the step's in-world words (≤ 4, no full stop; "Land in the gold ring" is the one 5-word name) and where
    /// they sit; nil = none. R11 P0-3: the rule comes before the miss ("Fold down the wave"), and the diagram's words
    /// always sit under the diagram. R12 P0-1: words that name a ring ("Land here", "Land in the gold ring") only while
    /// that ring is fully on screen and ahead of the bird (`ringInView`, from `SchoolRingRule`); otherwise the step's
    /// other words, never anchored to a ring. Pure; tested.
    func words(at time: Double, ringInView: Bool = true) -> (text: String, anchor: SchoolWordsAnchor)? {
        guard let w = ringWords(at: time) else { return nil }
        guard w.anchor == .ring, !ringInView else { return w }
        return noRingWords(at: time)
    }

    /// R12 P0-1: what a ring step says while its ring is not (yet, or any more) on screen ahead of the bird: the storm
    /// step "Stay ahead" by the meter; the land step tells the wings to wait (open to glide). Pure; tested.
    func noRingWords(at time: Double) -> (text: String, anchor: SchoolWordsAnchor)? {
        switch stepNow {
        case .land:
            return (tapping ? "Glide" : (touch ? "Let go to glide" : "Open to glide"), .spot)
        case .storm:
            return ("Stay ahead", .meter)
        default:
            return nil
        }
    }

    /// R12 P0-3: the miss words show (the bird has gone down the face and opened early), until the rewind.
    func showsMiss(at time: Double) -> Bool {
        guard stepNow == .dive else { return false }
        if missHeld { return true }
        guard let m = missedAt else { return false }
        return rewindAt != nil || time - m < Self.missWordsMax
    }

    /// The step's words with a ring in view (R11's table).
    private func ringWords(at time: Double) -> (text: String, anchor: SchoolWordsAnchor)? {
        let e = elapsed(at: time)
        guard phase == .prompt else { return nil }
        switch stepNow {
        case .hold:
            // R11: the iPhone's first step says what to do too (tester 15 thought it had frozen).
            return (touch ? "Hold it sideways" : "Hold it open", .diagram)
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
            // R10: a miss says what happened ("Opened too soon"); R11: its remedy is the muted second line. R12 P0-3:
            // only once the bird has gone down the face and opened early, until the rewind; back on the crest the
            // rule shows again, with the remedy under it.
            if showsMiss(at: time) {
                return (tapping ? "Tapped too soon" : (touch ? "Let go too soon" : "Opened too soon"), .diagram)
            }
            return (tapping ? "Tap at the top" : (touch ? "Hold down the wave" : "Fold down the wave"), .diagram)
        case .soar:
            return (tapping ? "Tap again" : (touch ? "Let go" : "Open"), .diagram)
        case .land:
            return ("Land here", .ring)
        case .rhythm:
            // R10: one cue on the rhythm step, in plain words.
            return e < 4 ? (touch ? "One hold per wave" : "One fold per wave", .spot) : nil
        case .storm:
            // R11 P0-6: the storm and its meter are there from the first frame, and so are the words; P0-7: the
            // Perfect's push is said by the meter it moves; P1-10: never "Stay ahead" twice in a row.
            if pushedAt != nil { return ("Perfect pushes it back", .meter) }
            if e < Self.stormWordsAfter { return nil }
            return e < Self.stormRingWordsAfter ? ("Stay ahead", .meter) : ("Land in the gold ring", .ring)
        }
    }

    /// R11 P0-3: the muted second line under the words: the rhythm on the first move ("One fold per wave"), when to
    /// open once the ghost has shown the dive, the remedy after a miss, and what the finger does to land. ≤ 7 words, no
    /// full stop. Pure; tested.
    func subWords(at time: Double, ringInView: Bool = true) -> String? {
        guard phase == .prompt, let w = words(at: time, ringInView: ringInView) else { return nil }
        let e = elapsed(at: time)
        // R12 P0-1: the land step's waiting words have no second line (it would ask to come down before the ring).
        if stepNow == .land && w.anchor != .ring { return nil }
        switch stepNow {
        case .wings:
            if tapping || folded { return nil }
            return touch ? "One hold per wave" : "One fold per wave"
        case .dive:
            if missedOnce || showsMiss(at: time) {
                return tapping ? "Tap again at the bottom" : (touch ? "Keep holding to the bottom" : "Stay folded to the bottom")
            }
            guard e >= Self.ghostDemoSeconds else { return nil }
            return tapping ? "Tap again at the bottom" : (touch ? "Let go at the bottom" : "Open at the bottom")
        case .land:
            return tapping ? "Tap to come down" : (touch ? "Hold to come down" : "Fold to come down")
        case .hold, .wingCheck, .soar, .rhythm, .storm:
            return nil
        }
    }

    /// R11 P0-7: the school meter's lead this frame: after step 6's Perfect it jumps away from the storm (Scene's
    /// recoil while it lasts, the push itself without a scene). Pure; tested (live: a Perfect raises it).
    func meterLead(_ lead: Double, recoil: Double = 0) -> Double {
        let pushed = stepNow == .storm && pushedAt != nil
        return AppRules.schoolMeterLead(lead, pushed: pushed, recoil: stepNow == .storm ? recoil : 0)
    }

    /// R11 P0-6: the storm is (or is rolling) in: the storm step itself, and the rhythm step's success before it (the
    /// roll-in plays in the transition). Also true for a school started at the storm step (demo, replays). Pure; tested.
    var stormRollsIn: Bool { stepNow == .storm || (stepNow == .rhythm && phase == .praise) }

    /// R11 P0-7: the meter's "+" gap pop shows while the push holds. Pure; tested.
    var showsGapPop: Bool { stepNow == .storm && pushedAt != nil }

    /// The live diagram rides the bird until step 3 (Down) has passed (UX-ROUND-9 §1.1 rule 6).
    /// R10 P0-3: the one diagram shows for the moves it can show (hold, wings, dive, soar) and always draws the pose its
    /// words ask for as the dashed target (`diagramTarget`); never on the clear-side, land, rhythm or storm steps.
    var showsDiagram: Bool { [.hold, .wings, .dive, .soar].contains(stepNow) }

    /// The pose the step's words ask for (tuck 0 open … 1 folded): "Hold it open" shows the open book, "Fold a little"
    /// the folded target, "Now open" the open one again. Pure; tested.
    var diagramTarget: Double? {
        switch stepNow {
        case .hold: return 0
        case .wings: return folded ? 0 : 1
        case .dive: return 1
        case .soar: return 0
        case .wingCheck, .land, .rhythm, .storm: return nil
        }
    }

    /// R12 P0-4: the pose a step's done state draws (filled, with the tick): the one its words asked for ("Hold it
    /// open" open, "Fold a little" the 135° fold), never a deeper fold the player (or the demo) made. Pure; tested.
    static func doneTarget(_ step: SchoolStep) -> Double? {
        switch step {
        case .hold, .soar: return 0
        case .wings, .dive: return 1
        case .wingCheck, .land, .rhythm, .storm: return nil
        }
    }

    /// R10 P0-1: the big in-world word of a moment: "Perfect" when step 4 lands it, and as step 6's Perfect pushes the
    /// storm back.
    var bigWord: String? {
        if stepNow == .land && phase == .praise { return "Perfect" }
        if stepNow == .storm && pushedAt != nil { return "Perfect" }
        return nil
    }

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
        missedAt = nil
        rewindAt = nil
        missHeld = false
        faceStartX = nil
        faceTime = 0
        pushedAt = nil
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
            // R12 P0-3: the frame is the bird partway down the face with its wings opened (the demo's early-open
            // tuck, `GameController.demoEarlyOpenTuck`), the miss words held.
            subline = FlightSchoolCopy.failure(stepNow, touch: touch)
            missedOnce = true
            missedAt = time
            missHeld = true
            frozenElapsed = Self.ghostDemoSeconds + 1
        case "push":
            // R10: step 6 at the moment its Perfect pushes the storm back.
            pushedAt = time
            frozenElapsed = 4
        case "demo":
            frozenElapsed = Self.ghostDemoSeconds * 0.5
        case "turn":
            frozenElapsed = Self.ghostDemoSeconds + 1
            if stepNow == .wings { folded = false }
        case "1", "2", "3":
            // R7: the storm step's moments as held frames. R11: 1 = its first frame (the storm in, "Stay ahead" by
            // the meter), 2 = Gull Point risen ("Land in the gold ring" by the ring), 3 = the ring ahead.
            let k = min(max(Int(key) ?? 1, 1), 3)
            let at: [Double] = [0.3, Self.stormRingWordsAfter + 0.4, Self.stormRingWordsAfter + 2.4]
            stepStartedAt = time - at[k - 1]
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
        // R12 P0-3: a missed dive's words have been said where the bird is; now back to the crest, with the rule.
        if let r = rewindAt, t >= r {
            rewindAt = nil
            missedAt = nil
            faceStartX = nil
            faceTime = 0
            out.rewind = true
        } else if rewindAt == nil, let m = missedAt, t - m >= Self.missWordsMax {
            missedAt = nil
        }

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
            // Founder's Duo test (27 Oct): a deep fold is fine (it just holds full tuck); warn only near the closing pause.
            if let a = input.angle, !touch, a < FeelClosingGate.closeBelow + 10 {
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
            watchFace(input, tuck: u, dt: dt, time: t)
            for sig in input.signals {
                if case let .diveDone(fraction) = sig { judgeDive(fraction, time: t, out: &out) }
            }
        case .dive:
            watchFace(input, tuck: u, dt: dt, time: t)
            if input.flying && input.skimming && input.slope < -0.05 {
                onDownslope = true
                downTime += dt
                if u >= 0.6 { heldTime += dt }
            } else if onDownslope && (input.slope >= 0 || !input.skimming) {
                onDownslope = false
                if downTime >= 0.3 { judgeDive(downTime > 0 ? heldTime / downTime : 0, time: t, out: &out) }
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
            // R10 P0-1: the Perfect pushes the storm back; its words and the meter's jump hold for 2.4 s, then on.
            var perfect = false
            for sig in input.signals { if case let .landed(q) = sig { landAttempts += 1; if q == .perfect { perfect = true } } }
            for e in input.events where !input.practice { if case let .touchdown(q, _, _) = e { landAttempts += 1; if q == .perfect { perfect = true } } }
            if perfect && pushedAt == nil {
                pushedAt = t
                out.pushed = true
            }
            if let p = pushedAt, t - p >= Self.stormPushHold { pendingSuccess = true }
            if pushedAt == nil && (landAttempts >= Self.maxFails || elapsed >= Self.stormPassAfter) { pendingSuccess = true }
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
    /// R12 P0-3: the miss words show now, at the trough the bird has reached, and the rewind waits
    /// `missRewindDelay` so they are never first read back on the crest.
    private mutating func judgeDive(_ fraction: Double, time t: Double, out: inout Output) {
        guard !pendingSuccess, rewindAt == nil else { return }
        if fraction >= 0.7 {
            missedAt = nil
            pendingSuccess = true
            return
        }
        fails += 1
        missedOnce = true
        if missedAt == nil { missedAt = t }
        if fails >= Self.maxFails {
            subline = "Good enough. Let's fly."
            pendingSuccess = true
        } else {
            subline = FlightSchoolCopy.failure(.dive, touch: touch)
            rewindAt = t + Self.missRewindDelay
        }
    }

    /// R12 P0-3: the wings opened early, seen on the face itself: folded off the crest, then open (< 0.3) once the bird
    /// has gone `earlyOpenAfter` pt down the face (0.5 s folded without a sea x). Never on the crest: the distance only
    /// counts from where the folded bird started down.
    private mutating func watchFace(_ input: SchoolInput, tuck u: Double, dt: Double, time t: Double) {
        guard rewindAt == nil, missedAt == nil else { return }
        if input.skimming && input.slope < -0.05 {
            if faceStartX == nil && u >= 0.6 {
                faceStartX = input.seaX ?? 0
                faceTime = 0
            }
            guard let start = faceStartX else { return }
            faceTime += dt
            let down = input.seaX.map { $0 - start } ?? (faceTime >= 0.5 ? Self.earlyOpenAfter : 0)
            if u < 0.3 && down >= Self.earlyOpenAfter { missedAt = t }
        } else if input.slope >= 0 {
            faceStartX = nil
            faceTime = 0
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
            return "Land in the gold ring."
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
    /// R10 P0-1: the land step's Perfect holds long enough to read; others move on. R11 P0-6: the rhythm step's success
    /// holds while the storm rolls in, so the storm step opens with the storm, its meter and its words on screen.
    static func praiseSeconds(_ step: SchoolStep) -> Double {
        switch step {
        case .land: return 1.4
        case .rhythm: return rhythmToStormSeconds
        default: return FlightSchool.praiseSeconds
        }
    }

    /// The rhythm → storm transition (Scene's roll-in takes 2 s; most of it plays here).
    static let rhythmToStormSeconds: Double = 1.6
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
        /// R11 P1-10: how many of them were new on the route ("2 new lighthouses"); 0 = unknown (one, if new).
        var newLighthouses = 0
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
            // R10 P0-4: every lighthouse passed is counted ("…past Saltlight" left Gull Point out).
            let name = i.lastPassed.isEmpty ? RouteRules.name(i.passed - 1) : i.lastPassed
            let what: String
            switch i.passed {
            case 1: what = name
            case 2: what = "\(RouteRules.name(0)) and \(name)"
            default: what = "\(i.passed) lighthouses, to \(name)"
            }
            headline = "You made it past \(what)" + (i.newLighthouse ? "!" : "")
            if i.newLighthouse { chip = Self.newChip(count: i.newLighthouses) }
        } else {
            headline = "You flew \(flown)"
        }

        // R11 P0-2 / P1-10: the one quiet line says WHY the flight ended ("The storm caught you 2.2 km before Kestrel
        // Head."); the "… is 2.2 km further." line repeated the tracker above it and is gone. A flight ended from the
        // cover has no cause to tell (the tracker says the rest).
        let next = Lighthouses.next(afterMeters: i.meters)
        var lines: [String] = []
        if i.dailyPractice {
            lines.append("Practice doesn't count for today.")
        } else if !i.endedEarly {
            var line = "The storm caught you \(ShareText.distance(next.metersFurther)) before \(next.name)."
            if i.firstFlight && i.passed == 0 { line += " You'll get there." }
            let m = i.meters.isFinite ? max(i.meters, 0) : 0
            if !i.isNewBest && i.previousBest > 0 && m < i.previousBest && i.previousBest - m <= i.previousBest * 0.10 {
                line = "The storm caught you \(ShareText.distance(i.previousBest - m, roundUp: true)) short of your best."
            }
            lines.append(line)
        }
        if i.dailyScored { lines.append("New waves tomorrow.") }
        return ResultsHeadline(overline: overline, headline: headline, chip: chip, lines: lines)
    }

    /// "New lighthouse", or "2 new lighthouses" when more than one was new. Pure; tested.
    static func newChip(count: Int) -> String {
        count >= 2 ? "\(count) new lighthouses" : "New lighthouse"
    }
}