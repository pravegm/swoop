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
                        BookPoseDrawing()
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
                        BookPoseDrawing()
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

    private var copy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isDuo ? "Turn your Duo sideways and hold it like a book" : "Turn your iPhone sideways")
                .font(SwoopTheme.title(28))
                .foregroundStyle(SwoopTheme.foam)
                .fixedSize(horizontal: false, vertical: true)
            Text(isDuo ? "The two halves are your wings. Fold a little to dive, open to soar."
                       : "Press and hold to fold your wings. Let go to soar.")
                .font(SwoopTheme.text(17))
                .foregroundStyle(SwoopTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
            if isDuo {
                SwoopButton(kind: .secondary, height: 58, action: onPlayWithTouch) {
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
                Ellipse()
                    .fill(SwoopTheme.gold.opacity(0.10))
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

/// A seabird seen from the front, wings in a shallow V (pose cards, badges).
struct BirdGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.78))
        p.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.05), control: CGPoint(x: x + w * 0.22, y: y + h * 0.15))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.52), control: CGPoint(x: x + w * 0.26, y: y + h * 0.40))
        p.addQuadCurve(to: CGPoint(x: x + w, y: y + h * 0.05), control: CGPoint(x: x + w * 0.74, y: y + h * 0.40))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.78), control: CGPoint(x: x + w * 0.78, y: y + h * 0.15))
        p.closeSubpath()
        return p
    }
}

// MARK: - Closed / cover display: "Open your wings"

/// The calm card on the cover display (or while the Duo is shut): best distance, today's Daily, "Open your wings".
struct ClosedCard: View {
    @ObservedObject var store: ProgressStore

    private var today: Int { DailySeed.dayNumber(for: Date()) }

    var body: some View {
        ZStack {
            SwoopTheme.abyss.ignoresSafeArea()
            RadialGradient(colors: [SwoopTheme.gold.opacity(0.22), SwoopTheme.abyss.opacity(0)],
                           center: .bottom, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                BirdGlyph()
                    .fill(SwoopTheme.foam)
                    .frame(width: 72, height: 34)
                Text("Open your wings")
                    .font(SwoopTheme.display(32))
                    .foregroundStyle(SwoopTheme.foam)
                    .multilineTextAlignment(.center)
                Text("Hold your Duo like a book to fly.")
                    .font(SwoopTheme.text(16, .bold))
                    .foregroundStyle(SwoopTheme.mist)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    row(icon: "flag.fill", title: "Best flight",
                        value: store.data.bestMeters > 0 ? ShareText.km(store.data.bestMeters) : "—")
                    Rectangle().fill(SwoopTheme.foam.opacity(0.08)).frame(height: 1)
                    row(icon: "calendar", title: "Daily Flight #\(today)", value: dailyValue)
                    if store.data.dailyStreak(today: today) > 1 {
                        Rectangle().fill(SwoopTheme.foam.opacity(0.08)).frame(height: 1)
                        row(icon: "flame.fill", title: "Daily streak", value: "\(store.data.dailyStreak(today: today)) days")
                    }
                }
                .swoopCard(padding: 18, radius: 22)
                .frame(maxWidth: 340)
            }
            .padding(24)
        }
    }

    private var dailyValue: String {
        if let record = store.data.dailyRecord(day: today) { return "Flown · \(ShareText.km(record.meters))" }
        return "Ready"
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SwoopTheme.gold)
                .frame(width: 22)
            Text(title)
                .font(SwoopTheme.text(16, .bold))
                .foregroundStyle(SwoopTheme.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(value)
                .font(SwoopTheme.number(17))
                .foregroundStyle(SwoopTheme.goldLight)
                .lineLimit(1)
        }
    }
}
