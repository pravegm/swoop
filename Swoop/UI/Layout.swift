import CoreGraphics
import SwiftUI

// MARK: - Pose

/// What the display should show, from the canvas shape, the hinge and the run (UX-SPEC §9).
enum AppPose: String, Equatable {
    /// Landscape (the Duo held like a book, or any phone turned sideways): the game and its screens.
    case play
    /// Portrait on a Duo during a run or its results (seated inner display), or "Keep flying here" on the cover: the
    /// split deck, the game band on the top half and the touch deck below (UX-D2).
    case deck
    /// Portrait with nothing to play (Home and pages on a seated Duo; an iPhone held upright): "Turn it sideways".
    case turn
    /// The Duo shut (hinge ≤ 10°) or the small cover display: the cover card (UX-D1).
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

    /// - `inRun`: a run or its results is on screen (route playing / results).
    /// - `touchOverride`: "Play with touch" from the portrait card.
    /// - `coverFlying`: "Keep flying here" on the cover display.
    static func pose(canvas: CGSize, hingeSeen: Bool, isShut: Bool, inRun: Bool = false, touchOverride: Bool = false,
                     coverFlying: Bool = false) -> AppPose {
        let valid = canvas.width > 10 && canvas.height > 10
        let small = valid && max(canvas.width, canvas.height) < coverMaxSide
        if hingeSeen && small { return coverFlying && inRun ? .deck : .closed }
        // Duo R3 P2-7: a lit inner display (long side ≥ 760) is never "shut", whatever a stale latch says.
        if hingeSeen && isShut && !(valid && max(canvas.width, canvas.height) >= coverMaxSide) { return .closed }
        if valid && canvas.height > canvas.width {
            let duo = hingeSeen || looksLikeDuoInner(canvas)
            if duo && (inRun || touchOverride) { return .deck }
            return .turn
        }
        return .play
    }

    /// A vertical fold runs down the middle of a landscape Duo inner display (book pose).
    static func hasFold(canvas: CGSize, hingeSeen: Bool, demoDuo: Bool, divisionSeen: Bool) -> Bool {
        guard canvas.width >= canvas.height else { return false }
        if demoDuo { return true }
        if hingeSeen || divisionSeen { return max(canvas.width, canvas.height) >= coverMaxSide }
        return looksLikeDuoInner(canvas)
    }

    /// The game canvas in the play pose: the whole screen.
    static func playRect(in canvas: CGSize) -> CGRect {
        CGRect(origin: .zero, size: canvas)
    }
}

// MARK: - The split deck (UX-D2: seated Duo, or flying on the cover)

/// The portrait split: the game band on the top half and the deck (distance, meter, touch pad, pause) below, nothing
/// in the inner display's horizontal fold band (y 456–496). Pure; tested.
struct DeckLayout: Equatable {
    var band: CGRect
    var deck: CGRect

    /// Clear room either side of the seated fold.
    static let foldClear: CGFloat = 28

    static func make(canvas: CGSize) -> DeckLayout {
        let w = max(canvas.width, 1)
        let h = max(canvas.height, 1)
        let inner = max(w, h) >= AppPoseRule.coverMaxSide
        if inner {
            // 669 × 951: the band y 8…448, the deck from 504.
            let mid = h / 2
            let band = CGRect(x: 0, y: 8, width: w, height: max(mid - 8 - foldClear, 0))
            let deckTop = mid + foldClear
            return DeckLayout(band: band, deck: CGRect(x: 0, y: deckTop, width: w, height: max(h - deckTop, 0)))
        }
        // The cover (466 × 678): a 466 × 328 band, the deck under it.
        let bandH = min((w * 0.704).rounded(), h * 0.5)
        let band = CGRect(x: 0, y: 0, width: w, height: bandH)
        let deckTop = bandH + 8
        return DeckLayout(band: band, deck: CGRect(x: 0, y: deckTop, width: w, height: max(h - deckTop, 0)))
    }
}

// MARK: - The canvas as SwiftUI sees it

/// The play canvas in SwiftUI points (origin top-left), with the fold band mapped from the 952 × 670 design canvas
/// (aspect-filled, like the scene). Every screen lays its controls out on the two pages either side of the fold.
struct AppCanvas: Equatable {
    var size: CGSize
    var insets: EdgeInsets
    var layout: ScreenLayout
    /// One page only (the split deck, the cover): both "pages" are the whole width.
    var singlePage: Bool

    /// The smallest tap target anywhere (arm's length on a Duo held in two hands).
    static let minTap: CGFloat = 56

    init(size: CGSize, insets: EdgeInsets, layout: ScreenLayout, singlePage: Bool = false) {
        self.size = size
        self.insets = insets
        self.layout = layout
        self.singlePage = singlePage
    }

