import Foundation

/// Tiny deterministic RNG for sound variation (main thread). Named to avoid clashing with Core's `SeededRandom`.
struct FeelDice {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0…1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Uniform in lower…upper.
    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    mutating func seed32() -> UInt32 {
        UInt32(truncatingIfNeeded: next()) | 1
    }
}

/// Swoop's sound design (GAME-DESIGN §7), as pure data: every recipe returns synth commands and the continuous bed is
/// a pure function of the telemetry, so it is all unit-tested and nothing here touches audio hardware.
///
/// Mix intent for a 3-minute run: the wind is the bed and the speedometer (quiet at rest, a full rush with a faint
/// whistle at top speed); the skim hiss and the chimes sit on top; splashes and thunder are the only loud things, and
/// the master limiter keeps every pile-up clean.
enum FeelSoundBook {
    // MARK: Speed

    /// Speeds (pt/s) mapped to 0 (the bird's minimum, 260) … 1 (a fast run; max speed is 2600).
    static let restSpeed = 260.0
    static let fullSpeed = 2200.0

    /// 0…1 speed for the feedback curves.
    static func speedUnit(_ speed: Double) -> Double {
        clamp01((speed - restSpeed) / (fullSpeed - restSpeed))
    }

    // MARK: The continuous bed (wind, skim, rain)

    /// Wind level at rest, at full speed, and the extra a full tuck adds at full speed (before master).
    static let windRestGain: Float = 0.06
    static let windTopGain: Float = 0.30
    static let windTuckGain: Float = 0.05
    /// Wind low-pass cutoff: `windCutoffLow` × `windCutoffRange`^e, e = 0.78·speed + 0.22·tuck (260 Hz … 3.9 kHz).
    static let windCutoffLow = 260.0
    static let windCutoffRange = 15.0
    /// The whistle fades in from this speed (0…1) and peaks at this level.
    static let whistleStart = 0.45
    /// Round 2 (the 3-minute fatigue pass): the whistle is the only tonal part of the bed, so it stays a hint
    /// (0.26 → 0.2, Q 7…12 → 6…10).
    static let whistlePeak: Float = 0.2
    static let whistleQLow = 6.0
    static let whistleQSpan = 4.0
    /// Skim hiss level at rest and at full speed (before master). Round 2: its band tops out at 5.4 kHz (was 6.6), out
    /// of the harshest part of a phone speaker.
    static let skimRestGain: Float = 0.03
    static let skimTopGain: Float = 0.11
    static let skimCenterLow = 3000.0
    static let skimCenterSpan = 2400.0
    /// Rain starts when the lead falls under this fraction, full at 0.
    static let rainLead = 0.3
    static let rainPeak: Float = 0.14
    static let rumblePeak: Float = 0.5
    /// Tailwind's golden glow: a soft D major pad.
    static let tailwindPadGain: Float = 0.02
    static let tailwindPadHz: Float = 293.66
    /// Glide (s) of the frame-by-frame bed, of a fade to quiet (pause, menus), and of the storm catching the bird.
    static let frameGlide: Float = 0.06
    static let fadeGlide: Float = 0.35
    static let caughtGlide: Float = 1.4

    /// Round 6 (D2): the practice sea of Flight School is calm: the wind at this share of its level, half the whistle,
    /// a softer gust, and no rain or rumble whatever the telemetry says.
    static let practiceWindShare: Float = 0.6
    static let practiceWhistleShare: Float = 0.5

    /// The flight bed made calm for the practice sea.
    static func practiceBed(telemetry: FlightTelemetry, master: Float) -> FeelBed {
        var bed = flightBed(telemetry: telemetry, master: master)
        bed.windGain *= practiceWindShare
        bed.whistleGain *= practiceWhistleShare
        bed.gust *= 0.6
        bed.rainGain = 0
        bed.dropRate = 0
        bed.rumbleGain = 0
        return bed
    }

    /// No continuous layers, master kept: menus, pause cards and one-shots stay audible.
    static func idleBed(master: Float, glide: Float = fadeGlide) -> FeelBed {
        var bed = FeelBed()
        bed.master = master
        bed.glide = glide
        bed.gust = 0
        return bed
    }

    /// 0…1 rain for the storm gap: silent at a lead ≥ 0.3, a smoothstep up to full at 0.
    static func rainLevel(lead: Double) -> Double {
        guard lead.isFinite else { return 0 }
        return smoothstep((rainLead - lead) / rainLead)
    }

