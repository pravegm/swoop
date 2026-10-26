# Review 3: iPhone Duo specialist

**Score: 7.5 / 10. Launch verdict: not yet.** This is the studio's most Duo-aware build. It plays in every pose, never letterboxes,
keeps the fold band clean, reads the hinge angle and never `status`, and ports the Squish/Brim filters and lifecycle handling.
- **What holds it back:** nobody has felt the input on a real Duo yet. Every PASS so far comes from the simulator's synthetic 60 Hz
  sweeps.
- **Three code gaps** could make a first-time player think the controls are broken: the calibration floor, the closing pause firing
  mid-dive, and the reopen blur.
- **The path:** fix the 6 P1s, then run Appendix A on a real Duo. If it passes, ship.

**What I read.**
- **Code:** BRIEF, `research/02-hinge-tech.md`, `Swoop/Input/*`, `GameController`, `RootView`, `Layout`, `PoseCards`, `PlayHUD`,
  `FeelHaptics`, `OrientationLock`, `project.yml`, `ci/duo.sh`.
- **Frames:** duo-01…08, duo-ui-*, store 12/18/20/21/22/28/32–36, and iPhone home / touch-wing / pose.
- **Sim:** I re-ran `tools/balance-sim.js` with a stroke counter (12 seeds per skill).

## What is right (keep it)
- **Pose map. No state is a dead end:**

  | Pose / state | What happens |
  |---|---|
  | Book | Hinge input |
  | Flat | u = 0, playable |
  | Closing < 95° | Card on the far page |
  | Shut | Cover card: home, mid-run or results |
  | Seated / portrait | Split deck; fold band y 448–504 clear (store-34) |
  | Cover | "Keep flying here", touch play in a 466 × 328 band |
  | Tent | Same as closing |

- **Fold composition** (duo-01/03/04, store-12/28): bird page and far page work as designed.
  - The bird page (bird at 30 % x, storm, pause, meter, hints) and the far page (distance, toasts, lighthouse card, countdown, Ready,
    results, Home menu) are respected.
  - No control or text sits in x 456–496 in any frame. The sun stays ≥ 280 pt from the crease. Mirroring works.
- **Hinge pipeline:**
  - Samples are stamped on receipt, then alpha-beta, One-Euro and a hold stabiliser (smoothing only while still).
  - Shut has 10° / 15° hysteresis; closing has 95° / 102°.
  - The ready snap only lands when the hinge is still. The reader re-enables on every activation.
  - A nil never demotes to touch, and a restored `hasHinge` is trusted only on a Duo-shaped screen.
- **Cover** (duo-06/07, real 466 × 678): paused distance, storm gap, best line, two clear actions. The camera corner is empty and
  nothing reads "—".
- **Thermal and haptics:** 120 Hz in Play only, 60 Hz at `.serious` or Low Power, effects trimmed. Strong haptics by default, and
  audio on every cue.

## P0
None in code. The ship gate is the real-device pass (Appendix A).

## P1
1. **Players who rest under 140° fly permanently tucked** (unseen: CI only holds 147–160°).
   - **Why:** `snapCalibration` and `calibrate` ignore angles below `calibrationLow` 140, and `openMin` is 145. A reader at 130–138°
     keeps `openAngle` at 160.
   - **Resting tuck:** 0.66 at 138°, 0.78 at 135°, 0.93 at 130°.
   - **Effect:** the title bird looks folded, the bird drops heavy at "Go", and the Fly glow never fires. GAME-DESIGN §3 names
     130–170° as the ready pose.
   - **Fix:** `openMin` 132 and `calibrationLow` 125. Stroke = clamp(open − 100, 30, 36). Closing latch 90° / 98° (the display is lit at
     85°).
   - **Fix:** a still countdown under 132° reads "Open a little wider" and holds, like the flat hold.
2. **A hard squeeze pauses the run mid-dive.**
   - **Why:** full tuck saturates at open − 36° (109–124° for real rests), with no cue to stop. `FeelClosingLatch` fires on a single
     tracked report below 95°, so an excited 14–29° overshoot freezes the run on the downslope.
   - **Fix:** pause after 0.2 s below the latch, or at once below 75°. Feed the latch the One-Euro angle.
   - **Fix:** add an "end-stop" detent when u first hits 1 in a stroke: a 25 ms tick at 0.35, and the wind note caps.
