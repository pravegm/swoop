import CoreGraphics
import Foundation

// MARK: - Contracts between the modules (owned by the founder; change only in a founder round)
//
// Core     (Swoop/Core)      pure Swift simulation: no SpriteKit, no UIKit, no SwiftUI. Deterministic. Unit-tested.
// Input    (Swoop/Input)     hinge / touch / autopilot → tuck (0 = wings spread … 1 = fully tucked).
// Scene    (Swoop/Scene)     SpriteKit rendering of a FlightSnapshot + the sea + cosmetic FX from FlightEvents.
// Feedback (Swoop/Feedback)  live audio synth + Core Haptics from FlightEvents + FlightTelemetry.
// App/UI   (Swoop/App, Swoop/UI, Swoop/Persistence) SwiftUI shell, the loop glue, menus, persistence, Game Center.
//
// SEA SPACE (Core): points. x = distance flown forward (10 pt = 1 m), y up, y = 0 is the mean water level.
// SCREEN SPACE (Scene/UI): the play canvas in points, landscape, origin bottom-left (SpriteKit). On an iPhone Duo held
// like a book it is 951 × 669 with the fold running top to bottom at x ≈ 475 (a 40 pt band).

// MARK: Screen layout

/// The play canvas. Built once per canvas size by the App, handed to the scene and the UI.
public struct ScreenLayout: Equatable, Sendable {
    /// The design canvas (always 952 × 670: the Duo's book-pose inner display). Every device shows this canvas
    /// aspect-FILLED, so other phones crop a little top and bottom; `visibleRect` is the part on screen.
    public var size: CGSize
    /// The fold band in canvas x (left, right). On phones without a fold: a zero-width band at mid-screen.
    public var creaseMinX: CGFloat
    public var creaseMaxX: CGFloat
    /// Whether this canvas has a real fold (a hinge was seen).
    public var hasFold: Bool
    /// The part of the canvas actually on screen. HUD and anything the player must read stays inside it.
    public var visibleRect: CGRect
    /// "Bird on the other side" (Settings): the flight runs right-to-left, the bird sits on the right half.
    public var mirrored: Bool

    public init(size: CGSize, creaseMinX: CGFloat, creaseMaxX: CGFloat, hasFold: Bool, visibleRect: CGRect? = nil,
                mirrored: Bool = false) {
        self.size = size; self.creaseMinX = creaseMinX; self.creaseMaxX = creaseMaxX; self.hasFold = hasFold
        self.visibleRect = visibleRect ?? CGRect(origin: .zero, size: size)
        self.mirrored = mirrored
    }

    public static let canvasWidth: CGFloat = 952
    public static let canvasHeight: CGFloat = 670
    public static let creaseLeft: CGFloat = 456
    public static let creaseRight: CGFloat = 496
    /// Where the bird sits on screen, as a fraction of the canvas width (0.30: the left half, clear of the fold).
    public static let birdScreenFraction: CGFloat = 0.30

    /// Layout for a play canvas of `canvas` points (any orientation is treated as landscape: width ≥ height).
    public static func make(canvas: CGSize, hasFold: Bool, mirrored: Bool = false) -> ScreenLayout {
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        let cw = max(max(canvas.width, canvas.height), 1), ch = max(min(canvas.width, canvas.height), 1)
        let scale = max(cw / size.width, ch / size.height)
        let visW = min(size.width, cw / scale), visH = min(size.height, ch / scale)
        let visible = CGRect(x: (size.width - visW) / 2, y: (size.height - visH) / 2, width: visW, height: visH)
        return ScreenLayout(size: size, creaseMinX: creaseLeft, creaseMaxX: creaseRight, hasFold: hasFold,
                            visibleRect: visible, mirrored: mirrored)
    }
}

// MARK: Colours (platform-neutral so Core stays UIKit-free)

public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    /// 0xRRGGBB
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let k = min(max(t, 0), 1)
        return RGBA(r + (other.r - r) * k, g + (other.g - g) * k, b + (other.b - b) * k, a + (other.a - a) * k)
    }
}

// MARK: Birds and skies (cosmetic catalogue data; the catalogue lives in Core: `BirdCatalog`, `SkyCatalog`)

public enum BirdID: String, Codable, CaseIterable, Sendable {
    case gull, tern, puffin, swift, albatross, petrel, heron, gannet
}

public struct Bird: Codable, Hashable, Sendable {
    public var id: BirdID
    public var name: String
    public var blurb: String          // one short line for the Birds screen
    public var body: RGBA
    public var wing: RGBA
    public var wingTip: RGBA
    public var beak: RGBA
    public var trail: RGBA            // spray / slipstream tint
    /// Wing span relative to the gull (cosmetic only: physics is identical for every bird).
    public var span: Double
    /// Wing shape 0 = broad/rounded (puffin) … 1 = long/pointed (swift, albatross).
    public var pointiness: Double
    /// Rank needed to unlock (0 = from the start).
    public var unlockRank: Int
}

