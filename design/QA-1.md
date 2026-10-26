# QA-1: Swoop bug hunt (26 Oct 2026, against `cbb2c8f`)

Scope: every Swift file in `Swoop/` end to end, plus the design docs and notes; each finding re-checked in the code.
"Suspect" = the code path is real but the impact needs a device or Instruments. Line numbers are for `cbb2c8f`.

**Counts: P0 0 · P1 6 · P2 15.** No crash, data wipe or App Review blocker was confirmed (see "Checked and OK").

**Daily rule, answered:** a player **cannot** get unlimited scored tries by killing the app. The try is spent and saved
at the drop (`GameController.swift:741` → `ProgressStore.markDailyAttempt`, which writes straight away). Killing the
app during the 3-2-1 countdown keeps the try, but by then the player has only seen 3 s of the sea. The real problem is
the opposite one, P1-2 below: killing the app loses the player's Daily score.

---

## P1

### P1-1 The 1.8 s "caught" window is still a live run, so a finished run can be paused, frozen or thrown away
- **Where:** `GameController.swift:303-306` (`isLiveRun` is true until `.finished`), `:450` (going inactive pauses any
  live run), `:554` (`pause()`), `PlayHUD.swift:85` (the pause button never hides).
- **What happens:**
  - The storm catches the bird, and for 1.8 s the run is in `.caught`. Tapping Pause in that window, then Home or
    Restart, goes through `startAttract()`/`start()`, and the result is never recorded. The best, lifetime metres,
    goals and Game Center all lose the run. (A scored Daily at least files its distance so far.)
  - Locking the phone right after being caught is the most natural moment to stop, and it does the same: the run
    pauses itself with `isUserPaused`. On unlock the player sees "Paused · The storm waits for you" over a dead bird.
    If iOS ends the suspended app, the run is gone.
- **Repro:** Fly → get caught → within 1.8 s tap Pause → Home. The Settings › Progress best and run count are
  unchanged. Or: get caught → press the side button at once → unlock → the pause card appears.
- **Fix:** make `isLiveRun` false once the phase is `.caught` and hide the pause button while `hud.caught`. In
  `setAppActive(false)` and at the top of `start`/`startAttract`, if the session is caught, step it headless to `.finished`
  (`while !s.isFinished { _ = s.step(dt: 1/60, tuck: 0) }`) and call `handleFinished()`.

### P1-2 Killing the app after the Daily drop loses the day's score, and Home still says "one try"
- **Where:** The attempt is saved at `.started` (`GameController.swift:741`). The distance is only filed by
  `closeOutDaily()` (`:723`), which runs on in-app navigation and never on backgrounding. Home keys its text off
  `daily[day]` only (`HomeView.swift:175, 191-195`), and so does `ClosedCard.dailyValue` (`PoseCards.swift:211`).
- **What happens:** If the app is killed or jettisoned after the drop:
  - no `DailyRecord` exists and the streak breaks;
  - Home still shows "Everyone's sea today · one try";
  - the next tap silently starts a practice run. The pause card offers Restart, and only the results say "· Practice".
  - The player feels robbed of a try they think they still have.
- **Repro:** Daily → fly 20 s → swipe up and kill → relaunch. Home says "one try". Fly it: the results are titled
  "Daily Flight #N · Practice" and the streak is 0.
- **Fix:**
  - In `setAppActive(false)`, when `scoredDailyDay != nil && flightStart != nil && !recordedFinish`, call
    `store.fileDailyPartial(...)`.
  - Make `ProgressRules.fileDailyPartial` keep the larger distance instead of returning early when a record exists.
    `record()` already overwrites with the finished run.
  - Have `dailyStatus` treat `dailyAttempted.contains(today)` as spent ("Tried · practice").

### P1-3 Calibration ratchets upward: after a wide-open glide, the player's normal rest reads as a half tuck
- **Where:** `HingeTuckSource.swift:193-204` with `calibrationHigh = 178` (`:17`) and `openMax = 172` (`:12`).
- **What happens:**
  - Any angle between 140° and 178° with a tuck under 0.08 teaches `openAngle` at τ 4 s. That includes ≥ 175°, which
    reads as tuck 0. So a few seconds of the wings opened wide ("open to soar") drags `openAngle` up to 170-172°.
  - Back at a 150° rest, the tuck is smoothstep(20/36) ≈ 0.6.
  - Neither path can bring it back. The fast path needs a tuck under 0.15 and the settle path a tuck under 0.4, so the
    bird dives "by itself" until the next countdown snap.
