# Swoop: design review 1 (Round 1 build, 26 Oct 2026)

*Reviewer: design critic. Sources: 27 iPhone 18 Pro frames (r2), 14 Duo store frames + 7 Duo UI frames (duo1),
balance CI numbers, GAME-DESIGN.md, the R1 hand-off notes and the code. The duo-01..08 gameplay content was ignored,
as instructed (the test-timing bug).*

## Score: 6 / 10

The bones are good. Golden Hour reads warm and calm. The big swells look great on the Duo's near-square canvas
(store-02, -03, -13), and Moonrise (store-13) is a frame worth putting on a store page. The rounded-heavy type and the
navy/gold UI system hang together, and splitting pages across the fold (Flocks, Birds, Settings, Results) feels
right for a Duo. But **satisfaction, the founder's #1 bar, isn't there yet.** No frame shows a readable Perfect (no
ring, callout or chain number). The bird is ~5 % of canvas width. Trails are flat bars like highlighter strokes. The
storm, the only antagonist, is missing from 10 of 14 store frames and is a grey smudge when it shows. A casual player
splashes **2.7× more often than they score a Perfect** (9.6 vs 3.5/min), a novice 11× (5.6 vs 0.5), and Tailwind, the
best moment, is almost never reached below expert. The title bird, the one image that sells "your halves are wings",
is a headless bowling pin that turns into a spider when tucked.

Fix the feel loop and the hero art, and this is an 8.

---

## P0: must fix before launch

**P0-1. Perfects are too rare and splashes too common: the core reward loop is upside-down** (balance numbers; results
frames show "1 Perfect" in a 10.5 km run and "0 Perfects" in a first run).
- Casual: 3.5 Perfects/min against 9.6 splashes/min. Novice: 0.5 against 5.6. A first-timer will see roughly one
  Perfect per run and a splash every ~10 s. That is the opposite of "satisfying".
- Casual also runs short of its target: 111 s median against the design's 120–180 s.
- Targets for the next harness pass:

  | Player | Perfects/min | Splashes/min | Run length |
  |---|---|---|---|
  | Novice | ≥ 2 | ≤ 4 | 45–75 s |
  | Casual | ≥ 7 | ≤ 4 | 130–170 s |
  | Expert | — | — | 6–8 min |

- Fixes, in order:
  1. **Landing assist:** wings open (u < 0.35) and touchdown due within 0.25 s → rotate the velocity toward the
     surface tangent by up to 7° (Alto does this invisibly).
  2. Windows: `perfectAngleDeg` 14 → 18, `perfectSlopeDeg` −4 → −2, `goodAngleDeg` 30 → 36; `splashKeep`
     0.75 → 0.82 (still wet and heavy, just less costly).
  3. The tutorial swell guarantees a Perfect with no input, so everyone hears the chime in the first 8 s.
  4. Storm post-cruise acceleration 2.5 → 3.5 pt/s² so expert doesn't run away (Core: 17° alone = expert +30 %).

**P0-2. A Good landing breaks the chain, so Tailwind is out of reach for most players** (daily-results: expert,
67 Perfects but a longest chain of 4; casual results: chain 1).
- Change: a chain breaks only on a **splash**. Good landings hold it and don't add to it.
- Show the chain count always ("×5") instead of pips that loop back to one. The chain frame (chain=5) shows one lit
  pip, which reads as "1".

**P0-3. The Perfect moment can't be seen** (perfect, chain, store-04-perfect-chain).
- In none of these frames is there a ring, a callout or a glow. Store-04 is called "perfect chain" and shows a
  "10 km" toast instead.
- Add at touchdown: a gold ring growing 40 → 160 pt over 0.35 s (a second ring at 0.08 s on chains ≥ 2); a small
  "Perfect ×N" callout 40 pt above the bird (0.6 s, rises 30 pt, fades); a 35 ms hit-stop and a 3 % punch-in.
