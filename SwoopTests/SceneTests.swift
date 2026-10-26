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

    // MARK: Round 6: the storm cloud (a noise texture, not lobes)

    /// Made once for the cloud tests (≈ 0.15 M pixels).
    static let cloudField = SceneStormCloud.makeField()

    /// ROUND-6 "the storm": one soft cloud, empty beyond its front and its top (no hard cut at the sprite's edges),
    /// solid inside, its shelf's front at `edgeX`.
    @Test func stormCloudIsSoftAndEndsAtItsFront() {
        let f = SceneTests.cloudField
        let ppp = SceneStormCloud.pixelsPerPoint
        #expect(f.w == Int((SceneStormCloud.width * ppp).rounded()))
        var maxBeyond: Float = 0, maxTop: Float = 0
        for j in 0..<f.h {
            let y = SceneStormCloud.height - (CGFloat(j) + 0.5) / ppp
            for i in 0..<f.w {
                let x = (CGFloat(i) + 0.5) / ppp
                let a = SceneStormCloud.alpha(f, i: i, j: j)
                if x > SceneStormCloud.drawnRight { maxBeyond = max(maxBeyond, a) }
                if y > SceneStormCloud.drawnTop { maxTop = max(maxTop, a) }
            }
        }
        #expect(maxBeyond < 0.004)
        #expect(maxTop < 0.004)
        func alphaAt(_ x: CGFloat, _ y: CGFloat) -> Float {
            SceneStormCloud.alpha(f, i: Int(x * ppp), j: Int((SceneStormCloud.height - y) * ppp))
        }
        // Solid in the body, the shelf's front near `edgeX` at the base, nothing in the clear sky ahead of it.
        #expect(alphaAt(600, 420) > 0.98)
        #expect(alphaAt(SceneStormCloud.edgeX - 60, 220) > 0.5)
        #expect(alphaAt(SceneStormCloud.edgeX + 140, 220) < 0.01)
        #expect(alphaAt(SceneStormCloud.edgeX + 60, 640) < 0.01)
    }

    /// Lit from the sun side: the anvil's top reads at least 1.4× brighter than the dark base (it is weather, not a
    /// row of stones of one value), and the rain curtain hangs under the base.
    @Test func stormCloudIsLitFromAboveAndRainsBelow() {
        let f = SceneTests.cloudField
        let p = ScenePalette.palette(.goldenHour)
        let px = SceneStormCloud.pixels(f, body: p.stormBody, top: p.stormTop, rim: p.stormRim, rain: p.rain)
        #expect(px.count == f.w * f.h * 4)
        let ppp = SceneStormCloud.pixelsPerPoint
        var top: Double = 0, nTop = 0, low: Double = 0, nLow = 0, rain = 0
        for j in 0..<f.h {
            let y = SceneStormCloud.height - (CGFloat(j) + 0.5) / ppp
            for i in 0..<f.w {
                let k = j * f.w + i
                let a = Double(px[k * 4 + 3]) / 255
                if f.depth[k] > 30 && a > 0.5 {
                    let lum = (0.2126 * Double(px[k * 4]) + 0.7152 * Double(px[k * 4 + 1])
                               + 0.0722 * Double(px[k * 4 + 2])) / 255 / a
                    if y > 560 {
                        top += lum
                        nTop += 1
                    } else if y > 200 && y < 330 {
                        low += lum
                        nLow += 1
                    }
                }
                if y < SceneStormCloud.baseY - 20 && y > SceneStormCloud.baseY - 100 && a > 0.08 { rain += 1 }
            }
        }
        #expect(nTop > 100 && nLow > 100)
        if nTop > 0 && nLow > 0 { #expect(top / Double(nTop) > 1.4 * low / Double(nLow)) }
        #expect(rain > 200)
    }

    /// The storm keeps out of the fold band and the HUD on every layout, the mirrored Duo default included, at any
    /// gap; caught, it sweeps past the fold and ends outside the band (ART-FLIGHT-SCHOOL §6, SC5).
    @Test @MainActor func stormNeverDrawsInTheFoldBandOrTheHUD() {
        for layout in [SceneTests.duo, SceneTests.duoMirrored, SceneTests.phone] {
            for stormX in [-9000.0, -3000.0, -800.0, -60.0] {
                let scene = FlightScene(layout: layout)
                let driver = SceneTestsDriver()
                scene.driver = driver
                scene.reset()
                driver.snap.phase = .flying
                driver.snap.stormX = stormX
                driver.stormSpeed = 300
                var now: TimeInterval = 90
                let limit: CGFloat = layout.hasFold ? 447 : layout.size.width * 0.5
                for _ in 0..<120 {
                    scene.update(now)
                    now += 1.0 / 120.0
                    #expect(scene.stormShown)
                    #expect(scene.stormDrawnRightU < limit)
                    #expect(scene.stormTopY <= layout.visibleRect.maxY - SceneLook.stormHUDClearance + 0.5)
                }
            }
        }
        // Caught (mirrored): the edge ends at ≤ 0.40 w from the left on screen, never inside the fold band.
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .caught(elapsed: 0)
        var now: TimeInterval = 5
        for _ in 0..<300 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        let screenEdge = 952 - scene.stormEdgeU
        #expect(screenEdge <= 952 * 0.40)
        #expect(screenEdge < 447 || screenEdge > 503)
    }

    /// ART-FLIGHT-SCHOOL §6: the mirrored Duo default puts the bird at 0.70 w and the sun at 0.20 w, and every u-space
    /// layer (rain, gusts, speed lines, the storm) flips with it, so the rain moves away from the storm.
    @Test @MainActor func mirroredDefaultComposition() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 3
        for _ in 0..<60 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(abs(scene.birdCanvasPoint.x - 952 * 0.70) < 1)
        #expect(abs(scene.sunCanvasPoint.x - 952 * 0.20) < 1)
        #expect(abs(scene.sunCanvasPoint.x - 475) >= 120)
        #expect(scene.uSpaceXScale == -1)
        // Rain runs +u (away from the storm's behind edge): with the flip, leftward on the mirrored screen.
        #expect(SceneLook.rainVX > 0)
        let plain = FlightScene(layout: SceneTests.duo)
        #expect(plain.uSpaceXScale == 1)
    }

    // MARK: Round 6: Flight School's practice sea

    /// SC1: a snapshot with no storm (Core's practice sea) starts in the Morning practice look with no storm drawn;
    /// step 7 rolls the storm in over 2 s to `stormEdgeFar`, names it with one glow, and crossfades to the sky.
    @Test @MainActor func practiceSeaHidesTheStormThenRollsItIn() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        driver.snap.stormX = -1_000_000
        driver.snap.gap = 1_000_000
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 7
        func frames(_ n: Int) {
            for _ in 0..<n {
                scene.update(now)
                now += 1.0 / 120.0
            }
        }
        frames(30)
        #expect(scene.practiceLook == 1)
        #expect(!scene.stormShown)
        let glowsBefore = scene.stormGlows
        scene.rollInStorm()
        frames(60)
        #expect(scene.stormShown)
        #expect(scene.practiceLook < 1 && scene.practiceLook > 0)
        #expect(scene.stormEdgeU < SceneLook.stormEdgeFar)
        frames(120)
        #expect(scene.stormGlows > glowsBefore)
        frames(80)
        #expect(scene.practiceLook == 0)
        #expect(abs(scene.stormEdgeU - SceneLook.stormEdgeFar) < 1)
        #expect(scene.stormDrawnRightU < 447)
        // No catch in school: the edge stays put.
        frames(120)
        #expect(abs(scene.stormEdgeU - SceneLook.stormEdgeFar) < 1)
    }

    /// The App's flag alone also hides the storm (a session starts in the look, with no fade).
    @Test @MainActor func practiceFlagHidesTheStorm() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.practiceSea = true
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 2
        for _ in 0..<10 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.practiceLook == 1)
        #expect(!scene.stormShown)
        scene.practiceSea = false
        for _ in 0..<300 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(scene.practiceLook == 0)
        #expect(scene.stormShown)
    }

    @Test func practicePaletteIsMorningAndBlends() {
        let p = ScenePalette.practice
        #expect(p.zenith == RGBA(hex: 0x3D6FB0) && p.horizon == RGBA(hex: 0xFFE7C2) && p.nearMean == RGBA(hex: 0x2A7392))
        let g = ScenePalette.palette(.goldenHour)
        #expect(ScenePalette.blended(g, p, 0) == g)
        let end = ScenePalette.blended(g, p, 1)
        #expect(abs(end.zenith.r - p.zenith.r) < 1e-9 && abs(end.nearMean.b - p.nearMean.b) < 1e-9)
        let mid = ScenePalette.blended(g, p, 0.5)
        #expect(abs(mid.zenith.g - (g.zenith.g + p.zenith.g) * 0.5) < 1e-9)
    }

    /// SC2: the guides find the sea ahead of the bird: the next downslope (crest → trough), its trough, and the middle
    /// of the next downslope for the landing ring.
    @Test func guidesFindTheSeaAhead() {
        let h: (Double) -> Double = { x in 100 * sin(2 * Double.pi * x / 1000) }
        let d = SceneGuidePlacement.nextDownslope(after: 0, height: h)
        #expect(d != nil)
        if let d = d {
            #expect(abs(d.from - 250) <= 10 && abs(d.to - 750) <= 10)
        }
        if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: 0, height: h) {
            #expect(abs(x - 500) <= 10)
        } else {
            Issue.record("no landing guide")
        }
        // Sliding down a slope already: the ring goes on the next one.
        if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: 400, height: h) {
            #expect(abs(x - 1500) <= 10)
        } else {
            Issue.record("no landing guide")
        }
        if case .openMark(let x) = SceneGuidePlacement.resolve(.openMarkAhead, birdX: 400, height: h) {
            #expect(abs(x - 750) <= 10)
        } else {
            Issue.record("no open mark")
        }
    }

    /// A Perfect in the ghost landing ring bursts it (the guide goes).
    @Test @MainActor func perfectInTheLandingRingBurstsIt() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 4
        scene.update(now)
        scene.guide = .landing(at: Double(driver.snap.position.x) + 100)
        for _ in 0..<40 {
            now += 1.0 / 120.0
            scene.update(now)
        }
        if case .landing = scene.shownGuide {} else { Issue.record("the ring is not up") }
        driver.pending = [.touchdown(.perfect, speed: 1400, chain: 1)]
        now += 1.0 / 120.0
        scene.update(now)
        #expect(scene.shownGuide == .none)
        scene.guide = .foldPathAhead
        now += 1.0 / 120.0
        scene.update(now)
        if case .foldPath(let from, let to) = scene.shownGuide {
            #expect(to > from && from >= Double(driver.snap.position.x) - 1)
        } else {
            Issue.record("no fold path")
        }
    }

    // MARK: Round 6: the lighthouse is the goal

    /// SC4 / N3: the next tower stands on the far horizon from 1.5 km out; at the pass it stands on the sea page and
    /// its beam sweeps down across it (never toward the fold); Reduce Motion has no sweep.
    @Test @MainActor func lighthouseReachedSweepsTheSeaPage() {
        for still in [false, true] {
            let scene = FlightScene(layout: SceneTests.duoMirrored)
            scene.reduceMotion = still
            let driver = SceneTestsDriver()
            scene.driver = driver
            scene.reset()
            let lx = Lighthouses.x(index: 0)
            driver.snap.phase = .flying
            driver.snap.speed = 2000
            driver.snap.stormX = lx - 30_000
            driver.snap.nextLighthouseX = lx
            driver.snap.position = CGPoint(x: lx - 20_000, y: 200)
            var now: TimeInterval = 60
            scene.update(now)
            #expect(scene.lighthouseU == nil)
            driver.snap.position = CGPoint(x: lx - 14_000, y: 200)
            scene.reset()
            for _ in 0..<3 {
                now += 1.0 / 120.0
                scene.update(now)
            }
            if let u = scene.lighthouseU { #expect(abs(u - 952 * SceneLook.lighthouseFarU) < 1) }
            #expect(scene.lighthouseU != nil)
            driver.snap.position = CGPoint(x: lx - 10, y: 200)
            scene.reset()
            for _ in 0..<3 {
                now += 1.0 / 120.0
                scene.update(now)
            }
            driver.snap.lighthousesPassed = 1
            driver.snap.nextLighthouseX = Lighthouses.x(index: 1)
            driver.pending = [.lighthouse(index: 0, name: "Gull Point")]
            var sawBeam = false
            var angles: [CGFloat] = []
            for i in 0..<120 {
                now += 1.0 / 120.0
                scene.update(now)
                if i == 1, let u = scene.lighthouseU { #expect(u >= 952 - (476 - SceneLook.foldArtBand)) }
                if scene.reachedBeamShown {
                    sawBeam = true
                    angles.append(scene.reachedBeamAngle)
                }
            }
            #expect(sawBeam == !still)
            if let first = angles.first, let last = angles.last { #expect(first > last) }
            for a in angles { #expect(a <= SceneLook.reachedBeamFrom + 0.001 && a >= SceneLook.reachedBeamTo - 0.001) }
        }
    }

    // MARK: Round 6: art helpers for the App

    @Test func routeArtCoastHeadlandsAndSnap() {
        let heads: [CGFloat] = [150, 300, 450]
        let plain = RouteArt.coastY(at: 300, headlands: [])
        #expect(abs(RouteArt.coastY(at: 300, headlands: heads) - plain - RouteArt.headlandBulge) < 0.01)
        #expect(abs(RouteArt.coastY(at: 225, headlands: heads) - RouteArt.coastY(at: 225, headlands: [])) < 0.01)
        let land = RouteArt.coastPath(width: 600, headlands: heads).boundingBoxOfPath
        #expect(land.minY <= 0.01 && land.maxY <= RouteArt.coastBase + 22 + 12 + RouteArt.headlandBulge + 0.5)
        let contours = RouteArt.contours(width: 600, headlands: heads)
        #expect(contours.count == 3)
        if let deep = contours.last { #expect(deep.boundingBoxOfPath.minY > RouteArt.coastBase + 100 - 34 - 1) }
        let xs = RouteArt.lighthouseXs(count: 3, spacing: RouteArt.spacingDuo, startX: 900, towardLowerX: true)
        #expect(xs == [750, 600, 450])
        let pin = RouteArt.routePoint(at: 375, headlands: heads)
        #expect(pin.y > RouteArt.coastY(at: 375, headlands: heads))
        #expect(!RouteArt.routePath(headlands: heads, from: 100, to: 420).isEmpty)
        // A lighthouse whose centre would land in the fold band is scrolled out of it.
        let band: ClosedRange<CGFloat> = 447...503
        let centres: [CGFloat] = [470, 620]
        let o = RouteArt.snapOffset(proposed: 0, centres: centres, band: band)
        for c in centres { #expect(!band.contains(c - o)) }
        #expect(abs(o) < 60)
        let clear: [CGFloat] = [300, 600]
        #expect(RouteArt.snapOffset(proposed: 0, centres: clear, band: band) == 0)
        for g in [RouteArt.stormGlyph(size: 40), RouteArt.quayGlyph(size: 26), RouteArt.stormRainTicks(size: 40)] {
            let b = g.boundingBoxOfPath
            #expect(!g.isEmpty && b.minX >= -0.01 && b.minY >= -0.01 && b.maxX <= 40.01 && b.maxY <= 40.01)
        }
    }

    @Test func duoDiagramFoldsLikeABook() {
        let box = CGSize(width: 240, height: 170)
        let flat = DuoDiagramArt.geometry(angle: 180, box: box)
        #expect(abs(flat.phi) < 0.0001)
        #expect(abs(flat.leftPanel[1].x - 0) < 0.01 && abs(flat.rightPanel[1].x - 240) < 0.01)
        let folded = DuoDiagramArt.geometry(angle: 100, box: box)
        let flatW = flat.rightPanel[1].x - flat.rightPanel[0].x
        let foldW = folded.rightPanel[1].x - folded.rightPanel[0].x
        #expect(abs(foldW / flatW - cos(40 * CGFloat.pi / 180)) < 0.01)
        // The near (outer) edges read taller when folded; nothing leaves the box.
        let outer = folded.rightPanel[2].y - folded.rightPanel[1].y
        let spine = folded.rightPanel[3].y - folded.rightPanel[0].y
        #expect(outer > spine)
        for p in folded.leftPanel + folded.rightPanel { #expect(p.y >= 0 && p.y <= 170 && p.x >= 0 && p.x <= 240) }
        // Screens sit inside their panels; the gauge spans 140°.
        #expect(folded.rightScreen[0].x > folded.rightPanel[0].x && folded.rightScreen[1].x < folded.rightPanel[1].x)
        #expect(abs(DuoDiagramArt.gaugeAngle(hinge: 100) - 200 * CGFloat.pi / 180) < 0.0001)
        #expect(abs(DuoDiagramArt.gaugeAngle(hinge: 180) - 340 * CGFloat.pi / 180) < 0.0001)
        #expect(DuoDiagramArt.gaugeAngle(hinge: 60) == DuoDiagramArt.gaugeAngle(hinge: 100))
        let top = DuoDiagramArt.gaugePoint(center: CGPoint(x: 120, y: 200), radius: 74, hinge: 140)
        #expect(abs(top.x - 120) < 0.01 && abs(top.y - 126) < 0.01)
        #expect(!DuoDiagramArt.mittenPath(outerTop: folded.rightPanel[1], outerBottom: folded.rightPanel[2],
                                          outward: 1).isEmpty)
    }

    /// SC8: "you" is one gull path that fits its box and faces the flight direction.
    @Test func youGlyphFitsAndFaces() {
        let rect = CGRect(x: 10, y: 20, width: 32, height: 20)
        let right = BirdArt.youGlyph(facingLeft: false, in: rect)
        let left = BirdArt.youGlyph(facingLeft: true, in: rect)
        for g in [right, left] {
            let b = g.boundingBoxOfPath
            #expect(b.minX >= rect.minX - 0.01 && b.maxX <= rect.maxX + 0.01)
            #expect(b.minY >= rect.minY - 0.01 && b.maxY <= rect.maxY + 0.01)
            #expect(b.width > rect.width * 0.85)
        }
        // The beak leads: right-facing, the rightmost tip; left-facing, mirrored.
        let k = min(rect.width / 1, rect.height / 0.62)
        let ox = rect.midX - k * 0.5, oy = rect.midY - 0.62 * k * 0.5
        #expect(right.contains(CGPoint(x: ox + 0.94 * k, y: oy + 0.335 * k)))
        #expect(left.contains(CGPoint(x: ox + 0.06 * k, y: oy + 0.335 * k)))
        #expect(!right.contains(CGPoint(x: ox + 0.06 * k, y: oy + 0.335 * k)))
        // Body and wing are filled (one shape, not a hole where they overlap).
        #expect(right.contains(CGPoint(x: ox + 0.45 * k, y: oy + 0.30 * k)))
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
