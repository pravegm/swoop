# Scene R3 hand-off (Scene engineer)

## Done (ART-S1–S15, UX-S1–S3, the scene parts of UX-D3/D5, QA-2 P2-2/P2-9)
- **S1 palette.** `ScenePalette.palette(_:)` in `SceneLook.swift` holds every §2 row for the five skies, plus a `sunline` stop.
  - Backdrop, sea, storm, props and bird read it; `mixed(with:)` is gone from the sky, far sea and storm.
  - The sky is a 5-stop texture (0/.45/.80/.96/1) with ±1/255 dither. Reward gold is now #FFD45E / #FFF3C4.
- **S2 far swells.** Amplitude 2.5 / 5 pt, k 14/31 and 9/19, lifts 34/18 and 14/14, yScale 0.8 + 0.2z.
  - The front layer's top 30 pt hazes into the back layer. The far shade is at α 0.5 and runs to the bottom (no hard edge).
  - The glitter column is 0.12 w of dashes whose spacing grows downward, shimmering at 3 Hz. A 60 pt horizon haze sits at 0.5.
  - The sun sits at 0.16 h, clamped to the visible top − 90 (iPhone crop). Monsoon: the disk at 40 %, the glow 1.6×.
- **S3 clouds.** Flat-bottomed, lit-from-below streaks (300–700 × 18–40, α 0.30–0.45, `palette.cloud`). The touchable band uses the same texture.
- **S4 sea.** Seven eased stops (pinned to fixed sea heights, so no colour steps), the band at 18/14 and α 0.18, foam 3.0.
  - Lit strips on the sun-facing faces (two soft layers at α 0.06 each). Chop is 9 + 5c.
- **S5 glints.** Crest glints only within ±0.30 w of the sun, α 0.55 → 0.85 at full speed. The 4-point twinkles are now 12 dash glints on the sun's side.
- **S6 storm.** The lobes are varied, never alternating. The fill has 3 bands (top shelf, body, rain base fading out over 140 pt).
  - A crisp 3 pt `stormRim` runs along the anvil's top edge.
  - The wall now sits **behind the far sea** (backdrop z −16). That kills the hard rectangle at its base.
  - The sky shade is α 0.10 + 0.40c, reaching edge + 0.45 w, capped at 0.5 at the bird.
  - The rain sheets have soft tops and bottoms. The sun dims 0.15c. Flashes last ≤ 120 ms, at most 2 per second.
- **S7 caught.** Over a 1.5 s ease-in-out the sun and glow dim by half (tested), and the 30 % wash drops to 60 % on the far page.
  - The wall sweeps to 0.62 w (tested ≥ 0.6 w). In flight its edge stops at 0.3 w + 160 = 445, never inside the 447–503 fold band (tested).
- **S8 bird.**
  - Wing: elevation 0.42, far lift 0.10, flap 0.45, hand sweep 0.34, spread length base 0.46, tucked chord 0.42 (no more rabbit ears; tested).
  - Size: `birdUnit` 107, zoom resist 0.7.
  - Outline: light birds get a 1.25 pt ink contour at 55 %; dark birds get the key rim plus a halo over the sea; Monsoon gives every bird the contour.
  - New paths: `backLinePath` and the near-wing leading edge, stroked in `birdKeyRim`.
  - Body: the belly 12 % darker; a tuck stretch of 1.06 / 0.92; a 90 ms touchdown squash.
  - Nose angles while airborne: +4°, −6°, −10°. A contact shadow while skimming.
- **S9 title.** Dihedral +6° / −3°, a wrist kink at 0.38, chord tapering 0.16 h → 0.05 h, a smooth trailing edge (no notches), the body's centre line on w / 2.
  - Tucked, it is a straight-edged dart, 0.320 w (within ±0.17 w), with the tips past the tail and ≥ 62 % of the chord.
  - New `BirdArt.titleDetail(...)` returns the band, primaries, mirrors, beak and beak-spot paths for the App.
- **S10 trails.** One continuous ribbon: 3 nested tapered fills, each starting further along, so the alpha fades toward the tail with no seams.
  - Width 9 → 14, α 0.8, an additive glow at 2.0× and α 0.12–0.35. The Tailwind strands are 0.4× wide, wobbling 6 pt.
