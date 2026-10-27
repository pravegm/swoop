# QA-FINAL: Scene, Input and Feedback (pre-App-Store bug hunt)

Date: 27 Oct 2026. Reviewer: senior QA (read-only on code). Base: `a4bc58d` (TestFlight 9/10, closing gate 55° / 40° / 65°).
Scope: `Swoop/Scene/`, `Swoop/Input/`, `Swoop/Feedback/`. App and UI call sites were read where the scope's behaviour
depends on them (touch gestures, orientation, the closing pause). No code was changed.

**Counts: P0 0 · P1 3 · P2 16.** "Unverified" means the reasoning comes from reading the code and needs a real-Duo
or iPhone check. Nothing here can be compiled or run on this host.

---

## P1: visible bugs

### P1-1. A touch hold cut off by a pause or the catch leaves the touch layer "stuck". The next press does nothing.
- **Where:** `Swoop/UI/PlayHUD.swift:17` (`@State touching` lives on the parent `PlayHUD`), `:27-28` (the
  `touchLayer` is removed while `paused || hud.caught`), `:172-190` (the `DragGesture`: `guard !touching` in
  `onChanged`, reset only in `onEnded`). The deck pad has the same pattern at `:236`, `:287-296`. Feel side:
  `TouchTuckSource.cancelled(at:)` (`Swoop/Input/TouchTuckSource.swift:89`) exists, but nothing calls it.
- **Why:** SwiftUI does not call `onEnded` when a gesture is cancelled. A gesture is cancelled when its view leaves
  the hierarchy or a system gesture takes the touch. `touching` is state on the parent view, so it outlives the
  removed layer and stays `true`. `setPause` → `releaseTouches()` (`GameController.swift:2125-2131`, `:866`) clears
  the tuck source but not the view flag.
- **Repro (iPhone, or a Duo in touch):**
  1. Hold to dive as the storm catches you. `hud.caught` removes the layer mid-hold. This is very common, because
     players are often diving at the catch.
  2. Or hold while pulling Control Center or Notification Center (play defers the edge gestures, `PlayHUD.swift:127`),
     or press the pause button with a second finger.
  3. Back in flight, the first press is swallowed by `guard !touching` and the wings don't tuck. Lifting resets the
     flag, so the second press works.
  4. With "Tuck by: Tapping" on, the lost press is a lost toggle. VoiceOver also keeps reading "Tucked".
- **Fix:** drive the state from `@GestureState`, which resets on cancel, instead of `@State`:
  ```swift
  @GestureState private var pressed = false
  DragGesture(minimumDistance: 0).updating($pressed) { _, s, _ in s = true }
  .onChange(of: pressed) { _, down in down ? controller.touchBegan() : controller.touchEnded() }
  ```
  Keep the ripple in `onChanged` without the guard. As a belt-and-braces measure, also add
  `.onDisappear { if touching { touching = false; controller.touchEnded() } }` to `touchLayer` and to the deck pad.

