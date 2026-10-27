# QA-FINAL: Core, Persistence, Daily Flight, Game Center, goals and share (pre-App-Store)

*Read-only audit, Tue 27 Oct 2026, HEAD `a4bc58d` (TestFlight 10). Scope: `Swoop/Core/`, `Swoop/Persistence/`,
`Swoop/App/GameCenterManager.swift`, the Daily Flight, goals/levels/unlocks, `Swoop/UI/ShareText.swift`, and how
`Swoop/App/GameController.swift` calls into Core and Persistence. Every finding below was checked against the code;
anything that depends on Apple runtime behaviour I could not test is marked **unverified**. Balance figures come from
running `node tools/balance-sim.js seeds=20 skills=expert,perfect cap=2000`.*

**Totals: P0 0 · P1 2 · P2 13.** No crash, data-loss or rejection-grade defect was found in this scope.

---

## P1

### P1-1 The "Device test · Hinge readout (TestFlight)" section is visible to App Review
- **Where:** `Swoop/App/BuildChannel.swift:6-13`, `Swoop/UI/SettingsView.swift:94-102`, `Swoop/UI/RootView.swift:114`.
- **What:** In Release, `BuildChannel.isTestBuild` is true whenever `Bundle.main.appStoreReceiptURL?.lastPathComponent
  == "sandboxReceipt"`. Builds under App Review run in the sandbox environment and carry a sandbox receipt (as TestFlight
  builds do), so the reviewer sees a Settings heading "Device test" with a toggle labelled **"Hinge readout (TestFlight)"**,
  and can switch on a developer overlay over play. The code comment says "Never in an App Store build", but the reviewer
  sees the same binary that later goes to the store. A visible test/debug feature that names TestFlight invites a 2.1
  (completeness) or 2.2 (beta content) note. `docs/appstore/review-notes.md:81` claims debug modes are off in Release,
  and the reviewer can see that this is not quite true. `appStoreReceiptURL` is also deprecated from the iOS 18 SDK.
  The sandbox receipt during review is **unverified** on our side, but Apple documents review as running in sandbox.
- **Repro:** install the Release build from TestFlight (the same signing path as review), open Settings, and the
  "Device test" card is there.
- **Fix:** gate the readout on a compile-time flag and not on the receipt. Add `TESTFLIGHT_TOOLS` to
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS` only in a non-release `testflight.yml` lane, and use
  `#if DEBUG || TESTFLIGHT_TOOLS` in `BuildChannel.isTestBuild`. The release-candidate build (the one submitted on
  18 Nov) is archived without the flag. If the toggle has to stay in the RC build, at least drop "(TestFlight)" from the
  label and say in the review notes what it is.

### P1-2 Home's stale "today" sends a returning player to a "spent" card for a fresh Daily
- **Where:** `Swoop/UI/HomeView.swift:19` and `:144-151` (`today` and `now` are refreshed only by a 30 s
  `Task.sleep` loop, never on `scenePhase == .active`); `:348-352` (the button routes on `attempted` computed from that
  stale day); `Swoop/App/GameController.swift:1417-1437` (`openDailyCard()` recomputes `day` from `Date()`).
- **What:** For up to 30 s after a UTC day change, and in particular in the first seconds after the app returns from the
  background on a new day with Home still mounted, Home still shows yesterday's state ("Flown 7.4 km · next in 6 h", the
  countdown also stale). Suppose the player flew yesterday's Daily and taps the button. `attempted` is true for
  yesterday, so the button calls `openDailyCard()`. That method uses the new day, finds `record == nil`, and builds a card
  with `dailySpentUnfiled = true`. Today's unflown Daily is then shown as a spent try ("Practise today's waves", no
  Share). Tapping Practise flies today's sea unscored *before* the scored try, which is a free preview the one-try rule
  is meant to prevent. `Task.sleep` does not advance while the device is asleep, so "open the app the next morning and tap
  Daily straight away" hits this. That is the core daily habit.
