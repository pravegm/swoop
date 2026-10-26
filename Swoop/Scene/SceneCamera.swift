import CoreGraphics
import Foundation

/// The scene's camera as a pure value (unit-tested): sea space → canvas.
///
/// - Horizontal: the bird is pinned at `ScreenLayout.birdScreenFraction` (30 %) of the canvas width, or at 70 % with
///   the world flipped when `mirrored` (the flight then runs right-to-left).
/// - Zoom: 1.0 near the water, down to `zoomMin` high up, chosen from the bird's altitude above a smoothed water line
///   and followed by a critically damped spring, so the water always stays in view (GAME-DESIGN §4).
/// - Vertical: the smoothed water line sits `groundFraction` up the visible height; the bird is kept between
///   `birdBottomFraction` and `birdTopFraction` of it (R2: never in the top 22 %, the HUD band). Everything is framed
///   inside `layout.visibleRect`, so phones (which crop the 952 × 670 canvas top and bottom) keep the water too.
/// - Display scale (R2): a short-lived multiplier centred on the bird (the Perfect punch-in, the full-speed pull-out).
///   The bird stays exactly where it is on screen; only the world around it scales.
struct SceneCamera: Equatable {
    /// Zoom with the bird on the water.
    static let zoomMax: Double = 1.0
    /// The furthest zoom-out on the Duo canvas (GAME-DESIGN §4: ≈ 0.45). Shorter visible heights (cropped phones) zoom
    /// out a little further so the same world height fits.
    static let zoomMinDuo: Double = 0.42
    /// The smoothed water line sits this fraction up the visible height.
    static let groundFraction: Double = 0.32
    /// Altitude that fits at zoom 1, as a fraction of the visible height; above it the camera zooms out.
    /// (groundFraction + this stays under birdTopFraction, so the zoom-out starts before the bird reaches the HUD.)
    static let framingFraction: Double = 0.42
    /// The bird never goes higher on screen than this fraction of the visible height (REVIEW-1 P0-5: the 22 % HUD
    /// band)…
    static let birdTopFraction: Double = 0.78
    /// …nor lower than this one.
    static let birdBottomFraction: Double = 0.12
    /// Spring rate of the zoom (rad/s, critically damped): τ 0.35 s (ART §5).
    static let zoomOmega: Double = 2.86
    /// Spring rate of the water-line follow (rad/s). Low, so the frame doesn't bob with every swell.
    static let groundOmega: Double = 2.2

    var canvasWidth: Double
    var visibleMinY: Double
    var visibleHeight: Double
    var mirrored: Bool

    /// The framing zoom (springs). What is drawn is `zoom` = this × `displayScale`.
    private(set) var framingZoom: Double = 1
    private(set) var zoomVelocity: Double = 0
    /// The smoothed sea height under the bird (sea space).
    private(set) var ground: Double = 0
    private(set) var groundVelocity: Double = 0
    private(set) var birdX: Double = 0
    private(set) var birdY: Double = 0
    /// The sea y at the bottom of the visible rect before the display scale.
    private(set) var framingBottomY: Double = 0
    /// Short-lived multiplier centred on the bird: > 1 punches in, < 1 pulls out.
    private(set) var displayScale: Double = 1
    /// Home's attract loop (R5b): the bird's screen y (canvas, y up) never goes above this; the zoom also comes out
    /// sooner, so the flight fits under it. nil = no limit.
    var birdCeiling: Double?

    init(layout: ScreenLayout) {
        canvasWidth = Double(layout.size.width)
        visibleMinY = Double(layout.visibleRect.minY)
        visibleHeight = max(Double(layout.visibleRect.height), 1)
        mirrored = layout.mirrored
        framingBottomY = -SceneCamera.groundFraction * visibleHeight
    }

    var zoomMin: Double {
        let k = min(max(visibleHeight / Double(ScreenLayout.canvasHeight), 0.7), 1.0)
        return SceneCamera.zoomMinDuo * k
    }

    /// The drawn zoom (canvas points per sea point).
    var zoom: Double { framingZoom * displayScale }

