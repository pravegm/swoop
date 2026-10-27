# Swoop: Round 9 art (teach through the world, caught, polish, Route L→R), 27 Oct 2026

*Owner: Art Director. Scope: the look. The UX Lead's `design/UX-ROUND-9.md` (being written now) owns the flow, the steps, the copy and the timings; this file gives them the in-world pieces to build the flow from.*

*Sources:*
- *testers 6 and 7 (`design/fresh/`);*
- *every frame in `fresh3/duo` (Duo, 951 × 669 pt, mirrored: bird on the right) and `fresh3/phone` (iPhone 874 × 402 pt, not mirrored).*

*Coordinates are in points: Duo pt = display px × 0.476, phone pt = display px × 0.437. Tokens are from `ART-DIRECTION.md` and `ART-FLIGHT-SCHOOL.md`:*
- *`surface` `#0B2236`;*
- *reward gold `#FFD45E`;*
- *`accentOn` teal `#5CC2D6`;*
- *foam `#F2F7FA`;*
- *mist `#B6CCDA`;*
- *ink `#0E2438`.*

**Why "finished" is stuck at 6.**
- The art is liked ("Alto-grade mood"). What breaks it is **words doing the world's job**:
  - seven cards;
  - a "Faster!" bar and a slider nobody explains;
  - a ring nobody sees;
  - a storm that's mentioned but not shown;
  - a "caught" where the storm is still behind the bird.
- Then there is visible **unfinish**: truncation, overlap, units, drift and a placeholder look on Route.
- The rule for R9: **every teaching beat is a thing in the world, drawn in two colours: gold = fold, teal = open.** If a beat needs a sentence, it gets at most three words, and the world shows the meaning first.

## 1. In-world teaching visuals

### 1A. The guide gull (a ghost that flies each move first)

**Look.**
- The player's own bird silhouette (`BirdArt`, the same species) at **0.9×** its size.
- Fill: foam at α 0.38 (body) and α 0.30 (wings). No beak or tip colour.
- A **1.5 pt reward-gold outline** at α 0.85 (path stroke, round joins).
- A soft additive glow, 18 pt, `#FFD45E` at α 0.18.
- It reads as "a spirit of the bird", never as a second player.

**Trail.** A **dotted gold path**, the line to copy:
- 4 pt dots every 14 pt along its flown path, `#FFD45E` at α 0.75;
- each dot fades to 0 over 1.6 s;
- the dots stay on the water and sky after the ghost passes, so the player's bird can fly *through* them.

**Behaviour** (a Scene API; the UX sequences it).
- It flies the scripted move **one swell ahead**: start at player x + 0.55 × wavelength in the flight direction (Duo ≈ +420 pt, toward the sea page).
- It runs real physics with a scripted tuck curve, so its wings fold and open *visibly*. Its tuck is rendered with the same tuck-1 stretch.
- **Camera** during a demo: zoom ≤ 0.78 and a horizontal bias of 0.22 w toward the ghost, so the ghost and the player both stay on screen, ≥ 60 pt from every edge.
- **Hand-off:** the ghost finishes on the same swell type the player gets next. When the player's bird reaches the ghost's start point, the ghost dissolves into **10 gold motes** (4–7 pt, rising 40–80 pt over 0.8 s) and the dotted path stays.
- **Moves:**

  | Move | What the ghost does |
  |---|---|
  | `dive` | tucks at the crest, stays tucked to the trough |
  | `soar` | opens at the trough and launches |
  | `land` | descends wings open and lands inside the ring (§1C), firing a ghost Perfect: the ring in gold outline only, no sound |
  | `rhythm` | all three over two swells |

- **Reduce Motion:** the ghost still flies (it is the lesson), with no motes and no glow pulse.

### 1B. Fold and open cues drawn on the water (glyphs, not words)

Drawn in world space on the near sea, sized with the bird's zoom resistance (0.7). Fade in 0.25 s, fade out 0.3 s. Never under a card.

