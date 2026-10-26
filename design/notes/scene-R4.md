# Scene R4 hand-off (Scene engineer)

## Done
- **P0-2: the storm is a weather wall.**
  - **The shape.** The stacked pillar under a disc is gone. One node holds three layers:
    - a lobed core silhouette whose front runs through the lobe centres, so no edge ever shows;
    - five lighter back billows;
    - eight front lobes on a new soft-rimmed, sun-lit `stormLobe` texture (radii 1.3/0.7/1.1/0.6/1.4/0.9/1.0/0.8, min 0.6×, never alternating). They roll slowly, about 4 pt/s; the roll is off under Reduce Motion.
  - **The anvil.** It overhangs about 1.4× the column depth and ends in a tapered lip, with no disc. The 3 pt sunlit rim runs along its top only.
  - **The fills.** The core goes body → top shelf → rain-curtain base, feathered into the far sea. The anvil is lit on top.
  - **The rain.** Sheets and rain are constant under the wall (sheet α 0.20 → 0.50, drops α ≥ 0.24).
  - **It chases.** The new `SceneStormMap`, pure and tested, maps the gap to the meter fill, sqrt(gap / (5 × 3000)), and maps that fill to the edge:
    - a 24 pt hint at a full lead;
    - 40 % of the bird page at the storm-close fill (0.17);
    - `anchorU − 36` at contact.
  - **Monotonic and smoothed.** The mapping is monotonic (tested), and the screen edge closes as the gap closes (tested). The edge is eased at 3.5/s, so a Tailwind or a lighthouse visibly shoves it back. Height, darkness and rain follow the same fill.
  - **Caught.** It still sweeps to 0.62 w (tested ≥ 0.6 w). In flight its edge now stays ≤ 250 pt, never in the fold band (tested).
- **P0-5: the title bird and one mark.**
  - **Tucked.** It morphs point for point from the spread "M" into one teardrop dart:
    - the leading edge leaves the shoulder at 25–29° below horizontal;
    - the wing fills everything between the leading edge and the body (mid-chord ≥ the root chord);
    - the tips end 0.18 h behind the tail;
    - the body stretches 6 %;
    - the mirrors are empty past tuck 0.5, so there are no "feet".
  - **Size.** Width is 0.259 w at full tuck (checked in a Node port at 254, 393, 420 and 670 pt box heights). That keeps it inside ±0.17 w, and above the App's 25 % refit threshold.
  - **Mid-tuck.** The poses sweep back smoothly (0.78 / 0.49 / 0.30 w at u 0.25 / 0.5 / 0.75), with no drop to −50°.
  - **Detail.** `titleDetail` adds `beakLower` and `headContour` (juror #25).
  - **The mark.** New `BirdArt.markPath(width:height:)` is the single brand mark: the dorsal "M" as one rounded-stroke glyph plus a head dot. `markLineWidth(forHeight:)` gives 2 pt at 24 pt.
- **P1-8: rings escalate.** Foam #F2F7FA for ×1–4, gold #F7C75B for ×5–9, reward gold #FFD45E with a second ring from ×10 (`SceneEffects.ringTier`, tested). The punch-in fires only at milestones (`FlightScene.isChainMilestone`: 3, 5, 10, 15…; tested).
- **P1-9: the splash thuds.**
  - The camera dips about 8 pt over 0.25 s (ω 12), and the bird dunks 6 pt nose-down for 0.3 s.
  - 36–48 hard drops are thrown higher, with a 1.3× mist puff (117 pt at α 0.5) and a foam crater ring left on the water.
  - It now reads heavier than a Perfect.
- **P1-10: the sea, the clouds and the burst.**
  - **Depth.** The gradient reaches the deep about 300 pt below the mean line (stops 0/.18/.26/.33/.40/.48/1), and the lit faces are at α 0.12 per layer.
  - **Lace.** Ten foam streaks (1.5 pt, α 0.25, 40–120 pt) ride the faces along the local slope.
  - **Glitter.** The sun's glitter column now continues down the near sea.
  - **Surface.** It is drawn as midpoint-quad curves (Catmull-Rom-like), so chop rolls instead of zigzagging. The chop wavelengths are ≥ 120 pt, and the caught / Results sea is calm.
  - **Clouds.** At most 4 streaks at α 0.30, with alpha-feathered ends (a `destinationIn` ramp) and a 3-stop profile.
  - **Perfect burst.** No more white spiky blob: hard pale-gold drops at 60 % size, one 90 pt mist puff at α 0.5, and a softer bloom. Gold stars appear only from ×5 (3) and ×10 (6), and there are no stars on the Tailwind trail (those motes are soft dots now).
- **Other Scene findings.**
  - The trail has five nested layers (a smoother fade) and a 24 pt head taper, so there is no square cap (juror #22).
  - `sunCanvasPoint` is published for keeping text off the sun (P0-3 / UX P1-3).
  - `gutterEnabled` turns the gutter off in store captures (juror #26).

## Files
- **Rewritten:** `Swoop/Scene/SceneStorm.swift` (with `SceneStormMap`).
- **Patched:** `BirdArt`, `SceneLook`, `SceneTextures` (cloud streak v2, `stormLobe`), `SceneEffects`, `SceneSea`, `SceneBirdView`, `SceneBackdrop`, `FlightScene`.
- **Tests:** `SwoopTests/SceneTests.swift` gains 6 new tests (dart, mark, storm map, on-screen chase, ring tiers / milestones), and the punch test now uses chain 3.
- **NEEDS:** `design/NEEDS.md`, "Scene → App (Round 4)".

## Deviations
- **Edge mapping.** Juror #4's `x_edge = 40 + 360·c` would put the storm at about 250 pt at the start (0.4 fill). I used ROUND-4's own rule instead (a hint at a full lead, 40 % of the bird page under 15 %, behind the bird at contact). It is monotonic and the HUD shares it.
- **Dart width.** The tucked dart is 26 % wide, not narrower, so the App's 25 % refit can't blow it up.
- **Splash particles.** I followed the player's "2× the drops" over ART's 18–26 (the panel says it must read heavier than a Perfect).

## NEEDS (App)
- Draw the meter with `SceneStormMap.meterFill`.
- Use `isChainMilestone` for the callout and hit-stop.
- Use `sunCanvasPoint` for text placement.
- Set `gutterEnabled = false` in store mode.
- Put the "Splash" word and the "×N lost" pill at `onBirdPoint`.
- Use `BirdArt.markPath` everywhere outside gameplay; colour `beakLower` and stroke `headContour`.

## Check on frames
- store-04 / store-07 / duo-03 / duo-04: the wall reads as a shelf cloud with rain under it, and its x clearly differs between a 77 % and a 9 % lead.
- store-17 / home-tucked: the dart, with no legs or feet.
- skim / perfect: no white starburst. splash: bigger than a Perfect.
- The sea: lace, lit faces and the glitter column; no ridge in the storm-close or caught frames. The clouds have soft ends.
