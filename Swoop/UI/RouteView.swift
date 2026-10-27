import SwiftUI

// R9 (UX-ROUND-9 §5, ART-ROUND-9 §4 / AR5): the Route reads LEFT TO RIGHT always, like a sentence (the mirrored play
// layout exists for the blur; a map is a map): the harbour with the storm behind it at the left, the lighthouses in km
// order to the right, every one by its real name, labels on one baseline row that never overlap, "and on…" in its own
// slot, the single Best pin, and the next lighthouse at 60 % of the width on open.

/// The Route's geometry as data (content points, y down). Pure; tested (`routeLabelsNeverOverlap`,
/// `routeReadsLeftToRight`).
struct RouteLayout: Equatable {
    struct Node: Equatable {
        var index: Int
        var x: CGFloat
        var tipY: CGFloat
        var iconRect: CGRect
        var labelRect: CGRect
        var nameLines: Int
    }

    var spacing: CGFloat
    var contentWidth: CGFloat
    var coastBase: CGFloat
    var labelRowY: CGFloat
    var harbourX: CGFloat
    var nodes: [Node]
    var tailRect: CGRect
    /// The Best pin on the route line, and its label (nil: the label didn't fit clear; the bottom bar has it).
    var bestPin: CGPoint?
    var bestLabelRect: CGRect?
    /// The scroll offset (content x at the view's left edge) on open.
    var openOffset: CGFloat

    static func spacing(_ compact: Bool) -> CGFloat { compact ? 130 : 150 }
    static func coastBase(_ compact: Bool) -> CGFloat { compact ? 118 : 150 }
    static let headland: CGFloat = 34
    static let headlandWidth: CGFloat = 120
    static let routeDrop: CGFloat = 26
    static func nameSize(_ c: Bool) -> CGFloat { c ? 15 : 17 }
    static func captionSize(_ c: Bool) -> CGFloat { c ? 13 : 14 }
    static func line(_ s: CGFloat) -> CGFloat { (s * 1.22).rounded(.up) }

    /// The coast's y at content x (ART §4): `base + 20 sin(x/170) + 10 sin(x/61 + 1.3)`, plus a 34 pt seaward point
    /// (a cosine bump 120 pt wide) at every lighthouse, so each stands on a headland, never in a cove.
    static func coastY(_ x: CGFloat, base: CGFloat, heads: [CGFloat]) -> CGFloat {
        var y = base + 20 * sin(x / 170) + 10 * sin(x / 61 + 1.3)
        for h in heads {
            let d = abs(x - h) / (headlandWidth / 2)
            if d < 1 { y += headland * 0.5 * (1 + cos(CGFloat.pi * d)) }
        }
        return y
    }