    /// The drawn sea y at the bottom of the visible rect (the display scale is centred on the bird).
    var bottomY: Double {
        let z = max(zoom, 0.0001)
        return birdY - (birdY - framingBottomY) * framingZoom / z
    }

    /// Canvas x of the bird.
    var anchorX: Double {
        let f = Double(ScreenLayout.birdScreenFraction)
        return canvasWidth * (mirrored ? 1 - f : f)
    }

    /// +1: flight runs left-to-right on screen; −1 mirrored.
    var direction: Double { mirrored ? -1 : 1 }

    /// The zoom that frames `altitude` pt of air between the water line and the bird.
    func targetZoom(altitude: Double) -> Double {
        var framing = SceneCamera.framingFraction
        if let c = birdCeiling {
            let ceilingFraction = (c - visibleMinY) / visibleHeight
            framing = min(framing, max(ceilingFraction - SceneCamera.groundFraction - 0.04, 0.05))
        }
        let fit = framing * visibleHeight / max(altitude, 1)
        return min(SceneCamera.zoomMax, max(zoomMin, fit))
    }

    /// Jump straight to the framing for this bird (new session, layout change).
    mutating func snap(bird: CGPoint, water: Double) {
        birdX = Double(bird.x)
        ground = water
        groundVelocity = 0
        framingZoom = targetZoom(altitude: Double(bird.y) - ground)
        zoomVelocity = 0
        displayScale = 1
        frame(birdY: Double(bird.y))
    }

    /// Follow the bird. `water` is the sea height under it; `dt` 0 holds the springs (paused / frozen frames).
    mutating func update(bird: CGPoint, water: Double, dt: Double) {
        birdX = Double(bird.x)
        if dt > 0 {
            let h = min(dt, 1.0 / 30.0)
            let wg = SceneCamera.groundOmega
            let ga = wg * wg * (water - ground) - 2 * wg * groundVelocity
            groundVelocity += ga * h
            ground += groundVelocity * h
            let tz = targetZoom(altitude: Double(bird.y) - ground)
            let wz = SceneCamera.zoomOmega
            let za = wz * wz * (tz - framingZoom) - 2 * wz * zoomVelocity
            zoomVelocity += za * h
            framingZoom += zoomVelocity * h
            framingZoom = min(SceneCamera.zoomMax * 1.02, max(zoomMin * 0.9, framingZoom))
        }
        frame(birdY: Double(bird.y))
    }

    /// A launch "pull-out": the zoom dips by about `amount` and springs back.
    mutating func pullOut(_ amount: Double) {
        zoomVelocity -= amount * SceneCamera.zoomOmega * 2.7
    }

    /// The display multiplier (clamped 0.9 … 1.1), centred on the bird.
    mutating func setDisplayScale(_ s: Double) {
        displayScale = min(max(s, 0.9), 1.1)
    }

    private mutating func frame(birdY y: Double) {
        birdY = y
        let z = max(framingZoom, 0.01)
        let hv = visibleHeight
        var b = ground - SceneCamera.groundFraction * hv / z
        b = max(b, y - SceneCamera.birdTopFraction * hv / z)
        b = min(b, y - SceneCamera.birdBottomFraction * hv / z)
        // The ceiling wins over the bottom margin: the bird stays under Home's text.
        if let c = birdCeiling { b = max(b, y - (c - visibleMinY) / z) }
        framingBottomY = b
    }

    /// Canvas point of a sea-space point.
    func screenPoint(_ p: CGPoint) -> CGPoint {
        let z = zoom
        let x = anchorX + direction * (Double(p.x) - birdX) * z
        let y = visibleMinY + (Double(p.y) - bottomY) * z
        return CGPoint(x: x, y: y)
    }

    /// The sea-x range on the canvas (0 … width), widened by `margin` canvas points on each side.
    func visibleSeaRange(margin: Double) -> (lo: Double, hi: Double) {
        let z = max(zoom, 0.01)
        let a = birdX + (-margin - anchorX) / (direction * z)
        let b = birdX + (canvasWidth + margin - anchorX) / (direction * z)
        return (min(a, b), max(a, b))
    }

    /// Canvas y of the mean water level (y = 0).
    var meanWaterScreenY: Double { visibleMinY - bottomY * zoom }
}
