# QA-2: Round 2 audit (26 Oct 2026, `42306c4..61f0997`)

Scope: every Swift change since QA-1 (`git diff 42306c4..HEAD -- Swoop SwoopTests`, 49 files), read against
`ROUND-2.md`, `NEEDS.md` and the `*-R2` notes, plus a re-check of every QA-1 item marked fixed. "Suspect" = the code
path is real, but the impact needs a device or Instruments. Line numbers are for `61f0997`.

**Counts: P0 0 · P1 0 · P2 9.**
- All six QA-1 P1s are fixed and verified in the code.
- 13 of the 15 QA-1 P2s are fixed. P2-13 is partly fixed (one string remains); P2-10 is fixed except the clock
  exploit, which is still open.

---

## The focus areas, answered

**Caught window and headless finish (QA-1 P1-1): correct; no double record, double submit or double count.**
- `isLiveRun` is false in `.caught` (`GameController.swift:376-381`), and the pause button hides
  (`PlayHUD.swift:105`).
- `finishCaughtRunHeadless()` (`:891-901`) runs from `setAppActive(false)`, `start` and `startAttract`. It steps the run
  to `.finished` (108 steps, capped at 600) and calls `handleFinished()`.
- The `recordedFinish` guard records exactly once:
  - a natural finish → background does nothing (the phase is already `.finished`);
  - background → resume emits no `.finished` event;
  - `.inactive` then `.background` hits the guard the second time.

  So `store.record` and `GameCenterManager.report` each run once. On `start`/`startAttract` the new results task is
  cancelled at once.
- `fileDailyProgress()` runs after it and stops at `!recordedFinish`, so a caught Daily is never also filed as a
  partial.

**Daily background filing (QA-1 P1-2): no inflation, and a practice run is never filed as scored.**
- `fileDailyProgress()` (`:878-887`) needs `scoredDailyDay`. That is set only for `.daily(_, scored: true)` and cleared
  by `handleFinished` and `closeOutDaily`. Practice runs, including "Fly again" via `playDaily()`, never set it.
- Each background files the *current* distance. `fileDailyPartial` (`ProgressStore.swift:335-345`) keeps the larger
  one and never replaces a finished record. The finish then overwrites the partial with a distance that can only be
  larger.
- Game Center gets each partial with `context = day`; the board keeps the best and stale days are dropped. Home and
  the cover card now say "Tried".

**Hit-stop: it can't stall the session, and it doesn't freeze audio.**
- `hitStopUntil` is a 35 ms wall-clock deadline (`:918`), checked after the pause and Ready returns (`:453-459`).
- A pause or a freeze inside those 35 ms simply outlives it. It clears on the first later frame, resets in
  `buildSession`, and is never set in the Home loop.
- `feedback.handle([], playing: true)` keeps the bed and haptics flowing, and the scene's FX clock runs on wall time
  for ≤ 0.1 s (`FlightScene.swift:256-262`).

**Rank migration (maxRank 15 → 14): not clamped.** See P2-1.

**Sea caching: no stale geometry.**
- `invalidate()` runs on `reset()` and on `applyLayout()` (`FlightScene.swift:196, 604`).
- The cache is in sea space under the world transform, so mirroring needs no rebuild.
- The rebuild *rate* is higher than claimed (P2-2).

**Per-frame cost: mostly fixed.**
- Done: colours cached; wing poses cached (48×40, cleared per bird); the trail is sprites; far swells built once; the
  storm anvil scaled.
- Remaining: P2-2; a `[CGPoint]` allocated per rebuild, because the scene ignores Core's new `samples(into:)`
  (`FlightScene.swift:627`); and P2-6.

---

## P2

1. **Stored R1 progress isn't migrated (rank clamp and reused goal ids).**
   - **Where:** `ProgressStore.swift:127` decodes `rank` with only `max(…, 0)`, and nothing clamps it to
     `GoalCatalog.maxRank` (14), though NEEDS.md asks for it. `FlocksView.swift:27` then shows "RANK 16 OF 15", and the
     ladder highlights no row.
   - **Worse:** `goalProgress` stores 0…1 ratios keyed by goal id, and R2 reuses ids with new targets (`r0-reach`
     500 m → 1 km, `r4-clean` 3 → 4 km, `r9-chain` 4 → 10, `r3-total` 25 → 30 km). Progress never goes down, so an
     R1 install shows "Chain 10 Perfects ✓" and can rank up on goals it never met.
   - **Who:** only devices that ran an R1 build (TestFlight, the founder). Nothing is public yet.
   - **Repro:** decode a v1 blob with `rank: 15` and `goalProgress: ["r9-chain": 1]`.
   - **Fix:** `ProgressData.currentVersion = 2`. When decoding version < 2, clamp `rank` to `maxRank` and clear
     `goalProgress`; bests, Dailies and cosmetics stay.
