# Scene, Round 12 (27 Oct 2026)

Scope: ROUND-12 P0-1 (the Scene part), P0-2(a), P0-3 (the optional tick, done because it was a few lines), P1-6 and
P1-7 (the Scene part). P0-5 is App-only: the big top-down gull is the App's `TitleBirdView`, not a Scene node. The
asks are in `design/NEEDS.md` → "Scene → App (Round 12)". Nothing is committed; CI hasn't compiled any of this.

**Files:** new `SceneTargets.swift` (the pure rules), `FlightScene`, `SceneCamera`, `SceneGuides`, `SceneGuideGull`,
`SceneProps`, `SceneLook`, and `SwoopTests/SceneTests.swift`.

## P0-2(a): why R11's 200 pt rule didn't hold in s1-08
Three causes, all visible in the frames:
1. **The ring was placed after the camera.** `guides.show(...)` ran after the camera step in `render`, and the ring's
   `liveCenter` only appeared on its first `update`. So the frame a ring appeared on (a reset, a step change) was
   framed without it, and the snap at the land step's start never saw it. From then on the camera eased toward it on
   the zoom spring (τ ≈ 0.35 s), the lift spring and the bias spring (ω 3), which take 1.5–2 s to settle.
2. **The CI frame comes 0.5 s in.** The land step starts at the launch (x 2104, ring at 3450) and s1-08 freezes at
   x 2650, about 0.5 s later. A held frame also stalls the camera (`simDt` = 0), so the frame showed the springs
   caught mid-way. In the Duo frame the zoom was about 0.82 and the bias about 80 pt, against targets of about 0.45
   and 196 pt.
3. **The rule only held the centre.** Even when settled, a centre 200 pt in put the ellipse 101 pt from the edge, under
   Skip. The drop marker wasn't counted at all.

The fix:
- **The rule is for the whole rect.** The ellipse widened 1.1× plus the drop marker (`SceneTargets.ringCanvasRect`)
  must sit inside the visible canvas inset 200 pt at the sides, 160 pt at the bottom and 120 pt at the top
  (`ringInboardRect`). On short canvases the insets are capped at 25 % of the width, 30 % and 20 % of the height, so the
  phone gets 131 pt at the bottom and 88 pt at the top. `ringSafeRect()` is now the matching centre rect
  (`ringCentreRect`), and the camera frames the centre into it.
- **Guides are placed before the camera.** A reset or a jump snaps first (`viewCam.snap`), so the ring fit is worked
  out for where the bird is now. A ring is inboard on the frame it appears. `SceneGuides.ringX` exists from the moment
  of placement.
- **A jump of more than 600 pt is a cut.** A rewind or a session switch already broke the trail; now the camera snaps
  too. In the storm step the ring is placed afresh ahead.
- **Rushing springs.** While a ring is framed (`SceneCamera.rushToCap`), the zoom spring (when above its cap) and the
  lift spring run 2× faster.
- **More zoom-out.** `zoomToFit` may go to the framing floor (0.9 × `zoomMin`, `ringFitFloor`), so a ring 1.35 km ahead
  still fits on the Duo.
- **Held school frames settle on wall time.** In school, a held frame (a demo freeze or a pause, but not the 0.1 s
  hit-stop) runs the camera and the guides' fades on wall time. A frozen frame shows the framing the words were
  placed for.
- **The horizon holds under the lift.** The practice horizon (≥ 15 % under the top) now also holds after the ring
  lift. Where both can't hold, `zoomToFit` (which frames through the same code) zooms out instead. This is what keeps
  the room above Gull Point (P1-7).

The App moved Skip and the dots to the trailing corner (NEEDS "App → Scene (Round 12)"). The rule is symmetric, so it
keeps the ring off them in either corner.

## P0-1: the storm step's ring, and what `ringScreenRect` reports
**Why s1-12/s1-13 pointed behind the bird.** The storm frames start at the rhythm checkpoint (x 4300, at the bottom of
a trough), and the scene put the first ring at 5800. The bird flies at 1700 pt/s and passed it about 0.9 s later. The
frame freezes at 6300, and a ring only counted as missed at 1.5 widths + 200 pt past (≈ 6340). So the ring stayed
"live" behind the bird and was reported, and the pointer ran off the behind edge to it. There were also two latent
bugs:
- From exactly the bottom of a trough, `nextDownslope` found an 8 pt "downslope" and gave up, so a respawn at 6300 would
  place nothing.
- After a Perfect in the storm step's ring, nothing was placed again.

The fix:
- **Passing is a miss.** A ring the bird has flown past, beyond the Perfect window (`SceneLandingRing.hitReach`), is
  missed at once. It fades over 0.3 s and respawns on the next downslope ahead.
