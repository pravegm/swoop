# App R1: shell, UI, persistence, Game Center, demo mode (26 Oct 2026)

## Built
- **SwoopApp / RootView.** Full-bleed `SpriteView(FlightScene)` at 120 fps, SwiftUI screens on top, pose cards above.
  One `HingeReader` at the root feeds `GameController.hingeSample` → `HingeTuckSource.ingest`. hasFold = demo `duo` ∥
  hinge seen ∥ `.division` seen ∥ Duo-shaped canvas (landscape, long side ≥ 760). Poses (`AppPoseRule`, pure):
  landscape → play; portrait → "Turn your Duo sideways…" (animated book diagram, "Play with touch" on a Duo); shut
  (≤ 10°, released ≥ 15°) or the cover display → "Open your wings". `OrientationLock`: `.all` on a Duo, `.landscape`
  elsewhere (phones turn by themselves); the stored hinge flag is trusted only on a Duo-shaped screen.
- **GameController** (`SceneDriver`) owns `FlightSession`. Input (`AppRules.chooseInput`, pure): autopilot for the Home
  loop and demo pilots, else the hinge if hasHinge ∧ ¬playWithTouch, else touch; a run may switch touch → hinge on the
  first hinge sample, never hinge → touch. `advance` clamps dt ≤ 1/30, steps, feeds `FeedbackDirector`, publishes the
  HUD ≤ 15 Hz (toasts at once). Pause reasons: user; closing (`isClosing` ∨ shut, hinge runs only →
  `SWOOP-T paused closing`); background (+ pause card); pose (portrait mid-run → pause card). Every resume of a live
  run holds 1.5 s under a "Ready" ring, then `SWOOP-T resumed`. Finish → `ProgressStore`, Game Center,
  `SWOOP-T run …`, results after 0.45 s; "Fly again" rebuilds at once. Daily: the try is spent at the drop; leaving
  after it files the distance so far. Screen kept awake in live runs; `hinge.reset()` on reactivation; `celebrate()` on
  rank up / new best.
- **Home:** attract loop behind; the title bird (`BirdArt.titlePath`) centred on the fold, tuck live from
  `hinge.angle`/`openAngle` (never `tuck(at:)`, so no stray tuck lines), idle beat + press-and-hold on phones; caption
  flips to "Fold to dive. Open to soar." after the first fold/hold. Menu on the far half (Fly, Daily Flight, Flocks,
  Birds); Settings + Game Center round buttons on the bird's half.
- **HUD:** pause (bird-side corner), distance (far corner, monospaced), slate → gold lead meter (pulses coral < 15 %),
  chain pips, Tailwind badge, lighthouse card, first-run hints until the first Perfect ("Hold…/Let go…" on touch),
  3-2-1, Ready, milestone / New best toasts, pause card, "Open your wings to keep flying".
- **Results** (far half): km, best / New best, Perfects, longest chain, lighthouses + "Past X", the 3 goals animating
  before → after with checks, rank-up banner with unlocks; Fly again / Home / ShareLink (`ShareText`).
- **Flocks, Birds, Settings** on two pages either side of the fold (`SwoopPages`); in-app privacy text; reset confirm.
- **Persistence:** versioned, tolerant JSON (`ProgressData`, `SettingsData`). `ProgressRules.record` (pure, injectable
  goals): bests, lifetime, Daily + streak, goal progress (never down), one rank up → `RecordOutcome`.
- **Game Center** (Brim port): quiet auth, confirmed-only queue, stale Dailies dropped, access point off;
  `swoop.longest`, `swoop.daily` (metres); 12 `swoop.ach.{first,km1,km5,km10,chain5,chain10,tailwind,lighthouse,
  lighthouse3,cloud,daily3,allbirds}`.
- **Demo** (DEBUG only; `AppTrace` is a no-op in Release): every ROUND-1 key and log line; seeded runs are really flown
  headless (`DemoRunner`); `screen=icon` / `screen=badges` write the PNGs (`AppIconArt`, `AchievementBadge`).
  `ci/scenarios.txt` 28 frames, `ci/duo-scenarios.txt` 14 Duo store frames.

## Files
`Swoop/App/`: SwoopApp, GameController (+HUDState, AppRules), OrientationLock (+SwoopAppDelegate), GameCenterManager,
AppTrace, DemoMode, DemoRunner. `Swoop/UI/`: RootView, Layout (AppPose, AppPoseRule, AppCanvas, HomeLayout,
PlayLayout, ResultsLayout, TitleTuck), SwoopTheme, HomeView, PlayHUD, ResultsView, FlocksView, BirdsView, SettingsView,
SwoopPages, PoseCards, BirdPreview, ShareText, AppIconArt, AchievementArt. `Swoop/Persistence/`: ProgressStore,
SettingsStore. `SwoopTests/AppTests.swift` (27 tests). `ci/scenarios.txt`, `ci/duo-scenarios.txt`.

## Deviations
- Extra demo keys: `freezeAfter=<s>` (named in the table's text), `freezeOn=splash`, `skipTo=<m>` (fly headless to just
  short of a lighthouse). `freezeOn=stormclose` also accepts a lead already < 15 % (a `lead=` seed fires it headless).
- `SWOOP-T frame 120` comes from FlightScene and `SWOOP-T tuck` from HingeTuckSource; my copies were removed.
- Ranks are shown 1-based ("Rank 1 of 16"). The VoiceOver "wing" control is the labelled hold area only.

## NEEDS
- None blocking. Relies on Core's types being `public` (Contracts' public protocols use them; they are).

## Tune on a real Duo
1. Ready hold (`GameController.readyHold` 1.5 s); shut thresholds (10° / 15°).
2. Title bird: is `hinge.angle` (predictor estimate, not One-Euro) smooth enough? `homeFoldDegrees` 18°.
3. HUD sizes at arm's length (distance 50 pt) and the fold clearance (`AppCanvas.foldClear` 18 pt).
4. Hint timing (`openHintMinDelay` / `openHintMaxDelay` / `hintSeconds`) on real first runs.
