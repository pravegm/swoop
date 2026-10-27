# Scene, Round 9 (27 Oct 2026)

Scope: ART-ROUND-9 SR1–SR7 and every Scene row of the §3 defect list. UX-ROUND-9 §1 supplied the flow. The App wiring
is in `design/NEEDS.md` → "Scene → App (Round 9)", which also answers the App's "App → Scene" asks.

**Files:**
- new: `Swoop/Scene/SceneGuideGull.swift`;
- rewritten: `SceneGuides.swift`;
- changed: `FlightScene`, `SceneCamera`, `SceneStorm`, `SceneBackdrop`, `SceneBirdView`, `SceneEffects`, `SceneSea`,
  `SceneMoments`, `SceneLook`, `RouteArt`;
- tests: `SwoopTests/SceneTests.swift`.

The scene stays independent of Core's new types: the App maps Core's `GhostSample` onto `SceneGhostPose`.

## Tasks
- **SR1, the guide gull:**
  - **Look:** the player's species at 0.9×, foam at α 0.38 on the body and 0.30 on the wings, a 1.5 pt gold outline
    at 0.85, and an 18 pt additive glow at 0.18. It flies just under the bird.
  - **Dotted path:** 4 pt gold dots every 14 pt, each fading over 1.6 s, left where it flew.
  - **Hand-off:** it holds its last pose for 0.6 s (or until the player reaches it), then dissolves into 10 rising
    motes and calls `onGhostFinished`.
  - **Camera:** while it flies, zoom ≤ 0.78 and the bird shifts back by up to 0.22 w (springed, clamped to 90 pt from
    the edge).
  - **Two ways to drive it:**
    - `guideGhost` (per-frame `SceneGhostPose`, as the App asked) for Core's path;
    - `playGhost(_:)`, the scene's own stand-in flights (dive, soar, land, rhythm), used when no path is given.
  - **Land:** fires the ghost Perfect (a gold outline ring only).
  - **Reduce Motion:** the ghost still flies, with no motes and no glow pulse.
  - **Exposed:** `ghostScreenPoint` and `ghostTuck`.
- **SR2, water cues** (gold = fold, teal = open; sizes follow the 0.7 zoom resistance; fades 0.25 s in, 0.3 s out):
  - **The fold zone:** a 16 pt band at α 0.55 with a 6 pt additive glow, from the crest to 85 % of the way down. It
    paints solid behind a folded bird and greys to mist at α 0.4 from where the bird opened. A rewind to the crest
    restarts it. Done, it leaves a 14 pt gold bead with an ink tick over the crest.
  - **Fold chevrons:** 18 × 10, 3 pt, 36 pt apart, running down the slope at 120 pt/s.
  - **The mini books:** 14 × 20 panels with §1D's exaggerated angle. Gold closing 170° → 110° at the crest, teal opening
    at the launch, 1.2 s, still under Reduce Motion.
  - **Lift chevrons:** 3 teal, 14 pt apart, 0.15 s stagger.
  - **Rhythm:** `.rhythm(swells:)` / `.rhythmAhead(count:)` (up to 3 swells), each with its zone, books and bead.
- **SR3, the ring:**
  - 180 × 58 pt, a 4 pt gold stroke at 0.95, an 8 pt additive glow at 0.35, a fill at 0.12, breathing 0.96–1.04 at
    1.2 Hz;
  - the drop marker: 3 pt dots every 9 pt up to 96 pt, under a 22 pt chevron bobbing ±6 pt;
  - α 1 and 1.1× within 120 pt above it;
  - a Perfect in it makes the real ring plus a 12-mote burst;
  - a Good or Splash near it, or flying 200 pt past it, fades it in 0.3 s, and it respawns on the next downslope
    ≥ 200 pt ahead;
  - the camera looks 0.25 w ahead while it is live;
  - `ringScreenRect` is exposed.
- **SR4, caught:**
  - the front sweeps past the bird to 0.90 w in 1.2 s (ease-in-out), with the rain covering the wall and leading it
    by 60 pt;
  - the light: wash 0.45 (uniform), sun −70 %, light over 2.4 s, a 0.10 w warm horizon strip ahead at 0.6;
  - one bolt inside the wall, ahead of the bird, at 0.9 s;
  - the bird settles at tuck 0.6, nose −4°, 15 % darker (wet), with 3 rain rings;
  - the camera pushes in +4 % from 0.6 to 2.4 s (none under Reduce Motion);
  - `stormShadeReach` 260.
