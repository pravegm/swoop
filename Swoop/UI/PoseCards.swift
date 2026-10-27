import SwiftUI

// MARK: - Portrait: "Turn your Duo sideways"

/// Full-screen card for a portrait canvas (Duo tabletop, or a phone held upright before iOS turns the UI): the game
/// holds until the phone is held like a book. On a Duo in tabletop the fold runs across the middle, so the drawing sits
/// on the top half and the words and the button on the bottom half, both clear of the fold.
struct TurnCard: View {
    var insets: EdgeInsets = EdgeInsets()
    let isDuo: Bool
    let onPlayWithTouch: () -> Void

    /// Clear band kept around the middle of a portrait canvas (the Duo's tabletop fold, 40 pt + margins).
    static let foldBand: CGFloat = 80

    var body: some View {
        ZStack {
            // Opaque: the paused scene never shows through.
            SwoopTheme.abyss.ignoresSafeArea()
            LinearGradient(colors: [SwoopTheme.deep, SwoopTheme.abyss], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    // A landscape canvas (demo `screen=pose`, a band): drawing and words side by side, clear of the
                    // middle.
                    let page = max((geo.size.width - Self.foldBand) / 2, 0)
                    HStack(spacing: 0) {
                        poseDrawing
                            .frame(width: min(page * 0.8, 260), height: min(geo.size.height * 0.7, 240))
                            .frame(width: page, height: geo.size.height)
                        Color.clear.frame(width: Self.foldBand)
                        ScrollView(showsIndicators: false) {
                            copy
                                .frame(maxWidth: 420, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 24)
                                .frame(minHeight: geo.size.height)
                        }
                        .frame(width: max(page - insets.trailing, 0), height: geo.size.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    let half = max((geo.size.height - Self.foldBand) / 2, 0)
                    VStack(spacing: 0) {
                        poseDrawing
                            .frame(width: min(geo.size.width * 0.6, 260), height: min(half * 0.8, 240))
                            .frame(maxWidth: .infinity)
                            .frame(height: half)
                            .padding(.top, insets.top * 0.5)
                        Color.clear.frame(height: Self.foldBand)
                        copy
                            .frame(maxWidth: 440)
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity)
                            .frame(height: half, alignment: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// A Duo opening like a book, or (R5, juror / Duo R4) on a regular iPhone a single phone turning sideways.
    @ViewBuilder
    private var poseDrawing: some View {
        if isDuo { BookPoseDrawing() } else { PhoneTurnDrawing() }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isDuo ? "Turn it sideways, like a book" : "Turn your iPhone sideways")
                .font(SwoopType.title(false))
                .foregroundStyle(SwoopTheme.foam)
                .fixedSize(horizontal: false, vertical: true)
            Text(isDuo ? "The two halves are your wings. Fold going down, open going up."
                       : "Hold going down. Let go going up.")
                .font(SwoopType.body(false))
                .foregroundStyle(SwoopTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
            if isDuo {
                SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(false), action: onPlayWithTouch) {
                    Label("Play with touch", systemImage: "hand.point.up.left.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: 320)
                .padding(.top, 6)
            }
        }
    }
}

/// A regular iPhone turning from upright to sideways, a tiny bird gliding across its screen once it lands. On a loop;
/// still under Reduce Motion and in demo captures.
struct PhoneTurnDrawing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var still: Bool { AppTrace.enabled }
    static let loop: Double = 3.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || still)) { context in
            let t = (reduceMotion || still) ? 2.4
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            let turn = 1 - pow(1 - min(max((t - 0.4) / 0.9, 0), 1), 3)
            let glide = min(max((t - 1.5) / 1.6, 0), 1)
            ZStack {
                Circle()
                    .fill(SwoopTheme.poseCircle)
                    .frame(width: 230, height: 230)
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SwoopTheme.foam.opacity(0.9))
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(LinearGradient(colors: [SwoopTheme.slate, SwoopTheme.goldLight, SwoopTheme.gold],
                                             startPoint: .leading, endPoint: .trailing))
                        .padding(5)
                    BirdGlyph()
                        .fill(SwoopTheme.foam)
                        .frame(width: 30, height: 14)
                        .offset(x: CGFloat(-50 + 100 * glide), y: CGFloat(-8 + 6 * sin(t * 4)))
                        .opacity(turn > 0.95 ? 1 : 0)
                }
                .frame(width: 196, height: 96)
                .rotationEffect(.degrees(-90 * (1 - turn)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A Duo seen from the front: it turns from upright to sideways, then opens a little like a book (two halves in a
/// shallow V) while a tiny bird glides across. On a loop; still under Reduce Motion and in demo captures.
struct BookPoseDrawing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Demo captures hold the clearest moment (turned and opened).
    private var still: Bool { AppTrace.enabled }

    static let loop: Double = 4.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || still)) { context in
            let t = (reduceMotion || still) ? 2.6
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            let turn = Self.ease(min(max((t - 0.3) / 0.9, 0), 1))       // 0 upright → 1 sideways
            let openIn = Self.ease(min(max((t - 1.5) / 0.7, 0), 1))
            let openOut = Self.ease(min(max((t - 3.6) / 0.6, 0), 1))
            let open = openIn * (1 - openOut)                             // the book's V
            ZStack {
                Circle()
                    .fill(SwoopTheme.poseCircle)
                    .frame(width: 230, height: 230)
                HStack(spacing: 2) {
                    half(left: true)
                        .rotation3DEffect(.degrees(26 * open), axis: (x: 0, y: 1, z: 0), anchor: .trailing,
                                          perspective: 0.5)
                    half(left: false)
                        .rotation3DEffect(.degrees(-26 * open), axis: (x: 0, y: 1, z: 0), anchor: .leading,
                                          perspective: 0.5)
                }
                .frame(width: 186, height: 132)
                .rotationEffect(.degrees(-90 * (1 - turn)))
                BirdGlyph()
                    .fill(SwoopTheme.foam)
                    .frame(width: 34, height: 16)
                    .offset(x: CGFloat(-60 + 120 * open), y: CGFloat(-90 + 12 * sin(t * 3)))
                    .opacity(open)
            }
        }
        .accessibilityHidden(true)
    }

    private static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    private func half(left: Bool) -> some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: left ? 18 : 3, bottomLeadingRadius: left ? 18 : 3,
                                   bottomTrailingRadius: left ? 3 : 18, topTrailingRadius: left ? 3 : 18,
                                   style: .continuous)
                .fill(SwoopTheme.foam.opacity(0.9))
            UnevenRoundedRectangle(topLeadingRadius: left ? 13 : 2, bottomLeadingRadius: left ? 13 : 2,
                                   bottomTrailingRadius: left ? 2 : 13, topTrailingRadius: left ? 2 : 13,
                                   style: .continuous)
                .fill(LinearGradient(colors: left ? [SwoopTheme.slate, SwoopTheme.sea]
                                                  : [SwoopTheme.goldLight, SwoopTheme.gold],
                                     startPoint: .top, endPoint: .bottom))
                .padding(5)
        }
        .frame(width: 92, height: 132)
    }
}

