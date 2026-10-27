import Combine
import CoreGraphics
import Foundation

/// The app's screens (inside the play pose; the pose cards sit above these).
enum AppRoute: String, Equatable {
    /// `daily` = the Daily card (today's flown or spent Daily, UX-A10). R6: `route` (the Route page), `school` (Flight
    /// School, first Fly and replays), `wingCheck` (the standalone Wing check from Settings or the Home card).
    case home, playing, results, goals, birds, settings, daily, route, school, wingCheck
}

/// Where the tuck comes from this run.
enum AppInputKind: String, Equatable {
    case hinge, touch, autopilot
}

/// First-run hints (UX-A5), each retired by success (`ProgressData.learnedHints` holds the raw values), plus the
/// once-per-run flat reminder.
enum AppHint: String, Hashable {
    case fold, open, land, storm, keepBend
}

/// A short message over the far half (milestones, new best) or the lighthouse name card.
struct HUDToast: Equatable {
    enum Kind: Equatable { case milestone, newBest, lighthouse }
    var kind: Kind
    var title: String
    var detail: String
    var serial: Int
}

/// "Perfect ×N" / "Tailwind!" anchored to the bird where it happened (UX-A1). `point` is in the play view's points
/// (y down, from Scene's `onBirdPoint`); `serial` changes with every callout so the same text re-animates.
struct HUDCallout: Equatable {
    var text: String
    var chain: Int
    var point: CGPoint
    var radius: CGFloat
    var serial: Int
}

/// "×4 lost": a chain of 3+ broken by a splash (UX §3).
struct HUDChainLost: Equatable {
    var chain: Int
    var serial: Int
}

/// "Splash" (and "×4 lost" when a chain of 3+ broke) at the bird (R4 P1-9): the mistake is said where the eye is.
struct HUDSplashMark: Equatable {
    var lostChain: Int?
    /// The bird in the play view's points; nil = the scene hadn't reported it (the view uses its default spot).
    var point: CGPoint?
    var serial: Int
    /// False: a plain landing broke the chain (no splash), so the mark only says "×4 lost" (R5 P1-2).
    var splash: Bool = true

    /// "Splash", "Splash · ×4 lost" or "×4 lost". Pure; tested.
    var text: String {
        let lost = lostChain.flatMap { $0 >= 3 ? "×\($0) lost" : nil }
        if splash { return lost.map { "Splash · \($0)" } ?? "Splash" }
        return lost ?? "Chain lost"
    }
}

/// R6 (UX §4.3): "Gull Point reached!" (with "New on your route" when the route grew).
struct HUDReached: Equatable {
    var index: Int
    var name: String
    var newOnRoute: Bool
    var serial: Int
}

/// What Flight School shows this frame (published only when it changes).
struct SchoolDisplay: Equatable {
    var step: SchoolStep = .hold
    var overline = ""
    var prompt = ""
    var subline: String?
    var praise: String?
    /// R7 P0-2: the teaching line under the praise ("Land on a downslope = Perfect. …").
    var praiseLine: String?
    var dotIndex = 0
    var stepCount = 5
    var canSkip = false
    var offersTouch = false
    var touch = false
    var wingPhase: WingCheckFlow.Phase = .explain
    var wingNeedsFlatHelp = false
    /// R9: the step's ≤ 3 in-world words and where they sit (nil: none).
    var words: String?
    var wordsAnchor: SchoolWordsAnchor = .diagram
    /// When the step began (the diagram's dashed ghost pose plays from it).
    var stepStartedAt: Double = 0
    /// Demo frames: the step's held moment (overrides the clock).
    var frozenElapsed: Double?
    /// R10: the big in-world word ("Perfect") and the diagram's dashed target pose (tuck 0…1).
    var bigWord: String?
    var diagramTarget: Double?
    /// R10 P0-1: step 6's Perfect has pushed the storm back (the meter's knob jumps away).
    var stormPushed = false
    /// The live wing diagram rides the bird (until step 3 has passed).
    var showsDiagram = true
    /// The Studio steps (title bird + diagram) vs the Sea steps (the practice sea).
    var isSea: Bool { step.isSea }
}

