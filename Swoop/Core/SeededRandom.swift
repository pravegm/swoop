import Foundation

// MARK: - Deterministic RNG (SplitMix64)
//
// The same seed gives the same sequence on every device and every run. Everything random in Core (the sea, the
// lighthouse names, the pilot) draws from one of these, never from the system RNG.

public struct SeededRandom {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unit() -> Double {
        return Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform in [lower, upper).
    public mutating func range(_ r: ClosedRange<Double>) -> Double {
        return r.lowerBound + (r.upperBound - r.lowerBound) * unit()
    }

    /// Uniform integer in 0..<n (n ≥ 1).
    mutating func int(_ n: Int) -> Int {
        if n <= 1 { return 0 }
        return Int(next() % UInt64(n))
    }

    mutating func chance(_ p: Double) -> Bool {
        return unit() < p
    }
}
