import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Swoop

// App engineer tests: demo-mode parsing, ProgressStore round-trip and the goal → rank-up flow (with a fake RunResult
// and injected goals, so they don't depend on Core's catalogue), share text, the pose rules, and the layouts never
// putting a control on the fold.

// MARK: - Helpers

private func makeRun(mode: RunMode = .flight, meters: Double = 1_200, perfects: Int = 6, bestChain: Int = 3,
                     tailwinds: Int = 1, lighthouses: Int = 0, lastLighthouse: String = "",
                     cloudTouches: Int = 0) -> RunResult {
    RunResult(mode: mode, seed: 7, meters: meters, score: Int(meters) + 25 * perfects, seconds: 64, perfects: perfects,
              goods: 4, splashes: 2, bestChain: bestChain, tailwinds: tailwinds, lighthouses: lighthouses,
              lastLighthouseName: lastLighthouse, cloudTouches: cloudTouches, maxSpeed: 1_900, maxAltitude: 640,
              longestCleanMeters: meters / 2, birdID: .gull)
}

/// Three fake goals per rank: fly `1000·(r+1)` m, `5·(r+1)` Perfects, a chain of `3 + r`.
private func fakeGoals(_ rank: Int) -> [Goal] {
    [
        Goal(id: "r\(rank).m", kind: .reachMeters, target: Double(1_000 * (rank + 1)), text: "Fly \(rank + 1) km"),
        Goal(id: "r\(rank).p", kind: .perfectsInRun, target: Double(5 * (rank + 1)), text: "Perfects"),
        Goal(id: "r\(rank).c", kind: .chain, target: Double(3 + rank), text: "Chain"),
    ]
}

private func fakeEvaluate(_ goal: Goal, _ run: RunResult, _ lifetime: Double, _ daily: Bool) -> Double {
    switch goal.kind {
    case .reachMeters: return run.meters / goal.target
    case .perfectsInRun: return Double(run.perfects) / goal.target
    case .chain: return Double(run.bestChain) / goal.target
    case .totalMeters: return lifetime / goal.target
    case .dailyPlayed: return daily ? 1 : 0
    default: return 0
    }
}

private func noUnlocks(_ from: Int, _ to: Int) -> (birds: [BirdID], skies: [SkyID]) {
    let birds: [BirdID] = to == 1 ? [BirdID.tern] : []
    let skies: [SkyID] = to == 1 ? [SkyID.roseDusk] : []
    return (birds: birds, skies: skies)
}

private func noTrails(_ from: Int, _ to: Int) -> [String] {
    to == 1 ? ["dawn"] : []
}

private let dove = ShareText.dove
private let sunrise = ShareText.sunrise
private let fire = ShareText.fire

private func canvas(_ w: CGFloat, _ h: CGFloat, fold: Bool, mirrored: Bool = false,
                    insets: EdgeInsets = EdgeInsets()) -> AppCanvas {
    let size = CGSize(width: w, height: h)
    return AppCanvas(size: size, insets: insets, layout: ScreenLayout.make(canvas: size, hasFold: fold,
                                                                           mirrored: mirrored))
}

/// The canvases every layout must work on: the Duo's book pose, an iPhone 18 Pro / Pro Max / SE in landscape.
private let testCanvases: [AppCanvas] = [
    canvas(951, 669, fold: true),
    canvas(951, 669, fold: true, mirrored: true),
    canvas(874, 402, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    canvas(874, 402, fold: false, mirrored: true, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    canvas(956, 440, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
    canvas(667, 375, fold: false),
]

// MARK: - Demo mode

#if DEBUG
struct DemoModeTests {
    @Test func parsesEveryKey() {
        let c = DemoConfig.parse("screen=results;mode=daily;seed=42;autopilot=expert;touch;duo;mirror;skipCountdown;"
                                 + "freezeOn=perfect;freezeAfter=2.5;freezeAt=9;progress=mid;bird=tern;sky=roseDusk;"
                                 + "best=5400;chain=4;hints=fresh;lead=0.12;skipTo=3700")
        #expect(c.screen == .results)
        #expect(c.mode == .daily)
        #expect(c.seed == 42)
        #expect(c.autopilot == .expert)
        #expect(c.touch && c.duo && c.mirror && c.skipCountdown)
        #expect(c.freezeOn == .perfect)
        #expect(c.freezeAfter == 2.5)
        #expect(c.freezeAt == 9)
        #expect(c.progress == .mid)
        #expect(c.bird == .tern)
        #expect(c.sky == .roseDusk)
        #expect(c.best == 5400)
        #expect(c.chain == 4)
        #expect(c.hintsFresh)
        #expect(c.lead == 0.12)
        #expect(c.skipTo == 3700)
        #expect(c.runMode(today: 300) == .daily(day: 300, scored: true))
    }

    @Test func defaultsAndImpliedScreens() {
        let empty = DemoConfig.parse("")
        #expect(empty.effectiveScreen == .home)
        #expect(empty.freezeAfter == DemoConfig.defaultFreezeAfter)
        #expect(!empty.hintsFresh && !empty.duo && !empty.touch)
        #expect(empty.runMode(today: 3) == nil)
        #expect(DemoConfig.parse("mode=flight").effectiveScreen == .play)
        #expect(DemoConfig.parse("mode=attract").runMode(today: 1) == .attract)
        #expect(DemoConfig.parse("screen=badges").badges)
        #expect(DemoConfig.parse("screen=goals;mode=flight").effectiveScreen == .goals)
    }

    @Test func ignoresJunkAndClamps() {
        let c = DemoConfig.parse(" ;=;wat=1;seed=abc;lead=7;freezeOn=nope;autopilot=god;bird=dodo;chain=-3;duo=0")
        #expect(c.seed == nil)
        #expect(c.lead == 1)
        #expect(c.freezeOn == nil)
        #expect(c.autopilot == nil)
        #expect(c.bird == nil)
        #expect(c.chain == 0)
        #expect(!c.duo)
    }

    @Test func freezeMatchesTheRightEvents() {
        #expect(AppRules.demoMatches(.perfect, .touchdown(.perfect, speed: 900, chain: 2)))
        #expect(!AppRules.demoMatches(.perfect, .touchdown(.good, speed: 900, chain: 0)))
        #expect(AppRules.demoMatches(.launch, .launched(speed: 1200)))
        #expect(AppRules.demoMatches(.tailwind, .tailwindStarted))
        #expect(AppRules.demoMatches(.lighthouse, .lighthouse(index: 0, name: "Saltlight")))
        #expect(AppRules.demoMatches(.stormclose, .stormClose))
        #expect(AppRules.demoMatches(.caught, .caught))
        #expect(!AppRules.demoMatches(.caught, .finished))
    }
}
#endif

// MARK: - Persistence

@MainActor
struct ProgressStoreTests {
    @Test func roundTripsThroughUserDefaults() throws {
        let suite = "swoop.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var data = ProgressData()
        data.bestMeters = 7_480
        data.rank = 3
        // A real goal id: progress for ids that are gone is dropped on load (R5).
        let realGoal = GoalCatalog.goals(forRank: 3).first?.id ?? "r3"
        data.goalProgress = [realGoal: 0.5]
        data.daily[300] = DailyRecord(meters: 4_200, perfects: 12, lighthouses: 1, lastLighthouseName: "Saltlight",
                                      finished: true)
        data.dailyAttempted = [300]
        data.bird = .puffin
        data.hintsLearned = true
        let store = ProgressStore(defaults: defaults)
        store.replace(with: data)
        let reloaded = ProgressStore(defaults: defaults)
        // Loading migrates the R2 `hintsLearned` flag into R3's per-hint `learnedHints` (both hints learned).
        #expect(reloaded.data.learnedHints.count == 2)
        var expected = data
        expected.learnedHints = reloaded.data.learnedHints
        #expect(reloaded.data == expected)
    }

    @Test func decodesTolerantly() throws {
        let partial = Data(#"{"bestMeters": 1234.5, "rank": 2, "bird": "dodo", "future": [1,2,3]}"#.utf8)
        let data = try #require(ProgressStore.decode(partial))
        #expect(data.bestMeters == 1234.5)
        #expect(data.rank == 2)
        #expect(data.bird == .gull)
        #expect(data.version == ProgressData.currentVersion)
        #expect(data.daily.isEmpty)
        let settings = try #require(SettingsStore.decode(Data(#"{"mirrored": true}"#.utf8)))
        #expect(settings.mirrored)
        #expect(settings.soundOn)
        #expect(!settings.respectSilentSwitch)
    }

    @Test func settingsPersist() throws {
        let suite = "swoop.tests.settings.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let s = SettingsStore(defaults: defaults)
        s.playWithTouch = true
        s.mirrored = true
        let again = SettingsStore(defaults: defaults)
        #expect(again.playWithTouch)
        #expect(again.mirrored)
        #expect(!SettingsStore(defaults: nil).mirrored)
    }
}

struct ProgressRulesTests {
    @Test func goalsAccumulateThenRankUp() {
        var data = ProgressData()
        // Run 1: meets the distance and the chain goals only.
        let first = ProgressRules.record(makeRun(meters: 1_500, perfects: 2, bestChain: 3), into: &data, today: 300,
                                         goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(first.goals.count == 3)
        #expect(first.rankUp == nil)
        #expect(data.rank == 0)
        #expect(first.goals.filter { $0.justMet }.count == 2)
        #expect(data.goalProgress["r0.p"] == 0.4)
        // Run 2: worse distance (progress never goes down), but enough Perfects: all three met → rank up.
        let second = ProgressRules.record(makeRun(meters: 400, perfects: 5, bestChain: 1), into: &data, today: 300,
                                          goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(second.goals.first { $0.goal.id == "r0.m" }?.after == 1)
        #expect(second.goals.first { $0.goal.id == "r0.p" }?.justMet == true)
        #expect(second.rankUp == AppRankUp(from: 0, to: 1, birds: [.tern], skies: [.roseDusk], trails: ["dawn"]))
        #expect(data.rank == 1)
        #expect(data.goalProgress["r0.m"] == nil)
        // Rank 1's goals start fresh on the next run.
        let third = ProgressRules.record(makeRun(meters: 1_000), into: &data, today: 300, goals: fakeGoals,
                                         maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(third.goals.map { $0.goal.id } == ["r1.m", "r1.p", "r1.c"])
        #expect(third.goals.first?.before == 0)
    }

    @Test func bestsLifetimeAndNewBest() {
        var data = ProgressData()
        let a = ProgressRules.record(makeRun(meters: 2_000, lighthouses: 0), into: &data, today: 10, goals: fakeGoals,
                                     maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(a.isNewBest && !a.showsNewBest)          // the first run is never "New best!"
        let b = ProgressRules.record(makeRun(meters: 3_000, lighthouses: 1, lastLighthouse: "Gull Point"), into: &data,
                                     today: 10, goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate,
                                     unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(b.showsNewBest)
        #expect(b.previousBest == 2_000)
        let c = ProgressRules.record(makeRun(meters: 900), into: &data, today: 10, goals: fakeGoals, maxRank: 15,
                                     evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(!c.isNewBest)
        #expect(data.bestMeters == 3_000)
        #expect(data.bestLastLighthouse == "Gull Point")
        #expect(data.lifetimeMeters == 5_900)
        #expect(data.runs == 3)
        #expect(data.bestLighthousesInRun == 1)
    }

    @Test func attractRunsAreNeverRecorded() {
        var data = ProgressData()
        _ = ProgressRules.record(makeRun(mode: .attract), into: &data, today: 1, goals: fakeGoals, maxRank: 15,
                                 evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(data == ProgressData())
    }

    @Test func dailyIsFiledOnceAndStreaks() {
        var data = ProgressData()
        for day in [298, 299, 300] {
            let out = ProgressRules.record(makeRun(mode: .daily(day: day, scored: true), meters: 4_000), into: &data,
                                           today: day, goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate,
                                           unlocks: noUnlocks, trailUnlocks: noTrails)
            #expect(out.dailyCounted)
        }
        #expect(data.dailyStreak(today: 300) == 3)
        #expect(data.dailyStreak(today: 301) == 3)          // still alive until today's is flown
        #expect(data.dailyStreak(today: 302) == 0)
        #expect(data.bestDailyStreak == 3)
        let practice = ProgressRules.record(makeRun(mode: .daily(day: 300, scored: false), meters: 9_000), into: &data,
                                            today: 300, goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate,
                                            unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(!practice.dailyCounted)
        #expect(data.daily[300]?.meters == 4_000)
        // A scored try left early is filed as the day's score.
        ProgressRules.fileDailyPartial(into: &data, day: 301, meters: 1_234, perfects: 3, lighthouses: 0,
                                       lastLighthouseName: "", today: 301)
        #expect(data.daily[301]?.finished == false)
        #expect(data.dailyAttempted.contains(301))
        // UX §4 grace: one missed day per rolling 7 keeps the streak (the missed day itself doesn't count).
        #expect(ProgressRules.streak(days: [1, 2, 4, 5], today: 5) == 4)
        #expect(ProgressRules.streak(days: [1, 3, 5], today: 5) == 2)
    }

    @Test func achievementsFollowTheProgress() {
        var data = ProgressData()
        #expect(ProgressRules.earnedAchievements(data, allBirdsRank: 10).isEmpty)
        data.runs = 1
        data.bestMeters = 5_100
        data.bestChain = 10
        data.totalTailwinds = 1
        data.bestLighthousesInRun = 3
        data.totalCloudTouches = 1
        data.bestDailyStreak = 3
        data.rank = 10
        #expect(ProgressRules.earnedAchievements(data, allBirdsRank: 10)
                == Set(ProgressRules.allAchievements).subtracting([ProgressRules.achievementKm10]))
        #expect(ProgressRules.allAchievements.count == 12)
        #expect(Set(ProgressRules.allAchievements).count == 12)
        #expect(ProgressRules.allAchievements.allSatisfy { $0.hasPrefix("swoop.ach.") })
    }
}

@MainActor
struct GameCenterQueueTests {
    @Test func queueEntriesRoundTripAndGoStale() {
        let entry = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 4200, day: 300,
                                             token: "t")
        let parsed = GameCenterManager.parse(entry)
        #expect(parsed == GameCenterManager.QueuedScore(leaderboard: "swoop.daily", score: 4200, day: 300, token: "t"))
        if let parsed {
            #expect(!GameCenterManager.isStale(parsed, today: 300))
            #expect(GameCenterManager.isStale(parsed, today: 301))
        }
        let longest = GameCenterManager.QueuedScore(leaderboard: "swoop.longest", score: 1, day: nil, token: "x")
        #expect(!GameCenterManager.isStale(longest, today: 999))
        #expect(GameCenterManager.parse("garbage") == nil)
        #expect(GameCenterManager.pending(earned: ["swoop.ach.first", "bogus"], reported: []) == ["swoop.ach.first"])
    }
}

// MARK: - Share text

struct ShareTextTests {
    @Test func formatsDistances() {
        #expect(ShareText.km(7_480) == "7.4 km")
        #expect(ShareText.km(0) == "0.0 km")
        #expect(ShareText.km(12_059) == "12.0 km")
        #expect(ShareText.km(-5) == "0.0 km")
        #expect(ShareText.km(.nan) == "0.0 km")
        #expect(ShareText.grouped(1_234_567) == "1,234,567")
        #expect(ShareText.grouped(999) == "999")
        #expect(ShareText.meters(1_234.9) == "1,234 m")
    }

    @Test func formatsShareLines() {
        #expect(ShareText.flight(meters: 7_480, perfects: 23, lastLighthouse: "Saltlight")
                == "Swoop 7.4 km \(dove) 23 Perfects · past Saltlight \(sunrise)")
        #expect(ShareText.flight(meters: 950, perfects: 1, lastLighthouse: "")
                == "Swoop 0.9 km \(dove) 1 Perfect")
        #expect(ShareText.daily(day: 12, meters: 7_480, perfects: 23, lastLighthouse: "Saltlight")
                == "Swoop Daily #12 7.4 km \(dove) 23 Perfects · past Saltlight \(sunrise)")
        #expect(ShareText.daily(day: 12, meters: 7_480, perfects: 23, lastLighthouse: "", streak: 4)
                == "Swoop Daily #12 7.4 km \(dove) 23 Perfects \(fire)4")
        let run = makeRun(mode: .daily(day: 5, scored: true), meters: 4_100, perfects: 9, lighthouses: 1,
                          lastLighthouse: "Gull Point")
        // The share line carries the DISPLAY number (R4 P1-13): day 5 is before launch, so #1.
        #expect(ShareText.line(for: run, streak: 1) == "Swoop Daily #1 4.1 km \(dove) 9 Perfects · past Gull Point \(sunrise)")
    }
}

// MARK: - Pose and input rules

struct PoseRuleTests {
    @Test func posesFromTheCanvasAndHinge() {
        let book = CGSize(width: 951, height: 669)
        let tabletop = CGSize(width: 669, height: 951)
        let cover = CGSize(width: 466, height: 678)
        let phoneLandscape = CGSize(width: 874, height: 402)
        let phonePortrait = CGSize(width: 402, height: 874)
        #expect(AppPoseRule.pose(canvas: book, hingeSeen: true, isShut: false, touchOverride: false) == .play)
        #expect(AppPoseRule.pose(canvas: tabletop, hingeSeen: true, isShut: false, touchOverride: false) == .turn)
        #expect(AppPoseRule.pose(canvas: tabletop, hingeSeen: true, isShut: false, touchOverride: true) == .deck)
        #expect(AppPoseRule.pose(canvas: cover, hingeSeen: true, isShut: false, touchOverride: false) == .closed)
        // A stale shut latch never covers the lit inner display (Duo R3 P2-7).
        #expect(AppPoseRule.pose(canvas: book, hingeSeen: true, isShut: true, touchOverride: false) == .play)
        #expect(AppPoseRule.pose(canvas: CGSize(width: 1, height: 1), hingeSeen: true, isShut: true) == .closed)
        #expect(AppPoseRule.pose(canvas: phoneLandscape, hingeSeen: false, isShut: false, touchOverride: false) == .play)
        #expect(AppPoseRule.pose(canvas: phonePortrait, hingeSeen: false, isShut: false, touchOverride: false) == .turn)
        // Without a hinge a small canvas is just a small phone, never the cover.
        #expect(AppPoseRule.pose(canvas: CGSize(width: 667, height: 375), hingeSeen: false, isShut: false,
                              touchOverride: false) == .play)
    }

    @Test func foldOnlyInBookPose() {
        let book = CGSize(width: 951, height: 669)
        #expect(AppPoseRule.hasFold(canvas: book, hingeSeen: true, demoDuo: false, divisionSeen: false))
        #expect(AppPoseRule.hasFold(canvas: book, hingeSeen: false, demoDuo: false, divisionSeen: false))  // Duo-shaped
        #expect(!AppPoseRule.hasFold(canvas: CGSize(width: 669, height: 951), hingeSeen: true, demoDuo: false,
                                  divisionSeen: false))
        #expect(!AppPoseRule.hasFold(canvas: CGSize(width: 874, height: 402), hingeSeen: false, demoDuo: false,
                                  divisionSeen: false))
        #expect(AppPoseRule.hasFold(canvas: CGSize(width: 874, height: 402), hingeSeen: false, demoDuo: true,
                                 divisionSeen: false))
        #expect(!AppPoseRule.hasFold(canvas: CGSize(width: 678, height: 466), hingeSeen: true, demoDuo: false,
                                  divisionSeen: false))
    }

    @Test func playRectIsTheWholeCanvas() {
        // R3: portrait play is the split deck (DeckLayout), so the play rect is always the full canvas.
        #expect(AppPoseRule.playRect(in: CGSize(width: 951, height: 669)) == CGRect(x: 0, y: 0, width: 951, height: 669))
        #expect(AppPoseRule.playRect(in: CGSize(width: 669, height: 951)) == CGRect(x: 0, y: 0, width: 669, height: 951))
    }

    @Test func orientationMask() {
        #expect(OrientationLock.mask(hasHinge: true, screen: CGSize(width: 402, height: 874)) == .all)
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 669, height: 951)) == .all)
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 402, height: 874)) == .landscape)
        #expect(OrientationLock.mask(hasHinge: false, screen: .zero) == .landscape)
        #expect(!OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 402, height: 874)))
        #expect(OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 669, height: 951)))
    }

    @Test func inputChoice() {
        #expect(AppRules.chooseInput(homeLoop: true, demoAutopilot: false, demoTouch: false, hasHinge: true,
                                      playWithTouch: false, touchOverride: false) == .autopilot)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: false, demoTouch: false, hasHinge: true,
                                      playWithTouch: false, touchOverride: false) == .hinge)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: false, demoTouch: false, hasHinge: true,
                                      playWithTouch: true, touchOverride: false) == .touch)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: false, demoTouch: false, hasHinge: true,
                                      playWithTouch: false, touchOverride: true) == .touch)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: false, demoTouch: false, hasHinge: false,
                                      playWithTouch: false, touchOverride: false) == .touch)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: true, demoTouch: true, hasHinge: true,
                                      playWithTouch: false, touchOverride: false) == .autopilot)
        #expect(AppRules.chooseInput(homeLoop: false, demoAutopilot: false, demoTouch: true, hasHinge: true,
                                      playWithTouch: false, touchOverride: false) == .touch)
    }

    @Test func stepClampAndTitleTuck() {
        #expect(AppRules.clampStep(0.5) == 1.0 / 30.0)
        #expect(AppRules.clampStep(-1) == 0)
        #expect(AppRules.clampStep(.infinity) == 0)
        #expect(AppRules.clampStep(0.008) == 0.008)
        #expect(TitleTuck.fromHinge(angle: 170, openAngle: 158) == 0)
        #expect(TitleTuck.fromHinge(angle: 122, openAngle: 158) == 1)
        #expect(abs(TitleTuck.fromHinge(angle: 140, openAngle: 158) - 0.5) < 0.001)
        #expect(TitleTuck.touch(now: 10, heldSince: 9, releasedAt: nil) == 1)
        let idle = TitleTuck.touch(now: 10, heldSince: nil, releasedAt: nil)
        #expect(idle >= 0 && idle <= 0.3)
    }

    @Test func eventLogLines() {
        #expect(AppTrace.describe(.touchdown(.perfect, speed: 1234.4, chain: 3)) == "touchdown perfect speed=1234 chain=3")
        #expect(AppTrace.describe(.launched(speed: 980.6)) == "launched speed=981")
        #expect(AppTrace.describe(.lighthouse(index: 1, name: "Saltlight")) == "lighthouse index=1 name=Saltlight")
        #expect(AppTrace.describe(.milestone(km: 2)) == "milestone km=2")
        #expect(AppTrace.describe(.countdownTick(3)) == "countdown 3")
        #expect(AppTrace.int(.nan) == 0)
    }

    @Test func hintCopy() {
        #expect(HintBubble.text(.fold, touch: false) == "↘ Fold on the way down")
        #expect(HintBubble.text(.open, touch: false) == "↗ Open on the way up")
        #expect(HintBubble.text(.fold, touch: true) == "↘ Hold on the way down")
        #expect(HintBubble.text(.open, touch: true, mirrored: true) == "↖ Let go on the way up")
        #expect(HintBubble.text(.fold, touch: false, mirrored: true) == "↙ Fold on the way down")
        #expect(HintBubble.text(.land, touch: true) == "Land on the way down")
        #expect(HintBubble.text(.keepBend, touch: false) == "Keep a little bend")
        #expect(RankUpBanner.unlockLine(birds: ["Tern"], skies: ["Rose Dusk"]) == "New bird: Tern · New sky: Rose Dusk")
        #expect(RankUpBanner.unlockLine(birds: ["Tern"], skies: [], trails: ["Coral"]) == "New bird: Tern · New trail: Coral")
        #expect(RankUpBanner.unlockLine(birds: ["Tern", "Heron"], skies: []) == "New birds: Tern, Heron")
        #expect(RankUpBanner.unlockLine(birds: [], skies: []) == "")
        #expect(HomeView.dailyStatus(record: nil, attempted: false, nextIn: "6 h") == "Everyone's sea · one try")
        #expect(HomeView.dailyStatus(record: nil, attempted: true, nextIn: "6 h") == "Tried · next in 6 h")
        let flown = DailyRecord(meters: 7_480, perfects: 23, lighthouses: 1, lastLighthouseName: "", finished: true)
        #expect(HomeView.dailyStatus(record: flown, attempted: true, nextIn: "6 h") == "Flown 7.48 km · next in 6 h")
    }
}