- **Repro (`InputTests` FakeHinge):** `snapCalibration()` at 150 → `run(6) { _ in 176 }` → `run(10) { _ in 150 }`. Then
  `openAngle` ≈ 170 and `lastTuck` ≈ 0.6.
- **Fix:**
  - Only learn upward from angles ≤ `openAngle + 6` (or cap `calibrationHigh` near 168).
  - Learn upward at τ ≥ 12 s.
  - Add the test above.

### P1-4 (suspect) The resume snap reads the raw angle mid-reopen
- **Where:** `GameController.swift:344` calls `hinge.snapCalibration()` on every frame of the 1.5 s Ready hold, and
  `HingeTuckSource.swift:170-172` snaps to `lastRawAngle`, which is unfiltered (±5°).
- **What happens:**
  - After a closing pause, the hold starts at 102° while the hand is still opening. A "gentle, slow" reopen to a 158°
    rest takes 2-3 s, so the snap lands on roughly 140-150°.
  - For several seconds a full squeeze to 125° then gives a tuck of about 0.5 instead of 1, until the fast path
    (τ 4 s) catches up.
  - The countdown snap has the same raw-noise issue: it can start up to 5° off.
- **Fix:**
  - Snap only while the stabiliser reports still (`stabiliser.speed(at:) < stillSpeed`), using the filtered `angle`.
  - On resume, take the maximum seen during the hold, or extend the hold until the hinge has been still for 0.3 s.

### P1-5 The Game Center button silently does nothing when the player is signed out
- **Where:** `GameCenterManager.swift:42-47` (the sign-in view controller is dropped on purpose) and `:51-52`
  (`showDashboard` returns when not authenticated). The button is at `HomeView.swift:46-48`.
- **Why it matters:**
  - A signed-out reviewer taps a 56 pt button and nothing happens, which risks a guideline 2.1 "unresponsive UI"
    rejection.
  - Players are never offered a way to sign in.
- **Repro:** Sign out of Game Center → Home → tap the controller icon.
- **Fix:** when `!GKLocalPlayer.local.isAuthenticated`, show a short toast ("Sign in to Game Center in Settings"),
  present the stored authentication view controller on this explicit tap, or hide the button while signed out.

### P1-6 (suspect) Frame-rate hazards at 120 Hz: per-frame `SKShapeNode` rebuilds and allocations
- **Where:**
  - Every frame rebuilds these paths: the sea fill, a concave ~220-vertex polygon with a `fillTexture` that SpriteKit
    re-triangulates (`SceneSea.swift:71-77`); the sea band (`:80-86`); two far swells (`SceneBackdrop.swift:130-133`);
    and the trail plus its glow ribbon (`SceneBirdView.swift:171-178`).
  - The wings rebuild on every tuck change (`:101-106`).
  - Each frame also allocates a new `[CGPoint]` (`SeaProfile.samples`, called from `FlightScene.swift:300`) and 2-4
    `UIColor`s (`FlightScene.swift:370, 377`; `SceneBirdView.swift:174, 178`).
- **Repro:** Time Profiler / Game Performance on a ProMotion device in a Tailwind at zoom 0.42 (most segments, trail,
  glow and sparkles all at once).
- **Fix, in this order:** (1) cache the `UIColor`s per sky and bird; (2) reuse one sample buffer (add
  `samples(into:)`); (3) drop `seaMaxSegments` to about 140; (4) if still over budget, draw the sea fill as a sprite
  with an `SKShader` or `SKWarpGeometryGrid` and keep the `SKShapeNode` for the stroke only.

---

## P2

1. **A hard speed drop when a Tailwind ends.** `FlightSession.swift:307, 320, 349-352`: `vmax` falls from 2990 to 2600
   in a single 1/240 s sub-step, a 13 % jolt you can feel at `tailwindEnded`. Fix: ease the cap back over about 0.5 s,
   or let drag bleed the extra speed.
