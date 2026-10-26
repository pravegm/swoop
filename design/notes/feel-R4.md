# Feel R4: hinge comfort, scarce Perfects, a real splash (26 Oct 2026)

## Built
- **P0-6, hinge comfort (REVIEW-3-duo P1-1, P1-2, P1-5).**
  - **Calibration floor:** `openMin` 145 → 132, and `calibrationLow` 140 → 125 (both the ready snap and the slow
    learning). A snap from 125–132° clamps to 132. A rest at 134° now flies with spread wings (tested).
  - **Stroke:** `HingeTuckTuning.stroke(forOpen:)` = clamp(open − 100, 30, 36), so full tuck sits at ≥ 100°, never
    inside the closing zone. Open 132 gives full tuck at 100° and half at 116° (tested).
  - **Closing gate:** `FeelClosingGate` replaces the 95°/102° latch. It closes after 0.2 s under 90° on the One-Euro
    angle, or at once under 75°, and reopens above 98°.
    - While frames run it reads the smoothed angle; while paused (no frames) it reads the tracked reports.
    - `closing(at:)` lets the dwell mature with time alone.
    - Tested: a brief overshoot to 85° doesn't pause, a held 85° does, and a slam under 75° pauses at once.
  - **End-stop detent:** `consumeEndStop()` fires once per stroke when the tuck first reaches full, and re-arms below
    0.8. A stop older than 0.1 s is dropped. `cue(.endStop)` plays a 25 ms buzz at 0.35 and a tiny dry wood tick.
  - **Wear (P1-5):** the tuck rises 0 → 1 no faster than 0.15 s, so a slam gains nothing. Opening is not limited, and
    a deliberate 90–150°/s squeeze is untouched (smoothstep's peak slope stays under the limit).
  - `restIsBelowFloor(at:)` is the countdown's "Open a little wider" signal (the App owns the copy and the hold).
- **P1-8, Perfects special again.**
  - `isChainMilestone`: 3, then 5, 10, 15, 20, 25…
  - **Ordinary Perfects:** a soft chime on the same rising pentatonic note (about −5 dB, 0.6 s, no whoosh-pop, no
    glint) and one light tap.
  - **Milestones:** the full chime, brighter with the chain, plus a soft bell an octave under for weight, the
    whoosh-pop, the double tap on the hit-stop, and a three-note sparkle from ×10.
  - `FeedbackDirector.isPerfectMilestone(chain:)` is for the App's callout and hit-stop. `FeelSoundBook.hitStop` is
    now 60 ms, the milestone stop UX asked for.
- **P1-9, the splash thud.** A body tone of 300 → 120 Hz with 5 harmonics, a slap, and a dull falling plop. Phone
  speakers play 180–320 Hz; they never played the old 150 → 55 Hz tone. The haptic is heavier and longer (0.26 s with a
  sag), matching the scene's 80 ms slow-down.
- **REVIEW-3-duo P2-14:** the touch-down click plays on Duo deck and cover runs too (the App calls it only in touch).

## Files
Input: FeelFilters (`FeelClosingGate` replaces `FeelClosingLatch`), HingeTuckSource (floor, stroke, gate, rise
limit, end-stop, `restIsBelowFloor`). Feedback: FeelSoundBook, FeelHaptics, FeedbackDirector. Tests: InputTests 26,
FeedbackTests 27. NEEDS.md ("Feel → App (Round 4)").

## Tests changed
- The 95°/102° latch tests became gate tests (90/98, dwell, instant). The closing test now closes to 80°.
- `readyPoseSnapsTheOpenAngle`: the fold goes to 115°, because 125° is now learnable; the low snap is at 128 → 132.
- The R2 Perfect tests use milestones (chain 5 for the whoosh-pop; brightness vs gain compared between ×3 and ×15).
  `hitStop` is 0.06.
- The touch-down gate test was removed (no gate now).

## Deviations and decisions
- **Hit-stop 35 → 60 ms** for milestones (REVIEW-3-ux P1-2). The App must use `FeelSoundBook.hitStop`, or tell me.
- **The pentatonic doesn't reset each octave** (REVIEW-3-ux's suggestion). It still climbs two octaves, then cycles
  the top one. The soft level of ordinary chimes already stops the top notes from getting shrill.
- **"The wind note caps" at full tuck** needs no change: the wind cutoff and whistle already saturate at u = 1. The
  end-stop tick is the new cue.
- **No slow-path learning from a 160° start to a 136° rest** (the tuck there is 0.74, too deep to tell from a held
  dive). The countdown snap covers it, every run.

**NEEDS (App):** `hinge.closing(at: now)` in `checkClosing`; `consumeEndStop()` → `cue(.endStop)`; nudge on
`restIsBelowFloor`; callout, hit-stop and VoiceOver through `isPerfectMilestone`; the hit-stop = `FeelSoundBook.hitStop`.

## Tune on a real Duo (Appendix A)
- A4/A9: is 132° the right floor for the natural hold?
- A11: does 0.2 s at 90° stop mid-dive pauses?
- Does the end-stop tick read as "that's enough" under the rumble? Is the soft chime audible over the wind at speed?
- Does the splash thud now land on the speaker?