// MARK: - Layout: nothing tappable on the fold

struct LayoutTests {
    @Test func foldBandMapsFromTheDesignCanvas() {
        let duo = canvas(951, 669, fold: true)
        #expect(abs(duo.foldMinX - 455.5) < 1)
        #expect(abs(duo.foldMaxX - 495.5) < 1)
        #expect(duo.isFoldClear(CGRect(x: 0, y: 0, width: 440, height: 60)))
        #expect(!duo.isFoldClear(CGRect(x: 430, y: 0, width: 60, height: 60)))
        #expect(duo.leftPage.maxX <= duo.foldMinX)
        #expect(duo.rightPage.minX >= duo.foldMaxX)
    }

    @Test func homeButtonsAreFoldClearAndBigEnough() {
        for c in testCanvases {
            let l = HomeLayout.make(c)
            for b in l.buttons {
                #expect(c.isFoldClear(b), "button \(b) on the fold of \(c.size)")
                #expect(b.height >= AppCanvas.minTap - 0.01, "button \(b) too short on \(c.size)")
                #expect(b.width >= AppCanvas.minTap - 0.01, "button \(b) too narrow on \(c.size)")
                #expect(b.minX >= 0 && b.maxX <= c.size.width && b.minY >= 0 && b.maxY <= c.size.height + 0.5,
                        "button \(b) off \(c.size)")
            }
            // The menu sits on the far half; the corner buttons on the bird's half.
            #expect(c.farPage.contains(CGPoint(x: l.fly.midX, y: c.size.height / 2)))
            #expect(c.birdPage.contains(CGPoint(x: l.settings.midX, y: c.size.height / 2)))
            // Buttons never overlap one another.
            let all = l.buttons
            for i in 0..<all.count {
                for j in (i + 1)..<all.count {
                    #expect(!all[i].insetBy(dx: 1, dy: 1).intersects(all[j].insetBy(dx: 1, dy: 1)))
                }
            }
        }
    }

    @Test func playAndResultsAreFoldClear() {
        for c in testCanvases {
            let p = PlayLayout.make(c)
            #expect(c.isFoldClear(p.pause))
            #expect(p.pause.width >= AppCanvas.minTap && p.pause.height >= AppCanvas.minTap)
            #expect(c.isFoldClear(p.card))
            #expect(c.isFoldClear(p.distance))
            #expect(c.isFoldClear(ResultsLayout.card(c)))
            #expect(ResultsLayout.card(c).height > 200)
        }
        // Mirrored: the pause button moves to the bird's (right) half.
        let mirrored = PlayLayout.make(canvas(951, 669, fold: true, mirrored: true))
        #expect(mirrored.pause.minX > 495)
    }
}

// MARK: - Round 2

struct RoundTwoTests {
    @Test func dailyPartialKeepsTheLargerDistanceAndNeverReplacesAFinish() {
        var data = ProgressData()
        ProgressRules.fileDailyPartial(into: &data, day: 300, meters: 1_000, perfects: 2, lighthouses: 0,
                                       lastLighthouseName: "", today: 300)
        ProgressRules.fileDailyPartial(into: &data, day: 300, meters: 2_500, perfects: 5, lighthouses: 0,
                                       lastLighthouseName: "", today: 300)
        #expect(data.daily[300]?.meters == 2_500)
        ProgressRules.fileDailyPartial(into: &data, day: 300, meters: 900, perfects: 1, lighthouses: 0,
                                       lastLighthouseName: "", today: 300)
        #expect(data.daily[300]?.meters == 2_500)
        data.daily[300] = DailyRecord(meters: 2_000, perfects: 3, lighthouses: 0, lastLighthouseName: "", finished: true)
        ProgressRules.fileDailyPartial(into: &data, day: 300, meters: 9_000, perfects: 9, lighthouses: 2,
                                       lastLighthouseName: "", today: 300)
        #expect(data.daily[300]?.meters == 2_000)
    }

