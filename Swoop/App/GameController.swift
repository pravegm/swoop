import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The app's screens (inside the play pose; the pose cards sit above these).
enum AppRoute: String, Equatable {
    case home, playing, results, goals, birds, settings
}

/// Where the tuck comes from this run.
enum AppInputKind: String, Equatable {
    case hinge, touch, autopilot
}

/// First-run hints (GAME-DESIGN §9): shown once each per run until the first Perfect, then never again.
enum AppHint: String, Equatable {
    case fold, open
}

/// A short message over the far half (milestones, new best) or the lighthouse name card.
struct HUDToast: Equatable {
    enum Kind: Equatable { case milestone, newBest, lighthouse }
    var kind: Kind
    var title: String
    var detail: String
    var serial: Int
}

/// HUD values, published at ≤ 15 Hz (toasts at once). Separate from GameController so only the HUD redraws.
@MainActor
final class HUDState: ObservableObject {
    @Published var meters = 0
    @Published var lead = 1.0
    @Published var chain = 0
    @Published var perfects = 0
    /// Tailwind seconds left (0.1 s steps; 0 = none).
    @Published var tailwind = 0.0
    /// 3, 2, 1 during the countdown; nil after the drop.
    @Published var countdown: Int?
    @Published var flying = false
    @Published var stormClose = false
    @Published var caught = false
    @Published var toast: HUDToast?
    @Published var lighthouse: HUDToast?
    @Published var hint: AppHint?
    /// The "Ready" hold after a resume: seconds left (0.1 s steps); nil = none.
    @Published var ready: Double?

    // Setters that publish only on a change (explicit, no key paths: nothing to trip Swift 6-style isolation checks).
    func setMeters(_ v: Int) { if meters != v { meters = v } }
    func setLead(_ v: Double) { if lead != v { lead = v } }
    func setChain(_ v: Int) { if chain != v { chain = v } }
    func setPerfects(_ v: Int) { if perfects != v { perfects = v } }
    func setTailwind(_ v: Double) { if tailwind != v { tailwind = v } }
    func setCountdown(_ v: Int?) { if countdown != v { countdown = v } }
    func setFlying(_ v: Bool) { if flying != v { flying = v } }
    func setStormClose(_ v: Bool) { if stormClose != v { stormClose = v } }
    func setCaught(_ v: Bool) { if caught != v { caught = v } }
    func setToast(_ v: HUDToast?) { if toast != v { toast = v } }
    func setLighthouse(_ v: HUDToast?) { if lighthouse != v { lighthouse = v } }
    func setHint(_ v: AppHint?) { if hint != v { hint = v } }
    func setReady(_ v: Double?) { if ready != v { ready = v } }

