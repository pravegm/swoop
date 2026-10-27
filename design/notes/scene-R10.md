# Scene, Round 10 (27 Oct 2026)

Scope: ROUND-10 P0-1 (the Scene part) and P1-5 (the peaks). The App's side is in `design/NEEDS.md` → "Scene → App
(Round 10)".

**Files:** `FlightScene`, `SceneEffects`, `SceneParticles`, `SceneLook` and `SwoopTests/SceneTests.swift`.

## 1. The storm recoils in the school's storm step
- **Before:** a 90 pt push that decayed linearly over 1.5 s. Easy to miss in a still.
- **Now** (`FlightScene.recoil(age:)`, pure):
  - nothing for 0.15 s, while the gust streaks run from the bird to the wall;
  - then a 150 pt ease-out shove over 0.2 s, with an inner glow as the gust hits;
  - a hold to 1.2 s;
  - an ease back to its 0.20 w rest by 2.7 s.
- **For the App:** `stormRecoil` (0…1) lets the meter knob jump in sync.
- **In real flights:** each Perfect now kicks the wall back 40 pt for about 1 s (it only showed through the meter's
  easing before).

## 2. Each moment's peak is its strongest beat
- **The Perfect:**
  - The ring used to fade *while* growing, so at full size it was invisible (tester 10's s09 shows only spray). It now
    grows at full alpha, holds 0.15 s at full size, then fades over 0.3 s.
  - Every Perfect's ring is gold, where ×1–4 were foam before; the tiers escalate to reward gold and a second ring.
  - The bloom is larger and brighter (210 pt, 0.45 / 0.55), and there is a 4-star gold burst on every Perfect, with
    more up the chain.
  - The peak is at 0.42 s.
- **The catch:**
  - The peak is the front crossing over the bird, at about 0.5 s of the 1.2 s sweep.
  - The bird flinches (squash, camera dip, a splash of spray) and the wall lights from inside.
  - The R9 bolt ahead of the bird follows at 0.9 s.
- **Hooks:** `onPeak` / `momentPeak` (`.perfect`, `.caught`, `.recoil`) fire once on the peak frame, for the App's CI
  freezes.

## Tests
- `recoilEnvelopeShovesThenEasesBack`
- `schoolPerfectShovesTheStormBack`: ≥ 140 pt back, both peaks fire, the wall returns.
- `catchPeakFiresAsTheFrontCrossesTheBird`: it fires once, with the edge just past the bird.

## Not changed
- The PERFECT word, the meter knob jump and the "Perfect pushes it back" words are App's (P0-1).
- The bolt timing stays as ART-ROUND-9 §2 set it.
