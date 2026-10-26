# Round 7: clarity polish (fresh first-time testers on R6, 27 Oct 2026)

Three testers with no prior context walked the first-launch frames. Their write-ups are in the scratchpad:
`fresh/tester1-duo.md`, `tester2-duo.md` and `tester3-phone.md` (copied into `design/fresh/`).

**All three answered the four questions correctly.**
- **Hands:** hold the fold down the wave, open at the bottom, one per wave, never flap.
- **Storm:** it chases you from behind; Perfects and lighthouses push it back.
- **Route:** fly from lighthouse to lighthouse.
- **Outcome:** you lose when the storm catches you; you win more lighthouses and a better distance.

The founder couldn't answer any of these on R2.

Understanding scores: 7, 6 and 7. The aim for this round is ≥ 8.5 from new fresh testers.

## P0
1. **The Wing check is confusing and asked twice.** The non-gamer "nearly quit" at it (screens 6–9), and Home asks
   again after the school.
   - **Decision: take the Wing check out of Flight School and out of the Home card.**
   - The default bird is on the right of the screen, in the first-run orientation, tracked physically. This is
     exactly what the founder asked for.
   - The check lives only in **Settings → Bird side** ("Sharp side · Left · Right"), with a short illustrated
     "Why?" explainer.
   - Duo Flight School is now **7 steps**, with numbering that matches on screen. No "step 5 of 8" jumping to 8.
2. **"Perfect" is never taught.**
   - Step 5 must say it outright: the big word **PERFECT** lands, then the line "Land on a downslope = Perfect.
     Perfects push the storm back."
   - The first Tailwind already has its teaching line; keep it.
   - **"Too close" on the meter** must show only while the storm is inside the danger zone; it's permanent today.
3. **Contradicting numbers and the first-flight state.**
   - "FIRST FLIGHT" must only show when there is no previous best.
   - The best must update after a run.
   - CI must stop mixing differently seeded progress across the first-session frames. Add a demo key, e.g.
     `session=first:<step>`, that seeds ONE coherent first session (fresh install → school → run 1 → results →
     home), so testers see consistent numbers.
   - Audit the stat lines for impossible combinations.
   - Fix **"159 of 25"** (phone screen 22, the route page counter).
4. **Broken layout.**
   - Home tiles are cut off and "New" is squashed one letter per line (Duo screen 29, phone 24).
   - Text overlaps on phone screens 13, 17 and 25.
   - A blank navy screen appears at phone screen 12 (`r6-school-storm-1`).
   - Add a fit test for the Home tiles on all canvases.

## P1
5. **Plain reward language.**
   - "+2 ranks! New: Tern, Coral" becomes "You ranked up twice! New bird: Tern · New trail: Coral".
   - Rank titles ("Spray Chaser") always appear with "Rank 3" beside them, never alone.
6. **The goal sentence, early.** "Outfly the storm. Reach the next lighthouse." appears:
   - on the first real run's countdown;
   - and as the Home subtitle under Fly until the first lighthouse is reached.
   Today it shows only on the pause card.
7. **The touch variant contradicts itself.** Screen 3 says "tap"; screen 8 says "no tapping".
   - Use "Press and hold" everywhere.
   - Say "don't tap" only after the player has held correctly once.
8. **Make iPhone players feel welcome, not short-changed** (the gamer felt they'd bought "the lesser version").
   - No Duo upsell on the first screen of a non-Duo phone.
   - The one-time line becomes positive and later, after the first run's results: "Fun fact: on iPhone Duo, you fold
     the phone to fly." Never on first launch.
9. **The Flight School phone diagram is too small** to read on the Duo (store-55): about 240×170 pt, as ART
   specified. Check its rendered size.

## Owners
- **App:** everything above except the parts noted below.
- **Core:** the reward and rank copy helpers (item 5), if the strings live in Core.
- **Scene:** whether the blank screen at phone 12 is a scene problem (the storm roll-in in practice on iPhone).
- **Founder:** re-run the fresh testers on the coherent first-session frames.
