# App R6: Flight School, Bird side, the route and the objective (27 Oct 2026)

## Built
- **D2 Flight School** (`App/FlightSchool.swift`, `UI/FlightSchoolView.swift`, `UI/DuoDiagram.swift`).
  - A pure state machine runs steps 0–7. A prompt must be up for 1.2 s before a step can pass, the praise shows for
    1.2 s, and three misses move the player on.
  - The touch variant (iPhone, Play with touch, tapping, or the step-0 escape) has no Wing check, so it has 7 dots.
  - The Studio steps show the title bird and the live DuoDiagram on the sharp page.
  - The Sea steps fly Core's `FlightSession.practice`:
    - the time scale comes from the school (0.8, 0.5 on the step-4 up-face, 1.0 in the storm);
    - `practiceSignals` judge steps 3–6;
    - a miss rewinds to Core's checkpoint (step 5: `nextGuidedSwell`);
    - step 7 sets `practiceStormGap` and `rollInStorm()`;
    - Scene shows the guides, `practiceSea` and `slowMoBloom`;
    - the App draws SC3 (`SchoolBirdHUD`): the Faster! capsule and the rhythm bar, one per λ 2000 wave;
    - at step 7 the meter and the goal chip fade in at +1.6 s;
    - Feel plays the step, rewind and storm cues and the practice ambience.
  - Persistence is `ProgressData.flightSchool`. The school starts on the first Fly ever. Skip gives a full 3-2-1; the
    school's end gives the 1.5 s Ready · Go. Settings › Flight School replays it.
  - Pausing in the school shows "Flight School paused / Open your wings to carry on." (also on the cover).
- **D1 Bird side.**
  - Settings › Bird side: Sharp side / Left / Right on a Duo, Left / Right on an iPhone. R3–R5 `mirrored` migrates to
    Right.
  - The sharp half is Feel's `SharpHalf`. The default is screen-right in whatever orientation the app first runs in on
    a Duo (stored then). A 180° turn swaps the bird's screen side and pauses a live run.
  - The Wing check runs in the school (step 2), from Settings (Check again) and from the existing-player Home card.
    The flat tip appears on the 3rd flat opening (Feel's counter), once per session.
- **D3 the objective.**
  - The HUD goal chip; the lighthouse-reached card with its 60 ms hit-stop; the goal near cue.
  - The Route page and its strip; Home "Next: Saltlight · 9 km · best 6.42 km"; the 3 tiles.
  - Results lead with the 56 pt mini route and "Reached Kestrel Head!" / "Caught 0.8 km short of Saltlight", plus
    "New on your route". The "Next time" tip has a "Route ›" link. Cover and Pause both show "Gull Point in 1.9 km".
- **Scene art.** `RouteArt` draws the Route strip; `DuoDiagramArt` draws the diagram and gauge. `BirdArt.youGlyph`
  (`YouGlyph`) is the "you" mark. The reached card dodges `lampCanvasPoint`.
- **D4.**
  - Rank-up copy is "3 goals done! New bird: Tern" + "Rank 2 · Puddle Hopper"; "New in the logbook" is cut.
  - Goals: REWARDS, the "Finish 3 goals…" line and "See your route ›". Birds: "Rank N goals".
  - The meter's "Storm" / "You" / "Too close" labels show for the first 3 runs. The first chain reads "×2 in a row".
    The first Tailwind gets a teach line.
  - The first Daily row gets a sub-line; the first results say "Every lighthouse you reach goes on your Route.".
  - Home shows a "Leaderboards" label on the Duo; "Keep a little bend" is cut; "Star goals" replaces "Star flock".
- **CI.** `ci/scenarios.txt` has r6-* (34 frames); `ci/duo-scenarios.txt` has 46–90. They cover every row of the
  UX §7 table except "skip → countdown" (there's no demo key for it; the `school=` frames show the Skip link).
- **Tests.** AppTests `RoundSixTests` (13 tests) plus `RoundSixSceneWiringTests` cover:
  - bird side and migration;
  - every school step, using Core signals, misses and fallbacks;
  - variants, copy, the Wing check, persistence and route migration;
  - RouteRules, the strip and diagram geometry, the Results plan and next tip;
  - the SchoolLayout fold check, the scene guides and the demo keys.
  - The R5 expectations for flySubtitle, rank-up, small lines, locked label and deck summary were updated.

## Decisions
- `FlatOpenCounter` (App) is removed in favour of Feel's `flatOpenings`.
- Results drop content in this order when space runs out: Daily row, route note, tip, stats, headline sub, mini
  route, and the headline last.
- The demo key `sharp=a|b` also marks the Wing check as done, so Settings shows the checked footnote.

## Not done / to check on a real Duo
- The Daily card's first-open sub-line (D4 table) is not done.
- Does the bird start on the sharp half the founder's way up? Read the `SWOOP-T birdside … physical= o=` line.
- Whether the school's practice sea reporting `mode == .attract` changes any Scene camera behaviour mid-school.
