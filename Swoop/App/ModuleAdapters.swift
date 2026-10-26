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

/// Scene: where the bird is on screen (ART-S14 / UX-S1), for the "Perfect ×N" callout, plus the Round 3 hooks
/// (the title morph, effects quality, fine detail).
@MainActor
enum SceneAdapter {
    /// The bird's on-screen radius (view points) used to keep the callout clear of it.
    static let birdRadius: CGFloat = 44

    /// The bird's centre in the play view's own points (y down) and its radius: the scene's last `onBirdPoint` report
    /// when there is one, else the bird's fixed screen x at mid-height.
    static func birdPoint(_ scene: FlightScene?, layout: ScreenLayout?,
                          reported: CGPoint?) -> (point: CGPoint, radius: CGFloat)? {
        guard scene != nil, let layout else { return nil }
        if let reported { return (reported, birdRadius) }
        let f = ScreenLayout.birdScreenFraction
        let x = layout.size.width * (layout.mirrored ? 1 - f : f)
        return (CGPoint(x: x, y: layout.size.height * 0.5), birdRadius)
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

    /// The sun's centre in the play view's points (y down), from Scene's `sunCanvasPoint` (canvas, y up), in 8 pt
    /// steps so the HUD doesn't republish every frame.
    static func sunScreenPoint(_ scene: FlightScene?, layout: ScreenLayout?) -> CGPoint? {
        guard let scene, let layout else { return nil }
        let p = scene.sunCanvasPoint
        guard p != .zero, p.x.isFinite, p.y.isFinite else { return nil }
        return CGPoint(x: (p.x / 8).rounded() * 8, y: ((layout.size.height - p.y) / 8).rounded() * 8)
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
