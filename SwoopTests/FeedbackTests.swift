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

    // MARK: Round 2: the Perfect moment

    @Test func chimeGetsBrighterWithTheChainButNeverLouder() {
        #expect(abs(FeelSoundBook.chimeBrightness(chain: 1) - FeelSoundBook.chimeBrightnessBase) < 1e-12)
        var previous: Double = 0
        for chain in 1...20 {
            let brightness = FeelSoundBook.chimeBrightness(chain: chain)
            #expect(brightness >= previous)
            #expect(brightness <= FeelSoundBook.chimeBrightnessMax)
            previous = brightness
        }
        #expect(FeelSoundBook.chimeBrightness(chain: 10) > FeelSoundBook.chimeBrightness(chain: 2))
        var dice = FeelDice(seed: 4)
        let one = FeelSoundBook.perfect(chain: 1, dice: &dice)
        let ten = FeelSoundBook.perfect(chain: 10, dice: &dice)
        var oneRing: FeelRingSpec?
        var tenRing: FeelRingSpec?
        if case .ring(let ring) = one[0] { oneRing = ring }
        if case .ring(let ring) = ten[0] { tenRing = ring }
        #expect(oneRing != nil)
        #expect(tenRing != nil)
        #expect((tenRing?.brightness ?? 0) > (oneRing?.brightness ?? 1))
        #expect((tenRing?.partials ?? 0) >= (oneRing?.partials ?? 9))
        // Among the big (milestone) chimes, brighter never means louder.
        let early = FeelSoundBook.perfect(chain: 3, dice: &dice)
        let late = FeelSoundBook.perfect(chain: 15, dice: &dice)
        var earlyGain: Float = 0
        var lateGain: Float = 1
        if case .ring(let ring) = early[0] { earlyGain = ring.gain }
        if case .ring(let ring) = late[0] { lateGain = ring.gain }
        #expect(lateGain <= earlyGain)
        // The glassy glint joins from chain 3.
        let glints = { (commands: [FeelSynthCommand]) -> Int in
            var count = 0
            for command in commands {
                if case .ring(let ring) = command, ring.kind == .glass { count += 1 }
            }
            return count
        }
        // (Built outside `#expect`: the macro can't pass `&dice`.)
        let three = FeelSoundBook.perfect(chain: 3, dice: &dice)
        #expect(glints(one) == 0)
        #expect(glints(three) == 1)
        // Round 4: ×10 is a milestone, so it has the glint plus the three-note glass sparkle.
        #expect(glints(ten) == 4)
    }

    @Test func perfectHasAWhooshPopOnTheHitStopAndItsHapticLandsThere() {
        var dice = FeelDice(seed: 5)
        let cue = FeelSoundBook.perfect(chain: 5, dice: &dice)
        var whoosh = false
        var popAtRelease = false
        for command in cue {
            if case .noise(let noise) = command, noise.delay == 0, noise.cutoffEnd > noise.cutoff,
               noise.sweep <= FeelSoundBook.hitStop + 0.001 {
                whoosh = true
            }
            if case .drop(let drop) = command, abs(drop.delay - FeelSoundBook.hitStop) < 0.0001 {
                popAtRelease = true
                #expect(drop.gain <= 0.1)
            }
        }
        #expect(whoosh)
        #expect(popAtRelease)
        // Round 4: hit-stops only at milestones, 60 ms (REVIEW-3-ux P1-2).
        #expect(abs(FeelSoundBook.hitStop - 0.06) < 0.0001)
        // The haptic: a firm tap the instant the Perfect lands, a lighter keen one as the hit-stop releases.
        let notes = FeelHapticBook.perfect.notes
        #expect(notes.count == 2)
        #expect(notes.allSatisfy { $0.kind == .transient })
        #expect(notes[0].time == 0)
        #expect(abs(notes[1].time - Double(FeelSoundBook.hitStop)) < 1e-6)
        #expect(notes[0].intensity > notes[1].intensity)
        #expect(notes[1].sharpness >= notes[0].sharpness)
    }

    @Test func chainBreakIsSoftFallingAndOnlyAfterARealChain() {
        #expect(FeedbackDirector.chainBroke(previousChain: 5, quality: .splash))
        #expect(FeedbackDirector.chainBroke(previousChain: 3, quality: .splash))
        // Round 3: the same threshold as the HUD's "×N lost" pill (UX §3: a chain ≥ 3).
        #expect(FeedbackDirector.chainBroke(previousChain: 2, quality: .splash) == false)
        #expect(FeedbackDirector.chainBroke(previousChain: 1, quality: .splash) == false)
        #expect(FeedbackDirector.chainBroke(previousChain: 6, quality: .good) == false)
        #expect(FeedbackDirector.chainBroke(previousChain: 6, quality: .perfect) == false)
        var dice = FeelDice(seed: 6)
        for chain in [2, 5, 12, 40] {
            let notes = FeelSoundBook.chainBreak(previousChain: chain, dice: &dice)
            #expect(notes.count == 2)
            var pitches: [Float] = []
            for command in notes {
                // Soft bell notes only: no noise, nothing loud, after the splash has spoken.
                #expect(command.gain <= 0.06)
                #expect(command.delay >= 0.2)
                if case .ring(let ring) = command {
                    pitches.append(ring.fundamental)
                    #expect(ring.brightness <= 0.25)
                    #expect(ring.fundamental < 1000)
                } else {
                    Issue.record("chain break should be ring notes only")
                }
            }
            #expect(pitches.count == 2)
            if pitches.count == 2 { #expect(pitches[1] < pitches[0]) }
        }
    }

    /// The 3-minute fatigue check at a casual Perfect rate (7/min): 8 s of a typical casual stretch (a swell every
    /// 2.5 s: skim, launch, tuck down the next face; a Perfect every 8.6 s, a Good in between), rendered at 48 kHz.
    @Test func aCasualMixStaysComfortableForThreeMinutes() {
        let rate: Float = 48_000
        let synth = FeelSynth(sampleRate: rate)
        let bedOnly = FeelSynth(sampleRate: rate)
        var dice = FeelDice(seed: 9)
        let block = 512
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: block)
        defer { buffer.deallocate() }
        let seconds = 8.0
        let blocks = Int(seconds * Double(rate) / Double(block))
        var mixSum: Double = 0
        var bedSum: Double = 0
        var samples = 0
        var hot = 0
        var finite = true
        var nextLaunch = 1.0
        var nextPerfect = 2.0
        var nextGood = 5.0
        var chain = 0
        for index in 0..<blocks {
            let t = Double(index * block) / Double(rate)
            let phase = t.truncatingRemainder(dividingBy: 2.5) / 2.5
            let skimming = phase < 0.45
            let tuck: Double = (phase > 0.55 && phase < 0.95) ? 1 : 0
            let speed = 1000 + 400 * sin(2 * Double.pi * t / 2.5)
            let telemetry = FlightTelemetry(speed: speed, tuck: tuck, skimming: skimming,
                                            altitude: skimming ? 0 : 150, tailwind: false, lead: 0.6, playing: true)
            let bed = FeelSoundBook.flightBed(telemetry: telemetry, master: FeelAudioEngine.masterGain)
            synth.send(.bed(bed))
            bedOnly.send(.bed(bed))
            if t >= nextLaunch {
                for command in FeelSoundBook.launch(speed: speed) { synth.send(command) }
                nextLaunch += 2.5
            }
            if t >= nextPerfect {
                chain += 1
                for command in FeelSoundBook.perfect(chain: chain, dice: &dice) { synth.send(command) }
                nextPerfect += 60.0 / 7
            }
            if t >= nextGood {
                for command in FeelSoundBook.good(speed: speed, dice: &dice) { synth.send(command) }
                nextGood += 8.6
            }
            synth.render(frames: block, into: buffer)
            for frame in 0..<block {
                let value = buffer[frame]
                if !value.isFinite { finite = false }
                mixSum += Double(value * value)
                if abs(value) > 0.6 { hot += 1 }
            }
            bedOnly.render(frames: block, into: buffer)
            for frame in 0..<block {
                let value = buffer[frame]
                bedSum += Double(value * value)
            }
            samples += block
        }
        let mixRMS = (mixSum / Double(max(samples, 1))).squareRoot()
        let bedRMS = (bedSum / Double(max(samples, 1))).squareRoot()
        #expect(finite)
        // The wind is there, but the bed sits at or under −24 dBFS: something you can listen to for 3 minutes.
        #expect(bedRMS > 0.004)
        #expect(bedRMS < 0.063)
        // With every moment on top it stays under −21 dBFS, and the limiter almost never has to work.
        #expect(mixRMS < 0.09)
        #expect(mixRMS >= bedRMS * 0.9)
        #expect(Double(hot) / Double(max(samples, 1)) < 0.002)
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

    // MARK: Round 3: haptic profiles (F2)

    @Test func hapticProfileDefaultsAndTheBackwardCompatibleToggle() {
        #expect(HapticProfile.defaultFor(hasFold: true) == .strong)
        #expect(HapticProfile.defaultFor(hasFold: false) == .normal)
        #expect(HapticProfile.allCases.map { $0.label } == ["Off", "Normal", "Strong"])
        #expect(HapticProfile(rawValue: "strong") == .strong)
        let director = FeedbackDirector()
        director.soundOn = false
        #expect(director.hapticProfile == .normal)
        // A Duo, no choice made yet: Strong.
        director.deviceHasFold = true
        #expect(director.hapticProfile == .strong)
        #expect(director.hapticsOn)
        // The old Bool still works, and turning it back on restores the profile.
        director.hapticsOn = false
        #expect(director.hapticProfile == .off)
        director.hapticsOn = true
        #expect(director.hapticProfile == .strong)
        // A player's choice sticks, even when the device changes its mind.
        director.hapticProfile = .normal
        director.deviceHasFold = false
        director.deviceHasFold = true
        #expect(director.hapticProfile == .normal)
        director.hapticsOn = false
        director.hapticsOn = true
        #expect(director.hapticProfile == .normal)
        director.hapticProfile = .off
        #expect(director.hapticsOn == false)
    }

    @Test func strongProfileTurnsTapsIntoBurstsTheDuoCanFeel() {
        // Every transient becomes a 55 ms continuous burst at sharpness 0.4; continuous notes get × 1.4.
        let strong = FeelHapticBook.adapt(FeelHapticBook.lighthouse, to: .strong)
        #expect(strong.notes.count == FeelHapticBook.lighthouse.notes.count)
        for (index, note) in strong.notes.enumerated() {
            let original = FeelHapticBook.lighthouse.notes[index]
            #expect(note.kind == .continuous)
            #expect(abs(note.duration - FeelHapticBook.strongBurst) < 1e-9)
            #expect(note.sharpness == FeelHapticBook.strongBurstSharpness)
            #expect(note.intensity >= original.intensity)
            #expect(note.intensity <= 1)
            #expect(note.time == original.time)
        }
        let caught = FeelHapticBook.adapt(FeelHapticBook.caught, to: .strong)
        #expect(caught.curve == FeelHapticBook.caught.curve)
        #expect((caught.notes.first?.intensity ?? 0) > (FeelHapticBook.caught.notes.first?.intensity ?? 1))
        // Normal and Off leave a cue alone.
        #expect(FeelHapticBook.adapt(FeelHapticBook.splash, to: .normal) == FeelHapticBook.splash)
        // Strong Perfect: 2 × 60 ms bursts 80 ms apart. Strong launch: one 80 ms burst.
        let perfect = FeelHapticBook.perfect(for: .strong).notes
        #expect(perfect.count == 2)
        #expect(perfect.allSatisfy { $0.kind == .continuous && abs($0.duration - 0.06) < 1e-9 })
        #expect(abs(perfect[1].time - perfect[0].time - 0.08) < 1e-9)
        #expect(FeelHapticBook.perfect(for: .normal) == FeelHapticBook.perfect)
        let launch = FeelHapticBook.launch(speed: 1500, profile: .strong).notes
        #expect(launch.count == 1)
        #expect(abs((launch.first?.duration ?? 0) - 0.08) < 1e-9)
        // Continuous: × 1.4 (clamped) and a 0.3 floor while skimming.
        let normal = FeelHapticBook.rumbleLevel(speed: 800, playing: true, skimming: false, profile: .normal)
        let loud = FeelHapticBook.rumbleLevel(speed: 800, playing: true, skimming: false, profile: .strong)
        #expect(abs(loud - min(normal * 1.4, 1)) < 1e-6)
        #expect(FeelHapticBook.rumbleLevel(speed: 300, playing: true, skimming: true, profile: .strong) >= 0.3)
        #expect(FeelHapticBook.rumbleLevel(speed: 2600, playing: true, skimming: false, profile: .strong) <= 1)
        #expect(FeelHapticBook.rumbleLevel(speed: 800, playing: false, skimming: true, profile: .strong) == 0)
        #expect(FeelHapticBook.rumbleLevel(speed: 800, playing: true, skimming: true, profile: .off) == 0)
        #expect(FeelHapticBook.skimLevel(speed: 800, skimming: true, playing: true, profile: .strong)
                > FeelHapticBook.skimLevel(speed: 800, skimming: true, playing: true, profile: .normal))
    }

    // MARK: Round 3: cues for the App's states (F1, F4) and the motion language

    @Test func stateCuesAreSoftShortAndAlwaysAudible() {
        let perfectPeak: Float = 0.2
        let cues: [[FeelSynthCommand]] = [
            FeelSoundBook.homeFold(), FeelSoundBook.foldFired(), FeelSoundBook.closing(), FeelSoundBook.reopened(),
            FeelSoundBook.go(), FeelSoundBook.splitDeck(), FeelSoundBook.bookPrompt(),
            FeelSoundBook.resultsTick(step: 0), FeelSoundBook.resultsTick(step: 99), FeelSoundBook.endStop(),
        ]
        for recipe in cues {
            #expect(!recipe.isEmpty)
            for command in recipe {
                #expect(command.gain > 0)
                // Quieter than any flight moment (the UI settles).
                #expect(command.gain < perfectPeak)
                #expect(command.delay >= 0 && command.delay < 0.5)
            }
        }
        // The closing breath falls, the reopening breath rises.
        if case .noise(let fall) = FeelSoundBook.closing()[0] { #expect(fall.cutoffEnd < fall.cutoff) }
        if case .noise(let rise) = FeelSoundBook.reopened()[0] { #expect(rise.cutoffEnd > rise.cutoff) }
        // The count-up ticks climb a little and stop climbing.
        var low: Float = 0
        var high: Float = 0
        var capped: Float = 0
        if case .ring(let a) = FeelSoundBook.resultsTick(step: 0)[0] { low = a.fundamental }
        if case .ring(let b) = FeelSoundBook.resultsTick(step: 10)[0] { high = b.fundamental }
        if case .ring(let c) = FeelSoundBook.resultsTick(step: 500)[0] { capped = c.fundamental }
        #expect(high > low)
        #expect(capped < 3000)
        // F4: the touch-down click only where there is no fold.
        #expect(FeelHapticBook.touchDown.notes.count == 1)
        #expect((FeelHapticBook.touchDown.notes.first?.intensity ?? 1) < 0.5)
    }

    @Test func milestoneSparkleFollowsTheToastRule() {
        // UX §3: km toasts only at 5, 10, 15 km…, never on top of a lighthouse.
        #expect(FeedbackDirector.milestoneAudible(km: 5, lighthouseNearby: false))
        #expect(FeedbackDirector.milestoneAudible(km: 10, lighthouseNearby: false))
        #expect(FeedbackDirector.milestoneAudible(km: 1, lighthouseNearby: false) == false)
        #expect(FeedbackDirector.milestoneAudible(km: 4, lighthouseNearby: false) == false)
        #expect(FeedbackDirector.milestoneAudible(km: 5, lighthouseNearby: true) == false)
        #expect(FeedbackDirector.milestoneAudible(km: 0, lighthouseNearby: false) == false)
        #expect(FeedbackDirector.milestoneAudible(km: -5, lighthouseNearby: false) == false)
    }

    @Test func directorPlaysEveryStateCueWithFeedbackOff() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticProfile = .off
        let cues: [FeelCue] = [.homeFold, .homeFold, .foldArmed, .foldFired, .closing, .reopened, .go, .splitDeck,
                               .bookPrompt, .resultsTick(0), .resultsTick(1), .touchDown, .endStop, .endStop]
        for cue in cues { director.cue(cue) }
        director.deviceHasFold = true
        director.cue(.touchDown)
        #expect(director.hapticProfile == .off)
        #expect(director.hapticsOn == false)
    }

    // MARK: Round 4: Perfects special again (P1-8), the splash's thud (P1-9), the end-stop (P0-6)

    @Test func onlyChainMilestonesGetTheBigPerfect() {
        let milestones = (1...30).filter { FeelSoundBook.isChainMilestone($0) }
        #expect(milestones == [3, 5, 10, 15, 20, 25, 30])
        #expect(FeedbackDirector.isPerfectMilestone(chain: 3))
        #expect(FeedbackDirector.isPerfectMilestone(chain: 4) == false)
        #expect(FeedbackDirector.isPerfectMilestone(chain: 0) == false)
        var dice = FeelDice(seed: 12)
        let soft = FeelSoundBook.perfect(chain: 4, dice: &dice)
        let big = FeelSoundBook.perfect(chain: 5, dice: &dice)
        // Every Perfect still chimes on its pentatonic note.
        var softRing: FeelRingSpec?
        var bigRing: FeelRingSpec?
        if case .ring(let ring) = soft[0] { softRing = ring }
        if case .ring(let ring) = big[0] { bigRing = ring }
        #expect(softRing != nil)
        #expect(bigRing != nil)
        let softPitch = Float(FeelSoundBook.chimeFrequency(chain: 4))
        #expect(abs((softRing?.fundamental ?? 0) - softPitch) < 0.5)
        // The soft one is quieter, shorter and plainer: no whoosh-pop (no drop), no glint.
        #expect((softRing?.gain ?? 1) < (bigRing?.gain ?? 0))
        #expect((softRing?.decay ?? 9) < (bigRing?.decay ?? 0))
        var softDrops = 0
        var softGlass = 0
        for command in soft {
            if case .drop = command { softDrops += 1 }
            if case .ring(let ring) = command, ring.kind == .glass { softGlass += 1 }
            #expect(command.gain <= 0.12)
        }
        #expect(softDrops == 0)
        #expect(softGlass == 0)
        #expect(big.count > soft.count)
        // ×10 adds the sparkle.
        let ten = FeelSoundBook.perfect(chain: 10, dice: &dice)
        #expect(ten.count > big.count)
        // Haptics: a light single tap for an ordinary Perfect, the double tap for a milestone.
        #expect(FeelHapticBook.perfectSoft.notes.count == 1)
        #expect((FeelHapticBook.perfectSoft.notes.first?.intensity ?? 1) < (FeelHapticBook.perfect.notes.first?.intensity ?? 0))
        #expect(FeelHapticBook.perfectSoft(for: .strong).notes.first?.kind == .continuous)
    }

    @Test func splashHasAThudThePhoneSpeakerCanCarry() {
        var dice = FeelDice(seed: 13)
        let splash = FeelSoundBook.splash(speed: 1200, dice: &dice)
        var body = false
        for command in splash {
            if case .tone(let tone) = command, tone.start >= 180, tone.start <= 400, tone.gain >= 0.15 { body = true }
        }
        #expect(body)
        let good = FeelSoundBook.good(speed: 1200, dice: &dice)
        let splashEnergy = splash.map { $0.gain }.reduce(0, +)
        let goodEnergy = good.map { $0.gain }.reduce(0, +)
        #expect(splashEnergy > goodEnergy * 5)
        // The haptic thud lasts through the scene's 80 ms slow-down and sags after it.
        #expect(FeelHapticBook.splash.length >= 0.25)
        #expect((FeelHapticBook.splash.notes.map { $0.intensity }.max() ?? 0) >= 0.95)
        // The synth survives the heavier splash on top of a fast bed.
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.flightBed(telemetry: flying(speed: 2000, skimming: true),
                                                master: FeelAudioEngine.masterGain)))
        for command in splash { synth.send(command) }
        let result = feelRender(synth, blocks: 40)
        #expect(result.finite)
        #expect(result.peak < 1)
    }

    @Test func endStopIsATinyTick() {
        let notes = FeelHapticBook.endStop.notes
        #expect(notes.count == 1)
        #expect(abs((notes.first?.duration ?? 0) - 0.025) < 1e-9)
        #expect(abs((notes.first?.intensity ?? 0) - 0.35) < 1e-6)
        let sound = FeelSoundBook.endStop()
        #expect(sound.count == 1)
        #expect((sound.first?.gain ?? 1) <= 0.05)
    }

    // MARK: Round 6: Flight School cues, the lighthouse reached, the practice sea (UX-FLIGHT-SCHOOL F4, D2, D3)

    @Test func schoolStepChimesClimbAndStaySoft() {
        var dice = FeelDice(seed: 21)
        var previous: Float = 0
        for step in 0...7 {
            let chime = FeelSoundBook.schoolStep(step, dice: &dice)
            #expect(chime.count == 2)
            var pitch: Float = 0
            if case .ring(let ring) = chime[0] { pitch = ring.fundamental }
            #expect(pitch > previous)
            previous = pitch
            for command in chime {
                #expect(command.gain > 0)
                // Softer than a Perfect: the school praises, it doesn't fanfare.
                #expect(command.gain <= 0.1)
            }
        }
        // Out-of-range steps clamp.
        var low: Float = 0
        if case .ring(let ring) = FeelSoundBook.schoolStep(-4, dice: &dice)[0] { low = ring.fundamental }
        #expect(abs(low - Float(FeelSoundBook.chimeBaseHz)) < 0.5)
        // The rewind breath falls, then rises; the school storm is half the real thunder.
        let rewind = FeelSoundBook.schoolRewind()
        if case .noise(let fall) = rewind[0] { #expect(fall.cutoffEnd < fall.cutoff) }
        if case .noise(let rise) = rewind[1] { #expect(rise.cutoffEnd > rise.cutoff) }
        var a = FeelDice(seed: 3)
        var b = FeelDice(seed: 3)
        let storm = FeelSoundBook.schoolStorm(dice: &a).map { $0.gain }.reduce(0, +)
        let thunder = FeelSoundBook.thunder(dice: &b).map { $0.gain }.reduce(0, +)
        #expect(abs(storm - thunder * 0.5) < 0.001)
        #expect(FeelHapticBook.schoolPraise.notes.count == 2)
        #expect((FeelHapticBook.schoolPraise.notes.map { $0.intensity }.max() ?? 1) <= 0.5)
    }

    @Test func lighthouseReachedIsTheBigSuccessOnTheHitStop() {
        var dice = FeelDice(seed: 22)
        let bell = FeelSoundBook.lighthouse(index: 0, dice: &dice)
        let reached = FeelSoundBook.lighthouseReached(index: 0, dice: &dice)
        #expect(reached.count > bell.count)
        var glintOnRelease = false
        for command in reached {
            if case .ring(let ring) = command, ring.kind == .glass, abs(ring.delay - FeelSoundBook.hitStop) < 0.0001 {
                glintOnRelease = true
            }
            #expect(command.gain <= 0.2)
        }
        #expect(glintOnRelease)
        let notes = FeelHapticBook.lighthouseReached.notes
        #expect(notes.count == 4)
        #expect(notes[0].time == 0)
        #expect(abs(notes[1].time - Double(FeelSoundBook.hitStop)) < 1e-6)
        #expect(notes[0].intensity > notes[1].intensity)
        // The goal-near glint is small.
        for command in FeelSoundBook.goalNear() { #expect(command.gain <= 0.05) }
        #expect(FeelHapticBook.goalNear.notes.count == 2)
    }

    @Test func practiceSeaIsCalmWithNoRain() {
        // Even with telemetry that would mean a close storm, the practice sea has no rain and a softer wind.
        let telemetry = flying(speed: 1800, tuck: 1, skimming: false, lead: 0.05)
        let real = FeelSoundBook.flightBed(telemetry: telemetry, master: 1)
        let calm = FeelSoundBook.practiceBed(telemetry: telemetry, master: 1)
        #expect(real.rainGain > 0)
        #expect(calm.rainGain == 0)
        #expect(calm.rumbleGain == 0)
        #expect(calm.dropRate == 0)
        #expect(calm.windGain < real.windGain)
        #expect(abs(calm.windGain - real.windGain * FeelSoundBook.practiceWindShare) < 1e-6)
        #expect(calm.whistleGain <= real.whistleGain * 0.5 + 1e-6)
        #expect(calm.gust < real.gust)
        #expect(calm.windGain > 0)
        // Not playing: still just the master.
        var idle = telemetry
        idle.playing = false
        #expect(FeelSoundBook.practiceBed(telemetry: idle, master: 1).windGain == 0)
    }

    @Test func directorPlaysTheSchoolCuesAndSilencesTheStormInPractice() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticProfile = .off
        director.practiceAmbience = true
        let cues: [FeelCue] = [.schoolStep(0), .schoolStep(3), .schoolStep(7), .schoolRewind, .schoolStorm, .goalNear,
                               .goalNear]
        for cue in cues { director.cue(cue) }
        director.handle([.stormClose, .lighthouse(index: 0, name: "Gull Point")],
                        telemetry: flying(speed: 900, lead: 0.05))
        director.practiceAmbience = false
        director.handle([.stormClose], telemetry: flying(speed: 900, lead: 0.05))
        #expect(director.practiceAmbience == false)
    }

    // MARK: Round 9: the guide gull, the overtake, the school beats

    /// The ghost's "watch" cues can never be mistaken for the player's: breath only (no thump, chime, tick or drop),
    /// about half the level of the player's own swish, in a narrower band.
    @Test func ghostCuesAreSoftBreathsUnlikeThePlayersOwn() {
        let launchPeak = FeelSoundBook.launch(speed: 1000).map { $0.gain }.max() ?? 0
        for move in FeelGhostMove.allCases {
            let cue = FeelSoundBook.ghost(move)
            #expect(!cue.isEmpty)
            for command in cue {
                #expect(command.gain > 0)
                #expect(command.gain <= FeelSoundBook.ghostPeak)
                #expect(command.gain < launchPeak * 0.5)
                if case .noise(let noise) = command {
                    #expect(noise.mode == .bandPass)
                    #expect(noise.q >= 1.5)
                    #expect(noise.cutoff >= 700 && noise.cutoffEnd >= 700)
                } else {
                    Issue.record("a ghost cue must be breath only")
                }
            }
        }
        // Shaped like the move: dive falls, soar rises; rhythm is two down-up pairs.
        if case .noise(let dive) = FeelSoundBook.ghost(.dive)[0] { #expect(dive.cutoffEnd < dive.cutoff) }
        if case .noise(let soar) = FeelSoundBook.ghost(.soar)[0] { #expect(soar.cutoffEnd > soar.cutoff) }
        #expect(FeelSoundBook.ghost(.rhythm).count == 4)
    }

    @Test func caughtOvertakeSweepsThenStrikesOnceThenCalms() {
        var dice = FeelDice(seed: 31)
        let caught = FeelSoundBook.caught(dice: &dice)
        var cracks = 0
        var padStart: Float = 99
        var sweepEnds: Float = 0
        for command in caught {
            switch command {
            case .noise(let noise):
                if noise.mode == .highPass {
                    cracks += 1
                    #expect(abs(noise.delay - FeelSoundBook.caughtStrike) < 0.0001)
                }
                if noise.delay == 0 { sweepEnds = max(sweepEnds, noise.attack + noise.sweep) }
            case .tone(let tone):
                if tone.duration >= 4 { padStart = min(padStart, tone.delay) }
            default:
                break
            }
            #expect(command.gain <= 0.2)
        }
        // One strike, ahead of the bird, inside the 1.2 s sweep; the calm pad only once the front has passed.
        #expect(cracks == 1)
        #expect(FeelSoundBook.caughtStrike < FeelSoundBook.caughtSweep)
        #expect(abs(FeelSoundBook.caughtSweep - 1.2) < 0.0001)
        #expect(abs(padStart - FeelSoundBook.caughtSweep) < 0.0001)
        #expect(sweepEnds <= FeelSoundBook.caughtSweep + 0.6)
        // The haptic: the front's roll and exactly one jolt with the strike.
        let transients = FeelHapticBook.caught.notes.filter { $0.kind == .transient }
        #expect(transients.count == 1)
        #expect(abs((transients.first?.time ?? 0) - Double(FeelSoundBook.caughtStrike)) < 1e-6)
    }

    @Test func schoolBeatsHaveSoftCues() {
        var dice = FeelDice(seed: 32)
        let beats: [[FeelSynthCommand]] = [FeelSoundBook.schoolMorph(), FeelSoundBook.waveDone(1),
                                           FeelSoundBook.waveDone(3), FeelSoundBook.stormPushedBack(),
                                           FeelSoundBook.lighthouseSighted(dice: &dice)]
        for beat in beats {
            #expect(!beat.isEmpty)
            for command in beat {
                #expect(command.gain > 0)
                #expect(command.gain <= 0.08)
            }
        }
        // The wave beads climb, and clamp.
        var pitches: [Float] = []
        for index in [0, 1, 2, 3, 9] {
            if case .ring(let ring) = FeelSoundBook.waveDone(index)[0] { pitches.append(ring.fundamental) }
        }
        #expect(pitches.count == 5)
        if pitches.count == 5 {
            #expect(pitches[0] == pitches[1])
            #expect(pitches[1] < pitches[2])
            #expect(pitches[2] < pitches[3])
            #expect(pitches[3] == pitches[4])
        }
        // The sighting is quieter than the "reached" bell.
        var a = FeelDice(seed: 1)
        var b = FeelDice(seed: 1)
        let sighted = FeelSoundBook.lighthouseSighted(dice: &a).map { $0.gain }.max() ?? 1
        let reached = FeelSoundBook.lighthouseReached(index: 0, dice: &b).map { $0.gain }.max() ?? 0
        #expect(sighted < reached * 0.5)
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticProfile = .off
        let cues: [FeelCue] = [.ghost(.dive), .ghost(.soar), .ghost(.land), .ghost(.rhythm), .schoolMorph,
                               .waveDone(1), .waveDone(2), .waveDone(3), .stormPushedBack, .lighthouseSighted]
        for cue in cues { director.cue(cue) }
        #expect(director.hapticsOn == false)
    }

    // MARK: QA-FINAL (27 Oct): haptic start tags, audio self-repair

    /// QA-FINAL P2-1: the engine's "stopped" hop can land after a newer start built fresh players. A stop from before
    /// the latest start began is stale and must leave them alone; a stop after it is real.
    @Test func aStaleHapticStopNeverOrphansTheNewPlayers() {
        var starts = FeelEngineStarts()
        let first = starts.begin(at: 10, offMain: false)
        let firstDone = starts.finish(first)
        #expect(firstDone)
        // The engine stops at 20 s; `resume()` starts it again at 20.5 s before the stop's hop arrives.
        let second = starts.begin(at: 20.5, offMain: false)
        let secondDone = starts.finish(second)
        #expect(secondDone)
        #expect(second != first)
        #expect(starts.stopIsCurrent(stoppedAt: 20) == false)
        #expect(starts.stopIsCurrent(stoppedAt: 20.5))
        #expect(starts.stopIsCurrent(stoppedAt: 21))
        // Never started: any stop counts.
        #expect(FeelEngineStarts().stopIsCurrent(stoppedAt: 0))
    }

    /// QA-FINAL P2-10: a mid-flight start runs off the main thread. Its completion builds players only if no newer
    /// start, stop or switch-off superseded it, and a second recovery waits for it (up to 2 s).
    @Test func anOffMainHapticStartLandsOnlyIfNothingSupersededIt() {
        var starts = FeelEngineStarts()
        let a = starts.begin(at: 1, offMain: true)
        #expect(starts.isPending(at: 1.5))
        #expect(starts.isPending(at: 1 + FeelEngineStarts.pendingTimeout) == false)
        #expect(starts.isPending(at: Double.nan) == false)
        // A synchronous start (the app active again) supersedes it: the late completion is ignored.
        let b = starts.begin(at: 1.2, offMain: false)
        #expect(starts.isPending(at: 1.3) == false)
        let lateA = starts.finish(a)
        let doneB = starts.finish(b)
        #expect(lateA == false)
        #expect(doneB)
        // A stop (or haptics switched off) cancels a start on its way.
        let c = starts.begin(at: 5, offMain: true)
        starts.cancel()
        let lateC = starts.finish(c)
        #expect(lateC == false)
        #expect(starts.isPending(at: 5.1) == false)
        // An undisturbed off-main start lands.
        let d = starts.begin(at: 6, offMain: true)
        let doneD = starts.finish(d)
        #expect(doneD)
        #expect(starts.isPending(at: 6.1) == false)
    }

    /// QA-FINAL P2-2: a late "app was suspended" `.began` (no `.ended` ever follows) must never switch self-repair off.
    @Test func aLateWasSuspendedInterruptionIsIgnored() {
        #expect(FeelAudioRules.isLiveInterruption(began: true, reason: nil, wasSuspended: false))
        #expect(FeelAudioRules.isLiveInterruption(began: true, reason: 0, wasSuspended: false))
        #expect(FeelAudioRules.isLiveInterruption(began: true, reason: FeelAudioRules.appWasSuspendedReason,
                                                  wasSuspended: false) == false)
        #expect(FeelAudioRules.isLiveInterruption(began: true, reason: nil, wasSuspended: true) == false)
        #expect(FeelAudioRules.isLiveInterruption(began: false, reason: nil, wasSuspended: false) == false)
        #expect(FeelAudioRules.appWasSuspendedReason == 1)
        #expect(FeelAudioRules.soundRetryGap <= 0.5)
    }

    /// QA-FINAL P2-6 and P2-8: a 10 ms IO buffer, and the background pauses the engine until the app is active again
    /// (nothing plays in between). The engine is never started here (no audio hardware is needed).
    @Test func audioUsesATenMillisecondBufferAndRestsInTheBackground() {
        #expect(abs(FeelAudioEngine.ioBufferDuration - 0.01) < 1e-9)
        let audio = FeelAudioEngine()
        audio.enterBackground()
        #expect(audio.inBackground)
        audio.play(FeelSoundBook.uiTap())
        audio.setBed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain))
        audio.heal()
        #expect(audio.isRunning == false)
        audio.resume()
        #expect(audio.inBackground == false)
        #expect(audio.isRunning == false)
    }
}
