import CoreGraphics
import Foundation

/// The scene's camera as a pure value (unit-tested): sea space → canvas.
///
/// - Horizontal: the bird is pinned at `ScreenLayout.birdScreenFraction` (30 %) of the canvas width, or at 70 % with
///   the world flipped when `mirrored` (the flight then runs right-to-left).
/// - Zoom: 1.0 near the water, down to `zoomMin` high up, chosen from the bird's altitude above a smoothed water line
///   and followed by a critically damped spring, so the water always stays in view (GAME-DESIGN §4).
/// - Vertical: the smoothed water line sits `groundFraction` up the visible height; the bird is kept between
///   `birdBottomFraction` and `birdTopFraction` of it. Everything is framed inside `layout.visibleRect`, so phones
///   (which crop the 952 × 670 canvas top and bottom) keep the water too.
struct SceneCamera: Equatable {
    /// Zoom with the bird on the water.
    static let zoomMax: Double = 1.0
    /// The furthest zoom-out on the Duo canvas (GAME-DESIGN §4: ≈ 0.45). Shorter visible heights (cropped phones) zoom
    /// out a little further so the same world height fits.
    static let zoomMinDuo: Double = 0.42
    /// The smoothed water line sits this fraction up the visible height.
    static let groundFraction: Double = 0.32
    /// Altitude that fits at zoom 1, as a fraction of the visible height; above it the camera zooms out.
    static let framingFraction: Double = 0.50
    /// The bird never goes higher on screen than this fraction of the visible height…
    static let birdTopFraction: Double = 0.84
    /// …nor lower than this one.
    static let birdBottomFraction: Double = 0.12
    /// Spring rate of the zoom (rad/s, critically damped). Higher = snappier zoom.
    static let zoomOmega: Double = 2.6
    /// Spring rate of the water-line follow (rad/s). Low, so the frame doesn't bob with every swell.
    static let groundOmega: Double = 2.2

    var canvasWidth: Double
    var visibleMinY: Double
    var visibleHeight: Double
    var mirrored: Bool

    private(set) var zoom: Double = 1
    private(set) var zoomVelocity: Double = 0
    /// The smoothed sea height under the bird (sea space).
    private(set) var ground: Double = 0
    private(set) var groundVelocity: Double = 0
    private(set) var birdX: Double = 0
    /// The sea y shown at the bottom of the visible rect.
    private(set) var bottomY: Double = 0

    init(layout: ScreenLayout) {
        canvasWidth = Double(layout.size.width)
        visibleMinY = Double(layout.visibleRect.minY)
        visibleHeight = max(Double(layout.visibleRect.height), 1)
        mirrored = layout.mirrored
        bottomY = -SceneCamera.groundFraction * visibleHeight
    }

    var zoomMin: Double {
        let k = min(max(visibleHeight / Double(ScreenLayout.canvasHeight), 0.7), 1.0)
        return SceneCamera.zoomMinDuo * k
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
        let fit = SceneCamera.framingFraction * visibleHeight / max(altitude, 1)
        return min(SceneCamera.zoomMax, max(zoomMin, fit))
    }

    /// Jump straight to the framing for this bird (new session, layout change).
    mutating func snap(bird: CGPoint, water: Double) {
        birdX = Double(bird.x)
        ground = water
        groundVelocity = 0
        zoom = targetZoom(altitude: Double(bird.y) - ground)
        zoomVelocity = 0
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
            let za = wz * wz * (tz - zoom) - 2 * wz * zoomVelocity
            zoomVelocity += za * h
            zoom += zoomVelocity * h
            zoom = min(SceneCamera.zoomMax * 1.02, max(zoomMin * 0.9, zoom))
        }
        frame(birdY: Double(bird.y))
    }

    /// A launch "pull-out": the zoom dips by about `amount` and springs back.
    mutating func pullOut(_ amount: Double) {
        zoomVelocity -= amount * SceneCamera.zoomOmega * 2.7
    }

    private mutating func frame(birdY: Double) {
        let z = max(zoom, 0.01)
        let hv = visibleHeight
        var b = ground - SceneCamera.groundFraction * hv / z
        b = max(b, birdY - SceneCamera.birdTopFraction * hv / z)
        b = min(b, birdY - SceneCamera.birdBottomFraction * hv / z)
        bottomY = b
    }

    /// Canvas point of a sea-space point.
    func screenPoint(_ p: CGPoint) -> CGPoint {
        let x = anchorX + direction * (Double(p.x) - birdX) * zoom
        let y = visibleMinY + (Double(p.y) - bottomY) * zoom
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
