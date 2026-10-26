import Combine
import Foundation

/// "Haptics: Off | Normal | Strong" (UX §3 Settings, §9 "the weak taptic engine": Strong is the Duo default).
enum AppHapticLevel: String, Codable, CaseIterable, Equatable {
    case off, normal, strong

    var label: String {
        switch self {
        case .off: return "Off"
        case .normal: return "Normal"
        case .strong: return "Strong"
        }
    }

    /// The level when the player hasn't picked one: Strong on a Duo, Normal elsewhere. Pure; tested.
    static func defaultLevel(isDuo: Bool) -> AppHapticLevel { isDuo ? .strong : .normal }
}

/// The player's settings (kept apart from progress so "Reset progress" leaves them alone). Versioned JSON.
struct SettingsData: Codable, Equatable {
    static let currentVersion = 2

    var version = SettingsData.currentVersion
    var soundOn = true
    var hapticsOn = true
    /// The chosen haptic level; nil = the device default (`AppHapticLevel.defaultLevel`).
    var hapticLevel: AppHapticLevel?
    /// Off by default (GAME-DESIGN §7: sound plays on silent, as the founder asked for Squish).
    var respectSilentSwitch = false
    /// iPhone Duo: hold the screen to tuck instead of folding.
    var playWithTouch = false
    /// "Tuck by: Tapping" (UX §10): a tap toggles the tuck, for Switch Control and VoiceOver players.
    var tuckByTapping = false
    /// R3–R5 "Bird on the other side" (the bird on the right half). R6: read only to migrate into `birdSide`.
    var mirrored = false
    /// The one-time "Tap to tuck instead of holding?" offer (Switch Control / VoiceOver) was answered.
    var tapOfferAnswered = false
    /// R4 P1-15: the founder's hinge readout overlay (TestFlight / Debug builds only).
    var hingeReadout = false
    /// R5 P1-7: the player's resting book angle (Feel's calibrated "open"), restored at launch. nil = never learned.
    var hingeOpenAngle: Double?
    /// R6 D1 (UX §2): Bird side. nil = never chosen: the device default (`resolvedBirdSide`), so an R3–R5 save's
    /// `mirrored` keeps meaning "Right".
    var birdSide: BirdSide?
    /// Feel's `SharpHalf`: the sharp physical half and the orientation that names it (set on a Duo's first run).
    var sharpHalf: SharpHalf?
    /// The Wing check was answered (not skipped).
    var wingCheckDone = false
    /// The existing-player Wing check card (UX §2.4) was shown.
    var wingCheckCardShown = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = SettingsData.currentVersion
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        hapticLevel = (try? c.decodeIfPresent(AppHapticLevel.self, forKey: .hapticLevel)) ?? nil
        if hapticLevel == nil && !hapticsOn { hapticLevel = .off }
        respectSilentSwitch = (try? c.decodeIfPresent(Bool.self, forKey: .respectSilentSwitch)) ?? false
        playWithTouch = (try? c.decodeIfPresent(Bool.self, forKey: .playWithTouch)) ?? false
        tuckByTapping = (try? c.decodeIfPresent(Bool.self, forKey: .tuckByTapping)) ?? false
        mirrored = (try? c.decodeIfPresent(Bool.self, forKey: .mirrored)) ?? false
        tapOfferAnswered = (try? c.decodeIfPresent(Bool.self, forKey: .tapOfferAnswered)) ?? false
        hingeReadout = (try? c.decodeIfPresent(Bool.self, forKey: .hingeReadout)) ?? false
        let open = (try? c.decodeIfPresent(Double.self, forKey: .hingeOpenAngle)) ?? nil
        hingeOpenAngle = open.flatMap { $0.isFinite ? $0 : nil }
        birdSide = (try? c.decodeIfPresent(BirdSide.self, forKey: .birdSide)) ?? nil
        sharpHalf = (try? c.decodeIfPresent(SharpHalf.self, forKey: .sharpHalf)) ?? nil
        wingCheckDone = (try? c.decodeIfPresent(Bool.self, forKey: .wingCheckDone)) ?? false
        wingCheckCardShown = (try? c.decodeIfPresent(Bool.self, forKey: .wingCheckCardShown)) ?? false
    }

    /// The bird side in effect: the chosen one, else the R3–R5 "Bird on the other side" (Right), else the sharp side
    /// on a Duo and Left on an iPhone. Pure; tested.
    func resolvedBirdSide(isDuo: Bool) -> BirdSide {
        if let birdSide { return isDuo || birdSide != .sharp ? birdSide : .left }
        return BirdSideRule.migrated(oldMirrored: mirrored, isDuo: isDuo)
    }
}

