# App R2: make it satisfying (26 Oct 2026)

## Built (ROUND-2 App 1–9, QA-1 App items)
- **QA-1 P1-1 (caught window):** `isLiveRun` is false once the phase is `.caught`, and the pause button hides while
  caught. Leaving a caught run (Home, a new run, the background) steps it headless to `.finished` and records it
  (`finishCaughtRunHeadless`, logs `SWOOP-T caught finished headless`).
- **P1-2 (Daily on kill):** going to the background after the drop files the distance so far
  (`fileDailyProgress`). `fileDailyPartial` keeps the larger distance and never replaces a finished record. Home and
  the cover card treat a started try as spent ("Tried · practice").
- **P1-5 (Game Center):** `showDashboard()` returns `.shown`, `.signingIn` or `.signedOut`. The sign-in sheet iOS hands
  over is kept and shown only on the button tap. Signed out with no sheet, Home shows "Sign in to Game Center in iOS
  Settings…".
- **QA P2s:**
  - Input picks the hinge only from a live sample; the stored flag drives orientation only (P2-2).
  - The closing card has Resume, which ignores a stale latch until the next sample (P2-3).
  - The lead meter pulses only while the storm is close and doesn't take touches (P2-4).
  - The Birds preview is fitted to a fixed reference pose, so it no longer "breathes" (P2-5).
  - "Fly again" after midnight starts today's Daily (P2-7).
  - The pose card's touch override ends once the canvas is landscape, and the card no longer requests a rotation
    (P2-8).
  - Lifetime goals read live on the Flocks screen (P2-9).
  - Daily partials go to the Daily board with the day as the score context (P2-10).
  - An unreadable save is copied to `swoop.progress.corrupt` (P2-11).
  - The `-swoopDemo` check is `#if DEBUG` (P2-13).
  - Home flies the expert pilot (P2-14).
  - VoiceOver can adjust the wings on the touch layer (P2-15).
- **Perfect:** "Perfect ×N" pops on the bird's half at the bird's screen x (`PlayLayout.callout`, fold-clear). There
  is a 35 ms wall-clock hit-stop: the session doesn't step, and `feedback.handle` keeps running.
- **HUD:** metres below 1 km, then "4.06 km" with ticking hundredths. A "DAILY #298 (· PRACTICE)" tag. The lead meter
  shows `gap / (1.3 × fullLead)` (`AppRules.meterHeadroom`) with a storm icon and a bird knob. The chain always reads
  "×N" (no looping pips).
- **Toasts:** no km toast within 0.5 km of a lighthouse or over its card.
- **Results:** cards under 480 pt fold the stats into one line and the buttons into one row, so the lighthouse line
  and the goals show on 667×375 up to the Pro Max. Added a "First flight!" chip and the near-miss hook
  ("Past X · 0.6 km short of Y").
- **Home:**
  - The wordmark is bigger and inset, and the wordmark and caption sit on a feathered navy scrim over the attract
    bird.
  - The menu is 8 % narrower.
  - The cover card's stack is raised and its bird art made bigger.
- **Settings:** Reset progress is a plain red row at the bottom. A fresh player sees "No flights yet".
- **Hints:** touch wording ("Hold on the way down" / "Let go to fly") unless the hinge flies the bird
  (`AppRules.touchWording`).
- **Ranks and trails:**
  - Core's `TrailCatalog` and 15 ranks (`maxRank` 14) are adopted through one adapter,
    `ProgressRules.trailOptions()`.
  - The Birds screen has a trail picker; the skies moved to the left page.
  - Bird tiles sit on the chosen sky, and trails appear in the rank-up banner and on the ladder.
  - `SceneDriver.bird` carries the chosen trail colour.
  - Flocks scrolls to the current rank, with "N of 3 done" on its own line.
- **Feel NEEDS:** `snapCalibration(at: now)`. The Ready hold extends by up to 1 s while `!hinge.isStill`. The
  founder's countdown snap is kept.
- **Art:**
  - Icon: the eyes and the hard tip band are gone; the gold is a wave with a curling foam lip.
  - Badges: sea swell; chain badges use gold Perfect rings.
- **Demo/CI:**
  - New keys `freezeDelay=<s>` (Perfect frames at 0.12, lighthouse at 0.4) and `freezeOn=countdown` (fixes the blank
    portrait frame).
  - Lead is seeded before chain.
  - storm-close is at lead 0.12; store-07 is at lead 0.06.
  - New frames: perfect-storm, 15-perfect-storm, 16-tailwind-callout.
  - A freeze holds the callout fully on screen (`hud.holdFrame`).

## Files
- Changed: Swoop/App/GameController, GameCenterManager, DemoMode.
- Changed: Swoop/UI/Layout, PlayHUD, ResultsView, HomeView, BirdsView, FlocksView, SettingsView, SwoopPages, PoseCards,
  BirdPreview, ShareText, RootView, AppIconArt, AchievementArt.
- Changed: Swoop/Persistence/ProgressStore.
- Changed: SwoopTests/AppTests (+8 tests), ci/scenarios.txt, ci/duo-scenarios.txt, design/NEEDS.md (App entry
  resolved).

## Deviations
- The HUD shows hundredths of a km ("4.06 km"), as REVIEW-1 P1-9 asks; ROUND-2's "1.2 km" was read as an example.
- The callout's height is fixed at 34 % of the canvas, because the App can't see the scene camera's bird y. Its x
  follows the bird.
- The countdown → play title-bird morph (REVIEW P2) isn't done.
- The committed asset-catalog icon PNG is the R1 render. Re-export it from CI `screen=icon`.

## NEEDS
- None.

## Tune on device
- Hit-stop length (`hitStopSeconds` 0.035) against Feel's double-tap haptic.
- Callout height (`PlayLayout.calloutY` 0.34).
- Meter headroom (1.3).
- Home scrim opacity (0.38).