- **S11 speed lines.** At most 10, in ±0.18 h around the bird and below the top 72 pt, 80–220 long, α ≤ 0.28, gold at ≥ 90 % of max speed. Reduce Motion: a 6 % edge vignette in the trail colour.
- **S12 Perfect.**
  - The ring rides with the bird as a 1 : 0.32 ellipse, 40 → 170 over 0.38 s (ease-out cubic). A faint ripple stays at the touchdown. Reduce Motion: it appears at 120 and fades over 0.3 s.
  - Splash: 18–26 hard drops (a new drop texture with a darker underside), one ≤ 90 pt mist puff at α 0.5, the bump ≤ 6 pt.
- **S13 lighthouse.** Lit +15 % ahead, −20 % behind. A foam ring over the far-front sea, a 60 pt lamp glow, a soft cone beam at α ≤ 0.25.
- **S14 / UX-S1.** `FlightScene.onBirdPoint` reports at ≤ 30 Hz in view points, y down (tested). `birdCanvasPoint` is available every frame.
- **S15 fold.** The glint shows only when `layout.hasFold`. The milestone pulse goes to the glint on a Duo and to the horizon haze elsewhere.
  - The gutter shade on a tuck is 60 pt per side at α 0.10 × tuck, Duo only.
  - The sun stays ≥ 280 pt from the crease, and the ring rides 16 pt behind the bird so it stays ≥ 120 pt away. The storm height is in visible-height fractions.
- **UX-S2.** The PB buoy shows in Flight only. **UX-S3:** `playTitleMorph(tuck:)` runs a 0.6 s scale-and-slide with a crossfade at 50 % (tested); Reduce Motion gives a crossfade only.
- **UX-D3.** `fineDetail` hides fine sparkle while the App's blur guard is up. The scene also hides it during the countdown and the first 2 s of a run (ART §8).
- **UX-D5.**
  - Play band: a 669 × 440 (or 466 × 328) canvas works through `ScreenLayout.make`. The bird stays at 30 %, framing uses `visibleRect`, and the far layers are a fixed ≤ 14 % of h.
  - Thermal: `effectsQuality` sets particles to ×0.7 and rain to 60 %.
- **QA-2 P2-2.** The sea rebuilds for the storm only while the chop zone overlaps the view. It uses `SeaProfile.samples(into:)` with one reused buffer, so no allocation (tested ≤ 10 rebuilds in 2 s with a close storm).
- **QA-2 P2-9.** The `-swoopDemo` check and the `SWOOP-T frame 120` print are now `#if DEBUG`.
- **ART §5.** The camera's zoom τ is 0.35 s (ω 2.86). A Tailwind start pulls out 2 % for 0.5 s and flares the sun locally at 0.25 (no full-screen bloom).

## Decisions and deviations (logged per ROUND-3)
- **Title span.** §7 says 92 % and §8 says the tips sit 12 pt from the edge. I took §7 (92 %, 38 pt in): it keeps the tips clear of the gripping thumbs and the rounded corners.
- **Trail.** S10 asks for sprite segments overlapping by 0.6 w. Overlapping alpha sprites are exactly what made the checkerboard, so the trail is continuous fills instead (about 4 small paths per frame).
- **`SceneDriver.hasFold`.** Not added: `ScreenLayout.hasFold` already carries "a hinge was seen", so no Contracts change.
- **Not done:**
  - ART §5's "camera lead 8 % w at full speed": it conflicts with UX and ART's fixed 30 % bird.
  - The foam turning toward `rain` under the shade: the foam is one stroke, and the wash already greys it.
  - The 0.85× splash slow-down: it is the App's clock.

## Files
- `Swoop/Scene/`: every file.
  - Rewritten: `SceneLook` (with `ScenePalette`), `BirdArt`, `SceneBackdrop`, `SceneSea`, `SceneStorm`, `SceneBirdView`, `FlightScene`.
  - Patched: `SceneTextures`, `SceneEffects`, `SceneParticles`, `SceneProps`, `SceneCamera`.
- `SwoopTests/SceneTests.swift`, with 6 new tests and tightened ones.
- `design/NEEDS.md`: the "Scene → App (Round 3)" hooks.

## NEEDS (App)
- Wire `onBirdPoint` → the callout.
- Call `playTitleMorph` on Fly from Home.
- Set `effectsQuality` from thermal state and Low Power.
- Set `fineDetail` from the blur guard.
- Colour the title from `titleDetail`.

## Check on frames / device
- store-04 / store-14: the storm reads as a shelf cloud with a sunlit rim, no rectangle; the caught frame is dim with the edge past the fold.
- Golden Hour sky: blue → violet → peach with no mud. The far sea is a thin band. The bird is about 10 % of the width.
- The title spread on Home and the tucked dart. The ring around the bird at +0.12 s.
- 120 fps: the trail and two lit-face strips are the new per-frame and per-rebuild paths.
