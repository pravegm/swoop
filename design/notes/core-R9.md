# Core — Round 9 notes (guide gull, headline inputs)

## Built
- **`PracticeGhost`** (new file `Swoop/Core/PracticeGhost.swift`; also `FlightSession.practiceGhostPath(step:)`, the
  name UX §9 uses).
  - **How it works:** each demo is a headless `FlightSession.practice` at 1× time. It rewinds to the step's
    checkpoint and flies the scripted ideal tuck, so the ghost does exactly what the player's bird will do if copied.
  - **The four demos:**
    - `.dive`: waits on crest A while the tuck comes in, then slides folded to the trough (~2.2 s, held ≈ 1.0).
    - `.soarAndLand`: from the trough it opens up the face, launches with the wings open, and lands Perfect on the
      guided downslope.
    - `.guidedLanding`: the retry, from the `nextGuidedSwell()` point, into the ring.
    - `.rhythm`: the 3 waves (λ 2000), folding down each slope and in the air on the way down and opening up each
      face. It launches 3 times and lands Perfect per wave.
  - **Samples** are taken every 1/60 s with `t`, `x`, `y`, `bodyAngle`, `tuck`, `skimming`, `folded` (tuck ≥ 0.5,
    the fill rule) and the step `signals` at each sample. `PracticeGhost.sample(_:at:)` interpolates and `duration`
    gives the length.
  - **Pure and deterministic.** There's no cache (a static mutable one would trip Swift 6 isolation); each demo is a
    few hundred steps.
- **Results-headline inputs.** `Lighthouses.next(afterMeters:)` gives the next fixed-name lighthouse and its
  "further" distance, rounded up per UX §2.2: 100 m steps from 1 km, 10 m below (e.g. 1,900 m, 350 m).
  `roundedFurther(meters:)` is public. The passed count and name are already in `RunResult`.
- **Tests (CoreTests):**
  - every ghost is deterministic, evenly sampled, forward-only and bounded in speed;
  - the dive is held and folded down the path, and the soar and the retry land Perfect;
  - rhythm gives waves 0/1/2 with ≥ 3 launches and ≥ 2 Perfects;
  - interpolation;
  - building a ghost doesn't touch a live practice session;
  - the headline rounding cases.

## Unchanged
Balance and the practice session's own behaviour: no physics, Tuning or practice-API changes. The Node sim doesn't
model the ghost; its rhythm and landing paths were the R6/R6b Node checks.