- **Fix:** (a) in `HomeView`, add `@Environment(\.scenePhase)` and on `.active` set `now = Date()` and
  `today = DailySeed.dayNumber(for: now)`; (b) make the controller authoritative. In `openDailyCard()`, start with
  `guard store.hasDailyAttempt(day: day) else { playDaily(); return }`, and decide on the button at tap time
  (`controller.openDailyOrPlay()`) rather than from the cached `attempted`.

---

## P2

### P2-1 The streak vanishes on Home the morning after a single missed day, although the grace keeps it
- **Where:** `Swoop/Persistence/ProgressStore.swift:294-318` (`streakWithGrace`), used by `HomeView.swift:347`,
  `PoseCards.swift:294`.
- **What:** `var day = days.contains(today) ? today : today - 1`. If yesterday is missing, `count == 0` on the first step
  and the grace branch needs `count > 0`, so it breaks and returns 0. Days {1…5} flown, day 6 missed, today 7 unflown:
  Home shows no streak (and the "5-day streak" accessibility text is gone). Once today is flown, the same function returns
  6 with "Calm sea: streak kept". The streak looks lost and then comes back.
- **Fix:** when today isn't flown and `today - 1` is missing but `today - 2` is flown, start the walk at `today - 2` with
  the grace already applied, and report "alive, fly today to keep it".

### P2-2 "Calm sea: streak kept" repeats on every scored Daily after a bridged gap
- **Where:** `ProgressStore.swift:310` (`if lastGrace == Int.max { graceKept = true }`) and `:424`; shown at
  `ResultsView.swift:348`.
- **What:** `graceKept` is true whenever *any* gap inside the current streak was bridged, not only one bridged by today's
  flight. Days {1,2,4,5} with today 5: the walk bridges day 3 and reports `graceKept`, so day 5's result card says "Calm
  sea: streak kept" again (and so do days 6 and 7, and so on).
- **Fix:** return the bridged day and set `dailyGraceKept` only when it equals `today - 1` (the gap this run just
  bridged).

### P2-3 `swoop.ach.daily3` ("three days in a row") is earned with a gap
- **Where:** `ProgressStore.swift:358` (`bestDailyStreak >= 3`) with `:421-436` (the grace streak feeds
  `bestDailyStreak`).
