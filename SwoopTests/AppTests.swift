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
        data.goalProgress = ["g1": 0.5]
        data.daily[300] = DailyRecord(meters: 4_200, perfects: 12, lighthouses: 1, lastLighthouseName: "Saltlight",
                                      finished: true)
        data.dailyAttempted = [300]
        data.bird = .puffin
        data.hintsLearned = true
        let store = ProgressStore(defaults: defaults)
        store.replace(with: data)
        let reloaded = ProgressStore(defaults: defaults)
        #expect(reloaded.data == data)
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
        #expect(ProgressRules.streak(days: [1, 2, 4, 5], today: 5) == 2)
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
        #expect(ShareText.line(for: run, streak: 1) == "Swoop Daily #5 4.1 km \(dove) 9 Perfects · past Gull Point \(sunrise)")
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
        #expect(AppPoseRule.pose(canvas: tabletop, hingeSeen: true, isShut: false, touchOverride: true) == .play)
        #expect(AppPoseRule.pose(canvas: cover, hingeSeen: true, isShut: false, touchOverride: false) == .closed)
        #expect(AppPoseRule.pose(canvas: book, hingeSeen: true, isShut: true, touchOverride: false) == .closed)
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

    @Test func playRectIsALandscapeBandInPortrait() {
        let full = AppPoseRule.playRect(in: CGSize(width: 951, height: 669))
        #expect(full == CGRect(x: 0, y: 0, width: 951, height: 669))
        let band = AppPoseRule.playRect(in: CGSize(width: 669, height: 951))
        #expect(band.width == 669)
        #expect(band.height < band.width)
        #expect(abs(band.midY - 951 / 2) <= 1)
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
        #expect(HintBubble.text(.fold, touch: false) == "Fold on the way down")
        #expect(HintBubble.text(.open, touch: false) == "Open to fly")
        #expect(HintBubble.text(.fold, touch: true) == "Hold on the way down")
        #expect(RankUpBanner.unlockLine(birds: ["Tern"], skies: ["Rose Dusk"]) == "New: Tern, Rose Dusk")
        #expect(RankUpBanner.unlockLine(birds: [], skies: []) == "")
        #expect(HomeView.dailyStatus(record: nil, attempted: false, streak: 0) == "Everyone's sea today · one try")
        #expect(HomeView.dailyStatus(record: nil, attempted: true, streak: 0) == "Tried · practice")
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

    @Test func leadMeterHasHeadroom() {
        #expect(abs(AppRules.meterLead(gap: 2_400, fullLead: 3_000) - 2_400 / 3_900) < 1e-9)
        #expect(AppRules.meterLead(gap: 99_999, fullLead: 3_000) == 1)
        #expect(AppRules.meterLead(gap: -5, fullLead: 3_000) == 0)
        #expect(AppRules.meterLead(gap: .nan, fullLead: 3_000) == 0)
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
        let line = AppRules.nextLighthouseLine(meters: first - 550, lighthousesPassed: 0, seed: 7)
        #expect(line?.hasPrefix("0.6 km short of ") == true)
        #expect(ResultsView.hookText(past: "Gull Point", next: "0.6 km short of Saltlight")
                == "Past Gull Point · 0.6 km short of Saltlight")
        #expect(ResultsView.hookText(past: "", next: nil) == "")
        #expect(ResultsView.inlineStatsText(perfects: 1, chain: 4, lighthouses: 2) == "1 Perfect · chain 4 · 2 lighthouses")
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
        for c in testCanvases {
            let p = PlayLayout.make(c)
            #expect(c.isFoldClear(p.callout))
            #expect(c.birdPage.contains(CGPoint(x: p.callout.midX, y: c.size.height / 2)))
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