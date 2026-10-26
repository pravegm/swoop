# Core — Round 1 notes

## Built
All of `Swoop/Core/`, with exactly the ARCHITECTURE "Core API" signatures, all `public` (the public `SceneDriver`
exposes `SeaProfile`).
- **`SeededRandom`** (SeededRandom.swift): SplitMix64.
- **`Tuning`** (Tuning.swift): every number, documented; the ones to try first on a Duo are marked FEEL.
- **`SeaProfile`** (SeaProfile.swift): sets of 3 sine swells (a component can be 0, so 2–3 per set).
  - Between sets, each swell's amplitude and frequency morph over 600 pt, with a phase-continuous integral (C¹).
  - Each set keeps Σ2πA/λ ≤ 1.0, and every blend is checked numerically against 1.08 (it scales down, else continues
    the previous set), so |h'| ≤ 1.1.
  - The sea grows every 3 km, with 7 % rogue sets. Sets are cached, and queries walk from the last index (O(1)).
  - The tutorial swell is fixed for every seed up to x = 4000: a crest at x = 200, a long downslope (the first landing,
    with no input it is a "good" at x ≈ 900), then a gentle crest at ~3.5 km (the first launch, at ~1470 pt/s).
- **`Lighthouses` and `DailySeed`** (Lighthouses.swift).
  - Lighthouses stand at 4, 9, 15, 22, 30, 38 km, then every +8 km. 40 invented names in a seeded order.
  - `DailySeed` defaults to a UTC Gregorian calendar (`DailySeed.utc`), per the founder.
- **`FlightSession`** (FlightSession.swift): per GAME-DESIGN §5–§6 and ARCHITECTURE. It uses every `FlightEvent`.
  - It has internal test hooks, `testPlace` and `testSetGap`, and a pure `classify(velocityAngle:surfaceAngle:)`.
- **`FlightPilot`** (FlightPilot.swift).
  - While skimming, it tucks on downslopes, looking a little ahead.
  - In the air it plans the dive: it integrates the open path, flies a tucked branch at each candidate moment, and
    aims at the centre of the widest run of Perfects. Then it holds the dive to the water.
  - Every decision is held ≥ 0.12 s. Casual has a 0.15 s lag it doesn't allow for, plus 20 % mistimed dives.
    Novice folds in a ~0.8 s rhythm.
- **Catalogues** (Catalogs.swift, Goals.swift).
  - 8 birds (unlock ranks 0, 2, 4…14) and 5 skies (ranks 0, 3, 6, 9, 12; the storm is slate).
  - 15 ranks × 3 goals, Fledgling → Storm Rider, paced to the harness.
- **Tests.** CoreTests (34 tests) and BalanceTests (20 seeds; `SWOOP_BAL_SEEDS` overrides that).
- **`tools/balance-sim.js`**: a Node port of the sea, physics and pilot. **Keep it in sync with Tuning.**
  - Usage: `node tools/balance-sim.js [seeds=20] [skills=casual] [T.name=value]`, or `node tools/balance-sim.js sea`.

## Deviations (all tuning; the reasons are also in Tuning.swift)
- **Swells are 2× longer and 1.4× taller than §4.** The long swell is now 1240–1800 pt, and swells reach ~250 pt.
  - With 380–900 pt, the time window for a landing at 1000–2500 pt/s was too short. Casual died in ~40 s, and even the
    perfect pilot splashed 9 times a minute.
  - **Scene: check the camera zoom.**
- **Lift.** It is 0.65 g (not 0.5) and acts perpendicular to the velocity, so it does no work: an open-wing pull-out
  turns the dive into forward speed. Its vertical part is < g, so it never makes the bird climb.
- **Storm.** After 1500 pt/s it keeps accelerating (+2.5 pt/s², up to 3200), so flawless runs still end.
  §6's cap alone never caught a good pilot.
- **Blend width.** It is 600 pt, not 300: at 300 the amplitude morph pushed the slope past 1.1.
- **Tutorial length.** It runs to 4000 pt, and the x ≤ 1200 part is identical for every seed as asked.
  ARCHITECTURE says "1.2 km".
- **Launch grace.** After a touchdown the bird skims ≥ 0.1 s before it can launch again. Without it, a re-launch off a
  concave shoulder scored a double Perfect.
- **Tailwind.** It triggers at chains of 3, 6, 9… (+600 pt each). It gives +15 % speed at the start, raises the max
  speed by 15 %, and turns drag off. Each Perfect during a Tailwind refills it to 2.5 s.
- **Event and result values.**
  - `touchdown(speed:)` is the impact speed.
  - `RunResult.seconds` is the flight time up to `caught`.
  - `PilotSkill` is also `Sendable`, because Swift Testing's `arguments:` needs it.

## NEEDS
None.

## Predicted run lengths (Node: 20 seeds, dt 1/120, 15-minute cap)
| skill | median run | p10–p90 | median distance | Perfects/min |
|---|---|---|---|---|
| novice | 50 s | 41–65 s | 3.5 km | 1.3 |
| casual | 114 s | 105–122 s | 11 km | 2.8 |
| expert | 336 s | 285–388 s | 49 km | 12 |
| perfect | 617 s | 579–642 s (never capped) | 114 km | 19 |

- **Sea:** over 200 km the max |slope| is 1.05, with no blend scalings or fallbacks.
- **Idle bird:** with tuck held at 0, the storm catches it in ~33 s.
- **Frame rate:** at dt 1/30 the results are similar.

## Tune on a real Duo
- **`airTuckGravityFactor`** (1.9): how violent the air dive feels.
- **`liftMaxFraction`** (0.65): how floaty the glide is.
- **`perfectAngleDeg`** (14): at 17°, expert runs are ~30 % longer.
- **`tuckAttack` / `tuckRelease`** (0.06 / 0.08).
- **`seaWavelengthScale` / `seaAmplitudeScale`**: how the sea reads on screen.
- **The storm law:** casual players die near t ≈ 110 s, when the storm reaches cruise speed.

**Risk:** BalanceTests are ~1.5 M pilot frames. That is fast in Node but may take minutes in a debug build. If CI is
slow, lower `SWOOP_BAL_SEEDS`.
