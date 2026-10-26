# Scene, Round 6 (27 Oct 2026)

Scope: ROUND-6 Scene items, ART-FLIGHT-SCHOOL SC1–SC8, UX-FLIGHT-SCHOOL N1–N6. Files: `Swoop/Scene/*` (new:
`SceneStormCloud.swift`, `SceneGuides.swift`, `SceneMoments.swift`, `RouteArt.swift`), `SwoopTests/SceneTests.swift`.
The App's wiring is in `design/NEEDS.md` → "Scene → App (Round 6)". Nothing in Contracts changed. The scene doesn't use
Core's new practice APIs: it reads only existing snapshot fields, so it compiles whatever Core lands.

## The storm: a new technique (settled point, SC6)
- **One soft cumulonimbus texture, rendered once at load from noise** (`SceneStormCloud`), tinted per sky and cached.
  It replaces the ~60 lobe sprites, rims and core shape.
  - **The shape:** a smooth envelope (a flat dark base, a front face leaning back, a flat anvil with an overhang),
    domain-warped by low-frequency fbm, then eroded by 4-octave fbm. Each octave is rotated 37°, so there are no grid
    "bricks". The outline billows at every scale and nothing repeats in rows.
  - **The light:** a rounded bevel of the depth gives the normals, lit from ahead and above. The sunlit upper-right
    edges take the sky's storm-rim colour (a crisp rim on the anvil top), the base is dark, and soft tone noise varies
    the body.
  - **The rain curtain:** streaked and slanted, at 0.35, feathering out over 140 pt below the base.
- **Why a texture and not an `SKShader`:** there is no Metal compiler here, and a shader that fails to compile on a
  device draws nothing, silently. The texture is 520 × 288 px (0.4 px per nominal pt; the cloud is drawn at about
  0.33×). It takes about 0.15 M pixel evaluations once, then one tint pass per sky. I tuned it against PNG renders of a
  bit-exact JS port (same RNG, noise and maths) before porting.
- **Life:**
  - a slow breathe (≤ 1.2 % in height) and a ±3 pt sway;
  - an internal glow every 3–6 s from first sight, drawn as one of 3 precomputed glow masks (the cloud's alpha × a
    soft disc), so a glow never shows outside the cloud. Reduce Motion: the glow only.
  - the bolts and flashes once the storm is close, as before.
- **Still the same rules:**
  - The edge comes from `SceneStormMap` (unchanged): the shelf's front at its base (`edgeX` = 1110 nominal) sits on
    the edge.
  - The top is clamped 120 pt under the visible top.
  - The left columns stretch behind it, so it runs on off screen.
  - Nothing is drawn past `drawnRight`, so in play the cloud ends ≤ edge + 50 pt, far short of the fold band.
  - The sky shade, sea wash, sheets, rain and caught wash are kept.
- **Not applicable now:** SC6's lobe jitter (±35 %) and row offset (≥ 0.5 r). There are no lobes or rows.

## The practice sea (SC1, N1, N2)
- **`ScenePalette.practice`:** the "Morning practice" table from §2, plus a designed sunline #FFF1D8.
  `ScenePalette.blended` exists only for the transition.
- **Turning it on:** `scene.practiceSea = true`, or on its own when a snapshot reports no storm (gap ≥ 500,000 pt,
  which is Core's practice gap). A session starts in the look with no fade.
- **What the look does:**
  - no storm at all (wall, sky shade, wash, rain and lightning off);
  - no chop;
  - far swells at 70 % and the sun at 0.24 h;
  - no lighthouse and no buoy;
  - no aurora over the morning.
- **Step 7, `rollInStorm()`:**
  - the palette crossfades to the player's sky over 2 s (12 steps; the in-between sky textures are undithered, < 1 ms
    each);
  - the wall slides in from off screen to `stormEdgeFar` (70 pt), with no catch while the practice gap holds;
  - one glow (no bolt, no flash) at +1.2 s;
  - the rain comes in from +1.6 s to +2.6 s.

## Guides on the water (SC2)
- **`scene.guide`:**
  - `.foldPath(from:to:)`: a 12 pt reward-gold ribbon on the foam line, α 0.40 → 0 down the slope, with a shimmer
    travelling down it every 1.2 s.
  - `.openMark(at:)`: three 14 × 8 chevrons, 2.5 pt, white at 70 %, pointing up and ahead, on a 0.15 s stagger.
  - `.landing(at:)`: a ghost ring 150 pt wide (1 : 0.32), dashed 8 / 6 in foam at 60 %, breathing at 1 Hz. A Perfect
    within 260 pt bursts it into 8 motes.
  - The `…Ahead` variants are placed by `SceneGuidePlacement` on the next downslope, trough or slope middle ahead of
    the bird.