2. **The stored hinge flag picks hinge input before any live sample.** `GameController.swift:317, 384`;
   `HingeTuckSource.swift:126`. Backed by `swoop.hasHinge`, a run starts on the hinge before this launch has seen a
   reading. If none arrives (the phone is still and iOS sends no first report), the tuck stays 0 and the touch layer is
   hidden until the hinge moves. Fix: pass the live `hinge.hasHinge` into `chooseInput` (`refreshInput` already
   upgrades touch → hinge on the first sample) and keep the stored flag for orientation only.
3. **(suspect) The closing latch and `isShut` only clear on a fresh hinge sample.** `reset()` keeps the latch
   (`HingeTuckSource.swift:148-159`); see also `GameController.swift:504-515`. If the Duo is reopened while the app is
   suspended and iOS sends no change after the 30 ms re-enable, the run stays behind "Open your wings", and Resume
   doesn't clear `.closing`. Fix: after the re-enable, if no sample has arrived within 0.5 s, show Resume on the
   ClosingCard.
4. **The lead meter animates all run and blocks a tuck.** `PlayHUD.swift:166`: the `repeatForever` pulse starts on
   appear and animates the whole flight, even when the storm isn't close. Also `PlayHUD.swift:87-90`: the meter is
   hit-testable, so a hold that starts on it doesn't tuck. Fix: run the pulse only while `stormClose`, and add
   `.allowsHitTesting(false)` to the meter.
5. **The Birds preview bird "breathes".** `BirdPreview.swift:87-89` → `BirdDrawing.fit` (`:26`): with `flipY` the
   transform is refit to the union box on every frame, so the bird zooms in and out as its wings flap and tuck. Fix: fit
   once to a fixed reference pose (tuck 0, flap 0).
6. **Cloud touches fire in clear sky.** Core fires `cloudTouched` at ≥ 900 pt above the *local* water
   (`Tuning.swift:106`). The drawn clouds sit 1000-1160 pt above the *mean* water with gaps of about 40 %
   (`SceneProps.swift:212-224`). So "Touch a cloud", the achievement and the puffs can fire with no cloud there, which
   breaks the truthful-frames rule. Fix: on `cloudTouched`, move the nearest cloud sprite to the bird, or share one
   cloud layout between Core and Scene.
7. **"Fly again" after UTC midnight replays yesterday's Daily as practice.** `GameController.swift:543-546`. Fix: use
   today's day number, scored if today's try is unspent.
8. **"Play with touch" from the pose card can't be undone.** `GameController.swift:204, 583-591`: it lasts for the
   whole app session, and there is no way back to the hinge short of quitting the app. Fix: clear `touchOverride` when
   the pose returns to `.play` in landscape, or show it in Settings.
9. **Flocks shows lifetime goals at their stored progress.** `FlocksView.swift:55-56`: after a rank-up, a `.totalMeters`
   goal such as "Fly 25 km in total" reads 0 % until the next run, even when lifetime metres already meet it. Fix:
   evaluate `.totalMeters` live from `data.lifetimeMeters`.
10. **Daily partials never reach the Game Center Daily board.** `GameCenterManager.swift:65-67` submits only finished
    runs. Two exploits exist:
    - Changing the device clock gives scored tries on other days' seas, which land on today's server-side occurrence.
      `isStale` uses the device clock too.
    - Reinstalling gives a fresh scored try, and the board keeps the best.

    Fix: submit the partial too, and send the day as the score `context`. Optionally, check the occurrence start date
    with `GKLeaderboard.loadLeaderboards`.
11. **A corrupt progress blob is silently replaced.** `ProgressStore.swift:301-308, 323-326`: if decoding fails, fresh
    data overwrites the stored JSON on the next save. Fix: copy the unreadable blob to `swoop.progress.corrupt` before
    the first write.
12. **Turning haptics off mid-session leaves the hardware awake.** `FeelHaptics.swift:133-142`: the two looping
    players and the engine keep running at zero intensity until the menus idle them. Fix: `stopPlayers()` and
    `engine.stop()` when the setting is turned off.