3. **The Ready ring can expire under the iOS handover blur** (duo-08, store-36).
   - **Why:** reopening from the cover returns the inner canvas behind a 1–2.5 s blur, but the ring lasts 1.5 s + ≤ 1 s while moving.
     A hand that stops at 150° sees the bird already flying.
   - **Fix:** after a closed / shut pause, `readyHold` is 2.5 s, starting 0.3 s after the first frame on a ≥ 760 pt canvas. User
     pauses keep 1.5 s.
4. **"Paused at 0.0 km." over a HUD reading 89 m** (store-35).
   - **Why:** `ClosingCard` and `PauseCard` use `ShareText.km`, which floors to tenths: the first 100 m reads "0.0 km", and 11.88 km reads
     "11.8 km".
   - **Fix:** use `ShareText.hudDistance` ("89 m", "11.88 km"), as the cover hero does.
5. **The wear claims are ~2× too low.**
   - **Sim:** pilots make one full 36° stroke per touchdown.
     - Casual: 38/min, ~90 per 142 s run, ~2,700° of hinge travel a minute. Expert: 35/min, ~200 a run. Novice: 38/min.
     - The physics reward a full squeeze, so humans will saturate too.
   - **Docs say otherwise:** GAME-DESIGN §2, UX §9, `review-notes.md` and `press-kit.md` all say "one wave every 2–3 s, about 30°".
   - **Scale:** the 20-min rest line allows ~760 strokes a day, about 280k partial strokes a year. The only public figure is a robot
     test of 32,640 full folds, and Apple publishes no rating.
   - **Fix:** correct the copy to "one 30–35° fold per wave, every 1–2 s". App Review reads it (2.4.2).
   - **Fix:** rate-limit the rise of u (full tuck no faster than 0.15 s), so a slam above ~240°/s gains nothing. Squish coaches at
     250°/s.
6. **The founder can't see the hinge on the device.** Release strips `SWOOP-H`, and the founder isn't a developer.
   - **Fix:** a TestFlight-only readout, toggled by tapping the Settings version 5×. It is a bird-page corner overlay.
   - **It shows:** raw angle, `openAngle`, u, Hz, last-report age, `isClosing` / `isShut`, pose, and strokes per run with their mean
     depth.
   - Appendix A needs it. Keep it out of App Store builds.

## P2
7. **`isShut` can stick on the inner display.** `AppPoseRule.pose` checks `isShut` before canvas size. If a ≥ 15° report is dropped on
   reopen, the lit inner display shows "Open your wings".
   - **Fix:** ignore `isShut` when the long side is ≥ 760 pt, and clear it in `innerDisplayBack()`.
8. **The blur guard is narrower than the blur.** It queues toasts and cards and hides sparkle, but not hints or the callout.
   - After the 4 s flat-hold timeout the run starts flat, so the first fold blurs one half while "↘ Fold on the way down" shows.
   - **Fix:** no hint offer while `inFlatBlurGuard`.
   - **Fix:** if Q1 says it's always the same half, default the bird page to the other half.
9. **store-36: "Spread your wings" is unreadable over the sun.** Mist ~#9FB4CC on peach ~#F7C9A8 is about 1.6 : 1.
   - **Fix:** foam #F2F6F8, 17 pt semibold, with `swoopLegible()`.
10. **store-28: the fold-to-fly fill is never seen.**
    - **Why:** with a hinge present, `updateFoldToFly` overwrites the demo `foldFill` to 0 every frame. And #FFF3C4 at 55 % over
      #FFD45E is about 1.1 : 1.
    - **Fix:** freeze the demo fill. Draw the fill as ink #10233A at 18 %, plus a 3 pt #10233A underline at 60 %.
11. **store-21 = store-20.** The freeze came after the 4 s flat hold expired, so the countdown's "Bend it a little" has never been
    seen.
    - **Fix:** add `freezeOn=flathold`.
12. **The hinge pass misses two states.**
    - duo-01 "countdown" is mid-flight (224 m).
    - duo-06 "closing" is the cover (the simulator switches displays by 60°).
    - **Fix:** shoot the countdown before the launch wait ends. Add `hinge_set 90` with a shot before the 60° sweep.
13. **The Home corner icons sit under the left grip thumb.** Settings and Leaderboards are at x 32–144 pt, bottom − 56, right where
    the left thumb grips 254 g.
    - **Fix:** check on the device (A29). If thumbs hit them, move them to the top outer corner, where pause sits.
