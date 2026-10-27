# QA FINAL: App shell and UI (Swoop/App, Swoop/UI)

*Pre-App-Store bug hunt, 27 Oct 2026, on `main` at a4bc58d (TestFlight 9/10, R12 + the 55°/65° closing gate).
Read-only on code. Every finding below comes from reading the code: there is no Mac or simulator on this side.
Items marked **unverified** rest on estimated text metrics or on platform behaviour I could not run.*

**Counts:** P0 1 · P1 7 · P2 18.

Severity: **P0** = a crash, a stuck state, or a likely review rejection. **P1** = a visible bug a player will hit.
**P2** = minor.

---

## P0

### P0-1 The TestFlight-only "Hinge readout" row and overlay show in App Review builds
- **Files:** `Swoop/App/BuildChannel.swift:46-53`, `Swoop/UI/SettingsView.swift:94-102`, `Swoop/UI/RootView.swift:114-120`.
- **The cause:** `isTestBuild` is true whenever `appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"`. App Review
  installs a production-signed build that runs in the **sandbox** environment, so it carries a sandbox receipt too.
  The reviewer will therefore see this in Settings:
  - a "DEVICE TEST" section;
  - the row **"Hinge readout (TestFlight)"**;
  - a monospaced debug overlay once it is toggled on ("angle … raw … Hz … strokes").
- **Why it matters:** Guideline 2.2 says betas and test features don't belong on the App Store, and the word
  "TestFlight" makes the case for rejection. A Duo reviewer could also toggle the overlay on.
- **The fix:** gate the row at compile time, not with a receipt check at run time.
  - Add a `TESTFLIGHT` active compilation condition that only `testflight.yml` sets (for example
    `xcodebuild … SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) TESTFLIGHT'`). Make it
    `isTestBuild = { #if DEBUG || TESTFLIGHT … }`.
  - The App Store archive must then be a separate build without the flag. **Or, simplest for 1.0:** delete the row
    from Release (keep it `#if DEBUG`) and give the founder a debug build for device tests.
  - Either way, drop "(TestFlight)" from the label.

---

## P1

### P1-1 Flight School step 1 can't pass while the Duo is held flat, and the help text is never drawn
- **Files:**
  - `Swoop/App/FlightSchool.swift:679-691` (`.hold`: success needs 110° ≤ angle < 174° and still);
  - `Swoop/App/GameController.swift:1352` (`d.subline = sc.subline`);
  - `Swoop/UI/FlightSchoolView.swift:702-708` (the Studio draws only `d.words` / `d.wordsSub`);
  - `Swoop/UI/FlightSchoolView.swift:339` (`openHinge = 174`).
- **Repro:** fresh install on a Duo. Tap Fly, then open the Duo fully flat (180°), which is what most people do when
  told **"Hold it open"**.
  - The step needs < 174°, so it never succeeds.
  - The correction "A little less than flat." is stored in `subline`, but **no view renders `subline`**. Nor does
    any view render "Open it wider.", "Turn it sideways.", "Not that far. Just a little." or "Fold both halves in a
    little."
  - The diagram's dashed "open" target is drawn at 174°, which looks flat, so the live pose sits on the target and
    the screen reads as "you're doing it".
  - Nothing moves until the 10 s "Play with touch" offer (the wrong remedy for a Duo player) or Skip.
