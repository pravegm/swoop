# Swoop: Accessibility Nutrition Labels (v1.0)

*Decided Mon 26 Oct 2026; **updated Tue 27 Oct for the Round 6–9 build** (Flight School, the bird side, the "Wings by: Tapping" control, the route HUD, the glossary of `design/UX-ROUND-9.md`). The rule, the same as Squish and Brim: **claim a label only when the build earns it across every common task**, and verify on the release build first. Labels are voluntary, per device, and can only be published once a version is live, so this happens on **the day Swoop goes live** (on approval; runbook step 7, "Launch day"). The App Store Connect tool doesn't set labels: the founder ticks them by hand.*

Common tasks for Swoop:
1. the first launch: get through **Flight School** (or skip it), including the one-tap clear-side check on a Duo (a side, or "Not sure");
2. start a flight or the Daily Flight from Home;
3. fly (fold / open on a Duo; hold / let go, or tap, elsewhere) and read the HUD: distance, the storm meter, the "×3 in a row" chip, the NEXT lighthouse chip;
4. read the result card (route strip, "You made it past…", distance) and share the Daily result;
5. open Route, Goals and Birds, and pick a bird or sky;
6. change Settings (Bird side, Play with touch, Wings by, Sound, Haptics, Respect silent switch, Flight School replay).

## What the build has today (27 Oct, from the code)

- **Three ways to give the input:** the hinge (Duo); press and hold (any iPhone, and on a Duo via Settings → "Play with touch"); and **Settings → "Wings by: Tapping"**, where one tap folds the wings and the next opens them ("Made for Switch Control and VoiceOver", `UI/SettingsView.swift`). Tapping removes the need to hold a press, which helps motor access.
- **Flight School is spoken:** each step keeps its full sentence as a VoiceOver announcement, and the step number is VoiceOver-only ("Flight School, step 3 of 6", `App/FlightSchool.swift`).
- **Reduce Motion:** Swoop follows the iOS setting (Settings shows it as an info row: "no camera shake or screen bloom when on").
- **Sound and haptics:** Sound on/off, Haptics Off · Normal · Strong, and "Respect silent switch".
- **Bird side** (Sharp side (auto) · Left · Right on a Duo; Left · Right elsewhere) lets a player put the bird where they can see it best.
- **Words in the world:** Perfect is shown as a word on the water, lighthouse passes as "Gull Point!", the end as "The storm caught you" (and "Flight over" on the Results card), and the goal as text ("NEXT · Gull Point · 1.2 km").

## The answer, at a glance

