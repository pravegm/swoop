import Foundation
import QuartzCore
import UIKit

/// Round 9: the guide gull's moves (ART-ROUND-9 §1A).
enum FeelGhostMove: String, CaseIterable, Sendable {
    case dive, soar, land, rhythm
}

/// Round 3: one-shot cues for states the App owns (`FeedbackDirector.cue(_:)`; UX-SPEC §2, §9, §10, F1/F4).
enum FeelCue: Sendable, Equatable {
    /// Home: the first fold of the title bird (≥ 18°): a soft wind swell.
    case homeFold
    /// Results: fold-to-fly armed (= `uiTap`) and fired (= `uiConfirm` plus a rising rush of air).
    case foldArmed
    case foldFired
    /// The closing pause (< 95°): a falling breath. Call it alongside `silence()`.
    case closing
    /// The Ready ring appears after a pause or reopening: a rising breath.
    case reopened
    /// The Ready ring ends and the run goes on.
    case go
    /// The seated split deck starts (also the cover's "Keep flying here").
    case splitDeck
    /// "Fly with the fold?" back in book pose.
    case bookPrompt
    /// The results distance count-up: one tick per 0.5 km (step = 0, 1, 2…).
    case resultsTick(Int)
    /// A finger lands in touch play (Round 4: on every phone, a Duo's deck and cover runs too; the App calls it only
    /// in touch input).
    case touchDown
    /// Round 4 (REVIEW-3-duo P1-2): the hinge tuck hit full (`hinge.consumeEndStop()`): the end-stop detent.
    case endStop
    /// Round 6, Flight School (UX-FLIGHT-SCHOOL F4): step `n` (0…7) succeeded: the climbing step chime and the praise
    /// tap. Also the Wing check's "Got it" (step 2).
    case schoolStep(Int)
    /// The school rewinds to a checkpoint (a missed dive, launch or landing).
    case schoolRewind
    /// Step 7: the storm rolls in for the first time.
    case schoolStorm
    /// 300 m before the next lighthouse (the goal chip).
    case goalNear
    /// Round 9: the guide gull starts a demonstration (a soft "watch" whoosh; sound only, never a haptic).
    case ghost(FeelGhostMove)
    /// Round 9: the title bird morphs into the play bird and drops into the practice sea.
    case schoolMorph
    /// Round 9, step 5: wave `n` (1–3) flown right (its gold bead appears).
    case waveDone(Int)
    /// Round 9, step 6: the Perfect pushes the storm back.
    case stormPushedBack
    /// Round 9, step 6: the first lighthouse rises on the horizon.
    case lighthouseSighted
}

/// Audio + haptics for Swoop (GAME-DESIGN §7). The App calls `start()` once at launch, sets the three toggles from its
/// SettingsStore, then calls `handle(_:telemetry:)` every frame. Everything audible is synthesised in real time
/// (`FeelSynth`); every touch is Core Haptics (`FeelHaptics`).
///
/// Per frame it builds one small value (`FeelBed`), pushes it into a lock-free queue (≤ 60 Hz) and steers the two
/// looping haptic players (≤ 30 Hz); events map to short recipes from `FeelSoundBook` and `FeelHapticBook`. Nothing
/// here allocates per frame beyond the recipes of this frame's events.
///
/// Battery: after `idleDelay` s with no flight (menus, a pause card, the results) the engines idle by themselves (the
/// haptic players stop, the audio engine naps once quiet); a flying frame, an event or a menu sound wakes them.
@MainActor
final class FeedbackDirector: FeedbackSink {
    static let shared = FeedbackDirector()

    /// Seconds without flight (and without events) before the engines idle.
    static let idleDelay: Double = 3
    /// Seconds after `caught` during which the bed glides out slowly (the wind fading into the rain and the pad).
    static let caughtFadeWindow: Double = 3
    /// Minimum gaps (s) between repeats of the same cue (a burst of events never machine-guns).
    static let launchGap: Double = 0.12
    static let touchdownGap: Double = 0.08
    static let cloudGap: Double = 1.5
    static let thunderGap: Double = 4

