# Feel R3: Duo-first feel and the iPhone fallback (26 Oct 2026)

## Built
- **F2, the Strong haptic profile.** `HapticProfile` (off, normal, strong; `.label`; `defaultFor(hasFold:)`) and
  `FeedbackDirector.hapticProfile`. `hapticsOn` still works.
  - An unchosen profile becomes Strong once the App sets `deviceHasFold = true`; a player's choice always sticks.
  - Strong follows UX §9 exactly. Continuous ×1.4 (clamped), with a 0.3 floor while skimming. Every transient becomes
    a 55 ms burst at sharpness 0.4 (×1.15). The Perfect is 2 × 60 ms bursts 80 ms apart, the launch one 80 ms burst.
  - The prebuilt Perfect is rebuilt on a profile change; every event haptic goes through `FeelHapticBook.adapt`.
- **F3 and accessibility.**
  - `TouchTuckSource.tapToggles` ("Tuck by: Tapping"): a press toggles the tuck and a release does nothing. Switching
    the mode while tucked lets go, so a tuck can never stick.
  - `toggle(at:)` (Switch Control select) and `setTucked(_:at:)` (the VoiceOver adjustable).
  - `CombinedTuckSource` (hinge + assist, the larger tuck wins) closes QA-2 P2-7 for VoiceOver on a hinge Duo.
- **Touch ramp tuning (UX §10).** The ramps are now ease-out, from the current tuck to the target, with a duration
  proportional to the distance left. A press reads 44 % at 30 ms (smoothstep was 16 %), a full stroke still takes
  0.12 s in and 0.10 s out, and a reversal is continuous.
  - `TouchTuckSource(attack:release:)` and `phoneAttack` 0.09 let the founder run the 0.09 / 0.10 test.
- **F4.** `cue(.touchDown)` plays a light crisp click on iPhone only. It is haptic only, by design.
- **F1 and the state cues.** `FeedbackDirector.cue(_: FeelCue)`:
  - `.homeFold`: a soft wind swell. `.foldArmed` = `uiTap`. `.foldFired` = `uiConfirm` plus a rising rush of air.
  - `.closing`: a falling breath. `.reopened`: a rising breath and a low marimba note. `.go`: a light "started".
  - `.splitDeck`: a two-tick click into place. `.bookPrompt`: a rising two-note question.
  - `.resultsTick(step)`: ART §5's count-up tick, climbing slightly, at most 25/s.
  - Every cue has sound (haptics never stand alone on a Duo); all are quieter than any flight moment, ≤ 0.8 s.
- **Matching ART §5 and UX §3.**
  - The km sparkle now sounds only on toast kms (5, 10, 15…) and stays quiet within 3 s of a lighthouse.
  - The chain-break notes now need a chain of 3+, the same threshold as the "×N lost" pill.
  - Perfect taps stay on the 35 ms hit-stop at Normal. A splash keeps its heavy thud with no stop.
- **UX-D3 helpers.** `HingeTuckSource.flatDuration(at:)`, `timeSinceFlat(at:)` and `inFlatBlurGuard(at:)` (2.2 s).
  They use the last reading plus a timer, with 175°/173° hysteresis.

## Files
Input: TouchTuckSource (rewritten, plus `TouchTuckRamp` and `CombinedTuckSource`), HingeTuckSource (flat timers).
Feedback: FeelHaptics (`HapticProfile`, Strong, the profile-aware prebuilt Perfect), FeelSoundBook (8 state recipes),
FeedbackDirector (`FeelCue`, the profile, the milestone and chain rules). Tests: InputTests 21, FeedbackTests 24. NEEDS.md.

## Deviations and decisions
- **Strong Perfect vs. the hit-stop.** UX's "2 × 60 ms, 80 ms apart" puts the second burst after the 35 ms hit-stop
  has ended. I followed UX (it wins on flow); Normal keeps the taps on the hit-stop. Q2 on the device decides.
- **Chain-break threshold 2 → 3** to match the HUD pill. R2's test was updated.
- **Touch curve smoothstep → ease-out** (ART §5: "rewards snap"). R1's ramp tests were rewritten for the new curve.
- **Declined: thermal / Low Power scaling for audio and haptics.** The synth costs a few % of one core, and haptic
  sends are already ≤ 30 Hz. UX-D4 only asks for frame-rate and particle cuts.
- **Declined: a continuous Home wind that follows the title tuck.** It would keep the audio engine awake on Home
  (battery); the one-shot swell on the first fold is what UX asked for.
- **Not mine: the restart timing.** With a 1.5 s countdown, Core ticks at 0 and 0.5 s. I flagged it in NEEDS.md for
  the App and Core.

**NEEDS (App, in NEEDS.md):** `deviceHasFold`; persist only an explicit haptic choice; the `cue(...)` calls;
`setTucked(false, at:)` on run end or pause; `CombinedTuckSource` under VoiceOver; the flat helpers; `hinge.tuck(at:)`
per frame for the title bird.

## Tune on a real Duo
1. Q2: Normal vs. Strong on the Duo (the burst length 55 ms and sharpness 0.4, the Perfect spacing 80 ms vs. 35 ms).
2. iPhone: attack 0.12 vs. 0.09 with the ease-out curve. Does the touch-down click (0.42/0.78) feel like a fold or
   like a button?
3. Are the state cues audible over a noisy room yet still calm (the closing and reopened breaths ~0.05–0.07)?
4. Title bird driven by `tuck(at:)` on Home: no jitter at rest, and does the first fold's swell land with the sweep?
