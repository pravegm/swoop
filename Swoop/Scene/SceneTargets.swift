import CoreGraphics
import Foundation

/// ROUND-12: the pure rules for the targets the words name (all canvas points, SpriteKit, y up; unit-tested).
///
/// - **P0-1:** the landing ring is reported to the App (`FlightScene.ringScreenRect`) only while it is ahead of the
///   bird and its whole rect (the ellipse and its drop marker) is on the visible canvas. A ring is first reported once
///   it has settled inboard (`ringInboardRect`), so the words never appear while it sits at an edge.
/// - **P0-2:** the camera frames the ring's whole rect inside the visible canvas inset by 200 pt at the sides, 160 pt
///   at the bottom and 120 pt at the top (scaled down on short canvases): clear of Skip, the step dots and the pause
///   button whichever corner they use.
/// - **P1-6:** the guide gull shows only while it is fully on screen and ahead of or level with the bird.
/// - **P1-7:** the school's Gull Point leaves `towerLabelRoom` under the visible top for its name.
enum SceneTargets {
    // MARK: The landing ring

    /// The ring's rect half-width: its ellipse widened 1.1× (the ring keeps its screen size at every zoom).
    static var ringHalfWidth: CGFloat { SceneLook.ringWidth * 1.1 * 0.5 }
    /// How far the rect reaches under the ring's centre (the ellipse's lower half).
    static var ringBelow: CGFloat { SceneLook.ringWidth * 1.1 * SceneLook.ringAspect * 0.5 }
    /// How far it reaches above the centre (the drop marker's dots and chevron, plus 8 pt).
    static var ringAbove: CGFloat { SceneLook.dropHeight + SceneLook.dropChevron + 8 }

    /// The ring's whole rect on the canvas around its centre `c` (canvas, y up).
    static func ringCanvasRect(center c: CGPoint) -> CGRect {
        CGRect(x: c.x - ringHalfWidth, y: c.y - ringBelow, width: ringHalfWidth * 2, height: ringBelow + ringAbove)
    }

    /// The side / bottom / top insets for a visible rect: 200 / 160 / 120 pt, but at most 25 % of the width, 30 % and
    /// 20 % of the height (a phone's cropped canvas is about 440 pt tall).
    static func ringInsets(visible v: CGRect) -> (side: CGFloat, bottom: CGFloat, top: CGFloat) {
        (min(SceneLook.ringEdgeInset, v.width * 0.25), min(SceneLook.ringBottomInset, v.height * 0.3),
         min(SceneLook.ringTopInset, v.height * 0.2))
    }

    /// ROUND-12 P0-2: where the ring's whole rect may sit (canvas, y up).
    static func ringInboardRect(visible v: CGRect) -> CGRect {
        let i = ringInsets(visible: v)
        return CGRect(x: v.minX + i.side, y: v.minY + i.bottom, width: max(v.width - 2 * i.side, 1),
                      height: max(v.height - i.bottom - i.top, 1))
    }

    /// Where the ring's centre may sit so its whole rect is inboard (the camera frames the centre into this).
    static func ringCentreRect(visible v: CGRect) -> CGRect {
        let box = ringInboardRect(visible: v)
        return CGRect(x: box.minX + ringHalfWidth, y: box.minY + ringBelow,
                      width: max(box.width - 2 * ringHalfWidth, 1),
                      height: max(box.height - ringBelow - ringAbove, 1))
    }

    /// ROUND-12 P0-1: whether the ring may be named now. `wasReported`: whether it was reported last frame.
    /// - Behind the bird (or level with it), or any part of it off the visible canvas: never.
    /// - Otherwise: once it is inboard, and from then on while it stays fully on screen (no flicker at the inboard
    ///   line as the camera eases).
    static func reportsRing(ringX: Double, birdX: Double, rect: CGRect, visible v: CGRect, wasReported: Bool) -> Bool {
        guard ringX > birdX else { return false }
        guard v.insetBy(dx: -0.5, dy: -0.5).contains(rect) else { return false }
        return wasReported || ringInboardRect(visible: v).contains(rect)
    }

    // MARK: The guide gull

    /// P1-6: the guide gull's half extents on the canvas at drawn zoom `z` (its art keeps 0.3 of the zoom, 0.9× the
    /// bird, plus half its glow).
    static func ghostHalfSize(zoom z: CGFloat) -> CGSize {
        let k = pow(max(z, 0.01), 1 - SceneLook.birdZoomResist) * SceneLook.ghostScale
        return CGSize(width: 0.62 * SceneLook.birdUnit * k + SceneLook.ghostGlow * 0.5,
                      height: 0.32 * SceneLook.birdUnit * k + SceneLook.ghostGlow * 0.5)
    }

    /// P1-6: the guide gull shows only fully on screen (`ghostEdgeMargin` inside the visible canvas) and ahead of or
    /// level with the bird (sea x, `ghostLevelSlack` of slack).
    static func ghostShows(center c: CGPoint, halfSize h: CGSize, visible v: CGRect, ghostX: Double,
                           birdX: Double) -> Bool {
        guard ghostX >= birdX - SceneLook.ghostLevelSlack else { return false }
        let box = CGRect(x: c.x - h.width, y: c.y - h.height, width: h.width * 2, height: h.height * 2)
        let m = SceneLook.ghostEdgeMargin
        return v.insetBy(dx: m, dy: m).contains(box)
    }

    // MARK: The school lighthouse

    /// The tower's height in its own units (the cap's apex; the lamp is at 131, the lantern room's top at 139).
    static let towerTop: CGFloat = 157

    /// P1-7: the school tower's scale: `nominal`, but small enough that its apex, standing at `baseY`, stays
    /// `towerLabelRoom` under `visibleTop` (room for its name above it), never below `schoolTowerMinScale`.
    static func schoolTowerScale(nominal: CGFloat, baseY: CGFloat, visibleTop: CGFloat) -> CGFloat {
        let room = (visibleTop - SceneLook.towerLabelRoom - baseY) / towerTop
        return max(min(nominal, room), SceneLook.schoolTowerMinScale)
    }
}
