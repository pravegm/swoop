# App engineer: Round 4 notes

## P0
- **P0-1 Results never clip.** Two cards, one per page (Duo, mirrored and every landscape iPhone): the far card keeps
  overline → distance → best → hook → stats → buttons; the bird-page card takes the rank-up (with "New goals"), the goal
  rows, the small lines (logbook capped at 3 names + "+N more") and, on the Daily card, the share card + a 7-day dots
  row. The split decks show the far card with a one-line summary ("Rank up! You're a Gull Wing · New: Tern" /
  "1 of 3 goals · next: …"). `ResultsPlan` bounds every card's height from the type tokens and the line limits the view
  sets; `resultsFitEveryCanvas` checks 6 worst-case variants × 2 (Daily row) on 951×669 (both mirrors), 874×402, 956×440,
  667×375 and the 669×448 / 466×342 decks, and fails on any overflow. Compact Dailies drop the hook line to fit.
- **Contradicting numbers:** every goal row has a scope line ("This flight: 2 of 4", "In total · 48.30 km of 150 km",
  "Done in an earlier flight"); Flocks shows it for totals only (Core's texts now say "in one flight").
- **P0-3 Text over the sun:** the numeral, "Ready"/"Go", the Ready ring, every countdown line and the caught line sit on
  navy `#0B2236` at **0.62** (0.55 measures 3.8 : 1 over the sun's core; 0.62 gives 4.5 : 1, `Contrast`, tested), all in
  foam; the stage moves to 28 % / 62 % height when Scene's `sunCanvasPoint` is within 160 pt. Hint pill and banners:
  solid navy 0.8.
- **P0-4 One distance formatter:** `ShareText.distance` ("89 m", "11.88 km"; `roundUp` for distances to go) on every
  screen: HUD, pause, closing card ("Paused at 89 m."), cover, results hero and lines, Home, toasts, Best-in, hooks.
  Share lines keep one decimal (social format).
- **P0-6 (App half):** countdown holds on "Open a little wider" while Feel's `restIsBelowFloor` (shares the 4 s flat
  budget); after the Duo was shut the Ready hold is 2.5 s + 0.3 s from the inner display's return; a stale `isShut`
  never covers a ≥ 760 pt canvas and is cleared on `innerDisplayBack`.

## P1
- **7 Meter:** fill = Scene's `SceneStormMap.meterFill` (one source with the storm wall), coral zone `closeFill` (~17 %),
  3 pt storm-close outline, first-run "Storm ←→ you" for the first 3 s; no "0 m" during the countdown.
- **8 Perfects:** callout, 60 ms hit-stop (`FeelSoundBook.hitStop`) and VoiceOver only at milestones, ONE rule
  (`FeedbackDirector.isPerfectMilestone`, asserted equal to `FlightScene.isChainMilestone`); the callout tracks the bird
  (0.08 s ease). Decision: no extra callout for a player's first Perfect, so picture, sound and haptic agree.
- **9 Splash:** "Splash" / "Splash · ×4 lost" at the bird for 0.9 s (the far-corner "lost" pill is gone).
- **11 Icon:** span 0.88, 1.45× chord, 15 px contour, primaries over the outer 26 %, one mirror per wing, beak lower and
  head contour, additive sun glow, rising foam swell; `screen=icon` also writes AppIcon-180/60/40.png.
- **12 iPhone:** hints ride 110 pt above the bird (flip below under the HUD); the touch glyph is the brand mark, 56 pt,
  bottom-centre of the bird page, foam 0.35 α → gold 0.9 α with an ink outline; the Daily card's buttons are labelled
  rows ([Practise | Home]); "Free flight" always has its label; the Daily card's void holds the share card + dots.
- **13 Daily:** numbered from launch (`DailySeed.displayNumber`) everywhere; "New best!" or "Daily best!" chip; no Flight
  best line under a Daily.
- **14 Fold fill:** amber `#E8A93A` multiplied up from the bottom + a 3 pt foam progress line; the demo `foldFill` frame
  is held on the Duo simulator; "or fold and open" turns foam while armed.
- **15 Hinge readout:** Settings › Device test › "Hinge readout (TestFlight)" (Debug, TestFlight, sandbox only): angle,
  raw, open, tuck, Hz, report age, pose, closing/shut, strokes and mean depth (`StrokeCounter`).
- **16 CI:** store-21 / countdown-flat-duo freeze on `freezeOn=flathold`; new scenarios: pause, pause-daily, nudge, hint
  land, splash word, storm teach, Best in, meter label, phone TurnCard (`pose=phone`), fresh Daily card, icon sizes;
  Duo 40–45. Demo progress no longer contradicts itself (logbook filled for mid/late).
- **Review extras:** returning-player caption, compact Goals tile ("Crest Hopper / 1 of 3 goals"), Settings hides "Play
  with touch" without a hinge and "Tuck by" on a hinge Duo unless touch is on, Birds skies above "Fly as", preview
  halo + no clip, tile sun at (80 %, 22 %), future ladder ranks at 0.5 α, cover "Storm close" / "Storm far · lead N %",
  "N-day streak", "No best yet: this flight sets it", `#F2A65A` plusLighter horizon strip, the caught line, no hints
  during the blur guard, Go at 0.85 × the numeral without the sub-line, one bird mark in cards and badges.

## Declined / not mine
- Hands-on-Duo store frames, 160°/125° pairs, duo-01/06 timing, `UIRequiresFullScreen` in Release: founder (NEEDS).
- Thumb reach of the Home corner icons (Duo P2-13): needs the device test (A29) before moving them.
- Dynamic Type at `.accessibility2`: still R5 (UX agrees for 1.0).

## Tests
~20 new (fit, formatter, contrast, Daily number, milestones agree, goal captions, hint/splash placement, comfort rules,
strokes/readout, Daily best, touch glyph, demo keys); R2/R3 tests updated for the new copy and rules.
