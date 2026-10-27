# Swoop: architecture and module contracts

The types that modules share live in `Swoop/Shared/Contracts.swift`, which the founder owns. This file sets out who
owns what. It also gives the exact API each module must expose, so that the others can compile against it **without a
compiler on our side**. CI on GitHub's macOS runner is our only compiler.

**Rules**
- Swift 5 language mode, iOS 18 deployment target, built with Xcode 27.1 and the iOS 27.1 SDK.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Everything that touches views, nodes, audio or haptics is `@MainActor`.
- Core is plain value types plus final classes, with no actor isolation and no UIKit, SpriteKit or SwiftUI imports.
  Core may import Foundation and CoreGraphics only.
- No third-party packages.

## The frame loop

```
SpriteView(FlightScene)                    ← SwiftUI hosts SpriteKit, preferredFramesPerSecond = 120
  FlightScene.update(currentTime)
    → driver.advance(dt:now:)              ← GameController (App), the hub
         tuck   = tuckSource.tuck(at: now)    (HingeTuckSource on a Duo, TouchTuckSource elsewhere, Autopilot in attract/CI)
         events = session.step(dt, tuck)      (Core: FlightSession, sub-steps at ≤ 1/240 s)
         feedback.handle(events, telemetry)   (Feedback: FeedbackDirector)
         publish HUD state at ≤ 15 Hz to SwiftUI
    ← (snapshot, events)
    FlightScene draws the sea (driver.sea), the bird, sky, night, FX for the events
```

`dt` is clamped to ≤ 1/30 s by the driver.

## Module ownership

| Module | Folder | Owner |
|---|---|---|
| Contracts | `Swoop/Shared/` | founder |
| Core simulation, catalogues, goals, pilot brain | `Swoop/Core/` | **Core engineer** |
| Scene (SpriteKit) and bird art | `Swoop/Scene/` | **Scene engineer** |
| Input (hinge, touch, autopilot) and Feedback (audio synth, haptics) | `Swoop/Input/`, `Swoop/Feedback/` | **Feel engineer** |
| App shell, UI, persistence, Game Center, demo mode | `Swoop/App/`, `Swoop/UI/`, `Swoop/Persistence/` | **App engineer** |
| Tests | `SwoopTests/` | each engineer writes `SwoopTests/<Module>Tests.swift` |
| CI | `.github/`, `ci/`, `project.yml` | founder |

An engineer only writes inside their own folders. If you need something from another module that isn't listed
below, don't invent it. Write a note in `design/NEEDS.md` and use a local private stand-in.

## Core API (the Core engineer must provide exactly these)

```swift
/// SplitMix64. Deterministic everywhere.
struct SeededRandom { init(seed: UInt64); mutating func next() -> UInt64; mutating func unit() -> Double /* [0,1) */
                      mutating func range(_ r: ClosedRange<Double>) -> Double }

/// The sea: an infinite, deterministic, C¹-smooth height field (GAME-DESIGN §4). Segments are generated lazily and
/// cached; queries anywhere from x = -2000 to any distance ahead must be cheap (O(1) amortised).
final class SeaProfile {
    init(seed: UInt64)
    let seed: UInt64
    func height(at x: Double) -> Double            // pt above mean water
    func slope(at x: Double) -> Double             // dh/dx
    /// Surface points from x0 to x1 (inclusive) every `step` pt, for drawing.
    func samples(from x0: Double, to x1: Double, step: Double) -> [CGPoint]
}

enum Lighthouses {
    static func x(index: Int) -> Double            // sea x of the n-th lighthouse (0-based): 4 km, then +5 km, +6 km… (capped at +8 km)
    static func name(index: Int, seed: UInt64) -> String   // from a list of ~40 invented headland names, seeded
}

enum Tuning { /* every number from GAME-DESIGN §5–§6 as static lets, documented; nothing hard-coded elsewhere */ }

final class FlightSession {
    init(mode: RunMode, seed: UInt64, bestMeters: Double, bird: BirdID)
    let sea: SeaProfile
    let seed: UInt64
    /// tuck 0…1 from the input. Returns this step's events in order.
    func step(dt: Double, tuck: Double) -> [FlightEvent]
    var snapshot: FlightSnapshot { get }
    var isFinished: Bool { get }
    var result: RunResult? { get }                 // non-nil once finished
    func skipCountdown()                           // attract/CI: start flying immediately
}

enum DailySeed {
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int   // days since 2026-01-01
    static func seed(day: Int) -> UInt64
}

enum BirdCatalog { static var all: [Bird] { get }; static func bird(_ id: BirdID) -> Bird }
enum SkyCatalog  { static var all: [Sky]  { get }; static func sky(_ id: SkyID) -> Sky }

enum GoalCatalog {
    static let maxRank: Int                        // 15
    static func goals(forRank rank: Int) -> [Goal] // exactly 3 per rank; rank 0…14 (at maxRank: [])
    static func rankTitle(_ rank: Int) -> String   // "Fledgling" … "Storm Rider"
}
enum GoalEvaluator {
    /// 0…1 progress of `goal` after `run` (lifetimeMeters includes this run). ≥ 1 means met.
    static func progress(_ goal: Goal, run: RunResult, lifetimeMeters: Double, dailyPlayed: Bool) -> Double
}

enum PilotSkill: String, CaseIterable { case novice, casual, expert, perfect }
/// A simulated player: used by the autopilot (attract loop, CI frames) and by the balance tests.
struct FlightPilot {
    init(skill: PilotSkill, seed: UInt64)
    mutating func tuck(for snapshot: FlightSnapshot, sea: SeaProfile) -> Double
}
```

