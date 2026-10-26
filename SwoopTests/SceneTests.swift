import CoreGraphics
import Foundation
import Testing
@testable import Swoop

/// Scene module tests: the bird art (pure CoreGraphics), the camera mapping (pure struct), and a smoke run of the
/// scene through every event, phase, mirroring and Reduce Motion.
struct SceneTests {
    /// Every catalogue bird plus synthetic extremes of span and wing shape.
    static func allBirds() -> [Bird] {
        var list = BirdCatalog.all
        let c = RGBA(0.5, 0.5, 0.5)
        list.append(Bird(id: .puffin, name: "Broad", blurb: "", body: c, wing: c, wingTip: c, beak: c, trail: c,
                         span: 0.7, pointiness: 0, unlockRank: 0))
        list.append(Bird(id: .albatross, name: "Long", blurb: "", body: c, wing: c, wingTip: c, beak: c, trail: c,
                         span: 1.5, pointiness: 1, unlockRank: 0))
        list.append(SceneDefaults.bird)
        return list
    }

    // MARK: BirdArt

    @Test func sideViewPathsAreNonEmptyAndBounded() {
        for b in SceneTests.allBirds() {
            for tuck in [0.0, 0.5, 1.0] {
                for flap in [0.0, 0.25, 0.75] {
                    let p = BirdArt.path(for: b, tuck: tuck, flap: flap)
                    let limit = 0.95 * max(1.0, CGFloat(b.span))
                    for path in [p.body, p.nearWing, p.farWing, p.beak] {
                        #expect(!path.isEmpty)
                        let r = path.boundingBox
                        #expect(r.width > 0.005 && r.height > 0.005)
                        #expect(r.minX >= -limit && r.maxX <= limit && r.minY >= -limit && r.maxY <= limit)
                    }
                    let tips = BirdArt.wingTipPaths(for: b, tuck: tuck, flap: flap)
                    #expect(!tips.near.isEmpty && !tips.far.isEmpty)
                }
            }
        }
    }

    @Test func wingsFoldFlatWhenTucked() {
        for b in SceneTests.allBirds() {
            let open = BirdArt.path(for: b, tuck: 0, flap: 0).nearWing.boundingBoxOfPath
            let shut = BirdArt.path(for: b, tuck: 1, flap: 0).nearWing.boundingBoxOfPath
            // Spread: raised high above the back. Tucked: a slim wing lying along the body, swept back past the tail.
            #expect(shut.height < open.height * 0.5)
            #expect(shut.maxY < open.maxY)
            #expect(shut.minX < -0.3)
        }
    }

    @Test func flapPhaseZeroIsTheRestPose() {
        let b = SceneDefaults.bird
        let rest = BirdArt.path(for: b, tuck: 0, flap: 0).nearWing.boundingBoxOfPath
        let wrapped = BirdArt.path(for: b, tuck: 0, flap: 1).nearWing.boundingBoxOfPath
        let beat = BirdArt.path(for: b, tuck: 0, flap: 0.25).nearWing.boundingBoxOfPath
        #expect(abs(rest.maxY - wrapped.maxY) < 0.0001)
        #expect(abs(rest.maxY - beat.maxY) > 0.01)
    }

    @Test func titleBirdSpansTheCanvasAndFolds() {
        let w: CGFloat = 952, h: CGFloat = 670
        for b in SceneTests.allBirds() {
            let open = BirdArt.titlePath(for: b, tuck: 0, width: w, height: h)
            let spread = open.leftWing.boundingBoxOfPath.union(open.rightWing.boundingBoxOfPath)
            #expect(spread.width >= w * 0.93)
            #expect(open.leftWing.boundingBoxOfPath.midX < w * 0.5)
            #expect(open.rightWing.boundingBoxOfPath.midX > w * 0.5)
            #expect(open.leftWing.boundingBoxOfPath.minX < w * 0.05)
            #expect(open.rightWing.boundingBoxOfPath.maxX > w * 0.95)
            let body = open.body.boundingBoxOfPath
            #expect(!open.body.isEmpty)
            #expect(abs(body.midX - w * 0.5) < 1)

            let shut = BirdArt.titlePath(for: b, tuck: 1, width: w, height: h)
            let folded = shut.leftWing.boundingBoxOfPath.union(shut.rightWing.boundingBoxOfPath)
            #expect(folded.width <= w * 0.6)
            #expect(folded.width < spread.width * 0.7)

            let half = BirdArt.titlePath(for: b, tuck: 0.5, width: w, height: h)
            let mid = half.leftWing.boundingBoxOfPath.union(half.rightWing.boundingBoxOfPath)
            #expect(mid.width < spread.width && mid.width > folded.width)

            for path in [open.leftWing, open.rightWing, open.body, shut.leftWing, shut.rightWing] {
                let r = path.boundingBox
                #expect(r.minX >= -1 && r.maxX <= w + 1 && r.minY >= -1 && r.maxY <= h + 1)
            }
        }
    }

