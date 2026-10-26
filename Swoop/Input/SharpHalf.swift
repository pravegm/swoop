import Foundation
import UIKit

// Round 6 (D1, UX-FLIGHT-SCHOOL §2.1): the bird lives on the Duo's sharp half.
//
// iOS softens one FIXED PHYSICAL half of the inner display for ~2 s whenever a fold starts from (near) flat. Which half
// that is on screen depends on how the phone is held: turning it 180° (landscapeLeft ↔ landscapeRight) swaps the two
// physical halves between screen-left and screen-right. So the sharp half is stored as a physical half, plus the
// interface orientation that names the halves, and mapped to a screen side for whatever orientation is current.

/// A screen side of the landscape canvas.
enum FeelScreenSide: String, Codable, CaseIterable, Sendable {
    case left, right

    var opposite: FeelScreenSide { self == .left ? .right : .left }
}

/// The two physical halves of the Duo's inner display. `.a` is the half that was on screen-RIGHT in the reference
/// orientation (`SharpHalf.reference`); `.b` is the other one.
enum FeelPhysicalHalf: String, Codable, CaseIterable, Sendable {
    case a, b

    var other: FeelPhysicalHalf { self == .a ? .b : .a }
}

/// The two landscape interface orientations (`UIWindowScene.interfaceOrientation`).
enum FeelLandscape: String, Codable, CaseIterable, Sendable {
    case left, right

    /// The landscape orientation of a window scene; nil for portrait or unknown (keep the last landscape one).
    static func from(_ orientation: UIInterfaceOrientation) -> FeelLandscape? {
        switch orientation {
        case .landscapeLeft: return .left
        case .landscapeRight: return .right
        default: return nil
        }
    }

    /// The other landscape orientation (a 180° turn).
    var turned: FeelLandscape { self == .left ? .right : .left }

    /// One letter for logs (`o=L` / `o=R`).
    var letter: String { self == .left ? "L" : "R" }
}

/// Which physical half stays sharp, persisted (SettingsStore) so the bird stays on the same physical half after a
/// 180° turn and across launches. Pure, so it is tested.
struct SharpHalf: Codable, Equatable, Sendable {
    /// The sharp physical half.
    var physical: FeelPhysicalHalf
    /// The interface orientation that defines the halves: `.a` is on screen-right in it.
    var reference: FeelLandscape

    init(physical: FeelPhysicalHalf, reference: FeelLandscape) {
        self.physical = physical
        self.reference = reference
    }

    /// The default before any Wing check (ROUND-6 D1 correction): the half on screen-RIGHT in whatever landscape
    /// orientation the app first runs in on a Duo. That orientation becomes the reference for good.
    static func firstRun(in orientation: FeelLandscape) -> SharpHalf {
        SharpHalf(physical: .a, reference: orientation)
    }

    /// The physical half that is on `side` of the screen in `orientation`.
    func physicalHalf(onScreen side: FeelScreenSide, in orientation: FeelLandscape) -> FeelPhysicalHalf {
        let onRight: FeelPhysicalHalf = orientation == reference ? .a : .b
        return side == .right ? onRight : onRight.other
    }

    /// The screen side the sharp half is on in `orientation` (where the bird flies when Bird side is "Sharp side").
    func screenSide(in orientation: FeelLandscape) -> FeelScreenSide {
        physicalHalf(onScreen: .right, in: orientation) == physical ? .right : .left
    }

    /// The Wing check's answer: "this side stayed sharp", tapped on `side` while the phone was in `orientation`.
    /// The reference orientation is kept, so earlier answers and the default stay comparable.
    func recording(sharpSide side: FeelScreenSide, in orientation: FeelLandscape) -> SharpHalf {
        SharpHalf(physical: physicalHalf(onScreen: side, in: orientation), reference: reference)
    }

    /// `SWOOP-T birdside <left|right> physical=<a|b> o=<L|R>` (UX §2.1), for the sharp side in `orientation`.
    func logLine(in orientation: FeelLandscape) -> String {
        "SWOOP-T birdside \(screenSide(in: orientation).rawValue) physical=\(physical.rawValue) o=\(orientation.letter)"
    }
}
