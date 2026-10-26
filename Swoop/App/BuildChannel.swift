import Foundation

/// Which channel this build came from. The hinge readout (R4 P1-15) is for the founder's device test only: Debug,
/// TestFlight and sandbox builds, never an App Store build.
enum BuildChannel {
    static let isTestBuild: Bool = {
        #if DEBUG
        return true
        #else
        // TestFlight and Xcode-installed sandbox builds carry a sandbox receipt; App Store builds never do.
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()
}

/// One frame of the founder's hinge readout (Duo R3 P1-6): what the filters see, and the run's strokes.
struct HingeReadout: Equatable {
    var angle: Double?
    var rawAngle: Double?
    var openAngle: Double
    var tuck: Double
    var reportsPerSecond: Double
    var lastReportAge: Double?
    var closing: Bool
    var shut: Bool
    var pose: String
    var strokes: Int
    var meanStrokeDepth: Double

    /// The overlay's lines. Pure; tested.
    var lines: [String] {
        func deg(_ v: Double?) -> String { v.map { String(format: "%.1f°", $0) } ?? "—" }
        return [
            "angle \(deg(angle))  raw \(deg(rawAngle))",
            "open \(deg(openAngle))  tuck \(String(format: "%.2f", tuck))",
            String(format: "%.0f Hz", reportsPerSecond)
                + "  age " + (lastReportAge.map { String(format: "%.2f s", $0) } ?? "—"),
            "pose \(pose)\(closing ? " · closing" : "")\(shut ? " · shut" : "")",
            "strokes \(strokes)  mean " + String(format: "%.2f", meanStrokeDepth),
        ]
    }
}

/// Counts the run's folds: a stroke starts when the tuck rises past 0.5 and ends back under 0.2; its depth is the
/// deepest tuck reached. Pure; tested.
struct StrokeCounter: Equatable {
    static let downAt = 0.5
    static let upAt = 0.2

    private(set) var strokes = 0
    private(set) var depthSum = 0.0
    private var down = false
    private var peak = 0.0

    var meanDepth: Double { strokes > 0 ? depthSum / Double(strokes) : 0 }

    mutating func note(_ tuck: Double) {
        guard tuck.isFinite else { return }
        if down {
            peak = max(peak, tuck)
            if tuck <= Self.upAt {
                down = false
                depthSum += peak
            }
        } else if tuck >= Self.downAt {
            down = true
            strokes += 1
            peak = tuck
        }
    }
}
