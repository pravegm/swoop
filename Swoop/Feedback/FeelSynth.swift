import Foundation
import Synchronization

// MARK: - Commands (main thread → audio thread)
//
// Every payload is a plain value (Floats, Ints, enums without payloads), so copying a command never touches ARC and
// the audio thread can read it from the lock-free queue without allocating or locking. Ported from Brim's PourSynth.

enum FeelFilterMode: Sendable, Equatable {
    case lowPass, bandPass, highPass
}

/// Partial tables for struck resonators.
enum FeelRingKind: Sendable, Equatable {
    /// The Perfect chime: a soft, nearly pure bell (harmonic partials 1, 2, 3, 4.2 … rolled off hard).
    case chime
    /// The lighthouse bell: inharmonic church-bell partials (prime, hum an octave down, minor-third tierce, quint,
    /// nominal), long decay.
    case bell
    /// Countdown ticks: a marimba bar (1, 3.93, 9.3 …).
    case marimba
    /// UI clicks: a wooden tick.
    case wood
    /// Sparkles: glassy, sparse, bright.
    case glass
}

/// A one-shot filtered-noise burst (splashes, whumps, thunder), optionally sweeping its cutoff.
struct FeelNoiseSpec: Sendable, Equatable {
    var mode: FeelFilterMode
    var cutoff: Float
    var cutoffEnd: Float
    var sweep: Float
    var q: Float
    var attack: Float
    /// Exponential decay time constant (s).
    var decay: Float
    var gain: Float
    var delay: Float

