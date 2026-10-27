# Final fixes before App Store submission (27 Oct 2026)

These come from the four audits in this folder: `QA-FINAL-app-ui.md`, `QA-FINAL-core-data.md`,
`QA-FINAL-scene-feel.md` and `QA-FINAL-release.md`. Each fix is the founder's decision, and each owner fixes exactly
the items listed for them.

**Rules for every fix:**
- Fix the item and add a regression test where the code is testable.
- Don't refactor anything else.
- There is no local compiler. CI compiles, so write Swift carefully and follow the gotchas in `CLAUDE.md`.
- Don't commit or push.
- Write `design/notes/<role>-FINAL.md`.

## App engineer (Swoop/App, Swoop/UI, Swoop/Persistence, App tests, the s1/scenario lines if needed)

**P0 and P1**

1. **Remove the hinge readout from Release entirely.** `BuildChannel.isTestBuild` becomes `#if DEBUG` only, with no
   sandbox-receipt check, because App Review and TestFlight run the same binary as the App Store build.
   - In Release, Settings has no "Device test" card and no overlay.
   - Update the tests.
2. **Home's Daily goes stale across UTC midnight.**
   - Refresh the day when the scene becomes active as well as on the 30 s tick.
   - `openDailyCard()` starts today's scored Daily when today has no attempt. It never shows "spent" for an unplayed
     day.
   - Test it.
3. **Flight School step 1 ("Hold it open") on a Duo held flat.**
   - A flat Duo passes the step, the same as a relaxed book.
   - The step's sub-line (e.g. "A little less than flat.", "Open it wider.") must actually be drawn as the muted
     second line. Today `subline` is computed but never drawn.
   - Keep the wording within the glossary.
4. **Seated (portrait) Duo dead screen after Home.** Clear `touchOverride` (or limit the split deck to a live run)
   when the attract loop starts, so Home is always reachable.
5. **Auto-Lock during Flight School.** Keep the idle timer disabled while the school is running, as during a flight,
   and re-enable it when the school ends.
6. **Fold-to-fly on a scored Daily's Results** must not start a hidden practice run. Exclude the scored-Daily card
   from `FoldToFly`.
7. **Touch stuck after a pause or the catch** (PlayHUD hold layer and the deck pad).
   - Use `@GestureState`, or reset in `onDisappear`, so the first press after a pause, the catch or Control Center
     always tucks.
   - Also, when holding with two thumbs, handing over from one thumb to the other keeps the tuck. The tuck is held
     while any finger is down.
8. **A 180° turn may leave the bird on the blurred half.** Re-read the interface orientation after the rotation
   settles, in the existing ~350 ms task or via the window scene's geometry, so `SharpHalf` gets the final
   orientation.
9. **Resuming from the closing pause.** For a resume from `.closing` (not a user pause), "Go" waits until the start
   tuck is ≤ 0.5 or 3.0 s have passed, whichever comes first. The founder's recent change gave only a 1.0 s grace.
10. **Two adjacent Skip buttons** on the clear-side check.
    - Keep one, labelled clearly. "Skip" skips the whole lesson; the clear-side check gets "Not sure", or is skipped by
      the same control.
    - Tap areas must never overlap.
11. **Game Center.**
    - The offline queue keeps only the highest pending `swoop.longest` score, never evicting it.
    - On every successful sign-in, submit `bestMeters` to `swoop.longest` and re-report every earned achievement at
      100 %, which Game Center de-duplicates. That way TestFlight players' earned achievements reach production.
12. **Small screens** (667×375 iPhone SE, 844×390). Make sure Home's caption never runs into the Settings and Scores
    pills: shrink or wrap the caption, or hide it on compact canvases. Add a layout test for those canvases.

**P2, where the fix is small and safe**

13. **The practice Daily's share text** must not match the scored line. Prefix it with "Practice".
14. **Streaks** (`ProgressStore.streakWithGrace`):
    - Home shows the kept streak after a single missed day.
    - "Calm sea: streak kept" shows only once, for the day it bridges.
    - `swoop.ach.daily3` needs three consecutive days with no bridged gap.
    - Test all three.
15. **Pause the SKView**, or drop its preferred frame rate to about 10, while a pause card, the closing card or
    Results is up, to save battery.
16. **Glossary slips** in user-visible strings: "tucks", "ranks", "record", "Perfects/Chain" in goal text, and the
    missing dot in "Daily 27 Oct". Follow `design/UX-ROUND-9.md`.
17. **Animations that ignore Reduce Motion** (listed in `QA-FINAL-app-ui.md`): honour it.
18. **Delete the dead code that holds banned copy.**
19. **Cache the date formatter.**

**Not doing (founder's decision):**
- Dynamic Type support (accessibility.md must not claim Larger Text).
- Achievement progress percentages.
- Telling the player that a Daily which crosses midnight was dropped.
- The clock-jump edge case.

## Feel engineer (Swoop/Input, Swoop/Feedback, InputTests and Feedback tests)

1. **Haptics: stale "stopped" signals.**
   - Tag each engine start and ignore a stopped handler from an older start.
   - Stop the looping players before rebuilding.
2. **Audio self-repair.**
   - A late "app was suspended" interruption must never switch self-repair off for the session.
   - Retry a failed engine restart for menu sounds too.
   - On a configuration change (headphones), renegotiate the output format before restarting.
   - Pause the engine explicitly when the app goes to the background, and resume it in the foreground.
   - Don't push sound settings to the synth while the engine is paused. Apply them on resume.
3. **Raise the 5 ms IO buffer to about 10 ms** if latency stays fine for the tuck rumble. Otherwise leave it and say
   why.
4. **Move the haptic engine start off the main thread mid-flight,** if it's safe and simple. Otherwise leave it and
   say why.
5. **On returning from the background,** forget the stale hinge angle so the ready snap waits for a fresh sample.
6. **First Duo launch:** record the sharp half from the first hinge sample.
7. **Stale gate notes:** fix the 95°/102° text in `HingeTuckSource.swift:331` and `InputTests.swift:365`.

**Not doing:** "Respect silent switch" stays off by default. That is the founder's decision (GAME-DESIGN §7): sound
plays on silent, and a toggle respects the switch.

## Scene: no changes for 1.0

Leave the storm-cloud generation hitch, the trail rebuild per frame and the crossfade texture cache for 1.0.1. They
are perf polish, and a late Scene change risks more than it saves.

## Founder, by hand (no API)

- Turn on GitHub Pages (runbook §0b). The support, privacy and marketing URLs return 404 until then.
- Everything else is in the final checklist.