The `FlightSession` behaviour is specified in `design/GAME-DESIGN.md` §5–§6. In short:

- **Countdown.** It runs 3.0 s with `countdownTick(3/2/1)`, then `started`.
  - The bird starts 260 pt above the first swell at 520 pt/s, so it falls onto a long, gentle downslope. The sea's
    first segment is fixed by design to be a gentle 1.2 km "tutorial" swell train for every seed.
- **Caught.** The night catches the bird at `gap ≤ 0`: `caught` fires, then 1.8 s of the `caught` phase, then
  `finished`. `.attract` never catches the bird: the night is held 1500 pt behind it.
- **Tuck easing.** The session applies its own tuck easing on top of the input: 0.06 s attack, 0.08 s release.
  Physics uses the eased value.
- **Body angle.** `bodyAngle` follows the velocity direction with a 0.08 s smoothing. While skimming it follows the
  surface tangent.

## Input API (the Feel engineer)

```swift
@MainActor final class HingeTuckSource: TuckSource {       // fed by HingeReader samples
    func ingest(angleDegrees: Double, at time: TimeInterval)
    var hasHinge: Bool { get }                            // true once any real sample arrived (never goes back to false)
    var angle: Double? { get }                            // display-rate filtered hinge angle (180 = flat)
    var openAngle: Double { get }                         // the auto-calibrated "wings spread" angle (150…172)
    var isClosing: Bool { get }                           // filtered angle < 55° for 0.2 s or < 40° at once (pause), back above 65°
}
@MainActor final class TouchTuckSource: TuckSource {     // hold anywhere = tuck, with 0.12 s / 0.10 s ramps
    func began(at time: TimeInterval); func ended(at time: TimeInterval)
}
@MainActor final class AutopilotTuckSource: TuckSource { // wraps Core's FlightPilot
    init(skill: PilotSkill, seed: UInt64, snapshot: @escaping () -> FlightSnapshot?, sea: @escaping () -> SeaProfile?)
}
struct HingeReader: ViewModifier                          // copy of Brim's: (angle°, time) + onUnavailable
// usage: view.modifier(HingeReader(onUpdate: { angle, time in … }, onUnavailable: { … }))
```

## Feedback API (the Feel engineer)

```swift
@MainActor final class FeedbackDirector: FeedbackSink {
    static let shared: FeedbackDirector
    func start()                                      // audio session + engines (idempotent)
    var soundOn: Bool; var hapticsOn: Bool; var respectSilentSwitch: Bool
    func handle(_ events: [FlightEvent], telemetry: FlightTelemetry)
    func uiTap(); func uiConfirm(); func celebrate()  // menus, rank up
    func silence()                                    // fade the continuous layers out (pause, menus)
}
```

## Scene API (the Scene engineer)

```swift
@MainActor final class FlightScene: SKScene {
    init(layout: ScreenLayout)                        // scene.size = layout.size; the host aspect-fills it
    weak var driver: SceneDriver?
    var reduceMotion: Bool
    var layout: ScreenLayout                          // settable (mirroring, canvas change)
    func reset()                                      // new session: clear FX, snap the camera
}
/// The bird drawn with CoreGraphics only, so SwiftUI (the title, the Birds screen) and SpriteKit share one art source.
enum BirdArt {
    /// The bird in a unit box (centre origin, facing +x, span ≈ 1.0 × bird.span), wings at `tuck` (0 spread … 1 tucked)
    /// and `flap` phase 0…1 (a small idle flap; 0 = none).
    static func path(for bird: Bird, tuck: Double, flap: Double) -> (body: CGPath, nearWing: CGPath, farWing: CGPath, beak: CGPath)
    /// The front-on "title" bird whose wings span the whole canvas width: wings fold toward the body as tuck → 1.
    static func titlePath(for bird: Bird, tuck: Double, width: CGFloat, height: CGFloat) -> (body: CGPath, leftWing: CGPath, rightWing: CGPath)
}
```

The scene draws only from snapshots, the sea and events. It owns cosmetic state: spray particles, wake, rings,
clouds, stars, the lighthouse beam and the camera. It never changes game state.

## App API (the App engineer)

- **`GameController`** (`@MainActor ObservableObject`, `SceneDriver`) owns the session, the tuck source and the
  feedback, and exposes HUD state to SwiftUI.
- **Persistence.** `ProgressStore` and `SettingsStore` keep versioned JSON in UserDefaults.
- **Demo mode** (DEBUG and CI) is enabled by the launch argument `-swoopDemo "key=value;key"`. The keys are documented
  at the top of `Swoop/App/DemoMode.swift`.
- **Logs CI greps.** Every app log line that CI looks for starts with `SWOOP-`:
  - `SWOOP-T` for timing and demo lines;
  - `SWOOP-H` for hinge samples.
  - `SWOOP-T frame 120` is printed once the scene has drawn 120 frames.
- **Orientation.** All four orientations are supported, because a landscape-only app is letterboxed on a Duo held
  in tabletop pose (Brim run 40203342285). Play is landscape. Portrait shows the pose card.