/// HUD values, published at ≤ 15 Hz (toasts at once). Separate from GameController so only the HUD redraws.
@MainActor
final class HUDState: ObservableObject {
    @Published var meters = 0
    @Published var callout: HUDCallout?
    @Published var chainLost: HUDChainLost?
    /// A demo freeze holds the frame: transient HUD art (the callout) stays fully on screen for the capture.
    @Published var holdFrame = false
    /// The lead meter's fill (0…1, with headroom).
    @Published var lead = 1.0
    @Published var chain = 0
    @Published var perfects = 0
    /// Tailwind seconds left (0.1 s steps; 0 = none).
    @Published var tailwind = 0.0
    /// 3, 2, 1 during a full countdown; nil after the drop.
    @Published var countdown: Int?
    /// The short (1.5 s) countdown says "Ready" then "Go" (UX-A2).
    @Published var countdownWord: String?
    /// The countdown holds while the Duo lies flat (UX-A4).
    @Published var flatHold = false
    @Published var flying = false
    @Published var stormClose = false
    @Published var caught = false
    @Published var toast: HUDToast?
    @Published var lighthouse: HUDToast?
    @Published var hint: AppHint?
    /// The hint was done: it shows a gold "✓" for 0.6 s.
    @Published var hintDone = false
    /// The bird page's one-time teach line under the meter ("Perfects push the storm back").
    @Published var teachLine: String?
    /// "Best in 0.3 km" (metres to go; nil = not shown).
    @Published var bestIn: Double?
    /// The "Ready" hold after a resume: seconds left (0.1 s steps); nil = none.
    @Published var ready: Double?
    /// The bird's point in the play view (y down) and radius (≤ 15 Hz), for anchoring.
    @Published var birdPoint: CGPoint?
    @Published var birdRadius: CGFloat = 40
    /// Results: Fly again fills with the fold (UX-A3), 0…1, and fold-to-fly is armed (the helper pulses).
    @Published var foldFill = 0.0
    @Published var foldArmed = false
    /// R4 P1-9: the splash word at the bird.
    @Published var splashMark: HUDSplashMark?
    /// R4 P1-7: the first run's one-time "Storm ←→ you" label under the meter.
    @Published var meterLabel = false
    /// R7: one of the first 3 runs (the meter names its danger zone while the storm is in it).
    @Published var meterTeach = false
    /// D4: the chain pill reads "✦ ×2 in a row" on the run that first chains.
    @Published var chainTeach = false
    /// SC3 (App-drawn): step 3's "Faster!" fill (0…1) and step 6's rhythm bar; nil = hidden.
    @Published var schoolFaster: Double?
    @Published var schoolRhythm: SchoolRhythm?
    /// Step 7, 1.6 s after the storm starts rolling in (Scene SC1): the meter and the goal chip fade in.
    @Published var schoolStormHUD = false
    /// R10 P0-1: the school meter's knob jumps away from the storm after step 6's Perfect.
    @Published var schoolStormPushed = false
    /// Scene's `stormRecoil` (0 … 1) while step 6's storm is shoved back.
    @Published var schoolStormRecoil: Double = 0
    /// R10 P0-2: the first real flight's countdown carries the goal sentence.
    @Published var countdownGoal = false
    /// R4 P0-6: the countdown holds with "Open a little wider" (the open angle sits on the floor).
    @Published var openNudge = false
    /// R5 P1-8: the nudge can't be met (a rest under 119°): "Fly with touch" is offered.
    @Published var nudgeOffer = false
    /// The sun's centre in DESIGN canvas points (y up, 8 pt steps), so text can keep off it (R4 P0-3).
    @Published var sunPoint: CGPoint?
    /// SC4: the lighthouse lamp's centre (DESIGN canvas, y up, 8 pt steps) while a tower shows; the reached card dodges it.
    @Published var lampPoint: CGPoint?
    /// R6 (UX §4.2): the goal chip: the next lighthouse's index and the metres left (10 m steps); hidden in the
    /// countdown, in Flight School's early steps and once caught (it freezes).
    @Published var goalIndex = 0
    @Published var goalMetersLeft: Double = 0
    @Published var goalVisible = false
    /// "YOUR GOAL" over the chip on the first real run (5 s).
    @Published var goalOverline = false
    @Published var reached: HUDReached?
    /// The one-time lines on the bird page: the storm line, the Tailwind teach, the flat tip.
    @Published var tipLine: String?
    /// Flight School is flying the practice sea: only the pause shows.
    @Published var schoolSea = false

    func setMeters(_ v: Int) { if meters != v { meters = v } }
    func setLead(_ v: Double) { if lead != v { lead = v } }
    func setChain(_ v: Int) { if chain != v { chain = v } }
    func setPerfects(_ v: Int) { if perfects != v { perfects = v } }
    func setTailwind(_ v: Double) { if tailwind != v { tailwind = v } }
    func setCountdown(_ v: Int?) { if countdown != v { countdown = v } }
    func setCountdownWord(_ v: String?) { if countdownWord != v { countdownWord = v } }
    func setFlatHold(_ v: Bool) { if flatHold != v { flatHold = v } }
    func setFlying(_ v: Bool) { if flying != v { flying = v } }
    func setStormClose(_ v: Bool) { if stormClose != v { stormClose = v } }
    func setCaught(_ v: Bool) { if caught != v { caught = v } }
    func setToast(_ v: HUDToast?) { if toast != v { toast = v } }
    func setLighthouse(_ v: HUDToast?) { if lighthouse != v { lighthouse = v } }
    func setHint(_ v: AppHint?) { if hint != v { hint = v } }
    func setHintDone(_ v: Bool) { if hintDone != v { hintDone = v } }
    func setTeachLine(_ v: String?) { if teachLine != v { teachLine = v } }
    func setBestIn(_ v: Double?) { if bestIn != v { bestIn = v } }
    func setReady(_ v: Double?) { if ready != v { ready = v } }
    func setCallout(_ v: HUDCallout?) { if callout != v { callout = v } }
    func setChainLost(_ v: HUDChainLost?) { if chainLost != v { chainLost = v } }
    func setBirdPoint(_ v: CGPoint?) { if birdPoint != v { birdPoint = v } }
    func setBirdRadius(_ v: CGFloat) { if birdRadius != v { birdRadius = v } }
    func setFoldFill(_ v: Double) { if foldFill != v { foldFill = v } }
    func setFoldArmed(_ v: Bool) { if foldArmed != v { foldArmed = v } }
    func setSplashMark(_ v: HUDSplashMark?) { if splashMark != v { splashMark = v } }
    func setMeterLabel(_ v: Bool) { if meterLabel != v { meterLabel = v } }
    func setMeterTeach(_ v: Bool) { if meterTeach != v { meterTeach = v } }
    func setChainTeach(_ v: Bool) { if chainTeach != v { chainTeach = v } }
    func setSchoolFaster(_ v: Double?) { if schoolFaster != v { schoolFaster = v } }
    func setSchoolRhythm(_ v: SchoolRhythm?) { if schoolRhythm != v { schoolRhythm = v } }
    func setSchoolStormHUD(_ v: Bool) { if schoolStormHUD != v { schoolStormHUD = v } }
    func setSchoolStormPushed(_ v: Bool) { if schoolStormPushed != v { schoolStormPushed = v } }
    func setSchoolStormRecoil(_ v: Double) { if schoolStormRecoil != v { schoolStormRecoil = v } }
    func setCountdownGoal(_ v: Bool) { if countdownGoal != v { countdownGoal = v } }
    func setOpenNudge(_ v: Bool) { if openNudge != v { openNudge = v } }
    func setNudgeOffer(_ v: Bool) { if nudgeOffer != v { nudgeOffer = v } }
    func setSunPoint(_ v: CGPoint?) { if sunPoint != v { sunPoint = v } }
    func setLampPoint(_ v: CGPoint?) { if lampPoint != v { lampPoint = v } }
    func setGoal(index: Int, metersLeft: Double, visible: Bool) {
        if goalIndex != index { goalIndex = index }
        if goalMetersLeft != metersLeft { goalMetersLeft = metersLeft }
        if goalVisible != visible { goalVisible = visible }
    }
    func setGoalOverline(_ v: Bool) { if goalOverline != v { goalOverline = v } }
    func setReached(_ v: HUDReached?) { if reached != v { reached = v } }
    func setTipLine(_ v: String?) { if tipLine != v { tipLine = v } }
    func setSchoolSea(_ v: Bool) { if schoolSea != v { schoolSea = v } }

