import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit flight underneath, the SwiftUI screens on top, the pose states above all (UX-SPEC §9).
///
/// Safe areas: the content ignores the safe area (the scene is full-bleed), so the insets are read from an outer
/// GeometryReader that does NOT ignore it and from the key window (whichever is larger), and handed to every screen in
/// `AppCanvas.insets`. The hinge is read here, once, for the whole app (HingeReader → GameController.hingeSample →
/// HingeTuckSource).
struct RootView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false
    @State private var windowInsets = EdgeInsets()
    /// The `.division` reserved region (iOS 27.1: present while the Duo is partly folded) has been seen.
    @State private var divisionSeen = false
    @State private var lastCanvas = CGSize.zero
    /// UX §10: an iPhone's TurnCard shows only if the canvas is still portrait 0.6 s later (it never flashes).
    @State private var turnCardReady = false
    /// UX-D4: thermal state and Low Power drop Play to 60 fps.
    @State private var thermalHot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// How long an iPhone waits before showing the TurnCard.
    static let turnCardDelay: Double = 0.6

    var body: some View {
        GeometryReader { safeGeo in
            let safe = safeGeo.safeAreaInsets
            GeometryReader { geo in
                let division = Self.activeDivision(in: geo)
                content(canvas: geo.size, safe: merged(safe, windowInsets))
                    .onChange(of: division ?? .zero) { _, frame in
                        logFold(frame)
                        if frame != .zero && !divisionSeen {
                            divisionSeen = true
                            handleCanvas(geo.size)
                        }
                    }
            }
            .ignoresSafeArea()
        }
        .background(SwoopTheme.abyss.ignoresSafeArea())
        .modifier(HingeReader(onUpdate: { angle, time in
            controller.hingeSample(angle: angle, time: time)
        }, onUnavailable: {
            controller.hingeUnavailable()
        }))
        .onChange(of: scenePhase) { _, phase in
            controller.setAppActive(phase == .active)
            if phase == .active { refreshWindowInsets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshWindowInsets()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            thermalHot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onChange(of: reduceMotion) { _, on in controller.setReduceMotion(on) }
        // UX-D4/D5: hot or Low Power, the scene trims particles and rain (Scene R3 `effectsQuality`).
        .onChange(of: thermalHot) { _, hot in controller.setPowerState(thermalHot: hot, lowPower: lowPower) }
        .onChange(of: lowPower) { _, low in controller.setPowerState(thermalHot: thermalHot, lowPower: low) }
        .onChange(of: settings.playWithTouch) { _, _ in controller.refreshInput() }
        .onChange(of: settings.mirrored) { _, _ in
            controller.refreshLayout()
            handleCanvas(lastCanvas)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func content(canvas: CGSize, safe: EdgeInsets) -> some View {
        let pose = currentPose(canvas)
        ZStack {
            SwoopTheme.abyss
            switch pose {
            case .play:
                let rect = AppPoseRule.playRect(in: canvas)
                let layout = ScreenLayout.make(canvas: rect.size, hasFold: currentFold(canvas),
                                               mirrored: controller.effectiveMirrored)
                let info = AppCanvas(size: rect.size, insets: safe, layout: layout)
                gameLayer(rect, hidden: false)
                screenLayer(info)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            case .deck:
                deckLayer(canvas: canvas, safe: safe)
            case .turn:
                gameLayer(AppPoseRule.playRect(in: canvas), hidden: true)
                if turnCardReady || isDuoLike(canvas) {
                    TurnCard(insets: safe, isDuo: isDuoLike(canvas) || controller.forcedPose != nil,
                             onPlayWithTouch: { controller.chooseTouchFromPoseCard() })
                        .transition(.opacity)
                }
            case .closed:
                gameLayer(AppPoseRule.playRect(in: canvas), hidden: true)
                ClosedCard(controller: controller, store: store, state: closedState, insets: safe)
                    .transition(.opacity)
            }
            if controller.showsIconExport {
                iconLayer(canvas)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .animation(SwoopTheme.settle(reduceMotion), value: pose)
        .onAppear {
            refreshWindowInsets()
            handleCanvas(canvas)
            launchOnce()
        }
        .onChange(of: canvas) { _, newSize in
            refreshWindowInsets()
            handleCanvas(newSize)
        }
        .onChange(of: controller.hingeSeen) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.isShut) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.touchOverride) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.coverFlying) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.route) { _, _ in handleCanvas(canvas) }
        .task(id: pose == .turn) {
            // The iPhone TurnCard waits 0.6 s (the landscape mask usually turns the UI first).
            turnCardReady = false
            guard pose == .turn else { return }
            try? await Task.sleep(nanoseconds: UInt64(Self.turnCardDelay * 1_000_000_000))
            if !Task.isCancelled { turnCardReady = true }
        }
    }

    // MARK: - Pose and canvas

    private func isDuoLike(_ canvas: CGSize) -> Bool {
        controller.hasHinge || AppPoseRule.looksLikeDuoInner(canvas)
    }

    private func currentPose(_ canvas: CGSize) -> AppPose {
        if let forced = controller.forcedPose { return forced }
        return AppPoseRule.pose(canvas: canvas, hingeSeen: controller.hingeSeen, isShut: controller.isShut,
                                inRun: controller.inRun, touchOverride: controller.touchOverride,
                                coverFlying: controller.coverFlying)
    }

    private func currentFold(_ canvas: CGSize) -> Bool {
        AppPoseRule.hasFold(canvas: canvas, hingeSeen: controller.hingeSeen, demoDuo: controller.demoDuo,
                            divisionSeen: divisionSeen)
    }

    /// The cover card's state (UX-D1): the results you left, the paused run, or Home.
    private var closedState: ClosedCardState {
        if controller.route == .results, let summary = controller.summary { return .results(summary) }
        if controller.inRun, let paused = controller.pausedRun { return .midRun(paused) }
        return .home
    }

    private func handleCanvas(_ canvas: CGSize) {
        guard canvas.width > 1, canvas.height > 1 else { return }
        lastCanvas = canvas
        if max(canvas.width, canvas.height) >= AppPoseRule.coverMaxSide { controller.innerDisplayBack() }
        // QA-1 P2-8: "Play with touch" from the portrait card lasts only while the canvas is portrait.
        if canvas.width > canvas.height && controller.touchOverride { controller.clearTouchOverride() }
        let pose = currentPose(canvas)
        controller.setPose(pose)
        if pose == .turn && controller.forcedPose == nil && !isDuoLike(canvas) {
            // A phone held upright (landscape-only mask): ask iOS to turn the interface now.
            OrientationLock.requestLandscape()
        }
        switch pose {
        case .play:
            controller.updateCanvas(AppPoseRule.playRect(in: canvas).size, hasFold: currentFold(canvas))
        case .deck:
            controller.updateCanvas(DeckLayout.make(canvas: canvas).band.size, hasFold: false)
        case .turn, .closed:
            break
        }
    }

    private func merged(_ a: EdgeInsets, _ b: EdgeInsets) -> EdgeInsets {
        EdgeInsets(top: max(a.top, b.top), leading: max(a.leading, b.leading),
                   bottom: max(a.bottom, b.bottom), trailing: max(a.trailing, b.trailing))
    }

    private func refreshWindowInsets() {
        let read = OrientationLock.windowSafeArea()
        if read != windowInsets { windowInsets = read }
        // The window settles its insets a beat after a rotation or a display handover.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let later = OrientationLock.windowSafeArea()
            if later != windowInsets { windowInsets = later }
        }
    }

    /// The active fold (`.division` reserved region, iOS 27.1): present only while the Duo is partly folded.
    private static func activeDivision(in proxy: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).first?.frame
        }
        return nil
    }

    private func logFold(_ frame: CGRect) {
        if frame == .zero {
            AppTrace.t("SWOOP-T fold inactive")
        } else {
            AppTrace.t(String(format: "SWOOP-T fold active %.0f,%.0f %.0fx%.0f", frame.minX, frame.minY,
                              frame.width, frame.height))
        }
    }

    private func launchOnce() {
        guard !launched else { return }
        launched = true
        controller.setReduceMotion(reduceMotion)
        controller.setPowerState(thermalHot: thermalHot, lowPower: lowPower)
        OrientationLock.refreshSupportedOrientations()
        controller.launch()
    }

    // MARK: - Layers

    /// UX-D4: 120 Hz only in Play; Home, pages and cards at 60; 60 in Play too when hot or in Low Power. Pure; tested.
    nonisolated static func framesPerSecond(playing: Bool, thermalHot: Bool, lowPower: Bool) -> Int {
        playing && !thermalHot && !lowPower ? 120 : 60
    }

    /// The scene stops rendering while an opaque pose card covers it (real runs only: CI's demo launches wait for the
    /// scene's `SWOOP-T frame 120`).
    private func sceneIdle(hidden: Bool) -> Bool {
        guard !controller.isDemo else { return false }
        return hidden
    }

    @ViewBuilder
    private func gameLayer(_ rect: CGRect, hidden: Bool) -> some View {
        if let scene = controller.scene {
            let fps = Self.framesPerSecond(playing: controller.route == .playing, thermalHot: thermalHot,
                                           lowPower: lowPower)
            SpriteView(scene: scene, isPaused: sceneIdle(hidden: hidden), preferredFramesPerSecond: fps)
                .id(controller.sceneGeneration)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The split deck (UX-D2): the game band on the top half, the deck below; the deck takes the run's HUD, its
    /// pause card and its results.
    @ViewBuilder
    private func deckLayer(canvas: CGSize, safe: EdgeInsets) -> some View {
        let d = DeckLayout.make(canvas: canvas)
        let deckInsets = EdgeInsets(top: 0, leading: safe.leading, bottom: safe.bottom, trailing: safe.trailing)
        let deckCanvas = AppCanvas(size: d.deck.size, insets: deckInsets,
                                   layout: ScreenLayout.make(canvas: d.deck.size, hasFold: false,
                                                             mirrored: controller.effectiveMirrored),
                                   singlePage: true)
        gameLayer(d.band, hidden: false)
        // The deck is solid `surface` and meets the band with a 1 pt hairline (ART conflict 6).
        Rectangle()
            .fill(SwoopTheme.surface)
            .frame(width: d.deck.width, height: d.deck.height)
            .position(x: d.deck.midX, y: d.deck.midY)
        Rectangle()
            .fill(SwoopTheme.stroke)
            .frame(width: d.deck.width, height: 1)
            .position(x: d.deck.midX, y: d.deck.minY)
        Group {
            if controller.route == .results, let summary = controller.summary {
                ResultsView(controller: controller, summary: summary, info: deckCanvas)
            } else {
                DeckPlayView(controller: controller, hud: controller.hud, info: deckCanvas)
            }
        }
        .frame(width: d.deck.width, height: d.deck.height)
        .position(x: d.deck.midX, y: d.deck.midY)
    }

    @ViewBuilder
    private func screenLayer(_ info: AppCanvas) -> some View {
        ZStack {
            switch controller.route {
            case .home:
                HomeView(controller: controller, store: store, settings: settings, info: info)
                    .transition(.opacity)
            case .playing:
                PlayLayer(controller: controller, hud: controller.hud, info: info)
                    .transition(.opacity)
            case .results, .daily:
                if let summary = controller.summary {
                    ResultsView(controller: controller, summary: summary, info: info)
                        .transition(SwoopTheme.pageTransition(reduceMotion, fromTrailing: !info.mirrored))
                }
            case .goals:
                FlocksView(controller: controller, store: store, info: info)
                    .transition(SwoopTheme.pageTransition(reduceMotion))
            case .birds:
                BirdsView(controller: controller, store: store, info: info)
                    .transition(SwoopTheme.pageTransition(reduceMotion))
            case .settings:
                SettingsView(controller: controller, store: store, settings: settings, info: info)
                    .transition(SwoopTheme.pageTransition(reduceMotion))
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(SwoopTheme.pageAnimation(reduceMotion), value: controller.route)
    }

    @ViewBuilder
    private func iconLayer(_ canvas: CGSize) -> some View {
        let side = min(canvas.width, canvas.height)
        ZStack {
            Color.black
            AppIconArt()
                .frame(width: side, height: side)
        }
        .frame(width: canvas.width, height: canvas.height)
        .onAppear {
            #if DEBUG
            IconExport.render()
            #endif
        }
    }
}
