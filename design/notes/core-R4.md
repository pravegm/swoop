# Core — Round 4 notes

## Built
- **Goal text (P0-1, the Core half).**
  - Every goal now says "in one flight" or "in total". There are 42 ladder goals and 7 star-pool texts, for example
    "Pass 3 lighthouses in one flight" and "Fly 400 km in total". The Daily goals read "Play 1 Daily Flight in total"
    and "Fly 1 more Daily Flight in total".
  - New `GoalCatalog.scope(of:) -> GoalScope` (`.oneFlight` / `.total`), so the App can show "best 2 of 4 in one
    flight" next to this run's stats instead of a bare tick.
  - Test: `everyGoalStatesItsScope` checks every text against its scope.
- **Fast squeezes gain nothing (Duo critic).** The eased tuck alone did *not* make this true: a slam reached the dive
  sooner than a firm squeeze. So the session now rate-limits the rise of the tuck input before its easing
  (`Tuning.tuckMaxRise` = 1/0.15 s, the critic's figure). Any squeeze that reaches full tuck faster than 0.15 s (more
  than ~240°/s of hinge) now gives exactly the same flight. Opening is not limited.
  - Test: `slammingTheHingeGainsNothing`. A slam and a 0.05 s squeeze give bit-identical events and snapshots. A
    0.4 s squeeze differs. 0.1 s after a slam the eased tuck is ~0.3.
  - The pilot's predictor models the limit too, as does the Node sim.
- **Daily number.** `DailySeed.displayNumber(day:)` returns `max(1, day − launchDay + 1)`. `DailySeed.launchDay` is
  2026-11-24 UTC, day 327, so that day is #1. Seeds are unchanged; the test checks both.
- **Re-tune.** The rise limit cost the pilots tempo (expert median 341 → 239 s), so I refit the storm with
  `tools/storm-fit.js`. Only `stormLateAccel` changed, 3.5 → 2.5; the leash now keeps experts from running away.
- **Ladder re-paced** for the slower casual run. Mid-ladder targets are down about 15 % (for example r5 is now
  3 lighthouses, 25 Perfects and 6 Tailwinds), and r13 is 65 km, a chain of 32 and 7 clouds. Star flocks are
  1.5 × those targets.
  - `goal-cadence.js` (10 players) reaches ranks 1/3/6/10/14 at runs 1/6/18/46/86, against targets of 2/8/20/50/105.

## Node-sim balance (20 seeds, dt 1/120; the R2 targets are kept)
| skill | median | Perfects/min | splashes/min | target |
|---|---|---|---|---|
| novice | 71.7 s | 3.7 | 2.5 | 45–80 s, ≥ 2 |
| casual | 138.9 s | 10.9 | 3.3 | 130–170 s, ≥ 7, ≤ 4 |
| expert | 386.0 s | 17.3 | 2.5 | 300–500 s |
| perfect | 461.5 s (all caught) | 22.6 | 1.7 | must end |

The casual gap p50 is still 3.07 × fullLead, so `leadMeterScale` 5 still reads ~61 %. Swift has run a few seconds
longer than Node for casual in past rounds, which helps the 130 s floor.

## Other review findings touching Core
- **Lead meter "starts almost empty" (player)** against "pinned full" (R3 UX). I left the gap and the scale alone.
  NEEDS.md offers the App a saturating curve, gap / (gap + 2400): 50 % at the start, 16 % at storm-close, ~79 % at
  cruise. Juror #15 asks the App to confirm it reads `Tuning.leadMeterScale`.
- **"Goals too easy after a big run"** (player: draw new goals at 1.2–1.5 × the best). Not adopted. It would break the
  fixed, paced ladder and the reward-per-rank layout. The re-paced mid ladder already sits at casual p75–p95.
- **Tests adjusted.**
  - `openWingsDescendSlower` now measures over 0.4 s, because the dive needs the 0.15 s rise.
  - The two text asserts follow the new copy.

## Tune on a Duo
- **`tuckMaxRise`:** 0.15 s should feel firm, not laggy. Squish coaches at 250°/s. If the dive feels late, try 0.12 s
  and re-run the sim.
