import SwiftUI

/// R6 D3 (UX §4.4, ART §5 AP7): the Route. A sea chart strip of the lighthouses in the flight direction from the harbour
/// (where the storm comes from), what you've reached, the next one, your best; the summary and Fly on the bird page.
struct RouteView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    private var c: Bool { info.isCompact }

    var body: some View {
        let bp = info.birdPage
        let reached = store.data.routeReached
        let mapTop = info.top + (c ? 54 : 84)
        let summaryH: CGFloat = c ? 64 : 150
        let mapH = max(info.bottom - mapTop - summaryH - 16, 120)
        ZStack(alignment: .topLeading) {
            SwoopTheme.backdrop
                .frame(width: info.size.width, height: info.size.height)
            HStack(spacing: 12) {
                SwoopIconButton(systemName: "chevron.left", compact: c, label: "Back") { controller.goHome() }
                Text("Route")
                    .font(SwoopType.title(c))
                    .foregroundStyle(SwoopTheme.foam)
                Spacer(minLength: 0)
            }
            .frame(width: bp.width)
            .position(x: bp.midX, y: info.top + 28)
            RouteStrip(routeReached: reached, best: store.data.bestMeters, mirrored: info.mirrored, compact: c,
                       focusX: info.farPage.midX / max(info.size.width, 1))
                .frame(width: info.size.width, height: mapH)
                .position(x: info.size.width / 2, y: mapTop + mapH / 2)
            summary(reached: reached)
                .frame(width: min(bp.width, 440))
                .position(x: bp.midX, y: info.bottom - summaryH / 2)
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }

    private func summary(reached: Int) -> some View {
        // R7 P0-4: a phone's 64 pt summary holds two lines (four were cut to "1 lighthouse r…").
        let all = RouteRules.summary(routeReached: reached, best: store.data.bestMeters)
        let lines = c ? [all.first, all.first(where: { $0.hasPrefix("Next") })].compactMap { $0 } : all
        return HStack(spacing: 14) {
            LighthouseIcon(state: .next, size: c ? 26 : 30)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(item.offset == 0 ? SwoopType.headline(c) : SwoopType.caption(c))
                        .foregroundStyle(item.offset == 0 ? SwoopTheme.foam : SwoopTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            SwoopButton(kind: .primary, height: AppCanvas.minTap, compact: c, action: { controller.fly() }) {
                Label("Fly", systemImage: "play.fill").lineLimit(1)
            }
            .frame(width: 112)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: SwoopTheme.cardRadius(c), style: .continuous)
            .fill(SwoopTheme.surface.opacity(0.9)))
        .accessibilityElement(children: .contain)
    }
}

/// The strip: a coast along the top, the sea below, lighthouses on headlands at equal spacing by index, the route line
/// (gold where flown, dashed after), your best as a pin, the harbour and the storm at the start.
struct RouteStrip: View {
    let routeReached: Int
    let best: Double
    let mirrored: Bool
    let compact: Bool
    /// Where on screen (0…1 of the width) the next lighthouse is centred on open: the sea page's middle.
    var focusX: CGFloat = 0.25

    /// Equal spacing by index (ART §5), and the nodes shown: the reached ones, the next, then three more.
    nonisolated static func spacing(_ c: Bool) -> CGFloat { c ? 130 : 150 }
    nonisolated static func nodeCount(routeReached: Int) -> Int { max(routeReached, 0) + 4 }

    /// Node i's x along a strip `width` wide, from the harbour end in the flight direction. Pure; tested.
    nonisolated static func nodeX(_ i: Int, width: CGFloat, spacing: CGFloat, mirrored: Bool) -> CGFloat {
        let fromStart = 110 + CGFloat(i) * spacing
        return mirrored ? width - fromStart : fromStart
    }

    /// The best pin's x: interpolated by metres between the lighthouses either side. Pure; tested.
    nonisolated static func bestX(best: Double, width: CGFloat, spacing: CGFloat, mirrored: Bool) -> CGFloat? {
        guard best > 0, best.isFinite else { return nil }
        let n = RouteRules.reached(within: best)
        let before = n == 0 ? 0 : RouteRules.meters(n - 1)
        let after = RouteRules.meters(n)
        let f = after > before ? (best - before) / (after - before) : 0
        let startX = n == 0 ? (mirrored ? width - 40 : 40) : nodeX(n - 1, width: width, spacing: spacing, mirrored: mirrored)
        let endX = nodeX(n, width: width, spacing: spacing, mirrored: mirrored)
        return startX + (endX - startX) * CGFloat(min(max(f, 0), 1))
    }

