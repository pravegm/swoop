# Round 8: the finish pass (fresh testers 4–6 on R7, 27 Oct 2026)

Testers 4 (iPhone, casual), 5 (Duo, casual) and 6 (Duo, design-savvy) walked one coherent first session
(`session=first:*`). Their reports are in `design/fresh/` (tester4-phone.md, tester5-duo.md and tester6-duo.md).

**Where we are:** all three answered the four clarity questions correctly. Their scores:

| Tester | Understood | Keep playing | Feels finished |
|---|---|---|---|
| 4 (iPhone, casual) | 7 | 7 | — |
| 5 (Duo, casual) | 7 | 7 | — |
| 6 (Duo, design-savvy) | 8 | 7 | **6** |

Tester 6: "Alto-grade in play, but it isn't finished… much wordier and busier [than Alto]. Monument Valley is far
ahead on clarity and finish, because it teaches through the world rather than text boxes."

**The bar:** feels finished ≥ 8, understood ≥ 8.5, from new fresh testers.

## P0 (everything that reads as unfinished)
1. **The Route page** (s1-18).
   - No placeholder names ("Lighthouse 5/6"). Every lighthouse shows its real fixed name.
   - Gull Point must be on it.
   - It must not be half empty: show the coast through at least the next 2 unreached lighthouses, with names, the
     distance and your best pin, filling both pages on the Duo.
2. **Flight School numbering** (s1-08, s1-11, s1-13).
   - Each step has one unique "step N of 7", in order, and every step the player sees is numbered.
   - "Go" is never shown unlabelled.
   - The rhythm step (6) must be visible.
   - Add a test that walks every step and checks the numbering.
3. **Results contradict themselves** (s1-16). "Reached Saltlight!" and "Caught 2.17 km short" read as a
   contradiction. Write one story:
   - the headline is "**Reached Saltlight!**";
   - the line under it is "The storm caught you 2.17 km before Kestrel Head.";
   - if no lighthouse was reached, the headline is "Caught 0.8 km short of Gull Point".
4. **Stale goals after a big flight** (s1-16). The card sets "Fly 3 km" after a 12.83 km run. Already-met goals must
   tick and cascade on *this* results screen, including the next rank's goals. Fix it and add a test.
5. **Home** (s1-01, s1-17).
   - A broken yellow icon sliver sits before the Fly subtitle.
   - There are four "New" badges: show at most one, on the most relevant tile.
6. **The tutorial fold gauge and title bird don't move** on "That's a tuck" (s1-04). The "done" state must show the
   bird and gauge fully tucked, both in the demo and live.

## P1 (calm the words and teach through the world)
7. **Wordiness.**
   - Every Flight School prompt is at most 7 words, and sub-lines are optional and muted.
   - Prefer showing over telling: guides on the water, the bird's response, the gauge.
   - Cut any line that repeats what the picture already shows.
8. **One vocabulary.**
   - On the Duo, instructions say **fold** and **open**. On iPhone they say **hold** and **let go**.
   - Never mix in tuck, dive or drop in instructions. "Tuck & Soar" stays as the title.
9. **Never cover the bird.** Prompt cards keep out of the bird's rectangle, plus a 60 pt margin (phone s10, s12).
10. **Contrast.** Prompt text over bright sky (s1-05, s1-07) gets the navy backing at 4.5:1 or better.
11. **No Duo line on iPhone at all.** Remove the "Fun fact: on iPhone Duo…" results line (tester 4 felt it made the
    iPhone a lesser version).
12. **The first session should show the catch.** Add an s1 frame of the storm catching the bird, before the results.

**Owner:** App, plus Core only if the goal cascade needs a Core change. The founder re-runs fresh testers 7–9 on the
new s1 frames.