    func reset() {
        if holdFrame { holdFrame = false }
        setCallout(nil)
        setChainLost(nil)
        setMeters(0)
        setLead(1.0)
        setChain(0)
        setPerfects(0)
        setTailwind(0.0)
        setCountdown(nil)
        setCountdownWord(nil)
        setFlatHold(false)
        setFlying(false)
        setStormClose(false)
        setCaught(false)
        setToast(nil)
        setLighthouse(nil)
        setHint(nil)
        setHintDone(false)
        setTeachLine(nil)
        setBestIn(nil)
        setReady(nil)
        setFoldFill(0)
        setFoldArmed(false)
        setSplashMark(nil)
        setMeterLabel(false)
        setOpenNudge(false)
        setNudgeOffer(false)
        setGoal(index: 0, metersLeft: 0, visible: false)
        setGoalOverline(false)
        setReached(nil)
        setTipLine(nil)
    }
}

/// What the results card shows.
struct ResultSummary: Equatable {
    var result: RunResult
    var outcome: RecordOutcome
    var title: String
    var dailyDay: Int?
    var practice: Bool
    var share: String
    /// The Daily card (Home's Daily button once today's is flown or spent, UX-A10): no goals, Share first.
    var isDailyCard = false
    /// Today's try is spent but nothing was filed (the app died before the first background).
    var dailySpentUnfiled = false
    /// "or fold and open" under Fly again (the first 5 results flown by hinge, UX-A3).
    var showsFoldHelper = false
    /// UX §9 fatigue: "Long flight. Your wings can rest; the Daily will wait."
    var showsRestLine = false
    /// The run was flown by hinge (fold-to-fly again is live).
    var hingeRun = false
    /// R4 P1-13: this Daily is the best of every Daily flown (celebrated when it isn't also a new overall best).
    var dailyBest = false
    /// R6: the first real run after Flight School (its "Next time" tip is the storm one).
    var firstRealRun = false
    /// D4: the Daily row's one-time sub-line is due (captured when the card is built).
    var explainsDaily = false
    /// R9: which flight this was (1 = the first): the tip shows on the first 5 only. 0 = unknown (tests, demos).
    var flightNumber = 0
    /// R9: ended from the cover ("You stopped at 4.2 km", overline "Flight ended").
    var endedEarly = false
}

/// A run paused mid-flight (the cover display's Paused state, UX-D1), built at the pause.
struct PausedRun: Equatable {
    var meters: Double
    /// The storm's distance behind the bird (m).
    var stormMeters: Double
    var perfects: Int
    var chain: Int
    var bestMeters: Double
    var isScoredDaily: Bool
    var day: Int?
    /// R6: "Gull Point in 1.9 km" (the cover), and whether this is Flight School (the cover's "Flight School paused").
    var goalLine: String = ""
    var inSchool = false
}

// MARK: - The hint coach (UX-A5): pure, tested

/// Hints are retired by success, not by a timer or the first Perfect (UX §2):
/// - "Fold on the way down" from the drop; done = a tuck ≥ 0.6 held 0.3 s on a downslope; else it gives up after 4 s
///   and repeats on the next downslope (3 times at most per run).
/// - "Open on the way up" once fold is learned (or exhausted); done = a launch with the tuck ≤ 0.3; same 4 s / 3 tries.
/// - "Land on the way down" once ever, on a splash before any Perfect: 3 s, or until the next Perfect.
/// - "Keep a little bend" once per run after 2 s flat mid-run (the controller drives it).
/// A done hint shows a gold check for 0.6 s.
struct HintCoach: Equatable {
    static let maxTries = 3
    static let timeout: Double = 4.0
    static let doneLinger: Double = 0.6
    static let landSeconds: Double = 3.0
    static let foldHold: Double = 0.3
    static let foldTuck: Double = 0.6
    static let openTuck: Double = 0.3
    static let downslope: Double = -0.05
    static let upslope: Double = 0.06
    static let keepBendSeconds: Double = 3.0

    var learned: Set<String>
    private(set) var current: AppHint?
    private(set) var done = false
    private var shownAt: Double = 0
    private var doneAt: Double = 0
    private var foldTuckSince: Double?
    private var foldTries = 0
    private var openTries = 0
    private var anyPerfect = false
    private var landShownThisRun = false

    init(learned: Set<String>) {
        self.learned = learned
    }

    private func has(_ h: AppHint) -> Bool { learned.contains(h.rawValue) }

    /// Marks a hint learned; true if it wasn't yet.
    private mutating func learn(_ h: AppHint) -> Bool {
        if learned.contains(h.rawValue) { return false }
        learned.insert(h.rawValue)
        return true
    }

