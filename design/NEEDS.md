# NEEDS (cross-module requests)

## App → Core (Round 2, trail-colour rank rewards): RESOLVED
Core shipped `TrailID` / `Trail` / `TrailCatalog` (Catalogs.swift) and `maxRank = 14` (15 ranks). The App adapts in one
place, `ProgressRules.trailOptions()` (Persistence/ProgressStore.swift): the Birds-screen trail picker, the rank-up
banner and the Flocks ladder read trails from there. The chosen trail is stored as the `TrailID` raw value, and
`SceneDriver.bird` hands the scene the bird with its `trail` recoloured, so Scene and Contracts need no change. The UI
shows "Rank r + 1 of maxRank + 1" (= 15). Nothing further needed.
## Feel → App (Round 2, the ready-pose snap; GameController)
The current calls (`hinge.snapCalibration()` on every frame of the countdown and of the resume hold) are right and
need no change: the snap now lands only once the hinge is still (QA-1 P1-4), so calling it while the hand is still
moving is harmless. Two small optional improvements:
- Pass the frame clock: `hinge.snapCalibration(at: now)` (the default is `CACurrentMediaTime()`, the same clock).
- Resume hold (QA-1 P1-4, second half): keep the "Ready" ring up past `readyHold` while `!hinge.isStill(at: now)`,
  for at most ~1 s more. Then a slow reopen always finishes, and the snap lands on the rest before the bird moves. If
  the hold ends while the hand is still moving, the previous calibration is kept, which is safe, just less exact.
- Perfect hit-stop: the Perfect haptic fires in `feedback.handle` on the frame the `touchdown(.perfect)` event
  arrives (a firm tap at 0, a lighter one at +35 ms). Start the hit-stop on that same frame, and keep calling
  `handle` in the frames after it, as now.

## Core → Scene (Round 2)
- **Clouds (QA-1 P2-6):** Core now fires `cloudTouched` when the bird's sea-space **y ≥ `Tuning.cloudHeight` (900) above
  the MEAN water** (it used to be 900 above the local swell). Please draw the touchable clouds with their **underside at
  y = `Tuning.cloudHeight`**, continuous enough along x that a bird at that height is visibly in a cloud (today
  `SceneLook.nearCloudHeight` 1000 is the cloud centre, with ~40 % gaps). It re-arms below y = `Tuning.cloudRearmHeight`.
- **Sea:** swells are now 3× the GAME-DESIGN wavelengths (`Tuning.seaWavelengthScale`; long swell 1860–2700 pt, up
  to ~330 pt high). The intro (x < 3700) is a fixed half-cosine train (`Tuning.tutorialKnots`).
- `SeaProfile.samples(into:from:to:step:)` is available: it reuses one buffer (QA-1 P1-6).
- Optional: `Tuning.fullSpeed` (2340 pt/s, 90 % of max) is the threshold for REVIEW-1's gold speed streaks.

## Core → App / Feel (Round 2)
- **Chains:** a Good no longer breaks a chain. `touchdown(.good, speed:, chain: N)` now reports the unchanged chain N.
  Only `touchdown(.splash, …, chain: 0)` breaks it (a chain-break sound should play only if the chain was > 0).
- `GoalCatalog.rewards(forRank:) -> [RankReward]` lists what reaching a rank unlocks (bird, sky or trail). Every rank
  from 1 to 14 has at least one. A rank stored by R1 builds can be 15: clamp it to `GoalCatalog.maxRank` (14).
- Lead meter headroom: `Tuning.leadMeterScale` (1.3). Draw gap / (1.3 × `Tuning.fullLead`); `snapshot.lead` is unchanged.
- Founder: the `cloudTouched` comment in Contracts.swift ("≥ 900 pt above the water") now means above the mean water.