    @Test func leadMeterIsTheStormsOwnFill() {
        // R4 P1-7 / Scene: one source, sqrt(gap / (leadMeterScale × fullLead)).
        let full = Tuning.leadMeterScale * Tuning.fullLead
        #expect(abs(AppRules.meterLead(gap: 2_400) - (2_400 / full).squareRoot()) < 1e-6)
        #expect(abs(AppRules.meterLead(gap: 2_400) - Double(SceneStormMap.meterFill(gap: 2_400))) < 1e-9)
        #expect(AppRules.meterHeadroom == Tuning.leadMeterScale)
        #expect(AppRules.meterLead(gap: full * 10) == 1)
        #expect(AppRules.meterLead(gap: -5) == 0)
        #expect(AppRules.meterLead(gap: .nan) == 0)
        #expect(abs(AppRules.meterDangerZone - Double(SceneStormMap.closeFill)) < 1e-9)
        #expect(AppRules.meterDangerZone > 0.1 && AppRules.meterDangerZone < 0.25)
    }

    @Test func milestonesStayOffLighthouses() {
        let first = Lighthouses.x(index: 0) / Tuning.pointsPerMeter
        let km = Int((first / 1000).rounded())
        if abs(Double(km) * 1000 - first) <= AppRules.milestoneLighthouseClearance {
            #expect(AppRules.milestoneNearLighthouse(km: km))
        }
        #expect(!AppRules.milestoneNearLighthouse(km: 1))
    }

    @Test func nearMissHook() {
        let first = Lighthouses.x(index: 0) / Tuning.pointsPerMeter
        let name = Lighthouses.name(index: 0, seed: 7)
        // First flight: the first lighthouse is named.
        let firstLine = AppRules.hookLine(meters: first - 550, best: first - 550, previousBest: 0, lighthousesPassed: 0,
                                          lastLighthouse: "", seed: 7, firstFlight: true)
        #expect(firstLine == "550 m short of \(name), the first lighthouse")
        // Within 10 % of the best, the best wins.
        let nearBest = AppRules.hookLine(meters: 9_600, best: 10_000, previousBest: 10_000, lighthousesPassed: 2,
                                         lastLighthouse: "Gull Point", seed: 7, firstFlight: false)
        #expect(nearBest == "400 m short of your best")
        // Past one, short of the next.
        let next = Lighthouses.x(index: 1) / Tuning.pointsPerMeter
        let past = AppRules.hookLine(meters: next - 1_550, best: 50_000, previousBest: 50_000, lighthousesPassed: 1,
                                     lastLighthouse: "Gull Point", seed: 7, firstFlight: false)
        #expect(past == "Past Gull Point · 1.55 km short of \(Lighthouses.name(index: 1, seed: 7))")
        #expect(AppRules.statsLine(perfects: 1, chain: 4, lighthouses: 2) == "1 Perfect · chain 4 · 2 lighthouses")
        #expect(AppRules.statsLine(perfects: 0, chain: 1, lighthouses: 0) == "")
        #expect(AppRules.statsLine(perfects: 5, chain: 3, lighthouses: 1) == "5 Perfects · chain 3 · 1 lighthouse")
    }

    @Test func hudDistanceAndWording() {
        let short = ShareText.hudDistance(842.9)
        #expect(short.value == "842" && short.unit == "m")
        let one = ShareText.hudDistance(1_000)
        #expect(one.value == "1.00" && one.unit == "km")
        #expect(ShareText.hudDistance(4_068).value == "4.06")
        #expect(ShareText.hudDistance(12_345).value == "12.34")
        #expect(AppRules.touchWording(input: .touch, hasHinge: true))
        #expect(!AppRules.touchWording(input: .hinge, hasHinge: true))
        #expect(AppRules.touchWording(input: .autopilot, hasHinge: false))
        #expect(!AppRules.touchWording(input: .autopilot, hasHinge: true))
        #expect(PerfectCalloutText.text(chain: 1) == "Perfect")
        #expect(PerfectCalloutText.text(chain: 3) == "Perfect ×3")
        #expect(SettingsView.progressLine(runs: 0, rankTitle: "Fledgling", best: 0, lifetime: 0) == "No flights yet")
    }

    @Test func lifetimeGoalsReadLive() {
        var data = ProgressData()
        data.lifetimeMeters = 30_000
        let total = Goal(id: "t", kind: .totalMeters, target: 25_000, text: "Fly 25 km in total")
        let reach = Goal(id: "r", kind: .reachMeters, target: 5_000, text: "Fly 5 km")
        #expect(ProgressRules.liveProgress(total, data: data) == 1)
        #expect(ProgressRules.liveProgress(reach, data: data) == 0)
        data.goalProgress["r"] = 0.5
        #expect(ProgressRules.liveProgress(reach, data: data) == 0.5)
    }

    @Test func calloutIsOnTheBirdsHalfAndClearOfTheFold() {
        let size = CGSize(width: 240, height: 52)    // PerfectCalloutView.size
        for c in testCanvases {
            let bp = c.birdPage
            // Birds anywhere on their page, high and low.
            for fy in [0.15, 0.5, 0.85] {
                let bird = CGPoint(x: bp.minX + bp.width * 0.6, y: c.size.height * fy)
                let p = CalloutPlacement.center(bird: bird, birdRadius: 44, size: size, canvas: c)
                let box = CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width,
                                 height: size.height)
                #expect(c.isFoldClear(box), "callout \(box) on the fold of \(c.size)")
                #expect(box.minX >= bp.minX - 0.5 && box.maxX <= bp.maxX + 0.5, "callout off the bird page")
                #expect(box.minY >= c.top - 0.5 && box.maxY <= c.bottom + 0.5)
            }
            let h = HomeLayout.make(c)
            #expect(c.isFoldClear(h.textBlock))
        }
    }

    #if DEBUG
    @Test func newDemoKeys() {
        let c = DemoConfig.parse("freezeOn=countdown;freezeDelay=0.12")
        #expect(c.freezeOn == .countdown)
        #expect(c.freezeDelay == 0.12)
        #expect(DemoConfig.parse("").freezeDelay == DemoConfig.defaultFreezeDelay)
    }
    #endif
}

// MARK: - Round 3

struct RoundThreeRuleTests {
    @Test func hintCoachRetiresHintsBySuccess() {
        var coach = HintCoach(learned: [])
        _ = coach.step(time: 0, flying: true, slope: -0.1, skimming: false, tuck: 0, events: [])
        #expect(coach.current == .fold)
        _ = coach.step(time: 0.1, flying: true, slope: -0.1, skimming: false, tuck: 0.7, events: [])
        let learned = coach.step(time: 0.45, flying: true, slope: -0.1, skimming: false, tuck: 0.7, events: [])
        #expect(learned == ["fold"])
        #expect(coach.done)
        _ = coach.step(time: 1.1, flying: true, slope: 0, skimming: false, tuck: 0, events: [])
        #expect(coach.current == nil)
        _ = coach.step(time: 1.2, flying: true, slope: 0.1, skimming: true, tuck: 0.6, events: [])
        #expect(coach.current == .open)
        let open = coach.step(time: 1.3, flying: true, slope: 0.1, skimming: false, tuck: 0.1,
                              events: [.launched(speed: 900)])
        #expect(open == ["open"])
        #expect(coach.learned == ["fold", "open"])
    }

    @Test func hintCoachTimesOutAndGivesUpAfterThreeTries() {
        var coach = HintCoach(learned: [])
        var shown = 0
        var t = 0.0
        for _ in 0..<6 {
            _ = coach.step(time: t, flying: true, slope: -0.1, skimming: false, tuck: 0, events: [])
            if coach.current == .fold { shown += 1 }
            t += HintCoach.timeout + 0.1
            _ = coach.step(time: t, flying: true, slope: -0.1, skimming: false, tuck: 0, events: [])
            #expect(coach.current == nil)
            t += 0.1
        }
        #expect(shown == HintCoach.maxTries)
        // A splash before any Perfect teaches landing, once.
        var land = HintCoach(learned: ["fold", "open"])
        let first = land.step(time: 0, flying: true, slope: 0, skimming: false, tuck: 0,
                              events: [.touchdown(.splash, speed: 400, chain: 0)])
        #expect(land.current == .land)
        #expect(first == ["land"])
    }

    @Test func foldToFlyArmsFillsAndFires() {
        var f = FoldToFly()
        #expect(!f.update(u: 0, now: 0, cardAge: 0.2, closing: false).armedNow)     // the card is too new
        _ = f.update(u: 0, now: 0.0, cardAge: 1, closing: false)
        #expect(f.update(u: 0, now: 0.5, cardAge: 1.5, closing: false).armedNow)
        #expect(abs(f.update(u: 0.35, now: 0.6, cardAge: 1.6, closing: false).fill - 0.5) < 1e-9)
        _ = f.update(u: 0.8, now: 0.7, cardAge: 1.7, closing: false)
        _ = f.update(u: 0.8, now: 0.96, cardAge: 1.96, closing: false)
        #expect(f.phase == .folded)
        #expect(f.update(u: 0.1, now: 1.2, cardAge: 2.2, closing: false).fired)
        #expect(f.phase == .idle)
        // Closing disarms.
        var g = FoldToFly()
        _ = g.update(u: 0, now: 0, cardAge: 1, closing: false)
        _ = g.update(u: 0, now: 0.6, cardAge: 1.6, closing: false)
        #expect(g.phase == .armed)
        #expect(g.update(u: 0.9, now: 0.7, cardAge: 1.7, closing: true).fill == 0)
        #expect(g.phase == .idle)
    }