| Cue | Where | Spec |
|---|---|---|
| **Fold zone** | the downslope from the crest to 85 % of the way to the trough | a band **16 pt wide on the foam line, `#FFD45E` at α 0.55**, with a 6 pt additive edge glow at α 0.25. (The R6 ribbon at 12 pt / α 0.40 was invisible in s1-05.) |
| **Fold chevrons** | inside the fold zone, 10 pt above the foam line | 3 chevrons pointing *down the slope*: 18 × 10 pt, 3 pt round stroke, `#FFD45E` at α 0.95, 36 pt apart, travelling down the slope at 120 pt/s and looping |
| **Fold glyph** | at the crest, 34 pt above the foam line | the **mini book, closing**: two 14 × 20 pt rounded panels at a 110° angle with a 2 pt spine, gold `#FFD45E` fill and a 1 pt ink outline at 40 %. It animates 170° → 110° every 1.2 s (static at 110° under Reduce Motion) |
| **Open glyph** | at the launch point (the trough, rising into the upslope), 34 pt above the water | the **mini book, opening**: the same panels, 110° → 170°, in teal `#5CC2D6` |
| **Lift chevrons** | above the open glyph | 3 upward chevrons 18 × 10 pt, 3 pt, teal at α 0.95, stacked 14 pt apart, 0.15 s stagger |
| **Done mark** | a swell where the move was done right | the zone band turns *solid* gold behind the bird as it travels down the slope tucked: the progress is painted on the water. If the player opens early, the rest of the band greys to mist at α 0.4 and the ghost re-flies the move. On completion, a 14 pt gold bead with an ink tick floats 24 pt above that crest and drifts back with the sea |

### 1C. A landing ring you can actually see

The R6 ghost ring was drawn *under the bird*, flat and faint (s1-08 duo; absent on the phone). Replace it:

| Item | Spec |
|---|---|
| Place | the centre of the **next** downslope's Perfect window, **≥ 200 pt ahead of the bird** in the flight direction; respawns on the next downslope after a miss |
| Ellipse | 180 × 58 pt (1 : 0.32), stroke **4 pt `#FFD45E` at α 0.95**, an 8 pt additive glow `#FFD45E` at α 0.35, inner fill `#FFD45E` at α 0.12 |
| Breathing | scale 0.96 ↔ 1.04 at 1.2 Hz (static under Reduce Motion) |
| Drop marker | a vertical dotted line (3 pt dots every 9 pt, gold at α 0.7) from 96 pt above the ring centre down to it, topped by a 22 pt down-chevron (3 pt stroke) bobbing ±6 pt at 1 Hz |
| Camera | look-ahead bias 0.25 w toward the ring while it is live, so the ring is always on screen (≥ 80 pt from the edges) |
| Feedback | when the bird is within 120 pt above it, the ring brightens to α 1.0 and widens 1.1×. A landing inside turns it into the real Perfect ring plus a 12-mote gold burst; a miss fades it over 0.3 s |

### 1D. The phone diagram rides with the bird and visibly folds

- **The problem:**
  - the R6 diagram is front-on, so it barely changes shape (s1-03 and s1-04 look the same);
  - it sits 200 pt away from the bird, with a gauge over it;
  - it vanishes after step 2.
- **The fix:** a compact **wing diagram** that is *part of the bird*.

| Item | Duo | iPhone |
|---|---|---|
| Size | 96 × 64 pt | 80 × 54 pt (the touch phone: 80 × 40) |
| Anchor | bird + (0, −96) (above); if the bird's screen y < 0.30 h, bird + (0, +78) (below) | same, −84 / +70 |
| Follow | critically damped, τ 0.15 s; clamped inside the bird page, ≥ 28 pt off the fold band and ≥ 24 pt off the edges | inside the canvas, 20 pt margins |
| Shown | the whole of Flight School, plus the first 3 waves of the first real run; fades out over 0.6 s | same |

- **Projection:**
  - a 3/4 view, each panel rotated about the spine;
  - **exaggerated:** display angle `φd = min(1.6 · (180° − θ) / 2, 60°)`;
  - panel width × `cos φd`, top and bottom edges skewed by `0.18 · sin φd`;
  - inner faces darkened by `25 % · sin φd`.
  - At θ = 122° (full tuck) the panels show at 46°, so the fold reads at a glance.