- Freeze store-04 at +0.12 s after the Perfect so the ring and the callout are in the frame.

**P0-4. The bird is too small to love and too faint to read** (skim, splash, store-02, store-07: ~100 px on a
2000 px-wide frame).
- `SceneLook.birdUnit` 64 → 84 and `birdZoomResist` 0.45 → 0.6.
- Add a 1.5 pt darker rim to the body so the white gull doesn't vanish against the pale sage far swell (store-02,
  lighthouse).

**P0-5. The bird flies into the HUD** (tailwind: the bird sits right under the lead meter at y ≈ 12 %; mirror-flight
and store-12 do the same on the far side).
- Clamp the bird's top to 22 % of the height (was 12 %), or zoom out sooner.
- The water visibility rule can give a little ground: at y = 22 % the swells still show in every frame here.

**P0-6. The results card clips on regular iPhones, and it clips the hook** (results, daily-results). The lighthouse
line ("Past Halcyon Point") is cut in half behind Fly again, and the Flock goals aren't visible at all. On the Duo
(store-08) the card is excellent, so it's purely a compact-height problem.
- At heights below 420 pt, fold the three stat tiles into one inline row ("1 Perfect · chain 1 · 2 lighthouses"),
  then show the goals.
- Or let the card scroll, with Fly again pinned.

**P0-7. The lighthouse is missing at the lighthouse moment** (lighthouse, store-06).
- Both frames are frozen on the pass event, and neither shows a lighthouse, a beam or a rock. The milestone is only
  a card.
- Check `FlightScene.updateLighthouse` on the `skipTo` path (cache X/Y, `lighthouseKeepBehind`) and confirm the rock
  isn't drawn under the sea.
- The pass should put the tower on screen beside the bird, beam sweeping across the right half.

