import CoreGraphics
import SwiftUI

// MARK: - Pose

/// What the display should show, from the canvas shape and the hinge.
enum AppPose: String, Equatable {
    /// Landscape (the Duo held like a book, or any phone turned sideways): the game and its screens.
    case play
    /// Portrait (Duo tabletop, or a phone held upright): "Turn your Duo sideways and hold it like a book".
    case turn
    /// The Duo closed (hinge ≤ 10°) or the small cover display: "Open your wings".
    case closed
}

/// The pose rules. Pure; tested.
enum AppPoseRule {
    /// The Duo cover display is 466 × 678 pt; its inner canvas 951 × 669 / 669 × 951. Anything whose long side is under
    /// this, on a device with a hinge, is the cover.
    static let coverMaxSide: CGFloat = 760

    /// Both Duo displays are ~0.7 short-to-long; other iPhones ~0.46. The inner display is ≥ 600 pt on its short side.
    static func looksLikeDuoInner(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0 else { return false }
        return short / long > 0.62 && short >= 600
    }

    static func pose(canvas: CGSize, hingeSeen: Bool, isShut: Bool, touchOverride: Bool) -> AppPose {
        if hingeSeen && isShut { return .closed }
        let valid = canvas.width > 10 && canvas.height > 10
        if hingeSeen && valid && max(canvas.width, canvas.height) < coverMaxSide { return .closed }
        if valid && canvas.height > canvas.width && !touchOverride { return .turn }
        return .play
    }

    /// A vertical fold runs down the middle of a landscape Duo inner display (book pose).
    static func hasFold(canvas: CGSize, hingeSeen: Bool, demoDuo: Bool, divisionSeen: Bool) -> Bool {
        guard canvas.width >= canvas.height else { return false }
        if demoDuo { return true }
        if hingeSeen || divisionSeen { return max(canvas.width, canvas.height) >= coverMaxSide }
        return looksLikeDuoInner(canvas)
    }

    /// The game canvas: the whole screen in landscape; a centred landscape band on a portrait canvas ("Play with touch"
    /// from the pose card when iOS keeps the interface upright).
    static func playRect(in canvas: CGSize) -> CGRect {
        guard canvas.height > canvas.width else { return CGRect(origin: .zero, size: canvas) }
        let ratio = ScreenLayout.canvasHeight / ScreenLayout.canvasWidth
        let height = min(canvas.height, (canvas.width * ratio).rounded())
        return CGRect(x: 0, y: ((canvas.height - height) / 2).rounded(), width: canvas.width, height: height)
    }
}

// MARK: - The canvas as SwiftUI sees it

/// The play canvas in SwiftUI points (origin top-left), with the fold band mapped from the 952 × 670 design canvas
/// (aspect-filled, like the scene). Every screen lays its controls out on the two pages either side of the fold.
struct AppCanvas: Equatable {
    var size: CGSize
    var insets: EdgeInsets
    var layout: ScreenLayout

    /// Controls keep at least this far from the fold band.
    static let foldClear: CGFloat = 18
    /// Margin inside the safe area at the outer edges.
    static let edgeMargin: CGFloat = 14
    /// The smallest tap target anywhere (arm's length on a Duo held in two hands).
    static let minTap: CGFloat = 56

    init(size: CGSize, insets: EdgeInsets, layout: ScreenLayout) {
        self.size = size
        self.insets = insets
        self.layout = layout
    }

    /// The design canvas → screen scale (aspect fill).
    var scale: CGFloat {
        guard layout.size.width > 0, layout.size.height > 0 else { return 1 }
        return max(size.width / layout.size.width, size.height / layout.size.height)
    }

    /// Screen x of a design-canvas x.
    func screenX(_ designX: CGFloat) -> CGFloat {
        (size.width - layout.size.width * scale) / 2 + designX * scale
    }

    var foldMinX: CGFloat { screenX(layout.creaseMinX) }
    var foldMaxX: CGFloat { screenX(layout.creaseMaxX) }
    var hasFold: Bool { layout.hasFold }
    var mirrored: Bool { layout.mirrored }

    var leftPage: CGRect {
        let x0 = max(insets.leading, 0) + Self.edgeMargin
        let x1 = foldMinX - Self.foldClear
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    var rightPage: CGRect {
        let x0 = foldMaxX + Self.foldClear
        let x1 = size.width - max(insets.trailing, 0) - Self.edgeMargin
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    /// The half the bird flies on (left; right with "Bird on the other side").
    var birdPage: CGRect { mirrored ? rightPage : leftPage }
    /// The half that shows what's coming: menus, the results card, the HUD's distance.
    var farPage: CGRect { mirrored ? leftPage : rightPage }

    var top: CGFloat { max(insets.top, 0) + 10 }
    var bottom: CGFloat { size.height - max(insets.bottom, 8) - 8 }
    var isCompact: Bool { size.height < 520 }

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ rect: CGRect) -> Bool {
        rect.maxX <= foldMinX + 0.5 || rect.minX >= foldMaxX - 0.5
    }
}

// MARK: - Home

/// Where everything on Home goes (screen points). Pure; tested (every button fold-clear and ≥ 56 pt).
struct HomeLayout: Equatable {
    var bird: CGRect
    var wordmark: CGRect
    var caption: CGRect
    var menuPanel: CGRect
    /// The wordmark + caption block (its navy scrim keeps it readable over the attract bird).
    var textBlock: CGRect
    var fly: CGRect
    var daily: CGRect
    var flocks: CGRect
    var birds: CGRect
    var settings: CGRect
    var gameCenter: CGRect

