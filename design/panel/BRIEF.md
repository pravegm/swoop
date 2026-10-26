# Critic panel brief (Round 4 build, 26 Oct ~18:00; R3 brief kept below for paths)

Swoop: Tuck & Soar is a paid (£1.99) iPhone Duo-first game. Hold the Duo like a book: the two halves are the
bird's wings. Fold to dive down ocean swells, open to soar off the crests, and outfly the storm. On other iPhones you
hold to tuck.

The founder's bar: "simple, fun, addictive, satisfying". Design and UX are "really key in making this a huge
success". The game must be "optimised in all ways for iPhone Duo, with a fallback if it's not a Duo".

## Read
- `design/GAME-DESIGN.md`
- `design/ART-DIRECTION.md`
- `design/UX-SPEC.md` (the standard the build was meant to meet)
- `design/ROUND-3.md`
- `design/notes/*-R3.md`

## Frames (CI, real builds)
The scratchpad root is `C:\Users\59527\AppData\Local\Temp\claude\C--Users-59527-OneDrive---Bain-Desktop\f240a197-ea15-474e-85a1-a1a682401921\scratchpad`.

- **iPhone 18 Pro landscape:** `r5\screenshots\*.png`, about 50 frames, including the cover-* states and the
  touch-wing fallback. The demo args for each are in `ci\scenarios.txt`, and the per-frame logs are in
  `r5\screenshots\logs\`.
- **iPhone Duo inner display:** `duo5\duo-screens\duo-screens\*.png`.
  - `store-01`…`39`: autopilot frames (args in `ci\duo-scenarios.txt`).
  - `duo-01`…`08`: the real hinge pass at 147°/122°/150°, then closing and reopening.
  - `duo-07-closed`: the cover display.
  - `duo-ui-*`: menus.
- **Earlier rounds** for comparison: `r3\screenshots`, `duo3\duo-screens\duo-screens`.

## Balance (Swift, CI)
| Player | Median run | Perfects/min | Splashes/min |
|---|---|---|---|
| Novice | 64 s | 2.6 | 2.3 |
| Casual | 156 s | 12.9 | 3.5 |
| Expert | 338 s | 20.6 | 2.2 |
| Perfect | 420 s | — | — |

## Duo hinge checks (simulator, real hinge events)
ready-pose calibration, hinge flight, and close/pause/reopen: all PASS.

## Output
- `design/panel/REVIEW-3-<you>.md`, at most 150 lines.
  - Open with a score out of 10 and a launch verdict (yes / not yet).
  - Then findings marked P0, P1 or P2. Each gives the frame name, the problem and a concrete fix (with numbers or
    hex where it's visual).
  - End with "Top 8 for Round 4".
- **Look at every relevant frame** with the Read tool. Don't edit code.

## Round 4 update
**Frames**
- iPhone: `r8\screenshots\` (about 60 frames; `captures.tsv` lists them; logs in `r8\screenshots\logs\`).
- Duo: `duo6\duo-screens\duo-screens\` (59 frames). It was built from the R4 code before the R4b balance retune;
  the visuals are identical.
- Compare against R3: `r5\screenshots` and `duo5\duo-screens\duo-screens`.

**Balance (Swift CI, R4b)**

| Player | Median run | Perfects/min | Splashes/min |
|---|---|---|---|
| Novice | 64 s | 2.6 | 2.6 |
| Casual | 138 s | 9.9 | 3.3 |
| Expert | 355 s | 17.8 | — |
| Perfect | 506 s | — | — |

**Other evidence**
- **Tests:** 193 pass.
- **Duo hinge checks:** all PASS.
- **What changed:** `design/ROUND-4.md` and `design/notes/*-R4.md`.

**Output:** `design/panel/REVIEW-4-<you>.md`, same format, at most 120 lines. Open by stating which of your R3 P0s
and P1s are fixed, partly fixed, or not fixed.