- **Colour:** the panels tint reward gold at α 0.35 when tucked (u > 0.6) and teal at α 0.30 when open (u < 0.2), in the same language as the water glyphs. The angle gauge is **removed**.
- **Body:** `#DCE3EA` with a 2 pt ink rim at 40 %. No hands at this size.
- **During a ghost demo:** the diagram shows the *ghost's* pose as a dashed outline (5 / 4, foam at α 0.6). When it is the player's turn, it becomes solid and follows the live hinge.
- **Touch:** a landscape phone with a finger. Pressed: the screen tints gold at α 0.35 and a 40 pt ring appears in foam at α 0.6.

### 1E. "Faster!" bar and rhythm dots: removed, replaced by the world

- **Remove** the `Faster!` capsule (s1-05/06) and the rhythm slider with its 3 dots (s1-10, both devices). Testers read them as a loading bar and a media scrubber.
- **Speed is shown in the world:**
  - speed lines start at 600 pt/s in practice (900 in play);
  - the bird's trail turns gold as it reaches the dive target;
  - wind streaks (6 × 80–160 pt, foam at α 0.35) appear around the bird above 80 % of the target.
  - The fold-zone band filling solid gold behind the bird (§1B) is the progress.
- **Rhythm is shown on the sea:** the next three swells each carry their fold glyph and open glyph pair in sequence. A finished swell leaves its gold tick bead on the crest. Three beads mean the rhythm is learned. No bar.

## 2. "Caught": the storm visibly overtakes the bird

Today (s1-15b, both devices) the cloud is still behind the bird, the sun page stays bright, the meter and pause vanish, and a label floats over the water. New sequence, t = 0 at G ≤ 0:

| t (s) | Beat | Spec |
|---|---|---|
| 0.0–1.2 | **The front passes the bird** | the wall's leading edge sweeps from its position, *past* the bird, to **0.10 w from the ahead edge** (it covers 90 % of the width), ease-in-out. The rain curtain leads the edge by 60 pt. A crisp anvil rim crosses over the bird at t ≈ 0.5 |
| 0.3 | Meter | stays visible: the knob slides into the storm icon (fill → 0), the bar flashes coral `#FF7B6E` at α 0.6 for 0.25 s, and the storm icon sits *over* the knob. The HUD fades out from 1.6 to 2.0 s (not instantly) |
| 0.5–2.4 | **Light** | inside the wall: a wash of `storm top` at α **0.45** (was 0.30), the sun dims **70 %** and goes behind a rain veil (`rain` at α 0.35). Ahead of the edge, a 0.10 w strip keeps a warm horizon glow at α 0.6: *the light is still out there* |
| 0.9 | Lightning | one bolt *ahead* of the bird, inside the wall (proof the storm is now over and ahead), with a flash ≤ 0.14 |
| 0.6–2.4 | Bird | settles onto the water: tuck 0.6, head down, nose −4°, bob 2.5 pt. Body value −15 % (wet). 3 rain-ring ripples (ellipse 24 → 60 pt, foam at α 0.4) around it |
| 0.6–2.4 | Camera | +4 % zoom toward the bird (none under Reduce Motion) |
| 1.4 | Label | the UX line in a `surface` at 0.85 pill, `headline`, centred on the bird page at bird + (0, −110). Never over the sea page water |

**Constants (`SceneLook`).**

| Constant | Old | New |
|---|---|---|
| `stormCaughtEdge` | 0.62 | 0.90 (fraction of the width covered, measured from the storm side) |
| `caughtSweepTime` (new) | — | 1.2 |
| `caughtWashAlpha` | 0.30 | 0.45 |
| `caughtWashFarPage` | 0.6 | 1.0 (inside the wall) |
| `caughtSunDim` | 0.5 | 0.7 |
| `caughtEase` | 1.5 | 2.4 |
| `caughtHorizonStrip` (new) | — | 0.10 w at α 0.6 |
| `caughtRainCover` (new) | — | 1.0 |

