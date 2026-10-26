# Review 4: iPhone Duo specialist

**Score: 8.5 / 10 (R3: 7.5). Launch verdict: not yet**, and close.
- **Code:** one P1 is left in code, the Home calibration (P1-A), plus the founder's wear copy (P1-B).
- **Ship gate:** unchanged. Swoop has still never been flown on a real Duo, so Appendix A must pass first.
- **Non-Duo fallback:** 8.5 / 10.

**Read.** I read BRIEF (R4 update), ROUND-4, feel/app-R4, `HingeTuckSource`, `FeelClosingGate`, GameController (`advance`, `checkClosing`, `setPose`, `resumed`) and `ci/duo.sh`. I looked at these duo6 frames: duo-01/03/04/07/08, store-21/28/34/35/36/41/42 and duo-ui-home-*. From r8 I looked at touch-wing and pose-phone. I re-ran the stroke counter on R4b.

## My R3 P0s and P1s
| R3 item | Status | Evidence |
|---|---|---|
| P1-1 calibration floor | **Partly fixed** | `openMin` is 132, learning starts at 125, and the stroke is clamp(open − 100, 30, 36). store-42 shows "Open a little wider". **Home still starts at 160° every launch** (P1-A). |
| P1-2 overshoot pause | **Fixed** | `FeelClosingGate`: 90° for 0.2 s on the One-Euro angle, instant below 75°, reopens at 98°. The end-stop detent fires once per stroke. |
| P1-3 Ready ring vs handover blur | **Fixed** | After `.closed`, the hold is 2.5 + 0.3 s, counted from when the pose goes `.play`. store-36's ring is legible on navy. |
| P1-4 "0.0 km" | **Fixed** | `ShareText.distance` everywhere: store-35 reads "Paused at 101 m." The HUD and cards still differ by a few metres (P2-1). |
| P1-5 wear | **Partly fixed** | The rise limit (0.15 s) is in. The copy is **not** corrected (P1-B). |
| P1-6 hinge readout | **Fixed** | Settings › Device test, gated by `BuildChannel.isTestBuild`. It overlays every screen and shows strokes and depth. |

