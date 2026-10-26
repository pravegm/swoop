# Core — Round 2 notes

## What I built (ROUND-2 "Core engineer")
1. **Landings.**
   - A 7° landing assist (`Tuning.landingAssistDeg`, `Tuning.assistedAngle`): the velocity turns toward the tangent
     before it is judged, with the speed kept. It applies to every touchdown.
   - Perfect is now ≤ 18° on a slope below −2°, Good ≤ 36°, and a splash keeps 0.82 of the speed.
   - After cruise speed the storm accelerates at 3.5 pt/s².
2. **Chains.** A Good holds the chain (no add, no Tailwind refill), and `touchdown(.good, chain: N)` reports N. Only a
   splash breaks a chain.
3. **The tutorial guarantees Perfects.**
   - The intro (x < 3700) is a fixed half-cosine train between extrema (`Tuning.tutorialKnots`, C¹), found by a Node
     search.
   - With no input, the drop lands Perfect at ~1.3 s and the second swell at ~3.3 s.
   - Tucking at any point on the first downslope, for any length, still lands Perfect on the second swell. In Node
     this holds even at a 13° window.
   - Test: `CoreTests.tutorialGuaranteesPerfects`.
4. **Goals.**
   - 15 ranks (`maxRank` 14, 14 flocks × 3 = 42 goals). The speed goals are gone; every goal is visible.
   - Every rank 1…14 unlocks something (`GoalCatalog.rewards(forRank:)`). Birds are at 1/4/7/10/11/13/14 and skies at
     3/6/9/12. The new `TrailCatalog` adds Coral (2), Aurora (5), Ember (8) and Storm Gold (14), plus Natural (0);
     `TrailCatalog.apply` recolours a bird. App already uses it (NEEDS.md).
5. **QA-1 P2s.**
   - The Tailwind end eases the speed cap and drag back over 0.6 s (`tailwindFade`); the test asserts < 1 % per frame.
   - Clouds fire at y ≥ `Tuning.cloudHeight` above the mean water. Scene draws its deck there (SceneProps uses
     `Tuning.cloudHeight`).
6. **Extras.**
   - `SeaProfile.samples(into:)`, a no-allocation buffer (QA-1 P1-6).
   - The pilot planner has a step budget, 2500 per plan, about 1 k typical (QA-1 P2-14).
   - Pilots pull out of a dive that is sure to splash.
   - `Tuning.fullSpeed` and `Tuning.leadMeterScale` are new.
   - The new `tools/storm-fit.js` fits the storm law instantly from recorded runs.

## Tuning changes beyond the five listed (needed to hit the new targets)
- **`seaWavelengthScale` 2 → 3** (the long swell is 1860–2700 pt). Changing only the R2 rules left casual at
  7 splashes/min whatever its error model. Longer downslopes forgive a late fold.
- **`airTuckGravityFactor` 1.9 → 1.3**, a gentler air dive. Together with the longer swells, casual splashes drop to
  3.5/min.
- **Storm.** Base 520 → 480, accel 9 → 18, cruise 1500 → 1800 (late 3.5 per ROUND-2, max 3200), fitted by storm-fit.
  Cruise is reached at ~73 s.

## Node-sim balance (20 seeds, dt 1/120, 15-min cap; BalanceTests assert the ROUND-2 targets)
| skill | median | p10–p90 | Perfects/min | splashes/min | target |
|---|---|---|---|---|---|
| novice | 52.6 s | 38–72 | 2.4 | 2.7 | 45–80 s, ≥ 2 |
| casual | 157.4 s | 136–183 | 12.3 | 3.5 | 130–170 s, ≥ 7, ≤ 4 |
| expert | 409.8 s | 379–424 | 20.5 | 2.1 | 300–500 s |
| perfect | 526.2 s | 501–554 (all caught) | 25.6 | 1.3 | must end |

The tight margins are casual splashes (3.5 against ≤ 4) and novice Perfects (2.4 against ≥ 2). If Swift drifts from
Node, re-run `node tools/storm-fit.js grid=1` for the storm. Over 200 km the max |slope| is 1.01, with no blend
fallbacks.

## API (all additive; old signatures kept)
- `GoalCatalog.maxRank` changes value, 15 → 14. A rank stored by R1 can be 15 and should be clamped (NEEDS.md).
- New types and calls:
  - `TrailID`, `Trail`, `TrailCatalog`
  - `RankReward`, `GoalCatalog.rewards(forRank:)`
  - `SeaProfile.samples(into:from:to:step:)`
  - `Tuning.landingAssistDeg`, `tailwindFade`, `fullSpeed`, `leadMeterScale`, `tutorialKnots`
- Removed: `Tuning.tutorialAmplitude`, which had no users.
- Tests: CoreTests has 43 tests, adding the classification and assist windows, the tutorial guarantee, chain rules,
  the Tailwind fade, rewards and trails, the intro's smoothness and `samples(into:)`. BalanceTests use the new asserts.

## Tune on a Duo
- **The assist plus 18°/36° is generous.** If Perfects feel free, try `perfectAngleDeg` 16 before touching the assist.
- **`airTuckGravityFactor` 1.3:** does the dive still feel heavy? If not, raise it to 1.5 and check casual splashes
  in the sim.
- **Longer swells:** check that the camera shows a whole swell (Scene zoom).
