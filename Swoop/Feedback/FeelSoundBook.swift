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
    static let whistlePeak: Float = 0.26
    /// Skim hiss level at rest and at full speed (before master).
    static let skimRestGain: Float = 0.03
    static let skimTopGain: Float = 0.12
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
        bed.whistleQ = Float(7 + 5 * s)

        // Skim hiss with spray crackle.
        if telemetry.skimming {
            bed.skimGain = skimRestGain + (skimTopGain - skimRestGain) * Float(s)
            bed.skimCenter = Float(3400 + 3200 * s)
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

    /// Perfect: a soft bell chime on the rising pentatonic, a quiet octave shimmer, and a light kiss of water.
    static func perfect(chain: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let frequency = chimeFrequency(chain: chain)
        // Higher notes sit in the ear's most sensitive band: a touch quieter.
        let gain = Float(0.2 * pow(chimeBaseHz / frequency, 0.3))
        let f = Float(frequency)
        return [
            .ring(FeelRingSpec(.chime, fundamental: f, partials: 5, decay: 0.9, brightness: 0.32, gain: gain,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: f * 2, partials: 2, decay: 0.35, brightness: 0.3, gain: 0.045,
                               delay: 0.04, seed: dice.seed32())),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 2600, to: 1400, sweep: 0.08, q: 0.9, attack: 0.002, decay: 0.05,
                                 gain: 0.05)),
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
    static func splash(speed: Double, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = Float(0.6 + 0.4 * speedUnit(speed))
        var commands: [FeelSynthCommand] = [
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
