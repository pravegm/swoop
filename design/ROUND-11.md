# Round 11: the seams (fresh testers 13–15 on R10, 27 Oct 2026)

The reports are in `design/fresh/tester13-duo.md` (61, non-gamer, Duo), `tester14-duo.md` (product designer, Duo) and
`tester15-phone.md` (casual, iPhone). They saw the R10 `session=first:*` frames (TF 1.0 (7)).

| Tester | Understood | Finished | Keep playing |
|---|---|---|---|
| 13 (Duo, non-gamer) | 6 | 6 | 6 |
| 14 (Duo, designer) | 6 | **5** | 6 |
| 15 (iPhone, casual) | 7 | 6 | 6 |

All three still got the four questions right. But "finished" went **down**, because R10's new frames put two things
on screen that look broken:
- the storm at the catch (s1-15b, s1-15c);
- a tutorial that fails you before it has told you the rule (s1-05 → s1-06).

**The bar for R12 testers:** finished ≥ 7 from all three, no tester naming a rendering defect, and no "nobody told me"
moment.

## P0 (looks broken, or punishes before teaching)

1. **The storm has no straight edges, ever** (s1-15b, s1-15c; all three testers; the founder verified it in the
   frames).
   - **Symptoms in s1-15c:**
     - the grey storm tint stops at a hard vertical line about 240 pt from the left of the canvas;
     - the cloud's texture smears into horizontal streaks to its right (a clamp-to-edge stretch);
     - in s1-15b, a hard rectangular band sits behind the cloud.
   - **The fix:** the tint becomes a mask whose leading edge is a soft horizontal alpha ramp at least 300 pt wide,
     positioned from the storm's x. When the front has crossed the bird, the tint covers the whole screen and no edge
     shows.
   - The cloud must never draw past its texture. Fade it out with alpha before its edge, or size and tile it for the
     maximum overscan (the catch sweep and the school recoil).
   - Check every frame where the storm is on screen: s1-11 to s1-13b, s1-15 to s1-15c, P03, the r10 caught-peak frame,
     and both orientations on the Duo.
   - **Owner:** Scene.
2. **Failure says why** (s1-15b, s1-15c, s1-16).
   - The pill "Flight over" becomes **"The storm caught you"**, at the scale of the big "Perfect".
   - The storm meter stays on screen through the catch, with the storm end reaching the bird knob.
   - The Results card repeats the cause in its existing story line ("The storm caught you 2.2 km before Kestrel
     Head."). Check that it appears and isn't cut. Don't add a new line.
   - **Owner:** App (the HUD and pill); Scene if the catch peak needs the meter kept.
3. **Teach the rule before the miss** (s1-05 → s1-06, s1-08, s1-10; all three testers).
   - **Dive step words** (≤ 7 words, in the glossary vocabulary):
     - Duo: **"Fold down the wave"**; iPhone: **"Hold down the wave"**.
     - After the ghost has shown it, add a muted second line: "Open at the bottom" / "Let go at the bottom".
   - **The miss** keeps "Opened too soon" / "Let go too soon" and adds the remedy as its muted second line: "Stay
     folded to the bottom" / "Keep holding to the bottom".
   - **Rhythm:** "One fold per wave" / "One hold per wave" moves to the **first** move step's sub-line as well (keep it
     on the rhythm step too). No tester should ever ask "do I flap?".
   - **Owner:** App.
4. **The fold diagram shows the fold** (s1-02 to s1-05; testers 13 and 14).
   - "Hold it open" and "Fold a little" look like the same flat book. Draw a **side-on hinge**: two plates meeting at
     a hinge.
     - The open target is about 170–180°. The "fold a little" target is about 135°, a visibly narrower wedge.
     - A live pose (the real tuck) moves inside it.
   - **The done state** (s1-04) shows the reached pose with a tick, not an open book.
   - The label always sits in one place (below the diagram) on every step.
   - Remove the small duplicate book/flag drawn on the gull's back (s1-05, s1-06). If it is the live tuck indicator,
     there must be exactly one indicator, and it is the diagram.
   - On iPhone, the same slot shows a finger-press glyph (no book).
   - **Owner:** App (UI); Scene if the indicator on the bird is a Scene node.