2. **(suspect) The sea still rebuilds ~12-20 times a second late in a run.**
   - **Where:** `SceneSea.swift:96` rebuilds whenever the storm moves 150 pt while `stormNear`, and
     `FlightScene.swift:362` sets `stormNear = gapPx < 1.6·w`.
   - Zoomed out, or once the lead is below about 0.5, that holds almost all the time. At the storm's 1800-3200 pt/s
     that is a rebuild every 47-83 ms, on top of the range exits.
   - Each rebuild re-tessellates a textured ~260-vertex fill plus the band. The smoke test's bound (< 1 rebuild per 3
     frames, so < 40/s) passes, but this is not "a few a second".
   - The storm chop is also re-anchored in 150 pt jumps, so its amplitude near the front can visibly step ~2-3 pt.
   - **Fix:** rebuild for the storm only while the chop zone (`stormX … stormX + chopReach`) is on screen (that needs
     `gap < anchorX/z + chopReach + margin`), and use `samples(into:)`.
3. **(suspect) The pose card's touch override hands a live run to the hinge with no Ready hold.**
   - **Where:** `RootView.swift:129` → `clearTouchOverride()` → `refreshInput()` (`GameController.swift:718-722`).
   - **What happens:** in a touch run in the portrait band (tabletop), turning the Duo to landscape swaps input to
     the hinge mid-flight, with no pause, Ready hold or snap.
     - Coming out of tabletop, the hinge is typically at about 90-125°.
     - So the bird either closing-pauses or snaps to a full tuck instantly, which is a likely splash.
   - **Fix:** if the run is live, swap input behind a Ready hold (`resumed()`, which also snaps), or keep touch until
     the next run.
4. **Game Center partials can evict an unconfirmed score.**
   - **Where:** `fileDailyProgress()` queues a Daily partial on every `.inactive` and on every background
     (`GameController.swift:557-559`): a notification banner, Control Center, the side button.
   - Each one gets a fresh UUID, and the queue keeps only `suffix(20)` (`GameCenterManager.swift`, `queueScore`).
   - While signed out or offline, a few interruptions push an unsent `swoop.longest` best out of the queue.
   - **Fix:** keep one pending Daily entry per day (replace it when the new one is larger), or exempt `longest`
     entries from the cap.
5. **The lead meter's coral pulse never starts if the storm is already close when the meter appears.**
   - **Where:** `PlayHUD.swift:209-215` starts the pulse in `.onChange(of: stormClose)`, which doesn't fire for the
     value the meter appears with (a demo `lead=` frame, or a rebuild with the storm already close). The meter then
     sits at the 0.35 coral floor with no pulse.
   - **Fix:** also start the pulse in `.onAppear` when `stormClose` is already true.
6. **The HUD hundredths tick behind a constant numeric transition.**
   - **Where:** `PlayHUD.swift:129-132`: "4.06 km" changes its hundredths digit at almost every 15 Hz publish, and each
     change starts a `.numericText()` transition. The digits roll continuously, which costs SwiftUI layout every frame
     and can read as a blur at arm's length.
   - **Fix:** drop `contentTransition` for km, or publish the hundredths at about 4 Hz.
7. **Carried over from QA-1 P2-15: a hinge run still has no accessible wing control.**
   - The new `accessibilityAdjustableAction` (`PlayHUD.swift:34-40`) sits on the touch layer, which exists only when
     `usesTouch`, so a VoiceOver user on a Duo flying by hinge has no accessible input.
   - **Fix:** while `UIAccessibility.isVoiceOverRunning`, show the adjustable element in every input mode.