    func reset() {
        setMeters(0)
        setLead(1.0)
        setChain(0)
        setPerfects(0)
        setTailwind(0.0)
        let none: Int? = nil
        setCountdown(none)
        setFlying(false)
        setStormClose(false)
        setCaught(false)
        let noToast: HUDToast? = nil
        setToast(noToast)
        setLighthouse(noToast)
        let noHint: AppHint? = nil
        setHint(noHint)
        let noReady: Double? = nil
        setReady(noReady)
    }
}

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

    /// The input for a run (tested): autopilot for the Home loop and demo pilots; touch when forced; the hinge on a Duo
    /// unless the player asked for touch; touch everywhere else.
    static func chooseInput(homeLoop: Bool, demoAutopilot: Bool, demoTouch: Bool, hasHinge: Bool,
                            playWithTouch: Bool, touchOverride: Bool) -> AppInputKind {
        if homeLoop || demoAutopilot { return .autopilot }
        if demoTouch { return .touch }
        if hasHinge && !playWithTouch && !touchOverride { return .hinge }
        return .touch
    }

    /// The milestone toast's second line.
    static func milestoneLine(_ km: Int) -> String {
        switch km {
        case 1: return "Keep the rhythm"
        case 2: return "The swells are growing"
        case 3: return "A lighthouse ahead"
        default: return km % 5 == 0 ? "Outflying the storm" : "Still ahead of the storm"
        }
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

/// What the results card shows.
struct ResultSummary: Equatable {
    var result: RunResult
    var outcome: RecordOutcome
    var title: String
    var dailyDay: Int?
    var practice: Bool
    var share: String
}

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): FlightScene.update → advance(dt:now:) → tuck source →
/// FlightSession.step → FeedbackDirector → HUD. Owns the session, the scene, the tuck sources and the app's route.
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: Hashable { case user, closing, background, pose }

    // MARK: Tuning (named so they're easy to find and tune)

    /// HUD publishing rate cap.
    static let hudInterval: Double = 1.0 / 15.0
    /// After any resume (reopening the Duo, the pause card, the app coming back) the bird holds this long under a
    /// "Ready" ring, so the flight never restarts by surprise.
    static let readyHold: Double = 1.5
    /// Caught → finished takes 1.8 s in Core; the card then follows after this short beat.
    static let resultsDelay: Double = 0.45
    /// The Duo counts as shut (cover display) at or below this hinge angle, and open again from the release angle.
    static let shutBelow: Double = 10
    static let shutReleaseAbove: Double = 15
    /// Home: a fold this far below the calibrated open angle counts as "they folded" (caption changes).
    static let homeFoldDegrees: Double = 18
    /// How long the lighthouse card and the toasts stay up (session seconds).
    static let lighthouseCardSeconds: Double = 2.8
    static let toastSeconds: Double = 1.8
    /// First-run hints: "Open to fly" waits at least this long after "Fold on the way down", and shows by this time at
    /// the latest; each hint then stays up for `hintSeconds`.
    static let openHintMinDelay: Double = 1.2
    static let openHintMaxDelay: Double = 6.0
    static let hintSeconds: Double = 3.0
    /// Climbing a swell's face faster than this slope (dh/dx) while skimming is "the first crest".
    static let crestSlope: Double = 0.06
    /// The lead meter's storm-close threshold (GAME-DESIGN §6: 15 %).
    static let stormCloseLead: Double = 0.15

    // MARK: Published state (changes rarely; the HUD lives in `hud`)

    @Published private(set) var route: AppRoute = .home
    @Published private(set) var scene: FlightScene?
    @Published private(set) var sceneGeneration = 0
    /// A hinge has reported this launch (or on an earlier launch of this Duo).
    @Published private(set) var hingeSeen: Bool
    /// The Duo is shut (hinge ≤ 10°, released at ≥ 15°).
    @Published private(set) var isShut = false
    @Published private(set) var input: AppInputKind = .autopilot
    @Published private(set) var isUserPaused = false
    /// The run paused itself because the Duo is closing (< 95°): "Open your wings to keep flying".
    @Published private(set) var isClosingPaused = false
    @Published private(set) var summary: ResultSummary?
    /// Home: the player has folded the Duo (or held the screen) at least once: "Fold to dive. Open to soar."
    @Published private(set) var homeFolded = false
    /// "Play with touch" chosen on the pose card (this app session only).
    @Published private(set) var touchOverride = false
    @Published private(set) var mode: RunMode = .attract
    /// The Home attract loop is running (Home, Flocks, Birds, Settings sit over it).
    @Published private(set) var homeLoop = true
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose` forces the pose card.
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon` shows the app icon full screen.
    @Published private(set) var showsIconExport = false

    let hud: HUDState
    let store: ProgressStore
    let settings: SettingsStore
    let hinge: HingeTuckSource
    let touch: TouchTuckSource
    private let feedback: FeedbackDirector
    private var autopilot: AutopilotTuckSource?

    private var session: FlightSession?
    private var layout: ScreenLayout?
    private var pauseReasons: Set<PauseReason> = []
    private var readyUntil: TimeInterval?
    private var reduceMotion = false

    // Loop bookkeeping
    private var frameCount = 0
    private var lastHUDPublish: TimeInterval = -1
    private var recordedFinish = false
    /// Session time of the drop (`started`); nil before it.
    private var flightStart: Double?
    private var toastSerial = 0
    private var toastUntil = 0.0
    private var lighthouseUntil = 0.0
    private var hintsActive = false
    private var foldHintAt: Double?
    private var openHintAt: Double?
    private var resultsTask: Task<Void, Never>?
    private var screenKeptAwake = false
    private var scoredDailyDay: Int?
    private var runBird: BirdID = .gull
    private var runSky: SkyID = .goldenHour
    private var lastCanvasLine = ""
    /// Demo freeze: the session no longer steps (the scene keeps drawing the held frame).
    private(set) var frozen = false

    #if DEBUG
    let demo: DemoConfig?
    private var freezePendingAt: Double?
    #endif

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.hud = HUDState()
        self.hinge = HingeTuckSource()
        self.touch = TouchTuckSource()
        self.feedback = FeedbackDirector.shared
        #if DEBUG
        self.demo = DemoConfig.current
        #endif
        // `swoop.hasHinge` comes back with a backup restored onto another iPhone: believe it only on a Duo-shaped screen.
        let stored = UserDefaults.standard.bool(forKey: OrientationLock.hingeKey)
        let trusted = OrientationLock.trustsStoredHinge(stored, screen: UIScreen.main.bounds.size)
        if stored && !trusted { UserDefaults.standard.removeObject(forKey: OrientationLock.hingeKey) }
        self.hingeSeen = trusted
        self.runBird = store.activeBird
        self.runSky = store.activeSky
    }

    // MARK: - Derived

    var isDemo: Bool {
        #if DEBUG
        return demo != nil
        #else
        return false
        #endif
    }

    /// "Bird on the other side" (Settings), or demo `mirror`.
    var effectiveMirrored: Bool {
        #if DEBUG
        if let demo, demo.mirror { return true }
        #endif
        return settings.mirrored
    }

    /// Demo `duo`: draw the fold on a regular simulator.
    var demoDuo: Bool {
        #if DEBUG
        return demo?.duo ?? false
        #else
        return false
        #endif
    }

    private var isPausedByReason: Bool { !pauseReasons.isEmpty }

    /// A run the player is in the middle of (not the Home loop, not finished, not on results, not a CI freeze).
    var isLiveRun: Bool {
        guard route == .playing, !homeLoop, summary == nil, !frozen, let session else { return false }
        return !session.isFinished
    }

    /// The run is today's one scored Daily try (the pause card offers no Restart).
    var isScoredDaily: Bool {
        if case let .daily(_, scored) = mode { return scored }
        return false
    }

    var usesTouch: Bool { input == .touch }

    /// The hinge is plugged into a real Duo and readable (for copy: "Fold" vs "Hold").
    var hasHinge: Bool { hingeSeen || hinge.hasHinge }

    /// The title bird's tuck on Home: live from the hinge, else the idle beat / press-and-hold.
    func titleTuck(now: Double, heldSince: Double?, releasedAt: Double?) -> Double {
        if hinge.hasHinge, let angle = hinge.angle {
            return TitleTuck.fromHinge(angle: angle, openAngle: hinge.openAngle)
        }
        return TitleTuck.touch(now: now, heldSince: heldSince, releasedAt: releasedAt)
    }

    // MARK: - SceneDriver

    var sea: SeaProfile? { session?.sea }
    var bird: Bird { BirdCatalog.bird(runBird) }
    var sky: Sky { SkyCatalog.sky(runSky) }

    func advance(dt: TimeInterval, now: TimeInterval) -> (FlightSnapshot, [FlightEvent]) {
        // `SWOOP-T frame 120` is printed by FlightScene itself (it counts drawn frames).
        frameCount += 1
        guard let session else { return (FlightSnapshot(), []) }
        if input == .hinge { checkClosing() }
        if isPausedByReason || frozen {
            return (session.snapshot, [])
        }
        if let until = readyUntil {
            let left = until - now
            if left > 0 {
                let shown: Double? = (left * 10).rounded(.up) / 10
                hud.setReady(shown)
                return (session.snapshot, [])
            }
            readyUntil = nil
            let none: Double? = nil
            hud.setReady(none)
        }
        let step = AppRules.clampStep(dt)
        let tuck = activeSource.tuck(at: now)
        let events = session.step(dt: step, tuck: tuck)
        let snapshot = session.snapshot
        if !homeLoop {
            feedback.handle(events, telemetry: AppRules.telemetry(snapshot, playing: true))
            process(events, snapshot: snapshot)
            // `SWOOP-T tuck <u> angle <θ>` (≤ 4/s, from the hinge) is printed by HingeTuckSource itself.
            updateHints(snapshot)
            publishHUD(snapshot, now: now, force: false)
        }
        #if DEBUG
        demoAfterStep(snapshot, events: events)
        #endif
        return (snapshot, events)
    }

    private func chooseInput() -> AppInputKind {
        var demoAutopilot = false
        var demoTouch = false
        #if DEBUG
        if let demo {
            demoAutopilot = demo.autopilot != nil
            demoTouch = demo.touch
        }
        #endif
        return AppRules.chooseInput(homeLoop: homeLoop, demoAutopilot: demoAutopilot, demoTouch: demoTouch,
                                     hasHinge: hasHinge, playWithTouch: settings.playWithTouch,
                                     touchOverride: touchOverride)
    }

    private var activeSource: TuckSource {
        switch input {
        case .hinge: return hinge
        case .touch: return touch
        case .autopilot:
            if let autopilot { return autopilot }
            return touch
        }
    }

    private func setInput(_ kind: AppInputKind) {
        if input != kind { input = kind }
        AppTrace.t("SWOOP-T input \(kind.rawValue)")
    }

    // MARK: - Lifecycle hooks from RootView

    func launch() {
        #if DEBUG
        if let demo {
            launchDemo(demo)
            return
        }
        #endif
        startAttract()
    }

    /// The play canvas (points) or its fold changed. The scene is built once and then re-laid out.
    func updateCanvas(_ size: CGSize, hasFold: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        let newLayout = ScreenLayout.make(canvas: size, hasFold: hasFold, mirrored: effectiveMirrored)
        let line = "SWOOP-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(newLayout.hasFold ? 1 : 0) mirrored=\(newLayout.mirrored ? 1 : 0)"
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
        }
        guard newLayout != layout else { return }
        layout = newLayout
        if let scene {
            scene.layout = newLayout
        } else {
            makeScene(newLayout)
        }
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = FlightScene(layout: layout)
        newScene.scaleMode = .aspectFill
        newScene.reduceMotion = reduceMotion
        newScene.driver = self
        scene = newScene
        sceneGeneration += 1
        newScene.reset()
    }

    func setAppActive(_ active: Bool) {
        if active {
            // Back from the background the hinge's motion history is stale (Feel: reset keeps the calibration).
            hinge.reset()
            setPause(.background, false)
        } else {
            if isLiveRun && !isDemo { setUserPaused(true) }
            setPause(.background, true)
        }
    }

    /// The display's pose changed. Portrait mid-run shows the pause card when it comes back; the cover display (shut)
    /// pauses like closing, and reopening resumes behind the Ready hold.
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        pose = newPose
        if newPose == .play {
            setPause(.pose, false)
        } else {
            if newPose == .turn && isLiveRun && !isDemo { setUserPaused(true) }
            setPause(.pose, true)
        }
    }

    func setReduceMotion(_ on: Bool) {
        reduceMotion = on
        scene?.reduceMotion = on
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval) {
        hinge.ingest(angleDegrees: angle, at: time)
        if !hingeSeen {
            hingeSeen = true
            UserDefaults.standard.set(true, forKey: OrientationLock.hingeKey)
            OrientationLock.hingeArrived()
        }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
        }
        if route == .home && !homeFolded, let filtered = hinge.angle,
           filtered < hinge.openAngle - Self.homeFoldDegrees {
            homeFolded = true
        }
        refreshInput()
        checkClosing()
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research 02 §7).
    func hingeUnavailable() {}

    /// Home on a phone: the player held the title bird.
    func noteHomeHold() {
        if !homeFolded { homeFolded = true }
    }

    /// Closing below 95° pauses a live hinge run; reopening past 102° (HingeTuckSource's hysteresis) resumes it.
    private func checkClosing() {
        let closing = hinge.isClosing || isShut
        if closing {
            guard !isClosingPaused, input == .hinge, isLiveRun else { return }
            isClosingPaused = true
            setPause(.closing, true)
            AppTrace.t("SWOOP-T paused closing")
        } else if isClosingPaused {
            isClosingPaused = false
            setPause(.closing, false)
        }
    }

    /// The input may change mid-run only from touch to the hinge (the first hinge sample of a launch); a run never
    /// swaps the hinge away under the player.
    func refreshInput() {
        guard session != nil, !homeLoop else { return }
        let kind = chooseInput()
        guard kind != input else { return }
        if input == .hinge && isLiveRun { return }
        if kind == .touch { touch.ended(at: CACurrentMediaTime()) }
        setInput(kind)
    }

    // MARK: - Touch (the play layer's hold-anywhere)

    func touchBegan() { touch.began(at: CACurrentMediaTime()) }
    func touchEnded() { touch.ended(at: CACurrentMediaTime()) }

    // MARK: - Commands

    func fly() { start(mode: .flight) }

    func playDaily() {
        let day = DailySeed.dayNumber(for: Date())
        start(mode: .daily(day: day, scored: !store.hasDailyAttempt(day: day)))
    }

    /// "Fly again" (results) and "Restart" (pause card): the same kind of run, in under a second.
    func flyAgain() {
        switch mode {
        case let .daily(day, _):
            start(mode: .daily(day: day, scored: !store.hasDailyAttempt(day: day)))
        case .flight:
            start(mode: .flight)
        case .attract:
            if homeLoop { start(mode: .flight) } else { start(mode: .attract) }
        }
    }

    func pause() {
        guard isLiveRun else { return }
        setUserPaused(true)
    }

    func resume() {
        setUserPaused(false)
    }

    func goHome() {
        if homeLoop {
            setRoute(.home)
        } else {
            startAttract()
        }
    }

    func show(_ newRoute: AppRoute) {
        switch newRoute {
        case .home: goHome()
        case .playing: fly()
        case .results: break
        case .goals, .birds, .settings:
            if !homeLoop { startAttract() }
            setRoute(newRoute)
        }
    }

    /// "Play with touch" on the pose card: touch for this app session, and ask iOS for landscape.
    func chooseTouchFromPoseCard() {
        touchOverride = true
        // The player asked for touch: this one swap may happen mid-run (the run is paused behind the card).
        if session != nil && !homeLoop {
            let kind = chooseInput()
            if kind != input { setInput(kind) }
        }
        OrientationLock.requestLandscape()
    }

    func chooseBird(_ id: BirdID) {
        store.selectBird(id)
        if homeLoop { runBird = store.activeBird }
    }

    func chooseSky(_ id: SkyID) {
        store.selectSky(id)
        if homeLoop { runSky = store.activeSky }
    }

    /// Settings › Reset progress.
    func resetProgress() {
        store.resetProgress()
        if homeLoop {
            runBird = store.activeBird
            runSky = store.activeSky
        }
    }

    /// The mirror setting changed: re-lay the scene out for the same canvas.
    func refreshLayout() {
        guard let layout else { return }
        var mirroredLayout = layout
        mirroredLayout.mirrored = effectiveMirrored
        guard mirroredLayout != layout else { return }
        self.layout = mirroredLayout
        scene?.layout = mirroredLayout
    }

    // MARK: - Runs

    private func start(mode newMode: RunMode) {
        resultsTask?.cancel()
        closeOutDaily()
        homeLoop = false
        mode = newMode
        summary = nil
        if case let .daily(day, scored) = newMode, scored {
            scoredDailyDay = day
        } else {
            scoredDailyDay = nil
        }
        clearRunPauses()
        setRoute(.playing)
        buildSession()
        syncIdleTimer()
    }

    private func startAttract() {
        resultsTask?.cancel()
        closeOutDaily()
        homeLoop = true
        mode = .attract
        summary = nil
        clearRunPauses()
        setRoute(.home)
        buildSession()
        feedback.silence()
    }

    private func buildSession() {
        runBird = store.activeBird
        runSky = store.activeSky
        var best = store.data.bestMeters
        #if DEBUG
        if let demo {
            if let bird = demo.bird { runBird = bird }
            if let sky = demo.sky { runSky = sky }
            if let b = demo.best { best = b }
        }
        #endif
        let runSeed = self.seed(for: mode)
        let newSession = FlightSession(mode: mode, seed: runSeed, bestMeters: best, bird: runBird)
        session = newSession
        recordedFinish = false
        flightStart = nil
        frozen = false
        readyUntil = nil
        lastHUDPublish = -1
        toastUntil = 0
        lighthouseUntil = 0
        foldHintAt = nil
        openHintAt = nil
        hintsActive = !homeLoop && hintsWanted
        hud.reset()

        let kind = chooseInput()
        if kind == .autopilot {
            var skill: PilotSkill = .perfect
            #if DEBUG
            if !homeLoop, let demo, let pilot = demo.autopilot { skill = pilot }
            #endif
            autopilot = AutopilotTuckSource(skill: skill, seed: runSeed,
                                            snapshot: { [weak self] in self?.session?.snapshot },
                                            sea: { [weak self] in self?.session?.sea })
        } else {
            autopilot = nil
        }
        touch.ended(at: CACurrentMediaTime())
        setInput(kind)

        if homeLoop { newSession.skipCountdown() }
        #if DEBUG
        if !homeLoop, let demo { seedDemoRun(newSession, demo: demo, seed: runSeed) }
        #endif
        scene?.reset()
        if !homeLoop { publishHUD(newSession.snapshot, now: CACurrentMediaTime(), force: true) }
        syncIdleTimer()
    }

    private var hintsWanted: Bool {
        #if DEBUG
        if let demo { return demo.hintsFresh }
        #endif
        return !store.data.hintsLearned
    }

    private func seed(for mode: RunMode) -> UInt64 {
        #if DEBUG
        if let demo { return demo.seed ?? DemoConfig.defaultSeed }
        #endif
        switch mode {
        case let .daily(day, _): return DailySeed.seed(day: day)
        case .attract: return UInt64.random(in: 1...UInt64(UInt32.max))
        case .flight: return UInt64.random(in: 1...UInt64.max)
        }
    }

    /// Leaving today's scored Daily after the drop (Home, Restart, another run) files the distance so far as the day's
    /// score: one counted try, no free retries.
    private func closeOutDaily() {
        guard let day = scoredDailyDay else { return }
        scoredDailyDay = nil
        guard !recordedFinish, flightStart != nil, let s = session?.snapshot else { return }
        store.fileDailyPartial(day: day, meters: s.distanceMeters, perfects: s.perfects,
                               lighthouses: s.lighthousesPassed, lastLighthouseName: "",
                               today: DailySeed.dayNumber(for: Date()))
        AppTrace.t("SWOOP-T daily left day=\(day) meters=\(AppTrace.int(s.distanceMeters))")
    }

    // MARK: - Events

    private func process(_ events: [FlightEvent], snapshot s: FlightSnapshot) {
        for event in events {
            AppTrace.t("SWOOP-T event " + AppTrace.describe(event))
            switch event {
            case .started:
                if flightStart == nil { flightStart = s.time }
                if let day = scoredDailyDay { store.markDailyAttempt(day: day) }
            case let .touchdown(quality, _, _):
                if quality == .perfect && hintsActive {
                    hintsActive = false
                    let none: AppHint? = nil
                    hud.setHint(none)
                    if !isDemo { store.learnHints() }
                }
            case let .lighthouse(index, name):
                toastSerial += 1
                hud.lighthouse = HUDToast(kind: .lighthouse, title: name, detail: "Lighthouse \(index + 1)",
                                          serial: toastSerial)
                lighthouseUntil = s.time + Self.lighthouseCardSeconds
            case let .milestone(km):
                toastSerial += 1
                hud.toast = HUDToast(kind: .milestone, title: "\(km) km", detail: AppRules.milestoneLine(km),
                                     serial: toastSerial)
                toastUntil = s.time + Self.toastSeconds
            case .newBest:
                toastSerial += 1
                hud.toast = HUDToast(kind: .newBest, title: "New best!", detail: "Every metre now is a record",
                                     serial: toastSerial)
                toastUntil = s.time + Self.toastSeconds
            case .caught:
                touch.ended(at: CACurrentMediaTime())
                hud.setCaught(true)
            case .finished:
                handleFinished()
            case .countdownTick, .launched, .tailwindStarted, .tailwindEnded, .cloudTouched, .stormClose:
                break
            }
        }
    }

    /// "Fold on the way down" at the drop; "Open to fly" on the first climb toward a crest (GAME-DESIGN §9).
    private func updateHints(_ s: FlightSnapshot) {
        guard hintsActive, case .flying = s.phase else { return }
        let t = s.time
        if foldHintAt == nil {
            foldHintAt = t
            let fold: AppHint? = .fold
            hud.setHint(fold)
            return
        }
        if let shown = openHintAt {
            if t - shown > Self.hintSeconds {
                let none: AppHint? = nil
                hud.setHint(none)
                hintsActive = false
            }
            return
        }
        guard let foldAt = foldHintAt else { return }
        let since = t - foldAt
        if since > Self.hintSeconds && hud.hint == .fold {
            let none: AppHint? = nil
            hud.setHint(none)
        }
        var climbing = false
        if s.skimming, let sea = session?.sea {
            climbing = sea.slope(at: Double(s.position.x)) > Self.crestSlope
        }
        if (since >= Self.openHintMinDelay && climbing) || since >= Self.openHintMaxDelay {
            openHintAt = t
            let open: AppHint? = .open
            hud.setHint(open)
        }
    }

    private func publishHUD(_ s: FlightSnapshot, now: TimeInterval, force: Bool) {
        guard force || lastHUDPublish < 0 || now - lastHUDPublish >= Self.hudInterval else { return }
        lastHUDPublish = now
        hud.setMeters(s.distanceMeters.isFinite ? Int(max(s.distanceMeters, 0)) : 0)
        hud.setLead((min(max(s.lead, 0), 1) * 100).rounded() / 100)
        hud.setChain(s.chain)
        hud.setPerfects(s.perfects)
        hud.setTailwind((max(s.tailwindRemaining, 0) * 10).rounded() / 10)
        var countdown: Int?
        var flying = false
        var caught = false
        switch s.phase {
        case let .countdown(remaining):
            countdown = remaining.isFinite ? min(max(Int(remaining.rounded(.up)), 1), 3) : 3
        case .flying: flying = true
        case .caught, .finished: caught = true
        }
        hud.setCountdown(countdown)
        hud.setFlying(flying)
        hud.setCaught(caught)
        hud.setStormClose(flying && s.lead < Self.stormCloseLead)
        if hud.toast != nil && s.time > toastUntil {
            let none: HUDToast? = nil
            hud.setToast(none)
        }
        if hud.lighthouse != nil && s.time > lighthouseUntil {
            let none: HUDToast? = nil
            hud.setLighthouse(none)
        }
    }

    private func handleFinished() {
        guard !recordedFinish, let session, let result = session.result else { return }
        recordedFinish = true
        if homeLoop { return }
        if case .attract = result.mode { return }
        let today = DailySeed.dayNumber(for: Date())
        let outcome = store.record(result, today: today)
        scoredDailyDay = nil
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("SWOOP-T run meters=\(AppTrace.int(result.meters)) perfects=\(result.perfects) "
                   + "seconds=\(String(format: "%.1f", result.seconds))")
        let built = makeSummary(result, outcome: outcome)
        var delay = Self.resultsDelay
        #if DEBUG
        if demo?.freezeOn == .finished { delay = 0 }
        #endif
        let wait = delay
        resultsTask?.cancel()
        resultsTask = Task { @MainActor [weak self] in
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            guard !Task.isCancelled, let self, !self.homeLoop else { return }
            self.showResults(built)
        }
    }

    private func showResults(_ built: ResultSummary) {
        summary = built
        setRoute(.results)
        if built.outcome.rankUp != nil || built.outcome.showsNewBest { feedback.celebrate() }
    }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        var title = "Flight"
        var day: Int?
        var practice = false
        if case let .daily(d, scored) = result.mode {
            day = d
            practice = !scored
            title = scored ? "Daily Flight #\(d)" : "Daily Flight #\(d) · Practice"
        }
        return ResultSummary(result: result, outcome: outcome, title: title, dailyDay: day, practice: practice,
                             share: ShareText.line(for: result, streak: outcome.dailyStreak))
    }

    // MARK: - Routes, pauses, the idle timer

    private func setRoute(_ newRoute: AppRoute) {
        if route != newRoute {
            route = newRoute
            AppTrace.t("SWOOP-T screen \(newRoute.rawValue)")
        }
        if newRoute != .playing { feedback.silence() }
        syncIdleTimer()
    }

    private func setUserPaused(_ paused: Bool) {
        if isUserPaused != paused { isUserPaused = paused }
        setPause(.user, paused)
    }

    private func setPause(_ reason: PauseReason, _ on: Bool) {
        let was = isPausedByReason
        if on { pauseReasons.insert(reason) } else { pauseReasons.remove(reason) }
        let now = isPausedByReason
        if !was && now {
            touch.ended(at: CACurrentMediaTime())
            feedback.silence()
        } else if was && !now {
            resumed()
        }
        syncIdleTimer()
    }

    /// Every resume of a live run holds under the "Ready" ring for `readyHold` s.
    private func resumed() {
        guard isLiveRun else { return }
        let until = CACurrentMediaTime() + Self.readyHold
        readyUntil = until
        let shown: Double? = Self.readyHold
        hud.setReady(shown)
        AppTrace.t("SWOOP-T resumed")
    }

    /// Clears the pauses of a run being replaced (start, Home) without the resume hold.
    private func clearRunPauses() {
        isUserPaused = false
        isClosingPaused = false
        pauseReasons.remove(.user)
        pauseReasons.remove(.closing)
        readyUntil = nil
    }

    /// The hinge is the input, so a whole run can pass without a touch: Auto-Lock must not dim mid-flight.
    private func syncIdleTimer() {
        let awake = route == .playing && !homeLoop && !isPausedByReason && summary == nil
        guard awake != screenKeptAwake else { return }
        screenKeptAwake = awake
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    // MARK: - Demo (DEBUG only)

    #if DEBUG
    private func launchDemo(_ demo: DemoConfig) {
        let today = DailySeed.dayNumber(for: Date())
        store.replace(with: DemoPresets.progress(demo.progress, today: today))
        if demo.screen == .pose { forcedPose = .turn }
        if demo.screen == .icon { showsIconExport = true }
        if demo.badges {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                BadgeExport.renderAll()
            }
        }
        switch demo.effectiveScreen {
        case .home, .icon, .badges:
            startAttract()
        case .pose:
            if let m = demo.runMode(today: today) { start(mode: m) } else { startAttract() }
        case .goals, .birds, .settings:
            startAttract()
            let target: AppRoute = demo.effectiveScreen == .goals ? .goals
                : (demo.effectiveScreen == .birds ? .birds : .settings)
            setRoute(target)
        case .play:
            start(mode: demo.runMode(today: today) ?? .flight)
        case .results:
            presentDemoResults(demo, today: today)
        }
    }

    /// `chain=`, `lead=`, `skipTo=`, `skipCountdown`: the run is really flown headless before the live frames.
    private func seedDemoRun(_ s: FlightSession, demo: DemoConfig, seed: UInt64) {
        let needsFlight = (demo.chain ?? 0) > 0 || demo.lead != nil || demo.skipTo != nil
        if demo.skipCountdown || needsFlight { s.skipCountdown() }
        guard needsFlight else { return }
        var started: Double?
        let note: (FlightEvent, FlightSnapshot) -> Void = { event, snap in
            if case .started = event, started == nil { started = snap.time }
        }
        if let meters = demo.skipTo {
            DemoRunner.fly(s, skill: .perfect, seed: seed, maxSeconds: 600, onEvent: note,
                           until: { $0.distanceMeters >= meters })
            AppTrace.t("SWOOP-T skipped to \(AppTrace.int(s.snapshot.distanceMeters))")
        }
        if let chain = demo.chain, chain > 0 {
            DemoRunner.fly(s, skill: .perfect, seed: seed, maxSeconds: 240, onEvent: note,
                           until: { $0.chain >= chain })
            AppTrace.t("SWOOP-T chain seeded \(s.snapshot.chain) (asked \(chain))")
        }
        if let lead = demo.lead {
            DemoRunner.glide(s, maxSeconds: 90, onEvent: note,
                             until: { DemoRunner.isFlying($0) && $0.lead <= lead })
            AppTrace.t(String(format: "SWOOP-T lead seeded %.2f", s.snapshot.lead))
        }
        if flightStart == nil {
            flightStart = started ?? (DemoRunner.isFlying(s.snapshot) ? 0 : nil)
        }
    }

    /// `screen=results`: a real run of the mode flown headless by the autopilot, recorded into the demo progress; its
    /// finished session stays behind the card (the calm bird on the swell).
    private func presentDemoResults(_ demo: DemoConfig, today: Int) {
        let runMode = demo.runMode(today: today) ?? .flight
        start(mode: runMode)
        guard let session else { return }
        session.skipCountdown()
        DemoRunner.playToEnd(session, skill: demo.autopilot ?? .casual, seed: demo.seed ?? DemoConfig.defaultSeed)
        let s = session.snapshot
        let result = session.result ?? RunResult(
            mode: runMode, seed: session.seed, meters: s.distanceMeters, score: s.score, seconds: s.time,
            perfects: s.perfects, goods: 0, splashes: 0, bestChain: s.bestChain, tailwinds: 0,
            lighthouses: s.lighthousesPassed, lastLighthouseName: "", cloudTouches: 0, maxSpeed: s.speed,
            maxAltitude: s.altitude, longestCleanMeters: s.distanceMeters, birdID: runBird)
        recordedFinish = true
        scoredDailyDay = nil
        let outcome = store.record(result, today: today)
        AppTrace.t("SWOOP-T run meters=\(AppTrace.int(result.meters)) perfects=\(result.perfects) "
                   + "seconds=\(String(format: "%.1f", result.seconds))")
        showResults(makeSummary(result, outcome: outcome))
    }

    /// `freezeOn=` / `freezeAt=`: hold the frame once the moment has come.
    private func demoAfterStep(_ s: FlightSnapshot, events: [FlightEvent]) {
        guard let demo, !frozen, !homeLoop else { return }
        let flightTime = flightStart.map { s.time - $0 } ?? -1
        if let at = demo.freezeAt, flightStart != nil, flightTime >= at {
            freeze("time", s)
            return
        }
        guard let target = demo.freezeOn else { return }
        if let pending = freezePendingAt {
            if s.time >= pending { freeze(target.rawValue, s) }
            return
        }
        if target == .finished {
            if events.contains(.finished) { freeze(target.rawValue, s) }
            return
        }
        guard flightStart != nil, flightTime >= demo.freezeAfter || target == .caught else { return }
        var hit = events.contains(where: { AppRules.demoMatches(target, $0) })
        if target == .stormclose && DemoRunner.isFlying(s) && s.lead < Self.stormCloseLead { hit = true }
        if target == .flying && DemoRunner.isFlying(s) {
            hit = (!s.skimming && s.altitude >= 120) || flightTime >= demo.freezeAfter + 10
        }
        if hit {
            freezePendingAt = target == .flying ? s.time : s.time + 0.25
        }
    }

    private func freeze(_ reason: String, _ s: FlightSnapshot) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        let t = flightStart.map { s.time - $0 } ?? s.time
        AppTrace.t("SWOOP-T freeze \(reason) t=\(String(format: "%.2f", t)) m=\(AppTrace.int(s.distanceMeters)) "
                   + "chain=\(s.chain) lead=\(String(format: "%.2f", s.lead))")
    }
    #endif
}
