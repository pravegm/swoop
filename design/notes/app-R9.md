# App R9: taught by the world, framed as progress (27 Oct 2026)

## Built (UX-ROUND-9 R1–R8, ART-ROUND-9 AR1–AR6)
- **R1 / AR1 / AR2 Flight School without cards.**
  - **Cut:** the prompt card, the "STEP n OF 7" overline, the praise lines and failure sentences, the PERFECT card,
    the Faster! bar, the rhythm bar and the R6 gauge (and the mini diagram over the sea).
  - **The step's words:** each step shows ≤ 3 words with no full stop (`FlightSchool.words(at:)`), e.g. "Fold a little",
    "Stay folded", "Land here", "Stay ahead". They are drawn in `headline` on a soft navy glow (`SchoolWord`), beside
    their cue, ≥ 80 pt from the bird and off the fold band (`SchoolRig`, tested).
  - **The live `WingDiagram`** rides the bird:
    - 96 × 64 on a Duo, 80 × 54 on iPhone;
    - above the bird, or below it in the top 30 %;
    - the fold is exaggerated (φd), tinted gold when folded and teal when open;
    - it draws a dashed ghost pose during each demonstration;
    - it is shown until step 3 has passed.
  - **Show, then wait:** every step demonstrates its move for 1.8 s before it can pass. Successes pause 0.5 s with no
    words.
  - **Dots:** 6 on a Duo (the clear-side step 2 is back, on the hinge and until answered), else 5. "Hold" shares Wings'
    dot; soar and land are one dot ("Up and land"). They sit in a row at the bottom of the bird page.
  - **Pause and Skip:** the pause shows from step 1 (`SchoolPauseButton`, a solid surface disc), with a Studio pause
    card. Skip is a surface capsule at the sea page's bottom outer corner.
  - **Step 6** passes on its Perfect (3 landings or 15 s pass it anyway).
- **Core / Feel hooks.**
  - **Guide gull:** `GhostPlayback` plays `FlightSession.practiceGhostPath(step:)` at 0.8× from the step's start. It
    uses no x offset, because the paths are on the same wave and an offset would put the ghost over a different wave.
    It calls `SceneAdapter.setGuideGhost` each frame. That call is a no-op until Scene exposes its guide gull (NEEDS
    "App → Scene (Round 9)").
  - **Feel:** `.ghost(move)`, `.schoolMorph`, `.waveDone(n)`, `.stormPushedBack` and `.lighthouseSighted`.
- **R2 / AR3 Results and the catch.**
  - The catch shows "Flight over" in a pill above the bird on the bird page at 1.4 s. The meter's knob slides into the
    storm and flashes, the HUD fades from 1.6 to 2.0 s, and the distance stays.
  - The card is `ResultsHeadline.make` (the case table, every case tested) on Core's `Lighthouses.next`:
    - an overline ("Flight over", "Your first flight", "Daily Flight · 27 Oct", "Practice · 27 Oct" or "Flight ended");
    - the tappable L→R mini strip;
    - the headline "You made it past Saltlight!" with a "New lighthouse" chip, or "You flew 2.1 km";
    - the distance with "New best!";
    - one quiet line ("Kestrel Head is 2.2 km further.", "Just 400 m short of your best.");
    - a tip on the first 5 flights only.
  - **Cut:** "Caught", the best line, stats, the route note, "Route ›" and the lightbulb.
  - **Bird page:** one moment: "New bird: Tern", "Level 2" and "Fly as Tern", which selects the bird and flies.
    Otherwise up to 3 goal rows that moved; after a level-up, the new level's unmet goals only.
- **R3 glossary.**
  - Stay ahead of the storm · the way down/up · perfect landings · "×3 in a row" · Level n · Unlocks · "Gull Point!" ·
    New lighthouse · Same waves for everyone · 1 try · Practise today's waves · "Daily Flight · 27 Oct" everywhere
    (`AppRules.dailyTitle`) · Top scores.
  - Cut: the first-flight storm teach line and the countdown's goal pill.
- **R4 units.** `ShareText.distance` shows one decimal at ≥ 1 km, rounds down for distance flown and up for distance
  to go (0.1 km / 10 m). The HUD ticks every 100 m. The share line says "perfect landings".
- **R5 HUD.**
  - The chip always sits under "NEXT" on a backing.
  - Toasts, the lighthouse card and the one-time lines move to the other page's top band when they would come within
    80 pt of the bird (`AppRules.clearOfBird`, tested).
  - The countdown sits on the bird page.