13. **The TestFlight Release check always warns.** `testflight.yml` greps for `swoopDemo`, but Release code legitimately
    contains `-swoopDemo` (`FeelFilters.swift:308`, `HingeReader.swift:63`, `FlightScene.swift:44`,
    `GameCenterManager.swift:37`). The warning always fires, so it can never catch a real leak. Fix: put those checks
    behind `#if DEBUG` (they only print logs), or grep for a string that exists only in DEBUG.
14. **(suspect) The Home attract loop runs the perfect pilot's full planner.** `FlightPilot.swift:229-262` with
    `replan 0.15`: up to 48 branches × 240 steps, about 11 k physics and sea queries every 0.15 s on the main thread,
    alongside the 120 Hz scene and the 60 Hz title `TimelineView` (`HomeView.swift:67`). This could cause periodic
    hitches on Home. Fix: use the `expert` profile for the attract loop, or cap `maxFlight` and the number of branches.
15. **Accessibility gaps.**
    - The GAME-DESIGN §3 "VoiceOver-adjustable wing control" is missing: hinge runs have no accessible input, and the
      touch layer exists only in touch mode (`PlayHUD.swift:18-37`). Fix: add an
      `accessibilityAdjustableAction`/hold element in every mode while VoiceOver is running.
    - Lightning fires a full-screen additive flash (`SceneStorm.swift:201-209`) every ~0.8 s when the storm is close.
      It stays under 3 Hz, but consider gating it on `UIAccessibility.isReduceMotionEnabled` and on a lower peak.

---

## Checked and OK (so nobody re-checks them)

- **Audio render thread:** a lock-free SPSC ring (`Synchronization.Atomic`) of POD commands; no allocations, locks or
  ARC on the render path; preallocated voices; NaN resets to silence (`FeelSynth.swift:374-508`). Rebuilds happen only
  when the engine is dead or stopped.
- **Audio session:** the interruption, route, configuration and media-reset observers run on the main queue
  (`assumeIsolated` is safe); `resume()` on `didBecomeActive` also covers a missing `.ended`; pause calls `silence()`.
- **Core Haptics:** the stopped and reset handlers rebuild the players; auto-shutdown only while idle;
  `UIImpactFeedbackGenerator` fallback on devices without Core Haptics.
- **Hinge pipeline:** re-enabled on every activation (`HingeReader.swift:43-53`); the predictor glides to the last
  reading when samples stop; `hingeUnavailable()` is a no-op and a live run never drops from hinge to touch; the closing
  latch has hysteresis; closing, user and pose pauses stack in one set with a single Ready hold.
- **Crashes:** no force unwraps; every `Int(Double)` is guarded as finite; every array index is bounded; every `/z` has
  z ≥ zoomMin·0.9 > 0; every loop has a guard (`SeaProfile.index` 100 k, blend 30 tries, 8 lighthouses per step,
  60 sub-steps).
- **Memory:** the scene holds its driver `weak`; the autopilot, results and nap Tasks capture `[weak self]`; the pools
  are fixed (240/120/110 sprites, 5 rings) and the trail is capped at 40 points; sea sets grow by about 1 per second.
- **Persistence:** tolerant per-field decoding, versioned; Reset keeps the Daily history and asks first; demo runs write
  nothing; goals are max-only with at most one rank-up per run, and nothing is double counted.
- **Release:** `DemoMode`, `DemoRunner` and every demo hook are `#if DEBUG`, and `AppTrace` compiles to nothing; the
  privacy manifest declares UserDefaults (CA92.1) and boot time (35F9.1); the Game Center access point is off.
- **Layout:**
  - iPhone SE (667×375): the Home menu shrinks to fit (Fly 56 pt, Daily 60.5 pt), the pause card (about 264 pt) fits
    its 349 pt slot, and the results scroll.
  - Pro Max and Dynamic Island: the 59-62 pt side insets reach the pause, back and settings buttons and refresh on
    rotation.
  - The mirrored layout flips the HUD, Home, results and scene consistently. The cover display shows `ClosedCard`.
