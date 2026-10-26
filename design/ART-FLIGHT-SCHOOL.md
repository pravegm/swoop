# Swoop: art for Flight School, the route and the mirrored default (Round 6, 27 Oct 2026)

*Owner: Art Director. Scope: the look of the D1–D4 work in `design/ROUND-6.md`. The UX Lead's `design/UX-FLIGHT-SCHOOL.md` owns states, copy, timings and flow; it did not exist when this was written, so the assumptions are listed at the end. Builds on `design/ART-DIRECTION.md` (tokens, palette, motion), whose names are used here: `surface`, `surfaceRaised`, `stroke`, `accentOn`, reward gold, and the `SwoopType` sizes. Frames reviewed: r10 (iPhone 18 Pro, 874 × 402) and duo6 (Duo 951 × 669), mirror frames `store-12` and `mirror-flight`.*

**Canvases.**
- Duo: 951 × 669 pt, crease x 475, art fold band x 447–503.
- iPhone: 874 × 402 pt.

**Default page names (mirrored, D1).**
- The **bird page** is the RIGHT half of the Duo, the sharp one, x 503–951.
- The **sea page** is the LEFT half, ahead, x 0–447: this is the page that blurs.
- If Wing check or Settings flips the side, every rule here mirrors, with no exceptions.

## 0. Where R10 stands (what this round fixes)

- **Better since R3:**
  - the 5-stop skies;
  - thin far swells;
  - the title bird's "M" wings with mirrors;
  - the callout outline;
  - the ribbon trail;
  - the gold budget.
- **Still unclear at a glance** (founder: "half baked"):
  - Nothing on screen says *where we are going*. There is no goal on the HUD, and the lighthouse is only a passing card.
  - The storm reads as rows of grey river stones (storm-teach, meter-label, home), not weather.
  - The meter carries an unexplained red tick, and its knob is an "M" logo in a navy disc that reads as an eye.
  - Three bird marks compete: the dorsal "M" in the knob and the touch glyph, the SF `bird` symbol (a dove) on Birds and Goals, and the side-view bird in play.
  - The pose card's "phone" is a gradient pill (pose-phone).
  - Results stack two cards (rank-up, logbook) above the objective.

## 1. The live phone diagram (Flight School steps 0–3, Wing check, pose cards)

One SwiftUI component, `DuoDiagram(angle:, target:, sharpSide:)`, used everywhere a phone is drawn (it replaces the pose-card pill).

**Purpose.** At a glance: *a Duo, held like a book, folding as I fold.*

**View.**
- A 3/4 view from slightly above and in front.
- Two screen panels hinged on a vertical spine. Each panel is a parallelogram rotated about the spine by `(180° − θ) / 2`, projected with a horizontal scale of `cos(φ)` and a top/bottom skew of `0.18 · sin(φ)`, so the near (outer) edges read taller.
- θ is the live filtered hinge angle (the same filters as play), clamped to 100–180°.

| | Duo (on the bird page) | iPhone (pose card only) |
|---|---|---|
| Box | 240 × 170 pt | 180 × 128 pt |
| Position | centred at (727, 300), the bird page's middle | the left half of the pose card |
| Spine | 8 pt wide rounded rect `#9AA5B1`, height 0.86 box | same, scaled |
| Device body | fill `#DCE3EA`, 4 pt corner, 3 pt rim stroke `#0E2438` at 40 % | same |
| Screens (inset 7 pt) | sea panel: the current sky gradient (2 stops: zenith → horizon) with a 2 pt sea strip; bird panel: the same, plus a 22 pt side-view bird in white facing the flight direction | same |
| Hands | two mitten silhouettes holding the outer edges, `#B6CCDA` (mist, deliberately not a skin tone), 2 pt `#0E2438` at 30 % outline, thumbs on the front face | none (the iPhone shows a finger: §1 touch) |

