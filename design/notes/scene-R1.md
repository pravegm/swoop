# Scene R1 hand-off (Scene engineer)

## Built
- `FlightScene` with exactly the ARCHITECTURE API: `init(layout:)`, `driver`, `reduceMotion`, settable `layout`, and `reset()`.
  - Each frame `update` clamps dt to 0…1/30, calls `driver.advance(dt:now: CACurrentMediaTime())`, then draws.
  - Cosmetic time runs on the snapshot's clock, so a paused or `freezeOn` frame holds still, FX included. I use no SKActions.
  - If `driver.sea` changes identity, or the snapshot time runs backwards, it resets itself.
  - It prints `SWOOP-T frame 120` (flushed) once, only with `-swoopDemo`. The App's `advance` prints the same line too, which CI won't mind.
- Camera (`SceneCamera`, a pure struct): the bird is pinned at 30 % of the width, or 70 % with the world flipped when mirrored.
  - Zoom runs from 1.0 down to 0.42 (lower on cropped phones) and follows altitude above a smoothed water line through critically damped springs.
  - The bird stays between 12 % and 84 % of `visibleRect`, so the water is still visible at 1100 pt on the Duo and on phones.
  - A launch gives a small pull-out. A Splash gives a spring bump (off with Reduce Motion).
- The sea:
  - It is one `SKShapeNode`, rebuilt each frame from `sea.samples` (≤ 220 segments). Its fill is a cached vertical depth gradient, and its stroke is the foam line.
  - A lit band runs just under the surface.
  - There's a glint on each crest (local maximum within ±40 pt) and 20 twinkles at stable hashed spots in the water.
  - Visual ripples of ±2 pt sit on top (the bird never feels them). Chop up to 9 pt appears under and ahead of the storm.
- Sky (u-space, flipped when mirrored): zenith→horizon gradient, sun ahead with glow, haze and a glitter path, 5 parallax clouds, 2 far swell layers (own sines), stars when the zenith is dark, an aurora on Northern Lights.
- Storm: a slate cloud wall with a billowing edge at `stormX`. Within 1.5 screens a hint always shows at the behind edge, fading in over the next 0.3 screens.
  - A grey wash covers the sea under it, with slanting rain.
  - Rain reaches the left half when the lead is under 20 %, and the whole canvas when caught (softly, with a calm wash).
  - Lightning (bolt, flash, cloud glow) comes more often and stronger as the gap closes. Reduce Motion gives a glow only.
  - Once caught, the wall stops just past the bird.
- Bird (`BirdArt`, pure CoreGraphics, no isolation):
  - Side view: a sleek body (forked tail when pointiness > 0.6), dagger or deep beak, near and far wings, wing-tip overlay paths and an eye.
  - Spread, the wings are held up in a V with the hand swept back. Tucked, they fold flat along the back past the tail. `flap` is phase 0…1, and 0 = rest.
  - The scene flaps in the countdown hover, when airborne below 430 pt/s with the wings open, and for one beat after a slow launch.
  - Caught: tucked, sitting low and bobbing.
  - The bird resists the zoom (size ∝ zoom^0.55).
- Title bird: front-on, wings spanning the full width (about 98 %), body on the centre line. Tucking folds the wings down to about 26 % of the width.
- FX (own pools, textures generated once in code):
  - Skim spray off the wingtip and a foam wake on the surface, both scaling with speed. Launch burst.
  - Perfect: a white ring on the water (plus a gold one on chains of 2+), gold sparkles, and the trail turns gold for 1.4 s.
  - Tailwind: a long golden ribbon with a glow, shedding motes, and a sun flare.
  - Splash: crown, plume, foam, a bump, and drips off the bird.
  - Also speed lines (above 1300 pt/s, or during a Tailwind), cloud-touch puffs, and a touchable cloud band at y ≈ 1000.
  - Lighthouse on a sea stack at `Lighthouses.x`, its rock clearing the nearby crests. The beam turns all the time; passing one brightens and speeds the sweep.
  - Personal-best buoy with a pennant at `bestMeters × 10`.
  - Milestone: a horizon haze pulse, a crease glint and a few sparkles. Crease glint band only when `hasFold`.

## Files
`Swoop/Scene/`: `FlightScene.swift` (which also holds `SceneSpeedLines`), `SceneCamera.swift`, `BirdArt.swift`, `SceneLook.swift`, `SceneTextures.swift`, `SceneParticles.swift`, `SceneEffects.swift`, `SceneSea.swift`, `SceneBackdrop.swift`, `SceneStorm.swift`, `SceneProps.swift`, `SceneBirdView.swift`.
- `SceneLook.swift` holds every tunable; `SceneTextures.swift` also holds `ScenePaint`, `SceneRNG`, `SceneDefaults` and `SceneFallbackSea`.

Tests: `SwoopTests/SceneTests.swift`:
- art bounds;
- the wing fold;
- flap rest;
- title span and fold;
- camera at 30 % and at 70 % mirrored;
- water visible up to 1100 pt on Duo, mirrored and phone layouts;
- a paused camera holds;
- a 350-frame smoke run through every event, both phases, mirroring, Reduce Motion and a layout change.

## Deviations
- Coordinates:
  - `path(for:)` is a unit box, y up.
  - `titlePath` is y down (SwiftUI). `BirdPreview.swift` already assumes exactly this.
  - `BirdArt.flippedVertically(_:)` is there if wanted.
- Extra internal helpers beyond the API: `BirdArt.wingTipPaths`, `BirdArt.eye`, `BirdArt.bodyPath/beakPath`, `FlightScene.drawnFrames`.
- The scene doesn't read `Tuning`. It uses `SceneLook` constants and Core's `SeaProfile` and `Lighthouses` only.

## NEEDS
- None blocking.
- The tests use Core's `BirdCatalog.all` and `SeaProfile(seed:)`, and the scene uses `Lighthouses.x(index:)`, `height`, `slope` and `samples`.

## Check on screenshots / device
1. The sea reads as the hero: depth gradient, foam line, crest glints. If the gradient band jumps as crests change height, tune the `SceneSea.apply` stops.
2. Bird size and readability at zoom 0.42: `birdUnit` and `birdZoomResist`. Check the spread-wing V angle (`BirdArt.spreadElevation`).
3. The storm hint at the left edge on a fresh run (gap 2400, so it shows once within 1.5 screens) and the `lead=0.1` frames: rain on the left half, lightning.
4. Mirrored: sun and lighthouse on the left, storm on the right, bird at 70 %.
5. 120 fps on a real Duo: about 10 shape nodes are rebuilt per frame. If it drops, lower `seaMaxSegments` (220) first, then `rainCount`.
6. Caught frames: calm wash plus full rain, the bird bobbing tucked, the wall stopped just past the bird.
