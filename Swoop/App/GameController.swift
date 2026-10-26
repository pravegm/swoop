import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): FlightScene.update → advance(dt:now:) → tuck source →
/// FlightSession.step → FeedbackDirector → HUD. Owns the session, the scene, the tuck sources, the app's route and the
/// Duo states (UX-SPEC §9).
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: Hashable { case user, closing, background, pose }

    // MARK: Tuning (named so they're easy to find and tune)

    /// HUD publishing rate cap, and the slower one for the km hundredths (QA-2 P2-6).
    static let hudInterval: Double = 1.0 / 15.0
    static let kmInterval: Double = 0.25
    /// After any resume the bird holds this long under a "Ready" ring, and up to `readyStillGrace` more while the
    /// hinge still moves.
    static let readyHold: Double = 1.5
    static let readyStillGrace: Double = 1.0
    /// Caught → finished takes 1.8 s in Core; the card then follows after this beat (UX-A2: 0.45 → 0.2).
    static let resultsDelay: Double = 0.2
    /// Caught can be skipped (a tap, or a fold u ≥ 0.6) this long after the catch (UX-A2).
    static let caughtSkipAfter: Double = 0.6
    static let caughtSkipTuck: Double = 0.6
    /// The countdown: 3 s for the first run of a launch (it calibrates), 1.5 s ("Ready · Go") after (UX-A2).
    static let firstCountdown: Double = 3.0
    static let shortCountdown: Double = 1.5
    /// The countdown holds while the Duo lies flat (≥ `flatAngle`), for at most this long (UX-A4).
    static let flatHoldMax: Double = 4.0
    static let flatAngle: Double = 175
    /// Home's flat caption: flat this long shows it; bent (130–170°) this long clears it (UX §2).
    static let homeFlatAfter: Double = 1.0
    static let homeBentAfter: Double = 0.5
    /// Mid-run flat: after this long, once per run, "Keep a little bend" (UX §9), and the blur guard: new toasts wait
    /// this long after leaving flat.
    static let midRunFlatAfter: Double = 2.0
    static let blurGuard: Double = 2.2
    /// The Duo counts as shut (cover display) at or below this hinge angle, and open again from the release angle.
    static let shutBelow: Double = 10
    static let shutReleaseAbove: Double = 15
    /// Home: a fold this far into the stroke counts as "they folded" (caption changes); back under this, a stroke.
    static let homeFoldTuck: Double = 0.5
    static let homeOpenTuck: Double = 0.2
    /// Hit-stops (ART §5): 35 ms on a Perfect, 60 ms when a Tailwind starts; a splash runs at 0.85× for 80 ms.
    static let hitStopSeconds: Double = 0.035
    static let tailwindStopSeconds: Double = 0.060
    static let splashSlowSeconds: Double = 0.080
    static let splashSlowRate: Double = 0.85
    /// How long the callout, the chain-lost pill, the lighthouse card, toasts and the teach line stay up (session s).
    static let calloutSeconds: Double = 0.7
    static let chainLostSeconds: Double = 0.8
    static let lighthouseCardSeconds: Double = 2.8
    static let toastSeconds: Double = 1.8
    static let teachSeconds: Double = 2.5
    /// R4: the splash word's life at the bird, and the first run's meter label (seconds after the drop).
    static let splashMarkSeconds: Double = 1.3
    /// R6: the reached card's life, the "YOUR GOAL" overline and the first-run storm line.
    /// Scene SC1: the meter and the goal chip fade in this long after step 7's storm starts rolling in.
    static let schoolStormHUDAfter: Double = 1.6
    static let reachedCardSeconds: Double = 1.9
    static let goalOverlineSeconds: Double = 5
    static let stormLineSeconds: Double = 3
    static let meterLabelSeconds: Double = 3.0
    /// The lead meter's storm-close threshold (GAME-DESIGN §6: 15 %).
    static let stormCloseLead: Double = 0.15
    /// VoiceOver announcements at most this often (UX §6).
    static let announceGap: Double = 1.5

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
    /// Home: the Duo has lain flat ≥ 1 s: "Bend it a little, like a book."
    @Published private(set) var homeFlat = false
    /// Home: Fly glows once after the first full stroke (fold, then open).
    @Published private(set) var flyGlowSerial = 0
    /// Home on a Duo resting under the 132° floor: "Open it a little wider" (R5 P1-7).
    @Published private(set) var homeLowRest = false
    /// "Play with touch" / "Switch to touch" / "Keep touch" (this app session only).
    @Published private(set) var touchOverride = false
    @Published private(set) var mode: RunMode = .attract
    /// The Home attract loop is running (Home, Goals, Birds, Settings sit over it).
    @Published private(set) var homeLoop = true
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover|deck` forces a pose.
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon` shows the app icon full screen.
    @Published private(set) var showsIconExport = false
    /// The run left the split deck for book pose: "Fly with the fold?" (UX-D2).
    @Published private(set) var deckReturnPrompt = false
    /// "Keep flying here" on the cover display (UX-D1).
    @Published private(set) var coverFlying = false
    /// The paused run, for the cover display (UX-D1).
    @Published private(set) var pausedRun: PausedRun?
    /// The current Ready hold's length (the ring's full turn).
    @Published private(set) var readyTotal: Double = GameController.readyHold

    let hud: HUDState
    let store: ProgressStore
    let settings: SettingsStore
    let hinge: HingeTuckSource
    let touch: TouchTuckSource
    /// The VoiceOver / Switch Control wing in a hinge run (QA-2 P2-7), paired with the hinge (the larger tuck wins).
    let accessibleTouch: TouchTuckSource
    private var assistedHinge: CombinedTuckSource?
    private let feedback: FeedbackDirector
    private var autopilot: AutopilotTuckSource?

    private var session: FlightSession?
    private var layout: ScreenLayout?
    private var pauseReasons: Set<PauseReason> = []
    private var readyUntil: TimeInterval?
    private var hitStopUntil: TimeInterval?
    private var slowUntil: TimeInterval?
    private var reduceMotion = false
    /// The scene's last reported bird centre (view points, y down; Scene R3 `onBirdPoint`).
    private var reportedBirdPoint: CGPoint?
    /// Thermal / Low Power effects quality pushed to the scene (UX-D5).
    private var effectsQuality: CGFloat = 1

    // Loop bookkeeping
    private var lastHUDPublish: TimeInterval = -1
    private var lastKmPublish: TimeInterval = -1
    private var recordedFinish = false
    /// Session time of the drop (`started`); nil before it.
    private var flightStart: Double?
    /// D4 (UX §5 HUD): this run teaches the chain ("✦ ×2 in a row") until its first chain of 2.
    private var chainTeachRun = false
    /// The lighthouse index the 300 m "goal near" cue last played for (-1: none this run).
    private var goalNearCued = -1
    private var countdownTotal: Double = 3
    private var flatHoldUsed: Double = 0
    private var caughtAt: Double?
    private var runsStartedThisLaunch = 0
    private var toastSerial = 0
    private var toastUntil = 0.0
    private var pendingToast: HUDToast?
    private var lighthouseUntil = 0.0
    private var tipUntil = 0.0
    private var stormLineShown = false
    private var flatTipPending = false
    /// Once an app session (UX §3).
    private var flatTipShown = false
    private var calloutSerial = 0
    private var calloutUntil = 0.0
    private var chainLostUntil = 0.0
    private var teachUntil = 0.0
    private var splashUntil = 0.0
    /// The next HUD publish is exact and unthrottled (pause, caught; R5 P1-3).
    private var forceHUD = false
    private var perfectCalloutShown = false
    /// The Duo was shut mid-run: the next resume is the long one.
    private var resumeAfterCover = false
    /// The founder's hinge readout (R4 P1-15): report rate and this run's strokes.
    private var hingeRate: Double = 0
    private var lastHingeSampleAt: TimeInterval?
    private var strokeCounter = StrokeCounter()
    private var coach = HintCoach(learned: [])
    private var coachOn = false
    private var keepBendShown = false
    private var tally = RunTally()
    private var runLastLighthouse = ""
    /// QA-1 P2-3: "Resume" on the closing card ignores a stale closing latch until the next fresh hinge sample.
    private var closingIgnoredUntilSample = false
    private var foldToFly = FoldToFly()
    private var resultsShownAt: TimeInterval = 0
    private var resultsTask: Task<Void, Never>?
    private var screenKeptAwake = false
    private var scoredDailyDay: Int?
    private var runBird: BirdID = .gull
    private var runSky: SkyID = .goldenHour
    private var runTrail: RGBA?
    private var lastCanvasLine = ""
    private var homeFlatSince: TimeInterval?
    private var homeBentSince: TimeInterval?
    private var homeStrokeFolded = false
    private var flyGlowed = false
    /// Home: the title bird's tuck through play's filters (hinge.tuck(at:) once per frame, Feel NEEDS).
    private var homeHingeTuck: Double = 0
    private var lastAnnounce: TimeInterval = -100
    private var lastAnnouncePriority = 0
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
        self.accessibleTouch = TouchTuckSource()
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
        settings.isDuo = trusted
        // R5 P1-7 (Feel): start from the saved resting angle, and save every new one (never in demo runs).
        if !isDemo, let saved = settings.hingeOpenAngle { hinge.restoreOpenAngle(saved) }
        hinge.onCalibrated = { [weak self] open in
            MainActor.assumeIsolated { self?.noteCalibrated(open) }
        }
    }

    private func noteCalibrated(_ open: Double) {
        guard !isDemo, open.isFinite else { return }
        settings.hingeOpenAngle = (open * 10).rounded() / 10
    }

    // MARK: - Derived

    var isDemo: Bool {
        #if DEBUG
        return demo != nil
        #else
        return false
        #endif
    }

    /// R6 D1: the bird's side (Settings › Bird side, the physical sharp half on a Duo, tracked through 180° turns), or
    /// demo `mirror`.
    var effectiveMirrored: Bool {
        #if DEBUG
        if let demo, demo.mirror { return true }
        #endif
        let side = (hasHinge || demoDuo) ? settings.birdSide : (settings.birdSide == .sharp ? .left : settings.birdSide)
        return BirdSideRule.mirrored(side, sharp: settings.sharpHalf, orientation: interfaceSide)
    }

    /// The interface orientation (RootView reads the window scene's).
    @Published private(set) var interfaceSide: InterfaceSide = .landscapeRight

    /// The bird's screen side now (Settings footnotes, the Wing check's "Currently: right half.").
    var birdScreenSide: ScreenSide { effectiveMirrored ? .right : .left }

    /// RootView: the window's landscape orientation changed (or is first known).
    func setInterfaceSide(_ o: InterfaceSide) {
        let before = effectiveMirrored
        if interfaceSide != o { interfaceSide = o }
        recordSharpHalfIfNeeded()
        guard effectiveMirrored != before else { return }
        // A 180° turn: the bird hops halves to stay on the same physical half. Mid-run, behind a pause.
        AppTrace.t(birdSideLogLine)
        if isLiveRun && !isDemo { setUserPaused(true) }
        refreshLayout()
    }

    /// The founder's correction to D1: the default sharp half is screen-right in the orientation the app first runs in
    /// on a Duo; that orientation becomes the physical reference.
    private func recordSharpHalfIfNeeded() {
        guard settings.sharpHalf == nil, hasHinge, !isDemo else { return }
        settings.sharpHalf = SharpHalf.firstRun(in: interfaceSide.feel)
        AppTrace.t(birdSideLogLine)
    }

    /// `SWOOP-T birdside <left|right> physical=<a|b> o=<L|R>` (UX §2.1): Feel's line for the sharp half, else the
    /// bird's side.
    private var birdSideLogLine: String {
        if let h = settings.sharpHalf, settings.birdSide == .sharp { return h.logLine(in: interfaceSide.feel) }
        return "SWOOP-T birdside \(birdScreenSide.rawValue) setting=\(settings.birdSide.rawValue) "
            + "o=\(interfaceSide.feel.letter)"
    }

    /// Demo `settingsWhy`: Settings opens with the Bird side explainer showing.
    var demoSettingsWhy: Bool {
        #if DEBUG
        return demo?.settingsWhy ?? false
        #else
        return false
        #endif
    }

    /// Demo `pose=phone`: the forced TurnCard uses the iPhone copy.
    var demoPosePhone: Bool {
        #if DEBUG
        return demo?.posePhone ?? false
        #else
        return false
        #endif
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
    /// QA-1 P1-1: the 1.8 s `caught` window is NOT live: it can't be paused, and leaving it records the run.
    var isLiveRun: Bool {
        guard route == .playing || route == .school, !homeLoop, summary == nil, !frozen, let session else { return false }
        if session.isFinished { return false }
        if case .caught = session.snapshot.phase { return false }
        return true
    }

    /// A run or its results is on screen (the split deck applies, UX-D2).
    var inRun: Bool { !homeLoop && (route == .playing || route == .results) }

    /// The run is today's one scored Daily try (the pause card offers no Restart).
    var isScoredDaily: Bool {
        if case let .daily(_, scored) = mode { return scored }
        return false
    }

    /// The scored Daily's countdown banner title (UX §3 "Daily"): "Daily Flight #298"; nil otherwise.
    var dailyBannerTitle: String? {
        if case let .daily(day, scored) = mode, scored { return "Daily Flight \(AppRules.dailyTag(day: day))" }
        return nil
    }

    var usesTouch: Bool { input == .touch }

    /// The hinge is plugged into a real Duo and readable (copy: "Fold" vs "Hold").
    var hasHinge: Bool { hingeSeen || hinge.hasHinge }

    /// The hints say "Hold…/Let go…" unless the hinge flies the bird.
    var hintTouchWording: Bool { AppRules.touchWording(input: input, hasHinge: hasHinge) }

    /// The HUD's run tag: "DAILY #298" (· PRACTICE once today's try is spent); nil for a Flight.
    var hudTag: String? {
        if case let .daily(day, scored) = mode {
            let n = AppRules.dailyTag(day: day).uppercased()
            return scored ? "DAILY \(n)" : "DAILY \(n) · PRACTICE"
        }
        return nil
    }

    /// The pause card's goal: "Gull Point in 1.9 km" (UX §5 Pause).
    var currentGoalLine: String? {
        guard let s = session?.snapshot, !homeLoop, !schoolSeaRun else { return nil }
        return RouteRules.goalLine(nextIndex: s.lighthousesPassed, metersFlown: Double(hud.meters))
    }

    /// The pause card's objective line on the first 3 runs (UX §4.1).
    var showsObjectiveLine: Bool { store.data.runs < 3 && !schoolSeaRun }

    /// The current distance (the pause card, the closing card).
    var currentMeters: Double {
        // R5 P1-3: the HUD's published value (forced exact at every pause), so the card never disagrees with it.
        Double(hud.meters)
    }

    /// The title bird's tuck on Home: live from the hinge (play's mapping and calibration), else the idle beat or
    /// press-and-hold.
    func titleTuck(now: Double, heldSince: Double?, releasedAt: Double?) -> Double {
        #if DEBUG
        if let t = demo?.titleTuck { return t }
        #endif
        if hinge.hasHinge { return homeHingeTuck }
        return TitleTuck.touch(now: now, heldSince: heldSince, releasedAt: releasedAt)
    }

    /// The founder's hinge readout (TestFlight / Debug only, R4 P1-15).
    func hingeReadout(now: TimeInterval) -> HingeReadout {
        var rate = hingeRate
        if let last = lastHingeSampleAt, now - last > 1 { rate = 0 }
        return HingeReadout(angle: hinge.angle, rawAngle: hinge.lastRawAngle, openAngle: hinge.openAngle,
                            tuck: hinge.lastTuck, reportsPerSecond: rate,
                            lastReportAge: lastHingeSampleAt.map { max(now - $0, 0) }, closing: hinge.isClosing,
                            shut: isShut, pose: pose.rawValue, strokes: strokeCounter.strokes,
                            meanStrokeDepth: strokeCounter.meanDepth)
    }

    /// The touch control's tuck now (the iPhone wing glyph and vignette, ART A13 / UX §10).
    func touchTuck(now: TimeInterval) -> Double {
        guard input == .touch else { return 0 }
        return touch.tuck(at: now)
    }

    // MARK: - SceneDriver

    var sea: SeaProfile? { session?.sea }
    /// The run's bird, its trail recoloured with the chosen trail colour (a rank reward), so Scene needs no change.
    var bird: Bird {
        var b = BirdCatalog.bird(runBird)
        if let trail = runTrail { b.trail = trail }
        return b
    }
    var sky: Sky { SkyCatalog.sky(runSky) }

    func advance(dt: TimeInterval, now: TimeInterval) -> (FlightSnapshot, [FlightEvent]) {
        // `SWOOP-T frame 120` is printed by FlightScene itself (it counts drawn frames).
        guard let session else { return (FlightSnapshot(), []) }
        if homeLoop && hinge.hasHinge { homeHingeTuck = hinge.tuck(at: now) }
        // R5 P1-7 (Feel): Home and Results (before fold-to-fly arms) learn the resting book angle once still.
        if hinge.hasHinge && (homeLoop || (route == .results && foldToFly.phase == .idle)) {
            hinge.homeCalibrate(at: now)
        }
        if homeLoop && hinge.hasHinge {
            let low = hinge.restIsBelowFloor(at: now)
            if homeLowRest != low { homeLowRest = low }
        }
        // UX-D3: no fine sparkle while a fold blur may still be on screen.
        SceneAdapter.setFineDetail(scene, !(hinge.hasHinge && hinge.inFlatBlurGuard(at: now, window: Self.blurGuard)))
        if input == .hinge { checkClosing(now: now) }
        if route == .results { updateFoldToFly(now: now) }
        if isPausedByReason || frozen {
            return (session.snapshot, [])
        }
        // The ready pose (countdown, resume hold) defines "wings spread" for this player.
        if input == .hinge {
            if case .countdown = session.snapshot.phase { hinge.snapCalibration(at: now) }
            if readyUntil != nil { hinge.snapCalibration(at: now) }
        }
        if let until = readyUntil {
            var left = until - now
            // A slow reopen finishes before the bird moves: the ring stays up while the hinge still moves.
            if left <= 0 && input == .hinge && !hinge.isStill(at: now) && now < until + Self.readyStillGrace {
                left = 0.05
            }
            if left > 0 {
                hud.setReady((left * 10).rounded(.up) / 10)
                return (session.snapshot, [])
            }
            readyUntil = nil
            hud.setReady(nil)
            if !homeLoop { feedback.cue(.go) }
        }
        // Hit-stops: the session skips its steps; the scene's FX keep animating on wall time, Feedback keeps its bed.
        if let stop = hitStopUntil {
            if now < stop {
                if !homeLoop { feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, playing: true)) }
                return (session.snapshot, [])
            }
            hitStopUntil = nil
        }
        var step = AppRules.clampStep(dt)
        // UX-A4: the countdown holds while the Duo lies flat (fold-blur risk), and (R4 P0-6) while a still hinge rests
        // on the calibration floor ("Open a little wider"): 4 s at most between them.
        // R5 P1-8 (Feel): when the nudge budget runs out, a rest under 119° keeps holding and offers touch; "Go" never
        // comes while the start tuck is over 0.5.
        if case let .countdown(remaining) = session.snapshot.phase, !homeLoop {
            let raw = countdownHold(now: now)
            var lowRest: HingeLowRest?
            if raw == .nudge && flatHoldUsed >= Self.flatHoldMax && input == .hinge {
                lowRest = hinge.lowRestFallback(at: now)
            }
            let startTuck = input == .hinge ? hinge.startTuck(at: now) : 0
            let gate = AppRules.countdownGate(raw: raw, budgetUsed: flatHoldUsed, budget: Self.flatHoldMax,
                                              lowRest: lowRest, startTuck: startTuck, remaining: remaining, step: step)
            hud.setNudgeOffer(gate.offerTouch)
            if gate.hold != .free {
                if flatHoldUsed < Self.flatHoldMax { flatHoldUsed += step }
                hud.setFlatHold(gate.hold == .flat)
                hud.setOpenNudge(gate.hold == .nudge)
                #if DEBUG
                demoFlatHoldFrame(session.snapshot)
                #endif
                feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, playing: false))
                publishHUD(session.snapshot, now: now, force: false)
                return (session.snapshot, [])
            }
        }
        hud.setFlatHold(false)
        hud.setOpenNudge(false)
        hud.setNudgeOffer(false)
        if let slow = slowUntil {
            if now < slow { step *= Self.splashSlowRate } else { slowUntil = nil }
        }
        if schoolSeaRun, let sc = school {
            // Core's practice sea scales its own dt (0.8×, 0.5× around the step-4 launch, 1.0 in the storm).
            if session.isPractice { session.timeScale = sc.timeScale } else { step *= sc.timeScale }
        }
        let prevChain = session.snapshot.chain
        let tuck = activeSource.tuck(at: now)
        if input == .hinge && !homeLoop { strokeCounter.note(tuck) }
        // Feel R4: the end-stop detent when the tuck first reaches full in a stroke.
        if input == .hinge && hinge.consumeEndStop() { feedback.cue(.endStop) }
        let events = session.step(dt: step, tuck: tuck)
        let snapshot = session.snapshot
        if school != nil {
            // The school reads the player's wings: touch, the title bird's hinge tuck (Studio), or the run's tuck.
            let schoolTuck = schoolTouch ? touch.tuck(at: now) : (homeLoop ? homeHingeTuck : tuck)
            stepSchool(now: now, tuck: schoolTuck, snapshot: snapshot, events: events)
        }
        if route == .wingCheck { stepStandaloneWingCheck(now: now) }
        SceneAdapter.setSchool(scene, step: schoolSeaRun ? school?.stepNow : nil,
                               slowMo: schoolSeaRun && (school?.timeScale ?? 1) < 0.6)
        if !homeLoop {
            tally.note(events, snapshot: snapshot)
            feedback.handle(events, telemetry: AppRules.telemetry(snapshot, playing: true))
            process(events, snapshot: snapshot, prevChain: prevChain, now: now)
            updateCoach(snapshot, events: events, now: now)
            watchMidRunFlat(snapshot, now: now)
            if input == .hinge && tuck >= Self.caughtSkipTuck { skipCaught() }
            publishHUD(snapshot, now: now, force: false)
        }
        #if DEBUG
        demoAfterStep(snapshot, events: events)
        #endif
        return (snapshot, events)
    }

    private typealias CountdownHold = AppRules.CountdownHold

    private func countdownHold(now: TimeInterval) -> CountdownHold {
        #if DEBUG
        if demo?.flat == true { return .flat }
        if demo?.nudge == true { return .nudge }
        #endif
        guard input == .hinge else { return .free }
        if hinge.flatDuration(at: now) > 0 { return .flat }
        // R4 P0-6 (Feel): a still hand resting under the 132° floor.
        if hinge.restIsBelowFloor(at: now) { return .nudge }
        return .free
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
        // QA-1 P2-2: only a LIVE hinge reading picks the hinge; `refreshInput` upgrades touch → hinge on the first one.
        return AppRules.chooseInput(homeLoop: homeLoop, demoAutopilot: demoAutopilot, demoTouch: demoTouch,
                                    hasHinge: hinge.hasHinge, playWithTouch: settings.playWithTouch,
                                    touchOverride: touchOverride, deck: pose == .deck)
    }

    private var activeSource: TuckSource {
        switch input {
        case .hinge:
            if Self.assistiveTechRunning {
                if let assistedHinge { return assistedHinge }
                let combined = CombinedTuckSource(primary: hinge, assist: accessibleTouch)
                assistedHinge = combined
                return combined
            }
            return hinge
        case .touch: return touch
        case .autopilot:
            if let autopilot { return autopilot }
            return touch
        }
    }

    private func setInput(_ kind: AppInputKind) {
        if input != kind {
            input = kind
            releaseTouches()
        }
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
        // UX-A1: the callout anchors to where the bird really is (Scene R3, view points, y down).
        SceneAdapter.watchBird(newScene) { [weak self] p in self?.reportedBirdPoint = p }
        SceneAdapter.setEffects(newScene, quality: effectsQuality)
        if isDemo { SceneAdapter.storeCapture(newScene) }
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
            // QA-1 P1-1: caught = over; finish it now so a lock or a kill never loses the run.
            finishCaughtRunHeadless(immediate: false)
            // QA-1 P1-2: a kill after the Daily drop must not lose the day's score.
            fileDailyProgress()
            if isLiveRun && !isDemo { setUserPaused(true) }
            setPause(.background, true)
        }
    }

    /// The display's pose changed (UX-SPEC §9).
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        let old = pose
        pose = newPose
        switch newPose {
        case .play:
            setPause(.pose, false)
            // Back in book pose from the split deck mid-run: ask before handing the run to the hinge (UX-D2, QA-2 P2-3).
            if old == .deck && isLiveRun && hinge.hasHinge && input == .touch && !isDemo {
                deckReturnPrompt = true
                setUserPaused(true)
                feedback.cue(.bookPrompt)
            }
            coverFlying = false
        case .deck:
            setPause(.pose, false)
            if isLiveRun && input != .touch {
                // Into the seated deck mid-run: touch flies it, behind the pause card (never a silent swap).
                if !isDemo && old == .play { setUserPaused(true) }
                setInput(.touch)
            }
            if inRun { feedback.cue(.splitDeck) }
        case .turn:
            if isLiveRun && !isDemo { setUserPaused(true) }
            setPause(.pose, true)
        case .closed:
            // R4 P0-6: the next resume waits out iOS's display-handover blur.
            if isLiveRun || pausedRun != nil { resumeAfterCover = true }
            setPause(.pose, true)
            if !isDemo { UIAccessibility.post(notification: .screenChanged, argument: nil) }
        }
    }

    /// Thermal state or Low Power changed (RootView observes both; UX-D4/D5).
    func setPowerState(thermalHot: Bool, lowPower: Bool) {
        effectsQuality = SceneAdapter.effectsQuality(thermalHot: thermalHot, lowPower: lowPower)
        SceneAdapter.setEffects(scene, quality: effectsQuality)
    }

    /// Home shows (its wordmark and caption frames) or leaves ([]): the attract bird keeps under the text (R5b).
    func setHomeTextRects(_ rects: [CGRect]) {
        SceneAdapter.setHomeTextRects(scene, rects)
    }

    func setReduceMotion(_ on: Bool) {
        reduceMotion = on
        scene?.reduceMotion = on
    }

    /// The inner display is back (the canvas is large again): "Keep flying here" on the cover is over.
    func innerDisplayBack() {
        if coverFlying { coverFlying = false }
        // Duo R3 P2-7: a dropped ≥ 15° report must never leave "Open your wings" on the lit inner display.
        if isShut { isShut = false }
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval) {
        if let last = lastHingeSampleAt {
            let dt = time - last
            if dt > 0 && dt < 1 { hingeRate = hingeRate * 0.9 + (1 / dt) * 0.1 }
        }
        lastHingeSampleAt = time
        hinge.ingest(angleDegrees: angle, at: time)
        closingIgnoredUntilSample = false
        if !hingeSeen {
            hingeSeen = true
            settings.isDuo = true
            UserDefaults.standard.set(true, forKey: OrientationLock.hingeKey)
            OrientationLock.hingeArrived()
        }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
        }
        if homeLoop { watchHomeHinge(time: time) }
        watchFlatOpenings(angle: hinge.angle ?? angle, now: CACurrentMediaTime())
        refreshInput()
        checkClosing(now: CACurrentMediaTime())
    }

    /// Home: the flat caption, the first fold, and the first full stroke (UX §2).
    private func watchHomeHinge(time: TimeInterval) {
        #if DEBUG
        // Demo `flat` holds the bend caption although the simulator's hinge reads 150°.
        if demo?.flat == true { return }
        #endif
        guard let a = hinge.angle else { return }
        if a >= Self.flatAngle {
            homeBentSince = nil
            let since = homeFlatSince ?? time
            homeFlatSince = since
            if time - since >= Self.homeFlatAfter && !homeFlat { homeFlat = true }
        } else {
            homeFlatSince = nil
            if homeFlat {
                if a >= 130 && a <= 170 {
                    let since = homeBentSince ?? time
                    homeBentSince = since
                    if time - since >= Self.homeBentAfter {
                        homeFlat = false
                        homeBentSince = nil
                    }
                } else {
                    homeBentSince = nil
                }
            }
        }
        let u = homeHingeTuck
        if u >= Self.homeFoldTuck {
            if !homeFolded { homeFolded = true }
            if !homeStrokeFolded { feedback.cue(.homeFold) }
            homeStrokeFolded = true
        } else if homeStrokeFolded && u <= Self.homeOpenTuck {
            homeStrokeFolded = false
            if !flyGlowed {
                flyGlowed = true
                flyGlowSerial += 1
            }
        }
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research 02 §7).
    func hingeUnavailable() {}

    /// Home on a phone: the player held the title bird.
    func noteHomeHold() {
        if !homeFolded { homeFolded = true }
    }

    /// Closing below 90° for 0.2 s (at once under 75°) pauses a live hinge run; reopening past 98° resumes it (Feel R4:
    /// `closing(at:)` matures the dwell on the frame clock).
    private func checkClosing(now: TimeInterval) {
        let closing = (hinge.closing(at: now) || isShut) && !closingIgnoredUntilSample
        if closing {
            guard !isClosingPaused, input == .hinge, isLiveRun else { return }
            isClosingPaused = true
            setPause(.closing, true)
            feedback.cue(.closing)
            AppTrace.t("SWOOP-T paused closing")
        } else if isClosingPaused && !demoHoldsClosing {
            isClosingPaused = false
            setPause(.closing, false)
        }
    }

    /// Demo `closing`: the closing card stays up although the simulator's hinge reads open.
    private var demoHoldsClosing: Bool {
        #if DEBUG
        return demo?.closing == true
        #else
        return false
        #endif
    }

    /// QA-1 P2-3: the closing card's Resume ignores a stale closing latch until the next fresh sample.
    func resumeFromClosing() {
        guard isClosingPaused else { return }
        closingIgnoredUntilSample = true
        if isShut { isShut = false }
        isClosingPaused = false
        setPause(.closing, false)
    }

    /// The input may change mid-run only from touch to the hinge (the first hinge sample of a launch).
    func refreshInput() {
        guard session != nil, !homeLoop else { return }
        let kind = chooseInput()
        guard kind != input else { return }
        if input == .hinge && isLiveRun { return }
        if kind == .hinge && pose == .deck { return }
        setInput(kind)
    }

    // MARK: - Touch (the play layer's hold-anywhere; tap-to-tuck in Settings)

    func touchBegan() {
        touch.tapToggles = settings.tuckByTapping
        touch.began(at: CACurrentMediaTime())
        feedback.cue(.touchDown)
    }

    /// Holding: release. Tapping: nothing (Feel's `tapToggles`).
    func touchEnded() {
        touch.ended(at: CACurrentMediaTime())
    }

    /// VoiceOver or Switch Control is running (the accessible wing, UX §10).
    static var assistiveTechRunning: Bool {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }

    /// Releases every touch tuck (a pause, a run's end, an input change): a toggled tuck never carries over.
    private func releaseTouches() {
        let now = CACurrentMediaTime()
        touch.setTucked(false, at: now)
        accessibleTouch.setTucked(false, at: now)
    }

    /// VoiceOver's adjustable "Wings" (QA-2 P2-7): in a hinge run it switches the run to touch first.
    func accessibleTuck(_ down: Bool) {
        let now = CACurrentMediaTime()
        if input == .hinge {
            accessibleTouch.setTucked(down, at: now)
        } else {
            touch.setTucked(down, at: now)
        }
    }

    /// Switch Control "select" on the wings: toggles the tuck.
    func accessibleToggle() {
        let now = CACurrentMediaTime()
        if input == .hinge { accessibleTouch.toggle(at: now) } else { touch.toggle(at: now) }
    }

    // MARK: - Commands

    /// The first Fly ever opens Flight School (UX §1.1); afterwards Fly is a Flight.
    func fly() {
        if Self.schoolOnFly(state: store.data.flightSchool, runs: store.data.runs) && !isDemo {
            startSchool(replay: false)
        } else {
            start(mode: .flight)
        }
    }

    /// Pure; tested.
    nonisolated static func schoolOnFly(state: FlightSchoolState, runs: Int) -> Bool {
        state == .notStarted && runs == 0
    }

    /// Fly with a bird (Birds › "Fly as Tern").
    func fly(as id: BirdID) {
        chooseBird(id)
        start(mode: .flight)
    }

    func playDaily() {
        let day = DailySeed.dayNumber(for: Date())
        store.markSeen("daily")
        start(mode: .daily(day: day, scored: store.dailyIsScorable(day: day)))
    }

    /// "Practise today's sea" (the Daily card): never scored.
    func practiseDaily() {
        let day = DailySeed.dayNumber(for: Date())
        start(mode: .daily(day: day, scored: false))
    }

    /// "Fly again" (results), "Restart" (pause card), and fold-to-fly: the same kind of run, behind the short countdown.
    func flyAgain() {
        switch mode {
        case .daily:
            // After midnight "Fly again" is today's Daily (scored if today's try is unspent); a spent Daily is practice.
            playDaily()
        case .flight:
            start(mode: .flight)
        case .attract:
            if homeLoop { start(mode: .flight) } else { start(mode: .attract) }
        }
    }

    /// The scored Daily's "Free flight": a Flight, never a silent practice.
    func freeFlight() { start(mode: .flight) }

    func pause() {
        guard isLiveRun else { return }
        setUserPaused(true)
    }

    func resume() {
        deckReturnPrompt = false
        // Flight School: Resume rewinds to the current step's checkpoint (UX §1.1).
        if schoolSeaRun { rewindSchoolSea() }
        setUserPaused(false)
    }

    /// Pause › "Switch to touch" (UX-D7): one tap for tired or one-handed players.
    func switchToTouch() {
        touchOverride = true
        setInput(.touch)
        resume()
    }

    /// The split deck's return prompt: "Fly with the fold".
    func flyWithFold() {
        touchOverride = false
        deckReturnPrompt = false
        setInput(chooseInput())
        resume()
    }

    /// The split deck's return prompt: "Keep touch".
    func keepTouch() {
        touchOverride = true
        deckReturnPrompt = false
        setInput(.touch)
        resume()
    }

    /// Caught → results now (UX-A2): a tap or a fold, 0.6 s after the catch.
    func skipCaught() {
        guard !homeLoop, !recordedFinish, let session, let at = caughtAt else { return }
        guard case .caught = session.snapshot.phase, session.snapshot.time - at >= Self.caughtSkipAfter else { return }
        finishCaughtRunHeadless(immediate: true)
    }

    func goHome() {
        // Leaving school mid-way: the next Fly starts it again at step 0 (UX §1.4).
        if school != nil { endSchool() }
        if homeLoop {
            setRoute(.home)
        } else {
            startAttract()
        }
    }

    // MARK: - Flight School (R6 D2, design/UX-FLIGHT-SCHOOL.md)

    /// What the school shows (published only on change).
    @Published private(set) var schoolDisplay = SchoolDisplay()
    /// The standalone Wing check (Settings, the Home card): its flow.
    @Published private(set) var wingCheckDisplay: WingCheckFlow.Phase = .explain
    private var school: FlightSchool?
    private var standaloneWingCheck: WingCheckFlow?
    /// The practice sea of the school's steps 3–7 is flying (not recorded, no hints, no storm catch).
    private(set) var schoolSeaRun = false
    /// The next real run gets the full 3-2-1 (a skip) or the 1.5 s Ready · Go (the school ends in the air).
    private var nextCountdown: Double?
    /// The first real run after the school: the storm line and "YOUR GOAL".
    private var firstRealRun = false
    #if DEBUG
    /// Demo `school=`: the frame is held (the machine isn't stepped).
    private var schoolHeld = false
    /// Demo `school=wingcheck:<phase>`: the Settings check is held at its phase (the hinge doesn't move it on).
    private var demoWingHeld = false
    #endif

    var schoolActive: Bool { school != nil }

    /// The live filtered hinge angle for the diagram (150° before any reading).
    var hingeAngleForDiagram: Double { hinge.angle ?? 150 }

    /// The school's variant: touch on iPhones, a Duo set to touch or tapping, or after the step-0 escape.
    private var schoolTouch: Bool {
        !hasHinge || settings.playWithTouch || settings.tuckByTapping || touchOverride
    }

    /// Fly (first ever) or Settings › Flight School (replay).
    func startSchool(replay: Bool, at step: SchoolStep = .hold) {
        let now = CACurrentMediaTime()
        // R7 P0-1: the Wing check is no longer part of the school (it lives in Settings › Bird side): 7 steps.
        var s = FlightSchool(touch: schoolTouch, tapping: settings.tuckByTapping, asksWingCheck: false)
        s.start(at: step, time: now)
        school = s
        AppTrace.t("SWOOP-T school \(s.stepNow.key) prompt")
        if s.stepNow.isSea {
            startSchoolSea()
            placeSchoolSea(at: s.stepNow)
        } else {
            if !homeLoop { startAttract() }
            setRoute(.school)
        }
        publishSchool(now)
    }

    /// The practice sea (steps 3–7): Core's `FlightSession.practice` (built by `buildSession` while `schoolSeaRun`),
    /// never recorded. The App's own `mode` stays a Flight (`CoreAdapter.practiceMode`).
    private func startSchoolSea() {
        schoolSeaRun = true
        feedback.practiceAmbience = true
        start(mode: CoreAdapter.practiceMode)
        session?.skipCountdown()
        hud.setSchoolSea(true)
        setRoute(.school)
    }

    /// Rewind the practice sea to the current step's checkpoint (Core's `rewind` when it exists, else a fresh sea).
    private func rewindSchoolSea() {
        guard schoolSeaRun else { return }
        let step = school?.stepNow ?? .dive
        if let session, session.isPractice {
            // Core K1: back to the step's checkpoint (step 5: the next guided swell).
            if let point = FlightSchool.checkpoint(for: step) {
                session.rewind(to: point)
            } else {
                session.nextGuidedSwell()
            }
        } else {
            buildSession()
            session?.skipCountdown()
            hud.setSchoolSea(true)
        }
        AppTrace.t("SWOOP-T school rewind \(step.key)")
    }

    /// A school started at a later sea step (replay at a step, demo `school=soar`): put the bird at that step's place.
    private func placeSchoolSea(at step: SchoolStep) {
        guard let session, session.isPractice, step > .dive else { return }
        if let point = FlightSchool.checkpoint(for: step) { session.rewind(to: point) } else { session.rewind(to: .guided(0)) }
        if step == .storm { session.practiceStormGap = CoreAdapter.practiceStormGap }
    }

    /// Skip (after step 0) or Pause › Skip Flight School: straight into a real Flight with the full 3-2-1.
    func skipSchool() {
        guard var s = school, s.skip() else { return }
        store.setFlightSchool(.skipped(atStep: s.stepNow.rawValue))
        AppTrace.t("SWOOP-T school skip at \(s.stepNow.key)")
        endSchool()
        nextCountdown = Self.firstCountdown
        firstRealRun = true    // R7: a skip's run is the first real run too (the goal sentence, the storm line)
        start(mode: .flight)
    }

    /// Step 0's escape: "Play with touch instead" (the touch variant from step 1).
    func schoolPlayWithTouch() {
        touchOverride = true
        let now = CACurrentMediaTime()
        var s = FlightSchool(touch: true, tapping: settings.tuckByTapping, asksWingCheck: false)
        s.start(at: .wings, time: now)
        school = s
        publishSchool(now)
    }

    /// The Wing check's answer (step 2, or the standalone check): a side, or nil for "Not sure · skip".
    func answerWingCheck(_ side: ScreenSide?) {
        let now = CACurrentMediaTime()
        if let side {
            settings.sharpHalf = BirdSideRule.recording(answer: side, sharp: settings.sharpHalf, orientation: interfaceSide)
            settings.wingCheckDone = true
            settings.birdSide = .sharp
            refreshLayout()
            AppTrace.t(birdSideLogLine)
        }
        AppTrace.t("SWOOP-T wingcheck \(side?.rawValue ?? "skip")")
        if school != nil {
            school?.answerWingCheck(side, time: now)
            publishSchool(now)
        } else if standaloneWingCheck != nil {
            standaloneWingCheck?.answer(side, time: now)
            wingCheckDisplay = .confirm
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard let self, self.route == .wingCheck else { return }
                self.standaloneWingCheck = nil
                self.show(.settings)
            }
        }
    }

    /// Settings › Check again, the Home card's Check now.
    func openWingCheck() {
        standaloneWingCheck = WingCheckFlow()
        wingCheckDisplay = .explain
        settings.wingCheckCardShown = true
        if !homeLoop { startAttract() }
        setRoute(.wingCheck)
    }

    /// A one-time explanation was shown (D4; never written in demo runs).
    func learnHint(_ hint: String) {
        guard !isDemo else { return }
        store.learnHint(hint)
    }

    /// The Home card's Not now.
    func dismissWingCheckCard() { settings.wingCheckCardShown = true }

    /// The existing-player Wing check card (UX §2.4): a Duo, runs > 0, never checked, never shown.
    /// R7 P0-1: the Home Wing check card is gone (testers met it as a second, confusing ask); Settings keeps it.
    var showsWingCheckCard: Bool { false }

    private func endSchool() {
        school = nil
        hud.setSchoolFaster(nil)
        hud.setSchoolRhythm(nil)
        hud.setSchoolStormHUD(false)
        schoolSeaRun = false
        feedback.practiceAmbience = false
        hud.setSchoolSea(false)
        schoolDisplay = SchoolDisplay()
    }

    /// One frame of the school (from `advance`).
    private func stepSchool(now: TimeInterval, tuck: Double, snapshot s: FlightSnapshot, events: [FlightEvent]) {
        guard var sc = school else { return }
        publishSchoolBirdHUD(sc, snapshot: s, now: now)
        #if DEBUG
        if schoolHeld { return }
        #endif
        var slope = 0.0
        if let sea = session?.sea { slope = sea.slope(at: Double(s.position.x)) }
        if !slope.isFinite { slope = 0 }
        var flying = false
        if case .flying = s.phase { flying = true }
        var input = SchoolInput(time: now, landscape: pose == .play, angle: hinge.hasHinge ? hinge.angle : nil,
                                still: hinge.hasHinge && hinge.isStill(at: now, window: 0.5), tuck: tuck, slope: slope,
                                skimming: s.skimming, flying: flying, events: schoolSeaRun ? events : [])
        if schoolSeaRun, let session, session.isPractice {
            input.practice = true
            input.signals = session.practiceSignals
        }
        let out = sc.step(input)
        school = sc
        if out.succeeded {
            feedback.cue(.schoolStep(sc.dotIndex))
            AppTrace.t("SWOOP-T school \(sc.stepNow.key) done")
            announce("Done. \(sc.praise ?? "")", priority: 2)
        }
        if out.rewind {
            feedback.cue(.schoolRewind)
            rewindSchoolSea()
        }
        if out.advanced {
            if sc.stepNow == .storm {
                feedback.cue(.schoolStorm)
                session?.practiceStormGap = CoreAdapter.practiceStormGap
                SceneAdapter.rollInStorm(scene)
            }
            AppTrace.t("SWOOP-T school \(sc.stepNow.key) prompt")
            announce("Flight School, step \(sc.dotIndex + 1) of \(sc.stepCount). \(sc.prompt(at: now))", priority: 2)
            if sc.stepNow.isSea && !schoolSeaRun { startSchoolSea() }
        }
        if out.finished { finishSchool() }
        publishSchool(now)
    }

    /// SC3: the bird-anchored "Faster!" capsule (step 3) and rhythm bar (step 6), drawn by the App (`SchoolBirdHUD`).
    private func publishSchoolBirdHUD(_ sc: FlightSchool, snapshot s: FlightSnapshot, now: TimeInterval) {
        hud.setSchoolStormHUD(schoolSeaRun && sc.stepNow == .storm && now - sc.stepStartedAt >= Self.schoolStormHUDAfter)
        var flying = false
        if case .flying = s.phase { flying = true }
        let faster: Double? = schoolSeaRun && flying && sc.stepNow == .dive
            ? (FlightSchool.fasterFill(speed: s.speed) * 20).rounded() / 20 : nil
        hud.setSchoolFaster(faster)
        var rhythm: SchoolRhythm?
        if schoolSeaRun && sc.stepNow == .rhythm, let pos = FlightSchool.rhythmPosition(x: Double(s.position.x)) {
            rhythm = SchoolRhythm(wave: pos.wave, fraction: (pos.fraction * 60).rounded() / 60,
                                  tuck: (s.tuck * 10).rounded() / 10)
        }
        hud.setSchoolRhythm(rhythm)
    }

    /// Step 7 ends in the air: the real Flight, behind the 1.5 s Ready · Go.
    private func finishSchool() {
        store.setFlightSchool(.done)
        AppTrace.t("SWOOP-T school finished")
        endSchool()
        firstRealRun = true
        nextCountdown = Self.shortCountdown
        start(mode: .flight)
    }

    private func publishSchool(_ now: TimeInterval) {
        guard let sc = school else { return }
        var d = SchoolDisplay()
        d.step = sc.stepNow
        d.overline = sc.overline
        d.prompt = sc.prompt(at: now)
        d.subline = sc.subline
        d.praise = sc.phase == .praise ? sc.praise : nil
        d.praiseLine = sc.phase == .praise ? FlightSchoolCopy.praiseLine(sc.stepNow) : nil
        d.dotIndex = sc.dotIndex
        d.stepCount = sc.stepCount
        d.canSkip = sc.canSkip
        d.offersTouch = sc.offersTouch
        d.touch = sc.touch
        d.wingPhase = sc.wingCheck.phase
        d.wingNeedsFlatHelp = sc.wingCheck.needsFlatHelp
        if d != schoolDisplay { schoolDisplay = d }
    }

    /// The standalone Wing check's frame.
    private func stepStandaloneWingCheck(now: TimeInterval) {
        #if DEBUG
        if demoWingHeld { return }
        #endif
        guard var w = standaloneWingCheck, let a = hinge.angle else { return }
        w.update(angle: a, time: now)
        standaloneWingCheck = w
        if wingCheckDisplay != w.phase { wingCheckDisplay = w.phase }
    }

    func show(_ newRoute: AppRoute) {
        switch newRoute {
        case .home: goHome()
        case .playing: fly()
        case .results: break
        case .daily: openDailyCard()
        case .goals, .birds, .settings, .route:
            if newRoute == .goals { store.markSeen("goals") }
            if newRoute == .birds { store.markSeen("birds") }
            if newRoute == .route { store.markSeen("route") }
            if !homeLoop { startAttract() }
            setRoute(newRoute)
        case .school:
            startSchool(replay: true)
        case .wingCheck:
            openWingCheck()
        }
    }

    /// Home's Daily button once today's Daily is flown or spent: the Daily card (UX-A10).
    func openDailyCard() {
        let day = DailySeed.dayNumber(for: Date())
        store.markSeen("daily")
        if !homeLoop { startAttract() }
        let record = store.data.dailyRecord(day: day)
        let result = RunResult(mode: .daily(day: day, scored: true), seed: DailySeed.seed(day: day),
                               meters: record?.meters ?? 0, score: 0, seconds: 0, perfects: record?.perfects ?? 0,
                               goods: 0, splashes: 0, bestChain: 0, tailwinds: 0, lighthouses: record?.lighthouses ?? 0,
                               lastLighthouseName: record?.lastLighthouseName ?? "", cloudTouches: 0, maxSpeed: 0,
                               maxAltitude: 0, longestCleanMeters: 0, birdID: runBird)
        var outcome = RecordOutcome()
        outcome.best = store.data.bestMeters
        outcome.previousBest = store.data.bestMeters
        outcome.dailyCounted = true
        outcome.dailyStreak = store.data.dailyStreak(today: day)
        var card = ResultSummary(result: result, outcome: outcome,
                                 title: "Daily Flight \(AppRules.dailyTag(day: day))", dailyDay: day,
                                 practice: false, share: ShareText.line(for: result, streak: outcome.dailyStreak))
        card.isDailyCard = true
        card.dailySpentUnfiled = record == nil
        card.dailyBest = Self.isDailyBest(result, data: store.data)
        summary = card
        setRoute(.daily)
    }

    /// "Play with touch" on the portrait card: a split-deck Flight (UX-D2).
    func chooseTouchFromPoseCard() {
        touchOverride = true
        if homeLoop {
            start(mode: .flight)
        } else if session != nil {
            let kind = chooseInput()
            if kind != input { setInput(kind) }
        }
    }

    /// QA-1 P2-8: the pose card's touch override ends once the canvas is landscape. A live run keeps touch until the
    /// player answers the return prompt (QA-2 P2-3), so only an idle override is cleared here.
    func clearTouchOverride() {
        guard touchOverride, !isLiveRun else { return }
        touchOverride = false
        refreshInput()
    }

    /// The cover's "Keep flying here" (UX-D1): a split-deck touch run on the cover, behind the Ready ring.
    func keepFlyingHere() {
        guard session != nil, !homeLoop, !recordedFinish else { return }
        coverFlying = true
        touchOverride = true
        setInput(.touch)
        feedback.cue(.splitDeck)
        closingIgnoredUntilSample = true
        if isClosingPaused {
            isClosingPaused = false
            setPause(.closing, false)
        }
        setUserPaused(false)
    }

    /// The cover's "End flight" (UX-D1): records the run as it stands and shows its results on the cover.
    func endFlightHere() {
        guard let session, !homeLoop, !recordedFinish else { return }
        guard flightStart != nil else {
            startAttract()
            return
        }
        let result = tally.result(mode: mode, seed: session.seed, snapshot: session.snapshot, bird: runBird)
        recordedFinish = true
        clearRunPauses()
        record(result, immediate: true)
    }

    func chooseBird(_ id: BirdID) {
        store.selectBird(id)
        if homeLoop { runBird = store.activeBird }
    }

    func chooseTrail(_ id: String) {
        store.selectTrail(id)
        if homeLoop { runTrail = store.activeTrail?.color }
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
            runTrail = store.activeTrail?.color
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
        let fromHome = route == .home && homeLoop
        let morphTuck = titleTuck(now: CACurrentMediaTime(), heldSince: nil, releasedAt: nil)
        finishCaughtRunHeadless(immediate: false)
        resultsTask?.cancel()
        closeOutDaily()
        homeLoop = false
        mode = newMode
        summary = nil
        pausedRun = nil
        deckReturnPrompt = false
        if case let .daily(day, scored) = newMode, scored {
            scoredDailyDay = day
        } else {
            scoredDailyDay = nil
        }
        clearRunPauses()
        setRoute(.playing)
        buildSession()
        // UX-S3 / ART §7: the title bird flies down into the play bird (Home hides its own title bird on `.playing`).
        if fromHome { SceneAdapter.playTitleMorph(scene, tuck: morphTuck) }
        syncIdleTimer()
    }

    private func startAttract() {
        finishCaughtRunHeadless(immediate: false)
        resultsTask?.cancel()
        closeOutDaily()
        homeLoop = true
        mode = .attract
        summary = nil
        pausedRun = nil
        deckReturnPrompt = false
        coverFlying = false
        clearRunPauses()
        setRoute(.home)
        buildSession()
        feedback.silence()
    }

    private func buildSession() {
        runBird = store.activeBird
        runSky = store.activeSky
        runTrail = store.activeTrail?.color
        var best = store.data.bestMeters
        #if DEBUG
        if let demo {
            if let bird = demo.bird { runBird = bird }
            if let sky = demo.sky { runSky = sky }
            if let b = demo.best { best = b }
        }
        #endif
        let runSeed = self.seed(for: mode)
        var countdown = Self.firstCountdown
        if !homeLoop {
            if runsStartedThisLaunch > 0 { countdown = Self.shortCountdown }
            runsStartedThisLaunch += 1
            // R6: a skip gets the full 3-2-1; the school's end, the 1.5 s Ready · Go (calibration is done).
            if let forced = nextCountdown, !schoolSeaRun {
                countdown = forced
                nextCountdown = nil
            }
            #if DEBUG
            if demo?.shortCountdown == true { countdown = Self.shortCountdown }
            #endif
        }
        let newSession = schoolSeaRun
            ? CoreAdapter.makePracticeSession(bird: runBird)
            : CoreAdapter.makeSession(mode: mode, seed: runSeed, bestMeters: best, bird: runBird, countdown: countdown)
        session = newSession
        if case let .countdown(remaining) = newSession.snapshot.phase, remaining.isFinite, remaining > 0 {
            countdownTotal = remaining
        } else {
            countdownTotal = countdown
        }
        recordedFinish = false
        flightStart = nil
        frozen = false
        readyUntil = nil
        hitStopUntil = nil
        slowUntil = nil
        flatHoldUsed = 0
        caughtAt = nil
        calloutUntil = 0
        chainLostUntil = 0
        teachUntil = 0
        splashUntil = 0
        perfectCalloutShown = false
        lastHUDPublish = -1
        lastKmPublish = -1
        toastUntil = 0
        pendingToast = nil
        lighthouseUntil = 0
        tipUntil = 0
        stormLineShown = false
        hinge.resetFlatOpenings()
        flatTipPending = false
        keepBendShown = false
        tally = RunTally()
        strokeCounter = StrokeCounter()
        runLastLighthouse = ""
        touch.tapToggles = settings.tuckByTapping
        releaseTouches()
        coachOn = !homeLoop && hintsWanted && !schoolSeaRun
        coach = HintCoach(learned: coachOn ? coachLearned : Set([AppHint.fold.rawValue, AppHint.open.rawValue,
                                                                  AppHint.land.rawValue]))
        hud.reset()
        chainTeachRun = !store.data.learnedHints.contains("chain") && !schoolSeaRun
        // R7 P1-6: the first real run's countdown carries the goal sentence (until Go).
        if firstRealRun && !homeLoop && !schoolSeaRun {
            showTip(RouteRules.objective, seconds: countdownTotal, sessionTime: 0)
        }
        goalNearCued = -1

        let kind = chooseInput()
        if kind == .autopilot {
            // QA-1 P2-14: the Home loop flies the `expert` pilot (the perfect one's full planner is heavy on Home).
            var skill: PilotSkill = homeLoop ? .expert : .perfect
            #if DEBUG
            if !homeLoop, let demo, let pilot = demo.autopilot { skill = pilot }
            #endif
            autopilot = AutopilotTuckSource(skill: skill, seed: runSeed,
                                            snapshot: { [weak self] in self?.session?.snapshot },
                                            sea: { [weak self] in self?.session?.sea })
        } else {
            autopilot = nil
        }
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
        return true
    }

    private var coachLearned: Set<String> {
        #if DEBUG
        if demo != nil { return [] }
        #endif
        return store.data.learnedHints
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

    /// Leaving today's scored Daily after the drop (Home, Restart, another run) files the distance so far.
    private func closeOutDaily() {
        guard scoredDailyDay != nil else { return }
        if fileDailyProgress(), let day = scoredDailyDay {
            AppTrace.t("SWOOP-T daily left day=\(day) meters=\(AppTrace.int(currentMeters))")
        }
        scoredDailyDay = nil
    }

    /// Files the scored Daily's distance so far (after the drop, before the finish). The store keeps the larger one.
    @discardableResult
    private func fileDailyProgress() -> Bool {
        guard let day = scoredDailyDay, !recordedFinish, flightStart != nil, let s = session?.snapshot else {
            return false
        }
        store.fileDailyPartial(day: day, meters: s.distanceMeters, perfects: s.perfects,
                               lighthouses: s.lighthousesPassed, lastLighthouseName: runLastLighthouse,
                               today: DailySeed.dayNumber(for: Date()))
        GameCenterManager.shared.reportDailyPartial(meters: s.distanceMeters, day: day, progress: store.data)
        return true
    }

    /// QA-1 P1-1: a run in its `caught` window is over. Leaving it steps it headless to `.finished` and records it.
    private func finishCaughtRunHeadless(immediate: Bool) {
        guard !homeLoop, !recordedFinish, let session else { return }
        guard case .caught = session.snapshot.phase else { return }
        // Core R3: `finishCaught()` skips the calm ending with the same result.
        let events = session.finishCaught()
        AppTrace.t("SWOOP-T caught finished headless events=\(events.count)")
        handleFinished(immediate: immediate)
    }

    // MARK: - Events

    private func process(_ events: [FlightEvent], snapshot s: FlightSnapshot, prevChain: Int, now: TimeInterval) {
        let tailwindNow = events.contains(.tailwindStarted)
        for event in events {
            AppTrace.t("SWOOP-T event " + AppTrace.describe(event))
            switch event {
            case .started:
                if flightStart == nil { flightStart = s.time }
                if let day = scoredDailyDay { store.markDailyAttempt(day: day) }
            case let .touchdown(quality, _, chain):
                if quality == .perfect {
                    // R4 P1-8: the rule stays, the presentation is scarce: the text, the hit-stop and VoiceOver only
                    // at chain milestones (3 = Tailwind, 5, 10, 15…), the same rule as Feel's chime and Scene's punch-in.
                    if AppRules.showsPerfectCallout(chain: chain, tailwind: tailwindNow) {
                        perfectCalloutShown = true
                        calloutSerial += 1
                        let text = tailwindNow ? "Tailwind!" : (chain >= 2 ? "Perfect ×\(chain)" : "Perfect")
                        let anchor = SceneAdapter.birdPoint(scene, layout: layout, reported: reportedBirdPoint)
                        hud.setCallout(HUDCallout(text: text, chain: max(chain, 1),
                                                  point: anchor?.point ?? .zero,
                                                  radius: anchor?.radius ?? SceneAdapter.birdRadius,
                                                  serial: calloutSerial))
                        calloutUntil = s.time + Self.calloutSeconds
                        hitStopUntil = now + AppRules.milestoneHitStop
                        announce(tailwindNow ? "Tailwind, chain \(chain)"
                                 : (chain >= 2 ? "Perfect, chain \(chain)" : "Perfect"), priority: 1)
                    }
                } else if quality == .splash {
                    slowUntil = now + Self.splashSlowSeconds
                    // R4 P1-9: the mistake is said at the bird: "Splash", and "×4 lost" when a chain of 3+ broke.
                    calloutSerial += 1
                    let anchor = SceneAdapter.birdPoint(scene, layout: layout, reported: reportedBirdPoint)
                    showSplashMark(splash: true, lostChain: prevChain >= 3 ? prevChain : nil, anchor: anchor?.point,
                                   sessionTime: s.time)
                } else if prevChain >= 3 && chain < prevChain {
                    // R5 P1-2: a chain broken by a plain landing is said too ("×4 lost"), never silent.
                    calloutSerial += 1
                    let anchor = SceneAdapter.birdPoint(scene, layout: layout, reported: reportedBirdPoint)
                    showSplashMark(splash: false, lostChain: prevChain, anchor: anchor?.point, sessionTime: s.time)
                }
            case let .lighthouse(index, name):
                toastSerial += 1
                runLastLighthouse = name
                // R6 D3 (UX §4.3): the big success moment. A 60 ms hit-stop, the card for 1.9 s, then the chip rolls on.
                let placeName = RouteRules.name(index)
                let isNew = index >= store.data.routeReached && !schoolSeaRun
                hud.setReached(HUDReached(index: index, name: placeName, newOnRoute: isNew, serial: toastSerial))
                lighthouseUntil = s.time + Self.reachedCardSeconds
                hitStopUntil = now + AppRules.milestoneHitStop
                if hud.toast?.kind == .milestone { hud.setToast(nil) }
                announce(isNew ? "\(placeName) reached. New on your route." : "\(placeName) reached.", priority: 2)
            case let .milestone(km):
                if AppRules.milestoneToasts(km: km) && hud.lighthouse == nil {
                    toastSerial += 1
                    showToast(HUDToast(kind: .milestone, title: "\(km) km", detail: AppRules.milestoneLine(km),
                                       serial: toastSerial), now: now, sessionTime: s.time)
                }
            case .newBest:
                toastSerial += 1
                showToast(HUDToast(kind: .newBest, title: "New best!", detail: "Every metre now is a record",
                                   serial: toastSerial), now: now, sessionTime: s.time)
            case .stormClose:
                announce("Storm close", priority: 3)
                if coachOn && !coach.learned.contains(AppHint.storm.rawValue) {
                    coach.learned.insert(AppHint.storm.rawValue)
                    if !isDemo { store.learnHint(AppHint.storm.rawValue) }
                    hud.setTeachLine(AppRules.hintText(.storm, touch: false, mirrored: false))
                    teachUntil = s.time + Self.teachSeconds
                }
            case .caught:
                if schoolSeaRun {
                    // No catch in school: back to the step's checkpoint.
                    rewindSchoolSea()
                    return
                }
                releaseTouches()
                forceHUD = true
                caughtAt = s.time
                hud.setCaught(true)
                announce("Caught at \(ShareText.distance(s.distanceMeters))", priority: 3)
            case .finished:
                handleFinished(immediate: false)
            case .tailwindStarted:
                // D4: the first Tailwind ever is explained.
                if !store.data.learnedHints.contains("tailwind") && !schoolSeaRun {
                    if !isDemo { store.learnHint("tailwind") }
                    showTip("Tailwind! 3 Perfects in a row = a burst of speed.", seconds: 3, sessionTime: s.time)
                    // R7 P0-4: the teach line says "Tailwind!"; the callout word clipped out from under it.
                    hud.setCallout(nil)
                }
            case .countdownTick, .launched, .tailwindEnded, .cloudTouched:
                break
            }
        }
    }

    /// The splash word at the bird (R4 P1-9 / R5 P1-2). A missing anchor falls back to the bird's fixed spot (never
    /// `.zero`, which put the word off the bird page).
    private func showSplashMark(splash: Bool, lostChain: Int?, anchor: CGPoint?, sessionTime: Double) {
        // A missing anchor stays nil: the view places it at the bird's default spot in its own canvas.
        let mark = HUDSplashMark(lostChain: lostChain, point: anchor, serial: calloutSerial, splash: splash)
        hud.setSplashMark(mark)
        splashUntil = sessionTime + Self.splashMarkSeconds
        AppTrace.t("SWOOP-T splashMark shown \(mark.text)")
        if lostChain != nil { announce("Chain lost", priority: 1) }
    }

    static func ordinal(_ n: Int) -> String {
        let tens = n % 100
        if tens >= 11 && tens <= 13 { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }

    /// New toasts wait out the fold-blur guard (2.2 s after leaving flat, UX §9).
    private func showToast(_ toast: HUDToast, now: TimeInterval, sessionTime: Double) {
        if hinge.hasHinge && hinge.inFlatBlurGuard(at: now, window: Self.blurGuard) {
            pendingToast = toast
            return
        }
        hud.setToast(toast)
        toastUntil = sessionTime + Self.toastSeconds
    }

    private func updateCoach(_ s: FlightSnapshot, events: [FlightEvent], now: TimeInterval) {
        guard coachOn else { return }
        var flying = false
        if case .flying = s.phase { flying = true }
        var slope = 0.0
        if let sea = session?.sea { slope = sea.slope(at: Double(s.position.x)) }
        if !slope.isFinite { slope = 0 }
        let blurring = hinge.hasHinge && hinge.inFlatBlurGuard(at: now, window: Self.blurGuard)
        let learned = coach.step(time: s.time, flying: flying, slope: slope, skimming: s.skimming, tuck: s.tuck,
                                 events: events, mayOffer: !blurring)
        if !isDemo { for h in learned { store.learnHint(h) } }
        hud.setHint(coach.current)
        hud.setHintDone(coach.done)
    }

    /// Mid-run flat (UX §9): "Keep a little bend" once per run after 2 s flat; leaving flat starts the blur guard.
    /// A one-time line in the bird page's hint slot (the storm line, the Tailwind teach, the flat tip).
    private func showTip(_ text: String, seconds: Double, sessionTime: Double) {
        hud.setTipLine(text)
        tipUntil = sessionTime + seconds
    }

    /// R6 D1.4 (UX §3): the 3rd opening to flat in a run shows the tip, once a session, never inside the blur guard.
    private func watchFlatOpenings(angle: Double, now: TimeInterval) {
        guard isLiveRun, input == .hinge, !schoolSeaRun else { return }
        // Feel's counter (raw openings to ≥ 174°, re-armed under 166°, reset per run).
        if hinge.flatOpenings >= 3 && !flatTipShown { flatTipPending = true }
        if flatTipPending && !hinge.inFlatBlurGuard(at: now, window: Self.blurGuard), let s = session?.snapshot {
            flatTipPending = false
            flatTipShown = true
            showTip("Tip: no need to open flat.\nA slight fold is wings fully spread (and keeps the screen sharp).",
                    seconds: 4, sessionTime: s.time)
        }
    }

    /// R6: "Keep a little bend" is cut (the flat tip replaces it).
    private func watchMidRunFlat(_ s: FlightSnapshot, now: TimeInterval) {
        _ = s
        _ = now
    }

    private func publishHUD(_ s: FlightSnapshot, now: TimeInterval, force forced: Bool) {
        let force = forced || forceHUD
        forceHUD = false
        guard force || lastHUDPublish < 0 || now - lastHUDPublish >= Self.hudInterval else { return }
        lastHUDPublish = now
        let meters = AppRules.hudMeters(s.distanceMeters)
        // QA-2 P2-6: past 1 km the hundredths change at ≤ 4 Hz (10 m steps), so the digits don't roll constantly.
        if meters < 1000 {
            hud.setMeters(meters)
        } else if force || lastKmPublish < 0 || now - lastKmPublish >= Self.kmInterval {
            lastKmPublish = now
            hud.setMeters(meters)
        }
        hud.setLead((AppRules.meterLead(gap: s.gap) * 100).rounded() / 100)
        hud.setChain(s.chain)
        if chainTeachRun && s.chain >= 2 && !store.data.learnedHints.contains("chain") && !isDemo {
            store.learnHint("chain")    // the rest of this run keeps "in a row"; later runs read "✦ ×2"
        }
        hud.setChainTeach(chainTeachRun)
        hud.setPerfects(s.perfects)
        hud.setTailwind((max(s.tailwindRemaining, 0) * 10).rounded() / 10)
        var countdown: Int?
        var word: String?
        var flying = false
        var caught = false
        switch s.phase {
        case let .countdown(remaining):
            let r = remaining.isFinite ? remaining : countdownTotal
            if countdownTotal <= 2.0 {
                word = AppRules.shortCountdownWord(remaining: r, total: countdownTotal)
            } else {
                countdown = min(max(Int(r.rounded(.up)), 1), 3)
            }
        case .flying: flying = true
        case .caught, .finished: caught = true
        }
        hud.setCountdown(countdown)
        hud.setCountdownWord(word)
        hud.setFlying(flying)
        hud.setCaught(caught)
        hud.setStormClose(flying && s.lead < Self.stormCloseLead)
        var isFlight = false
        if case .flight = mode { isFlight = true }
        let bestIn = AppRules.bestIn(meters: s.distanceMeters, best: s.bestMeters, isFlight: isFlight)
        hud.setBestIn(bestIn.map { ($0 / 100).rounded(.up) * 100 })
        if let anchor = SceneAdapter.birdPoint(scene, layout: layout, reported: reportedBirdPoint) {
            hud.setBirdPoint(CGPoint(x: (anchor.point.x / 2).rounded() * 2, y: (anchor.point.y / 2).rounded() * 2))
            hud.setBirdRadius((anchor.radius / 2).rounded() * 2)
        }
        if hud.toast != nil && s.time > toastUntil { hud.setToast(nil) }
        if hud.toast == nil, let pending = pendingToast,
           !(hinge.hasHinge && hinge.inFlatBlurGuard(at: now, window: Self.blurGuard)) {
            pendingToast = nil
            hud.setToast(pending)
            toastUntil = s.time + Self.toastSeconds
        }
        if hud.reached != nil && s.time > lighthouseUntil { hud.setReached(nil) }
        if hud.tipLine != nil && s.time > tipUntil { hud.setTipLine(nil) }
        // R6 (UX §4.2): the goal chip: the next lighthouse and the metres to it (10 m steps); hidden in the countdown
        // and in school; frozen once caught (the Results headline reuses it).
        if !caught {
            let left = (RouteRules.metersLeft(nextIndex: s.lighthousesPassed, metersFlown: s.distanceMeters) / 10)
                .rounded(.up) * 10
            // R7 P0-4: hidden under the pause card (it ghosted through its top).
            hud.setGoal(index: s.lighthousesPassed, metersLeft: left, visible: flying && !schoolSeaRun && !isPausedByReason)
            // Feel F4: one glint at 300 m to go, once per lighthouse.
            if flying && !schoolSeaRun && RouteRules.isNear(metersLeft: left) && goalNearCued != s.lighthousesPassed {
                goalNearCued = s.lighthousesPassed
                feedback.cue(.goalNear)
            }
        }
        var overline = false
        if firstRealRun, let start = flightStart {
            overline = s.time - start < Self.goalOverlineSeconds
            if s.time - start < Self.stormLineSeconds && hud.tipLine == nil && !stormLineShown {
                stormLineShown = true
                showTip("Storm behind you. Don't let it catch you.", seconds: Self.stormLineSeconds, sessionTime: s.time)
            }
        }
        hud.setGoalOverline(overline)
        if hud.callout != nil && s.time > calloutUntil { hud.setCallout(nil) }
        if hud.chainLost != nil && s.time > chainLostUntil { hud.setChainLost(nil) }
        if hud.splashMark != nil && s.time > splashUntil { hud.setSplashMark(nil) }
        hud.setSunPoint(SceneAdapter.sunDesignPoint(scene))
        hud.setLampPoint(hud.reached != nil ? SceneAdapter.lampDesignPoint(scene) : nil)
        // R4 P1-7 / R6 D4: the first 3 runs explain the meter ("Storm", "You", "Too close") for their first seconds.
        var label = false
        if store.data.runs < 3 && !homeLoop && !schoolSeaRun {
            // UX R4 P2-2: after Go only (in the countdown it sat under the bird's wing).
            if let start = flightStart { label = s.time - start < Self.meterLabelSeconds }
        }
        hud.setMeterLabel(label)
        hud.setMeterTeach(store.data.runs < 3 && !homeLoop && !schoolSeaRun)
        if hud.teachLine != nil && s.time > teachUntil { hud.setTeachLine(nil) }
    }

    private func handleFinished(immediate: Bool) {
        // Flight School's practice sea is never recorded: an end (or a catch) rewinds it.
        if schoolSeaRun {
            rewindSchoolSea()
            return
        }
        guard !recordedFinish, let session, let result = session.result else { return }
        recordedFinish = true
        if homeLoop { return }
        if case .attract = result.mode { return }
        record(result, immediate: immediate)
    }

    /// Records a finished (or ended) run and shows its results.
    private func record(_ result: RunResult, immediate: Bool) {
        let today = DailySeed.dayNumber(for: Date())
        let wasHinge = input == .hinge
        let outcome = store.record(result, today: today)
        scoredDailyDay = nil
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("SWOOP-T run meters=\(AppTrace.int(result.meters)) perfects=\(result.perfects) "
                   + "seconds=\(String(format: "%.1f", result.seconds))")
        var built = makeSummary(result, outcome: outcome)
        built.hingeRun = wasHinge
        built.firstRealRun = firstRealRun
        built.explainsDaily = !store.data.learnedHints.contains(AppRules.dailyRowHint)
        // R7 P1-8: an iPhone hears about the Duo once, positively, after its first results (never on first launch).
        built.funFact = !hasHinge && !demoDuo && store.data.runs == 1
        firstRealRun = false
        built.dailyBest = Self.isDailyBest(result, data: store.data)
        if wasHinge && store.data.foldToFlyShown < 5 {
            built.showsFoldHelper = true
            if !isDemo { store.noteFoldToFlyShown() }
        }
        if wasHinge && !isDemo {
            built.showsRestLine = store.addHingeSeconds(result.seconds, day: today)
        }
        var delay = immediate ? 0 : Self.resultsDelay
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
        pausedRun = nil
        foldToFly = FoldToFly()
        hud.setFoldFill(0)
        resultsShownAt = CACurrentMediaTime()
        setRoute(.results)
        if built.outcome.rankUp != nil || built.outcome.showsNewBest { feedback.celebrate() }
        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .screenChanged, argument: nil) }
    }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        // R7 P0-3: "First flight" only with no previous best, on the very first recorded run.
        var title = outcome.isNewBest && outcome.previousBest <= 0 && store.data.runs <= 1 ? "First flight" : "Flight"
        var day: Int?
        var practice = false
        if case let .daily(d, scored) = result.mode {
            day = d
            practice = !scored
            let n = AppRules.dailyTag(day: d)
            title = scored ? "Daily Flight \(n)" : "Daily Flight \(n) · Practice"
        }
        return ResultSummary(result: result, outcome: outcome, title: title, dailyDay: day, practice: practice,
                             share: ShareText.line(for: result, streak: outcome.dailyStreak))
    }

    /// R4 P1-13: a scored Daily that beats every other Daily flown. Pure; tested.
    nonisolated static func isDailyBest(_ result: RunResult, data: ProgressData) -> Bool {
        guard case let .daily(day, scored) = result.mode, scored, result.meters > 0 else { return false }
        let others = data.daily.filter { $0.key != day }.map { $0.value.meters }
        return !others.isEmpty && others.allSatisfy { result.meters > $0 }
    }

    /// Fold to fly again (UX-A3): on Results, a hinge run's player folds and opens the wings.
    private func updateFoldToFly(now: TimeInterval) {
        guard let summary, summary.hingeRun, !summary.isDailyCard, hinge.hasHinge else { return }
        #if DEBUG
        // Duo R3 P2-10: the demo `foldFill` frame is held (the simulator's live hinge would overwrite it).
        if demo?.foldFill != nil { return }
        #endif
        let u = hinge.tuck(at: now)
        let out = foldToFly.update(u: u, now: now, cardAge: now - resultsShownAt, closing: hinge.closing(at: now) || isShut)
        hud.setFoldFill((out.fill * 50).rounded() / 50)
        hud.setFoldArmed(foldToFly.phase != .idle)
        if out.armedNow { feedback.cue(.foldArmed) }
        if out.fired {
            feedback.cue(.foldFired)
            AppTrace.t("SWOOP-T fold to fly again")
            flyAgain()
        }
    }

    /// The paused run for the cover display (UX-D1).
    private func makePausedRun() -> PausedRun? {
        guard let s = session?.snapshot else { return nil }
        var day: Int?
        if case let .daily(d, _) = mode { day = d }
        let gap = s.gap.isFinite ? max(s.gap, 0) / Tuning.pointsPerMeter : 0
        var run = PausedRun(meters: Double(hud.meters), stormMeters: gap, perfects: s.perfects, chain: s.chain,
                            bestMeters: store.data.bestMeters, isScoredDaily: isScoredDaily, day: day)
        run.goalLine = RouteRules.goalLine(nextIndex: s.lighthousesPassed, metersFlown: Double(hud.meters))
        run.inSchool = schoolSeaRun
        return run
    }

    // MARK: - VoiceOver

    /// `.announcement` at most every 1.5 s, priority storm (3) > lighthouse (2) > Perfect (1) (UX §6).
    private func announce(_ text: String, priority: Int) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let now = CACurrentMediaTime()
        if now - lastAnnounce < Self.announceGap && priority <= lastAnnouncePriority { return }
        lastAnnounce = now
        lastAnnouncePriority = priority
        UIAccessibility.post(notification: .announcement, argument: text)
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
            releaseTouches()
            feedback.silence()
            // R5 P1-3: the cards read the HUD's value, so the HUD shows the exact distance first.
            if !homeLoop, let s = session?.snapshot { publishHUD(s, now: CACurrentMediaTime(), force: true) }
            if isLiveRun { pausedRun = makePausedRun() }
        } else if was && !now {
            resumed()
        }
        syncIdleTimer()
    }

    /// Every resume of a live run holds under the "Ready" ring: 1.5 s, or 2.5 s from 0.3 s after the inner display is
    /// back when the Duo was shut (R4 P0-6).
    private func resumed() {
        guard isLiveRun else { return }
        pausedRun = nil
        // Duo R4 P2-4: the cover's own deck ("Keep flying here") has no handover blur: the short hold there.
        let hold = AppRules.readyHold(afterCover: resumeAfterCover && pose == .play, normal: Self.readyHold)
        resumeAfterCover = false
        readyTotal = hold
        let until = CACurrentMediaTime() + hold
        readyUntil = until
        hud.setReady(hold)
        feedback.cue(.reopened)
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
        // R7 P0-3: `session=first:` always starts from the fresh install.
        var data = DemoPresets.progress(demo.session != nil ? .fresh : demo.progress, today: today)
        if let stage = demo.session, stage != .home && stage != .school { data.flightSchool = .done }
        if demo.dailyToday {
            data.daily[today] = DailyRecord(meters: 7_480, perfects: 23, lighthouses: 1,
                                            lastLighthouseName: Lighthouses.name(index: 0, seed: DailySeed.seed(day: today)),
                                            finished: true)
            data.dailyAttempted.insert(today)
        }
        if demo.rankUp {
            for goal in GoalCatalog.goals(forRank: data.rank) { data.goalProgress[goal.id] = 1 }
        }
        store.replace(with: data)
        if demo.screen == .pose { forcedPose = .turn }
        // `cover=midrun` flies 1.2 s first, so the paused run has a distance (the pose is forced at the pause).
        if demo.screen == .cover && demo.coverState != .midrun { forcedPose = .closed }
        if demo.screen == .icon { showsIconExport = true }
        if demo.folded { homeFolded = true }
        if demo.flat { homeFlat = true }
        if demo.badges {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                BadgeExport.renderAll()
            }
        }
        if demo.orientPortrait { DemoOrientation.requestPortrait() }
        // R6 (UX §7): the bird's side, the variants, the existing player.
        if let side = demo.birdSide { settings.chosenBirdSide = side }
        if let half = demo.sharpHalf {
            settings.sharpHalf = half
            settings.wingCheckDone = true    // `sharp=` frames show the checked footnote
        }
        if let o = demo.orientLandscape {
            interfaceSide = o
            DemoOrientation.request(o)
        }
        if demo.schoolTouch { settings.playWithTouch = true }
        if demo.schoolTap { settings.tuckByTapping = true }
        if demo.resultsFrame == .first { firstRealRun = true }
        if demo.flatTip {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, let s = self.session?.snapshot else { return }
                self.flatTipShown = true
                self.showTip("Tip: no need to open flat.\nA slight fold is wings fully spread (and keeps the screen sharp).",
                             seconds: 3600, sessionTime: s.time)
                AppTrace.t("SWOOP-T flatTip shown")
            }
        }
        if demo.schoolStep == .wingCheck {
            // R7 P0-1: the Wing check lives in Settings only; its frames show that check at the phase asked.
            startAttract()
            openWingCheck()
            if let p = demo.schoolPhase.flatMap(WingCheckFlow.Phase.init(rawValue:)) {
                standaloneWingCheck?.force(p)
                wingCheckDisplay = p
            }
            demoWingHeld = true
            AppTrace.t("SWOOP-T wingcheck \(demo.schoolPhase ?? "explain")")
            return
        }
        if let stage = demo.session, launchFirstSession(stage, demo: demo, today: today) { return }
        if let step = demo.schoolStep {
            startSchool(replay: false, at: step)
            school?.demo(phase: demo.schoolPhase, time: CACurrentMediaTime())
            schoolHeld = demo.schoolPhase != nil || !step.isSea
            publishSchool(CACurrentMediaTime())
            AppTrace.t("SWOOP-T school \(step.key) \(demo.schoolPhase ?? "prompt")")
            // UX §7 #11 / #24: the school's pause card, and the cover's "Flight School paused".
            let cover = demo.screen == .cover
            if demo.paused || cover {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard let self, self.isLiveRun else { return }
                    self.setUserPaused(true)
                    if cover {
                        if self.pausedRun == nil { self.pausedRun = self.makePausedRun() }
                        self.forcedPose = .closed
                    }
                    AppTrace.t("SWOOP-T paused user school")
                }
            }
            return
        }
        switch demo.effectiveScreen {
        case .home, .icon, .badges:
            startAttract()
        case .pose:
            if let m = demo.runMode(today: today) { start(mode: m) } else { startAttract() }
        case .cover:
            switch demo.coverState {
            case .home:
                startAttract()
            case .midrun:
                start(mode: demo.runMode(today: today) ?? .flight)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard let self else { return }
                    self.setUserPaused(true)
                    if self.pausedRun == nil { self.pausedRun = self.makePausedRun() }
                    self.forcedPose = .closed
                    AppTrace.t("SWOOP-T cover midrun paused")
                }
            case .results:
                presentDemoResults(demo, today: today)
            }
        case .goals, .birds, .settings, .route:
            startAttract()
            let target: AppRoute
            switch demo.effectiveScreen {
            case .goals: target = .goals
            case .birds: target = .birds
            case .route: target = .route
            default: target = .settings
            }
            setRoute(target)
        case .daily:
            startAttract()
            openDailyCard()
        case .play:
            start(mode: demo.runMode(today: today) ?? .flight)
            if demo.closing {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard let self, self.isLiveRun else { return }
                    self.isClosingPaused = true
                    self.setPause(.closing, true)
                    AppTrace.t("SWOOP-T paused closing")
                }
            }
            if demo.paused {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard let self, self.isLiveRun else { return }
                    self.setUserPaused(true)
                    AppTrace.t("SWOOP-T paused user")
                }
            }
            if demo.holdReady {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard let self, self.isLiveRun else { return }
                    self.readyUntil = CACurrentMediaTime() + 3600
                    self.hud.setReady(1.0)
                    AppTrace.t("SWOOP-T resumed")
                }
            }
        case .results:
            presentDemoResults(demo, today: today)
        }
    }

    /// R7 P0-3 `session=first:<stage>`: one coherent first session. Returns false for `school` with a `school=` step
    /// (the school branch shows it, on the same fresh progress).
    private func launchFirstSession(_ stage: DemoConfig.FirstSession, demo: DemoConfig, today: Int) -> Bool {
        AppTrace.t("SWOOP-T session first \(stage.rawValue)")
        switch stage {
        case .home:
            startAttract()
        case .school:
            if demo.schoolStep != nil { return false }
            startSchool(replay: false, at: .hold)
            schoolHeld = true
            publishSchool(CACurrentMediaTime())
        case .run:
            firstRealRun = true
            start(mode: .flight)
        case .results:
            firstRealRun = true
            presentDemoResults(demo, today: today)
        case .home2, .route, .goals:
            demoRecordFirstRun(today: today)
            startAttract()
            if stage == .route { setRoute(.route) }
            if stage == .goals { setRoute(.goals) }
        }
        return true
    }

    /// Run 1 of the first session, flown headless (casual pilot, seed 7, like `session=first:results`) and recorded.
    private func demoRecordFirstRun(today: Int) {
        let s = CoreAdapter.makeSession(mode: .flight, seed: DemoConfig.defaultSeed, bestMeters: 0, bird: store.activeBird,
                                        countdown: 0)
        s.skipCountdown()
        DemoRunner.playToEnd(s, skill: .casual, seed: DemoConfig.defaultSeed)
        if let r = s.result {
            _ = store.record(r, today: today)
            AppTrace.t("SWOOP-T run meters=\(AppTrace.int(r.meters)) perfects=\(r.perfects) (session first)")
        }
    }

    /// `chain=`, `lead=`, `skipTo=`, `skipCountdown`: the run is really flown headless before the live frames.
    private func seedDemoRun(_ s: FlightSession, demo: DemoConfig, seed: UInt64) {
        // R6: `goalNear` starts 250 m short of the first lighthouse; `resultsFrame=reached|newroute` just past it.
        var skipTo = demo.skipTo
        if skipTo == nil && demo.goalNear { skipTo = RouteRules.meters(0) - 250 }
        if skipTo == nil && (demo.resultsFrame == .reached || demo.resultsFrame == .newroute) {
            skipTo = RouteRules.meters(0) + 150
        }
        let needsFlight = (demo.chain ?? 0) > 0 || demo.lead != nil || skipTo != nil
        if demo.skipCountdown || needsFlight { s.skipCountdown() }
        guard needsFlight else { return }
        var started: Double?
        let note: (FlightEvent, FlightSnapshot) -> Void = { event, snap in
            if case .started = event, started == nil { started = snap.time }
        }
        if let meters = skipTo {
            DemoRunner.fly(s, skill: .perfect, seed: seed, maxSeconds: 600, onEvent: note,
                           until: { $0.distanceMeters >= meters })
            AppTrace.t("SWOOP-T skipped to \(AppTrace.int(s.snapshot.distanceMeters))")
        }
        // Lead first (a wings-spread glide may splash, which breaks a chain), then the chain.
        if let lead = demo.lead {
            DemoRunner.glide(s, maxSeconds: 90, onEvent: note,
                             until: { DemoRunner.isFlying($0) && $0.lead <= lead })
            AppTrace.t(String(format: "SWOOP-T lead seeded %.2f", s.snapshot.lead))
        }
        if let chain = demo.chain, chain > 0 {
            DemoRunner.fly(s, skill: .perfect, seed: seed, maxSeconds: 240, onEvent: note,
                           until: { $0.chain >= chain })
            AppTrace.t("SWOOP-T chain seeded \(s.snapshot.chain) (asked \(chain))")
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
        var built = makeSummary(result, outcome: outcome)
        // R7: the demo card is framed like the real one (`resultsFrame=first`, `session=first:results`).
        built.firstRealRun = firstRealRun
        firstRealRun = false
        built.explainsDaily = !store.data.learnedHints.contains(AppRules.dailyRowHint)
        built.funFact = !hasHinge && !demoDuo && store.data.runs == 1
        if demo.duo || hasHinge || demo.foldFill != nil {
            built.hingeRun = true
            built.showsFoldHelper = true
        }
        showResults(built)
        if let fill = demo.foldFill { hud.setFoldFill(fill) }
    }

    /// Demo `freezeOn=countdown`: session seconds into the 3 s countdown (the "2").
    static let demoCountdownFreezeAt: Double = 1.3

    /// `freezeOn=` / `freezeAt=`: hold the frame once the moment has come.
    private func demoAfterStep(_ s: FlightSnapshot, events: [FlightEvent]) {
        guard let demo, !frozen, !homeLoop else { return }
        let flightTime = flightStart.map { s.time - $0 } ?? -1
        if let at = demo.freezeAt, flightStart != nil, flightTime >= at {
            freeze("time", s)
            return
        }
        guard let target = demo.freezeOn else { return }
        if target == .countdown {
            if case .countdown = s.phase, s.time >= Self.demoCountdownFreezeAt { freeze(target.rawValue, s) }
            return
        }
        if let pending = freezePendingAt {
            if s.time >= pending { freeze(target.rawValue, s) }
            return
        }
        if target == .finished {
            if events.contains(.finished) { freeze(target.rawValue, s) }
            return
        }
        if target == .chainlost {
            // R5: the frame after a chain of 3+ breaks, with the mark held on screen.
            if hud.splashMark?.lostChain != nil { freezePendingAt = s.time + demo.freezeDelay }
            return
        }
        guard flightStart != nil, flightTime >= demo.freezeAfter || target == .caught else { return }
        var hit = events.contains(where: { AppRules.demoMatches(target, $0) })
        if target == .stormclose && DemoRunner.isFlying(s) && s.lead < Self.stormCloseLead { hit = true }
        if target == .flying && DemoRunner.isFlying(s) {
            hit = (!s.skimming && s.altitude >= 120) || flightTime >= demo.freezeAfter + 10
        }
        if hit {
            freezePendingAt = target == .flying ? s.time : s.time + demo.freezeDelay
        }
    }

    /// `freezeOn=flathold`: the countdown's flat / nudge hold, 1 s in.
    private func demoFlatHoldFrame(_ s: FlightSnapshot) {
        guard let demo, demo.freezeOn == .flathold, !frozen, flatHoldUsed >= 1.0 else { return }
        freeze("flathold", s)
    }

    private func freeze(_ reason: String, _ s: FlightSnapshot) {
        frozen = true
        hud.holdFrame = true
        freezePendingAt = nil
        feedback.silence()
        let t = flightStart.map { s.time - $0 } ?? s.time
        AppTrace.t("SWOOP-T freeze \(reason) t=\(String(format: "%.2f", t)) m=\(AppTrace.int(s.distanceMeters)) "
                   + "chain=\(s.chain) lead=\(String(format: "%.2f", s.lead))")
    }
    #endif
}
