# Core — Round 5 notes (P1-9: goals the bests already meet)

## Built
- **`PlayerBests`** (Goals.swift; Codable, Equatable, Sendable). It holds the best single flight for metres,
  Perfects, chain, lighthouses, Tailwinds, cloud touches, clean metres and speed, plus `lifetimeMeters` and
  `dailyPlayed`. `merged(with: RunResult)` folds a run in: maxima, lifetime += metres, and a Daily sets `dailyPlayed`.
- **`GoalEvaluator.isMet(_:bests:)`, `alreadyMet(goals:bests:)` and `cascadedRank(from:bests:)`**, all pure.
  - One-flight goals are met by the best flight. Totals are met by lifetime figures. Rank 2's Daily is met by any
    Daily played.
  - The "Fly 1 more Daily Flight" goals (`dailyRunGoalIDs`: r7, r10, r13) are never met from bests.
- **Ladder re-pace.** With auto-complete, an expert swept every flock in 17 runs, so the ladder now has a pace that
  bests can't skip:
  - **Distance spine:** every flock carries one lifetime goal: 5, 15, 40, 80, 130, 200, 300, 420, 560, 720, 900,
    1,200, 2,000 and 3,600 km. This supersedes R3's r9 400 km and r12 1,000 km.
  - **Daily gates:** "Fly 1 more Daily Flight in total" at ranks 7, 10 and 13.
  - **One-flight goals:** the two left in each flock are the R4 targets. Some were dropped to make room (for
    example, r1's chain).
- **`tools/goal-cadence.js`**: auto-complete with cascading rank-ups, plus `model=expert` and `autocomplete=0`.
- **Tests (CoreTests):**
  - a 12 km flight pre-completes "Fly 3 km" and "3 Perfects" but not "15 km in total";
  - `isMet` agrees with `progress` for every goal;
  - `merged(with:)` maxima and totals;
  - the cascade stops at the distance spine and at the Daily gates;
  - the spine rises and has exactly one total per flock.

## Cadence (`goal-cadence.js`, 10 players, 5 runs a day, auto-complete on)
| Model | Rank 3 | Rank 6 | Rank 10 | Rank 14 | Target |
|---|---|---|---|---|---|
| Expert from run 1 | — | — | — | run 59 | ≥ ~60 |
| Improving (casual for 12 days, then half expert) | run 6 | run 13 | run 41 | run 124 | 8 / 20 / 50 / 105 |

**Trade-off:** with distance as the only gate bests can't skip, a top that lasts an expert 60 runs comes about 4
days later than UX's day 21 for the improving player. The expert floor wins here, as asked. To shift the balance,
lower `r13-total` (3,600 km): 3,000 km gives expert 49 / improving 110.

## Balance
No physics or Tuning changes. The R4b numbers stand (Swift casual 138 s).