**The target ghost.** When a step waits for a pose (step 0 open book, step 1 tuck), a ghost of the target pose draws behind the live diagram.
- 2 pt dashed outline (6 / 5), foam at 45 %, no fill.
- It eases from the live angle to the target and back: 1.4 s per cycle, ease-in-out, a 0.3 s hold at the target.
- The ghost stops the moment the live angle is within 6° of the target. A 0.25 s check pulse plays: the outline turns `accentOn` `#5CC2D6`, the device scales 1.0 → 1.04 → 1.0 (spring 0.3 / 0.6), and an 18 pt check glyph appears over the spine.

**Angle gauge.** A 140° arc under the diagram, radius 74 pt, 6 pt stroke:
- the "open" band 150–180° in `accentOn`;
- the "tucked" band 100–122° in reward gold `#FFD45E`;
- in between, `#FFFFFF` at 14 %.
- A 10 pt foam needle shows the live θ. Small 12 pt Bold mist labels "open" and "fold" sit at the band ends.
- The gauge hides on Wing check and after step 3.

**Flat warning (D1.4).** At θ ≥ 174°, the panels tint `#FFFFFF` at 10 % and a 1.5 pt coral `#FF7B6E` underline appears under the gauge's flat end. Never a red fill.

**Reduce Motion.** No ghost oscillation: the ghost sits static at the target. The check is a crossfade.

**Touch variant (iPhone).**
- A flat landscape iPhone, 180 × 88 pt, body `#DCE3EA`, screens as above.
- A finger glyph (mist mitten, 36 pt) presses the screen's lower outer corner.
- Pressed: a 56 pt ring in foam at 60 %, radius 22 → 30 over 0.2 s, and the mini bird inside tucks (the same art, tuck 1).
- The ghost hand repeats the press and release every 1.6 s until the first hold.

**Wing check (step 2) art.** The question asks *which side stayed sharp*, so each page *is* its own answer button. Each page fills with one tappable card:
- `surface` at 0.92, radius 32, inset 32 pt from the outer edge and 28 pt from the fold band.
- Inside, a **sharpness test pattern**: a 160 × 100 pt block of 1 pt foam hairlines at 4 pt pitch (horizontal), crossed by a 44 pt "Swoop" wordmark. Blur is obvious on it; sharpness is too.
- A big outward arrow (`arrow.left` / `arrow.right`, 40 pt) and the UX label in `headline`.
- Between the cards, on the fold, a 22 pt `DuoDiagram` mini at θ 150° with a soft blur on one half that alternates sides every 1.2 s: it illustrates "one half goes soft", without claiming which.
- "Neither / skip" is a tertiary text button centred at the bottom, y = h − 40.

## 2. The calm practice sea

**Look.** The same world, in **"Morning practice"**: brighter, softer and stormless. It says *safe, rehearsal*.

| Role | Hex | Role | Hex |
|---|---|---|---|
| zenith | `#3D6FB0` | far-back sea | `#A9C4D8` |
| mid (0.45) | `#9DB7D9` | far-front sea | `#6E9FBE` |
| low (0.80) | `#F5D3B0` | near crest / lit face | `#4FA3BF` |
| horizon (0.96) | `#FFE7C2` | near mean | `#2A7392` |
| sun disk / glow | `#FFF8E6` / `#FFD99A` | near deep | `#123E58` |
| cloud streaks | `#FFFFFF` at 0.35 | foam | `#FFFFFF` |
| glitter | `#FFF6D8` | bird key rim | `#FFE9BE` |

- Add it to `ScenePalette` as `practice`. It is not a selectable sky.
- **No storm at all** until step 7: no wall, no sky shade, no rain, no chop.
- **Swells:** long and even, wavelength 760 pt, amplitude 70 pt, one at a time. The far layers show at 70 % alpha (calmer), and the sun sits higher (`sunLiftFraction` 0.16 → 0.24).
- **0.8× time** shows as nothing but the slower world: no vignette, no slow-motion bars. The founder asked for calm.
- **Step 4 ("Soar"):** the air slow-mo (UX timing) adds a soft 6 % white bloom at the bird's half-page, the only visual cue.

