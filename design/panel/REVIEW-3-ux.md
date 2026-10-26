# Review 3: UX and game feel (Round 3 build)

**Score: 7.0 / 10. Launch verdict: not yet.** It is one focused round away, not three.

The core loop is now readable at a glance on both canvases: fold and dive, open and soar, storm behind, gold ahead.
The Duo flow has no dead ends any more: cover pause card, split deck, fold to fly again, the 1.5 s "Ready · Go"
restart and the 0.6 s caught skip all work. Death to flying again is ~2.5 s with zero taps on a Duo (Tiny Wings
territory). What stops a ship:
- **The reward moment is still hidden, for the third round running.** The rank-up banner is clipped inside an
  invisible ScrollView on every iPhone results frame and on two of three Duo rank-up frames.
- **The lead meter's mapping hides the danger** it exists to show.
- **Perfect is so frequent at casual-plus skill that the callout has become wallpaper.**

Everything else is polish. Frames: iPhone `r5\screenshots`; Duo `duo5\duo-screens\duo-screens`; code where needed.

## P0

**P0-1. Rank-up and goals are clipped on results (iPhone and Duo).** Frames: `results-fresh`, `results-rankup`,
`results`, `daily-results`, `results-foldfill-duo`, Duo `store-25` to `store-28`.
- iPhone: `results-rankup` cuts "Gull Wing" in half; `results` shows one goal with its tick half cut;
  `results-foldfill-duo` shows a "GOALS" overline with nothing under it. Duo: `store-26` cuts the "New goals" line,
  `store-27` the logbook line.
- Cause: `ResultsView` line 77 puts the details in a `ScrollView(showsIndicators: false)` above pinned buttons, with
  no indicator and no fade. A player gripping a 254 g book with both thumbs will never scroll. This is UX-SPEC §7
  P0 #4, carried over from R2. The unlock ("New: Tern") pays for the ladder, and nobody sees it.
- Fix, Duo and mirrored: **move rank-up, goals and logbook to the bird page**, which sits empty under the storm
  (~400 × 600 pt). Card at x 32–432, y 120–560, entering from the outer edge. The far page keeps distance → best →
  hook → stats → buttons, which fits with 80 pt to spare at 669 pt.
- Fix, iPhone 874 × 402 (no fold): put a second card with rank-up/goals on the left page (island-safe x 82–403;
  UX §3 allows it without a fold). Failing that, in order: hide the stats line on a rank-up; move the Daily row into
  the button row as a 4th 56 pt chip ("Daily ▶"); show the logbook as "+9 in the logbook".
- Add a CI assert: details content height ≤ the ScrollView frame on every results scenario.

## P1

**P1-1. The lead meter starts nearly empty and its danger zone is invisible.** Frames: `countdown`, `hint-fold`,
`perfect-storm`, `storm-close`, Duo `store-07`, `store-20`, `store-23`.
- The meter is linear, `gap / (5 × 3000)`. Every run opens at 16 % fill (2400 pt), which reads "the storm is on you"
  before the first swell. Storm-close fires at gap < 450 pt = **3 % of the bar**, a sliver invisible at arm's
  length. `perfect-storm` shows the mismatch: meter nearly empty, storm wall no closer than usual.
