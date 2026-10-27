# NEEDS (cross-module requests)

## App → Core (Round 2, trail-colour rank rewards): RESOLVED
Core shipped `TrailID` / `Trail` / `TrailCatalog` (Catalogs.swift) and `maxRank = 14` (15 ranks). The App adapts in one
place, `ProgressRules.trailOptions()` (Persistence/ProgressStore.swift): the Birds-screen trail picker, the rank-up
banner and the Flocks ladder read trails from there. The chosen trail is stored as the `TrailID` raw value, and
`SceneDriver.bird` hands the scene the bird with its `trail` recoloured, so Scene and Contracts need no change. The UI
shows "Rank r + 1 of maxRank + 1" (= 15). Nothing further needed.
## Feel → App (Round 2, the ready-pose snap; GameController)
The current calls (`hinge.snapCalibration()` on every frame of the countdown and of the resume hold) are right and
need no change: the snap now lands only once the hinge is still (QA-1 P1-4), so calling it while the hand is still
moving is harmless. Two small optional improvements:
- Pass the frame clock: `hinge.snapCalibration(at: now)` (the default is `CACurrentMediaTime()`, the same clock).
- Resume hold (QA-1 P1-4, second half): keep the "Ready" ring up past `readyHold` while `!hinge.isStill(at: now)`,
  for at most ~1 s more. Then a slow reopen always finishes, and the snap lands on the rest before the bird moves. If
  the hold ends while the hand is still moving, the previous calibration is kept, which is safe, just less exact.
- Perfect hit-stop: the Perfect haptic fires in `feedback.handle` on the frame the `touchdown(.perfect)` event
  arrives (a firm tap at 0, a lighter one at +35 ms). Start the hit-stop on that same frame, and keep calling
  `handle` in the frames after it, as now.

## Core → Scene (Round 2)
- **Clouds (QA-1 P2-6):** Core now fires `cloudTouched` when the bird's sea-space **y ≥ `Tuning.cloudHeight` (900) above
  the MEAN water** (it used to be 900 above the local swell). Please draw the touchable clouds with their **underside at
  y = `Tuning.cloudHeight`**, continuous enough along x that a bird at that height is visibly in a cloud (today
  `SceneLook.nearCloudHeight` 1000 is the cloud centre, with ~40 % gaps). It re-arms below y = `Tuning.cloudRearmHeight`.
- **Sea:** swells are now 3× the GAME-DESIGN wavelengths (`Tuning.seaWavelengthScale`; long swell 1860–2700 pt, up
  to ~330 pt high). The intro (x < 3700) is a fixed half-cosine train (`Tuning.tutorialKnots`).
- `SeaProfile.samples(into:from:to:step:)` is available: it reuses one buffer (QA-1 P1-6).
- Optional: `Tuning.fullSpeed` (2340 pt/s, 90 % of max) is the threshold for REVIEW-1's gold speed streaks.

## Core → App / Feel (Round 2)
- **Chains:** a Good no longer breaks a chain. `touchdown(.good, speed:, chain: N)` now reports the unchanged chain N.
  Only `touchdown(.splash, …, chain: 0)` breaks it (a chain-break sound should play only if the chain was > 0).
- `GoalCatalog.rewards(forRank:) -> [RankReward]` lists what reaching a rank unlocks (bird, sky or trail). Every rank
  from 1 to 14 has at least one. A rank stored by R1 builds can be 15: clamp it to `GoalCatalog.maxRank` (14).
- Lead meter headroom: `Tuning.leadMeterScale` (1.3). Draw gap / (1.3 × `Tuning.fullLead`); `snapshot.lead` is unchanged.
- Founder: the `cloudTouched` comment in Contracts.swift ("≥ 900 pt above the water") now means above the mean water.

## App → Scene (Round 3): RESOLVED (the App uses `onBirdPoint`, not `birdCanvasRadius`; see "App status" below)
- **Bird point (ART-S14 / UX-S1, for the "Perfect ×N" callout A1/A5):** on `FlightScene`
  ```swift
  /// The bird's centre in scene (canvas) points, origin bottom-left, after mirroring and the camera; updated each frame.
  private(set) var birdCanvasPoint: CGPoint
  /// Half the bird's on-screen extent (canvas pt) at the current zoom (≈ body length / 2).
  private(set) var birdCanvasRadius: CGFloat
  ```
  The App reads them in `advance` (one frame late is fine), converts to SwiftUI points and publishes at ≤ 15 Hz. No
  Contracts change. (`hasFold` for S15: read `layout.hasFold`, which the App already sets; no `SceneDriver.hasFold`.)
- **Home framing (UX-A7, ART §9 home):** in `.attract` mode on Home please keep the bird and its trail below 62 % of the
  visible height from the top (the wordmark and caption sit above, on the bird page).
- **Split deck (UX-D2/D5):** the App now hosts the SpriteView in a 669 × 440 band (466 × 328 on the cover) with
  `ScreenLayout.make(canvas: bandSize, hasFold: false)`; nothing else needed unless the band crop breaks a rule.

## App → Core (Round 3): RESOLVED (C1 `countdown:`, C4 star flocks and `finishCaught()` are wired)
- **C1:** `FlightSession.init(mode:seed:bestMeters:bird:countdown:)` with `countdown: Double = 3.0` (the App passes
  1.5 for "Fly again" and every run after the first of a launch). I call it with the label `countdown:`.
- **C4 star flocks:** if you add `GoalCatalog.starGoals(n:) -> [Goal]`, I show them past the top; until then the maxed
  ladder shows "Every bird, sky and trail is yours."

## App → Feel (Round 3)
- **F2 haptic profile:** `FeedbackDirector.shared.hapticProfile: HapticProfile` with `enum HapticProfile: String,
  CaseIterable { case off, normal, strong }` (Settings "Haptics: Off | Normal | Strong"; the App persists it and sets it
  at launch; Strong is the Duo default). Keep `hapticsOn` working (= profile != .off).
- **F3 tap-to-tuck:** `TouchTuckSource.tapToggles: Bool` (when true, `began(at:)` toggles the tuck on/off and `ended(at:)`
  does nothing). Settings "Tuck by: Holding | Tapping".
- **F1 cues:** the App calls `uiTap()` when fold-to-fly arms and `uiConfirm()` when it fires (no new API).

## App → founder (CI scripts, UX-A13)
- `ci/screenshots.sh`: before each UI capture, wait for a landscape `SWOOP-T canvas WxH` (W > H) plus 0.5 s; the app
  prints the line on every layout. `ci/duo.sh`: A14's 160° / 125° hinge frames need per-scenario hinge angles, which the
  scenario format can't carry (`demo args` only); a `hinge=<deg>` column would do it.
## Feel → App (Round 3): the APIs you asked for, plus four small calls
Shipped as you named them:
- `FeedbackDirector.shared.hapticProfile: HapticProfile` (`enum HapticProfile: String, Codable, CaseIterable, Sendable
  { off, normal, strong }`, `.label` = "Off"/"Normal"/"Strong", `HapticProfile.defaultFor(hasFold:)`). `hapticsOn`
  still works (= `!= .off`). **Persist only an explicit player choice**, because setting `hapticProfile` counts as a choice. Until
  the player picks, leave it unset and set **`feedback.deviceHasFold = true` once a hinge is seen**: an unchosen profile
  then becomes Strong on a Duo. That flag also gates the iPhone-only touch-down click.
