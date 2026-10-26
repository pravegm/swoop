import Combine
import CoreGraphics
import Foundation

/// The app's screens (inside the play pose; the pose cards sit above these).
enum AppRoute: String, Equatable {
    /// `daily` = the Daily card (today's flown or spent Daily, UX-A10).
    case home, playing, results, goals, birds, settings, daily
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
    /// Results: Fly again fills with the fold (UX-A3), 0…1.
    @Published var foldFill = 0.0

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

    /// One frame. Returns the hints learned in it (raw values).
    mutating func step(time t: Double, flying: Bool, slope: Double, skimming: Bool, tuck: Double,
                       events: [FlightEvent]) -> [String] {
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
        guard flying else { return newly }
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

    /// The lead meter's fill, 0…1: gap / (headroom × fullLead). Tested.
    static func meterLead(gap: Double, fullLead: Double = Tuning.fullLead, headroom: Double = Tuning.leadMeterScale)
        -> Double {
        guard gap.isFinite, fullLead > 0, headroom > 0 else { return 0 }
        return min(max(gap / (headroom * fullLead), 0), 1)
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
        let km: (Double) -> String = { ShareText.km($0 + 99.999) }
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
        if chain >= 2 { parts.append("chain \(chain)") }
        if lighthouses > 0 { parts.append(lighthouses == 1 ? "1 lighthouse" : "\(lighthouses) lighthouses") }
        return parts.joined(separator: " · ")
    }

    /// The milestone toast's second line.
    static func milestoneLine(_ km: Int) -> String {
        km % 10 == 0 ? "Outflying the storm" : "Still ahead of the storm"
    }

    /// The hint text (UX §2), with the touch words and the mirrored arrows. Tested.
    static func hintText(_ hint: AppHint, touch: Bool, mirrored: Bool) -> String {
        let down = mirrored ? "↙" : "↘"
        let up = mirrored ? "↖" : "↗"
        switch hint {
        case .fold: return touch ? "\(down) Hold on the way down" : "\(down) Fold on the way down"
        case .open: return touch ? "\(up) Let go on the way up" : "\(up) Open on the way up"
        case .land: return "Land on the way down"
        case .storm: return "Perfects push the storm back"
        case .keepBend: return "Keep a little bend"
        }
    }

    /// The countdown's line (UX-A4).
    static func countdownLine(touch: Bool, flat: Bool) -> String {
        if touch { return "Hold to dive · let go to soar" }
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
