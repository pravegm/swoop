# Swoop: Accessibility Nutrition Labels (v1.0)

*Decided Mon 26 Oct 2026 from the design and the expected build. The rule, the same as Squish and Brim: **claim a label only when the build earns it across every common task**, and verify on the release build first. Labels are voluntary, per device, and can only be published once a version is live, so this happens on **launch day, Tue 24 Nov** (runbook §7).*

Common tasks for Swoop:
1. start a Flight or the Daily Flight from Home;
2. fly a run (hinge on Duo, press-and-hold elsewhere) and read the HUD (distance, lead meter, chain);
3. read the result card and share the Daily result;
4. open Flocks and Birds, pick a bird or sky;
5. change Settings (sound, haptics, silent switch, touch, mirror, reduce motion).

## The answer, at a glance

| Label | 1.0 answer | Status | Why |
|---|---|---|---|
| VoiceOver | **No** | Decided | Menus will be labelled, and the bible plans a VoiceOver-adjustable "wing" control, but flying (task 2) depends on seeing the shape of the waves ahead. Apple's bar is all common tasks |
| Voice Control | **No** | Decided | Flying needs the hinge or a press-and-hold with timing; there's no spoken alternative |
| Larger Text | **No** | Decided | Menus may scale, but the in-flight HUD and the result card aren't designed to reach 200% |
| Dark Interface | **No** (unless check D passes) | **Verify** | The system style is forced dark (`UIUserInterfaceStyle: Dark`), but the play screen is a bright golden-hour sky. Claim it only if every common task's screens read as dark |
| Differentiate Without Color Alone | **Yes**, if check A passes | **Verify** | Needs every touchdown to show a **word** (PERFECT / SPLASH), not only a white ring or gold trail; the lead meter is a bar length, not just grey vs gold |
| Sufficient Contrast | **Yes**, if check B passes | **Verify** | HUD text sits over a changing sky and sea; it needs an outline or a backing plate |
| Reduced Motion | **Yes**, if check C passes | **Verify** | Bible §3: with Reduce Motion on, camera shake and screen bloom are off |
| Captions | **No** (not applicable) | Decided | No dialogue, video or audio-only content |
| Audio Descriptions | **No** (not applicable) | Decided | No time-based video content |

**Publish for iPhone: Reduced Motion, Sufficient Contrast, Differentiate Without Color Alone**, each only if its check below passes on the release build. Leave every other box unticked. If a check fails, leave that box unticked: an honest "not indicated" beats a false claim.

## Checks (on the release build, on a Duo and on a non-Duo iPhone)

### A. Differentiate Without Color Alone
- [ ] Every touchdown that matters shows its **word**: "PERFECT" (with the chain number) and "SPLASH". A Good landing can stay quiet. The chime and the white ring are extras, not the only cue.
- [ ] **Tailwind** shows its word or an icon with a timer, not only the golden trail.
- [ ] The **lead meter** reads by length or position (how far the marker is from the storm end), not only by its grey/gold colour. The storm-close warning has a shape or word too (for example rain streaks plus the meter flashing), not only a colour change.
- [ ] The chain pip counter uses filled vs empty **shapes**.
- [ ] Locked birds and skies show a **lock glyph** and their rank, not just greyed colour.
- [ ] Selected options in Settings and Birds have a check mark, toggle position or outline, not only a tint.
- [ ] Run through tasks 1–5 with **Settings > Accessibility > Display & Text Size > Color Filters > Grayscale** on.

### B. Sufficient Contrast
Apple's bar: about 4.5:1 for text, 3:1 for large text, controls and state indicators.
- [ ] HUD text (distance, chain, lighthouse name card) keeps ≥ 4.5:1 against **every** sky (Golden Hour, Rose Dusk, Northern Lights, Monsoon, Moonrise) and under the storm. A dark outline or a translucent dark plate behind the text solves it on all of them; plain white on a golden sky won't.
- [ ] Menu and result-card text ≥ 4.5:1 on its panel.
- [ ] The lead meter and the pause button reach 3:1 against the sky behind them.
- [ ] Check with Increase Contrast and Bold Text on.

Measure the palette with a contrast checker once the Scene engineer's colours are in `SkyCatalog`, and paste the ratios here (Brim's table format).

### C. Reduced Motion
- [ ] With **Settings > Accessibility > Motion > Reduce Motion** on: no camera shake (splash bump, launch pull-out shake), no screen bloom or sun flare pulse, no lightning flashes (a dim flicker at most).
- [ ] Menu transitions become fades or short moves, not springs and slides.
- [ ] The bird, the sea, the scrolling and the camera zoom still move: that motion is the game itself, which Apple's criteria allow.

### D. Dark Interface (only if we want to claim it)
- [ ] Home, Flocks, Birds, Settings and the result card are dark panels, and the play screen with the darkest sky option is acceptable. If the golden-hour sky is the default play screen, leave this unticked.

## What we can say in copy today

The description says only: "With Reduce Motion on, camera shake and screen bloom are turned off", and that sound and haptics switch off separately. It makes no VoiceOver or Larger Text claim. If check C fails, cut that sentence too.

## 1.0.1 list to earn more labels honestly

| Fix | Size | Earns |
|---|---|---|
| The VoiceOver "wing" adjustable control, plus spoken cues for the wave ahead ("downslope", "crest") and sound-only timing cues | M | VoiceOver (maybe), and helps low-vision players |
| Named custom actions "Tuck" / "Spread" on the play area | S | Voice Control (with the above) |
| HUD, result card and menus scale to AX3 with reflow | M | Larger Text |

Re-check the labels with every update; add one only after the fix is on device and tested.

## Sources
- App Store Connect Help, *Overview of Accessibility Nutrition Labels*: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- App Store Connect Help, *Manage Accessibility Nutrition Labels* (publish only for devices with a live version): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
- Brim's label decisions (method mirrored): `C:\Users\59527\Fold\docs\appstore\accessibility.md`