8. **Carried over from QA-1 P2-10: the clock exploit is open.**
   - The day is still read from the device clock (`playDaily`, `isStale`): another day's clock gives a scored try on
     that sea, which is submitted with `context = day` but lands on the current server occurrence.
   - **Fix:** at flush, drop Daily entries whose `context` doesn't match the occurrence date from
     `GKLeaderboard.loadLeaderboards`. Or accept the exploit and note it in DECISIONS.
9. **Carried over from QA-1 P2-13 (partial): one `-swoopDemo` string still ships.**
   - `FlightScene.swift:57` still reads `-swoopDemo` in Release (prints `SWOOP-T frame 120`). Harmless, and the new
     Release check greps DEBUG-only strings, but it is the one leftover. **Fix:** `#if DEBUG`, as in `FeelDemoLog`.

---

## QA-1 re-check

| QA-1 | Status | Evidence (61f0997) |
|---|---|---|
| P1-1 caught window | **fixed** | `isLiveRun` excludes `.caught`; pause hidden; `finishCaughtRunHeadless` on background, start and Home |
| P1-2 Daily on kill | **fixed** | `fileDailyProgress` on inactive/background; larger wins; "Tried · practice" (`HomeView.swift:230-235`) |
| P1-3 calibration ratchet | **fixed** | upward only ≤ open + 6°, ≤ 168°, τ 10 s; ≥ 175° never teaches (`HingeTuckSource.swift:235-247`); tested |
| P1-4 resume snap | **fixed** | snaps only when still (spread ≤ 1.5° over 0.3 s), from the filtered or predictor angle; Ready extends ≤ 1 s while moving |
| P1-5 Game Center button | **fixed** | `.shown` / `.signingIn` (stored sheet, shown on the tap) / `.signedOut` hint (`HomeView.swift:67-89`) |
| P1-6 frame rate | **mostly fixed** | see P2-2 |
| P2-1 Tailwind jolt | fixed | `vmax` and drag ease over `tailwindFade` 0.6 s (`FlightSession.swift:314-326`) |
| P2-2 stored hinge flag | fixed | `chooseInput` uses the live `hinge.hasHinge` |
| P2-3 stale closing latch | fixed | ClosingCard Resume → `resumeFromClosing` ignores the latch until the next sample |
| P2-4 lead meter | fixed | pulse only while close, and no hit-testing (see P2-5 for the edge case) |
| P2-5 Birds "breathing" | fixed | fit to the reference pose (`BirdPreview.swift:92-95`) |
| P2-6 cloud truth | fixed | Core: y ≥ 900 above the mean water; Scene: the deck's underside at `Tuning.cloudHeight` |
| P2-7 Fly again after midnight | fixed | `flyAgain` → `playDaily()` |
| P2-8 touch override | fixed | cleared on a landscape canvas (new side effect: P2-3) |
| P2-9 lifetime goals | fixed | `ProgressRules.liveProgress` on the Flocks screen |
| P2-10 Daily partial and Game Center | fixed, exploit open | partials submitted with `context = day`; clock exploit: P2-8 |
| P2-11 corrupt save | fixed | the unreadable blob is copied to `swoop.progress.corrupt` |
| P2-12 haptics off | fixed | players and engine stopped at once; `restart()` is guarded by `enabled` |
| P2-13 demo strings | partial | Input, Feedback and Game Center are DEBUG-only; FlightScene isn't (P2-9) |
| P2-14 Home planner | fixed | expert pilot + `planBudget` 2500 steps |
| P2-15 accessibility | partial | adjustable wing in touch mode, flash peak 0.14; hinge mode: P2-7 |

**Checked and OK in the new code:**
- **Rank rewards:** `GoalCatalog.rewards` lists ranks 1…14; trails are adapted in one place (`trailOptions`); a locked
  trail falls back to the bird's own; Reset clears `trail`.
- **The sea intro:** knots are C¹, and set 0 continues from the −300 trough. The blend is checked against the slope
  cap. `introSurface` is O(knots) and only for x < 3700.
- **Pilot pull-out:** 2 branches per replan.
- **Perfect haptic:** prebuilt per engine start and rebuilt after reset.
- **Chain break:** previous chain ≥ 2 and a splash only; a quiet −22 dB pair.
- **New-code safety:** no new force unwraps, unguarded `Int(Double)` conversions or unbounded loops
  (`milestoneNearLighthouse` stops at 200, and returns early).
