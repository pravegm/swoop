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
            #expect(shut.height < open.height * 0.6)
            #expect(shut.maxY < open.maxY)
            #expect(shut.minX < -0.3)
        }
    }

    /// Each species has its own wing (REVIEW-1 P1-10): the albatross's is long, the puffin's stubby, the swift's a
    /// swept-back sickle.
    @Test func speciesWingsDiffer() {
        let c = RGBA(0.5, 0.5, 0.5)
        func wing(_ id: BirdID) -> CGRect {
            let b = Bird(id: id, name: "", blurb: "", body: c, wing: c, wingTip: c, beak: c, trail: c, span: 1,
                         pointiness: 0.5, unlockRank: 0)
            return BirdArt.path(for: b, tuck: 0, flap: 0).nearWing.boundingBoxOfPath
        }
        let albatross = wing(.albatross), puffin = wing(.puffin), swift = wing(.swift), gull = wing(.gull)
        #expect(hypot(albatross.width, albatross.height) > hypot(puffin.width, puffin.height) * 1.4)
        // The sickle sweeps its hand further back than the gull's.
        #expect(swift.minX < gull.minX)
    }

    /// ART §4: the spread wings are a long, shallow check-mark lifted up and back, never "rabbit ears".
    @Test func spreadWingsNeverPointStraightUp() {
        for b in SceneTests.allBirds() {
            let open = BirdArt.path(for: b, tuck: 0, flap: 0).nearWing.boundingBoxOfPath
            #expect(open.width > open.height)
            let back = BirdArt.backLinePath(for: b).boundingBoxOfPath
            let belly = BirdArt.bellyPath(for: b).boundingBoxOfPath
            let body = BirdArt.path(for: b, tuck: 0, flap: 0).body.boundingBoxOfPath
            #expect(back.minY > body.midY - 0.01 && belly.maxY < body.midY)
            #expect(!BirdArt.nearWingLeadingEdge(for: b, tuck: 0.5, flap: 0).isEmpty)
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
            // A 92 % span (ART §7).
            #expect(spread.width >= w * 0.90 && spread.width <= w * 0.95)
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
            // R5 (ROUND-5 P1-6): a narrow gannet dart, at most 14 % of the width.
            #expect(folded.width <= w * 0.145 && folded.width >= w * 0.10)
            // The body's invisible specks keep its box at the full span at every tuck, so the App's fit (which refits
            // anything under 25 % wide) leaves the dart at its real size.
            let shutBody = shut.body.boundingBoxOfPath
            #expect(shutBody.width >= w * 0.9 && shutBody.width <= w * 0.93)
            // The tucked tips sweep back past the tail (y down), and each wing stays on its own side of the body.
            #expect(shut.leftWing.boundingBoxOfPath.maxY > shutBody.maxY)
            #expect(shut.leftWing.boundingBoxOfPath.minX < w * 0.5 - w * 0.045)
            #expect(shut.rightWing.boundingBoxOfPath.maxX > w * 0.5 + w * 0.045)

            let half = BirdArt.titlePath(for: b, tuck: 0.5, width: w, height: h)
            let mid = half.leftWing.boundingBoxOfPath.union(half.rightWing.boundingBoxOfPath)
            #expect(mid.width < spread.width && mid.width > folded.width)

            // The detail layers sit on the wings.
            let detail = BirdArt.titleDetail(for: b, tuck: 0, width: w, height: h)
            let wings = open.leftWing.boundingBoxOfPath.union(open.rightWing.boundingBoxOfPath)
            for path in [detail.leftBand, detail.rightBand, detail.leftPrimaries, detail.rightPrimaries,
                         detail.leftMirrors, detail.rightMirrors] {
                #expect(!path.isEmpty)
                #expect(wings.insetBy(dx: -2, dy: -2).contains(path.boundingBoxOfPath))
            }
            #expect(detail.leftPrimaries.boundingBoxOfPath.maxX < w * 0.25)
            #expect(!detail.beak.isEmpty && !detail.beakSpot.isEmpty)
            for path in [open.leftWing, open.rightWing, open.body, shut.leftWing, shut.rightWing] {
                let r = path.boundingBox
                #expect(r.minX >= -1 && r.maxX <= w + 1 && r.minY >= -1 && r.maxY <= h + 1)
            }
        }
    }

    /// ROUND-4 P0-5: the tucked title bird is one clean dart, not sticks with feet.
    @Test func tuckedTitleIsADartWithoutFeet() {
        let w: CGFloat = 952
        for h in [CGFloat(254), CGFloat(420), CGFloat(670)] {
            for b in SceneTests.allBirds() {
                let shut = BirdArt.titlePath(for: b, tuck: 1, width: w, height: h)
                let detail = BirdArt.titleDetail(for: b, tuck: 1, width: w, height: h)
                #expect(detail.leftMirrors.isEmpty && detail.rightMirrors.isEmpty)
                let wing = shut.leftWing.boundingBoxOfPath
                let body = shut.body.boundingBoxOfPath
                // A gannet dart (R5): tight along the body, longer than it is wide, ≤ 0.07 w from the fold, the tips
                // behind the tail; the white band is gone too (it hung beside the tail like legs).
                #expect(wing.minX >= w * 0.5 - w * 0.0705)
                #expect(wing.height > wing.width * 2)
                #expect(wing.maxY > body.maxY)
                #expect(detail.leftBand.isEmpty && detail.rightBand.isEmpty)
                #expect(!detail.beakLower.isEmpty && !detail.headContour.isEmpty)
            }
        }
    }

    /// The one bird mark (REVIEW-3 juror #16): an "M" glyph inside its box.
    @Test func birdMarkFitsItsBox() {
        let p = BirdArt.markPath(width: 48, height: 24)
        let r = p.boundingBoxOfPath
        #expect(!p.isEmpty)
        #expect(r.minX >= 0 && r.maxX <= 48 && r.minY >= 0 && r.maxY <= 24)
        #expect(r.width > 40)
        #expect(abs(BirdArt.markLineWidth(forHeight: 24) - 2) < 0.001)
    }

    // MARK: Storm map (ROUND-4 P0-2)

    @Test func stormEdgeFollowsTheLeadMeter() {
        let birdPage: CGFloat = 456
        let anchor: CGFloat = 952 * 0.30
        // The meter and the picture use one formula.
        // sqrt(gap / (leadMeterScale × fullLead)); the start gap reads ~37–40 % (scale 5.0–5.7, R4b).
        let startFill: Double = (2400.0 / (Tuning.leadMeterScale * Tuning.fullLead)).squareRoot()
        #expect(abs(SceneStormMap.meterFill(gap: 2400) - startFill) < 0.001)
        #expect(startFill > 0.33 && startFill < 0.45)
        #expect(SceneStormMap.meterFill(gap: 1e9) == 1)
        #expect(SceneStormMap.meterFill(gap: -50) == 0)
        // A hint at a full lead, 40 % of the bird page at storm-close, right behind the bird at contact.
        #expect(abs(SceneStormMap.edgeU(meterFill: 1, birdPageWidth: birdPage, anchorU: anchor)
                    - SceneLook.stormHintEdge) < 0.01)
        let close = SceneStormMap.edgeU(meterFill: SceneStormMap.closeFill, birdPageWidth: birdPage, anchorU: anchor)
        #expect(abs(close - 0.40 * birdPage) < 0.5)
        let contact = SceneStormMap.edgeU(meterFill: 0, birdPageWidth: birdPage, anchorU: anchor)
        #expect(contact <= anchor && contact > close)
        // Monotonic: a smaller gap always means a closer wall.
        var last: CGFloat = -1
        var gap: Double = 20_000
        while gap >= 0 {
            let e = SceneStormMap.edgeU(meterFill: SceneStormMap.meterFill(gap: gap), birdPageWidth: birdPage,
                                        anchorU: anchor)
            #expect(e >= last)
            last = e
            gap -= 250
        }
        // At a 77 % and a 9 % lead (the frames the panel compared) the wall stands visibly apart.
        let far = SceneStormMap.edgeU(meterFill: SceneStormMap.meterFill(gap: 0.77 * 15_000), birdPageWidth: birdPage,
                                      anchorU: anchor)
        let near = SceneStormMap.edgeU(meterFill: SceneStormMap.meterFill(gap: 0.09 * 15_000), birdPageWidth: birdPage,
                                       anchorU: anchor)
        #expect(near - far > 80)
    }

    @Test @MainActor func stormOnScreenChasesAsTheGapCloses() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        driver.snap.stormX = -9000
        driver.stormSpeed = 520 + 1500
        var now: TimeInterval = 40
        var edges: [CGFloat] = []
        for i in 0..<600 {
            scene.update(now)
            now += 1.0 / 120.0
            if i % 60 == 59 { edges.append(scene.stormEdgeU) }
        }
        #expect(edges.count == 10)
        if let first = edges.first, let last = edges.last {
            #expect(last - first > 60)
        }
        for i in 1..<edges.count { #expect(edges[i] >= edges[i - 1] - 0.5) }
    }

    /// ROUND-5 P1-5: the storm never reaches the HUD band (the pause button and the meter), on the Duo or a phone,
    /// even at contact.
    @Test @MainActor func stormStaysClearOfTheHUD() {
        for layout in [SceneTests.duo, SceneTests.phone] {
            let scene = FlightScene(layout: layout)
            let driver = SceneTestsDriver()
            scene.driver = driver
            scene.reset()
            driver.snap.phase = .flying
            driver.snap.stormX = -60
            var now: TimeInterval = 70
            for _ in 0..<90 {
                scene.update(now)
                now += 1.0 / 120.0
                #expect(scene.stormTopY <= layout.visibleRect.maxY - SceneLook.stormHUDClearance + 0.5)
            }
        }
    }

    /// REVIEW-4 juror #7: the caught / Results sea settles into one calm swell.
    @Test func caughtSeaIsOneCalmSwell() {
        for x in stride(from: 0.0, to: 4000.0, by: 37.0) {
            let h = 180 * sin(x * 0.02)
            #expect(SceneSeaView.calmed(h, x: x, calm: 1) == h)
            let c = SceneSeaView.calmed(h, x: x, calm: 0)
            #expect(abs(c) <= 60)
        }
        #expect(SceneLook.calmSwellLength >= 500)
    }

    /// REVIEW-4 juror #8: the Birds preview fits every pose (no clipped wing) at ≤ 2.2× the in-game size.
    @Test func birdPreviewNeverClips() {
        for b in SceneTests.allBirds() {
            for size in [CGSize(width: 220, height: 160), CGSize(width: 600, height: 320), CGSize(width: 120, height: 90)] {
                let t = BirdArt.previewTransform(for: b, in: size)
                let env = BirdArt.previewEnvelope(for: b).applying(t)
                #expect(env.minX >= -0.5 && env.maxX <= size.width + 0.5)
                #expect(env.minY >= -0.5 && env.maxY <= size.height + 0.5)
                #expect(abs(t.a) <= BirdArt.previewMaxUnit + 0.001)
            }
        }
        #expect(BirdArt.isDark(Bird(id: .petrel, name: "", blurb: "", body: RGBA(hex: 0x2B2F36), wing: RGBA(hex: 0x2B2F36),
                                    wingTip: RGBA(hex: 0x111111), beak: RGBA(hex: 0x333333), trail: RGBA(hex: 0x9DB4FF),
                                    span: 1.1, pointiness: 0.8, unlockRank: 0)))
        #expect(!BirdArt.isDark(SceneDefaults.bird))
    }

    @Test func perfectRingsEscalateWithTheChain() {
        #expect(SceneEffects.ringTier(chain: 1) == 0)
        #expect(SceneEffects.ringTier(chain: 4) == 0)
        #expect(SceneEffects.ringTier(chain: 5) == 1)
        #expect(SceneEffects.ringTier(chain: 9) == 1)
        #expect(SceneEffects.ringTier(chain: 10) == 2)
        #expect(SceneEffects.ringTier(chain: 23) == 2)
        #expect(FlightScene.isChainMilestone(3) && FlightScene.isChainMilestone(5) && FlightScene.isChainMilestone(20))
        #expect(!FlightScene.isChainMilestone(1) && !FlightScene.isChainMilestone(4) && !FlightScene.isChainMilestone(12))
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
            let vis = SceneTests.duo.visibleRect
            #expect(abs(p.x - 952 * 0.30) < 0.01)
            // Never in the top 22 % (the HUD band, REVIEW-1 P0-5).
            #expect(p.y >= vis.minY && p.y <= vis.minY + vis.height * 0.78 + 0.5)
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

    /// The Perfect punch-in / full-speed pull-out scale the world around the bird, which stays put.
    @Test func displayScaleIsCentredOnTheBird() {
        var cam = SceneCamera(layout: SceneTests.duo)
        let bird = CGPoint(x: 3000, y: 240)
        cam.snap(bird: bird, water: 0)
        let before = cam.screenPoint(bird)
        let z0 = cam.zoom
        cam.setDisplayScale(1.03)
        let after = cam.screenPoint(bird)
        #expect(abs(after.x - before.x) < 0.001 && abs(after.y - before.y) < 0.001)
        #expect(abs(cam.zoom - z0 * 1.03) < 0.0001)
        cam.setDisplayScale(5)
        #expect(cam.displayScale <= 1.1)
    }

    /// R5b: Home's attract bird stays under the wordmark (the camera's ceiling wins over the framing).
    @Test func cameraCeilingKeepsTheBirdUnderHomeText() {
        let vis = SceneTests.duo.visibleRect
        let ceiling = Double(vis.minY + vis.height * 0.38)
        for altitude in [0.0, 200, 500, 900] {
            var cam = SceneCamera(layout: SceneTests.duo)
            cam.birdCeiling = ceiling
            let bird = CGPoint(x: 1000, y: altitude)
            cam.snap(bird: bird, water: 0)
            for _ in 0..<240 { cam.update(bird: bird, water: 0, dt: 1.0 / 120.0) }
            #expect(Double(cam.screenPoint(bird).y) <= ceiling + 0.01)
            #expect(abs(cam.screenPoint(bird).x - 952 * 0.30) < 0.01)
        }
    }

    @Test @MainActor func attractBirdStaysUnderTheWordmark() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        driver.snap.mode = .attract
        // A wordmark block at y 260…360 (view points, y down) on the bird page.
        scene.homeTextRects = [CGRect(x: 32, y: 260, width: 420, height: 100)]
        guard let ceiling = scene.attractBirdCeiling() else {
            #expect(Bool(false))
            return
        }
        #expect(abs(ceiling - (670 - 360 - FlightScene.attractClearance)) < 0.5)
        var now: TimeInterval = 90
        for _ in 0..<240 {
            scene.update(now)
            now += 1.0 / 120.0
            #expect(scene.birdCanvasPoint.y <= ceiling + 0.5)
        }
        // Outside attract, no ceiling.
        driver.snap.mode = .flight
        scene.update(now)
        #expect(scene.birdCanvasPoint.y > 0)
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
        // QA-1 P1-6: the sea surface is cached, not rebuilt every frame.
        #expect(scene.seaRebuilds < 350 / 3)
    }

    /// ART-S6/S7/S15: caught, the storm sweeps past the fold band (≥ 0.6 w), the sun dims by about half; in flight
    /// its edge never rests inside the fold band.
    @Test @MainActor func caughtStormSweepsPastTheFold() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        driver.snap.stormX = -150
        var now: TimeInterval = 20
        for _ in 0..<120 {
            scene.update(now)
            now += 1.0 / 120.0
            let e = scene.stormEdgeU
            #expect(e < 447 || e > 503)
        }
        driver.snap.phase = .caught(elapsed: 0)
        for _ in 0..<240 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.stormEdgeU >= 952 * 0.6)
        #expect(scene.sunBrightness <= 0.55)
    }

    /// UX-S1: the bird's screen point reaches the App at most 30 times a second, and sits at 30 % of the width.
    @Test @MainActor func birdPointIsReportedAtThirtyHertz() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var calls = 0
        var last = CGPoint.zero
        scene.onBirdPoint = { p in
            calls += 1
            last = p
        }
        var now: TimeInterval = 5
        for _ in 0..<120 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(calls >= 20 && calls <= 31)
        #expect(abs(last.x - 952 * 0.30) < 1)
        #expect(abs(scene.birdCanvasPoint.x - 952 * 0.30) < 1)
    }

    /// UX-S3: the title morph runs for 0.6 s and hands over to the play bird.
    @Test @MainActor func titleMorphHandsOverToThePlayBird() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        scene.playTitleMorph(tuck: 0)
        #expect(scene.morphProgress == 0)
        var now: TimeInterval = 1
        for _ in 0..<36 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.morphProgress > 0.3 && scene.morphProgress < 1)
        for _ in 0..<60 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.morphProgress == 1)
    }

    /// QA-2 P2-2: a close, fast storm whose chop zone is off screen does not force sea rebuilds.
    @Test @MainActor func closeStormDoesNotForceSeaRebuilds() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        driver.snap.speed = 1500
        driver.snap.stormX = -1200
        driver.stormSpeed = 1500
        var now: TimeInterval = 30
        for _ in 0..<240 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.seaRebuilds <= 10)
    }

    /// REVIEW-1 P0-7: at the pass (and 0.25 s later, when the frames are frozen) the lighthouse is on screen beside the
    /// bird.
    @Test @MainActor func lighthouseIsOnScreenAtThePass() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        let lx = Lighthouses.x(index: 0)
        driver.snap.phase = .flying
        driver.snap.speed = 2000
        driver.snap.position = CGPoint(x: lx - 1500, y: 200)
        driver.snap.stormX = lx - 4000
        driver.snap.nextLighthouseX = lx
        var now: TimeInterval = 50
        var passed = false
        for _ in 0..<150 {
            if !passed && Double(driver.snap.position.x) >= lx {
                passed = true
                driver.snap.lighthousesPassed = 1
                driver.snap.nextLighthouseX = Lighthouses.x(index: 1)
                driver.pending = [.lighthouse(index: 0, name: "Gull Point")]
            }
            scene.update(now)
            now += 1.0 / 120.0
            if Double(driver.snap.position.x) >= lx - 400 && Double(driver.snap.position.x) <= lx + 600 {
                let u = scene.lighthouseU
                #expect(u != nil)
                if let u = u { #expect(u > 0 && u < 952) }
            }
        }
        #expect(passed)
    }

    /// The Perfect's FX keep moving through the App's hit-stop (the same snapshot for 35 ms) and its punch-in shows.
    @Test @MainActor func perfectPunchesInThroughAHitStop() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 10
        for _ in 0..<30 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        driver.pending = [.touchdown(.perfect, speed: 1400, chain: 3)]
        driver.hold = true
        var peak: CGFloat = 1
        for _ in 0..<6 {
            scene.update(now)
            now += 1.0 / 120.0
            peak = max(peak, scene.displayScale)
        }
        driver.hold = false
        for _ in 0..<12 {
            scene.update(now)
            now += 1.0 / 120.0
            peak = max(peak, scene.displayScale)
        }
        #expect(peak > 1.01)
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
    /// A hit-stop: hand back the same snapshot.
    var hold = false
    /// The storm's speed while flying (pt/s).
    var stormSpeed: Double = 700

    func advance(dt: TimeInterval, now: TimeInterval) -> (FlightSnapshot, [FlightEvent]) {
        if hold {
            let e = pending
            pending = []
            return (snap, e)
        }
        snap.time += dt
        if snap.phase == .flying {
            let vx = max(snap.speed, 300)
            snap.position.x += CGFloat(vx * dt)
            let water = sea?.height(at: Double(snap.position.x)) ?? 0
            snap.position.y = CGFloat(water + (snap.skimming ? 0 : 140))
            snap.velocity = CGVector(dx: vx, dy: 0)
            snap.stormX += stormSpeed * dt
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
