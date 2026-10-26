# App engineer: Round 5 notes

## P0-1 The Home button (all four critics)
- Cause: on the Daily rows Home was a *labelled* button beside "Free flight" / "Practise"; the HStack squeezed its
  label out and the Label's glyph floated above the empty tile.
- Fix: every results / Daily button is now data (`ResultsButtons.rows`, `ResultsButton`), built by one view. Home and
  Share are either labelled (Duo) or a fixed 64 × 56 `SwoopIconTileStyle` tile with the glyph centred (compact); a
  labelled button takes `maxWidth: .infinity`. Tests: `everyButtonHasALabel` (every button has a title/VoiceOver
  label, only Home/Share are tiles, Fly again is always labelled and the one primary, a spent Daily has no Share) and
  `buttonRowsFitEveryCanvas` (each row's labels fit their tiles on all 7 canvases; `ResultsPlan` drops the Daily row
  rather than squeeze a label).

## P1
- **2 Splash:** the word did fire; the R4 capture missed it because its fade ran on wall time while the demo froze the
  session. A frozen frame now draws the word statically (as the callout does); it lives 1.3 s in `#E6ECF2` on navy; a
  chain of 3+ broken by a plain landing says "×4 lost" too (never silent); a missing bird anchor no longer becomes
  `.zero` (`SceneAdapter.defaultBirdPoint`, in view points); `SWOOP-T splashMark shown …` is logged. CI:
  `freezeOn=chainlost` (new), `chain-lost`/`24-chain-lost` use it, `splash-mark`/`43-splash`/`hint-land` freeze 0.15 s
  after the splash (`hint-land` with `freezeAfter=0`).
- **3 One distance:** every pause (and the catch) forces an exact, unthrottled HUD publish, and the pause, closing and
  cover cards read `hud.meters` (`AppRules.hudMeters`, tested), so card and HUD show one value.
- **4 Results:** the far card is sized to its content and bottom-anchored (`ResultsLayout.anchored`; no void); on
  compact cards "Fly again" is full width and labelled with [Daily · one try | Home | Share] under it, falling back to
  one row [Fly again | Home | Share] only when the card is too short (667 × 375 rank-ups, the cover deck). Compact
  Dailies keep their hook when it fits. A spent, unfiled Daily (`.dailySpent`) leads with "Today's try is spent." and
  offers Practise today's sea + Home: no "0 m", no share card, no Share. The streak was real (three demo Dailies); the
  pre-launch Daily now shows its date ("Daily Flight 26 Oct") instead of a clamped "#1". The 7 dots have a "Last 7
  days" overline and weekday initials.
- **7 (App):** `homeCalibrate` every Home / Results frame, the open angle saved via `onCalibrated` (Settings) and
  restored at launch (never in demo runs), "Open it a little wider." on Home below the floor.
- **8 (App):** after the nudge budget, `lowRestFallback`: `.tooLow` keeps holding and shows "Fly with touch"; "Go"
  never comes with `startTuck > 0.5` (`AppRules.countdownGate`, tested).
- **9 (App):** ProgressData keeps best clean metres, cloud touches and speed (`bests: PlayerBests`); goals the bests
  meet tick at once (with the results animation) and a rank-up cascades through every met flock: one banner,
  "+6 ranks! You're a …". Progress for goal ids Core removed is dropped on load.
- **10 (App):** the Goals tile is "Goals / 1 of 3 · Crest Hopper" again; the iPhone TurnCard draws a phone turning
  (`PhoneTurnDrawing`); the touch glyph sits a quarter into the bird page at h − 28, 0.55 α spread, 0.15 α while the
  bird is near.
- **Review extras:** the meter's coral zone and a 2 pt tick sit above the fill; "Storm" / "You" labels under the cloud
  and the knob after Go; a 20 pt knob on a 24 pt navy dot; the cover reads "Storm 900 m behind" (coral under 300 m);
  the cover deck keeps the 1.5 s Ready hold; Birds preview uses Scene's `previewTransform`, key rim and halo.
- **Bug found:** `ScreenLayout.size` is the 952 × 670 design canvas, so R4's sun point and bird-point fallbacks
  were in the wrong space. The sun is now converted with `AppCanvas.screenPoint`.

## Declined / waiting
- The attract bird crossing the wordmark needs a Scene hook (the App can't move or hide it): asked in NEEDS.
- `pose.png` (a portrait iPhone frame) is blank. The landscape-only iPhone app can't draw a portrait canvas;
  `pose-phone` is the real iPhone TurnCard frame.
- TitleBirdView needs no change for the 14 % dart: its fit includes Scene's body specks.

## Tests
New: buttons and rows, spent Daily, HUD/card distance, splash texts, default bird point, countdown gate, Daily tag and
weekdays, goals met by bests + cascade, pruning, PlayerBests, saved open angle, touch glyph, demo key.