    /// The continuous layers for this frame. Not playing (menus, countdown, caught): only the master.
    static func flightBed(telemetry: FlightTelemetry, master: Float) -> FeelBed {
        guard telemetry.playing else { return idleBed(master: master) }
        var bed = FeelBed()
        bed.master = master
        bed.glide = frameGlide
        let s = speedUnit(telemetry.speed)
        let tuck = clamp01(telemetry.tuck)
        let air = clamp01(telemetry.altitude / 900)
        let curve = pow(s, 1.3)

        // Wind: louder and brighter with speed, brighter and a little louder with the tuck; thinner up high.
        var wind = Double(windRestGain) + Double(windTopGain - windRestGain) * curve + Double(windTuckGain) * tuck * s
        wind *= 1 - 0.2 * air
        if telemetry.skimming { wind *= 0.9 }
        var exponent = clamp01(0.78 * s + 0.22 * tuck)
        if telemetry.tailwind {
            wind *= 1.08
            exponent = clamp01(exponent + 0.06)
        }
        bed.windGain = Float(wind)
        bed.windCutoff = Float(windCutoffLow * pow(windCutoffRange, exponent))
        bed.gust = Float(0.32 - 0.12 * s)

        // The whistle: only at speed, stronger in a tuck, higher in a tuck and up high.
        let whistle = smoothstep((s - whistleStart) / (1 - whistleStart)) * (0.55 + 0.45 * tuck)
        bed.whistleGain = whistlePeak * Float(whistle)
        bed.whistleHz = Float(650 + 1100 * s + 350 * tuck + 300 * air)
        bed.whistleQ = Float(whistleQLow + whistleQSpan * s)

        // Skim hiss with spray crackle.
        if telemetry.skimming {
            bed.skimGain = skimRestGain + (skimTopGain - skimRestGain) * Float(s)
            bed.skimCenter = Float(skimCenterLow + skimCenterSpan * s)
            bed.sprayRate = Float(120 + 900 * s)
        }

        // The storm closing in.
        let rain = rainLevel(lead: telemetry.lead)
        bed.rainGain = rainPeak * Float(rain)
        bed.dropRate = Float(30 + 420 * rain)
        bed.rumbleGain = rumblePeak * Float(rain)

        if telemetry.tailwind {
            bed.padGain = tailwindPadGain
            bed.padHz = tailwindPadHz
        }
        return bed
    }

    // MARK: The Perfect chain (a rising pentatonic, one step per Perfect)

    /// Major pentatonic degrees (semitones).
    static let pentatonic: [Int] = [0, 2, 4, 7, 9]
    /// The first Perfect's chime (D5).
    static let chimeBaseHz = 587.33
    /// The scale wraps an octave up every 5 Perfects, at most this many octaves (then it cycles the top octave).
    static let chimeMaxOctave = 2

    /// Semitones above `chimeBaseHz` for the n-th Perfect of a chain (1-based; 0 or less plays the first note).
    static func chimeSemitones(chain: Int) -> Int {
        let index = max(chain - 1, 0)
        let octave = min(index / pentatonic.count, chimeMaxOctave)
        return 12 * octave + pentatonic[index % pentatonic.count]
    }

    static func chimeFrequency(chain: Int) -> Double {
        chimeBaseHz * pow(2, Double(chimeSemitones(chain: chain)) / 12)
    }

    // MARK: Flight moments