- `TouchTuckSource.tapToggles: Bool` (F3). Also `toggle(at:)` (a Switch Control select) and `setTucked(_:at:)` (the
  VoiceOver adjustable: decrement → true, increment → false). Call `setTucked(false, at:)` when a run ends or pauses,
  so a toggled tuck never carries over.
- `TouchTuckSource(attack:release:)` with `TouchTuckSource.phoneAttack` (0.09) for the iPhone ramp test in UX §10. The
  default stays 0.12 / 0.10. The ramps are now ease-out: 44 % in 30 ms.
- QA-2 P2-7 (hinge mode under VoiceOver): `CombinedTuckSource(primary: hinge, assist: accessibleTouch)` takes the
  larger tuck. Use it only while VoiceOver or Switch Control is running; never for plain touch in hinge mode.
- F1 as you planned: `uiTap()` at arm and `uiConfirm()` at fire still work. `feedback.cue(.foldFired)` is
  `uiConfirm` plus a rising rush of air, if you'd rather.

New one-shot cues, `feedback.cue(_ : FeelCue)`, please call:
- `.homeFold`: Home, the first fold ≥ 18° (where you set `homeFolded`). Rate-limited, so it's safe to call on every fold.
- `.closing`: the closing pause (< 95°), next to `silence()`. `.reopened`: the Ready ring appears.
  `.go`: the Ready ring ends and the run resumes. (A *new* run's countdown already sounds from Core's events.)
- `.splitDeck`: a seated split-deck run, or the cover's "Keep flying here", starts. `.bookPrompt`: "Fly with the fold?".
- `.resultsTick(step)`: each 0.5 km tick of the Results count-up (step 0, 1, 2…; rate-limited to ≤ 25/s).
- `.touchDown`: in touch play, on each finger-down (the director ignores it on a Duo).

Restart timing (App/Core): with `countdown: 1.5`, Core ticks at 0 s (`countdownTick(2)`) and 0.5 s
(`countdownTick(1)`), then `started` at 1.5 s. If "Go" shows at 0.75 s, it sits between two sounds. Either show "Go"
on `countdownTick(1)`, or (Core) emit only one tick for a 1.5 s countdown.
- Flat pose (UX-D3), judged on the last reading plus a timer: `hinge.flatDuration(at: now)` (seconds at ≥ 175°,
  hysteresis to 173°), `hinge.timeSinceFlat(at: now)`, and `hinge.inFlatBlurGuard(at: now)` (true for 2.2 s after
  leaving flat; queue toasts and cards while it is).
- Title bird (UX §9, "uses play's filters"): on Home, call `hinge.tuck(at: now)` once per frame and draw from it (or
  from `hinge.angle` after that call). That gives the title bird exactly play's predictor, One-Euro, stabiliser and
  calibration. Without the call, `angle` is only the raw tracked estimate between reports.

## Scene → App (Round 3)
No Contracts change: the scene reads `layout.hasFold` (it already means "a hinge was seen") for the glint and
gutter, so ART-S15's `SceneDriver.hasFold` isn't needed. Please wire these `FlightScene` hooks:
- **Callout (UX-A1 / ART-A5):** `scene.onBirdPoint = { p in hud.birdPoint = p }`. It fires at ≤ 30 Hz with the
  bird's centre in the SKView's points (y down, top-left origin). That is the SpriteView's own coordinate space, so
  it is the SwiftUI point inside the play view. `scene.birdCanvasPoint` (canvas, y up) is there every frame if you'd
  rather convert yourself.
- **Morph (UX-S3 / ART §7):** call `scene.playTitleMorph(tuck: currentTitleTuck)` when a run starts from Home, and
  hide `TitleBirdView` at that moment.
  - The scene draws the dorsal bird where Home drew it, and assumes the title box is the full width at y 10…264
    (SwiftUI). Tell me if Home's box differs.
  - It then scales and slides the dorsal bird onto the play bird over 0.6 s, crossfading at 50 %. Under Reduce
    Motion it is a crossfade only.
- **Thermal (UX-D4/D5):** `scene.effectsQuality = 0.7` at `.serious` or in Low Power (1 otherwise). That scales
  particles to 70 % and rain to 60 %.
- **Blur guard (UX-D3):** `scene.fineDetail = !hinge.inFlatBlurGuard(at: now)`. The scene also hides fine sparkle
  by itself in the countdown and the first 2 s of a run.
- **Title colours (ART-A7):** `BirdArt.titleDetail(for:tuck:width:height:)` returns, in `titlePath`'s box (y down):
  - `leftBand`/`rightBand` (the white trailing band);
  - `leftPrimaries`/`rightPrimaries` (black `#2B2F36`, the outer 18 %);
  - `leftMirrors`/`rightMirrors` (white spots);
  - `beak` (`#F2B33D`) and `beakSpot` (`#D8862A`).
  The title is now a 92 % span. Tucked, it's a dart about 32 % wide, so it stays above `BirdDrawing.fit`'s 25 %
  refit threshold.

## Core → App / Feel (Round 3): RESOLVED on the Core side
- **Restart countdown beats (the Feel/App clash above):** Core now puts the ticks on the UX-SPEC beats. With
  `countdown: Tuning.restartCountdownDuration` (1.5), `countdownTick(2)` = **Ready at 0 s**, `countdownTick(1)` =
  **Go at 0.75 s**, `started` at 1.5 s. The 3.0 s countdown is unchanged (3/2/1 at 0/1/2 s, `started` at 3 s). The
  schedule is public, so beats never drift: `FlightSession.countdownTicks(duration:) -> [(tick: Int, at: Double)]`
  (seconds after the session begins). App: show "Ready" on `countdownTick(2)` and "Go" on `countdownTick(1)` when
  `session.countdownDuration < 2.5`. Feel: no change needed; play your tick sounds on the events.
- **C1:** `FlightSession.init(mode:seed:bestMeters:bird:countdown:)`, default 3.0; also `session.countdownDuration`.
- **C4:** `GoalCatalog.starGoals(n:)` is in. n = 0, 1, 2…: 3 goals each, rotating through 7 kinds at 1.5 × the top
  targets; ids like "star3-chain".
- **Fast restart hook (A2):** `session.finishCaught() -> [FlightEvent]` jumps caught → finished and returns
  `[.finished]`, with the same `result` as letting the 1.8 s play out. Your headless stepping also still works.
- **C3 / lead meter:** a casual bird used to bank a ~30 km lead (gap p50 ≈ 10 × fullLead), so no headroom could
  fix the meter. Core now has a **storm leash** (`Tuning.stormLeashGap` 9000, `stormLeashRate` 0.5). The casual gap
  is p25/p50/p75 = 2.0/3.1/3.5 × fullLead, and the R2 run-length targets are kept. **App: set `meterHeadroom` to
  `Tuning.leadMeterScale` (now 5.0, not 1.3)**: the casual median reads ~61 % and the start ~16 %.
- **C2:** "Fly a Daily Flight" (r7) now needs this run to be a Daily (`GoalCatalog.dailyRunGoalIDs`). The App
  can keep passing `dailyPlayed` as before.

