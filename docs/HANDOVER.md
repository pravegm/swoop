# Swoop: handover for the founder

*Kept current as work continues. Last update: 27 Oct 2026, early hours (UK).*

## What Swoop is
**Swoop: Tuck & Soar**, £1.99 once, rated 4+. No ads, no in-app purchases, and no data collected.
- **On iPhone Duo:** hold it like a book, and the two halves are the bird's wings.
- **How you fly:** fold a little to tuck, and hold it down the face of a wave. Open at the bottom to fly off the
  crest. Land on the next downslope for a **Perfect**. That's one fold per wave; you never flap.
- **The goal:** a storm chases you out to sea. Outfly it and reach the next lighthouse along the route.
- **Other iPhones:** press and hold to tuck.

## What changed after your first test (TestFlight 1.0 (2))
You said the controls, the blurred half and the objective were unclear, and that it felt half-baked. Every point
was taken as a P0.

| You said | What it is now |
|---|---|
| "Do I flap like Flappy Bird? What does what?" | **Flight School** runs on the first launch: 7 steps in a calm practice sea (Duo) or 6 on a normal iPhone, taught by doing. Fold = wings → hold the fold down the wave → open to fly → land = **PERFECT** → "one fold per wave, you never flap" → the storm. You can replay it from Settings. |
| "The bird is on the side that blurs" | No app can switch the blur off; iOS does it to one physical half whenever a fold starts from flat. So the **bird now defaults to the right half**, flying right-to-left, and stays on that physical half if you turn the phone round. **Settings → Bird side** changes it, with a "Why?" explainer. A one-time tip says "no need to open flat" (folding from flat is what triggers the blur). |
| "What is the storm, where are we going, what is success?" | **Lighthouses are fixed places on a route** (Gull Point 4 km, Saltlight 9 km, Kestrel Head 15 km…). The HUD always shows "← Gull Point · 1.2 km". Reaching one is the big moment ("Gull Point reached!", "New on your route"). Results lead with "Caught 0.8 km short of Saltlight". There's a **Route** page. "Outfly the storm. Reach the next lighthouse." shows under Fly and on your first run. |

**Proof:** three new first-time testers with no context (a casual gamer on a Duo, a 52-year-old non-gamer on a Duo,
and a gamer on a normal iPhone) were each given only the screens. **All three correctly explained** the hands, the
storm, the route and win/lose. That was round 6, which scored 7, 6 and 7. Round 7 fixed what still confused them.

## Builds
| TestFlight | What's in it |
|---|---|
| 1.0 (2) | the build you tested |
| **1.0 (3)** | Round 6: Flight School, bird on the sharp half, lighthouse goals and the route |
| next | Round 7 (clarity polish) and anything after; I'll keep pushing builds |

## What only you can do
1. Install the newest TestFlight build and play the first 2 minutes as if you'd never seen it. Tell me whether
   you'd know what to do.
2. The 15-minute Duo test script is in the appendix of `design/panel/REVIEW-4-duo.md`. It uses Settings → Hinge
   readout; that row only appears in TestFlight builds.
3. Still pending from the launch runbook (`docs/LAUNCH-RUNBOOK.md`):
   - Game Center leaderboards and achievements (§4);
   - price, age rating and privacy (§5);
   - GitHub Pages for the support and privacy URLs (§0b);
   - the featuring nomination by Tue 3 Nov (§1e);
   - the store listing paste (§6).
   The store screenshots are built by the **App Store screenshots** workflow (`store.yml`).

## Where things are
- **Repo:** `pravegm/swoop` (local copy at `C:\Users\59527\Wing`).
- `CLAUDE.md`: how to work on it.
- `design/`: the game design, the art and UX specs, round briefs, critic reviews (`panel/`), fresh-tester reports
  (`fresh/`), QA.
- `docs/`: the launch runbook, the project log, App Store copy, the website.