**P0-8. Two toasts stack at the lighthouse** (lighthouse, store-06: "Old Harry" plus "4 km · Still ahead of the
storm"). The first lighthouse sits at 4 km, so this happens to **every** player.
- Suppress the km toast within ±400 m of a lighthouse. The lighthouse card wins.

## P1: should fix before launch

**P1-1. The title bird is the Duo pitch, and it looks cheap** (home, store-01, duo-ui-home-tucked).
- The front-on body is a featureless white pin: no head, no beak, no tail. Tucked, the wings drop into an "M" and the
  bird reads as a spider or a ghost.
- Redraw it as a **dorsal view (from above and behind)**, with a head, beak, a tail fan and dark primaries. The wings
  lie flat across both halves.
- Tucking sweeps the wings back into a dart, tips pointing down-and-back, never hanging like legs. That matches the
  in-game tuck silhouette, so the two read as the same bird.
- Keep the body on the crease; that idea is right.

**P1-2. The attract bird collides with the title text** (store-01: its trail cuts through "Swoop"; home-duo-layout:
spray and bird sit under the caption; badges/home: the bird clips the title bird's wing).
- On Home, keep the attract run in the lower 40 % of the canvas, or scrim the text block (navy at 35 %, 24 pt
  feathered).
- Raise the wordmark from ~40 pt to 64–72 pt with a 24 pt left margin. On the Duo it currently sits ~15 pt from the
  edge.

**P1-3. The trails look cheap** (soar, tailwind, mirror-flight, store-03, -05, -06).
- They are constant-width, hard-ended rectangles. The tailwind frame's trail is a flat grey rod, like a contrail
  that has hardened.
- Taper width 1 → 0 and alpha 0.85 → 0, cap the length at ~0.5 s of flight, add a soft additive glow. Tailwind:
  two gold strands with a slight sine wobble, plus motes.

**P1-4. The far swell layer reads as sand dunes or hills, not sea** (every gameplay frame).
- The flat sage-khaki band is the most "cheap"-looking element on screen.
- Tint it ~55 % sea-mid + 45 % sky horizon, add a 1 px lit crest line, let the sun glitter cross it, and give the
  mid layer a faint vertical gradient.

**P1-5. The crease glint looks like a rendering bug** (store-02 to -07, -11, -13).
- It is a full-height vertical light shaft at x = 1000, running through the sea and the sky.
- Keep it to a ±40 pt band around the horizon, at alpha ≤ 0.12, and pulse it only on milestones.

**P1-6. The storm isn't present enough, and doesn't look like a storm**
- Store-07 ("storm") shows a dark sliver at the left edge. Caught/store-14 show a blurry smoke smudge while the sun
  still blazes on the right ("calm wash" was asked for). 10 of 14 store frames have no chaser at all.
- Always draw a distant storm band on the left edge, height and darkness mapped to the gap (faint at full lead).
- Give the wall a crisp anvil silhouette with a lit top rim, rain sheets, and darker, choppier sea under it.
- On caught: dim the sun 50 %, desaturate the right half 30 % over 1.5 s, and bob the bird level, not nose-up on a
  slope (results, store-14).
- Re-shoot store-07 at lead 0.06, when the wall covers ~40 % of the left half and lightning is in frame.

**P1-7. The lead meter sits pinned at full, so there's no tension** (skim, soar, perfect, chain, tailwind, daily,
store-02 to -06).
- Show the gap against `fullLead` 3000 with headroom, so a 2400 pt start reads 60 %.
- Put a small storm cloud icon at the left end and the bird on the knob.

**P1-8. Speed isn't readable, and the speed goals are unreadable** (goals, store-08/-09: "Reach 230 m/s").
- 230 m/s is about 830 km/h for a gull, and nothing in the HUD shows speed, so the goal can't be tracked.
- Replace the three speed goals with visible ones: "Hit full speed (gold streaks) 3 times", "Launch off a crest at
  full speed".
- Make full speed visible: speed lines from 900 pt/s (now 1300), gold above 90 % of max; a 2 % zoom-out kick above
  1800 pt/s; wind streaks across the far half.

**P1-9. The HUD distance has no units story.**
- It ticks up to "45,803 m", while the toasts say "10 km" and the results say "10.5 km".
- Above 1 km, show "4.06 km" with the hundredths still ticking. Below that, keep metres.

**P1-10. Birds look identical and the dark ones vanish** (birds, birds-fresh, store-10).
- Puffin, Swift and Storm Petrel are dark birds on dark navy tiles: give each tile its sky's gradient as a backdrop.
- The personality is meant to be the wing shape, but it isn't visible. Make the shapes differ: Swift sickle wings,
  Albatross long and straight, Puffin stubby and round.
- The big preview (store-10) exposes fin-like wings on a lozenge body: redraw it, or show the bird at 2× not 5×.
- On the Duo, the bottom 40 % of the Birds page is empty. Move the skies there.

**P1-11. Settings leads with the destructive button** (settings, duo-ui-settings).
- "Reset progress" is the biggest, brightest button on the page. Make it a plain red text row at the bottom of the
  right page, behind its confirmation. Show "No flights yet" in place of "best 0.0 km · 0.0 km flown".

**P1-12. The Flocks ladder and goals clip on iPhone** (goals, goals-late).
- The third goal ("Reach 230 m/s", "Touch the clouds 6 times in…") is cut off. Scroll the ladder to the current
  rank on open, and put "1 of 3 done" on its own line (no "1 of / 3 done" widow).

**P1-13. Store frames aren't store-ready yet.**
- **Keep:** store-13 (hero), -03, -08, -09. **Fix:** -04 (P0-3), -06 (P0-7), -07 (P1-6), -10 (P1-10), -11 (add a
  "Daily #298" HUD tag; today it can't be told from Flight). **Retake:** countdown (captured in portrait as a blank
  navy frame) and storm-close (screenshot failed).
- A flat frame can't show the USP. Lead the set with a composite: a Duo held in book pose, mid-fold, with the bird
  across both halves and the caption "Fold your phone. Fly the bird."
- Confirm that App Store Connect accepts 2853 × 2007 for the Duo class. Also produce 6.9" landscape frames.

## P2: polish

- **Icon** (AppIcon-1024). Right concept (wings over a fold line), but the gold reads as a sand dune, the wing tips
  have clipped grey triangles (an artefact), and the cartoon eyes don't match the game. Make the gold a wave with a
  foam lip, drop the eyes, keep the faint centre seam.
- **Badges.** Coherent, but the gold "sand" problem repeats, and the chain5 rings read as plain ovals. Use the gold
  Perfect ring instead.
- **Ranks.** Six of the 16 ranks reward only "A new title", which reads as nothing. Give each one a trail colour or a
  sky variant. The design said 15 ranks; the UI says 16, so pick one.
- **The distance readout over the sun** (hint-open, skim) loses contrast. Add a 0.25-opacity navy shadow at an
  8 pt radius.
- **Hint copy on touch.** Check that touch input gets "Hold on the way down" and not "Fold…". The hint-fold frame,
  on an iPhone without a hinge, shows "Fold".
- **First-run results** (results-fresh, duo-05) say "Best 4.5 km" with no fanfare. Make the first flight a
  "First flight!" chip and point to the next lighthouse ("Saltlight at 9 km").
- **Results hook.** Add a "0.6 km short of {next lighthouse}" line under the distance; near-misses drive one more go.
- **The countdown** should morph the big title bird down into the play bird, so the wings-equal-halves mapping
  carries into the run.
- **Cover display** (duo-ui-cover). Good copy. Move the stack up about 15 % and show the bird art bigger.
- **The Home menu** on the Duo hides the sea on the right half. Drop the menu panel's alpha to 0.85 and narrow it
  by ~8 %.

## Duo-first and addictiveness, in brief

- **Duo:** the play composition works (bird and storm on the left half, sky and swells ahead on the right; the meter
  stops at x ≈ 925 of 1000), and the two-page menus are the UI's best Duo use. But only the title bird makes the
  halves into wings (P1-1), and the idea is gone by the countdown. Fix: the countdown morph (P2), plus a soft
  wing-shaped vignette on each half that deepens with the tuck.
- **Addictiveness:** novice runs are on target, casual is short (P0-1), expert just under 6 min. Fly again is big and
  first, but the goals behind it clip on iPhone (P0-6) and there's no near-miss line (P2). Daily streak, three goals
  and the ladder are enough for 1.0 once every rank pays out.

## Top 10 changes for Round 2

1. Landing assist (7°), Perfect 14° → 18° and slope −4° → −2°, Good 30° → 36°, `splashKeep` 0.82; harness to the
   targets in P0-1, storm post-cruise 3.5 pt/s².
2. A chain breaks only on a splash; always show "×N".
3. Perfect juice: growing gold ring, "Perfect ×N" callout, 35 ms hit-stop, 3 % punch-in. Tutorial swell guarantees
   the first one.
4. Bird +30 % (`birdUnit` 84, zoom resist 0.6) with a dark rim; clamp the bird's top at 22 % so it never enters the
   HUD.
5. Redraw the title bird as a dorsal view that folds into a dart (no spider), and keep the attract bird and trail
   away from the wordmark.
6. Tapered, fading, glowing trails, with a two-strand gold Tailwind ribbon.
7. Far swell recoloured to sea-plus-horizon with a lit crest line; crease glint limited to the horizon band.
8. A storm that is always present and scaled to the gap: crisp anvil, rain sheets, a dimmed world when caught; a
   lead meter with headroom and icons.
9. Fix the lighthouse: tower on screen at the pass, no km toast within 400 m. Fix the results clipping on compact
   heights.
10. Replace the m/s goals with visible full-speed goals (gold speed lines); HUD in km above 1 km; Daily tag in the
    HUD; re-shoot store-04, -06, -07, countdown and storm-close, and add a mid-fold device composite as store
    frame 1.