    /// One frame. Returns the hints learned in it (raw values). `mayOffer` false (the fold-blur guard, Duo R3 P2-8)
    /// shows no new hint.
    mutating func step(time t: Double, flying: Bool, slope: Double, skimming: Bool, tuck: Double,
                       events: [FlightEvent], mayOffer: Bool = true) -> [String] {
        var newly: [String] = []
        // Events first.
        for event in events {
            switch event {
            case let .touchdown(quality, _, _):
                if quality == .perfect {
                    anyPerfect = true
                    if current == .land { current = nil; done = false }
                } else if quality == .splash && !anyPerfect && !has(.land) && !landShownThisRun
                            && (current == nil || done) {
                    current = .land
                    done = false
                    shownAt = t
                    landShownThisRun = true
                    if learn(.land) { newly.append(AppHint.land.rawValue) }
                }
            case .launched:
                if current == .open && !done && tuck <= Self.openTuck {
                    done = true
                    doneAt = t
                    if learn(.open) { newly.append(AppHint.open.rawValue) }
                }
            default:
                break
            }
        }
        // The hint on screen.
        if let hint = current {
            if done {
                if t - doneAt >= Self.doneLinger { current = nil; done = false }
            } else {
                switch hint {
                case .fold:
                    if tuck >= Self.foldTuck && slope < 0 {
                        let since = foldTuckSince ?? t
                        foldTuckSince = since
                        if t - since >= Self.foldHold {
                            done = true
                            doneAt = t
                            if learn(.fold) { newly.append(AppHint.fold.rawValue) }
                        }
                    } else {
                        foldTuckSince = nil
                    }
                    if !done && t - shownAt > Self.timeout { current = nil; foldTuckSince = nil }
                case .open:
                    if t - shownAt > Self.timeout { current = nil }
                case .land:
                    if t - shownAt > Self.landSeconds { current = nil }
                case .keepBend:
                    if t - shownAt > Self.keepBendSeconds { current = nil }
                case .storm:
                    current = nil
                }
            }
            return newly
        }
        // Nothing on screen: offer the next lesson.
        guard flying && mayOffer else { return newly }
        if !has(.fold) && foldTries < Self.maxTries {
            if slope < Self.downslope {
                current = .fold
                done = false
                shownAt = t
                foldTries += 1
            }
        } else if !has(.open) && openTries < Self.maxTries {
            if skimming && slope > Self.upslope {
                current = .open
                done = false
                shownAt = t
                openTries += 1
            }
        }
        return newly
    }

    /// The once-per-run "Keep a little bend" (shown only over nothing else).
    mutating func showKeepBend(time t: Double) {
        guard current == nil || done else { return }
        current = .keepBend
        done = false
        shownAt = t
    }
}

// MARK: - Fold to fly again (UX-A3): pure, tested

/// On Results, a Duo flying by hinge can fly again with the wings: arm with the wings open (u ≤ 0.2 for 0.5 s, the card
/// up ≥ 0.8 s); Fly again then fills with u; fire on a fold (u ≥ 0.7 held 0.25 s) and an open (u ≤ 0.25) within 2 s.
/// Closing below 95° or shut disarms it.
struct FoldToFly: Equatable {
    enum Phase: Equatable { case idle, armed, folded }

    static let armTuck: Double = 0.2
    static let armHold: Double = 0.5
    static let cardMinAge: Double = 0.8
    static let foldTuck: Double = 0.7
    static let foldHold: Double = 0.25
    static let openTuck: Double = 0.25
    static let openWindow: Double = 2.0

    struct Output: Equatable {
        var fill: Double
        var armedNow: Bool
        var fired: Bool
    }

    private(set) var phase: Phase = .idle
    private var lowSince: Double?
    private var highSince: Double?
    private var foldedAt: Double = 0

    mutating func update(u: Double, now: Double, cardAge: Double, closing: Bool) -> Output {
        let tuck = u.isFinite ? min(max(u, 0), 1) : 0
        if closing {
            self = FoldToFly()
            return Output(fill: 0, armedNow: false, fired: false)
        }
        switch phase {
        case .idle:
            if cardAge >= Self.cardMinAge && tuck <= Self.armTuck {
                let since = lowSince ?? now
                lowSince = since
                if now - since >= Self.armHold {
                    phase = .armed
                    highSince = nil
                    return Output(fill: 0, armedNow: true, fired: false)
                }
            } else {
                lowSince = nil
            }
            return Output(fill: 0, armedNow: false, fired: false)
        case .armed:
            let fill = min(tuck / Self.foldTuck, 1)
            if tuck >= Self.foldTuck {
                let since = highSince ?? now
                highSince = since
                if now - since >= Self.foldHold {
                    phase = .folded
                    foldedAt = now
                }
            } else {
                highSince = nil
            }
            return Output(fill: fill, armedNow: false, fired: false)
        case .folded:
            if tuck <= Self.openTuck {
                self = FoldToFly()
                return Output(fill: 1, armedNow: false, fired: true)
            }
            if now - foldedAt > Self.openWindow {
                self = FoldToFly()
                return Output(fill: 0, armedNow: false, fired: false)
            }
            return Output(fill: 1, armedNow: false, fired: false)
        }
    }
}

// MARK: - The run's own tally (for "End flight" on the cover, which records a run Core hasn't finished)

struct RunTally: Equatable {
    var goods = 0
    var splashes = 0
    var tailwinds = 0
    var cloudTouches = 0
    var maxSpeed: Double = 0
    var maxAltitude: Double = 0
    var lastSplashMeters: Double = 0
    var longestClean: Double = 0
    var lastLighthouse = ""