    /// Leaving a crest: a low "whump" of air (a falling low-passed thump with a short low tone), then a rising swish,
    /// a little brighter and bigger with speed.
    static func launch(speed: Double) -> [FeelSynthCommand] {
        let s = speedUnit(speed)
        let k = Float(0.45 + 0.55 * s)
        return [
            .noise(FeelNoiseSpec(.lowPass, cutoff: 420, to: 150, sweep: 0.12, q: 0.9, attack: 0.006, decay: 0.075,
                                 gain: 0.2 * k)),
            .tone(FeelToneSpec(start: 120, end: 70, glide: 0.1, duration: 0.18, attack: 0.005, decay: 0.06,
                               gain: 0.12 * k, harmonics: 3)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 700, to: Float(2200 + 1200 * s), sweep: 0.22, q: 0.9,
                                 attack: 0.03, decay: 0.1, gain: 0.075 * k, delay: 0.015)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 4200, q: 0.7, attack: 0.002, decay: 0.05, gain: 0.035 * k)),
        ]
    }

    // MARK: The Perfect moment (Round 2: brighter with the chain, a whoosh-pop on the punch-in)

    /// The chime's partial roll-off: 0.3 for the first Perfect, +0.035 per chain step, at most 0.62 (chain 10+).
    static let chimeBrightnessBase = 0.3
    static let chimeBrightnessStep = 0.035
    static let chimeBrightnessMax = 0.62
    /// The App's milestone hit-stop (Round 4: hit-stops only at chain milestones, 60 ms; REVIEW-3-ux P1-2). The pop
    /// and the milestone haptic's second tap land as the world starts moving again. The App should read this value.
    static let hitStop: Float = 0.06

    /// Round 4 (P1-8, "make Perfects special again"): the chain milestones, 3 (Tailwind), then 5, 10, 15, 20…
    /// Only these get the big chime, the whoosh-pop, the hit-stop haptic and (App) the callout and hit-stop. Every
    /// other Perfect gets a soft chime and a light tap.
    static func isChainMilestone(_ chain: Int) -> Bool {
        chain == 3 || (chain >= 5 && chain % 5 == 0)
    }

    /// The soft chime's level against the big one's (about −5 dB), and its decay (s).
    static let softChimeGain = 0.11
    static let softChimeDecay: Float = 0.6

    /// How bright the n-th Perfect's chime rings (0.3 … 0.62).
    static func chimeBrightness(chain: Int) -> Double {
        let steps = Double(max(chain - 1, 0))
        return min(chimeBrightnessBase + chimeBrightnessStep * steps, chimeBrightnessMax)
    }

    /// 0…1: how far up the brightness ramp this chain is (drives the glint layer).
    static func chimeGlow(chain: Int) -> Double {
        (chimeBrightness(chain: chain) - chimeBrightnessBase) / (chimeBrightnessMax - chimeBrightnessBase)
    }

    /// Perfect: a soft bell chime on the rising pentatonic that gets brighter (more and stronger upper partials, a
    /// glassy glint from chain 3) as the chain grows; its level is compensated so brighter never means louder. Under
    /// it, the punch-in: a short soft whoosh through the 35 ms hit-stop and a round "pop" as it releases, and a light
    /// kiss of water.
    static func perfect(chain: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        isChainMilestone(chain) ? perfectMilestone(chain: chain, dice: &dice) : perfectSoft(chain: chain, dice: &dice)
    }

    /// An ordinary Perfect (Round 4): the same rising pentatonic note, soft and short, with a faint octave and a kiss
    /// of water. No whoosh-pop and no glint: those belong to the milestones.
    static func perfectSoft(chain: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let frequency = chimeFrequency(chain: chain)
        let gain = Float(softChimeGain * pow(chimeBaseHz / frequency, 0.3))
        let f = Float(frequency)
        let brightness = Float(chimeBrightness(chain: chain) * 0.85)
        return [
            .ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: softChimeDecay, brightness: brightness,
                               gain: gain, seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: f * 2, partials: 2, decay: 0.25, brightness: 0.3, gain: 0.025,
                               delay: 0.03, seed: dice.seed32())),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 2600, to: 1400, sweep: 0.08, q: 0.9, attack: 0.002, decay: 0.05,
                                 gain: 0.04)),
        ]
    }

    /// A milestone Perfect (3, 5, 10, 15…): the full chime, brighter with the chain, the whoosh-pop through the
    /// hit-stop, a soft bell an octave under for weight, the glint, and from ×10 a three-note sparkle on top.
    static func perfectMilestone(chain: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let frequency = chimeFrequency(chain: chain)
        let glow = chimeGlow(chain: chain)
        // Higher notes sit in the ear's most sensitive band, and brighter partials add loudness: both a touch quieter.
        let gain = Float(0.2 * pow(chimeBaseHz / frequency, 0.3) * (1 - 0.18 * glow))
        let f = Float(frequency)
        let brightness = Float(chimeBrightness(chain: chain))
        var commands: [FeelSynthCommand] = [
            .ring(FeelRingSpec(.chime, fundamental: f, partials: glow > 0.4 ? 6 : 5, decay: 0.9,
                               brightness: brightness, gain: gain, seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: f * 2, partials: 2, decay: 0.35, brightness: 0.3,
                               gain: Float(0.04 + 0.025 * glow), delay: 0.04, seed: dice.seed32())),
            // The punch-in: whoosh (in the hit-stop), then the pop (on its release).
            .noise(FeelNoiseSpec(.bandPass, cutoff: 800, to: 3000, sweep: hitStop, q: 0.8, attack: 0.01,
                                 decay: 0.018, gain: 0.035)),
            .drop(FeelDropSpec(frequency: 520, chirp: 1.9, decay: 0.014, gain: 0.07, delay: hitStop)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 2600, to: 1400, sweep: 0.08, q: 0.9, attack: 0.002, decay: 0.05,
                                 gain: 0.045)),
        ]
        if chain >= 3 {
            // A glassy glint an octave up, growing with the chain (short, so it sparkles rather than rings).
            commands.append(.ring(FeelRingSpec(.glass, fundamental: f * 2, partials: 2, decay: 0.16, brightness: 0.3,
                                               gain: Float(0.015 + 0.03 * glow), delay: 0.02, seed: dice.seed32())))
        }
        // Weight: a soft bell an octave under, so the milestone sounds bigger, not just brighter.
        commands.append(.ring(FeelRingSpec(.chime, fundamental: f / 2, partials: 3, decay: 0.8, brightness: 0.3,
                                           gain: 0.07, delay: 0.01, seed: dice.seed32())))
        if chain >= 10 {
            let sparkle: [Float] = [2093.0, 2637.0, 3136.0]
            for index in 0..<sparkle.count {
                commands.append(.ring(FeelRingSpec(.glass, fundamental: sparkle[index], partials: 2, decay: 0.2,
                                                   brightness: 0.3, gain: 0.035,
                                                   delay: hitStop + 0.05 + 0.06 * Float(index), seed: dice.seed32())))
            }
        }
        return commands
    }

    /// The chain breaks (a splash after a chain of 3+, with the HUD's "×N lost"): never harsh, a soft "oh well". Two quiet, dull chime notes
    /// falling a fourth from the chain's current scale degree (in the base octave), after the splash has had its moment.
    /// Longer chains sound a little more rueful (a touch longer), never louder.
    static func chainBreak(previousChain: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let degree = pentatonic[max(previousChain - 1, 0) % pentatonic.count]
        let top = Float(chimeBaseHz * pow(2, Double(degree) / 12))
        let fall = top * Float(pow(2, -5.0 / 12))
        let length = Float(min(max(previousChain, 2), 10)) * 0.02
        return [
            .ring(FeelRingSpec(.chime, fundamental: top, partials: 3, decay: 0.3 + length, brightness: 0.22,
                               gain: 0.05, delay: 0.22, seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: fall, partials: 3, decay: 0.45 + length, brightness: 0.2,
                               gain: 0.045, delay: 0.36, seed: dice.seed32())),
        ]
    }

    /// Good landing: a soft water touch, no chime.
    static func good(speed: Double, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = Float(speedUnit(speed))
        return [
            .noise(FeelNoiseSpec(.bandPass, cutoff: Float(dice.range(1800, 2100)), to: 900, sweep: 0.1, q: 0.8,
                                 attack: 0.003, decay: 0.06, gain: 0.07 + 0.05 * k)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 500, q: 0.8, attack: 0.002, decay: 0.03, gain: 0.05)),
        ]
    }

    /// Splash: the mistake, wet and heavy. A broad falling burst, a low slap and thud, a fizz of spray, then drops.
    /// Round 4 (P1-9, "splashes must read as mistakes"): a real thud a phone speaker can carry. The body sits in
    /// 180–320 Hz (the old 150 → 55 Hz tone is below what the speaker plays), with a dull falling "plop" and a slap.
    static func splash(speed: Double, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = Float(0.6 + 0.4 * speedUnit(speed))
        var commands: [FeelSynthCommand] = [
            .tone(FeelToneSpec(start: 300, end: 120, glide: 0.12, duration: 0.24, attack: 0.003, decay: 0.08,
                               gain: 0.24 * k, harmonics: 5)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 480, to: 220, sweep: 0.1, q: 1.1, attack: 0.002, decay: 0.06,
                                 gain: 0.22 * k)),
            .drop(FeelDropSpec(frequency: 420, chirp: 0.6, decay: 0.05, gain: 0.12 * k, delay: 0.01)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1300, to: 380, sweep: 0.35, q: 0.7, attack: 0.004, decay: 0.22,
                                 gain: 0.34 * k)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 700, q: 0.8, attack: 0.002, decay: 0.07, gain: 0.26 * k)),
            .tone(FeelToneSpec(start: 150, end: 55, glide: 0.14, duration: 0.3, attack: 0.004, decay: 0.09,
                               gain: 0.2 * k, harmonics: 4)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 3500, q: 0.7, attack: 0.01, decay: 0.12, gain: 0.06 * k,
                                 delay: 0.03)),
        ]
        let times: [Float] = [0.18, 0.31, 0.47, 0.66, 0.9]
        for index in 0..<times.count {
            let gain: Float = 0.09 - 0.012 * Float(index)
            commands.append(.drop(FeelDropSpec(frequency: Float(dice.range(1300, 2600)), chirp: 1.6, decay: 0.035,
                                               gain: gain, delay: times[index])))
        }
        return commands
    }

    /// Tailwind: a warm D major chord swelling in (strummed), a rising breath of air and a glint on top.
    static func tailwindStarted(dice: inout FeelDice) -> [FeelSynthCommand] {
        let chord: [Float] = [293.66, 369.99, 440.0, 587.33]
        var commands: [FeelSynthCommand] = []
        for index in 0..<chord.count {
            commands.append(.tone(FeelToneSpec(start: chord[index], duration: 1.8, attack: 0.22, decay: 0.8,
                                               gain: 0.05, harmonics: 3, vibratoRate: 4.4 + 0.4 * Float(index),
                                               vibratoDepth: 0.003, delay: 0.04 * Float(index))))
        }
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 500, to: 3000, sweep: 0.7, q: 0.7, attack: 0.35,
                                             decay: 0.25, gain: 0.06)))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.3, brightness: 0.35,
                                           gain: 0.04, delay: 0.25, seed: dice.seed32())))
        return commands
    }

    /// Tailwind ran out: a soft falling breath.
    static func tailwindEnded() -> [FeelSynthCommand] {
        [.noise(FeelNoiseSpec(.bandPass, cutoff: 2400, to: 700, sweep: 0.4, q: 0.8, attack: 0.05, decay: 0.15,
                              gain: 0.045))]
    }

    /// The end-stop detent (Round 4, REVIEW-3-duo P1-2): the wings are fully tucked, so squeezing further gains
    /// nothing. A tiny dry wooden tick, felt more than heard.
    static func endStop() -> [FeelSynthCommand] {
        [.ring(FeelRingSpec(.wood, fundamental: 720, partials: 2, decay: 0.008, brightness: 0.3, gain: 0.045))]
    }

    /// Lighthouse bells (one per headland, cycling): C5, B4, D5.
    static let lighthouseBellHz: [Double] = [523.25, 493.88, 587.33]

    /// Passing a lighthouse: a distant bell tolled twice (inharmonic partials, long decay), with the clapper's thunk.
    static func lighthouse(index: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let count = lighthouseBellHz.count
        let f = Float(lighthouseBellHz[((index % count) + count) % count])
        return [
            .noise(FeelNoiseSpec(.lowPass, cutoff: 900, q: 0.8, attack: 0.001, decay: 0.012, gain: 0.03)),
            .ring(FeelRingSpec(.bell, fundamental: f, partials: 6, decay: 1.6, brightness: 0.55, gain: 0.17,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.bell, fundamental: f, partials: 6, decay: 1.4, brightness: 0.5, gain: 0.1,
                               delay: 1.1, seed: dice.seed32())),
        ]
    }

    /// Round 6 (D3, "Gull Point reached!"): the lighthouse is the goal, so reaching one is the big success. The bell
    /// tolls as before. Under it, a warm D-major swell rises, and a glass glint lands as the App's 60 ms hit-stop lets go.
    static func lighthouseReached(index: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands = lighthouse(index: index, dice: &dice)
        let chord: [Float] = [293.66, 369.99, 440.0]
        for (step, frequency) in chord.enumerated() {
            commands.append(.tone(FeelToneSpec(start: frequency, duration: 1.6, attack: 0.18, decay: 0.7, gain: 0.04,
                                               harmonics: 2, vibratoRate: 4.4 + 0.4 * Float(step),
                                               vibratoDepth: 0.003, delay: 0.03 * Float(step))))
        }
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.3, brightness: 0.3,
                                           gain: 0.04, delay: hitStop, seed: dice.seed32())))
        return commands
    }

    /// Round 6 (UX-FLIGHT-SCHOOL F4): 300 m before the next lighthouse, a small "nearly there" glint.
    static func goalNear() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.glass, fundamental: 1760.0, partials: 2, decay: 0.18, brightness: 0.3, gain: 0.05)),
            .ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.22, brightness: 0.3, gain: 0.045,
                               delay: 0.08)),
        ]
    }

    // MARK: Round 6: Flight School (UX-FLIGHT-SCHOOL §1, F4; ART §5: rewards snap, the UI settles)

    /// The school's step chime: a soft chime that climbs the pentatonic one step per lesson (step 0 → D5 … step 7), so
    /// the lesson itself sounds like progress. Short and quiet; a Perfect in step 5 still plays its own.
    static func schoolStep(_ step: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let index = min(max(step, 0), 7)
        let semitones = 12 * (index / pentatonic.count) + pentatonic[index % pentatonic.count]
        let f = Float(chimeBaseHz * pow(2, Double(semitones) / 12))
        return [
            .ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: 0.5, brightness: 0.32, gain: 0.1,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: f * 1.5, partials: 3, decay: 0.45, brightness: 0.3, gain: 0.06,
                               delay: 0.09, seed: dice.seed32())),
        ]
    }

    /// The school rewinds to a checkpoint (0.4 s fade): a soft breath that falls away and comes back, "go again".
    static func schoolRewind() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 2400, to: 700, sweep: 0.2, q: 0.8, attack: 0.04, decay: 0.1,
                                 gain: 0.05)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 700, to: 1800, sweep: 0.2, q: 0.8, attack: 0.05, decay: 0.1,
                                 gain: 0.04, delay: 0.22)),
        ]
    }

    /// Step 7: the storm rolls in for the first time. The thunder, distant and half as loud.
    static func schoolStorm(dice: inout FeelDice) -> [FeelSynthCommand] {
        thunder(dice: &dice).map { (command: FeelSynthCommand) -> FeelSynthCommand in
            switch command {
            case .noise(var spec):
                spec.gain *= 0.5
                return .noise(spec)
            case .tone(var spec):
                spec.gain *= 0.5
                return .tone(spec)
            default:
                return command
            }
        }
    }

    /// Every whole km: a small three-note glass sparkle (C7 E7 G7).
    static func milestone(dice: inout FeelDice) -> [FeelSynthCommand] {
        let notes: [Float] = [2093.0, 2637.0, 3136.0]
        var commands: [FeelSynthCommand] = []
        for index in 0..<notes.count {
            commands.append(.ring(FeelRingSpec(.glass, fundamental: notes[index], partials: 2, decay: 0.25,
                                               brightness: 0.35, gain: 0.05, delay: 0.07 * Float(index),
                                               seed: dice.seed32())))
        }
        return commands
    }

    /// Passing the personal best: a brighter rising four-note chime with a glint (bigger than a milestone).
    static func newBest(dice: inout FeelDice) -> [FeelSynthCommand] {
        let notes: [Float] = [1046.5, 1318.5, 1568.0, 2093.0]
        var commands: [FeelSynthCommand] = []
        for index in 0..<notes.count {
            let last = index == notes.count - 1
            let decay: Float = last ? 0.9 : 0.5
            let gain: Float = last ? 0.11 : 0.085
            commands.append(.ring(FeelRingSpec(.chime, fundamental: notes[index], partials: 4, decay: decay,
                                               brightness: 0.35, gain: gain, delay: 0.085 * Float(index),
                                               seed: dice.seed32())))
        }
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 4186.0, partials: 2, decay: 0.2, brightness: 0.3,
                                           gain: 0.03, delay: 0.3, seed: dice.seed32())))
        return commands
    }

    /// Reaching the clouds: an airy breath and a high glint.
    static func cloudTouched(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.highPass, cutoff: 5000, q: 0.7, attack: 0.08, decay: 0.2, gain: 0.03)),
            .ring(FeelRingSpec(.glass, fundamental: 2793.8, partials: 2, decay: 0.4, brightness: 0.3, gain: 0.035,
                               delay: 0.05, seed: dice.seed32())),
        ]
    }

    /// The storm gets close: distant thunder, a soft crackle then two low rolls (the bed's rain and rumble follow).
    static func thunder(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 900, to: 400, sweep: 0.6, q: 0.7, attack: 0.05, decay: 0.18,
                                 gain: 0.05, delay: Float(dice.range(0.05, 0.15)))),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 320, to: 110, sweep: 1.4, q: 0.8, attack: 0.18, decay: 0.6,
                                 gain: 0.3)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 220, to: 90, sweep: 1.6, q: 0.9, attack: 0.35, decay: 0.9,
                                 gain: 0.26, delay: 0.45)),
            .tone(FeelToneSpec(start: 70, end: 52, glide: 1.0, duration: 2.2, attack: 0.3, decay: 0.8, gain: 0.12,
                               harmonics: 5)),
        ]
    }

    /// The storm catches the bird: the rain sweeps over (swells, then fades), a low soft "whoom", and everything
    /// settles into a calm A major pad with one soft bell. Self-contained one-shots (~5 s), so it plays out even if
    /// the frames stop; the bed fades the wind out underneath (`caughtGlide`).
    static func caught(dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 3000, q: 0.6, attack: 0.7, decay: 1.0, gain: 0.12)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 400, to: 140, sweep: 1.0, q: 0.8, attack: 0.25, decay: 0.5,
                                 gain: 0.12)),
        ]
        let pad: [Float] = [220.0, 277.18, 329.63, 440.0]
        for index in 0..<pad.count {
            commands.append(.tone(FeelToneSpec(start: pad[index], duration: 5.0, attack: 0.9, decay: 1.8, gain: 0.045,
                                               harmonics: 2, vibratoRate: 4.1 + 0.6 * Float(index),
                                               vibratoDepth: 0.003, delay: 0.35)))
        }
        commands.append(.ring(FeelRingSpec(.chime, fundamental: 440, partials: 4, decay: 1.5, brightness: 0.3,
                                           gain: 0.06, delay: 0.6, seed: dice.seed32())))
        return commands
    }

    // MARK: Countdown

    /// 3, 2, 1: a soft marimba blip (E5) with a hint of mallet.
    static func countdownTick() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.marimba, fundamental: 659.25, partials: 3, decay: 0.12, brightness: 0.3, gain: 0.16)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 1200, q: 0.7, attack: 0.0005, decay: 0.006, gain: 0.03)),
        ]
    }

    /// The drop: a higher, longer blip (B5 over B4) and a breath of air.
    static func started() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.marimba, fundamental: 987.77, partials: 3, decay: 0.18, brightness: 0.3, gain: 0.18)),
            .ring(FeelRingSpec(.marimba, fundamental: 493.88, partials: 3, decay: 0.2, brightness: 0.3, gain: 0.08)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 600, to: 2200, sweep: 0.3, q: 0.8, attack: 0.04, decay: 0.12,
                                 gain: 0.05)),
        ]
    }

    // MARK: Round 3: Duo poses, the restart and Home (UX-SPEC §2, §9; F1)
    //
    // All of these are breaths of air and small wooden or bell notes, quieter than any flight moment: the UI settles,
    // the world eases like air (ART §5). None is longer than ~0.8 s.

    /// The first fold on Home: a soft swell of wind under the title bird sweeping into a dart.
    static func homeFold() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.lowPass, cutoff: 300, to: 1400, sweep: 0.5, q: 0.7, attack: 0.25, decay: 0.35,
                                 gain: 0.07)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 900, to: 2200, sweep: 0.6, q: 0.8, attack: 0.3, decay: 0.3,
                                 gain: 0.03, delay: 0.05)),
        ]
    }

    /// Fold-to-fly fired (on top of `uiConfirm`): the wings throw the bird back up, a short rising rush of air.
    static func foldFired() -> [FeelSynthCommand] {
        [.noise(FeelNoiseSpec(.bandPass, cutoff: 500, to: 2600, sweep: 0.3, q: 0.8, attack: 0.05, decay: 0.14,
                              gain: 0.06, delay: 0.04))]
    }

    /// The closing pause (< 95°): a soft falling breath, like wings settling (Brim's pause whoosh).
    static func closing() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1900, to: 520, sweep: 0.34, q: 0.8, attack: 0.07, decay: 0.16,
                                 gain: 0.07)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 700, to: 260, sweep: 0.3, q: 0.7, attack: 0.05, decay: 0.14,
                                 gain: 0.05, delay: 0.04)),
        ]
    }

    /// The Ready ring after a pause or reopening ("Spread your wings"): a rising breath and one low marimba note.
    static func reopened() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 500, to: 1800, sweep: 0.45, q: 0.8, attack: 0.15, decay: 0.2,
                                 gain: 0.05)),
            .ring(FeelRingSpec(.marimba, fundamental: 493.88, partials: 3, decay: 0.16, brightness: 0.3, gain: 0.07,
                               delay: 0.1)),
        ]
    }

    /// The Ready ring lets go and the bird flies on: a lighter cousin of `started`.
    static func go() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.marimba, fundamental: 987.77, partials: 3, decay: 0.15, brightness: 0.3, gain: 0.12)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 600, to: 2200, sweep: 0.25, q: 0.8, attack: 0.03, decay: 0.1,
                                 gain: 0.04)),
        ]
    }

    /// Entering the seated split deck (and the cover's "Keep flying here"): the deck clicks into place, two wood ticks.
    static func splitDeck() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: 900, partials: 3, decay: 0.014, brightness: 0.35, gain: 0.09)),
            .ring(FeelRingSpec(.wood, fundamental: 1200, partials: 3, decay: 0.014, brightness: 0.35, gain: 0.08,
                               delay: 0.07)),
        ]
    }

    /// "Fly with the fold?" (back in book pose): a soft rising two-note question (D5 → A5).
    static func bookPrompt() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.chime, fundamental: 587.33, partials: 3, decay: 0.3, brightness: 0.25, gain: 0.07)),
            .ring(FeelRingSpec(.chime, fundamental: 880.0, partials: 3, decay: 0.4, brightness: 0.25, gain: 0.065,
                               delay: 0.12)),
        ]
    }

    /// The results distance count-up (ART §5: a tick every 0.5 km): a tiny wood tick that climbs a little per step.
    static func resultsTick(step: Int) -> [FeelSynthCommand] {
        let climb = Float(min(max(step, 0), 24)) * 45
        return [.ring(FeelRingSpec(.wood, fundamental: 1400 + climb, partials: 2, decay: 0.01, brightness: 0.35,
                                   gain: 0.05))]
    }

    // MARK: UI

    /// A soft wooden click.
    static func uiTap() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: 1500, partials: 3, decay: 0.012, brightness: 0.4, gain: 0.12)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 3000, q: 0.7, attack: 0.0005, decay: 0.003, gain: 0.05)),
        ]
    }

    /// Two wooden clicks, the second higher.
    static func uiConfirm() -> [FeelSynthCommand] {
        var commands = uiTap()
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 2000, partials: 3, decay: 0.014, brightness: 0.4,
                                           gain: 0.12, delay: 0.06)))
        return commands
    }

    /// Rank up / big moments on the menus: a rising pentatonic arpeggio of chimes over a soft D major chord.
    static func celebrate() -> [FeelSynthCommand] {
        let semitones: [Double] = [0, 2, 4, 7, 12]
        var commands: [FeelSynthCommand] = []
        for index in 0..<semitones.count {
            let last = index == semitones.count - 1
            let frequency = Float(1174.66 * pow(2.0, semitones[index] / 12))
            let decay: Float = last ? 0.9 : 0.4
            let gain: Float = last ? 0.12 : 0.09
            let lateness: Float = last ? 0.02 : 0
            commands.append(.ring(FeelRingSpec(.chime, fundamental: frequency, partials: 4, decay: decay,
                                               brightness: 0.35, gain: gain, delay: 0.09 * Float(index) + lateness,
                                               seed: UInt32(index + 7))))
        }
        let chord: [Float] = [587.33, 739.99, 880.0]
        for frequency in chord {
            commands.append(.tone(FeelToneSpec(start: frequency, duration: 1.2, attack: 0.05, decay: 0.5, gain: 0.03,
                                               harmonics: 2)))
        }
        return commands
    }

    // MARK: Helpers

    static func clamp01(_ value: Double) -> Double {
        FeelMath.clamp01(value)
    }

    static func smoothstep(_ x: Double) -> Double {
        FeelMath.smoothstep(x)
    }
}