The storm shade's hard vertical edge (s1-15b duo, x ≈ 600 pt) gets a feather: `stormShadeReach` 170 → 260.

## 3. Polish and consistency defect list

Owner: **S** = Scene, **A** = App. "duo" means the `fresh3/duo` frame and "ph" the phone frame.

| # | Frame | Element | Defect | Fix | Owner |
|---|---|---|---|---|---|
| 1 | duo/ph s1-01, s1-17 | Fly subtitle icon | a yellow sliver before the text (tester 6): the inline icon's frame collapses | the inline `LighthouseIcon` gets a fixed 12 × 16 pt frame, baseline −2 pt, 6 pt gap; or drop it | A |
| 2 | duo s1-01, s1-17 | "Leaderboards" label | labelled trophy, unlabelled gear | drop the text; both icons 48 pt with VoiceOver labels | A |
| 3 | duo s1-17 | Home sea | the foam line runs behind the Goals/Route/Birds row | Home camera: foam line y ≥ menu bottom + 24 pt, or the tile row on a `surface` at 0.9 plate | S |
| 4 | duo/ph s1-17 | "New" badge | straddles the tile's top edge; several on screen | inside the tile, top-right inset 8 pt, 11 pt `chip`; at most one at a time (UX picks which) | A |
| 5 | duo s1-03/04, ph s1-02–04 | Practice sky | the storm, rain and a muddy green-grey sun (≈ `#9EA37F` halo) during the first steps | the `practice` palette and no storm from step 0 (R6 SC1, not applied) | S |
| 6 | duo s1-03/04, ph s1-02–04 | Near sea | a thin grey surface line (not foam) and a **second sine line** through the water | one sea only during the Home → school crossfade; foam line `#FFFFFF` 3 pt | S |
| 7 | duo s1-03/04 | Diagram | front-on; doesn't change shape between unfolded and folded | §1D projection | A |
| 8 | duo s1-03/04 | Gauge | sits on the play bird; "fold" label over its wing | removed (§1D) | A |
| 9 | duo s1-03/04, ph s1-02–04, s1-12 | Cards | cover the bird (ph: the bird is hidden under the card) | no card within the bird's rect + 40 pt; with §1 there are almost no cards | A |
| 10 | duo s1-04 → s1-05 | Card anchor | jumps from the bottom to the top | one anchor: the top of the bird page, y = 0.16 h | A |
| 11 | duo/ph s1-03 → s1-05 | Pause | missing in steps 1–2, present from step 3 | pause visible from step 0, same position and style | A |
| 12 | duo s1-05 vs ph s1-07, s1-12 | Pause colour | blue `#2E4C78` in one frame, grey `#6B6A6E` in another (glass over a bright sky) | in play and school: solid `surface` at α 0.82 with a 1 pt hairline; glass only in menus | A |
| 13 | duo s1-07, ph s1-07 | Card fill | muddy grey on bright sky (α too low) | `surface` at α 0.92 everywhere | A |
| 14 | duo/ph s1-05/06 | "Faster!" bar | unexplained; white on peach | removed (§1E) | A |
| 15 | duo s1-05/08, ph s1-05/08 | Practice sun | blown out; the disk reads *darker* than its glow (an "eclipse" ring) | practice: `sunGlowSize` 520 → 360 and glow α 0.55; the disk drawn *above* the glow in `#FFFFFF` at α 1 | S |
| 16 | duo s1-05 | Fold ribbon | invisible | §1B | S |
| 17 | duo s1-08, ph s1-08 | Landing ring | under the bird / absent | §1C | S |
| 18 | duo s1-09 | Camera | the bird at 87 % down the screen at the Perfect, with a flat empty far-sea slab above | practice camera: bird y within 0.35–0.70 h; far-front fill darkens into near-mean over its lower 200 pt | S |
| 19 | ph s1-12 | Camera | no sky at all (the horizon is off the top) | horizon kept ≥ 0.15 h inside the top in practice | S |
| 20 | duo s1-09 | "PERFECT" card | a caps card, unlike the "Perfect ×N" callout in play | use the in-world callout and the real ring | A |
| 21 | duo s1-10, ph s1-10 | Rhythm slider | a scrubber, and it fills against the flight direction on the Duo | removed (§1E) | A |
| 22 | duo/ph s1-11–13 | Storm step | "A storm is chasing you" with no storm on screen | the wall rolls in from the bird page's outer edge (Duo x ≥ 760) over 2.0 s, *before* any words; a cloud glow at +1.2 s | S |
| 23 | duo s1-12/13, ph s1-12 | Step dots | sit on the meter knob | no dots in R9 (UX). If kept: y = meter bottom + 16 pt | A |
| 24 | all play frames | Meter | the red tick (R6 AP8 not done) | remove it; the coral end zone (last 15 %, α 0.35) only | A |
| 25 | duo s1-12–15 | Meter storm icon | white on a pale sky, low contrast | on a 26 pt `surface` at 0.62 disc, like the knob | A |
| 26 | duo s1-14 | Countdown | on the sea page (it should be on the bird page) | centred at the bird page's middle, x 727 | A |
| 27 | duo/ph s1-14 | Pills | two text pills at once; the objective pill overlaps the foam line | one pill at a time (UX), ≥ 24 pt above the horizon/foam line | A |
| 28 | duo s1-15 | Toast | covers the bird | toasts avoid the bird's rect + 40 pt; sea page, y 0.60 h (UX rule) | A |
| 29 | duo/ph s1-15 | Trail | a straight 700 pt pink "contrail" from off screen to the bird | clear the trail at run start and after a rebase; break the strand at any segment > 3 × `trailSpacing`/z | S |
| 30 | duo/ph s1-15 | Units | "63 m" beside "3.94 km" | one style: km with one decimal in the HUD distance and the goal chip ("0.1 km", "3.9 km") | A |
| 31 | duo/ph s1-15 | "NEXT LIGHTHOUSE" | an overline on a bright sky, low contrast; three rows on the sea page | drop it (the lighthouse icon says it) | A |
| 32 | duo/ph s1-13/15 | Goal chip | static at 4.00 km in school (tester 6) | live distance, or hidden in school | A |
| 33 | duo/ph s1-15b | Caught | the storm is still behind; the HUD vanishes; the label is over the water | §2 | S + A |
| 34 | duo s1-15b | Storm shade | a hard vertical edge at x ≈ 600 | `stormShadeReach` 260 (§2) | S |
| 35 | duo/ph s1-16 | Rank-up card | a card inside a card (outer r 40 plus inner r 28) | one `surface` card, r 28, padding 16 | A |
| 36 | duo/ph s1-16 | Truncation | "Fly 15 km in t…", "Kestrel He…", "Not flown…" | no `lineLimit(1)` on content text; wrap to 2 lines; goals as rows with leading 18 pt check/circle icons, not inline "· ✓" | A |
| 37 | duo/ph s1-16 | Decimals | 12.83 km, 2.17 km | results hero "12.8 km", lines one decimal (as ART-DIRECTION §6 already says) | A |
| 38 | duo s1-16 | Mini route strip | reads right to left; the bird pin sits under the first icon | §4: left to right, pin at the true fraction | A |
| 39 | duo/ph s1-16 | Card density | 8 text rows | ≤ 4 text rows plus buttons (UX decides which) | A |
| 40 | duo s1-18 | Route text | "…and on, as far as you can fly." prints over "30 km" | §4 label layout (16 pt minimum gaps) | A |
| 41 | duo/ph s1-18 | Route land | a murky green (`#2F4A3E`) found nowhere else | §4 dusk-headland palette | A |
| 42 | duo/ph s1-18 | Lighthouses | sit in coves (troughs) | on headlands (points) | A |
| 43 | duo s1-18 | Route layout | the bottom 45 % is empty; the header sits off centre at x 523 | §4 layout | A |
| 44 | duo/ph s1-18 | "Best" | shown twice; the pin chip overlaps the summary card (ph y 297 vs 304) | the pin chip only; ≥ 16 pt clear of the card | A |
| 45 | duo/ph s1-18 | Label baseline | labels ragged, following the coast | one baseline row (§4) | A |
| 46 | ph s1-02/03 | Title bird | crammed into the top 95 pt; the step dots overlap its left wing | iPhone title box y 24, height 0.30 h; no dots | A |
| 47 | ph all play | Touch glyph | a thin "M" outline that reads as a watermark (R6 §7.12 not done) | the §1D touch diagram during school; afterwards the 36 pt side-view gull on a 44 pt `surface` at 0.5 disc | A |
| 48 | duo/ph | HUD drift | the distance/goal stack and the meter shift ±10 pt between school and run frames | one `PlayLayout` for both (school just hides elements); constants from `ART-FLIGHT-SCHOOL` §6 | A |
| 49 | duo/ph s1-03–13 | Skip | duo: bottom-left on the sea page; ph: bottom-right; disappears on sunset (tester 6) | tertiary button on `surface` at 0.82, bottom outer corner of the *sea* page on Duo; ph bottom-right | A |
| 50 | duo/ph s1-15/16 | Copy marks | "The storm caught you" without a full stop; "=" in copy | UX copy; Art requires consistent sentence punctuation in pills | A |