5. **"Land here" points at something** (s1-08; testers 13–15; tester 15's "single most confusing moment").
   - Use the s1-09 treatment (chevron plus dotted line to the ring) from the step's start.
   - The ring spawns at least 200 pt inboard of every edge and never under Skip, the step dots or the pause button.
   - The words sit next to the ring they name.
   - **Owner:** App (words, anchor); Scene (ring placement).
6. **The storm step is never empty** (s1-11, frame 1 of step 6: no storm, no meter, no words).
   - The storm and its meter must be on screen from the step's first frame, with "Stay ahead" by the meter. Shorten
     `stormWordsAfter`, or bring the storm in during the step transition.
   - **Owner:** App and Scene.
7. **The Perfect visibly pushes the storm** (s1-13b).
   - The R10 frame froze with "Stay ahead" on screen, no storm in view and the knob not jumped. So either the recoil
     peak froze before `pushedAt` was set, or the storm was off screen.
   - Find which. In the frame, the storm must be visible, recoiling, with "Perfect pushes it back" by the meter and
     the knob visibly jumped. Add a short **"+" gap pop** on the meter when it jumps.
   - This must hold **live**, not only in the demo freeze. Add a test that, after a school Perfect in the storm step,
     the words are "Perfect pushes it back" and the meter lead has risen.
   - **Owner:** App and Scene.
8. **One direction everywhere** (tester 14).
   - In flight, the bird flies **toward** the lighthouses and the storm is behind. On the Duo's default (the bird on
     the right half, mirrored) that is right-to-left. The Route page (s1-18) and the Results tracker (s1-16) run
     left-to-right with the storm on the left.
   - Both must follow the current flight direction: in a mirrored flight, the pier and storm are on the right and the
     lighthouses lead left. The bird art on Results and Birds faces the flight direction.
   - On iPhone (not mirrored) nothing changes.
   - **Owner:** App.
9. **No placeholder art.** The translucent rectangular slab under the Gull Point lighthouse (s1-12, s1-13) becomes an
   irregular rock/headland silhouette in the scene palette. **Owner:** Scene.

## P1 (the copy and collision pass)

10. **Copy.**
    - Use "2 new lighthouses" (plural) when two were passed.
    - On Results, delete any line that repeats what the tracker shows ("Kestrel Head is 2.2 km further." if the
      tracker already says it).
    - "Land a Perfect" becomes **"Land in the gold ring"**.
    - Never show "Stay ahead" twice in a row.
    - One distance format everywhere: "4 km" for whole km and "2.2 km" otherwise, with no "4.0 km".
    - The countdown (s1-14) doesn't repeat the tagline shown on Home. If the goal sentence is shown there, show it
      once and in full ("lighthouses...." is truncated on the iPhone).
    - On Goals (s1-19) there is no double colon, and Level 1's label is a noun phrase like the others.
    - On Results, "Level 2" becomes "Level 2 reward".
    - **Owner:** App.
11. **Collisions.** No text overlaps a sprite or a control:
    - the Home gull and its trail vs the tagline (s1-01);
    - the wing vs "Hold anywhere" (s1-03);
    - the Perfect ring vs the step dots (s1-09).
    - Add a test where layout code exists (text rects vs the bird rect, as R8 did for prompt cards).
    - **Owner:** App; Scene for where the Home attract gull flies.
12. **Step dots.**
    - One count, sequential, the same on Duo and iPhone for the steps each platform has.
    - Never jump from 1 to 3 (tester 13, s1-04 → s1-05).
    - The current dot is gold, the done dots white, the future dots dim.
    - **Owner:** App.
13. **Mystery UI.**
    - The unlabelled round bird button at bottom-left in school and countdown (s1-05, s1-10, s1-14) gets a visible
      label ("Show me" if it replays the guide gull), or goes.
    - The two round Home icons (Leaderboard, Settings) get labels or are self-evident.
    - The Birds tile matches Goals and Route (icon plus inline label; the New badge is a corner dot).
    - **Owner:** App.
14. **The "Perfect ×N" lettering** in flight has a speckled, mottled texture fill (P02 store frame). Make it a clean
    gold with a solid outline, crisp at 3×. **Owner:** Scene.
15. **The Results cards** have equal height or a shared bottom. "Choose Tern" gets a visible secondary style.
    **Owner:** App.

## Process
- Each engineer writes only in their own folders (`design/ARCHITECTURE.md` § Module ownership), updates the tests,
  and writes `design/notes/<role>-R11.md`. Cross-module asks go in `design/NEEDS.md` → "Round 11".
- There is no local compiler (Windows). CI is the compiler, so check Swift carefully, and follow the gotchas in
  `CLAUDE.md` (Swift Testing: no mutating calls inside `#expect`; use typed `CGFloat` constants and tolerances).
- Don't commit or push. The founder integrates, pushes, runs CI, Duo and fresh testers 16–18 on the new s1 frames.