    @Test func splitDeckAndCoverPoses() {
        let tabletop = CGSize(width: 669, height: 951)
        let cover = CGSize(width: 466, height: 678)
        #expect(AppPoseRule.pose(canvas: tabletop, hingeSeen: true, isShut: false, inRun: true) == .deck)
        #expect(AppPoseRule.pose(canvas: tabletop, hingeSeen: true, isShut: false, inRun: false) == .turn)
        #expect(AppPoseRule.pose(canvas: cover, hingeSeen: true, isShut: false, inRun: true, coverFlying: true) == .deck)
        #expect(AppPoseRule.pose(canvas: cover, hingeSeen: true, isShut: false, inRun: true) == .closed)
        #expect(AppPoseRule.pose(canvas: cover, hingeSeen: true, isShut: false, inRun: false, coverFlying: true)
                == .closed)
        #expect(AppPoseRule.pose(canvas: CGSize(width: 402, height: 874), hingeSeen: false, isShut: false,
                                 inRun: true) == .turn)
        // The deck keeps the seated fold band (y 456–496) clear.
        let inner = DeckLayout.make(canvas: tabletop)
        #expect(inner.band.minY == 8)
        #expect(inner.band.maxY <= 456)
        #expect(inner.deck.minY >= 496)
        #expect(inner.deck.maxY == 951)
        let small = DeckLayout.make(canvas: cover)
        #expect(small.band.height == 328)
        #expect(small.deck.minY == 336)
        let deckHeight: CGFloat = 678 - 336
        #expect(abs(small.deck.height - deckHeight) < 0.5)
    }

    @Test func countdownWordsSitOnCoresTicks() {
        let total = Tuning.restartCountdownDuration
        let goAt = AppRules.shortCountdownGoAt(total: total)
        let ticks = FlightSession.countdownTicks(duration: total)
        #expect(ticks.count >= 2)
        if ticks.count >= 2 { #expect(goAt == ticks[1].at) }
        #expect(AppRules.shortCountdownWord(remaining: total, total: total) == "Ready")
        #expect(AppRules.shortCountdownWord(remaining: total - goAt + 0.01, total: total) == "Ready")
        #expect(AppRules.shortCountdownWord(remaining: total - goAt, total: total) == "Go")
        #expect(AppRules.shortCountdownWord(remaining: 0.05, total: total) == "Go")
    }

    @Test func hudRules() {
        #expect(AppRules.bestIn(meters: 5_700, best: 6_000, isFlight: true) == 300)
        #expect(AppRules.bestIn(meters: 4_000, best: 6_000, isFlight: true) == nil)
        #expect(AppRules.bestIn(meters: 5_700, best: 6_000, isFlight: false) == nil)
        #expect(AppRules.bestIn(meters: 500, best: 900, isFlight: true) == nil)
        #expect(AppRules.bestIn(meters: 6_100, best: 6_000, isFlight: true) == nil)
        for km in [0, 1, 2, 3, 4, 6, 7] { #expect(!AppRules.milestoneToasts(km: km)) }
        #expect(ChainPill.text(chain: 1, tailwind: false) == nil)
        #expect(ChainPill.text(chain: 5, tailwind: false) == "×5")
        #expect(ChainPill.text(chain: 5, tailwind: true) == "×5 · TAILWIND")
        #expect(ChainPill.text(chain: 2, tailwind: false, teach: true) == "×2 in a row")
        #expect(ChainPill.text(chain: 3, tailwind: true, teach: true) == "×3 · TAILWIND")
        #expect(AppRules.countdownLine(touch: true, flat: true) == "Hold to dive · let go to soar")
        #expect(AppRules.countdownLine(touch: false, flat: true) == "Bend it a little, like a book")
        #expect(AppRules.countdownLine(touch: false, flat: false) == "Wings open, hold steady")
    }

    @Test func frameRateAndEffects() {
        #expect(RootView.framesPerSecond(playing: true, thermalHot: false, lowPower: false) == 120)
        #expect(RootView.framesPerSecond(playing: false, thermalHot: false, lowPower: false) == 60)
        #expect(RootView.framesPerSecond(playing: true, thermalHot: true, lowPower: false) == 60)
        #expect(RootView.framesPerSecond(playing: true, thermalHot: false, lowPower: true) == 60)
        #expect(SceneAdapter.effectsQuality(thermalHot: false, lowPower: false) == 1)
        #expect(SceneAdapter.effectsQuality(thermalHot: true, lowPower: false) == 0.7)
        #expect(SceneAdapter.effectsQuality(thermalHot: false, lowPower: true) == 0.7)
        #expect(AppHapticLevel.defaultLevel(isDuo: true) == .strong)
        #expect(AppHapticLevel.defaultLevel(isDuo: false) == .normal)
    }

    @Test func designToScreenPoints() {
        let c = canvas(951, 669, fold: true)
        let top = c.screenPoint(CGPoint(x: 0, y: c.layout.size.height))
        #expect(abs(top.y - (c.size.height - c.layout.size.height * c.scale) / 2) < 0.5)
        let bottom = c.screenPoint(CGPoint(x: 0, y: 0))
        #expect(bottom.y > top.y)
        #expect(abs(c.screenPoint(CGPoint(x: c.layout.size.width / 2, y: 0)).x - c.size.width / 2) < 1)
        // The deck canvas is one page: everything is fold-clear.
        let deck = AppCanvas(size: CGSize(width: 669, height: 447), insets: EdgeInsets(),
                             layout: ScreenLayout.make(canvas: CGSize(width: 669, height: 447), hasFold: false,
                                                       mirrored: false), singlePage: true)
        #expect(deck.leftPage == deck.rightPage)
        #expect(deck.isFoldClear(CGRect(x: 300, y: 0, width: 100, height: 100)))
    }

    @Test func homeCopy() {
        #expect(HomeView.captionText(duo: true, folded: false, flat: false)
                == "Hold your Duo like a book. These are your wings.")
        #expect(HomeView.captionText(duo: true, folded: true, flat: false) == "Fold to dive. Open to soar.")
        #expect(HomeView.captionText(duo: true, folded: true, flat: true) == "Bend it a little, like a book.")
        #expect(HomeView.captionText(duo: false, folded: false, flat: true) == "Press and hold anywhere. That's a tuck.")
        #expect(HomeView.captionText(duo: false, folded: true, flat: false) == "Hold to dive. Let go to soar.")
        // R6 (UX §4.5): "Next: …", dropping the best, then "Next:", to fit; never an ellipsis.
        // R7 P1-6: the goal sentence under Fly until the first lighthouse is reached.
        #expect(HomeView.flySubtitle(best: 0) == "Outfly the storm. Reach the next lighthouse.")
        #expect(HomeView.flySubtitle(best: 6_420, routeReached: 1) == "Next: Saltlight · 9 km · best 6.42 km")
        #expect(HomeView.flySubtitle(best: 6_420, routeReached: 1, compact: true) == "Next: Saltlight · 9 km")
        #expect(RouteRules.homeNext(routeReached: 1, best: 6_420, maxChars: 12) == "→ Saltlight · 9 km")
        #expect(ProgressRules.goalsLine(rank: 0, done: 1, total: 3, starFlocks: 0) == "1 of 3 · Fledgling")
        #expect(ProgressRules.goalsLine(rank: GoalCatalog.maxRank, done: 0, total: 3, starFlocks: 2)
                == "Storm Rider ★2")
        #expect(ShareText.nextIn(seconds: 6 * 3600 + 12 * 60) == "6 h 12 m")
        #expect(ShareText.nextIn(seconds: 59) == "1 m")
        #expect(ShareText.nextIn(seconds: 0) == "1 m")
        #expect(ShareText.nextInShort(seconds: 6 * 3600 + 59 * 60) == "6 h")
        #expect(ShareText.nextInShort(seconds: 600) == "10 m")
        let midnight = DailySeed.utc.startOfDay(for: Date()).addingTimeInterval(86_400 - 90)
        #expect(abs(ShareText.secondsToNextDaily(now: midnight) - 90) < 0.5)
    }

    @Test func resultsCopy() {
        #expect(ResultsView.classify(isDailyCard: true, dailyDay: 3, practice: false, title: "") == .dailyCard)
        #expect(ResultsView.classify(isDailyCard: false, dailyDay: 3, practice: false, title: "") == .scoredDaily)
        #expect(ResultsView.classify(isDailyCard: false, dailyDay: 3, practice: true, title: "") == .practiceDaily)
        #expect(ResultsView.classify(isDailyCard: false, dailyDay: nil, practice: false, title: "First flight")
                == .firstFlight)
        // Before launch the Daily shows its date (R5: no "3-day streak" on "#1"); from launch, its number.
        #expect(ResultsView.overline(.dailyCard, day: DailySeed.launchDay + 9) == "Daily Flight #10")
        #expect(ResultsView.overline(.firstFlight, day: nil) == "First flight")
        #expect(ResultsView.bestLine(.firstFlight, showsNewBest: false, best: 2_100, previousBest: 0) == nil)
        #expect(ResultsView.bestLine(.flight, showsNewBest: true, best: 7_000, previousBest: 6_420)
                == "Previous best 6.42 km")
        #expect(ResultsView.bestLine(.flight, showsNewBest: false, best: 6_420, previousBest: 6_420) == "Best 6.42 km")
        // R4 P1-7: a Daily never shows the Flight best under it.
        #expect(ResultsView.bestLine(.dailyCard, showsNewBest: false, best: 6_420, previousBest: 6_420) == nil)
        #expect(ResultsView.chip(showsNewBest: false, dailyBest: true, kind: .scoredDaily) == "Daily best!")
        #expect(ResultsView.chip(showsNewBest: true, dailyBest: true, kind: .scoredDaily) == "New best!")
        #expect(ResultsView.chip(showsNewBest: false, dailyBest: true, kind: .flight) == nil)
        #expect(ResultsView.countUp(meters: 4_000, t: 0, duration: 0.8) == 0)
        #expect(ResultsView.countUp(meters: 4_000, t: 0.8, duration: 0.8) == 4_000)
        let mid = ResultsView.countUp(meters: 4_000, t: 0.4, duration: 0.8)
        #expect(mid > 3_000 && mid < 4_000)                  // ease-out expo: most of it early
        #expect(ResultsView.countUp(meters: 4_000, t: 0.1, duration: 0) == 4_000)
        #expect(ResultsView.streakText(streak: 3, nextIn: "6 h 12 m") == "3-day streak · next Daily in 6 h 12 m")
        #expect(ResultsView.streakText(streak: 1, nextIn: "2 h 0 m") == "Next Daily in 2 h 0 m")
        var summary = ResultSummary(result: makeRun(mode: .daily(day: 298, scored: true), perfects: 23,
                                                    lastLighthouse: "Saltlight"),
                                    outcome: RecordOutcome(), title: "Daily Flight #298", dailyDay: 298,
                                    practice: false, share: "")
        #expect(ShareCardView.subtitle(summary) == "Daily Flight 26 Oct · 23 Perfects · past Saltlight")
        #expect(ResultsView.smallLines(summary).isEmpty)
        summary.outcome.newLogbook = ["Saltlight"]
        summary.outcome.dailyGraceKept = true
        summary.showsRestLine = true
        // R6: "New in the logbook" is cut (the headline chip "New on your route" carries it).
        #expect(ResultsView.smallLines(summary) == ["Calm sea: streak kept",
                                                    "Long flight. Your wings can rest; the Daily will wait."])
        #expect(ResultsView.smallLines(summary, limit: 1).count == 1)
        summary.outcome.starEarned = true
        #expect(ResultsView.smallLines(summary).contains("Star goals done ★"))
        #expect(RankUpBanner.newGoalsLine(rank: 1).hasPrefix("New goals: "))
    }

    @Test func pagesCopy() {
        #expect(FlocksView.rankLine(rank: 1) == "Rank 2 of 15")
        #expect(FlocksView.nextRankLine(rank: GoalCatalog.maxRank, unlocks: []) == nil)
        #expect(FlocksView.nextRankLine(rank: 0, unlocks: ["Tern"]) == "Next rank: Tern")
        #expect(FlocksView.logbookLine(count: 12, total: 40) == "Logbook 12 of 40")
        #expect(BirdsView.nextUnlockRank([0, 1, 1, 3, 5], current: 1) == 3)
        #expect(BirdsView.nextUnlockRank([0, 1], current: 4) == nil)
        #expect(BirdsView.lockedLabel(unlockRank: 3, next: 3) == "Rank 4 goals")
        #expect(BirdsView.lockedLabel(unlockRank: 5, next: 3) == nil)
        #expect(ClosedCard.dartWidth(.home) == 150)
        #expect(ClosedCard.heroDistance(18_574) == "18.57 km")
        #expect(ClosedCard.heroDistance(842) == "842 m")
        #expect(ClosedCard.stormFill(0) == 0)
        #expect(ClosedCard.stormFill(.nan) == 0)
        #expect(ClosedCard.stormFill(400) < ClosedCard.stormFill(800))
        #expect(ClosedCard.stormLine(0).close)
        #expect(ClosedCard.stormLine(250).text == "Storm 250 m behind")
        #expect(ClosedCard.stormLine(250).close)
        #expect(!ClosedCard.stormLine(900).close)
        #expect(ClosedCard.stormLine(1_200).text == "Storm 1.20 km behind")
        #expect(ClosedCard.bestLine(meters: 4_000, best: 0) == "No best yet: this flight sets it")
        #expect(ClosedCard.bestLine(meters: 5_500, best: 6_100) == "600 m to your best")
        #expect(ClosedCard.bestLine(meters: 4_000, best: 6_100) == "Beat 6.10 km to set a best")
        #expect(ClosedCard.bestLine(meters: 7_000, best: 6_100) == "Past your best")
    }

    @Test func migrationAndDailyGuards() throws {
        let v1 = Data(#"{"version": 1, "rank": 20, "goalProgress": {"r0-reach": 0.5}, "hintsLearned": true, "bestMeters": 900}"#.utf8)
        let data = try #require(ProgressStore.decode(v1))
        #expect(data.version == ProgressData.currentVersion)
        #expect(data.goalProgress.isEmpty)
        #expect(data.rank == GoalCatalog.maxRank)
        #expect(data.learnedHints == ["fold", "open"])
        #expect(data.bestMeters == 900)
        #expect(data.starFlocks == 0)
        #expect(data.lastDailyDay == Int.min)
        // QA-2 P2-8: a clock set back never scores an older Daily.
        #expect(ProgressRules.dailyMayScore(day: 300, lastDailyDay: 300))
        #expect(ProgressRules.dailyMayScore(day: 301, lastDailyDay: 300))
        #expect(!ProgressRules.dailyMayScore(day: 299, lastDailyDay: 300))
        #expect(ProgressRules.dailyMayScore(day: 1, lastDailyDay: Int.min))
        let grace = ProgressRules.streakWithGrace(days: [3, 4, 6], today: 6)
        #expect(grace.streak == 3 && grace.graceKept)
        #expect(!ProgressRules.streakWithGrace(days: [5, 6], today: 6).graceKept)
        #expect(ProgressRules.streakWithGrace(days: [Int.max - 1, Int.max], today: Int.max).streak == 2)
    }

    @Test func starFlocksPastTheTop() {
        var data = ProgressData()
        data.rank = 2
        let stars: (Int) -> [Goal] = { n in
            [Goal(id: "s\(n)", kind: .reachMeters, target: 500, text: "Fly 0.5 km")]
        }
        let out = ProgressRules.record(makeRun(meters: 900), into: &data, today: 1, goals: fakeGoals, maxRank: 2,
                                       evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails, stars: stars)
        #expect(out.starEarned)
        #expect(out.rankUp == nil)
        #expect(data.rank == 2)
        #expect(data.starFlocks == 1)
        #expect(data.goalProgress["s0"] == nil)
        #expect(ProgressRules.currentGoals(rank: GoalCatalog.maxRank, starFlocks: 1).count == 3)
        #expect(ProgressRules.currentGoals(rank: 0, starFlocks: 9).map(\.id) == GoalCatalog.goals(forRank: 0).map(\.id))
    }

    @Test func logbookFillsFromLighthouses() {
        var data = ProgressData()
        let out = ProgressRules.record(makeRun(meters: 9_000, lighthouses: 2), into: &data, today: 1, goals: fakeGoals,
                                       maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(out.newLogbook.count == 2)
        #expect(data.logbook.count == 2)
        let again = ProgressRules.record(makeRun(meters: 9_000, lighthouses: 2), into: &data, today: 1,
                                         goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks,
                                         trailUnlocks: noTrails)
        #expect(again.newLogbook.isEmpty)
    }

    #if DEBUG
    @Test func roundThreeDemoKeys() {
        let c = DemoConfig.parse("screen=cover;cover=midrun;titleTuck=0.8;folded;flat;dailyToday;rankUp;closing;"
                                 + "holdReady;foldFill=0.6;orient=portrait")
        #expect(c.screen == .cover)
        #expect(c.coverState == .midrun)
        #expect(c.titleTuck == 0.8)
        #expect(c.folded && c.flat && c.dailyToday && c.rankUp && c.closing && c.holdReady && c.orientPortrait)
        #expect(c.foldFill == 0.6)
        #expect(DemoConfig.parse("screen=daily").effectiveScreen == .daily)
        #expect(DemoConfig.parse("cover=nope").coverState == .home)
        #expect(DemoConfig.parse("titleTuck=9").titleTuck == 1)
    }
    #endif
}

@MainActor
struct RoundThreeStoreTests {
    @Test func dailyEntriesKeepTheLargerAndTheCapSparesBests() {
        let daily = GameCenterManager.Leaderboard.daily
        let longest = GameCenterManager.Leaderboard.longest
        var q: [String] = []
        q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: daily, score: 1_000, day: 300, token: "a"),
                                      into: q)
        q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: daily, score: 2_000, day: 300, token: "b"),
                                      into: q)
        q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: daily, score: 500, day: 300, token: "c"),
                                      into: q)
        #expect(q.count == 1)
        #expect(GameCenterManager.parse(q[0])?.score == 2_000)
        for i in 0..<25 {
            q = GameCenterManager.enqueue(GameCenterManager.encode(leaderboard: longest, score: i, day: nil,
                                                                   token: "l\(i)"), into: q, cap: 20)
        }
        #expect(q.count == 20)
        #expect(q.compactMap { GameCenterManager.parse($0) }.allSatisfy { $0.leaderboard == longest })
    }

    @Test func hapticLevelPersistsOnlyWhenChosen() throws {
        let suite = "swoop.tests.haptics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let s = SettingsStore(defaults: defaults)
        #expect(s.chosenHapticLevel == nil)
        s.isDuo = true
        #expect(s.hapticLevel == .strong)
        s.hapticLevel = .off
        let again = SettingsStore(defaults: defaults)
        #expect(again.chosenHapticLevel == .off)
        #expect(!again.hapticsOn)
        // A v1 save with haptics off reads as a chosen Off.
        let legacy = try #require(SettingsStore.decode(Data(#"{"hapticsOn": false}"#.utf8)))
        #expect(legacy.hapticLevel == .off)
        let fresh = try #require(SettingsStore.decode(Data("{}".utf8)))
        #expect(fresh.hapticLevel == nil)
        #expect(!fresh.tuckByTapping && !fresh.tapOfferAnswered)
    }
}

// MARK: - Round 4