    var soundOn: Bool = true {
        didSet {
            guard oldValue != soundOn else { return }
            audio.enabled = soundOn
            audio.setBed(FeelSoundBook.idleBed(master: master))
        }
    }

    /// Round 3 (F2): "Haptics: Off | Normal | Strong". Setting it counts as the player's choice; until then the
    /// profile follows the device (`deviceHasFold`: Strong on a Duo, Normal elsewhere).
    var hapticProfile: HapticProfile {
        get { profile }
        set {
            profileChosen = true
            applyProfile(newValue)
        }
    }

    /// Backward compatible (R1/R2 Settings): `hapticProfile != .off`. Turning it on restores the last chosen profile,
    /// or the device default.
    var hapticsOn: Bool {
        get { profile != .off }
        set {
            if !newValue {
                applyProfile(.off)
            } else if profile == .off {
                applyProfile(profileChosen ? lastOnProfile : HapticProfile.defaultFor(hasFold: deviceHasFold))
            }
        }
    }

    /// The App sets this once a hinge has been seen (a Duo). It moves an unchosen profile to Strong.
    var deviceHasFold: Bool = false {
        didSet {
            guard oldValue != deviceHasFold, !profileChosen, profile != .off else { return }
            applyProfile(HapticProfile.defaultFor(hasFold: deviceHasFold))
        }
    }

    var respectSilentSwitch: Bool = false {
        didSet {
            guard oldValue != respectSilentSwitch else { return }
            audio.respectSilentSwitch = respectSilentSwitch
        }
    }

    private let audio = FeelAudioEngine()
    private let haptics = FeelHaptics()
    private var started = false
    private var activationObserver: NSObjectProtocol?
    private var dice = FeelDice(seed: 0x5300_B1D5)
    private var lastBedSend: CFTimeInterval = 0
    private var lastHeal: CFTimeInterval = 0
    private var lastActive: CFTimeInterval = -Double.infinity
    private var isIdle = false
    private var wasPlaying = false
    private var caughtAt: CFTimeInterval = -Double.infinity
    private var lastLaunch: CFTimeInterval = -Double.infinity
    private var lastTouchdown: CFTimeInterval = -Double.infinity
    private var lastCloud: CFTimeInterval = -Double.infinity
    private var lastThunder: CFTimeInterval = -Double.infinity
    /// The Perfect chain as of the last touchdown (Round 2: only a splash breaks it).
    private var currentChain = 0
    private var profile: HapticProfile = .normal
    private var lastOnProfile: HapticProfile = .normal
    private var profileChosen = false
    private var lastLighthouse: CFTimeInterval = -Double.infinity
    private var lastHomeFold: CFTimeInterval = -Double.infinity
    private var lastClosing: CFTimeInterval = -Double.infinity
    private var lastResultsTick: CFTimeInterval = -Double.infinity
    private var lastEndStop: CFTimeInterval = -Double.infinity
    private var lastGoalNear: CFTimeInterval = -Double.infinity

    /// Round 6 (D2): true during Flight School's practice sea: a calm wind, no rain and no thunder. The App sets it
    /// when the school's Sea steps start and clears it when the real run begins.
    var practiceAmbience = false
    /// Seconds around a lighthouse in which a milestone sparkle stays quiet (the bell and its card win).
    static let milestoneLighthouseQuiet: Double = 3

