import Foundation
import Testing
@testable import Swoop

/// Renders `blocks` × 512 frames and reports the peak, the energy and whether every sample was finite.
private func feelRender(_ synth: FeelSynth, blocks: Int) -> (peak: Float, energy: Float, finite: Bool) {
    let frames = 512
    let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { buffer.deallocate() }
    var peak: Float = 0
    var energy: Float = 0
    var finite = true
    for _ in 0..<blocks {
        synth.render(frames: frames, into: buffer)
        for index in 0..<frames {
            let value = buffer[index]
            if !value.isFinite { finite = false }
            peak = max(peak, abs(value))
            energy += value * value
        }
    }
    return (peak, energy, finite)
}

private func flying(speed: Double, tuck: Double = 0, skimming: Bool = false, altitude: Double = 120,
                    tailwind: Bool = false, lead: Double = 0.8) -> FlightTelemetry {
    FlightTelemetry(speed: speed, tuck: tuck, skimming: skimming, altitude: altitude, tailwind: tailwind, lead: lead,
                    playing: true)
}

/// Every flight event, once.
private let everyEvent: [FlightEvent] = [
    .countdownTick(3), .countdownTick(2), .countdownTick(1), .started, .launched(speed: 900),
    .touchdown(.perfect, speed: 1100, chain: 1), .touchdown(.perfect, speed: 1200, chain: 2),
    .touchdown(.good, speed: 800, chain: 0), .touchdown(.splash, speed: 700, chain: 0), .tailwindStarted,
    .tailwindEnded, .lighthouse(index: 0, name: "Gull Point"), .cloudTouched, .milestone(km: 1), .newBest,
    .stormClose, .caught, .finished,
]

@MainActor
struct FeedbackTests {
    // MARK: The Perfect chain

    @Test func perfectChainClimbsThePentatonicAndWrapsAnOctaveUp() {
        #expect(FeelSoundBook.chimeSemitones(chain: 1) == 0)
        #expect(FeelSoundBook.chimeSemitones(chain: 2) == 2)
        #expect(FeelSoundBook.chimeSemitones(chain: 3) == 4)
        #expect(FeelSoundBook.chimeSemitones(chain: 4) == 7)
        #expect(FeelSoundBook.chimeSemitones(chain: 5) == 9)
        #expect(FeelSoundBook.chimeSemitones(chain: 6) == 12)
        #expect(FeelSoundBook.chimeSemitones(chain: 7) == 14)
        #expect(FeelSoundBook.chimeSemitones(chain: 11) == 24)
        #expect(FeelSoundBook.chimeSemitones(chain: 15) == 33)
        // Past three octaves it keeps cycling the top octave (never shrill).
        #expect(FeelSoundBook.chimeSemitones(chain: 16) == 24)
        #expect(FeelSoundBook.chimeSemitones(chain: 40) <= 33)
        // No chain (or nonsense) plays the first note.
        #expect(FeelSoundBook.chimeSemitones(chain: 0) == 0)
        #expect(FeelSoundBook.chimeSemitones(chain: -3) == 0)
        // Strictly rising through the first 15, an exact octave at the 6th.
        var previous: Double = 0
        for chain in 1...15 {
            let f = FeelSoundBook.chimeFrequency(chain: chain)
            #expect(f > previous)
            previous = f
        }
        #expect(abs(FeelSoundBook.chimeFrequency(chain: 6) - 2 * FeelSoundBook.chimeBaseHz) < 1e-9)
        #expect(FeelSoundBook.chimeFrequency(chain: 99) < 4500)
    }

    @Test func perfectChimeIsSoftAndPitchedByTheChain() {
        var dice = FeelDice(seed: 7)
        let first = FeelSoundBook.perfect(chain: 1, dice: &dice)
        let later = FeelSoundBook.perfect(chain: 6, dice: &dice)
        var firstPitch: Float = 0
        var laterPitch: Float = 0
        if case .ring(let ring) = first[0] { firstPitch = ring.fundamental }
        if case .ring(let ring) = later[0] { laterPitch = ring.fundamental }
        #expect(abs(laterPitch - 2 * firstPitch) < 0.5)
        for command in first + later {
            #expect(command.gain > 0)
            #expect(command.gain <= 0.25)
        }
    }

    // MARK: The continuous bed

