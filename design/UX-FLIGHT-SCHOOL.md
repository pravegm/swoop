# Swoop: Flight School, the objective and the coherence pass (UX, Round 6, 27 Oct 2026)

*Owner: UX Lead. Implements ROUND-6 D1–D4. The look of everything named here (the phone diagram, practice sea, goal chip,
lighthouse moment and route map art) is `design/ART-FLIGHT-SCHOOL.md`; this file owns the flow, states, copy, timings
and layout. Frames reviewed: `r10/screenshots` (iPhone, R5b) and `duo6/duo-screens` (Duo, R4). Terms: the **bird
page** is the half the bird flies on (the sharp half on a Duo); the **far page** is the sea-ahead half.*

**The round's bar, restated as UI.** By the end of Flight School the player has *done* the gesture three times. They
have *seen* the storm arrive and been *told* the goal ("Reach Gull Point · 4 km"). On the first real run the goal sits
in the HUD as a chip, and every result is phrased against it.

## 0. Decisions this spec makes (flag any you overrule)

- **U1. Lighthouse names are fixed by index in every mode** (Core). Use `Lighthouses.name(index:)` = `names[index % 40]`
  with no seed, so lighthouse 1 is always Gull Point (4 km), 2 Saltlight (9 km), 3 Kestrel Head (15 km), 4 Old Harry
  (22 km)…
  - Why: a route map, "Next: Saltlight" on Home, and "0.8 km short of Saltlight" only make sense if Saltlight is a
    *place*. D3's own examples follow this order.
  - Daily seas keep their seeded swells; the lighthouse names don't change with the seed.
- **U2. Route progress is a count:** `routeReached` = the most lighthouses ever passed in one run, in any mode.
  Migration sets it from `bestMeters` (lighthouses with x ≤ best). The R3–R5 name logbook (`logbook`) is read once for
  that migration and then ignored.
- **U3. The Bird side model.** A setting `birdSide: .sharp | .left | .right` (default `.sharp` on a Duo, `.left` on
  iPhone), plus `sharpPhysical: .a | .b` (default `.a`) and `wingCheckDone: Bool`.
  - `.a` = the physical half that is on screen-right in `landscapeRight`.
  - `mirrored` becomes derived (§2); the old `mirrored: true` migrates to `.right`, false to `.sharp`.
- **U4. Existing players** (runs > 0, Flight School never seen) aren't forced into the school.
  - On a Duo the next Home shows the Wing check card once (§2.4).
  - Settings offers "Flight School · Replay".
  - The founder will see the Wing check on first launch of the new build.
- **U5. School supersedes hints.** Finishing Flight School marks `fold` and `open` learned. A skip leaves every hint
  active as the safety net. `land`, `storm` and the flat tip stay as they are.

## 1. Flight School

### 1.1 Entry, layout, chrome
- **Entry:** the first Fly ever (`progress.flightSchool == .notStarted && runs == 0`). Fly → School step 0 directly:
  no 3-2-1 and no Home pause. Daily stays hidden until run 1, as now.