**Guides on the water.** They are scene sprites in world space, fading in 0.3 s and out 0.25 s.
- **Fold path (step 3):** along the downslope ahead of the bird, a 12 pt-wide glow ribbon *on* the foam line, reward gold `#FFD45E`. Alpha 0.40 at the crest, falling to 0 at the trough, with a slow travelling shimmer (1.2 s). It says "fold along here".
- **Open mark (step 4):** at the trough, a 3-chevron "lift" mark pointing up and ahead (`#FFFFFF` at 70 %, each chevron 14 × 8 pt, 2.5 pt stroke, 0.15 s stagger loop).
- **Landing target (step 5):** a ghost Perfect ring on the next downslope: a 1 : 0.32 ellipse 150 pt wide, 2.5 pt dashed foam at 60 % (8 / 6), breathing 0.97 ↔ 1.03 at 1 Hz. When a Perfect lands *in it*, the real gold ring plays over it, and the ghost bursts into 8 motes.
- **"Faster!" meter (step 3):** a 140 × 10 pt capsule 46 pt above the bird. The fill runs from `accentOn` to reward gold as speed rises, with gold speed lines from 70 %. It sits on the bird page only.
- **Rhythm bar (step 6):** 132 × 8 pt, 38 pt under the bird. Wave segments alternate fold (reward gold) and open (`accentOn`); a 3 pt foam playhead follows the bird's x through the current wave. Past segments dim to 40 %. One segment per wave, three waves.
- **Step dots:** eight 7 pt dots, top centre of the bird page, y = 28. Done: foam. Current: reward gold, 10 pt. To do: `#FFFFFF` at 25 %. No other HUD during steps 0–6.

**Step 7, the storm arrives.**
- Over 2.0 s ease-in-out, the palette crossfades from `practice` to the player's sky.
- The storm wall rolls in from the bird page's outer edge, at `stormEdgeFar` (70 pt in, 0.42 height).
- One lightning glow (no bolt, no flash) at +1.2 s *names* it.
- The meter and the goal chip fade in at +1.6 s.
- The rain starts last.

## 3. The goal chip and the lighthouse icon

**The lighthouse icon** (`LighthouseIcon`, a SwiftUI Shape set; it replaces `LighthouseGlyph`). The viewBox is 24 × 32: a tapered tower (base 12 wide, top 8), a lamp room 9 × 5, a roof cap, and a 2-pixel gallery rail. It has three states:

| State | Tower | Bands | Lamp |
|---|---|---|---|
| **reached** (lit) | foam `#F2F7FA` | two cut-out bands `#D8574A` | reward gold `#FFD45E` plus a glow (radius 1.4× width, additive, 0.5) |
| **next** (goal) | 2 pt outline in reward gold, no fill | outlined | the lamp alone filled gold, pulsing 0.6 ↔ 1.0 at 0.8 Hz (static under Reduce Motion) |
| **unreached** | 1.5 pt outline in mist `#B6CCDA` at 60 % | — | unlit |

- Sizes: 16 (inline in text), 22 (chip), 30 (chip, near), 44 (reached card), 64 (route map focus).
- **Scene match:** the in-world lighthouse switches to the same two warm-red bands `#D8574A` on `#F4F1EA` (now three candy stripes `#D33`), so the icon and the world are one object.

**The goal chip** ("← Gull Point · 1.2 km"; copy UX).
- **Placement:** the sea page, top, under the distance. Duo (mirrored): leading edge x = 32, y = 84. iPhone: x = 82 (island inset), y = 70.
- **Shape:** a capsule, height 40 (Duo) / 34 (iPhone), padding 14 / 12, `surface` at 0.62 with a 1 pt `stroke`.
- **Contents, in order of the flight direction:**
  - a 12 pt **chevron** in reward gold pointing the way the bird flies ("←" in the mirrored default, "→" otherwise; it must follow the layout, never a fixed glyph);
  - the lighthouse icon (*next* state);
  - the name in `headline` 19 / 17 Bold foam;
  - a "·" in mist;
  - the distance in `SwoopType.hud`-style Heavy mono at 19 / 17, in goldLight `#FFE08A`.
