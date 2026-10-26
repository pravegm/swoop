import Combine
import Foundation

/// The player's settings (kept apart from progress so "Reset progress" leaves them alone). Versioned JSON.
struct SettingsData: Codable, Equatable {
    static let currentVersion = 1

    var version = SettingsData.currentVersion
    var soundOn = true
    var hapticsOn = true
    /// Off by default (GAME-DESIGN §7: sound plays on silent, as the founder asked for Squish).
    var respectSilentSwitch = false
    /// iPhone Duo: hold the screen to tuck instead of folding.
    var playWithTouch = false
    /// "Bird on the other side": the flight runs right to left, the bird on the right half.
    var mirrored = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? SettingsData.currentVersion
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        respectSilentSwitch = (try? c.decodeIfPresent(Bool.self, forKey: .respectSilentSwitch)) ?? false
        playWithTouch = (try? c.decodeIfPresent(Bool.self, forKey: .playWithTouch)) ?? false
        mirrored = (try? c.decodeIfPresent(Bool.self, forKey: .mirrored)) ?? false
    }
}

/// Player settings for SwiftUI. Sound, haptics and the silent switch are pushed to `FeedbackDirector.shared` on every
/// change (and once at launch, `apply()`). `defaults` nil = in-memory (demo runs): nothing is written.
@MainActor
final class SettingsStore: ObservableObject {
    static let key = "swoop.settings"

    @Published var soundOn: Bool { didSet { changed() } }
    @Published var hapticsOn: Bool { didSet { changed() } }
    @Published var respectSilentSwitch: Bool { didSet { changed() } }
    @Published var playWithTouch: Bool { didSet { changed() } }
    @Published var mirrored: Bool { didSet { changed() } }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        var stored = SettingsData()
        if let raw = defaults?.data(forKey: Self.key), let decoded = Self.decode(raw) {
            stored = decoded
        }
        soundOn = stored.soundOn
        hapticsOn = stored.hapticsOn
        respectSilentSwitch = stored.respectSilentSwitch
        playWithTouch = stored.playWithTouch
        mirrored = stored.mirrored
    }

    var snapshot: SettingsData {
        var d = SettingsData()
        d.soundOn = soundOn
        d.hapticsOn = hapticsOn
        d.respectSilentSwitch = respectSilentSwitch
        d.playWithTouch = playWithTouch
        d.mirrored = mirrored
        return d
    }

    nonisolated static func encode(_ data: SettingsData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> SettingsData? { try? JSONDecoder().decode(SettingsData.self, from: raw) }

    /// Pushes the sound settings to the feedback engines (launch, and after every change).
    func apply() {
        let feedback = FeedbackDirector.shared
        if feedback.soundOn != soundOn { feedback.soundOn = soundOn }
        if feedback.hapticsOn != hapticsOn { feedback.hapticsOn = hapticsOn }
        if feedback.respectSilentSwitch != respectSilentSwitch { feedback.respectSilentSwitch = respectSilentSwitch }
    }

    private func changed() {
        apply()
        guard let defaults, let raw = Self.encode(snapshot) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