- **SR5, practice:**
  - school is never caught, and nothing is drawn or dimmed for a storm before the roll-in;
  - the practice sun: a 360 pt glow at 0.55 under a white disk;
  - the camera keeps the bird within 35–70 % and the horizon ≥ 15 % under the top;
  - the far-front fill darkens into the near-mean over 200 pt;
  - pure white foam;
  - the storm step rolls the wall in to 0.20 w (Duo x ≥ 760) at closeness 0.3, and a Perfect pushes it back with a
    gust;
  - `stormLinkTarget` draws the dotted wall → meter link;
  - `schoolLighthouse` raises Gull Point on the horizon, at `lampCanvasPoint`.
- **SR6:**
  - **The trail:** a jump over 3 spacings starts a new strand; any 600 pt jump of the bird clears it.
  - **Home:** `homeMenuRects` keeps the attract water 24 pt under the menu.
- **SR7:** `birdScreenPoint` (30 Hz, now including the bias), `ghostScreenPoint` and `ringScreenRect`.
- **§1E, the speed in the world:** in school the speed lines start at 600 pt/s and the trail turns gold at
  1,100–1,600 pt/s. There is nothing to remove in Scene: the Faster! bar and the rhythm bar were App-drawn.
- **App helpers:**
  - `DuoDiagramArt.geometry(angle:box:exaggerated:)`, `displayPhi` and `innerShade` (§1D);
  - `RouteArt` L→R: the coast with +34 pt points, base 150 / 118; `lighthouseXs(count:spacing:)`; `focusOffset`; and
    `labelRows` (one baseline, a collision drops a row of 40 pt).
  - The R6 coast functions are kept unchanged for the current Route.

## Scene defects (§3)

| # | Status | Note |
|---|---|---|
| 3 | Fixed (needs App) | `homeMenuRects`. If the sea under the row looks too thin, Art's plate alternative is App's |
| 5 | Fixed (needs App) | Scene: no storm, rain, caught wash or dim in school. App: pass `practiceSea` for the Studio steps too |
| 6 | Fixed (part) | The "second sine" is the far-front fill showing above a deep trough: it now darkens into the near-mean, and the school foam is pure white. A two-scene crossfade, if there is one, is App's |
| 15 | Fixed | The practice sun: a 360 / 0.55 glow, the disk white on top |
| 16 | Fixed | The §1B fold zone, chevrons and book |
| 17 | Fixed | The §1C ring, ahead, with the camera bias |
| 18 | Fixed | Practice framing 35–70 %, the far fill darkening |
| 19 | Fixed | The horizon ≥ 15 % under the top in practice |
| 22 | Fixed | The roll-in to 0.20 w at closeness 0.3 (it was 70 pt, behind the HUD). The timing before the words is App's |
| 29 | Fixed | The strand break and the clear on a jump |
| 33 | Fixed (Scene part) | §2. The HUD fade and the label are App's |
| 34 | Fixed | `stormShadeReach` 260 |

Declined: none.

## Tests added
- `ghostFlightsFlyEachMove`
- `guideGullFliesAheadThenHandsOver`
- `appDrivenGuideGullHandsOver`
- `foldZonePaintsTheProgress`
- `landingRingLandsOrRespawns`
- `bookGlyphFoldsVisibly`
- `caughtStormOvertakesTheBird`
- `schoolShowsNoStormEvenWhenCaught`
- `trailBreaksOnAJump`
- `practiceCameraKeepsTheHorizon`
- `cameraBiasZoomCapAndWaterCeiling`
- `routeArtReadsLeftToRight`

R6's roll-in test now expects 0.20 w. I checked the ghost kinematics in a JS port first (dive 300 → 756; soar peaks
349 pt over the water; land arcs 206 pt).

## Risks
- The stand-in ghost flights are kinematic, not Core's physics. Core's path via `guideGhost` is the intended source.
- The practice camera's horizon rule can put the bird slightly under 35 % in a deep trough. The rule order is: the
  horizon, then the bird's 12 % floor.
- Defect #3 pins the Home water low when the menu sits at the bottom. That is Art's literal rule; the plate may read
  better.