    mutating func note(_ events: [FlightEvent], snapshot s: FlightSnapshot) {
        if s.speed.isFinite { maxSpeed = max(maxSpeed, s.speed) }
        if s.altitude.isFinite { maxAltitude = max(maxAltitude, s.altitude) }
        for event in events {
            switch event {
            case let .touchdown(quality, _, _):
                if quality == .good { goods += 1 }
                if quality == .splash {
                    splashes += 1
                    longestClean = max(longestClean, s.distanceMeters - lastSplashMeters)
                    lastSplashMeters = s.distanceMeters
                }
            case .tailwindStarted: tailwinds += 1
            case .cloudTouched: cloudTouches += 1
            case let .lighthouse(_, name): lastLighthouse = name
            default: break
            }
        }
    }

    /// The run as it stands, as a result (the player ended it from the cover).
    func result(mode: RunMode, seed: UInt64, snapshot s: FlightSnapshot, bird: BirdID) -> RunResult {
        let meters = s.distanceMeters.isFinite ? max(s.distanceMeters, 0) : 0
        return RunResult(mode: mode, seed: seed, meters: meters, score: s.score, seconds: s.time, perfects: s.perfects,
                         goods: goods, splashes: splashes, bestChain: s.bestChain, tailwinds: tailwinds,
                         lighthouses: s.lighthousesPassed, lastLighthouseName: lastLighthouse,
                         cloudTouches: cloudTouches, maxSpeed: maxSpeed, maxAltitude: maxAltitude,
                         longestCleanMeters: max(longestClean, meters - lastSplashMeters), birdID: bird)
    }
}

// MARK: - Pure rules

/// The controller's pure rules (no actor isolation, so tests call them directly).
enum AppRules {
    /// The driver clamps every frame step to this (ARCHITECTURE).
    static let maxStep: Double = 1.0 / 30.0

    /// dt clamped to 0…1/30 s (a hitch never becomes a teleport). Pure; tested.
    static func clampStep(_ dt: Double) -> Double {
        guard dt.isFinite else { return 0 }
        return min(max(dt, 0), maxStep)
    }

    /// Feedback's continuous inputs for this frame.
    static func telemetry(_ s: FlightSnapshot, playing: Bool) -> FlightTelemetry {
        var flying = false
        if case .flying = s.phase { flying = true }
        return FlightTelemetry(speed: s.speed, tuck: s.tuck, skimming: s.skimming, altitude: s.altitude,
                               tailwind: s.tailwindRemaining > 0, lead: s.lead, playing: playing && flying)
    }

    /// The input for a run (tested): autopilot for the Home loop and demo pilots; touch when forced, in the split deck
    /// or when asked for; the hinge on a Duo; touch everywhere else.
    static func chooseInput(homeLoop: Bool, demoAutopilot: Bool, demoTouch: Bool, hasHinge: Bool,
                            playWithTouch: Bool, touchOverride: Bool, deck: Bool = false) -> AppInputKind {
        if homeLoop || demoAutopilot { return .autopilot }
        if demoTouch || deck { return .touch }
        if hasHinge && !playWithTouch && !touchOverride { return .hinge }
        return .touch
    }

    /// The lead meter's headroom: the gap is drawn against this many full leads (Core's `Tuning.leadMeterScale`).
    static var meterHeadroom: Double { Tuning.leadMeterScale }

    /// The lead meter's fill, 0…1 (R4 P1-7): Scene's `SceneStormMap.meterFill`, sqrt(gap / (leadMeterScale ×
    /// fullLead)), the SAME value that places the storm wall, so the meter and the picture agree. The start (2400 pt)
    /// reads 40 %, storm-close 17 %. UI only: `snapshot.lead` still drives the logic. Tested.
    static func meterLead(gap: Double) -> Double {
        guard gap.isFinite else { return 0 }
        return Double(SceneStormMap.meterFill(gap: gap))
    }

    /// The coral danger zone at the behind end of the meter: Scene's storm-close fill (≈ 0.17).
    static var meterDangerZone: Double { Double(SceneStormMap.closeFill) }

    /// R4 P0-3: the countdown / Ready stage moves to 28 % of the height when the sun's centre is within 160 pt of its
    /// usual place (it already sits on a navy disc; this keeps it off the glare altogether). Pure; tested.
    static let sunClearance: CGFloat = 160
    static func stageCenter(usual: CGPoint, sun: CGPoint?, height: CGFloat) -> CGPoint {
        guard let sun, sun.x.isFinite, sun.y.isFinite else { return usual }
        let dx = sun.x - usual.x
        let dy = sun.y - usual.y
        guard dx * dx + dy * dy < sunClearance * sunClearance else { return usual }
        let high = CGPoint(x: usual.x, y: height * 0.28)
        let low = CGPoint(x: usual.x, y: height * 0.62)
        let dHigh = abs(sun.y - high.y)
        let dLow = abs(sun.y - low.y)
        return dHigh >= dLow ? high : low
    }

    /// R4 P1-8: Perfect's text callout and hit-stop only at chain milestones: 3 (the Tailwind), 5, 10, 15, 20… Tested.
    static func isChainMilestone(_ chain: Int) -> Bool {
        FeedbackDirector.isPerfectMilestone(chain: chain)
    }

    /// Whether a Perfect gets the text callout, the hit-stop and the announcement: a milestone (or the Tailwind that
    /// starts at one), so the picture agrees with Feel's big chime and Scene's punch-in. Tested.
    static func showsPerfectCallout(chain: Int, tailwind: Bool) -> Bool {
        tailwind || isChainMilestone(chain)
    }