    var buttons: [CGRect] { [fly, daily, flocks, birds, settings, gameCenter] }

    /// Preferred heights, shrunk toward `AppCanvas.minTap` on short screens.
    static let flyHeight: CGFloat = 76
    static let dailyHeight: CGFloat = 62
    static let rowHeight: CGFloat = 58
    static let gap: CGFloat = 10
    /// The menu column (REVIEW-1 P2: narrowed ~8 % so more of the sea ahead shows).
    static let maxMenuWidth: CGFloat = 368
    static let menuPageFraction: CGFloat = 0.92
    /// The wordmark's left inset from the page edge (REVIEW-1 P1-2: 24 pt from the screen edge on the Duo).
    static let wordmarkInset: CGFloat = 10

    static func make(_ c: AppCanvas) -> HomeLayout {
        let w = c.size.width
        let h = c.size.height
        let minTap = AppCanvas.minTap
        let top = c.top
        let bottom = c.bottom
        let minMenu = minTap * 3 + gap * 2
        let birdRoom = max(bottom - top - 12 - minMenu, 60)
        let birdH = min(max(h * 0.38, 90), 300, birdRoom)
        // Centred on the fold, so the title bird's body sits on the crease and each wing on its own half.
        let foldMid = (c.foldMinX + c.foldMaxX) / 2
        let birdHalf = max(min(foldMid - max(c.insets.leading, 0) - 8, w - max(c.insets.trailing, 0) - 8 - foldMid), 0)
        let bird = CGRect(x: foldMid - birdHalf, y: top, width: birdHalf * 2, height: birdH)
        let menuTop = bird.maxY + 12
        let avail = max(bottom - menuTop, 0)

        var flyH = flyHeight
        var dailyH = dailyHeight
        var rowH = rowHeight
        var need = flyH + dailyH + rowH + gap * 2
        if need > avail {
            let cut = min(need - avail, flyH - minTap)
            flyH -= cut
            need -= cut
        }
        if need > avail {
            let cut = min(need - avail, dailyH - minTap)
            dailyH -= cut
            need -= cut
        }
        if need > avail {
            let cut = min(need - avail, rowH - minTap)
            rowH -= cut
            need -= cut
        }

        let page = c.farPage
        let menuW = min(page.width * menuPageFraction, maxMenuWidth)
        let mx = c.mirrored ? page.minX : page.maxX - menuW
        let y0 = max(menuTop, bottom - need)
        let fly = CGRect(x: mx, y: y0, width: menuW, height: flyH)
        let daily = CGRect(x: mx, y: fly.maxY + gap, width: menuW, height: dailyH)
        let half = max((menuW - gap) / 2, 0)
        let flocks = CGRect(x: mx, y: daily.maxY + gap, width: half, height: rowH)
        let birds = CGRect(x: mx + half + gap, y: daily.maxY + gap, width: half, height: rowH)
        let panel = CGRect(x: mx - 10, y: y0 - 10, width: menuW + 20, height: birds.maxY - y0 + 20)

        let bp = c.birdPage
        let cornerY = bottom - minTap
        let settings: CGRect
        let gameCenter: CGRect
        if c.mirrored {
            settings = CGRect(x: bp.maxX - minTap, y: cornerY, width: minTap, height: minTap)
            gameCenter = CGRect(x: settings.minX - gap - minTap, y: cornerY, width: minTap, height: minTap)
        } else {
            settings = CGRect(x: bp.minX, y: cornerY, width: minTap, height: minTap)
            gameCenter = CGRect(x: settings.maxX + gap, y: cornerY, width: minTap, height: minTap)
        }
        // REVIEW-1 P1-2: a bigger wordmark (64–72 pt type on the Duo), inset from the edge.
        let wordH = min(max(h * 0.14, 46), 96)
        let tx = c.mirrored ? bp.minX : bp.minX + wordmarkInset
        let tw = max(bp.width - wordmarkInset, 0)
        let wordmark = CGRect(x: tx, y: menuTop, width: tw, height: wordH)
        let captionTop = wordmark.maxY + 2
        let caption = CGRect(x: tx, y: captionTop, width: tw, height: max(cornerY - 8 - captionTop, 0))
        let textBlock = CGRect(x: tx, y: wordmark.minY, width: tw,
                               height: wordH + 2 + min(caption.height, c.isCompact ? 70 : 110))
        return HomeLayout(bird: bird, wordmark: wordmark, caption: caption, menuPanel: panel, textBlock: textBlock,
                          fly: fly, daily: daily,
                          flocks: flocks, birds: birds, settings: settings, gameCenter: gameCenter)
    }
}

// MARK: - Play HUD

/// Where the play HUD goes (screen points). Pure; tested.
struct PlayLayout: Equatable {
    /// The pause button: the outer top corner of the bird's half (never on the fold).
    var pause: CGRect
    /// The distance: the outer top corner of the far half.
    var distance: CGRect
    /// The lead meter: a thin bar along the top of the bird's half.
    var meter: CGRect
    /// First-run hints: low on the bird's half.
    var hint: CGRect
    /// Countdown, "Ready", toasts: the middle of the far half.
    var center: CGRect
    /// Cards (pause, closing, lighthouse): the far half.
    var card: CGRect
    /// "Perfect ×N": above the bird on its own half (x follows the bird's fixed screen x), never on the fold.
    var callout: CGRect

