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

    private var leftPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "Sound & feel")
            VStack(alignment: .leading, spacing: 4) {
                toggleRow("Sound", icon: "speaker.wave.2.fill", isOn: $settings.soundOn)
                divider
                toggleRow("Haptics", icon: "hand.tap.fill", isOn: $settings.hapticsOn)
                divider
                toggleRow("Respect silent switch", icon: "bell.slash.fill", isOn: $settings.respectSilentSwitch,
                          footnote: "Off: Swoop plays sound even in Silent Mode.")
            }
            .swoopCard(padding: 14, radius: 22)
            PageHeading(text: "Controls")
            VStack(alignment: .leading, spacing: 4) {
                toggleRow("Play with touch", icon: "hand.point.up.left.fill", isOn: $settings.playWithTouch,
                          footnote: controller.hasHinge
                            ? "Hold the screen to tuck instead of folding your Duo."
                            : "On iPhones without a fold you always play with touch.")
                divider
                toggleRow("Bird on the other side", icon: "arrow.left.and.right", isOn: $settings.mirrored,
                          footnote: "Fly right to left, with the bird on the right half.")
                divider
                infoRow("Reduce Motion", icon: "figure.walk.motion", value: reduceMotion ? "On" : "Off",
                        footnote: "Follows iOS: no camera shake or screen bloom when on.")
            }
            .swoopCard(padding: 14, radius: 22)
        }
    }

    private var rightPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeading(text: "About")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    BirdGlyph()
                        .fill(SwoopTheme.gold)
                        .frame(width: 30, height: 14)
                    Text("Made for iPhone Duo: the two halves are your wings.")
                        .font(SwoopTheme.text(16, .heavy))
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
            .swoopCard(padding: 16, radius: 22)
            PageHeading(text: "Privacy")
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    FeedbackDirector.shared.uiTap()
                    withAnimation(SwoopTheme.settle(reduceMotion)) { showPrivacy.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SwoopTheme.ink)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(SwoopTheme.gold))
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
            .swoopCard(padding: 14, radius: 22)
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
            .swoopCard(padding: 14, radius: 22)
        }
    }

    /// "No flights yet", else "Crest Hopper · best 6.4 km · 48.3 km flown". Pure; tested.
    nonisolated static func progressLine(runs: Int, rankTitle: String, best: Double, lifetime: Double) -> String {
        if runs <= 0 { return "No flights yet" }
        return "\(rankTitle) · best \(ShareText.km(best)) · \(ShareText.km(lifetime)) flown"
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

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SwoopTheme.ink)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(SwoopTheme.gold))
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
            .tint(SwoopTheme.goldDeep)
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