- The casual median (3.1 × fullLead) reads 62 %, so headroom isn't the problem; the curve is.
- Fix: fill = `sqrt(gap / 15000)`. Start (2400 pt) → 40 %, storm-close (450 pt) → 17 %, casual p50 → 79 %, leash
  (9000 pt) → 77 %. Draw a fixed coral zone (#FF7B6E at 0.25 α) under the first 17 % of the track: the knob
  entering it *is* the warning, and it is positional, not colour alone.
- Keep `snapshot.lead` for logic; this is UI-only (`AppModels.meterLead`).

**P1-2. Perfect is too common to feel special, and the callout fires on every one.** Balance; `skim`, `chain`,
`daily`, Duo `store-04`.
- Casual 12.9/min with a swell every 2–3 s means about every second landing is Perfect; expert 20.6/min is nearly
  every landing. Each gets the same gold "Perfect ×N", a 35 ms hit-stop and a VoiceOver announcement
  (`GameController` 1072–1079). By minute two it is noise, and a hit-stop every ~3 s reads as stutter.
- Keep the window (novices need it: 2.6/min is fine). Make the presentation scarce and escalating:
  1. Text callout on the first 3 Perfects of a run, then only at milestones: 3 = "Tailwind!", then 5, 10, 15, 20,
     30. Others get ring, chime and pill tick only.
  2. Hit-stop only on milestones (60 ms) and Tailwind; none on ordinary Perfects.
  3. Ring tiers: ×1–4 foam #F2F7FA, ×5–9 gold #F7C75B, ×10+ reward gold #FFD45E with a second ring. Reset the
     pentatonic chime each octave; add a sparkle at ×10.
  4. VoiceOver announces milestones only. Tuning target for Feel: at most one callout per ~8 s for a casual player.

**P1-3. The Ready ring and countdown lines sit on the sun and can't be read.** Frames: `reopened-ready`,
`countdown`, `countdown-daily`, `countdown-short`, Duo `store-36`.
- "Spread your wings" is mist on #FFF3C4, ~1.3 : 1 (invisible in `store-36`). "Hold to dive · let go to soar" is
  white on the sun disc; "Ready" is white inside a gold ring on yellow.
- Fix: a navy #0B2236 disc at 0.55 α (r = ring + 16 pt) behind the ring and a 0.45 α pill behind the sub-line. Or
  move the stack to y 28 % of the far page whenever the sun's centre is within ±120 pt (Scene knows the sun).

**P1-4. The fold-to-fly fill is barely visible.** Frames: `results-foldfill-duo`, Duo `store-28`.
- Pale gold over gold: at 0.6 it washes out "Fly" (iPhone render) or shows as a 15 pt sliver (Duo). This is the
  Duo's signature restart; the player has to *see* it charge.
- Fix: amber #E8A93A fill rising from the bottom edge plus a 3 pt foam #F2F7FA progress line along the top; keep
  the label colour constant. At arm (u ≤ 0.2 held), pulse "or fold and open" to foam for 0.4 s.

**P1-5. The pause and closing card says "Paused at 0.0 km."** at 89 m (`closing-duo`, Duo `store-35`).
`ShareText.km` floors to tenths. Use `hudDistance` ("89 m") under 1 km (PlayHUD line 963), and audit every `km()`
call that can see < 100 m: the results hero can show "0.0 km" on a very short run.

**P1-6. iPhone Daily buttons are broken or unlabelled.** `daily-card` has a blank 30 pt pill between Share and Home;
`daily-results` has a lone paper-plane icon for "Free flight", which reads as Send or Share. Fix: on compact,
Share full width, then [Practise today's sea | Home] at 56 pt, or label+icon chips with `minimumScaleFactor(0.8)`.
Never ship an icon-only "Free flight".

**P1-7. The Daily card is half empty and its best line is confusing** (`daily-card`, Duo `store-29`). There is
~180 pt of void between the hook and the streak, and "Best 6.4 km" under a 7.4 km Daily reads as an error. Fill the
gap with the stats line and the 1080² share-card thumbnail (A9 exists). Relabel "Your best Flight 6.4 km", or drop
the line on Daily cards.

**P1-8. Hint pills cover the bird's flight path on iPhone** (`hint-fold`, `hint-open`). The pill sits at a fixed
62 % height, exactly where the bird skims on 402 pt, so bird and trail pass under the text at the moment of teaching
(Duo `store-23` is fine). Anchor it to the bird: centre at bird + (0, −110 pt), clamped to y ≥ HUD bottom + 16, and
flip below the bird when it would hit the HUD (reuse `CalloutPlacement`).

**P1-9. The touch-wing glyph doesn't read as a wing or as feedback** (`touch-wing`, `countdown`). A 44 pt, 2 pt
stroke at 0.7 α (PlayHUD line 837) reads as a "chevron-down" control, and it sits under the left thumb. Fix: the
filled cover dart, 56 pt, 0.35 α spread → 0.9 α gold #F7C75B at u = 1, bottom-centre of the bird page (iPhone
x ≈ 240, y = h − 40), tied to the ramp so the 0.12 s fold shows. It is the fallback's only "you are folding" cue.

## P2

1. **The Home attract bird crosses text.** On Duo, `store-19` spray crosses "your wings." and `duo-ui-home-tucked`
   the trail crosses "Swoop" (R2 P1 #10, still open in NEEDS); same on iPhone `home-folded`. Clamp the run to
   y ≥ caption bottom + 24 pt, or to the far page only.
2. **The returning-player iPhone Home still says "Press and hold the bird. That's a tuck."** (`home-returning`,
   2 lines). After run 1, start at "Hold to dive. Let go to soar." on one line.
3. **The countdown shows "0 m"** (`countdown`, Duo `store-20`), against "no zeros". Fade the distance in at Go.
4. **"Go" is smaller than "2"** and keeps "Wings open, hold steady" (`countdown-short`, Duo `store-22`), which
   contradicts it. Show "Go" at 0.85× the numeral; drop the sub-line at Go.
5. **The Perfect callout touches the bird** (`daily`: baseline on the wing), though A1 says bird rect + 24; `soar`
   leaves a callout 290 px from a launched bird. Let it follow the bird for its 0.7 s life.
6. **A splash reads smaller than a Perfect** (`skim` starburst vs `splash` droplets). The mistake should be wetter
   and heavier: tint the Perfect spray gold #FFF3C4 at 60 % size; raise the splash mist to 1.3×.
7. **"×4 lost" is only on the far-page pill** (`chain-lost`, Duo `store-24`); the eye is on the bird page. Add a
   slate #5B6976 "×4" that crumbles 40 pt behind the bird over 0.5 s.
8. **The Goals subtitle truncates** "1 of 3 · Crest…" (`home-returning`). Title "Crest Hopper", sub-line "1 of 3".
9. **The skies row is cut at 402 pt** (`birds-fresh`; UX §11 says visible). Preview to 140 pt tall on compact.
10. **iPhone Settings contradicts itself** (`settings`): "Play with touch" is off while the caption says you always
    play with touch. Hide the row on a phone with no hinge.
11. **Cover copy.** The streak row is a bare "🔥 3" (`store-31`): write "3-day streak". On the true cover
    (`duo-07`), "Storm 0.1 km behind" is neutral grey: under 0.3 km make the icon and bar coral. "Your first flight"
    reads oddly at 11.88 km: use "Every metre is a best".
12. **The storm-close outline is faint on Duo** (`store-07`, 2 pt coral on a dark track). Use 3 pt plus the P1-1
    zone.
13. **The ladder names every future reward** (`goals-fresh`); UX §4 says next only. A product call: keep the names
    but dim them to 0.5 α past the next rank.
14. **CI gaps:** no manual Pause card ("Switch to touch", the Daily "Leaving ends today's try"); no
    splash-before-Perfect hint, storm teach line or "Best in 0.3 km"; cover-* frames render on the 951 × 669 inner
    canvas, so only `duo-07` proves the 466 × 678 cover.
15. **Dynamic Type was declined** (app-R3). Fine for 1.0; reflow results at `.accessibility2` once P0-1 lands.

## What's working (keep it)

- The title bird tucks live with the hinge (`store-17`): that *is* the tutorial. The ✓ on "Let go on the way up"
  (`hint-open`) is a lovely beat. One pill keeps the far page calm; the lighthouse card (`lighthouse`) is right.
- The results hook ("2.2 km short of Wicklight") gives every death a next goal. The scored Daily (Share primary,
  streak, next-in) is the Wordle ritual. The cover card (`duo-07`) and split deck (`store-34`) leave no dead ends.
- The iPhone fallback is a real game (hold anywhere, Hold/Let go copy, an honest "Made for iPhone Duo" line).

## Top 8 for Round 4

1. **Unclip results** (P0-1): rank-up/goals/logbook to the bird page on Duo, two cards on iPhone, a CI assert.
2. **Meter fill `sqrt(gap/15000)` with a coral danger zone at 0–17 %** (P1-1).
3. **Make Perfect scarce in presentation, not in rules** (P1-2): text and hit-stop at milestones only; ring tiers
   foam → gold → reward gold.
4. **Scrim behind the Ready ring and countdown lines on the sun** (P1-3).
5. **A visible fold-to-fly fill** (P1-4): amber #E8A93A rising fill plus a top progress line.
6. **Fix the copy and button bugs** (P1-5 to P1-7): "Paused at 89 m", the empty Daily-card button, an icon-only
   "Free flight", the Daily card's void and best line.
7. **Anchor iPhone hints to the bird** (P1-8); **make the wing glyph a filled dart that charges gold** (P1-9).
8. **Clamp the Home attract run off the caption and wordmark**, and add CI frames for the manual Pause card and the
   true-size cover states (P2-1, P2-14).