private func deckCanvas(_ w: CGFloat, _ h: CGFloat) -> AppCanvas {
    let size = CGSize(width: w, height: h)
    return AppCanvas(size: size, insets: EdgeInsets(),
                     layout: ScreenLayout.make(canvas: size, hasFold: false, mirrored: false), singlePage: true)
}

/// Every results variant the game can show, at its worst (long lines, every optional row on).
private func resultsVariants() -> [ResultSummary] {
    let goals = GoalCatalog.goals(forRank: 1)
    let rows = goals.enumerated().map { i, g in GoalRowOutcome(goal: g, before: 0.2, after: i == 0 ? 1 : 0.6) }
    func summary(_ mode: RunMode, title: String, day: Int?, practice: Bool) -> ResultSummary {
        ResultSummary(result: makeRun(mode: mode, meters: 12_840, perfects: 17, bestChain: 6, lighthouses: 2,
                                      lastLighthouse: "Saltlight"),
                      outcome: RecordOutcome(), title: title, dailyDay: day, practice: practice, share: "s")
    }
    var first = summary(.flight, title: "First flight", day: nil, practice: false)
    first.outcome.isNewBest = true
    first.outcome.goals = rows
    first.showsFoldHelper = true
    var rankUp = summary(.flight, title: "Flight", day: nil, practice: false)
    rankUp.outcome.isNewBest = true
    rankUp.outcome.previousBest = 9_000
    rankUp.outcome.best = 12_840
    rankUp.outcome.goals = rows
    rankUp.outcome.rankUp = AppRankUp(from: 0, to: 1, birds: [.tern], skies: [.roseDusk], trails: ["coral"])
    rankUp.outcome.newLogbook = ["Old Harry", "Saltlight", "Wicklight", "Farthing Light", "Brightwater Head"]
    rankUp.outcome.starEarned = true
    rankUp.showsRestLine = true
    rankUp.showsFoldHelper = true
    var goalsRun = summary(.flight, title: "Flight", day: nil, practice: false)
    goalsRun.outcome.best = 14_000
    goalsRun.outcome.previousBest = 14_000
    goalsRun.outcome.goals = rows
    goalsRun.outcome.newLogbook = ["Old Harry", "Saltlight"]
    goalsRun.showsRestLine = true
    goalsRun.showsFoldHelper = true
    var daily = summary(.daily(day: 400, scored: true), title: "Daily Flight #74", day: 400, practice: false)
    daily.outcome.isNewBest = true
    daily.outcome.previousBest = 9_000
    daily.outcome.dailyCounted = true
    daily.outcome.dailyStreak = 4
    daily.outcome.dailyGraceKept = true
    daily.outcome.goals = rows
    daily.outcome.rankUp = AppRankUp(from: 0, to: 1, birds: [.tern], skies: [], trails: [])
    daily.outcome.newLogbook = ["Old Harry", "Saltlight", "Wicklight", "Farthing Light"]
    daily.showsRestLine = true
    daily.dailyBest = true
    var practice = summary(.daily(day: 400, scored: false), title: "Daily Flight #74 · Practice", day: 400,
                           practice: true)
    practice.outcome.goals = rows
    var card = summary(.daily(day: 400, scored: true), title: "Daily Flight #74", day: 400, practice: false)
    card.isDailyCard = true
    card.dailySpentUnfiled = true
    card.outcome.dailyStreak = 6
    return [first, rankUp, goalsRun, daily, practice, card]
}

struct RoundFourTests {
    /// R4 P0-1: nothing on the results clips, on any canvas, in any variant (with and without the Daily row).
    @Test func resultsFitEveryCanvas() {
        let canvases = testCanvases + [deckCanvas(669, 447.5), deckCanvas(466, 342)]
        for c in canvases {
            let far = ResultsLayout.far(c)
            let side = ResultsLayout.side(c)
            for s in resultsVariants() {
                for dailyRow in [false, true] {
                    let plan = ResultsPlan.make(s, canvas: c, cardHeight: far.height, dailyRowAllowed: dailyRow)
                    #expect(plan.farHeight() <= far.height,
                            "far card \(plan.farHeight()) > \(far.height) on \(c.size) for \(s.title)")
                    if plan.twoPages {
                        #expect(plan.sideHeight(width: side.width) <= side.height,
                                "side card \(plan.sideHeight(width: side.width)) > \(side.height) on \(c.size) for \(s.title)")
                        #expect(c.isFoldClear(side))
                        #expect(c.isFoldClear(far))
                    } else {
                        #expect(!plan.hasSideCard || plan.deckSummary || !plan.twoPages)
                    }
                }
            }
        }
    }

    @Test func resultsPutTheRewardOnTheBirdPage() {
        let duo = canvas(951, 669, fold: true)
        let rankUp = resultsVariants()[1]
        let plan = ResultsPlan.make(rankUp, canvas: duo, cardHeight: ResultsLayout.far(duo).height, dailyRowAllowed: true)
        #expect(plan.twoPages && plan.rankUp && plan.hasSideCard)
        #expect(ResultsLayout.side(duo).maxX <= duo.foldMinX)
        #expect(ResultsLayout.far(duo).minX >= duo.foldMaxX)
        let mirrored = canvas(951, 669, fold: true, mirrored: true)
        #expect(ResultsLayout.side(mirrored).minX >= mirrored.foldMaxX)
        // The split deck: one card with the one-line summary.
        let deck = ResultsPlan.make(rankUp, canvas: deckCanvas(669, 447.5), cardHeight: 423.5, dailyRowAllowed: true)
        #expect(!deck.twoPages && deck.deckSummary && deck.compact)
        #expect(ResultsView.deckSummary(rankUp)?.hasPrefix("You ranked up! New bird: Tern") == true)
        #expect(ResultsView.deckSummary(rankUp)?.contains("Rank 2 · ") == true)
        var two = resultsVariants()[2]
        two.outcome.rankUp = nil
        #expect(ResultsView.deckSummary(two)?.hasPrefix("1 of 3 goals · next: ") == true)
        #expect(ResultsView.lastSevenDays(ProgressData(), today: 10) == Array(repeating: false, count: 7))
    }

    @Test func oneDistanceFormatter() {
        #expect(ShareText.distance(89) == "89 m")
        #expect(ShareText.distance(0) == "0 m")
        #expect(ShareText.distance(.nan) == "0 m")
        #expect(ShareText.distance(11_885) == "11.88 km")
        #expect(ShareText.distance(541, roundUp: true) == "550 m")
        #expect(ShareText.distance(996, roundUp: true) == "1.00 km")
        #expect(ShareText.target(3_000) == "3 km")
        #expect(ShareText.target(500) == "500 m")
        #expect(ShareText.target(2_500) == "2.50 km")
        // The pause card and the cover use the same words as the HUD: never "Paused at 0.0 km" at 89 m.
        #expect(ClosedCard.heroDistance(89) == ShareText.distance(89))
    }

    @Test func textOverTheSunReads() {
        #expect(Contrast.overSun(text: 0xF2F7FA) >= 4.5)
        #expect(Contrast.overSun(text: 0xF2F7FA, scrimAlpha: 0.55) < 4.5)    // why 0.62, not 0.55
        #expect(Contrast.ratio(Contrast.rgb(0xFFFFFF), Contrast.rgb(0x000000)) > 20.9)
        let usual = CGPoint(x: 700, y: 270)
        #expect(AppRules.stageCenter(usual: usual, sun: nil, height: 669) == usual)
        #expect(AppRules.stageCenter(usual: usual, sun: CGPoint(x: 700, y: 600), height: 669) == usual)
        let moved = AppRules.stageCenter(usual: usual, sun: CGPoint(x: 720, y: 300), height: 669)
        #expect(moved != usual)
        // A sun mid-height sits between the high (0.28 h) and low (0.62 h) stages, so the best move is ~113 pt;
        // the navy backing (4.5:1, above) covers what's left.
        #expect(abs(moved.y - 300) > 100)
    }

    @Test func dailyIsNumberedFromLaunch() {
        #expect(AppRules.dailyNumber(day: DailySeed.launchDay) == 1)
        #expect(AppRules.dailyNumber(day: DailySeed.launchDay + 9) == 10)
        #expect(AppRules.dailyNumber(day: 0) == 1)
        #expect(AppRules.dailyNumber(day: Int.min) == 1)
        for d in [DailySeed.launchDay - 5, DailySeed.launchDay, DailySeed.launchDay + 300] {
            #expect(AppRules.dailyNumber(day: d) == DailySeed.displayNumber(day: d))
        }
    }

    @MainActor
    @Test func oneMilestoneRuleEverywhere() {
        for n in 0...80 {
            let app = AppRules.isChainMilestone(n)
            #expect(app == FlightScene.isChainMilestone(n), "scene disagrees at \(n)")
            #expect(app == FeedbackDirector.isPerfectMilestone(chain: n), "feel disagrees at \(n)")
        }
        #expect(AppRules.isChainMilestone(3) && AppRules.isChainMilestone(5) && AppRules.isChainMilestone(10))
        #expect(!AppRules.isChainMilestone(4) && !AppRules.isChainMilestone(7))
        #expect(!AppRules.showsPerfectCallout(chain: 4, tailwind: false))
        #expect(AppRules.showsPerfectCallout(chain: 4, tailwind: true))
        #expect(AppRules.milestoneHitStop == Double(FeelSoundBook.hitStop))
    }

    @Test func goalCaptionsStateTheirScope() {
        let lighthouses = Goal(id: "l", kind: .lighthouses, target: 4, text: "Pass 4 lighthouses in one flight")
        let run = makeRun(meters: 9_000, lighthouses: 2)
        #expect(AppRules.goalCaption(lighthouses, before: 0.5, run: run, lifetime: 0) == "This flight: 2 of 4")
        #expect(AppRules.goalCaption(lighthouses, before: 1, run: run, lifetime: 0) == "Done in an earlier flight")
        #expect(AppRules.goalCaption(lighthouses, before: 0, run: nil, lifetime: 0) == "In one flight")
        let total = Goal(id: "t", kind: .totalMeters, target: 150_000, text: "Fly 150 km in total")
        #expect(AppRules.goalCaption(total, before: 0, run: run, lifetime: 48_300) == "In total · 48.30 km of 150 km")
        let reach = Goal(id: "r", kind: .reachMeters, target: 3_000, text: "Fly 3 km in one flight")
        #expect(AppRules.goalCaption(reach, before: 0, run: makeRun(meters: 1_180), lifetime: 0)
                == "This flight: 1.18 km of 3 km")
    }

    @Test func hintAndSplashSitOffTheBird() {
        let size = CGSize(width: 300, height: 56)
        for c in testCanvases where !c.hasFold {
            for fy in [0.3, 0.5, 0.7, 0.9] {
                let bird = CGPoint(x: c.birdPage.minX + c.birdPage.width * 0.55, y: c.size.height * fy)
                let box = HintPlacement.box(center: HintPlacement.center(bird: bird, size: size, canvas: c), size: size)
                #expect(!box.insetBy(dx: 0, dy: -20).contains(bird), "hint covers the bird on \(c.size) at \(fy)")
                #expect(box.minY >= c.top + CalloutPlacement.hudBand + 15.5)
                let s = SplashPlacement.center(bird: bird, canvas: c)
                #expect(c.birdPage.insetBy(dx: -1, dy: 0).contains(CGPoint(x: s.x, y: c.size.height / 2)))
            }
        }
        #expect(HUDSplashMark(lostChain: 4, point: .zero, serial: 1).text == "Splash · ×4 lost")
        #expect(HUDSplashMark(lostChain: 2, point: .zero, serial: 1).text == "Splash")
        #expect(HUDSplashMark(lostChain: nil, point: .zero, serial: 1).text == "Splash")
    }

    @Test func hingeComfortRules() {
        #expect(AppRules.readyHold(afterCover: true, normal: 1.5) == 2.8)
        #expect(AppRules.readyHold(afterCover: false, normal: 1.5) == 1.5)
        #expect(AppRules.countdownLine(touch: false, flat: false, nudge: true) == "Open a little wider")
        #expect(AppRules.countdownLine(touch: true, flat: false, nudge: true) == "Hold to dive · let go to soar")
        // The title bird uses play's stroke: open 132 → full at 100°; a floored open angle.
        #expect(abs(TitleTuck.fromHinge(angle: 100, openAngle: 132) - 1) < 1e-9)
        #expect(TitleTuck.fromHinge(angle: 132, openAngle: 120) == 0)
        // No hint is offered during the fold-blur guard.
        var coach = HintCoach(learned: [])
        _ = coach.step(time: 0, flying: true, slope: -0.1, skimming: false, tuck: 0, events: [], mayOffer: false)
        #expect(coach.current == nil)
        _ = coach.step(time: 0.1, flying: true, slope: -0.1, skimming: false, tuck: 0, events: [])
        #expect(coach.current == .fold)
    }

    @Test func strokesAndReadout() {
        var s = StrokeCounter()
        for u in [0.0, 0.3, 0.6, 0.9, 1.0, 0.4, 0.1, 0.2, 0.55, 0.7, 0.15] { s.note(u) }
        #expect(s.strokes == 2)
        #expect(abs(s.meanDepth - (1.0 + 0.7) / 2) < 1e-9)
        let r = HingeReadout(angle: 150, rawAngle: 151, openAngle: 152, tuck: 0.1, reportsPerSecond: 28,
                             lastReportAge: 0.05, closing: false, shut: false, pose: "play", strokes: 2,
                             meanStrokeDepth: 0.85)
        #expect(r.lines.count == 5)
        #expect(r.lines[0] == "angle 150.0°  raw 151.0°")
        #expect(r.lines[4] == "strokes 2  mean 0.85")
        #expect(SettingsView.showsTuckBy(hasHinge: false, playWithTouch: false))
        #expect(!SettingsView.showsTuckBy(hasHinge: true, playWithTouch: false))
        #expect(SettingsView.showsTuckBy(hasHinge: true, playWithTouch: true))
    }

    @Test func dailyBestAndTouchGlyph() {
        var data = ProgressData()
        data.daily[400] = DailyRecord(meters: 5_000, perfects: 1, lighthouses: 0, lastLighthouseName: "", finished: true)
        data.daily[401] = DailyRecord(meters: 7_400, perfects: 1, lighthouses: 0, lastLighthouseName: "", finished: true)
        #expect(GameController.isDailyBest(makeRun(mode: .daily(day: 401, scored: true), meters: 7_400), data: data))
        #expect(!GameController.isDailyBest(makeRun(mode: .daily(day: 401, scored: true), meters: 4_000), data: data))
        #expect(!GameController.isDailyBest(makeRun(mode: .daily(day: 401, scored: false), meters: 9_000), data: data))
        #expect(!GameController.isDailyBest(makeRun(meters: 9_000), data: data))
        let c = canvas(874, 402, fold: false, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62))
        let g = TouchWingFeedback.glyphCenter(birdPage: c.birdPage, height: c.size.height)
        #expect(abs(g.x - (c.birdPage.minX + c.birdPage.width * 0.25)) < 0.01)    // off the thumb, off the centre
        let glyphY: CGFloat = 402 - 28                                            // under the skim line
        #expect(abs(g.y - glyphY) < 0.5)
        #expect(TouchWingFeedback.glyphAlpha(tuck: 0) == 0.55)
        #expect(abs(TouchWingFeedback.glyphAlpha(tuck: 1) - 0.9) < 1e-9)
        #expect(TouchWingFeedback.glyphAlpha(tuck: 1, birdNear: true) == 0.15)
        #expect(TouchWingFeedback.birdNear(bird: CGPoint(x: g.x + 20, y: g.y - 30), glyph: g))
        #expect(!TouchWingFeedback.birdNear(bird: CGPoint(x: g.x, y: g.y - 200), glyph: g))
        #expect(!TouchWingFeedback.birdNear(bird: nil, glyph: g))
    }

    #if DEBUG
    @Test func roundFourDemoKeys() {
        let c = DemoConfig.parse("freezeOn=flathold;paused;nudge;screen=pose;pose=phone")
        #expect(c.freezeOn == .flathold)
        #expect(c.paused && c.nudge && c.posePhone)
        #expect(!DemoConfig.parse("pose=duo").posePhone)
    }
    #endif
}

