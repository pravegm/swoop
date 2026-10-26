# Feel R6: the sharp half, the flat tip, Flight School's sound (27 Oct 2026)

## Built
- **F5, the sharp-half helper (D1, UX §2.1).** New file `Swoop/Input/SharpHalf.swift`. All of it is pure and tested.
  - The types: `FeelScreenSide` (left/right), `FeelPhysicalHalf` (a/b), and `FeelLandscape` (left/right).
    `FeelLandscape.from(UIInterfaceOrientation)` reads landscape orientations; portrait gives nil.
  - `SharpHalf(physical:, reference:)` is Codable, for SettingsStore.
  - **Default (the ROUND-6 correction):** `SharpHalf.firstRun(in: o)` takes the half on screen-RIGHT in whatever
    orientation the app first runs in on a Duo, and keeps that orientation as the reference. Nothing is hard-coded to
    `landscapeRight`.
  - `screenSide(in:)` maps it for the current orientation, so after a 180° turn the bird swaps screen sides and stays
    on the same physical half (tested both ways round).
  - `recording(sharpSide:in:)` stores the Wing check answer. The same physical answer given either way up is equal
    (tested). `logLine(in:)` is the `SWOOP-T birdside` line.
- **F3, the flat-open counter.** `HingeTuckSource.flatOpenings` counts raw openings to ≥ 174°, re-arming under 166°.
  `resetFlatOpenings()` starts it per run; a run that starts already flat doesn't count until the hinge comes back
  under 166°. Tested: a wobble around 174° counts once, 173° never counts, and three openings make 3.
- **F1:** `isStill(at:window:)` for step 0's 0.5 s stillness. **F2** already holds: u = 0 at θ ≥ θ_open, so opening
  flat gains nothing (tested since R1).
- **F4, cues matching ART §5 (rewards snap, the UI settles):**
  - `cue(.schoolStep(n))`: a soft chime that climbs the pentatonic one step per lesson (D5 → F♯6, ≤ 0.1) and a light
    praise double-tap.
  - `.schoolRewind`: a breath that falls and rises across the 0.4 s fade, with a soft sag.
  - `.schoolStorm`: the thunder at half level, with a low roll, for step 7's first storm.
  - `.goalNear`: a two-note glint at 300 m.
  - **Lighthouse reached (D3):** the `lighthouse` event now plays the bell plus a warm D-major swell, with a glass
    glint and a keen second tap on the release of a 60 ms hit-stop; a firm tap starts it.
- **Practice sea ambience (D2).** `FeedbackDirector.practiceAmbience` switches to `FeelSoundBook.practiceBed`:
  - wind × 0.6, whistle × 0.5, gusts × 0.6;
  - no rain, rumble or drops, whatever the telemetry says;
  - and `stormClose` thunder is suppressed.

## Files
Input: `SharpHalf.swift` (new), `HingeTuckSource.swift` (flat counter, windowed `isStill`). Feedback: FeelSoundBook,
FeelHaptics, FeedbackDirector. Tests: InputTests 35 (+5, and it imports UIKit), FeedbackTests 31 (+4). NEEDS.md
("Feel → App (Round 6)").

## Decisions
- The sharp half is stored as physical + reference orientation (`SharpHalf`), not UX's bare `sharpPhysical` with `.a`
  fixed to landscapeRight. This follows the ROUND-6 correction. The App maps the Settings copy through
  `screenSide(in:)`.
- The flat counter reads raw reports (the same "last reading" rule as the flat timers), not the filtered angle, so a
  quick touch of flat is counted.
- The lighthouse event always plays the "reached" cue (every lighthouse is the run's goal). "New on your route" is the
  App's text; it has no extra sound.

## NEEDS (App)
- `SharpHalf` in SettingsData, with `firstRun(in:)` on a Duo's first run;
- `resetFlatOpenings()` and `flatOpenings`;
- `isStill(at:window: 0.5)`;
- the `cue(...)` calls;
- the 60 ms lighthouse hit-stop;
- `practiceAmbience` on and off.

## Tune on a real Duo
- Does the bird land on the sharp half the founder's way up, and after a 180° turn? Check the readout's `birdside` line.
- Is the step chime too sweet for an adult? Is the 0.6 calm wind still a sense of speed in step 3?
- Does the lighthouse-reached moment feel bigger than a Perfect milestone, without being louder?
