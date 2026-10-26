# Swoop: art direction (Round 3, 26 Oct 2026)

*Owner: Art Director. Scope: the look (palette, light, bird, motion, type, colour, materials, component style, icon, fold composition). The UX Lead's `design/UX-SPEC.md` owns flows, layout, hierarchy and copy. Sources: every R2 iPhone 18 Pro frame (`r3/screenshots`: 31 frames, 12 badges, the icon), the fresh R2 Duo run (`duo3`: store-01 to 16, duo-ui-\*, duo-07-closed), the R1/early-R2 Duo frames (`duo1`, `duo2`), the Scene/UI code, REVIEW-1, scene-R2, app-R2. Hex values are sRGB.*

**Verdict on R2's look: 5.5 / 10.** The bones are right: the sun ahead, the storm behind, big swells, a navy-and-gold UI. Moonrise (store-13) already shows what the whole game should feel like: one light, one hue family, a clean value ramp. Golden Hour, the sky every player sees first, misses:
- the zenith is a muddy mauve-brown and the clouds are dusty taupe puffballs;
- the far swells read as mountains;
- the storm is a stack of pancakes;
- speed lines cross the whole frame like scanlines;
- the trail is a checkerboard of segments;
- the near sea is a flat slab that covers 45 % of every frame.

None of it is hard to fix. It is palette and layer discipline.

## References: what makes them premium (described, not copied)

| Game | The lesson for Swoop |
|---|---|
| Alto's Adventure / Odyssey | Each time of day is a *designed* palette of 4–5 stops, not a lerp. Far layers are flat shapes fading toward the horizon colour (depth from value, not detail). Weather is a full-screen value shift. The rider is tiny but always the crispest, darkest thing on screen. |
| Tiny Wings | The ground is the toy: bold banded hills against a plain sky, a chunky high-contrast bird, day-to-night as a visible clock. |
| Monument Valley | A strict palette per scene, soft flat gradients, generous negative space. The UI almost vanishes. |
| Sky / Journey | Light is the subject: warm key against cool shadow, ribbons that taper into nothing, the ground (sand; our sea) carries the glitter. Motion is slow-in, slow-out. |
| Prune | One gesture, one silhouette against a gradient sky. Colour arrives only as the reward. |
| Lumino City | Restraint in effects and honesty in shading: everything reads as *made*. |
| Ori | A backlit rim on the hero, deep parallax, bloom kept to the hero and rewards. |
| ADA Visuals & Graphics (2025: Infinity Nikki; finalist Neva) | Judges reward a *distinctive, cohesive theme* across art, interface and animation. Neva and Gris use colour as emotion. |

**Distilled for a seabird over swells:**
1. Design each sky as fixed stops, never as an RGB lerp between complementary colours.
2. Atmospheric perspective: each layer further back is lighter, less saturated and flatter.
3. One key light, ahead.
4. The bird is the crispest, highest-contrast shape on screen.
5. Rewards are the only crisp gold.
6. Trails taper into nothing.
7. The UI stays quiet over the art.

## 1. Pillars

1. **Light runs ahead.** The sun and every warm light live on the right page; the storm and every cold light live on the left. Blurred, a frame still reads as dread on the left and hope on the right. On the Duo, one wing is the past and the other is the future.
2. **The bird always reads.** Silhouette, contrast and size come first. If a squint loses the bird, the frame fails.
3. **Water is the hero.** The detail budget goes to the near sea (lit faces, foam, glitter, spray). The sky stays two or three calm gradients. The far sea stays thin and quiet.
4. **Soft world, crisp reward.** Ambient things are soft (gradients, haze, mist). Rewards are crisp, gold and brief: the Perfect ring, the foam line, the Tailwind strands. Rarity makes them read as valuable.

## 2. Palette system

**Rules.**
- The sky is five fixed stops: zenith 0, mid 0.45, low 0.80, horizon 0.96, sunline 1.0. `mixed(with:)` is banned for the sky, the far sea and the storm: blue + orange = grey, and teal + gold = khaki.
- The scene reads a Scene-owned `ScenePalette` (§10). Core's `Sky` stays as it is, for tiles and tints.
- The reward gold is the same in every sky: core `#FFD45E`, highlight `#FFF3C4`, deep `#E8A93A`.
- The UI gold `#F7C75B` is the brand and never changes.
- **Never put gold on navy at partial alpha**: it turns olive (the cover glow, the pose circle, the icon glow). Use additive or `.plusLighter` blending, or a dark warm hue (`#5A3A2A`).

| Role | Golden Hour | Rose Dusk | Northern Lights | Monsoon | Moonrise |
|---|---|---|---|---|---|
| zenith | `#2B4F8F` | `#2E2A5E` | `#060D22` | `#4E6470` | `#0A1230` |
| mid (0.45) | `#8C7CB6` | `#7A5C9E` | `#0C1F3A` | `#7F959A` | `#16224A` |
| low (0.80) | `#F0A07A` | `#E68A9A` | `#12384A` | `#B9C8C2` | `#2A3C6E` |
| horizon (0.96) | `#FFD18C` | `#FFC2A8` | `#1D5E60` | `#E4ECE2` | `#4A6296` |
| sun disk / glow | `#FFF3D1` / `#FFC46B` | `#FFE7DA` / `#FF9E8A` | `#DFFFF0` / `#59F0B8` | `#FFFBEA` (disk at 40 %) / `#F4F1D8` | `#F4F1E6` / `#9DB4FF` |
| far-back sea | `#8FB0C8` | `#A79BC4` | `#24525A` | `#9FB5B0` | `#3A5288` |
| far-front sea | `#4F86A6` | `#6A6AA0` | `#163E4C` | `#6E8F8A` | `#26396A` |
| near crest / lit face | `#3D8FB0` | `#6F79B5` | `#1E5868` | `#5E8A82` | `#2E4A80` |
| near mean | `#1C5A7C` | `#3A3F78` | `#0C2836` | `#2E5650` | `#12224A` |
| near deep | `#0A2B44` | `#171A3E` | `#040F18` | `#12302C` | `#060D22` |
| foam line | `#FFF6E6` | `#FFEFF2` | `#CFFAF0` | `#F4F8F2` | `#E2EAFF` |
| storm body / top | `#3A4252` / `#262C38` | `#3B3550` / `#252136` | `#232C3A` / `#151B26` | `#2F3A40` / `#1E262B` | `#1E2436` / `#121626` |
| storm rim (sunlit) | `#FFD9A6` | `#FFC9C0` | `#7CF5C8` | `#E8F0E6` | `#C9D6FF` |
| rain | `#A9B6C6` | `#B3A9C9` | `#8FB8C0` | `#C2CEC9` | `#8C9CC4` |
| bird key rim | `#FFE2A8` | `#FFD3C2` | `#BFFFE6` | `#FFFFFF` | `#DDE6FF` |
| cloud streaks | `#F6C7A6` | `#F2B4BE` | `#1C3A4E` | `#D5DED8` | `#3C4E7E` |
| glitter / accent | `#FFF0C2` | `#FFE0D6` | `#A8FFE0` | `#FFFFFF` | `#E6ECFF` |