public enum SkyID: String, Codable, CaseIterable, Sendable {
    case goldenHour, roseDusk, northernLights, monsoon, moonrise
}

public struct Sky: Codable, Hashable, Sendable {
    public var id: SkyID
    public var name: String
    public var zenith: RGBA           // top of the sky
    public var horizon: RGBA          // at the horizon
    public var sun: RGBA
    public var seaNear: RGBA          // water colour at the front
    public var seaFar: RGBA           // far swell layers
    public var foam: RGBA
    public var storm: RGBA            // the storm front's colour (clouds, rain)
    public var unlockRank: Int
}

// MARK: Modes

public enum RunMode: Codable, Hashable, Sendable {
    /// The endless main mode. A fresh seed each run.
    case flight
    /// Everyone's sea for that day (days since 2026-01-01, `DailySeed.dayNumber(for:)`). `scored` = the one counted try.
    case daily(day: Int, scored: Bool)
    /// The title screen's attract loop and CI frames: never finishes (the storm never catches you).
    case attract
}

// MARK: Simulation output

public enum FlightPhase: Equatable, Sendable {
    /// 3-2-1 before the drop; `remaining` seconds.
    case countdown(remaining: Double)
    case flying
    /// The storm has caught the bird; the calm ending plays for `elapsed` s (1.8 s) before `.finished`.
    case caught(elapsed: Double)
    case finished
}

public enum TouchdownQuality: String, Codable, Sendable { case perfect, good, splash }

public enum FlightEvent: Equatable, Sendable {
    case countdownTick(Int)                 // 3, 2, 1
    case started                            // the drop
    case launched(speed: Double)            // left the water off a crest (pt/s)
    case touchdown(TouchdownQuality, speed: Double, chain: Int)   // chain = Perfect streak after this landing
    case tailwindStarted
    case tailwindEnded
    case lighthouse(index: Int, name: String)
    case cloudTouched                       // reached cloud height (≥ 900 pt above the water)
    case milestone(km: Int)                 // every whole km
    case newBest                            // passed the personal best distance during the run (fires once)
    case stormClose                         // the gap fell under 15 % of a full lead (fires once per dip)
    case caught                             // the storm caught the bird
    case finished
}

/// Everything the scene, HUD and feedback need for one frame. Value type, cheap to copy.
public struct FlightSnapshot: Equatable, Sendable {
    public var phase: FlightPhase
    public var time: Double                 // s since the session began
    public var position: CGPoint            // sea space
    public var velocity: CGVector           // pt/s
    public var speed: Double                // |velocity|
    /// The bird's body angle in radians (0 = level, positive = nose up), smoothed for display.
    public var bodyAngle: Double
    /// The tuck being applied (0 spread … 1 tucked), after the session's own easing.
    public var tuck: Double
    public var skimming: Bool
    /// Height above the water directly below (pt, ≥ 0).
    public var altitude: Double
    public var distanceMeters: Double
    public var score: Int
    public var chain: Int                   // current Perfect streak
    public var bestChain: Int
    public var perfects: Int
    public var tailwindRemaining: Double    // s, 0 = none
    /// The storm front's x in sea space and the gap to the bird.
    public var stormX: Double
    public var gap: Double
    /// gap / Tuning.fullLead, clamped 0…1 (the lead meter: how far ahead of the storm).
    public var lead: Double
    public var lighthousesPassed: Int
    public var nextLighthouseX: Double
    public var nextLighthouseName: String
    /// Personal best distance (m) shown as a marker in the sea; 0 = none.
    public var bestMeters: Double
    public var mode: RunMode

    public init(phase: FlightPhase = .countdown(remaining: 3), time: Double = 0, position: CGPoint = .zero,
                velocity: CGVector = .zero, speed: Double = 0, bodyAngle: Double = 0, tuck: Double = 0,
                skimming: Bool = false, altitude: Double = 0, distanceMeters: Double = 0, score: Int = 0, chain: Int = 0,
                bestChain: Int = 0, perfects: Int = 0, tailwindRemaining: Double = 0, stormX: Double = 0,
                gap: Double = 0, lead: Double = 1, lighthousesPassed: Int = 0, nextLighthouseX: Double = 0,
                nextLighthouseName: String = "", bestMeters: Double = 0, mode: RunMode = .flight) {
        self.phase = phase; self.time = time; self.position = position; self.velocity = velocity; self.speed = speed
        self.bodyAngle = bodyAngle; self.tuck = tuck; self.skimming = skimming; self.altitude = altitude
        self.distanceMeters = distanceMeters; self.score = score; self.chain = chain; self.bestChain = bestChain
        self.perfects = perfects; self.tailwindRemaining = tailwindRemaining; self.stormX = stormX; self.gap = gap
        self.lead = lead; self.lighthousesPassed = lighthousesPassed; self.nextLighthouseX = nextLighthouseX
        self.nextLighthouseName = nextLighthouseName; self.bestMeters = bestMeters; self.mode = mode
    }
}