14. **Haptics.**
    - The touch-down click is gated on `!deviceHasFold`, so Duo touch runs (deck, cover) lose it. Gate it on `input == .touch`.
    - The Strong Perfect's second burst lands 45 ms after the 35 ms hit-stop: Q2.
    - Strong's looping player runs all flight on a phone reviewers call warm: Q5.
15. **`UIRequiresFullScreen` ships in Release.** On a real Duo, Brim found iOS strips upside-down on the inner display.
    - **Fix:** drop the key in Release and keep it in Debug, as Brim does.
16. **Fresh-profile cover mid-run reads "Your first flight"** like a stat (duo-06).
    - **Fix:** "No best yet: this flight sets it".
17. **iPhone `pose.png` shows the Duo TurnCard** (`forcedPose` forces `isDuo`). "Turn your iPhone sideways" is never captured.
    - **Fix:** add `pose=phone`.

## Non-Duo fallback (regular iPhones): good, 8 / 10
- **Detection:** below iOS 27.1, or nil before any reading, means touch at once.
- **Orientation:** landscape-only mask. The TurnCard waits 0.6 s. A restored `hasHinge` is distrusted on 0.46-aspect screens.
- **Touch:** hold anywhere, edge gestures deferred, ease-out 0.12 s in / 0.10 s out (44 % at 30 ms).
  - The touch-down click, wing glyph and 3-run ripple are all there.
  - Hold / Let go copy everywhere.
- **The Duo mention:** one quiet "Made for iPhone Duo. Here, hold to tuck." (home.png). Honest, no upsell.
- **One visual nit (touch-wing.png):** the 70 % foam glyph with 2 pt strokes vanishes on the foam line.
  - **Fix:** 85 %, with a 1 pt #10233A outline at 40 %.
- **Untested:** the 0.09 vs 0.12 s attack.

## Still untested (a real Duo only)
- **Input:** natural rest angle, latency, report rate under heat or Low Power, overshoot past full tuck.
- **Displays:** the display-off angle, whether reports reach the cover, and which half blurs (Q1).
  - Does the handover make the scene inactive? If so, every reopen shows the Pause card, not the Ready ring.
- **Feel:** Strong vs Normal (Q2), hands after 3 runs (Q3), warmth after 10 min at 120 Hz (Q5).
- **Accidents:** grip taps, and unrequested fold-to-fly restarts.

## Top 8 for Round 4
1. Calibration floor: `openMin` 132, `calibrationLow` 125, stroke = clamp(open − 100, 30, 36), latch 90 / 98, "Open a little wider"
   (P1-1).
2. Closing latch: a 0.2 s dwell, the One-Euro angle, and an end-stop detent at u = 1 (P1-2).
3. Ready ring after a cover reopen: 2.5 s, started after the inner canvas returns (P1-3).
4. Closing and pause cards use `hudDistance` (P1-4).
5. A TestFlight hinge readout with a stroke counter, then run Appendix A (P1-6).
6. Correct the wear copy (GAME-DESIGN, UX, review-notes, press kit) and rate-limit u's rise (P1-5).
7. Ignore `isShut` on a ≥ 760 pt canvas; the blur guard holds hints too (P2-7, P2-8).
8. CI: the countdown, the 90° closing card, the flat hold, the fold fill. Fix the Ready label's contrast (P2-9 to P2-12).

## Appendix A: real-Duo test script for the founder (15 minutes)

**Before you start**
- Install the newest TestFlight build. Delete the old app first, so it is a fresh install.
- Battery above 50 %, Low Power off, sound on.
- Keep a timer and this page beside you. Write each answer as you go: a number, a word, or Y/N.
- If the build has the hinge readout (P1-6), turn it on: in Settings, tap the version number five times.
  - Wherever a step says **[readout]**, note the number shown. With no readout, skip those parts.

**0:00–1:30 · First launch, shut**
1. With the Duo **shut**, open Swoop from the cover screen.
   - Expect "Open your wings / Your first flight is waiting."
   - A1: Y/N. Is anything hidden under the camera at the top right?
2. Open the Duo slowly to a comfortable book.
   - A2: how many seconds until Home is sharp on the big screen?
   - A3: did the title bird's wings arrive spread? Y/N.

