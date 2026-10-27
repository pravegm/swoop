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
    /// step 7 rolls the storm in over 2 s to `rollInEdge` (0.20 w, R9), names it with one glow, and crossfades to the sky.
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
        #expect(abs(scene.stormEdgeU - SceneLook.rollInEdge * 952) < 1)
        #expect(scene.stormDrawnRightU < 447)
        // No catch in school: the edge stays put.
        frames(120)
        #expect(abs(scene.stormEdgeU - SceneLook.rollInEdge * 952) < 1)
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
        // R12: the ring sits `ringSlopeFraction` (0.35) of the way down the downslope (R9: the middle).
        let k = SceneLook.ringSlopeFraction
        if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: 0, height: h) {
            #expect(abs(x - (250 + 500 * k)) <= 10)
        } else {
            Issue.record("no landing guide")
        }
        // Sliding down a slope already: the ring goes on the next one.
        if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: 400, height: h) {
            #expect(abs(x - (1250 + 500 * k)) <= 10)
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

    // MARK: Round 9: the guide gull (SR1)

    static let sine: (Double) -> Double = { x in 100 * sin(2 * Double.pi * x / 1000) }

    /// Each move's stand-in flight: in time order, starting ahead of the bird, with the move's tuck curve.
    @Test func ghostFlightsFlyEachMove() {
        let h = SceneTests.sine
        let dive = SceneGhostFlight.synthesize(.dive, birdX: 0, lead: 300, ringX: nil, height: h)
        #expect(dive.count > 10)
        if let first = dive.first, let last = dive.last {
            #expect(first.x >= 299 && abs(last.x - 750) < 12 && last.tuck == 1)
        }
        for i in stride(from: 1, to: dive.count, by: 1) {
            #expect(dive[i].t > dive[i - 1].t && dive[i].x >= dive[i - 1].x)
        }

        let soar = SceneGhostFlight.synthesize(.soar, birdX: 0, lead: 300, ringX: nil, height: h)
        #expect(soar.count > 10)
        #expect(soar.contains { $0.y > h($0.x) + 20 })
        if let first = soar.first { #expect(first.tuck > 0.9 && abs(first.x - 750) < 12) }
        #expect(soar.contains { $0.tuck < 0.2 })

        let land = SceneGhostFlight.synthesize(.land, birdX: 0, lead: 300, ringX: 500, height: h)
        if let last = land.last { #expect(abs(last.x - 500) < 0.01 && abs(last.y - h(500)) < 0.01) }
        #expect(land.contains { $0.y > h($0.x) + 50 })

        let rhythm = SceneGhostFlight.synthesize(.rhythm, birdX: 0, lead: 300, ringX: nil, height: h)
        #expect(rhythm.contains { $0.tuck > 0.8 } && rhythm.contains { $0.tuck < 0.2 })

        let path = [SceneGhostSample(t: 0, x: 0, y: 0, tuck: 0), SceneGhostSample(t: 1, x: 100, y: 50, tuck: 1)]
        if let mid = SceneGhostFlight.sample(path, at: 0.5) {
            #expect(abs(mid.x - 50) < 0.001 && abs(mid.y - 25) < 0.001 && abs(mid.tuck - 0.5) < 0.001)
        }
    }

    /// The ghost flies ahead of the bird (the camera making room), then hands over exactly once.
    @Test @MainActor func guideGullFliesAheadThenHandsOver() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 3
        scene.update(now)
        var finished = 0
        scene.onGhostFinished = { finished += 1 }
        scene.playGhost(.dive)
        #expect(scene.ghostActive)
        for _ in 0..<60 {
            now += 1.0 / 120.0
            scene.update(now)
        }
        #expect(scene.ghostScreenPoint != nil)
        // Mirrored: ahead is to the left.
        if let g = scene.ghostScreenPoint { #expect(g.x < scene.birdScreenPoint.x) }
        #expect(scene.cameraBias > 50)
        for _ in 0..<720 {
            now += 1.0 / 120.0
            scene.update(now)
        }
        #expect(finished == 1)
        #expect(!scene.ghostActive)
        #expect(scene.ghostScreenPoint == nil)
    }

    /// The App can drive the ghost frame by frame (Core's path); clearing it hands over once.
    @Test @MainActor func appDrivenGuideGullHandsOver() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 2
        var finished = 0
        scene.onGhostFinished = { finished += 1 }
        for i in 0..<60 {
            let x = Double(driver.snap.position.x) + 400 + Double(i) * 8
            scene.guideGhost = SceneGhostPose(x: x, y: 260, tuck: 1, bodyAngle: nil, move: .dive, landed: i == 59)
            scene.update(now)
            now += 1.0 / 120.0
        }
        // R12 P1-6: the ghost flies while driven, and reports a screen point exactly while it is drawn (wholly on
        // screen, ahead of or level with the bird); this path runs up to ~870 pt ahead, off the Duo's leading edge.
        let active = scene.ghostActive
        let shown = scene.ghostShown
        let point = scene.ghostScreenPoint
        #expect(active)
        #expect((point != nil) == shown)
        #expect(SceneGhostMove(name: "land") == .land && SceneGhostMove(name: "fly") == nil)
        scene.guideGhost = nil
        scene.update(now)
        #expect(finished == 1)
        #expect(!scene.ghostActive)
    }

    // MARK: Round 9: water cues and the ring (SR2, SR3)

    /// The fold zone paints solid behind a folded bird and finishes with a bead; flown open, the rest greys out.
    @Test @MainActor func foldZonePaintsTheProgress() {
        let g = SceneGuides()
        let h: (Double) -> Double = { x in -0.3 * x }
        g.show(.foldPath(from: 0, to: 1000))
        for i in 0..<120 {
            let x = Double(i) * 10
            g.update(dt: 1.0 / 60.0, time: Double(i) / 60, zoom: 1, originX: 0, birdX: x, birdY: h(x), tuck: 1,
                     height: h)
        }
        if let p = g.foldPaint.first {
            #expect(p.done && !p.missed)
            #expect(abs(p.painted - 850) < 0.5)
        } else {
            Issue.record("no fold zone")
        }
        g.show(.foldPath(from: 2000, to: 3000))
        for i in 0..<100 {
            let x = 2000 + Double(i) * 10
            g.update(dt: 1.0 / 60.0, time: Double(i) / 60, zoom: 1, originX: 0, birdX: x, birdY: h(x),
                     tuck: x < 2400 ? 1 : 0, height: h)
        }
        if let p = g.foldPaint.first {
            #expect(p.missed && !p.done)
            #expect(p.painted < 2401)
        } else {
            Issue.record("no fold zone")
        }
        g.show(.rhythm(swells: [SceneSwell(from: 0, to: 500), SceneSwell(from: 1000, to: 1500)]))
        g.update(dt: 1.0 / 60.0, time: 0, zoom: 1, originX: 0, birdX: 0, birdY: 0, tuck: 1, height: h)
        #expect(g.foldPaint.count == 2)
    }

    /// The ring: a Perfect in it lands; a miss fades it and asks for a respawn ahead.
    @Test @MainActor func landingRingLandsOrRespawns() {
        let g = SceneGuides()
        let flat: (Double) -> Double = { _ in 0 }
        func frames(_ n: Int, birdX: Double) {
            for i in 0..<n {
                g.update(dt: 1.0 / 60.0, time: Double(i) / 60, zoom: 1, originX: 0, birdX: birdX, birdY: 200, tuck: 0,
                         height: flat)
            }
        }
        g.show(.landing(at: 1000))
        frames(30, birdX: 500)
        #expect(g.ringCenter != nil)
        #expect(g.perfectLanded(at: 1060, zoom: 1) == 1000)
        g.show(.landing(at: 1000))
        frames(30, birdX: 500)
        g.missedRing(birdX: 900, zoom: 1)
        frames(30, birdX: 900)
        #expect(g.ringCenter == nil)
        #expect(g.ringNeedsRespawn)
        g.respawnRing(at: 2000)
        frames(2, birdX: 900)
        #expect(g.ringCenter.map { abs($0.x - 2000) < 0.01 } == true)
    }

    @Test func bookGlyphFoldsVisibly() {
        let open = SceneGuides.bookPath(angle: 170).boundingBoxOfPath
        let shut = SceneGuides.bookPath(angle: 110).boundingBoxOfPath
        #expect(shut.width < open.width * 0.8)
        #expect(shut.height > open.height)
        let tucked = DuoDiagramArt.displayPhi(angle: 122) * 180 / CGFloat.pi
        let expected: CGFloat = 46.4
        #expect(abs(tucked - expected) < 0.5)
        #expect(SceneGuides.bookAngle(time: 0.5, closing: true, still: true) == 110)
        #expect(SceneGuides.bookAngle(time: 0.75, closing: true, still: false) < 111)
    }

    // MARK: Round 9: caught, practice, trail, camera (SR4–SR6)

    /// ART-ROUND-9 §2: caught, the front passes the bird and covers 90 % of the width in 1.2 s, with one bolt ahead.
    @Test @MainActor func caughtStormOvertakesTheBird() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        driver.snap.stormX = -2000
        var now: TimeInterval = 8
        for _ in 0..<60 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        let strikes = scene.stormStrikes
        driver.snap.phase = .caught(elapsed: 0)
        for _ in 0..<160 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        let covered: CGFloat = 952 * 0.9
        #expect(scene.stormEdgeU >= covered - 1)
        #expect(scene.stormStrikes > strikes)
        #expect(scene.stormTopY <= SceneTests.duoMirrored.visibleRect.maxY - SceneLook.stormHUDClearance + 0.5)
    }

    /// Defect #5: school is never caught and shows no storm, rain or dimmed sun, whatever the phase.
    @Test @MainActor func schoolShowsNoStormEvenWhenCaught() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.practiceSea = true
        scene.reset()
        driver.snap.phase = .caught(elapsed: 1)
        driver.snap.stormX = -100
        var now: TimeInterval = 4
        for _ in 0..<120 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        #expect(!scene.stormShown)
        #expect(scene.sunBrightness == 1)
    }

    /// Defect #29: a jump of the bird starts a new trail strand (no straight "contrail").
    @Test @MainActor func trailBreaksOnAJump() {
        let b = SceneBirdView()
        b.updateTrail(emit: .zero, show: true, time: 0, zoom: 1, speedK: 0, goldK: 0, tailwind: false)
        b.updateTrail(emit: CGPoint(x: 10, y: 0), show: true, time: 0.01, zoom: 1, speedK: 0, goldK: 0, tailwind: false)
        #expect(b.trailPointCount == 2)
        b.updateTrail(emit: CGPoint(x: 5000, y: 0), show: true, time: 0.02, zoom: 1, speedK: 0, goldK: 0,
                      tailwind: false)
        #expect(b.trailPointCount == 1)
    }

    /// SR5: the practice camera keeps the bird in 35–70 % and the horizon inside the top, even in a deep trough.
    @Test func practiceCameraKeepsTheHorizon() {
        var cam = SceneCamera(layout: SceneTests.duo)
        cam.practiceFraming = true
        cam.snap(bird: CGPoint(x: 0, y: 0), water: 0)
        let hv = cam.visibleHeight
        let y0 = Double(cam.screenPoint(CGPoint(x: 0, y: 0)).y) - cam.visibleMinY
        #expect(y0 >= 0.35 * hv - 0.5 && y0 <= 0.70 * hv + 0.5)
        cam.snap(bird: CGPoint(x: 0, y: -300), water: -300)
        let horizon = cam.meanWaterScreenY + 34 + 18 * cam.zoom
        #expect(horizon <= cam.visibleMinY + 0.85 * hv + 0.5)
        let y1 = Double(cam.screenPoint(CGPoint(x: 0, y: -300)).y) - cam.visibleMinY
        #expect(y1 >= 0.12 * hv - 0.5)
    }

    /// SR1/SR3: the look-ahead bias and the zoom cap; defect #3: Home's water stays under the menu.
    @Test func cameraBiasZoomCapAndWaterCeiling() {
        var cam = SceneCamera(layout: SceneTests.duoMirrored)
        let base = cam.anchorX
        cam.biasTarget = 150
        cam.snap(bird: .zero, water: 0)
        #expect(abs(cam.anchorX - (base + 150)) < 0.001)
        var plain = SceneCamera(layout: SceneTests.duo)
        let plainBase = plain.anchorX
        plain.biasTarget = 150
        plain.snap(bird: .zero, water: 0)
        #expect(abs(plain.anchorX - (plainBase - 150)) < 0.001)
        plain.zoomCap = 0.78
        #expect(abs(plain.targetZoom(altitude: 1) - 0.78) < 0.0001)
        var home = SceneCamera(layout: SceneTests.duo)
        home.waterCeiling = 100
        home.snap(bird: .zero, water: 0)
        let ground = Double(home.screenPoint(.zero).y)
        #expect(ground <= 100 - 40 * home.zoom + 0.5)
    }

    // MARK: Round 10: the recoil and the peaks

    /// ROUND-10 P0-1: the recoil waits for the gust, shoves fast, holds, then eases back.
    @Test func recoilEnvelopeShovesThenEasesBack() {
        #expect(FlightScene.recoil(age: 0.1) == 0)
        #expect(FlightScene.recoil(age: 0.25) > 0.6)
        #expect(FlightScene.recoil(age: 0.8) == 1)
        let late = FlightScene.recoil(age: 2.0)
        #expect(late > 0 && late < 1)
        #expect(FlightScene.recoil(age: 3.0) == 0)
    }

    /// In the school's storm step a Perfect visibly shoves the wall back (≥ 140 pt), fires the recoil peak once, then
    /// the wall returns.
    @Test @MainActor func schoolPerfectShovesTheStormBack() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        driver.snap.stormX = -1_000_000
        driver.snap.gap = 1_000_000
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 5
        var peaks: [ScenePeak] = []
        scene.onPeak = { peaks.append($0) }
        func frames(_ n: Int) {
            for _ in 0..<n {
                scene.update(now)
                now += 1.0 / 120.0
            }
        }
        frames(10)
        scene.rollInStorm()
        frames(300)
        let rest = scene.stormEdgeU
        let expected: CGFloat = SceneLook.rollInEdge * 952
        #expect(abs(rest - expected) < 1)
        driver.pending = [.touchdown(.perfect, speed: 1400, chain: 1)]
        frames(72)
        #expect(scene.stormEdgeU <= rest - 140)
        #expect(scene.stormRecoil > 0.9)
        #expect(peaks.contains(.recoil) && peaks.contains(.perfect))
        frames(360)
        #expect(abs(scene.stormEdgeU - rest) < 1)
        #expect(peaks.filter { $0 == .recoil }.count == 1)
    }

    /// ROUND-10 P1-5: the catch's peak fires once, as the front crosses over the bird.
    @Test @MainActor func catchPeakFiresAsTheFrontCrossesTheBird() {
        let scene = FlightScene(layout: SceneTests.duo)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 6
        var peaks: [ScenePeak] = []
        scene.onPeak = { peaks.append($0) }
        for _ in 0..<30 {
            scene.update(now)
            now += 1.0 / 120.0
        }
        driver.snap.phase = .caught(elapsed: 0)
        var edgeAtPeak: CGFloat?
        for _ in 0..<200 {
            scene.update(now)
            now += 1.0 / 120.0
            if scene.momentPeak == .caught { edgeAtPeak = scene.stormEdgeU }
        }
        #expect(peaks.filter { $0 == .caught }.count == 1)
        let birdU: CGFloat = 952 * 0.30
        if let e = edgeAtPeak { #expect(e >= birdU && e < birdU + 120) } else { Issue.record("no catch peak") }
    }

    // MARK: Round 9: the Route reads left to right

    @Test func routeArtReadsLeftToRight() {
        let xs = RouteArt.lighthouseXs(count: 3, spacing: 150)
        let want: [CGFloat] = [150, 300, 450]
        #expect(xs == want)
        let heads: [CGFloat] = [150, 300, 450]
        let base = RouteArt.coastBaseDuo
        let plain = RouteArt.coastY(at: 300, headlands: [], base: base)
        #expect(abs(RouteArt.coastY(at: 300, headlands: heads, base: base) - plain - RouteArt.pointBulge) < 0.01)
        // Every lighthouse stands on a point: seaward of the coast around it.
        for x in heads {
            let tip = RouteArt.coastY(at: x, headlands: heads, base: base)
            #expect(tip > RouteArt.coastY(at: x - 70, headlands: heads, base: base))
            #expect(tip > RouteArt.coastY(at: x + 70, headlands: heads, base: base))
        }
        let labels = [CGRect(x: 100, y: 248, width: 120, height: 36), CGRect(x: 180, y: 248, width: 120, height: 36),
                      CGRect(x: 420, y: 248, width: 80, height: 36)]
        let laid = RouteArt.labelRows(labels)
        for i in 0..<laid.count {
            for j in (i + 1)..<laid.count { #expect(!laid[i].intersects(laid[j])) }
        }
        let row: CGFloat = 248
        #expect(laid[0].minY == row && laid[2].minY == row && laid[1].minY > row)
        let o = RouteArt.focusOffset(index: 2, spacing: 150, viewWidth: 500)
        let focus: CGFloat = 150
        #expect(abs(o - focus) < 0.001)
        let g = DuoDiagramArt.geometry(angle: 122, box: CGSize(width: 96, height: 64), exaggerated: true)
        #expect(abs(g.phi - DuoDiagramArt.displayPhi(angle: 122)) < 0.0001)
    }

    // MARK: Round 11: the storm has no straight edges (ROUND-11 P0-1)

    /// Every soft span ends in a smoothstep ramp ≥ 300 pt, its coverage never jumps on the canvas (no more than the
    /// ramp's own slope between neighbouring points), and its body runs off the canvas edge it reaches toward.
    @Test func stormTintSpansHaveNoEdges() {
        let w: CGFloat = 952
        for e in stride(from: CGFloat(-400), through: CGFloat(1300), by: 37) {
            let fall = SceneStormTint.falling(clearAt: e + 428, ramp: 120)
            #expect(fall.rampWidth >= SceneStormTint.minRamp - 0.001)
            #expect(fall.bodyLo <= -SceneStormTint.overscan + 0.001)
            #expect(abs(fall.bodyHi - fall.rampLo) < 0.0001)
            let fallLimit: CGFloat = 1.5 / fall.rampWidth + 0.002
            #expect(SceneStormTint.maxStep(fall, from: -1, to: w + 1) <= fallLimit)
            let rise = SceneStormTint.rising(startAt: e - 150, ramp: 300, width: w)
            #expect(rise.rampWidth >= SceneStormTint.minRamp - 0.001)
            #expect(rise.bodyHi >= w + SceneStormTint.overscan - 0.001)
            #expect(abs(rise.bodyLo - rise.rampHi) < 0.0001)
            let riseLimit: CGFloat = 1.5 / rise.rampWidth + 0.002
            #expect(SceneStormTint.maxStep(rise, from: -1, to: w + 1) <= riseLimit)
        }
        let s = SceneStormTint.falling(clearAt: 600, ramp: 400)
        #expect(abs(s.coverage(atU: 100) - 1) < 0.0001)
        #expect(abs(s.coverage(atU: 700)) < 0.0001)
        #expect(abs(s.coverage(atU: 400) - 0.5) < 0.001)
        // A narrower minimum is allowed for the cloud's backing (it ramps out under the cloud's body).
        let b = SceneStormTint.falling(clearAt: 100, ramp: 60, minimum: 1)
        #expect(abs(b.rampWidth - 60) < 0.0001)
    }

    /// A span's body and ramp textures meet exactly: the ramp's seam column is the body's colour, its far column empty.
    @Test func stormRampPixelsMatchTheirBodies() {
        let profile = SceneStormTint.bandProfile(rows: 64)
        let body = SceneStormTint.pixels(profile: profile, rows: 64, columns: 4, ramp: .flat)
        let fall = SceneStormTint.pixels(profile: profile, rows: 64, columns: 128, ramp: .falling)
        let rise = SceneStormTint.pixels(profile: profile, rows: 64, columns: 128, ramp: .rising)
        #expect(body.count == 64 * 4 * 4 && fall.count == 64 * 128 * 4)
        for j in 0..<64 {
            let a = Int(body[(j * 4) * 4 + 3])
            #expect(abs(Int(fall[(j * 128) * 4 + 3]) - a) <= 1)
            #expect(Int(fall[(j * 128 + 127) * 4 + 3]) <= 1)
            #expect(abs(Int(rise[(j * 128 + 127) * 4 + 3]) - a) <= 1)
            #expect(Int(rise[(j * 128) * 4 + 3]) <= 1)
        }
        // The band is soft at its top and bottom, full in the middle.
        #expect(profile[3] < 8 && profile[63 * 4 + 3] < 8 && profile[32 * 4 + 3] > 240)
        let white = SceneStormTint.whiteProfile(rows: 2)
        let allWhite = white.allSatisfy { $0 == 255 }
        #expect(white.count == 8 && allWhite)
    }

    /// The cloud texture is empty along all four borders (no sprite edge can show, at any stretch), and its backing
    /// profile is soft (no row step a stretch could turn into a streak), premultiplied, and empty at its top and bottom.
    @Test func stormCloudHasNoHardBorderAndASoftBacking() {
        let f = SceneTests.cloudField
        var border: Float = 0
        for i in 0..<f.w {
            border = max(border, SceneStormCloud.alpha(f, i: i, j: 0), SceneStormCloud.alpha(f, i: i, j: f.h - 1))
        }
        for j in 0..<f.h {
            border = max(border, SceneStormCloud.alpha(f, i: 0, j: j), SceneStormCloud.alpha(f, i: f.w - 1, j: j))
        }
        #expect(border < 0.01)
        #expect(SceneStormCloud.leftFadeK(x: 0) < 0.0001)
        #expect(SceneStormCloud.leftFadeK(x: Float(SceneStormCloud.leftFade)) > 0.9999)
        let p = ScenePalette.palette(.goldenHour)
        let px = SceneStormCloud.pixels(f, body: p.stormBody, top: p.stormTop, rim: p.stormRim, rain: p.rain)
        var col0 = 0
        for j in 0..<f.h { col0 = max(col0, Int(px[(j * f.w) * 4 + 3])) }
        #expect(col0 <= 2)
        let prof = SceneStormCloud.backingProfile(px, w: f.w, h: f.h)
        #expect(prof.count == f.h * 4)
        var worst = 0
        var peak = 0
        for j in 0..<f.h {
            let a = Int(prof[j * 4 + 3])
            peak = max(peak, a)
            for c in 0..<3 { #expect(Int(prof[j * 4 + c]) <= a) }
            if j > 0 { worst = max(worst, abs(a - Int(prof[(j - 1) * 4 + 3]))) }
        }
        #expect(peak > 200)
        #expect(worst <= 16)
        #expect(Int(prof[3]) <= 1 && Int(prof[(f.h - 1) * 4 + 3]) <= 1)
    }

    /// The scene, on the Duo (both orientations) and a phone: at every storm x on the way in and through the catch
    /// sweep, every tint ramp is ≥ 300 pt with no jump on the canvas, the backing starts exactly where the cloud's fade
    /// ends and runs off the behind edge, and once caught the sky shade covers the whole width.
    @Test @MainActor func stormLayersNeverShowAnEdge() {
        func check(_ scene: FlightScene, _ w: CGFloat) {
            for sp in scene.stormTintSpans {
                #expect(sp.rampWidth >= SceneStormTint.minRamp - 0.01)
                let limit: CGFloat = 3 / sp.rampWidth + 0.003
                #expect(SceneStormTint.maxStep(sp, from: -1, to: w + 1, step: 2) <= limit)
            }
            if scene.stormShown, let b = scene.stormBackingSpan {
                #expect(abs(b.rampLo - scene.stormCloudFadeEndU) < 0.05)
                #expect(b.bodyWidth < 0.5 || b.bodyLo <= -SceneStormTint.overscan + 0.01)
            }
        }
        for layout in [SceneTests.duo, SceneTests.duoMirrored, SceneTests.phone] {
            let w = layout.size.width
            let scene = FlightScene(layout: layout)
            let driver = SceneTestsDriver()
            scene.driver = driver
            scene.reset()
            driver.snap.phase = .flying
            driver.snap.stormX = -9000
            driver.stormSpeed = 520 + 2500
            var now: TimeInterval = 30
            for _ in 0..<360 {
                scene.update(now)
                now += 1.0 / 120.0
                check(scene, w)
            }
            #expect(!scene.stormTintSpans.isEmpty)
            driver.snap.phase = .caught(elapsed: 0)
            for _ in 0..<320 {
                scene.update(now)
                now += 1.0 / 120.0
                check(scene, w)
            }
            if let sky = scene.stormSkySpan {
                for u in stride(from: CGFloat(0), through: w, by: 8) { #expect(sky.coverage(atU: u) > 0.999) }
            } else {
                Issue.record("no sky shade once caught")
            }
        }
    }

    /// ROUND-11 P0-6 / P0-7: the storm step's storm is on screen from its first frame (it rolls in from u = 40, not
    /// from off screen), and a school Perfect shoves it back while it stays in view, its layers soft throughout.
    @Test @MainActor func schoolStormShowsFromTheFirstFrameAndRecoilsInView() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        driver.snap.stormX = -1_000_000
        driver.snap.gap = 1_000_000
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 5
        func frames(_ n: Int) {
            for _ in 0..<n {
                scene.update(now)
                now += 1.0 / 120.0
            }
        }
        frames(10)
        #expect(!scene.stormShown)
        scene.rollInStorm()
        frames(1)
        #expect(scene.stormShown)
        #expect(scene.stormEdgeU >= SceneLook.rollInFrom - 1)
        #expect(scene.stormDrawnRightU > 40)
        frames(300)
        driver.pending = [.touchdown(.perfect, speed: 1400, chain: 1)]
        var lowest: CGFloat = 10_000
        var reach: CGFloat = 10_000
        for _ in 0..<120 {
            frames(1)
            lowest = min(lowest, scene.stormEdgeU)
            reach = min(reach, scene.stormDrawnRightU)
            for sp in scene.stormTintSpans { #expect(sp.rampWidth >= SceneStormTint.minRamp - 0.01) }
            if let b = scene.stormBackingSpan {
                #expect(b.bodyWidth < 0.5 || b.bodyLo <= -SceneStormTint.overscan + 0.01)
            }
        }
        let rest: CGFloat = SceneLook.rollInEdge * 952
        #expect(lowest <= rest - 140)
        #expect(lowest > 0)
        #expect(reach > 30)
        #expect(scene.stormRecoil > 0.9)
    }

    // MARK: Round 11: the ring, the headland, the Home trail

    /// ROUND-11 P0-5 (pure): the camera rides the bird higher so a kept point stays ≥ the inset above the bottom, and
    /// `zoomToFit` finds the zoom that puts it inside a safe rect.
    @Test func cameraKeepsTheRingInboard() {
        var cam = SceneCamera(layout: SceneTests.duoMirrored)
        cam.practiceFraming = true
        let ring = CGPoint(x: 600, y: -160)
        cam.keepInView = ring
        cam.keepInset = 200
        cam.snap(bird: CGPoint(x: 0, y: 60), water: -20)
        let p = cam.screenPoint(ring)
        let floorY: Double = cam.visibleMinY + 200 - 0.5
        #expect(Double(p.y) >= floorY)
        let safe = CGRect(x: 200, y: cam.visibleMinY + 200, width: 952 - 400, height: cam.visibleHeight - 320)
        let fit = cam.zoomToFit(ring, inside: safe)
        #expect(fit < 0.8 && fit >= cam.ringFitFloor - 0.0001)
        #expect(safe.contains(cam.previewPoint(ring, framingZoom: fit)))
        var plain = SceneCamera(layout: SceneTests.duo)
        plain.snap(bird: CGPoint(x: 0, y: 60), water: -20)
        #expect(plain.keepLift == 0)
    }

    /// ROUND-11 P0-5 in the scene: in school the live landing ring ahead settles ≥ 200 pt inside the sides and the
    /// bottom of the canvas (clear of Skip, the step dots and the pause button).
    @Test @MainActor func schoolRingSettlesInboard() {
        for layout in [SceneTests.duoMirrored, SceneTests.duo] {
            let scene = FlightScene(layout: layout)
            let driver = SceneTestsDriver()
            driver.snap.stormX = -1_000_000
            driver.snap.gap = 1_000_000
            scene.driver = driver
            scene.practiceSea = true
            scene.reset()
            driver.snap.phase = .flying
            var now: TimeInterval = 3
            for _ in 0..<5 {
                scene.update(now)
                now += 1.0 / 120.0
            }
            scene.guide = .landing(at: Double(driver.snap.position.x) + 1100)
            for _ in 0..<150 {
                scene.update(now)
                now += 1.0 / 120.0
            }
            let safe = scene.ringSafeRect().insetBy(dx: -25, dy: -25)
            if let c = scene.ringCanvasPoint {
                #expect(c.x >= safe.minX && c.x <= safe.maxX)
                #expect(c.y >= safe.minY)
            } else {
                Issue.record("no live ring")
            }
        }
    }

    /// ROUND-11 P0-9: Gull Point's rock is an irregular headland (no vertical side, no level run) whose underwater
    /// part fades out completely, not a translucent slab.
    @Test func lighthouseHeadlandHasNoStraightEdges() {
        let top = SceneHeadland.top
        for i in 1..<top.count {
            #expect(top[i].x > top[i - 1].x)
            #expect(abs(top[i].y - top[i - 1].y) > 0.5)
        }
        let out = SceneHeadland.outline
        for i in 0..<out.count {
            let a = out[i], b = out[(i + 1) % out.count]
            #expect(abs(a.x - b.x) > 1)
        }
        #expect(SceneHeadland.rockFade(y: 0) > 0.99)
        #expect(SceneHeadland.rockFade(y: -70) < 0.001)
        let lowest = out.map { $0.y }.min() ?? 0
        let highest = out.map { $0.y }.max() ?? 0
        #expect(SceneHeadland.rockFade(y: lowest) < 0.001)
        #expect(SceneHeadland.box.minY <= lowest && SceneHeadland.box.maxY >= highest)
        #expect(SceneHeadland.rim.count >= 3)
    }

    /// ROUND-11 P1-11: on Home the trail's older end is trimmed back below the ceiling (never into the text).
    @Test @MainActor func trailCeilingTrimsTheOldEnd() {
        let b = SceneBirdView()
        for i in 0..<6 {
            b.updateTrail(emit: CGPoint(x: CGFloat(i * 10), y: CGFloat(100 - i * 10)), show: true,
                          time: Double(i) * 0.01, zoom: 1, speedK: 0, goldK: 0, tailwind: false)
        }
        #expect(b.trailPointCount == 6)
        b.updateTrail(emit: CGPoint(x: 60, y: 40), show: true, time: 0.06, zoom: 1, speedK: 0, goldK: 0,
                      tailwind: false, ceiling: 65)
        #expect(b.trailPointCount == 3)
    }

    // MARK: Round 12: targets that are really there

    /// A Flight School scene on Core's practice sea, the bird flying at `speed` from sea x `x` (always airborne, so it
    /// never lands in a ring: every ring is flown past).
    @MainActor static func schoolScene(_ layout: ScreenLayout, x: Double,
                                       speed: Double) -> (FlightScene, SceneTestsDriver) {
        let scene = FlightScene(layout: layout)
        let driver = SceneTestsDriver()
        driver.sea = SeaProfile(seed: 7, practice: true)
        driver.stormSpeed = 0
        driver.snap.stormX = -1_000_000
        driver.snap.gap = 1_000_000
        driver.snap.position = CGPoint(x: x, y: 0)
        driver.snap.speed = speed
        driver.snap.phase = .flying
        scene.driver = driver
        scene.practiceSea = true
        scene.reset()
        return (scene, driver)
    }

    /// ROUND-12 P0-2(a) (pure): the WHOLE ring rect (ellipse + drop marker) must sit inside the visible canvas inset
    /// 200 pt at the sides, 160 pt at the bottom and 120 pt at the top; the camera's centre rect guarantees it.
    @Test func ringTargetsKeepTheWholeRectInboard() {
        let duo = SceneTests.duo.visibleRect
        let box = SceneTargets.ringInboardRect(visible: duo)
        let side: CGFloat = 200, bottom: CGFloat = 160
        let width: CGFloat = 952 - 400, height: CGFloat = 670 - 160 - 120
        #expect(abs(box.minX - side) < 0.01 && abs(box.minY - bottom) < 0.01)
        #expect(abs(box.width - width) < 0.01 && abs(box.height - height) < 0.01)
        let c = SceneTargets.ringCentreRect(visible: duo)
        for p in [CGPoint(x: c.minX, y: c.minY), CGPoint(x: c.maxX, y: c.maxY), CGPoint(x: c.midX, y: c.midY)] {
            #expect(box.insetBy(dx: -0.01, dy: -0.01).contains(SceneTargets.ringCanvasRect(center: p)))
        }
        // R11 held only the centre 200 pt in: its ellipse then reached 101 pt from the edge (under Skip, s1-08).
        #expect(!box.contains(SceneTargets.ringCanvasRect(center: CGPoint(x: 201, y: 300))))
        // The rect covers the drop marker above the ring (the App puts its words just above it).
        let r = SceneTargets.ringCanvasRect(center: CGPoint(x: 400, y: 300))
        let top: CGFloat = 300 + SceneLook.dropHeight + SceneLook.dropChevron
        #expect(r.maxY >= top)
        // On the phone's cropped canvas the insets scale with the shorter visible height, and there is still room.
        let phone = SceneTests.phone.visibleRect
        let i = SceneTargets.ringInsets(visible: phone)
        let phoneBottom: CGFloat = phone.height * 0.3
        #expect(abs(i.side - side) < 0.01 && abs(i.bottom - phoneBottom) < 0.01)
        #expect(SceneTargets.ringCentreRect(visible: phone).height > 20)
    }

    /// ROUND-12 P0-1 (pure): a ring is named only ahead of the bird and wholly on screen, and first only once inboard.
    @Test func ringIsNamedOnlyAheadAndOnScreen() {
        let v = SceneTests.duo.visibleRect
        let inboard = SceneTargets.ringCanvasRect(center: CGPoint(x: 476, y: 300))
        let edge = SceneTargets.ringCanvasRect(center: CGPoint(x: 120, y: 300))
        let off = SceneTargets.ringCanvasRect(center: CGPoint(x: 40, y: 300))
        #expect(SceneTargets.reportsRing(ringX: 1000, birdX: 500, rect: inboard, visible: v, wasReported: false))
        // Behind or level with the bird: never, wherever it is drawn.
        #expect(!SceneTargets.reportsRing(ringX: 400, birdX: 500, rect: inboard, visible: v, wasReported: true))
        #expect(!SceneTargets.reportsRing(ringX: 500, birdX: 500, rect: inboard, visible: v, wasReported: true))
        // Cut by the screen edge: never.
        #expect(!SceneTargets.reportsRing(ringX: 1000, birdX: 500, rect: off, visible: v, wasReported: true))
        // On screen but at the edge: not first named there; kept if it already was (no flicker as the camera eases).
        #expect(!SceneTargets.reportsRing(ringX: 1000, birdX: 500, rect: edge, visible: v, wasReported: false))
        #expect(SceneTargets.reportsRing(ringX: 1000, birdX: 500, rect: edge, visible: v, wasReported: true))
    }

    /// ROUND-12 P0-1 (pure): from the bottom of a trough (the storm step starts in one, at 4300) the ring still goes
    /// on the next downslope. R11's search found a 8 pt "downslope" there and gave up, so no ring was placed.
    @Test func landingAheadFindsARingFromATrough() {
        let h: (Double) -> Double = { x in -100 * cos(2 * Double.pi * x / 2000) }
        for bx in [0.0, 2000.0] {
            if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: bx, height: h) {
                let expected = bx + 1000 + 1000 * SceneLook.ringSlopeFraction
                #expect(abs(x - expected) <= 12)
            } else {
                Issue.record("no ring from the trough at \(bx)")
            }
        }
        let sea = SeaProfile(seed: 7, practice: true)
        let ps: (Double) -> Double = { x in sea.height(at: x) }
        let start = Tuning.practiceGuidedTroughX
        if case .landing(let x) = SceneGuidePlacement.resolve(.landingAhead, birdX: start, height: ps) {
            #expect(x > 5300 && x < 6300)
        } else {
            Issue.record("no ring from the storm step's start")
        }
    }

    /// ROUND-12 P0-2(a), s1-08: the land step starts at the launch (2104) with its ring at 3450 and the CI frame holds
    /// at 2650. The ring is named within about half a second, and in the held frame its whole rect is inboard, on the
    /// Duo both ways and on the iPhone.
    @Test @MainActor func landingStepRingIsInboardByTheFrame() {
        for layout in [SceneTests.duoMirrored, SceneTests.duo, SceneTests.phone] {
            let (scene, driver) = SceneTests.schoolScene(layout, x: Tuning.practiceLaunchX, speed: 1113)
            scene.guide = .landing(at: 3450)
            var now: TimeInterval = 7
            var t = 0.0
            var namedAt: Double?
            while Double(driver.snap.position.x) < 2650 && t < 2 {
                scene.update(now)
                now += 1.0 / 120.0
                t += 1.0 / 120.0
                if namedAt == nil && scene.ringScreenRect != nil { namedAt = t }
                if scene.ringScreenRect != nil, let r = scene.ringCanvasRect {
                    #expect(layout.visibleRect.insetBy(dx: -1, dy: -1).contains(r))
                }
            }
            #expect(namedAt.map { $0 <= 0.6 } == true, "mirrored \(layout.mirrored), visible \(layout.visibleRect)")
            // The CI frame is held: the framing settles, with the whole ring rect inside the inset canvas.
            driver.hold = true
            for _ in 0..<240 {
                scene.update(now)
                now += 1.0 / 120.0
            }
            let box = scene.ringInboardRect().insetBy(dx: -1, dy: -1)
            if let r = scene.ringCanvasRect {
                #expect(box.contains(r), "ring \(r) vs \(box)")
            } else {
                Issue.record("no ring")
            }
            #expect(scene.ringInboard)
            #expect(scene.ringScreenRect != nil)
        }
    }

    /// ROUND-12 P0-1, s1-12 / s1-13: in the storm step (from 4300 at 1700 pt/s, never landing) there is always a ring
    /// to name within 1.5 s, a named ring is always ahead of the bird and wholly on screen, and the held frame at sea
    /// x 6300 (the R11 frames, whose ring was behind) names a ring ahead and inboard.
    @Test @MainActor func stormStepAlwaysHasARingAheadToName() {
        for layout in [SceneTests.duoMirrored, SceneTests.duo, SceneTests.phone] {
            let (scene, driver) = SceneTests.schoolScene(layout, x: Tuning.practiceGuidedTroughX + 1, speed: 1700)
            scene.guide = .landingAhead
            var now: TimeInterval = 9
            var t = 0.0
            var lastNamed = 0.0
            var longestGap = 0.0
            var named = 0
            while Double(driver.snap.position.x) < 9700 && t < 5 {
                scene.update(now)
                now += 1.0 / 120.0
                t += 1.0 / 120.0
                if scene.ringScreenRect != nil, let c = scene.ringCanvasPoint, let r = scene.ringCanvasRect {
                    named += 1
                    lastNamed = t
                    let bird = scene.birdCanvasPoint
                    let ahead = layout.mirrored ? c.x < bird.x : c.x > bird.x
                    #expect(ahead, "a named ring behind the bird at t \(t)")
                    #expect(layout.visibleRect.insetBy(dx: -1, dy: -1).contains(r))
                }
                longestGap = max(longestGap, t - lastNamed)
            }
            #expect(named > 0)
            #expect(longestGap <= 1.5, "no ring to name for \(longestGap) s (mirrored \(layout.mirrored))")

            // The held s1-12 frame: frozen at 6300, just past the first ring.
            let (held, heldDriver) = SceneTests.schoolScene(layout, x: Tuning.practiceGuidedTroughX + 1, speed: 1700)
            held.guide = .landingAhead
            var clock: TimeInterval = 20
            var guardFrames = 0
            while Double(heldDriver.snap.position.x) < 6300 && guardFrames < 600 {
                held.update(clock)
                clock += 1.0 / 120.0
                guardFrames += 1
            }
            heldDriver.hold = true
            for _ in 0..<300 {
                held.update(clock)
                clock += 1.0 / 120.0
            }
            #expect(held.ringScreenRect != nil, "the held storm frame names no ring (mirrored \(layout.mirrored))")
            #expect(held.ringInboard)
            if let c = held.ringCanvasPoint {
                let bird = held.birdCanvasPoint
                #expect(layout.mirrored ? c.x < bird.x : c.x > bird.x)
            }
        }
    }

    /// ROUND-12 P0-1: the storm step's ring comes back ahead after a Perfect in it; the land step's does not; a ring
    /// flown past is missed at once (not 1.5 widths + 200 pt later) and asks for the next.
    @Test @MainActor func stormRingComesBackAndPassedRingsGo() {
        let g = SceneGuides()
        let flat: (Double) -> Double = { _ in 0 }
        func frames(_ n: Int, birdX: Double) {
            for i in 0..<n {
                g.update(dt: 1.0 / 60.0, time: Double(i) / 60, zoom: 1, originX: 0, birdX: birdX, birdY: 200, tuck: 0,
                         height: flat)
            }
        }
        g.show(.landing(at: 1000), repeatsRing: true)
        frames(30, birdX: 900)
        #expect(g.perfectLanded(at: 1000, zoom: 1) == 1000)
        #expect(g.ringX == nil)
        frames(30, birdX: 1000)
        #expect(!g.ringNeedsRespawn)
        frames(24, birdX: 1000)
        #expect(g.ringNeedsRespawn)
        g.respawnRing(at: 2400)
        #expect(g.ringX.map { abs($0 - 2400) < 0.01 } == true)

        g.show(.landing(at: 3000))
        frames(30, birdX: 2900)
        #expect(g.perfectLanded(at: 3000, zoom: 1) == 3000)
        frames(90, birdX: 3000)
        #expect(!g.ringNeedsRespawn)
        #expect(g.shown == .none)

        g.show(.landing(at: 5000), repeatsRing: true)
        frames(30, birdX: 4800)
        #expect(g.ringX != nil)
        frames(1, birdX: 5000 + SceneLandingRing.hitReach(zoom: 1) + 1)
        #expect(g.ringX == nil)
        #expect(g.ringCenter == nil)
        frames(30, birdX: 5300)
        #expect(g.ringNeedsRespawn)
    }

    /// ROUND-12 P0-3: where the bird opened too soon in a fold zone, a gold tick marks the wave; a fresh attempt
    /// (back at the crest) clears it.
    @Test @MainActor func earlyOpenIsMarkedOnTheWave() {
        let g = SceneGuides()
        let h: (Double) -> Double = { x in -0.3 * x }
        g.show(.foldPath(from: 0, to: 1000))
        for i in 0..<100 {
            let x = Double(i) * 10
            g.update(dt: 1.0 / 60.0, time: Double(i) / 60, zoom: 1, originX: 0, birdX: x, birdY: h(x),
                     tuck: x < 400 ? 1 : 0, height: h)
        }
        #expect(g.missMarks.count == 1)
        if let m = g.missMarks.first { #expect(abs(m - 400) <= 10.5) }
        g.update(dt: 1.0 / 60.0, time: 2, zoom: 1, originX: 0, birdX: -50, birdY: 0, tuck: 0, height: h)
        #expect(g.missMarks.isEmpty)
    }

    /// ROUND-12 P1-6 (pure): the guide gull shows only wholly on screen, and ahead of or level with the bird.
    @Test func ghostShowsOnlyWhollyOnScreenAndAhead() {
        let v = SceneTests.duo.visibleRect
        let half = SceneTargets.ghostHalfSize(zoom: 0.78)
        #expect(half.width > 40 && half.width < 120)
        let mid = CGPoint(x: 600, y: 300)
        #expect(SceneTargets.ghostShows(center: mid, halfSize: half, visible: v, ghostX: 1400, birdX: 1000))
        // Half off the edge (s1-07): not drawn; touching it: not drawn either.
        #expect(!SceneTargets.ghostShows(center: CGPoint(x: 10, y: 300), halfSize: half, visible: v, ghostX: 1400,
                                         birdX: 1000))
        #expect(!SceneTargets.ghostShows(center: CGPoint(x: half.width, y: 300), halfSize: half, visible: v,
                                         ghostX: 1400, birdX: 1000))
        // Level with the bird is fine; behind it is not.
        #expect(SceneTargets.ghostShows(center: mid, halfSize: half, visible: v, ghostX: 990, birdX: 1000))
        #expect(!SceneTargets.ghostShows(center: mid, halfSize: half, visible: v, ghostX: 900, birdX: 1000))
    }

    /// ROUND-12 P1-6 in the scene: a ghost far ahead (off the edge) or behind the bird is not drawn and has no screen
    /// point; it still flies, and shows once it is wholly on screen ahead.
    @Test @MainActor func guideGullIsNeverCutByTheEdge() {
        let scene = FlightScene(layout: SceneTests.duoMirrored)
        let driver = SceneTestsDriver()
        scene.driver = driver
        scene.reset()
        driver.snap.phase = .flying
        var now: TimeInterval = 4
        func frames(_ n: Int, ahead: Double) {
            for _ in 0..<n {
                let x = Double(driver.snap.position.x) + ahead
                let y = (driver.sea?.height(at: x) ?? 0) + 60
                scene.guideGhost = SceneGhostPose(x: x, y: y, tuck: 0, bodyAngle: 0, move: .soar)
                scene.update(now)
                now += 1.0 / 120.0
            }
        }
        frames(90, ahead: 350)
        #expect(scene.ghostShown)
        #expect(scene.ghostScreenPoint != nil)
        if let g = scene.ghostScreenPoint { #expect(g.x < scene.birdScreenPoint.x) }
        frames(10, ahead: 4000)
        #expect(!scene.ghostShown)
        #expect(scene.ghostScreenPoint == nil)
        frames(10, ahead: -400)
        #expect(!scene.ghostShown)
        #expect(scene.ghostActive)
    }

    /// ROUND-12 P1-7: the school's Gull Point leaves room for its name between its apex and the visible top (on the
    /// iPhone the R11 tower reached the top, so "Gull Point" was drawn through it).
    @Test @MainActor func schoolTowerLeavesRoomForItsName() {
        for layout in [SceneTests.phone, SceneTests.duoMirrored] {
            let (scene, _) = SceneTests.schoolScene(layout, x: 6000, speed: 1700)
            scene.schoolLighthouse = true
            var now: TimeInterval = 11
            for _ in 0..<240 {
                scene.update(now)
                now += 1.0 / 120.0
            }
            if let top = scene.lighthouseTopCanvasPoint, let lamp = scene.lampCanvasPoint {
                #expect(top.y > lamp.y)
                #expect(top.y + SceneLook.towerLabelRoom <= layout.visibleRect.maxY + 0.5)
            } else {
                Issue.record("no school tower")
            }
        }
        let roomy = SceneTargets.schoolTowerScale(nominal: 0.4, baseY: 400, visibleTop: 670)
        #expect(abs(roomy - 0.4) < 0.0001)
        let tight = SceneTargets.schoolTowerScale(nominal: 0.4, baseY: 480, visibleTop: 554)
        let limit: CGFloat = 554.01
        #expect(tight < 0.4)
        #expect(480 + SceneTargets.towerTop * tight + SceneLook.towerLabelRoom <= limit)
        #expect(SceneTargets.schoolTowerScale(nominal: 0.4, baseY: 540, visibleTop: 554) == SceneLook.schoolTowerMinScale)
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