    init(_ mode: FeelFilterMode, cutoff: Float, to cutoffEnd: Float? = nil, sweep: Float = 0, q: Float = 0.8,
         attack: Float = 0.002, decay: Float, gain: Float, delay: Float = 0) {
        self.mode = mode
        self.cutoff = cutoff
        self.cutoffEnd = cutoffEnd ?? cutoff
        self.sweep = sweep
        self.q = q
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// A pitched tone with a glide, vibrato and a 1/n harmonic stack (thuds, chord swells, the calm pad).
struct FeelToneSpec: Sendable, Equatable {
    var start: Float
    var end: Float
    var glide: Float
    var duration: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var harmonics: Int
    var vibratoRate: Float
    var vibratoDepth: Float
    var delay: Float

    init(start: Float, end: Float? = nil, glide: Float = 0.1, duration: Float, attack: Float = 0.01, decay: Float,
         gain: Float, harmonics: Int = 1, vibratoRate: Float = 0, vibratoDepth: Float = 0, delay: Float = 0) {
        self.start = start
        self.end = end ?? start
        self.glide = glide
        self.duration = duration
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.harmonics = harmonics
        self.vibratoRate = vibratoRate
        self.vibratoDepth = vibratoDepth
        self.delay = delay
    }
}

/// A struck modal resonator: up to `FeelSynth.maxPartials` decaying sinusoids.
struct FeelRingSpec: Sendable, Equatable {
    var kind: FeelRingKind
    var fundamental: Float
    var partials: Int
    /// Decay time constant of the first partial (s); higher partials decay faster.
    var decay: Float
    /// Amplitude roll-off per partial, 0…1 (higher = brighter).
    var brightness: Float
    var gain: Float
    var delay: Float
    /// Seeds a ±1.5 % partial detune so two strikes never sound identical.
    var seed: UInt32

    init(_ kind: FeelRingKind, fundamental: Float, partials: Int = 4, decay: Float, brightness: Float = 0.5,
         gain: Float, delay: Float = 0, seed: UInt32 = 1) {
        self.kind = kind
        self.fundamental = fundamental
        self.partials = partials
        self.decay = decay
        self.brightness = brightness
        self.gain = gain
        self.delay = delay
        self.seed = seed
    }
}

/// A water droplet (Minnaert bubble): a decaying sine whose pitch chirps upward.
struct FeelDropSpec: Sendable, Equatable {
    var frequency: Float
    /// Pitch ratio reached by the end of the pop (> 1 rises).
    var chirp: Float
    var decay: Float
    var gain: Float
    var delay: Float

    init(frequency: Float, chirp: Float = 1.5, decay: Float, gain: Float, delay: Float = 0) {
        self.frequency = frequency
        self.chirp = chirp
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// The continuous layers (sent every frame, glided per sample on the audio thread).
struct FeelBed: Sendable, Equatable {
    /// Master gain (0 = silent; sound off goes through here).
    var master: Float = 0
    /// Time constant (s) of the glide from the current layers to this bed (frames: ~0.06; silence: ~0.35).
    var glide: Float = 0.06
    /// Wind: low-passed noise. Level and cutoff rise with speed and tuck.
    var windGain: Float = 0
    var windCutoff: Float = 300
    /// The whistle: a resonant band of the same noise, only at high speed.
    var whistleGain: Float = 0
    var whistleHz: Float = 900
    var whistleQ: Float = 8
    /// Depth (0…0.6) of the slow random gust wobble on the wind.
    var gust: Float = 0.25
    /// Skim hiss: brighter band-passed noise with spray crackle while the bird skims.
    var skimGain: Float = 0
    var skimCenter: Float = 4500
    var sprayRate: Float = 0
    /// Rain: broad noise plus sparse droplet ticks (the storm closing in, the catch).
    var rainGain: Float = 0
    var dropRate: Float = 0
    /// The storm's low rolling rumble under the rain.
    var rumbleGain: Float = 0
    /// A soft sustained chord (Tailwind's golden glow).
    var padGain: Float = 0
    var padHz: Float = 293.66

    mutating func approach(_ target: FeelBed, _ k: Float) {
        master += (target.master - master) * k
        windGain += (target.windGain - windGain) * k
        windCutoff += (target.windCutoff - windCutoff) * k
        whistleGain += (target.whistleGain - whistleGain) * k
        whistleHz += (target.whistleHz - whistleHz) * k
        whistleQ = target.whistleQ
        gust += (target.gust - gust) * k
        skimGain += (target.skimGain - skimGain) * k
        skimCenter += (target.skimCenter - skimCenter) * k
        sprayRate += (target.sprayRate - sprayRate) * k
        rainGain += (target.rainGain - rainGain) * k
        dropRate += (target.dropRate - dropRate) * k
        rumbleGain += (target.rumbleGain - rumbleGain) * k
        padGain += (target.padGain - padGain) * k
        padHz += (target.padHz - padHz) * k
    }
}

enum FeelSynthCommand: Sendable, Equatable {
    case bed(FeelBed)
    case noise(FeelNoiseSpec)
    case tone(FeelToneSpec)
    case ring(FeelRingSpec)
    case drop(FeelDropSpec)
    /// Stop every one-shot voice and the continuous layers' grain state now (sound switched off, an interruption).
    case stopAll

    /// Peak gain parameter (0 for `bed`/`stopAll`), for tests.
    var gain: Float {
        switch self {
        case .noise(let spec): return spec.gain
        case .tone(let spec): return spec.gain
        case .ring(let spec): return spec.gain
        case .drop(let spec): return spec.gain
        case .bed, .stopAll: return 0
        }
    }

    /// When the voice starts (s after the command), for tests.
    var delay: Float {
        switch self {
        case .noise(let spec): return spec.delay
        case .tone(let spec): return spec.delay
        case .ring(let spec): return spec.delay
        case .drop(let spec): return spec.delay
        case .bed, .stopAll: return 0
        }
    }
}

// MARK: - DSP building blocks (audio thread)

/// Topology-preserving state-variable filter (Zavalishin), from Squish/Brim. Band-pass normalised to 0 dB at centre.
private struct FeelSVF {
    var a1: Float = 0, a2: Float = 0, a3: Float = 0, k: Float = 1
    var ic1: Float = 0, ic2: Float = 0

    mutating func tune(cutoff: Float, q: Float, sampleRate: Float) {
        let f = min(max(cutoff, 20), sampleRate * 0.45)
        let g = tan(Float.pi * f / sampleRate)
        k = 1 / max(q, 0.1)
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    mutating func process(_ x: Float, _ mode: FeelFilterMode) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        switch mode {
        case .lowPass: return v2
        case .bandPass: return v1 * k
        case .highPass: return x - k * v1 - v2
        }
    }
}

private enum FeelVoiceKind {
    case noise, tone, ring, drop
}

private struct FeelVoice {
    var active = false
    var kind: FeelVoiceKind = .noise
    var delay = 0
    var age = 0
    var attack = 1
    var length = 0
    var decayRate: Float = 1
    var level: Float = 1
    var gain: Float = 0
    // Noise.
    var filter = FeelSVF()
    var mode: FeelFilterMode = .bandPass
    var q: Float = 1
    var cutoff: Float = 1000
    var cutoffEnd: Float = 1000
    var sweepSamples = 0
    // Tone and drop.
    var phase: Float = 0
    var frequency: Float = 0
    var startFrequency: Float = 0
    var endFrequency: Float = 0
    var glide = 1
    var harmonics = 1
    var vibratoPhase: Float = 0
    var vibratoRate: Float = 0
    var vibratoDepth: Float = 0
    var chirpPerSample: Float = 1
    // Ring (its partial state lives in the synth's bank at this voice's slot).
    var partialCount = 0
}

// MARK: - Synth

/// Swoop's real-time synth, rendered inside an `AVAudioSourceNode` (mono Float32). Ported from Brim's `PourSynth`.
///
/// Threading: the main thread calls `send` (single producer); the audio thread calls `render` (single consumer).
/// Commands cross through a fixed-capacity single-producer/single-consumer ring whose two indices are atomics
/// (acquire/release), so the render path takes no locks, never allocates and never touches ARC.
/// Master chain: DC blocker → peak-follower limiter (ceiling 0.9) → tanh soft clip, so the output can never clip.
final class FeelSynth: @unchecked Sendable {
    let sampleRate: Float

    static let voiceCount = 40
    static let maxPartials = 6
    static let queueCapacity = 512
    static let ceiling: Float = 0.9
    private static let partialStride = 5 // re, im, cos, sin, decay
    /// Below this a continuous layer is skipped entirely.
    private static let quiet: Float = 0.00002

    private let queue: UnsafeMutablePointer<FeelSynthCommand>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)
    private let peakBits = Atomic<UInt32>(0)
    private let renderCount = Atomic<Int>(0)

    // Audio-thread-only state below.
    private let voices: UnsafeMutablePointer<FeelVoice>
    private let bank: UnsafeMutablePointer<Float>
    private var bed = FeelBed()
    private var target = FeelBed()
    private var glideK: Float = 0
    private var noiseState: UInt32 = 0x2545_F491
    private var retuneCounter = 0
    private var windFilter = FeelSVF()
    private var whistleFilter = FeelSVF()
    private var skimFilter = FeelSVF()
    private var rainFilter = FeelSVF()
    private var dropFilter = FeelSVF()
    private var rumbleFilter = FeelSVF()
    private var gustValue: Float = 0.5
    private var gustTarget: Float = 0.5
    private var gustCountdown = 0
    private var rumbleValue: Float = 0.5
    private var rumbleTarget: Float = 0.5
    private var rumbleCountdown = 0
    private var sprayLevel: Float = 0
    private var dropLevel: Float = 0
    private var padPhaseA: Float = 0
    private var padPhaseB: Float = 0
    private var padPhaseC: Float = 0
    private var padPhaseD: Float = 0
    private var padPhaseE: Float = 0
    private var padLFO: Float = 0
    private var dcIn: Float = 0
    private var dcOut: Float = 0
    private var envelope: Float = 0

    private let gustStep: Float
    private let rumbleStep: Float
    private let sprayDecay: Float
    private let dropDecay: Float
    private let envelopeRelease: Float
    private let dcCoefficient: Float

    init(sampleRate: Float) {
        let rate: Float = sampleRate > 1000 ? sampleRate : 48_000
        self.sampleRate = rate
        queue = UnsafeMutablePointer<FeelSynthCommand>.allocate(capacity: FeelSynth.queueCapacity)
        queue.initialize(repeating: .stopAll, count: FeelSynth.queueCapacity)
        voices = UnsafeMutablePointer<FeelVoice>.allocate(capacity: FeelSynth.voiceCount)
        voices.initialize(repeating: FeelVoice(), count: FeelSynth.voiceCount)
        let bankSize = FeelSynth.voiceCount * FeelSynth.maxPartials * FeelSynth.partialStride
        bank = UnsafeMutablePointer<Float>.allocate(capacity: bankSize)
        bank.initialize(repeating: 0, count: bankSize)
        glideK = 1 - exp(-1 / (0.06 * rate))
        gustStep = 1 - exp(-1 / (0.14 * rate))
        rumbleStep = 1 - exp(-1 / (0.25 * rate))
        sprayDecay = exp(-1 / (0.0025 * rate))
        dropDecay = exp(-1 / (0.0012 * rate))
        envelopeRelease = exp(-1 / (0.08 * rate))
        dcCoefficient = 1 - 2 * Float.pi * 30 / rate
        retuneContinuous()
        rainFilter.tune(cutoff: 3200, q: 0.6, sampleRate: rate)
        dropFilter.tune(cutoff: 2600, q: 0.7, sampleRate: rate)
        rumbleFilter.tune(cutoff: 170, q: 0.7, sampleRate: rate)
    }

    deinit {
        queue.deinitialize(count: FeelSynth.queueCapacity)
        queue.deallocate()
        voices.deinitialize(count: FeelSynth.voiceCount)
        voices.deallocate()
        bank.deallocate()
    }

    // MARK: Main thread

    /// Queue a command (main thread only). Returns false if the queue is full (the command is dropped, never blocks).
    @discardableResult
    func send(_ command: FeelSynthCommand) -> Bool {
        let write = writeIndex.load(ordering: .relaxed)
        let next = (write + 1) % FeelSynth.queueCapacity
        guard next != readIndex.load(ordering: .acquiring) else { return false }
        queue[write] = command
        writeIndex.store(next, ordering: .releasing)
        return true
    }

    /// Loudest output sample so far (linear), for tests and diagnostics.
    var peak: Float { Float(bitPattern: peakBits.load(ordering: .relaxed)) }

    /// Render callbacks so far: if it stops climbing, the engine isn't pulling audio.
    var renderCallbacks: Int { renderCount.load(ordering: .relaxed) }

    // MARK: Audio thread

    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        drain()
        let twoPi = 2 * Float.pi
        var blockPeak: Float = 0
        for frame in 0..<frames {
            bed.approach(target, glideK)
            retuneCounter += 1
            if retuneCounter >= 32 {
                retuneCounter = 0
                retuneContinuous()
            }

            var sample: Float = 0
            // Wind and whistle: one noise source through a low-pass (the rush of air) and a resonant band (the
            // whistle), both breathing with a slow random gust.
            if bed.windGain > FeelSynth.quiet || bed.whistleGain > FeelSynth.quiet {
                gustCountdown -= 1
                if gustCountdown <= 0 {
                    gustTarget = unitNoise()
                    gustCountdown = Int(sampleRate * (0.18 + 0.4 * unitNoise())) + 1
                }
                gustValue += (gustTarget - gustValue) * gustStep
                let swell = 1 + bed.gust * (2 * gustValue - 1)
                let n = nextNoise()
                let air = windFilter.process(n, .lowPass) * bed.windGain
                let whistle = whistleFilter.process(n, .bandPass) * bed.whistleGain * (0.75 + 0.5 * gustValue)
                sample += (air + whistle) * swell
            }
            // Skim hiss: brighter noise with fine spray crackle.
            if bed.skimGain > FeelSynth.quiet {
                if unitNoise() < bed.sprayRate / sampleRate { sprayLevel = 0.3 + 0.7 * unitNoise() }
                sprayLevel *= sprayDecay
                sample += skimFilter.process(nextNoise() * (0.6 + sprayLevel), .bandPass) * bed.skimGain
            }
            // Rain: a broad wash plus sparse droplet ticks.
            if bed.rainGain > FeelSynth.quiet {
                sample += rainFilter.process(nextNoise(), .bandPass) * bed.rainGain
                if unitNoise() < bed.dropRate / sampleRate { dropLevel = 0.3 + 0.7 * unitNoise() }
                dropLevel *= dropDecay
                if dropLevel > 0.0005 {
                    sample += dropFilter.process(nextNoise() * dropLevel, .highPass) * bed.rainGain * 1.6
                }
            }
            // The storm's low rumble, rolling slowly.
            if bed.rumbleGain > FeelSynth.quiet {
                rumbleCountdown -= 1
                if rumbleCountdown <= 0 {
                    rumbleTarget = unitNoise()
                    rumbleCountdown = Int(sampleRate * (0.3 + 0.7 * unitNoise())) + 1
                }
                rumbleValue += (rumbleTarget - rumbleValue) * rumbleStep
                sample += rumbleFilter.process(nextNoise(), .lowPass) * bed.rumbleGain * (0.5 + rumbleValue)
            }
            // The golden pad: root (two detuned), just major third, fifth and a soft octave, with a slow tremolo.
            if bed.padGain > FeelSynth.quiet {
                let f = min(max(bed.padHz, 60), sampleRate * 0.1)
                padPhaseA += twoPi * f / sampleRate
                if padPhaseA > twoPi { padPhaseA -= twoPi }
                padPhaseB += twoPi * f * 1.0041 / sampleRate
                if padPhaseB > twoPi { padPhaseB -= twoPi }
                padPhaseC += twoPi * f * 1.25 / sampleRate
                if padPhaseC > twoPi { padPhaseC -= twoPi }
                padPhaseD += twoPi * f * 1.5 / sampleRate
                if padPhaseD > twoPi { padPhaseD -= twoPi }
                padPhaseE += twoPi * f * 2.003 / sampleRate
                if padPhaseE > twoPi { padPhaseE -= twoPi }
                padLFO += twoPi * 0.31 / sampleRate
                if padLFO > twoPi { padLFO -= twoPi }
                let root: Float = 0.3 * sin(padPhaseA) + 0.22 * sin(padPhaseB)
                let upper: Float = 0.2 * sin(padPhaseC) + 0.18 * sin(padPhaseD)
                let octave: Float = 0.1 * sin(padPhaseE)
                let tremolo: Float = 0.85 + 0.15 * sin(padLFO)
                sample += (root + upper + octave) * tremolo * bed.padGain
            }
            for index in 0..<FeelSynth.voiceCount where voices[index].active {
                sample += renderVoice(&voices[index], slot: index)
            }
            sample *= bed.master

            // DC blocker (30 Hz), then a peak follower that keeps the drive at or below the ceiling, then tanh.
            let blocked = sample - dcIn + dcCoefficient * dcOut
            dcIn = sample
            dcOut = blocked
            let magnitude = abs(blocked)
            envelope = max(magnitude, envelope * envelopeRelease)
            let drive = envelope > FeelSynth.ceiling ? FeelSynth.ceiling / envelope : 1
            var shaped = tanh(blocked * drive)
            if !shaped.isFinite {
                shaped = 0
                resetFilters()
            }
            shaped = min(max(shaped, -0.98), 0.98)
            blockPeak = max(blockPeak, abs(shaped))
            out[frame] = shaped
        }
        let previous = Float(bitPattern: peakBits.load(ordering: .relaxed))
        if blockPeak > previous { peakBits.store(blockPeak.bitPattern, ordering: .relaxed) }
        renderCount.store(renderCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
    }

    private func retuneContinuous() {
        windFilter.tune(cutoff: bed.windCutoff, q: 0.62, sampleRate: sampleRate)
        whistleFilter.tune(cutoff: bed.whistleHz, q: bed.whistleQ, sampleRate: sampleRate)
        skimFilter.tune(cutoff: bed.skimCenter, q: 0.8, sampleRate: sampleRate)
    }

    private func drain() {
        var read = readIndex.load(ordering: .relaxed)
        let write = writeIndex.load(ordering: .acquiring)
        var handled = 0
        while read != write && handled < 128 {
            let command = queue[read]
            read = (read + 1) % FeelSynth.queueCapacity
            handled += 1
            apply(command)
        }
        readIndex.store(read, ordering: .releasing)
    }

    private func apply(_ command: FeelSynthCommand) {
        switch command {
        case .bed(let params):
            target = params
            let glide = params.glide.isFinite ? max(params.glide, 0.004) : 0.06
            glideK = 1 - exp(-1 / (glide * sampleRate))
        case .stopAll:
            for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
            sprayLevel = 0
            dropLevel = 0
        case .noise, .tone, .ring, .drop:
            start(command)
        }
    }

    private func resetFilters() {
        windFilter = FeelSVF()
        whistleFilter = FeelSVF()
        skimFilter = FeelSVF()
        rainFilter = FeelSVF()
        dropFilter = FeelSVF()
        rumbleFilter = FeelSVF()
        retuneContinuous()
        rainFilter.tune(cutoff: 3200, q: 0.6, sampleRate: sampleRate)
        dropFilter.tune(cutoff: 2600, q: 0.7, sampleRate: sampleRate)
        rumbleFilter.tune(cutoff: 170, q: 0.7, sampleRate: sampleRate)
        sprayLevel = 0
        dropLevel = 0
        envelope = 0
        dcIn = 0
        dcOut = 0
        for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
    }

    private func nextNoise() -> Float {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }

    private func unitNoise() -> Float {
        (nextNoise() + 1) * 0.5
    }

    private func start(_ command: FeelSynthCommand) {
        var slot = -1
        var oldest = -1
        var oldestAge = -1
        for index in 0..<FeelSynth.voiceCount {
            if !voices[index].active {
                slot = index
                break
            }
            if voices[index].age > oldestAge {
                oldestAge = voices[index].age
                oldest = index
            }
        }
        if slot < 0 { slot = oldest }
        guard slot >= 0 else { return }
        var voice = FeelVoice()
        voice.active = true
        switch command {
        case .noise(let spec):
            voice.kind = .noise
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.mode = spec.mode
            voice.q = spec.q
            voice.cutoff = spec.cutoff
            voice.cutoffEnd = spec.cutoffEnd
            voice.sweepSamples = abs(spec.cutoffEnd - spec.cutoff) > 1 ? max(Int(spec.sweep * sampleRate), 1) : 0
            voice.filter.tune(cutoff: spec.cutoff, q: spec.q, sampleRate: sampleRate)
        case .tone(let spec):
            voice.kind = .tone
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.length = max(Int(spec.duration * sampleRate), voice.attack + 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.gain = spec.gain
            voice.startFrequency = spec.start
            voice.endFrequency = spec.end
            voice.glide = max(Int(spec.glide * sampleRate), 1)
            voice.harmonics = min(max(spec.harmonics, 1), 8)
            voice.vibratoRate = spec.vibratoRate
            voice.vibratoDepth = spec.vibratoDepth
        case .drop(let spec):
            voice.kind = .drop
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0015 * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 6)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.frequency, 40), sampleRate * 0.4)
            voice.chirpPerSample = pow(max(spec.chirp, 0.25), 1 / Float(max(voice.length, 1)))
        case .ring(let spec):
            voice.kind = .ring
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0005 * sampleRate), 1)
            voice.decayRate = 1
            voice.length = min(Int(spec.decay * sampleRate * 7), Int(sampleRate * 6))
            voice.gain = 1
            configureRing(spec, slot: slot, voice: &voice)
        case .bed, .stopAll:
            return
        }
        voices[slot] = voice
    }

    private static func ratio(_ kind: FeelRingKind, _ n: Int) -> Float {
        switch kind {
        case .chime:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.0
            case 3: return 4.2
            case 4: return 5.4
            default: return 6.8
            }
        case .bell:
            switch n {
            case 0: return 1      // prime
            case 1: return 0.5    // hum
            case 2: return 1.19   // tierce (minor third)
            case 3: return 1.5    // quint
            case 4: return 2.0    // nominal
            default: return 2.66
            }
        case .marimba:
            switch n {
            case 0: return 1
            case 1: return 3.93
            case 2: return 9.3
            case 3: return 12.0
            case 4: return 15.2
            default: return 18.6
            }
        case .wood:
            switch n {
            case 0: return 1
            case 1: return 2.6
            case 2: return 3.9
            case 3: return 5.4
            case 4: return 6.9
            default: return 8.6
            }
        case .glass:
            switch n {
            case 0: return 1
            case 1: return 2.32
            case 2: return 4.25
            case 3: return 6.63
            case 4: return 9.38
            default: return 12.1
            }
        }
    }

    private func configureRing(_ spec: FeelRingSpec, slot: Int, voice: inout FeelVoice) {
        let count = min(max(spec.partials, 1), FeelSynth.maxPartials)
        voice.partialCount = count
        let brightness = min(max(spec.brightness, 0.05), 0.98)
        var total: Float = 0
        for n in 0..<count { total += pow(brightness, Float(n)) }
        var jitter = spec.seed | 1
        let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
        for n in 0..<count {
            jitter ^= jitter << 13
            jitter ^= jitter >> 17
            jitter ^= jitter << 5
            let detune: Float = n == 0 ? 1 : 1 + 0.015 * (Float(jitter % 2001) / 1000 - 1)
            let frequency = spec.fundamental * FeelSynth.ratio(spec.kind, n) * detune
            let offset = base + n * FeelSynth.partialStride
            guard frequency > 20, frequency < sampleRate * 0.45 else {
                bank[offset] = 0
                bank[offset + 1] = 0
                bank[offset + 2] = 1
                bank[offset + 3] = 0
                bank[offset + 4] = 0
                continue
            }
            var tau = spec.decay / (1 + 0.7 * Float(n))
            // The lighthouse bell's hum (an octave under the prime) is what lingers in a real bell.
            if spec.kind == .bell && n == 1 { tau = spec.decay * 1.3 }
            if frequency > 2500 && frequency < 4500 && n > 0 { tau *= 0.5 } // no lingering screech in the ear's peak
            let omega = 2 * Float.pi * frequency / sampleRate
            bank[offset] = spec.gain * pow(brightness, Float(n)) / total * 1.6
            bank[offset + 1] = 0
            bank[offset + 2] = cos(omega)
            bank[offset + 3] = sin(omega)
            bank[offset + 4] = exp(-1 / max(tau * sampleRate, 1))
        }
    }

    private func renderVoice(_ voice: inout FeelVoice, slot: Int) -> Float {
        if voice.delay > 0 {
            voice.delay -= 1
            return 0
        }
        let age = voice.age
        voice.age += 1
        if age >= voice.length {
            voice.active = false
            return 0
        }
        let envelope: Float
        if age < voice.attack {
            envelope = Float(age) / Float(voice.attack)
        } else {
            voice.level *= voice.decayRate
            envelope = voice.level
        }
        if envelope < 0.0003 && age > voice.attack {
            voice.active = false
            return 0
        }
        // A gentle release over the last 30 ms so nothing ever clicks off.
        let left = voice.length - age
        let release = min(Float(left) / (0.03 * sampleRate), 1)
        let twoPi = 2 * Float.pi
        switch voice.kind {
        case .noise:
            if voice.sweepSamples > 0 && age % 32 == 0 {
                let progress = min(Float(age) / Float(voice.sweepSamples), 1)
                let cutoff = voice.cutoff * pow(voice.cutoffEnd / max(voice.cutoff, 1), progress)
                voice.filter.tune(cutoff: cutoff, q: voice.q, sampleRate: sampleRate)
            }
            return voice.filter.process(nextNoise(), voice.mode) * envelope * voice.gain * release
        case .tone:
            let progress = min(Float(age) / Float(voice.glide), 1)
            var frequency = voice.startFrequency + (voice.endFrequency - voice.startFrequency) * progress
            if voice.vibratoDepth > 0 {
                voice.vibratoPhase += twoPi * voice.vibratoRate / sampleRate
                if voice.vibratoPhase > twoPi { voice.vibratoPhase -= twoPi }
                frequency *= 1 + voice.vibratoDepth * sin(voice.vibratoPhase)
            }
            voice.phase += twoPi * frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            var value: Float = 0
            let limit = sampleRate * 0.45
            var harmonic = 1
            while harmonic <= voice.harmonics {
                if frequency * Float(harmonic) < limit {
                    value += sin(voice.phase * Float(harmonic)) / Float(harmonic)
                }
                harmonic += 1
            }
            return value * envelope * voice.gain * release
        case .drop:
            voice.frequency *= voice.chirpPerSample
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            return sin(voice.phase) * envelope * voice.gain * release
        case .ring:
            let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
            var sum: Float = 0
            for n in 0..<voice.partialCount {
                let o = base + n * FeelSynth.partialStride
                let re = bank[o]
                let im = bank[o + 1]
                let c = bank[o + 2]
                let s = bank[o + 3]
                let d = bank[o + 4]
                let newIm = (re * s + im * c) * d
                bank[o] = (re * c - im * s) * d
                bank[o + 1] = newIm
                sum += newIm
            }
            return sum * envelope * release
        }
    }
}
