# App engineer: Round 3 notes

## Built
- **Design system (ART A1–A3, A6, A9, A11):** `SwoopTheme` tokens (surface/surfaceRaised/stroke/accentOn, reward gold, flame),
  `SwoopType` scale (Duo ~10 % larger), concentric radii, primary/secondary/quiet/danger buttons, Liquid Glass icon
  buttons (iOS 26+), cards, chips, overlines in `mist`, `SwoopSegmented`. No gold glows over navy (pages, badges).
- **Play (UX-A1/A2/A4/A5/A8, ART A4/A5/A13):** callout anchored to Scene's `onBirdPoint` via `CalloutPlacement` (flips
  under the HUD, clear of the bird + 24, clamped to the bird page), "Tailwind!" text, hit-stops 35/60 ms, splash 0.85×;
  one pill (×N / · TAILWIND / ×N lost shake); "Best in"; Daily tag + teach line under the meter; km toasts every 5 km
  at 60 %; caught fades all but distance, tap-to-skip after 0.6 s (`finishCaught()`); hints retire by success
  (`HintCoach`, mirrored arrows); 3-2-1 first run, then "Ready · Go" on Core's own tick schedule; flat hold ≤ 4 s;
  scored-Daily countdown banner; iPhone wing glyph + 0.08 × tuck vignette + 3-run ripple.
- **Results (UX-A3/A6/A9/A10):** rebuilt order, 0.8 s ease-out-expo count-up with `.resultsTick` per 0.5 km (instant
  under Reduce Motion / demo), rank-up collapse with "New goals:", logbook / grace / star / rest lines, Daily row,
  scored-Daily + practice + Daily-card button sets, streak + next-in, fold-to-fly fill + helper, 1080² share card.
- **Home (UX-A7, ART A7/A12):** fresh = Fly only; pop-ins + gold dots; flat/fold captions; Fly glow on first stroke;
  "Best 6.4 km" on Fly; trophy "Leaderboards"; "Goals · 1 of 3 · Fledgling" (★ past the top); radial scrim; iPhone
  "Made for iPhone Duo" line until run 1; one-time tap-to-tuck offer; VoiceOver order; title bird with Scene's
  `titleDetail` colours; Fly hides it and calls `playTitleMorph`.
- **Pages:** Goals (rank line, next rank, ladder, Logbook N of 40, star flocks), Birds (A8 sun/size/lock 35 %, next
  unlock only, skies in one row, "Fly as X"), Settings (CONTROLS first, Tuck by, Haptics Off/Normal/Strong, copy).
- **Duo states (D1–D8):** cover card home/mid-run/results (Keep flying here, End flight, never "—"), split deck +
  "Fly with the fold?", closing card + 1.5 s Resume, Ready ring + `.go`, blur-guard toast queue + `fineDetail`,
  "Keep a little bend", 120/60 fps + `effectsQuality`, Switch to touch, long-flight line.
- **QA-2:** P2-1 migration v2, P2-3 return prompt / idle-only override clear, P2-4 queue dedupe + best-safe cap, P2-5
  pulse on appear, P2-6 km at ≤ 4 Hz, P2-7 Wings element in every mode, P2-8 monotonic `lastDailyDay`.
- **Icon:** `AppIconPainter` = concept A (slate | sunset split, sun, dorsal gull at 84 % with ink contour, sea + foam,
  fold highlight/shadow, no stars/glow). Badges: bronze/silver/gold rims, beam clipped to the disc.
- **Persistence:** `starFlocks`, `currentGoals`, `goalsLine`; haptic level persisted only when chosen.
- **CI:** 18 new iPhone and 23 new Duo scenarios (cover ×4, seated deck, closing, reopened-ready, flat hold, Ready·Go,
  home folded/flat/fresh, chain-lost, results first/rank-up/daily/fold-fill, Daily card). New demo keys: `screen=cover|
  daily`, `cover=`, `titleTuck=`, `folded`, `flat`, `dailyToday`, `rankUp`, `closing`, `holdReady`, `foldFill=`,
  `orient=portrait`, `shortCountdown`.
- **Tests:** ~20 new (coach, fold-to-fly, poses + deck, countdown beats, migration, grace, enqueue, haptics, copy rules,
  star flocks, logbook, demo keys); R2 tests updated for the changed rules.

## Files
App: GameController, AppModels (new), ModuleAdapters (new; replaced FeelAdapter), DemoMode, GameCenterManager.
UI: every file. Persistence: ProgressStore, SettingsStore. SwoopTests/AppTests. ci/scenarios.txt, ci/duo-scenarios.txt.

## Conflicts decided
- Countdown on the far page centre (UX layout) over Art's bird-page placement. Toasts: UX's far page at 60 %.
- Cover dart: 150 pt on Home/shut, 96 pt mid-run/results (Art conflict 4). Fold-to-fly cues: Feel's `.foldArmed` /
  `.foldFired` (they wrap uiTap/uiConfirm). "Keep flying here" is secondary, "End flight" quiet (UX §9).
- Cover best line: "X to your best" within 10 %, else "Beat X to set a best" (UX gave both, no rule).

## Declined (with reasons)
- **Dynamic Type scaling** (UX §6): fonts are fixed tokens tuned to the fold pages; scaling them needs a layout pass
  per page. R4.
- **Committing AppIcon-1024.png / the A14 composite template:** no commits this round and no Mac; CI `screen=icon`
  renders it. The 160°/125° store frames need a per-scenario hinge angle (founder, NEEDS).
- **Callout-high/low Duo frames:** a Perfect lands at sea level, so the flip-below case can't be staged by demo keys;
  CalloutPlacement's flip is unit-tested instead.

## NEEDS
Scene: Home's title box is inset 12 pt per side (morph start); attract bird below 62 % still open. Founder: CI waits.

## Device tune list
Callout offset (40, −64) at 120–150°; Ready·Go beat feel; fold-to-fly thresholds (0.2/0.7/0.25); 0.08 vignette;
Strong haptics; split-deck pad size; scrim strength over bright skies; cover copy at 466 pt.