## 4. The Route map reads left to right

- **This overrides the flight-direction rule in `ART-FLIGHT-SCHOOL.md` §5.**
- The mirrored play layout exists for the *blur*. A map is read like a sentence, so Route and the Results mini strip always read **start on the left → the far lighthouses on the right**, on every device and both bird sides.

| Element | Spec |
|---|---|
| Start | the harbour quay glyph at x = 48 pt, with the **storm glyph behind it at the far left** (x = 16, 40 pt slate anvil, 3 rain ticks): the storm chases from the start |
| Spacing | lighthouses evenly spaced: Duo 150 pt, iPhone 130 pt; first one at x = 150 / 130. Scrolls horizontally; on open, the next lighthouse sits at x = 0.60 w |
| Coast | along the top. Base y: Duo 150, iPhone 118. `y = base + 20 sin(x/170) + 10 sin(x/61 + 1.3)`, then each lighthouse x gets a **headland: a seaward point +34 pt** (a cosine bump 120 pt wide), so every lighthouse stands on a *point*, never in a cove |
| Land | the dusk-headland gradient `#3E4466` → `#2A2E4A` (matching the lilac sky and the navy UI), a sand rim 3 pt `#C9B98F`, and a foam line 1.5 pt `#FFF6E6` at 40 %, 4 pt seaward |
| Sea | `#12405C` → `#0B2A40`, 3 contours following the coast at +30 / +60 / +100 pt, 1 pt white at 6 % |
| Route line | 26 pt seaward of the headland tips. Flown: solid `#FFD45E` 2.5 pt with a 6 pt glow at 0.25. Ahead: 2 pt dashed mist at 45 % (6 / 8) |
| Icons | `LighthouseIcon` states (reached / next / unreached), 30 pt; the next one at 44 pt with a pulsing lamp |
| Labels | **one baseline row** at headland tip + 64 pt (Duo y ≈ 248, iPhone 212): the name in `body` (reached foam, next gold, ahead haze `#7896AB`), and "9 km" plus a ✓ on a second line in `caption` mist. Labels are laid out as rects with ≥ 16 pt gaps; a label that would collide shifts down one row (+40 pt), never overlaps |
| Tail | after the last lighthouse drawn, the dashed route continues 140 pt and fades to 0, ending in "…and on, as far as you can fly." on the **same baseline**, starting at last x + 140 |
| Best pin | the side-view "you" gull, 22 pt, at the true distance fraction between lighthouses, on the route line; "Best 12.8 km" chip 28 pt above the pin. The only place "Best" appears on the map |
| Header | top-left: back button at (32, 32), "Route" in `title` at x 88, both centred on y 56 |
| Bottom | Duo: two cards, one per page, never across the fold. **Left:** "Next: Kestrel Head · 15 km" with the 30 pt *next* icon. **Right:** "2 reached" plus the Fly button. Both y 520–628, `surface` at 0.92, r 28. iPhone: one bar y 318–382 |
| Fold | Duo: the scroll snaps so no icon centre or label rect is within x 447–503 |
| Fill | the map band runs from the coast top to y 470 (Duo) / 300 (iPhone): the sea and its contours fill the gap down to the cards. No empty half, no seam |

