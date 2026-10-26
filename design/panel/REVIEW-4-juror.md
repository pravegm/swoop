# Review 4: Apple Design Award juror (R4 build, duo6 + r8)

**Score: 7.5 / 10 (R3: 6.5). Launch verdict: not yet. It is close.**

- **Feature:** I would now put it forward for "Great on iPhone Duo" once the one broken button (#1) is fixed.
- **Shortlist:** not yet. The two signature images, the storm and the tucked title bird, are better but not yet iconic.
- **What R4 got right:**
  - Results no longer clip; the two-page card layout is exactly right for the fold.
  - Text over the sun is solved: navy discs, foam type, Go at full size.
  - The storm now visibly chases: store-04 at a 77 % lead against store-07 at storm-close is a real difference.
  - One brand mark runs across the cover, cards, badges and glyphs.
  - The icon reads at 40 px.
  - Clouds have soft ends, the trail is clean, and the fold-to-fly fill shows amber on the Duo.

## R3 findings: status

| R3 # | Finding | Status |
|---|---|---|
| P0-1 | Results clip | **Fixed** (new void, #3) |
| P0-2 | "Paused at 0.0 km" | **Partly**: one formatter, but the values still disagree (#4) |
| P0-3 | Daily-card broken button | **Not fixed**: the Home icon floats above an empty tile (#1) |
| P0-4 | Storm shape and chase | **Partly**: the chase is fixed; the lens-shaped "saucer" anvil remains (#2) |
| P0-5 | Tucked title bird | **Partly**: no legs now, but it reads as a manta ray or kite (#5) |
| P0-6 | Text over the sun | **Fixed** |
| P1-7 | Hard-ended cloud streaks | **Fixed** |
| P1-8 | Sea slab | **Partly**: the lace is barely visible; store-07 and 14 are still slabs |
| P1-9 | Jagged chop / Results sea | **Partly**: storm-close is smooth; the Results sea is still a ridge (#7) |
| P1-10 | Caught edge in the fold | **Fixed** |
| P1-11 | White burst, star confetti | **Mostly**: store-29's backdrop still shows the spiky burst; store-16 still swarms with stars |
| P1-12 | Callouts detach | **Fixed** |
| P1-13 | Duo countdown states | **Fixed** (store-21 holds on 3; Go at size) |
| P1-14 | Fold fill invisible | **Fixed** |
| P1-15 | Meter and world disagree | **Fixed** (one map) |
| P1-16 | Four bird marks | **Fixed** |
| P1-17 | Muddy cover strip | **Fixed** |
| P1-18 | Daily card void | **Partly**: the share card fills the bird page, but the far card still has a void |
| P1-19 | Birds page | **Not fixed** (#8) |
| P1-20 | Attract bird over text | **Not fixed** (#9) |
| P1-21 | Overlay surface colour | **Fixed** |
| P1-22 | Trail cap | **Fixed** |
| P2-23/24 | Icon, badges | **Fixed** (icon at 40 px; one mark in badges) |

## P0

1. **The Home button is broken on every Daily card.**
   - Where: store-27, store-29, and iPhone daily-card, daily-results and results-daily-card-fresh.
   - The secondary row is a wide button plus an empty 56 × 56 tile, with the house glyph drawn ~16 pt *above* the tile, outside it. This is the third round this row has been broken, and it is on the screen people share.
   - **Fix:**
     - One `HStack(spacing: 8)`: the secondary button at `maxWidth: .infinity`, then `IconButton("house.fill")` with a 56 × 56 frame, the glyph centred, 20 pt.
     - Add a snapshot test that asserts every glyph's frame is inside its button's frame.

## P1

2. **The storm's anvil is a flat lens ("saucer") and the body reads as chimney smoke.**
   - Where: store-02–06, 11, 15–24, duo-01–08, and every iPhone gameplay frame. In store-07 and storm-close, the anvil's flat underside makes a hard horizontal edge behind the HUD (y ≈ 148 pt).
   - The billows are dark grey-brown `#3A3A40`-ish puffs, which read as smoke because they have no sunlit tops.
   - **Fix:**
     - **Anvil:** give it a lobed, scalloped underside (5–7 shallow 30–60 pt bumps) that blends into the column, with no straight edge. Fade its far tip to α 0 over 120 pt.
     - **Billows:** light each one from the right with a rim of `#FFD9A6` at 0.35 on its top-right edge. Lift the body to `#4A5468` with a vertical gradient to `#2A3040` at the base.
     - **HUD:** clip the anvil to y ≥ 120 pt (Duo) so it never runs behind the HUD.
3. **The far Results card has a ~190 pt empty void** between the stats and the Daily row (store-08, 25–28, duo-ui-results, and all iPhone results).
   - Fix:
     - Size the card to its content and bottom-anchor it (top inset ≥ 32 pt).
     - Or use the void for a 120 pt sea-profile strip with lighthouse dots, the share-card art, which is the most beautiful thing the app makes.
4. **Distances disagree on one screen.**
   - Where:
     - store-35: HUD 99 m, card "Paused at 101 m";
     - store-41: HUD 91 m, card "99 m";
     - iPhone closing-duo: 79 m against 81 m.
   - Fix: the pause card and the HUD read the same frozen `pausedMeters`. Freeze the HUD's 4 Hz throttle on pause, so it shows the exact value.
5. **The tucked title bird reads as a manta ray or kite** (store-17, duo-ui-home-tucked, iPhone home-folded).
   - The legs are gone, but the wings balloon *outward* into a rounded diamond. The two white trailing-band strokes still hang down beside the tail like legs.
   - It should read as a gannet entering the water: narrower and longer, not wider.
   - **Fix:**
     - the dart at 0.18 w wide and 1.15× the spread body length;
     - a straight leading edge from shoulder to tip at 18–22° off the body axis, with the trailing edge hugging the body;
     - hide the white trailing band past tuck 0.4;
     - tips black `#2B2F36` and meeting 0.12 h behind the tail.
   - Review it as a 5-step strip before shipping.
6. **On iPhone, "Fly again" lost its label.** The primary action is now a 56 pt gold square with only a ↻ glyph, while "Daily" gets a text label (results, results-rankup, results-fresh, results-foldfill-duo).
   - Fix:
     - a full-width gold `Fly again` button (label plus glyph);
     - underneath it, one secondary row of Daily · Home · Share, each 48 pt.
7. **The Results and caught sea is still a "mountain ridge"** with 6–10 bumps across the bird page (store-08, 14, 25–28; iPhone caught and results).
   - Fix: freeze Results on one calm swell (amplitude ≤ 60 pt, wavelength ≥ 500 pt) and lower the chop to ≤ 4 pt once caught.
8. **Birds.**
   - Storm Petrel is still a black blob on navy (store-10, duo-ui-birds, iPhone birds). Fix: key rim `#DDE6FF` 1.5 pt, a 28 pt halo of the horizon colour at 0.18, and its preview sky lifted 15 %.
   - The Gull preview still clips its upper wing at the frame's top edge (store-39, birds-fresh). Fix: scale ≤ 2.2× and centre at y 58 %.
9. **The attract bird still flies through text.**
   - duo-ui-home-tucked: through "Swoop".
   - store-18: through the caption.
   - iPhone home, home-duo-layout and home-mirror: through the wordmark.
   - Fix: hide it (fade over 0.2 s) whenever its rect + 24 pt meets any text rect, or keep it in y ≥ 72 % on Home.
10. **Fresh-tried Daily shows "0 m" as a hero and on the share card** (results-daily-card-fresh).
    - Fix: hero "Tried", the line "Today's try is spent", no share card; Share becomes secondary and Practise primary.
11. **The iPhone fallback has three problems.**
    - **pose.png is a blank navy portrait.** The portrait TurnCard draws nothing. Fix: verify the portrait layout; pose-phone also draws a *folding book* for a non-Duo iPhone, so draw a phone rotating instead.
    - **touch-wing:** the brand-mark glyph sits right under the bird. Fix: move it to the bird page's lower outer corner (x 82 + 28, y h − 44) per UX §10.
    - **"Storm ←→ you" overlaps the bird** in the countdown (countdown, countdown-short, countdown-flat-duo, nudge). Fix: put it on the meter's right end, or drop it during the countdown.

## P2

12. **The splash word is not visible.** No "Splash" word near the bird in splash-mark or store-43. Freeze 0.15 s after the splash event to prove it ships.
13. **Wrong frame for the open hint.** iPhone hint-open shows the *fold* hint. Freeze on `hintOpen`.
14. **Callout over the lighthouse.** store-06: "Perfect ×10" sits on the lamp. Keep the callout clear of prop rects + 16 pt.
15. **Truncated Goals tile.** It reads "Crest… / 1 of 3 goals" on iPhone and Duo (home-duo-layout, store-01). Use "Goals" as the title and the rank as the subtitle, as in R3.
16. **The meter's bird mark is tiny.** It is ~14 pt and reads as a tick. Make it 20 pt with a foam 1.5 pt stroke on a 24 pt navy dot.
17. **Store composites are still unproven.** They exist in CI (store-R4) but none has run. A juror judges the store page first, so make that first run happen before launch.

## Top 8 for Round 5

1. Fix the Daily-card Home tile on both platforms, with a glyph-inside-button snapshot test (#1).
2. Make the storm read as weather: a scalloped anvil clipped off the HUD, sunlit billow tops, lifted body values (#2).
3. Turn the tucked title bird into a gannet dart: narrow, long, no white bands below tuck 0.4 (#5).
4. Fill or remove the far Results card's void; restore a labelled full-width Fly again on iPhone (#3, #6).
5. One frozen distance across the HUD, pause and closing cards (#4).
6. A calm Results sea; less slab in storm frames, with lace at α 0.35 and longer streaks (#7, R3 P1-8).
7. Birds legibility; keep the attract bird off text; a non-zero Daily hero (#8–10).
8. The iPhone fallback (blank TurnCard, touch glyph, meter label), then the first real store-composite run (#11, #17).
