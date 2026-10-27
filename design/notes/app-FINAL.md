# App FINAL: the last fix pass before App Store submission (27 Oct 2026)

Scope: the App engineer's items 1–19 in `design/qa/FINAL-FIXES.md`, plus the Feel engineer's item 6 (record the sharp
half on the first Duo launch), which lives in `GameController.hingeSample` and was handed to the App. Evidence is in
`design/qa/QA-FINAL-*.md`. **Nothing is committed and CI hasn't compiled any of it** (no local Swift compiler).
New tests: `SwoopTests/AppTestsFinal.swift`; stale tests updated in `SwoopTests/AppTests.swift`.

## P0 and P1

1. **The hinge readout is Debug only.** `BuildChannel.isTestBuild` is `#if DEBUG` true / false, with no receipt check.
   The Settings "Device test" card (and its `toggleRow("Hinge readout", …)`, renamed from "Hinge readout
   (TestFlight)") and the `HingeReadoutOverlay` (its struct and its use in `RootView`) are inside `#if DEBUG`, so no
   "Hinge readout" literal is in the Release binary (`testflight.yml` greps for it). `HingeReadout`'s own line strings
   stay (no "Hinge readout" text in them). A stored `hingeReadout = true` from a TestFlight install does nothing in
   Release. Test: `hingeReadoutIsDebugOnly`.
2. **Home's Daily across UTC midnight.**
   - `HomeView` re-reads `now` / `today` on appear, when `scenePhase` becomes active, on the 30 s tick and at the tap.
   - Both the button and its VoiceOver action call `controller.openDailyCard()`, which decides at the tap on today's
     date via `AppRules.dailyTap(data:day:)`: no try today → `playDaily()` (today's scored Daily); a try (flown or
     spent) → today's card. The "spent" card can only show for a day that really has a try.
   - DEBUG: `screen=daily` on a fresh store (CI's `results-daily-card-fresh`) marks today's try spent on the
     in-memory demo store first, so that frame still shows the "spent, nothing filed" card.
   - Test: `dailyTapDecidesOnTodayNotAStaleDay`.
3. **Flight School step 1 on a flat Duo.** `.hold` no longer refuses ≥ 174°: flat passes once still, like a relaxed
   book. `subWords(at:)` now returns the step's correction for `.hold` as the muted second line under "Hold it open"
   ("Open it wider" under 110°, "Turn it sideways" in portrait; no full stop, `FlightSchool.inWorldLine`). The Studio
   already draws `wordsSub`. "A little less than flat." is gone (flat passes): the hold step's miss copy
   (`FlightSchoolCopy.failure(.hold)`, used only by the demo `school=hold:fail` frame) is now "Open it wider.", and
   that Duo scenario is renamed `47-school-hold-flat` → `47-school-hold-wider` in `ci/duo-scenarios.txt`. Not done
   (not in the list): QA's idea to draw the diagram's open target at ~155° instead of 174°. Tests:
   `flatDuoPassesHoldItOpen`, `holdStepDrawsItsCorrectionAsTheSecondLine`; `schoolStudioSteps` updated.
4. **Seated Duo after Home.** `startAttract()` clears `touchOverride`, and so does `goHome()` when the attract loop is
   already running (the school Studio's "Play with touch" set it there). Home on a portrait Duo is the TurnCard again.
   Test: `seatedDuoHomeIsTheTurnCard` (the pose rule; the clearing itself is controller state, not unit-testable here).
5. **Auto-Lock in Flight School.** `syncIdleTimer` uses `AppRules.keepsScreenAwake(...)`: a live run as before, plus
   `route == .school` while the school runs and its Studio isn't paused (any pause reason turns it off). Synced on
   Studio pause/resume and in `endSchool`. Test: `screenStaysAwakeThroughFlightSchool`.
6. **Fold-to-fly on a scored Daily's results.** `AppRules.foldToFlyArms`: never on the Daily card or a scored Daily's
   results; a Flight and a practice Daily keep it. Test: `foldToFlyNeverStartsAHiddenPractice`.
7. **Touch stuck after a pause or the catch; thumb hand-offs.** The PlayLayer hold layer and the deck pad are now a
   `HoldPad` (`UIViewRepresentable`, `PlayHUD.swift`): a multi-touch UIView that counts fingers (`HoldCount`, pure).
   The wings fold on the first finger down and open when the last lifts, so a two-thumb hand-off keeps the tuck.
   `touchesCancelled`, an end never delivered (reconciled against the event's live touches), leaving the window and
   `dismantleUIView` all count as lifts (the last two report on the next main-queue turn, so no state changes during a
   view update), so the first press after a pause, the catch or Control Center always tucks. The old
   `onChange(of: paused)` reset is kept as a belt and braces. VoiceOver and Switch Control paths are unchanged.
   Test: `holdCountsEveryFinger` (the UIKit view itself needs a device).
8. **A 180° turn.** `RootView.refreshWindowInsets`'s 350 ms task now re-reads `OrientationLock.interfaceSide()` and
   calls `setInterfaceSide` (idempotent), and once more 450 ms later for a slow turn. **Unverified**: needs the real
   Duo (`SWOOP-T birdside` after a turn); CI's demo sets the side directly.
9. **Resuming from the closing pause.** `setPause` tells `resumed(afterClosing:)` when the last pause to clear was the
   closing one (the hinge reopening, or the card's Resume). Then "Go" waits while the start tuck is > 0.5 for up to
   `closingResumeGrace` = 3.0 s past the 1.5 s hold, whichever comes first (`AppRules.readyWaits`); the 1 s grace for a
   still-moving hinge is unchanged, and a user pause keeps the old rule. I read "3.0 s have passed" as 3 s past the
   hold, replacing the 1 s grace (the founder's "only a 1.0 s grace"). Test: `goWaitsForOpenWingsAfterTheClosingPause`.
10. **One Skip on the clear-side check.** The check's own button is now **"Not sure"** (VoiceOver "Not sure, skip this
    check"); "Skip" is only the lesson's. In the school `WingCheckPages.notSureRect` keeps its 56 pt tap area ≥ 8 pt
    from Skip's (shifted, narrowed if needed); the Settings check (no Skip) stays centred. Test:
    `clearSideCheckHasOneSkipAndNoOverlap` (9 canvases, both sizes).
11. **Game Center.** `enqueue` keeps one pending `swoop.longest` entry, the highest, and the cap only evicts other
    entries. On every successful sign-in (`authenticationChanged` with `isAuthenticated`) `syncAfterSignIn` queues
    `bestMeters` to `swoop.longest` and sets the pending achievements to every earned one (whatever `swoop.gc.reported`
    says), then flushes; Game Center de-duplicates. The progress comes from `GameCenterManager.progress`, set in
    `SwoopApp` before `authenticate()`. Tests: `gameCenterQueueKeepsTheHighestLongest`,
    `signInResendsTheBestAndEveryAchievement`; `dailyEntriesKeepTheLargerAndTheCapSparesBests` updated (25 rising
    `longest` entries now leave one, the 24).
12. **Small screens.** `HomeCaptionPlan` (pure, `HomeView.swift`) gives the headline every line that fits (≤ 2 iPhone,
    ≤ 3 Duo) and shows the goal sentence only when it fits whole (≤ 2 lines) under it. On 667 × 375 and 844 × 390 the
    fresh caption keeps "Hold anywhere. The wings fold." and drops the goal sentence; the iPhone 18 Pro (874 × 402)
    drops it too (it was ~5 pt over). The Duo is unchanged. Test: `homeCaptionNeverRunsIntoTheCornerPills` (9 canvases
    × every caption). Not done: an SE simulator run in `ci/screenshots.sh` (CI owner; QA's suggestion).

## P2

13. **Practice Daily share line:** `ShareText.line` prefixes "Practice · " and drops the 🔥 streak for
    `.daily(_, scored: false)`. Test: `practiceShareLineIsMarked`.
14. **Streaks** (`ProgressRules.streakWithGrace`):
    - today unflown and yesterday missed, the day before flown: the streak is alive (counted with the grace already on
      yesterday), so Home and the cover show it;
    - `graceKept` (→ "Calm sea: streak kept") only when today is flown and the gap it bridges is yesterday;
    - `swoop.ach.daily3` needs `ProgressRules.longestStrictStreak(days:) >= 3` (no gap) as well as
      `bestDailyStreak >= 3`.
    - Tests: `streakIsKeptOnHomeAfterOneMissedDay`, `calmSeaShowsOnlyForTheDayItBridges`,
      `threeDawnsNeedsThreeDaysInARow`; `dailyIsFiledOnceAndStreaks` (302 now keeps 3, 303 is 0) and
      `achievementsFollowTheProgress` (three consecutive Dailies) updated.
15. **Battery:** `RootView.sceneRest`: the SKView is paused under the pause card and the closing card (`.playing`,
    `.school`), and runs at 10 fps on Results and the Daily card (fold-to-fly still reads the hinge from `advance`).
    Never in demo runs (CI waits for the scene's frames). The closing pause still ends from the hinge samples
    (`hingeSample` → `checkClosing`). Test: `sceneRestsUnderCards`.
16. **Glossary:** see "Labels changed" below. The goal texts are Core's (`Core/Goals.swift`); the App now shows them
    through `AppRules.goalText` ("N perfect landings in one flight", "N perfect landings in a row") on Results, Goals
    and the deck summary. Test: `goalWordsFollowTheGlossary` (the whole ladder and 4 star flocks).
17. **Reduce Motion:** the ChainPill "×N lost" shake, the LeadMeter's storm-close pulse and icon shake (the ring is
    drawn steady), and `SchoolBigWord`'s 1.6× scale (now a fade) honour it. No unit test (environment-driven views).
18. **Dead code with banned copy deleted:** `RankUpBanner` ("You ranked up!", "Rank 2 · …"; its still-used
    `unlockLine` moved to `RewardWords.unlockLine`, used by the Goals page), `ResultsView.goldChip`, `WingCheckCard`
    (and its never-true Home branch), and `TouchWingFeedback.glyphSize/glyphCenter/glyphAlpha/birdNear`. Their tests
    were removed or moved to `RewardWords`. (`GameController.showsWingCheckCard` / `dismissWingCheckCard` are left as
    harmless stubs.)
19. **Date formatter:** `AppRules.dailyTag` uses a static formatter and epoch. Test: `dailyTagIsStableAcrossCalls`.

**Feel #6 (handed to the App):** `hingeSample`, inside `if !hingeSeen`, after `OrientationLock.hingeArrived()`:
`if let o = OrientationLock.interfaceSide() { setInterfaceSide(o) } else { recordSharpHalfIfNeeded() }`.

## Labels changed (user-visible)
Untouched: "Fly", "Play with touch", "Respect silent switch", "Open your wings to keep flying", "Open your wings",
"Skip" (the lesson's), "Scores".
- Clear-side check button: "Skip" → **"Not sure"** (VoiceOver "Not sure, skip" → "Not sure, skip this check").
- Settings › Reset alert: "Your bests, ranks, goals…" → "Your bests, **levels**, goals…".
- Settings › Wings by footnote: "one tap tucks, the next opens" → "one tap **folds the wings**, the next opens".
- New best toast: "Every metre now is a record" → "Every metre now is **your best.**"
- Touch wing VoiceOver value: "Tucked / Spread" → "**Folded / Open**".
- Birds VoiceOver: "locked until rank N" → "locked until **level** N"; Goals ladder VoiceOver "Current rank" →
  "Current level".
- Goal rows (Results, Goals, the deck line): "3 Perfects in one flight" → "3 perfect landings in one flight";
  "Chain 10 Perfects in one flight" → "10 perfect landings in a row" (and the same for every rank and star goal).
- Cover: "Daily 27 Oct" → "Daily Flight · 27 Oct"; "Daily 27 Oct · your one try is paused" → "Daily Flight · 27 Oct ·
  your one try is paused".
- Practice Daily share text: now starts "Practice · Swoop Daily #n …" (no 🔥).
- Flight School step 1: the sub-lines "Open it wider" / "Turn it sideways" are now drawn; "A little less than flat."
  is gone (flat passes).
- Debug only: "Hinge readout (TestFlight)" → "Hinge readout".
- Home: on iPhone-sized canvases the fresh caption no longer shows the goal sentence under the headline.

## For other owners
- **Core:** the ladder text in `Core/Goals.swift` still says "Perfects" / "Chain …"; the App rewrites it for display.
  Fixing the source copy later is optional (the App mapping then becomes a no-op).
- **Docs / store:** the review notes and support page should no longer mention a "Device test" card (it isn't in any
  Release build). If any doc quotes the clear-side "Skip", it is now "Not sure". The new CI frames will differ: Home
  fresh on iPhone (no goal sentence), the clear-side frames ("Not sure"), `47-school-hold-wider`, and the cover's
  Daily row (longer title; check it doesn't truncate on the 466 pt cover).
- **CI owner:** an SE (3rd gen) run in `ci/screenshots.sh` would catch item 12 on the real text.

## What CI might catch
- `HoldPad` / `HoldPadView` (new UIKit representable): `dismantleUIView(_:coordinator: ())` signature,
  `Int(bitPattern: ObjectIdentifier(_:))`.
- `nonisolated static` members added to View structs (`WingCheckPages`, `RootView.sceneRest` and its nested enum).
- `GameCenterManager.progress` is `(@MainActor () -> ProgressData)?`, set from `SwoopApp` with `{ [store] in
  store.data }`.
- Tests: `AppTestsFinal` is `@MainActor` (it touches `GameController.closingResumeGrace` and `ProgressStore`);
  mutating calls are made before `#expect`; CGFloat comparisons use tolerances. The caption and "Not sure" layout
  numbers were checked with a JS replica of `AppCanvas` / `HomeLayout` (all 9 canvases pass).