**Results mini strip** (s1-16):
- 56 pt tall, the same L→R logic: the last reached lighthouse at the left (24 pt reached icon), the next at the right (24 pt next icon), the route solid gold from the left to the bird pin at the true fraction, dashed after it.
- Left label: "Saltlight"; right: "Kestrel Head · 2.2 km to go" in `caption`.

## 5. Tasks

### Scene

| Task | Spec |
|---|---|
| **SR1** | `GuideGull`: the 0.9× ghost bird (fill α 0.38/0.30, 1.5 pt gold outline at 0.85, 18 pt glow at 0.18), the dotted trail (4 pt every 14 pt, α 0.75, 1.6 s fade), the moves `dive / soar / land / rhythm` with physics and a scripted tuck, the camera bias (zoom ≤ 0.78, 0.22 w toward the ghost), and the 10-mote dissolve |
| **SR2** | `WaterCues`: the fold band (16 pt, α 0.55, 6 pt glow at 0.25) with progress paint and the grey-out, fold chevrons (18×10, 3 pt, 36 pt apart, 120 pt/s), fold and open book glyphs (14×20 panels, 110° ↔ 170°, 1.2 s), lift chevrons, tick beads (14 pt) |
| **SR3** | The landing ring per §1C (180×58, 4 pt, glow 8 at 0.35, fill 0.12, breathing 0.96–1.04 at 1.2 Hz, the drop marker, ≥ 200 pt ahead, camera bias 0.25 w, brighten within 120 pt, burst / fade) |
| **SR4** | Caught per §2: the sweep to 0.90 w in 1.2 s, wash 0.45, sun dim 0.7, horizon strip, the bolt ahead at 0.9 s, the wet bird, rain rings, `stormShadeReach` 260, and the constants table |
| **SR5** | Practice fixes: the palette and no storm from step 0; one sea only; the practice sun (glow 360 at α 0.55, disk on top); camera bird y 0.35–0.70 h, horizon ≥ 0.15 h; the far fill darkening; the storm-step roll-in from x ≥ 760 over 2.0 s |
| **SR6** | Trail fix (clear at run start and on rebase; break segments > 3 × spacing/z); Home camera keeps the foam line under the menu |
| **SR7** | `birdScreenPoint` at ≥ 30 Hz (exists), plus `ghostScreenPoint` and `ringScreenRect` for the App's avoid-rects |