**Light direction.**
- The key light is the sun at u = 0.80 w, lifted 0.16 h above the horizon, with its centre clamped to ≤ the visible top − 90 pt (the iPhone crop).
- Swell faces that look toward the sun (dh/dx < 0) are 10–14 % lighter (`near crest`); faces turned away stay at `near mean`.
- Crest glints appear only within ±0.30 w of the sun's x.
- The storm behind is cold fill: the left 45 % carries a shade in the `storm top` colour, rising with closeness (§3).
- No light source ever sits on the left page. Lightning is the one exception (≤ 120 ms).

**Value structure (the squint test).** Blurred by 12 px, a frame reads as three bands:

| Band | L* | Contents |
|---|---|---|
| Light | 75–98 | horizon, sun, foam, light birds, HUD text |
| Mid | 35–65 | upper sky, far sea, near crests |
| Dark | 8–30 | storm, near mean and deep, UI surfaces |

- The bird keeps **ΔL\* ≥ 35** against everything within 1.5 body lengths.
- Light birds get a 1.25 pt `#0E2438` contour at 55 %.
- Dark birds (puffin, swift, petrel) get the key rim at 1.5 pt, plus a 28 pt halo of the horizon colour at 10 %, shown only over the sea (the Ori trick).
- In Monsoon (the low-contrast sky) every bird uses the dark contour.

## 3. Atmosphere and depth

| z | Layer | Parallax | Treatment |
|---|---|---|---|
| −20 | sky | 0 | 5 stops, ±1/255 dither against banding |
| −19 | stars / aurora | 0 / 0.005 | stars only where zenith L\* < 20; aurora as two additive ribbons `#48E6A8` → `#7A6CFF` at α 0.35–0.5 |
| −18 | sun | 0 | a 520 pt additive glow and a crisp disk; Monsoon: the disk at 40 %, the glow 1.6× |
| −16.5 | clouds | 0.02 | **thin flat-bottomed streaks** 300–700 × 18–40 pt, lit from below, α 0.30–0.45; no puffballs (they make the mud) |
| −16 | storm anvil | locked to the gap | between the sky and the far sea; the base feathered into the far sea over 140 pt |
| −15 | horizon haze | 0 | 60 pt of `horizon` at 0.5; 0.75 on milestones |
| −14 | far-back sea | 0.08 | amplitude 2.5 pt, wavelength 80–140, a 1 px crest line in `horizon` at 0.6 |
| −13 | islands, lighthouse | 0.30 | value between the two far layers; a lamp glow and a beam |
| −12 | far-front sea | 0.22 | amplitude 5 pt, wavelength 130–220, the top 30 pt fades to far-back (haze) |
| −11.5 | glitter column | 0 | under the sun, 0.12 w wide; dashes 6–28 × 1.5 pt whose spacing grows downward; 3 Hz shimmer |
| 0 | near sea | 1.0 | lit faces, the foam line, a soft sub-surface band (not a second outline), crest glints |
| 1–2 | trail, FX, bird | 1.0 | §4, §5 |
| 3 | rain, foreground spray | 1.12 | slight fore-parallax |
| 4 | storm shade | screen | see below |

**Haze and glitter.**
- Atmospheric perspective uses explicit colours: far-front sits about 35 % of the way from the near mean to the horizon value, far-back about 65 %.
- The far layers together stay **≤ 14 % of the canvas height**. Today they are about 22 % on iPhone, so they read as mountains.
- Near-sea glints (74 × 7 streaks) appear only on sun-facing crests within ±0.30 w of the sun, at α `0.55 × (1 − |dx| / 0.30 w)`, up to 0.85 at ≥ 90 % of max speed.
- The 4-point twinkles scattered over the sea go. 4-point stars are reserved for the Perfect.

**How the storm changes the light** (c = closeness 0…1):
- **Sky shade:** a horizontal gradient in `storm top`, α `0.10 + 0.40c`, reaching `edge + 0.45 w`. The sky darkens before the sea does.
- **Sun:** dims `0.15c` during play and 50 % when caught.
- **Sea:** the foam under the shade moves toward `rain` (lerp 0.6c), and the chop rises from 9 to 14 pt.
- **Wall:** three value bands: a top shelf (`storm top`) with a crisp 3 pt sunlit rim along the anvil's upper edge, the body, and a rain-curtain base (`rain` at 0.35) fading into the sea. The lobes vary in radius (0.6–1.4×, never alternating), so the column reads as a shelf cloud, not stacked tyres.
- **Rain sheets:** soft tops (α 0 → 1 over the top 30 %) and soft bottoms, never hard rectangles.
- **Caught**, over 1.5 s ease-in-out: the world goes 30 % grey, the sun dims 50 %, and rain covers both pages. The right page takes only 60 % of the wash, so the ending is calm, not dead.

## 4. The bird

**Silhouette** (it must read at 40 pt):
- a long, narrow wing (aspect ≥ 5 : 1) with a visible wrist bend;
- a pointed hand;
- a round head 1.25× the neck;
- a dagger beak;
- a short wedge tail (forked for tern and swift).

**The wings never point straight up.** Today's spread pose (elevation 0.82 rad plus a 0.22 far-wing lift) reads as rabbit ears in countdown, hint-fold, hint-open and the Birds tiles.