R3 P2s:
- **Fixed:** 7 (stale `isShut`), 8 (hints wait for the blur guard), 9, 10 (store-28's amber fill reads), 11 (store-21 now holds "Bend it a little"), 14 (the touch-down click on Duo touch runs), 16 ("No best yet…", duo-07), 17 (pose-phone).
- **Partly fixed:** 12. duo-01 is a real countdown at 147°, but the inner closing card under a real hinge is still uncaptured.
- **Open:** 13 (grip thumbs, device), 15 (`UIRequiresFullScreen` in Release, founder).

## What is now right
- **The comfort envelope holds together.**
  - Full tuck sits at ≥ 100°. The pause is at 90° with a 0.2 s dwell, and instant below 75°.
  - The gap between full tuck and the pause has grown to ≥ 10° plus the dwell. It was 14° with no dwell.
  - The end-stop tick teaches the hand where "enough" is.
  - The rise limit removes any reward for slamming.
- **The closing gate is lifecycle-aware.** While frames run, it judges the smoothed angle. While paused, it judges the reports. `closing(at:)` lets the dwell mature with no new event. The Duo sends nothing while still, so this matters.
- **Duo text over the scene meets 4.5:1** (store-21/36/42). Results no longer clip: the bird-page goals card (store-28) sits at x 33–431 pt, clear of the fold.

## P1
**A. The Home title bird still shows a permanent tuck for anyone who rests below ~145°.** Not visible in CI, which holds Home at 160°/124°.
- **Why:**
  - `openAngle` starts at 160 on every launch.
  - Snaps only happen in the countdown and the resume hold; Home's input is `.autopilot`.
  - Slow learning refuses tucks above 0.4.
- **What a player sees:**

  | Rest angle | Title-bird tuck |
  |---|---|
  | 140° | 0.58 |
  | 135° | 0.78 |
  | 130° | 0.93 |

  - At 140° the tuck is already over `homeFoldTuck` (0.5). The caption flips to "Fold to dive. Open to soar." and `.homeFold` plays with no fold.
  - The Fly glow never fires.
  - The title bird is the tutorial (UX §1.2), and the first launch is where it is wrong.
- **Fix:**
  - Call `hinge.snapCalibration(at:)` on Home (and on Results before fold-to-fly arms) once `isStill` has held for 0.6 s and the angle is 125–172°.
  - Save `openAngle` in UserDefaults after every countdown snap, and start the next launch from it, not 160.
  - Below 132° on Home, the caption reads "Open it a little wider".

**B. The wear claims in the store and review copy are still wrong** (ROUND-4 gave this to the founder).
- **Where:** `docs/appstore/metadata.md` lines 60 and 103, `docs/site/index.html:157`, `review-notes.md:86` and GAME-DESIGN §2 all still say "one swell every two or three seconds".
- **R4b measurement:**

  | Player | Strokes/min | Stroke size | Strokes/run |
  |---|---|---|---|
  | Casual | 36.5 | 36° | 83 |
  | Expert | 33 | 36° | 227 |

  That is about one stroke every 1.6 s.
- **Fix:** "about one short fold per wave, every second or two". App Review reads these notes against guideline 2.4.2.

## P2
1. **The distance on the card disagrees with the HUD at the moment of pausing.**
   - store-35: the HUD shows "99 m" and the card "Paused at 101 m."
   - store-41: the HUD shows "91 m" and the card "99 m · the storm waits."
   - **Why:** the HUD publishes at ≤ 15 Hz; the cards read the live snapshot.
   - **Fix:** in `setPause`, call `publishHUD(force: true)` when a pause starts, and have the cards read `hud.meters`.
2. **A rest below 125° after the 4 s nudge budget starts the run fully tucked.**
   - **Why:** the snap refuses angles below `calibrationLow`, so the open angle stays at 160 and a 120° rest gives u = 1 at "Go".
   - **Fix:** when the budget expires with a still angle ≥ 105°, snap to `openMin` 132 anyway. A 120° rest then gives u ≈ 0.32. Keep "Open a little wider" as the first hint for 3 s.
3. **The rise limit may add lag to a brisk squeeze.** I proposed 0.15 s in R3, and that may be too tight.
   - **Why:** smoothstep's peak slope is 1.5/stroke. A 0.15 s limit therefore caps the angle speed at 160°/s on a 36° stroke and 142°/s on a 32° one.
   - A brisk human squeeze averages about 144°/s, so its peak is about 200°/s and gets clipped by roughly 20–40 ms. This is game-design bar #1 ("feels like flying").
   - **Fix:** after device check A10/A10b, relax the limit to 0.12 s (200°/s), matching the touch attack, if anyone reports lag.
4. **"Keep flying here" on the cover gets the 2.8 s cover hold.** `resumeAfterCover` is consumed by the deck resume on the cover, where there is no handover blur.
   - **Fix:** only apply the long hold when the new pose is `.play` on a canvas ≥ 760 pt. The cover deck keeps 1.5 s.
5. **CI never exercises the new comfort rules with a real hinge.** Add to the hinge pass:
   - an overshoot, `hinge_sweep 86 0.15; hinge_sweep 150 0.15`: expect no "paused closing";
   - a hold, `hinge_sweep 85 0.3; sleep 1`: expect a pause;
   - a low rest, `hinge_set 130` and a countdown: expect READY-CALIB with open = 132 and tuck < 0.05;
   - a log of `resumed hold=2.8` after the shut/reopen.
6. **The iPhone TurnCard (pose-phone) draws a folding Duo** under "Turn your iPhone sideways". Draw one slab rotating 90° when `!isDuo`.
7. **The iPhone wing glyph (touch-wing) now sits on the bird's path.** At bottom-centre of the bird page it overlaps a bird skimming a trough (x≈555, y≈830 in the frame).
   - **Fix:** offset it to x = bird page minX + 25 % of its width, y = bottom − 40 pt, or fade it to 0.15 α while the bird's rect + 24 pt intersects it.
8. **Open from R3:** P2-13 (grip thumbs on the Home icons, Appendix A29) and P2-15 (drop `UIRequiresFullScreen` in Release, as Brim did after its real-Duo test).

## Top 8 for Round 5
1. Snap the open angle on Home when the hinge is still, save it between launches, and add the Home nudge below 132° (P1-A).
2. Correct the wear copy in metadata, site, review notes and GAME-DESIGN (P1-B, founder).
3. Run Appendix A on a real Duo with the readout on. Everything below depends on it.
4. Force a HUD publish at pause, and have the cards read `hud.meters` (P2-1).
5. After the nudge budget, snap a rest below 125° to 132° (P2-2).
6. Decide the rise limit from A10 and A10b: 0.15 s or 0.12 s (P2-3).
7. CI hinge checks for overshoot, hold, low rest and the 2.8 s reopen (P2-5). Also capture the inner closing card at 90°.
8. Drop `UIRequiresFullScreen` in Release; fix the iPhone TurnCard drawing and the glyph placement (P2-6/7/8).

## Appendix A: real-Duo test script for the founder (15 minutes, R4 build)

**Before you start**
- Install the newest TestFlight build. Delete the old app first, so it's a fresh install.
- Battery above 50 %, Low Power off, sound on.
- Keep a timer and this page beside you. Write each answer as you go: a number, a word, or Y/N.
- Turn on the readout: Settings › Device test › **Hinge readout (TestFlight)**. Then go back to Home.
- Wherever a step says **[readout]**, write down the numbers shown in the corner.

**0:00–1:30 · First launch, shut**
1. With the Duo **shut**, open Swoop on the cover.
   - Expect "Open your wings / Your first flight is waiting."
   - **A1:** did you see that? Y/N. Is anything hidden under the camera at the top right?
2. Open the Duo slowly to a comfortable book.
   - **A2:** how many seconds until Home is sharp?
   - **A3:** did the big bird arrive with its wings spread? Y/N.
   - *(Then turn the readout on, as in "Before you start".)*

**1:30–3:30 · Your natural hold (most important)**
3. Hold it the way you'd read a book, relaxed, for 5 seconds.
   - **A4:** are the big bird's wings fully spread, half-folded or folded? Did the caption change by itself? **[readout]** angle __, open __.
   - Ask two other people to hold it the same way. Note their angles too.
4. Fold slowly over about 2 seconds, then open slowly.
   - **A5:** do the wings follow your hands? (1 = steppy or late, 5 = glued to my hands)
5. Hold still at half fold for 5 seconds.
   - **A6:** do the wings shiver or drift? Y/N.

**3:30–4:30 · The flat blur (Q1)**
6. Lay the Duo flat on the table for 3 seconds, then start folding it.
   - **A7:** which half blurred: the storm (left) side or the sun (right) side? For how many seconds?
7. Do it twice more. The second time, turn the phone round first.
   - **A8:** was it always the same physical half? Y/N.

**4:30–7:30 · Two flights (feel, lag, overshoot, haptics Q2)**
8. Tap Fly and hold your relaxed book through the countdown.
   - **A9:** at "Go", were the bird's wings spread? Y/N. Did "Open a little wider" appear? **[readout]** open __.
9. Fly the whole run.
   - **A10:** lag on a gentle squeeze. (1 = late, 5 = instant)
   - **A10b:** lag on a brisk, quick squeeze. (1–5)
   - **A11:** how many times did the game pause by itself while you were squeezing? __
   - **A12:** when the wings are fully tucked, do you feel or hear a small tick telling you to stop? Y/N. Does it help?
   - **A13:** can you feel the Perfect buzz and the splash thud? (Haptics are set to Strong.)
10. On Results, open Settings › Haptics, set **Normal**, and fly again.
    - **A14:** which feels better, Strong or Normal? Was either too weak? Set back the one you prefer.

**7:30–10:00 · Closing and reopening mid-flight**
11. Mid-run, close slowly. **[readout]**
    - **A15:** at what angle does "Open your wings to keep flying" appear?
    - **A16:** at what angle does the big screen go dark?
12. Close it fully.
    - **A17:** the cover shows PAUSED and a distance. Does it match the distance in the game's corner? Y/N.
13. Open it to a book.
    - **A18:** once the screen is sharp, is the gold **Ready** ring still there for at least 1 second? Or is the bird already flying? Or is there a Pause card?
14. Close it again, tap **Keep flying here** on the cover, and play for 10 seconds by holding the cover screen.
    - **A19:** does it play? Y/N.
15. Open the Duo.
    - **A20:** does "Fly with the fold?" appear? Tap **Fly with the fold**.

**10:00–11:00 · Lock and return**
16. Mid-run, lock the phone with the side button. Wait 10 seconds, then unlock.
    - **A21:** is a Pause card shown? Y/N.
    - Tap Resume. **A22:** are the wings spread, not stuck folded? Y/N.
    - **A22b:** does the distance on the card match the HUD? Y/N.

**11:00–12:00 · Seated and tent**
17. Mid-run, stand the Duo up like a laptop, lid up.
    - **A23:** does the game move to the top half, with a "Hold to dive" pad below? Can you fly with the pad?
18. Pick it up as a book again.
    - **A24:** does "Fly with the fold?" appear?
19. Stand it as a tent.
    - **A25:** does the game pause cleanly? Y/N.

**12:00–14:00 · A hard run (comfort Q3, heat Q5, grip)**
20. Fly one full run with a firm grip.
    - **A26:** **[readout]** strokes __, average depth __, run length __ s.
    - **A27:** how do your hands and forearms feel afterwards? (0 = fine, 5 = sore)
    - **A28:** how warm is the hinge, and the back? (cool / warm / hot)
    - **A29:** on Home or in a run, did your thumbs ever press the gear, the trophy or pause by accident? Y/N.

**14:00–15:00 · Fly again with the fold**
21. On Results, fold in and then open.
    - **A30:** did "Fly again" fill amber and start a run? After how many tries?
22. On another Results screen, set the Duo down half-closed, then pick it up.
    - **A31:** did a flight start that you didn't ask for? Y/N.

**Send back:** A1–A31, plus anything that felt wrong, in your own words. These answers decide Round 5:
- A4 and A9: the floor, and Home.
- A10b: the rise limit.
- A11 and A12: the overshoot pause and the tick.
- A18: the reopen ring.
- A7 and A8: which half blurs.
- A14: haptic strength.
- A26–A28: wear and heat.

**Optional, 2 minutes on a regular iPhone**
- Does hold-to-dive feel instant?
- Does the click feel like a fold?
- Does the wing glyph ever get in the way of the bird?