    // MARK: Camera

    static let duo = ScreenLayout.make(canvas: CGSize(width: 952, height: 670), hasFold: true)
    static let duoMirrored = ScreenLayout.make(canvas: CGSize(width: 952, height: 670), hasFold: true, mirrored: true)
    static let phone = ScreenLayout.make(canvas: CGSize(width: 852, height: 393), hasFold: false)

    @Test func cameraPinsTheBirdAtThirtyPercent() {
        var cam = SceneCamera(layout: SceneTests.duo)
        var x: Double = 12_345
        cam.snap(bird: CGPoint(x: x, y: 80), water: 20)
        #expect(abs(cam.screenPoint(CGPoint(x: x, y: 80)).x - 952 * 0.30) < 0.01)
        #expect(abs(cam.zoom - 1) < 0.0001)
        for i in 0..<480 {
            x += 9
            let y = 120 + 500 * sin(Double(i) * 0.02)
            cam.update(bird: CGPoint(x: x, y: max(y, 0)), water: 40 * sin(x * 0.01), dt: 1.0 / 120.0)
            let p = cam.screenPoint(CGPoint(x: x, y: max(y, 0)))
            #expect(abs(p.x - 952 * 0.30) < 0.01)
            #expect(p.y >= SceneTests.duo.visibleRect.minY && p.y <= SceneTests.duo.visibleRect.maxY)
        }
        // Ahead is to the right.
        #expect(cam.screenPoint(CGPoint(x: x + 100, y: 0)).x > cam.screenPoint(CGPoint(x: x, y: 0)).x)
    }

    @Test func mirroredCameraPinsTheBirdAtSeventyPercentAndFlips() {
        var cam = SceneCamera(layout: SceneTests.duoMirrored)
        cam.snap(bird: CGPoint(x: 5000, y: 50), water: 0)
        #expect(abs(cam.screenPoint(CGPoint(x: 5000, y: 50)).x - 952 * 0.70) < 0.01)
        #expect(cam.screenPoint(CGPoint(x: 5100, y: 0)).x < cam.screenPoint(CGPoint(x: 5000, y: 0)).x)
        let r = cam.visibleSeaRange(margin: 0)
        #expect(r.lo < 5000 && r.hi > 5000)
        #expect(abs(cam.screenPoint(CGPoint(x: r.lo, y: 0)).x - 952) < 0.5)
    }

    @Test func waterStaysVisibleHighUp() {
        for layout in [SceneTests.duo, SceneTests.duoMirrored, SceneTests.phone] {
            for altitude in [0.0, 300, 600, 900, 1100] {
                var cam = SceneCamera(layout: layout)
                let bird = CGPoint(x: 8000, y: altitude)
                cam.snap(bird: bird, water: 0)
                // Settle at that altitude for 4 s.
                for _ in 0..<480 { cam.update(bird: bird, water: 0, dt: 1.0 / 120.0) }
                let vis = layout.visibleRect
                let waterY = cam.screenPoint(CGPoint(x: 8000, y: 0)).y
                let birdY = cam.screenPoint(bird).y
                #expect(waterY >= vis.minY && waterY <= vis.maxY, "water off screen at \(altitude)")
                #expect(birdY >= vis.minY && birdY <= vis.maxY, "bird off screen at \(altitude)")
                #expect(birdY >= waterY)
                #expect(cam.zoom <= 1.0001 && cam.zoom >= cam.zoomMin * 0.9)
            }
        }
        var cam = SceneCamera(layout: SceneTests.duo)
        cam.snap(bird: CGPoint(x: 0, y: 1100), water: 0)
        #expect(cam.zoom < 0.5)
    }

