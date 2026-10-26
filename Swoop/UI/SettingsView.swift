import SwiftUI

/// Settings: sound and feel and the controls on the left page; progress, about and the privacy text (in-app, no web)
/// on the right page.
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore
    let info: AppCanvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmReset = false
    @State private var showPrivacy = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        SwoopPages(info: info, title: "Settings", onBack: { controller.goHome() }) {
            leftPage
        } right: {
            rightPage
        }
        .alert("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                controller.resetProgress()
                FeedbackDirector.shared.uiConfirm()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your bests, ranks, goals, birds and skies will be erased. Daily Flight results are kept. This can't be undone.")
        }
    }

    private var c: Bool { info.isCompact }

    /// The copy for "Bird on the other side" (UX §3).
    static let mirroredFootnote = "The bird flies on the right half. Try it if you're left-handed, or if one half "
        + "blurs when you fold."

    // UX-A14: CONTROLS first, then SOUND & FEEL.
    private var leftPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "Controls", compact: c)
            VStack(alignment: .leading, spacing: 4) {
                birdSideRow
                divider
                // UX R3 P2-10: a phone without a hinge always plays with touch, so the toggle only shows on a Duo;
                // "Tuck by" shows wherever touch flies the bird.
                if controller.hasHinge {
                    toggleRow("Play with touch", icon: "hand.point.up.left.fill", isOn: $settings.playWithTouch,
                              footnote: "Hold the screen to tuck instead of folding your Duo.")
                    divider
                }
                if Self.showsTuckBy(hasHinge: controller.hasHinge, playWithTouch: settings.playWithTouch) {
                    segmentRow("Tuck by", icon: "hand.tap.fill", options: ["Holding", "Tapping"],
                               selected: settings.tuckByTapping ? 1 : 0,
                               footnote: "Tapping: one tap tucks, the next opens. Made for Switch Control and VoiceOver.") { i in
                        settings.tuckByTapping = i == 1
                        settings.tapOfferAnswered = true
                    }
                    divider
                }
                schoolRow
                divider
                infoRow("Reduce Motion", icon: "figure.walk.motion", value: reduceMotion ? "On" : "Off",
                        footnote: "Follows iOS: no camera shake or screen bloom when on.")
            }
            .swoopCard(padding: 14, radius: SwoopTheme.cardRadius(c))
            PageHeading(text: "Sound & feel", compact: c)
            VStack(alignment: .leading, spacing: 4) {
                toggleRow("Sound", icon: "speaker.wave.2.fill", isOn: $settings.soundOn)
                divider
                segmentRow("Haptics", icon: "waveform", options: AppHapticLevel.allCases.map(\.label),
                           selected: AppHapticLevel.allCases.firstIndex(of: settings.hapticLevel) ?? 1,
                           footnote: controller.hasHinge ? "Strong suits the Duo's gentle taptic engine." : nil) { i in
                    let levels = AppHapticLevel.allCases
                    if levels.indices.contains(i) {
                        settings.hapticLevel = levels[i]
                        FeedbackDirector.shared.uiConfirm()
                    }
                }
                divider
                toggleRow("Respect silent switch", icon: "bell.slash.fill", isOn: $settings.respectSilentSwitch,
                          footnote: "Off: Swoop plays sound even in Silent Mode.")
            }
            .swoopCard(padding: 14, radius: SwoopTheme.cardRadius(c))
            if BuildChannel.isTestBuild {
                // R4 P1-15: the founder's device test. Never in an App Store build.
                PageHeading(text: "Device test", compact: c)
                VStack(alignment: .leading, spacing: 4) {
                    toggleRow("Hinge readout (TestFlight)", icon: "gauge.with.needle", isOn: $settings.hingeReadout,
                              footnote: "Shows the live angle, open angle, tuck, report rate, pose and strokes.")
                }
                .swoopCard(padding: 14, radius: SwoopTheme.cardRadius(c))
            }
        }
    }

    /// R6 D1 (UX §2.3): Bird side, first in Controls (it replaces "Bird on the other side").
    private var birdSideOptions: [BirdSide] { controller.hasHinge ? [.sharp, .left, .right] : [.left, .right] }

    private var birdSideRow: some View {
        let options = birdSideOptions
        let current = controller.hasHinge ? settings.birdSide : (settings.birdSide == .right ? .right : .left)
        return VStack(alignment: .leading, spacing: 4) {
            segmentRow("Bird side", icon: "arrow.left.and.right", options: options.map(\.label),
                       selected: options.firstIndex(of: current) ?? 0,
                       footnote: Self.birdSideFootnote(current, checked: settings.wingCheckDone,
                                                       screenSide: controller.birdScreenSide)) { i in
                if options.indices.contains(i) {
                    settings.birdSide = options[i]
                    controller.refreshLayout()
                }
            }
            if controller.hasHinge && current == .sharp {
                SwoopButton(kind: .quiet, height: 44, compact: c, action: { controller.openWingCheck() }) {
                    Text(settings.wingCheckDone ? "Check again" : "Check now").lineLimit(1)
                }
                .frame(width: 160)
            }
        }
    }

    /// The Bird side footnote (UX §2.3). Pure; tested.
    nonisolated static func birdSideFootnote(_ side: BirdSide, checked: Bool, screenSide: ScreenSide) -> String {
        switch side {
        case .sharp:
            return checked
                ? "Your bird stays on the half that doesn't blur when you fold. Now: \(screenSide.rawValue) half."
                : "Using the usual sharp side (the \(screenSide.rawValue) half, held this way up)."
        case .left: return "The bird always flies on the left half."
        case .right: return "The bird always flies on the right half, flying right to left."
        }
    }

    /// "Flight School · Replay the 45-second lesson" (UX §1.4).
    private var schoolRow: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            controller.show(.school)
        } label: {
            HStack(spacing: 12) {
                rowIcon("graduationcap.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Flight School")
                        .font(SwoopType.body(c).weight(.bold))
                        .foregroundStyle(SwoopTheme.foam)
                    Text("Replay the 45-second lesson")
                        .font(SwoopType.caption(c))
                        .foregroundStyle(SwoopTheme.haze)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(SwoopTheme.mist)
            }
            .frame(minHeight: AppCanvas.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "Tuck by" shows where touch flies the bird: every phone without a hinge, and a Duo set to play with touch.
    /// Pure; tested.
    nonisolated static func showsTuckBy(hasHinge: Bool, playWithTouch: Bool) -> Bool {
        !hasHinge || playWithTouch
    }

    private var rightPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "About")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    BirdGlyph()
                        .fill(SwoopTheme.foam)
                        .frame(width: 30, height: 14)
                    Text(RouteRules.objective)
                        .font(SwoopType.body(c).weight(.heavy))
                        .foregroundStyle(SwoopTheme.foam)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Hold your Duo like a book. Fold a little to tuck and dive down the swells; open to soar off the crests. Outfly the storm. On other iPhones, press and hold to tuck.")
                    .font(SwoopTheme.text(14))
                    .foregroundStyle(SwoopTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every sound is synthesised live. No ads, no in-app purchases, no tracking, no accounts.")
                    .font(SwoopTheme.text(14))
                    .foregroundStyle(SwoopTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Swoop \(version) · made by a tiny studio")
                    .font(SwoopTheme.text(13, .bold))
                    .foregroundStyle(SwoopTheme.haze)
            }
            .swoopCard(padding: 16, radius: SwoopTheme.cardRadius(c))
            PageHeading(text: "Privacy")
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    FeedbackDirector.shared.uiTap()
                    withAnimation(SwoopTheme.settle(reduceMotion)) { showPrivacy.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SwoopTheme.foam)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(SwoopTheme.surfaceRaised))
                        Text("Swoop collects no data")
                            .font(SwoopTheme.text(17, .bold))
                            .foregroundStyle(SwoopTheme.foam)
                        Spacer(minLength: 0)
                        Image(systemName: showPrivacy ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SwoopTheme.mist)
                    }
                    .frame(minHeight: AppCanvas.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showPrivacy {
                    Text(Self.privacyText)
                        .font(SwoopTheme.text(14))
                        .foregroundStyle(SwoopTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .swoopCard(padding: 14, radius: SwoopTheme.cardRadius(c))
            // REVIEW-1 P1-11: progress last, and Reset as a plain destructive row behind its confirmation.
            PageHeading(text: "Progress")
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.progressLine(runs: store.data.runs, rankTitle: GoalCatalog.rankTitle(store.data.rank),
                                       best: store.data.bestMeters, lifetime: store.data.lifetimeMeters))
                    .font(SwoopTheme.text(14, .bold))
                    .foregroundStyle(SwoopTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    FeedbackDirector.shared.uiTap()
                    confirmReset = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SwoopTheme.coral)
                            .frame(width: 32, height: 32)
                        Text("Reset progress")
                            .font(SwoopTheme.text(17, .bold))
                            .foregroundStyle(SwoopTheme.coral)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: AppCanvas.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .swoopCard(padding: 14, radius: SwoopTheme.cardRadius(c))
        }
    }

    /// "No flights yet", else "Crest Hopper · best 6.4 km · 48.3 km flown". Pure; tested.
    nonisolated static func progressLine(runs: Int, rankTitle: String, best: Double, lifetime: Double) -> String {
        if runs <= 0 { return "No flights yet" }
        return "\(rankTitle) · best \(ShareText.distance(best)) · \(ShareText.distance(lifetime)) flown"
    }

    /// The in-app privacy policy (no web link).
    static let privacyText = """
    Swoop doesn't collect, store or share any personal data. There are no accounts, no ads, no analytics and no \
    tracking, and the app never connects to our servers (we don't have any).

    Your progress, bests and settings are saved only on this iPhone.

    If you're signed in to Game Center, your scores and achievements are sent to Apple's Game Center under your \
    Game Center profile, as with any game. You can turn Game Center off in iOS Settings at any time.

    The hinge angle is read only while the app is open, to fly the bird, and never leaves your iPhone.
    """

    private var divider: some View {
        Rectangle().fill(SwoopTheme.foam.opacity(0.08)).frame(height: 1)
    }

    /// ART A6: `surfaceRaised` tiles with foam glyphs (no gold in Settings).
    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SwoopTheme.foam)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(SwoopTheme.surfaceRaised))
    }

    /// A row with a segmented choice ("Tuck by: Holding | Tapping", "Haptics: Off | Normal | Strong").
    private func segmentRow(_ title: String, icon: String, options: [String], selected: Int, footnote: String?,
                            onSelect: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                rowIcon(icon)
                Text(title)
                    .font(SwoopType.body(c).weight(.bold))
                    .foregroundStyle(SwoopTheme.foam)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40)
            SwoopSegmented(options: options, selected: selected, compact: c) { i in
                FeedbackDirector.shared.uiTap()
                onSelect(i)
            }
            .accessibilityLabel(title)
            if let footnote {
                Text(footnote)
                    .font(SwoopType.caption(c))
                    .foregroundStyle(SwoopTheme.haze)
                    .padding(.bottom, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: Binding(get: { isOn.wrappedValue }, set: { newValue in
                FeedbackDirector.shared.uiTap()
                isOn.wrappedValue = newValue
            })) {
                HStack(spacing: 12) {
                    rowIcon(icon)
                    Text(title)
                        .font(SwoopTheme.text(17, .bold))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .tint(SwoopTheme.accentOn)
            .frame(minHeight: AppCanvas.minTap)
            if let footnote {
                Text(footnote)
                    .font(SwoopTheme.text(13))
                    .foregroundStyle(SwoopTheme.haze)
                    .padding(.leading, 44)
                    .padding(.bottom, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func infoRow(_ title: String, icon: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 12) {
                rowIcon(icon)
                Text(title)
                    .font(SwoopTheme.text(17, .bold))
                    .foregroundStyle(SwoopTheme.foam)
                Spacer()
                Text(value)
                    .font(SwoopTheme.text(16, .heavy))
                    .foregroundStyle(SwoopTheme.mist)
            }
            .frame(minHeight: AppCanvas.minTap)
            Text(footnote)
                .font(SwoopTheme.text(13))
                .foregroundStyle(SwoopTheme.haze)
                .padding(.leading, 44)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A segmented choice with 48 pt segments (56 pt tap), `surfaceRaised` with the chosen one in `accentOn`.
struct SwoopSegmented: View {
    let options: [String]
    let selected: Int
    var compact: Bool = false
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { item in
                let on = item.offset == selected
                Button {
                    onSelect(item.offset)
                } label: {
                    Text(item.element)
                        .font(SwoopType.body(compact).weight(on ? .heavy : .semibold))
                        .foregroundStyle(on ? SwoopTheme.ink : SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(true), style: .continuous)
                            .fill(on ? SwoopTheme.accentOn : Color.clear))
                        .frame(minHeight: AppCanvas.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.element)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(true) + 4, style: .continuous)
            .fill(SwoopTheme.surfaceRaised))
        .accessibilityElement(children: .contain)
    }
}