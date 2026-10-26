import CoreGraphics
import Foundation

// The only places the App touches the other modules' Round 3 additions (design/NEEDS.md "App → Core / Scene / Feel"),
// so a rename on either side is a one-file change.

/// Core: building a session (UX-C1's countdown length).
enum CoreAdapter {
    /// A session with a `countdown`-second 3-2-1 (3.0 for the first run of a launch, 1.5 after: UX-A2).
    static func makeSession(mode: RunMode, seed: UInt64, bestMeters: Double, bird: BirdID,
                            countdown: Double) -> FlightSession {
        FlightSession(mode: mode, seed: seed, bestMeters: bestMeters, bird: bird, countdown: countdown)
    }
}

/// R6 (Core K1): Flight School's practice sea. Core's `FlightSession.practice(bird:)` (the scripted calm sea, no storm,
/// never finishes, reports mode `.attract` so nothing records it). The App's own `mode` stays a Flight for the HUD.
extension CoreAdapter {
    static var practiceMode: RunMode { .flight }

    static func makePracticeSession(bird: BirdID) -> FlightSession { FlightSession.practice(bird: bird) }

    /// Step 7's storm: shown behind, held there, never catching.
    static let practiceStormGap: Double = 3000
}

/// Scene: where the bird is on screen (ART-S14 / UX-S1), for the "Perfect ×N" callout, plus the Round 3 hooks
/// (the title morph, effects quality, fine detail).
@MainActor
enum SceneAdapter {
    /// The bird's on-screen radius (view points) used to keep the callout clear of it.
    static let birdRadius: CGFloat = 44

    /// The bird's centre in the play view's own points (y down) and its radius: the scene's last `onBirdPoint` report,
    /// or nil (R5: `ScreenLayout.size` is the 952 × 670 DESIGN canvas, so a fallback from it landed in the wrong place;
    /// the views fall back to `defaultBirdPoint` in their own canvas instead).
    static func birdPoint(_ scene: FlightScene?, layout: ScreenLayout?,
                          reported: CGPoint?) -> (point: CGPoint, radius: CGFloat)? {
        guard scene != nil, layout != nil, let reported else { return nil }
        return (reported, birdRadius)
    }

    /// Where the bird sits when the scene hasn't said: its fixed design x (30 %, mirrored 70 %) at mid-height, in the
    /// view's points. Pure; tested.
    nonisolated static func defaultBirdPoint(_ c: AppCanvas) -> CGPoint {
        let f = ScreenLayout.birdScreenFraction
        let x = ScreenLayout.canvasWidth * (c.mirrored ? 1 - f : f)
        return c.screenPoint(CGPoint(x: x, y: ScreenLayout.canvasHeight * 0.5))
    }

    /// Subscribes to the scene's bird point (≤ 30 Hz, view points, y down).
    static func watchBird(_ scene: FlightScene, _ report: @escaping @MainActor (CGPoint) -> Void) {
        scene.onBirdPoint = { p in
            MainActor.assumeIsolated { report(p) }
        }
    }

    /// Thermal / Low Power (UX-D4/D5): 0.7 at `.serious`+ or in Low Power, else 1. Pure; tested.
    nonisolated static func effectsQuality(thermalHot: Bool, lowPower: Bool) -> CGFloat {
        thermalHot || lowPower ? 0.7 : 1
    }

    static func setEffects(_ scene: FlightScene?, quality: CGFloat) {
        guard let scene, scene.effectsQuality != quality else { return }
        scene.effectsQuality = quality
    }

    static func setFineDetail(_ scene: FlightScene?, _ on: Bool) {
        guard let scene, scene.fineDetail != on else { return }
        scene.fineDetail = on
    }

    static func playTitleMorph(_ scene: FlightScene?, tuck: Double) {
        scene?.playTitleMorph(tuck: tuck)
    }

    /// The sun's centre in DESIGN canvas points (Scene's `sunCanvasPoint`, y up), in 8 pt steps so the HUD doesn't
    /// republish every frame. The view converts it with `AppCanvas.screenPoint` (R5: R4 treated it as view points).
    static func sunDesignPoint(_ scene: FlightScene?) -> CGPoint? {
        guard let scene else { return nil }
        let p = scene.sunCanvasPoint
        guard p != .zero, p.x.isFinite, p.y.isFinite else { return nil }
        return CGPoint(x: (p.x / 8).rounded() * 8, y: (p.y / 8).rounded() * 8)
    }

    /// R6 (Scene SC1–SC2): Flight School's practice look, the guide on the water for the step (fixed sea positions on
    /// Core's scripted practice sea) and step 4's slow-motion bloom. nil = off. Only changes are written.
    static func setSchool(_ scene: FlightScene?, step: SchoolStep?, slowMo: Bool) {
        guard let scene else { return }
        let sea = step?.isSea ?? false
        if scene.practiceSea != sea { scene.practiceSea = sea }
        let g = guide(for: step)
        if scene.guide != g { scene.guide = g }
        if scene.slowMoBloom != slowMo { scene.slowMoBloom = slowMo }
    }

    /// The guide for a school step (Core's practice knots: crest A 0, trough 1500, crest B 2300; the guided landing
    /// falls around x 3150–3760). Pure; tested.
    nonisolated static func guide(for step: SchoolStep?) -> SceneGuide {
        switch step {
        case .some(.dive): return .foldPath(from: Tuning.practiceCrestAX, to: Tuning.practiceTroughX)
        case .some(.soar): return .openMark(at: Tuning.practiceTroughX)
        case .some(.land): return .landing(at: practiceLandingX)
        default: return SceneGuide.none
        }
    }

    nonisolated static let practiceLandingX: Double = 3450

    /// Step 7: the storm rolls in (no catch).
    static func rollInStorm(_ scene: FlightScene?) { scene?.rollInStorm() }

    /// SC4: the lit lighthouse's lamp (DESIGN canvas, y up, 8 pt steps), nil when no tower shows.
    static func lampDesignPoint(_ scene: FlightScene?) -> CGPoint? {
        guard let p = scene?.lampCanvasPoint, p.x.isFinite, p.y.isFinite else { return nil }
        return CGPoint(x: (p.x / 8).rounded() * 8, y: (p.y / 8).rounded() * 8)
    }

    /// R5b: Home's text frames (view points) keep the attract bird out from under the wordmark and caption; [] clears.
    static func setHomeTextRects(_ scene: FlightScene?, _ rects: [CGRect]) {
        guard let scene, scene.homeTextRects != rects else { return }
        scene.homeTextRects = rects
    }

    /// Store captures (demo runs): no book-gutter shade (juror R3 #26).
    static func storeCapture(_ scene: FlightScene) {
        scene.gutterEnabled = false
    }
}

/// Feel: the haptic profile (UX-F2) and the device flag.
@MainActor
enum FeelAdapter {
    /// Pushes the device flag (an unchosen profile follows it: Strong on a Duo) and, only when the player picked one,
    /// the haptic profile (Feel counts any write as a choice).
    static func applyHaptics(chosen: AppHapticLevel?, isDuo: Bool) {
        let feedback = FeedbackDirector.shared
        if feedback.deviceHasFold != isDuo { feedback.deviceHasFold = isDuo }
        guard let chosen else { return }
        let wanted = Self.profile(for: chosen)
        if feedback.hapticProfile != wanted { feedback.hapticProfile = wanted }
    }

    static func profile(for level: AppHapticLevel) -> HapticProfile {
        switch level {
        case .off: return .off
        case .normal: return .normal
        case .strong: return .strong
        }
    }
}
