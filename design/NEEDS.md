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