// MARK: - Round 5

struct RoundFiveTests {
    private let kinds: [ResultsView.Kind] = [.flight, .firstFlight, .scoredDaily, .practiceDaily, .dailyCard, .dailySpent]

    /// R5 P0-1: every results / Daily button has a label (its VoiceOver label too), Home and Share are the only
    /// icon-only tiles, a Flight's "Fly again" is always labelled and primary, and a spent Daily offers no Share.
    @Test func everyButtonHasALabel() {
        for kind in kinds {
            for compact in [false, true] {
                for dailyRow in [false, true] {
                    for oneRow in [false, true] {
                        let rows = ResultsButtons.rows(kind: kind, compact: compact, dailyRow: dailyRow, oneRow: oneRow,
                                                       dailyTag: "26 Oct")
                        let all = rows.flatMap { $0 }
                        #expect(!all.isEmpty)
                        #expect(rows.allSatisfy { !$0.isEmpty })
                        for b in all {
                            #expect(!b.title.trimmingCharacters(in: .whitespaces).isEmpty)
                            #expect(!b.icon.isEmpty)
                            if b.iconOnly {
                                #expect(b.action == .home || b.action == .share)
                                #expect(b.minWidth(compact: compact) == ResultsButton.tileWidth)
                            }
                        }
                        #expect(all.filter { $0.primary }.count == 1)
                        if kind == .flight || kind == .firstFlight {
                            let fly = all.first { $0.action == .flyAgain }
                            #expect(fly?.primary == true)
                            #expect(fly?.iconOnly == false)
                        }
                        if kind == .dailySpent { #expect(!all.contains { $0.action == .share }) }
                        if kind == .scoredDaily || kind == .dailyCard { #expect(all.contains { $0.action == .home }) }
                    }
                }
            }
        }
    }

    /// R5 P0-1 / P1-4: on every canvas and variant each button row fits its card, and the far card is sized to its
    /// content and bottom-anchored.
    @Test func buttonRowsFitEveryCanvas() {
        let canvases = testCanvases + [deckCanvas(669, 447.5), deckCanvas(466, 342)]
        for c in canvases {
            let far = ResultsLayout.far(c)
            for s in resultsVariants() {
                for dailyRow in [false, true] {
                    let plan = ResultsPlan.make(s, canvas: c, cardHeight: far.height, dailyRowAllowed: dailyRow)
                    #expect(plan.rowsFit(width: far.width - 2 * ResultsPlan.padding(plan.compact)),
                            "a button row overflows on \(c.size) for \(s.title)")
                    let rect = ResultsLayout.anchored(far, height: plan.farHeight())
                    #expect(abs(rect.maxY - far.maxY) < 0.01)
                    #expect(rect.height <= far.height)
                }
            }
        }
        let space = CGRect(x: 0, y: 10, width: 400, height: 600)
        #expect(ResultsLayout.anchored(space, height: 450) == CGRect(x: 0, y: 160, width: 400, height: 450))
        #expect(ResultsLayout.anchored(space, height: 900).height == 600)
    }

    @Test func aSpentDailyNeverLeadsWithZero() {
        #expect(ResultsView.classify(isDailyCard: true, dailyDay: 400, practice: false, title: "",
                                     spentUnfiled: true) == .dailySpent)
        let spent = resultsVariants()[5]
        let duo = canvas(951, 669, fold: true)
        let plan = ResultsPlan.make(spent, canvas: duo, cardHeight: ResultsLayout.far(duo).height, dailyRowAllowed: true)
        #expect(plan.kind == .dailySpent)
        #expect(!plan.shareThumb)
        #expect(!plan.hasHook)
        #expect(!plan.hasStats)
        #expect(plan.streak)
    }

    @Test func pauseCardsShowTheHUDsValue() {
        #expect(AppRules.hudMeters(89.7) == 89)
        #expect(AppRules.hudMeters(999.9) == 999)
        #expect(AppRules.hudMeters(1_234.5) == 1_230)
        #expect(AppRules.hudMeters(.nan) == 0)
        #expect(AppRules.hudMeters(-3) == 0)
        for d in [0.0, 89.4, 99.9, 101.2, 999.0, 1_004.0, 11_885.0] {
            let published = Double(AppRules.hudMeters(d))
            let hud = ShareText.hudDistance(published)
            #expect(ShareText.distance(published) == "\(hud.value) \(hud.unit)")
        }
    }

    @Test func splashAndChainBreaksAlwaysShow() {
        // The default bird spot is in the VIEW's points (ScreenLayout.size is the design canvas): on the bird page.
        let phone = canvas(874, 402, fold: false)
        let d = SceneAdapter.defaultBirdPoint(phone)
        #expect(phone.birdPage.insetBy(dx: -40, dy: 0).contains(CGPoint(x: d.x, y: 200)))
        #expect(abs(d.y - 201) < 2)
        #expect(HUDSplashMark(lostChain: 4, point: .zero, serial: 1, splash: false).text == "×4 lost")
        #expect(HUDSplashMark(lostChain: 4, point: .zero, serial: 1, splash: true).text == "Splash · ×4 lost")
        #expect(HUDSplashMark(lostChain: nil, point: .zero, serial: 1, splash: false).text == "Chain lost")
    }

    @Test func countdownNeverStartsTucked() {
        var g = AppRules.countdownGate(raw: .nudge, budgetUsed: 1, budget: 4, lowRest: nil, startTuck: 0,
                                       remaining: 1, step: 0.016)
        #expect(g.hold == .nudge)
        #expect(!g.offerTouch)
        g = AppRules.countdownGate(raw: .nudge, budgetUsed: 4, budget: 4, lowRest: .snappedToFloor, startTuck: 0.3,
                                   remaining: 1, step: 0.016)
        #expect(g.hold == .free)
        #expect(!g.offerTouch)
        g = AppRules.countdownGate(raw: .nudge, budgetUsed: 4, budget: 4, lowRest: .tooLow, startTuck: 0.9,
                                   remaining: 1, step: 0.016)
        #expect(g.hold == .nudge)
        #expect(g.offerTouch)
        g = AppRules.countdownGate(raw: .flat, budgetUsed: 4.1, budget: 4, lowRest: nil, startTuck: 0, remaining: 1,
                                   step: 0.016)
        #expect(g.hold == .free)
        g = AppRules.countdownGate(raw: .free, budgetUsed: 0, budget: 4, lowRest: nil, startTuck: 0.6,
                                   remaining: 0.01, step: 0.016)
        #expect(g.hold == .nudge)
        #expect(!g.offerTouch)
        g = AppRules.countdownGate(raw: .free, budgetUsed: 0, budget: 4, lowRest: nil, startTuck: 0.6,
                                   remaining: 0.9, step: 0.016)
        #expect(g.hold == .free)
        g = AppRules.countdownGate(raw: .free, budgetUsed: 4, budget: 4, lowRest: nil, startTuck: 0.7,
                                   remaining: 0.01, step: 0.016)
        #expect(g.hold == .nudge)
        #expect(g.offerTouch)
    }

    @Test func dailyTagAndWeekdays() {
        #expect(AppRules.dailyTag(day: 298) == "26 Oct")
        #expect(AppRules.dailyTag(day: DailySeed.launchDay) == "#1")
        #expect(AppRules.dailyTag(day: DailySeed.launchDay + 41) == "#42")
        #expect(AppRules.weekdayInitial(day: 0) == "T")      // 2026-01-01 was a Thursday
        #expect(AppRules.weekdayInitial(day: 3) == "S")
        #expect(AppRules.weekdayInitial(day: 4) == "M")
        #expect(HomeView.captionText(duo: true, folded: false, flat: false, lowRest: true) == "Open it a little wider.")
        #expect(HomeView.captionText(duo: false, folded: false, flat: false, lowRest: true)
                == "Press and hold anywhere. That's a tuck.")
    }

    @Test func goalsMetByBestsCompleteAtOnce() {
        var data = ProgressData()
        data.bestMeters = 12_160
        data.bestChain = 9
        data.bestPerfectsInRun = 40
        let reach = Goal(id: "g", kind: .reachMeters, target: 3_000, text: "Fly 3 km in one flight")
        #expect(ProgressRules.bestProgress(reach, data: data) == 1)
        #expect(ProgressRules.bestProgress(Goal(id: "s", kind: .speed, target: 1, text: "x"), data: data) == 0)
        // A rank whose goals the bests already meet ticks them all on the next run and ranks up.
        data.rank = 1
        let out = ProgressRules.record(makeRun(meters: 300, perfects: 0, bestChain: 0), into: &data, today: 1,
                                       goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks,
                                       trailUnlocks: noTrails)
        #expect(out.goals.allSatisfy { $0.isMet })
        #expect(out.goals.allSatisfy { $0.justMet })
        // The cascade: fake rank r needs 1000(r+1) m, 5(r+1) Perfects and a chain of 3+r, so bests of 12.16 km, 40
        // and 9 carry the player from rank 1 to rank 7 (chain 10 is not met): one banner, "+6 ranks".
        #expect(out.rankUp?.from == 1)
        #expect(out.rankUp?.to == 7)
        #expect(data.rank == 7)
        // R7 P1-5: plain words.
        #expect(RankUpBanner.title(from: 1, to: 7) == "You ranked up 6 times!")
        #expect(RankUpBanner.title(from: 1, to: 3) == "You ranked up twice!")
        #expect(RankUpBanner.title(from: 1, to: 2) == "You ranked up!")
        #expect(RankUpBanner.rankLine(rank: 1, title: "Puddle Hopper") == "Rank 2 · Puddle Hopper")
    }

    @Test func unknownGoalIDsAreDropped() {
        let known: Set<String> = ["r1-total", "r1-reach"]
        let kept = ProgressRules.pruned(["r1-chain": 0.5, "r1-total": 0.4, "star3-chain": 0.2, "r1-reach": .nan],
                                        knownIDs: known)
        #expect(kept == ["r1-total": 0.4, "star3-chain": 0.2])
        var data = ProgressData()
        data.bestCleanMeters = 2_500
        data.bestCloudTouchesInRun = 2
        data.daily[1] = DailyRecord(meters: 1, perfects: 0, lighthouses: 0, lastLighthouseName: "", finished: true)
        #expect(data.bests.cleanMeters == 2_500)
        #expect(data.bests.cloudTouchesInRun == 2)
        #expect(data.bests.dailyPlayed)
        #expect(ProgressRules.bestProgress(Goal(id: "c", kind: .cleanMeters, target: 2_000, text: "x"), data: data) == 1)
        // Every goal id in the real ladder survives pruning.
        let ids = ProgressRules.knownGoalIDs()
        #expect(!ids.isEmpty)
        #expect(GoalCatalog.goals(forRank: 0).allSatisfy { ids.contains($0.id) })
    }

    @MainActor
    @Test func openAnglePersistsAndIgnoresNaN() throws {
        let suite = "swoop.tests.open.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let s = SettingsStore(defaults: defaults)
        #expect(s.hingeOpenAngle == nil)
        s.hingeOpenAngle = 141.5
        #expect(SettingsStore(defaults: defaults).hingeOpenAngle == 141.5)
        s.hingeOpenAngle = .nan
        let raw = try #require(SettingsStore.encode(s.snapshot))
        #expect(SettingsStore.decode(raw)?.hingeOpenAngle == nil)
        #expect(SettingsStore.decode(Data("{}".utf8))?.hingeOpenAngle == nil)
    }

    #if DEBUG
    @Test func roundFiveDemoKeys() {
        #expect(DemoConfig.parse("freezeOn=chainlost;freezeDelay=0.15").freezeOn == .chainlost)
    }
    #endif
}

struct HomeTextRectTests {
    /// R5b: Home hands the scene its wordmark and caption frames, on the bird page, fold-clear, below the title bird.
    @Test func homeTextRectsCoverTheText() {
        for c in testCanvases {
            let l = HomeLayout.make(c)
            #expect(l.textRects.count == 2)
            #expect(l.textRects.allSatisfy { c.isFoldClear($0) })
            #expect(l.textRects.allSatisfy { $0.minY >= l.bird.maxY - 0.5 })
            #expect(l.textRects[0] == l.wordmark)
        }
    }
}

// MARK: - Round 6 (design/UX-FLIGHT-SCHOOL.md)

/// Steps the school until `until` (60 Hz), feeding the same input; returns every output.
private func driveSchool(_ s: inout FlightSchool, from t0: Double, to t1: Double, _ make: (Double) -> SchoolInput)
    -> [FlightSchool.Output] {
    var outs: [FlightSchool.Output] = []
    var t = t0
    while t <= t1 {
        outs.append(s.step(make(t)))
        t += 1.0 / 60
    }
    return outs
}

