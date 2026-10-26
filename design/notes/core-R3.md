# Core — Round 3 notes

## Built (ROUND-3 Core: UX-C1–C4, the ladder stretch, the restart hook)
- **C1. Countdown option.** `FlightSession.init(…, countdown: Double = 3.0)`, plus `countdownDuration` and the public
  `FlightSession.countdownTicks(duration:)`. `Tuning.restartCountdownDuration` is 1.5.
  - Ticks for 3.0 are unchanged: 3, 2, 1 at 0, 1 and 2 s.
  - Below 2.5 s there are two beats on UX's "Ready · Go": `countdownTick(2)` at 0 s and `countdownTick(1)` at
    duration / 2 (0.75 s), then `started` at 1.5 s.
  - This resolves the Feel/App beat clash; the choice is logged in NEEDS.md.
- **Restart hook (A2).** `finishCaught()` jumps caught → finished, with the same `RunResult` as letting the 1.8 s play
  out.
- **C2.** "Fly a Daily Flight" (r7) now needs this run to be a Daily (`GoalCatalog.dailyRunGoalIDs`). r2's Daily goal
  still accepts any Daily played.
- **C3.** `balance-sim.js` prints `SWOOP-GAP` (gap / fullLead p25/p50/p75 per skill), and so does BalanceTests.
  - **Finding:** without a fix the casual gap p50 was ~10 × fullLead (a ~30 km lead), so no headroom could make the
    meter move.
  - **Fix: a storm leash** (`stormLeashGap` 9000, `stormLeashRate` 0.5 per second on the excess), with the storm law
    refit by `tools/storm-fit.js`: accel 18 → 12, cruise 1800 → 1300; base 480 and late 3.5 are kept.
  - The casual gap is now p25/p50/p75 = 2.0/3.1/3.5 × fullLead. `Tuning.leadMeterScale` 1.3 → 5.0 puts the casual
    median at ~61 %.
  - The App should read `Tuning.leadMeterScale` (NEEDS.md); its own `meterHeadroom` is 1.3.
- **C4.**
  - r9 is now "Fly 400 km in total" and r12 "Fly 1,000 km in total".
  - `GoalCatalog.starGoals(n:)` gives 3 goals per star flock, rotating through 7 kinds at 1.5 × the top targets.
- **Ladder re-paced** against UX §4 with the new `tools/goal-cadence.js`. It parses Goals.swift, so it stays in sync.
  - **Player model:** novice for runs 1–3, casual to run 60 (12 days at 5 a day), then half casual, half expert. A
    Daily is the first run of each day from day 2. Progress is max-only, with one rank-up per run.
  - **Result (median of 10 players):** rank 1 at run 1, 3 at run 6, 6 at run 19, 10 at run 49, 14 at run 98. The
    targets were 2 / 8 / 20 / 50 / 105.
  - Mid-ladder goals sit at casual p75–p95. "Touch a cloud" moved from r8 to r10 (casual players almost never reach
    the clouds). r13 is 75 km, chain 38 and 9 clouds.
- **Tests.** CoreTests adds the countdown schedules and Ready/Go timing, `finishCaught`, the leash bound, the r7 Daily
  rule, and the ladder stretch and star flocks. BalanceTests prints SWOOP-GAP and keeps the R2 asserts.

## Node-sim balance (20 seeds, dt 1/120; the R2 targets are kept)
| skill | median | Perfects/min | splashes/min | gap p50 (× fullLead) | target |
|---|---|---|---|---|---|
| novice | 65.2 s | 2.8 | 2.3 | 2.3 | 45–80 s, ≥ 2 |
| casual | 141.6 s | 12.9 | 3.3 | 3.1 | 130–170 s, ≥ 7, ≤ 4 |
| expert | 340.6 s | 21.1 | 2.0 | 3.3 | 300–500 s |
| perfect | 398.4 s (all caught) | 25.6 | 1.2 | 3.4 | must end |

R2's Swift ran ~5 s longer than Node for casual, so casual should land ~145 s. The idle bird is caught at ~43 s.

## Deviations and decisions
- **The leash is a feel change.** A big chain far ahead now buys less, because the excess decays (τ 2 s). Near the
  storm every Perfect still counts. I judged UX's "≈ 2.0 headroom" impossible without it. To try other values, run
  `node tools/storm-fit.js grid=1 cache=…`.
- **The cadence player model is an assumption** (UX said "casual"). A purely casual player stalls at rank 10–11,
  because clouds and chains of 30+ need expert flying, and I think that's right for the top ranks.
- **Star flocks are very hard by design** (e.g. 112 km, chain 57).

## Tune on a Duo
- `stormLeashGap` and `stormLeashRate`: whether the storm feels present but fair.
- `leadMeterScale` 5: meter readability.
- `restartCountdownDuration`.
