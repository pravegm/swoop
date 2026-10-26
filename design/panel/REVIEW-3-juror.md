# Review 3: Apple Design Award juror (Delight and Fun, Visuals and Graphics, Interaction, Innovation)

**Score: 6.5 / 10. Launch verdict: not yet.**

- **Shortlist:** no, not in this build.
- **Featured in "Great Apps and Games on iPhone Duo":** yes, I would put it forward once the P0s below are fixed. The idea is the strongest Duo concept on the table: the halves *are* the wings, the cover display holds the paused run, fold-and-open flies again, and seated play splits into a deck.
- **What holds it back from a shortlist** is craft, not concept:
  - the antagonist (the storm) and the hero material (the sea) still look like placeholder vector;
  - the signature moment (the first fold on Home) draws a stick figure;
  - text still clips on the screen players see most (Results).

**What R3 got right** (visible against duo3): the Golden Hour sky (no more mud) and the Moonrise discipline; the navy/foam/gold UI system and type scale (store-08's hierarchy is App-Store-grade); the Perfect ring riding the bird; the mid-run cover (duo-06/07), a real Duo-first answer; the seated split deck (store-34) and the pose card; correct mirror mode; storm-close (store-07), the best frame in the game.

## P0 (blocks launch or feature)

1. **Results still clips. This is UX-spec P0 #4, carried over unfixed.**
   - **Duo:**
     - store-08 and store-28: the 3rd goal is hidden behind the Daily row (a sliver shows at y ≈ 535 pt);
     - store-25 and store-26: "New goals: Fly 3 km · 3 Perfects in one flight · Chain 2…" is cut mid-glyph;
     - store-27: the logbook line is cut.
   - **iPhone:**
     - results shows 1 of 3 goals;
     - results-rankup stops at "Rank up! You're a";
     - results-fresh loses "New: Tern".
   - **Fix:**
     - The stats block goes in a `ScrollView` with the buttons pinned, or `ViewThatFits` with a compact variant.
     - On iPhone (402 pt), goals collapse to one line: "2 of 3 goals · next: 32 Perfects".
     - The logbook caps at "New in the logbook: Farthing Light +8".
     - Add a CI check that fails on any `Text` truncated or clipped by its container.
2. **"Paused at 0.0 km." while the HUD reads 89 m** (store-35, closing-duo).
   - Fix: pass the live distance and use the HUD formatter, so under 1 km it reads "Paused at 89 m".
   - A juror who sees this on the first close stops trusting the Duo states.
3. **The iPhone daily-card has a broken button.** Between Share and Home sits an empty 24 pt sliver: "Practise today's sea" has collapsed (daily-card).
   - Fix: give it a 48 pt min width and the label "Practise", or stack the secondaries under Share.
4. **The storm wall is still a stack of pancakes under a flat disc.**
   - Seen in store-01–06, 11, 13, 16, 20–24, duo-01–08, and every iPhone gameplay frame. It is unchanged in silhouette since duo3 store-04.
   - It is the game's only antagonist, on screen 100 % of the time.
   - It also does not chase. Its edge sits at x ≈ 115 pt at a 77 % lead (store-04) and at x ≈ 160 pt at a 9 % lead (duo-03).
   - **Fix:**
     - **Shape:** draw it as one shelf-cloud path. The anvil overhangs the body by 1.4×, with a tapered lip (no disc rim). There are 6–7 lobes with radii from {1.3, 0.7, 1.1, 0.6, 1.4, 0.9}.
     - **Colour:** a vertical body gradient `#3A4252` → `#262C38`, and a 3 pt `#FFD9A6` rim only on the anvil's sun-facing top.
     - **Motion:** a slow roll of 4 pt/s on the lobes.
     - **Position:** drive the edge x from closeness, `x_edge = 40 + 360·c` pt (Duo). That way the meter and the world tell the same story.
5. **The tucked title bird reads as a stick figure with legs** (store-17, duo-ui-home-tucked, iPhone home-folded).
   - This is the pitch frame. The player folds the phone and the bird must become a diving gannet. Instead the wings drop to −50° as 30 pt-wide sticks with white "feet" (the mirrors).
   - **Fix (ART §7):**
     - sweep the wings *back*, not down: the leading edge at ≤ 30° below horizontal, so it reads as an arrowhead;
     - keep the chord ≥ 0.6 (it is ~0.25 now), with the tips meeting 0.18 h behind the tail;
     - hide the mirrors at tuck > 0.5;
     - add a 6 % stretch on the body.
   - Review it as a 5-step strip (u = 0, 0.25, 0.5, 0.75, 1) before shipping.
6. **Text and the Ready ring are illegible over the sun.**
   - Where it happens:
     - store-36 and iPhone reopened-ready: "Spread your wings" is about 1.3 : 1, and the gold ring sits on the sun, which Art bans;
     - iPhone countdown and countdown-flat-duo: the caption is yellow on the sun glow, so it is invisible.
   - **Fix:**
     - put the ring and numeral on a 128 pt disc of `#0B2236` at 0.62;
     - set the labels in `#F2F7FA` with a `#04121F` 45 % r 6 shadow;
     - anchor them at the far page's x centre, y 28 %, which is always above the sun clamp.

## P1

7. **Cloud streaks are hard-ended rectangles** in every gameplay frame (store-04 at y ≈ 145 pt ends square at x 778 pt; store-20 crosses the whole frame).
   - Fix: a 120 pt alpha ramp at both ends, a 3-stop vertical profile, lengths 300–700 at random, at most 4 on screen, α 0.30.
8. **The near sea is a featureless slab covering 40–55 % of the frame** (store-02, 05, 12, 16, duo-04). Pillar 3, "water is the hero", fails.
   - **Fix:**
     - a depth gradient `#1C5A7C` → `#0A2B44` over 260 pt below the crest;
     - lit faces at α 0.12 (0.06 does not read);
     - 6–10 lace streaks (1.5 pt, `#FFF6E6` α 0.25, 40–120 pt) at parallax 1.0;
     - the glitter column continued into the near sea under the sun.
9. **Storm chop and the caught sea are a jagged polyline "mountain ridge"** (store-07, 14, 08, 25–28, iPhone caught and results).
   - Fix: Catmull-Rom the chop at ≤ 6 pt spacing with wavelength ≥ 60 pt.
   - The Results backdrop should freeze on a calm swell, not the chop.
10. **The caught wall edge rests on the fold band** (store-08 and store-25–28: spikes at x 468–520 pt; store-14: edge ≈ 528 pt). The spikes are tiny-radius lobes that read as a starburst.
    - Fix: end the sweep at ≥ 570 pt as specced, and set the minimum lobe radius to 0.6×.
11. **The Perfect and attract-landing burst is still a ~100 pt white spiky blob** (iPhone skim, duo-ui-home-open), and 4-point star confetti swarms the bird (store-02, 15, 16, store-18 trail). The bird loses its ΔL\* at the exact reward moment.
    - Fix: use the splash frame's hard drops (it is right), plus one mist puff ≤ 90 pt at α 0.5. Allow ≤ 6 gold `#FFD45E` 4-point stars per Perfect, and none on the trail.
12. **Callouts detach from the bird.**
    - store-03 and iPhone soar: "Perfect ×4" is ~250 pt below the airborne bird, left at the touchdown point.
    - store-15: "Tailwind!" is ~195 pt above the bird.
    - Fix: re-anchor every frame to `birdPoint + (40, −64)` with τ 0.08 s for the full 0.7 s life.
13. **The Duo countdown states are wrong.**
    - store-21 (`flat`) shows "2 · Wings open, hold steady"; it should hold on 3 with "Bend it a little, like a book". store-22: "Go" is ~45 pt (the token is 120) and keeps the "hold steady" line.
    - Fix: Go at 120 pt Heavy with a 0.3 s pop (spring 0.28 / 0.62), and no sub-line.
14. **Fold-to-fly has no visible feedback on the Duo.** store-28 at `foldFill=0.6` shows a ~4 % sliver; the iPhone frame shows ~60 %.
    - The live hinge reading probably overwrites the demo value. Verify it on device.
    - This is the Duo's signature restart and must read across the room.
    - Fix: fill `#FFF3C4` → `#FFD45E` left to right with a 2 pt bright leading edge, plus a small two-panel fold glyph that closes with u.
15. **The lead meter and the world disagree in the real-hinge pass.** The meter sits at ~9 % from 224 m (duo-01) to 12 km (duo-08). There is no rain on the left half, no thunder state and no storm advance.
    - Check that `Tuning.leadMeterScale` (5.0, Core NEEDS) is the value the App reads, and that the meter updates under hinge input.
16. **One bird, one brand.** There are four marks:
    - the dorsal gull (icon, title);
    - a "V" chevron (cover, closing card, About, the iPhone wing glyph, which reads as "chevron-down");
    - the old dove "V" (badges);
    - the side-view gull.
    - Fix: derive one 2 pt rounded-stroke glyph from the icon gull's dorsal "M" and use it everywhere except gameplay.
17. **The cover horizon strip is mud.** It renders as a brown band of about `#4A3214` (store-30–33, duo-06/07, duo-ui-cover), and in cover-results it runs behind "Open to fly again" and Share. This is the gold-at-partial-alpha trap Art bans.
    - Fix: `#F2A65A` with `.plusLighter` at 0.18, 40 pt tall, placed 24 pt below the last control.
18. **The Duo Daily card has a 210 pt empty void** mid-card (store-29).
    - Fix: put the share card's sea profile there (UX A9), 120 pt tall with lighthouse dots. Make it the hero; it is the Wordle moment.
19. **Birds page.**
    - The Storm Petrel preview is dark on navy and illegible (store-10, iPhone birds). Fix: key rim `#DDE6FF` 1.5 pt plus a 28 pt halo.
    - The Gull preview clips its wing (store-39). Fix: cap the scale at 2.4×.
    - Tile suns still sit on the birds' heads. Fix: sun at (80 %, 22 %), r 12 %.
20. **The attract bird hits text.**
    - store-18: it overlaps the title bird's wing.
    - iPhone: it crosses the caption (home-returning), the wordmark (home-folded) and the icons (home-flat-duo).
    - Fix: hide the attract bird whenever its rect intersects any text or icon rect + 24 pt, and keep the run within y ≥ 70 %.
21. **Overlay surfaces change colour with the backdrop.** The hint pill (store-23) and the lighthouse toast (duo-03) render grey-brown, while store-06 and duo-01 are navy.
    - Fix: solid `#0B2236` at 0.8 with no backdrop blur.
22. **The trail has a hard square cap and a colour step at the bird** (store-23, duo-04: blue → pink at x ≈ 120 pt).
    - Fix: taper the 24 pt nearest the bird and use one gradient along the length.

## P2

23. **Icon (AppIcon-1024).** Concept A is the right idea and reads instantly at 180 px: storm against sun, bridged by a gull. At 60 and 40 px, though, the bird collapses to a dash with a white dot (it covers ~9 % of the icon's height). The 22 px ink contour (~2.1 %) makes it look like a sticker, the mirror dots read as eyes, and the sun is a flat disk.
    - **Fix:**
      - **Bird shape:** span 0.88, a shoulder chord ≥ 0.11, and dihedral +10° / −4° so it reads as an "M".
      - **Bird details:** a 15 px `#0E2438` contour, and one mirror dot per wing.
      - **Sun:** an additive glow of `#FFC46B` at 0.35 r 1.6×.
      - **Sea:** a foam line that rises slightly to the right, as a swell.
      - **Delivery:** ship Icon Composer layers (bird as foreground) for tinted and clear modes.
24. **Badges.**
    - lighthouse3 reads as rockets or obelisks;
    - the cloud is a puffball (Art bans these);
    - the sea band stops short of the rim with hard vertical ends (x ≈ 235 / 775 of 1024), so clip it to the disc;
    - use the one brand gull (#16).
    - Also, the `badges` CI frame captures Home, not the sheet.
25. **Title bird.**
    - The beak tip reads as a party hat. Fix: a darker `#D8862A` lower mandible and a visible head contour.
    - The vertical chord shading isn't visible. Fix: a +12 % leading edge.
26. **The crease glint spans ~260 pt vertically in flat captures** (store-15, 24), where it looks like a rendering seam.
    - Fix: confine it to ±40 pt of the horizon per spec, and disable the gutter shade in store-capture mode.
27. **Small content and demo fixes.**
    - store-31: "🔥 3" sits alone in a row. Make it a chip in the Daily row.
    - iPhone Birds tile reads "Storm Pe…".
    - Demo data contradicts itself in store frames: "FIRST FLIGHT" at 12.8 km with 17 Perfects, and "Logbook 0 of 40" at rank 13.
    - ART A14 is not done: there is no hands-on-Duo store frame 1 and no 160° / 125° pair. Without them the store page cannot show the gesture, and the gesture is the whole game.

## Top 8 for Round 4

1. **Nothing clips, nothing lies.** Rebuild the Results and Daily cards (Duo and iPhone) with a CI truncation check; fix "Paused at 0.0 km"; fix the iPhone daily-card button (#1–3).
2. **A storm worth outflying.** One shelf-cloud silhouette with a sunlit anvil, an edge driven by closeness (`40 + 360·c` pt), a caught edge at ≥ 570 pt, and meter/world agreement on the hinge pass (#4, 10, 15).
3. **Make the first fold the hero shot.** The tucked title bird becomes a swept arrowhead (chord ≥ 0.6); the fold-to-fly fill reads on the Duo; the flat countdown hold works (#5, 13, 14).
4. **Water is the hero.** Kill the slab with a depth gradient, lace and lit faces; Catmull-Rom chop; a calm swell behind Results (#8, 9).
5. **Remove the cheap tells.** Feathered cloud streaks, hard-drop splashes in place of the white burst, ≤ 6 gold stars, a tapered trail cap, solid overlay surfaces (#7, 11, 21, 22).
6. **Legibility over light.** The Ready ring, countdown and captions sit on navy discs at y 28 %; callouts track the bird (#6, 12).
7. **One bird mark** across the cover, cards, badges and glyphs; a plusLighter cover strip; Daily card hero art; Birds preview legibility (#16–19).
8. **Store and icon.** Icon refinements for 60/40 px plus Composer layers; the A14 hands-on-Duo frame 1 and the 160° / 125° pair (#23, 27).
