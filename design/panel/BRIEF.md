# Critic panel brief (Round 3 build, commit on main 26 Oct ~15:30)

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