struct RoundSixTests {
    // D1: the bird on the sharp half, tracked through 180° turns with Feel's SharpHalf.
    @Test func birdSideFollowsThePhysicalHalf() {
        // No stored half yet: screen-right in whatever orientation is current (the ROUND-6 correction).
        #expect(BirdSideRule.sharpSide(nil, orientation: .landscapeLeft) == .right)
        #expect(BirdSideRule.sharpSide(nil, orientation: .landscapeRight) == .right)
        // Stored on a first run held landscapeLeft: a 180° turn moves the bird to the other screen side.
        let first = SharpHalf.firstRun(in: InterfaceSide.landscapeLeft.feel)
        #expect(BirdSideRule.sharpSide(first, orientation: .landscapeLeft) == .right)
        #expect(BirdSideRule.sharpSide(first, orientation: .landscapeRight) == .left)
        #expect(BirdSideRule.mirrored(.sharp, sharp: first, orientation: .landscapeLeft))
        #expect(!BirdSideRule.mirrored(.sharp, sharp: first, orientation: .landscapeRight))
        // The Wing check: "the left stayed sharp", answered in landscapeRight.
        let checked = BirdSideRule.recording(answer: .left, sharp: first, orientation: .landscapeRight)
        #expect(BirdSideRule.sharpSide(checked, orientation: .landscapeRight) == .left)
        #expect(BirdSideRule.sharpSide(checked, orientation: .landscapeLeft) == .right)
        #expect(checked.reference == first.reference)
        // Fixed sides ignore the half.
        #expect(BirdSideRule.birdSide(.left, sharp: first, orientation: .landscapeLeft) == .left)
        #expect(BirdSideRule.birdSide(.right, sharp: first, orientation: .landscapeRight) == .right)
        // R3-R5 saves.
        #expect(BirdSideRule.migrated(oldMirrored: true, isDuo: true) == .right)
        #expect(BirdSideRule.migrated(oldMirrored: false, isDuo: true) == .sharp)
        #expect(BirdSideRule.migrated(oldMirrored: false, isDuo: false) == .left)
    }

    @Test func settingsMigrateToBirdSide() throws {
        let old = try #require(SettingsStore.decode(Data(#"{"mirrored": true}"#.utf8)))
        #expect(old.resolvedBirdSide(isDuo: true) == .right)
        let fresh = try #require(SettingsStore.decode(Data("{}".utf8)))
        #expect(fresh.resolvedBirdSide(isDuo: true) == .sharp)
        #expect(fresh.resolvedBirdSide(isDuo: false) == .left)
        #expect(fresh.sharpHalf == nil)
        let sharpOnPhone = try #require(SettingsStore.decode(Data(#"{"birdSide": "sharp"}"#.utf8)))
        #expect(sharpOnPhone.resolvedBirdSide(isDuo: false) == .left)
        var d = SettingsData()
        d.sharpHalf = SharpHalf(physical: .b, reference: .left)
        d.birdSide = .right
        let raw = try #require(SettingsStore.encode(d))
        let back = try #require(SettingsStore.decode(raw))
        #expect(back.sharpHalf == d.sharpHalf)
        #expect(back.birdSide == .right)
        #expect(SettingsView.birdSideFootnote(.left, checked: false, screenSide: .left)
                == "The bird always flies on the left half.")
        #expect(SettingsView.birdSideFootnote(.sharp, checked: true, screenSide: .right).hasSuffix("Now: right half."))
    }

    // D2: Flight School.
    @Test func schoolStudioSteps() {
        var s = FlightSchool(touch: false, asksWingCheck: false)
        s.start(at: .hold, time: 0)
        #expect(!s.canSkip)
        let skippedEarly = s.skip()   // (`#expect` can't call a mutating method)
        #expect(!skippedEarly)
        #expect(s.stepCount == 7)
        // Step 0: held open like a book and still; success only after the prompt has been up 1.2 s.
        var outs = driveSchool(&s, from: 0, to: 1.0) { SchoolInput(time: $0, landscape: true, angle: 150, still: true) }
        #expect(!outs.contains { $0.succeeded })
        outs = driveSchool(&s, from: 1.0, to: 1.3) { SchoolInput(time: $0, landscape: true, angle: 150, still: true) }
        #expect(outs.contains { $0.succeeded })
        #expect(s.canSkip)
        #expect(s.phase == .praise)
        // The praise shows 1.2 s, then step 1 (the Wing check is skipped: not asked).
        outs = driveSchool(&s, from: 1.3, to: 2.7) { SchoolInput(time: $0, landscape: true, angle: 150) }
        #expect(outs.contains { $0.advanced })
        #expect(s.stepNow == .wings)
        // Too flat / too shut help lines.
        var h = FlightSchool(touch: false, asksWingCheck: false)
        h.start(at: .hold, time: 0)
        _ = h.step(SchoolInput(time: 0.1, landscape: true, angle: 178))
        #expect(h.subline == "A little less than flat.")
        _ = h.step(SchoolInput(time: 0.2, landscape: false, angle: 150))
        #expect(h.subline == "Turn it sideways.")
        // Step 1: fold (0.8 for 0.2 s), then open.
        var w = FlightSchool(touch: false, asksWingCheck: false)
        w.start(at: .wings, time: 0)
        _ = driveSchool(&w, from: 0, to: 0.5) { SchoolInput(time: $0, landscape: true, angle: 120, tuck: 0.9) }
        outs = driveSchool(&w, from: 0.5, to: 1.4) { SchoolInput(time: $0, landscape: true, angle: 150, tuck: 0.1) }
        #expect(outs.contains { $0.succeeded })
    }

    @Test func schoolSeaStepsReadCoreSignals() {
        func sea(_ t: Double, _ signals: [PracticeSignal]) -> SchoolInput {
            SchoolInput(time: t, landscape: true, flying: true, practice: true, signals: signals)
        }
        // Step 3: a dive held 40 % rewinds with the help line; one held 90 % passes.
        var d = FlightSchool(touch: false, asksWingCheck: false)
        d.start(at: .dive, time: 0)
        var out = d.step(sea(2, [.diveDone(heldFraction: 0.4)]))
        #expect(out.rewind)
        #expect(d.subline == "You opened too soon. Keep it folded to the bottom.")
        out = d.step(sea(3, [.diveDone(heldFraction: 0.9)]))
        #expect(out.succeeded && !out.rewind)
        // Three misses: "Good enough. Let's fly."
        var f = FlightSchool(touch: true, asksWingCheck: false)
        f.start(at: .dive, time: 0)
        _ = f.step(sea(2, [.diveDone(heldFraction: 0.1)]))
        #expect(f.subline == "You let go too soon. Keep holding to the bottom.")
        _ = f.step(sea(3, [.diveDone(heldFraction: 0.1)]))
        out = f.step(sea(4, [.diveDone(heldFraction: 0.1)]))
        #expect(out.succeeded)
        #expect(f.subline == "Good enough. Let's fly.")
        // Step 4: launched folded rewinds; launched open passes.
        var o = FlightSchool(touch: false, asksWingCheck: false)
        o.start(at: .soar, time: 0)
        #expect(o.step(sea(2, [.launched(tuck: 0.7)])).rewind)
        #expect(o.step(sea(3, [.launched(tuck: 0.1)])).succeeded)
        // Step 5: a splash asks for the next guided swell; a Perfect passes.
        var l = FlightSchool(touch: false, asksWingCheck: false)
        l.start(at: .land, time: 0)
        out = l.step(sea(2, [.landed(.splash)]))
        #expect(out.rewind)
        #expect(l.subline == "Splash! Aim for the downslope.")
        #expect(l.step(sea(3, [.landed(.perfect)])).succeeded)
        // Step 6: three waves.
        var r = FlightSchool(touch: false, asksWingCheck: false)
        r.start(at: .rhythm, time: 0)
        #expect(!r.step(sea(2, [.waveDone(index: 1)])).succeeded)
        #expect(r.step(sea(3, [.waveDone(index: 2)])).succeeded)
        // Step 7: the storm lines, then the real Flight.
        var st = FlightSchool(touch: false, asksWingCheck: false)
        st.start(at: .storm, time: 0)
        #expect(st.timeScale == 1.0)
        #expect(st.prompt(at: 0.5) == "A storm is chasing you out to sea.")
        let outs = driveSchool(&st, from: 0, to: 7) { sea($0, []) }
        #expect(outs.contains { $0.finished })
        #expect(st.phase == .finished)
        // Where a miss rewinds Core's practice sea.
        #expect(FlightSchool.checkpoint(for: .dive) == .crestA)
        #expect(FlightSchool.checkpoint(for: .soar) == .trough)
        #expect(FlightSchool.checkpoint(for: .land) == nil)
        #expect(FlightSchool.checkpoint(for: .rhythm) == .rhythm)
    }

    @Test func schoolVariantsAndCopy() {
        let touch = FlightSchool(touch: true, asksWingCheck: true)
        #expect(!touch.asksWingCheck)
        #expect(touch.stepCount == 7)
        // R7 P0-1: the Duo school is 7 steps (no Wing check), numbered as shown.
        var duo = FlightSchool(touch: false, asksWingCheck: false)
        #expect(duo.stepCount == 7)
        duo.start(at: .dive, time: 0)
        #expect(duo.dotIndex == 2)
        #expect(duo.overline == "Flight School · step 3 of 7")
        #expect(duo.canSkip)
        let skippedDuo = duo.skip()
        #expect(skippedDuo)
        var phone = FlightSchool(touch: true, asksWingCheck: false)
        phone.start(at: .wingCheck, time: 0)
        #expect(phone.stepNow == .dive)
        #expect(phone.dotIndex == 2)
        #expect(FlightSchoolCopy.prompt(.hold, touch: false) == "Hold your Duo open like a book.")
        #expect(FlightSchoolCopy.prompt(.dive, touch: true) == "Hold the screen all the way down the wave.")
        #expect(FlightSchoolCopy.prompt(.storm, touch: false, elapsed: 5).hasPrefix("Reach the first lighthouse: Gull Point"))
        #expect(SchoolStep.from(key: "wingcheck") == .wingCheck)
        #expect(SchoolStep.from(key: "5") == .land)
        #expect(SchoolStep.from(key: "nope") == nil)
        #expect(GameController.schoolOnFly(state: .notStarted, runs: 0))
        #expect(!GameController.schoolOnFly(state: .done, runs: 0))
        #expect(!GameController.schoolOnFly(state: .notStarted, runs: 2))
    }

    @Test func wingCheckFlow() {
        var w = WingCheckFlow()
        w.update(angle: 176, time: 0)
        w.update(angle: 176, time: 0.6)
        #expect(w.phase == .fold)
        w.update(angle: 165, time: 0.8)
        #expect(w.phase == .ask)
        w.answer(.left, time: 1)
        #expect(w.phase == .confirm)
        #expect(w.answer == .left)
        var slow = WingCheckFlow()
        slow.update(angle: 150, time: 0)
        slow.update(angle: 150, time: 10.5)
        #expect(slow.needsFlatHelp)
        #expect(slow.phase == .explain)
    }

    @Test func schoolStatePersists() throws {
        for state in [FlightSchoolState.notStarted, .skipped(atStep: 4), .done] {
            let raw = try JSONEncoder().encode(state)
            #expect(try JSONDecoder().decode(FlightSchoolState.self, from: raw) == state)
        }
        let empty = try #require(ProgressStore.decode(Data("{}".utf8)))
        #expect(empty.flightSchool == .notStarted)
        // U2: the route migrates from the best distance (4 km and 9 km at or before 9.5 km).
        let old = try #require(ProgressStore.decode(Data(#"{"bestMeters": 9500}"#.utf8)))
        #expect(old.routeReached == 2)
        let kept = try #require(ProgressStore.decode(Data(#"{"bestMeters": 100, "routeReached": 3}"#.utf8)))
        #expect(kept.routeReached == 3)
        // A run that reaches further puts a lighthouse on the route.
        var data = ProgressData()
        let out = ProgressRules.record(makeRun(meters: 9_400, lighthouses: 2), into: &data, today: 300, goals: fakeGoals,
                                       maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks, trailUnlocks: noTrails)
        #expect(out.newOnRoute)
        #expect(data.routeReached == 2)
        let again = ProgressRules.record(makeRun(meters: 9_100, lighthouses: 2), into: &data, today: 300,
                                         goals: fakeGoals, maxRank: 15, evaluate: fakeEvaluate, unlocks: noUnlocks,
                                         trailUnlocks: noTrails)
        #expect(!again.newOnRoute)
    }

    // D3: the route and the objective.
    @Test func routeRules() {
        #expect(RouteRules.name(0) == "Gull Point")
        #expect(RouteRules.name(1) == "Saltlight")
        #expect(RouteRules.meters(0) == 4_000)
        #expect(RouteRules.meters(1) == 9_000)
        #expect(RouteRules.reached(within: 3_999) == 0)
        #expect(RouteRules.reached(within: 4_000) == 1)
        #expect(RouteRules.reached(within: .nan) == 0)
        #expect(RouteRules.chip(nextIndex: 0, metersFlown: 2_800, mirrored: false).hasPrefix("→ Gull Point · "))
        #expect(RouteRules.chip(nextIndex: 0, metersFlown: 2_800, mirrored: true).hasPrefix("← Gull Point · "))
        #expect(RouteRules.goalLine(nextIndex: 0, metersFlown: 3_200) == "Gull Point in 800 m")
        #expect(RouteRules.isNear(metersLeft: 299))
        #expect(!RouteRules.isNear(metersLeft: 300))
        #expect(RouteRules.iconScale(metersLeft: 0) == 1.25)
        #expect(abs(RouteRules.iconScale(metersLeft: 5_000) - 0.8) < 1e-9)
        let caught = RouteRules.headline(reachedThisRun: 0, meters: 3_200)
        #expect(caught.title == "Caught 800 m short of Gull Point")
        #expect(caught.sub == nil && !caught.reached)
        let reached = RouteRules.headline(reachedThisRun: 2, meters: 12_900)
        #expect(reached.title == "Reached Saltlight!")
        #expect(reached.reached)
        #expect(reached.sub?.hasSuffix("short of Kestrel Head") == true)
        #expect(RouteRules.nextTip(firstRealRun: true, perfects: 0, splashes: 9, bestChain: 0, nearBestHook: nil)
                == "Land Perfects to push the storm back.")
        #expect(RouteRules.nextTip(firstRealRun: false, perfects: 0, splashes: 1, bestChain: 0, nearBestHook: nil)
                == "Next time: land on a downslope for a Perfect.")
        #expect(RouteRules.nextTip(firstRealRun: false, perfects: 2, splashes: 5, bestChain: 2, nearBestHook: nil)
                == "Next time: open on the way up, so you come down on a downslope.")
        #expect(RouteRules.nextTip(firstRealRun: false, perfects: 5, splashes: 1, bestChain: 2, nearBestHook: "x")
                == "Next time: 3 Perfects in a row = a Tailwind.")
        #expect(RouteRules.nextTip(firstRealRun: false, perfects: 5, splashes: 1, bestChain: 4, nearBestHook: "x") == "x")
        #expect(RouteRules.nextTip(firstRealRun: false, perfects: 5, splashes: 1, bestChain: 4, nearBestHook: nil)
                == "Next time: chain Perfects to push the storm back.")
        #expect(RouteRules.summary(routeReached: 0, best: 0) == ["No lighthouses yet", "Next: Gull Point · 4 km"])
        #expect(RouteRules.summary(routeReached: 1, best: 6_420).first == "1 lighthouse reached")
        #expect(RouteRules.nodeState(index: 0, routeReached: 1) == .reached)
        #expect(RouteRules.nodeState(index: 1, routeReached: 1) == .next)
        #expect(RouteRules.nodeState(index: 2, routeReached: 1) == .soon)
        #expect(RouteRules.nodeState(index: 3, routeReached: 1) == .unknown)
        #expect(RouteRules.nodeLabel(index: 3, routeReached: 1) == "Lighthouse 4")
        #expect(RouteRules.objective == "Outfly the storm. Reach the next lighthouse.")
        #expect(PauseCard.subline(meters: 2_120, scoredDaily: false, goalLine: "Gull Point in 1.9 km")
                == "2.12 km · Gull Point in 1.9 km")
    }

    @Test func routeStripGeometry() {
        #expect(RouteStrip.nodeX(0, width: 1_000, spacing: 150, mirrored: false) == 110)
        #expect(RouteStrip.nodeX(0, width: 1_000, spacing: 150, mirrored: true) == 890)
        #expect(RouteStrip.nodeX(2, width: 1_000, spacing: 150, mirrored: false) == 410)
        #expect(RouteStrip.bestX(best: 0, width: 1_000, spacing: 150, mirrored: false) == nil)
        #expect(RouteStrip.bestX(best: 4_000, width: 1_000, spacing: 150, mirrored: false) == 110)
        #expect(RouteStrip.bestX(best: 6_500, width: 1_000, spacing: 150, mirrored: false) == 185)
        #expect(RouteStrip.nodeCount(routeReached: 2) == 6)
        #expect(MiniRouteStrip.shown(reachedThisRun: 0) == 2)
        #expect(MiniRouteStrip.shown(reachedThisRun: 2) == 3)
        #expect(MiniRouteStrip.birdFraction(meters: 4_500, reachedThisRun: 0) == 0.5)
        #expect(MiniRouteStrip.birdFraction(meters: 99_000, reachedThisRun: 0) == 1)
        #expect(DuoDiagramGeometry.clampAngle(.nan) == 180)
        #expect(DuoDiagramGeometry.clampAngle(90) == 100)
        #expect(DuoDiagramGeometry.gaugeFraction(angle: 180) == 1)
        #expect(DuoDiagramGeometry.gaugeFraction(angle: 100) == 0)
        #expect(DuoDiagramGeometry.horizontalScale(angle: 180) == 1)
    }

    @Test func resultsLeadWithTheObjective() {
        var s = ResultSummary(result: makeRun(meters: 3_200, perfects: 0, bestChain: 0), outcome: RecordOutcome(),
                              title: "Flight", dailyDay: nil, practice: false, share: "")
        s.firstRealRun = true
        #expect(ResultsView.nextTip(s) == "Land Perfects to push the storm back.")
        let duo = canvas(951, 669, fold: true)
        let plan = ResultsPlan.make(s, canvas: duo, cardHeight: ResultsLayout.far(duo).height, dailyRowAllowed: false)
        #expect(plan.headline && plan.routeStrip && plan.hasHook && plan.routeNote)
        #expect(!plan.headlineSub)
        s.firstRealRun = false
        s.outcome.previousBest = 3_400
        s.result = makeRun(meters: 3_200, perfects: 6, bestChain: 4)
        #expect(ResultsView.nextTip(s) == "200 m short of your best")
        let phone = canvas(874, 402, fold: false)
        let compact = ResultsPlan.make(s, canvas: phone, cardHeight: ResultsLayout.far(phone).height, dailyRowAllowed: true)
        #expect(!compact.routeStrip)
        #expect(ChainPill.text(chain: 2, tailwind: false, teach: false) == "×2")
    }

    @Test func schoolLayoutIsFoldClear() {
        for c in testCanvases {
            let l = SchoolLayout.make(c)
            for r in [l.dots, l.diagram, l.prompt, l.seaPrompt, l.stormPrompt, l.skip] {
                #expect(c.isFoldClear(r), "\(r) on the fold of \(c.size)")
                #expect(r.minX >= -0.5 && r.maxX <= c.size.width + 0.5)
            }
            // What you read sits on the bird page (the sharp half).
            #expect(l.prompt.minX >= c.birdPage.minX - 0.5 && l.prompt.maxX <= c.birdPage.maxX + 0.5)
        }
    }

    @Test func schoolGuidesOnThePracticeSea() {
        #expect(SceneAdapter.guide(for: .dive) == .foldPath(from: Tuning.practiceCrestAX, to: Tuning.practiceTroughX))
        #expect(SceneAdapter.guide(for: .soar) == .openMark(at: Tuning.practiceTroughX))
        #expect(SceneAdapter.guide(for: .storm) == SceneGuide.none)
        #expect(SceneAdapter.guide(for: nil) == SceneGuide.none)
    }

    #if DEBUG
    @Test func roundSixDemoKeys() {
        let d = DemoConfig.parse("school=dive:fail;sharp=b;orient=landscapeLeft;birdSide=sharp;resultsFrame=newroute;"
                                 + "screen=route;goalNear;flatTip;existingPlayer;schoolTouch")
        #expect(d.schoolStep == .dive)
        #expect(d.schoolPhase == "fail")
        #expect(d.sharpHalf == SharpHalf(physical: .b, reference: .right))
        #expect(d.orientLandscape == .landscapeLeft)
        #expect(!d.orientPortrait)
        #expect(d.birdSide == .sharp)
        #expect(d.resultsFrame == .newroute)
        #expect(d.screen == .route)
        #expect(d.goalNear && d.flatTip && d.existingPlayer && d.schoolTouch)
        #expect(DemoConfig.parse("school=wingcheck:ask").schoolPhase == "ask")
        #expect(DemoConfig.parse("sharp=z").sharpHalf == nil)
    }
    #endif
}

