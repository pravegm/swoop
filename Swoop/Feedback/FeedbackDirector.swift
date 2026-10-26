import Foundation
import QuartzCore
import UIKit

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

    var hapticsOn: Bool = true {
        didSet {
            guard oldValue != hapticsOn else { return }
            haptics.enabled = hapticsOn
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

    init() {
        // Menus play before any flight frame: start from an audible, empty bed (a master of 0 mutes one-shots too).
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private var master: Float { soundOn ? FeelAudioEngine.masterGain : 0 }

    /// True when this touchdown broke a chain worth mourning: a splash after 2+ Perfects (a lone Perfect lost is not
    /// worth a sound on top of the splash). Pure.
    nonisolated static func chainBroke(previousChain: Int, quality: TouchdownQuality) -> Bool {
        quality == .splash && previousChain >= 2
    }

    /// True while the engines idle (menus, a long pause).
    var idling: Bool { isIdle }

    /// Audio session + engines. Safe to call more than once; also called lazily by the first sound.
    func start() {
        guard !started else { return }
        started = true
        audio.enabled = soundOn
        audio.respectSilentSwitch = respectSilentSwitch
        haptics.enabled = hapticsOn
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
            var bed = FeelSoundBook.flightBed(telemetry: telemetry, master: master)
            if !telemetry.playing {
                bed.glide = now - caughtAt < Self.caughtFadeWindow ? FeelSoundBook.caughtGlide : FeelSoundBook.fadeGlide
            }
            audio.setBed(bed)
        }
        wasPlaying = telemetry.playing
        haptics.update(telemetry: telemetry, now: now)

        for event in events {
            react(to: event, now: now)
        }
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
        haptics.play(FeelHapticBook.uiTap)
    }

    func uiConfirm() {
        ensureStarted()
        audio.play(FeelSoundBook.uiConfirm())
        haptics.play(FeelHapticBook.uiConfirm)
    }

    /// Rank up, a new best on the results card: a rising chime arpeggio and a celebratory pattern.
    func celebrate() {
        ensureStarted()
        audio.play(FeelSoundBook.celebrate())
        haptics.play(FeelHapticBook.celebrate)
    }

    // MARK: - Events

    private func react(to event: FlightEvent, now: CFTimeInterval) {
        switch event {
        case .countdownTick:
            audio.play(FeelSoundBook.countdownTick())
            haptics.play(FeelHapticBook.countdownTick)
        case .started:
            caughtAt = -Double.infinity
            currentChain = 0
            audio.play(FeelSoundBook.started())
            haptics.play(FeelHapticBook.started)
        case .launched(let speed):
            guard now - lastLaunch >= Self.launchGap else { return }
            lastLaunch = now
            audio.play(FeelSoundBook.launch(speed: speed))
            haptics.play(FeelHapticBook.launch(speed: speed))
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
                // The haptic first: it must land on the App's hit-stop, which starts this very frame.
                haptics.play(FeelHapticBook.perfect)
                audio.play(FeelSoundBook.perfect(chain: max(chain, 1), dice: &dice))
            case .good:
                audio.play(FeelSoundBook.good(speed: speed, dice: &dice))
                haptics.play(FeelHapticBook.good)
            case .splash:
                haptics.play(FeelHapticBook.splash)
                audio.play(FeelSoundBook.splash(speed: speed, dice: &dice))
                if Self.chainBroke(previousChain: previousChain, quality: quality) {
                    audio.play(FeelSoundBook.chainBreak(previousChain: previousChain, dice: &dice))
                }
            }
        case .tailwindStarted:
            audio.play(FeelSoundBook.tailwindStarted(dice: &dice))
            haptics.play(FeelHapticBook.tailwind)
        case .tailwindEnded:
            audio.play(FeelSoundBook.tailwindEnded())
        case .lighthouse(let index, _):
            audio.play(FeelSoundBook.lighthouse(index: index, dice: &dice))
            haptics.play(FeelHapticBook.lighthouse)
        case .cloudTouched:
            guard now - lastCloud >= Self.cloudGap else { return }
            lastCloud = now
            audio.play(FeelSoundBook.cloudTouched(dice: &dice))
            haptics.play(FeelHapticBook.cloudTouched)
        case .milestone:
            audio.play(FeelSoundBook.milestone(dice: &dice))
            haptics.play(FeelHapticBook.milestone)
        case .newBest:
            audio.play(FeelSoundBook.newBest(dice: &dice))
            haptics.play(FeelHapticBook.newBest)
        case .stormClose:
            guard now - lastThunder >= Self.thunderGap else { return }
            lastThunder = now
            audio.play(FeelSoundBook.thunder(dice: &dice))
            haptics.play(FeelHapticBook.thunder)
        case .caught:
            caughtAt = now
            // The wind glides out under the rain swell and the calm pad.
            audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.caughtGlide))
            lastBedSend = now
            audio.play(FeelSoundBook.caught(dice: &dice))
            haptics.play(FeelHapticBook.caught)
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