- **The storm step's ring repeats.** A `.landingAhead` ring (the storm step's) comes back ahead 0.8 s after a Perfect
  in it (`SceneGuides.repeatsRing`). The land step's `.landing(at:)` ring doesn't, so there's no second ring during
  "Perfect" (s1-09).
- **The search skips short flats.** `nextDownslope` passes over level stretches shorter than 40 pt and keeps looking.
- **Rings sit higher on the face.** A ring now sits 0.35 of the way down its downslope (`ringSlopeFraction`), where a
  bird clearing the crest first comes down. R9 used the middle. A ring placed from a trough is then about 1.35 km
  ahead and still fits inboard on the Duo.
- **`ringScreenRect` is non-nil only for a named ring.** The ring must be ahead of the bird, wholly on the visible
  canvas, and faded in to at least 50 %. It is first reported once it is inboard, then kept while it stays ahead and on
  screen, so it doesn't flicker at the inboard line (`SceneTargets.reportsRing`). `ringCanvasPoint`,
  `ringCanvasRect` and `ringInboard` are set whether or not it is reported (tests).
- **The s1-12/s1-13 frames.** They hold at 6300, just past the first ring. On the held frame's wall time, that ring
  finishes fading and the next is placed at 7650, 1350 pt ahead. The camera then frames it inboard and it is reported.
  In live play, a test bird that never lands has a ring to name at least every ~0.8 s; the test bound is 1.5 s.

## P0-3: the early-open tick (optional; done)
Each fold zone already knows where the bird opened inside it (`missFrom`, where its band turns grey). It now draws a
gold tick across the foam line there: 18 × 3 pt on an ink underlay, fading in over 0.15 s. A fresh attempt (back at the
crest) clears it. The App needs to call nothing. `scene.foldMissMarks` lists the sea x.

## P1-6: the guide gull is never cut by the edge
The ghost still flies (and the camera still makes room), but its art and its dotted path are drawn only while its whole
box, inset 8 pt from the visible canvas, is on screen and it is ahead of or level with the bird
(`SceneTargets.ghostShows`, up to 40 sea pt behind). While hidden, `ghostScreenPoint` is nil, no dots are dropped, and
it fades in afresh once it may show. `scene.ghostShown` reports it.

## P1-7: the room above Gull Point
The label is the App's (`SchoolRig.lampLabelCenter`). On the Scene side:
- The school tower is now sized so its apex stays ≥ 46 pt (`towerLabelRoom`) under the visible top
  (`SceneTargets.schoolTowerScale`). It is never drawn below 0.14 scale (about 22 pt tall).
- On the phone the far horizon sits ~65 pt under the top, so the tower comes out about 38 pt tall instead of 63. The
  label can then go above it.
- `lampCanvasPoint` is unchanged (the lamp).
- The new `lighthouseTopCanvasPoint` is the apex, for a baseline ≥ 8 pt above it.

No Scene label was added.

## Tests (new)
- `ringTargetsKeepTheWholeRectInboard`
- `ringIsNamedOnlyAheadAndOnScreen`
- `landingAheadFindsARingFromATrough`
- `landingStepRingIsInboardByTheFrame`: s1-08 on the mirrored Duo, the Duo and the iPhone. It is named within 0.6 s,
  and the held frame's whole rect is inside the 200/160/120 inset.
- `stormStepAlwaysHasARingAheadToName`: s1-12/s1-13. No gap over 1.5 s, a named ring is never behind or off screen,
  and the held 6300 frame names a ring ahead and inboard.
- `stormRingComesBackAndPassedRingsGo`
- `earlyOpenIsMarkedOnTheWave`
- `ghostShowsOnlyWhollyOnScreenAndAhead`
- `guideGullIsNeverCutByTheEdge`
- `schoolTowerLeavesRoomForItsName`

Updated:
- `guidesFindTheSeaAhead`: the 0.35 slope position.
- `cameraKeepsTheRingInboard`: the fit floor is now `ringFitFloor`.

## For CI to confirm
- **The two scene tests are tuned.** `landingStepRingIsInboardByTheFrame` and `stormStepAlwaysHasARingAheadToName` use
  spring timings worked out by hand: a 0.6 s naming bound, and a 1.5 s gap, against an estimated 0.8 s. If one fails
  on a bound, raise the frame count or the hold first; don't loosen the inboard rect.
- **The Duo storm frame is tight.** It fits at zoom 0.40 against a floor of 0.378.
- **The ghost-perfect sparkle** fires only when the ghost is shown. It is cosmetic.
- **A cut now snaps the camera.** Every jump of more than 600 pt in a frame snaps it. No real flight moves that far in
  a frame (≤ 100 pt), so only rewinds and session switches are affected.
