# Feel R2: calibration fixes and the Perfect moment (26 Oct 2026)

## Built
- **QA-1 P1-3, the upward ratchet (`HingeTuckSource.calibrate`).**
  - Upward learning is now slow (τ 10 s). It only uses angles at most 6° above open, and never above 168°.
  - A still rest further up (≤ 168°) is still learned, at τ 12 s after 2.5 s held still, so a low snap can recover.
  - Downward learning is unchanged (τ 4 s near open; the still-settle path at τ 12 s).
  - So a wide-open or flat glide (≥ 175°) never moves "open". Tested: snap at 150 → 6 s at 176 → back at 150 leaves
    open at 150 and the tuck under 0.05.
- **QA-1 P1-4, the snap (`snapCalibration(at:)`, default `CACurrentMediaTime()`).** The founder's API and the
  countdown snap are kept.
  - It snaps only while the hinge is still: the raw reports of the last 0.3 s span ≤ 1.5°, and a resting Duo sends
    none. I used the spread rather than net speed, because a net speed reads 0 at a fidget's turnaround.
  - It snaps only from the filtered angle: the display-rate angle while frames run (countdown), otherwise the
    predictor (the resume hold asks no tuck), which glides onto the last reading once still.
  - A mid-reopen angle never becomes "open". If the hand never rests inside the hold, the old calibration stays.
  - New `isStill(at:)` so the App can extend the hold (NEEDS.md).
- **The Perfect moment.**
  - **Brighter with the chain.** Brightness rises from 0.3 to 0.62 (0.035 per step) and a 6th partial appears. A
    glass glint an octave up joins from chain 3 and grows. The chime's level drops as it brightens, so it is never
    louder (tested).
  - **Whoosh-pop on the punch-in.** A 35 ms upward band sweep through the hit-stop, then a soft 520 Hz "pop" droplet
    at +35 ms (`FeelSoundBook.hitStop`).
  - **Haptic on the hit-stop.** A firm tap (0.9/0.85) at 0 and a keen, lighter one (0.55/1.0) at +35 ms.
    - The pattern player is prebuilt for every engine start, so nothing is built at the moment it fires.
    - It plays before the audio on the frame of the Perfect, and Perfects are no longer rate-limited.
  - **Chain break.** After a splash that ends a chain of 2 or more, two quiet, dull chime notes (≤ 0.05) fall a fourth
    from the chain's scale degree, starting 0.22 s after the splash. No noise, nothing harsh. Chain tracking follows
    Core's new rule: a Good keeps the chain.
- **3-minute fatigue pass.**
  - The whistle (the only tonal part of the bed) goes from 0.26 to 0.2, with Q 6…10 (was 7…12).
  - The skim band tops out at 5.4 kHz (was 6.6), and its peak gain goes from 0.12 to 0.11.
  - A new test renders 8 s of a casual stretch at 48 kHz: a swell every 2.5 s with skim, launch and tuck, and
    Perfects at 7/min. It checks that the bed is ≤ −24 dBFS RMS, the full mix ≤ −21 dBFS, and under 0.2 % of
    samples go above 0.6 (the limiter barely works). My estimate is a bed around −35 dBFS.
- **QA-1 P2-12:** haptics off stops both players and the engine at once. **P2-13:** `-swoopDemo` is DEBUG-only in Input.

## Files
Input: HingeTuckSource, FeelFilters (`HoldStabiliser.spread`), HingeReader. Feedback: FeelSoundBook, FeelHaptics,
FeedbackDirector. Tests: InputTests (17), FeedbackTests (19). `design/NEEDS.md` (Feel → App).

## Deviations
- The founder's `readyPoseSnapsTheOpenAngle` now drives the snap the way the App does (every frame, through
  FakeHinge). The fold check allows 0.3°, because the dive's pass through the near-open band nudges the calibration.
- `calibrationStaysInsideItsRange` and `calibrationFollowsAHigherRestingAngle` were updated for the new upward rules.
  177° no longer teaches "open"; a 168° rest needs ~30 s without a snap.
- QA-1 P2-3 (the closing latch clears only on a fresh sample) is left to the App's ClosingCard.

**NEEDS:** none blocking; optional App items (`snapCalibration(at: now)`, a hold extended while `!isStill`) in NEEDS.md.

## Tune on a real Duo
1. `snapStillSpread` 1.5° / `snapStillWindow` 0.3 s: does a resting two-handed grip count as still? Watch
   `SWOOP-T calib open=… (ready pose)` during the countdown. If it never fires, raise the spread to 2.5°.
2. Is the upward window (6°, τ 10 s) and ceiling (168°) right for players who rest at 165–170°?
3. **Perfect timing:** does the second tap feel like the release of the hit-stop, or like a flam? If it smears, try
   +50 ms or a single tap.
4. **Chain break:** is it audible under the splash on the speaker, without sounding like a penalty?
5. Bright high chains (chain 11+, D7 region): the top octave is less loud but brighter. If it gets piercing, cap
   `chimeBrightnessMax` at 0.5.