**Proportions** (BirdArt units): body 0.90; depth 0.14 (gull) to 0.16 (puffin); head 0.17; beak 0.10–0.15; tail 0.12; spread near wing 0.52 × span × species length.

| tuck | elevation (rad) | hand sweep | chord | body | reads as |
|---|---|---|---|---|---|
| 0 (soar) | 0.42 (far wing +0.10) | 0.34 | 1.0 | level, nose +4° | a long, shallow "check-mark" lifted up and back: lift |
| 0.5 | 0.20 | 0.18 | 0.70 | nose −6° | half-folded, the arm still visible: committing |
| 1 (dive) | 0.04 | 0.03 | 0.42 | 6 % longer, 8 % thinner, nose −10° when airborne | a dart: weight and speed |

- Flap ±0.45 rad (now 0.62).
- Touchdown squash: 0.92 × 1.08 for 90 ms, then a spring back.

**Rim and shadow.**
- **Key rim:** 1.5 pt in the sky's `bird key rim` along the back line, the crown and the near wing's leading edge. It catches the sun ahead.
- **Contour** (light birds): 1.25 pt `#0E2438` at 55 %.
- **Belly:** 12 % darker on the lower third.
- **Contact shadow** while skimming: an ellipse 1.2 body lengths × 6 pt in `near deep` at 35 %, gone by 60 pt of height. This is the cheapest "premium" win there is.

**Size** (body length at zoom 1, and the floor at full zoom-out):

| Device | Target | Floor |
|---|---|---|
| Duo 951 × 669 | **96 pt (10 % of the width)** | 66 pt |
| iPhone 874 × 402 | 88 pt | 60 pt |
| 667 × 375 | 72 pt | 52 pt |

That is `birdUnit` 84 → 107 and `birdZoomResist` 0.6 → 0.7.

**The title bird** (dorsal view) is specified in §7.

## 5. Motion and juice language

The world eases like air (slow in, slow out). Rewards snap. The UI settles. Nothing is linear except rain.

| Thing | Curve | Time | Overshoot |
|---|---|---|---|
| UI settle | spring 0.45 / 0.86 | ~0.45 s | ≤ 2 % |
| UI pop (chips, ×N, badges) | spring 0.28 / 0.62 | ~0.3 s | 8–12 % |
| Button press | spring 0.18 / 0.7, scale 0.96, lip 4 → 1 pt | 0.12 s | 0 |
| Page change | crossfade + a 24 pt slide toward the new page (no 3D rotation: the `goals` capture caught a rotate-and-scale) | 0.32 s ease-out | 0 |
| Perfect ring | ease-out cubic, 40 → 170 pt, α ease-in to 0 | 0.38 s | — |
| "Perfect ×N" | pop 0.6 → 1.12 → 1 (spring 0.2 / 0.55), hold 0.25 s, rise 24 pt ease-out, fade over the last 0.25 s | 0.7 s | 12 % |
| Toast | in: spring 0.35 / 0.8 from +16 pt; hold 1.6 s; out: ease-in 0.22 s | — | 3 % |
| Results distance | count-up, ease-out expo, a tick every 0.5 km | 0.8 s | — |
| Camera | zoom critically damped τ 0.35 s; y lag τ 0.12 s; lead 8 % w at full speed; punch-in +3 % (60 / 350 ms, keep) | — | — |
| Tailwind start | a local sun flare to 0.25 additive (never full-screen), +2 % zoom-out | 0.5 s | — |

**Particles.**
- **Soft** (gaussian): mist, foam flecks, glow.
- **Hard:** droplets are crisp 2–5 pt discs, stretched along their velocity, with a 1 px darker underside on bright skies.
- **Splash:** 18–26 hard drops plus one mist puff ≤ 90 pt at α ≤ 0.5. The current 200 pt white radial burst (the `splash` frame) reads as light, not water.

**Trails.**
- One continuous ribbon. Segments overlap by `0.6 × width`, and the texture is solid along its length and soft only across it. Today's seams make a checkerboard.
- Width 9 pt (slow) to 14 pt (full speed), tapering to 0 over 0.45 s; core α 0.8; additive glow 2.0× at α 0.12–0.35.
- Tailwind: two strands at 0.4× the width, wobbling 6 pt.

**Speed lines.** Only in a band of ±0.18 h around the bird and never in the top 72 pt. Each is 80–220 pt, tapered, α ≤ 0.28, with 10 at most. Today they cross the full width in every gameplay frame: the #1 "cheap" tell.

**Hit-stop and shake.**
- Hit-stop: 35 ms on a Perfect, 60 ms when a Tailwind starts. On a splash, no stop: 0.85× time for 80 ms (heavy, not frozen).
- Shake: the splash bump ≤ 6 pt, the storm rumble ≤ 2 pt, nothing else.

**Flashes.** Full-screen ≤ 0.14 α, ≤ 120 ms, ≤ 2 per second (the photosensitivity rule is 3); local flares ≤ 0.25; never a white-out.

**Reduce Motion.**

| Effect | Variant |
|---|---|
| shake, punch-in | off |
| callout | fades in place |
| Perfect ring | appears at 120 pt and fades over 0.3 s |
| speed lines | a 6 % edge vignette in the trail colour |
| lightning | cloud glow only |
| page change | 0.2 s crossfade |
| parallax | kept; cloud drift stops |

## 6. UI visual language

**Type.** SF Pro Rounded. Weight must mean something; today every label is Heavy or Black.

| Weight | Use |
|---|---|
| Black | wordmark, "Perfect" |
| Heavy | numbers, page titles |
| Bold | buttons, card titles |
| Semibold | body |
| Medium | captions |

All digits are `.monospacedDigit()`. One scale replaces the 25 ad-hoc sizes in `Swoop/UI`. The Duo sizes run larger because the halves are held at arm's length and seen at an angle (§8).