/// THE bird mark (R4 P0-5, juror R3 #16): Scene's `BirdArt.markPath`, the icon gull's dorsal "M", as a round-capped
/// stroke outline, so `.fill` paints the glyph. Used everywhere outside gameplay (cover, cards, About, the meter knob,
/// the pose card, the touch glyph).
struct BirdGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let mark = Path(BirdArt.markPath(width: rect.width, height: rect.height))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return mark.strokedPath(StrokeStyle(lineWidth: BirdArt.markLineWidth(forHeight: rect.height),
                                            lineCap: .round, lineJoin: .round))
    }
}

// MARK: - The cover display (UX-D1, ART §8)

/// What the cover shows: the results you closed on, the run you paused, or Home.
enum ClosedCardState: Equatable {
    case home
    case midRun(PausedRun)
    case results(ResultSummary)
}

/// The cover display (466 × 678) and the shut Duo: black, a thin horizon strip, the dart bird, then the state's words.
/// Nothing on the cover ever says "—": an unflown best reads "Your first flight is waiting."
struct ClosedCard: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let state: ClosedCardState
    var insets: EdgeInsets = EdgeInsets()

    private var today: Int { DailySeed.dayNumber(for: Date()) }

    /// The dart's width: 150 pt on Home, 96 pt with a paused run or results above the words.
    nonisolated static func dartWidth(_ state: ClosedCardState) -> CGFloat {
        if case .home = state { return 150 }
        return 96
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                // The horizon (juror R3 #17): `#F2A65A` added light at 0.18, 40 pt, at the foot of the card: warm,
                // never the brown of gold at partial alpha over black.
                LinearGradient(colors: [Color(swoopHex: 0xF2A65A).opacity(0), Color(swoopHex: 0xF2A65A).opacity(0.18),
                                        Color(swoopHex: 0xF2A65A).opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .blendMode(.plusLighter)
                    .frame(height: 40)
                    .position(x: geo.size.width / 2, y: geo.size.height - max(insets.bottom, 8) - 20)
                    .allowsHitTesting(false)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        BirdGlyph()
                            .fill(LinearGradient(colors: [SwoopTheme.foam, SwoopTheme.mist], startPoint: .top,
                                                 endPoint: .bottom))
                            .frame(width: Self.dartWidth(state), height: Self.dartWidth(state) * 0.42)
                            .padding(.top, 8)
                            .accessibilityHidden(true)
                        content
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 24)
                    .padding(.top, max(insets.top, 20) + 16)
                    .padding(.bottom, max(insets.bottom, 16) + 16)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .home: homeContent
        case let .midRun(run): pausedContent(run)
        case let .results(summary): resultsContent(summary)
        }
    }

    // MARK: Home

    private var homeContent: some View {
        VStack(spacing: 14) {
            Text("Open your wings")
                .font(SwoopType.title(false))
                .foregroundStyle(SwoopTheme.foam)
                .multilineTextAlignment(.center)
            Text(store.data.runs == 0 ? "Your first flight is waiting." : "Hold your Duo like a book to fly.")
                .font(SwoopType.body(false))
                .foregroundStyle(SwoopTheme.mist)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                if store.data.bestMeters > 0 {
                    row(icon: "flag.fill", title: "Best flight", value: ShareText.distance(store.data.bestMeters))
                    divider
                }
                // FINAL-FIXES #16 (UX-ROUND-9 §4.1): the one name, "Daily Flight · 27 Oct".
                row(icon: "calendar", title: AppRules.dailyTitle(day: today), value: dailyValue)
                if store.data.dailyStreak(today: today) >= 2 {
                    divider
                    row(icon: "flame.fill", title: "Daily streak", value: "\(store.data.dailyStreak(today: today))-day streak")
                }
            }
            .swoopCard(padding: 18, radius: SwoopTheme.cardRadius(true))
            .padding(.top, 4)
        }
    }

    private var dailyValue: String {
        let next = ShareText.nextInShort(seconds: ShareText.secondsToNextDaily(now: Date()))
        if let record = store.data.dailyRecord(day: today) { return "Flown \(ShareText.distance(record.meters)) · next in \(next)" }
        // QA-1 P1-2: a started try is spent even if nothing was filed.
        if store.hasDailyAttempt(day: today) { return "Tried · next in \(next)" }
        return "Ready"
    }

    // MARK: Paused mid-run

    private func pausedContent(_ run: PausedRun) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                // R6 (UX §1.4, §5 Cover): the school's own pause copy; a real run names the next lighthouse.
                SwoopOverline(text: run.inSchool ? "Flight School paused" : "Paused")
                if !run.inSchool {
                    Text(Self.heroDistance(run.meters))
                        .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !run.goalLine.isEmpty {
                        Text(run.goalLine)
                            .font(SwoopType.headline(false))
                            .foregroundStyle(SwoopTheme.rewardGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                Text(run.inSchool ? "Open your wings to carry on." : "Open your wings to keep flying.")
                    .font(SwoopType.body(false))
                    .foregroundStyle(SwoopTheme.mist)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(run.inSchool ? "Flight School paused. Open your wings to carry on."
                                : "Paused at \(ShareText.hudDistance(run.meters).value) "
                                + "\(run.meters < 1000 ? "metres" : "kilometres")"
                                + (run.goalLine.isEmpty ? "" : ", \(run.goalLine)") + ". Open your Duo to keep flying.")
            if !run.inSchool {
            VStack(alignment: .leading, spacing: 10) {
                let storm = Self.stormLine(run.stormMeters)
                HStack(spacing: 8) {
                    Image(systemName: "cloud.bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(storm.close ? SwoopTheme.coral : SwoopTheme.mist)
                    Text(storm.text)
                        .font(SwoopType.caption(false))
                        .foregroundStyle(storm.close ? SwoopTheme.coral : SwoopTheme.foam)
                    Spacer(minLength: 0)
                }
                SwoopProgressBar(value: Self.stormFill(run.stormMeters), height: 6)
                    .overlay(alignment: .leading) {
                        if storm.close {
                            Capsule().fill(SwoopTheme.coral).frame(width: 18, height: 6)
                        }
                    }
                let stats = AppRules.statsLine(perfects: run.perfects, chain: run.chain, lighthouses: 0)
                if !stats.isEmpty {
                    Text(stats)
                        .font(SwoopType.caption(false))
                        .foregroundStyle(SwoopTheme.mist)
                }
                Text(Self.bestLine(meters: run.meters, best: run.bestMeters))
                    .font(SwoopType.caption(false))
                    .foregroundStyle(SwoopTheme.mist)
                if run.isScoredDaily, let day = run.day {
                    Text("\(AppRules.dailyTitle(day: day)) · your one try is paused")
                        .font(SwoopType.caption(false))
                        .foregroundStyle(SwoopTheme.mist)
                }
            }
            .swoopCard(padding: 16, radius: SwoopTheme.cardRadius(true))
            .accessibilityElement(children: .combine)
            }
            SwoopButton(kind: .secondary, height: SwoopTheme.secondaryHeight(false), compact: true,
                        action: { controller.keepFlyingHere() }) {
                Label("Keep flying here", systemImage: "hand.point.up.left.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 4)
            SwoopButton(kind: .quiet, height: 48, compact: true, action: { controller.endFlightHere() }) {
                Text("End flight")
            }
        }
    }

    /// "1.00 km to your best" within 10 % of it, else "Beat 19.60 km to set a best"; "Past your best" beyond it; "No best
    /// yet: this flight sets it" without one (never "—", UX §9; Duo R3 P2-16). Pure; tested.
    nonisolated static func bestLine(meters: Double, best: Double) -> String {
        guard best > 0, best.isFinite else { return "No best yet: this flight sets it" }
        let m = meters.isFinite ? max(meters, 0) : 0
        if m >= best { return "Past your best" }
        if best - m <= best * 0.10 { return "\(ShareText.distance(best - m, roundUp: true)) to your best" }
        return "Beat \(ShareText.distance(best)) to set a best"
    }

    /// The paused hero: "18.57 km" (hundredths, like the HUD) or "842 m". Pure; tested.
    nonisolated static func heroDistance(_ meters: Double) -> String {
        let d = ShareText.hudDistance(meters)
        return "\(d.value) \(d.unit)"
    }

    /// The cover's storm meter: the HUD's own fill (`AppRules.meterLead`), from the gap in metres. Pure; tested.
    nonisolated static func stormFill(_ meters: Double) -> Double {
        guard meters.isFinite else { return 0 }
        return AppRules.meterLead(gap: max(meters, 0) * Tuning.pointsPerMeter)
    }

    /// "Storm 900 m behind" (UX R4 P2-6: a percentage read as jargon, and 32 % as danger), coral under 300 m.
    /// Pure; tested.
    static let stormCoralUnder: Double = 300
    nonisolated static func stormLine(_ meters: Double) -> (text: String, close: Bool) {
        let m = meters.isFinite ? max(meters, 0) : 0
        return ("Storm \(ShareText.distance(m)) behind", m < 300)
    }

    // MARK: Results

    private func resultsContent(_ summary: ResultSummary) -> some View {
        let r = summary.result
        let o = summary.outcome
        let hook = AppRules.hookLine(meters: r.meters, best: o.best, previousBest: o.previousBest,
                                     lighthousesPassed: r.lighthouses, lastLighthouse: r.lastLighthouseName,
                                     seed: r.seed, firstFlight: summary.title == "First flight")
        return VStack(spacing: 12) {
            SwoopOverline(text: summary.dailyDay != nil ? "Daily" : "Flight")
            Text(ShareText.distance(r.meters))
                .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if o.showsNewBest {
                SwoopPill(text: "New best!")
            }
            if let hook {
                Text(hook)
                    .font(SwoopType.body(false))
                    .foregroundStyle(SwoopTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Open to fly again")
                .font(SwoopType.headline(false))
                .foregroundStyle(SwoopTheme.foam)
                .padding(.top, 8)
            ShareLink(item: summary.share) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(SwoopType.body(true))
                    .foregroundStyle(SwoopTheme.foam)
                    .frame(maxWidth: .infinity, minHeight: AppCanvas.minTap)
                    .background(SwoopButtonBackground(kind: .secondary, pressed: false, compact: true)
                                    .frame(height: SwoopTheme.secondaryHeight(true)))
            }
        }
    }

    // MARK: Pieces

    private var divider: some View {
        Rectangle().fill(SwoopTheme.stroke).frame(height: 1)
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SwoopTheme.foam)
                .frame(width: 22)
            Text(title)
                .font(SwoopType.body(false))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(value)
                .font(SwoopType.body(false).monospacedDigit())
                .foregroundStyle(SwoopTheme.mist)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}