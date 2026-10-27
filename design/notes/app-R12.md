# App R12: targets that are really there (27 Oct 2026)

Scope: ROUND-12's App items: P0-1 (the words and pointer rule), P0-2(b) (Skip and the dots), P0-3 (the miss after
the dive, and the s1-06 frame), P0-4 (the diagram's done state), P0-5 ("Your wings"), P1-8 (the backing), plus P1-7 for
the App-drawn lighthouse name. The asks for Scene are in `design/NEEDS.md` → "App → Scene (Round 12)". Nothing is
committed; CI hasn't compiled any of it.

## P0
- **1. Words never name a target that isn't on screen.**
  - The rule is `SchoolRingRule.ringInView(ring, bird:, screen:, mirrored:)` (pure, in `FlightSchool.swift`): the ring
    rect (Scene's `ringScreenRect`, which covers the ellipse and its drop marker) must be non-empty, entirely inside
    the view, and its centre ahead of the bird's screen x in the flight direction. It checks "ahead" itself, so a ring
    behind is refused even if Scene still reports one.
  - `FlightSchool.words(at:ringInView:)` / `subWords(at:ringInView:)`: with the ring not in view, the storm step says
    "Stay ahead" by the meter and the land step "Open to glide" / "Let go to glide" / "Glide" (tapping) at the spot,
    with no second line (it would ask to come down before the ring).
  - `publishSchool` puts both into `SchoolDisplay` (`noRingWords`, `noRingAnchor`, `noRingSub`), and `SchoolBirdRig`
    picks per frame (`SchoolDisplay.shownWords(ringInView:)`), so held demo frames follow the ring too.
  - The pointer only goes to a ring in view (`SchoolRig.pointerRing`): never off an edge or back to a ring behind.
- **2(b). Skip and the dots in the trailing corner.** `SchoolLayout.make`: Skip sits at the bird page's outer bottom
  corner (bottom-left unmirrored and on iPhone, bottom-right mirrored), and the dots pill is centred 6 pt above it, so
  the pair stays in that corner. Stacking (rather than side by side) keeps both behind the bird's default point on
  every canvas, including the iPhone, where side by side would have reached the bird's x.
- **3. "Opened too soon" only after the dive.**
  - The miss words show only from `missedAt`, which is set when the wings open (< 0.3) after the folded bird has gone
    ≥ 300 pt down the face (`watchFace`, from the new `SchoolInput.seaX`), or by Core's verdict at the trough.
  - The rewind now waits `missRewindDelay` (1.2 s), so the words are read where the bird is. Back on the crest the rule
    shows again ("Fold down the wave"), with the remedy ("Stay folded to the bottom") as its second line.
  - If the player corrects in time and Core passes the dive, the miss words go.
  - The s1-06 frame (`school=dive:fail`, both scenario files, wait 6 → 8 s) is now a real early open: a DEBUG tuck
    script folds off crest A and opens at sea x 450 (`demoEarlyOpenTuck`), and the frame holds at x 1000
    (`demoSchoolFreezeX`), partway down the face, with the wings and the diagram open. The scenario args are unchanged.
  - No gold tick on the wave (Scene's, offered in NEEDS).
- **4. The fold diagram matches what it asks.** The done state draws the step's TARGET pose
  (`FlightSchool.doneTarget`: hold/soar open, wings/dive the 135° fold) filled: its wedge, solid plates, the tick.
  It's the same geometry as the dashed target. `WingDiagram.drawnTuck` clamps the live pose so it never folds past a
  fold target. The Studio now passes the done target, not nil.
  - The R11 code already drew done at 135°, the same as the target, so s1-04's "deep V" was mostly the drawing's 1.6×
    rise exaggeration (36° a plate for 135°) shown as solid plates. I left the exaggeration alone, because tests pin
    it. If testers still read the done pose as deep, lower that factor.
- **5. Which bird is me.** The top-down gull is the App's `TitleBirdView`, so this is App work. On the first step
  (`.hold`), a muted caption reads "Your wings" (a Duo on its hinge) or "Your bird" (touch and iPhone).
  - It sits under the gull's far-page wing (`SchoolLayout.wingsCaption`), so it's off the fold and away from the
    diagram, and fades out over 0.4 s as the step's success shows.

## P1
- **7 (App-drawn).** The storm step's "Gull Point" label (`SchoolRig.lampLabelCenter`): its box sits 22 pt over the
  lamp, or beside the tower when the top of the screen leaves no room (the iPhone's s1-12, where the old clamp drew it
  through the tower).
- **8. Words on the sun-glint.** `SchoolWord(backed:)` adds a soft navy backing at 0.5: a feathered (blur 8) rounded
  scrim, not a panel. Every word at sea uses it.

## Tests
- **New `SwoopTests/AppTestsR12.swift`:**
  - the ring rule (ahead / behind / cut / missing, both directions);
  - the other words without the ring, and that no step anchors to a ring not in view;
  - the display's pick;
  - Skip and the dots in the trailing corner, behind the bird and off the pause, the meter and the Studio's words;
  - the miss only down the face, with the deferred rewind and a corrected open;
  - the s1-06 demo (DEBUG);
  - the done target;
  - "Your wings";
  - the lighthouse label vs its tower.
- **Updated in `AppTests.swift`:**
  - `schoolSeaStepsReadCoreSignals`: the deferred rewind, and three misses spaced past it;
  - `wingDiagramAndRig`: the dots on the bird page, stacked over Skip.

## For CI to confirm
- **`SchoolStep.allCases` loop with `#expect(s.words(at:ringInView:)…)`.** It's a non-mutating call on a `var`, as in
  R11's tests.
- **`.background { if backed { … } }` on `SchoolWord`.** The negative padding grows the scrim past the text before the
  blur.
- **`return` inside the `Canvas` renderer closure** (the done branch).
- **The s1-06 timing.** The bird must travel crest A → x 1000 within 8 s after launch at the practice sea's 0.8×. If the
  frame shows the crest, raise the wait. The capture would also log no `SWOOP-T freeze school`.
- **s1-12 / s1-13** now read "Stay ahead" unless Scene's ring is fully on screen ahead by 3.4 s / 5.4 s into the storm
  step (Scene's P0-1 spawn).
