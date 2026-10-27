# Scene, Round 11 (27 Oct 2026)

Scope: ROUND-11 P0-1 (the storm's edges), the Scene parts of P0-4/5/6/7, P0-9 (the lighthouse slab), P1-11 (the Home
trail) and P1-14 (the Perfect lettering, which turned out to be App code). The asks are in `design/NEEDS.md` →
"Scene → App (Round 11)". Nothing is committed; CI hasn't compiled any of this yet.

**Files:** `SceneStorm`, `SceneStormCloud`, `SceneTextures`, `FlightScene`, `SceneCamera`, `SceneBirdView`,
`SceneGuides`, `SceneProps`, `SceneLook`, and `SwoopTests/SceneTests.swift`.

## P0-1: the storm has no straight edges, ever
There were two causes, both visible in the R10 frames:
- **The hard vertical line** (Duo s1-15c at x ≈ 240, phone s1-15c/s1-15b just behind the front) was the caught warm
  horizon strip. It was an additive sprite starting at a hard edge 20 pt behind the front. The grey "stopping" there is
  really the warm light starting.
- **The horizontal smear** (to the right of the cloud on the mirrored Duo, to the left on the phone) and the hard
  rectangular band in s1-15b were the backing: `SKTexture(rect:in:)` took the cloud's two leftmost texture columns and
  stretched them over everything behind the cloud. That is a clamp-to-edge stretch of the anvil's ragged top.

The fix is one technique for every soft storm layer, in u-space, so it holds in both orientations:
- **`SceneStormTint`** (pure, nonisolated, tested). A layer is a `Span`: a body of identical columns plus a
  smoothstep ramp that shares one edge with it. `falling(clearAt:ramp:)` is covered behind and clear ahead;
  `rising(startAt:ramp:width:)` is clear behind and covered ahead.
  - The tints' ramps are always ≥ 300 pt (`minRamp`).
  - The body always runs 160 pt (`overscan`) past the canvas edge, so on screen a layer can only end in its ramp.
  - It also holds the texture bytes (`pixels(profile:rows:columns:ramp:)`), so a layer's body and ramp come from one
    colour profile and match exactly at the seam.
- **`SceneSoftSpan`** draws a span as two abutting sprites. The seam is each sprite's anchor, so it is the same float
  on both and there is no gap or overlap.
- **The layers:**
  - **Sky shade:** the ramp is max(300, 0.55 w) wide and ends 0.45 w ahead of the front, as before. Once caught it slides
    past the ahead edge (`+ caughtness × (w + ramp)`), so it covers the whole screen. The cap of 0.5 at the bird is
    kept.
  - **Sea wash:** the same look as R10 (it ramps out over 504 pt and ends 260 pt ahead), but its body now always
    reaches past the behind edge. R10's fixed 1,800 pt sprite would have shown its back end at large edges.
  - **Caught warm strip:** it ramps in over 300 pt from 150 pt behind the front, then holds the horizon band to past
    the ahead edge.
  - **The calm wash** now overhangs by 160 pt.
  - **Rain sheets:** their sides feather too (`rainsheet3`).
- **The cloud never draws past its texture.**
  - `SceneStormCloud.leftFade`: the texture fades from α 0 at x = 0 to full by nominal x 360, in the colour, the alpha
    and the lightning glows. All four borders of the texture are now empty.
  - Behind it, the backing is `SceneStormCloud.backingProfile`: the tinted cloud averaged across its body (x 400–660),
    blurred down the rows (two ±10-row box passes with zero padding) and tapered at the top and bottom. It has no
    detail, so stretching it to any width is exact. It is solid from −160 to exactly where the cloud's fade ends
    (`cloudFadeEndU`), then ramps out under the cloud's body over 260 nominal pt.

