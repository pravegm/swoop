# App R8: the finish pass (fresh testers 4–6, 27 Oct 2026)

## P0
1. **The Route page** (`RouteView.swift`, rewritten).
   - Every lighthouse shows its real fixed name; `RouteRules.nodeLabel` no longer makes "Lighthouse 5".
   - It shows the reached lighthouses (Gull Point included), the next one and two more (`nodeCount = reached + 3`).
     `fittedSpacing` spreads them across the whole screen (both pages on the Duo), so the page doesn't scroll until
     the route gets long.
   - No lighthouse is centred in the fold band: `RouteArt.snapOffset` shifts the row when it fits one screen.
   - Gull Point clears the phone's safe-area inset.
   - The chart fills edge to edge behind the header and the summary: land to the top, sea with depth contours to
     the bottom, scaled ×1–1.7 into the band (no empty half, no seam).
   - The phone summary reads "2 reached" and "Next: …".
2. **Numbering.**
   - The demo school frames walked on to later steps, which is why the testers saw "7 of 7" and "Go" out of order.
     Now every demo school frame holds its step (`schoolHeld = true`).
   - The practice sea freezes at each step's moment (`demoSchoolFreezeX`):
     - the soar frame on the up-face;
     - the land frame in the air with the ring ahead;
     - the PERFECT frame after the touchdown;
     - the rhythm frame on wave 2;
     - the storm frame after the roll-in.
   - The new test walks all 7 steps on the Duo and on iPhone: "step 1 of 7" … "step 7 of 7", each shown once and
     in order.
3. **One story on Results.**
   - "Reached Saltlight!", then "The storm caught you 2.17 km before Kestrel Head."; with no reach, "Caught 0.8 km
     short of Gull Point".
   - The stats line is now just "11 Perfects" ("chain 9" and the lighthouse count were noise).
   - The Daily row line is now "Daily Flight: one try a day, same sea for everyone. Not flown yet."
   - The helper reads "Or fold and open to fly again".
4. **Stale goals.** All in the App (`ProgressRules.record`); no Core change.
   - The cascade still stops at the first rank the bests don't meet. Now that rank's goals start from this run's
     bests, so the ones already met tick at once: they are stored, and returned as `RecordOutcome.nextGoals`.
   - The rank-up card says "Next goals: ✓ Fly 3 km · 15 Perfects… · ✓ Chain 5". Tested.
5. **Home.** The 16 pt lighthouse before the Fly subtitle, which rendered as the yellow sliver, is gone. There is at
   most one "New" badge (`HomeView.newBadge`): the Route once a lighthouse is reached, then Goals, the Daily, then
   the Birds. The caption keeps one colour on every visit.
6. **The done state.** On "Wings folded!" the title bird is fully folded and the diagram and gauge sit at the 118°
   fold target, live and in the demo (`SchoolStudioView.showsDoneFold`). On iPhone the drawing shows the press.

## P1
- **7. Short prompts.** Every school prompt is 7 words or fewer (tested on every step and variant), and the sub-lines
  are shorter. The mini diagram over the sea is cut; the fold ribbon and the Faster! fill teach the dive instead.
  The school's goal chip (stuck at "4.00 km") is cut too.
- **8. One vocabulary.** The Duo says fold / open and iPhone says hold / let go: "Fold going down. Open going up." /
  "Hold going down. Let go going up.". Tuck, dive, drop, soar and float are gone from instructions, praise
  ("Wings folded!"), the countdown, hints, the cover, Settings and the VoiceOver hints. "Perfect grip" became "Good
  grip" so "Perfect" means one thing. Tested.
- **9. Never cover the bird.** The Sea prompt moves to a low place on the bird page while the bird (+ 60 pt) is under
  it, with hysteresis so it doesn't flicker (`SchoolLayout.usesLowPrompt`, tested). It also clears the pause button
  and the dots.
- **10. Contrast.** The prompt cards, the Faster! label and Skip all sit on the navy scrim (cards at 0.86).
- **11.** The iPhone "Fun fact" Duo line is removed.
- **12.** `session=first:caught` flies run 1 headless to just before the catch, then live into it. Frame
  `s1-15b-caught` is in both scenario files.

## Tests
- AppTests `RoundEightTests` (11 tests): the numbering walk, the cascade, one story, the route, one badge, the done
  state, short and plain prompts, the prompt keeping off the bird, no Duo line on iPhone, and the demo holds.
- Updated R6/R7 expectations: copy, sub-lines, node labels and node count.

## Notes
- Tester 4's "black pill on the left edge" is the iPhone's Dynamic Island in landscape, not app UI.
- Not done: the Birds tile's detail still names the bird in use ("Gull" after unlocking the Tern).
