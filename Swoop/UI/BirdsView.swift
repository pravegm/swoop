import SwiftUI

/// Birds: the chosen bird over its sky, then the skies, on the left page; every bird and every trail colour on the right
/// page. Locked ones are silhouetted or dimmed with "Rank N". All birds fly the same (GAME-DESIGN §8): the choice is looks
/// and a little personality. REVIEW-1 P1-10: each bird tile shows the chosen sky behind it (dark birds read), the
/// preview is smaller, and the skies fill the left page's empty lower half on the Duo.
struct BirdsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The bird shown in the preview (a locked one can be previewed, not chosen).
    @State private var previewBird: BirdID?

    private var shownBird: Bird { BirdCatalog.bird(previewBird ?? store.activeBird) }
    private var shownSky: Sky { SkyCatalog.sky(store.activeSky) }
    private var c: Bool { info.isCompact }

    /// The tile bird's height; the preview is at most 3 × it (ART A8).
    static let tileBirdHeight: CGFloat = 42
    static let previewCap: CGFloat = 3
    /// Locked tiles dim to this (UX §3: a lock, no rank, except the next unlock).
    static let lockedOpacity: Double = 0.35

    /// Only the NEXT unlock names its rank (UX-A11): the smallest unlock rank above the current one. Pure; tested.
    nonisolated static func nextUnlockRank(_ ranks: [Int], current: Int) -> Int? {
        ranks.filter { $0 > current }.min()
    }

    /// A locked tile's label: "Rank 3" for the next unlock, nil (a lock only) for the rest. Pure; tested.
    nonisolated static func lockedLabel(unlockRank: Int, next: Int?) -> String? {
        unlockRank == next ? "Rank \(unlockRank + 1)" : nil
    }

    var body: some View {
        SwoopPages(info: info, title: "Birds", onBack: { controller.goHome() }) {
            leftPage
        } right: {
            rightPage
        }
    }

    // MARK: Left: the preview and the skies

    private var leftPage: some View {
        let bird = shownBird
        let locked = !store.isUnlocked(bird)
        let trail = store.activeTrail
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                SkySwatch(sky: shownSky)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let flap = reduceMotion ? 0 : (t * 0.9).truncatingRemainder(dividingBy: 1)
                    let tuck = reduceMotion ? 0.3 : 0.3 + 0.12 * sin(t * 1.1)
                    ZStack {
                        // The chosen trail behind the bird.
                        Capsule()
                            .fill(LinearGradient(colors: [Color(swoopRGBA: trail?.color ?? bird.trail).opacity(0),
                                                          Color(swoopRGBA: trail?.color ?? bird.trail).opacity(0.85)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 130, height: 6)
                            .offset(x: -70, y: 6)
                            .opacity(locked ? 0 : 1)
                        // ART A8 at tuck 0.3, capped so the spread wing never clips (juror R3 #19), with a pale key
                        // halo so dark birds (the Storm Petrel) read on any sky.
                        BirdSideView(bird: bird, tuck: tuck, flap: flap, silhouette: locked, fill: 0.68)
                            .shadow(color: Color(swoopHex: 0xDDE6FF).opacity(locked ? 0 : 0.55), radius: 10)
                    }
                    .offset(y: reduceMotion ? 0 : CGFloat(5 * sin(t * 1.7)))
                }
            }
            .frame(height: min(c ? 96 : 150, Self.tileBirdHeight * Self.previewCap))
            .clipShape(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
                .stroke(SwoopTheme.stroke, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(bird.name)
                    .font(SwoopType.title(c))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                Text(locked ? "Reach rank \(bird.unlockRank + 1) · \(GoalCatalog.rankTitle(bird.unlockRank))" : bird.blurb)
                    .font(SwoopType.body(c))
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every bird flies the same.")
                    .font(SwoopType.caption(c))
                    .foregroundStyle(SwoopTheme.haze)
            }
            .padding(.horizontal, 4)
            // UX R3 P2-9: the skies row comes before "Fly as", so it shows without scrolling at 402 pt.
            PageHeading(text: "Skies", compact: c)
            HStack(spacing: 6) {
                ForEach(SkyCatalog.all, id: \.id) { sky in
                    skyTile(sky)
                }
            }
            if !locked {
                SwoopButton(kind: .primary, height: AppCanvas.minTap, compact: c,
                            action: { controller.fly(as: bird.id) }) {
                    Label("Fly as \(bird.name)", systemImage: "play.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    // MARK: Right: birds and trails

    private var rightPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "Birds", compact: c)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(BirdCatalog.all, id: \.id) { bird in
                    birdTile(bird)
                }
            }
            let trails = ProgressRules.trailOptions()
            if trails.count > 1 {
                PageHeading(text: "Trails", compact: c)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(trails, id: \.id) { trail in
                        trailTile(trail)
                    }
                }
            }
        }
    }

    private func birdTile(_ bird: Bird) -> some View {
        let unlocked = store.isUnlocked(bird)
        let chosen = store.activeBird == bird.id
        let label = Self.lockedLabel(unlockRank: bird.unlockRank,
                                     next: Self.nextUnlockRank(BirdCatalog.all.map { $0.unlockRank }, current: store.data.rank))
        let shape = RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
        return Button {
            FeedbackDirector.shared.uiTap()
            previewBird = bird.id
            if unlocked { controller.chooseBird(bird.id) }
        } label: {
            VStack(spacing: 2) {
                BirdSideView(bird: bird, tuck: 0.15, flap: 0, silhouette: !unlocked, fill: 0.86)
                    .frame(height: Self.tileBirdHeight)
                    .opacity(unlocked ? 1 : Self.lockedOpacity)
                tileLabel(unlocked ? bird.name : label, locked: !unlocked)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                SkySwatch(sky: shownSky)
                    .opacity(unlocked ? 0.95 : Self.lockedOpacity)
                    .clipShape(shape)
            )
            .overlay(shape.stroke(chosen ? SwoopTheme.gold : SwoopTheme.foam.opacity(previewBird == bird.id ? 0.5 : 0.09),
                                  lineWidth: chosen ? 3 : 1))
            .contentShape(shape)
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(unlocked ? "\(bird.name)\(chosen ? ", chosen" : "")"
                                     : "\(bird.name), locked until rank \(bird.unlockRank + 1)")
    }

    private func skyTile(_ sky: Sky) -> some View {
        let unlocked = store.isUnlocked(sky)
        let chosen = store.activeSky == sky.id
        let label = Self.lockedLabel(unlockRank: sky.unlockRank,
                                     next: Self.nextUnlockRank(SkyCatalog.all.map { $0.unlockRank }, current: store.data.rank))
        return Button {
            FeedbackDirector.shared.uiTap()
            if unlocked { controller.chooseSky(sky.id) }
        } label: {
            ZStack(alignment: .bottomLeading) {
                SkySwatch(sky: sky)
                    .opacity(unlocked ? 1 : Self.lockedOpacity)
                tileLabel(unlocked ? nil : label, locked: !unlocked)
                    .padding(4)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .clipShape(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
                .stroke(chosen ? SwoopTheme.gold : SwoopTheme.foam.opacity(0.09), lineWidth: chosen ? 3 : 1))
            .contentShape(RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous))
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(unlocked ? "\(sky.name) sky\(chosen ? ", chosen" : "")"
                                     : "\(sky.name) sky, locked until rank \(sky.unlockRank + 1)")
    }

    private func trailTile(_ trail: AppTrail) -> some View {
        let unlocked = trail.unlockRank <= store.data.rank
        let chosen = (store.activeTrail?.id ?? TrailID.natural.rawValue) == trail.id
        let color = trail.color ?? shownBird.trail
        let label = Self.lockedLabel(unlockRank: trail.unlockRank,
                                     next: Self.nextUnlockRank(ProgressRules.trailOptions().map { $0.unlockRank },
                                                               current: store.data.rank))
        let shape = RoundedRectangle(cornerRadius: SwoopTheme.tileRadius(c), style: .continuous)
        return Button {
            FeedbackDirector.shared.uiTap()
            if unlocked { controller.chooseTrail(trail.id) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(swoopRGBA: color).opacity(0.15),
                                                  Color(swoopRGBA: color)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                    .shadow(color: Color(swoopRGBA: color).opacity(unlocked ? 0.7 : 0), radius: 5)
                tileLabel(unlocked ? trail.name : label, locked: !unlocked)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(shape.fill(SwoopTheme.surfaceRaised))
            .overlay(shape.stroke(chosen ? SwoopTheme.gold : SwoopTheme.stroke, lineWidth: chosen ? 3 : 1))
            .opacity(unlocked ? 1 : 0.6)
            .contentShape(shape)
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(unlocked ? "\(trail.name) trail\(chosen ? ", chosen" : "")"
                                     : "\(trail.name) trail, locked until rank \(trail.unlockRank + 1)")
    }

    /// A tile's caption: the name, or a lock (with "Rank N" only for the next unlock). 13 pt at least (UX-A11).
    @ViewBuilder
    private func tileLabel(_ text: String?, locked: Bool) -> some View {
        HStack(spacing: 4) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            if let text {
                Text(text)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .foregroundStyle(locked ? SwoopTheme.mist : SwoopTheme.foam)
        .swoopLegible()
    }
}

/// A sky's colours as a small scene: zenith → horizon, the sun at (72 %, 30 %) (ART A8), a band of sea.
struct SkySwatch: View {
    let sky: Sky

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(swoopRGBA: sky.zenith), Color(swoopRGBA: sky.horizon)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(Color(swoopRGBA: sky.sun))
                    .frame(width: h * 0.24, height: h * 0.24)
                    .shadow(color: Color(swoopRGBA: sky.sun).opacity(0.8), radius: h * 0.12)
                    .position(x: w * 0.80, y: h * 0.22)
                LinearGradient(colors: [Color(swoopRGBA: sky.seaFar), Color(swoopRGBA: sky.seaNear)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: h * 0.3)
            }
        }
    }
}