### App

| Task | Spec |
|---|---|
| **AR1** | `WingDiagram` riding the bird (§1D): 96×64 / 80×54, anchor rules, τ 0.15 s, the `φd` exaggeration, gold/teal tints, the dashed ghost mode, no gauge. Shown through school and the first 3 waves of run 1 |
| **AR2** | Remove the Faster bar, rhythm slider, step-dot collisions, the "PERFECT" card and the R6 gauge. School cards (if UX keeps any): top of the bird page at y 0.16 h, `surface` at 0.92, never within the bird, ghost or ring rects + 40 pt |
| **AR3** | Caught HUD (§2): the meter's knob-into-storm animation and coral flash, the HUD fade from 1.6 to 2.0 s, the label pill at bird + (0, −110) |
| **AR4** | Defects 1–4 and 7–14, 20–28, 30–32, 35–50 from §3 |
| **AR5** | Route redraw (§4): L→R, headlands, the dusk land, the baseline label layout with collision shift, the tail label, the single Best pin, the header, two bottom cards on Duo, the fold snap; and the Results mini strip L→R |
| **AR6** | CI frames: `school-ghost-dive`, `school-ghost-land`, `school-cues-fold`, `school-ring`, `school-diagram-tucked` and `-open`, `caught-0.6`, `caught-1.4`, `caught-2.4`, `route-duo`, `route-phone`, `results-strip`, each on the Duo (mirrored) and the iPhone |