    /// Margins (ART §6 "Spacing"): 32 pt from the Duo's outer edges and 24 pt from the fold band; 20 pt (plus the safe
    /// area) and 16 pt on iPhones.
    var edgeMargin: CGFloat { hasFold ? 32 : 20 }
    var foldClear: CGFloat { hasFold ? 24 : 16 }

    /// The design canvas → screen scale (aspect fill).
    var scale: CGFloat {
        guard layout.size.width > 0, layout.size.height > 0 else { return 1 }
        return max(size.width / layout.size.width, size.height / layout.size.height)
    }

    /// Screen x of a design-canvas x.
    func screenX(_ designX: CGFloat) -> CGFloat {
        (size.width - layout.size.width * scale) / 2 + designX * scale
    }

    /// Screen point (SwiftUI, y down) of a design-canvas point (SpriteKit, y up). Pure; tested.
    func screenPoint(_ design: CGPoint) -> CGPoint {
        let s = scale
        let oy = (size.height - layout.size.height * s) / 2
        return CGPoint(x: screenX(design.x), y: oy + (layout.size.height - design.y) * s)
    }

    var foldMinX: CGFloat { screenX(layout.creaseMinX) }
    var foldMaxX: CGFloat { screenX(layout.creaseMaxX) }
    var hasFold: Bool { layout.hasFold }
    var mirrored: Bool { layout.mirrored }

