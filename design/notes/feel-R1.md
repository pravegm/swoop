# Feel R1: input, sound, haptics (26 Oct 2026)

## Built
- **Hinge → tuck.** Brim's real-Duo stack, then tuck = smoothstep((open − θ)/36°). The stack: `HingePredictor` at
  display rate, then One-Euro (2.0 / 0.12 / 1.5), then `HoldStabiliser`. The stabiliser passes through while moving
  (≥ 20°/s). While held, its rest cutoff is 0.6 Hz near open and 1.6 Hz deep in a dive. A 90°/s squeeze lags about 1°
  (tested). Flat (≥ 175°) reads as open.
- **Calibration.** `openAngle` is an EMA with τ 4 s, fading out between tuck 0.08 and 0.15, inside 140…178°, clamped
  to 150…172°, starting at 160°. There is also a slow settle path (τ 12 s): it runs only after 2.5 s held dead still,
  with the tuck under 0.4. Without it, a player resting at 150° would be stuck with a tuck of 0.19 forever. A held dive
  (tested at 130°, with tremor and dead still) never moves it.
- **Closing.** A latch on the predictor's tracked angle: closed below 95°, open again above 102°. It updates on every
  report, so it also works while the run is paused and nothing asks for the tuck.
- **Touch.** A linear progress at 0.12 s up and 0.10 s down, passed through a smoothstep. It is computed from the
  event times, and a re-press mid-release carries on from where it was. **Autopilot** wraps `FlightPilot`.
- **Synth** (`FeelSynth`, Brim's lock-free SPSC design): continuous wind (low-pass + resonant whistle, gusts), skim
  hiss + spray, rain + drops, storm rumble, tailwind pad; one-shot noise/tone/ring/drop voices; DC block → limiter → tanh.
- **Sounds** (`FeelSoundBook`, pure): launch whump; Perfect chime on D5 pentatonic (step per chain, +1 octave every 5,
  max +2); water touch; heavy splash; Tailwind D-major swell; thunder; caught rain swell + A-major pad (~5 s,
  self-contained); lighthouse bell x2; km sparkle; new best; marimba countdown; UI clicks; celebrate.
- **Haptics** (`FeelHaptics`): two looping players (rumble: intensity = speed, sharpness = tuck; skim: fine sharp
  texture) + every §7 moment; reset/stopped recovery; `UIImpactFeedbackGenerator` fallback (≤ 3 taps).
- **Director:** `.playback` + `.mixWithOthers` (plays on silent), `.ambient` when respecting the switch; heals after
  interruptions, route/config changes, media resets. `start()` idempotent; `handle` = one bed (≤ 60 Hz) + haptic
  params (≤ 30 Hz). Engines idle after 3 s without flight (audio naps 6 s after the last sound).

## Files
`Swoop/Input/`: FeelFilters (One-Euro, HoldStabiliser, FeelSpring, HingePredictor, FeelClosingLatch, FeelDemoLog),
HingeReader (+FeelHingeLog), HingeTuckSource (+HingeTuckTuning), TouchTuckSource, AutopilotTuckSource.
`Swoop/Feedback/`: FeelSynth, FeelSoundBook (+FeelDice), FeelAudioEngine, FeelHaptics, FeedbackDirector.
`SwoopTests/InputTests.swift` (13 tests), `SwoopTests/FeedbackTests.swift` (15 tests).

## Deviations / notes for the App engineer
- The director doesn't persist the toggles (`SettingsStore` pushes them); no engine starts while a toggle is off.
- Call `handle` every frame of the play screen, including the countdown and caught. `playing: false` fades the
  layers. `caught` slows the fade to 1.4 s so the wind dissolves into the rain. Call `silence()` on pause and menus.
- `TouchTuckSource.began(at:)`/`ended(at:)` want `CACurrentMediaTime()`, the same clock as the frames.
- Extras beyond the API (optional): `HingeTuckSource.reset()` (after backgrounding), `lastTuck`,
  `TouchTuckSource.cancelled(at:)`, `FeedbackDirector.idling`.
- `SWOOP-T tuck` prints whenever the hinge source is asked (≤ 4/s), so also on the title screen if the UI asks.
- NEEDS: none.

## Tune on a real Duo (in this order)
1. **Squeeze feel.** Stroke 36° (`HingeTuckTuning.stroke`), then the stabiliser cutoffs (0.6/1.6 Hz) and spans
   (10°/22°). If the wings feel "sticky" just off open, raise `nearOpenRestCutoff`. If they flutter, lower it.
2. **Calibration.** Watch `SWOOP-T calib open=` in the console: does it land on the player's real rest? If the
   settle path ever eats a long dive, raise `settleDelay`.
3. **Mix on the speaker**, not headphones. The wind gains (0.06 → 0.30) and the whistle (0.26) set the bed; check
   that 3 minutes isn't fatiguing. The skim (0.03 → 0.12) should be clearly audible over the wind. The splash
   (0.34) and thunder (0.30) are the loudest things. Phone speakers drop below ~200 Hz, so the thuds and rumble may
   need more 200–400 Hz content.
4. **Chime pitch:** D5 base, +2 octaves max. If the top octave is too piercing, lower `chimeMaxOctave` to 1.
5. **Haptics.** Rumble 0.06 → 0.5 (the founder found the Taptic engine weak on Duo; maybe raise it); skim 0.1 →
   0.35; splash, launch and Perfect strength.
6. `speedUnit` range (260 → 2200 pt/s): once Core's real speeds are known, make sure top speed maps near 1.
