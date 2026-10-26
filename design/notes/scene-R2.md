# Scene R2 hand-off (Scene engineer)

## Built (ROUND-2 "Scene engineer" 1–8, plus REVIEW-1 P1-8/P1-10 and QA-1 P2-6/P2-15)
1. **Perfect visible.**
   - A gold ring grows from 40 to 160 px over 0.35 s; on chains of 2+ a paler ring follows at +0.08 s.
   - A gold bloom on the water, sparkles, and the trail turns gold.
   - The camera punches in 3 %, with a 0.06 s attack and a 0.35 s release, centred on the bird (`SceneCamera.setDisplayScale`). It is skipped with Reduce Motion.
   - FX run on an **FX clock**: the snapshot's time plus wall time while the snapshot is held for up to 0.1 s. They keep moving through the App's 35 ms hit-stop, but a pause or a `freezeOn` still holds them still.
2. **Bird.**
   - Size: `birdUnit` 84, zoom resist 0.6.
   - A 1.5 pt rim on the body and near wing, coloured to contrast with the bird: dark on light birds, light on dark ones.
   - The camera clamps the bird below 78 % of the visible height (`birdTopFraction`, framing 0.42).
   - Caught: the bird bobs level.
3. **Title bird.** `titlePath` (same signature, y-down) is now a dorsal view: beak and head up, broad shoulders, a fanned tail, and wings with finger notches on broad birds.
   - Tucking rotates the wings back into a dart, about 30 % of the width, tips down and back past the tail.
   - It stays wider than 25 % of the width, so `BirdDrawing.fit` keeps it at its real size.
4. **Species wings** (`BirdArt.shape(for:)`): sickle swift, long straight albatross, stubby round puffin, broad heron, and so on.
5. **Trails.** A chain of soft ribbon sprites through the last 0.45 s. Width tapers to 0 and alpha fades from 0.85 to 0, plus an additive glow layer.
   - Tailwind: two gold strands with a travelling sine wobble, plus motes. No path rebuilds.
6. **Far swell.** A lightened sea blue with 15 % of the horizon's hue, a sunlit 1 px crest line, a darkening haze down the near layer, and the glitter crossing both.
   - The crease glint is now an 80 px band at the horizon, alpha 0.08, rising to 0.12 only on milestones.
7. **Storm, always on screen.** A crisp vector anvil (one static path, only scaled) with a lit rim.
   - Far away it is a hazy band about 42 % of the sky high at u ≥ 70; near, it is a slate tower 115 % high with its edge at u ≥ 190. Its darkness also follows the gap.
   - 4 rain sheets, rain, a grey wash over the sea, and lightning.
   - Caught: a 30 % grey wash, the sun dimmed by half over 1.5 s, and rain over everything.
8. **Lighthouse.** It now stands on the far swells as a parallax depth layer (×0.3).
   - At the pass it is 120 px ahead of the bird; 0.25 s later it is still beside it, with the beam sweep starting ahead.
   - It comes in from the right before the pass and drifts back over about 1350 pt of flight.
   - The R1 bug: it was drawn at its real sea x, so it was 500 pt behind the bird, off screen, by freeze time.
9. **QA-1 P1-6 (frame rate).**
   - **Sea:** the surface is built over 2.15 screens and rebuilt only when the view leaves that range, the zoom drifts 25 %, the storm moves 150 pt (near), or the origin re-bases. The smoke test asserts fewer than 1 rebuild per 3 frames; in practice it's a few a second.
   - **Fill gradient:** it is pinned to sea y 700…−1400 by an off-screen speck, so a rebuild never shifts its colours. The time-varying ripple is gone, and chop is now static in space.
   - **Far swells:** built once and slid.
   - **Wings:** cached per quantised tuck (48 steps) and flap (40 steps).
   - **Colours:** cached per sky and bird. Cosmetics are re-read every 30 frames.
   - **Remaining per-frame work:** only Core's `samples` on a rebuild; nothing else allocates. There is no `samples(into:)` in Core's API.
10. **Also:**
    - Speed lines start at 900 pt/s and turn gold at ≥ 90 % of `Tuning.maxSpeed`. Above 1800 pt/s the camera pulls out up to 2 % (P1-8).
    - The cloud band sits at `Tuning.cloudHeight` (present, 900). It is overlapping clouds with their bottoms 170 pt under it, so `cloudTouched` always fires inside a cloud (P2-6).
    - The lightning flash peak is lowered from 0.22 to 0.14 (P2-15).

## Files
- Rewritten in `Swoop/Scene/`: `FlightScene.swift`, `SceneSea.swift`, `SceneStorm.swift`, `SceneBirdView.swift`, `SceneBackdrop.swift`, `SceneCamera.swift`, `SceneLook.swift`, `BirdArt.swift`.
- Patched: `SceneEffects.swift`, `SceneProps.swift`, `SceneTextures.swift` (ribbon and rain-sheet textures; the blurry storm bitmap is gone), `SceneParticles.swift`.

`SwoopTests/SceneTests.swift` gains these tests:
- `speciesWingsDiffer`;
- the dart and side assertions in the title test;
- the 22 % HUD clamp;
- `displayScaleIsCentredOnTheBird`;
- `lighthouseIsOnScreenAtThePass`;
- `perfectPunchesInThroughAHitStop`;
- the sea-rebuild count.

## Deviations
- The far swell is not "55 % sea + 45 % horizon": mixing teal with an orange horizon is exactly what made khaki. It is the sea blue lightened toward haze with 15 % of the horizon's hue.
- The lighthouse is a depth-layer prop, not at its true sea x (the pass is still exact: the event, the beam sweep).
- The scene now reads `Tuning.maxSpeed` and `Tuning.cloudHeight` directly.

## NEEDS
None.

## For the App
- Freeze store-04 about 0.12 s after a Perfect: the ring is at about 110 px then. Under `freezeOn` the scene runs FX for up to 0.1 s of the freeze.

## Check on device / frames
- Ring and punch-in readability at 120 fps.
- The rim on a white gull against the pale far swell.
- The storm band at full lead (it should read as weather, not a smudge) and at `lead=0.06`.
- The tucked title dart on Home.
- The lighthouse at 4 km.
- If a frame shows a gradient "pop" on the sea, tune the `SceneSea.apply` stops.
