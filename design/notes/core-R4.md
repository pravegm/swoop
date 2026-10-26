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

## Round 4b: the Swift/Node drift (CI run 40363850772: Swift casual 122.8 s < 130)
- **Cause 1, a harness mismatch.** `BalanceTests.swift` starts runs with `skipCountdown()`, but `balance-sim.js`
  flew the 3 s countdown first. That moved the Node novice median ~10 s (72 against Swift's 62). Node now starts
  runs the same way (`T.harnessSkipCountdown`) and matches Swift: novice 62–65, expert 330–354.
- **Cause 2, chaos.** A 1e-10 nudge to gravity moves a 20-seed casual median by ±5–10 s (135–155 s in Node), and
  Swift's libm is one more such draw. Swift's 123 s was a low draw on a mean that sat only ~10 s above the floor.
  - The pilots, the session and the tuck-rise cap all match Node line by line. `AutopilotTuckSource` and the
    hinge's own cap don't take part in the balance runs, since the tests drive `FlightPilot` directly.
  - `storm-fit.js ens=3` now fits against a 3-run perturbation ensemble.
- **Retune.** `stormLeashGap` 9000 → 10500. With the leash longer, `leadMeterScale` 5.0 → 5.7 keeps the casual
  median meter at ~60 %.

  Node ensemble (3 × 20 seeds), as medians:

  | Skill | Median run | Perfects/min | Splashes/min |
  |---|---|---|---|
  | Novice | 64–65 s | 2.6–2.9 | 2.7 |
  | Casual | 147–157 s (mean ~151) | 10.4–11.2 | 3.3–3.6 |
  | Expert | 345–366 s | — | — |
  | Perfect | 476–494 s (all caught) | — | — |