    static func make(viewWidth w: CGFloat, compact c: Bool, routeReached: Int, best: Double, edge: CGFloat = 0,
                     fold: ClosedRange<CGFloat>? = nil) -> RouteLayout {
        let s = spacing(c)
        let base = coastBase(c)
        let harbour = 48 + edge
        // Every passed lighthouse, the next, then two more (R10: "Lantern Rock" was cut at the Duo's right edge).
        let count = max(routeReached, 0) + 3
        let firstX = harbour + (c ? 82 : 102)
        let heads = (0..<count).map { firstX + CGFloat($0) * s }
        let rowY = base + headland + 64
        let nameW = s - 16
        var nodes: [Node] = []
        for (i, x) in heads.enumerated() {
            let tip = coastY(x, base: base, heads: heads)
            let size: CGFloat = i == routeReached ? 44 : 30
            let icon = CGRect(x: x - size * 0.375, y: tip - size + 4, width: size * 0.75, height: size)
            let name = RouteRules.name(i)
            let lines = min(2, max(1, Int((CGFloat(name.count) * nameSize(c) * 0.56 / nameW).rounded(.up))))
            let h = CGFloat(lines) * line(nameSize(c)) + 2 + line(captionSize(c))
            let label = CGRect(x: x - nameW / 2, y: rowY, width: nameW, height: h)
            nodes.append(Node(index: i, x: x, tipY: tip, iconRect: icon, labelRect: label, nameLines: lines))
        }
        let lastX = heads.last ?? harbour
        // "and on…" in its own slot one spacing beyond the last node, on the name row.
        let tailW: CGFloat = 90
        let tail = CGRect(x: lastX + s - tailW / 2, y: rowY, width: tailW, height: line(nameSize(c)))
        let contentWidth = max(w, tail.maxX + 24)

        // The Best pin: on the route line at the true fraction; its label above the line, else below, else none.
        var pin: CGPoint?
        var pinLabel: CGRect?
        if best > 0, best.isFinite {
            let n = RouteRules.reached(within: best)
            let before = n == 0 ? 0 : RouteRules.meters(n - 1)
            let after = RouteRules.meters(n)
            let f = after > before ? CGFloat(min(max((best - before) / (after - before), 0), 1)) : 0
            let x0 = n == 0 ? harbour : (n - 1 < heads.count ? heads[n - 1] : lastX)
            let x1 = n < heads.count ? heads[n] : x0 + s
            let px = x0 + (x1 - x0) * f
            let py = lineY(px, base: base, heads: heads, harbour: harbour)
            pin = CGPoint(x: px, y: py)
            let text = "Best \(ShareText.distance(best))"
            let lw = CGFloat(text.count) * captionSize(c) * 0.6 + 20
            let above = CGRect(x: px - lw / 2, y: py - 28 - 12, width: lw, height: 24)
            let below = CGRect(x: px - lw / 2, y: py + 14, width: lw, height: 24)
            let blockers = nodes.flatMap { [$0.iconRect, $0.labelRect] } + [tail]
            func clear(_ r: CGRect) -> Bool { !blockers.contains { $0.insetBy(dx: -4, dy: -4).intersects(r) } }
            pinLabel = clear(above) ? above : (clear(below) ? below : nil)
        }

        // On open: the next lighthouse at 60 % of the width, then snapped so no icon centre sits in the fold band.
        let nextX = routeReached < heads.count ? heads[routeReached] : lastX
        var offset = min(max(nextX - 0.6 * w, 0), max(contentWidth - w, 0))
        if let fold {
            let band = (fold.lowerBound - 22)...(fold.upperBound + 22)
            offset = min(max(RouteArt.snapOffset(proposed: offset, centres: heads, band: band), 0),
                         max(contentWidth - w, 0))
        }
        return RouteLayout(spacing: s, contentWidth: contentWidth, coastBase: base, labelRowY: rowY, harbourX: harbour,
                           nodes: nodes, tailRect: tail, bestPin: pin, bestLabelRect: pinLabel, openOffset: offset)
    }

    /// The route line: 26 pt seaward of the headland tips, straight between them; from the harbour to the first.
    static func lineY(_ x: CGFloat, base: CGFloat, heads: [CGFloat], harbour: CGFloat) -> CGFloat {
        let pts = [CGPoint(x: harbour, y: coastY(harbour, base: base, heads: heads) + routeDrop)]
            + heads.map { CGPoint(x: $0, y: coastY($0, base: base, heads: heads) + routeDrop) }
        guard let first = pts.first, let last = pts.last else { return base + routeDrop }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for i in 1..<pts.count where x <= pts[i].x {
            let a = pts[i - 1], b = pts[i]
            return a.y + (b.y - a.y) * (x - a.x) / max(b.x - a.x, 0.001)
        }
        return last.y
    }

    var heads: [CGFloat] { nodes.map(\.x) }
    func lineY(_ x: CGFloat) -> CGFloat { Self.lineY(x, base: coastBase, heads: heads, harbour: harbourX) }
}

