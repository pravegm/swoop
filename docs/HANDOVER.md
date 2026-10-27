# Swoop: handover for the founder

*Kept current as work continues. Last update: 27 Oct 2026, afternoon (UK).*

## What Swoop is
**Swoop: Tuck & Soar**, £1.99 once, rated 4+. No ads, no in-app purchases, and no data collected.
- **On iPhone Duo:** hold it like a book, and the two halves are the bird's wings.
- **How you fly:** fold a little on the way down a wave and the bird folds its wings and dives. Open at the bottom
  and it flies off the top. Land on the way down of the next wave for a **Perfect**. That's one fold per wave; you
  never flap.
- **The goal:** a storm chases you out to sea. Stay ahead of it and reach the next lighthouse along the route.
- **Other iPhones:** press and hold on the way down, let go on the way up (or tap).

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
| 1.0 (8) | Round 11: the storm has no hard edges, "The storm caught you", the lesson teaches each move before correcting it, a side-on fold diagram, and Perfects visibly push the storm back |
| 1.0 (9) | Round 12: the lesson only names landing rings that are on screen, and Skip is out of the bird's path |
| 1.0 (10) | Your fold note: folding about halfway no longer pauses; the pause is now under about 55° |
| 1.0 (11) | Release candidate: every final-QA fix |
| **1.0 (12)** | **The release build** (commit `c117b2d`, CI green): 11 plus one Results fix. This is the build Apple reviews |

## Final QA (27 Oct) and the fixes
Four release audits ran on 1.0 (10) (`design/qa/QA-FINAL-*.md`):

| Audit | P0 | P1 | P2 |
|---|---|---|---|
| App and UI | 1 | 7 | 18 |
| Core and data | 0 | 2 | 13 |
| Scene and feel | 0 | 3 | 16 |
| Release compliance | 4 | 10 | 14 |

The fixes you approved (`design/qa/FINAL-FIXES.md`) landed in commit `73c8369`:
- the hinge readout and the "Device test" card are gone from every TestFlight and App Store build (Debug only);
- Home's Daily never goes stale across midnight; a flat Duo passes Flight School's first step;
- touch is never stuck after a pause, and a two-thumb hand-off keeps the wings folded;
- one "Skip" on screen (the clear-side check now says "Not sure");
- Game Center keeps your best pending score and re-sends your achievements on sign-in;
- small-screen Home, battery, Reduce Motion and glossary fixes; audio and haptics repair themselves.

Every store document was then checked line by line against the code: the 55° pause, "The storm caught you", the
"Scores" button, the resting angle saved on the phone (privacy policy corrected), "Plays on other iPhones too".
The listing, Game Center, screenshots and the featuring nomination are pushed by the App Store Connect tool
(`asc.yml`), so you paste nothing. The release build is **1.0 (12)** (commit `c117b2d`): CI green, Duo hinge checks all
pass, checked on the smallest iPhone (SE) and on iPad, and the final store screenshots come from the same commit.

## What only you can do
Everything is in the checklist at the top of `docs/LAUNCH-RUNBOOK.md`, in order, with the exact clicks:
1. Turn on the website (GitHub Pages). **Do this now**: the Support and Privacy links don't work until then.
2. App Privacy: "Data Not Collected".
3. Pricing and Availability: Mac and Vision Pro off, Family Sharing on.
4. EU Digital Services Act trader status (only if asked).
5. Pick the build and submit for review, as soon as I say "ready".
6. If Apple rejects it: send me the message.
7. Launch day (optional): check the page, posts, accessibility labels, promo codes.

Steps 2–4 go before step 5. As you decided, Swoop goes live **as soon as Apple approves it** ("Automatically release
this version"), usually 24–48 hours after you submit: expected about **Thu 29 – Fri 30 Oct**, so Swoop now launches
before Brim (still Tue 17 Nov). Nothing to press. The Daily Flight's #1 and its leaderboard start Wed 28 Oct.
On each new build I send, the 10-minute Duo check is in the runbook's Appendix A. (The 15-minute script in
`design/panel/REVIEW-4-duo.md` uses Settings → Hinge readout, which is now only in Debug builds, not TestFlight.)

## Where things are
- **Repo:** `pravegm/swoop` (local copy at `C:\Users\59527\Wing`).
- `CLAUDE.md`: how to work on it.
- `design/`: the game design, the art and UX specs, round briefs, critic reviews (`panel/`), fresh-tester reports
  (`fresh/`), QA.
- `docs/`: the launch runbook, the project log, App Store copy, the website.