- **R6 / AR5 Route, rewritten** (`RouteLayout`, pure).
  - It always reads left to right: the storm behind the harbour at the left, then every passed lighthouse, the next
    and 3 more, all by real name.
  - Every lighthouse stands on a 34 pt headland point; the land uses the dusk palette.
  - Labels sit on one baseline row, ≤ spacing − 16 wide, wrapping to 2 lines. "and on…" has its own slot. There is
    one Best pin, its label above the line, else below, else only on the bottom bar.
  - On open the next lighthouse sits at 60 % of the width, snapped off the fold.
  - The header is at the top-left. The Duo has two bottom cards, one per page; the iPhone has one bar.
  - Tests: `routeLabelsNeverOverlap` (7 canvases × 0–12 × bests) and `routeReadsLeftToRight`.
- **R7 Home.**
  - Fresh captions: "Hold it like a book. These are your wings." / "Hold anywhere. The wings fold.".
  - After the school: "Stay ahead of the storm. Reach the lighthouses.".
  - Fly reads "Next: Gull Point · 4 km".
  - One "New" badge, inside the tile, on the most recent unlock (birds after a level-up).
  - No text label on the corner icons.
- **R8 / AR6 CI.** The r9-* frames (24 in each file) cover:
  - each school step's demo and turn;
  - the clear side;
  - "Stay folded";
  - caught at 0.6 / 1.4 / 2.4 s;
  - Results for each case;
  - the new-bird card;
  - the Route fresh / 2 / late;
  - Home returning.
  Demo `school=<step>:demo|turn|fail` holds the moment.

## ART §3 defect list, App rows
**Fixed:**
- **1** the icon sliver (removed in R8);
- **2** the text labels;
- **4** the badge;
- **7 / 8** the diagram and gauge;
- **9 / 10** the cards;
- **11 / 12** the pause;
- **13** no cards are left;
- **14** Faster;
- **20** PERFECT;
- **21** the slider;
- **23** the dots;
- **24** the red tick (now the coral zone at α 0.35 only);
- **25** the storm icon (now on a surface disc);
- **26** the countdown, on the bird page;
- **27** one pill;
- **28** toasts;
- **32** the school chip;
- **33** the App part of the catch;
- **35** one card;
- **36** truncation, now wrapped;
- **37** decimals;
- **38** the strip, L→R;
- **39** density;
- **40–45** Route;
- **46** the iPhone title bird (y 24, 0.30 h);
- **47** the touch glyph (now a 36 pt gull on a 44 pt disc);
- **48** one `PlayLayout` (school hides elements);
- **49** Skip;
- **50** punctuation.

**Declined, with reasons:**
- **30**, the HUD's km: UX §4.2 (UX wins on copy) keeps whole metres under 1 km and one decimal above, everywhere.
  ART's "0.1 km" would contradict the Results and Route formatter.
- **31**, dropping "NEXT": UX §4.4 / §4.1 put the chip under a NEXT overline as the one goal phrase. It is now short
  ("NEXT") on a surface backing for contrast.
- **The thin space before units (UX §4.2):** declined for the text strings, because it would change every distance
  string and its VoiceOver reading. The HUD keeps its thin space.
- **The "=" in "Tailwind! 3 in a row = speed boost":** this is the glossary's own line (UX §3), so I kept it.

## Not done
- The guide gull, the ring rect, the step-6 "Gull Point" label and the fold-path fill are Scene's (SR1–SR3, SR7).
  The App calls sit ready; see NEEDS.
- "Fly again → Free flight" with Share primary on a scored Daily (UX §2.2) is not changed this round.

## Scene R9 wired (after Scene landed)
- `scene.guideGhost` is driven every frame from Core's path, one to one (`landed` from the path's Perfect); `onGhostFinished` ends that step's demo. The diagram's dashed pose is Scene's `ghostTuck` in the sea steps; the App's scripted pose remains for the Studio only.
- `practiceSea` is set for every school step; `stormLinkTarget` flows to the meter's storm icon for 1 s; `schoolLighthouse` rises at 3 s with an in-world "Gull Point" at `lampCanvasPoint`; `ringScreenRect` places "Land here"; `ghostScreenPoint` keeps words off the guide gull; `homeMenuRects` is the Goals / Route / Birds row; step 5 uses `.rhythmAhead(count: 3)`.