    static let pauseSize: CGFloat = 56
    static let meterHeight: CGFloat = 14
    /// The callout's box and its height on the canvas (fraction from the top; the camera keeps the bird lower).
    static let calloutSize = CGSize(width: 260, height: 70)
    static let calloutY: CGFloat = 0.34

    static func make(_ c: AppCanvas) -> PlayLayout {
        let top = c.top
        let s = pauseSize
        let bp = c.birdPage
        let fp = c.farPage
        let pause: CGRect
        let meter: CGRect
        if c.mirrored {
            pause = CGRect(x: bp.maxX - s, y: top, width: s, height: s)
            let x0 = bp.minX
            meter = CGRect(x: x0, y: top + (s - meterHeight) / 2, width: max(pause.minX - 18 - x0, 0),
                           height: meterHeight)
        } else {
            pause = CGRect(x: bp.minX, y: top, width: s, height: s)
            let x0 = pause.maxX + 18
            meter = CGRect(x: x0, y: top + (s - meterHeight) / 2, width: max(bp.maxX - x0, 0), height: meterHeight)
        }
        let distance = CGRect(x: fp.minX, y: top - 6, width: fp.width, height: 130)
        let hint = CGRect(x: bp.minX, y: c.size.height * 0.62, width: bp.width, height: 64)
        let centerTop = distance.maxY + 4
        let center = CGRect(x: fp.minX, y: centerTop, width: fp.width, height: max(c.bottom - centerTop, 0))
        let card = CGRect(x: fp.minX, y: c.top, width: fp.width, height: max(c.bottom - c.top, 0))
        let f = ScreenLayout.birdScreenFraction
        let birdX = c.screenX(c.layout.size.width * (c.mirrored ? 1 - f : f))
        let cw = min(calloutSize.width, bp.width)
        let cx = min(max(birdX - cw / 2, bp.minX), max(bp.maxX - cw, bp.minX))
        let callout = CGRect(x: cx, y: c.size.height * calloutY - calloutSize.height / 2, width: cw,
                             height: calloutSize.height)
        return PlayLayout(pause: pause, distance: distance, meter: meter, hint: hint, center: center, card: card,
                          callout: callout)
    }
}

// MARK: - Results

/// The results card: the far half, full height (the calm bird stays visible on the bird's half). Pure; tested.
enum ResultsLayout {
    static let maxWidth: CGFloat = 460

    static func card(_ c: AppCanvas) -> CGRect {
        let page = c.farPage
        let w = min(page.width, maxWidth)
        let x = c.mirrored ? page.minX : page.maxX - w
        return CGRect(x: x, y: c.top, width: w, height: max(c.bottom - c.top, 0))
    }
}

// MARK: - The title bird's tuck

/// The Home title bird's wings: live from the hinge (the same stroke as the game, GAME-DESIGN §3), or a gentle idle
/// beat plus press-and-hold on phones. Pure; tested.
enum TitleTuck {
    /// The tuck stroke below the open angle (θ_open − θ_full = 36°).
    static let stroke: Double = 36
    /// Idle beat on phones: a slow, small fold (rest + amplitude · sin).
    static let idleRest: Double = 0.16
    static let idleAmplitude: Double = 0.12
    static let idleRate: Double = 1.3
    /// Press-and-hold ramps (the touch control's feel: 0.12 s in, 0.10 s out).
    static let holdAttack: Double = 0.12
    static let holdRelease: Double = 0.10

    static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func fromHinge(angle: Double, openAngle: Double) -> Double {
        guard angle.isFinite, openAngle.isFinite else { return 0 }
        return smoothstep((openAngle - angle) / stroke)
    }

    static func idle(time: Double) -> Double {
        idleRest + idleAmplitude * sin(time * idleRate)
    }

    /// `heldSince` while a finger is down, else `releasedAt` (both on the `now` clock).
    static func touch(now: Double, heldSince: Double?, releasedAt: Double?) -> Double {
        let base = idle(time: now)
        if let since = heldSince {
            return max(base, min(max((now - since) / holdAttack, 0), 1))
        }
        if let released = releasedAt {
            return max(base, 1 - min(max((now - released) / holdRelease, 0), 1))
        }
        return base
    }
}