| Token | Duo 951×669 | iPhone 874×402 | Weight / tracking | Use |
|---|---|---|---|---|
| `wordmark` | 72 | 52 | Black / −1.5 % | Home title |
| `hero` | 76 | 52 | Heavy / −1 % | the results distance (unit at 45 %, Bold, `mist`) |
| `hud` | 46 | 36 | Heavy | the HUD distance (unit 18/15 Bold `mist`; hundredths at 70 % opacity) |
| `countdown` | 120 | 96 | Heavy | 3-2-1 in foam with an ink shadow (never gold on the sun) |
| `callout` | 32 | 28 | Black | "Perfect ×N" |
| `title` | 34 | 28 | Heavy / −0.5 % | page titles |
| `headline` | 22 | 19 | Bold | card, toast and menu-item titles |
| `button` | 20 | 18 | Bold | button labels |
| `body` | 17 | 15 | Semibold | descriptions, goals |
| `caption` | 14 | 13 | Medium / +1 % | sub-labels |
| `overline` | 12 | 11 | Bold / +12 %, caps | section labels in **`mist` `#B6CCDA`**, not gold |
| `chip` | 13 | 12 | Heavy / +6 %, caps | TAILWIND, DAILY #298, "New best!" |

**Colour (UI vs world).** The world owns saturation; the UI is navy, foam and one gold.

| Token | Value | Use |
|---|---|---|
| `surface` | `#0B2236` at 90 % | cards |
| `surfaceRaised` | `#143352` | secondary buttons, tiles |
| `stroke` | white at 9 %, 1 pt, top-lit | hairlines |
| text | `#F2F7FA` / `#B6CCDA` / `#7896AB` | primary / secondary / tertiary |
| `accentOn` | teal `#5CC2D6` | toggles, neutral "on" states |
| danger | coral `#FF7B6E` | destructive actions |

- **Gold budget:** one gold fill per screen (the primary action), plus gold for *earned* states (checks, the current rank, Perfect, Tailwind).
- Settings' gold icon tiles and gold toggles break the budget.

**Materials.**
- **Over the live world** (HUD, toasts, callouts), no panels: text gets a legibility shadow (`#04121F` at 45 %, r 6), and chips sit on `surface` at 62 %. Today's grey translucent chain chip and grey-brown toast pill read dirty.
- **Cards:** solid `surface`, a hairline, and a shadow (black at 30 %, r 18, y 8). Gold strokes mark the selected state only.
- **Liquid Glass** (iOS 26+, behind `#available`): only for small floating controls (pause, the Home icon buttons): `.glassEffect(.regular.tint(surface.opacity(0.5)))`. Older systems keep the deep circle.

**Radii (concentric).** Cards 32 (Duo) / 28 (iPhone) with 16 pad give buttons of 16 / 12. Tiles 18 / 16. Chips and toggles are capsules. Today: a 26 card with a 20 button inside 20 pad.

**Spacing.**
- A 4 pt grid: 4 · 8 · 12 · 16 · 24 · 32 · 48.
- Margins: 32 pt from the Duo's outer edges, and the fold band (§8); 20 pt plus the safe area on iPhone. Rows ≥ 56 pt.

**Icons.**
- SF Symbols, rounded `.semibold`, at the cap height of the adjacent text (20 pt beside `button`).
- Custom glyphs (bird, lighthouse, storm) use 2 pt rounded strokes.
- No emoji in chrome: 🔥 becomes `flame.fill` in `#F39A4B`.

**Buttons.**

| Kind | Height Duo / iPhone | Fill | Label | Pressed |
|---|---|---|---|---|
| Primary | 64 / 56 | `#FFE08A` → `#F7C75B`, a 4 pt lip `#C98A2A`, shadow black at 25 % r 12 y 6 | ink `#0E2438`, `button`, 20 pt icon | lip 4 → 1, scale 0.97 |
| Secondary | 56 / 48 | `surfaceRaised` with a `stroke` hairline | foam, 17/16 Semibold | `#0F2942` |
| Tertiary | 44 | none | mist `body` Semibold; coral if destructive | α 0.6 |
| Icon | 48 / 44 visual, 56 tap | glass, or `#0B2236` at 82 % | foam at 0.4 × the size | scale 0.92 |

**Numbers.** A thin space before units ("4.06 km"), the unit at 45 % size in `mist`, a true "×", and one decimal in Results.

## 7. The title bird and the app icon

**The title bird** (dorsal view, Home and countdown):
- **Span:** 92 % of the canvas, the body exactly on the crease.
- **Dihedral:** +6° from the shoulder to the wrist, then −3° on the hand. A gull's "M", not a plank.
- **Chord:** tapers from 0.16 h at the shoulder to 0.05 h at the tip, with a forward wrist kink at 38 % of the span. The trailing edge is smooth: drop the finger notches, which read as torn paper.
- **Colours:** mantle `#9AA5B1`, a white trailing band at 10 % of the chord, black primaries `#2B2F36` over the outer 18 % with two white mirrors 0.012 w across.
- **Shading:** vertical across the chord (+12 % on the sunlit leading edge, −8 % at the trailing edge), replacing today's horizontal metallic gradient.
- **Body:** the head 1.25× the neck, a two-tone beak (`#F2B33D` with a `#D8862A` spot), a short fanned tail, and a soft drop shadow 40 pt below at 25 %.
- **Tucked:** a dart 34 % of the width, the tips past the tail, keeping ≥ 60 % of the chord and the lit leading edge. Wings hanging below the shoulder line with a thin chord read as legs: the "spider" in `duo2/duo-ui-home-tucked`.
- **Countdown morph:** 0.6 s; the bird scales and slides to the play bird's spot, dorsal crossfading to side view at 50 %.

**The icon.** Today's (a front-on dove, a gold "dune", an olive glow, stars) reads at 60 px as a generic peace dove over sand.

| | Concept | At 60 px | Risk |
|---|---|---|---|
| **A. Two-wing fold (pick)** | The square is split by a soft vertical fold. Left: storm slate `#2A3446` → `#3B4558`. Right: sunset `#F29A62` → `#FFD08A`, sun `#FFF3D1` upper right. A dorsal gull spans 84 % of the width with its body on the fold (mantle `#9AA5B1`, black tips with mirrors, white head, gold beak, a 1.5 % ink contour). The bottom 20 % is sea `#1C5A7C` with a foam line `#FFF6E6`. | A white-headed "M" bridging dark and light: *the halves are wings; storm against sun*. | The grey wing on the gold half: keep ΔL\* ≥ 18 through the dark primaries and the contour. |
| B. The swoop | A side-view gull diving down one huge teal swell whose foam lip curls into an S. | A strong diagonal and a curl. | Doesn't say Duo; close to surf clichés. |
| C. Sun crossing | A dark bird crossing a big gold sun over a navy sea with a glitter column. | Very legible. | Generic; loses the fold. |

