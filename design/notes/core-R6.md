# Core — Round 6 notes (Flight School practice, fixed lighthouse names)

## Built
- **K1 practice: `FlightSession.practice(bird:)`, as a session option rather than a new RunMode case.**
  - **Why:** a new `RunMode` or `FlightEvent` case would break the exhaustive switches in the App (GameCenterManager,
    GameController, ResultsView), Feel (FeedbackDirector) and Scene (FlightScene). Instead, the session reports
    `mode == .attract`, so it never finishes and nothing records it (bests, goals, route, Game Center). The App checks
    `isPractice`.
  - **Sea:** `SeaProfile(seed:practice:)` builds the scripted sea, `Tuning.practiceKnots`: crest A → a 1,500 pt
    downslope (slope 0.31) → trough → an 800 pt up-face → crest B → the guided 2,000 pt downslope → 3 rhythm waves of
    λ 700 → then even swells (A 300, λ 4000) forever. Seeded sets are never generated. The max |slope| is 0.58.
  - **Run:** no storm (`practiceStormGap` can show one, held behind and never catching, for step 7); 0.8×
    `timeScale`, settable; no lighthouse, milestone, best, storm-close or caught events; a 12° landing assist.
  - **Calls:** `holdAtCrest(untilTuck:)` (armed at 0.6 on start), `rewind(to: PracticeCheckpoint)` and
    `nextGuidedSwell()`.
  - **Signals:** `practiceSignals` after each step: `diveDone(heldFraction:)`, `launched(tuck:)`, `landed(quality)`
    and `waveDone(index:)`.
  - **Validated in Node:** holding the dive to 60 %, 70 %, 85 %, 100 % or 120 % of the downslope, then opening, always
    launches off crest B and lands Perfect on the guided downslope. That holds even with the normal 7° assist.
- **K2 lighthouse names fixed by index.** `Lighthouses.name(index:)` = `names[index % 40]`: Gull Point, Saltlight,
  Kestrel Head, Old Harry… `name(index:seed:)` ignores its seed, and every mode uses the fixed names.
- **K3 route helpers.** `Lighthouses.count(atOrBefore:)`, `count(atOrBeforeMeters:)`, `nextIndex(afterMeters:)` and
  `meters(index:)`.
- **"Next time" tips:** the inputs are already in `RunResult` (perfects, splashes, bestChain), so no Core change.
- **Tests:**
  - fixed names (and in a Daily);
  - the route counts;
  - practice is calm: 0.8× time, the crest hold, no storm, gentle slopes, no recording events;
  - the full script gives diveDone ≥ 0.7, launch at u ≤ 0.3, a Perfect, then waves 0/1/2;
  - an early opening gives held < 0.7;
  - rewind, nextGuidedSwell (it lands Perfect) and the storm roll-in gap;
  - the calls are no-ops in normal runs.

## Notes and decisions
- **Rhythm waves (Round 6b, decided):** λ 700 waves were flown over at the ~1,700 pt/s the bird brings, so they are
  now λ 2,000 and 150 pt high (troughs at 6300, 8300 and 10300). I searched λ 1,400–2,800 in Node; at λ 1,400 and
  1,700 the bird still overshoots onto the next up-face.
  - A player who opens up the face and folds on the way down gets exactly one launch and one Perfect per wave, on
    that wave's own downslope. That's about 1.4 s per wave at 0.8×, which makes for a clear rhythm bar.
  - Holding the wings open in the air overshoots, which is the lesson. `waveDone` still triggers on x.
- **The Node sim doesn't model practice.** It has no effect on balance. Normal play is unchanged; `timeScale` is
  exactly 1 there.
- **Balance targets:** unchanged from R4b.