    private var fullPage: CGRect {
        let x0 = max(insets.leading, 0) + edgeMargin
        let x1 = size.width - max(insets.trailing, 0) - edgeMargin
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    var leftPage: CGRect {
        if singlePage { return fullPage }
        let x0 = max(insets.leading, 0) + edgeMargin
        let x1 = foldMinX - foldClear
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    var rightPage: CGRect {
        if singlePage { return fullPage }
        let x0 = foldMaxX + foldClear
        let x1 = size.width - max(insets.trailing, 0) - edgeMargin
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    /// The half the bird flies on (left; right with "Bird on the other side").
    var birdPage: CGRect { mirrored ? rightPage : leftPage }
    /// The half that shows what's coming: menus, the results card, the HUD's distance.
    var farPage: CGRect { mirrored ? leftPage : rightPage }

    var top: CGFloat { max(insets.top, 0) + (hasFold ? 16 : 10) }
    var bottom: CGFloat { size.height - max(insets.bottom, 8) - (hasFold ? 16 : 8) }
    /// iPhone-sized type (ART §6): the Duo's 669 pt height gets the larger scale.
    var isCompact: Bool { size.height < 520 }

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ rect: CGRect) -> Bool {
        if singlePage { return true }
        return rect.maxX <= foldMinX + 0.5 || rect.minX >= foldMaxX - 0.5
    }
}

// MARK: - Home

/// Where everything on Home goes (screen points). Pure; tested (every button fold-clear and ≥ 56 pt).
struct HomeLayout: Equatable {
    var bird: CGRect
    var wordmark: CGRect
    var caption: CGRect
    var menuPanel: CGRect
    /// The wordmark + caption block.
    var textBlock: CGRect
    /// The feathered scrim behind it (ART A12): ends ≥ 28 pt + its feather before the crease.
    var scrim: CGRect
    var fly: CGRect
    var daily: CGRect
    var flocks: CGRect
    var birds: CGRect
    var settings: CGRect
    var gameCenter: CGRect

    var buttons: [CGRect] { [fly, daily, flocks, birds, settings, gameCenter] }
    /// The text the attract bird must keep under (R5b, Scene `homeTextRects`): the wordmark and the caption block.
    var textRects: [CGRect] { [wordmark, textBlock].filter { !$0.isEmpty } }

    /// Preferred heights, shrunk toward `AppCanvas.minTap` on short screens.
    static let flyHeight: CGFloat = 76
    static let dailyHeight: CGFloat = 62
    static let rowHeight: CGFloat = 58
    static let gap: CGFloat = 10
    /// The menu column: 368 wide on the Duo (UX §3).
    static let maxMenuWidth: CGFloat = 368
    static let menuPageFraction: CGFloat = 0.92
    /// The scrim's feather (blur) and its clearance from the fold band.
    static let scrimFeather: CGFloat = 32
    static let scrimFoldClear: CGFloat = 28

    static func make(_ c: AppCanvas) -> HomeLayout {
        let w = c.size.width
        let h = c.size.height
        let minTap = AppCanvas.minTap
        let top = c.top
        let bottom = c.bottom
        let minMenu = minTap * 3 + gap * 2
        let birdRoom = max(bottom - top - 12 - minMenu, 60)
        let birdH = min(max(h * 0.38, 90), 254, birdRoom)
        // Centred on the fold, so the title bird's spine sits on the crease and each wing on its own half.
        let foldMid = (c.foldMinX + c.foldMaxX) / 2
        let birdHalf = max(min(foldMid - max(c.insets.leading, 0) - 12, w - max(c.insets.trailing, 0) - 12 - foldMid), 0)
        let bird = CGRect(x: foldMid - birdHalf, y: max(c.insets.top, 0) + 10, width: birdHalf * 2, height: birdH)
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
        // The wordmark: 72 pt type on the Duo, 52 on iPhone (ART §6), on the bird page under the title bird.
        let wordH: CGFloat = c.isCompact ? 70 : 96
        let wordmark = CGRect(x: bp.minX, y: menuTop, width: bp.width, height: wordH)
        let captionTop = wordmark.maxY + 2
        let caption = CGRect(x: bp.minX, y: captionTop, width: bp.width, height: max(cornerY - 8 - captionTop, 0))
        let textBlock = CGRect(x: bp.minX, y: wordmark.minY, width: bp.width,
                               height: wordH + 2 + min(caption.height, c.isCompact ? 70 : 110))
        var scrim = textBlock.insetBy(dx: -16, dy: -12)
        if c.mirrored {
            let minX = c.foldMaxX + scrimFoldClear + scrimFeather
            if scrim.minX < minX { scrim = CGRect(x: minX, y: scrim.minY, width: max(scrim.maxX - minX, 0), height: scrim.height) }
        } else {
            let maxX = c.foldMinX - scrimFoldClear - scrimFeather
            if scrim.maxX > maxX { scrim.size.width = max(maxX - scrim.minX, 0) }
        }
        return HomeLayout(bird: bird, wordmark: wordmark, caption: caption, menuPanel: panel, textBlock: textBlock,
                          scrim: scrim, fly: fly, daily: daily, flocks: flocks, birds: birds, settings: settings,
                          gameCenter: gameCenter)
    }
}

// MARK: - Play HUD

/// Where the play HUD goes (screen points, UX-SPEC §3 "Play HUD"). Pure; tested.
struct PlayLayout: Equatable {
    /// The pause button: the outer top corner of the bird's half (never on the fold).
    var pause: CGRect
    /// The lead meter: from pause + 18 to the bird page's inner edge.
    var meter: CGRect
    /// One 12 pt line 22 pt under the meter: the DAILY tag and the one-time teach lines.
    var tagLine: CGRect
    /// The distance, its pill and "Best in…": the outer top corner of the far half.
    var distance: CGRect
    /// First-run hints: the bird's half at 62 % height.
    var hint: CGRect
    /// Countdown and "Ready": the middle of the far half.
    var center: CGRect
    /// Toasts and the lighthouse card: the far half, top edge at 60 % height, over the sea.
    var toast: CGRect
    /// Cards (pause, closing): the far half.
    var card: CGRect

    static let pauseSize: CGFloat = 56
    static let meterHeight: CGFloat = 14
    static let toastTop: CGFloat = 0.60

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
        let tagLine = CGRect(x: meter.minX, y: meter.maxY + 22 - 6, width: meter.width, height: 20)
        let distance = CGRect(x: fp.minX, y: top - 6, width: fp.width, height: 120)
        let hint = CGRect(x: bp.minX, y: c.size.height * 0.62, width: bp.width, height: 64)
        let centerTop = distance.maxY + 4
        let toastY = c.size.height * toastTop
        let center = CGRect(x: fp.minX, y: centerTop, width: fp.width, height: max(toastY - centerTop, 80))
        let toast = CGRect(x: fp.minX, y: toastY, width: fp.width, height: max(c.bottom - toastY, 60))
        let card = CGRect(x: fp.minX, y: c.top, width: fp.width, height: max(c.bottom - c.top, 0))
        return PlayLayout(pause: pause, meter: meter, tagLine: tagLine, distance: distance, hint: hint, center: center,
                          toast: toast, card: card)
    }
}

/// Where "Perfect ×N" goes (UX-A1, ART A5): the bird + (40, −64) (mirrored −40); if that's under the HUD, 70 pt below
/// the bird instead; clear of the bird's rect + 24; clamped into the bird page. Pure; tested.
enum CalloutPlacement {
    static let offset = CGPoint(x: 40, y: -64)
    static let below: CGFloat = 70
    static let birdClear: CGFloat = 24
    /// The HUD band at the top of the bird page.
    static let hudBand: CGFloat = 106

