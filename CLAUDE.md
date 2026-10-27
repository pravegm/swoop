# CLAUDE.md: working on Swoop

**Swoop: Tuck & Soar** is a paid iPhone game (£1.99, no ads, no IAP, no data collected), built **iPhone Duo first**.
The Duo is Apple's foldable (iOS 27.1). Hold it open like a book: the two halves are the bird's wings. Fold a
little to tuck and dive down a swell, open to soar off the next crest, and outfly the storm chasing you.

The founder (GitHub `pravegm`) is the product owner and was away while this was built. Claude runs the studio as
founder, designer and developer, with parallel subagents per role and a design-critic loop.

**Sister projects:** **Squish** (`C:\Users\59527\Squish`) and **Brim** (`C:\Users\59527\Fold`). Never modify them;
reuse their lessons and code by copying.

## The bar
1. **Duo-first.** Judge every change in book pose first: the Duo held in two hands at 120–170°, the bird on the left
   half, the sea ahead on the right half. The touch fallback (hold to tuck) is secondary.
2. **The fold feels like flying.** Tuck feels heavy and fast, opening feels like lift. Juice is the product: wind,
   spray, haptics, the Perfect chain.
3. **Gentle on the hinge.** Short, slow strokes. Never ask for a slam, a full close, or fully flat. Starting a fold
   from flat blurs half the Duo's screen for about 2 s, which is an iOS effect.
4. **Truthful store frames.** Nothing appears on a frame that the app doesn't do.

## Working rules
- Push straight to `main` (solo project, the founder's standing rule). No PRs.
- Repo: https://github.com/pravegm/swoop. It is **public** (since 26 Oct 2026: private-repo Actions are blocked by
  this account's billing; Brim and Squish are public too). Nothing personal goes in it.
- **No Mac on the Claude side. CI is the compiler.** A Swift change is unverified until a GitHub Actions run passes.
- On this Windows host Bash ignores `cd`. Use absolute paths and `git -C`. There is no Python; use Node
  (`tools/balance-sim.js` is a JS port of the flight physics for tuning).

## Build
`brew install xcodegen && xcodegen generate && open Swoop.xcodeproj`
- Xcode 27.1 with the iOS 27.1 SDK. Deployment target iOS 18.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Swift 5 mode.
- The `.xcodeproj` and `Info.plist` are generated, not committed.

## CI
| Workflow | Trigger | What |
|---|---|---|
| `ci.yml` | push | build, unit tests (iPhone 18 Pro sim) and demo screenshots (`ci/scenarios.txt`) |
| `duo.yml` | manual | iPhone Duo sim (iOS 27.1 runtime): real hinge flight with the `hinge` CLI, a close/reopen check, store and UI frames (`ci/duo.sh`, `ci/duo-scenarios.txt`) |
| `testflight.yml` | manual | signed Release archive and upload (needs the 4 ASC secrets; `check_only` builds unsigned) |

App and CI talk through stdout lines that start with `SWOOP-` (`SWOOP-T` demo/timing, `SWOOP-H` hinge samples). The
demo keys are listed in `design/ROUND-1.md`.

## Docs (read in this order)
1. `design/GAME-DESIGN.md`: the game.
2. `design/ARCHITECTURE.md` and `Swoop/Shared/Contracts.swift`: modules, owners, APIs.
3. `design/ROUND-N.md` (briefs), `design/REVIEW-N.md` (critic), `design/notes/` (engineer hand-offs),
   `docs/PROJECT-LOG.md` (what happened when).
4. `research/01-market.md`: the market and name check.
5. `docs/LAUNCH-RUNBOOK.md`: the steps only the founder can do (Apple login).

## Hinge facts that bite (from Squish's and Brim's real-Duo logs)
- Use the **angle**, never `status == .closed` (it turns on at ~85° on hardware).
- Samples arrive at 25–30 Hz while moving and not at all while still. Predict between samples (`HingePredictor`) and
  smooth with One-Euro.
- Re-enable `onHingeChange` on each activation to get a fresh reading.
- The inner display ignores orientation locks. Book pose = landscape 951 × 669 pt with a vertical fold.

## Swift Testing gotchas (found on CI)
- `#expect(x.mutatingMethod())` doesn't compile, because the macro captures `x` immutably. Call it first:
  `let r = x.mutatingMethod(); #expect(r)`.
- `#expect(cgFloatValue == 476 + 72)` can be **false** even when both sides print 548. The literal arithmetic is
  typed apart from `CGFloat`. Compare with a typed constant and a tolerance:
  `let e: CGFloat = 476 + 72; #expect(abs(v - e) < 0.01)`.
