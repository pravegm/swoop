# Review 4: UX and game feel (Round 4 build)

**Score: 8.2 / 10 (R3: 7.0). Launch verdict: not yet.** This is a short polish round away, not a structural one.

The three R3 blockers are fixed: results no longer clip, the lead meter tells the truth, and Perfect is scarce again.
What is left is a cluster of **button and number bugs on the results/pause cards**, plus one feedback cue (the
"Splash" word) that no frame shows. Frames: iPhone `r8\screenshots`, Duo `duo6\...`, against `r5` / `duo5`.

## Status of my R3 findings

| R3 | Status | Evidence |
|---|---|---|
| P0-1 results clip | **Fixed** | `results-rankup`, `results`, `daily-results`, Duo `store-26/27/28`: rank-up, goals and logbook ("+5 more") are on the bird page, fully visible. The goal scope lines ("This flight: 11 of 25", "Done in an earlier flight") also fix the contradicting numbers. |
| P1-1 meter | **Fixed** (small gap) | sqrt fill: the start reads ~37 % (`countdown`), the storm-close coral outline is 3 pt (`storm-teach`, Duo `store-07`), and the meter and wall share `SceneStormMap`. Gap: the 17 % coral zone sits *under* the gold fill, so it is invisible until you are already in it (P2-1). |
| P1-2 Perfect scarce | **Fixed** | The callout and hit-stop fire only at milestones (`perfect`/`tailwind` at ×3, Duo `store-04` at ×5). Rings are tiered (foam at ×3, gold at ×5). The soft chime is in Feel. |
| P1-3 text on sun | **Fixed** | Navy discs and pills behind 3-2-1, "Ready", "Spread your wings" and "Open a little wider" (`countdown`, `reopened-ready`, Duo `store-42`). |
| P1-4 fold fill | **Fixed** | Duo `store-28`: amber fill plus the foam progress line read clearly at 0.6. |
| P1-5 "0.0 km" | **Partly fixed** | One formatter ("Paused at 101 m."), but the HUD and the card now disagree (P1-3 below). |
| P1-6 Daily buttons | **Partly fixed** | "Free flight" and "Practise" are labelled, but the Home button next to them is broken (P1-1 below). |
| P1-7 Daily card void | **Partly fixed** | The share card and 7-day dots now sit on the bird page, and the Flight best line is gone. The far card still has ~200 pt of void, and the unflown state shows a "0 m" hero (P1-4). |
| P1-8 hints on path | **Fixed** | `hint-fold`, `storm-teach`: the pill rides 110 pt above the bird. |
| P1-9 touch glyph | **Partly fixed** | It is now the brand mark at bottom-centre, but it is faint, and the bird skims over it (`touch-wing`, P2-3). |
| R3 P2s | Mostly fixed | Fixed: returning caption, no "0 m" in the countdown, Duo Goals tile, cover copy ("No best yet: this flight sets it"), Pause and Daily pause frames now in CI. Still open: the iPhone attract bird through the wordmark (`home`) and "Crest…" truncation on iPhone (`home-returning`). |

## P0

None on its own; the P1s below, taken together, would embarrass a launch.

## P1

**P1-1. The Home button is broken on every Daily button row.** Frames: `daily-results`, `daily-card`,
`results-daily-card-fresh`, Duo `store-27`.
- The house icon floats *above* an empty 64 pt box. The label is squeezed out because "Free flight" / "Practise"
  takes all the width (`ResultsView` 341–344: both `iconOnly: false`, with no width or priority on Home).
- This is the most-seen secondary on the Daily, and it looks like a rendering glitch.
- Fix: either make Home `iconOnly: true` with `.frame(width: 64)` and centred, or give both buttons
  `.frame(maxWidth: .infinity)` and drop the icon from "Free flight" on compact. Add a snapshot test asserting each
  label's frame lies inside its button.

**P1-2. On iPhone the primary button lost its label, and the hierarchy is inverted.** Frames: `results`,
`results-rankup`, `results-fresh`.
- "Fly again" is a 64 pt gold square with only ↻. Meanwhile "Daily" gets a 104 pt labelled chip, so the secondary
  reads as more important than the primary.
- The far card has ~300 px of empty space above the buttons, because the two-card layout moved everything else off
  it.
- Fix: the far card has room now, so use "Fly again" full-width and labelled (52–56 pt), then a row of
  [Daily · one try | Home | Share] with Home and Share icon-only at 56 pt. Keep the chips only for 667 × 375, if
  `resultsFitEveryCanvas` says so.

**P1-3. The HUD distance and the pause card disagree on the Duo.** Frames: Duo `store-41` (HUD "91 m", card
"99 m · the storm waits.") and `store-35` (HUD "99 m", card "Paused at 101 m.").
- The HUD's ≤ 4 Hz km throttle leaves a stale value when the run freezes. One formatter is not enough; both need one
  *value*.
- Fix: on pause, closing, caught and finish, force a HUD distance refresh from the snapshot in the same frame, and
  have the card read the HUD's published value. Add a test that the pause card's text equals the HUD text at the
  pause.

