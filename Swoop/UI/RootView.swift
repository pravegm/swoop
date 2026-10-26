import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit flight full-bleed underneath, the SwiftUI screens on top, the pose cards above all.
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
        .onChange(of: reduceMotion) { _, on in controller.setReduceMotion(on) }
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
        let rect = AppPoseRule.playRect(in: canvas)
        let band = rect.height < canvas.height - 1
        let insets = band ? EdgeInsets(top: 0, leading: safe.leading, bottom: 0, trailing: safe.trailing) : safe
        let layout = ScreenLayout.make(canvas: rect.size, hasFold: currentFold(canvas),
                                       mirrored: controller.effectiveMirrored)
        let info = AppCanvas(size: rect.size, insets: insets, layout: layout)
        ZStack {
            SwoopTheme.abyss
            gameLayer(rect, hidden: pose != .play)
            switch pose {
            case .play:
                screenLayer(info)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            case .turn:
                TurnCard(insets: safe, isDuo: controller.hasHinge || AppPoseRule.looksLikeDuoInner(canvas)
                            || controller.forcedPose != nil,
                         onPlayWithTouch: { controller.chooseTouchFromPoseCard() })
                    .transition(.opacity)
            case .closed:
                ClosedCard(store: store)
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
    }

    // MARK: - Pose and canvas

    private func currentPose(_ canvas: CGSize) -> AppPose {
        if let forced = controller.forcedPose { return forced }
        return AppPoseRule.pose(canvas: canvas, hingeSeen: controller.hingeSeen, isShut: controller.isShut,
                             touchOverride: controller.touchOverride)
    }

    private func currentFold(_ canvas: CGSize) -> Bool {
        let rect = AppPoseRule.playRect(in: canvas)
        guard rect.height >= canvas.height - 1 else { return false }
        return AppPoseRule.hasFold(canvas: canvas, hingeSeen: controller.hingeSeen, demoDuo: controller.demoDuo,
                                divisionSeen: divisionSeen)
    }

    private func handleCanvas(_ canvas: CGSize) {
        guard canvas.width > 1, canvas.height > 1 else { return }
        lastCanvas = canvas
        // QA-1 P2-8: "Play with touch" from the portrait card lasts only while the canvas is portrait; held like a
        // book again, the hinge flies the bird.
        if canvas.width > canvas.height && controller.touchOverride { controller.clearTouchOverride() }
        let pose = currentPose(canvas)
        controller.setPose(pose)
        if pose == .turn && controller.forcedPose == nil && !controller.hasHinge
            && !AppPoseRule.looksLikeDuoInner(canvas) {
            // A phone held upright (landscape-only mask): ask iOS to turn the interface now.
            OrientationLock.requestLandscape()
        }
        guard pose == .play else { return }
        controller.updateCanvas(AppPoseRule.playRect(in: canvas).size, hasFold: currentFold(canvas))
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
        OrientationLock.refreshSupportedOrientations()
        controller.launch()
    }

    // MARK: - Layers

    /// The scene stops rendering while an opaque pose card covers it (real runs only: CI's demo launches wait for the
    /// scene's `SWOOP-T frame 120`).
    private func sceneIdle(hidden: Bool) -> Bool {
        guard !controller.isDemo else { return false }
        return hidden
    }

    @ViewBuilder
    private func gameLayer(_ rect: CGRect, hidden: Bool) -> some View {
        if let scene = controller.scene {
            SpriteView(scene: scene, isPaused: sceneIdle(hidden: hidden), preferredFramesPerSecond: 120)
                .id(controller.sceneGeneration)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func screenLayer(_ info: AppCanvas) -> some View {
        ZStack {
            switch controller.route {
            case .home:
                HomeView(controller: controller, store: store, info: info)
                    .transition(.opacity)
            case .playing:
                PlayLayer(controller: controller, hud: controller.hud, info: info)
                    .transition(.opacity)
            case .results:
                if let summary = controller.summary {
                    ResultsView(controller: controller, summary: summary, info: info)
                        .transition(.opacity)
                }
            case .goals:
                FlocksView(controller: controller, store: store, info: info)
                    .transition(.opacity)
            case .birds:
                BirdsView(controller: controller, store: store, info: info)
                    .transition(.opacity)
            case .settings:
                SettingsView(controller: controller, store: store, settings: settings, info: info)
                    .transition(.opacity)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(SwoopTheme.settle(reduceMotion), value: controller.route)
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