    var body: some View {
        let count = Self.nodeCount(routeReached: routeReached)
        let s = Self.spacing(compact)
        let width = 110 + CGFloat(count) * s + 140
        let heads = (0..<count).map { Self.nodeX($0, width: width, spacing: s, mirrored: mirrored) }
        let startX: CGFloat = mirrored ? width - 44 : 44
        let route = RouteArt.routePoints(headlands: heads)
        let routeY = route.first?.y ?? (RouteArt.coastBase + RouteArt.routeDrop)
        GeometryReader { geo in
            let h = geo.size.height
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        chart(width: width, height: h, heads: heads, startX: startX)
                        ForEach(0..<count, id: \.self) { i in
                            let tip = RouteArt.headlandTip(x: heads[i], headlands: heads)
                            let size: CGFloat = RouteRules.nodeState(index: i, routeReached: routeReached) == .next ? 44 : 30
                            LighthouseIcon(state: iconState(i), size: size)
                                .position(x: tip.x, y: tip.y - size * 0.5 + 4)
                                .id(i)
                            nodeLabels(i)
                                .position(x: tip.x, y: RouteArt.routePoint(at: tip.x, headlands: heads).y + 30)
                        }
                        if let bx = Self.bestX(best: best, width: width, spacing: s, mirrored: mirrored) {
                            let pin = RouteArt.routePoint(at: bx, headlands: heads)
                            YouGlyph(facingLeft: mirrored)
                                .fill(SwoopTheme.foam)
                                .frame(width: 24, height: 15)
                                .position(x: pin.x, y: pin.y - 2)
                            Text("Best \(ShareText.distance(best))")
                                .font(SwoopType.chip(compact))
                                .foregroundStyle(SwoopTheme.foam)
                                .swoopChip(compact)
                                .fixedSize()
                                .position(x: pin.x, y: pin.y + 70)
                        }
                        // The harbour (the quay) with the storm over it: where every flight starts.
                        Path(RouteArt.stormGlyph(size: 40))
                            .fill(SwoopTheme.slate)
                            .overlay(Path(RouteArt.stormRainTicks(size: 40))
                                .stroke(SwoopTheme.mist, style: StrokeStyle(lineWidth: 2, lineCap: .round)))
                            .frame(width: 40, height: 40)
                            .position(x: startX, y: routeY - 34)
                        Path(RouteArt.quayGlyph(size: 30))
                            .fill(Color(swoopHex: 0xC9B98F))
                            .frame(width: 30, height: 30)
                            .position(x: startX, y: routeY)
                        Text("Start").font(SwoopType.caption(compact)).foregroundStyle(SwoopTheme.mist)
                            .fixedSize()
                            .position(x: startX, y: routeY + 30)
                        Text("…and on, as far as you can fly.")
                            .font(SwoopType.caption(compact))
                            .foregroundStyle(SwoopTheme.haze)
                            .fixedSize()
                            .position(x: Self.nodeX(count, width: width, spacing: s, mirrored: mirrored)
                                        + (mirrored ? 30 : -30), y: routeY + 30)
                    }
                    .frame(width: width, height: h)
                }
                .onAppear {
                    proxy.scrollTo(min(routeReached, count - 1), anchor: UnitPoint(x: focusX, y: 0.5))
                }
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