    @Test func windRisesWithSpeedAndBrightensWithTheTuck() {
        let rest = FeelSoundBook.flightBed(telemetry: flying(speed: 260), master: 1)
        let mid = FeelSoundBook.flightBed(telemetry: flying(speed: 1200), master: 1)
        let fast = FeelSoundBook.flightBed(telemetry: flying(speed: 2400), master: 1)
        #expect(rest.windGain < mid.windGain)
        #expect(mid.windGain < fast.windGain)
        #expect(rest.windCutoff < mid.windCutoff)
        #expect(mid.windCutoff < fast.windCutoff)
        // Quiet at rest; no whistle until real speed.
        #expect(rest.windGain <= 0.08)
        #expect(rest.whistleGain == 0)
        #expect(fast.whistleGain > 0)
        let tucked = FeelSoundBook.flightBed(telemetry: flying(speed: 1200, tuck: 1), master: 1)
        #expect(tucked.windCutoff > mid.windCutoff)
        #expect(tucked.windGain >= mid.windGain)
        #expect(fast.master == 1)
    }

    @Test func skimHissOnlyWhileSkimmingAndRainOnlyWhenTheStormIsClose() {
        let air = FeelSoundBook.flightBed(telemetry: flying(speed: 1200), master: 1)
        let skim = FeelSoundBook.flightBed(telemetry: flying(speed: 1200, skimming: true), master: 1)
        let fastSkim = FeelSoundBook.flightBed(telemetry: flying(speed: 2000, skimming: true), master: 1)
        #expect(air.skimGain == 0)
        #expect(skim.skimGain > 0)
        #expect(fastSkim.skimGain > skim.skimGain)
        #expect(FeelSoundBook.rainLevel(lead: 0.8) == 0)
        #expect(FeelSoundBook.rainLevel(lead: 0.3) == 0)
        #expect(FeelSoundBook.rainLevel(lead: 0) == 1)
        #expect(FeelSoundBook.rainLevel(lead: Double.nan) == 0)
        var previous: Double = -1
        var lead: Double = 0.4
        while lead >= 0 {
            let r = FeelSoundBook.rainLevel(lead: lead)
            #expect(r >= previous)
            previous = r
            lead -= 0.02
        }
        let storm = FeelSoundBook.flightBed(telemetry: flying(speed: 1200, lead: 0.05), master: 1)
        #expect(storm.rainGain > 0)
        #expect(storm.rumbleGain > 0)
        #expect(air.rainGain == 0)
    }

    @Test func notPlayingMeansOnlyTheMaster() {
        var telemetry = flying(speed: 2000, tuck: 1, skimming: true, tailwind: true, lead: 0)
        telemetry.playing = false
        let bed = FeelSoundBook.flightBed(telemetry: telemetry, master: 1.25)
        #expect(bed.master == 1.25)
        #expect(bed.windGain == 0)
        #expect(bed.whistleGain == 0)
        #expect(bed.skimGain == 0)
        #expect(bed.rainGain == 0)
        #expect(bed.padGain == 0)
        #expect(bed.glide >= FeelSoundBook.frameGlide)
    }

    // MARK: Moments

    @Test func momentsScaleSensibly() {
        var dice = FeelDice(seed: 11)
        let slowLaunch = FeelSoundBook.launch(speed: 300).map { $0.gain }.max() ?? 0
        let fastLaunch = FeelSoundBook.launch(speed: 2400).map { $0.gain }.max() ?? 0
        #expect(fastLaunch > slowLaunch)
        let good = FeelSoundBook.good(speed: 1000, dice: &dice).map { $0.gain }.max() ?? 0
        let splash = FeelSoundBook.splash(speed: 1000, dice: &dice).map { $0.gain }.max() ?? 0
        #expect(splash > good * 2)
        // Every recipe is non-empty, finite and never absurdly hot.
        let recipes: [[FeelSynthCommand]] = [
            FeelSoundBook.launch(speed: 1500), FeelSoundBook.perfect(chain: 3, dice: &dice),
            FeelSoundBook.good(speed: 1500, dice: &dice), FeelSoundBook.splash(speed: 2600, dice: &dice),
            FeelSoundBook.tailwindStarted(dice: &dice), FeelSoundBook.tailwindEnded(),
            FeelSoundBook.lighthouse(index: 4, dice: &dice), FeelSoundBook.milestone(dice: &dice),
            FeelSoundBook.newBest(dice: &dice), FeelSoundBook.cloudTouched(dice: &dice),
            FeelSoundBook.thunder(dice: &dice), FeelSoundBook.caught(dice: &dice), FeelSoundBook.countdownTick(),
            FeelSoundBook.started(), FeelSoundBook.uiTap(), FeelSoundBook.uiConfirm(), FeelSoundBook.celebrate(),
        ]
        for recipe in recipes {
            #expect(!recipe.isEmpty)
            for command in recipe {
                #expect(command.gain.isFinite)
                #expect(command.gain > 0)
                #expect(command.gain <= 0.4)
                #expect(command.delay >= 0)
            }
        }
        // The lighthouse index wraps (negative too).
        #expect(!FeelSoundBook.lighthouse(index: -1, dice: &dice).isEmpty)
    }