**P1-4. The unflown Daily card leads with a "0 m" hero and makes Share primary** (`results-daily-card-fresh`).
- "0 m" on the card and on the share image, with Share as the gold button, invites sharing nothing.
- Fix for the tried-but-unfiled state: hero "Today's try is spent." in the title style; primary "Practise today's
  sea", secondary Home; no share card and no Share button; keep "Next Daily in 5 h 45 m".
- Also fill the flown card's far-card void (`daily-card`, ~200 pt) with the hook line. Compact Dailies drop it
  (`ResultsPlan` line 594), but the room is there now.

**P1-5. The "Splash" word (R4 P1-9) never appears in any frame.** Frames: `splash-mark`, `chain-lost`,
`hint-land`, Duo `store-43`, `store-24`.
- All five freeze 0.2–0.3 s after a splash (logs confirm the touchdown splash event), inside the mark's 0.9 s life,
  and none shows "Splash" or "×4 lost".
- The far-corner "lost" pill was removed, so a chain break is currently **silent on screen**. That is a regression
  from R3.
- Fix: check the anchor. `birdPoint(...)` returning nil gives `.zero`, so the mark may be positioned off-canvas, or
  the freeze may stop the SwiftUI layer.
- Make the CI frame hold the mark (`hud.holdFrame`), and add an assert in the demo log ("SWOOP-T splashMark shown").
- Also fix the scenarios: `chain-lost` needs a real chain of 3+ before the splash (its log shows `chain=0`), and
  `hint-land` freezes on the second splash, after a Perfect, so "Land on the way down" can't show (use
  `freezeAfter=0`).

## P2

1. **Make the danger zone visible before you are in it** (all play frames). Draw it as a coral 2 pt tick plus a
   0.4 α coral track segment *above* the fill (z over the gold), or tint the gold fill coral where it overlaps the
   first 17 %. That way the player sees the cliff edge coming.
2. **The "Storm ←→ you" label reads as a glyph string and collides with the bird** (`countdown`, `countdown-nudge`:
   "you" sits under the wing). Put "Storm" under the cloud icon and "You" under the knob, at 12 pt, both ends of the
   bar. Show it only after Go, for 3 s.
3. **The touch glyph is under the skim line** (`touch-wing`: the bird sits on it at y ≈ 820/920). At 0.35 α foam it
   also vanishes on the sea. Lift it to y = h − 28 and keep it clear of the bird's rect + 16 (hide it when the bird
   overlaps). Raise the spread state to 0.55 α.
4. **The iPhone fresh Home: the attract bird and spray run through "Swoop"** (`home`). Clamp the attract run below
   the caption bottom + 24 pt on iPhone, as on Duo `store-17`.
5. **The iPhone Goals tile still truncates** "Crest…" (`home-returning`). Use the Duo copy, "Goals / 1 of 3 · Crest
   Hopper", or drop the flag icon on compact.
6. **The cover shows "Storm far · lead 32 %"** (`duo-07`). 32 % reads as danger, and the percentage is jargon. Use
   the R3 wording, "Storm 0.9 km behind", and coral under 0.3 km.
7. **The 7 Daily dots have no key** (`daily-card`). Add a "Last 7 days" overline, plus the weekday initial under each
   dot at 11 pt.
8. **The storm wall sits over the pause button and meter at storm-close** (Duo `store-07`, `storm-teach`). The HUD
   chips have scrims, so legibility holds, but cap the anvil top at y ≥ HUD bottom + 8 so the pause target never
   looks occluded.
9. **Balance check: Perfect still feels special.** Casual is now 9.9/min. With callouts only at milestones, a casual
   player sees text about every 30–40 s. Good. Keep `isChainMilestone` at 3, 5, 10, 15…; don't add 4/6/8.

## What got better (keep)

- Two-card results: the bird page finally has a job after death. Navy discs keep the countdown legible on the sun.
- "Open a little wider" (Duo `store-42`) and goal scope lines ("This flight: 3 of 6") are exactly right.
- Pause has labelled Restart and Home; the scored-Daily pause drops Restart and says "Leaving ends today's try."

## Top 8 for Round 5

1. **Fix the Home button on Daily rows** (P1-1), with a test that labels sit inside their buttons.
2. **Label iPhone "Fly again" full width**; the Daily, Home and Share row below it (P1-2).
3. **Make the HUD and the pause/closing card show one distance value at the freeze** (P1-3).
4. **Rework the unflown Daily card**: no "0 m" hero, no Share; Practise is primary (P1-4).
5. **Make "Splash · ×4 lost" visible**; fix the `chain-lost` and `hint-land` scenarios (P1-5).
6. **Draw the meter's coral danger zone above the fill**; split the meter label into "Storm" and "You" (P2-1,
   P2-2).
7. **Move the touch glyph clear of the skim line and raise its alpha** (P2-3).
8. **iPhone Home polish**: clamp the attract bird, fix the Goals tile truncation, and use the cover's
   "Storm 0.9 km behind" (P2-4 to P2-6).
