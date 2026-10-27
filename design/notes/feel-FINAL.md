# Feel FINAL: the last fix pass before App Store submission (27 Oct 2026)

The founder's Feel list in `design/qa/FINAL-FIXES.md` (items 1–7), with the evidence from `QA-FINAL-scene-feel.md`.
The closing gate (55° close, 40° instant, 65° reopen, `FeelClosingGate`) is unchanged. "Respect silent switch" still
defaults to off. Nothing is committed yet, and nothing here has been compiled. CI is the compiler.

## Done

1. **Haptics: stale "stopped" signals (P2-1).** `FeelEngineStarts` is a new pure struct in `FeelHaptics.swift` that
   tags every engine start.
   - The `stoppedHandler` stamps the stop where it fires (`CACurrentMediaTime()`, before the hop to the main actor).
     A stop from before the latest start began is stale and ignored, so the new players stay. A current stop stops
     the players (never just drops them), sets `isRunning = false` and cancels any start still on its way.
   - `restart()` always calls `stopPlayers()` first, so no player is ever orphaned looping at its last intensity.
     The reset handler does the same.
   - Tests: `aStaleHapticStopNeverOrphansTheNewPlayers` and `anOffMainHapticStartLandsOnlyIfNothingSupersededIt`.
2. **Audio self-repair (P2-2, P2-3, P2-4, P2-7, P2-8).**
   - **Late "app was suspended" interruption:** a `.began` with reason `appWasSuspended` (or the older
     `WasSuspended` key) is ignored (`FeelAudioRules.isLiveInterruption`). As a belt-and-braces measure, `heal()`
     (flight only) clears an interruption that has had no `.ended` for 3 s, but only when the app is active and no
     other audio is playing. An `.ended` that arrives in the background no longer restarts the engine there.
   - **Menu sounds retry:** `play()` retries a stopped engine (not during an interruption), at most twice a second.
   - **Configuration change (headphones):** the mixer → output connection is renegotiated (`reconnectOutput()`,
     stopped engine only), then the engine restarts.
   - **Background:** `FeedbackDirector` now observes `didEnterBackgroundNotification` itself and calls
     `audio.enterBackground()`. That sends `stopAll` and pauses the engine, and nothing restarts it in the
     background (`ensureRunning`, `startEngine`, `heal` and `play` all check). The existing `didBecomeActive` →
     `resume()` starts it again. **No App change is needed.**
   - **Sound settings while paused:** `setBed` sends to the synth only while the engine runs. Every successful start
     applies the latest bed (`applyBed()`, which carries the master), so the 512-slot ring no longer fills while
     paused.
   - Tests: `aLateWasSuspendedInterruptionIsIgnored` and `audioUsesATenMillisecondBufferAndRestsInTheBackground`.
3. **IO buffer 5 ms → 10 ms** (`FeelAudioEngine.ioBufferDuration`, P2-6). Latency is fine for the tuck rumble:
   - the bed glides with a 60 ms time constant, and it is sent at 60 Hz (16.7 ms);
   - the extra ~5 ms is far below both;
   - the haptics and the hit-stop are timed by the frame loop, not by the audio buffer.
4. **Haptic engine start off the main thread mid-flight (P2-10).** `heal()` and a cue that finds the engine stopped
   in flight (`!idle`) use `start(completionHandler:)`. The players are built on the main actor when it completes,
   and only if no newer start, stop or switch-off superseded it (the generation check).
   - A second recovery waits for a pending start, for up to 2 s.
   - Menus, `resume()` and leaving idle still start synchronously, so the cue that asked for the start (a menu tap,
     the first countdown tick) still plays. Mid-flight, that one cue is skipped instead of blocking a frame.
   - Not done: QA's extra suggestion of a backoff when building the looping players keeps failing. It is not on the
     founder's list.
5. **Stale hinge angle after the background (P2-15).** `HingeTuckSource.reset(at:)` (the App's `hinge.reset()`
   compiles unchanged) marks a last reading older than 1 s as stale (`awaitingFreshReport`).
   - Until a fresh report arrives, `isStill` is false, so no ready snap, Home snap, low-rest snap or "Open a little
     wider" happens. The App's resume "Go" waits as it does for a moving hinge, within its own cap.
   - The fresh report reseeds the predictor outright, with no glide from the stale angle.
   - A reading from the last second (the launch's first sample, a brief inactive blip) is kept as it is, so launch
     and CI behave as before.
   - Test: `afterTheBackgroundTheReadySnapWaitsForAFreshReport`.
7. **Stale gate notes.** `HingeTuckSource.swift` now says "65° → 158° over 3–4 s" (it said 102°).
   `InputTests.swift` now says "never near the 55° closing zone" (it said 90°).

## Not done: needs an App call

6. **First Duo launch: record the sharp half from the first hinge sample (P2-17).** The sharp half lives in
   `SettingsStore` and is recorded by the private `GameController.recordSharpHalfIfNeeded()`, so Feel can't do it
   from Input. The exact call is below. In `GameController.hingeSample(angle:time:)`, inside `if !hingeSeen { … }`,
   add this after `OrientationLock.hingeArrived()`:
   ```swift
   // Feel FINAL #6: the first-ever hinge sample records the sharp half (screen-right in this orientation).
   if let o = OrientationLock.interfaceSide() { setInterfaceSide(o) } else { recordSharpHalfIfNeeded() }
   ```
   `setInterfaceSide` records the half (`hasHinge` is now true) and refreshes the layout if the bird changes sides.

## Left for whoever owns it
- `design/ARCHITECTURE.md:129` still says "`isClosing` … < 95° (pause), hysteresis back above 102°" (QA P2-16). It
  should say: under 55° for 0.2 s, or under 40° at once; reopens above 65°. That file is outside Feel's folders.

## Files
- Feedback: `FeelAudioEngine.swift` (`FeelAudioRules`, `enterBackground`, `interruptionEnded`, `hardwareChanged`,
  `reconnectOutput`, `applyBed`, `ioBufferDuration`), `FeelHaptics.swift` (`FeelEngineStarts`, `engineStopped`,
  `engineReset`, `engineStarted`, `restart(offMain:)`, `recover(offMain:)`) and `FeedbackDirector.swift` (the
  background observer).
- Input: `HingeTuckSource.swift` (`reset(at:)`, `awaitingFreshReport`, `HingeTuckTuning.staleReportAge`).
- Tests: `FeedbackTests.swift` has 4 new tests and `InputTests.swift` has 1 new test plus the comment fix.

## Check on the Duo
- Pull Control Center mid-flight, then lock and unlock. The rumble comes back with no stuck buzz, and haptics
  switched off stay off.
- Plug in or unplug headphones (or connect a Bluetooth headset) on Home, then tap a menu item. The tap sounds.
- Background the app with the Duo at 160°, set it down at 140°, then return. The Ready ring snaps to 140°.