- **Behaviour:** guides fade in over 0.3 s and out over 0.25 s. They live in world space, so they mirror with the
  world.
- **Step 4:** `slowMoBloom` adds a 6 % white bloom over the bird page.
- **SC3** (the Faster! capsule and the rhythm bar) is left to the App, anchored at `onBirdPoint` (30 Hz).

## The goal: the lighthouse (SC4, N3, N4)
- **The ahead tower:** drawn from 1.5 km out, small on the sea page's far horizon (u 0.90 w). It fades in and grows
  until the parallax brings it in.
- **At the pass:** it stands on the sea page at u 0.76 w. The parallax is now 0.15, a far-swell value, so it stays on
  that page through the moment.
- **Reached (`SceneReachedMoment`, on the `lighthouse` event):**
  - a 40° beam, 900 pt long, additive #FFF3C4 at ≤ 0.35, sweeping from 60° up to 10° down over 0.9 s (ease-out). It
    points ahead, so it never crosses toward the fold, and it fades as the tower nears the fold + 28 pt;
  - a lamp flare: 140 pt of reward gold, 0.55 → 0 over 0.6 s;
  - the haze pulse to 0.75;
  - 6 gust streaks from the bird toward the storm at +0.05 s;
  - 12 gold motes rising 60–120 pt at +0.2 s;
  - the turning beam goes quiet for 1.4 s.
  - Reduce Motion: the flare and the haze only. The 60 ms hit-stop is Feel's; the scene's FX run through it.
  - `lampCanvasPoint` lets the App keep its card off the lamp.
- **The tower:** #F4F1EA with exactly two #D8574A bands, and a dark cap (no third red stripe).

## The mirrored default (SC5, N6)
Everything mirrors through the u-space roots and the world's x flip. Verified, with tests:
- the bird is at 0.70 w and the sun at 0.20 w (285 pt from the crease);
- `uSpaceXScale` is −1, so the rain (+u, away from the storm) moves left on screen, and the gusts and speed lines flip
  too;
- the storm stays under the HUD clearance and out of the fold band at every gap, on the Duo, the mirrored Duo and the
  iPhone;
- the caught sweep ends at screen x ≈ 362 (≤ 0.40 w, outside 447–503);
- the reached beam starts on the sea page (u ≥ 504 mirrored).

## Art helpers for the App (SC7, SC8, AP1)
All pure CoreGraphics, y down:
- `RouteArt`: the coast with +30 pt headlands, the cliff and foam lines, contours, lighthouse x by index, the route
  and best-pin points, the fold-band snap, and the storm and quay glyphs;
- `DuoDiagramArt`: the book projection with cos φ and 0.18 sin φ, screen insets, mittens, and the 140° gauge;
- `BirdArt.youGlyph(facingLeft:in:)`: one path, every subpath wound the same way (checked by signed area).

## Tests added (SceneTests)
- `stormCloudIsSoftAndEndsAtItsFront`
- `stormCloudIsLitFromAboveAndRainsBelow`
- `stormNeverDrawsInTheFoldBandOrTheHUD`
- `mirroredDefaultComposition`
- `practiceSeaHidesTheStormThenRollsItIn`
- `practiceFlagHidesTheStorm`
- `practicePaletteIsMorningAndBlends`
- `guidesFindTheSeaAhead`
- `perfectInTheLandingRingBurstsIt`
- `lighthouseReachedSweepsTheSeaPage`
- `routeArtCoastHeadlandsAndSnap`
- `duoDiagramFoldsLikeABook`
- `youGlyphFitsAndFaces`

I set thresholds from the JS port's numbers:
- the anvil top's luminance is 2.0× the base's (the test needs 1.4×);
- nothing is drawn past `drawnRight` or above `drawnTop`;
- the body is solid;
- 6,381 rain pixels (the test needs 200).

## Risks / for the next round
- The cloud field costs about 1 s once per test process in Debug, and is estimated at 30–60 ms at first scene init on a
  device in Release. If launch hitches, move `makeField` to a background queue (it is pure).
- The storm is the same cloud every run (fixed seed). Variety could come from 2–3 seeds per sky if critics ask.
- The palette crossfade re-applies the cosmetics 12 times over 2 s (the bird paths are rebuilt each time); fine on
  device, worth watching in the Instruments pass.