    @Test func theCatchEndsOnALongSoftPad() {
        var dice = FeelDice(seed: 2)
        let caught = FeelSoundBook.caught(dice: &dice)
        var longest: Float = 0
        for command in caught {
            if case .tone(let tone) = command { longest = max(longest, tone.delay + tone.duration) }
        }
        #expect(longest >= 4)
    }

    // MARK: The synth

    @Test func synthRendersEveryLayerAndCueWithoutClipping() {
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelSoundBook.flightBed(telemetry: flying(speed: 2600, tuck: 1, skimming: true, tailwind: true,
                                                            lead: 0), master: FeelAudioEngine.masterGain)
        bed.glide = 0.01
        synth.send(.bed(bed))
        var dice = FeelDice(seed: 3)
        var cues: [FeelSynthCommand] = FeelSoundBook.splash(speed: 2600, dice: &dice)
        cues.append(contentsOf: FeelSoundBook.thunder(dice: &dice))
        cues.append(contentsOf: FeelSoundBook.perfect(chain: 15, dice: &dice))
        cues.append(contentsOf: FeelSoundBook.tailwindStarted(dice: &dice))
        cues.append(contentsOf: FeelSoundBook.lighthouse(index: 0, dice: &dice))
        cues.append(contentsOf: FeelSoundBook.caught(dice: &dice))
        cues.append(contentsOf: FeelSoundBook.launch(speed: 2600))
        for command in cues { synth.send(command) }
        // A deliberately hot pile-up on top: still never clips.
        for index in 0..<20 {
            synth.send(.ring(FeelRingSpec(.bell, fundamental: 400 + Float(index) * 41, partials: 6, decay: 0.5,
                                          gain: 2)))
        }
        let result = feelRender(synth, blocks: 120)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(result.energy > 0)
        #expect(synth.peak < 1)
        #expect(synth.renderCallbacks == 120)
    }

