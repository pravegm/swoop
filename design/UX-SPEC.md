# Swoop: UX spec (Round 3, 26 Oct 2026)

*Owner: UX Lead. Scope: flows, layout, hierarchy, copy. The look (type, colour, materials, component styling) is `design/ART-DIRECTION.md`.
Sources: GAME-DESIGN §3/§8–§10, REVIEW-1, QA-2, app-R2, the UI code, Brim research 02-hinge-tech, 27 iPhone 18 Pro frames (`r3`), Duo frames `duo1`/`duo2`
(R1) and `duo3` (R2, 29 frames). Apple's "Design for iPhone Duo" talk: controls at the outer edges, interactive elements off the hinge, no per-pose
custom layouts. Pattern research: Alto, Tiny Wings, Threes, Mini Metro, Downwell, Desert Golfing, Wordle.*

**Canvases (pt).**
- **Duo book:** 951 × 669, fold band x 456–496. Content pages (Art's margins: 32 from the outer edge, 24 from the band) are x 32–432 and
  520–919.
- **iPhone 874 × 402:** the fold maps to x 419–455. Pages 82–403 and 471–792 (20 pt + the 62 pt island inset).
- **iPhone 667 × 375:** fold 319–347; pages 20–303 and 363–647.
- **Duo cover:** 466 × 678 portrait; camera cut-out at the top right (keep x > 390, y < 80 clear).
- **Duo seated:** 669 × 951, horizontal band y 456–496.

"Bird page" = left (right when mirrored); "far page" = the other.

## 1. Principles

1. **The fold is the button.** In book pose both thumbs grip the outer edges of a 254 g phone, so lifting a thumb to mid-half is the dearest move.
   Primary actions live at the far page's lower outer edge, and on a Duo the busiest one ("Fly again") can be done with the wings: fold and open.
2. **Teach by doing, one idea at a time.** Six words or fewer, at the moment of need, each prompt retired by success rather than a timer. The title
   bird mirroring your fold *is* the tutorial. No text pages (Threes and Mini Metro make you play first).
3. **Each half has one job.** The bird page is *now*: you, the storm, the lead meter, pause, hints, Perfect. The far page is *next*: distance,
   toasts, menus, results. Nothing interactive or legible goes in the fold band, and only art (the title bird, the sea) spans it.
4. **Death is a comma.** Caught → flying again takes one tap (none on a Duo) and under 1 s from that input (Tiny Wings, Downwell). Every result
   names one near miss and one goal, so the next go is *about* something.
5. **Calm, honest, uncluttered.** A HUD element earns its place only if it changes what you do in the next 3 s. No zeros, no duplicates, no wall of
   locks, no nagging; a quiet daily ritual instead (Wordle, Desert Golfing).

## 2. The first 60 seconds

**Duo, fresh install, book pose.** If it is opened shut, the cover shows "Open your wings / Your first flight is waiting."

| t (s) | What happens | Text (where; when it leaves) |
|---|---|---|
| 0.0 | Launch screen (navy, bird glyph). | — |
| 0.4 | Home settles in (0.35 s). Attract flight behind; title bird across both halves, wings live from the hinge. **Fresh Home shows only Fly** and the 2 corner icons. | Bird page, under the wordmark: **"Hold your Duo like a book. These are your wings."** Leaves on the first fold. |
| any | ≥ 175° (flat) for 1 s (fold-blur risk, §9). | Caption: **"Bend it a little, like a book."** Leaves when the hinge is at 130–170° for 0.5 s. |
| ~2–5 | First fold ≥ 18°: the title bird sweeps into a dart with the hinge; soft wind swell (Feel). | Crossfade (0.4 s) to **"Fold to dive. Open to soar."** (gold-light). Stays. |
| ~5 | First full stroke (fold, then reopen to u ≤ 0.2): Fly glows once (0.6 s). No auto-start. | — |
| ~6 | Tap **Fly** (right thumb, lower outer edge). Menu and caption fade (0.25 s); the title bird morphs into the play bird (0.6 s; crossfade until Scene S3). HUD fades in. | — |
| 6.3–9.3 | 3-2-1, far page centre (the hinge calibrates). It holds on "3" while ≥ 175°, for 4 s at most. | Under the numeral: **"Wings open, hold steady"** (flat: **"Bend it a little, like a book"**). Leaves at Go. |
| 9.3 | Drop onto the long intro downslope. | Bird page, y 62 %: **"↘ Fold on the way down"**. Success (u ≥ 0.6 on a downslope for 0.3 s) → a gold **"✓"**, gone 0.6 s later. If it isn't done in 4 s, it repeats on the next downslope (3 times at most). |
| ~11 | Climbing the next face. | **"↗ Open on the way up"**. Success = a launch with u ≤ 0.3 → "✓". |
| ~12.5 | Guaranteed Perfect on the intro swell: ring, chime, haptic, 35 ms hit-stop. | **"Perfect"** anchored to the bird (A1), 0.7 s. |
| 13–40 | Free play. A splash before any Perfect: | once ever, **"Land on the way down"** (3 s, or until the next Perfect). |
| ~25 | Chain 3 = Tailwind. | The callout says **"Tailwind!"**; the pill becomes "✦ ×3 · TAILWIND". |
| storm-close | Lead < 15 %: thunder, the meter pulses. Once ever: | under the meter, **"Perfects push the storm back"**, 2.5 s. |
| ~50–60 | Caught: rain sweeps over, the bird bobs, the HUD fades except the distance. After 0.6 s a tap or a fold skips ahead. | — |
| +2.0 | The results card slides in from the far page's outer edge (0.35 s). | §3 Results, first-flight state. |
| next | **Fold and open** (Fly again fills with the fold) or tap → 1.5 s "Ready · Go" → flying. Only unlearned hints show. | Under Fly again, on the first 5 results only: **"or fold and open"**. |

**Regular iPhone, fresh install.** In portrait, §10. Then the same beats with touch words:
- caption **"Press and hold the bird. That's a tuck."** → **"Hold to dive. Let go to soar."**;
- countdown line **"Hold to dive · let go to soar"**;
- hints **"↘ Hold on the way down"**, **"↗ Let go on the way up"**, **"Land on the way down"**.

The title bird is the practice pad (0.12 s in, 0.10 s out). Fly again is the tap.

## 3. Information architecture and screens

`Home` → Fly → Play (⇄ Pause) → Results → {Fly again · Daily · Share · Home}. `Home` → Daily (a countdown banner, or the Daily card once flown) · Goals ·
Birds · Settings · Leaderboards (the Game Center sheet). Pose states (§9) sit above everything and return you where you were. Depth is ≤ 2.

**Home.** Purpose: the bird is your phone; start in one tap. Eye order: title bird → Fly → caption.
- **Duo:** bird y 10–264 across the band (art only). Bird page: wordmark at y 276, caption under it; Settings and Leaderboards icons (56 pt tap) at the
  lower outer corner. Far page, bottom-aligned at y 653, right-aligned, 368 wide: Fly 76, Daily 62, Goals | Birds 58.
- **iPhones:** the same, with buttons ≥ 56 pt and the caption 2 lines at most. On Duo the attract run stays below y 62 % so it never crosses the caption
  (duo3 home-tucked: the bird and spray cut through "Fold to dive").
- **Copy.** Fly **"Fly" / "Outfly the storm"**, or **"Best 6.4 km"** once you have one (the caption stops repeating it). Daily **"Daily Flight
  #298" / "Everyone's sea · one try"**, **"Flown 7.4 km · next in 6 h"** or **"Tried · next in 6 h"**, + flame and streak when ≥ 2. Goals (renamed
  on Home; "Flocks" stays the ladder's name) **"Goals" / "1 of 3 · Fledgling"**. Birds **"Birds" / name**. Icons: gear "Settings", **trophy
  "Leaderboards"** (the gamepad reads as controller settings).
- **States.** Fresh (runs = 0): Fly only. After run 1: Daily, Goals and Birds pop in (0.4 s, 0.08 s stagger), each with a gold dot until opened.
  Maxed: Goals reads "Storm Rider ★2".
- **Transitions:** to Play, the menu fades and the bird morphs. To pages, Art's crossfade + 24 pt slide, with the Home text faded 0.15 s first (goals.png
  caught Home bleeding through).

