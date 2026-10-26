import SwiftUI
import UIKit

/// Orientation policy (ported from Brim, turned round for Swoop: play is landscape).
///
/// Info.plist lists all four orientations, so iOS never runs Swoop as a letterboxed column on the Duo's portrait
/// (tabletop) inner display (Brim run 40203342285). The app itself decides what it supports:
/// - an iPhone Duo (a hinge reported on this device, one reports now, or the screen already looks foldable: both Duo
///   displays are ~0.7 wide-to-tall, other iPhones ~0.46): every orientation, so the inner display follows the way the
///   phone is held. Landscape (book pose) plays; portrait shows the "Turn your Duo sideways" card (PoseCards);
/// - every other iPhone: landscape only, so the UI turns sideways by itself.
@MainActor
enum OrientationLock {
    static let hingeKey = "swoop.hasHinge"

    /// A hinge reported in this run, before `swoop.hasHinge` was ever saved.
    private(set) static var hingeSeen = false

    static func mask(screen: CGSize) -> UIInterfaceOrientationMask {
        let stored = trustsStoredHinge(UserDefaults.standard.bool(forKey: hingeKey), screen: screen)
        return mask(hasHinge: stored || hingeSeen, screen: screen)
    }

    /// Pure rule (tested): all orientations on a Duo, landscape only elsewhere.
    nonisolated static func mask(hasHinge: Bool, screen: CGSize) -> UIInterfaceOrientationMask {
        allowsPortrait(hasHinge: hasHinge, screen: screen) ? .all : .landscape
    }

    /// Pure rule (tested): portrait only on a device with a hinge, or one whose screen looks like a Duo's.
    nonisolated static func allowsPortrait(hasHinge: Bool, screen: CGSize) -> Bool {
        if hasHinge { return true }
        guard screen.width > 0, screen.height > 0 else { return false }
        return min(screen.width, screen.height) / max(screen.width, screen.height) > 0.6
    }

    /// `swoop.hasHinge` travels in backups, so a saved "this device has a hinge" is only believed on a screen shaped
    /// like a Duo's (Brim QA-1 P1-1). Pure; tested.
    nonisolated static func trustsStoredHinge(_ stored: Bool, screen: CGSize) -> Bool {
        stored && allowsPortrait(hasHinge: false, screen: screen)
    }

    /// A hinge just reported: let the windows rotate freely from now on.
    static func hingeArrived() {
        guard !hingeSeen else { return }
        hingeSeen = true
        refreshSupportedOrientations()
    }

    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// Asks the window scene for landscape (the pose card's "Play with touch", phones held upright at launch).
    static func requestLandscape() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                AppTrace.t("SWOOP-T orient request error: \(error.localizedDescription)")
            }
        }
    }

    /// The key window's real safe-area insets (Dynamic Island, rounded corners, the Duo's inner camera cut-out).
    static func windowSafeArea() -> EdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
            return EdgeInsets()
        }
        let i = window.safeAreaInsets
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }

    /// The main screen's size in points (zero before the first scene connects).
    static func screenSize() -> CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first { return scene.screen.bounds.size }
        return .zero
    }
}

/// Supplies the orientation policy (`OrientationLock`) to UIKit.
@MainActor
final class SwoopAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask(screen: window?.windowScene?.screen.bounds.size ?? OrientationLock.screenSize())
    }
}
