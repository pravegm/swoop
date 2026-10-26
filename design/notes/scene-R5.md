# Scene R5 hand-off (Scene engineer)

## Done
- **P1-5, the storm: a rolling shelf cloud.**
  - **Gone:** the vector anvil (the "saucer"), its rim line and the plume of lobes.
  - **The wall** is now five horizontal tiers of soft, horizontally stretched lobes: cap, shelf, roll, low and base. Each tier steps forward of the one above, and the roll cloud sits furthest ahead. Together they read as layered weather, not smoke.
  - **Light:** every lobe in the top three tiers carries a sunlit crescent on its top-right edge (a new `stormRimLight` texture, `stormRim` colour at α 0.35).
  - **Value:** the body is lifted (Golden Hour ≈ #4A5468 at the top) down to the storm-top colour at the base.
  - **No hard edges:** a core silhouette behind the lobes, its edge always under a lobe, feathers into the rain-curtain base behind the far sea.
  - **Clear of the HUD:** the wall's top is clamped to `stormHUDClearance` (120 pt) under the visible top, so nothing draws behind the pause button or the meter (tested on the Duo and on a phone, at contact).
  - **Unchanged:** the R4 chase mapping (`SceneStormMap`) and the caught sweep.
- **P1-6, the tucked title bird: a gannet dart.**
  - **Shape:** wings tight along the body. A short straight arm runs to the wrist at 0.07 w from the fold, then one straight edge runs back to the tips 0.12 h behind the tail. That edge sits 15–23° off the body axis, depending on the box height. The inner edge hugs the body.
  - **Width:** 14 % of the canvas (tested ≤ 14.5 %); the wing is more than twice as tall as it is wide (tested).
  - **No legs:** the white trailing band and the mirrors are hidden past tuck 0.4 (tested).
  - **The App's fit:** two zero-area specks in the body path keep its box at the 92 % span. That way the App's `BirdDrawing.fit`, which refits anything under 25 % wide, never blows the narrow dart up (tested: body box 0.90–0.93 w).
- **P1-10, the Scene items.**
  - **Results / caught sea:** once caught, the surface blends into one calm swell (40 pt, 640 pt wavelength; `SceneSeaView.calmed`, tested). The bird bobs on that same surface, the chop already goes to 0, and the sea lands exactly on the swell when the ending settles.
  - **Lace:** α 0.25 → 0.35, streaks 60–180 pt long (REVIEW-4 juror: "still slabs").
  - **Birds page:** new pure helpers for the App.
    - `BirdArt.previewEnvelope` / `previewTransform(for:in:)` fit every flap and tuck pose with no clipped wing, at ≤ 2.2× the in-game size, centred at 58 % (tested).
    - `isDark`, `previewKeyRim` (#DDE6FF) and `previewHaloAlpha` (0.18) drive the Storm Petrel's rim and halo.
    - The drawing itself is App-owned (`BirdPreview.swift`); the hand-off is in NEEDS.

## Files
- `Swoop/Scene/`: `SceneStorm` (tiered shelf wall), `BirdArt` (dart, specks, preview helpers), `SceneSea` (`calmed`, lace), `SceneTextures` (`stormRimLight`), `SceneLook`, `FlightScene` (calm bird, `stormTopY`).
- `SwoopTests/SceneTests.swift`: new HUD-clearance, calm-swell and preview tests, plus the title tests updated for the 14 % dart.
- `design/NEEDS.md`: "Scene → App (Round 5)".

## Deviations
- **Dart width:** the juror suggested 0.18 w. I used ROUND-5's ≤ 14 % (0.14 w), as the brief asks.
- **The specks:** they are a deliberate compatibility shim for the App's fit. If the App switches the title to a fixed fit, they are harmless.

## Check on frames
- **store-07 / storm-close:** a layered shelf with lit billow tops and no saucer; nothing behind the pause button or the meter.
- **store-17 / home-tucked:** a narrow dart, with no white "legs".
- **store-08 / 14 / 25–28:** the Results and caught sea is one calm swell.
- **store-10 / birds:** depends on the App adopting `previewTransform` and the rim and halo.
