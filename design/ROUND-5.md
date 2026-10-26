# Round 5: the last polish (26 Oct 2026, evening)

The panel scored the R4 build (`design/panel/REVIEW-4-*.md`; read your relevant ones in full):

| Critic | R3 | R4 | Verdict |
|---|---|---|---|
| Juror | 6.5 | 7.5 | close; "Great on iPhone Duo" once the Home button is fixed |
| UX | 7.0 | 8.2 | one short polish round |
| Player | 7.0 | 8.0 | about a day away; 4★ today, 5★ once the Home button and splash are fixed |
| Duo | 7.5 | 8.5 | close; the real-device test is the last gate |

The bar is still 9. ROUND-1's rules still apply. Write your notes in `design/notes/<role>-R5.md`.

## P0
1. **The Home button on every Daily card and Daily result is broken** (all four critics: store-27, store-29,
   iPhone daily-card, daily-results). The house glyph floats above an empty tile.
   - **Owner:** App.
   - Fix it, and add a test that every results/daily button has a non-empty label and fits its tile.

## P1
2. **Splash feedback is invisible.** "Splash · ×N lost" appears in none of the 5 splash frames (UX, player).
   - **Owner:** App.
   - Find out whether the word doesn't fire or the capture misses it, and fix whichever it is.
   - A chain break must always show something on screen.
   - Fix the `chain-lost`, `splash-mark` and `hint-land` scenarios so they capture the moment, using a `freezeOn`
     with a short delay.
3. **The HUD and the pause/closing card show different distances** (91 m vs 99 m, 99 m vs 101 m; UX, juror, Duo).
   - **Owner:** App.
   - Force a HUD publish when the pause starts, and have the cards read the HUD's published value. Add a test.
4. **Results layout** (juror, UX, player).
   - **Owner:** App.
   - The far results card has an empty void of about 190 pt; use it or compact the card.
   - On iPhone, "Fly again" lost its label. It must be the biggest, labelled control.
   - An unflown Daily card leads with "0 m" and makes Share the primary button. Lead with "Fly today's sea" instead.
   - "3-day streak" on Daily #1: check that the streak logic is real, and not a demo artefact.
5. **The storm** (juror, player).
   - **Owner:** Scene.
   - The anvil is still a flat "saucer" with a hard edge behind the HUD, and the billows read as chimney smoke.
   - Make the top a soft, rounded, sunlit cloud mass with no disc and no hard edges.
   - Make the billows read as a rolling shelf (horizontal layering, not a vertical plume).
   - Never draw it over the pause button or the meter: clip or dim it there, or push it under a HUD scrim.
6. **The tucked title bird** reads as a manta ray or kite (juror).
   - **Owner:** Scene.
   - Make it a narrow gannet dart: wings swept tight along the body, a pointed head, and total width at most 14 % of
     the canvas.
7. **Home calibration on the Duo** (Duo critic).
   - **Owners:** Feel and App.
   - On Home, calibrate the open angle once the hinge has been still for 0.6 s.
   - Persist the open angle between launches.
   - So a player resting at 140° never sees a phantom tuck, a "Fold to dive" flip or a fold sound.
8. **Rests below 125°** start the run fully tucked once the 4 s "Open a little wider" hold ends (Duo critic).
   - **Owners:** Feel and App.
   - Choose kinder behaviour, for example keep holding the countdown with an option to fly with touch. Never start a
     run fully tucked.
9. **Goals feel too easy right after a big flight** (player): "Fly 3 km" just after flying 12.16 km.
   - **Owners:** Core and App.
   - Goals that the player's bests already meet complete straight away, with the tick animation on results, so a
     strong player climbs ranks quickly instead of being handed stale goals.
   - Re-run `tools/goal-cadence.js`.
10. **Smaller fixes.**
    - **App:**
      - the iPhone Home Goals tile lost its "Goals" title;
      - the attract bird crosses the wordmark;
      - the iPhone turn-sideways card draws a folding Duo, so draw an iPhone on non-Duo devices;
      - the iPhone wing glyph still sits on the bird's path.
    - **Scene:**
      - the Results sea is a jagged ridge; make it calm and smooth;
      - fix the Birds page items in REVIEW-4-juror.

## Founder
- Correct the wear copy (done).
- In `duo.sh`, add real-hinge checks for the R4 comfort rules (Duo critic P2):
  - a short overshoot to 85° must not pause;
  - holding 85° must pause;
  - a low rest at 130° flies with wings spread;
  - the Ready ring after a reopen lasts about 2.5 s.
- `UIRequiresFullScreen`: review it (keep it unless Apple rejects it; it only matters on iPad and the app is
  iPhone-only).
