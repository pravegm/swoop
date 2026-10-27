# Swoop: handover for the founder

*Kept current as work continues. Last update: 27 Oct 2026, about 05:00 (UK).*

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

**Proof:** after each round, three new first-time testers with no context walked the first session frame by
frame. There have been 12 so far: casual gamers, a 52-year-old non-gamer, a creative director, and players on a Duo
and on a normal iPhone. **All twelve correctly explained** the hands, the storm, the route and win/lose.
"Understood" now scores 6–8. "Feels finished" ranges 5–8, and is what rounds 8–10 worked on. Their reports are in
`design/fresh/`.

## Rounds since your test
| Round | What it fixed |
|---|---|
| 6 | Flight School, bird on the sharp half, lighthouses and the route |
| 7 | Clarity polish from the first three fresh testers |
| 8 | The finish pass: real lighthouse names everywhere, consistent step numbering, one story on Results ("Reached Saltlight! The storm caught you 2.17 km before Kestrel Head."), goals that tick on the same screen, at most one "New" badge |
| 9 | Teach through the world, not text cards: a guide gull flies the path on the water, prompts of 7 words or fewer, one vocabulary (Duo says **fold / open**, iPhone says **hold / let go**), cards never cover the bird, no "on iPhone Duo…" lines on a normal iPhone |
| 10 | The lesson now *shows* that Perfects push the storm back (a big PERFECT, the storm recoils, the meter jumps). The goal is stated before your first flight. One wing diagram style, showing the pose it asks for. Calmer Results, Home and Goals |

## Builds
| TestFlight | What's in it |
|---|---|
| 1.0 (2) | the build you tested |
| 1.0 (3) | Round 6 |
| 1.0 (4) | Round 7 |
| 1.0 (5) | Round 8 |
| 1.0 (6) | Round 9 |
| 1.0 (7) | Round 10 |
| **1.0 (8)** | **Round 11: install this one.** The storm has no hard edges, "The storm caught you", the lesson teaches each move before correcting it, a side-on fold diagram, and Perfects visibly push the storm back |

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