/// Player settings for SwiftUI. Sound, haptics and the silent switch are pushed to `FeedbackDirector.shared` on every
/// change (and once at launch, `apply()`). `defaults` nil = in-memory (demo runs): nothing is written.
@MainActor
final class SettingsStore: ObservableObject {
    static let key = "swoop.settings"

    @Published var soundOn: Bool { didSet { changed() } }
    /// The haptic level the player picked (nil = the device default).
    @Published var chosenHapticLevel: AppHapticLevel? { didSet { changed() } }
    @Published var respectSilentSwitch: Bool { didSet { changed() } }
    @Published var playWithTouch: Bool { didSet { changed() } }
    @Published var tuckByTapping: Bool { didSet { changed() } }
    @Published var mirrored: Bool { didSet { changed() } }
    @Published var tapOfferAnswered: Bool { didSet { changed() } }
    @Published var hingeReadout: Bool { didSet { changed() } }
    /// Saved without `apply()` (it is input calibration, not feedback).
    @Published var hingeOpenAngle: Double? { didSet { save() } }
    /// R6 D1: Bird side (nil = the device default) and the physical sharp half.
    @Published var chosenBirdSide: BirdSide? { didSet { save() } }
    @Published var sharpHalf: SharpHalf? { didSet { save() } }
    @Published var wingCheckDone: Bool { didSet { save() } }
    @Published var wingCheckCardShown: Bool { didSet { save() } }

    /// Set by the controller once the device is known to be a Duo (the Strong default).
    var isDuo = false {
        didSet { if oldValue != isDuo { apply() } }
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        var stored = SettingsData()
        if let raw = defaults?.data(forKey: Self.key), let decoded = Self.decode(raw) {
            stored = decoded
        }
        soundOn = stored.soundOn
        chosenHapticLevel = stored.hapticLevel
        respectSilentSwitch = stored.respectSilentSwitch
        playWithTouch = stored.playWithTouch
        tuckByTapping = stored.tuckByTapping
        mirrored = stored.mirrored
        tapOfferAnswered = stored.tapOfferAnswered
        hingeReadout = stored.hingeReadout
        hingeOpenAngle = stored.hingeOpenAngle
        chosenBirdSide = stored.birdSide
        sharpHalf = stored.sharpHalf
        wingCheckDone = stored.wingCheckDone
        wingCheckCardShown = stored.wingCheckCardShown
    }

    /// The bird side in effect on this device.
    var birdSide: BirdSide {
        get { snapshot.resolvedBirdSide(isDuo: isDuo) }
        set { chosenBirdSide = newValue }
    }

    /// The haptic level in effect.
    var hapticLevel: AppHapticLevel {
        get { chosenHapticLevel ?? AppHapticLevel.defaultLevel(isDuo: isDuo) }
        set { chosenHapticLevel = newValue }
    }

    var hapticsOn: Bool { hapticLevel != .off }

    var snapshot: SettingsData {
        var d = SettingsData()
        d.soundOn = soundOn
        d.hapticsOn = hapticsOn
        d.hapticLevel = chosenHapticLevel
        d.respectSilentSwitch = respectSilentSwitch
        d.playWithTouch = playWithTouch
        d.tuckByTapping = tuckByTapping
        d.mirrored = mirrored
        d.tapOfferAnswered = tapOfferAnswered
        d.hingeReadout = hingeReadout
        d.hingeOpenAngle = hingeOpenAngle.flatMap { $0.isFinite ? $0 : nil }
        d.birdSide = chosenBirdSide
        d.sharpHalf = sharpHalf
        d.wingCheckDone = wingCheckDone
        d.wingCheckCardShown = wingCheckCardShown
        return d
    }

    nonisolated static func encode(_ data: SettingsData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> SettingsData? { try? JSONDecoder().decode(SettingsData.self, from: raw) }

    /// Pushes the sound and haptic settings to the feedback engines (launch, and after every change).
    func apply() {
        let feedback = FeedbackDirector.shared
        if feedback.soundOn != soundOn { feedback.soundOn = soundOn }
        if feedback.respectSilentSwitch != respectSilentSwitch { feedback.respectSilentSwitch = respectSilentSwitch }
        FeelAdapter.applyHaptics(chosen: chosenHapticLevel, isDuo: isDuo)
    }

    private func changed() {
        apply()
        save()
    }

    private func save() {
        guard let defaults, let raw = Self.encode(snapshot) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