- **The fix:**
  - Make `FlightSchool.ringWords(at:)` (or `subWords`) return the live correction while it applies. For flat that is
    words **"Bend it a little"** (UX §9's flat copy, ≤ 3 words); for under 110°, **"Open it wider"**. Draw them in
    the Studio's existing word slot.
  - Draw the open target at the book angle (~155–160°, `HingeTuckTuning`'s typical open), not 174°.
  - Add a test: a flat Duo in step 1 shows a non-"Hold it open" word within 1 s.

### P1-2 A seated (portrait) Duo is left on a dead play deck after "Home"
- **Files:**
  - `Swoop/UI/Layout.swift:43-46` (`duo && (inRun || touchOverride)` → `.deck`);
  - `Swoop/App/GameController.swift:1443-1459, 1551-1565`;
  - `Swoop/UI/RootView.swift:177, 286-291`.
- **Repro:**
  1. Duo in portrait (tabletop) on Home. The TurnCard shows: tap **Play with touch**. `touchOverride` turns on and
     the run plays in the split deck.
  2. Pause › Home, or Results › Home.
  3. `startAttract()` leaves `touchOverride` set. `clearTouchOverride()` only runs on a landscape canvas, so the pose
     stays `.deck`.
  4. `deckLayer` shows `DeckPlayView` over the attract loop. Its pause is a no-op (`isLiveRun` is false), the pad
     does nothing, and the screen shows "0 m". There is no Home menu, no Fly and no TurnCard.
- **The only escape** is rotating to landscape, and nothing tells the player that.
- **The fix:** clear the pose-card override when a run ends. In `startAttract()` set `touchOverride = false` (and call
  `refreshInput()`). Or make the deck rule `duo && inRun`; the card's "Play with touch" starts the run at once, so
  `inRun` is already true.
- **Add a test:** `AppPoseRule.pose(portrait, hingeSeen, inRun: false, touchOverride: true)` after Home must be `.turn`.

### P1-3 Auto-Lock can lock the screen mid-Flight School on a Duo
- **File:** `Swoop/App/GameController.swift:2167-2172`. `awake` is only `route == .playing`; the school runs on
  `route == .school`.
- **Repro:**
  1. Duo, Low Power Mode on (which forces Auto-Lock to 30 s), or Auto-Lock set to 30 s.
  2. First Fly. The Studio and the practice sea are flown with the hinge alone, so nothing touches the screen.
  3. The school is about 30 s plus its waits (crest hold, rewinds, the 15 s storm pass). The screen dims and locks
     mid-lesson, then backgrounds and pauses.
- **The fix:** `awake = !isPausedByReason && summary == nil && !homeLoop && route == .playing || (route == .school &&
  !schoolStudioPaused && !isPausedByReason) || route == .wingCheck`.
  - Call `syncIdleTimer()` from `pauseSchoolStudio` / `resumeSchoolStudio` / `startSchool` / `endSchool`.
  - The Studio runs with `homeLoop == true`, so don't gate on `homeLoop` for `.school`.

### P1-4 Fold-to-fly on a scored Daily's results starts a silent practice Daily
- **Files:**
  - `Swoop/App/GameController.swift:2066-2081` (the guard checks only `hingeRun`, `!isDailyCard` and the hinge);
  - `Swoop/App/GameController.swift:923-928` (`flyAgain()` for `.daily` → `playDaily()` → today is spent → practice);
  - `Swoop/UI/ResultsView.swift:639-640, 786-788` (a scored Daily shows Share · Free flight · Home, with no Fly
    again, no fill and no helper).
- **Repro:** fly today's scored Daily by hinge. On its results, fold and open the Duo (for example while adjusting
  the grip). A "Practice · 27 Oct" run starts. The card showed nothing that could fill, and UX §3 says
  "Free flight starts a Flight, never a silent practice".
- **The fix:** in `updateFoldToFly`, return unless `summary.dailyDay == nil` (Flights only), or map the fire to
  `freeFlight()` for a scored Daily. Keep `practiceDaily` → `practiseDaily()` if wanted.

### P1-5 Home's Daily button goes stale across UTC midnight and says "Today's try is spent." for an unplayed Daily
- **Files:**
  - `Swoop/UI/HomeView.swift:19-20, 144-151` (`today` / `now` only refresh in a 30 s loop, not on `scenePhase` active);
  - `Swoop/UI/HomeView.swift:346-353` (the action uses the captured `attempted`);
  - `Swoop/App/GameController.swift:1417-1440` (`openDailyCard` uses the *fresh* day, finds no record, and sets
    `dailySpentUnfiled = true`).
- **Repro:**
  1. Fly the Daily, then leave the app on Home and background it.
  2. Return after 00:00 UTC (19:00 in New York, 01:00 in the UK in summer). Within the first 30 s or so after
     resuming, the tile still shows yesterday's date and "Flown …".
  3. Tap it. The card says **"Today's try is spent."** for a day not yet played, with "Practise today's waves" (which
     starts an unscored run).
- The same happens if the app stays open on Home across midnight.
- **The fix:**
  - Recompute `let day = DailySeed.dayNumber(for: Date())` and `store.hasDailyAttempt(day:)` inside the button
    action.
  - Refresh `today` / `now` in `.onChange(of: scenePhase) { if $0 == .active … }` and in `onAppear`.
  - Make `openDailyCard()` fall back to `playDaily()` when `!store.hasDailyAttempt(day: day)`.

### P1-6 Two "Skip" buttons side by side on the clear-side check, with different meanings
- **Files:** `Swoop/UI/FlightSchoolView.swift:655-657, 725` (the Studio's `SchoolSkipButton`, "Skip Flight School")
  and `:885-895` (`WingCheckPages`' own "Skip", meaning "Not sure").
- **Repro:** Duo, step "Clear side". Both pills read **Skip** on the bird page's bottom edge, about 36 pt apart.
  - After 10 s without flat, the check's Skip grows to 200 × 56 and its tap area overlaps `SchoolSkipButton` by about
    4 pt (unmirrored: x 132–136 against 40–136, y 601–645; mirrored: x 815–819).
  - A player who means "skip this check" can tap the other one. That skips the **whole** lesson (`.skipped` is
    persisted) and starts a 3-2-1 Flight.
- **The fix:** hide `SchoolSkipButton` while `d.step == .wingCheck` (the check has its own way out), or label them
  "Skip lesson" and "Not sure". Keep the tap areas ≥ 8 pt apart.

### P1-7 (unverified: text metrics) Home's caption overflows into the Settings and Scores pills on 375 pt and 390 pt tall iPhones
- **Files:** `Swoop/UI/Layout.swift:284-291` (the caption rect) and `Swoop/UI/HomeView.swift:199-227`. The headline is
  limited to 2 lines, and the objective sentence below it is `.fixedSize(vertical)` with no line limit.
- **The arithmetic on the iPhone SE 3 (667 × 375):** the caption rect is y 236.5–295 (58.5 pt), and the corner pills
  are drawn at y 309–353.
  - A fresh install's "Hold anywhere. The wings fold." at 19 pt wraps to 2 lines (~46 pt) in the 283 pt bird page.
  - The objective sentence below it (15 pt, 47 chars) is 2 lines (~37 pt).
  - That is about 91 pt of text: it runs past y 327 and over the pills.
- **iPhone 16e and 13 mini (844 × 390):** the rect is about 55 pt, so it is the same or worse.
- **Not caught so far:** AppTests check the rects, not the rendered text; CI shoots only iPhone 18 Pro (874 × 402),
  where it's about 5 pt over.
- **The fix:**
  - On compact canvases, drop the objective line when the caption is not the objective, or give the objective
    `.lineLimit(2).minimumScaleFactor(0.8)` and cap the headline at 1 line + `minimumScaleFactor(0.75)`.
  - Better: measure with `ViewThatFits` and drop the objective when it doesn't fit.
  - Add an iPhone SE (3rd gen) run to `ci/screenshots.sh` (`DEVICE="iPhone SE (3rd generation)"`) for home-fresh,
    play, pause, results and goals.

---

## P2

1. **"Switch to touch" / "Keep touch" last one flight, not the app session.**
   - `RootView.swift:137, 177` calls `clearTouchOverride()` on every route change on a landscape canvas, and
     `GameController.swift:1455-1459` clears it once the run is no longer live, so Results already clears it.
   - The next "Fly again" is back on the hinge, against UX §5's "this app session only".
   - **Fix:** keep a separate `sessionTouch` for D7's pause choice that the pose rule never clears.

2. **Flight School and the seated deck.**
   - In portrait during the school sea, the TurnCard's "Play with touch" moves the run to `DeckPlayView`
     (`PlayHUD.swift:313-320`). That view has no school words, dots or Skip, and its PauseCard offers
     **Restart** → `flyAgain()` → `start(.flight)` with `schoolSeaRun` still on (`GameController.swift:923-933`).
   - **Fix:** in `DeckPlayView` show `SchoolPauseCard` when `controller.schoolSeaRun`. Or keep the school out of the
     deck: TurnCard without "Play with touch" while `schoolActive`.

3. **The TurnCard's "Play with touch" bypasses Flight School for good.**
   - `GameController.swift:1443-1451` starts `.flight` directly. On a first launch `runs` becomes 1, so
     `schoolOnFly` is never true again.
   - Tapped during a Studio step, `school` stays non-nil and steps invisibly behind the real flight until Home.
   - **Fix:** route through `fly()` when `homeLoop`, and call `endSchool()` if `school != nil`.

4. **The cover never shows "Flight School paused".**
   - `RootView.swift:166-170`: `closedState` needs `inRun`, which excludes `.school`. Closing the Duo mid-school
     shows the generic Home cover.
   - The `inSchool` branch in `PoseCards.swift:318-342` is unreachable, and so is "End flight" there (good, because
     `endFlightHere()` would record a practice run: add a `!schoolSeaRun` guard anyway).
   - **Fix:** `if controller.route == .school, let p = controller.pausedRun { return .midRun(p) }`, and hide
     Keep flying / End flight when `run.inSchool`.

5. **The ClosingCard in the school says "Paused at 1.2 km."** (the practice sea's distance), `PlayHUD.swift:164-168`.
   **Fix:** in the school, omit the line or say "Flight School paused".

6. **The Studio has no accessible "Wings" element.**
   - `FlightSchoolView.swift:744-759`: the hold or tap is a raw `DragGesture`. With VoiceOver on, step 1 on an
     iPhone can't be done directly, and VO users must find Skip.
   - The first step's sentence is never announced: `startSchool` doesn't call `announce`.
   - **Fix:** add the same `accessibilityElement` + `.allowsDirectInteraction` + adjustable action as
     `PlayLayer.touchLayer`, and announce `sc.prompt` on start.

7. **No Dynamic Type anywhere.** Every font is `.system(size:)` (`SwoopTheme.swift:99-119`); UX §6 asks for pages and
   results up to `.accessibility2`. It isn't a crash or a rejection, but **don't tick "Larger Text" in the App Store
   Accessibility Nutrition Label.**

8. **Reduce Motion is not honoured by a few animations:**
   - the `ChainPill` lost-shake (`PlayHUD.swift:640-645`);
   - the `LeadMeter` storm-icon shake and repeating pulse (`PlayHUD.swift:583, 596`);
   - `SchoolBigWord`'s 1.6× scale transition (`FlightSchoolView.swift:612`).

   **Fix:** gate them on `reduceMotion`, as everywhere else.

9. **Battery.**
   - Under the pause and closing cards, `SpriteView` keeps rendering at 120 fps (`RootView.swift:241-262`; `fps`
     depends only on the route).
   - Behind the near-opaque Settings, Goals, Birds and Route pages, the attract loop renders at 60 fps.
   - **Fix:** pass `isPaused: true` (or 30 fps) while `isUserPaused || isClosingPaused`, and on page routes.

10. **Killing the app mid-Flight loses the flight entirely:** no lifetime metres and no goal credit
    (`GameController.swift:650-663` files only the Daily). This is a design call; consider filing `lifetimeMeters` at
    background.

11. **Opening the Route from Results drops the results.** Tapping the mini route strip (`ResultsView.swift:171`) runs
    `show(.route)` → `startAttract()`, and Back goes to Home, so Fly again is lost. Acceptable; or make Back return to
    the card.

12. **A Duo with a stored hinge but no live samples this launch gets the Duo lesson ("Hold it open") until the 10 s
    touch offer** (`GameController.swift:1022-1025`, `schoolTouch` uses `hasHinge`, which includes the stored
    flag). **Fix:** decide the variant on `hinge.hasHinge` after ~1 s, or offer touch at 3 s when `hinge.angle == nil`.

13. **Copy and glossary (UX-ROUND-9 §3/§4).** Each item is a one-line fix:
    - "Sign in to Game Center in Settings to see leaderboards." (`HomeView.swift:100`): the button says "Scores".
      Use "top scores", and "iOS Settings" (the app has its own Settings).
    - Settings › Wings by: the footnote "one tap **tucks**" (`SettingsView.swift:64`). Use "one tap folds the wings".
    - The Reset alert says "bests, **ranks**, goals…" (`SettingsView.swift:37`). Use "levels".
    - Birds VoiceOver says "locked until **rank** N" (`BirdsView.swift:170, 196, 229`) while the tile shows "Level N".
    - The touch wing's VoiceOver value is "**Tucked** / Spread" (`PlayHUD.swift:194`). Use "Folded / Open".
    - The New best toast reads "Every metre now is a **record**" (`GameController.swift:1780`): "record" is a banned
      word and the sentence has no full stop. Use "Every metre now is your best."
    - The Ready ring says "Spread your wings" on iPhone touch runs too (`PlayHUD.swift:1056`). Use "Let go" there.
    - Home's Route tile reads "1 reached" (`HomeView.swift:245`). The glossary says "passed".
    - The pause card says "Gull Point in 1.9 km" (`RouteRules.goalLine`, `FlightSchool.swift:1032`). The glossary wants
      "Next: Gull Point · 1.9 km".
    - The cover says "Daily 27 Oct" and "Daily 27 Oct · your one try is paused" (`PoseCards.swift:293, 371`), with no
      "Flight ·". It also has the row "Daily streak · 3-day streak" (`:296`), which says streak twice.
    - The VoiceOver-only school prompts still say "One fold per wave. **Never flap.**" and "Fly to Gull Point · 4 km."
      (`FlightSchool.swift:948, 953`). UX-R9 cut both.
    - Core's goal texts on Results and Goals: "3 **Perfects** in one flight", "**Chain** 10 Perfects in one flight"
      (`Core/Goals.swift:108-151`). Glossary: "3 perfect landings in one flight", "10 perfect landings in a row".
      Owner: Core.

14. **Dead code with banned copy:** `RankUpBanner` ("You ranked up!", "Rank 2 · …"), `ResultsView.goldChip`,
    `WingCheckCard` and `TouchWingFeedback.glyph*` (`ResultsView.swift:1029-1135`, `HomeView.swift:528-554`). None is
    on screen today. Delete them so a later round can't revive them.

15. **`AppRules.dailyTag` builds a `DateFormatter` on every call** (`AppModels.swift:706-720`). It runs in
    `hudTag` on every HUD redraw (up to 15 Hz in a Daily), and in Results and Home. **Fix:** use a static formatter.

16. **The Daily date is the UTC date:**
    - A US player in the evening sees tomorrow's date ("Daily Flight · 28 Oct" on 27 Oct, `AppModels.swift:706`).
    - `DailySeed.launchDay` is hard-coded to 24 Nov 2026 (`Core/Lighthouses.swift:118`). If 1.0 goes live earlier,
      every Daily before that shares as "Daily #1".

    Confirm both are intended.

17. **(unverified)** Some locked labels may truncate on the 667 pt iPhone:
    - Birds' 4-column grid tiles are ~65 pt, so "Storm Petrel"-length names at 13 pt with a 0.85 minimum scale.
    - The 5 sky tiles are ~52 pt, so "🔒 Level 3".

    Check on an SE frame.

18. **(unverified)** `GKAccessPoint.shared.trigger(handler:)` is called while `isActive = false`
    (`GameCenterManager.swift:44, 68`). I believe it still opens the dashboard; confirm on device once, or use
    `GKGameCenterViewController`.

---

## Checked and clean

- **Release vs DEBUG:**
  - `DemoMode.swift` and `DemoRunner.swift` are wrapped entirely in `#if DEBUG`.
  - `AppTrace.t`, `FeelDemoLog`, `FeelHingeLog` and the `SWOOP-T frame 120` print are DEBUG plus `-swoopDemo` only.
  - Every demo accessor (`isDemo`, `demoDuo`, `demoSettingsWhy`, `demoPosePhone`, `forcedPose`, `showsIconExport`,
    the freeze code) is false or unset in Release.
  - The Game Center demo bypass is DEBUG only.
  - Release compiles (TestFlight 9/10 were archived).
  - No `try!`, `as!` or force unwraps in App/UI; the only `fatalError` is `FlightScene.init(coder:)`.
- **Lifecycle:**
  - `scenePhase` != active (Control Centre, a call, Siri, background) does three things: it finishes and records a
    run in its caught window, files the scored Daily, and user-pauses a live run.
  - Coming back needs a tap (pause card) and then the 1.5 s Ready ring. The hinge is reset and re-subscribed on
    activation.
  - Audio interruptions are handled in `FeelAudioEngine`.
  - Low Power Mode and thermal state drop play to 60 fps and trim effects.
  - The idle timer is disabled only during a live `.playing` run, and re-enabled on pause, results, Home and
    background (apart from P1-3).
- **Duo states:**
  - The closing gate (55°, instant under 40°; resume at 65°) only pauses hinge runs.
  - The closing card's Resume appears at 1.5 s and ignores a stale latch.
  - Shut → cover: the mid-run card offers "Keep flying here", which flies the deck and gives the "Fly with the fold?"
    prompt on reopening, and "End flight", which records the run and shows results on the cover.
  - Reopening holds the 2.8 s Ready ring.
  - A 180° turn with Bird side = Sharp pauses before the bird changes halves.
  - Fold-to-fly disarms when closing.
- **Navigation:**
  - Goals, Birds, Settings and Route all have Back. The Daily card has Home. The standalone Wing check exits through
    "Not sure, skip".
  - The school Studio and Sea pauses both offer Skip and Home.
  - Pause is hidden once caught. A scored Daily has no Restart and says "Leaving ends today's try."
- **Double taps and races:**
  - `start()` cancels the pending results task, finishes a caught run, and clears pauses, ready rings, toasts and
    tallies.
  - A fold-to-fly and a tap on Fly again together just start one run.
  - School state is reset by `endSchool()` on skip, finish and Home.
- **Flight School:**
  - Skip is shown from step 1 (`canSkip = true`) and works in every phase except finished.
  - Misses rewind and pass after 3. The storm step passes after 15 s.
  - Sea pause → Resume rewinds to the checkpoint.
  - Replay from Settings starts at step 1 over the attract loop.
- **Touch only:**
  - On iPhone every flow works by touch: hold anywhere, the TurnCard plus an automatic landscape request, and tapping
    mode for Switch Control and VoiceOver.
  - Every button's tap area is ≥ 56 pt: `SwoopButtonStyle` minHeight, the 64 × 56 icon tiles, the 56 pt corner
    pills, the 56 pt segmented rows, and the quiet 44 pt buttons padded to 56.
- **Results:** the `ResultsPlan` fit plan drops rows before clipping on compact cards. On a 284 pt far card the Daily
  row drops because it doesn't fit, which is intended.
- **Accessibility:**
  - Every button and tile checked has a VoiceOver label.
  - Announcements are throttled (1.5 s, by priority).
  - Results and pose changes post `.screenChanged`.
  - Contrast: haze `#7896AB` on surface `#0B2236` ≈ 5.2:1 (computed). The navy scrims at 0.62 are covered by the
    `Contrast` tests.
- **Privacy:** the manifest declares UserDefaults CA92.1 and system boot time 35F9.1. There is no tracking and no
  network, apart from Game Center, which never shows a sheet on its own.