| Label | 1.0 answer | Status | Why |
|---|---|---|---|
| VoiceOver | **No** | Decided | Menus are labelled, Flight School is spoken and tapping mode works with VoiceOver, but flying (task 3) depends on seeing the shape of the waves ahead. Apple's bar is all common tasks |
| Voice Control | **No** | Decided | Flying needs timing on every wave; there's no spoken alternative. (Tapping mode serves Switch Control, which has no label of its own) |
| Larger Text | **No** | Decided | Swoop 1.0 has no Dynamic Type support (founder's decision, `design/qa/FINAL-FIXES.md`): text doesn't follow the iOS text size. Never tick it |
| Dark Interface | **No** (unless check D passes) | **Verify** | The system style is forced dark and the menus sit on navy surfaces, but the default play screen is a bright Golden Hour sky |
| Differentiate Without Color Alone | **Yes**, if check A passes | **Verify** | Perfect, Tailwind, lighthouses and the goal are words; the storm meter is a position on a bar; done goals have a ✓; Route uses ✓ and solid vs dashed line |
| Sufficient Contrast | **Yes**, if check B passes | **Verify** | HUD text and in-world words sit over a changing sky and sea; they need the soft navy glow or a backing plate everywhere |
| Reduced Motion | **Yes**, if check C passes | **Verify** | Follows iOS Reduce Motion: no camera shake or screen bloom; Flight School's rewind becomes a 0.3 s crossfade (`UX-ROUND-9` §1.1) |
| Captions | **No** (not applicable) | Decided | No dialogue, video or audio-only content |
| Audio Descriptions | **No** (not applicable) | Decided | No time-based video content |

**Publish for iPhone: Reduced Motion, Sufficient Contrast, Differentiate Without Color Alone**, each only if its check below passes on the release build. Leave every other box unticked. If a check fails, leave that box unticked: an honest "not indicated" beats a false claim.

## Checks (on the release build, on a Duo and on a non-Duo iPhone)

### A. Differentiate Without Color Alone
- [ ] Every landing that matters shows its **word**: "Perfect" in the world (and the "×3 in a row" chip from 2). A splash is shown by the splash itself and the bird slowing; if testers miss it in grayscale, add a word. The chime and the white ring are extras, not the only cue.
- [ ] **Tailwind** shows its word ("Tailwind!") the first time and a visible effect after, not only the golden trail.
- [ ] The **storm meter** reads by position (the storm icon at the outer end, "Storm" / "You" labels on the first 3 flights), not only by colour. The storm-close warning has a shape or word too (for example rain streaks, or "Storm 300 m behind"), not only a colour change.
- [ ] The **NEXT** chip, "Gull Point!", "New lighthouse" and the Results headline are words; the Route shows ✓ for passed lighthouses and solid vs dashed for done vs to come.
- [ ] Locked birds, skies and trails show a **lock glyph** and their level, not just greyed colour. Done goals show a ✓ circle.
- [ ] Selected options in Settings and Birds have a check mark, toggle position or outline, not only a tint. Flight School's progress dots differ by fill, not only by colour; the clear-side check's two halves are labelled by position.
- [ ] Run through tasks 1–6 with **Settings > Accessibility > Display & Text Size > Color Filters > Grayscale** on.

### B. Sufficient Contrast
Apple's bar: about 4.5:1 for text, 3:1 for large text, controls and state indicators.
- [ ] HUD text (distance, NEXT chip, "Best in…", "×3 in a row") and the in-world words (Flight School's ≤ 3-word cues on their soft navy glow, "Perfect", "Gull Point!", "The storm caught you") keep ≥ 4.5:1 (3:1 for the large ones) against **every** sky (Golden Hour, Rose Dusk, Northern Lights, Monsoon, Moonrise), the practice sky and under the storm. Plain white on a golden sky won't pass.
- [ ] Menu, Route and result-card text ≥ 4.5:1 on its panel; the quiet "mist" lines included.
- [ ] The storm meter, the pause button and Flight School's Skip reach 3:1 against what's behind them.
- [ ] Check with Increase Contrast and Bold Text on.

Measure with a contrast checker on the release-build frames (the CI frame sets) and paste the ratios here (Brim's table format).

### C. Reduced Motion
- [ ] With **Settings > Accessibility > Motion > Reduce Motion** on: no camera shake (splash bump, take-off shake), no screen bloom or sun flare pulse, no lightning flashes (a dim flicker at most).
- [ ] Flight School's rewind is a 0.3 s crossfade, not the sea running backwards; the title-bird morph and the storm roll-in are fades or short moves.
- [ ] Menu transitions become fades or short moves, not springs and slides.
- [ ] The bird, the sea, the scrolling, the guide gull's demonstration and the camera zoom still move: that motion is the game itself, which Apple's criteria allow.

### D. Dark Interface (only if we want to claim it)
- [ ] Home, Route, Goals, Birds, Settings and the result card are dark panels, and the play screen with the default sky is acceptable as dark. With Golden Hour as the default play sky, leave this unticked.

## What we can say in copy today

The description says: "Swoop follows Reduce Motion: no camera shake or screen bloom", "Sound switches off, and haptics can be Off, Normal or Strong", and "Rather tap than hold? One tap folds the wings, the next opens them". The press kit adds that Flight School is spoken with VoiceOver. None of this claims a VoiceOver or Larger Text label. If check C fails, cut the Reduce Motion sentence too.

## 1.0.1 list to earn more labels honestly

| Fix | Size | Earns |
|---|---|---|
| Spoken cues for the wave ahead ("the way down", "the top") and sound-only timing cues, played with tapping mode | M | VoiceOver (maybe), and helps low-vision players |
| Named custom actions "Fold" / "Open" on the play area | S | Voice Control (with the above) |
| HUD, in-world words, result card and menus scale to AX3 with reflow | M | Larger Text |

Re-check the labels with every update; add one only after the fix is on device and tested.

## Sources
- App Store Connect Help, *Overview of Accessibility Nutrition Labels*: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- App Store Connect Help, *Manage Accessibility Nutrition Labels* (publish only for devices with a live version): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
- Brim's label decisions (method mirrored): `C:\Users\59527\Fold\docs\appstore\accessibility.md`