    /// The milestone hit-stop: Feel's `FeelSoundBook.hitStop` (60 ms), so the pop and the tap land on its release.
    static let milestoneHitStop: Double = Double(FeelSoundBook.hitStop)
    /// R9 (UX-ROUND-9 §4.4): transient text (lighthouse card, toasts, first-time lines) is never within 80 pt of the
    /// bird's rect (radius 44): if it would be, it moves to the other page's top band under the HUD. Pure; tested.
    static func clearOfBird(center: CGPoint, size: CGSize, bird: CGPoint?, canvas c: AppCanvas,
                            hudBottom: CGFloat) -> CGPoint {
        guard let bird else { return center }
        let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width,
                          height: size.height).insetBy(dx: -80, dy: -80)
        let birdRect = CGRect(x: bird.x - 44, y: bird.y - 44, width: 88, height: 88)
        guard rect.intersects(birdRect) else { return center }
        let onBirdPage = c.birdPage.contains(center)
        let page = onBirdPage ? c.farPage : c.birdPage
        let alt = CGPoint(x: page.midX, y: hudBottom + 8 + size.height / 2)
        let altRect = CGRect(x: alt.x - size.width / 2, y: alt.y - size.height / 2, width: size.width,
                             height: size.height).insetBy(dx: -80, dy: -80)
        if !altRect.intersects(birdRect) { return alt }
        // Both near the bird (a single-page canvas): the opposite vertical half of the screen.
        return CGPoint(x: center.x, y: bird.y > c.size.height / 2 ? hudBottom + 8 + size.height / 2
                                                                    : c.bottom - 12 - size.height / 2)
    }

    /// R10 P0-1: the school meter's knob after step 6's Perfect: a visible jump away from the storm (+0.3). Pure; tested.
    static func schoolMeterLead(_ lead: Double, pushed: Bool, recoil: Double = 0) -> Double {
        let l = lead.isFinite ? min(max(lead, 0), 1) : 0
        // Scene's recoil drives the jump while it lasts; the push flag alone (no scene) jumps it fully.
        let r = recoil.isFinite ? min(max(recoil, 0), 1) : 0
        let kick = r > 0 ? r : (pushed ? 1 : 0)
        return min(l + 0.3 * kick, 1)
    }

    /// R9 (UX-ROUND-9 §4.1): "Daily Flight · 27 Oct", the one way the Daily is named.
    static func dailyTitle(day: Int) -> String { "Daily Flight · \(dailyTag(day: day))" }

    /// D4 one-time explanations (`ProgressData.learnedHints`).
    static let dailyRowHint = "dailyRow"

    /// R4 P1-13: the Daily is numbered from launch day (#1), so day one never reads "#298". The seed is unchanged.
    static var launchDay: Int { DailySeed.launchDay }

    /// The Daily's on-screen tag: its date, "26 Oct", always (R9 glossary, UX-ROUND-9 §4.1: "Daily Flight · 27 Oct",
    /// never "Daily #n" on screen; the share line keeps its "#12" via `dailyNumber`). Pure; tested.
    static func dailyTag(day: Int) -> String {
        var c = DateComponents()
        c.year = 2026
        c.month = 1
        c.day = 1
        c.hour = 12
        guard let epoch = DailySeed.utc.date(from: c),
              let date = DailySeed.utc.date(byAdding: .day, value: day, to: epoch) else { return "#1" }
        let f = DateFormatter()
        f.calendar = DailySeed.utc
        f.timeZone = DailySeed.utc.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    /// The weekday initial ("M", "T"…) of a Daily day number (UTC), for the 7-day dots. Pure; tested.
    static func weekdayInitial(day: Int) -> String {
        var c = DateComponents()
        c.year = 2026
        c.month = 1
        c.day = 1
        c.hour = 12
        guard let epoch = DailySeed.utc.date(from: c),
              let date = DailySeed.utc.date(byAdding: .day, value: day, to: epoch) else { return "" }
        let w = DailySeed.utc.component(.weekday, from: date)
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return letters.indices.contains(w - 1) ? letters[w - 1] : ""
    }

    /// The Daily's display number: day − launch day + 1, at least 1. Tested.
    static func dailyNumber(day: Int, launchDay: Int = AppRules.launchDay) -> Int {
        let n = day.subtractingReportingOverflow(launchDay)
        if n.overflow { return 1 }
        return max(n.partialValue + 1, 1)
    }

    /// The countdown's hold: free, the flat hold ("Bend it a little"), or the low-rest nudge ("Open a little wider").
    enum CountdownHold: Equatable { case free, flat, nudge }

    /// The start tuck above which "Go" never comes (Feel R5 P1-8: never start fully tucked).
    static let maxStartTuck: Double = 0.5

    /// The HUD's published distance: whole metres under 1 km, 100 m steps above (R9: one decimal). The pause and
    /// closing cards show THIS value (R5 P1-3). Pure; tested.
    static func hudMeters(_ distance: Double) -> Int {
        let m = distance.isFinite ? Int(max(distance, 0).rounded(.down)) : 0
        return m < 1000 ? m : (m / 100) * 100
    }

    /// R5 P1-8: what the countdown does this frame. Within the 4 s budget a flat or nudge hold holds. Once spent, a
    /// nudge asks Feel's `lowRestFallback`: `.tooLow` keeps holding and offers "Fly with touch"; anything else lets the
    /// countdown run. On the last step, a start tuck over 0.5 holds it (and offers touch once the budget is spent).
    /// Pure; tested.
    static func countdownGate(raw: CountdownHold, budgetUsed: Double, budget: Double, lowRest: HingeLowRest?,
                              startTuck: Double, remaining: Double, step: Double)
        -> (hold: CountdownHold, offerTouch: Bool) {
        var hold = raw
        var offer = false
        if raw != .free && budgetUsed >= budget {
            if raw == .nudge && lowRest == .tooLow {
                offer = true
            } else {
                hold = .free
            }
        }
        if hold == .free && startTuck.isFinite && startTuck > maxStartTuck && remaining <= step + 1e-6 {
            hold = .nudge
            offer = budgetUsed >= budget
        }
        return (hold, offer)
    }

    /// R4 P0-6: after the Duo was shut (the cover took over), the Ready hold is 2.5 s and starts 0.3 s after the inner
    /// display is back (iOS's handover blur lasts 1–2.5 s). A user pause keeps 1.5 s. Tested.
    static let coverReopenHold: Double = 2.5
    static let coverReopenDelay: Double = 0.3
    static func readyHold(afterCover: Bool, normal: Double) -> Double {
        afterCover ? coverReopenHold + coverReopenDelay : normal
    }

    /// R4 P0-1 (contradicting numbers): the line under each goal row says its scope and, after a run, where this flight
    /// stands, so "Pass 4 lighthouses ✓" never sits unexplained next to "2 lighthouses". Tested.
    /// R7 P0-3: never "159 of 25" (a met target says "Done this flight"), and a ticked row is never captioned with a
    /// this-flight count short of its target (`done`: the row shows as met).
    static func goalCaption(_ goal: Goal, before: Double, run: RunResult?, lifetime: Double, done: Bool = false) -> String {
        if run != nil && before >= 1 { return "Done in an earlier flight" }
        switch goal.kind {
        case .totalMeters:
            return "In total · \(ShareText.distance(lifetime)) of \(ShareText.target(goal.target))"
        case .dailyPlayed:
            return GoalCatalog.dailyRunGoalIDs.contains(goal.id) ? "Fly one while this goal is open" : "Any Daily counts"
        case .speed:
            return "In one flight"
        default:
            guard let run else { return "In one flight" }
            let value: String
            switch goal.kind {
            case .reachMeters: value = ShareText.distance(run.meters)
            case .cleanMeters: value = ShareText.distance(run.longestCleanMeters)
            case .perfectsInRun: value = "\(run.perfects)"
            case .chain: value = "\(run.bestChain)"
            case .lighthouses: value = "\(run.lighthouses)"
            case .cloudTouches: value = "\(run.cloudTouches)"
            case .tailwinds: value = "\(run.tailwinds)"
            default: value = ""
            }
            let amount: Double
            switch goal.kind {
            case .reachMeters: amount = run.meters
            case .cleanMeters: amount = run.longestCleanMeters
            case .perfectsInRun: amount = Double(run.perfects)
            case .chain: amount = Double(run.bestChain)
            case .lighthouses: amount = Double(run.lighthouses)
            case .cloudTouches: amount = Double(run.cloudTouches)
            case .tailwinds: amount = Double(run.tailwinds)
            default: amount = 0
            }
            if amount.isFinite && amount >= goal.target { return "Done this flight" }
            if done { return "Done in an earlier flight" }
            let target = (goal.kind == .reachMeters || goal.kind == .cleanMeters)
                ? ShareText.target(goal.target) : "\(Int(goal.target.rounded()))"
            return "This flight: \(value) of \(target)"
        }
    }

    /// km toasts only every 5 km (UX §3: the 1/2/3 km toasts duplicated the HUD).
    static let milestoneEvery = 5

    /// No km toast this close to a lighthouse (m): the lighthouse card wins.
    static let milestoneLighthouseClearance: Double = 500

    /// Whether a km milestone gets a toast. Tested.
    static func milestoneToasts(km: Int) -> Bool {
        km > 0 && km % milestoneEvery == 0 && !milestoneNearLighthouse(km: km)
    }

    /// Whether the `km` milestone falls within the clearance of any lighthouse. Tested.
    static func milestoneNearLighthouse(km: Int) -> Bool {
        let m = Double(km) * 1000
        for i in 0..<200 {
            let lighthouseMeters = Lighthouses.x(index: i) / Tuning.pointsPerMeter
            if !lighthouseMeters.isFinite { return false }
            if abs(lighthouseMeters - m) <= milestoneLighthouseClearance { return true }
            if lighthouseMeters > m + milestoneLighthouseClearance { return false }
        }
        return false
    }

    /// Hint words: the touch wording unless the hinge flies the bird (or a Duo's autopilot demo). Tested.
    static func touchWording(input: AppInputKind, hasHinge: Bool) -> Bool {
        switch input {
        case .hinge: return false
        case .touch: return true
        case .autopilot: return !hasHinge
        }
    }

    /// "Best in 0.3 km": a Flight within 1 km of a best of at least 1 km (metres to go). Tested.
    static func bestIn(meters: Double, best: Double, isFlight: Bool) -> Double? {
        guard isFlight, best >= 1000, meters.isFinite, best.isFinite else { return nil }
        let left = best - meters
        guard left > 0, left <= 1000 else { return nil }
        return left
    }

    /// The results hook (UX §3): past a lighthouse and short of the next; the first flight names the first lighthouse;
    /// within 10 % of the best, the best wins. Tested.
    static func hookLine(meters: Double, best: Double, previousBest: Double, lighthousesPassed: Int,
                         lastLighthouse: String, seed: UInt64, firstFlight: Bool) -> String? {
        guard meters.isFinite else { return nil }
        let km: (Double) -> String = { ShareText.distance($0, roundUp: true) }
        if !firstFlight && previousBest > 0 && meters < previousBest && previousBest - meters <= previousBest * 0.10 {
            return "\(km(previousBest - meters)) short of your best"
        }
        let nextX = Lighthouses.x(index: max(lighthousesPassed, 0)) / Tuning.pointsPerMeter
        var next: String?
        if nextX.isFinite, nextX > meters {
            let name = Lighthouses.name(index: max(lighthousesPassed, 0), seed: seed)
            next = lighthousesPassed == 0
                ? "\(km(nextX - meters)) short of \(name), the first lighthouse"
                : "\(km(nextX - meters)) short of \(name)"
        }
        let past = lastLighthouse.trimmingCharacters(in: .whitespaces)
        if !past.isEmpty, let next { return "Past \(past) · \(next)" }
        if !past.isEmpty { return "Past \(past)" }
        return next
    }

    /// The results line (zeros dropped): "5 Perfects · chain 3 · 1 lighthouse". Tested.
    static func statsLine(perfects: Int, chain: Int, lighthouses: Int) -> String {
        var parts: [String] = []
        if perfects > 0 { parts.append(ShareText.perfects(perfects)) }
        if chain >= 2 { parts.append("\(chain) in a row") }
        if lighthouses > 0 { parts.append(lighthouses == 1 ? "1 lighthouse" : "\(lighthouses) lighthouses") }
        return parts.joined(separator: " · ")
    }

    /// The milestone toast's second line.
    static func milestoneLine(_ km: Int) -> String {
        km % 10 == 0 ? "Way ahead of the storm" : "Still ahead of the storm"
    }

    /// The hint text (UX §2), with the touch words and the mirrored arrows. Tested.
    static func hintText(_ hint: AppHint, touch: Bool, mirrored: Bool) -> String {
        let down = mirrored ? "↙" : "↘"
        let up = mirrored ? "↖" : "↗"
        switch hint {
        case .fold: return touch ? "\(down) Hold on the way down" : "\(down) Fold on the way down"
        case .open: return touch ? "\(up) Let go on the way up" : "\(up) Open on the way up"
        case .land: return "Land on the way down"
        case .storm: return "Perfect landings push the storm back"
        case .keepBend: return "Keep a little bend"
        }
    }

    /// R10 P0-2: the countdown pill's text: on the first real flight the goal sentence comes first. Pure; tested.
    static func countdownText(touch: Bool, flat: Bool, nudge: Bool, firstFlight: Bool) -> String {
        let line = countdownLine(touch: touch, flat: flat, nudge: nudge)
        return firstFlight && !flat && !nudge ? RouteRules.objective + "\n" + line : line
    }

    /// The countdown's line (UX-A4).
    static func countdownLine(touch: Bool, flat: Bool, nudge: Bool = false) -> String {
        if touch { return "Hold going down · let go going up" }
        if nudge { return "Open a little wider" }
        return flat ? "Bend it a little, like a book" : "Wings open, hold steady"
    }

    /// A short countdown says "Ready" then "Go". The beats sit on Core's own tick schedule
    /// (`FlightSession.countdownTicks`: for 1.5 s, Ready at 0 s and Go at 0.75 s), so a word never falls between two
    /// sounds. Tested.
    static func shortCountdownGoAt(total: Double) -> Double {
        let ticks = FlightSession.countdownTicks(duration: total)
        return ticks.count >= 2 ? ticks[1].at : max(total, 0) / 2
    }

    static func shortCountdownWord(remaining: Double, total: Double) -> String {
        total - remaining >= shortCountdownGoAt(total: total) ? "Go" : "Ready"
    }

    #if DEBUG
    /// Whether an event is the demo `freezeOn` moment (tested).
    static func demoMatches(_ target: DemoConfig.Freeze, _ event: FlightEvent) -> Bool {
        switch (target, event) {
        case (.launch, .launched): return true
        case (.perfect, .touchdown(.perfect, _, _)): return true
        case (.splash, .touchdown(.splash, _, _)): return true
        case (.tailwind, .tailwindStarted): return true
        case (.lighthouse, .lighthouse): return true
        case (.stormclose, .stormClose): return true
        case (.caught, .caught): return true
        case (.finished, .finished): return true
        default: return false
        }
    }
    #endif
}