**Play HUD.** Eye order: bird and swell → distance → lead meter → chain.
- **Bird page:** pause 56 pt at the top outer corner; the meter from pause + 18 to the page edge; 22 pt below it one 12 pt line for the **"DAILY
  #298"** / **"DAILY #298 · PRACTICE"** tag (moved off the far page) and the one-time teach lines; hints at y 62 %.
- **Far page:** distance at the top outer corner; under it ONE pill, **"✦ ×5"** (only at chain ≥ 2), **"✦ ×5 · TAILWIND"** while a Tailwind blows;
  under that, within 1 km of a best ≥ 1 km, **"Best in 0.3 km"**.
- **Toasts and lighthouse card:** far page, top edge at 60 % height, over the sea, never over the sun (Art §8). **"New best!" / "Every metre now is a
  record"**; km toasts only at 5, 10, 15 km… (**"10 km" / "Outflying the storm"**); **"Old Harry" / "1st lighthouse · the storm falls back"**.
- **Chain lost** (a chain ≥ 3 broken by a splash): the pill turns slate and reads **"×4 lost"**, shakes 6 pt and fades over 0.8 s.
- **Caught:** everything except the distance fades over 0.3 s.

**Pause.** Far-page card, 400 wide: **"Paused" / "2.12 km · the storm waits."** / Resume (64 pt) / Restart · Home, plus on a hinge Duo a quiet
**"Switch to touch"** (one tap for tired or one-handed players). A scored Daily drops Restart and says **"Leaving ends today's try."** Resume → the
1.5 s Ready ring (**"Ready" / "Spread your wings"**).