struct RouteView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    private var c: Bool { info.isCompact }

    var body: some View {
        let reached = store.data.routeReached
        let edge = max(info.insets.leading, info.insets.trailing)
        let fold: ClosedRange<CGFloat>? = info.hasFold ? 447...503 : nil
        let layout = RouteLayout.make(viewWidth: info.size.width, compact: c, routeReached: reached,
                                      best: store.data.bestMeters, edge: edge, fold: fold)
        ZStack(alignment: .topLeading) {
            SwoopTheme.backdrop
                .frame(width: info.size.width, height: info.size.height)
            RouteMap(layout: layout, routeReached: reached, best: store.data.bestMeters, compact: c,
                     viewWidth: info.size.width)
                .frame(width: info.size.width, height: info.size.height)
            // ART §4 header: back at the top-left, "Route" beside it.
            HStack(spacing: 12) {
                SwoopIconButton(systemName: "chevron.left", compact: c, label: "Back") { controller.goHome() }
                Text("Route")
                    .font(SwoopType.title(c))
                    .foregroundStyle(SwoopTheme.foam)
                    .swoopLegible()
            }
            .fixedSize()
            .position(x: edge + (c ? 86 : 96), y: info.top + 32)
            bottomBar(reached: reached, pinShown: layout.bestLabelRect != nil)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    /// "Next: Kestrel Head · 15 km" and Fly (Best only when the pin's label couldn't show). Duo: one card per page,
    /// never across the fold; iPhone: one bar.
    @ViewBuilder
    private func bottomBar(reached: Int, pinShown: Bool) -> some View {
        let next = "Next: \(RouteRules.name(reached)) · \(ShareText.target(RouteRules.meters(reached)))"
        let best = store.data.bestMeters > 0 && !pinShown ? "Best \(ShareText.distance(store.data.bestMeters))" : nil
        let h: CGFloat = c ? 64 : 92
        let y = info.bottom - h / 2 - 8
        if info.hasFold {
            let left = info.leftPage.insetBy(dx: 24, dy: 0)
            let right = info.rightPage.insetBy(dx: 24, dy: 0)
            nextCard(next, best: best)
                .frame(width: left.width, height: h)
                .position(x: left.midX, y: y)
            flyCard
                .frame(width: min(right.width, 300), height: h)
                .position(x: right.midX, y: y)
        } else {
            HStack(spacing: 12) {
                nextCard(next, best: best)
                flyCard.frame(width: 140)
            }
            .frame(width: min(info.size.width - 2 * (max(info.insets.leading, info.insets.trailing) + 16), 640),
                   height: h)
            .position(x: info.size.width / 2, y: y)
        }
    }

    private func nextCard(_ next: String, best: String?) -> some View {
        HStack(spacing: 12) {
            LighthouseIcon(state: .next, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(next)
                    .font(SwoopType.headline(c))
                    .foregroundStyle(SwoopTheme.foam)
                    .fixedSize(horizontal: false, vertical: true)
                if let best {
                    Text(best).font(SwoopType.caption(c)).foregroundStyle(SwoopTheme.mist)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SwoopTheme.surface.opacity(0.92)))
        .accessibilityElement(children: .combine)
    }

    private var flyCard: some View {
        SwoopButton(kind: .primary, height: AppCanvas.minTap, compact: c, action: { controller.fly() }) {
            Label("Fly", systemImage: "play.fill").lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SwoopTheme.surface.opacity(0.92)))
    }
}

/// The map (ART §4): dusk headlands, sand rim and foam line along the top, the sea with contours to the bottom, the
/// route line (gold where flown, dashed after), lighthouses on their points, one baseline row of labels.
struct RouteMap: View {
    let layout: RouteLayout
    let routeReached: Int
    let best: Double
    let compact: Bool
    let viewWidth: CGFloat

    var body: some View {
        let L = layout
        GeometryReader { geo in
            let h = geo.size.height
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        chart(height: h)
                        // An anchor at the open offset (content x at the view's left edge).
                        Color.clear.frame(width: 1, height: 1).position(x: L.openOffset + 0.5, y: 0.5).id("open")
                        // The storm behind the harbour at the far left, the quay at the harbour.
                        Path(RouteArt.stormGlyph(size: 40))
                            .fill(SwoopTheme.slate)
                            .overlay(Path(RouteArt.stormRainTicks(size: 40))
                                .stroke(SwoopTheme.mist, style: StrokeStyle(lineWidth: 2, lineCap: .round)))
                            .frame(width: 40, height: 40)
                            .position(x: L.harbourX - 30, y: L.lineY(L.harbourX) - 30)
                        Path(RouteArt.quayGlyph(size: 30))
                            .fill(Color(swoopHex: 0xC9B98F))
                            .frame(width: 30, height: 30)
                            .position(x: L.harbourX, y: L.lineY(L.harbourX))
                        ForEach(L.nodes, id: \.index) { n in
                            LighthouseIcon(state: iconState(n.index), size: n.index == routeReached ? 44 : 30)
                                .position(x: n.iconRect.midX, y: n.iconRect.midY)
                            nodeLabel(n)
                                .frame(width: n.labelRect.width, height: n.labelRect.height, alignment: .top)
                                .position(x: n.labelRect.midX, y: n.labelRect.midY)
                        }
                        Text("and on…")
                            .font(SwoopType.body(compact))
                            .foregroundStyle(SwoopTheme.mist)
                            .frame(width: L.tailRect.width, alignment: .center)
                            .position(x: L.tailRect.midX, y: L.tailRect.midY)
                        if let pin = L.bestPin {
                            YouGlyph(facingLeft: false)
                                .fill(SwoopTheme.foam)
                                .frame(width: 22, height: 14)
                                .position(x: pin.x, y: pin.y - 2)
                            if let r = L.bestLabelRect {
                                Text("Best \(ShareText.distance(best))")
                                    .font(SwoopType.chip(compact))
                                    .foregroundStyle(SwoopTheme.foam)
                                    .padding(.horizontal, 8)
                                    .frame(height: r.height)
                                    .background(Capsule().fill(SwoopTheme.surface.opacity(0.8)))
                                    .fixedSize()
                                    .position(x: r.midX, y: r.midY)
                            }
                        }
                    }
                    .frame(width: L.contentWidth, height: h)
                }
                .scrollDisabled(L.contentWidth <= viewWidth + 0.5)
                .onAppear { proxy.scrollTo("open", anchor: .leading) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route map")
    }

    private func iconState(_ i: Int) -> LighthouseIcon.State {
        switch RouteRules.nodeState(index: i, routeReached: routeReached) {
        case .reached: return .reached
        case .next: return .next
        case .soon, .unknown: return .unreached
        }
    }

    private func nodeLabel(_ n: RouteLayout.Node) -> some View {
        let state = RouteRules.nodeState(index: n.index, routeReached: routeReached)
        return VStack(spacing: 2) {
            Text(RouteRules.name(n.index))
                .font(SwoopType.body(compact).weight(.semibold))
                .foregroundStyle(state == .reached ? SwoopTheme.foam
                                 : (state == .next ? SwoopTheme.rewardGold : Color(swoopHex: 0x7896AB)))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Text(ShareText.target(RouteRules.meters(n.index)))
                if state == .reached { Image(systemName: "checkmark") }
                if state == .next {
                    Text("· Next").foregroundStyle(SwoopTheme.rewardGold)
                }
            }
            .font(SwoopType.caption(compact))
            .foregroundStyle(SwoopTheme.mist)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func chart(height h: CGFloat) -> some View {
        let L = layout
        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(swoopHex: 0x12405C), Color(swoopHex: 0x0B2A40)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            func coastLine(_ offset: CGFloat) -> Path {
                var p = Path()
                var x: CGFloat = 0
                p.move(to: CGPoint(x: 0, y: RouteLayout.coastY(0, base: L.coastBase, heads: L.heads) + offset))
                while x <= size.width {
                    p.addLine(to: CGPoint(x: x, y: RouteLayout.coastY(x, base: L.coastBase, heads: L.heads) + offset))
                    x += 4
                }
                return p
            }
            for off in [CGFloat(30), 60, 100] {
                ctx.stroke(coastLine(off), with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            }
            var land = coastLine(0)
            land.addLine(to: CGPoint(x: size.width, y: 0))
            land.addLine(to: .zero)
            land.closeSubpath()
            ctx.fill(land, with: .linearGradient(Gradient(colors: [Color(swoopHex: 0x3E4466), Color(swoopHex: 0x2A2E4A)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: L.coastBase + 40)))
            ctx.stroke(coastLine(4), with: .color(Color(swoopHex: 0xFFF6E6).opacity(0.4)), lineWidth: 1.5)
            ctx.stroke(coastLine(0), with: .color(Color(swoopHex: 0xC9B98F)), lineWidth: 3)
            // The route: flown solid gold to the last passed lighthouse, dashed after, fading past the last node.
            let reachedX = routeReached > 0 ? L.heads[min(routeReached, L.heads.count) - 1] : L.harbourX
            func route(_ a: CGFloat, _ b: CGFloat) -> Path {
                var p = Path()
                var x = a
                p.move(to: CGPoint(x: a, y: L.lineY(a)))
                while x < b {
                    x = min(x + 8, b)
                    p.addLine(to: CGPoint(x: x, y: L.lineY(x)))
                }
                return p
            }
            let flown = route(L.harbourX, reachedX)
            ctx.stroke(flown, with: .color(SwoopTheme.rewardGold.opacity(0.25)), lineWidth: 6)
            ctx.stroke(flown, with: .color(SwoopTheme.rewardGold), lineWidth: 2.5)
            let lastX = L.heads.last ?? reachedX
            ctx.stroke(route(reachedX, lastX), with: .color(SwoopTheme.mist.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
            var tail = Path()
            tail.move(to: CGPoint(x: lastX, y: L.lineY(lastX)))
            tail.addLine(to: CGPoint(x: lastX + 140, y: L.lineY(lastX)))
            ctx.stroke(tail, with: .linearGradient(Gradient(colors: [SwoopTheme.mist.opacity(0.45), .clear]),
                                                   startPoint: CGPoint(x: lastX, y: 0),
                                                   endPoint: CGPoint(x: lastX + 140, y: 0)),
                       style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
        }
        .frame(width: L.contentWidth, height: h)
    }
}

/// R9 (ART §4, UX §2.2): the Results' 56 pt mini route, LEFT TO RIGHT: the last passed lighthouse (or the start) at the
/// left, the next one at the right, gold to the bird at its true place, dashed after; "Saltlight" and
/// "Kestrel Head · 2.2 km to go" under the ends. Tapping it opens the Route.
struct MiniRouteStrip: View {
    let reachedThisRun: Int
    let meters: Double

    /// The bird's place between the last passed lighthouse (or the start) and the next one, 0…1. Pure; tested.
    nonisolated static func birdFraction(meters: Double, reachedThisRun: Int) -> CGFloat {
        let from = reachedThisRun > 0 ? RouteRules.meters(reachedThisRun - 1) : 0
        let to = RouteRules.meters(reachedThisRun)
        guard to > from, meters.isFinite else { return 0 }
        return CGFloat(min(max((meters - from) / (to - from), 0), 1))
    }

    /// The left and right labels. Pure; tested.
    nonisolated static func labels(meters: Double, reachedThisRun: Int) -> (left: String, right: String) {
        let left = reachedThisRun > 0 ? RouteRules.name(reachedThisRun - 1) : "Start"
        let next = Lighthouses.next(afterMeters: meters)
        return (left, "\(next.name) · \(ShareText.distance(next.metersFurther)) to go")
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let inset: CGFloat = 16
            let x0 = inset
            let x1 = w - inset
            let lineY: CGFloat = 22
            let birdX = x0 + (x1 - x0) * Self.birdFraction(meters: meters, reachedThisRun: reachedThisRun)
            let names = Self.labels(meters: meters, reachedThisRun: reachedThisRun)
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: birdX, y: lineY))
                    p.addLine(to: CGPoint(x: x1, y: lineY))
                }
                .stroke(SwoopTheme.mist.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
                Path { p in
                    p.move(to: CGPoint(x: x0, y: lineY))
                    p.addLine(to: CGPoint(x: birdX, y: lineY))
                }
                .stroke(SwoopTheme.rewardGold, lineWidth: 2.5)
                if reachedThisRun > 0 {
                    LighthouseIcon(state: .reached, size: 24).position(x: x0, y: lineY - 8)
                } else {
                    Path(RouteArt.quayGlyph(size: 20)).fill(Color(swoopHex: 0xC9B98F))
                        .frame(width: 20, height: 20).position(x: x0, y: lineY - 4)
                }
                LighthouseIcon(state: .next, size: 24).position(x: x1, y: lineY - 8)
                YouGlyph(facingLeft: false)
                    .fill(SwoopTheme.foam)
                    .frame(width: 20, height: 13)
                    .position(x: birdX, y: lineY + 2)
                Text(names.left)
                    .font(SwoopType.caption(true))
                    .foregroundStyle(SwoopTheme.mist)
                    .fixedSize()
                    .position(x: x0 + 40, y: lineY + 24)
                Text(names.right)
                    .font(SwoopType.caption(true))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: max(w * 0.55, 60), alignment: .trailing)
                    .position(x: x1 - max(w * 0.55, 60) / 2, y: lineY + 24)
            }
            .frame(width: w, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.labels(meters: meters, reachedThisRun: reachedThisRun).right)
    }
}