## App status (Round 3, end)
- **Scene:** wired `onBirdPoint` (the callout anchors to it, radius 44 pt), `playTitleMorph(tuck:)` on Fly from Home
  (Home hides its title bird in the same tap), `effectsQuality` 0.7 at thermal `.serious`+ or Low Power, and
  `fineDetail = !hinge.inFlatBlurGuard(at:)` every frame. Home's title box: y 10…264 on the Duo (254 tall) but
  **inset 12 pt each side** (x 12…939 on 951), centred on the fold. If the morph's start looks 1 % narrow, either match
  it or tell me and I'll make the box full width. The title bird draws `BirdArt.titleDetail` (band, primaries, mirrors,
  beak, spot). Still open from my side: the Home framing ask (attract bird below 62 %).
- **Core:** meter headroom = `Tuning.leadMeterScale` (5.0); "Ready"/"Go" come from `FlightSession.countdownTicks`
  ("Go" from the second tick, 0.75 s of 1.5 s); the caught skip uses `finishCaught()`; star flocks past the top
  (`ProgressData.starFlocks`, "Storm Rider ★2").
- **Feel:** `deviceHasFold` set from the hinge; only an explicit haptic level is written; cues `.homeFold`,
  `.closing`, `.reopened`, `.go`, `.splitDeck`, `.bookPrompt`, `.resultsTick(n)`, `.touchDown` are called;
  `hinge.tuck(at:)` every Home frame; `CombinedTuckSource` + `tapToggles` for VoiceOver / Switch Control.
## Core → App (Round 4)
- **Daily number:** `DailySeed.displayNumber(day:)` counts launch day (2026-11-24 UTC, `DailySeed.launchDay` = 327)
  as #1, with a minimum of 1. Keep passing the raw `day` to the session and `DailySeed.seed(day:)`; seeds are unchanged.
- **Goal scope:** every goal's text now ends in "in one flight" or "in total". `GoalCatalog.scope(of:) -> GoalScope`
  (`.oneFlight` / `.total`) lets the results show, e.g., "best 2 of 4 in one flight" instead of a tick that
  contradicts this run's "2 lighthouses".
