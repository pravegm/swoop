# Round 12: targets that are really there (fresh testers 16–18 on R11, 27 Oct 2026)

The reports are in `design/fresh/tester16-duo.md` (33, casual, Duo), `tester17-duo.md` (47, non-gamer, Duo) and
`tester18-phone.md` (UI designer, iPhone). They saw the R11 frames (TF 1.0 (8)).

| Tester | Understood | Finished | Keep playing |
|---|---|---|---|
| 16 (Duo, casual) | 7 | **7** | 6 |
| 17 (Duo, non-gamer) | 7 | 6 | 6 |
| 18 (iPhone, designer) | 7 | 4* | 6 |

\* Tester 18 was shown three frames broken by the capture, not the game:
- s1-03 was a blank portrait frame, shot while the simulator was still rotating;
- s1-04 was caught mid-rotation;
- s1-14 was the launch screen.

The founder fixed `ci/screenshots.sh` to re-shoot unsettled frames.

**What R11 fixed:** nobody mentioned the storm edges. "The storm caught you" was understood by all three.

**What every tester named:** the storm step says "Land in the gold ring" with no ring anywhere on screen.

## P0
1. **Words never name a target that isn't on screen** (s1-12 and s1-13 on Duo and iPhone, all three testers).
   - In the storm step, the dotted pointer runs off the screen edge **behind** the bird, to a ring already passed or
     not yet spawned.
   - **The rule** (in a pure function, with a test): "Land in the gold ring", "Land here" and every pointer show only
     while the named ring is fully on screen and ahead of the bird. Otherwise the step shows its other words ("Stay
     ahead" by the meter), with no pointer.
   - **The storm step must actually spawn its ring ahead** within about 1.5 s of the words. Check the frames: s1-12,
     s1-13 and s1-13b.
   - **Owner:** App (words and pointer rule); Scene (spawning the ring ahead and reporting `ringScreenRect` only for
     a ring ahead and on screen).
2. **The landing ring is never under a control or cut by an edge** (s1-08, Duo and iPhone).
   - The ring sits in the bottom corner the bird flies toward, under Skip and the step dots, clipped by the screen
     edge. R11's camera rule (200 pt inboard) is not holding in the frame.
   - **Fix both ends:**
     - **(a) Scene:** make the inboard rule hold by the time the words show (test the settled rect against the
       canvas inset by 200 pt sideways, 160 pt at the bottom).
     - **(b) App:** Skip and the step dots move to the **trailing bottom corner**, the side the bird flies away from.
       That is bottom-left on iPhone and the unmirrored flight, and bottom-right when the flight is mirrored. They
       stay out of the bird's path.
   - **Owner:** Scene and App.
3. **"Opened too soon" never shows before the dive has happened** (s1-06, tester 17).
   - The miss words appeared with the bird still on the crest, where it was in s1-05, so it read as failing before
     starting.
   - The miss words show only after the bird has gone down the face and the early open was detected.
   - Make the s1-06 frame show the bird partway down the face, with a small gold tick on the wave where the open
     happened. Add that marker only if it's simple; skip it otherwise.
   - **Owner:** App (timing and scenario); Scene if a marker is added.
4. **The fold diagram matches what it asks** (s1-03 → s1-04, tester 17).
   - "Fold a little" shows the 135° target, but the done state shows a deep V, because the demo folded fully.
   - The done state draws the **target** pose filled, with the tick, and clamps the live pose to the target in the
     drawing. The diagram is never a different shape from the one the words ask for.
   - **Owner:** App.
5. **Which bird is me** (s1-02 to s1-04, tester 17; earlier testers too).
   - The big top-down gull at the top is the player's wings: the two screen halves. The small side-on gull on the
     water is the flight.
   - On the first step only, a muted caption under the top-down gull says **"Your wings"** (Duo) / **"Your bird"**
     (iPhone, if the top-down gull shows there). It fades when the step completes.
   - **Owner:** App, or Scene if the top-down gull is a Scene node. Decide by where it lives.

## P1
6. **The guide gull's ghost is never cut by the screen edge** (s1-07, Duo; tester 16).
   - The ghost outline and its dotted trail start half off the left edge and are never explained.
   - The ghost appears fully on screen, ahead of or level with the bird. If it can't be fully on screen, it doesn't
     show.
   - **Owner:** Scene.
7. **Lighthouse labels sit above the lighthouse** (s1-12 on iPhone: the "Gull Point" label is drawn through its own
   tower). The label's baseline is at least 8 pt above the lantern top. **Owner:** Scene (or App if the label is a HUD
   view).
8. **Sun-glint dashes never run through words** (s1-08 on Duo: the glint behind "Land here"). The words get a soft
   navy backing as in R8 P1-10, or move off the glint. **Owner:** App.

## Process
Same as R11:
- Each engineer stays in their own folders, updates the tests, and writes `design/notes/<role>-R12.md`, with
  cross-module asks in `design/NEEDS.md` → "Round 12".
- There is no local compiler.
- Don't commit or push.