    @Test func pausedCameraHoldsStill() {
        var cam = SceneCamera(layout: SceneTests.duo)
        cam.snap(bird: CGPoint(x: 100, y: 400), water: 0)
        cam.update(bird: CGPoint(x: 100, y: 800), water: 0, dt: 1.0 / 60.0)
        let z = cam.zoom
        cam.update(bird: CGPoint(x: 100, y: 800), water: 0, dt: 0)
        #expect(cam.zoom == z)
    }

    // MARK: Scene smoke run

    @Test @MainActor func sceneRunsThroughEveryPhaseAndEvent() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        var now: TimeInterval = 1000
        func frames(_ n: Int) {
            for _ in 0..<n {
                scene.update(now)
                now += 1.0 / 120.0
            }
        }
        frames(60)                                      // countdown hover
        driver.snap.phase = .flying
        driver.pending = [.started, .launched(speed: 900)]
        frames(30)
        driver.snap.skimming = true
        frames(30)
        driver.pending = [.touchdown(.perfect, speed: 1500, chain: 3), .tailwindStarted, .milestone(km: 1)]
        driver.snap.tailwindRemaining = 2
        frames(30)
        driver.pending = [.touchdown(.splash, speed: 800, chain: 0), .touchdown(.good, speed: 700, chain: 0),
                          .tailwindEnded, .cloudTouched, .newBest, .stormClose,
                          .lighthouse(index: 0, name: "Gull Point")]
        driver.snap.tailwindRemaining = 0
        driver.snap.speed = 2200
        frames(60)
        scene.layout = SceneTests.duoMirrored
        scene.reduceMotion = true
        driver.pending = [.touchdown(.splash, speed: 1200, chain: 0), .stormClose]
        frames(30)
        driver.snap.phase = .caught(elapsed: 0.2)
        driver.pending = [.caught]
        frames(90)
        driver.snap.phase = .finished
        driver.pending = [.finished]
        frames(10)
        scene.layout = SceneTests.phone
        scene.reset()
        frames(10)
        #expect(scene.drawnFrames == 350)
        #expect(scene.children.count >= 5)
    }
}

/// A scripted stand-in for the App's GameController.
@MainActor
final class SceneTestsDriver: SceneDriver {
    var sea: SeaProfile? = SeaProfile(seed: 42)
    var bird: Bird = SceneDefaults.bird
    var sky: Sky = SceneDefaults.sky
    var snap = FlightSnapshot(phase: .countdown(remaining: 3), position: CGPoint(x: 0, y: 260), speed: 520,
                              stormX: -2400, gap: 2400, lead: 0.8, nextLighthouseX: 3000, bestMeters: 150)
    var pending: [FlightEvent] = []

    func advance(dt: TimeInterval, now: TimeInterval) -> (FlightSnapshot, [FlightEvent]) {
        snap.time += dt
        if snap.phase == .flying {
            let vx = max(snap.speed, 300)
            snap.position.x += CGFloat(vx * dt)
            let water = sea?.height(at: Double(snap.position.x)) ?? 0
            snap.position.y = CGFloat(water + (snap.skimming ? 0 : 140))
            snap.velocity = CGVector(dx: vx, dy: 0)
            snap.stormX += 700 * dt
            snap.gap = Double(snap.position.x) - snap.stormX
            snap.lead = min(max(snap.gap / 3000, 0), 1)
            snap.tuck = 0.5 + 0.5 * sin(snap.time * 3)
            snap.bodyAngle = 0.2 * sin(snap.time * 2)
            snap.altitude = snap.skimming ? 0 : 140
        }
        let e = pending
        pending = []
        return (snap, e)
    }
}