- **Two layouts:**
  - **Studio** (steps 0–2): the title bird across both halves (y 10–220), body on the crease, mirroring the hinge as on
    Home. Everything you read sits on the **sharp bird page**: Art's `DuoDiagram` centred at y ≈ 335, the prompt
    panel under it at y 440–580. The far page shows only sea (it may blur).
  - **Sea** (steps 3–7): the practice sea (Core `.practice`). The bird at its usual x on the bird page. Prompt panel on
    the bird page at y 0.22 h (Art §6; there's no lead meter in school). In step 3 a 120 pt mini `DuoDiagram` sits
    under the prompt; it's hidden from step 4.
- **Prompt panel:** overline **"FLIGHT SCHOOL · STEP n OF 8"** (Duo; 7 steps on touch, where the Wing check is skipped),
  then the prompt (`headline` 22 / 19, ≤ 2 lines, max 380 pt), then an optional sub-line (body, mist). Art's `surface`
  0.55 scrim. Never in the fold band.
- **Progress:** Art's 8 (or 7) step dots, top centre of the bird page, y 28.
- **Skip:** a tertiary **"Skip"** (44 pt, mist) at the far page's bottom outer corner.
  - It's hidden in step 0 and appears once step 0 succeeds.
  - Tap → straight into a real Flight with the full 3-2-1. No confirmation: it's always one tap and fully reversible
    from Settings.
  - Sets `.skipped(atStep: n)`.
- **Pause:** the pause button (top outer corner of the bird page) works in the Sea steps. The Pause card in school
  reads **"Paused · Flight School"**, with Resume · **Skip Flight School** · Home. Resume rewinds to the current
  step's checkpoint.
- **Time:** the Sea runs at 0.8× (Core). Steps can set 0.5× locally (noted per step).
- **Every success:** Feel's step chime + a light haptic. The prompt swaps to a gold **"✓ {praise}"** for 0.8 s, then a
  0.4 s crossfade to the next step.
- **A prompt is up ≥ 1.2 s before its success can count,** so the line is read before the moment passes. An early
  success is held and credited at 1.2 s.

### 1.2 Steps (Duo hinge copy | touch copy)

| # | Prompt (Duo / touch) | Sub-line and live feedback | Success (needs ≥ 1.2 s on screen) | Praise | Failure, help, retry | Typical |
|---|---|---|---|---|---|---|
| **0 Hold** | "Hold your Duo open like a book." / "Turn your iPhone sideways." (on iPhone this step auto-passes if already landscape) | The diagram shows the live angle. Contextual sub-lines replace each other: ≥ 174° **"A little less than flat."** · < 110° **"Open it wider."** · portrait canvas **"Turn it sideways."** | Landscape inner canvas, hinge 110–172°, still (≤ 1.5° spread over 0.5 s; Feel's `isStill`) | "Perfect grip." | No timeout. After 10 s a secondary **"Play with touch instead"** appears; it switches to the touch variant from step 1. | 2 s |
| **1 Wings** | "These are your wings. Fold a little…" / "These are your wings. Press and hold anywhere…" | The title bird tucks with u; the diagram's halves move. At u ≥ 0.4 the sub-line becomes **"…and open again."** / **"…and let go."** | One full tuck: u ≥ 0.8 held 0.2 s, then u ≤ 0.2 | "That's a tuck." | < 95° (closing): **"Not that far. Just a little."** (no closing card in Studio). No movement for 6 s: the diagram loops the gesture and the sub-line reads **"Fold both halves in a little, like a book a third shut."** | 4 s |
| **2 Wing check** (Duo hinge only) | §2.2 | §2.2 | One tap | "Got it." | §2.2 | 8 s |
| **3 Dive** | "Hold the fold all the way down the wave." / "Hold the screen all the way down the wave." | The bird **waits on the crest** until u ≥ 0.6 (Core `holdAtCrest`), then descends. Art's fold-path ribbon glows down the slope, and the **Faster!** capsule (Art: 46 pt above the bird, riding with it) fills with speed; speed lines draw. | Core `diveDone(heldFraction ≥ 0.7)` at the trough | "Feel that speed?" | `heldFraction < 0.7` → at the trough time drops to 0.5× for 0.6 s, the prompt turns **"You opened too soon. Keep it folded to the bottom."**, then Core rewinds to the crest checkpoint (0.4 s fade). After 3 failures: **"Good enough. Let's fly."** and continue. | 5 s |
| **4 Soar** | "Open at the bottom… and fly!" / "Let go at the bottom… and fly!" | Slow motion 0.5× from the trough until 0.4 s after launch, back to 0.8× over 0.3 s. While u > 0.3 on the up-face: **"Open now!"** pulses. | `launched` with u ≤ 0.3 | "Lift-off!" | No launch (still tucked at the crest, so it rolls over flat): **"Open your wings to take off."**, rewind to the trough. 3 failures → continue. | 3 s |
| **5 Land** | "Land on the next downslope: Perfect!" (both) | A dotted landing ring (Art) on the guided downslope. Core's guided swell + strong landing assist. In the air: **"Fold to drop sooner, open to float."** | A Perfect touchdown | "Perfect!" (the real Perfect callout + ring + chime) | Good landing: **"Close! Aim for the ring."**; splash: **"Splash! Aim for the downslope."** Each miss → the next guided swell (Core `nextGuidedSwell`). 3 attempts → **"Perfects come with practice."** and continue. | 4 s |
| **6 Rhythm** | "That's it: **one fold per wave. You never flap.**" → after 2.5 s "Fold down, open up." / "That's it: **one hold per wave. No tapping.**" → "Hold down, let go up." | A rhythm bar under the bird (Art): per wave, a gold "fold" span over the downslope and a pale "open" span over the up-face; the cursor colours with u. Per wave: ✓, or a nudge **"Fold on the way down"** / **"Open on the way up"**. | Core `waveDone(index: 2)`, i.e. 3 waves flown, whatever the quality | "You've got the rhythm." | None (it always advances). | 9 s |
| **7 Storm** | "A storm is chasing you out to sea." (2.2 s) → "Stay ahead of it: Perfects push it back." (2.2 s) → "Reach the first lighthouse: **Gull Point · 4 km**." (2.2 s) | The storm rolls in from the behind edge (Scene, no catch). On the third line the goal chip flies in on the far page (§4.2). Time ramps to 1.0×. | Timed | — | — | 6.6 s |
| **→ Run** | — | Fade the practice sea (0.4 s). A real Flight with the **1.5 s "Ready · Go"** (calibration done). On Go: the HUD with the goal chip, plus the first-run line under the meter **"Storm behind you. Don't let it catch you."** for 3 s. | — | — | — | — |

- **Total:** about 41 s typical (Duo), 33 s (touch).
- **Practice sea** (Core): crest A → one long downslope (≥ 1400 pt, slope ≤ 0.7) → trough → up-face that launches
  cleanly at u ≤ 0.3 → guided downslope with the ring → 3 rhythm waves (λ 700 pt) → open sea for step 7.
  - There is no storm, no score and no distance.
  - Until step 7 the HUD shows only the pause button (a quiet 44 pt `surface` disc), because school needs a way out;
    no meter, chip or distance. Art's step 7 fades the meter and the chip in at +1.6 s.

### 1.3 Variants
- **Touch** (every iPhone; a Duo with Play with touch, tapping mode or the step-0 escape): the right-hand copy above,
  with step 2 skipped ("OF 7").
  - The diagram shows a thumb pressing (Art).
  - Tuck by tapping: step 1 "Tap to fold… tap again to open." Step 3 "Tap, and stay folded all the way down." Step 4
    "Tap again at the bottom… and fly!" Step 6 "One tap down, one tap up, per wave."
- **VoiceOver:**
  - Every prompt is posted as `.announcement`, prefixed "Flight School, step 3 of 8." Sub-lines are announced when they
    change, at most 1 every 2 s. Praise is announced as "Done. That's a tuck."
  - The diagram is an element: "Your Duo, open about 140 degrees."
  - Step 1 adds: "With VoiceOver, you can also swipe down on the wings to fold, and up to open." The adjustable
    **Wings** element exists in every input mode while VoiceOver runs.
  - Step 2's buttons are labelled "The left half stayed sharp", "The right half stayed sharp" and "Not sure, skip".
    Focus starts on the prompt.
  - Skip is reachable as a normal button.
- **Reduce Motion:** the rewinds are a 0.3 s crossfade. Slow motion is kept (it's time, not motion). No diagram loop;
  the diagram shows a still "folded a little" pose with an arrow.

### 1.4 Interruptions, persistence, replay
- **Closing (< 95°) in the Sea steps:** the standard closing card ("Open your wings to keep flying"); on reopen, the
  Ready ring, then a rewind to the current step's checkpoint.
- **Shut / cover:** **"Flight School paused" / "Open your wings to carry on."**
- **Background:** pause, as in a run.
- **Kill mid-school:** the next Fly restarts at step 0. If `wingCheckDone`, step 2 is skipped (the dots still count 8,
  with step 2 pre-filled gold).
- **Persistence** (`ProgressData`): `flightSchool: .notStarted | .skipped(atStep: Int) | .done`. "Reset progress"
  resets it to `.notStarted` but keeps `birdSide` and `sharpPhysical` (settings, not progress).
- **Replay:** Settings → **"Flight School" / "Replay the 45-second lesson"** → step 0.
  - Step 2 on replay shows **"Currently: right half."** with **[Keep]** beside the two side buttons.
  - The replay ends like the first time (step 7 → a real Flight), because the lesson ends in the air.
  - Its result counts as a normal Flight.

## 2. The Wing check and Bird side (D1)

### 2.1 Model (App + Feel)
- **Orientation:** `o = windowScene.interfaceOrientation` (`.landscapeLeft` or `.landscapeRight`).
- **Sharp screen side:** with `pR = (o == .landscapeRight)`, `sharpSide = (sharpPhysical == .a) == pR ? .right : .left`.
- **Bird screen side:** `.sharp` → `sharpSide`; `.left` → left; `.right` → right. `mirrored = (birdScreenSide == .right)`.
- **Recording an answer:** "This side →" given in orientation `o` sets `sharpPhysical = pR ? .a : .b`; "This side ←"
  sets the opposite.
- **180° turn:**
  - Between runs: re-lay out at once.
  - During a live run: pause and re-lay out, then the 1.5 s Ready ring (the bird hops halves while time is stopped).
    Log `SWOOP-T birdside <left|right> physical=<a|b> o=<L|R>`.
- **iPhone (no hinge):** the Wing check is never shown. Settings offers "Bird side: Left · Right" (default Left).

### 2.2 Step 2 UI (also the standalone check)
The blur can hit either half, so the instruction is printed **on both halves** (same text, centred in each page). One
copy is always sharp.

| Phase | Both halves show | Advances when |
|---|---|---|
| a. Explain | Headline **"One quick check."** Body **"iPhone Duo softens one half of the screen for a moment when it starts to fold from flat."** Then **"Open your Duo flat…"** (gold). The mini diagram on the fold (Art) shows one half going soft. | ≥ 174° held 0.5 s |
| b. Fold | **"…now fold it a little."** | The hinge drops ≥ 8° below its flat reading (≤ 166°) |
| c. Ask | Headline **"Which side stayed sharp?"** Each page becomes **one full-page tappable card** (Art AP2: test pattern + outward arrow), labelled **"This side ←"** (left page) / **"This side →"** (right page). The whole card is the hit area. A tertiary **"Not sure · skip"** sits at the bottom of the *default bird page* (y = h − 40, centred in that page). **Not centred on the canvas: x 475 is the fold band.** | One tap |
| d. Confirm | **"✓ Got it. Your bird flies on the sharp side."** The title bird glides (0.6 s) onto the chosen half and settles. | 1.2 s |

- **No flat within 10 s of phase a:** the sub-line **"Open it all the way flat, just for this check."** and the skip
  link becomes a 56 pt secondary.
- **Skip / Not sure:** keeps the default (`.a`), `wingCheckDone = false`, and moves on with **"No problem. You can check
  it in Settings."**
- **Answer:** `wingCheckDone = true`, `birdSide = .sharp`.
- **Phase c stays up until a tap.** Re-folding is harmless.

### 2.3 Settings, "Bird side" (Controls card, first row on a Duo)
- A segmented control: **Sharp side · Left · Right** (Duo); **Left · Right** (iPhone).
- Footnotes:
  - Sharp side, checked: **"Your bird stays on the half that doesn't blur when you fold. Now: right half."** + a
    tertiary **"Check again"** (runs §2.2 standalone; Done returns to Settings).
  - Sharp side, unchecked: **"Using the usual sharp side (the right half, held this way up)."** + **"Check now"**.
  - Left / Right: **"The bird always flies on the left half."** / **"…on the right half, flying right to left."**
- This **replaces** the "Bird on the other side" toggle (cut).
- Below it: the **"Flight School"** row (§1.4).

### 2.4 Existing Duo players (U4)
On the first Home after updating (runs > 0, `wingCheckDone == false`), once: a card on the bird page reading **"Which
half stays sharp when you fold?" / "Your bird should fly on that half."** with **[Check now]** (primary) **[Not now]**.
Not now never asks again; Settings keeps the way in.

## 3. The flat-open tip (D1.4)
- **Feel:** full spread at the calibrated open angle (u = 0 at θ ≥ θ_open), so flat adds nothing. Count openings that
  reach ≥ 174° per run (hysteresis: re-arm below 166°).
- **App:** on the 3rd such opening in a run, at most once per app session, and never during the 2.2 s blur guard
  (queue it), show at the bird page's hint slot for 4.0 s a 2-line pill: **"Tip: no need to open flat."** / **"A slight
  fold is wings fully spread (and keeps the screen sharp)."**
  - It **replaces** the R3 "Keep a little bend" hint (cut, so one message, one rule).
  - Home's flat caption and the countdown's flat hold stay.
  - Flight School teaches it in step 0 ("A little less than flat.") and step 2.

## 4. The objective (D3)

### 4.1 One sentence everywhere
**"Outfly the storm and reach the next lighthouse."** It appears as:
- the Home caption once the school is done (replacing "Hold to dive. Let go to soar." for returning players);
- the App Store subtitle text (Store owner);
- Settings → About, first line;
- the Pause card sub-line on the first 3 runs.

### 4.2 Goal chip (HUD, far page)
- **Place:** the far (sea) page's top outer corner stacks distance → **goal chip** → "Best in" (Art: chip at (32, 84)
  on Duo and (82, 70) on iPhone; capsule 40 / 34 pt, not tappable).
  - The chain / Tailwind pill **moves to the bird page**, under the meter's inner end (Art AP8: Duo x 520, y 64), because
    it pushes the storm back. The Daily tag goes under the meter's outer end.
  - The sea page then carries only *where* (distance, goal) and *how close to the best*. The bird page carries *now*:
    meter, chain, hints.
  - Ask to Art: hold the distance at ≤ 40 / 32 pt so the chip reads as its peer (Art's `hud` is 46 / 36; Art decides).
- **Copy:** **"← Gull Point · 1.2 km"**. The arrow points the way you fly (← when mirrored, → otherwise), and the
  distance uses `ShareText.distance(roundUp: true)`: "850 m" under 1 km.
  - The small lighthouse icon scales from 0.8× at ≥ 3 km to 1.25× at 0.
  - VoiceOver: "Next lighthouse, Gull Point, 1.2 kilometres."
- **States:**
  - normal (navy surface, foam text);
  - **near** (< 300 m): gold text and a 1 Hz glow;
  - **reached**: a gold fill for 0.6 s, then it slides out and the next one ("← Saltlight · 5.0 km") slides in from the
    outer edge;
  - **caught**: frozen at its last value, which the Results headline reuses verbatim;
  - countdown: hidden;
  - first real run: an overline **"YOUR GOAL"** above the chip for the first 5 s.
- **The lighthouse ahead** (Scene): the next tower is drawn on the far horizon from 1.5 km out and grows, so the chip
  points at something visible.

### 4.3 Lighthouse reached
At Core's `lighthouse` event (the bird crosses the tower's x):
- 60 ms hit-stop, the bell, and the beam sweeping across the far page (Art).
- A far-page card (Art §4: y 0.40 h; it moves to 0.62 h if the sun is within 160 pt, `AppRules.stageCenter`):
  **"Gull Point reached!"** (title) / **"Lighthouse 1 · the storm falls back"** (body). If `index ≥ routeReached` (new),
  add the gold chip **"New on your route"**.
- At 1.9 s the card shrinks into the goal chip, which rolls to the next lighthouse (Art). This replaces the 2.8 s hold.
- VoiceOver: "Gull Point reached. New on your route."
- The km-toast suppression stays.

### 4.4 Route map (new route `.route`, replacing the logbook)
- **Bird page:**
  - title **"Route"** (back button);
  - a summary card: **"3 lighthouses reached"** / **"Best 16.2 km"** / **"Next: Old Harry · 22 km"** / **"5.8 km past
    your best"** (mist);
  - a primary **"Fly"** (56 pt) at the bottom.
- **The map:** Art's horizontal sea-chart strip across both pages (art may cross the fold; no label, pin or icon centre
  in the band), running in the flight direction from the harbour (storm glyph) at the bird-page end. On open it is
  scrolled so the next lighthouse is centred on the sea page. UX rules for the labels:
  - reached: lit icon, name, km, ✓;
  - **next**: the next-state icon, the name, km and a **"Next"** tag;
  - your best: the "you" pin, labelled **"Best 16.2 km"**;
  - the one after next: name and km in haze;
  - beyond that: **"Lighthouse 6 · 38 km"** with no name (names are revealed by reaching them).
  - The strip ends 3 nodes past the next one, with **"…and on, as far as you can fly."**
- **Entries:** the Home tile **"Route"**; Results' **"Route ›"** link at the end of the hook line; the Goals page footer
  "See your route ›".
- **Fresh** (`routeReached == 0`): the summary reads **"No lighthouses yet"** / **"Next: Gull Point · 4 km"**; the map
  shows Gull Point as next.

### 4.5 Home "Next"
- **Fly subtitle:** **"Next: Saltlight · 9 km · best 6.42 km"**. Fresh: **"Next: Gull Point · 4 km"**.
- **Overflow:** if it exceeds the button's width at the caption size, drop " · best …" first, then shorten "Next:" to
  "→". It's never truncated with an ellipsis.
- **Menu rows:** Fly (76) · Daily (62) · **Goals | Route | Birds** (three 58 pt tiles).
  - On iPhone the tiles are icon + one word, with no detail line.
  - On Duo: Goals "1 of 3 done", Route "3 reached", Birds the bird's name.

### 4.6 Results lead with the objective
Far card order: overline → Art's **mini route strip** (56 pt: last reached → you → next) → **objective headline** →
distance hero → best line → **"Next time" tip** → stats → buttons.

- **Objective headline** (headline size, foam; gold when reached), using the chip's frozen value:
  - reached ≥ 1 this run: **"Reached Kestrel Head!"**, with **"Caught 2.1 km short of Old Harry"** under it in body;
  - reached none: **"Caught 0.8 km short of Saltlight"**;
  - if the run made the route longer: a chip **"New on your route"** next to the headline.
- **Best line:** "New best!" chip / "Best 9.40 km" (as now).
- **"Next time" tip** (body, mist), the first rule that applies:
  1. the first real run → **"Land Perfects to push the storm back."**;
  2. perfects = 0 → **"Next time: land on a downslope for a Perfect."**;
  3. splashes > perfects → **"Next time: open on the way up, so you come down on a downslope."**;
  4. bestChain < 3 → **"Next time: 3 Perfects in a row = a Tailwind."**;
  5. otherwise **"Next time: chain Perfects to push the storm back."**
- **Within 10 % of the best:** the best hook ("0.4 km short of your best") replaces rule 5 only.
- **Bird-page card:** the goal rows, as now (they need the room). A rank-up is no longer a second banner card but the
  card's header chip (Art): **"3 goals done! New bird: Tern"**, then **"Rank 2 · Puddle Hopper"** (mist) and the "New
  goals" line. "New in the logbook" is cut (the headline chip carries it).
- **Daily:** the headline is the same; the overline stays "DAILY FLIGHT #n".

## 5. D4 coherence audit (every screen)

Each row: **R** = rename, **C** = cut, **E** = first-time explanation (shown once, stored in `learnedHints`).

| Screen | Change |
|---|---|
| Home | **R** the Fly subtitle becomes "Next: …" (§4.5). **R** the gamepad/trophy corner icon gets a visible label "Leaderboards" on Duo. **C** the gold dots on tiles (unexplained) → a small "New" capsule until the tile is first opened. **R** the Goals detail "1 of 3 · Crest…" (truncated) → "1 of 3 done". **E** the returning caption is the §4.1 sentence. |
| Countdown | Unchanged copy. **C** the touch line on a Duo flown by hinge. It moves to the bird (sharp) page, as Art #13 asks. |
| Meter | Art's coral end zone replaces the red tick. **E** label it for the first 3 runs: **"Too close"** in 12 pt caption under the zone, next to "Storm" / "You". |
| Icons | Art #4/#5 adopted: Goals uses `checklist`, Route the lighthouse icon; no race flag, no SF dove; the side-view "you" glyph for the player. |
| HUD | **E** the storm line on the first real run (§1.2). **R** the meter's "Storm" / "You" labels show on the first 3 runs (was 1). **E** the first chain ≥ 2: the pill reads **"✦ ×2 in a row"** for that run, then "✦ ×2". **E** the first Tailwind ever: callout "Tailwind!" + a bird-page teach line for 3 s, **"Tailwind! 3 Perfects in a row = a burst of speed."** **C** "Keep a little bend" (→ §3). **C** km toasts except 5 km steps (as now). |
| Lighthouse card | **R** to §4.3. |
| Splash | Keep "Splash · ×4 lost". **E** the first splash already teaches "Land on the way down". |
| Pause | **R** the sub-line "2.12 km · the storm waits." → **"2.12 km · Gull Point in 1.9 km"**. On the first 3 runs a second line gives the §4.1 sentence. |
| Results | §4.6. **R** the overline "FLOCK GOALS" → "GOALS". **C** "New in the logbook". **E** the first time the Daily row appears: **"Daily: everyone flies the same sea today. One scored try."** as its sub-line. **E** the first results ever: under the hook, **"Every lighthouse you reach goes on your Route."** |
| Goals | **R** "THE LADDER" → **"REWARDS"**. **E** under the rank card: **"Finish 3 goals to earn the next bird, sky or trail."** The rank titles stay as flavour, never as a header alone (always "Rank 2 · Puddle Hopper"). **C** any remaining "Flocks" string (`grep -ri flock Swoop/UI`). The footer "See your route ›". |
| Route | New (§4.4). |
| Birds | Keep "Every bird flies the same." **R** locked tile "Rank 2" → **"Rank 2 goals"**. |
| Daily card | Keep. **E** the first open: the sub-line "Everyone flies this sea today. Come back tomorrow for a new one." |
| Settings | **R** "Bird on the other side" → **Bird side** (§2.3). **New** row "Flight School · Replay". **R** About first line → §4.1 sentence. The settings frame `r10/settings.png` is a blank portrait capture: CI fix (§7). |
| Cover | Mid-run: add **"Gull Point in 1.9 km"** under the distance. School: §1.4 copy. |
| Pose / TurnCard | Keep. |
| Store / About | The framing sentence (Store owner). The "Made for iPhone Duo. Here, hold to tuck." line stays. |

**Cut list summary:**
- "Bird on the other side";
- "Keep a little bend";
- the gold dots;
- "New in the logbook" and the logbook section on Goals (→ Route);
- "THE LADDER";
- "FLOCK GOALS";
- seeded lighthouse names.

## 6. Hand-off

**App** (Swoop/UI, Swoop/App):
- **S1** the `FlightSchool` pure state machine (like `HintCoach`, tested). Inputs per frame: canvas pose, hinge
  (angle, u, still), touch, Core practice signals, time. Outputs: step, phase, prompt key, sub-line key, praise, and
  `requestRewind` / `requestTimeScale`.
- **S2** the Studio and Sea layouts (`SchoolLayout`, fold-clear tests on the 7 canvases, both bird sides).
- **S3** the Wing check views (§2.2) as a standalone route and step.
- **S4** Bird side: `SettingsData.birdSide`, `sharpPhysical`, `wingCheckDone`, the migration, derived `mirrored`, the
  orientation observer and the live re-layout.
- **S5** Settings rows. **S6** the §2.4 card. **S7** the flat tip.
- **S8** goal chip, lighthouse card, Home "Next", Results framing and tips, the rank-up copy.
- **S9** the Route page. **S10** the §5 copy changes. **S11** ProgressData `flightSchool` and `routeReached`, plus the
  migration.
- **S12** the demo keys and scenarios (§7).

**Core:**
- **K1** `RunMode.practice`: no storm, no score; `timeScale` (default 0.8, settable); the scripted sea (§1.2);
  checkpoints `crestA / trough / guided(n) / rhythm`, with `rewind(to:)` and `holdAtCrest(untilTuck: 0.6)`; and events
  `.practice(.diveDone(heldFraction:))`, `.practice(.waveDone(index:))`, `nextGuidedSwell()`.
- **K2** U1 fixed lighthouse names. **K3** `routeReached` helpers (lighthouses at or before x).

**Feel:**
- **F1** `isStill` for step 0. **F2** full spread at θ_open (no gain past it). **F3** the ≥ 174° opening counter with
  re-arm at 166°.
- **F4** cues: the step chime, praise haptic, rewind whoosh, the lighthouse-reached bell + 60 ms hit-stop, the
  goal-near tick at 300 m.
- **F5** the sharp-half physical mapping helper (shared with App S4).

**Scene:**
- **N1** the practice sea look and the landing ring. **N2** the storm roll-in for step 7, with no catch.
- **N3** the next lighthouse drawn ahead from 1.5 km. **N4** the reached beam. **N5** route-map art helpers.
- **N6** polish for the mirrored default (Art owns the composition rules).

## 7. CI scenarios (new demo keys)

**Keys:**
- `school=<step>[:<phase>]` (steps 0–7 / `hold wings wingcheck dive soar land rhythm storm`; phases `fail`, `done`,
  `ask`, `explain`, `fold`, `confirm`);
- `schoolTouch`, `schoolTap`;
- `birdSide=sharp|left|right`, `sharp=a|b`, `orient=landscapeLeft|landscapeRight`;
- `flatTip`;
- `screen=route`;
- `goalNear`;
- `resultsFrame=caught|reached|newroute|first`;
- `existingPlayer` (the §2.4 card).

Each frame logs `SWOOP-T school <step> <phase>` / `SWOOP-T birdside …`.

| # | Scenario | iPhone (r) | Duo (default sharp = right) |
|---|---|---|---|
| 1 | `school=hold` (+ `flat` → "A little less than flat") | ✓ (turn copy) | ✓ ×2 |
| 2 | `school=wings` at u 0.5, and `school=wings:done` | ✓ (touch) | ✓ ×2 |
| 3 | `school=wingcheck:explain` / `:fold` / `:ask` / `:confirm` | — | ✓ ×4 (+ `orient=landscapeLeft` ask) |
| 4 | `school=dive` (on the crest; mid-slope with the Faster! bar) | ✓ ×2 | ✓ ×2 |
| 5 | `school=dive:fail` ("You opened too soon") | ✓ | ✓ |
| 6 | `school=soar` (0.5×, "Open now!") | ✓ | ✓ |
| 7 | `school=land` (ring) and `school=land:fail` (splash copy) | ✓ ×2 | ✓ ×2 |
| 8 | `school=rhythm` (rhythm bar, wave 2) | ✓ | ✓ |
| 9 | `school=storm` (each of the 3 lines) | ✓ ×3 | ✓ ×3 |
| 10 | The first real run at Go: storm line + "YOUR GOAL" chip | ✓ | ✓ |
| 11 | School pause card; skip → the countdown frame | ✓ | ✓ |
| 12 | `schoolTap` step 1; VoiceOver is checked in the AX audit (no frame) | ✓ | — |
| 13 | Goal chip mid-run, normal and `goalNear` | ✓ ×2 | ✓ ×2 |
| 14 | `freezeOn=lighthouse` new card ("reached!" + "New on your route") | ✓ | ✓ |
| 15 | Chip after the pass ("→ Saltlight · 5.0 km") | ✓ | ✓ |
| 16 | `resultsFrame=first` / `caught` / `reached` / `newroute` | ✓ ×4 | ✓ ×4 |
| 17 | Results rank-up copy ("3 goals done! New bird: Tern") | ✓ | ✓ |
| 18 | `screen=route` fresh / mid / late | ✓ ×3 | ✓ ×3 |
| 19 | Home fresh / returning (Next line, 3 tiles, New capsule) | ✓ ×2 | ✓ ×2 |
| 20 | `flatTip` pill | — | ✓ |
| 21 | Settings Bird side (unchecked / checked / Right) + the Flight School row; fix the blank portrait capture: wait for a landscape canvas | ✓ | ✓ ×3 |
| 22 | `existingPlayer` Wing check card on Home | — | ✓ |
| 23 | `birdSide=sharp sharp=a orient=landscapeLeft`: the bird on the LEFT (physical tracking) | — | ✓ |
| 24 | Pause with the goal line; cover mid-run with "Gull Point in 1.9 km"; cover "Flight School paused" | ✓ ×1 | ✓ ×3 |
| 25 | First chain "×2 in a row"; first Tailwind teach line | ✓ ×2 | ✓ |

The tester walk (ROUND-6 Verification) uses frames 1→10 in order, then 13, 14, 16-caught, 16-reached and 18.

## 8. Reconciled with `ART-FLIGHT-SCHOOL.md`

Art's six assumptions, answered:
1. **Prompt and diagram on the bird page:** yes, in steps 0–3 (§1.1). The title bird spans both pages in steps 0–2.
2. **The chain / Tailwind chip moves to the bird page:** adopted (§4.2).
3. **The goal chip under the distance, with a flight-direction chevron:** adopted. The chip is 40 / 34 pt and not
   tappable, so my earlier "≥ 44 pt" is withdrawn.
4. **Results lead with the mini route strip, and rank-up becomes a chip:** adopted. The bird-page card keeps the goal
   rows (§4.6).
5. **Wing check as one full-page card per half:** adopted. **One change:** "Neither / skip" can't sit at canvas centre
   (x 475 is the fold band). It goes at the bottom of the default bird page (§2.2).
6. **The coral end zone's one-time label:** "Too close" (§5).

Also adopted from Art:
- the Faster! capsule and the rhythm bar ride with the bird;
- the reached card at y 0.40 h, shrinking into the chip at 1.9 s;
- the horizontal route strip;
- the countdown on the bird page;
- the `checklist` and lighthouse icons.

Still open:
- **Distance size:** UX asks for ≤ 40 / 32 so the goal chip reads as its peer; Art decides.
- **Pause in school:** UX keeps a quiet pause button in steps 3–6 (Art said "no other HUD"), because the player needs
  an exit path.
