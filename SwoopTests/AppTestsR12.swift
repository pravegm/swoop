import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Swoop

// App engineer, Round 12 (design/ROUND-12.md): targets that are really there. Words and pointers name a ring only
// while it is fully on screen ahead of the bird; Skip and the dots sit in the trailing corner; "Opened too soon" only
// after the dive; the fold diagram's done state is the pose its words asked for; "Your wings" under the top-down gull;
// the words' soft backing; the lighthouse label above (or beside) its tower.

private func r12Canvas(_ w: CGFloat, _ h: CGFloat, fold: Bool, mirrored: Bool = false,
                       insets: EdgeInsets = EdgeInsets()) -> AppCanvas {
    let size = CGSize(width: w, height: h)
    return AppCanvas(size: size, insets: insets, layout: ScreenLayout.make(canvas: size, hasFold: fold,
                                                                           mirrored: mirrored))
}

private let r12Canvases: [AppCanvas] = [
    r12Canvas(951, 669, fold: true),
    r12Canvas(951, 669, fold: true, mirrored: true),
    r12Canvas(874, 402, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r12Canvas(874, 402, fold: false, mirrored: true, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r12Canvas(956, 440, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    r12Canvas(667, 375, fold: false),
]

private func r12Sea(_ t: Double, x: Double? = nil, slope: Double = 0, skimming: Bool = true, tuck: Double = 0,
                    _ signals: [PracticeSignal] = []) -> SchoolInput {
    var i = SchoolInput(time: t, landscape: true, tuck: tuck, slope: slope, skimming: skimming, flying: true,
                        practice: true, signals: signals)
    i.seaX = x
    return i
}

struct RoundTwelveTests {
    // MARK: P0-1: words never name a target that isn't on screen

    /// The pure rule: a ring counts only when it is entirely inside the screen and ahead of the bird in the flight
    /// direction. Behind the bird (s1-12's pointer off the trailing edge), half off an edge, or missing: no.
    @Test func ringWordsNeedTheRingOnScreenAhead() {
        let screen = CGSize(width: 951, height: 669)
        let bird = CGPoint(x: 285, y: 400)
        let ahead = CGRect(x: 560, y: 380, width: 120, height: 90)
        let behind = CGRect(x: 60, y: 380, width: 120, height: 90)
        let cut = CGRect(x: 880, y: 380, width: 120, height: 90)        // runs off the leading edge
        let below = CGRect(x: 560, y: 620, width: 120, height: 90)      // runs off the bottom
        #expect(SchoolRingRule.ringInView(ahead, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(behind, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(cut, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(below, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(nil, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(.zero, bird: bird, screen: screen, mirrored: false))
        #expect(!SchoolRingRule.ringInView(.null, bird: bird, screen: screen, mirrored: false))
        // Mirrored, the bird flies right to left: "ahead" is the smaller x (even if Scene still reported a ring
        // behind, belt and braces).
        let mBird = CGPoint(x: 666, y: 400)
        let mAhead = CGRect(x: 200, y: 380, width: 120, height: 90)
        let mBehind = CGRect(x: 760, y: 380, width: 120, height: 90)
        #expect(SchoolRingRule.ringInView(mAhead, bird: mBird, screen: screen, mirrored: true))
        #expect(!SchoolRingRule.ringInView(mBehind, bird: mBird, screen: screen, mirrored: true))
        #expect(!SchoolRingRule.ringInView(CGRect(x: -40, y: 380, width: 120, height: 90), bird: mBird, screen: screen,
                                           mirrored: true))
        // No pointer without a ring in view.
        #expect(SchoolRig.pointerRing(anchor: .ring, ring: behind, ringInView: false) == nil)
        #expect(SchoolRig.pointerRing(anchor: .ring, ring: ahead, ringInView: true) == ahead)
        #expect(SchoolRig.pointerRing(anchor: .meter, ring: ahead, ringInView: true) == nil)
    }

    /// The storm step's "Land in the gold ring" and the land step's "Land here" switch to their other words (never
    /// anchored to a ring, no second line asking to come down) while the ring is not in view.
    @Test func ringStepsSayTheirOtherWordsWithoutTheRing() {
        for touch in [false, true] {
            var st = FlightSchool(touch: touch, asksWingCheck: false)
            st.start(at: .storm, time: 0)
            let t = FlightSchool.stormRingWordsAfter + 0.5
            #expect(st.words(at: t)?.text == "Land in the gold ring")
            #expect(st.words(at: t, ringInView: false)?.text == "Stay ahead")
            #expect(st.words(at: t, ringInView: false)?.anchor == .meter)
            var land = FlightSchool(touch: touch, asksWingCheck: false)
            land.start(at: .land, time: 0)
            #expect(land.words(at: 0.5)?.text == "Land here")
            let other = land.words(at: 0.5, ringInView: false)
            #expect(other?.text == (touch ? "Let go to glide" : "Open to glide"))
            #expect(other?.anchor == .spot)
            #expect(land.subWords(at: 0.5, ringInView: false) == nil)
            #expect(land.subWords(at: 0.5) == (touch ? "Hold to come down" : "Fold to come down"))
            // No step, at any moment, anchors words to a ring that is not in view.
            for step in SchoolStep.allCases {
                var s = FlightSchool(touch: touch, asksWingCheck: false)
                s.start(at: step, time: 0)
                for e in stride(from: 0.0, to: 8.0, by: 0.5) {
                    #expect(s.words(at: e, ringInView: false)?.anchor != .ring, "\(step) at \(e)")
                }
            }
        }
        // The display carries both and picks per frame.
        var st = FlightSchool(touch: false, asksWingCheck: false)
        st.start(at: .storm, time: 0)
        let t = FlightSchool.stormRingWordsAfter + 0.5
        var d = SchoolDisplay()
        d.step = .storm
        if let w = st.words(at: t) {
            d.words = w.text
            d.wordsAnchor = w.anchor
        }
        if let o = st.words(at: t, ringInView: false) {
            d.noRingWords = o.text
            d.noRingAnchor = o.anchor
        }
        #expect(d.shownWords(ringInView: true)?.text == "Land in the gold ring")
        #expect(d.shownWords(ringInView: true)?.anchor == .ring)
        #expect(d.shownWords(ringInView: false)?.text == "Stay ahead")
        #expect(d.shownWords(ringInView: false)?.anchor == .meter)
        // Words that don't name a ring are unaffected.
        var m = SchoolDisplay()
        m.words = "Stay ahead"
        m.wordsAnchor = .meter
        #expect(m.shownWords(ringInView: false)?.text == "Stay ahead")
        // A ring display with no other words shows nothing rather than a ring that isn't there.
        var r = SchoolDisplay()
        r.words = "Land here"
        r.wordsAnchor = .ring
        #expect(r.shownWords(ringInView: false) == nil)
    }

    // MARK: P0-2(b): Skip and the dots in the trailing corner

    @Test func skipAndDotsSitInTheTrailingCorner() {
        for c in r12Canvases {
            let l = SchoolLayout.make(c)
            let play = PlayLayout.make(c)
            let bird = SceneAdapter.defaultBirdPoint(c)
            // The trailing bottom corner: bottom-left unmirrored (and on iPhone), bottom-right mirrored.
            if c.mirrored {
                #expect(l.skip.midX > c.size.width / 2, "Skip not bottom-right on \(c.size)")
            } else {
                #expect(l.skip.midX < c.size.width / 2, "Skip not bottom-left on \(c.size)")
            }
            #expect(l.skip.maxY <= c.size.height + 0.5 && l.skip.minY > c.size.height / 2)
            // The dots with Skip, just above it, on the same page.
            #expect(!l.dots.intersects(l.skip))
            #expect(l.dots.maxY <= l.skip.minY + 0.01 && l.skip.minY - l.dots.maxY < 12)
            #expect(abs(l.dots.midX - l.skip.midX) < 0.5)
            for r in [l.skip, l.dots] {
                #expect(c.isFoldClear(r), "\(r) on the fold of \(c.size)")
                #expect(r.minX >= -0.5 && r.maxX <= c.size.width + 0.5)
                #expect(c.birdPage.insetBy(dx: -0.5, dy: -0.5).contains(r), "\(r) off the bird page on \(c.size)")
                #expect(!r.intersects(play.pause) && !r.intersects(play.meter))
                // Behind the bird, never in its path (the bird's rect is 44 pt in radius).
                if c.mirrored {
                    #expect(r.minX >= bird.x + 44, "\(r) not behind the bird at \(bird) on \(c.size)")
                } else {
                    #expect(r.maxX <= bird.x - 44, "\(r) not behind the bird at \(bird) on \(c.size)")
                }
            }
            // The Studio's words and diagram stay clear of the moved chrome.
            #expect(!l.prompt.intersects(l.dots) && !l.prompt.intersects(l.skip))
            #expect(!l.diagram.intersects(l.dots) && !l.diagram.intersects(l.skip))
        }
    }

    // MARK: P0-3: "Opened too soon" only after the dive

    @Test func missWordsOnlyAfterTheBirdHasGoneDownTheFace() {
        for touch in [false, true] {
            let miss = touch ? "Let go too soon" : "Opened too soon"
            let rule = touch ? "Hold down the wave" : "Fold down the wave"
            var d = FlightSchool(touch: touch, asksWingCheck: false)
            d.start(at: .dive, time: 0)
            // Waiting on the crest, wings open: the rule, never the miss.
            _ = d.step(r12Sea(0.1, x: 1, slope: 0, tuck: 0))
            _ = d.step(r12Sea(1.0, x: 1, slope: -0.01, tuck: 0))
            #expect(d.words(at: 1.0)?.text == rule)
            // Folded off the crest, then open just over the top (under 300 pt down): still not a miss.
            _ = d.step(r12Sea(2.0, x: 20, slope: -0.2, tuck: 1))
            _ = d.step(r12Sea(2.1, x: 120, slope: -0.2, tuck: 0.1))
            #expect(d.words(at: 2.1)?.text == rule)
            #expect(d.missedAt == nil)
            // Open a third of the way down the face: the miss is said there.
            _ = d.step(r12Sea(2.4, x: 480, slope: -0.2, tuck: 0.1))
            #expect(d.words(at: 2.4)?.text == miss)
            #expect(d.subWords(at: 2.4) == (touch ? "Keep holding to the bottom" : "Stay folded to the bottom"))
            // Core's verdict at the trough: still said there; the rewind waits.
            let out = d.step(r12Sea(3.0, x: 1500, slope: 0.01, tuck: 0.1, [.diveDone(heldFraction: 0.2)]))
            #expect(!out.rewind)
            #expect(d.words(at: 3.0)?.text == miss)
            let back = d.step(r12Sea(3.0 + FlightSchool.missRewindDelay + 0.01, x: 1700, slope: 0.1))
            #expect(back.rewind)
            // Back on the crest: the rule again (with its remedy), not the miss.
            #expect(d.words(at: 4.5)?.text == rule)
            #expect(d.subWords(at: 4.5) == (touch ? "Keep holding to the bottom" : "Stay folded to the bottom"))
        }
        // An early open that the player corrects in time: Core's verdict passes and the miss words go.
        var ok = FlightSchool(touch: false, asksWingCheck: false)
        ok.start(at: .dive, time: 0)
        _ = ok.step(r12Sea(2.0, x: 20, slope: -0.2, tuck: 1))
        _ = ok.step(r12Sea(2.3, x: 400, slope: -0.2, tuck: 0.1))
        #expect(ok.showsMiss(at: 2.3))
        let passed = ok.step(r12Sea(3.0, x: 1500, slope: 0.01, tuck: 1, [.diveDone(heldFraction: 0.8)]))
        #expect(passed.succeeded && !passed.rewind)
        #expect(!ok.showsMiss(at: 3.0))
    }

    #if DEBUG
    /// The s1-06 frame: a real early open (folded off the crest, open from x 450) held partway down the face.
    @Test func diveFailFrameIsPartwayDownTheFace() {
        #expect(GameController.demoEarlyOpenTuck(seaX: 1) == 1)
        #expect(GameController.demoEarlyOpenTuck(seaX: GameController.demoEarlyOpenAt + 1) == 0)
        let fx = GameController.demoSchoolFreezeX(step: .dive, phase: "fail", autopilot: false) ?? 0
        #expect(fx > GameController.demoEarlyOpenAt + FlightSchool.earlyOpenAfter)
        #expect(fx < Tuning.practiceTroughX - 200)
        #expect(GameController.demoSchoolFreezeX(step: .dive, phase: "turn", autopilot: false) == nil)
        var d = FlightSchool(touch: false, asksWingCheck: false)
        d.start(at: .dive, time: 100)
        d.demo(phase: "fail", time: 100)
        #expect(d.words(at: 140)?.text == "Opened too soon")
        #expect(d.subWords(at: 140) == "Stay folded to the bottom")
    }
    #endif

    // MARK: P0-4: the fold diagram's done state is the target

    @Test func diagramDoneStateIsTheTargetPose() {
        // Done draws the target whatever the hands did; live never folds past a fold target.
        #expect(WingDiagram.drawnTuck(live: 1, target: 1, done: true) == 1)
        #expect(WingDiagram.drawnTuck(live: 0.4, target: 1, done: true) == 1)
        #expect(WingDiagram.drawnTuck(live: 0.9, target: 0, done: true) == 0)
        #expect(abs(WingDiagram.drawnTuck(live: 0.4, target: 1, done: false) - 0.4) < 1e-9)
        #expect(WingDiagram.drawnTuck(live: 3, target: 1, done: false) <= 1)
        #expect(abs(WingDiagram.drawnTuck(live: 0.7, target: nil, done: false) - 0.7) < 1e-9)
        // The wings step's done pose is the "Fold a little" target it showed (135°), not a deeper fold.
        var w = FlightSchool(touch: false, asksWingCheck: false)
        w.start(at: .wings, time: 0)
        let asked = w.diagramTarget
        #expect(asked == 1)
        #expect(FlightSchool.doneTarget(.wings) == asked)
        let doneHinge = WingDiagram.hinge(forTuck: WingDiagram.drawnTuck(live: 1, target: FlightSchool.doneTarget(.wings),
                                                                         done: true))
        #expect(abs(doneHinge - WingDiagram.foldHinge) < 1e-9)
        #expect(FlightSchool.doneTarget(.hold) == 0)
        #expect(FlightSchool.doneTarget(.storm) == nil)
    }

    // MARK: P0-5: which bird is me

    @Test func yourWingsCaptionOnTheFirstStep() {
        var d = SchoolDisplay()
        d.step = .hold
        #expect(d.wingsCaption(hasFold: true) == "Your wings")
        #expect(d.wingsCaption(hasFold: false) == "Your bird")
        d.touch = true
        #expect(d.wingsCaption(hasFold: true) == "Your bird")
        d.step = .wings
        #expect(d.wingsCaption(hasFold: true) == nil)
        for c in r12Canvases {
            let l = SchoolLayout.make(c)
            let r = l.wingsCaption
            #expect(r.width > 0 && r.height > 0)
            #expect(r.minY >= l.titleBird.maxY - 0.5, "caption not under the gull on \(c.size)")
            #expect(r.minX >= -0.5 && r.maxX <= c.size.width + 0.5)
            #expect(c.isFoldClear(r), "caption on the fold of \(c.size)")
            #expect(c.farPage.insetBy(dx: -0.5, dy: -0.5).contains(r))
            for other in [l.diagram, l.prompt, l.dots, l.skip, PlayLayout.make(c).pause] {
                #expect(!r.intersects(other), "caption on \(other) on \(c.size)")
            }
        }
    }

    // MARK: P1-7 / P1-8: the words' place and backing

    @Test func lighthouseLabelNeverCrossesItsTower() {
        for c in r12Canvases {
            let s = SchoolRig.lampLabelSize(compact: c.isCompact)
            for lamp in [CGPoint(x: c.size.width * 0.9, y: c.top + 8), CGPoint(x: c.size.width * 0.15, y: c.top + 4),
                         CGPoint(x: c.size.width * 0.2, y: 160), CGPoint(x: c.size.width * 0.8, y: 220)] {
                let p = SchoolRig.lampLabelCenter(lamp: lamp, canvas: c)
                let label = CGRect(x: p.x - s.width / 2, y: p.y - s.height / 2, width: s.width, height: s.height)
                // The tower: from its roof (≈ 14 pt over the lamp) down to the water.
                let tower = CGRect(x: lamp.x - 10, y: lamp.y - 14, width: 20, height: 140)
                #expect(!label.intersects(tower), "label \(label) through the tower at \(lamp) on \(c.size)")
                #expect(label.minY >= c.top - 0.5, "label off the top on \(c.size)")
                if label.maxY <= lamp.y { #expect(lamp.y - 14 - label.maxY >= 7.5, "label within 8 pt of the lantern") }
            }
        }
        #expect(SchoolWord.backingOpacity >= 0.4 && SchoolWord.backingFeather > 0)
    }
}
