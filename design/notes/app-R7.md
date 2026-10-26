# App R7: clarity polish from the fresh testers (27 Oct 2026)

## P0
- **1. Wing check out of the school and off Home.**
  - Flight School is 7 steps on every device (`asksWingCheck: false`); the dots and "step N of 7" now match.
  - `showsWingCheckCard` is always false.
  - The check lives in Settings › Bird side: "Check my Duo" / "Check again", plus a "Why?" button. It opens
    `BirdSideWhy`, a small diagram with the soft half shaded and three plain lines.
  - The default stays as before: screen-right in the first-run orientation, tracked physically.
- **2. Perfect taught.**
  - Step 5's prompt is now "Now land on the downslope ahead, in the ring." On success the big gold word PERFECT
    lands, then "Land on a downslope = Perfect. Perfects push the storm back.", held for 3 s.
  - The meter's "Too close" shows on the first 3 runs, and only while the knob is inside the danger zone
    (`LeadMeter.showsTooClose`).
- **3. Numbers.**
  - "First flight" needs no previous best and `runs <= 1`.
  - Goal captions never say "159 of 25": a met target says "Done this flight", and a ticked row says "Done in an
    earlier flight".
  - Demo results now carry the first-run framing (`firstRealRun`, the fun fact).
  - The new key `session=first:home|school|run|results|home2|route|goals` seeds ONE fresh install. Run 1 is the same
    headless casual flight (seed 7) in every later frame. CI has 19 frames, `s1-01` to `s1-19`, in walk order, in
    both scenario files.
  - The best always updated in real play. The testers' "6.42 km" came from mixed demo presets, which
    `session=first` replaces.
- **4. Layout.**
  - **Home tiles:**
    - `HomeView.tilePlan` picks one of three layouts: icon + word + detail, icon + word, or icon stacked over the
      word, from the tile's width.
    - The word never truncates.
    - "New" is a fixed-size corner badge, so it no longer takes the text's room.
    - A fit test covers every canvas.
  - **Step 7:**
    - The prompt's text cross-fades in place (the `.id` swap stacked the old line on the new).
    - The prompt sits under the meter and goal chip (`SchoolLayout.stormPrompt`).
    - Its CI frames use held lines (`school=storm:1|2|3`, 6 s wait). The 2 s capture was the blank portrait frame;
      it was not a Scene bug.
  - **Other overlaps:**
    - The goal chip hides under the pause card.
    - The first Tailwind's teach line replaces the "Tailwind!" callout instead of overlapping it.
    - The Results headline never cuts the lighthouse name (the "New on your route" chip goes first).
    - The phone Route summary keeps two lines: reached and Next.

## P1
- **5. Rank-up copy.** "You ranked up twice!", then "New bird: Tern · New trail: Coral", then "Rank 3 · Spray
  Chaser" under it. The rank title is never shown alone. All of these strings are in the App (ResultsView /
  ProgressStore); no Core change was needed.
- **6. The goal sentence early.** The objective is now "Outfly the storm. Reach the next lighthouse.". It is the
  Fly subtitle until the first lighthouse is reached, and the bird-page line during the first real run's countdown,
  after the school or a skip.
- **7. Touch copy.** "Press and hold anywhere" on Home and in the school. No "tap" and no "no tapping" in the touch
  variant (the tapping setting keeps its own copy; its CI frame is renamed `a11y-school-tap`). Step 0 on an iPhone
  says "Hold your iPhone sideways, in both hands."
- **8. iPhone welcome.** There is no Duo line on the first screen. After an iPhone's first results a one-time
  small line appears: "Fun fact: on iPhone Duo, you fold the phone to fly."
- **9. Diagram.** The Duo diagram's drawing is 240 × 170 with the gauge under it (it was squeezed to ~134 tall).
  The iPhone drawing is a phone on its side with its camera island, the bird and a fingertip on the screen. The old
  finger under the phone read as "a TV on a stand".
- **Small extras.**
  - The HUD overline "Your goal" is now "Next lighthouse" (a tester read the distance as the goal).
  - The demo key `settingsWhy` opens the explainer; Duo frame `settings-why`.
  - `school=wingcheck:<phase>` now shows the Settings check.

## Tests
- AppTests `RoundSevenTests` (8 tests): the 7 steps in order, Perfect and Too close, the goal captions, the Home
  tiles on every canvas, the reward copy, the early goal sentence and the fun fact, the session demo key, and the
  storm holds.
- Updated: the touch caption, the Fly subtitle, the objective, the rank-up and unlock lines, the deck summary, and
  the 7-step overline.

## Not done
- The "New goals" line after a cascade can list a goal the player's bests already meet.
- "Keep flying here" (cover) and "or fold and open" (Results helper) still puzzled one tester.
- The Daily card's first-open sub-line (from R6).