**Results.** Purpose: one more go. Eye order: distance → near miss → Fly again → goals.
- The card is on the far page, full height, 460 max; the calm bird stays on the bird page. Buttons at the bottom, Fly again flush to the outer edge.
- **Order:** overline **"FLIGHT"** / **"FIRST FLIGHT"** / **"DAILY FLIGHT #298"** → distance + chip (**"New best!"** only) → **"Best 6.4 km"** or
  **"Previous best 6.4 km"** (none on a first flight) → hook **"Past Old Harry · 1.6 km short of Brightwater Head"** (first flight: **"1.9 km short of
  Old Harry, the first lighthouse"**; within 10 % of your best: **"0.4 km short of your best"**) → stats, zeros dropped (**"5 Perfects · chain 3 · 1
  lighthouse"**) → goals or rank-up → buttons.
- **Rank-up:** the three finished goals collapse into the banner **"Rank up! You're a Puddle Hopper" / "New: Tern"**, plus one line **"New goals: Fly 3 km
  · 3 Perfects in one flight · Chain 2"**. Today the goals clip behind the buttons on iPhone *and* Duo (results.png, duo3 duo-ui-results).
- **Flight buttons:** **Fly again** (primary) · Home · Share. While today's Daily is unflown and runs ≥ 1, a 44 pt row: **"Daily Flight #298 · one try ▶"**.
- **Scored Daily:** **Share** (primary) · **"Free flight"** (starts a Flight, never a silent practice) · Home. Above them: a flame + **"3-day streak · next
  Daily in 6 h 12 m"**.
- **Practice Daily:** **"Practise again"** · Home · Share.

**Goals (the Flocks ladder).** Left page: **"RANK 2 OF 15" / "Puddle Hopper" / "2 of 3 done"**, the goals card, **"Next rank: Tern"**. Right page:
the ladder scrolled to the current rank, then **"Logbook 12 of 40"** (§4). Maxed: **"Storm Rider" / "Every bird, sky and trail is yours."** + the
star flock.

**Birds.** Left page: preview on its sky, name, blurb, **"Every bird flies the same."**, skies in one row (the chosen sky visible without scrolling at
402 pt), a 56 pt **"Fly as Tern"** button. Right page: birds 4 × 2, then trails. Only the *next* unlock names its rank ("Rank 2"); the rest are a
lock at 0.5 (birds-fresh is a wall of 14 "Rank N").

**Settings.** Left page, **CONTROLS** first: Play with touch; Tuck by: Holding | Tapping (§10); Bird on the other side (**"The bird flies on the right
half. Try it if you're left-handed, or if one half blurs when you fold."**); Reduce Motion. Then **SOUND & FEEL**: Sound; Haptics: Off | Normal |
Strong (Strong is the Duo default, §9); Respect silent switch. Right page: About, Privacy, Progress, Reset (as now).

**Daily.** Scored countdown: a far-page banner above the numeral, **"Daily Flight #298" / "One scored try. Everyone flies this sea."** Flown: the Home
Daily button opens the **Daily card** (ResultsView fed from the `DailyRecord`, with hook, streak and next-in; Share primary, **"Practise today's
sea"** secondary). Tried but unfiled: **"Today's try is spent."** with the same buttons.

**Game Center.** The Leaderboards icon opens the dashboard. Signed out: **"Sign in to Game Center in Settings to see leaderboards."** for 2.8 s above it.
No access-point overlay (it would sit on the bird page's HUD corner).

## 4. Retention loops

- **Daily ritual.** The Daily appears after run 1, and a rank-2 goal requires it (it already does). Home and the cover say **"next in 6 h"**. The
  streak survives one missed day per rolling 7 (**"Calm sea: streak kept"** on the next Daily result): gentle streaks outlast brittle ones, and it
  needs no data. Every Daily gets a share card.
- **Goals cadence** (check in `tools/balance-sim.js`, casual, ~5 runs a day). Targets: rank 1 by run 2, rank 3 by run 8, rank 6 by day 4, rank 10 by
  day 10, rank 14 by day 21. The top looks fast (600 km at r12 ≈ 26 casual runs): stretch r9 to 400 km and r12 to 1,000 km. Past the top, **star
  flocks**: 3 rotating goals at 1.5 × the r13 targets, each adding a ★ to the title and a shimmer to the trail.
- **Unlock pacing.** Every rank pays out (true). Show only the *next* reward by name, on Birds, on Goals and in Results.
- **Personal-best ghost.** In a Flight with a best ≥ 1 km: a pennant buoy at the best (S2), then **"Best in 0.3 km"**, then New best as you pass it.
- **Two weeks on: the logbook.** 40 named lighthouses, shuffled by seed. Show **"Logbook 12 of 40"** on Goals and **"New in the logbook: Selkie Rock"** in
  Results. A `Set<String>` in ProgressStore.
- **Share card.** A 1080² `ShareCardView` (`ImageRenderer`): the sea profile with dots for the lighthouses, the distance, Perfects, Daily # and the
  streak, plus the existing text line.

## 5. Friction audit (now → target)

| Path | Now | Target | Task |
|---|---|---|---|
| Launch → flying | 1 tap + 3.0 s | 1 tap + 3.0 s (first run per launch only; it calibrates) | — |
| Caught → results | 2.6 s, unskippable | skippable after 0.6 s (tap or fold); else 2.2 s | A2 |
| Results → flying | 1 tap + 3.0 s | **0 taps (fold) or 1 tap**, then 1.5 s "Ready · Go"; moving 0.6 s after the input | A2, A3, C1 |
| Results → Daily | Home + Daily (2 taps) | 1 tap (the Daily row) | A6 |
| Home → share today's Daily again | impossible | 1 tap | A10 |
| Birds → fly the new bird | Back + Fly | 1 tap ("Fly as Tern") | A11 |
| Tired hands → touch | Home → Settings → toggle | Pause → "Switch to touch" | D7 |
| Launch → first Perfect | ~10 s | ≤ 13 s, guaranteed | Core intro swell |

## 6. Accessibility

- **VoiceOver.** Home order: Fly, Daily, Goals, Birds, Settings, Leaderboards, title bird. The adjustable **"Wings"** element exists in *every*
  input mode while VoiceOver runs (QA-2 P2-7). `.announcement` at most every 1.5 s, priority storm > lighthouse > Perfect: **"Perfect, chain 3"**,
  **"Storm close"**, **"Old Harry"**, **"Caught at 2.1 km"**. Results and pose states post `.screenChanged` (focus: distance → hook → Fly again).
- **Dynamic Type.** Fixed: HUD numerals, countdown, callout. Hints and toasts scale to `.xxxLarge` at most; pages and results to `.accessibility2`
  with 2-line limits and the card scrolling (Fly again pinned). Body ≥ 13 pt; Art's caps overlines and chips may be 11–12.
- **Reduce Motion.** Art §5's table, plus the morph becomes a crossfade. The title bird still follows the hinge, because it is input.
- **Colour.** The meter's slate and gold differ in luminance. Storm-close adds the icon shake, a 2 pt outline and thunder, so coral is never alone.
  Perfect = ring + text + chime + haptic. Check every pair in Sim Daltonism.
- **Handedness.** "Bird on the other side" mirrors every page assignment, and the hint arrows (↙ ↖) and the callout offset too.

## 7. Critique of the current build

**P0**
1. **The Perfect callout is pinned at 34 % height.** It covers the bird (soar.png) or floats 300 pt above it (chain.png, duo3 store-16). → A1, S1.
2. **"Open" is never taught.** The first Perfect kills all hints (hint-open.png: none, ×1 at 290 m). → A5.
3. **Death → flying takes ~5.6 s and can't be skipped.** → A2, A3, C1.
4. **Results clip the goals on a rank-up, on iPhone and Duo** (results, results-fresh, daily-results, duo3 duo-ui-results). → A6.
5. **The cover display mid-run shows the Home card: "Best flight —" at 18 km, and nothing about the paused run** (duo3 duo-06/07). → D1.

**P1**
6. The lead meter sits ~95 % full from 600 m to 4 km (perfect, splash, daily, lighthouse, duo3 store-11/16), so there's no tension. → C3, A8.
7. The far page stacks 4 items plus a toast over the sun (daily, duo3 store-11). → A8, Art.
8. A chain break is silent (splash.png). A scored Daily's "Fly again" silently becomes practice, with no streak, next-in or Daily path. → A6, A8, A10.
9. Birds-fresh is a wall of locks, and the chosen sky is hidden below the fold (birds). → A11.
10. The attract bird crosses the Home caption on Duo (duo3 home-tucked). The goals.png capture was mid-rotation. → A7, A13.
11. The portrait Duo pose is a dead end: TurnCard's "Play with touch" plays a band centred across the horizontal fold. → D2.

**P2**
12. Home shows the best twice, the gamepad icon is ambiguous, and first-launch Home offers 4 destinations that mean nothing yet. → A7.
13. First flight: "First flight!" + "Best 2.1 km" + "0 lighthouses". → A6.
14. The 1/2/3 km toasts duplicate the HUD. The chain pill survives "caught". → A8.
15. Settings buries Controls. The hint arrows don't mirror. `r7-daily` is met by any past Daily. → A14, A5, C2.

## 8. Round 3 UX tasks (book pose and shared)

**App (Swoop/UI, Swoop/App)**
- **A1 Callout on the bird.** `HUDState.birdPoint` (SwiftUI pt, from S1). Centre = bird + (40, −64) (mirrored −40); if that's under the HUD
  (y < top + 106) use bird.y + 70. Clear of the bird's rect + 24, clamped into the bird page; delete `calloutY`. Text "Tailwind!" when
  `tailwindStarted` fires in the same step.
- **A2 Fast restart.** `resultsDelay` 0.45 → 0.2. In `.caught` after 0.6 s, a tap (full-screen layer) or u ≥ 0.6 → `finishCaughtRunHeadless()` + show
  results now. Fly again and the Daily row use `countdown: 1.5` (C1); `fly()` uses 3.0 for the first run per launch, then 1.5 ("Ready" 0–0.75 s,
  then "Go").
- **A3 Fold to fly again** (`input == .hinge`, Results only). Arm: u ≤ 0.2 for 0.5 s with the card up ≥ 0.8 s; Fly again then fills left → right
  with u. Fire: u ≥ 0.7 held 0.25 s, then u ≤ 0.25 within 2 s. Disarm below 95° or shut. Haptics F1. Helper "or fold and open" on 5 results
  (`foldToFlyShown`).
- **A4 Countdown copy and the flat hold.** As in §2.
- **A5 Hints retire by success.** `learnedHints: Set<AppHint>` (fold, open, land, storm) replaces `hintsLearned`. The rules and copy are in §2.
  Mirror the arrows.
- **A6 Results rebuild.** As in §3, including the rank-up collapse (`"New goals: " + goals(forRank:).map(\.text).joined(" · ")`), the Daily row, the
  scored-Daily buttons, and the streak + next-in line.
- **A7 Home.** Fresh state, pop-ins and dots; flat caption; glow after the first stroke; no best in the caption; trophy icon; "Goals" label;
  attract run below y 62 % on Duo.
- **A8 HUD.** Daily tag under the meter; one pill (hidden below 2, "· TAILWIND", "×N lost"); "Best in X km"; km toasts only every 5 km, toasts at
  60 % height; fade on caught; meter headroom from C3; the coral pulse also starts in `.onAppear`.
- **A9 Share card.** `ShareCardView` 1080² + `ShareLink(item: image, message: text)`.
- **A10 Daily card.** Route `.daily`. Streak grace in `ProgressStore.dailyStreak`.
- **A11 Birds.** Next-unlock-only labels, ≥ 13 pt, skies in one row, "Fly as {bird}".
- **A12 Pose copy.** Closing card and TurnCard copy as in §9 (the cover and seated states are D1, D2).
- **A13 CI.** Wait for a landscape `SWOOP-T canvas` + 0.5 s before UI captures. Duo set: home-fresh, home-folded, home-flat, countdown, hint-fold,
  hint-open, callout-high, callout-low, chain-lost, results-first, results-rankup, results-daily, results-foldfill, daily-card.
- **A14 Settings order and copy.** The logbook. The VoiceOver items in §6.

**Core**
- **C1** `FlightSession(…, countdown: 3.0)`, allowing 1.5. The hinge snap keeps using the Ready stillness logic.
- **C2** `r7-daily`: met only by a Daily flown at rank ≥ 7 (copy "Fly a Daily Flight").
- **C3** balance-sim prints the gap p25/p50/p75 per skill. The App sets `meterHeadroom` so the casual p50 reads 55–65 % (≈ 2.0).
- **C4** r9 → 400 km, r12 → 1,000 km; add `GoalCatalog.starGoals(n:)`.

**Scene:** **S1** the bird's screen point (SwiftUI pt) to the driver at ≤ 30 Hz; **S2** the best buoy at best × 10 pt (Flight only); **S3** the
countdown morph (Art §4).

## 9. Duo-first optimisation and fallback

The rule for every pose: **the game never shows a dead end.** Each state below says what you see, what you do, where it goes, and how it leaves. The
app can't draw on both displays at once, and iOS moves it between them.

| State (detect) | What the player sees and does | Halves | Transition rule |
|---|---|---|---|
| **Book pose, 100–178°** (landscape inner, hinge live): primary | The bird at screen x 30 % with the storm behind it on the left half; the swells ahead, the sun and the next lighthouse on the right half. Fold to tuck, open to soar. | Bird page: pause, meter, Daily tag, hints, callout. Far page: distance, pill, best-in, toasts, cards. **Band 456–496:** art only (horizon glint ≤ 0.12 α); nothing slides across it (cards enter from the outer edge). | Base state. Text on the far page ≥ 17 pt: at 122° each half tilts ~29° away from the eye. |
| **Flat, ≥ 175°** | Playable (u = 0). Starting a fold from flat blurs one half for ~2 s (iOS). | — | Home/countdown: "Bend it a little, like a book" (the countdown holds at most 4 s). Mid-run: once per run, after 2 s flat, the bird page shows **"Keep a little bend"**. **Blur guard:** for 2.2 s after leaving ≥ 175°, new toasts and cards are queued, not shown. **Sharp half:** no new toggle. The mirror setting's copy covers "if one half blurs", and device test Q1 decides whether the default bird page should move. |
| **Closing, < 95°** (mid-run, hinge) | The run pauses under a 45 % scrim; the bird freezes on its page. | Far page card: **"Open your wings to keep flying" / "Paused at 2.12 km."** / quiet Resume. | Reopen ≥ 102° → the Ready ring (1.5 s, +≤ 1 s while the hinge moves; the calibration snaps when still) → flying. |
| **Shut → cover** (≤ 10°, or a canvas < 760 pt long) | See "The cover display" below. | Single column, 24 pt margins, clear of the camera. | Opening past 15° → the inner display → the closing card if < 102°, else the Ready ring. It never resumes without the ring. |
| **Reopened mid-run** (duo-08) | The ring **"Ready" / "Spread your wings"** on the far page centre; the bird page shows the frozen bird and the meter. If no fresh sample arrives in 1.5 s, the card shows Resume (QA P2-3). | Far page. | Ring → Go. |
| **Seated / portrait inner** (669 × 951, horizontal band) | **Split deck, not a wall.** During a run or on results: the game band sits on the *top half* (669 × 440, aspect-fill crop, y 8–448). The *bottom half* is the deck: distance, meter and chain in a top row, then a big touch pad **"Hold to dive · let go to soar"**, and pause at the outer corner. Touch input (the hinge is ignored except for shut). Home and the pages keep the TurnCard (**"Turn it sideways, like a book"** + **"Play with touch"**, which starts a split-deck Flight). | The top half is the game, the bottom half the controls; nothing in y 456–496. | Book pose again → pause → **"Fly with the fold?" [Fly with the fold] [Keep touch]**, then the Ready ring. Never a silent mid-run swap (fixes QA-2 P2-3). Seated *hinge* play (the lid as the wing) is an experiment only (device test Q4). |
| **Tent** (outer display faces you) | The app can't draw on the outer display while open. Tent angles (< 95°) trip the closing pause. | — | As closing. |
| **One-handed / awkward grip** | The hinge stroke needs two hands. Touch does not also tuck in hinge mode (grip thumbs would trigger false tucks). | — | Pause → **"Switch to touch"** (D7); Settings. |
| **Fatigue over a 3-min run** | Strokes 30–36°, about one per wave (~36–40 a minute in active play, ~90 a casual run). The full tuck saturates at θ_open − 36°, so you never need to squeeze further. Calibration follows your rest angle. | — | After 20 min of hinge flying, at most once a day, the Results show **"Long flight. Your wings can rest; the Daily will wait."** (2.4.2 hinge wear). No other warnings. |
| **Left-handed / mirrored** | The bird on the right half, flying right to left; every page assignment, the hint arrows, the callout offset and the cards' entry side swap. | Mirrored. | The live setting re-lays out (exists). |

**The cover display** (466 × 678; founder: mid-run it shows "Best flight —" and Daily but nothing about the run). It shows the state you left:
- **Mid-run (or paused), top to bottom:** overline **"PAUSED"** · hero **"18.57 km"** · **"Open your wings to keep flying."** · a static mini lead
  meter with **"Storm 1.2 km behind"** (the gap at the pause, 0.1 km steps) · **"9 Perfects · chain 4"** · **"1.0 km to your best"** or **"Beat
  19.6 km to set a best"** (never "—") · scored Daily only: **"Daily #298 · your one try is paused"**. Buttons (it's a touch screen): secondary
  **"Keep flying here"** (a split-deck touch run on the cover, behind the Ready ring) and tertiary **"End flight"** (records it, shows results on the
  cover). VoiceOver: "Paused at 18.57 kilometres. Open your Duo to keep flying."
- **Results:** **"19.6 km"** + **"New best!"**, the hook line, **"Open to fly again"**, Share (works here).
- **Home / menus:** **"Open your wings" / "Hold your Duo like a book to fly."**, then rows Best / **"Daily #298 · Ready"** or **"Flown 7.4 km · next
  in 6 h"** / streak. Fresh: **"Your first flight is waiting."** (no "—" rows). Stack centred at 42 % height; bird glyph 96 pt (Art).

**The first-launch teach on a Duo.** The title bird uses the *same* mapping as play, `smoothstep((θ_open − θ)/36°)`, with the same calibration, so the
practice transfers. The captions follow §2.

**Hinge noise** (~5° accuracy, 25–30 Hz while moving, nothing while still, 100–200 ms gaps). No UI asks for an angle: thresholds are wide u bands
(0.2 / 0.6 / 0.7) with ≥ 0.25 s holds. The title bird uses play's HingePredictor + One-Euro filters, so it never jitters. Stillness and flatness are
judged on the last reading plus a timer, never by waiting for an event. The Ready ring extends while the hinge moves; `onHingeChange` re-enables on
every activation (exists).

**Thermal and Low Power.** 120 Hz only in Play; Home, pages and cards at 60. At thermal `.serious` or in Low Power, Play drops to 60, particles to
70 % and rain to 60 %; at `.critical` bloom goes too. Never a warning. The HUD (≤ 15 Hz), callout and hit-stop run on wall time, so nothing reads
slower.

**The weak taptic engine** (the founder found Duo haptics weak). Audio carries every cue; haptics never stand alone. **Strong is the Duo default**
(F2): continuous intensity × 1.4 (clamped) with a 0.3 floor while skimming; transients become 50–60 ms continuous bursts at sharpness 0.4; a Perfect
is 2 × 60 ms bursts 80 ms apart, a launch 80 ms. Device test Q2 tunes it.

## 10. The fallback on regular iPhones (874 × 402, 667 × 375)

- **Touch has to feel native.** **Hold anywhere** stays (Tiny Wings proved it): any finger, either thumb, edge gestures deferred (exists). No on-screen
  button to aim for; instead input *feedback*: a 44 pt wing glyph in the bird page's lower outer corner folds with u, and on the first 3 runs a soft
  0.2 s ripple marks the touch. Ramp 0.12 s in / 0.10 s out (test 0.09 / 0.10), plus a light touch-down transient (the iPhone's strong Taptic Engine
  sells the "fold" click). Copy says Hold / Let go everywhere (§2), never "fold" or "Duo" outside About.
- **"Made for iPhone Duo", honest and quiet.** Store: **"Made for iPhone Duo: fold to fly. Plays with touch on every iPhone."**, plus one iPhone frame
  captioned "Hold to tuck on any iPhone". In the app: one line under the first-launch caption until the first run ends, **"Made for iPhone Duo. Here,
  hold to tuck."**, then only Settings → About. No upsell, no repeat.
- **iPhone portrait.** The landscape mask makes iOS rotate. Show the TurnCard (**"Turn your iPhone sideways" / "Hold to dive. Let go to soar."**) only if
  the canvas is still portrait 0.6 s later, so it never flashes.
- **VoiceOver and Switch Control.** **Tuck by: Holding | Tapping** (Settings → Controls): tapping toggles the tuck (tap to dive, tap to soar), on a Duo
  too. When Switch Control or VoiceOver is running, Home offers it once: **"Tap to tuck instead of holding?" [Use tapping] [Keep holding]**. The
  full-screen wings element supports VoiceOver direct interaction (hold) and adjustable (swipe); a Switch Control "select" toggles.

## 11. Duo-specific Round 3 tasks

**App.**
- **D1** `ClosedCard(state:)`: `.home / .midRun(PausedRun) / .results(ResultSummary)`. `PausedRun` (meters, gap, perfects, chain, best, isScoredDaily) is
  built by GameController at the pause. Adds "Keep flying here" and "End flight".
- **D2** `SplitDeckLayout` for portrait canvases (seated inner, cover): the game band on the top half (`ScreenLayout`, `hasFold: false`), the deck below.
  It replaces the centred `playRect` band, and adds the book-pose return prompt.
- **D3** The flat hold, "Keep a little bend", the 2.2 s blur-guard queue. **D4** Frame rates by route and thermal state (`preferredFramesPerSecond`,
  `ProcessInfo.thermalState`, `isLowPowerModeEnabled`).
- **D7** "Switch to touch" on Pause, the long-flight line, tuck by tapping (with Input). **D8** CI Duo frames: cover-midrun, cover-results, cover-fresh,
  seated-deck, flat-hold, reopened-ready, closing.

**Scene:** **D5** render the play band at 669 × 440 (466 × 328 on the cover) with the bird at 30 % x; particle and rain scalars for thermal.
**Feel / Input:** **F1** `uiTap` at arm, `uiConfirm` at fire, a soft swell with the Home fold; **F2** `HapticProfile.duo` (Strong) + the Off/Normal/Strong
setting; **F3** tapping-toggle mode in `TouchTuckSource` (same 0.12 / 0.10 s ramps); **F4** a light touch-down transient (iPhone only). **Core:** none
beyond C1–C4.
- **Founder device tests:** **Q1** which half blurs, and is it always the same one; **Q2** haptics at Normal vs Strong; **Q3** hands after 3
  back-to-back runs; **Q4** does seated lid-as-wing feel good; **Q5** warmth after 10 min at 120 Hz.

## Conflicts (with `design/ART-DIRECTION.md`)

1. **Callout anchor.** Art: bird + (40, −64), clear of the bird's rect + 24. Adopted, plus the UX flip below the bird under the HUD. No conflict.
2. **Toasts.** Art: on the bird's half under the HUD, or off the sun. UX: the far page at 60 % height, over the sea. That keeps the bird page for *now*
   and gets the toasts off the sun. **Proposed resolution: UX's.**
3. **Margins.** Art: 32 pt from the Duo edge, 24 from the band. Adopted here (`AppCanvas.edgeMargin` and `foldClear` on Duo).
4. **Secondary buttons.** Art makes them 48 pt tall on iPhone. UX keeps 56 pt *tap* areas (`AppCanvas.minTap`); a 48 pt visual is fine with a 56 pt hit
   area.
5. **The 🔥 emoji.** It becomes `flame.fill` in the UI chrome (Art); the share text keeps 🔥.
6. **Type floor.** UX: body ≥ 13. Art: overlines 11 / chips 12 (caps, tracked) are accepted as the exception.
7. **The Results count-up (0.8 s).** Fine, as long as Fly again and the fold-to-fly are live from the first frame.
