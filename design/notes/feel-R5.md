# Feel R5: Home calibration, low rests, the slam cap (26 Oct 2026)

## Built
- **P1-7, Home calibration (REVIEW-4-duo P1-A).** `HingeTuckSource.homeCalibrate(at:)`, called every frame on Home
  (and on Results before fold-to-fly arms):
  - It snaps "open" once the hinge has been still for 0.6 s at 125–172°; under 132° it clamps to 132.
  - **It never learns from a tucked angle.** A still angle more than 8° under the previous still rest (within 10 s)
    is a fold being held, and is ignored for that whole still period. Relaxing ≤ 8° lower, or opening wider, is a
    new rest.
  - The slow calibration was already safe: it ignores tucks above 0.4.
  - Tested: a 140° rest snaps after 0.6 s (the title bird reads 0, not 0.58). A fold held at 128° for 3 s leaves
    open at 152°.
- **Persistence.** `restoreOpenAngle(_:)` (clamped to 132…172; NaN ignored) and `onCalibrated: ((Double) -> Void)?`,
  which fires after any snap (Home, countdown, resume, low rest) that moves open ≥ 0.5°. The App saves the value
  through SettingsStore and restores it at launch, so a launch no longer starts at 160°.
- **P1-8, rests under 125° (REVIEW-4-duo P2-2), with a kinder rule than the critic's.** The critic proposed
  "snap to 132 for any still rest ≥ 105°", but a 105° rest against 132 is a 0.93 tuck, nearly full. Instead:
  - `lowRestFallback(at:)` returns `.snappedToFloor` for 119–125°, setting open to 132 so the start tuck is ≤ 0.36.
  - It returns `.tooLow` for rests under 119°, where no open angle is safe (the closing zone starts at 90°). The App
    then keeps holding and offers "Fly with touch".
  - It returns `.fine` for ≥ 125° (the ready snap handles those) and `.moving` while the hinge moves.
  - `startTuck(at:)` is the App's guard: never "Go" while it is above 0.5.
- **Slam cap (optional item): left at 0.15 s, as instructed, because I could not show it never clips.**
  - Simulated a squeeze of 36° in 0.2 s at 120 Hz, mapped through the smoothstep.
  - With a linear angle ramp, it is clipped by up to 0.04 tuck, with no delay at half tuck.
  - With a natural (minimum-jerk) human motion it is clipped by up to 0.33 tuck, and reaches half tuck 17 ms late.
    Even a 0.3 s squeeze loses 0.13.
  - Relaxing to 0.12 s halves the clip. 0.10 s removes it for linear squeezes of 0.15 s or more, and for natural
    ones of ≥ 0.3 s.
  - **Recommendation:** decide on device checks A10/A10b. If anyone reports lag, try 0.10 s
    (`HingeTuckTuning.fullTuckMinTime`); it still stops a slam above ~360°/s from gaining anything.

## Files
`Swoop/Input/HingeTuckSource.swift` (`HingeLowRest`; `homeCalibrate`, `restoreOpenAngle`, `onCalibrated`,
`lowRestFallback`, `startTuck`; snaps now share one `applySnap`). `SwoopTests/InputTests.swift` has 30 tests (4 new;
FakeHinge gained `home:`). `design/NEEDS.md` ("Feel → App (Round 5)"). Feedback is unchanged this round.

## Deviations
- The low-rest floor is 119° (start tuck ≤ 0.36), not the critic's 105°. Under 119° the App holds and offers touch.
  That is ROUND-5's own suggestion, and the only way to never start nearly tucked.
- The Home fold guard uses the recent rest, not the current open angle. On a first launch (open 160° from the
  default) a 140° rest must still be learned.

## NEEDS (App)
- `homeCalibrate(at:)` each Home/Results frame;
- save/restore the open angle via `onCalibrated` / `restoreOpenAngle`;
- `lowRestFallback` at the end of the nudge budget, plus "Fly with touch" on `.tooLow`;
- the `startTuck` guard at Go;
- "Open it a little wider" on Home while `restIsBelowFloor`.

## Tune on a real Duo
- Is 0.6 s of stillness reached by a relaxed two-hand grip on Home? Readout: does "calib open=… (home)" appear?
- Is the 8° fold guard right? Does a deliberate shallow fold held on Home (< 8°) ever get learned as "open"?
- The rise cap: A10/A10b (lag) decides 0.15 vs 0.10 s.
