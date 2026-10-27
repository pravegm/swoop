import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Swoop

// App engineer, final fix pass before App Store submission (design/qa/FINAL-FIXES.md, App items 1–19).

private func finalRun(mode: RunMode = .flight, meters: Double = 1_200, perfects: Int = 6, lighthouses: Int = 0,
                      lastLighthouse: String = "") -> RunResult {
    RunResult(mode: mode, seed: 7, meters: meters, score: Int(meters) + 25 * perfects, seconds: 64, perfects: perfects,
              goods: 4, splashes: 2, bestChain: 3, tailwinds: 0, lighthouses: lighthouses,
              lastLighthouseName: lastLighthouse, cloudTouches: 0, maxSpeed: 1_900, maxAltitude: 640,
              longestCleanMeters: meters / 2, birdID: .gull)
}

private func finalCanvas(_ w: CGFloat, _ h: CGFloat, fold: Bool, mirrored: Bool = false,
                         insets: EdgeInsets = EdgeInsets()) -> AppCanvas {
    let size = CGSize(width: w, height: h)
    return AppCanvas(size: size, insets: insets, layout: ScreenLayout.make(canvas: size, hasFold: fold,
                                                                           mirrored: mirrored))
}

/// The Duo both ways, the iPhone 18 Pro both ways, a Pro Max, the 844 × 390 iPhones (16e, 13 mini) and the SE.
private let finalCanvases: [AppCanvas] = [
    finalCanvas(951, 669, fold: true),
    finalCanvas(951, 669, fold: true, mirrored: true),
    finalCanvas(874, 402, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    finalCanvas(874, 402, fold: false, mirrored: true, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    finalCanvas(956, 440, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    finalCanvas(844, 390, fold: false, insets: EdgeInsets(top: 0, leading: 47, bottom: 21, trailing: 47)),
    finalCanvas(844, 390, fold: false, mirrored: true, insets: EdgeInsets(top: 0, leading: 47, bottom: 21, trailing: 47)),
    finalCanvas(667, 375, fold: false),
    finalCanvas(667, 375, fold: false, mirrored: true),
]

private func finalDrive(_ s: inout FlightSchool, from t0: Double, to t1: Double, _ make: (Double) -> SchoolInput)
    -> [FlightSchool.Output] {
    var outs: [FlightSchool.Output] = []
    var t = t0
    while t <= t1 {
        outs.append(s.step(make(t)))
        t += 1.0 / 60
    }
    return outs
}

private func dailyRec() -> DailyRecord {
    DailyRecord(meters: 1_000, perfects: 1, lighthouses: 0, lastLighthouseName: "", finished: true)
}

@MainActor
struct FinalFixesTests {
    // MARK: #1 The hinge readout is Debug only

    @Test func hingeReadoutIsDebugOnly() {
        // Tests run the Debug build, where the founder's readout exists; Release compiles it (and every "Hinge readout"
        // string) out, which testflight.yml checks in the binary.
        #if DEBUG
        #expect(BuildChannel.isTestBuild)
        #else
        #expect(!BuildChannel.isTestBuild)
        #endif
    }

    // MARK: #2 Home's Daily across UTC midnight

    @Test func dailyTapDecidesOnTodayNotAStaleDay() {
        var data = ProgressData()
        // Yesterday (300) was flown; today (301) has no try yet.
        data.daily[300] = dailyRec()
        data.dailyAttempted = [300]
        // A tap after midnight starts today's scored Daily: never the "spent" card for an unplayed day.
        #expect(AppRules.dailyTap(data: data, day: 301) == .play)
        #expect(AppRules.dailyTap(data: data, day: 300) == .card)
        // A try started today (even unfiled) opens today's card.
        data.dailyAttempted.insert(301)
        #expect(AppRules.dailyTap(data: data, day: 301) == .card)
        // A filed partial counts too.
        var other = ProgressData()
        other.daily[302] = dailyRec()
        #expect(AppRules.dailyTap(data: other, day: 302) == .card)
        // The store agrees with the rule (the tile's "Tried" / "Flown" and the tap read the same day).
        let store = ProgressStore(inMemory: data)
        #expect(store.hasDailyAttempt(day: 301) == (AppRules.dailyTap(data: store.data, day: 301) == .card))
        #expect(store.hasDailyAttempt(day: 302) == (AppRules.dailyTap(data: store.data, day: 302) == .card))
    }

    // MARK: #3 Flight School step 1 on a Duo held flat

    @Test func flatDuoPassesHoldItOpen() {
        var s = FlightSchool(touch: false, asksWingCheck: false)
        s.start(at: .hold, time: 0)
        let outs = finalDrive(&s, from: 0, to: 1.5) { SchoolInput(time: $0, landscape: true, angle: 180, still: true) }
        #expect(outs.contains { $0.succeeded })
        #expect(s.subline == nil)
    }

    @Test func holdStepDrawsItsCorrectionAsTheSecondLine() {
        var s = FlightSchool(touch: false, asksWingCheck: false)
        s.start(at: .hold, time: 0)
        _ = s.step(SchoolInput(time: 0.2, landscape: true, angle: 100, still: true))
        #expect(s.words(at: 0.2)?.text == "Hold it open")
        #expect(s.subWords(at: 0.2) == "Open it wider")
        _ = s.step(SchoolInput(time: 0.4, landscape: false, angle: 150, still: true))
        #expect(s.subWords(at: 0.4) == "Turn it sideways")
        // Held right: no second line.
        _ = s.step(SchoolInput(time: 0.6, landscape: true, angle: 150, still: false))
        #expect(s.subWords(at: 0.6) == nil)
        // In-world words: no full stop, ≤ 7 words.
        #expect(FlightSchool.inWorldLine("Open it wider.") == "Open it wider")
        #expect(FlightSchool.inWorldLine("…and let go…") == "…and let go…")
        for line in ["Open it wider", "Turn it sideways"] { #expect(line.split(separator: " ").count <= 7) }
        // The iPhone's step 1 too.
        var t = FlightSchool(touch: true, asksWingCheck: false)
        t.start(at: .hold, time: 0)
        _ = t.step(SchoolInput(time: 0.2, landscape: false))
        #expect(t.subWords(at: 0.2) == "Turn it sideways")
    }

    // MARK: #4 A seated Duo after Home

    @Test func seatedDuoHomeIsTheTurnCard() {
        let seated = CGSize(width: 669, height: 951)
        // A run with the pose card's "Play with touch": the split deck.
        #expect(AppPoseRule.pose(canvas: seated, hingeSeen: true, isShut: false, inRun: true, touchOverride: true) == .deck)
        // Home (the controller clears the override as the attract loop starts): the TurnCard, never the dead deck.
        #expect(AppPoseRule.pose(canvas: seated, hingeSeen: true, isShut: false, inRun: false, touchOverride: false)
                == .turn)
    }

    // MARK: #5 Auto-Lock during Flight School

    @Test func screenStaysAwakeThroughFlightSchool() {
        // A live flight.
        #expect(AppRules.keepsScreenAwake(route: .playing, homeLoop: false, paused: false, hasSummary: false,
                                          schoolRunning: false, studioPaused: false))
        // The Studio runs over the attract loop (homeLoop), the practice sea on `.school` too.
        #expect(AppRules.keepsScreenAwake(route: .school, homeLoop: true, paused: false, hasSummary: false,
                                          schoolRunning: true, studioPaused: false))
        #expect(AppRules.keepsScreenAwake(route: .school, homeLoop: false, paused: false, hasSummary: false,
                                          schoolRunning: true, studioPaused: false))
        // Paused (the Studio's pause, a sea pause, the background) or ended: Auto-Lock is back.
        #expect(!AppRules.keepsScreenAwake(route: .school, homeLoop: true, paused: false, hasSummary: false,
                                           schoolRunning: true, studioPaused: true))
        #expect(!AppRules.keepsScreenAwake(route: .school, homeLoop: false, paused: true, hasSummary: false,
                                           schoolRunning: true, studioPaused: false))
        #expect(!AppRules.keepsScreenAwake(route: .school, homeLoop: true, paused: false, hasSummary: false,
                                           schoolRunning: false, studioPaused: false))
        for route in [AppRoute.home, .results, .daily, .settings, .goals, .birds, .route, .wingCheck] {
            #expect(!AppRules.keepsScreenAwake(route: route, homeLoop: true, paused: false, hasSummary: false,
                                               schoolRunning: false, studioPaused: false))
        }
        #expect(!AppRules.keepsScreenAwake(route: .playing, homeLoop: false, paused: false, hasSummary: true,
                                           schoolRunning: false, studioPaused: false))
        #expect(!AppRules.keepsScreenAwake(route: .playing, homeLoop: true, paused: false, hasSummary: false,
                                           schoolRunning: false, studioPaused: false))
    }

    // MARK: #6 Fold-to-fly on a scored Daily's results

    @Test func foldToFlyNeverStartsAHiddenPractice() {
        #expect(AppRules.foldToFlyArms(hingeRun: true, isDailyCard: false, dailyDay: nil, practice: false))
        #expect(!AppRules.foldToFlyArms(hingeRun: true, isDailyCard: false, dailyDay: 300, practice: false))
        #expect(AppRules.foldToFlyArms(hingeRun: true, isDailyCard: false, dailyDay: 300, practice: true))
        #expect(!AppRules.foldToFlyArms(hingeRun: true, isDailyCard: true, dailyDay: 300, practice: false))
        #expect(!AppRules.foldToFlyArms(hingeRun: false, isDailyCard: false, dailyDay: nil, practice: false))
    }

    // MARK: #7 Touch after a pause, the catch, and thumb hand-offs

    @Test func holdCountsEveryFinger() {
        // (Swift Testing: mutating calls are made first, then checked; see CLAUDE.md.)
        var h = HoldCount()
        let first = h.began([1])           // first thumb: fold
        #expect(first)
        let second = h.began([2])          // second thumb down: still folded, no second press
        #expect(!second)
        let handOff = h.ended([1])         // the first lifts: the second still holds the tuck
        #expect(!handOff)
        #expect(h.isHeld)
        let last = h.ended([2])            // the last lifts: open
        #expect(last)
        #expect(!h.isHeld)
        // Two at once, one cancelled by the system: still held until the other lifts.
        let both = h.began([3, 4])
        #expect(both)
        let oneCancelled = h.ended([3])
        #expect(!oneCancelled)
        let otherLifts = h.ended([4])
        #expect(otherLifts)
        // A lift never heard (the pad left the screen, the catch, a pause): released, and the next press folds again.
        let down5 = h.began([5])
        #expect(down5)
        let released = h.releaseAll()
        #expect(released)
        let releasedAgain = h.releaseAll()
        #expect(!releasedAgain)
        let down6 = h.began([6])
        #expect(down6)
        // A finger whose end was never delivered is dropped when the live set no longer has it.
        let dropped = h.keepOnly([])
        #expect(dropped)
        let down7 = h.began([7])
        #expect(down7)
        let kept = h.keepOnly([7, 8])
        #expect(!kept)
        #expect(h.isHeld)
        // A stray end for a finger that isn't down changes nothing.
        let stray = h.ended([99])
        #expect(!stray)
        #expect(h.isHeld)
    }

    // MARK: #9 Resuming from the closing pause

    @Test func goWaitsForOpenWingsAfterTheClosingPause() {
        // After the closing pause: wings still folded (start tuck 0.6) keeps "Go" waiting up to 3 s past the hold.
        #expect(AppRules.readyWaits(pastHold: 0.5, moving: false, startTuck: 0.6, afterClosing: true))
        #expect(AppRules.readyWaits(pastHold: 2.9, moving: false, startTuck: 0.6, afterClosing: true))
        #expect(!AppRules.readyWaits(pastHold: 3.0, moving: false, startTuck: 0.6, afterClosing: true))
        // Open enough (≤ 0.5): "Go" at once, whichever comes first.
        #expect(!AppRules.readyWaits(pastHold: 0.2, moving: false, startTuck: 0.5, afterClosing: true))
        // Still moving but open: the usual 1 s grace.
        #expect(AppRules.readyWaits(pastHold: 0.5, moving: true, startTuck: 0.2, afterClosing: true))
        #expect(!AppRules.readyWaits(pastHold: 1.2, moving: true, startTuck: 0.2, afterClosing: true))
        // A user pause keeps the 1 s grace for folded wings.
        #expect(AppRules.readyWaits(pastHold: 0.8, moving: false, startTuck: 0.6, afterClosing: false))
        #expect(!AppRules.readyWaits(pastHold: 1.5, moving: false, startTuck: 0.6, afterClosing: false))
        #expect(!AppRules.readyWaits(pastHold: 0.5, moving: false, startTuck: 0.1, afterClosing: false))
        // The controller's constants are the founder's numbers.
        #expect(abs(GameController.closingResumeGrace - 3.0) < 1e-9)
        #expect(abs(GameController.readyStillGrace - 1.0) < 1e-9)
        #expect(!AppRules.readyWaits(pastHold: .nan, moving: true, startTuck: 1, afterClosing: true))
    }

    // MARK: #10 One Skip on the clear-side check

    @Test func clearSideCheckHasOneSkipAndNoOverlap() {
        #expect(WingCheckPages.notSureTitle == "Not sure")
        for c in finalCanvases {
            let skip = SchoolLayout.make(c).skip
            for big in [false, true] {
                let r = WingCheckPages.notSureRect(c, big: big, avoiding: skip)
                // Tap areas never overlap: at least 8 pt apart.
                #expect(!r.intersects(skip.insetBy(dx: -WingCheckPages.skipGap + 0.01, dy: -WingCheckPages.skipGap + 0.01)))
                // Still a real button on the bird page (≥ 56 pt tall, wide enough for "Not sure").
                #expect(r.height >= AppCanvas.minTap - 0.01)
                #expect(r.width >= 96)
                #expect(r.minX >= c.birdPage.minX - 0.5 && r.maxX <= c.birdPage.maxX + 0.5)
                #expect(c.isFoldClear(r))
            }
            // The Settings check (no Skip beside it) stays centred on the bird page.
            let alone = WingCheckPages.notSureRect(c, big: false, avoiding: nil)
            #expect(abs(alone.midX - c.birdPage.midX) < 0.5)
        }
    }

    // MARK: #11 Game Center

    @Test func gameCenterQueueKeepsTheHighestLongest() {
        let longest = GameCenterManager.Leaderboard.longest
        let daily = GameCenterManager.Leaderboard.daily
        var q: [String] = []
        // Signed out: a 20 km best, then twenty weaker flights.
        q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: longest, score: 20_000, day: nil,
                                                               token: "best"), into: q)
        for i in 0..<20 {
            q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: longest, score: 1_000 + i, day: nil,
                                                                   token: "w\(i)"), into: q)
        }
        let longs = q.compactMap { GameCenterManager.parse($0) }.filter { $0.leaderboard == longest }
        #expect(longs.count == 1)
        #expect(longs.first?.score == 20_000)
        // A better one replaces it.
        q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: longest, score: 21_000, day: nil,
                                                               token: "better"), into: q)
        #expect(q.compactMap { GameCenterManager.parse($0) }.filter { $0.leaderboard == longest }.map(\.score) == [21_000])
        // The cap evicts Dailies, never the best.
        for d in 0..<30 {
            q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: daily, score: 500, day: 400 + d,
                                                                   token: "d\(d)"), into: q, cap: 20)
        }
        #expect(q.count == 20)
        #expect(q.compactMap { GameCenterManager.parse($0) }.contains { $0.leaderboard == longest && $0.score == 21_000 })
    }

    @Test func signInResendsTheBestAndEveryAchievement() {
        var data = ProgressData()
        data.runs = 4
        data.bestMeters = 12_345.6
        data.bestChain = 5
        let first = GameCenterManager.signInSync(data: data, queue: [], token: "a")
        let scores = first.queue.compactMap { GameCenterManager.parse($0) }
        #expect(scores.count == 1)
        #expect(scores.first?.leaderboard == GameCenterManager.Leaderboard.longest)
        #expect(scores.first?.score == 12_345)
        // Every earned achievement, whatever was reported before (Game Center de-duplicates).
        let earned = ProgressRules.earnedAchievements(data, allBirdsRank: ProgressRules.allBirdsRankDefault())
        #expect(Set(first.achievements) == earned)
        #expect(first.achievements.contains(ProgressRules.achievementKm10))
        #expect(first.achievements.contains(ProgressRules.achievementChain5))
        // A second sign-in adds nothing new to the queue.
        let again = GameCenterManager.signInSync(data: data, queue: first.queue, token: "b")
        #expect(again.queue == first.queue)
        // No best, no score.
        #expect(GameCenterManager.signInSync(data: ProgressData(), queue: [], token: "c").queue.isEmpty)
    }

    // MARK: #12 Home's caption on small screens

    @Test func homeCaptionNeverRunsIntoTheCornerPills() {
        let fresh: [String] = [HomeView.captionText(duo: false, folded: false, flat: false),
                               HomeView.captionText(duo: false, folded: true, flat: false),
                               HomeView.captionText(duo: true, folded: false, flat: false),
                               HomeView.captionText(duo: true, folded: true, flat: false),
                               HomeView.captionText(duo: true, folded: false, flat: true),
                               HomeView.captionText(duo: true, folded: false, flat: false, lowRest: true),
                               HomeView.captionText(duo: false, folded: true, flat: false, returning: true)]
        for c in finalCanvases {
            let l = HomeLayout.make(c)
            // The caption's rect ends above the pills.
            #expect(l.caption.maxY <= min(l.settings.minY, l.gameCenter.minY) - 8 + 0.01)
            for text in fresh {
                let objective: String? = text != RouteRules.objective ? RouteRules.objective : nil
                let plan = HomeCaptionPlan.make(text: text, objective: objective, width: l.caption.width,
                                                height: l.caption.height, compact: c.isCompact)
                #expect(plan.headlineLines >= 1)
                #expect(plan.used(compact: c.isCompact) <= l.caption.height + 0.01)
            }
        }
        // The SE (667 × 375): the fresh iPhone caption keeps its headline and drops the goal sentence under it.
        let se = HomeLayout.make(finalCanvases[7])
        let sePlan = HomeCaptionPlan.make(text: "Hold anywhere. The wings fold.", objective: RouteRules.objective,
                                          width: se.caption.width, height: se.caption.height, compact: true)
        #expect(!sePlan.showsObjective)
        // The Duo has room for both.
        let duo = HomeLayout.make(finalCanvases[0])
        let duoPlan = HomeCaptionPlan.make(text: "Hold it like a book. These are your wings.", objective: RouteRules.objective,
                                           width: duo.caption.width, height: duo.caption.height, compact: false)
        #expect(duoPlan.showsObjective)
    }

    // MARK: #13 The practice Daily's share line

    @Test func practiceShareLineIsMarked() {
        let dove = ShareText.dove
        let sunrise = ShareText.sunrise
        let scored = finalRun(mode: .daily(day: 5, scored: true), meters: 4_100, perfects: 9, lighthouses: 1,
                              lastLighthouse: "Gull Point")
        let practice = finalRun(mode: .daily(day: 5, scored: false), meters: 4_100, perfects: 9, lighthouses: 1,
                                lastLighthouse: "Gull Point")
        #expect(ShareText.line(for: scored, streak: 4)
                == "Swoop Daily #1 4.1 km \(dove) 9 perfect landings · past Gull Point \(sunrise) \(ShareText.fire)4")
        // Practice: prefixed, and no streak flame.
        #expect(ShareText.line(for: practice, streak: 4)
                == "Practice · Swoop Daily #1 4.1 km \(dove) 9 perfect landings · past Gull Point \(sunrise)")
        #expect(ShareText.line(for: practice, streak: 4) != ShareText.line(for: scored, streak: 0))
    }

    // MARK: #14 Streaks

    @Test func streakIsKeptOnHomeAfterOneMissedDay() {
        // Days 1…5 flown, 6 missed, today 7 not flown yet: still a 5-day streak (today's flight bridges 6).
        #expect(ProgressRules.streak(days: [1, 2, 3, 4, 5], today: 7) == 5)
        #expect(ProgressRules.streak(days: [1, 2, 3, 4, 5], today: 6) == 5)
        // Two missed days: gone.
        #expect(ProgressRules.streak(days: [1, 2, 3, 4, 5], today: 8) == 0)
        // Flying today then keeps it (the missed day doesn't count).
        #expect(ProgressRules.streakWithGrace(days: [1, 2, 3, 4, 5, 7], today: 7).streak == 6)
        // One grace per rolling 7: a second gap inside the window isn't bridged.
        #expect(ProgressRules.streak(days: [1, 2, 4, 5], today: 7) == 2)
    }

    @Test func calmSeaShowsOnlyForTheDayItBridges() {
        let bridged = ProgressRules.streakWithGrace(days: [1, 2, 4], today: 4)
        #expect(bridged.streak == 3 && bridged.graceKept)
        // The next day: the same old gap, no "Calm sea" again.
        let next = ProgressRules.streakWithGrace(days: [1, 2, 4, 5], today: 5)
        #expect(next.streak == 4 && !next.graceKept)
        // Not flown today yet: nothing to celebrate.
        #expect(!ProgressRules.streakWithGrace(days: [1, 2], today: 4).graceKept)
        // Through `record`: the bridging Daily says it, the following one doesn't.
        var data = ProgressData()
        var kept: [Bool] = []
        for day in [300, 301, 303, 304] {
            let out = ProgressRules.record(finalRun(mode: .daily(day: day, scored: true)), into: &data, today: day)
            kept.append(out.dailyGraceKept)
        }
        #expect(kept == [false, false, true, false])
    }

    @Test func threeDawnsNeedsThreeDaysInARow() {
        #expect(ProgressRules.longestStrictStreak(days: [1, 2, 3, 5, 6]) == 3)
        #expect(ProgressRules.longestStrictStreak(days: [1, 3, 4]) == 2)
        #expect(ProgressRules.longestStrictStreak(days: []) == 0)
        #expect(ProgressRules.longestStrictStreak(days: [Int.max - 1, Int.max]) == 2)
        // D, D+2, D+3: a grace streak of 3, but not three days in a row.
        var gap = ProgressData()
        var newly: [String] = []
        for day in [300, 302, 303] {
            newly += ProgressRules.record(finalRun(mode: .daily(day: day, scored: true)), into: &gap, today: day)
                .newAchievements
        }
        #expect(gap.bestDailyStreak == 3)
        #expect(!newly.contains(ProgressRules.achievementDaily3))
        #expect(!ProgressRules.earnedAchievements(gap, allBirdsRank: 10).contains(ProgressRules.achievementDaily3))
        // D, D+1, D+2: earned.
        var row = ProgressData()
        var earned: [String] = []
        for day in [300, 301, 302] {
            earned += ProgressRules.record(finalRun(mode: .daily(day: day, scored: true)), into: &row, today: day)
                .newAchievements
        }
        #expect(earned.contains(ProgressRules.achievementDaily3))
    }

    // MARK: #15 The scene rests under cards

    @Test func sceneRestsUnderCards() {
        #expect(RootView.sceneRest(route: .playing, cardUp: true, demo: false) == .paused)
        #expect(RootView.sceneRest(route: .school, cardUp: true, demo: false) == .paused)
        #expect(RootView.sceneRest(route: .playing, cardUp: false, demo: false) == .live)
        #expect(RootView.sceneRest(route: .results, cardUp: false, demo: false) == .slow)
        #expect(RootView.sceneRest(route: .daily, cardUp: false, demo: false) == .slow)
        #expect(RootView.sceneRest(route: .home, cardUp: false, demo: false) == .live)
        // CI's demo frames wait for the scene's own frames: never rested.
        #expect(RootView.sceneRest(route: .playing, cardUp: true, demo: true) == .live)
        #expect(RootView.sceneRest(route: .results, cardUp: false, demo: true) == .live)
        #expect(RootView.restFramesPerSecond == 10)
    }

    // MARK: #16 Glossary

    @Test func goalWordsFollowTheGlossary() {
        #expect(AppRules.goalText("3 Perfects in one flight") == "3 perfect landings in one flight")
        #expect(AppRules.goalText("Chain 10 Perfects in one flight") == "10 perfect landings in a row")
        #expect(AppRules.goalText("Land a Perfect in one flight") == "Land a Perfect in one flight")
        #expect(AppRules.goalText("Fly 1,200 km in total") == "Fly 1,200 km in total")
        var all: [Goal] = []
        for r in 0..<GoalCatalog.maxRank { all += GoalCatalog.goals(forRank: r) }
        for n in 0..<4 { all += GoalCatalog.starGoals(n: n) }
        #expect(!all.isEmpty)
        for g in all {
            let shown = AppRules.goalText(g.text)
            #expect(!shown.contains("Perfects"))
            #expect(!shown.hasPrefix("Chain"))
        }
        // "Daily Flight · 27 Oct", with its dot, everywhere.
        #expect(AppRules.dailyTitle(day: 298) == "Daily Flight · 26 Oct")
    }

    // MARK: #19 The cached date formatter

    @Test func dailyTagIsStableAcrossCalls() {
        let a = AppRules.dailyTag(day: 298)
        let b = AppRules.dailyTag(day: 298)
        #expect(a == "26 Oct" && a == b)
        #expect(AppRules.dailyTag(day: 299) == "27 Oct")
        #expect(AppRules.dailyTag(day: 0) == "1 Jan")
    }
}