// MARK: - Contrast over the live scene (R4 P0-3): pure, tested

/// WCAG 2 contrast, used to pick the scrims behind text that sits over the sky and the sun.
enum Contrast {
    /// The brightest thing text can sit on: the sun's core (`#FFF3C4`).
    static let brightestSky: UInt32 = 0xFFF3C4
    /// The scrim behind the Ready ring, the countdown and their lines: navy `#0B2236` at 0.62 (4.5 : 1 for foam text
    /// over the sun's core; the 0.55 asked for reads ~3.8 : 1).
    static let scrim: UInt32 = 0x0B2236
    static let scrimAlpha: Double = 0.62
    /// Overlay surfaces (hint pill, toasts, the lighthouse card): solid navy at 0.8 (no backdrop tint).
    static let surfaceAlpha: Double = 0.8

    static func channel(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    static func rgb(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static func luminance(_ c: (Double, Double, Double)) -> Double {
        0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
    }

    /// `top` at `alpha` over `bottom` (sRGB blending, as the compositor does).
    static func blend(_ top: UInt32, alpha: Double, over bottom: UInt32) -> (Double, Double, Double) {
        let a = min(max(alpha, 0), 1)
        let t = rgb(top)
        let b = rgb(bottom)
        return (t.0 * a + b.0 * (1 - a), t.1 * a + b.1 * (1 - a), t.2 * a + b.2 * (1 - a))
    }

    static func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Foam (or any `text`) on the scrim over the brightest sky.
    static func overSun(text: UInt32, scrimAlpha: Double = Contrast.scrimAlpha) -> Double {
        ratio(rgb(text), blend(scrim, alpha: scrimAlpha, over: brightestSky))
    }
}

/// Step 6's rhythm bar (SC3): which of the 3 practice waves the bird is over, how far along it (0 = the trough before,
/// 0.5 = the crest, 1 = the wave's trough), and the eased tuck for the cursor's colour.
struct SchoolRhythm: Equatable {
    var wave: Int
    var fraction: Double
    var tuck: Double
}