/// What a finished run produced. Persisted (best runs) and fed to goals / Game Center.
public struct RunResult: Codable, Equatable, Sendable {
    public var mode: RunMode
    public var seed: UInt64
    public var meters: Double
    public var score: Int
    public var seconds: Double
    public var perfects: Int
    public var goods: Int
    public var splashes: Int
    public var bestChain: Int
    public var tailwinds: Int
    public var lighthouses: Int
    public var lastLighthouseName: String
    public var cloudTouches: Int
    public var maxSpeed: Double
    public var maxAltitude: Double
    /// Longest distance flown (m) between two splashes (or start/end).
    public var longestCleanMeters: Double
    public var birdID: BirdID

    public init(mode: RunMode, seed: UInt64, meters: Double, score: Int, seconds: Double, perfects: Int, goods: Int,
                splashes: Int, bestChain: Int, tailwinds: Int, lighthouses: Int, lastLighthouseName: String,
                cloudTouches: Int, maxSpeed: Double, maxAltitude: Double, longestCleanMeters: Double, birdID: BirdID) {
        self.mode = mode; self.seed = seed; self.meters = meters; self.score = score; self.seconds = seconds
        self.perfects = perfects; self.goods = goods; self.splashes = splashes; self.bestChain = bestChain
        self.tailwinds = tailwinds; self.lighthouses = lighthouses; self.lastLighthouseName = lastLighthouseName
        self.cloudTouches = cloudTouches; self.maxSpeed = maxSpeed; self.maxAltitude = maxAltitude
        self.longestCleanMeters = longestCleanMeters; self.birdID = birdID
    }
}

// MARK: Goals and ranks ("Flocks")

public enum GoalKind: String, Codable, Sendable {
    case reachMeters            // fly ≥ target m in one run
    case perfectsInRun          // ≥ target Perfects in one run
    case chain                  // a Perfect chain of ≥ target
    case lighthouses            // pass ≥ target lighthouses in one run
    case cloudTouches           // touch the clouds ≥ target times in one run
    case cleanMeters            // fly ≥ target m without a splash
    case tailwinds              // ≥ target Tailwinds in one run
    case totalMeters            // lifetime metres (accumulates across runs)
    case dailyPlayed            // play the Daily Flight (target = 1)
    case speed                  // reach ≥ target pt/s
}

public struct Goal: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: GoalKind
    public var target: Double
    public var text: String     // "Chain 5 Perfects"
    public init(id: String, kind: GoalKind, target: Double, text: String) {
        self.id = id; self.kind = kind; self.target = target; self.text = text
    }
}

// MARK: Feedback telemetry (continuous, every frame)

public struct FlightTelemetry: Equatable, Sendable {
    public var speed: Double                // pt/s
    public var tuck: Double                 // 0…1
    public var skimming: Bool
    public var altitude: Double
    public var tailwind: Bool
    public var lead: Double                 // 0…1 (gap to the storm)
    public var playing: Bool                // false in menus/countdown/caught
    public init(speed: Double = 0, tuck: Double = 0, skimming: Bool = false, altitude: Double = 0, tailwind: Bool = false,
                lead: Double = 1, playing: Bool = false) {
        self.speed = speed; self.tuck = tuck; self.skimming = skimming; self.altitude = altitude
        self.tailwind = tailwind; self.lead = lead; self.playing = playing
    }
}

// MARK: Cross-module protocols

/// Where the tuck comes from (hinge, touch, autopilot). Called once per frame on the main actor.
@MainActor public protocol TuckSource: AnyObject {
    /// 0 = wings spread … 1 = fully tucked, at `time` (CACurrentMediaTime()).
    func tuck(at time: TimeInterval) -> Double
}

/// The scene asks the App's controller to advance the game once per frame.
@MainActor public protocol SceneDriver: AnyObject {
    /// Advance by `dt` (clamped by the driver) and return the frame to draw plus this frame's events.
    func advance(dt: TimeInterval, now: TimeInterval) -> (FlightSnapshot, [FlightEvent])
    /// The sea being flown (for drawing). Nil before the first session.
    var sea: SeaProfile? { get }
    var bird: Bird { get }
    var sky: Sky { get }
}

/// Consumes events + telemetry (audio, haptics).
@MainActor public protocol FeedbackSink: AnyObject {
    func handle(_ events: [FlightEvent], telemetry: FlightTelemetry)
}