- **What:** Days D, D+2, D+3 give a grace streak of 3, so the achievement unlocks after three Dailies that are not
  consecutive. The ASC copy (`docs/appstore/achievements.md` #11, runbook §4) says "three days in a row".
- **Fix:** keep a strict `bestStrictDailyStreak` (no grace) for the achievement, or change the earned description
  before the achievement is created in ASC (descriptions can change, IDs can't).

### P2-4 A practice Daily shares the same line as the scored one
- **Where:** `GameController.swift:2048-2055` (`share: ShareText.line(for: result, streak:)` for every mode),
  `ShareText.swift:108-114`; Share is offered on practice cards (`ResultsView.swift:762`).
- **What:** A practice run of today's sea shares "Swoop Daily #12 9.1 km 🕊️ … 🔥3", which can't be told apart from the
  one counted try. That undermines "one try that counts".
- **Fix:** for `.daily(_, scored: false)` either share the Flight line or prefix "Practice". Drop the 🔥 streak on
  practice lines too.

### P2-5 The Game Center queue cap can evict the player's best `swoop.longest` score
- **Where:** `GameCenterManager.swift:176-199` (`enqueue`).
- **What:** The comment says "the cap of 20 never evicts a `longest` best", but when the queue holds only `longest`
  entries, `out.removeFirst()` drops the *oldest*, whatever its score. Repro: signed out, fly a 20 km best, then 20 weaker
  flights, then sign in. The best was evicted and the board shows a lower best.
- **Fix:** keep at most one pending `longest` entry (the max; the board is "Best score"), or evict the lowest `longest`
  score. Also queue `Int(store.data.bestMeters)` to `swoop.longest` once on each authentication (cheap and idempotent),
  which also covers P2-7.

### P2-6 Achievements are reported only at 100 %, never as progress
- **Where:** `GameCenterManager.swift:151-157` and `:227-232` (`percentComplete = 100` only, for earned ids).
- **What:** `docs/appstore/achievements.md` "Implementation checklist" asks for `percentComplete` on #2–#6, #9, #11 and
  #12 (for example best distance / 1000). The Game Center dashboard therefore shows 0 % on every locked achievement.
  Not a review issue.
- **Fix:** after each run, report `GKAchievement(identifier:)` with `percentComplete = min(100, value / target × 100)`
  for the progressive ones, with `showsCompletionBanner` only when it reaches 100. Remember the last reported percent
  so nothing is resent unchanged.

### P2-7 TestFlight testers' "already reported" set carries over to the App Store build (unverified)
- **Where:** `GameCenterManager.swift:25` (`swoop.gc.reported` in UserDefaults), `:147-157`.
- **What:** TestFlight builds talk to the Game Center sandbox and App Store builds to production (**unverified** for
  iOS 27, but that has been Apple's split). UserDefaults survive the TestFlight to App Store install for the same bundle
  id. Achievements a tester earned and had confirmed in sandbox are then marked reported and are never sent to
  production. This affects the founder and testers only.
- **Fix:** on every authentication, re-report the full earned set at 100 % (GameKit ignores re-completion, and banners
  only fire on first completion), or key the reported set by build channel. Also submit `bestMeters` (see P2-5).

### P2-8 A Daily run that crosses 00:00 UTC never reaches the Daily board
- **Where:** `GameCenterManager.swift:140-144` (`isStale`), `:205-210`; the day comes from the run's mode
  (`GameController.swift:1538-1539`).
- **What:** A scored Daily started on day D and finished after midnight UTC is queued with day D. `flush()` runs at once,
  computes `today = D + 1` and drops the entry as stale. The local record is kept (under D). Dropping is the right call,
  because a recurring board only takes the current occurrence, but the player gets no sign of it. Midnight UTC is 4–7 pm
  in the Americas.
- **Fix:** none required. Optionally, once the clock has passed 23:55 UTC, show "new waves in 5 m" on the scored Daily's
  countdown.

### P2-9 A device clock that jumped forward locks the scored Daily until that date, and Home still says "1 try"
- **Where:** `ProgressStore.swift:286` (`dailyMayScore: day >= lastDailyDay`), `:413`, `:653-658`;
  `HomeView.swift:386-390` (`dailyStatus` ignores `dailyMayScore`); `GameController.swift:910-913`.
- **What:** If a Daily is ever played while the clock reads a future date (a wrong clock, a manual change or a dead-RTC
  reset), `lastDailyDay` keeps that future day, and every real day before it is practice only. Home's line still reads
  "Same waves for everyone · 1 try", so the player only learns on the results card ("Practice · …").
- **Fix:** treat `lastDailyDay > today + 1` as a past clock error (ignore it and lower it to today), and make
  `dailyStatus` take `dailyIsScorable` so Home never promises a scored try it won't give.

### P2-10 A foreground crash or kill after the Daily drop spends the day, files nothing and breaks the streak
- **Where:** `GameController.swift:1729` (the attempt is saved at `.started`), `:650-662` (partials are filed only on
  resign-active); `ProgressStore.swift:197` and `:421` (the streak counts only `daily` keys, not `dailyAttempted`).
- **What:** If the process dies in the foreground (crash, watchdog, or iOS killing it under memory pressure), the day is
  "Tried", nothing is filed, and the streak counts that day as missed.
- **Fix:** file the Daily partial every lighthouse and every ~30 s of flight (cheap: one UserDefaults write), and/or count
  `dailyAttempted` days in the streak.

### P2-11 A backgrounded run that iOS kills: the Daily keeps the distance but bests and the longest board never do
- **Where:** `GameController.swift:650-662`, `:1699-1707`; `ProgressStore.swift:545-555` (a partial updates only the
  Daily record and `bestDailyStreak`).
- **What:** Background a scored Daily at 20 km and iOS later kills the app. The Daily card shows "Flown 20 km", but
  `bestMeters`, lifetime metres, goals, achievements and `swoop.longest` never see the 20 km. Plain Flights lose the run
  entirely, which is acceptable. The Daily's inconsistency is visible.
- **Fix:** when filing a partial, also persist a pending `RunResult` (Codable) and `record()` it on the next launch if the
  session is gone, or fold the partial's metres into `bestMeters`, `lifetimeMeters` and `routeReached` at filing time.

### P2-12 The Daily title shows the UTC date, so evenings in the Americas read "tomorrow"
- **Where:** `Swoop/App/AppModels.swift:696-720` (`dailyTag` in UTC, used by Home, Results and the cover).
- **What:** At 7 pm PDT on 27 Oct, Home reads "Daily Flight · 28 Oct"; in Sydney before 11 am it reads yesterday's
  date. UTC days are the right call for one shared board (DECISIONS #19), but a date label makes the mismatch visible.
- **Fix:** use the display number on screen ("Daily Flight #12", as the share line already does), or keep the date but add
  "· new waves in 6 h" so the rollover is explained.

### P2-13 Star flocks past the top are effectively unreachable for people
- **Where:** `Swoop/Core/Goals.swift:205-213` (`starPool`).
- **What:** The balance sim shows the expert pilot at a median of 66 km, an average chain of 24 and 8.9 lighthouses. The
  frame-perfect pilot reaches 106 km, a chain of 44 and 13.8 lighthouses. Star flock n = 0 asks for 98 km, a chain of 48
  and 11 cloud touches in one flight each. That is at or beyond the perfect bot. It is optional endgame, nobody gets
  stuck below it, and the store copy promises nothing about it. But the "★" line will read as a wall.
- **Fix:** set the star targets at about the expert p90 (≈ 80 km, chain 30, 9 lighthouses), or scale them per flock
  (n = 0 easy, rising).

### Minor (noted, no action needed for 1.0)
- `GameCenterManager.unlock` (`:151-157`) *replaces* the pending list with `earned − reported`, so an achievement earned
  while signed out and then wiped by Settings › Reset progress before sign-in is never reported.
- `RunTally.result` (`AppModels.swift:583-590`, used by the cover's "End flight") sets `seconds: s.time`, which includes the
  countdown, while `FlightSession.finishRun` uses flight time. This only nudges the 20-minute rest line.

---

## Checked and clean

**Crash surface (Core, Persistence, GameCenterManager, the GameController paths that use them)**
- No `fatalError`, `precondition`, `try!`, `as!` or force unwraps. Array indexing is guarded: catalog fallbacks
  `birds[0]`, `skies[0]` and `trails[0]` over non-empty literals; `Lighthouses.name` wraps by modulo; `introSurface` and
  `index(for:)` are bounded; the pilot history and `PracticeGhost.sample` are bounded.
- Ranges can't invert: the logbook loop is behind `result.lighthouses > 0`; `lerpRange` returns `lo...max(lo, hi)`.
- Int conversions from Double are all of finite, clamped values (`ShareText`, `AppTrace.int`, HUD and score).
  `FlightSession.step` guards `dt`, `tuck` and `timeScale` for finite values. The physics never divides by zero
  (`cos(atan(p)) > 0`, `sp > 1e-6`, `max(vx, 1e-6)`).
- `dailyNumber` uses `subtractingReportingOverflow`. The 100k-iteration guards in `SeaProfile.index` and
  `Lighthouses.count` are present.

**Save data**
- `ProgressData`, `SettingsData`, `DailyRecord` and `FlightSchoolState` decode field by field with `try?` and defaults.
  Unknown or missing fields never wipe the rest; NaN goal progress is pruned; rank is clamped to 0…14; `starFlocks` is
  floored at 0.
- An unreadable save is copied to `swoop.progress.corrupt` before the fresh one is written.
- UserDefaults writes are atomic. `[Int: DailyRecord]` and the `Int.min` sentinels round-trip (covered by
  `AppTests.roundTripsThroughUserDefaults`).
- Keys `swoop.progress`, `swoop.settings` and `swoop.gc.*` are unchanged since Round 1. Every R5→HEAD schema change is
  additive: `flightSchool`, `routeReached` (migrated from `bestMeters`), `birdSide`, `sharpHalf`, the Wing check flags.
  TestFlight 2–10 saves load unchanged, and existing players aren't forced into Flight School (`schoolOnFly` needs
  `runs == 0`).
- Demo runs use an in-memory store and nil settings defaults, so they never touch real saves.
- Reset progress keeps the Daily history (no free retry) and asks for confirmation.

**Daily Flight**
- The day is a Gregorian **UTC** day (`DailySeed.utc`), so the device's calendar (Buddhist, Japanese and so on) or time
  zone can't change it.
- The seed is SplitMix64 of the day, and the sea is generated only forward from its own RNG, so the generation order
  doesn't depend on query order. The same day gives the same sea, lighthouses and names on every device. The player's
  best affects only the `newBest` event, not the physics.
- One try: the attempt is spent at the drop (`.started`), not during the countdown. A clock set back gives practice only
  (`lastDailyDay`). Practice and "Fly again" never score a spent day. A run that crosses midnight files under its own
  day, and the new day becomes scorable. Leaving, backgrounding or restarting files the larger partial, and a finished
  record is never replaced by a partial.
- `secondsToNextDaily` is UTC; the launch-day numbering is #1 on 24 Nov, clamped to ≥ 1 before that.

**Game Center**
- The IDs exactly match `docs/appstore/achievements.md` and LAUNCH-RUNBOOK §4: `swoop.longest`, `swoop.daily` and the
  12 `swoop.ach.*` (first, km1, km5, km10, chain5, chain10, tailwind, lighthouse, lighthouse3, cloud, daily3,
  allbirds).
- Scores are whole metres rounded down (`Int(max(meters, 0))`), with the day as context. The Daily board gets only the
  day's scored try (`dailyCounted`), with one pending entry per day, larger wins. Practice Dailies go to `longest` only.
- Authentication is quiet: the sign-in VC is shown only on the player's tap, and the button always answers (dashboard,
  sign-in, or the "Sign in in Settings" hint). The access point is kept off. Everything is async, and failures are silent
  and queued in UserDefaults. Unauthenticated or offline play is never blocked, and scores are resubmitted on the next
  flush with in-flight dedupe.
- The `com.apple.developer.game-center` entitlement is in `project.yml`, and `GKGameCenterBadgingDisabled` is set.
- `GKAccessPoint.shared.trigger(handler:)` working while `isActive == false` is **unverified** on iOS 27 (it works on
  iOS 18 and Brim relies on it).

**Goals, levels and unlocks**
- 14 flocks × 3 goals, 15 levels (`maxRank = 14`). Progress never goes down (`max(before, now)`). The rank only rises,
  with a cascade through flocks the player's bests already meet, stopping at the r7/r10/r13 "fly a Daily" goals, which
  practice Dailies also satisfy, so they are always reachable.
- Every level 1–14 unlocks something. The store copy's claims match the catalogue: **8 birds** (Gull 0, Tern 1, Puffin 4,
  Swift 7, Albatross 10, Storm Petrel 11, Night Heron 13, Golden Gannet 14) and **5 skies** (Golden Hour 0, Rose Dusk 3,
  Northern Lights 6, Monsoon 9, Moonrise 12), plus 4 trails.
- The hardest ladder goals are within reach of the expert pilot (r12: 105 Perfects against ≈ 102 at the median; r13:
  65 km against 66 km at the median). `allbirds` fires at rank 14 with the Gannet.
- Locked choices fall back to the gull, golden hour or the bird's own trail after a reset.

**Share text**
- Locale-independent formatting ("7.4 km", commas). Emoji are spelled as scalars. Empty lighthouse names are trimmed out.
- The share line uses the display number, never the seed day. A spent, unfiled Daily offers no Share.

**DEBUG and demo code in Release**
- `DemoMode.swift` and `DemoRunner.swift` sit entirely inside `#if DEBUG`.
- `AppTrace`, `FeelDemoLog` and `FlightScene.demoLogging` compile to nothing in Release, and the Game Center demo bypass
  is DEBUG-only. Every demo branch in `GameController` is `#if DEBUG`.
- `testflight.yml` archives Release, so a DEBUG-only symbol referenced from Release would fail the build.
- The only test feature left in Release is P1-1.

**Privacy**
- `PrivacyInfo.xcprivacy` declares UserDefaults (CA92.1) and system boot time (35F9.1), with no tracking and no
  collected data. Nothing in scope makes a network call except GameKit.