    init() {
        // Menus play before any flight frame: start from an audible, empty bed (a master of 0 mutes one-shots too).
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private var master: Float { soundOn ? FeelAudioEngine.masterGain : 0 }

    /// True when this touchdown broke a chain worth mourning: a splash after 3+ Perfects. Round 3: the same threshold
    /// as the HUD's "×N lost" pill (UX §3), so the sound always has its picture. Pure.
    nonisolated static func chainBroke(previousChain: Int, quality: TouchdownQuality) -> Bool {
        quality == .splash && previousChain >= 3
    }

    /// Round 3 (UX §3: km toasts only at 5, 10, 15 km…; no km toast near a lighthouse): the milestone sparkle follows
    /// the toast, so it sounds only on those. Pure.
    nonisolated static func milestoneAudible(km: Int, lighthouseNearby: Bool) -> Bool {
        km > 0 && km % 5 == 0 && !lighthouseNearby
    }

    /// True while the engines idle (menus, a long pause).
    var idling: Bool { isIdle }

    /// Audio session + engines. Safe to call more than once; also called lazily by the first sound.
    func start() {
        guard !started else { return }
        started = true
        audio.enabled = soundOn
        audio.respectSilentSwitch = respectSilentSwitch
        haptics.enabled = profile != .off
        if profile != .off { haptics.profile = profile }
        audio.start()
        haptics.start()
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.audio.resume()
                self?.haptics.resume()
            }
        }
    }

    // MARK: - Per frame

    func handle(_ events: [FlightEvent], telemetry: FlightTelemetry) {
        ensureStarted()
        let now = CACurrentMediaTime()
        if telemetry.playing || !events.isEmpty {
            lastActive = now
            if isIdle { setIdle(false) }
        } else if !isIdle && now - lastActive > Self.idleDelay {
            setIdle(true)
        }
        if now - lastHeal > 1 {
            lastHeal = now
            if !isIdle {
                audio.heal()
                haptics.heal()
            }
        }

        // The continuous layers. Fading out of flight (countdown, caught) glides slowly instead of cutting.
        let leavingFlight = wasPlaying && !telemetry.playing
        if now - lastBedSend >= 1.0 / 60 || leavingFlight {
            lastBedSend = now
            var bed = practiceAmbience
                ? FeelSoundBook.practiceBed(telemetry: telemetry, master: master)
                : FeelSoundBook.flightBed(telemetry: telemetry, master: master)
            if !telemetry.playing {
                bed.glide = now - caughtAt < Self.caughtFadeWindow ? FeelSoundBook.caughtGlide : FeelSoundBook.fadeGlide
            }
            audio.setBed(bed)
        }
        wasPlaying = telemetry.playing
        haptics.update(telemetry: telemetry, now: now)

        for event in events {
            if case .lighthouse = event { lastLighthouse = now }
        }
        for event in events {
            react(to: event, now: now)
        }
    }

    // MARK: - Round 3 cues (poses, the restart, Home; UX-SPEC §2, §9, §10)

    /// A one-shot cue for a state the App owns. Every cue has sound (the Duo's taptic is weak, so haptics never stand
    /// alone), except the iPhone touch-down click, which is a haptic by design.
    func cue(_ cue: FeelCue) {
        ensureStarted()
        let now = CACurrentMediaTime()
        switch cue {
        case .homeFold:
            guard now - lastHomeFold >= 1.5 else { return }
            lastHomeFold = now
            audio.play(FeelSoundBook.homeFold())
            playHaptic(FeelHapticBook.homeFold)
        case .foldArmed:
            uiTap()
        case .foldFired:
            var sounds = FeelSoundBook.uiConfirm()
            sounds.append(contentsOf: FeelSoundBook.foldFired())
            audio.play(sounds)
            playHaptic(FeelHapticBook.uiConfirm)
        case .closing:
            guard now - lastClosing >= 1 else { return }
            lastClosing = now
            audio.play(FeelSoundBook.closing())
            playHaptic(FeelHapticBook.closing)
        case .reopened:
            audio.play(FeelSoundBook.reopened())
            playHaptic(FeelHapticBook.reopened)
        case .go:
            audio.play(FeelSoundBook.go())
            playHaptic(FeelHapticBook.go)
        case .splitDeck:
            audio.play(FeelSoundBook.splitDeck())
            playHaptic(FeelHapticBook.uiConfirm)
        case .bookPrompt:
            audio.play(FeelSoundBook.bookPrompt())
            playHaptic(FeelHapticBook.uiTap)
        case .resultsTick(let step):
            guard now - lastResultsTick >= 0.04 else { return }
            lastResultsTick = now
            audio.play(FeelSoundBook.resultsTick(step: step))
            playHaptic(FeelHapticBook.resultsTick)
        case .touchDown:
            playHaptic(FeelHapticBook.touchDown)
        case .schoolStep(let step):
            audio.play(FeelSoundBook.schoolStep(step, dice: &dice))
            playHaptic(FeelHapticBook.schoolPraise)
        case .schoolRewind:
            audio.play(FeelSoundBook.schoolRewind())
            playHaptic(FeelHapticBook.schoolRewind)
        case .schoolStorm:
            audio.play(FeelSoundBook.schoolStorm(dice: &dice))
            playHaptic(FeelHapticBook.schoolStorm)
        case .ghost(let move):
            // Sound only: a touch always means the player did something.
            audio.play(FeelSoundBook.ghost(move))
        case .schoolMorph:
            audio.play(FeelSoundBook.schoolMorph())
            playHaptic(FeelHapticBook.schoolMorph)
        case .waveDone(let index):
            audio.play(FeelSoundBook.waveDone(index))
            playHaptic(FeelHapticBook.waveDone)
        case .stormPushedBack:
            audio.play(FeelSoundBook.stormPushedBack())
            playHaptic(FeelHapticBook.stormPushedBack)
        case .lighthouseSighted:
            audio.play(FeelSoundBook.lighthouseSighted(dice: &dice))
        case .goalNear:
            guard now - lastGoalNear >= 2 else { return }
            lastGoalNear = now
            audio.play(FeelSoundBook.goalNear())
            playHaptic(FeelHapticBook.goalNear)
        case .endStop:
            guard now - lastEndStop >= 0.15 else { return }
            lastEndStop = now
            audio.play(FeelSoundBook.endStop())
            playHaptic(FeelHapticBook.endStop)
        }
    }

    /// Round 4 (P1-8): a Perfect at this chain is a milestone (big chime, double tap; the App's callout and
    /// hit-stop). Pure; the App should use the same rule.
    nonisolated static func isPerfectMilestone(chain: Int) -> Bool {
        FeelSoundBook.isChainMilestone(chain)
    }

    private func playHaptic(_ cue: FeelHapticCue) {
        haptics.play(FeelHapticBook.adapt(cue, to: profile))
    }

    private func applyProfile(_ newProfile: HapticProfile) {
        profile = newProfile
        if newProfile != .off {
            lastOnProfile = newProfile
            haptics.profile = newProfile
        }
        haptics.enabled = newProfile != .off
    }

    /// Fade the continuous layers out (pause, menus). One-shots already ringing play out; the engines idle after
    /// `idleDelay` s unless flight resumes.
    func silence() {
        let now = CACurrentMediaTime()
        audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
        haptics.quiet(now: now)
        wasPlaying = false
        // Count the quiet from now (a pause right after a flight frame still waits the full delay).
        lastActive = now
        scheduleIdleCheck()
    }

    // MARK: - Menu sounds

    func uiTap() {
        ensureStarted()
        audio.play(FeelSoundBook.uiTap())
        playHaptic(FeelHapticBook.uiTap)
    }

    func uiConfirm() {
        ensureStarted()
        audio.play(FeelSoundBook.uiConfirm())
        playHaptic(FeelHapticBook.uiConfirm)
    }

    /// Rank up, a new best on the results card: a rising chime arpeggio and a celebratory pattern.
    func celebrate() {
        ensureStarted()
        audio.play(FeelSoundBook.celebrate())
        playHaptic(FeelHapticBook.celebrate)
    }

    // MARK: - Events

    private func react(to event: FlightEvent, now: CFTimeInterval) {
        switch event {
        case .countdownTick:
            audio.play(FeelSoundBook.countdownTick())
            playHaptic(FeelHapticBook.countdownTick)
        case .started:
            caughtAt = -Double.infinity
            currentChain = 0
            audio.play(FeelSoundBook.started())
            playHaptic(FeelHapticBook.started)
        case .launched(let speed):
            guard now - lastLaunch >= Self.launchGap else { return }
            lastLaunch = now
            audio.play(FeelSoundBook.launch(speed: speed))
            haptics.play(FeelHapticBook.launch(speed: speed, profile: profile))
        case .touchdown(let quality, let speed, let chain):
            // A Perfect and a splash always speak; repeats of the soft Good touch are thinned.
            let previousChain = currentChain
            currentChain = max(chain, 0)
            if quality == .good {
                guard now - lastTouchdown >= Self.touchdownGap else { return }
            }
            lastTouchdown = now
            switch quality {
            case .perfect:
                // Round 4: big only at chain milestones (where the App holds the hit-stop), soft otherwise. The haptic
                // goes first: it must land on the hit-stop, which starts this very frame.
                let link = max(chain, 1)
                if Self.isPerfectMilestone(chain: link) {
                    haptics.play(FeelHapticBook.perfect(for: profile))
                } else {
                    haptics.play(FeelHapticBook.perfectSoft(for: profile))
                }
                audio.play(FeelSoundBook.perfect(chain: link, dice: &dice))
            case .good:
                audio.play(FeelSoundBook.good(speed: speed, dice: &dice))
                playHaptic(FeelHapticBook.good)
            case .splash:
                playHaptic(FeelHapticBook.splash)
                audio.play(FeelSoundBook.splash(speed: speed, dice: &dice))
                if Self.chainBroke(previousChain: previousChain, quality: quality) {
                    audio.play(FeelSoundBook.chainBreak(previousChain: previousChain, dice: &dice))
                }
            }
        case .tailwindStarted:
            audio.play(FeelSoundBook.tailwindStarted(dice: &dice))
            playHaptic(FeelHapticBook.tailwind)
        case .tailwindEnded:
            audio.play(FeelSoundBook.tailwindEnded())
        case .lighthouse(let index, _):
            // Round 6 (D3): the lighthouse is the goal, so this is the run's big success moment.
            playHaptic(FeelHapticBook.lighthouseReached)
            audio.play(FeelSoundBook.lighthouseReached(index: index, dice: &dice))
        case .cloudTouched:
            guard now - lastCloud >= Self.cloudGap else { return }
            lastCloud = now
            audio.play(FeelSoundBook.cloudTouched(dice: &dice))
            playHaptic(FeelHapticBook.cloudTouched)
        case .milestone(let km):
            let nearby = now - lastLighthouse < Self.milestoneLighthouseQuiet
            guard Self.milestoneAudible(km: km, lighthouseNearby: nearby) else { return }
            audio.play(FeelSoundBook.milestone(dice: &dice))
            playHaptic(FeelHapticBook.milestone)
        case .newBest:
            audio.play(FeelSoundBook.newBest(dice: &dice))
            playHaptic(FeelHapticBook.newBest)
        case .stormClose:
            guard !practiceAmbience, now - lastThunder >= Self.thunderGap else { return }
            lastThunder = now
            audio.play(FeelSoundBook.thunder(dice: &dice))
            playHaptic(FeelHapticBook.thunder)
        case .caught:
            caughtAt = now
            // The wind glides out under the rain swell and the calm pad.
            audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.caughtGlide))
            lastBedSend = now
            audio.play(FeelSoundBook.caught(dice: &dice))
            playHaptic(FeelHapticBook.caught)
        case .finished:
            break // the calm pad from `caught` is still ringing; the results card may call `celebrate()`
        }
    }

    // MARK: - Helpers

    private func ensureStarted() {
        if !started { start() }
    }

    private func setIdle(_ idle: Bool) {
        guard idle != isIdle else { return }
        isIdle = idle
        if idle {
            audio.setBed(FeelSoundBook.idleBed(master: master))
            haptics.quiet(now: CACurrentMediaTime())
        }
        audio.idle = idle
        haptics.idle = idle
    }

    /// After `silence()` no frames may come (a pause card, the menus): idle once the delay has passed.
    private func scheduleIdleCheck() {
        let delay = Self.idleDelay + 0.05
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self else { return }
            if !self.isIdle && CACurrentMediaTime() - self.lastActive >= Self.idleDelay {
                self.setIdle(true)
            }
        }
    }
}