Rules for A:
- No stars, eyes or glow-over-navy. Full bleed. The fold is a 6 px highlight at 12 % next to a 6 px shadow at 18 %.
- Test at 1024, 180, 60 and 40 px, on light and dark wallpapers, and in iOS 26 tinted/clear modes. Supply the bird as a separate foreground layer for Icon Composer.

## 8. Composing for the fold (Duo first)

**Two pages.** The inner display is 951 × 669 pt, with the crease at x ≈ 475.

| | Left page, x 0–455 ("behind") | Right page, x 495–951 ("ahead") |
|---|---|---|
| Play | the bird (x ≈ 285, 30 %), its trail and the storm; cool and darker, the lead meter at the top | the sun (x ≈ 760), the swells to come, lighthouses arriving, the distance and chain |
| Home, Results, every page | the bird or the world: the title bird's left wing, the calm caught bird, the bird preview, the page title | the action column: menus, the Results card, lists |

- No card, button, text or line ever spans the crease. A two-page screen uses two cards, one per page.
- The **fold band** is ±28 pt around x 475 for art (glyphs, text, the sun, bright shapes) and ±18 pt for the App's tap targets. Sky and sea flow straight through it.

**On the crease.**
- Only three things cross the fold:
  - the horizon line;
  - the sea and sky gradients;
  - the title bird's spine (the crease *is* its spine; align the body's centre line to x = 475.5).
- The **horizon glint** dresses the crease: a soft vertical band 80 pt wide confined to ±40 pt of the horizon line, `horizon` + 20 % white at α 0.08, rising to 0.12 for 0.6 s on milestones. It reads as the sun catching the hinge.
- Never draw a hard line on the crease: the hardware crease already shows.
- During a tuck, a book-gutter shade grows along the crease: a 60 pt soft vertical shadow per side, `#04121F` at `0.10 × tuck`. The art "closes" with the hand.

**Read at 120–150° in the hand.**
- Each page turns 15–30° away from the picture plane, so it is foreshortened 3–13 % horizontally. Its outer edge sits nearer the eye and looks larger.
- Long horizontal straight lines that cross the crease therefore show a "V" kink. Keep anything that crosses low in contrast at the crease (the haze and the glint do this for the horizon). Keep the meter, speed lines, cards and the sun off it.
- The two pages face the eye differently. Held off-centre, one page is more oblique, and OLED off-axis luminance drops about 10–15 % with a slight colour shift. Value contrasts that matter (the bird, text, the reward ring) never rely on less than 20 L\* of difference.
- Type on the Duo is about 10 % larger than iPhone (§6) to cover the oblique view.
- Circles stay circles: the sun and the rings sit ≥ 120 pt from the crease, so a fold never splits them into a lens shape.

**Brightness per page and the fold blur.** iOS blurs one page for about 2 s when a fold starts from flat.
- Each page must read **on its own**. The left page carries the bird and the meter; the right carries the distance.
- Neither page relies on the other for its key information.
- Menus: average L\* between the pages differs by ≤ 30, so neither looks "off".
- Play: the left page is deliberately darker, but the bird's surroundings stay ≥ L\* 20 (the storm sky shade is capped at α 0.5 near the bird).
- The first 2 s of a run (countdown, first drop) use only big shapes on the bird's page: the 120 pt countdown digit and the bird. Nothing fine.
- "Bird on the other side" mirrors everything, including light direction and the shade.

**The title bird across both pages.** The spine is on the crease and each wing fills one page, its tip 12 pt from the outer edge. When the player tucks, the hardware halves fold *and* the art wings sweep back, so the gesture doubles. The tucked dart stays within ±0.17 w of the crease, never onto the menu card.

**The cover display** (466 × 678 pt portrait, OLED):
- Background `#000000` to `#06101C` (true black saves power and looks premium), with a horizon strip `#F2A65A` at 0.18 additive at 72 % height, and a 24 pt margin clear of the camera (top right).
- **Shut:** the title bird tucked into its dart, vertical, 150 pt tall, centred at 36 % height, with a soft key rim; "Open your wings" in `title` 30, and the Best/Daily card below.
- **Paused** (closed mid-run): the distance so far in `hero` 56, "Paused", and the bird resting on a single swell line. "Open to keep flying" in `body`.
- **Daily status:** a chip on the card.

| State | Chip |
|---|---|
| Ready | gold fill, ink text |
| Tried · practice | `surfaceRaised`, mist text |
| Done | a gold check and the distance |

- The streak shows as `flame.fill` with a number.
- Not on the cover: animation beyond a 4 s glint loop, or gold glows over navy.

**Store frames show the book.**
- **Frame 1 is a device composite:** a Duo held in two hands in book pose at about 140°, seen slightly from above and in front, at 2853 × 2007. The screen carries a real capture: the bird on the left page, the sun on the right, a Perfect ring mid-growth. The background is the Golden Hour sky, and the caption is "Fold your phone. Fly the bird."
- **Frames 2–3:** the same hands at 160° (soar) and 125° (dive), side by side with their real captures, showing the fold mapping.
- **Frames 4 onwards:** flat captures composed two-page (the storm left, the sun right).
- **Truthfulness:** composites use unedited captures, hands are neutral renders, and no UI is shown that the app doesn't have.

**The non-Duo fallback** (regular iPhones, no fold).
- **The canvas:** the same 951 × 669 world is aspect-filled. At 874 × 402 the scale is 0.919, so the view shows 951 × 437 of the world: the top and bottom 116 pt are cropped.
- **The composition still works**, because the two-page idea is horizontal: behind on the left 40 %, ahead on the right 60 %. The bird at 30 %, the sun at 80 %, the storm at the left edge.
- **Vertical fixes for the crop:**
  - the sun clamp (§2);
  - the far layers ≤ 14 % h;
  - the storm wall's height measured in visible-height fractions, not canvas fractions;
  - the HUD inside the safe area. The Dynamic Island sits at the left in landscape, beside the pause button: keep a 12 pt gap.