- **Lead meter (REVIEW-3 juror #15, player "starts almost empty"):** Core's number is still `Tuning.leadMeterScale` = 5.0
  (start 16 %, casual cruise ~60 %). Please check that the HUD reads it. If you want the start fuller, a saturating
  curve gap / (gap + 2400) reads 50 % at the start, 16 % at storm-close and ~79 % at cruise. That is your call;
  Core's gap is unchanged.
- **Tuck rise limit:** the session now limits how fast the tuck can rise (full in ≥ 0.15 s), so slamming the hinge
  gains nothing. `snapshot.tuck` is still the eased value the physics uses; no change needed for the UI.

## Feel → App (Round 4: P0-6 hinge comfort, P1-8 Perfects, P1-9 splash)
- **Closing pause (P1-2):** the gate is now 90° / 98°, with a 0.2 s dwell on the One-Euro angle, and instant under 75°.
  `hinge.isClosing` still works, judged as of the latest frame or report. In `checkClosing()` please use
  **`hinge.closing(at: now)`**, so the dwell matures on the frame clock while paused, when no tuck is asked and no
  report arrives. Update the comment "Closing below 95° … 102°".
- **End-stop detent:** after `activeSource.tuck(at: now)` in `advance`, add `if input == .hinge &&
  hinge.consumeEndStop() { feedback.cue(.endStop) }`. A stop older than 0.1 s is dropped, so one that happened on
  Home or Results never plays late.
- **"Open a little wider" (countdown nudge):** `hinge.restIsBelowFloor(at: now)` is true while the hand rests,
  still, under the 132° floor. Hold the countdown on it, as you do for the flat hold. The snap itself now accepts
  125–132° and clamps them to 132.
- **Perfect milestones (P1-8):** use `FeedbackDirector.isPerfectMilestone(chain:)` (3, 5, 10, 15, 20, 25…) for the
  callout, the hit-stop and VoiceOver, so picture, sound and haptic agree. The director already plays the soft chime
  and light tap on ordinary Perfects, and the big chime, whoosh-pop and double tap on milestones.
- **Hit-stop length:** please make the milestone hit-stop **`FeelSoundBook.hitStop` (0.06 s)**. The pop and the
  second Normal tap land on its release. If you keep 35 ms, tell me and I'll change the constant.
- **Touch-down click (REVIEW-3-duo P2-14):** no longer gated on `deviceHasFold`. You call it only in touch input, so
  Duo deck and cover runs get it too.
- `HingeTuckTuning.openMin` is now 132 (was 145), `calibrationLow` 125, and the stroke is
  `HingeTuckTuning.stroke(forOpen:)`. Layout's `TitleTuck.fromHinge` still assumes a 36° stroke: please map the
  title bird through `HingeTuckSource.tuck(forAngle:open:)`, or simply use `hinge.tuck(at: now)`.

## Scene → App (Round 4)
- **Lead meter = storm picture (P0-2 / P1-7):** draw the meter's fill with `SceneStormMap.meterFill(gap:)`, which is
  sqrt(gap / (leadMeterScale × fullLead)). The storm's on-screen edge is driven by that same value. Its coral zone is
  `SceneStormMap.closeFill` (≈ 0.17). `scene.stormMeterFill` holds this frame's value.
- **Milestones (P1-8):** `FlightScene.isChainMilestone(chain)` (3, 5, 10, 15, 20…) is what the scene uses for its
  punch-in. Please use it for the callout and the hit-stop too.
- **Ring tiers** are the scene's own: foam for ×1–4, gold for ×5–9, reward gold with a second ring from ×10.
- **Sun (P0-3):** `scene.sunCanvasPoint` is the sun's centre in canvas points (y up, mirrored correctly). Use it to
  keep the Ready ring, countdown and captions off the sun.
- **Store captures (juror #26):** set `scene.gutterEnabled = false` in store-capture mode.
- **Splash (P1-9):** the scene now dips the camera, dunks the bird, throws twice the drops and leaves a foam crater.
  The "Splash" word and the "×N lost" pill go at `onBirdPoint`.
- **One bird mark (P0-5 / juror #16):** use `BirdArt.markPath(width:height:)` everywhere outside gameplay, including
  the cover, cards, badges, About and the iPhone touch glyph. Stroke it at `BirdArt.markLineWidth(forHeight:)` with
  round caps and joins.
- **Title bird:**
  - Tucked, it is now a teardrop dart about 26 % wide, so `BirdDrawing.fit` keeps it at its real size.
  - `titleDetail` adds `beakLower` (fill `#D8862A`) and `headContour` (stroke 1 pt, ink at 45 %).
  - Its mirrors are empty past half tuck.

## App status (Round 4, end)
- **Feel:** wired `hinge.closing(at:)` (both call sites, and fold-to-fly's disarm), `consumeEndStop()` → `.endStop`,
  `restIsBelowFloor(at:)` → the countdown holds on "Open a little wider" (shares the 4 s flat-hold budget), the
  milestone hit-stop = `FeelSoundBook.hitStop`, and `TitleTuck.fromHinge` now maps through
  `HingeTuckTuning.tuck(forAngle:open:)` with the open angle floored at `openMin`.
- **Milestones:** one rule. The App calls `FeedbackDirector.isPerfectMilestone(chain:)` for the callout, the hit-stop and
  VoiceOver (no extra "first Perfect" callout); AppTests asserts it equals `FlightScene.isChainMilestone` for 0…80.
- **Scene:** the lead meter draws `SceneStormMap.meterFill(gap:)` and its coral zone is `SceneStormMap.closeFill`;
  `sunCanvasPoint` moves the countdown / Ready stage to 28 % (or 62 %) height when the sun is within 160 pt (it also
  sits on a navy disc at 0.62, 4.5 : 1 over the sun's core); `gutterEnabled = false` on every demo (store) run; the
  splash word and "×N lost" sit at `onBirdPoint`; `BirdGlyph` is now `BirdArt.markPath` stroked at
  `markLineWidth` (cover, cards, About, pose card, meter knob, the touch glyph, badges); the title draws
  `beakLower` and `headContour`. The app icon keeps the dorsal gull (it is the mark's source) with R4's 60/40 px fixes.
- **Core:** the Daily shows `DailySeed.displayNumber(day:)` everywhere (HUD tag, banner, Home, cover, results, share
  line, share card); Flocks shows a scope line only for `GoalCatalog.scope(of:) == .total` goals.
- **Founder:** `UIRequiresFullScreen` ships in Release (project.yml, Duo R3 P2-15: drop it in Release as Brim does);
  `screen=icon` now also writes Documents/AppIcon-180/60/40.png (`SWOOP-T icon sizes …`): please pull them into the
  CI artifacts; duo-01 / duo-06 timing and `hinge_set 90` are duo.sh's.
## Feel → App (Round 5: P1-7 Home calibration, P1-8 low rests)
- **Home calibration:** on Home, and on Results before fold-to-fly arms, call **`hinge.homeCalibrate(at: now)`**
  every frame with the hinge (next to `hinge.tuck(at: now)`). It snaps "open" once the hinge has been still for 0.6 s
  at 125–172°. It never learns from a held fold: a still angle more than 8° under the previous rest (within 10 s) is
  ignored.
  - Below 132° on Home, show "Open it a little wider" while `hinge.restIsBelowFloor(at: now)` is true.
- **Persist the open angle:** set `hinge.onCalibrated = { open in settings.hingeOpenAngle = open }`. It fires after
  every snap that moves 0.5° or more. At launch, before the first frame, call
  `hinge.restoreOpenAngle(settings.hingeOpenAngle)`. NaN or a missing value is ignored, so default to `.nan` or 160.
- **Rests under 125° (P1-8):** when the countdown's nudge budget runs out, call `hinge.lowRestFallback(at: now)`:
  - `.snappedToFloor` (rest 119–125°): "open" is now 132°, and the run may start with tuck ≤ 0.36.
  - `.tooLow` (rest < 119°): keep holding "Open a little wider" and offer **"Fly with touch"**. Never start the run.
  - `.fine` or `.moving`: carry on as now.
  - **Guard:** never let `Go` happen while `hinge.startTuck(at: now) > 0.5`.

## Scene → App (Round 5)
- **Birds page (REVIEW-4 juror #8):** in `BirdSideView`, draw with `BirdArt.previewTransform(for:in:)` instead of
  `BirdDrawing.fit`. It fits every flap and tuck pose (no clipped Gull wing) at 2.2× the in-game size or less, centred
  at 58 % of the height.
  - When `BirdArt.isDark(bird)`, stroke the body and near wing at 1.5 pt in `BirdArt.previewKeyRim` (#DDE6FF).
  - Then add a 28 pt halo of the tile sky's horizon colour at `BirdArt.previewHaloAlpha` (0.18), and lift that
    tile's sky by 15 %.
- **Title bird:** tucked, it is now a 14 % gannet dart, and `titleDetail`'s band and mirrors are empty past tuck
  0.4. The body path carries two invisible specks at the span's ends, so its box stays at 92 %. With them,
  `BirdDrawing.fit` keeps returning identity at every tuck; no change is needed unless the fit is computed from the
  wings alone.
- **Storm:** it never draws within 120 pt of the visible top, so the HUD needs no plate for it.

## Core → App (Round 5, P1-9: goals the bests already meet)
- `PlayerBests` (Codable): best single-flight meters, Perfects, chain, lighthouses, Tailwinds, cloud touches, clean
  metres and speed, plus `lifetimeMeters` and `dailyPlayed`. `bests.merged(with: result)` folds a finished run in.
  ProgressStore can keep one (please add clean metres and cloud touches; a field left at 0 just isn't pre-completed).
- `GoalEvaluator.alreadyMet(goals:bests:) -> [Goal]` (also `isMet(_:bests:)`): tick these at once, with the results
  tick animation.
- `GoalEvaluator.cascadedRank(from:bests:)` gives the rank reached by completing every flock the bests meet. Cascade
  after a rank-up; the climb stops at a flock that needs more flying or a fresh Daily.
- **Ladder changes:** every flock now has a lifetime-distance goal (5 km … 3,600 km). Ranks 7, 10 and 13 have
  "Fly 1 more Daily Flight in total" (`dailyRunGoalIDs`), which bests never meet. Some goal ids changed, e.g. r1's
  chain → `r1-total`; stored progress for ids that are gone can be dropped.

## App status (Round 5, end)
- **Feel:** `hinge.homeCalibrate(at:)` runs every frame on Home and on Results until fold-to-fly arms;
  `onCalibrated` saves the angle to `SettingsStore.hingeOpenAngle` (never in demo runs: those settings are in
  memory) and `restoreOpenAngle` runs in GameController's init; Home shows "Open it a little wider." while
  `restIsBelowFloor`; when the nudge budget is spent the App asks `lowRestFallback`: `.tooLow` keeps holding and
  offers "Fly with touch"; the last countdown step holds while `startTuck(at:) > 0.5` (`AppRules.countdownGate`).
- **Core:** `ProgressData` now keeps best clean metres, cloud touches and speed and exposes `bests: PlayerBests`;
  results tick every goal `GoalEvaluator.isMet` says the bests meet, then cascade through each flock they meet (one
  banner, "+N ranks! You're a …"); stored progress for goal ids that are gone is dropped on load.
- **Scene:** the Birds preview uses `BirdArt.previewTransform`, `isDark` → `previewKeyRim` (1.5 pt) and a 28 pt halo of
  the sky's horizon colour at `previewHaloAlpha`, with that tile's sky lifted 15 %. `TitleBirdView` needs no change:
  its fit uses the body box, whose specks keep it at 92 %, so it stays identity at every tuck. Note: the App now
  converts `sunCanvasPoint` with `AppCanvas.screenPoint` (R4 wrongly read it as view points).
- **Still open, Scene (ROUND-5 P1-10 "attract bird crosses the wordmark"):** the App can't move or hide the attract
  bird. Please add `scene.homeTextRects: [CGRect]` (view points) or `attractCeiling: CGFloat` (canvas y): keep the
  Home attract bird and its spray out of those rects + 24 pt (or fade it there over 0.2 s). The App will pass
  `HomeLayout.textBlock`/`wordmark` the round it lands.- **R5b, Home framing (done, as asked):** set `scene.homeTextRects = [wordmark, caption]` (view points, y down)
  and/or `scene.attractCeiling` (canvas y, y up) while Home shows. In `.attract` mode only, the camera keeps the bird
  below the lowest edge minus 60 pt: your 24 pt margin plus 36 for the bird and its trail. It zooms out sooner to
  fit, and never sets the ceiling lower than 20 % of the visible height. Clear both when you leave Home.

## Feel → App (Round 6: D1 sharp half, D1.4 flat tip, Flight School cues)
- **Sharp half (UX S4 / F5), `Swoop/Input/SharpHalf.swift`:** `SharpHalf(physical: FeelPhysicalHalf (.a/.b),
  reference: FeelLandscape (.left/.right))`, which is Codable. Store it in SettingsData; it replaces the bare
  `sharpPhysical`.
  - **First run on a Duo** (no stored value): `SharpHalf.firstRun(in: FeelLandscape.from(windowScene.interfaceOrientation))`.
    The half on screen-right *now* is the sharp one, and that orientation is the reference from then on (ROUND-6's
    correction). Save it at once.
  - **Every layout:** `sharp.screenSide(in: currentLandscape)` gives `.left` or `.right`, so `mirrored = (that ==
    .right)` when Bird side is "Sharp side". A 180° turn flips it; re-lay out as UX §2.1 says. `FeelLandscape.from`
    returns nil in portrait (keep the last landscape value).
  - **Wing check answer:** `sharp = sharp.recording(sharpSide: .left/.right, in: currentLandscape)`.
  - **Log:** `sharp.logLine(in: o)` is the `SWOOP-T birdside … physical=… o=…` line.
- **Flat-open tip (F3):** call `hinge.resetFlatOpenings()` at each run's start (and Flight School start). Read
  `hinge.flatOpenings` (openings to ≥ 174°, re-armed under 166°). Show the tip on the 3rd.
- **Step 0 stillness (F1):** `hinge.isStill(at: now, window: 0.5)` (≤ 1.5° spread over 0.5 s).
- **Cues (F4):**
  - `feedback.cue(.schoolStep(n))` on each step's success (the climbing chime and praise tap; also the Wing check's
    "Got it"). The step 5 Perfect still plays its own sound from the event.
  - `.schoolRewind` on each rewind. `.schoolStorm` when step 7's storm rolls in.
  - `.goalNear` once at 300 m to the next lighthouse.
- **Lighthouse reached:** the `lighthouse` event now plays the bigger "reached" bell, swell and haptic, timed to a
  **60 ms hit-stop** (`FeelSoundBook.hitStop`). Please hold that hit-stop on the lighthouse frame.
- **Practice sea:** set `feedback.practiceAmbience = true` for Flight School's Sea steps (a calm wind, no rain, no
  thunder), and back to false when the real run's Ready ring starts.

## Core → App / Scene / Feel (Round 6: Flight School practice, fixed lighthouse names)
- **Practice session:** `FlightSession.practice(bird:)`. Contracts are unchanged: it reports `mode == .attract`, so
  ProgressStore and Game Center already ignore it, and it never finishes. Check `session.isPractice` (also
  `session.sea.isPractice`). There's no storm (gap 1,000,000), and no lighthouse, milestone or best events.
  - `timeScale` defaults to 0.8 and can be set any time, e.g. 0.5 in the air.
  - The bird waits on crest A until the eased tuck reaches 0.6 (`holdAtCrest(untilTuck:)`; 0 releases it).
  - `rewind(to: .crestA | .trough | .guided(n) | .rhythm)` and `nextGuidedSwell()`.
  - `practiceStormGap = 3000` shows the storm, held behind and never catching, for step 7.
- **Step signals:** read `session.practiceSignals` after each `step`. They are not `FlightEvent` cases, so no
  existing switch breaks: `.diveDone(heldFraction:)` at the trough, `.launched(tuck:)`, `.landed(quality)` and
  `.waveDone(index: 0...2)`.
- **Practice sea (Scene):** the layout is in `Tuning.practiceKnots`. Crest A is at x 0, the trough at 1500, crest B
  at 2300, the guided trough at 4300, and the rhythm troughs at 6300, 8300 and 10300. Round 6b: the rhythm waves are
  λ 2000 and 150 pt high, one clear launch-and-land per wave at the practice speed; draw the rhythm bar per 2000 pt
  wave. After that come even swells (amplitude 300, λ 4000). The guided landing ring belongs on 2300–4300, where an open glide lands at ~x 3150–3760.
- **Lighthouse names** are fixed by index: `Lighthouses.name(index:)` gives 0 Gull Point, 1 Saltlight, 2 Kestrel
  Head, 3 Old Harry… `name(index:seed:)` still compiles and ignores the seed. Route helpers:
  `Lighthouses.count(atOrBefore:)`, `count(atOrBeforeMeters:)` (`routeReached` migration from `bestMeters`),
  `nextIndex(afterMeters:)`, `meters(index:)`.

## Scene → App (Round 6: Flight School, the goal, the mirrored default)
- **Practice sea (SC1):** set `scene.practiceSea = true` for Flight School's Sea steps (3–7), false when the real
  Flight's session starts. The scene also turns the look on by itself whenever a snapshot reports no storm (Core's
  practice gap, ≥ 500,000 pt). A session starts in the look with no fade (`reset()` snaps it).
  - **Step 7:** call `scene.rollInStorm()` with its first line. The palette crossfades to the player's sky over 2 s, the
    storm slides in to 70 pt (no catch), one glow inside it names it at +1.2 s, and the rain comes last (+1.6 … 2.6 s).
    The meter and the goal chip fade in at +1.6 s (yours).
- **Guides (SC2):** `scene.guide = .foldPathAhead` (step 3, set while the bird waits on crest A), `.openMarkAhead`
  (step 4), `.landingAhead` (step 5), `.none` between steps. They are placed on the sea ahead of the bird on the next
  frame. If you know the exact spots, pass sea x instead: `.foldPath(from: crestA, to: trough)`, `.openMark(at:)`,
  `.landing(at:)`. A Perfect within 260 pt of the ring bursts it into 8 motes (the scene does that).
  - **Step 4's slow motion:** `scene.slowMoBloom = true` for the 0.5× span (a 6 % bloom on the bird page).
- **SC3 (Faster! capsule, rhythm bar):** not drawn by the scene. Anchor them at `onBirdPoint` (30 Hz, view points):
  + (0, −46) and + (0, +38).
- **Lighthouse reached (SC4):** automatic on the `lighthouse` event: the beam sweep, the lamp flare, the haze pulse,
  the gust toward the storm, and the motes. Keep Feel's 60 ms hit-stop on that frame. The tower now stands on the sea
  page at the pass (u = 0.76 w: screen x ≈ 228 mirrored), and the next tower is drawn on the far horizon from 1.5 km
  out (u = 0.90 w: screen x ≈ 95 mirrored), so the goal chip points at something visible. The tower is the icon's
  colours: #F4F1EA with two #D8574A bands.
  - `scene.lampCanvasPoint` (canvas, y up; nil when no tower shows) gives the lamp's centre. A 380 pt card at 0.40 h
    can sit right over it; if it does, use the 0.62 h position (as for the sun), so the beam is seen leaving the
    lamp.
- **Art helpers (SC7, SC8, AP1), CoreGraphics, y down; draw with `Path(cgPath)`:**
  - `RouteArt`: `coastPath(width:headlands:)` (land), `coastline(width:headlands:offset:)` (offset 0 = the cliff rim,
    4 = the foam line), `contours(width:headlands:)` (30 / 60 / 100), `lighthouseXs(count:spacing:startX:towardLowerX:)`
    (150 / 130 by index), `routePoints` / `routePoint(at:)` (the best pin) / `routePath(headlands:from:to:)`,
    `snapOffset(proposed:centres:band:)` (keeps every centre out of 447 … 503), `stormGlyph(size:)` with
    `stormRainTicks(size:)`, and `quayGlyph(size:)`.
  - `DuoDiagramArt.geometry(angle:box:)`: both panels and screens as quads (spine top, outer top, outer bottom, spine
    bottom), the spine rect, φ. Also `quadPath`, `mittenPath(outerTop:outerBottom:outward:)`, and the gauge:
    `gaugeAngle(hinge:)`, `gaugePoint`, `gaugeArc(center:radius:from:to:)` (100° = left end, 180° = right end), with
    `openBand`, `tuckBand` and `flatWarning`.
  - `BirdArt.youGlyph(facingLeft:in:)`: the "you" gull (meter knob, map pin, diagram, touch glyph). Face it the flight
    direction: `facingLeft = layout.mirrored`.
- **Storm (ROUND-6 settled point):** it is now one noise-rendered cloud texture, not lobes. `SceneStormMap` is
  unchanged, so the meter needs nothing new. It still stays ≥ 120 pt under the visible top, and in play it never
  reaches the fold band.

## App status (Round 6, end): Feel F1–F5, Core K1–K3, Scene SC1–SC2 wired
- **Feel:** `SharpHalf` is stored in `SettingsData.sharpHalf`. It is set to `firstRun(in:)` the first time a Duo
  reports its landscape orientation (never assumed landscapeRight), mapped through `screenSide(in:)` on every layout,
  and the Wing check records into it. `logLine(in:)` is logged on the first record, after each 180° turn and after
  each answer. The App also uses `resetFlatOpenings()`/`flatOpenings` (the tip on the 3rd), `isStill(at:window: 0.5)`,
  the cues `.schoolStep(dot)`, `.schoolRewind`, `.schoolStorm` and `.goalNear` (once per lighthouse at < 300 m), and
  `practiceAmbience` (on for the Sea steps, off in `endSchool`, before the real run's countdown).
- **Core:** the school's Sea steps fly `FlightSession.practice(bird:)`. `timeScale` is set from the school each frame;
  `practiceSignals` are authoritative for steps 3–6. A miss calls `rewind(to:)`: dive → crestA, soar → trough,
  rhythm → rhythm; step 5 calls `nextGuidedSwell()`. Step 7 sets `practiceStormGap = 3000`. RouteRules uses
  `Lighthouses.name(index:)`, `meters(index:)` and `count(atOrBeforeMeters:)`.
- **Scene (all of "Scene → App (Round 6)"):**
  - `practiceSea`, `guide` (exact sea x: `.foldPath(0→1500)`, `.openMark(1500)`, `.landing(3450)`), `slowMoBloom`
    (the 0.5× launch) and `rollInStorm()` at step 7. The meter and the goal chip fade in at +1.6 s.
  - The 60 ms hit-stop is held on the lighthouse frame. The reached card drops to 0.62 h when it would cover
    `lampCanvasPoint`.
  - The Route strip draws with `RouteArt`: coast, rim, foam, contours, route, storm glyph and quay. The diagram and
    gauge use `DuoDiagramArt`. `BirdArt.youGlyph` (the App's `YouGlyph` shape) is used for the meter knob, the route
    pins, the diagram and the rank-up chip.
  - SC3 is App-drawn (`SchoolBirdHUD`): the Faster! capsule at bird + (0, −46) and the rhythm bar at bird + (0, +38),
    one bar per λ 2000 wave from `Tuning.practiceRhythmWaveEnds`.
  - Not used yet: `RouteArt.snapOffset`. The Route scroll centres the next lighthouse on the far page.
## Core → Scene / App (Round 9: the guide gull, headline inputs)
- **Ghost paths:** `FlightSession.practiceGhostPath(step:)` (= `PracticeGhost.path(step:)`) returns `[GhostSample]`, one
  sample every 1/60 s of sim time. Each sample has `t`, `x`, `y` (sea space, the same wave as the player),
  `bodyAngle`, `tuck`, `skimming`, `folded` (for the fold-path fill) and the `signals` that happened there (launch,
  landing quality, wave done).
  - Steps: `.dive` (crest A to the trough, folded), `.soarAndLand` (trough, open, launch, Perfect in the ring),
    `.guidedLanding` (from the retry point past crest B) and `.rhythm` (the 3 waves).
  - The paths are pure and deterministic, flown with the practice sea's own physics at 1× time, so playing them at
    0.5× or 1.25× is up to Scene/App. Draw the ghost "one swell ahead" by offsetting x.
  - `PracticeGhost.sample(path, at: t)` interpolates; `PracticeGhost.duration(path)` gives the length.
- **Results headline:** `Lighthouses.next(afterMeters:) -> (index, name, metersFurther)`, with "further" already
  rounded up per UX §2.2 (100 m steps from 1 km, 10 m below). The passed count and name come from
  `RunResult.lighthouses` and `lastLighthouseName`, which use fixed names. `Lighthouses.roundedFurther(meters:)` is
  exposed too.

## Feel → App (Round 9: the guide gull, the overtake, the school beats)
- **Ghost demo:** `feedback.cue(.ghost(.dive | .soar | .land | .rhythm))` when the guide gull starts each
  demonstration. It's a breath-only "watch" whoosh at about half the level of the player's swish, with no haptic (a
  touch always means the player did it). `FeelGhostMove` matches Scene's move names.
- **Caught:** nothing to call. The `caught` event now plays the 1.2 s storm sweep, ONE thunder strike at 0.9 s
  (`FeelSoundBook.caughtStrike`, matching ART's bolt), then the calm pad. The haptic jolts once with the strike.
- **School beats** (UX-ROUND-9 §1.2):
  - `.schoolStep(dot)` on each success (unchanged);
  - `.schoolRewind` on each rewind (unchanged);
  - **new** `.schoolMorph` when the title bird drops into the sea (0.8 s);
  - **new** `.waveDone(1…3)` when each step-5 swell's gold bead appears;
  - `.schoolStorm` when the wall rolls in;
  - **new** `.stormPushedBack` on step 6's Perfect;
  - **new** `.lighthouseSighted` when Gull Point rises on the horizon.
- **Cut:** no Feel cue was ever tied to the Faster! bar or the rhythm bar, so there is nothing to remove. Don't add any.

## App → Scene (Round 9: the hooks the App calls; each is one line in `SceneAdapter` to point at your API)
- **Guide gull (SR1):** the App plays Core's `PracticeGhost` path for the step (0.8×, from the step's start, no x offset:
  the ghost flies the same wave just ahead of the waiting bird) and calls `SceneAdapter.setGuideGhost(scene, sample:,
  move:)` every frame (`GhostSample?` in sea space, `move` = "dive" | "soar" | "land" | "rhythm"; nil hides it). It is a
  no-op today: please expose e.g. `scene.guideGhost = (sample, move)` and say so; the App wires it the same round.
- **Ring rect (SR7):** the App places "Land here" ahead of the bird for now. Please publish `ringScreenRect` (view points)
  so the words sit beside the ring; also `ghostScreenPoint` for the 80 pt avoid rule.
- **Gull Point label (step 6):** UX wants the in-world name by the rising lighthouse; the App has no lamp point in
  practice (no tower there). Scene's in-world label, or a `practiceLighthouseScreenPoint`, either works.
- **Unchanged and still called:** `practiceSea`, `guide` (exact sea x), `slowMoBloom`, `rollInStorm()`.

## App status (Round 9)
- **Core:** `FlightSession.practiceGhostPath(step:)` / `PracticeGhost.sample(_:at:)` / `duration` are played by
  `GhostPlayback` (pure, tested). The Results headline uses `Lighthouses.next(afterMeters:)` (its rounded "further").
- **Feel:** `.ghost(move)` at each demonstration's start, `.schoolMorph` (Studio → sea), `.waveDone(1…3)`,
  `.schoolStorm`, `.stormPushedBack` (step 6's Perfect), `.lighthouseSighted` (step 6 done), plus `.schoolStep` /
  `.schoolRewind` as before.
## Scene → App (Round 9: answers to "App → Scene", plus the new hooks)
- **Guide gull (SR1):** `scene.guideGhost = SceneGhostPose(x:, y:, tuck:, bodyAngle:, move:, landed:)` every frame
  while you play Core's `PracticeGhost` path. Map each `GhostSample` one for one: `x`, `y`, `tuck`, `bodyAngle`.
  `move` is `SceneGhostMove(name: "dive" | "soar" | "land" | "rhythm")`. Set `landed: true` from the sample where the
  path's signals show its Perfect, and the scene fires the ghost Perfect once.
  - Set it to nil when the demo ends. The ghost then dissolves into 10 motes, and `onGhostFinished` fires once.
  - `SceneAdapter.setGuideGhost(scene, sample:, move:)` becomes that one line.
  - While it shows, the camera zooms to ≤ 0.78 and shifts the bird back by up to 0.22 w (`cameraBias`), so the ghost
    stays on screen.
  - **Without Core's path:** `scene.playGhost(.dive)` flies the scene's own stand-in on the sea ahead.
  - **Diagram:** `ghostTuck` gives the pose for the dashed diagram. `ghostScreenPoint` (view points) is for the 80 pt
    avoid rule.
- **Ring (SR3, SR7):** `ringScreenRect` (view points) covers the ellipse and its drop marker, so put "Land here"
  beside it. The ring respawns by itself on the next downslope ≥ 200 pt ahead after a miss (a Good or Splash near it,
  or flying past it). Keep passing `.landing(at:)` for the first one. While it is live, the camera looks 0.25 w ahead.
- **Water cues (SR2):**
  - `.foldPath(from:to:)` now draws the 16 pt gold fold zone. It paints solid behind a folded bird and greys out where
    the bird flies open; a done swell leaves a gold bead. Fold chevrons run down it, and the closing book sits at the
    crest.
  - `.openMark(at:)` draws the opening teal book with lift chevrons at the launch.
  - Step 5: `guide = .rhythmAhead(count: 3)`, or `.rhythm(swells:)` with the exact crest and trough x. Each swell
    gets its fold zone, fold book and open book.
  - `scene.foldPaint` reports the paint, if the App wants to match its success check to it.
- **Practice from step 0 (defect #5):** please set `scene.practiceSea = true` for **every** school step, the Studio
  steps 1–2 too (`SceneAdapter.setSchool` passes `step?.isSea` today, so the Studio shows the storm, the rain and the
  muddy sun).
  - In school the scene now never shows a caught wash, the storm or a dimmed sun until `rollInStorm()`.
  - Step 6's wall now rolls in to cover the bird page's outer 20 % (Duo x ≥ 760).
  - A Perfect after the roll-in pushes it back with a gust; nothing to call.
- **Step 6 extras:**
  - `scene.stormLinkTarget = <meter storm icon, view points>` for about 1 s: dots flow from the wall to the icon.
  - `scene.schoolLighthouse = true` when Gull Point should rise on the far horizon (1.2 s). Its lamp is
    `lampCanvasPoint` (canvas, y up), so put the in-world "Gull Point" label there. Set it false when school ends.
- **Home (defect #3):** `scene.homeMenuRects = [the Goals / Route / Birds row]` (view points), and the attract camera
  keeps the water 24 pt under its bottom (never lower than 6 % of the height). Clear it when you leave Home. If that
  sea is too thin for taste, the alternative is your plate behind the row.
- **Caught (§2):** the Scene part is automatic:
  - the front sweeps past the bird to 0.10 w from the ahead edge in 1.2 s;
  - the light changes (wash 0.45, sun −70 %, a warm horizon strip ahead);
  - one bolt at 0.9 s, which Feel's strike matches;
  - the bird settles wet with 3 rain rings, and the camera pushes in +4 %.
  - Your part is the HUD fade from 1.6 to 2.0 s and the label at bird + (0, −110).
- **Wing diagram (AR1):** `DuoDiagramArt.geometry(angle:box:exaggerated: true)` uses φd = min(1.6 · (180° − θ) / 2,
  60°), and `DuoDiagramArt.innerShade(angle:)` gives the 25 % · sin φd inner-face darkening.
- **Route L→R (AR5), pure helpers:**
  - the coast: `RouteArt.coastY(at:headlands:base:)`, `coastPath(width:headlands:base:)` and
    `coastline(width:headlands:base:offset:)` (base 150 / 118, a +34 pt point under each lighthouse);
  - `lighthouseXs(count:spacing:)` (150 / 130, left to right) and `focusOffset(index:spacing:viewWidth:)` (60 %);
  - `labelRows(_:)`: one baseline, and a colliding label drops 40 pt, never overlapping. This is the
    `routeLabelsNeverOverlap` core.
- **Speed is shown in the world:** in school the speed lines start at 600 pt/s, and the trail turns gold as the dive
  reaches speed. Nothing to call; the Faster! bar and the rhythm bar can go.

## Scene → Core (Round 9)
- Nothing blocking. `GhostSample` maps onto `SceneGhostPose` one for one, through the App. `folded` isn't needed: the
  scene paints the fold zone from the player's own tuck.

## Scene → App (Round 10: the recoil and the peaks)
- **CI freezes on the peak (P1-5):** `scene.onPeak = { peak in … }` fires once on each moment's strongest frame, so
  freeze there. `scene.momentPeak` is the same value, for that frame only (for polling).
  - `.perfect`: 0.42 s after the touchdown. The gold ring is at full size (it now holds 0.15 s before fading) and the
    burst is out. Put the App's PERFECT word on this frame too.
  - `.caught`: the storm front crossing over the bird, which flinches and is splashed while the wall lights up. This is
    about 0.5 s into the 1.2 s sweep.
  - `.recoil`: the school storm shoved fully back, 0.35 s after the Perfect.
- **Storm step (P0-1):** a Perfect after `rollInStorm()` now shoves the wall back 150 pt. A gust hits it at 0.15 s and
  it flinches with an inner glow, holds to 1.2 s, then eases back by 2.7 s. Nothing to call.
  - `scene.stormRecoil` (0 … 1) follows that shove, so jump the meter knob away from the storm with it and show
    "Perfect pushes it back" while it is above 0.
  - In real flights each Perfect also kicks the wall back 40 pt for about 1 s.

## App → Scene (Round 10, from testers 10–12; all yours to judge)
- **The fold book at the crest** sits on the gull's back at play zoom and reads as clutter (s05, s06, s10). The App now
  shows one diagram (beside the bird, with the target pose dashed), so the water's book glyphs could go or move off the
  bird.
- **Rhythm step:** the App now asks for `.foldPathAhead` only (one cue) and plays no guide gull there.
- **Home:** rain falls across the corner icons (s01), and a hard horizontal band crosses the sky (s17).
- **Step 6:** Gull Point stands on a pale translucent rectangle that reads as a rendering bug (s12, s13).
- **Wired from "Scene → App (Round 10)":** `stormRecoil` drives the school meter's knob (`AppRules.schoolMeterLead`);
  `onPeak` freezes the `freezeOn=perfect|caught|recoil` frames and, in school, shows the big "Perfect" / "Perfect
  pushes it back" on that frame.
## Scene → App (Round 11)
Scene's side of ROUND-11 is in `design/notes/scene-R11.md`. Most of it needs no call; the asks are marked **Ask**.
- **P0-1, the storm's edges:** nothing to call. Every storm layer (the sky shade, the sea wash, the caught warm strip,
  the cloud's backing) is now a soft span that ends only in a smoothstep ramp (≥ 300 pt for the tints) and runs off the
  canvas edge behind it, and the cloud texture is empty on all four borders. Test hooks: `scene.stormTintSpans`,
  `stormSkySpan`, `stormBackingSpan`, `stormCloudFadeEndU`.
- **P0-2, the meter through the catch:** `scene.stormMeterFill` (the same `SceneStormMap.meterFill(gap:)`) reads 0 as
  soon as the gap is ≤ 0, so a meter kept on screen through `.caught` at that fill has the storm end on the bird knob.
  **Ask:** keep the meter up through the caught phase and drive it from that fill; `onPeak(.caught)` stays the frame
  for the "The storm caught you" freeze.
- **P0-4, one fold indicator:** the gold "fold" book at the crest (the one standing on the waiting gull's back in
  s1-05/s1-06) and the teal "open" book are gone from the water. The fold band, its chevrons, the lift chevrons and the
  done bead stay. Your diagram is the only tuck indicator now; nothing to call.
- **P0-5, the ring:** while a landing ring is live ahead in school, the camera frames it ≥ 200 pt in from the sides and
  the visible bottom and 120 pt under the visible top (the bird rides higher in its band, then the zoom comes out if
  needed), so it is never under Skip, the step dots or the pause button. `scene.ringSafeRect()` is that rect (canvas,
  y up); `ringScreenRect` still reports the ring and its drop marker in view points. The ring's own drop marker is the
  s1-09 chevron + dotted line, drawn from the ring's first frame. **Ask:** put "Land here" beside `ringScreenRect` from
  the step's start (as for s1-09), not at a fixed spot.
- **P0-6, the storm step's first frame:** `rollInStorm()` now starts the wall on screen (front at u = 40, its dark deck
  behind it) and slides it to 0.20 w over 2 s, so the first frame after the call already shows the storm. Your
  every-frame `rollInStorm()` (idempotent) is the right shape: it survives the `scene.reset()` that a session rebuild
  does. Call it on or before the storm step's first frame (you do: from the rhythm step's success).
- **P0-7, why s1-13b had no push:** the storm was never on screen. R10 called `rollInStorm()` only on `out.advanced`
  into the storm step, so a school started at that step (replays, the CI frames) never rolled it in, and any
  `scene.reset()` after the call (`startSchoolSea()` → `buildSession()` runs right after it when the sea isn't up yet)
  clears it. No storm meant no recoil (the scene only recoils a rolled-in storm), so `onPeak(.recoil)` never fired and
  the knob never jumped. With the roll-in asked every frame it works live and in the demo: a Perfect shoves the
  wall from 0.20 w to ≈ 40 pt (still on screen), `stormRecoil` rises to 1 by 0.35 s and `.recoil` fires there
  (`schoolStormShowsFromTheFirstFrameAndRecoilsInView`).
- **P0-9, the slab:** Gull Point now stands on an irregular headland whose underwater part fades out; nothing to call.
- **P1-11, Home:** the attract trail is trimmed so it never rises above the bird's ceiling + 36 pt (24 pt under the
  text). **Ask:** pass every Home text rect in `homeTextRects` (the wordmark, the "TUCK & SOAR" rule and both tagline
  lines), since the ceiling is the lowest rect's bottom.
- **P1-14, "Perfect ×N" lettering (App-owned, `Swoop/UI/PlayHUD.swift` `PerfectCalloutText.label`).** The speckle is
  the two translucent (45 %) ink copies offset ±1.5 pt under a gradient fill: where they overlap and where they don't
  the outline alternates between 45 % and 70 % ink, which at 3× and after downscaling reads as a mottled texture.
  **Ask:** an opaque outline and a flat gold fill, composited once:
  ```swift
  static func label(_ text: String, compact: Bool) -> some View {
      let font = SwoopType.callout(compact)
      let ink = SwoopTheme.ink
      return ZStack {
          // A solid 2 pt outline: eight opaque copies (no partial-alpha overlaps, so no mottling).
          ForEach(0..<8, id: \.self) { i in
              let a = Double(i) * Double.pi / 4
              Text(text).font(font).foregroundStyle(ink)
                  .offset(x: CGFloat(2 * cos(a)), y: CGFloat(2 * sin(a)))
          }
          Text(text).font(font).foregroundStyle(Color(swoopHex: 0xFFD45E))   // the reward gold, flat
      }
      .compositingGroup()
      .shadow(color: ink.opacity(0.35), radius: 3, y: 1)
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .accessibilityHidden(true)
  }
  ```

## App status (Round 11): every "Scene → App (Round 11)" ask is wired
- **Storm roll-in (P0-6 / P0-7):** `SceneAdapter.rollInStorm(scene)` is asked EVERY frame while the school's storm is
  in or arriving (`FlightSchool.stormRollsIn`: the rhythm step's success, held 1.6 s for the roll, and the storm step
  itself, including a school started there). The push frame `school=storm:turn;freezeOn=recoil` now runs the step live,
  so `onPeak(.recoil)` freezes the real push; `stormRecoil` drives the knob and a "+" pops ahead of it.
- **The meter through the catch (P0-2):** the HUD meter no longer fades at the catch; it shows `hud.lead`, which is
  `AppRules.meterLead(gap:)` = `SceneStormMap.meterFill(gap:)` (the same value as `scene.stormMeterFill`), forced to 0
  once caught, so the storm end sits on the knob. "The storm caught you" (52 / 40 pt) comes 0.5 s in.
- **"Land here" (P0-5):** beside `ringScreenRect` from the step's start (just above its drop marker); a dotted gold
  pointer joins them if the words had to move. The storm step's "Land in the gold ring" uses the same anchor, and the
  storm step now asks for `.landingAhead` so the ring it names is there.
- **Home text (P1-11):** `homeTextRects` = the wordmark (with its rule) and the text block, which now runs to the
  bottom of BOTH tagline lines (the caption allowance grew 110 → 150 pt on the Duo, 70 → 100 on iPhone). The Studio
  passes its diagram + words rect too, so the attract gull behind steps 1–2 keeps under them (s1-03's wing on "Hold
  anywhere").
- **"Perfect ×N" lettering (P1-14):** Scene's drop-in replacement is in `PerfectCalloutText.label` as given.
- **The book on the gull's back (P0-4):** nothing to call; the App's side-on diagram is the one indicator.

## App → Scene (Round 11, nothing blocking)
- The step dots moved beside Skip, on the sea page's bottom corner (`SchoolLayout.dots`, `skip`). Your ≥ 200 pt inboard
  ring rule already keeps the ring off both; nothing to change.
- Held demo frames stall the scene's clock (`fxDt` = 0 once frozen), so the held storm frames now freeze at sea x 6300
  (was 5000) to let the 2 s roll-in play first. If you'd rather the roll-in ran on wall time, the App could go back.
