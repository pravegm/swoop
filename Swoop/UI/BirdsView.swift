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
                    let tuck = reduceMotion ? 0.2 : 0.25 + 0.25 * sin(t * 1.1)
                    ZStack {
                        // The chosen trail behind the bird.
                        Capsule()
                            .fill(LinearGradient(colors: [Color(swoopRGBA: trail?.color ?? bird.trail).opacity(0),
                                                          Color(swoopRGBA: trail?.color ?? bird.trail).opacity(0.85)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 130, height: 6)
                            .offset(x: -70, y: 6)
                            .opacity(locked ? 0 : 1)
                        BirdSideView(bird: bird, tuck: tuck, flap: flap, silhouette: locked, fill: 0.5)
                    }
                    .offset(y: reduceMotion ? 0 : CGFloat(5 * sin(t * 1.7)))
                }
            }
            .frame(height: info.isCompact ? 120 : 170)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SwoopTheme.gold.opacity(0.3), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(bird.name)
                    .font(SwoopTheme.display(info.isCompact ? 24 : 30))
                    .foregroundStyle(SwoopTheme.foam)
                Text(locked ? "Reach rank \(bird.unlockRank + 1) · \(GoalCatalog.rankTitle(bird.unlockRank))" : bird.blurb)
                    .font(SwoopTheme.text(15, .bold))
                    .foregroundStyle(locked ? SwoopTheme.gold : SwoopTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every bird flies the same. Pick the one you love.")
                    .font(SwoopTheme.text(13, .semibold))
                    .foregroundStyle(SwoopTheme.haze)
            }
            .padding(.horizontal, 4)
            PageHeading(text: "Skies")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(SkyCatalog.all, id: \.id) { sky in
                    skyTile(sky)
                }
            }
        }
    }

    // MARK: Right: birds and trails

    private var rightPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "Birds")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(BirdCatalog.all, id: \.id) { bird in
                    birdTile(bird)
                }
            }
            let trails = ProgressRules.trailOptions()
            if trails.count > 1 {
                PageHeading(text: "Trails")
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
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            FeedbackDirector.shared.uiTap()
            previewBird = bird.id
            if unlocked { controller.chooseBird(bird.id) }
        } label: {
            VStack(spacing: 2) {
                BirdSideView(bird: bird, tuck: 0.15, flap: 0, silhouette: !unlocked, fill: 0.86)
                    .frame(height: 42)
                Text(unlocked ? bird.name : "Rank \(bird.unlockRank + 1)")
                    .font(SwoopTheme.text(11, .heavy))
                    .foregroundStyle(unlocked ? SwoopTheme.foam : SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .swoopLegible()
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                SkySwatch(sky: shownSky)
                    .opacity(unlocked ? 0.95 : 0.4)
                    .clipShape(shape)
            )
            .overlay(shape.stroke(chosen ? SwoopTheme.gold : SwoopTheme.foam.opacity(previewBird == bird.id ? 0.5 : 0.12),
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
        return Button {
            FeedbackDirector.shared.uiTap()
            if unlocked { controller.chooseSky(sky.id) }
        } label: {
            ZStack(alignment: .bottomLeading) {
                SkySwatch(sky: sky)
                    .opacity(unlocked ? 1 : 0.35)
                HStack(spacing: 4) {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(unlocked ? sky.name : "Rank \(sky.unlockRank + 1)")
                        .font(SwoopTheme.text(11, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(SwoopTheme.foam)
                .swoopLegible()
                .padding(6)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(chosen ? SwoopTheme.gold : SwoopTheme.foam.opacity(0.12), lineWidth: chosen ? 3 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(unlocked ? "\(sky.name) sky\(chosen ? ", chosen" : "")"
                                     : "\(sky.name) sky, locked until rank \(sky.unlockRank + 1)")
    }

    private func trailTile(_ trail: AppTrail) -> some View {
        let unlocked = trail.unlockRank <= store.data.rank
        let chosen = (store.activeTrail?.id ?? TrailID.natural.rawValue) == trail.id
        let color = trail.color ?? shownBird.trail
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                HStack(spacing: 4) {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(unlocked ? trail.name : "Rank \(trail.unlockRank + 1)")
                        .font(SwoopTheme.text(11, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(unlocked ? SwoopTheme.foam : SwoopTheme.haze)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(shape.fill(chosen ? SwoopTheme.tide.opacity(0.8) : SwoopTheme.deep.opacity(0.7)))
            .overlay(shape.stroke(chosen ? SwoopTheme.gold : SwoopTheme.foam.opacity(0.12), lineWidth: chosen ? 3 : 1))
            .opacity(unlocked ? 1 : 0.55)
            .contentShape(shape)
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(unlocked ? "\(trail.name) trail\(chosen ? ", chosen" : "")"
                                     : "\(trail.name) trail, locked until rank \(trail.unlockRank + 1)")
    }
}

/// A sky's colours as a small scene: zenith → horizon, the sun, a band of sea.
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
                    .frame(width: h * 0.34, height: h * 0.34)
                    .shadow(color: Color(swoopRGBA: sky.sun).opacity(0.8), radius: h * 0.12)
                    .position(x: w * 0.68, y: h * 0.62)
                LinearGradient(colors: [Color(swoopRGBA: sky.seaFar), Color(swoopRGBA: sky.seaNear)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: h * 0.3)
            }
        }
    }
}