- **The crease glint disappears**, along with the gutter shade: with no hardware fold it reads as a rendering bug (REVIEW-1 P1-5). Milestone pulses go to the horizon haze instead. Two-page screens become one canvas with the same left/right split and a 24 pt gap; no glint.
- **The touch control is invisible.** The whole screen is the wing. What you see is the response:
  - pressing grows a **wing-shaped vignette** inward from both side edges (a soft curved shade `#04121F` at `0.12 × tuck`, 90 pt deep). The flat phone "closes" like the Duo would.
  - The first-run hint shows a hand glyph with a 56 pt press ring on the bird's half, once.
  - No on-screen button, ever.
- On a Duo with "Play with touch", use the touch vignette *and* keep the glint (the crease is still real).

## 9. Frame-by-frame critique (R2 build)

| Frame | P | Change |
|---|---|---|
| **all gameplay** | P0 | Confine the speed lines to the bird band (§5). |
| **all gameplay** | P0 | Golden Hour's upper sky is mauve-brown and the clouds taupe: apply the 5-stop sky, thin lit clouds and explicit far-sea hexes (§2, §3). |
| **all gameplay** | P0 | The far swells read as mountains: amplitude 6/13 → 2.5/5, ≤ 14 % h, shorter wavelengths, the glitter column across them. |
| all gameplay | P1 | The near sea is a flat slab 40–50 % of the frame tall: add lit faces, soften the sub-surface band (it reads as a second outline), and a deep gradient. |
| skim, daily | P1 | The trail checkerboard → a ribbon. The "1 km" toast is a grey-brown pill over the sun: use `surface` at 80 %, off the sun (layout: UX). |
| **soar** | P0 | "Perfect ×3" sits *on the bird*: anchor it to the bird's screen point (+40, −64) and keep it clear of the bird's rect + 24. Gold on peach lacks contrast: a 2 pt `#0E2438` at 45 % outline and a gradient `#FFE7A0` → `#F2A93B`. |
| perfect, chain | P0 | The ring is invisible: it was left behind at the touchdown x (squashed at the left edge under the storm, or off screen). It rides with the bird for 0.38 s as a 1 : 0.32 water ellipse, and a physical ripple stays behind. |
| tailwind, perfect | P1 | The drops are soft blobs: make them hard stretched discs. The TAILWIND badge and the grey ×3 chip don't match: both on `surface`, gold glyph. |
| **hint-open, hint-fold, splash** | P0 | A hard horizontal colour step in the sea: the pinned gradient's stops show. Use ≥ 7 eased stops. Also a hard rectangle at the storm's base (x 0–150 pt): feather it. |
| countdown | P1 | The gold "2" is on the sun: use foam with an ink shadow at `countdown` size, on the bird's page. The spread wings read as bunny ears (§4). |
| storm-close | P1 | The best R2 frame. Fix the stacked lobes, soft-top rain sheets, the left-page sky shade, a sunlit anvil rim. |
| **caught**, results, results-fresh, perfect-storm | P0 | The sun still blazes on the right: the caught dim isn't reaching the disk and glow. The storm is a flat grey cut-out (apply the 3 bands). On iPhone the goals still clip behind Fly again (layout: UX/App). |
| lighthouse | P1 | Shading (lit right +15 %, left −20 %), a rock with a foam ring, a 60 pt lamp glow, and a soft cone beam α 0.25 → 0. The card goes to `surface`. |
| mirror-flight | P2 | Mirrored correctly, with the sun ahead on the left. Check that the storm shade mirrors too. |
| **home, badges, home-duo-layout** | P0 | The title bird is two flat grey planks with torn edges and a metallic gradient: redraw it (§7). The attract trail runs through the wordmark block. The storm is pancakes. Daily uses `surfaceRaised`, not a second gold-rimmed slab. |
| duo2 home-tucked | P0 | The tucked title is an "M" spider: the dart rules (§7). |
| **duo3 store-04-perfect-chain** (founder) | P0 | The storm wall is a stacked tower of brown "pancakes" (identical alternating lobes, brown from the far-swell and sky tints) sitting on a hard grey rectangle (x 0–72 pt, from the far sea down to the near sea). It reads as a building, not weather. Apply S6: varied lobes, 3 value bands, a sunlit anvil rim, the 140 pt feathered base, and the left-page sky shade. The ring is also stranded at the left edge, and the callout floats 160 pt from the bird. |
| **duo3 duo-07-closed** (founder) | P0 | The cover display while a run is paused says "Best flight —" and the Daily status, and nothing about the run in progress. Show the §8 Paused state: "Paused" and the distance so far in `hero` 56, the bird on a swell line, "Open to keep flying"; Daily drops to a single chip. Also, "Best flight —" must show the stored best (6.4 km exists in the same run's Home), and the olive glow goes (§8). |
| **duo3 store-01, duo-ui-home-\*** | P0 | The title bird is still planks with torn edges (§7). The Home scrim is a visible brown box (navy at 0.38 over peach) whose hard right edge stops at about x 447, just short of the crease: use a feathered radial scrim, `#0B2236` at 0.30 with a 64 pt feather, ending ≥ 28 pt before the crease. The attract bird and its sparkle trail run through "your wings.": keep the attract run below the caption's baseline + 24 pt. The tucked pose (duo-ui-home-tucked) is no longer a spider, but it reads as a falling dove. Its tips reach x ≈ 640, next to the menu card: keep the dart within ±0.17 w. |
| **duo3 store-14-caught, store-07** | P0 | Caught: the sun is still at full brightness (the dim isn't applied), and the storm's scalloped edge parks *on the crease* (x ≈ 485 pt), where the fold kinks it. The caught sweep carries the edge to x ≥ 570 (the wall covers about 60 %), or stops it at ≤ 400. Rule: the storm edge never rests inside the fold band. store-07: the wall at x ≈ 395 is right, and its threat level is right. |
| duo3 store-02 to 06, 11 to 13, 15, 16 | P1 | The bird is still about 5 % of the frame (bird size §4); speed lines, the mud palette, the mountain far swells and the trail seams as in "all gameplay". The crease glint is correct in R2 (confined to the horizon): keep it. |
| goals | P2 | A rotate-and-scale page transition was captured: use the §5 crossfade; CI waits 0.6 s. |
| goals-late (Flocks) | P1 | Overlines and reward names → `mist`; gold only for done and current. |
| birds, birds-fresh, duo-ui-birds | P1 | The bird sits on its sun like an egg: move the sun to (72 %, 30 %), draw the bird 1.6× larger at tuck 0.3, cap the preview at 3×, and show locked birds as a 35 % silhouette with a lock. |
| settings | P1 | Gold icon tiles and toggles → `surfaceRaised` tiles with foam glyphs, and `accentOn` toggles. |
| pose | P2 | The olive circle `#232E33` → `#13304A`. |
| duo cover (shut, no run) | P1 | The olive glow → the §8 horizon strip; the bird 60 → 150 pt (dart). The paused-run case is the P0 above. |
| store-08 results (Duo) | P1 | The best UI frame: `hero` size, the count-up, the overline in `mist`. |
| store-13 Moonrise | — | The reference frame: every sky gets its single-hue discipline. |
| AppIcon-1024 | P1 | Concept A (§7). |
| badges | P2 | Rim by tier: bronze `#C98A5A`, silver `#C9D3DC`, gold `#F7C75B`. Clip the lighthouse beam to the disc. |

## 10. Round 3 art tasks

### Scene engineer (`Swoop/Scene`)

**S1. `ScenePalette`** (in `SceneLook.swift`): `static func palette(_ id: SkyID) -> ScenePalette` with every §2 row. `SceneBackdrop`, `SceneSea` and `SceneStorm` read it and drop `mixed(with:)`. The sky texture: 5 stops `[0, .45, .80, .96, 1]` plus ±1/255 dither.

**S2. Far swells.**
- amplitudes 6 → 2.5 and 13 → 5;
- `k1/k2` back 6/14 → 14/31, front 4/9 → 9/19;
- `farBackLift0/1` 62/40 → 34/18, `farFrontLift0/1` 26/30 → 14/14;
- yScale `0.8 + 0.2z`;
- `farShade` α 0.35 → 0.5 with a 30 pt haze top;
- the glitter column `0.12 w` wide, as dashes.

**S3. Clouds:** a thin lit streak texture 600 × 36 replaces the puffs; heights 18–40 pt, α 0.30–0.45, `palette.cloud`.

**S4. Near sea.**
- 7 eased stops (crest 0, crest .18, lit .26, mean .36, mean×.85 .48, deep .66, deep×.7 1);
- `bandWidth` 12 → 18, `bandDepth` 8 → 14, band α 0.36 → 0.18;
- `foamLineWidth` 2.6 → 3.0;
- lit faces: a second translucent strip on segments with dh/dx < 0 at α 0.12, or an `SKShader` with `u_sun_x`.

**S5. Glints:** `seaSparkleCount` 20 → 12 with a new 18 × 2 dash texture. Crest glints only within ±0.30 w of the sun.

**S6. Storm.**
- Lobes x `[64, 18, 58, 30, 70, 12, 46, 8]`, y `[490, 430, 352, 300, 214, 150, 70, 0]`.
- The wall fill gets 3 bands (top 0, body .4, base 1); the rim 3 pt in `palette.stormRim`.
- A 140 pt base fade, and rain sheets with soft tops (30 %) and bottoms (15 %).
- A `skyShade` sprite: α `0.10 + 0.40c`, reach `edge + 0.45w`, capped at 0.5 near the bird.
- Chop `9 + 5c`; sun dim `0.15c`.
- Feather the rectangle at the wall's base.

**S7. Caught:** make the dim reach `sunDisk`/`sunGlow`; the right page takes 60 % of the wash.

**S8. Bird.**
- `spreadElevation` 0.82 → 0.42, `farWingLift` 0.22 → 0.10, `flapAmplitude` 0.62 → 0.45, `handSweep` 0.24 → 0.34;
- spread length base 0.40 → 0.46, `tuckedChord` 0.36 → 0.42;
- the tuck-1 stretch 1.06 / 0.92 and the §4 nose angles, plus a 90 ms touchdown squash;
- `birdUnit` 84 → 107, `birdZoomResist` 0.6 → 0.7;
- the contour 1.25 pt at 55 %, and a new `BirdArt.backLinePath` stroked 1.5 pt in `palette.birdKeyRim` at 80 %;
- the contact shadow, and the dark-bird halo.

**S9. Title bird** (`titlePath`, `titleBody`, `dorsalWing`):
- dihedral +6° / −3°, the wrist kink at 0.38, chord taper `0.16h → 0.05h`;
- delete the notch term (`c -= chord*0.10*…`);
- expose `trailingBand` and `primaries` paths;
- tuck keeps the chord ≥ 0.6 and stays within ±0.17 w of the crease;
- the body's centre line at exactly w/2.

**S10. Trails:**
- the ribbon texture solid along its length;
- segment width `len + w*0.6`;
- `trailWidth` 7 → 9, `trailWidthFast` 6 → 5, `trailGlowWidth` 2.6 → 2.0, `trailAlpha` 0.85 → 0.8, `strandWobble` 7 → 6.

**S11. Speed lines:** count 16 → 10, within `birdY ± 0.18h` and below the top 72 pt, lengths 80–220, α ≤ 0.28, tapered.

**S12. Perfect ring:** it rides with the bird; `perfectRingTo` 170, `perfectRingTime` 0.38, y-scale 0.32, `#FFD45E` / `#FFF3C4`. Splash: one mist puff ≤ 90 pt at α ≤ 0.5, 18–26 hard drops.

**S13. Lighthouse:** two-tone shading, a rock with a foam ring, a lamp glow, a cone beam.

**S14. Publish `birdScreenPoint`** (canvas pt) for the App's callout.

**S15. Duo fold.**
- The glint, only when the App reports `hasFold` (a new `SceneDriver.hasFold`), with `creaseAlpha` 0.08 and `creasePulseAlpha` 0.12 (keep). Off on non-fold phones, where the milestone pulse goes to the horizon haze.
- The gutter shade on tuck (60 pt per side, α `0.10 × tuck`, Duo only).
- Keep the sun and rings ≥ 120 pt from x 475.
- The storm edge never rests inside the fold band (x 447–503): the caught sweep ends at x ≥ 570.
- On iPhone, the storm height in visible-height fractions.

### App engineer (`Swoop/UI`)

**A1. Type tokens** in `SwoopTheme` (§6), with Duo/iPhone sizes from `info.isCompact`; replace all 25 ad-hoc sizes.

**A2. Colours:** `surface` `#0B2236`, `surfaceRaised` `#143352`, `stroke` (white at 9 %), `accentOn` `#5CC2D6`, reward gold `#FFD45E`. Overlines use `mist`.

**A3. Shapes:**
- `cardRadius` 26 → 32 / 28, card padding 20 → 16, `buttonRadius` 20 → 16 / 12;
- primary height 60 → 64 / 56;
- secondary 56 / 48 on `surfaceRaised` with the hairline (no gold stroke).

**A4. HUD:**
- distance `number(50/40)` → `hud` 46/36;
- `ChainCount` and the TAILWIND badge on `surface@0.62`;
- toasts and the lighthouse card on `surface@0.8`;
- the countdown at `countdown` size, foam with an ink shadow.

**A5. Callout:** anchor to `birdScreenPoint` + (40, −64), clear of the bird's rect + 24 (this replaces `PlayLayout.calloutY` 0.34); the gradient, outline and timing from §5/§9.

**A6. Gold budget:** Settings tiles go to `surfaceRaised` with foam glyphs and `.tint(accentOn)` toggles; reward names and overlines in Flocks and Results go to `mist`. The Results distance counts up over 0.8 s (instantly under Reduce Motion).

**A7. Title bird colours** (`BirdPreview`): vertical chord shading, a white trailing band, black primaries with mirrors, a 40 pt drop shadow; then the countdown morph (0.6 s).

**A8. Birds:** the sun at (72 %, 30 %), the bird 1.6× larger, the preview capped at 3×, locked birds at 35 %.

**A9. Mud fixes:** the pose circle `#13304A`; no gold-over-navy glows anywhere; 🔥 → `flame.fill` `#F39A4B`.

**A10. Icon:** redraw `AppIconPainter` as concept A, re-export through CI `screen=icon`, and commit the PNG (the committed one is still R1's).

**A11. Transitions:** crossfade plus a 24 pt slide over 0.32 s. Pause and the Home icon buttons get Liquid Glass behind `#available(iOS 26, *)`.

**A12. Duo pages:**
- no card or line spans x 475 ± 28 (two cards per two-page screen);
- the page L\* difference ≤ 30 in menus;
- the cover display art (§8): true black, the horizon strip, the 150 pt dart bird, the Daily chips;
- **P0, founder:** the cover's Paused state while a run is paused (the distance so far in `hero` 56, "Paused", "Open to keep flying"), and "Best flight" showing the stored best instead of "—";
- the Home scrim: a feathered radial `#0B2236` at 0.30 (64 pt feather) ending ≥ 28 pt before the crease, replacing the brown box.

**A13. Non-Duo:** the touch wing vignette (both edges, `#04121F` at `0.12 × tuck`, 90 pt deep), and the one-time press-ring hint. No crease glint unless `hasFold`.

**A14. Store frames:**
- `ci/duo-scenarios.txt` captures for a 160° soar and a 125° dive, plus the Perfect at +0.12 s;
- a composite template (Duo in hands at 140°) fed by those captures; captions per §8;
- a `duo3` run to re-shoot every Duo frame after S1–S15.

### Conflicts
Checked against `design/UX-SPEC.md` (R3).

| # | Topic | Art | UX | Resolution |
|---|---|---|---|---|
| 1 | Toasts | on the bird's page under the HUD, or off the sun | the far page at 60 % height, over the sea | **UX's**: it keeps them off the sun, which was the art concern. Style: `surface` at 0.8. |
| 2 | Fold band | ±28 pt for art (x 447–503) | x 456–496 for layout, with content pages 24 pt clear (x 432 / 520) | Compatible: Art's ±28 is a stricter rule for art only (glyphs, the sun, the storm edge) and sits inside UX's margins. |
| 3 | Non-Duo touch feedback | an edge wing vignette plus a one-time press ring | a 44 pt wing glyph in the bird page's lower outer corner that folds with u, plus a ripple on the first 3 runs | **Use both, with roles.** The UX glyph is the explicit feedback, styled foam at 70 % with 2 pt rounded strokes, no fill and no gold. The vignette drops to `0.08 × tuck` as the ambient "closing" feel. Art's one-time press ring is dropped in favour of UX's 3-run ripple (foam, 0.2 s, 56 pt). |
| 4 | Cover bird size | the 150 pt dart at 36 % height | the bird glyph 96 pt, the stack at 42 % | **Both, by state.** Shut or Home: the 150 pt dart. Mid-run and Results, which carry more content: 96 pt. UX's mid-run content (PAUSED, hero, mini meter, Perfects line, "to your best", Keep flying here / End flight) is adopted. Art adds the black field, the horizon strip and `hero` 56. |
| 5 | Two-page layout on iPhone | §8: one canvas with the left/right split and a 24 pt gap | pages mapped to x 419–455 on iPhone | Compatible: the same split. No glint on iPhone. |
| 6 | Seated pose / split deck (UX D2, D5) | not covered in §8 | a 669 × 440 play band, a deck below | **Art addendum:** the band keeps the bird at 30 % and the sun at 80 %, with the far layers ≤ 14 % of the *band* height. The deck is solid `surface` and meets the band with a 1 pt hairline, not a gradient. |

Accepted from UX without change:
- the callout flipping below the bird when it is under the HUD;
- 48 pt visual / 56 pt tap for secondary buttons;
- overlines 11 and chips 12 as exceptions to the body ≥ 13 floor;
- the count-up only with Fly again live from frame 1;
- 🔥 kept in the share text.

Results clipping on iPhone is UX/App layout; the art spec has nothing to add.
