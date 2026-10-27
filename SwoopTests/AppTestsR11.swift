import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Swoop

// App engineer, Round 11 (design/ROUND-11.md): the seams. Failure says why, the rule before the miss, the side-on
// fold diagram, "Land here" pointing at its ring, a storm step that is never empty, a Perfect that visibly pushes the
// storm (live, not only in the demo freeze), one flight direction everywhere, and the copy / collision / dots pass.

private func r11Canvas(_ w: CGFloat, _ h: CGFloat, fold: Bool, mirrored: Bool = false,
                       insets: EdgeInsets = EdgeInsets()) -> AppCanvas {
    let size = CGSize(width: w, height: h)
    return AppCanvas(size: size, insets: insets, layout: ScreenLayout.make(canvas: size, hasFold: fold,
                                                                           mirrored: mirrored))
}

private let r11Canvases: [AppCanvas] = [
    r11Canvas(951, 669, fold: true),
    r11Canvas(951, 669, fold: true, mirrored: true),
    r11Canvas(874, 402, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r11Canvas(874, 402, fold: false, mirrored: true, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r11Canvas(956, 440, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r11Canvas(667, 375, fold: false),
]

private func r11Run(meters: Double = 12_830, perfects: Int = 11, lighthouses: Int = 2) -> RunResult {
    RunResult(mode: .flight, seed: 7, meters: meters, score: Int(meters) + 25 * perfects, seconds: 300,
              perfects: perfects, goods: 4, splashes: 2, bestChain: 9, tailwinds: 1, lighthouses: lighthouses,
              lastLighthouseName: lighthouses >= 2 ? "Saltlight" : "", cloudTouches: 0, maxSpeed: 1_900,
              maxAltitude: 640, longestCleanMeters: meters / 2, birdID: .gull)
}

private func seaInput(_ t: Double, _ signals: [PracticeSignal] = []) -> SchoolInput {
    SchoolInput(time: t, landscape: true, flying: true, practice: true, signals: signals)
}

struct RoundElevenTests {
    // MARK: P0-7: the Perfect visibly pushes the storm, LIVE

    /// After a school Perfect in the storm step the words are "Perfect pushes it back" by the meter, the big
    /// "Perfect" shows, and the meter's lead has risen (with or without Scene's recoil), with the "+" gap pop.
    @Test func perfectPushesTheStormLive() {
        var st = FlightSchool(touch: false, asksWingCheck: false)
        st.start(at: .storm, time: 0)
        let lead = 0.35
        let before = st.meterLead(lead, recoil: 0)
        #expect(abs(before - lead) < 1e-9)
        #expect(!st.showsGapPop)
        // Live: the machine is stepped (no demo phase), the Perfect arrives as Core's practice signal.
        _ = st.step(seaInput(1.0))
        let out = st.step(seaInput(1.5, [.landed(.perfect)]))
        #expect(out.pushed && !out.succeeded)
        #expect(st.words(at: 1.6)?.text == "Perfect pushes it back")
        #expect(st.words(at: 1.6)?.anchor == .meter)
        #expect(st.bigWord == "Perfect")
        #expect(st.showsGapPop)
        let pushedNoScene = st.meterLead(lead, recoil: 0)
        let pushedRecoil = st.meterLead(lead, recoil: 1)
        #expect(pushedNoScene > before + 0.2)
        #expect(pushedRecoil > before + 0.2)
        // A half-way recoil is a half-way jump; never past the meter's end.
        #expect(abs(st.meterLead(lead, recoil: 0.5) - (lead + 0.15)) < 1e-9)
        #expect(st.meterLead(0.95, recoil: 1) <= 1)
        // The push holds 2.4 s, then the real flight; "Stay ahead" never comes back after it.
        for t in stride(from: 1.6, to: 3.8, by: 0.1) {
            let w = st.words(at: t)?.text
            #expect(w == "Perfect pushes it back", "at \(t): \(w ?? "nil")")
            _ = st.step(seaInput(t))
        }
        #expect(st.step(seaInput(4.0)).finished)
        // Outside the storm step the meter never jumps.
        var land = FlightSchool(touch: false, asksWingCheck: false)
        land.start(at: .land, time: 0)
        #expect(abs(land.meterLead(lead, recoil: 1) - lead) < 1e-9)
        // The "+" sits just ahead of the knob, away from the storm, in both directions.
        let k: CGFloat = 100
        let h: CGFloat = 14
        #expect(LeadMeter.gapPopCenter(knobX: k, barHeight: h, mirrored: false).x > k)
        #expect(LeadMeter.gapPopCenter(knobX: k, barHeight: h, mirrored: true).x < k)
        #expect(LeadMeter.gapPopCenter(knobX: k, barHeight: h, mirrored: false).y < 0)
    }

    #if DEBUG
    /// The R10 s1-13b frame: the storm was never rolled in when the school started at the storm step, and the held
    /// machine never saw the Perfect. Now the storm rolls in from the step (or the rhythm step's success) and the
    /// push frame runs live; the held storm frames stop after the 2 s roll-in.
    @Test func stormPushFrameRunsLive() {
        var st = FlightSchool(touch: false, asksWingCheck: false)
        st.start(at: .storm, time: 0)
        #expect(st.stormRollsIn)
        var r = FlightSchool(touch: false, asksWingCheck: false)
        r.start(at: .rhythm, time: 0)
        #expect(!r.stormRollsIn)
        _ = r.step(seaInput(2, [.waveDone(index: 2)]))
        #expect(r.phase == .praise && r.stormRollsIn)
        #expect(GameController.demoSchoolFreezeX(step: .storm, phase: nil, autopilot: false)! >= 6_000)
        #expect(DemoConfig.parse("school=storm:turn;freezeOn=recoil").freezeOn == .recoil)
    }
    #endif

    // MARK: P0-6: the storm step is never empty

    @Test func stormStepIsNeverEmpty() {
        var st = FlightSchool(touch: true, asksWingCheck: false)
        st.start(at: .storm, time: 0)
        #expect(st.words(at: 0)?.text == "Stay ahead")
        #expect(st.words(at: 0)?.anchor == .meter)
        #expect(FlightSchool.stormWordsAfter == 0)
        // The storm rolls in during the rhythm step's success (Scene's roll takes 2 s).
        #expect(FlightSchoolCopy.praiseSeconds(.rhythm) >= 1.5)
        // P1-10: never "Stay ahead" twice in a row; the second instruction names the ring that is there.
        let later = st.words(at: FlightSchool.stormRingWordsAfter + 0.5)
        #expect(later?.text == "Land in the gold ring" && later?.anchor == .ring)
        #expect(SceneAdapter.guide(for: .storm) == .landingAhead)
        // The held CI frames: 1 = the first frame, 2 / 3 = by the ring.
        var one = FlightSchool(touch: false, asksWingCheck: false)
        one.start(at: .storm, time: 100)
        one.demo(phase: "1", time: 100)
        #expect(one.words(at: 100)?.text == "Stay ahead")
        var two = FlightSchool(touch: false, asksWingCheck: false)
        two.start(at: .storm, time: 100)
        two.demo(phase: "2", time: 100)
        #expect(two.words(at: 100)?.text == "Land in the gold ring")
    }

    // MARK: P0-3: teach the rule before the miss

    @Test func ruleComesBeforeTheMiss() {
        for touch in [false, true] {
            var d = FlightSchool(touch: touch, asksWingCheck: false)
            d.start(at: .dive, time: 0)
            #expect(d.words(at: 0.1)?.text == (touch ? "Hold down the wave" : "Fold down the wave"))
            // After the ghost has shown it: when to open.
            #expect(d.subWords(at: FlightSchool.ghostDemoSeconds + 0.2) == (touch ? "Let go at the bottom"
                                                                              : "Open at the bottom"))
            _ = d.step(seaInput(3, [.diveDone(heldFraction: 0.3)]))
            #expect(d.words(at: 3.1)?.text == (touch ? "Let go too soon" : "Opened too soon"))
            #expect(d.subWords(at: 3.1) == (touch ? "Keep holding to the bottom" : "Stay folded to the bottom"))
            // The rhythm on the first move step too (and still on the rhythm step).
            var w = FlightSchool(touch: touch, asksWingCheck: false)
            w.start(at: .wings, time: 0)
            #expect(w.subWords(at: 0.5) == (touch ? "One hold per wave" : "One fold per wave"))
            var r = FlightSchool(touch: touch, asksWingCheck: false)
            r.start(at: .rhythm, time: 0)
            #expect(r.words(at: 0.5)?.text == (touch ? "One hold per wave" : "One fold per wave"))
            // "Land here" says what the finger / the fold does.
            var l = FlightSchool(touch: touch, asksWingCheck: false)
            l.start(at: .land, time: 0)
            #expect(l.subWords(at: 0.5) == (touch ? "Hold to come down" : "Fold to come down"))
            // Every second line: ≤ 7 words, no full stop.
            for s in [d.subWords(at: 3.1), w.subWords(at: 0.5), l.subWords(at: 0.5)] {
                let text = s ?? ""
                #expect(text.split(separator: " ").count <= 7 && !text.hasSuffix("."))
            }
        }
        // The iPhone's first step says something too.
        var h = FlightSchool(touch: true, asksWingCheck: false)
        h.start(at: .hold, time: 0)
        #expect(h.words(at: 0.2)?.text == "Hold it sideways")
    }

    // MARK: P0-4: the fold diagram shows the fold

    @Test func diagramShowsTheFold() {
        // Open ≈ 170–180°, "fold a little" ≈ 135°: a visibly narrower wedge, the live pose between them.
        let box = WingDiagram.size(compact: true)
        let open = WingDiagram.plates(phi: WingDiagram.displayAngle(hinge: WingDiagram.hinge(forTuck: 0)), size: box)
        let half = WingDiagram.plates(phi: WingDiagram.displayAngle(hinge: WingDiagram.hinge(forTuck: 0.5)), size: box)
        let fold = WingDiagram.plates(phi: WingDiagram.displayAngle(hinge: WingDiagram.hinge(forTuck: 1)), size: box)
        #expect(open.left.y > half.left.y && half.left.y > fold.left.y)
        #expect(fold.hinge.y - fold.left.y > 15)
        #expect(fold.left.y >= 0)
        // The step's words ask for the pose the diagram's target draws.
        var s = FlightSchool(touch: false, asksWingCheck: false)
        s.start(at: .hold, time: 0)
        #expect(s.diagramTarget == 0)
        s.start(at: .wings, time: 0)
        #expect(s.diagramTarget == 1)
        // The done state is the reached pose with a tick (the Studio's praise).
        var d = SchoolDisplay()
        d.step = .wings
        d.praise = FlightSchoolCopy.praise(.wings)
        #expect(SchoolStudioView.showsDoneFold(d))
    }

    // MARK: P0-5: "Land here" points at its ring

    @Test func landHereSitsByItsRing() {
        let c = r11Canvases[1]
        let l = SchoolLayout.make(c)
        let bird = CGPoint(x: 720, y: 360)
        let ring = CGRect(x: 150, y: 380, width: 120, height: 90)
        let p = SchoolRig.wordsCenter(anchor: .ring, bird: bird, canvas: c, layout: l, showsDiagram: false, ring: ring,
                                      hasSub: true)
        let size = SchoolRig.wordsSize(compact: c.isCompact, hasSub: true)
        // Right above the ring's drop marker, centred on it: no pointer needed.
        #expect(abs(p.x - ring.midX) < 1)
        #expect(p.y + size.height / 2 <= ring.minY)
        #expect(ring.minY - (p.y + size.height / 2) < 12)
        #expect(SchoolRig.ringPointer(words: p, size: size, ring: ring) == nil)
        // Words that had to move away point at the ring.
        let far = SchoolRig.ringPointer(words: CGPoint(x: 600, y: 120), size: size, ring: ring)
        #expect(far != nil)
        #expect(far.map { abs($0.to.x - ring.midX) < 0.01 && abs($0.to.y - ring.minY) < 0.01 } == true)
        #expect(SchoolRig.ringPointer(words: p, size: size, ring: nil) == nil)
        // The ring's words are "Land here" from the step's start.
        var s = FlightSchool(touch: false, asksWingCheck: false)
        s.start(at: .land, time: 0)
        #expect(s.words(at: 0)?.text == "Land here" && s.words(at: 0)?.anchor == .ring)
    }

    // MARK: P0-2: failure says why

    @Test func failureSaysWhy() {
        #expect(CaughtLine.text == "The storm caught you")
        #expect(CaughtLine.delay < 1)
        for c in r11Canvases {
            let meter = PlayLayout.make(c).meter
            let s = CaughtLine.size(canvas: c)
            #expect(s.height >= 2 * CaughtLine.fontSize(c.isCompact))
            for bird in [CGPoint(x: c.birdPage.midX, y: c.size.height * 0.55), CGPoint(x: c.birdPage.midX, y: c.size.height * 0.8),
                         CGPoint(x: c.birdPage.minX + 40, y: c.size.height * 0.25)] {
                let p = CaughtLine.center(bird: bird, canvas: c)
                let words = CGRect(x: p.x - s.width / 2, y: p.y - s.height / 2, width: s.width, height: s.height)
                let birdRect = CGRect(x: bird.x - 44, y: bird.y - 44, width: 88, height: 88)
                // On the bird page, under the meter (which stays to show the storm reaching the knob), off the bird.
                #expect(c.birdPage.insetBy(dx: -1, dy: -1).contains(CGPoint(x: words.minX, y: words.midY)))
                #expect(c.birdPage.insetBy(dx: -1, dy: -1).contains(CGPoint(x: words.maxX, y: words.midY)))
                #expect(c.isFoldClear(words))
                #expect(words.minY >= meter.maxY - 0.5 || !words.intersects(meter), "on the meter on \(c.size)")
                #expect(!words.intersects(birdRect), "on the bird on \(c.size) at \(bird)")
            }
        }
        // The Results card repeats the cause in its one line, and keeps it before the tracker strip on a tight card.
        var s = ResultSummary(result: r11Run(), outcome: RecordOutcome(), title: "First flight", dailyDay: nil,
                              practice: false, share: "")
        s.firstRealRun = true
        let line = ResultsHeadline.make(ResultsView.headlineInput(s, today: 300)).lines.first ?? ""
        #expect(line == "The storm caught you 2.2 km before Kestrel Head.")
        let duo = r11Canvases[0]
        let plan = ResultsPlan.make(s, canvas: duo, cardHeight: ResultsLayout.far(duo).height, dailyRowAllowed: true)
        #expect(plan.headlineSub)
        let phone = r11Canvases[5]
        let small = ResultsPlan.make(s, canvas: phone, cardHeight: ResultsLayout.far(phone).height, dailyRowAllowed: true)
        #expect(small.headlineSub || !small.headline)
    }

    // MARK: P1-12: the step dots

    @Test func stepDotsAreSequential() {
        for (touch, asks) in [(false, true), (false, false), (true, false)] {
            var s = FlightSchool(touch: touch, asksWingCheck: asks)
            var dots: [Int] = []
            for step in SchoolStep.allCases {
                if step == .wingCheck && !asks { continue }
                s.start(at: step, time: 0)
                #expect(s.stepCount == 5)
                if s.showsDots { dots.append(s.dotIndex) }
                if step == .wingCheck && asks { #expect(!s.showsDots) }
            }
            #expect(dots == [0, 0, 1, 2, 2, 3, 4], "touch \(touch), check \(asks): \(dots)")
            for i in 1..<dots.count { #expect(dots[i] - dots[i - 1] <= 1) }
        }
    }

    // MARK: P1-11: no text on a sprite or a control

    @Test func textKeepsOffTheBirdAndTheControls() {
        for c in r11Canvases {
            let l = SchoolLayout.make(c)
            let play = PlayLayout.make(c)
            // The chrome: the dots beside Skip, neither on the pause or each other.
            #expect(!l.dots.intersects(l.skip) && !l.dots.intersects(play.pause) && !l.skip.intersects(play.pause))
            // The Studio: the words under the diagram; the attract gull keeps under both (Scene `homeTextRects`).
            #expect(l.prompt.minY >= l.diagram.maxY - 0.5)
            let rects = SchoolStudioView.textRects(l)
            #expect(rects.count == 1 && rects[0].contains(l.diagram) && rects[0].contains(l.prompt))
            #expect(!l.prompt.intersects(l.dots))
            // Home: the block the attract gull keeps under covers the wordmark and the caption's lines.
            let h = HomeLayout.make(c)
            #expect(h.textRects.contains { $0.contains(h.wordmark) })
            #expect(h.textBlock.height >= h.wordmark.height + min(h.caption.height, c.isCompact ? 100 : 150) - 0.5)
            // Home's corner buttons are labelled pills, still on the bird page and clear of each other.
            #expect(h.settings.width >= 100 || h.settings.width >= (c.birdPage.width - HomeLayout.gap) / 2 - 0.5)
            #expect(!h.settings.intersects(h.gameCenter))
            #expect(c.birdPage.insetBy(dx: -0.5, dy: -0.5).contains(h.settings))
            #expect(c.birdPage.insetBy(dx: -0.5, dy: -0.5).contains(h.gameCenter))
        }
    }

    // MARK: P1-10 / P1-15: copy and the Results cards

    @Test func copyPass() {
        #expect(ShareText.distance(4_000) == "4 km")
        #expect(ShareText.distance(2_170, roundUp: true) == "2.2 km")
        #expect(ShareText.distance(4_000) == ShareText.target(4_000))
        #expect(RouteRules.chip(nextIndex: 0, metersFlown: 0, mirrored: false) == "→ Gull Point · 4 km")
        #expect(ResultsHeadline.newChip(count: 2) == "2 new lighthouses")
        #expect(FlightSchoolCopy.prompt(.land, touch: false) == "Land in the gold ring.")
        #expect(FlocksView.progressLine(rank: 1).components(separatedBy: ":").count == 2)
        #expect(!FlocksView.rewardLine(level: 0).hasPrefix("You "))
        // The level-up names what the level is.
        var s = ResultSummary(result: r11Run(), outcome: RecordOutcome(), title: "Flight", dailyDay: nil,
                              practice: false, share: "")
        s.outcome.rankUp = AppRankUp(from: 0, to: 1, birds: [.tern], skies: [], trails: [])
        #expect(ResultsView.unlockMoment(s)?.level == "Level 2 reward")
        // Two new lighthouses on the first flight.
        var data = ProgressData()
        let far = Goal(id: "x", kind: .reachMeters, target: 1_000_000, text: "Fly far")
        let out = ProgressRules.record(r11Run(), into: &data, today: 300, goals: { _ in [far] }, maxRank: 15,
                                       evaluate: { _, _, _, _ in 0 }, unlocks: { _, _ in (birds: [], skies: []) },
                                       trailUnlocks: { _, _ in [] })
        #expect(out.newOnRoute && out.newOnRouteCount == 2)
    }

    @Test func resultsCardsShareTheirBottom() {
        let side = CGRect(x: 32, y: 16, width: 400, height: 630)
        let far = CGRect(x: 520, y: 120, width: 400, height: 526)
        let r = ResultsLayout.sideRect(side: side, far: far, need: 300)
        #expect(abs(r.maxY - far.maxY) < 0.01)
        #expect(abs(r.height - far.height) < 0.01)
        // Taller content grows upward, never past its page.
        let tall = ResultsLayout.sideRect(side: side, far: far, need: 900)
        #expect(abs(tall.minY - side.minY) < 0.01 && abs(tall.maxY - far.maxY) < 0.01)
    }
}
