import SwiftUI

@main
struct SwoopApp: App {
    /// Landscape on phones; every orientation on a Duo (App/OrientationLock.swift).
    @UIApplicationDelegateAdaptor(SwoopAppDelegate.self) private var appDelegate
    @StateObject private var store: ProgressStore
    @StateObject private var settings: SettingsStore
    @StateObject private var controller: GameController

    init() {
        #if DEBUG
        let demo = DemoConfig.current
        let isDemo = demo != nil
        if let demo {
            setvbuf(stdout, nil, _IOLBF, 0)
            AppTrace.t("SWOOP-T demo '\(demo.raw)' starts")
        }
        #else
        let isDemo = false
        #endif
        // Demo runs never touch the player's saved progress or settings.
        let store = isDemo ? ProgressStore(inMemory: ProgressData()) : ProgressStore(defaults: .standard)
        let settings = SettingsStore(defaults: isDemo ? nil : UserDefaults.standard)
        _store = StateObject(wrappedValue: store)
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: GameController(store: store, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller, store: store, settings: settings)
                .onAppear {
                    settings.apply()
                    FeedbackDirector.shared.start()
                    // FINAL-FIXES #11: every sign-in resends the best and the earned achievements from the progress.
                    GameCenterManager.shared.progress = { [store] in store.data }
                    GameCenterManager.shared.authenticate()
                }
        }
    }
}