- **Growth:** the icon grows from 22 to 30 pt over the last 1.0 km (ease-in), and under 0.3 km the chip's stroke turns reward gold at 60 %. It never moves or bounces.
- **Blur-safe:** the chip sits on the blur-prone page, so it must read when soft. The icon and the number carry it (≥ 17 pt Heavy, ΔL\* ≥ 50 against `surface`); the name is secondary.

## 4. "Gull Point reached!"

t = 0 is the pass event.

| t (s) | What | Spec |
|---|---|---|
| 0.00 | hit-stop | 60 ms (the Tailwind value) |
| 0.00 | beam sweep | the lamp's cone (40° wide, 900 pt long, additive `#FFF3C4`, peak α 0.35) sweeps 70° across the sea page over 0.9 s, ease-out |
| 0.00 | lamp flare | a 140 pt additive disc of reward gold, α 0.55 → 0 over 0.6 s; the horizon haze pulses to 0.75 |
| 0.05 | gust | 6 wind streaks (80–160 pt, foam at 0.5) run from the bird toward the storm: "the storm falls back" made visible |
| 0.10 | the card | centred on the sea page, y = 0.40 h (Duo 268, iPhone 160). `surface` at 0.88, radius 28/24, width 380/320, padding 20. The lit icon 44 pt; "Gull Point reached!" in `title` 34/28 Heavy foam; if new, a "New on your route" chip (reward gold fill, ink `#0E2438`, `chip` caps). In: scale 0.92 → 1, spring 0.35 / 0.72. A 2 pt gold hairline sweeps along the card's top edge in the flight direction over 0.5 s |
| 0.20 | motes | 12 soft gold motes (4–7 pt) rise 60–120 pt from the lamp over 1.2 s |
| 1.90 | hand-off | the card shrinks *into the goal chip* (0.45 s ease-in-out, scale and position to the chip's frame), and the chip flips to the next lighthouse (a 0.25 s vertical text roll) |

- The card replaces the old "Old Harry · 1st lighthouse" card and the km toast.
- **Reduce Motion:** no sweep and no motes; the card fades in and out (0.2 s), and the chip updates in place.
- **Fold rule:** the beam, card and motes all stay on the sea page, ≥ 28 pt off the crease.

## 5. The route map ("Route")

**Style.** A top-down hand-made sea chart, the same ink and gold as the game: a coastline along the top, sea below, and lighthouses on headlands joined by your route.

**The strip.** One horizontal strip, scrollable along its length. It runs in the **flight direction**: the start harbour sits at the bird-page end, the far lighthouses toward the sea-page end (right → left in the mirrored default).

| Element | Spec |
|---|---|
| Sea | vertical gradient `#12405C` → `#0B2A40`; 3 depth contours following the coast at 30 / 60 / 100 pt offsets, 1 pt white at 6 % |
| Coast (land) | along the top, y = 70 + 22 sin(x/180) + 12 sin(x/67 + 1.3), a headland bulge of +30 pt seaward under each lighthouse; land fill `#34544A` → `#26403A`; cliff rim 3 pt `#C9B98F`; foam line 1.5 pt `#FFF6E6` at 40 %, 4 pt seaward |
| Lighthouses | on the headland tips, **equal spacing by index** (Duo 150 pt, iPhone 130 pt), not by km, with a km label under each |
| Labels | the name in `body` 17/15 Semibold (reached: foam; next: reward gold; unreached: haze `#7896AB`) and "9 km" in `caption` mist, centred 18 pt under the icon |
| Route line | a 2.5 pt line 26 pt below the headland tips. Flown: solid reward gold with a soft glow (6 pt, 0.25). Not yet: 2 pt dashed mist at 45 % (6 / 8) |
| Your best | a pin at the best distance (interpolated between lighthouses): the 22 pt side-view bird in white facing the flight direction, on a 2 pt gold stem; "Best 6.4 km" in `chip` on `surfaceRaised` |
| The storm | at the harbour end, a 40 pt slate storm glyph (the `storm body` colour with the anvil silhouette) with three rain ticks: *it comes from home* |
| Harbour | a 26 pt quay glyph with "Start" in `caption` |

**Duo.**
- The strip spans both pages as one illustration (art may cross the fold), but **no label, pin or icon centre sits within x 447–503**: the scroll snaps so the fold falls between lighthouses.
- Map band y 96–520. The header ("Route", `title`) sits top-outer on the bird page.
- The summary card sits bottom on the bird page, y 540–637: "Next: Saltlight · 9 km · your best 6.4 km" with the next-state icon at 30 pt.
- On open, the map scrolls so the next lighthouse is centred on the sea page (x = 224), with the 64 pt focus icon and its pulsing lamp.

**iPhone.** The map band is y 64–300, spacing 130 pt; the summary bar (`surface` at 0.9, height 64) is docked at the bottom with the next-lighthouse line. The same snap rule applies, with no fold.

**Home and Results tie-ins.**
- **Home's Fly subtitle:** "Next: Saltlight · 9 km" with the 16 pt *next* icon inline.
- **Results:** a **mini route strip** (height 56) at the top of the card, showing the last reached lighthouse, the next one, and the bird pin where you were caught. The span between is solid gold up to the pin, dashed after it. It illustrates "Caught 0.8 km short of Saltlight" before the words do.

## 6. The mirrored default composition (bird on the right page)

The scene already mirrors in u-space (the root flips). These rules fix what flipping alone gets wrong or leaves loose.

| Item | Rule (mirrored default; swap if the bird side is left) |
|---|---|
| Bird | screen x = 0.70 w (Duo 666, iPhone 612), ≥ 190 pt from the crease; faces left; key rim on its leading (left) edge, since the light is ahead |
| Sun | u 0.80 → screen x 0.20 w (Duo 190, iPhone 175); keep ≥ 120 pt from the crease; lift `sunLiftFraction` 0.16 |
| Storm | enters from the bird page's outer (right) edge; sky shade reaches leftward `edge + 0.45 w`; the caught sweep ends at x ≤ 381 (`stormCaughtEdge` 0.62 mirrored), never inside x 447–503 |
| Rain | slants away from the storm, so it moves *left* (`rainVX` sign follows the flip; check that it isn't a screen-space constant) |
| Trail, spray, speed lines | stream right (behind the bird); speed lines stay in the bird band and below y 72 |
| Distance | sea page, top-outer: leading x 32 (iPhone 82), `hud` 46/36, with a legibility shadow (the sun glow is under it) |
| Goal chip | under the distance (§3) |
| Chain / Tailwind chip | **moves to the bird page**, under the meter's inner end (Duo x 520, y 64): the chain pushes the storm back, so it belongs next to the storm meter. That leaves the sea page carrying only *where* (distance, goal). |
| Meter | bird page, top, x 520–820 (Duo) / 471–752 (iPhone), height 14. The storm icon sits at the **outer (right) end**, the knob moves toward the crease as the lead grows. The fill runs from the knob to the storm, gold → slate. **No red tick:** the last 15 % next to the storm tints coral `#FF7B6E` at 35 % instead, and is labelled once by UX copy. The knob is the 22 pt side-view bird (white with a `#0E2438` 1 pt contour) on a 26 pt `surface` disc, facing left; it replaces the dorsal "M" |
| Pause | bird page, top outer corner: Duo (895, 56), iPhone (812, 50), 48/44 visual, 56 tap, clear of the meter by 16 pt; glass or `surface` at 0.82 |
| Callout "Perfect ×N" | bird + (−40, −64), i.e. ahead and up; it flips below the bird under the HUD (UX) |
| Hints, prompts | bird page (sharp), centred at the page's middle x (727 Duo), y 0.62 h |
| Flight School prompt text | bird page, y = 0.22 h, `headline` 22/19, max width 380 pt, foam on a `surface` at 0.55 scrim (radius 20) |
| Home | menu on the sea page, wordmark and caption on the bird page (as home-mirror does: keep), the title bird spanning both, the storm at the right edge |
| Results | the card on the sea page; the calm caught bird on the bird page |

- **Blur rule:** everything you need *while folding* (the bird, the meter, prompts, the pause) is on the sharp bird page.
- The sea page holds the slower information (distance, goal), sized to survive a 2 s soften: no text under 17 pt on it during play.

## 7. The D4 visual coherence audit

Each item gets one fix. Every screen must answer *what do I do, why, how am I doing*.

| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | HUD | No goal on screen, so "where am I going?" fails | §3 goal chip; the reached moment flies into it (§4) |
| 2 | Meter | Red tick unexplained; the knob "M" reads as an eye or logo | §6: a coral end zone and the side-view bird knob |
| 3 | Storm (storm-teach, meter-label, home) | Rows of identical rounded lobes read as river stones or cobbles | Make it read as weather: **(a)** a crisp anvil top `storm top` with a sunlit 3 pt rim; **(b)** body lobes varied 0.6–1.4× and overlapping, not tiled; **(c)** a rain curtain under it (`rain` at 0.35, soft top, 140 pt feather into the sea); **(d)** an internal lightning glow every 3–6 s from first sight (Reduce Motion: the glow only). Lobe radius jitter ±35 % and row offset ≥ 0.5 radius (Scene) |
| 4 | Bird marks | Three marks: the dorsal "M", the SF dove `bird` symbol, the side-view gull | **Brand mark** = the dorsal M (icon, wordmark, cover). **"You"** = the side-view gull glyph (meter knob, map pin, diagram, touch glyph). Drop the SF `bird` symbol from Birds and Goals |
| 5 | Iconography | Goals uses a checkered race flag; the objective is a lighthouse | Goals: `checklist` symbol. Route: the lighthouse icon. Daily: keep the calendar. No race flags |
| 6 | Pose card | The phone is a gradient pill | `DuoDiagram` (§1) everywhere |
| 7 | Results | Rank-up and logbook cards sit above the objective | Lead with the mini route strip (§5), then the distance hero, then *one* secondary card. Rank-up becomes a chip on the card ("Rank up: Tern"), not a second card |
| 8 | Home | 3 lines of caption plus the "Made for iPhone Duo" line compete with Fly | Keep the wordmark, one caption line and the Fly subtitle "Next: Saltlight · 9 km" with its icon; the extra line moves below the menu in `caption` haze |
| 9 | Tailwind chip | "×3 · TAILWIND" jargon in a grey pill | On the bird page (§6), `surface` at 0.62; first time only, the callout's second line explains it (UX copy) in `body` foam under the gold callout |
| 10 | Lighthouse card | "1st lighthouse · the storm falls back" | Replaced by §4 |
| 11 | Goals screen | Reward names in mist on every row are fine, but the rank names (Spray Chaser, Crest Hopper) carry no picture | Each rank row gets its reward thumbnail (24 pt: a bird glyph, a sky swatch circle or a trail bar). The names stay (UX decides) |
| 12 | Touch glyph (touch-wing) | A thin white "M" outline at 25 % reads as a watermark | Use the side-view gull glyph 36 pt in a 44 pt `surface` at 0.5 disc; it tucks with u (tuck 0 → 1) |
| 13 | Countdown | A dark disc plus a hint pill on the sun page | Mirrored: move it to the bird page (sharp), centred x 727; keep the disc `surface` at 0.7 |
| 14 | Colour of "on / good" | Teal `accentOn` vs reward gold muddled in the new guides | Teal = **open / spread / neutral on**; gold = **fold / reward / goal**. Used the same way in the diagram gauge, the rhythm bar, the fold path and the toggles |

## 8. Tasks

### Scene (`Swoop/Scene`)

**SC1. `practice` palette** (§2) in `ScenePalette`, plus a `practiceMode` flag that hides the storm, sky shade, rain and chop, and sets the far layers' α to 0.7 and `sunLiftFraction` to 0.24. Step 7 crossfades the palettes over 2.0 s.

**SC2. Guides:**
- `SceneGuides`: the fold-path ribbon (12 pt, reward gold, α 0.40 → 0, shimmer 1.2 s);
- the open chevrons (3 × 14×8 pt, 2.5 pt, 0.15 s stagger);
- the landing ghost ring (150 pt, 1 : 0.32, dashed 8/6, foam at 0.6, breathing at 1 Hz, 8-mote burst);
- the 6 % slow-mo bloom.
- An API like `showGuide(.foldPath(from:to:) / .openMark(at:) / .landing(at:) / .none)`.

**SC3. Bird-anchored practice HUD art** (if Scene draws it; else App): the "faster" capsule 140 × 10 at bird + (0, −46), and the rhythm bar 132 × 8 at bird + (0, +38). Publish `birdScreenPoint` (exists) at ≥ 30 Hz.

**SC4. The lighthouse-reached moment** (§4):
- a beam cone 40° × 900 pt, additive `#FFF3C4`, α 0.35, sweeping 70° over 0.9 s;
- a lamp flare 140 pt, α 0.55 → 0 over 0.6 s;
- 6 gust streaks toward the storm;
- 12 motes over 1.2 s;
- 60 ms hit-stop;
- a haze pulse to 0.75.
- Reduce Motion variants. The in-world tower recoloured to `#F4F1EA` with two bands of `#D8574A`.

**SC5. Mirrored polish** (§6):
- verify the rain's x-velocity follows the flip;
- the caught sweep ends at x ≤ 0.40 w from the left (mirrored), never in the fold band;
- `stormHUDClearance` 120 measured from the right edge when mirrored.

**SC6. Storm readability** (§7.3): lobe radius jitter ±35 %, row offset ≥ 0.5 r, the anvil rim, the rain curtain with a 140 pt feather, and an internal glow every 3–6 s from first sight.

**SC7. Route-map art helpers** (pure CoreGraphics, like `BirdArt`):
- `RouteArt.coastPath(width:, headlands:)`, using the §5 formula with a +30 pt bulge per lighthouse;
- `RouteArt.contours(offsets: [30, 60, 100])`;
- `RouteArt.stormGlyph(size:)` (the anvil silhouette);
- `RouteArt.quayGlyph`.

**SC8. Side-view "you" glyph:** `BirdArt.youGlyph(facing:)`, a 1-path simplified gull side view at tuck 0.2 that reads at 16 pt (body, a single wing, beak). Used by the meter knob, the map pin, the diagram and the touch glyph.

### App (`Swoop/UI`)

**AP1. `DuoDiagram`** (§1):
- boxes 240×170 (Duo) and 180×128 (iPhone), the projection `cos φ` and skew `0.18 sin φ`;
- body `#DCE3EA`, rim 3 pt `#0E2438` at 40 %, spine `#9AA5B1`;
- mist mittens;
- the target ghost (dashed 6/5, foam at 0.45, 1.4 s cycle, 0.3 s hold, ±6° match);
- the check pulse in `accentOn`;
- the angle gauge (r 74, 6 pt, bands 150–180 teal and 100–122 gold, a foam needle);
- the flat tint at ≥ 174°;
- the touch variant (180×88, finger, 56 pt ring);
- the Reduce Motion statics.
- It replaces the pose-card pill.

**AP2. Wing check pages** (§1):
- two full-page cards (`surface` at 0.92, r 32, insets 32 / 28);
- the test pattern (160×100, 1 pt hairlines at 4 pt pitch, a 44 pt wordmark);
- 40 pt outward arrows;
- the mini diagram alternating its blur every 1.2 s;
- the tertiary skip at y = h − 40.

**AP3. Flight School chrome:**
- step dots (8 × 7 pt; current 10 pt gold; done foam; to-do white at 25 %; top centre of the bird page, y 28);
- the prompt on the bird page (y 0.22 h, `headline`, max 380, `surface` at 0.55 scrim, r 20);
- no other HUD until step 7;
- the HUD fade-in at +1.6 s.

**AP4. `LighthouseIcon`** (24×32 viewBox; reached / next / unreached; sizes 16/22/30/44/64; the lamp pulse at 0.8 Hz), replacing `LighthouseGlyph` everywhere.

**AP5. Goal chip** (§3):
- capsule h 40/34, pad 14/12, `surface` at 0.62 with a `stroke`;
- a flight-direction chevron, the icon growing 22 → 30 pt over the last 1 km, the name 19/17 Bold;
- the distance 19/17 Heavy mono in `#FFE08A`;
- the gold stroke under 0.3 km;
- position sea page (32, 84) on Duo and (82, 70) on iPhone.

**AP6. The reached card** (§4): `surface` at 0.88, r 28/24, w 380/320, the 44 pt lit icon, `title` text, the "New on your route" gold chip, the spring 0.35 / 0.72, the 2 pt gold top-edge sweep, then the 0.45 s fly-into-chip and the 0.25 s text roll. Delete the old lighthouse card and the km toast.

**AP7. Route screen** (§5):
- the strip in the flight direction, spacing 150/130, the coast, contours, labels by state;
- the route line (solid gold with a 6 pt glow / dashed mist at 45 %);
- the best pin (the "you" glyph and a chip), the storm and harbour glyphs;
- the snap keeping centres out of x 447–503;
- the open-scroll to the next lighthouse at x 224 (Duo);
- the header and summary card on the bird page; the iPhone summary bar at h 64.

**AP8. Mirrored HUD** (§6):
- the chain/Tailwind chip moves to the bird page (520, 64);
- the meter's storm at the outer end, the coral end zone (last 15 %, α 0.35) replacing the red tick;
- the "you"-glyph knob on a 26 pt disc;
- pause at (895, 56) Duo / (812, 50) iPhone;
- countdown and hints centred on the bird page.

**AP9. Results:** the mini route strip (h 56) first, then the hero, then one secondary card; rank-up becomes a chip.

**AP10. Home:**
- the Fly subtitle "Next: …" with a 16 pt *next* icon;
- the caption trimmed to one line;
- the Goals icon `checklist`;
- the SF `bird` symbol replaced by the "you" glyph on Birds;
- the touch glyph per §7.12.

**AP11. CI frames** for each item above, mirrored on Duo and plain on iPhone:
- `fs-0` … `fs-7`, `wing-check`, `goal-chip-far` / `-near`;
- `reached-0.1` / `-1.0` / `-2.2`;
- `route-duo`, `route-iphone`;
- `results-route`, `home-next`.

## Assumptions to confirm with the UX Lead (`UX-FLIGHT-SCHOOL.md`, not yet written)

1. The prompt and diagram live on the **bird (sharp) page** during steps 0–6, and the title bird spans both pages in step 1.
2. The chain/Tailwind chip moves to the bird page next to the meter, which leaves the sea page with distance and goal only. That is a layout change; UX decides.
3. The goal chip sits under the distance on the sea page, and its chevron follows the flight direction (copy "→" becomes a glyph).
4. Results lead with the mini route strip, and rank-up becomes a chip.
5. Wing check uses one full-page card per half (the half is the answer). The "Neither / skip" placement is UX's.
6. The coral meter end zone replaces the red tick; UX supplies its one-time label.