struct RoundSixSceneWiringTests {
    /// SC3: the "Faster!" fill and the rhythm bar's place on Core's λ 2000 waves.
    @Test func practiceHUDArt() {
        #expect(FlightSchool.fasterFill(speed: Tuning.practiceStartSpeed) == 0)
        #expect(FlightSchool.fasterFill(speed: Tuning.practiceTroughSpeed) == 1)
        #expect(FlightSchool.fasterFill(speed: .nan) == 0)
        #expect(FlightSchool.rhythmWaveLength == 2_000)
        #expect(FlightSchool.rhythmPosition(x: 4_000) == nil)
        let first = FlightSchool.rhythmPosition(x: 5_300)
        #expect(first?.wave == 0 && first?.fraction == 0.5)
        let last = FlightSchool.rhythmPosition(x: 10_299)
        #expect(last?.wave == 2)
        #expect(FlightSchool.rhythmPosition(x: 10_300) == nil)
        let page = CGRect(x: 476, y: 0, width: 475, height: 669)
        let leftEdge: CGFloat = 476 + 72, rightEdge: CGFloat = 951 - 72
        #expect(abs(SchoolBirdHUD.anchorX(birdX: 300, page: page) - leftEdge) < 0.01)
        #expect(SchoolBirdHUD.anchorX(birdX: 700, page: page) == 700)
        #expect(abs(SchoolBirdHUD.anchorX(birdX: 940, page: page) - rightEdge) < 0.01)
    }
}

struct RoundSevenTests {
    /// P0-1: every school step is numbered 1…7 in order, on a Duo and an iPhone.
    @Test func schoolIsSevenStepsInOrder() {
        for touch in [false, true] {
            var s = FlightSchool(touch: touch, asksWingCheck: false)
            var seen: [Int] = []
            for step in SchoolStep.allCases where step != .wingCheck {
                s.start(at: step, time: 0)
                seen.append(s.dotIndex + 1)
                #expect(s.overline == "Flight School · step \(s.dotIndex + 1) of 7")
            }
            #expect(seen == [1, 2, 3, 4, 5, 6, 7])
        }
        #expect(SchoolDisplay().stepCount == 7)
    }

    /// P0-2: step 5 names the Perfect outright; "Too close" only inside the danger zone.
    @Test func perfectIsTaughtAndTooCloseIsTruthful() {
        #expect(FlightSchoolCopy.praise(.land) == "PERFECT")
        #expect(FlightSchoolCopy.praiseLine(.land) == "Land on a downslope = Perfect. Perfects push the storm back.")
        #expect(FlightSchoolCopy.praiseLine(.dive) == nil)
        #expect(FlightSchoolCopy.praiseSeconds(.land) > FlightSchoolCopy.praiseSeconds(.dive))
        #expect(LeadMeter.showsTooClose(teach: true, lead: AppRules.meterDangerZone * 0.5))
        #expect(!LeadMeter.showsTooClose(teach: true, lead: 0.6))
        #expect(!LeadMeter.showsTooClose(teach: false, lead: 0.01))
    }

    /// P0-3: no "159 of 25", and a ticked goal never sits on a short this-flight count.
    @Test func goalCaptionsAgreeWithTheTick() {
        let perfects = Goal(id: "p", kind: .perfectsInRun, target: 25, text: "25 Perfects in one flight")
        let big = makeRun(perfects: 159)
        #expect(AppRules.goalCaption(perfects, before: 0, run: big, lifetime: 0) == "Done this flight")
        let small = makeRun(perfects: 11)
        #expect(AppRules.goalCaption(perfects, before: 0, run: small, lifetime: 0) == "This flight: 11 of 25")
        #expect(AppRules.goalCaption(perfects, before: 0, run: small, lifetime: 0, done: true)
                == "Done in an earlier flight")
    }

    /// P0-4: every Home tile's chosen layout fits its rect on every canvas (the "G…" / stacked "N e w" frames).
    @Test func homeTilesFitEveryCanvas() {
        let canvases = testCanvases + [canvas(667, 375, fold: false), canvas(951, 669, fold: true, mirrored: true)]
        for c in canvases {
            let l = HomeLayout.make(c)
            for (r, title, detail) in [(l.flocks, "Goals", "3 of 3 done"), (l.route, "Route", "12 reached"),
                                       (l.birds, "Birds", "Albatross")] {
                let plan = HomeView.tilePlan(width: r.width, height: r.height, title: title, detail: detail,
                                             compact: c.isCompact)
                #expect(plan.need <= r.width + 0.5, "\(title) needs \(plan.need) > \(r.width) on \(c.size)")
                if plan.stacked { #expect(r.height >= 40) }
                #expect(c.isFoldClear(r))
            }
        }
        // A roomy tile shows the detail; a narrow one stacks.
        #expect(HomeView.tilePlan(width: 200, height: 58, title: "Goals", detail: "1 of 3 done", compact: false).detail)
        #expect(HomeView.tilePlan(width: 70, height: 58, title: "Goals", detail: "1 of 3 done", compact: false).stacked)
    }

    /// P1-5: plain reward words; the rank title always with its number.
    @Test func plainRewardCopy() {
        #expect(RankUpBanner.title(from: 1, to: 3) + " "
                + RankUpBanner.unlockLine(birds: ["Tern"], skies: [], trails: ["Coral"])
                == "You ranked up twice! New bird: Tern · New trail: Coral")
        #expect(RankUpBanner.rankLine(rank: 2, title: "Spray Chaser") == "Rank 3 · Spray Chaser")
    }

    /// P1-6 / P1-8: the goal sentence early; the Duo only as a fun fact, after an iPhone's first results.
    @Test func goalEarlyAndAWelcomeOnIPhone() {
        #expect(HomeView.flySubtitle(best: 0, routeReached: 0) == RouteRules.objective)
        #expect(HomeView.flySubtitle(best: 9_000, routeReached: 1).hasPrefix("Next: Saltlight"))
        #expect(HomeView.captionText(duo: false, folded: false, flat: false).contains("Duo") == false)
        var s = ResultSummary(result: makeRun(), outcome: RecordOutcome(), title: "First flight", dailyDay: nil,
                              practice: false, share: "")
        #expect(!ResultsView.smallLines(s).contains(ResultsView.funFactLine))
        s.funFact = true
        #expect(ResultsView.smallLines(s).contains("Fun fact: on iPhone Duo, you fold the phone to fly."))
        #expect(!FlightSchoolCopy.prompt(.rhythm, touch: true).lowercased().contains("tap"))
        #expect(!FlightSchoolCopy.prompt(.wings, touch: true).lowercased().contains("tap"))
    }

    #if DEBUG
    @Test func firstSessionDemoKey() {
        #expect(DemoConfig.parse("session=first:results").session == .results)
        #expect(DemoConfig.parse("session=first").session == .home)
        #expect(DemoConfig.parse("session=other:home").session == nil)
        let s = DemoConfig.parse("session=first:school;school=storm:2")
        #expect(s.session == .school && s.schoolStep == .storm && s.schoolPhase == "2")
        #expect(DemoConfig.parse("screen=settings;settingsWhy").settingsWhy)
    }
    #endif

    /// The storm-line demo holds put the prompt on the asked line.
    @Test func stormLineHolds() {
        for (k, prefix) in [("1", "A storm"), ("2", "Stay ahead"), ("3", "Reach the first")] {
            var s = FlightSchool(touch: false, asksWingCheck: false)
            s.start(at: .storm, time: 100)
            s.demo(phase: k, time: 100)
            #expect(s.prompt(at: 100).hasPrefix(prefix), "line \(k)")
        }
    }
}