    @Test func windAloneIsAudibleButGentle() {
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.flightBed(telemetry: flying(speed: 1200), master: FeelAudioEngine.masterGain)))
        let result = feelRender(synth, blocks: 60)
        #expect(result.finite)
        #expect(result.peak > 0.002)
        #expect(result.peak < 0.6)
    }

    @Test func synthIsSilentWithMasterAtZero() {
        let synth = FeelSynth(sampleRate: 44_100)
        synth.send(.bed(FeelBed()))
        synth.send(.ring(FeelRingSpec(.chime, fundamental: 880, decay: 0.3, gain: 0.3)))
        let result = feelRender(synth, blocks: 20)
        #expect(result.peak < 0.0001)
    }

    @Test func commandQueueDropsInsteadOfBlockingWhenFull() {
        let synth = FeelSynth(sampleRate: 48_000)
        var accepted = 0
        for _ in 0..<(FeelSynth.queueCapacity * 2) {
            if synth.send(.stopAll) { accepted += 1 }
        }
        #expect(accepted == FeelSynth.queueCapacity - 1)
    }

    // MARK: Haptics

    @Test func hapticRumbleFollowsSpeedAndSharpnessFollowsTheTuck() {
        #expect(FeelHapticBook.rumbleLevel(speed: 2000, playing: false) == 0)
        var previous: Float = -1
        var speed: Double = 0
        while speed <= 2800 {
            let level = FeelHapticBook.rumbleLevel(speed: speed, playing: true)
            #expect(level >= previous)
            #expect(level <= 1)
            previous = level
            speed += 100
        }
        #expect(FeelHapticBook.rumbleSharpness(tuck: 1) > FeelHapticBook.rumbleSharpness(tuck: 0))
        #expect(FeelHapticBook.skimLevel(speed: 1500, skimming: false, playing: true) == 0)
        #expect(FeelHapticBook.skimLevel(speed: 1500, skimming: true, playing: true) > 0)
        #expect(FeelHapticBook.skimLevel(speed: 1500, skimming: true, playing: false) == 0)
    }

    @Test func hapticMomentsHaveTheirShapes() {
        #expect(FeelHapticBook.perfect.notes.filter { $0.kind == .transient }.count == 2)
        let fast = FeelHapticBook.launch(speed: 2400).notes.map { $0.intensity }.max() ?? 0
        let slow = FeelHapticBook.launch(speed: 300).notes.map { $0.intensity }.max() ?? 0
        #expect(fast > slow)
        // Tailwind rises.
        let ramp = FeelHapticBook.tailwind.curve
        #expect(ramp.count >= 2)
        #expect((ramp.last?.value ?? 0) > (ramp.first?.value ?? 1))
        // Splash is the heaviest hit; the catch is a long soft fade; the lighthouse a soft triple.
        let splashPeak = FeelHapticBook.splash.notes.map { $0.intensity }.max() ?? 0
        #expect(splashPeak >= 0.95)
        #expect(FeelHapticBook.caught.length >= 1.2)
        #expect((FeelHapticBook.caught.curve.last?.value ?? 1) == 0)
        #expect(FeelHapticBook.lighthouse.notes.count == 3)
        for note in FeelHapticBook.lighthouse.notes { #expect(note.intensity <= 0.4) }
        let cues: [FeelHapticCue] = [FeelHapticBook.perfect, FeelHapticBook.good, FeelHapticBook.tailwind,
                                     FeelHapticBook.splash, FeelHapticBook.lighthouse, FeelHapticBook.thunder,
                                     FeelHapticBook.caught, FeelHapticBook.countdownTick, FeelHapticBook.started,
                                     FeelHapticBook.milestone, FeelHapticBook.newBest, FeelHapticBook.cloudTouched,
                                     FeelHapticBook.uiTap, FeelHapticBook.uiConfirm, FeelHapticBook.celebrate]
        for cue in cues {
            #expect(!cue.notes.isEmpty)
            #expect(cue.curve.count <= 16)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
            }
        }
    }

    // MARK: The director

    /// Sound and haptics off: the director takes a whole run's worth of events and frames, the menu sounds and a
    /// silence, without starting any engine or crashing.
    @Test func directorHandlesEverythingWithSoundAndHapticsOff() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.respectSilentSwitch = true
        director.start()
        director.start()
        director.handle([], telemetry: FlightTelemetry())
        director.handle([.countdownTick(3)], telemetry: FlightTelemetry())
        for frame in 0..<240 {
            let speed = 260 + 8 * Double(frame)
            let telemetry = flying(speed: speed, tuck: Double(frame % 60) / 60, skimming: frame % 50 < 20,
                                   tailwind: frame > 120, lead: 1 - Double(frame) / 240)
            director.handle(frame == 30 ? everyEvent : [], telemetry: telemetry)
        }
        director.handle([.caught], telemetry: FlightTelemetry(speed: 400, lead: 0, playing: false))
        director.handle([.finished], telemetry: FlightTelemetry())
        director.uiTap()
        director.uiConfirm()
        director.celebrate()
        director.silence()
        director.silence()
        #expect(director.soundOn == false)
        #expect(director.hapticsOn == false)
        #expect(director.respectSilentSwitch)
    }

    @Test func directorEdgeCasesDoNotCrash() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        // Nonsense telemetry and repeated events in one frame.
        let weird = FlightTelemetry(speed: Double.nan, tuck: Double.infinity, skimming: true, altitude: -50,
                                    tailwind: true, lead: Double.nan, playing: true)
        director.handle([.launched(speed: Double.nan), .launched(speed: -5), .touchdown(.perfect, speed: 0, chain: 0),
                         .touchdown(.perfect, speed: 0, chain: 500), .lighthouse(index: -7, name: ""),
                         .milestone(km: -1)], telemetry: weird)
        director.silence()
        director.handle([], telemetry: weird)
        let bed = FeelSoundBook.flightBed(telemetry: weird, master: 1)
        #expect(bed.windGain.isFinite)
        #expect(bed.windCutoff.isFinite)
        #expect(bed.rainGain.isFinite)
    }
}