    static func center(bird: CGPoint, birdRadius: CGFloat, size: CGSize, canvas c: AppCanvas) -> CGPoint {
        let dx = c.mirrored ? -offset.x : offset.x
        var p = CGPoint(x: bird.x + dx, y: bird.y + offset.y)
        if p.y - size.height / 2 < c.top + hudBand { p.y = bird.y + below }
        // Keep the label's box clear of the bird's rect + 24.
        let r = birdRadius + birdClear
        let birdBox = CGRect(x: bird.x - r, y: bird.y - r, width: 2 * r, height: 2 * r)
        var box = CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width, height: size.height)
        if box.intersects(birdBox) {
            if p.y < bird.y {
                p.y = birdBox.minY - size.height / 2
            } else {
                p.y = birdBox.maxY + size.height / 2
            }
            box = CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width, height: size.height)
        }
        // Clamp into the bird page (horizontally) and the screen (vertically).
        let page = c.birdPage
        let minX = page.minX + size.width / 2
        let maxX = max(page.maxX - size.width / 2, minX)
        p.x = min(max(p.x, minX), maxX)
        let minY = c.top + size.height / 2
        let maxY = max(c.bottom - size.height / 2, minY)
        p.y = min(max(p.y, minY), maxY)
        _ = box
        return p
    }
}

/// R4 P1-12 (UX R3 P1-8): a phone's hint pill rides 110 pt above the bird (flipping 110 pt below it when that would
/// meet the HUD), centred on the bird page, so the bird and its trail never pass under the words. Pure; tested.
enum HintPlacement {
    static let offset: CGFloat = 110

    static func center(bird: CGPoint, size: CGSize, canvas c: AppCanvas) -> CGPoint {
        let hudBottom = c.top + CalloutPlacement.hudBand + 16
        var y = bird.y - offset
        if y - size.height / 2 < hudBottom { y = bird.y + offset }
        let minY = hudBottom + size.height / 2
        let maxY = max(c.bottom - size.height / 2, minY)
        y = min(max(y, minY), maxY)
        return CGPoint(x: c.birdPage.midX, y: y)
    }

    /// The pill's box at `center`.
    static func box(center p: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width, height: size.height)
    }
}

/// R4 P1-9: "Splash" sits just behind and above the bird (where the eye is), clamped onto the screen. Pure; tested.
enum SplashPlacement {
    static let offset = CGPoint(x: -36, y: -58)
    static let halfWidth: CGFloat = 110
    static let halfHeight: CGFloat = 20

    static func center(bird: CGPoint, canvas c: AppCanvas) -> CGPoint {
        let dx = c.mirrored ? -offset.x : offset.x
        var p = CGPoint(x: bird.x + dx, y: bird.y + offset.y)
        let page = c.birdPage
        p.x = min(max(p.x, page.minX + halfWidth), max(page.maxX - halfWidth, page.minX + halfWidth))
        p.y = min(max(p.y, c.top + CalloutPlacement.hudBand + halfHeight), max(c.bottom - halfHeight, c.top))
        return p
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

    /// The far card: `card`, or on a one-page canvas (the split decks) the whole page less 12 pt top and bottom.
    static func far(_ c: AppCanvas) -> CGRect {
        if c.singlePage {
            return CGRect(x: c.farPage.minX, y: 12, width: c.farPage.width, height: max(c.size.height - 24, 0))
        }
        return card(c)
    }

    /// R5 P1-4: a card `height` tall (at most the space), bottom-anchored in `space`, so it carries no void.
    static func anchored(_ space: CGRect, height: CGFloat) -> CGRect {
        let h = min(max(height, 0), space.height)
        return CGRect(x: space.minX, y: space.maxY - h, width: space.width, height: h)
    }

    /// R4 P0-1: the bird-page card (rank-up, goals, small lines, the Daily's share card), from its outer edge.
    static func side(_ c: AppCanvas) -> CGRect {
        let page = c.birdPage
        let w = min(page.width, maxWidth)
        let x = c.mirrored ? page.maxX - w : page.minX
        return CGRect(x: x, y: c.top, width: w, height: max(c.bottom - c.top, 0))
    }
}

// MARK: - The title bird's tuck

/// The Home title bird's wings: live from the hinge (the same mapping and filters as play), or a gentle idle beat
/// plus press-and-hold on phones. Pure; tested.
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

    /// Play's own mapping (R4, Feel): stroke = clamp(open − 100, 30, 36), the open angle floored at 132°.
    static func fromHinge(angle: Double, openAngle: Double) -> Double {
        guard angle.isFinite, openAngle.isFinite else { return 0 }
        return HingeTuckTuning.tuck(forAngle: angle, open: max(openAngle, HingeTuckTuning.openMin))
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