**1:30–3:30 · Your natural hold (most important)**
3. Hold it as if reading a book, relaxed, for 5 seconds.
   - A4: are the big bird's wings fully spread? Y / half-folded / folded. **[readout]** angle = ___, open = ___.
   - If you can, ask two other people to do the same, and note their angles.
4. Fold slowly, over about 2 seconds, then open slowly.
   - A5: do the wings follow your hands smoothly? (1 = steppy or laggy, 5 = glued to my hands)
5. Hold still at half fold for 5 seconds.
   - A6: do the wings shiver or drift? Y/N.

**3:30–4:30 · The flat blur (Q1)**
6. Lay the Duo fully flat on the table for 3 seconds, then start folding it.
   - A7: which half blurred, the left (storm side) or the right (sun side)? For how many seconds?
7. Do it twice more. The second time, turn the phone round so its top edge faces you.
   - A8: was it always the same physical half? Y/N.

**4:30–7:30 · Two flights (feel, lag, overshoot, haptics Q2)**
8. Tap Fly and hold a relaxed book through the countdown.
   - A9: at "Go", were the bird's wings spread? Y/N.
9. Fly the whole run: squeeze on the way down, open on the way up.
   - A10: lag. (1 = the bird is late, 5 = instant)
   - A11: how many times did the game pause by itself while you were squeezing? __
   - A12: did you squeeze further than the bird needed? Y/N.
   - A13: Haptics is set to Strong. Could you feel the Perfect buzz and the splash thud?
10. On Results, open Settings (the gear) and set Haptics to **Normal**. Fly once more.
    - A14: which feels better, Strong or Normal? Was either too weak to notice?
    - Then set it back to the one you prefer.

**7:30–10:00 · Closing and reopening, mid-flight**
11. Mid-run, close the Duo slowly. **[readout]**
    - A15: the angle where the "Open your wings to keep flying" card appears.
    - A16: the angle where the big screen goes dark.
12. Close it fully.
    - A17: the cover shows PAUSED and a distance. Does it match the distance you saw? Y/N.
13. Open it again and stop at a book angle.
    - A18: once the screen came back sharp, did you see the gold **Ready** ring for at least 1 second? Or was the bird already
      flying? Or did a Pause card appear instead?
14. Close it again. On the cover, tap **Keep flying here**, then play for 10 seconds by holding the cover screen.
    - A19: does it play? Y/N.
15. Open the Duo.
    - A20: did "Fly with the fold?" appear? Tap **Fly with the fold**.

**10:00–11:00 · Lock and return**
16. Mid-run, press the side button to lock. Wait 10 seconds, then unlock.
    - A21: was a Pause card shown? Y/N.
    - Tap Resume. A22: are the wings spread, not stuck folded? Y/N.

**11:00–12:00 · Seated and tent**
17. Mid-run, stand the Duo on the table like a laptop, lid up.
    - A23: does the game move to the top half, with a "Hold to dive" pad below? Can you fly by holding the pad?
18. Pick it up as a book again.
    - A24: did "Fly with the fold?" appear?
19. Stand it as a tent, screens facing out.
    - A25: did it pause cleanly? Y/N.

**12:00–14:00 · A hard run (comfort Q3, heat Q5, grip)**
20. Fly one full run as well as you can, with a firm grip.
    - A26: count your folds out loud, or estimate: __ folds in __ seconds. **[readout]** strokes = __.
    - A27: hands and forearms afterwards. (0 = fine, 5 = sore)
    - A28: warmth at the hinge and on the back: cool / warm / hot.
    - A29: on Home or in play, did your thumbs ever press the gear, the trophy or pause by accident? Y/N.

**14:00–15:00 · Fly again with the fold**
21. On Results, fold the Duo in, then open it.
    - A30: did "Fly again" fill and start a new flight? How many tries did it take?
22. On another Results screen, set the Duo down half-closed, then pick it up again.
    - A31: did a flight start that you didn't ask for? Y/N.

**Send back:** A1–A31, plus anything that felt wrong, in your own words. These answers decide Round 4:
- A4 and A9: the calibration floor.
- A11: overshoot.
- A18: the Ready ring vs the handover blur.
- A7 and A8: which half blurs.
- A14: haptics.
- A26–A28: wear and heat.

**Optional (2 minutes on a regular iPhone)**
- In a run, does holding to dive feel instant?
- Does the hold-down click feel like a fold or like a button?
- Can you see the small wing glyph in the lower-left corner over the sea?