Tests:
- `stormTintSpansHaveNoEdges`;
- `stormRampPixelsMatchTheirBodies`;
- `stormCloudHasNoHardBorderAndASoftBacking`;
- `stormLayersNeverShowAnEdge`: on the Duo, the mirrored Duo and the phone, through the approach and the catch
  sweep. Every tint ramp is ≥ 300 pt and nothing jumps on the canvas. The backing meets the fade and runs off the
  behind edge. Caught, the sky covers 100 % of the width.

## P0-6 / P0-7: the storm step
- `rollInFrom` is now 40, where it was −260, so the first frame after `rollInStorm()` already shows the storm (its front
  and the dark deck behind it). It still slides to 0.20 w over 2 s.
- **Why R10's s1-13b showed no storm and no push:**
  - the roll-in was only asked on the step's `advanced` signal, so a school started at the storm step (replays, the CI
    frames) never rolled it in;
  - a `scene.reset()` after the call also clears it;
  - so there was no storm, and the scene only recoils a rolled-in storm.

  The App now asks for the roll-in every frame (its R11 change), which fixes it live and in the demo.
- At the recoil peak the front sits at ≈ 40 pt, still on screen.

Test: `schoolStormShowsFromTheFirstFrameAndRecoilsInView`.

## P0-4: one fold indicator
The gold book at the crest (on the waiting gull's back in s1-05/s1-06) and the teal open book are gone from
`SceneSwellCue`. `bookPath` and `bookAngle` stay as pure helpers.

## P0-5: the ring is never under Skip, the dots or the pause button
- While a ring is live ahead in school, the camera keeps it inside `FlightScene.ringSafeRect()`: 200 pt in from the
  sides and the visible bottom, and 120 pt under the top (scaled down on small screens).
- It does this in two steps:
  - `SceneCamera.keepInView` / `keepInset` lower the frame (the bird rides higher; its 78 % top limit still wins),
    easing on the zoom's spring;
  - `zoomToFit(_:inside:)` caps the zoom at the largest value that fits, found with `previewPoint(_:framingZoom:)`.
- `ringCanvasPoint` was added for tests.

Tests: `cameraKeepsTheRingInboard` (pure) and `schoolRingSettlesInboard` (both Duo orientations).

## P0-9: no placeholder slab
The rock is now `SceneHeadland`: an irregular headland outline (a shoulder, a knoll under the tower, a ledge and a
spit) drawn as a texture whose alpha follows `rockFade` (solid down to −6 pt, gone by −70 pt). The R6 sea stack ran
320 pt down with straight sides, which the school's 70 % far sea showed as a slab. The foam ring is widened to
300 pt.

Test: `lighthouseHeadlandHasNoStraightEdges`.

## P1-11: the Home trail vs the tagline
In attract, `updateTrail(…, ceiling:)` trims the trail's older end back below the bird's ceiling + 36 pt, which is 24 pt
under the text. The camera holds the bird under the text, so the older, higher trail points used to show above it.
The ask that the App pass every text rect is in NEEDS.

Test: `trailCeilingTrimsTheOldEnd`.

## P1-14: the "Perfect ×N" lettering
This is `PerfectCalloutText.label` in `Swoop/UI/PlayHUD.swift` (App-owned). The speckle comes from the two 45 % ink
copies offset ±1.5 pt under a gradient. A drop-in replacement (an opaque 8-way outline and a flat reward-gold fill,
composited once) is in NEEDS.

## For CI to confirm
- **The seam between abutting sprites.** I'm relying on SpriteKit rasterising identical edge floats without a gap or a
  double-blended column. If a hairline shows at a seam in the frames, the fallback is a single sprite per layer with a
  fixed body:ramp texture ratio.
- **The backing's row-step bound.** `stormCloudHasNoHardBorderAndASoftBacking` expects ≤ 16 per row; the analytic bound
  after the two box passes is about 12. The backing's peak alpha is expected to be > 200.
- **`schoolRingSettlesInboard`** uses springs (zoom and lift) after 1.25 s with a 25 pt tolerance. If it is flaky on
  CI, raise the frame count rather than the tolerance.