### P1-2. After a 180° turn the bird can stay on the blurred half (the orientation is read too early). Unverified.
- **Where:** `Swoop/UI/RootView.swift:58-60` and `:199-210`. `refreshWindowInsets()` reads
  `OrientationLock.interfaceSide()` (the window scene's `interfaceOrientation`) inside the
  `UIDevice.orientationDidChangeNotification` handler. The 350 ms follow-up re-reads only the insets.
  `GameController.setInterfaceSide` is at `GameController.swift:272-281`.
- **Why:** `SharpHalf` itself is correct (`Swoop/Input/SharpHalf.swift:66-80`: the mapping, recording and reference
  are all right, and a flat Duo that doesn't auto-rotate correctly keeps the same physical half). The problem is the
  wiring:
  - For scene-based apps, the interface rotation is applied by the system after the device-orientation notification
    is posted. At notification time `interfaceOrientation` is usually still the old value.
  - A landscape-left ↔ landscape-right turn doesn't change the canvas size, so `onChange(of: canvas)` doesn't fire.
  - Scene phase doesn't change either.
  - Nothing re-reads the orientation, so `effectiveMirrored` never flips and the bird stays on the same screen side.
    That is now the other physical half, the one iOS blurs.
  - CI can't catch this: demo `orientLandscape` sets `interfaceSide` directly (`GameController.swift:2211-2213`).
- **Repro (real Duo):** Bird side = Sharp side. Start a run, turn the Duo 180° (landscape to the other landscape)
  and check the `SWOOP-T birdside` readout. Expected: the bird hops halves and the run pauses. Suspected: no hop, or
  a hop only after some later refresh.
- **Fix:** re-read the orientation after the rotation settles. The cheapest way is to call
  `OrientationLock.interfaceSide().map(controller.setInterfaceSide)` inside the existing 350 ms task, plus a second
  read at about 0.8 s. The robust way is to observe `UIWindowScene.effectiveGeometry` (KVO) or the window scene
  delegate's `windowScene(_:didUpdate:interfaceOrientation:traitCollection:)`. Either way, `setInterfaceSide` is
  idempotent, so repeated reads are free.

### P1-3. Resuming from the closing pause can say "Go" mid-reopen with the wings still folded. The 65° reopen made this likely.
- **Where:** `Swoop/Input/FeelFilters.swift:309-312` (reopen above 65°). In `GameController.swift`:
  - `:19-22`: `readyHold` 1.5 s and `readyStillGrace` 1.0 s.
  - `:446-462`: "Go" waits only while the hinge moves or `startTuck > 0.5`, and at most until `until + 1.0 s`.
  - `:813-815`: the closing pause clears the instant the gate unlatches.
- **Why:** before R13 the run resumed at 102°. Now it resumes at 65°, so the hand still has 85-100° of reopening to
  do (to a 150-165° rest), but the cap is still 2.5 s.
  - At a gentle reopen of about 30°/s (the founder's own note in `HingeTuckSource.swift:331` gives about 20-30°/s),
    the hand is at roughly 120-140° when the grace runs out.
  - With open = 160°, full tuck is at 124° and 140° gives a tuck of about 0.6.
  - So the run restarts in a steep dive, often straight into a Splash. That is exactly the "never punish a gentle
    hinge" case.
- **Repro (real Duo):** fold under 55° until paused. Reopen slowly over 3-4 s to the rest pose. Watch the
  `SWOOP-T tuck` lines right after `SWOOP-T resumed`/"Go".
- **Fix (App, any one):**
  - (a) For a closing-pause resume, don't cap the wait while `startTuck > 0.5`. Keep the Ready ring up until the
    wings read mostly open, and offer the card's Resume button after about 4 s.
  - (b) Or raise `readyStillGrace` to about 3 s for `.closing` resumes only.
  - (c) Or keep `isClosingPaused` true (the card up) until `startTuck(at:) ≤ 0.5`, not merely past 65°.
  - Add a Duo CI step: close to 50°, reopen 50° → 150° over 3 s, and assert the first tuck after "Go" is < 0.5.

---

## P2: minor bugs, risks and polish

**P2-1. The haptic `stoppedHandler` can land late and orphan new looping players. Unverified race.**
`Swoop/Feedback/FeelHaptics.swift:357-365` hops to the main actor with `Task {}`. Meanwhile `resume()` (on
didBecomeActive) or `play()` can run `restart()` (`:401-429`) first, which sets `isRunning = true` and creates new
`rumblePlayer` and `skimPlayer`.
- When the stale Task then runs, it sets `isRunning = false` and nils the new players without stopping them.
- `heal()` then rebuilds a second pair, and the first pair keeps looping at its last intensity, which `quiet()` can no
  longer reach.
- The result is a stuck buzz and battery drain until the engine stops.

Fix: tag each engine start with a generation number and ignore a handler whose generation is stale. Also call
`stopPlayers()` (stop, then nil) at the top of `restart()`, never just nil.

**P2-2. A late "was suspended" interruption can switch off audio self-healing. Unverified.**
`FeelAudioEngine.swift:299-309` treats every `.began` as live and sets `interrupted = true` (`:154-158`).
- iOS posts `.began` with `AVAudioSessionInterruptionWasSuspendedKey`/`.appWasSuspended` when the app returns from
  suspension, and no `.ended` ever follows.
- If that notification arrives after `didBecomeActive` → `resume()` cleared the flag, `heal()` (`:123-127`) stays
  disabled for the rest of the session.

Fix: ignore `.began` when `wasSuspended` is true (or the reason is `.appWasSuspended`). Also clear `interrupted` in
`heal()` once `AVAudioSession.sharedInstance().isOtherAudioPlaying == false` and the app is active.

**P2-3. A failed engine restart is never retried from a menu, so menu sounds stay silent.**
Verified logic path; the trigger is unverified.
- `play()` (`FeelAudioEngine.swift:96-103`) calls `ensureRunning` only through `wake()` when napping. If that start
  fails (for example the first `start()` after a route change during a nap), `isNapping` is already false.
- Every later `play()` hits `guard engine.isRunning` and drops the sound without retrying.
- `heal()` is the only other retry, and the director skips it while idle (`FeedbackDirector.swift:211-217`), which
  covers all menus.

Fix: in `play()`, when `!engine.isRunning && !interrupted`, call `ensureRunning(reason: "sound")`, throttled to
about 2/s, before the guard.

**P2-4. A configuration change restarts the engine without renegotiating the output format. Unverified.**
`FeelAudioEngine.swift:211-218` → `ensureRunning` → `startEngine` tries a plain `start()` first. The mixer → output
reconnect only happens on the 2nd failure (`:247-251`), and in flight that is 1 s later via `heal`. So a sample-rate
change, such as Bluetooth headphones at 44.1 kHz or unplugging wired ones, can cost about 1 s of silence, or more in
menus (see P2-3).

Fix: in the configuration-change observer, first run
`engine.disconnectNodeOutput(engine.mainMixerNode); engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)`,
then call `ensureRunning`.

**P2-5. `rebuild()` swaps engines without stopping the old one.**
`FeelAudioEngine.swift:282-295` replaces `engine` without `engine.stop()`. It is called after a media-services reset,
where the old engine is dead anyway, and after 4 failed starts. Add `engine.stop()` before the swap for hygiene. The
render block retains the synth, so there is no use-after-free.

**P2-6. The 5 ms IO buffer costs battery.**
`FeelAudioEngine.swift:181`: `setPreferredIOBufferDuration(0.005)` means about 200 render wake-ups a second for the
whole session, menus included until the nap. The synth's per-sample cost is small (40-voice scan, 3 filter retunes
every 32 samples, tanh), so the wake-up rate dominates. 10 ms halves the wake-ups at an inaudible latency cost for
wind and chimes. The haptic and hit-stop sync comes from the frame loop, not the audio buffer.

**P2-7. Beds keep being queued while the engine isn't pulling audio.**
`setBed` (`FeelAudioEngine.swift:107-111`) sends at 60 Hz even when the engine is paused (sound off, `enabled =
false`) or stopped (an interruption). The 512-slot ring fills in about 8.5 s and then every send is dropped.
- It's harmless (the drain catches up at 128 per callback and the latest bed wins), but a one-shot sent right after
  a restart can be dropped while the ring is still full.

Fix: only send `.bed` when `engine.isRunning`. `lastBed` is already re-sent on wake and rebuild.

**P2-8. No explicit audio pause on background.**
The engine keeps rendering through `.inactive` (the bed fades out via `silence()`) and relies on suspension to stop
it, since there is no `UIBackgroundModes audio`, which is correct for review. For tidiness and battery, pause the
engine on `didEnterBackground` (`engine.pause()`, keep `isStarted`) and let `resume()` restart it.

**P2-9. Product note: sound plays with the ring switch on silent by default.**
`.playback` + `.mixWithOthers` by default (`FeelAudioEngine.swift:172-176`) means sound plays with the Ring/Silent
switch on silent. That is the founder's rule, and it is not a rejection reason, but Apple's HIG expects games to
honour the switch. Consider defaulting "Respect silent switch" on for non-Duo iPhones, or mention it in the What's New
or Settings footnote.

**P2-10. Synchronous haptic engine starts on the main thread mid-flight.**
`FeelHaptics.play()` (`:526-532`) calls `resume()` → `restart()` → `engine.start()` synchronously, up to every 0.5 s.
`heal()` does the same every 1 s while the engine is down. `CHHapticEngine.start()` can block for tens of
milliseconds, which shows as a dropped frame or two at 120 Hz right on a Perfect.

Fix: use `engine.start(completionHandler:)` and build the players in the completion handler on the main actor. Also
add backoff to `heal` when creating the looping players keeps failing (today it rebuilds the Perfect player every
second).

**P2-11. The storm cloud is generated on the main thread (hitch at the first scene and at each new sky).**
- `SceneStorm.init` (`SceneStorm.swift:361-371`) → `SceneTextures.stormGlow(i)` → `stormCloudField` →
  `SceneStormCloud.makeField()` (`SceneStormCloud.swift:74-116`).
- That is 520 × 288 px, with roughly 15 value-noise lookups per pixel, run synchronously inside `FlightScene.init`.
- Each new sky adds another 150k-pixel `pixels()` pass in `applyCosmetics` → `storm.apply` (`SceneTextures.swift:349-362`).
- Expect tens of milliseconds in Release and far more in Debug (the CI builds). It isn't a watchdog risk, but it is a
  visible hitch at launch and when the sky changes between runs.

Fix: build the field and the per-sky sets on a background `Task.detached` (they are pure functions), show the storm
once they are ready (it starts far off anyway), and pre-warm the active sky at launch.

**P2-12. The Flight School crossfade caches textures that are never evicted.**
`FlightScene.swift:1552-1566` keys textures `practice-<sky>-<step>`, up to 12 steps per sky, and
`SceneTextures.cache` (`SceneTextures.swift:76`) never evicts.
- Each step makes a 32 × 512 sky (64 KB) plus a sea gradient. Across all skies that is a few MB that is never freed,
  plus re-tinting the bird twelve times in 2 s (`birdView.apply` clears its wing cache each time).

Fix: don't cache the blend steps (use a separate uncached `make`), or keep only the latest step's textures.

**P2-13. The trail rebuilds 6-8 shape-node paths every frame (CPU at 120 Hz).**
`SceneBirdView.swift:376-405`: five core layers plus the glow (and 2 strands in a Tailwind) get new `CGPath`s every
frame, each re-tessellated by `SKShapeNode`. This is the largest per-frame CPU cost found in the scene (bounded at 49
points, so not a leak).

If Low Power or thermal throttling shows frame drops, reduce `trailLayers` under `effectsQuality < 0.8`. Or switch to
the already-defined `SceneTextures.ribbon` sprite chain (the doc comment at `SceneTextures.swift:204` describes this).

**P2-14. A thumb hand-off releases the tuck. Unverified.**
`PlayHUD.swift:172-190`: `DragGesture` follows a single touch. Pressing with the left thumb before lifting the right
ends the gesture on the right thumb's lift, so the wings open while a thumb is still down, and the left thumb starts
no new gesture.

Fix: a small UIKit touch view (`UIViewRepresentable`, `isMultipleTouchEnabled`) that counts active touches and calls
`touchBegan` on 0 → 1 and `touchEnded` on 1 → 0, with `touchesCancelled` routed to `touch.cancelled(at:)`. This also
fixes P1-1 at the root.

**P2-15. After the background, the hinge is "still" at once and may snap to a stale angle. Unverified.**
`HingeTuckSource.reset()` (`HingeTuckSource.swift:309-318`) clears the stabiliser's history. `isStill` is
`spread ≤ 1.5°` and is trivially true with no samples (`FeelFilters.swift:145-159`). So the resume hold's
`snapCalibration` can snap "open" to the predictor's pre-background reading.
- Today `HingeReader`'s re-enable (`HingeReader.swift:43-53`) normally delivers a fresh report within about 30 ms,
  which covers this.
- If iOS sends nothing (the Squish trap), a player who changed pose while away starts with a wrong "open" until
  calibration catches up (τ 4-12 s).

Fix: in `reset()`, re-seed the stabiliser with the last raw report (as already done for the predictor), and make
`isStill` require at least one report newer than the reset, or 0.3 s of frames, before a snap.

**P2-16. Doc and comment leftovers from the old gate.**
- `design/ARCHITECTURE.md:129` still says "`isClosing` … < 95° (pause), hysteresis back above 102°". It should say
  55° (0.2 s dwell), instant under 40°, reopen above 65°.
- `Swoop/Input/HingeTuckSource.swift:331` comment: "102° → 158°" should read "65° → 158°".
- `SwoopTests/InputTests.swift:365` comment: "never into the 90° closing zone" should read "55°".

No leftover 90/95/98/102/75 thresholds are used as logic anywhere in `Swoop/` (grepped). The only constants that
remain are `HingePredictor.snapDegrees = 90` (a jump-snap size, unrelated) and the shut detector at 10°/15°
(`GameController.swift:42-43`, consistent: under the 40° instant close).

**P2-17. On the very first Duo launch, the sharp half isn't recorded on the first hinge sample.**
`GameController.recordSharpHalfIfNeeded()` (`:285-289`) runs only from `setInterfaceSide`. On the first-ever launch,
`hingeSeen` is false at `onAppear`, and the first hinge sample (`:737-741`) doesn't record. If the next orientation
refresh is a 180° turn, the half is recorded in the new orientation. The bird then stays screen-right, on the other
physical half, which contradicts the "screen-right in the orientation the app first runs in" rule.

Fix: call `recordSharpHalfIfNeeded()` inside the `if !hingeSeen { … }` block of `hingeSample`, after reading
`OrientationLock.interfaceSide()`.

**P2-18. Verification item: iOS may hand over to the cover display above 55°.**
`ci/duo.sh:127-129` already notes the simulator "may hand over to the cover by ~60°". `status` reads `.closed` at
about 85° on hardware. If the real Duo moves the scene to the outer display above 55°, the new deep-fold freedom
(DEEP-FOLD at 75°) isn't real on device: the pose path (`setPose(.closed)`) pauses instead, with the 2.5 s cover hold.
Check on the founder's Duo: hold 75°, 65° and 58° for 2 s each mid-run, and confirm the inner display stays up and
the run keeps flying.

---

## Checked and found clean

**Scene (SpriteKit)**
- **Crashes:**
  - No force unwraps, `try!` or `as!` in Scene, Input or Feedback.
  - The one `fatalError` is the unused `init(coder:)`.
  - Every array index was checked: sea lace and twinkles, crests, trail ribbons, rings, storm glows, cloud specs and
    caught ripples are all bounds-guarded.
  - Every `Int(...)` conversion was traced. All take finite inputs: Core clamps tuck and dt
    (`FlightSession.swift:256-258`), and the bird pose and gold index are clamped.
- **NaN and inf:**
  - Zoom is clamped (`SceneCamera.swift:158`, `max(z, 0.01)` everywhere).
  - The camera's divisions are guarded (`visibleHeight ≥ 1`, `max(zoom, 0.0001)`).
  - The synth zeroes any non-finite sample and resets its filters (`FeelSynth.swift:478-481`).
- **Long flights and precision:**
  - World coordinates are rebased (`originX`, 2048-pt steps once more than 4096 pt from the bird,
    `FlightScene.swift:791-798`).
  - Particles, rings, bloom, trail and ghost are shifted on a rebase. Sea, clouds, buoy, guides and bird are
    re-derived from `originX` every frame, and the sea rebuilds on an origin change.
  - All accumulators are Double (`animTime`, `cloudScroll`, `beamPhase`). The backdrop scroll uses a positive modulo.
- **Node and memory growth:** every node is created once at init: particle pools of 240 / 120 / 110, 6 rings, 72 rain
  drops, 4 sheets, 10 speed lines, 48 link dots, 8 clouds, 16 crests and fixed guide sprites. There is no runtime
  `addChild` or `removeFromParent`, no `SKAction`, no `SKEmitterNode`, no timers and no `@escaping` closures in
  Scene, so no retain cycles. The wing-pose cache is capped at 800 entries. The trail is capped at 48 points.
- **Textures:**
  - Every texture is generated once and cached, at an explicit scale of 1-2× (never the screen scale). The largest
    are the 720 × 224 px headland and the 520 × 288 storm field, so there is no 3× blow-up.
  - Premultiplied bitmaps check their sizes before allocating (`SceneTextures.swift:430`).
  - No texture work happens per frame. The sea rebuilds only when its range, zoom or origin changes, or the storm's
    chop moves (about 1/s in flight).
- **Fold:** the crease and the gutter shade hide without a fold. The fine detail (glints, speed lines) is off for the
  first 2 s of a run and inside the App's blur guard.

**Input**
- **The closing gate:** `FeelClosingGate` dwell, instant close and hysteresis are consistent with the docs, the tests
  (`InputTests.swift:300-302`), the App (`checkClosing`, `GameController.swift:805-816`, run per frame and per sample)
  and the school wording (`FlightSchool.swift:695`, warns under 65°).
- **Judging the gate:** frames judge the smoothed angle, and with no frames the reports do, so reopening works while
  paused. `closing(at:)` lets the dwell mature with no reports (a still hinge).
- **The predictor and filters:** a time that goes backwards is clamped (`HingeTuckSource.swift:245`). The One-Euro
  filter, `HoldStabiliser` and `HingePredictor` all guard dt and non-finite input. The tuck rise limit is in place.
  `restoreOpenAngle`, `snap` and calibration clamp to 132-172° and ignore NaN.
- **No hinge:** a nil hinge is ignored after first sight, and the hinge code is behind `#available(iOS 27.1, *)`.
- **Touch:** `TouchTuckSource` ramps are continuous on reversal, and a tap toggle can't stick: switching modes
  releases it and `releaseTouches()` runs on every pause.
- **Sharp half:** the `SharpHalf` mapping and recording are correct for both landscape orientations. Both sides use
  the interface orientation (never the device orientation), so the sides agree.

**Feedback**
- **The synth's real-time path:** a single-producer, single-consumer atomic ring holds POD commands. Nothing on the
  render thread allocates, takes a lock or uses ARC. The voice and partial banks are preallocated, the output can't
  clip (limiter and tanh), and a full queue drops commands instead of blocking.
- **The audio session:** the category switches correctly between `.playback` + `.mixWithOthers` and `.ambient` (the
  silent switch), live. The engine restarts on interruption end, route changes, configuration changes and
  media-services resets. Every error is logged and the game goes silent rather than crashing. The engine naps after
  6 s idle. There is no `UIBackgroundModes audio` (correct for review).
- **Haptics:**
  - A device without Core Haptics gets the `UIImpactFeedbackGenerator` fallback.
  - `playsHapticsOnly` is set.
  - The reset handler rebuilds, and the looping players stop while idle with auto-shutdown on.
  - Turning haptics off stops the hardware at once.
  - Pattern curves are capped at 16 points and intensities are clamped.
  - `heal()` and `resume()` are skipped in the background.
- **Rate limits:** one-shot cues are throttled (launch, Good, cloud, thunder, closing, results tick, end stop). The
  bed is sent at most at 60 Hz and haptics at 30 Hz.
