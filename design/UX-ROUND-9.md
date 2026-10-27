# Swoop: UX Round 9, teach through the world, frame the flight, speak plainly (27 Oct 2026)

*Owner: UX Lead. Inputs: fresh testers 6–9 (`design/fresh/`) and their frames in `scratchpad/fresh3/{duo,phone}`. This
supersedes the Flight School copy and timings in `UX-FLIGHT-SCHOOL.md` §1, the Results framing in §4.6, and every copy
string listed in §3 below. It keeps that file's state machine, persistence, Wing check model, Bird side and objective
data (fixed names, `routeReached`). The look of the ghost bird, water guides, diagram and map is
`design/ART-ROUND-9.md` (not yet written when this was; the joint points are in §6).*

**What the testers proved.** Nine out of nine answered the four questions, so clarity is solved.

"Finished" is stuck at 6–7 for four reasons:
1. a 7-card text tutorial;
2. Results that read as both a win and a loss;
3. jargon ("Outfly", "downslope", "Puddle Hopper", "Everyone's sea · one try");
4. units and wording that drift from screen to screen.

There are also visible bugs:
- truncation on Results;
- the Route label overlap;
- a map that runs backwards on the Duo;
- toasts covering the bird.

## 1. Flight School, taught by the world

### 1.1 Rules (binding for every step)
1. **Show, then wait, then answer.**
   - A **ghost bird** (Art: the player's bird at 45 % white, no shadow) performs the move once on the same wave, just
     ahead of the player's bird, for 1.6–2.0 s, while a **mini phone diagram** beside the bird does the matching fold
     (or finger press) in sync.
   - The sea then **waits** (Core `holdAtCrest` / slow time) until the player does it.
   - The world **answers**: the bird moves, a guide lights up, Feel's step chime plays.
2. **In-world text:** at most **3 words** per step.
   - No full stop. Placed beside its cue: the diagram, the ring, the storm. Never in a card, never over the bird
     (keep ≥ 80 pt from the bird's rect) and never in the fold band.
   - Style: Art's `headline` on a soft 0.45 navy glow, not a panel.
3. **Cut:**
   - the prompt card;
   - the "FLIGHT SCHOOL · STEP n OF 7" overline;
   - the praise lines ("✓ That's a tuck", "Wings folded!");
   - the failure sentences;
   - the Faster! bar;
   - the rhythm bar and its dots;
   - "Never flap" and "=".
4. **Progress:** one row of 6 dots (5 on touch), 6 pt, at the bottom centre of the bird page (y = h − 22). It never
   sits under the meter.
5. **A graphic stays only if it explains itself by moving with the player:**
   - the fold path fills as you stay folded;
   - the lift arrows point up where you open;
   - the landing ring is a bright target on the water before you launch;
   - the diagram copies your hinge live.
   - Anything static that the player has to decode is cut.
6. **The diagram is always live** (it copies the filtered hinge or the finger every frame, s1-04's frozen gauge was a
   bug). It sits on the bird page beside the bird: Duo 96 pt, iPhone 72 pt, offset (−130, −60) from the bird, mirrored.
   It hides once step 3 succeeds.
7. **No praise words.** Success = the chime, a 0.25 s gold glint on the diagram, and the world moving on.
8. **Failure = rewind, not a scolding.** The sea runs backwards for 0.4 s to the step's checkpoint (Reduce Motion: a
   0.3 s crossfade). The ghost replays only the part that went wrong. After 3 misses the step passes anyway, silently.
9. **Unchanged:** Skip (tertiary "Skip" at the sea page's bottom outer corner, from step 2) and the pause button in
   steps 3–6.
10. **VoiceOver** keeps the full sentences from `UX-FLIGHT-SCHOOL.md` §1.2 as announcements; nothing visual is read
    aloud twice.

### 1.2 The steps

| # (dot) | The world shows | Ghost / diagram | Words (Duo / touch), where | Done when | If missed |
|---|---|---|---|---|---|
| **1 Wings** (Studio: the title bird across both halves, calm practice sky, **no storm or rain**) | The title bird mirrors the hinge live. | If the Duo isn't in book pose: the diagram's ghost shows an open book, with **"Hold it open"** beside it. Then the diagram's ghost folds a third shut and back (1.4 s loop) while the title bird's ghost wings fold in sync. | **"Fold a little"** / **"Hold anywhere"**, by the diagram. After the tuck: **"Now open"** / **"Now let go"**. | One full tuck and reopen (u ≥ 0.8 for 0.2 s, then ≤ 0.2) | No movement for 6 s: the loop speeds up and the title bird does a small "nudge" flap. No words added. |
| **2 Clear side** (Duo hinge only) | Each half shows Art's test-pattern card (the whole half is the button). | The mini diagram at the fold animates flat → slight fold. | **"Open flat"** → **"Now fold"** → **"Tap clear side"**, on BOTH halves | One tap | No flat in 10 s: "Skip" grows to a 56 pt button. |
| *(transition)* | The title bird sweeps down into the sea and becomes the play bird (0.8 s morph, Art). The practice wave rolls in. | — | — | — | — |
| **3 Down** | The bird waits on the top of a long wave. A **gold fold path** is painted along the wave's downhill side (Art). | The ghost tucks and slides down the path to the bottom, with speed streaks (1.8 s); the diagram folds with it. | **"Fold"** / **"Hold"**, by the diagram | The bird reaches the bottom having stayed folded over ≥ 70 % of the path. **The path is the meter:** the stretch the bird covers while folded turns bright gold behind it; any stretch covered open stays pale. | Rewind to the top. The pale stretch pulses once, the ghost replays from that point, and **"Stay folded"** / **"Keep holding"** appears at the spot. |
| **4 Up and land** | At the bottom: 3 white **lift arrows** pointing up the wave. Ahead, on the next wave's downhill side: the **landing ring**, bright and pulsing, visible before the launch (it was invisible or late in s1-08). | The ghost opens at the bottom, launches along a dotted arc and drops into the ring (2.0 s, 0.5× time near the bottom); the diagram opens. | **"Open"** / **"Let go"** by the lift arrows; then **"Land here"** by the ring | A Perfect in the ring (the game's own "Perfect" callout, ring and chime) | **Never launched:** rewind to the bottom, and the arrows pulse. **Missed the ring:** the ring stays; the next guided wave comes; the ghost shows the fix (tuck in the air to drop sooner if the player overshot, stay open longer if they fell short). |
| **5 Rhythm** | 3 waves, each with its gold fold path down and lift arrows at the bottom. | The ghost flies **one wave ahead** as a leader to follow: one fold down, one open up, per wave. Repeating the motion shows there's no flapping. | **"One per wave"**, once, by the bird at the first wave | 3 waves flown | None. It always advances. |
| **6 The storm** | The calm sky darkens from the behind edge. The storm wall rolls in with thunder. The meter fades in, and for 1 s a dotted line links the real storm to the meter's storm icon. Then the next guided ring: on the player's Perfect, gust streaks hit the storm, it falls back, and the meter's gap grows. Finally the first lighthouse rises on the far horizon with its name in the world. | — | **"Stay ahead"** by the meter; the in-world name label **"Gull Point"** by the lighthouse | The Perfect lands (3 tries, then it passes) | — |
| *→ the real flight* | The practice tint lifts; 1.5 s **Ready · Go**; the HUD as §4. | — | The countdown line as now | — | — |

- **Timing:** about 30 s (Duo), 24 s (touch). Steps went from 8 to 6 dots on Duo and 7 to 5 on touch; the old "Hold"
  step folds into Wings.
- **Cut on the first real flight:** the teach line "Storm behind you. Don't let it catch you." (tester 8: it covered the
  bird; tester 7: it repeated step 7). The school has already shown the storm.
- **Tapping mode:** the words become **"Tap"** / **"Tap again"**.
- **Countdown line on touch:** keep **"Hold going down · let go going up"** (tester 9: "the clearest line in the
  game"). On Duo: **"Wings open, hold steady"**.

## 2. Results, framed as progress

**The rule:** every flight ends with the storm, so the ending is never news and never the headline. The headline is
always *how far you got*, in lighthouses. "Caught" appears nowhere on Results.

### 2.1 The caught moment (in play)
- At the caught event the HUD fades, except the distance.
- Art makes the storm visibly overtake the bird.
- One centred line at the sea page's 40 % height: **"Flight over"** (no full stop, 1.2 s). It replaces "The storm caught
  you".

### 2.2 The card (far page), top to bottom, nothing else
1. **Overline:** **"FLIGHT OVER"**. Variants: **"YOUR FIRST FLIGHT"**, **"DAILY FLIGHT · 27 OCT"**, **"PRACTICE ·
   27 OCT"**, **"FLIGHT ENDED"** (ended from the cover).
2. **Mini route strip** (left to right, §5): the start, the lighthouses passed lit, the bird where it stopped, and the
   next lighthouse outlined.
3. **Headline** (title size): the case table below.
4. **Distance hero:** **"12.8 km"** (§4 units), plus a **"New best!"** chip when it is one.
5. **One quiet line** (body, mist): the case table below.
6. **One tip,** on the first 5 flights only (body, mist, no lightbulb icon): the tip rules from `UX-FLIGHT-SCHOOL.md`
   §4.6 in the new words (§3).
7. **Buttons:** Fly again (primary) · Home · Share. On Duo, the line under them: **"Or fold and open"**.

**Cut from the card:**
- "The storm caught you … before …";
- "Every lighthouse you reach goes on your Route.";
- "Route ›" (the strip is tappable and opens Route);
- the stats line;
- the lightbulb.

| Case | Headline | Quiet line |
|---|---|---|
| Passed ≥ 1, a new one among them | **"You made it past Saltlight!"** + gold chip **"New lighthouse"** | **"Kestrel Head is 2.2 km further."** |
| Passed ≥ 1, none new | **"You made it past Saltlight"** | **"Kestrel Head is 2.2 km further."** |
| Passed none | **"You flew 2.1 km"** | **"Gull Point is 1.9 km further."** |
| Within 10 % of your best, not a best (any of the above) | (the same headline) | **"Just 0.4 km short of your best."** |
| New best (any of the above) | (the same headline) | the chip on the distance; the line as per its case |
| Your first flight | (the same headline) | Passed none: **"Gull Point is 1.9 km further. You'll get there."** |
| Daily, scored | (the same headline) | + a second line **"New waves tomorrow."** Share becomes primary, and Fly again → **"Free flight"** |
| Daily, practice | (the same headline) | **"Practice doesn't count for today."** |
| Ended from the cover | **"You stopped at 4.2 km"** | the next-lighthouse line |

"Further" is always the next lighthouse's position minus the distance, rounded **up** to 0.1 km (under 1 km, metres
rounded up to 10 m: "Gull Point is 350 m further.").

### 2.3 The bird-page card (one moment, not a list)
- **New bird unlocked:** the bird art large on its sky; **"New bird: Tern"** (title); **"Level 2"** (mist); a
  secondary **"Fly as Tern"**. Tapping it selects Tern and starts a flight; Home's Birds tile then says Tern. Fixes
  tester 8's "Birds · Gull, though I just got a Tern?". It appears 0.6 s after the card.
- **Otherwise:** **"Goals"** with at most 3 rows. Each row is one line that wraps to 2 lines (never truncated), with a
  ✓ circle before it for done ones.
  - **Rule:** after a level-up the new goals shown are only the *unmet* ones. A goal already met by this flight is
    credited at once and never shown as a "new goal ✓". This fixes "Fly 3 km" right after 12.8 km.
- **Nothing to show** (no goal moved): no card. The calm bird has the page.

## 3. Glossary (plain words, applied everywhere)

| Was | Now | Where it appears |
|---|---|---|
| Outfly the storm | **Stay ahead of the storm** | Home caption, store copy, About |
| Outfly the storm. Reach the next lighthouse. | **Stay ahead of the storm. Reach the lighthouses.** | Home caption (returning) |
| tuck / Tuck & Soar (as instruction) | **fold** (Duo) / **hold** (touch). "TUCK & SOAR" stays only in the logo lockup | All instructions |
| downslope / downhill side | **the way down** | Tips, hints |
| up-face / upslope | **the way up** | Tips, hints |
| crest / trough | **top / bottom (of the wave)** | Tips |
| Perfect (noun), "11 Perfects" | **Perfect** stays as the landing's name, shown in the world; plural **"perfect landings"** | Results tip, Goals, share line |
| Perfects push the storm back | **Perfect landings push the storm back** | Tip, VoiceOver |
| ×N / chain | **"×3 in a row"** chip; Goals: **"3 perfect landings in a row"** | HUD, Goals |
| Tailwind (unexplained) | **Tailwind**, once: **"Tailwind! 3 in a row = speed boost"** | First Tailwind callout line |
| Rank 2 · Puddle Hopper / You ranked up! | **Level 2** / **New bird: Tern** (titles only on Goals, small, under the level) | Results, Goals, Home |
| Flocks / THE LADDER / REWARDS | **Goals** / **"Unlocks"** | Goals page |
| New on your route | **New lighthouse** | Lighthouse card, Results |
| Gull Point reached! | **Gull Point!** + **"New lighthouse"** chip when new | Lighthouse card |
| Everyone's sea · one try | **Same waves for everyone · 1 try** | Home Daily tile |
| Daily Flight: one try a day, same sea for everyone. Not flown… | **One try a day. Same waves for everyone.** | Results Daily row (first time) |
| Practise today's sea | **Practise today's waves** | Daily card |
| Free flight (on a Daily) | **Free flight** (kept; it's next to Share, so it reads) | Daily results |
| Leaderboards (unexplained) | **Top scores** (Game Center sheet) | Home |
| Storm behind you. Don't let it catch you. | cut (taught in school) | First flight |
| The storm caught you | **Flight over** | Caught moment |
| Lighthouse 5 / Lighthouse 6 (placeholders) | the real names, always | Route, strip |
| …and on, as far as you can fly. | **"and on…"** in its own slot (§5) | Route |
| Wings folded! / That's a tuck | cut (the world answers) | School |
| Never flap | cut (the ghost leader shows it) | School |

## 4. Consistency sheet

### 4.1 One name per concept
| Concept | The one name | Never |
|---|---|---|
| The run | **flight** ("Fly", "Fly again", "Flight over", "Your first flight") | run, go, try (except a Daily's "1 try") |
| The gesture (Duo) | **fold / open** | tuck, flap, close |
| The gesture (touch) | **hold / let go** | press, tap (except in tapping mode), tuck |
| The chaser | **the storm** | the weather, the cloud |
| The goal | **the next lighthouse**; on screen always **"Next: Kestrel Head · 15 km"**, or in the HUD the chip under a **NEXT** overline | "Fly to…", "Reach…", "Gull Point · 4 km." |
| A lighthouse passed | **"past Saltlight"** (Results), **"Gull Point!"** (in flight), ✓ (Route) | reached, made, cleared |
| The map | **Route** | logbook, coast |
| The best | **"Your best"** in sentences; **"Best 12.8 km"** as a label | record, PB |
| The landing | **Perfect** (in world), **perfect landings** (counted) | Perfects |
| A streak | **in a row** | chain, combo |
| Progression | **Level n**, **New bird / sky / trail** | rank, flock |
| The daily | **Daily Flight · 27 Oct** | Daily #n, "Daily Flight 27 Oct" without a dot |

### 4.2 Units and numbers (one formatter: `ShareText.distance`, extended)
- **Under 1 km:** whole metres, "850 m".
- **1 km and over:** **one decimal**, "12.8 km". The HUD ticks every 100 m. This removes every two-decimal value (3.94,
  12.83, 2.17, 3.83).
- **Distance flown:** rounded **down**.
- **Distance to go** (chip, "further", "Best in"): rounded **up** (2.17 → 2.2 km; 341 m → 350 m, in 10 m steps).
- **Lighthouse positions:** whole km, "15 km".
- **Typography:** a thin space before the unit; the digits always; "km" and "m" in lower case; "×3" with the true ×.
- **Share text:** the same one decimal.

### 4.3 Punctuation and case
- Words in the world (≤ 3) and titles: no full stop.
- Sentences of 4 or more words end with a full stop.
- "!" only for celebrations: "New best!", "Gull Point!", "You made it past Saltlight!" (when new), "Tailwind!".
  "Perfect" has none.
- Sentence case everywhere; overlines in caps.

### 4.4 One HUD layout
It is defined by role, and it mirrors with the bird side: the Duo default has the bird on the right, the iPhone on the
left. The frames look different because they are mirrored, not because the layout differs.
- **Bird page, top:**
  - pause at the outer corner;
  - the meter, with the storm icon at the outer end and labelled "Storm" / "You" on the first 3 flights;
  - under the meter's inner end, the **"×3 in a row"** chip (only at 2 or more).
- **Sea page, top outer corner:** the distance; under it the **NEXT** overline + the goal chip (**"‹ [lighthouse icon] Gull Point ·
  3.9 km"**, the arrow follows the flight direction); under that, "Best in 0.3 km".
- **Transient text** (lighthouse card, toasts, first-time lines): on the sea page at 40 % height (62 % if the sun is
  near). It is never within 80 pt of the bird's rect: if it would be, it moves to the other page's top band under the
  HUD.
- **Nothing else.** No teach toasts on the first flight (§1.2).

### 4.5 Deviations seen in the frames (all to fix)
1. Two-decimal distances: chip "3.94 km", caught "12.83 km", Results "12.83 km" / "2.17 km", Route "Best 12.83 km" /
   "3.83 km past Saltlight".
2. Goal phrased five ways:
   - "Reach the next lighthouse." (Home);
   - "Fly to Gull Point · 4 km." (s1-13);
   - "NEXT LIGHTHOUSE · Gull Point" (s1-15);
   - "Next: Kestrel Head · 15 km" (s1-17);
   - "Kestrel Head 15 km Next" (s1-18).
3. Storm phrased four ways (s1-11, s1-15, s1-15b, s1-16); "The storm caught you" lacks the full stop that "Fly to Gull
   Point · 4 km." has (both wrong under §4.3).
4. "STEP n OF 7" with dots; "Step 7 of 7" used for 3 messages; the dots overlap the meter (s1-12, s1-13).
5. The school card jumps from the bottom (s1-03/04) to the top (s1-05+). The pause button is absent in s1-03/04.
6. The step-1 diagram (s1-04) is frozen while "That's a tuck" shows.
7. The practice Studio shows the storm and rain (Duo s1-03, phone s1-02) before the storm is taught. A grey wave line
   is drawn over the sea in phone s1-02.
8. The first-flight toast covers the bird (s1-15 Duo and phone).
9. Results: "Reached Saltlight!" + "The storm caught you 2.17 km before Kestrel Head."; truncation ("Kestrel He…",
   "Fly 15…", "Not flown…"); new goals pre-ticked; "11 Perfects".
10. The mini route strip and the Route map run right to left on Duo and left to right on iPhone.
11. Route: "…and on, as far as you can fly." over "30 km"; "Best 12.83 km" twice; "2 lighthouses reached" (Duo) vs
    "2 reached" (iPhone); the Best chip sits on the card's top edge (iPhone); the Duo's lower half is empty.
12. Home: "Birds · Gull" next to "New bird: Tern"; "Leaderboards" labelled but the gear isn't; 4 "New" badges after
    one flight (tester 6: "shouts"). Rule: at most one "New" badge (the most recent unlock); the rest show nothing.
13. Home caption: "Outfly the storm. Reach the next lighthouse." on Duo vs "Hold anywhere. The wings fold." on the
    phone (s1-01). Both become the §3 sentence once the school is done; on a fresh install, Duo **"Hold it like a book.
    These are your wings."** / touch **"Hold anywhere. The wings fold."**
14. The Daily date: "Daily Flight 27 Oct" (Home) vs "27 Oct" (tester 9 report). It becomes **"Daily Flight · 27 Oct"**
    everywhere.

## 5. The Route map reads left to right

- **Direction:** always left → right, whatever the flight direction or bird side. The start harbour is at the left, the
  lighthouses in km order to the right, and the "you" pin faces right. The mini route strip on Results follows the
  same rule.
  - The in-flight direction (the HUD chevron) stays true to the flight: the map is a map, the HUD is a compass.
- **Layout, Duo:**
  - The title **"Route"** with Back at the top-left.
  - The map band is centred vertically at y 160–540 (no empty lower half), in Art's spacing of 150 pt per node,
    snapped so no node or label centre falls in x 447–503.
  - A slim bottom bar at y 590–650 on the bird page: **"Next: Kestrel Head · 15 km"** · **"Best 12.8 km"** · **Fly**.
  - "N lighthouses passed" is cut: the ✓s say it.
- **Layout, iPhone:** the same, with the bar docked bottom-left and Fly at its right end.
- **Labels and collision rules:**
  - Each node's label block (name, then km below) is centred under its icon, with max width = node spacing − 16 pt; a
    long name wraps to 2 lines. Names are never truncated and never "Lighthouse n": every node shows its real name,
    and nodes past the next+3 aren't drawn.
  - **"and on…"** sits in its own empty slot one spacing beyond the last node, on the name row, never under a node.
  - **The Best pin:** a "you" glyph on the route line at the best km. Its label **"Best 12.8 km"** sits *above* the line,
    between the coast and the line. If its box intersects any node label, the pin label moves below the line, and if
    that collides too, it drops to the bottom bar only.
  - **"Next" tag:** a chip right of the km ("15 km · Next"), counted inside the label width.
  - The route line passes 26 pt under the icons. Done = solid gold; to come = dashed.
- **On open:** scrolled so the next lighthouse sits at 60 % of the map width (on Duo, on the sea page side if possible;
  otherwise the snap rule wins).
- **Tests:** `routeLabelsNeverOverlap` over 7 canvases × route states 0–12 × both bird sides; `routeReadsLeftToRight`.

## 6. With the Art Director (`ART-ROUND-9.md`)

UX needs Art to define:
- the **ghost bird** (45 % white, no shadow, its own soft trail);
- the gold **fold path** that fills behind a folded bird;
- the **lift arrows**;
- the bright, pulsing **landing ring** visible from launch;
- the **mini diagram** at 96 / 72 pt;
- the calm, stormless Studio and practice sky;
- the storm roll-in with the dotted link to the meter;
- the in-world lighthouse name label;
- the "Flight over" overtaking moment;
- the in-world word style (headline on a soft glow, no panel);
- the left-to-right Route and mini strip art.

UX has cut the Faster! bar and the rhythm bar, so Art can delete them. Conflicts go here once Art's file lands.

## 7. Build list

**App:**
- **R1** School view rewrite (no card, no overline, words ≤ 3 per §1.2, dots row at the bottom, live diagram beside
  the bird, rewinds). VoiceOver keeps the full sentences.
- **R2** The caught line and the Results card per §2 (the case table as a pure function `ResultsHeadline.make(…)`,
  tested for every case); the bird-page card per §2.3; unmet-only new goals.
- **R3** The glossary strings (§3); grep for "Outfly", "downslope", "Puddle", "Everyone's sea", "Perfects", "ranked",
  "Flock", "Leaderboards", "New on your route", "Lighthouse \\(" placeholders.
- **R4** `ShareText.distance` to one decimal at ≥ 1 km (down for flown, up for to-go) on every screen, plus a test that
  scans every distance string builder.
- **R5** The HUD per §4.4: the chain chip on the bird page; transient-text placement with the 80 pt bird clearance;
  the first-flight teach line cut.
- **R6** The Route per §5, plus the mini strip left to right. **R7** Home: the captions, one "New" badge, "Top scores",
  Birds following "Fly as".
- **R8 CI frames (Duo mirrored + iPhone):**
  - school steps 1–6, each in its "ghost demo" and "your turn" phase, plus "Stay folded";
  - the clear-side ask;
  - the caught "Flight over";
  - Results for each case in §2.2 (7 frames);
  - the new-bird card;
  - Route fresh / 2 passed / 6 passed with a long name;
  - the Home returning frame.

**Core:**
- `holdAtCrest`, `rewind(to:)` and guided swells (as before).
- A **ghost** replay: the same practice-sea physics run headless with the autopilot's ideal tuck for the step, exposed
  as `practiceGhostPath(step:) -> [GhostSample(t, x, y, tuck)]`, so Scene can draw it without App logic.

**Scene:** draw the ghost from `GhostSample`, the fold-path fill (needs per-sample "folded?" from Core's step signal),
the lift arrows, the ring and the storm link.

**Feel:** the step chime, the rewind whoosh, and a soft "ghost" swish under the demo (half volume).
