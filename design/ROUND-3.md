# Round 3: to the design standard (26 Oct 2026)

The founder said design and UX are the key to making this a huge success: "spend time on it". Their second
instruction: "optimise this in all ways for iPhone Duo, and have a fallback if it's not a Duo."

## The standard (read in full before starting; these are now the source of truth for look and flow)
- `design/ART-DIRECTION.md` is the look: palette, light, the bird, motion, UI tokens, the icon and composing for
  the fold. Its tasks are **S1–S15** (Scene) and **A1–A14** (App).
- `design/UX-SPEC.md` covers flows, layout, copy, the first 60 seconds, every Duo pose and state (§9) and the iPhone
  fallback (§10). Its tasks are **A1–A14** (App), **C1–C4** (Core), **S1–S3** (Scene), **D1–D8** (Duo) and **F1–F4**
  (Feel). To tell the two lists apart, refer to tasks as ART-S3 or UX-A5.
- `design/QA-2.md` has 9 P2s.
- **Conflicts:** ART wins on look, UX wins on flow, layout and copy. Toast placement is settled in UX's favour (Art
  accepted it). If you find another conflict, decide in the spirit of both documents and log the decision in your
  notes.

**ROUND-1 rules still apply:**
- own folders only;
- no commits;
- conservative Swift that compiles the first time;
- notes in `design/notes/<role>-R3.md`.

Cross-module requests go in `design/NEEDS.md`. Keep public APIs backward compatible.

## Who does what
- **Scene engineer** (`Swoop/Scene`, SceneTests):
  - all of ART-S1–S15 and UX-S1–S3;
  - the scene parts of UX-D1–D8: fold composition, the per-half brightness rule, the flat-pose blur guard visuals;
  - QA-2 P2-2 (sea rebuild rate; use `SeaProfile.samples(into:)`) and P2-9 (the `-swoopDemo` string in FlightScene
    goes behind `#if DEBUG`).
  - Bird art changes go in `BirdArt` (the title bird is shared with the App).
- **App engineer** (`Swoop/App`, `Swoop/UI`, `Swoop/Persistence`, AppTests, the `ci/*scenarios.txt` files):
  - all of ART-A1–A14 and UX-A1–A14;
  - the app parts of UX-D1–D8: the cover display states; the seated "split deck"; fold-and-open to fly again; the
    flat-pose countdown hold; the one-time "Made for iPhone Duo" line; the iPhone wing glyph;
  - QA-2 P2-1 (progress migration: bump the version, clamp the rank, clear goal progress), P2-3, P2-4, P2-5, P2-6,
    P2-7 (an accessible wing control, with Feel), and P2-8 (the device-clock Daily exploit: a monotonic
    "last-played" guard is enough);
  - the icon: ART concept A, in `AppIconArt`;
  - CI scenarios for every new state: the cover states, split deck, the restart flow, the first-60-seconds beats and
    the iPhone fallback line.
- **Core engineer** (`Swoop/Core`, Core/Balance tests, `tools/`):
  - UX-C1–C4;
  - any goal-ladder stretching that UX asks for (re-run balance-sim, keep the R2 targets);
  - support the App's restart flow if it needs a Core hook.
- **Feel engineer** (`Swoop/Input`, `Swoop/Feedback`, tests):
  - UX-F1–F4;
  - a "Strong" haptic profile by default on the Duo (the founder found the Duo's taptic weak) and a setting for it;
  - the touch ramp tuning for the iPhone fallback (UX §10);
  - hold-or-tap tuck for Switch Control and VoiceOver, with the App;
  - audio and haptic cues for the new restart, the cover, the split-deck states and the motion language in ART §5.

## Done means
- Every P0 in both specs is fixed.
- Every task has been done or explicitly declined with a reason in your notes.
- New and changed behaviour has tests.
- New CI scenarios exist so the critic panel can see each state on the iPhone and Duo simulators.