    /// Scene's AP7 chart (`RouteArt`): the land with a headland under each lighthouse, the cliff rim and foam line, the
    /// depth contours, then the route (gold where flown, dashed after).
    private func chart(width: CGFloat, height h: CGFloat, heads: [CGFloat], startX: CGFloat) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(swoopHex: 0x12405C), Color(swoopHex: 0x0B2A40)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            for contour in RouteArt.contours(width: width, headlands: heads) {
                ctx.stroke(Path(contour), with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            }
            ctx.fill(Path(RouteArt.coastPath(width: width, headlands: heads)), with: .linearGradient(
                Gradient(colors: [Color(swoopHex: 0x34544A), Color(swoopHex: 0x26403A)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: RouteArt.coastBase + RouteArt.headlandBulge)))
            ctx.stroke(Path(RouteArt.coastline(width: width, headlands: heads, offset: 4)),
                       with: .color(SwoopTheme.foam.opacity(0.5)), lineWidth: 1.5)
            ctx.stroke(Path(RouteArt.coastline(width: width, headlands: heads)),
                       with: .color(Color(swoopHex: 0xC9B98F)), lineWidth: 3)
            let reachedX = routeReached > 0 ? heads[min(routeReached, heads.count) - 1] : startX
            let endX = heads.last ?? startX
            let flown = Path(RouteArt.routePath(headlands: heads, from: startX, to: reachedX))
            ctx.stroke(flown, with: .color(SwoopTheme.rewardGold.opacity(0.25)), lineWidth: 6)
            ctx.stroke(flown, with: .color(SwoopTheme.rewardGold), lineWidth: 2.5)
            ctx.stroke(Path(RouteArt.routePath(headlands: heads, from: reachedX, to: endX)),
                       with: .color(SwoopTheme.mist.opacity(0.45)), style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
        }
        .frame(width: width, height: h)
    }

    private func nodeLabels(_ i: Int) -> some View {
        let state = RouteRules.nodeState(index: i, routeReached: routeReached)
        return VStack(spacing: 2) {
            Text(RouteRules.nodeLabel(index: i, routeReached: routeReached))
                .font(SwoopType.body(compact).weight(.semibold))
                .foregroundStyle(state == .reached ? SwoopTheme.foam : (state == .next ? SwoopTheme.rewardGold : SwoopTheme.haze))
                .lineLimit(1)
                .fixedSize()
            HStack(spacing: 4) {
                Text(ShareText.target(RouteRules.meters(i)))
                if state == .reached { Image(systemName: "checkmark") }
                if state == .next { Text("Next").font(SwoopType.chip(compact)).foregroundStyle(SwoopTheme.ink)
                    .padding(.horizontal, 6).background(Capsule().fill(SwoopTheme.rewardGold)) }
            }
            .font(SwoopType.caption(compact))
            .foregroundStyle(SwoopTheme.mist)
        }
        .accessibilityElement(children: .combine)
    }
}
/// R6 (UX §4.6): the Results' 56 pt mini route: this run's line from the start past each lighthouse reached to the bird,
/// the next lighthouse ahead. Duo cards only (the plan drops it on compact cards).
struct MiniRouteStrip: View {
    let reachedThisRun: Int
    let meters: Double
    let mirrored: Bool

    /// The lighthouses shown: those reached this run plus the next (at least two). Pure; tested.
    nonisolated static func shown(reachedThisRun: Int) -> Int { max(reachedThisRun + 1, 2) }

    /// The bird's position (0…1 of the track) by metres between the shown lighthouses. Pure; tested.
    nonisolated static func birdFraction(meters: Double, reachedThisRun: Int) -> CGFloat {
        let n = shown(reachedThisRun: reachedThisRun)
        let last = RouteRules.meters(n - 1)
        guard last > 0, meters.isFinite else { return 0 }
        return CGFloat(min(max(meters / last, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = Self.shown(reachedThisRun: reachedThisRun)
            let last = max(RouteRules.meters(n - 1), 1)
            let inset: CGFloat = 18
            let track = max(w - 2 * inset, 1)
            let x: (CGFloat) -> CGFloat = { f in mirrored ? w - inset - f * track : inset + f * track }
            let lineY = h * 0.62
            let birdX = x(Self.birdFraction(meters: meters, reachedThisRun: reachedThisRun))
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: x(0), y: lineY))
                    p.addLine(to: CGPoint(x: x(1), y: lineY))
                }
                .stroke(SwoopTheme.mist.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
                Path { p in
                    p.move(to: CGPoint(x: x(0), y: lineY))
                    p.addLine(to: CGPoint(x: birdX, y: lineY))
                }
                .stroke(SwoopTheme.rewardGold, lineWidth: 2.5)
                ForEach(0..<n, id: \.self) { i in
                    let f = CGFloat(RouteRules.meters(i) / last)
                    LighthouseIcon(state: i < reachedThisRun ? .reached : .next, size: i < reachedThisRun ? 22 : 26)
                        .position(x: x(f), y: lineY - 16)
                }
                YouGlyph(facingLeft: mirrored)
                    .fill(SwoopTheme.foam)
                    .frame(width: 20, height: 13)
                    .position(x: birdX, y: lineY + 12)
            }
            .frame(width: w, height: h)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reachedThisRun > 0
                            ? "Reached \(reachedThisRun) lighthouse\(reachedThisRun == 1 ? "" : "s") this run"
                            : "Short of the first lighthouse")
    }
}