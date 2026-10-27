# Swoop: Game Center leaderboards and achievements (v1.0)

*Written Mon 26 Oct 2026 from `design/GAME-DESIGN.md` §6 and §8 and the `RunResult` fields in `Swoop/Shared/Contracts.swift`. **IDs are permanent once created in App Store Connect**, so the App engineer must use exactly these strings. Every one works the same with the hinge (Duo) and with press-and-hold (other iPhones). Nothing rewards folding speed or the number of folds (App Review 2.4.2).*

## Apple's limits (from Brim's and Squish's sourced notes)
- ≤ 100 points per achievement, ≤ 1,000 points per app, ≤ 100 achievements.
- IDs ≤ 100 characters: letters, digits, `.` and `_`. Permanent.
- Each achievement needs a **1024 × 1024** image (PNG or JPEG, RGB, no transparency, ≥ 72 dpi). Leaderboard images are optional.
- Achievements and leaderboards only go live attached to a version that includes them (runbook §4c).

## Leaderboards (2)

| | `swoop.longest` | `swoop.daily` |
|---|---|---|
| Type | **Classic** (all-time) | **Recurring** |
| Reference name | `Longest flight` | `Daily Flight` |
| Display name (en-GB and en-US) | `Longest Flight` | `Daily Flight` |
| Score format | Integer | Integer |
| Format suffix (singular / plural) | ` m` / ` m` | ` m` / ` m` |
| Sort order | High to Low | High to Low |
| Score submission | Best score | Best score (the app submits only the day's one scored try) |
| Score range (optional) | 0 – 1,000,000 | 0 – 1,000,000 |
| Recurring settings | — | Start **Sun 1 Nov 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day** |
| What the app submits | the run's **distance in whole metres** (`RunResult.meters`, rounded down), any Flight or Daily run | the distance in whole metres of the **first scored Daily Flight** of the (UTC) day |

**Why distance, not the style score:** the boards are named for distance, the brief says "in metres", and the bible says "distance is the headline". The style bonus (Perfect 25 m, Tailwind 100 m) stays an in-game number. If the build makes the style-inclusive score the result card's headline instead, tell the launch lead before the leaderboards are created: the format suffix and display names would change (`DECISIONS.md` #18).

**Why the Daily starts on 1 Nov, not launch day:** TestFlight testers (Game Center sandbox) can then see the board before launch. It costs nothing.

**One engineering point (must be settled before 1.0):** a recurring leaderboard resets at the same UTC moment for everyone, but the contract keys the Daily seed to the player's local calendar (`DailySeed.dayNumber(for:calendar: .current)`). That would mix two days' seas on one board around midnight. Brim hit the same problem and switched to UTC (`Brim/Core/LevelCatalog.swift`). Recommendation: key the Daily Flight to the **UTC date**, so it changes at 00:00 UTC (midnight in the UK in winter, 4 pm Pacific). See `DECISIONS.md` #19.

## Achievements (12, 625 points)

| # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger (for the App engineer) |
|---|---|---|---|---|---|---|---|
| 1 | `swoop.ach.first` | First Flight | Finish your first flight. | Wings out, off you go. | 10 | No | The first run of any mode reaches `finished` (a Flight or Daily run, not attract) |
| 2 | `swoop.ach.km1` | Open Water | Fly 1 km in one flight. | One kilometre of open sea. / One kilometer of open sea. | 15 | No | `RunResult.meters ≥ 1000` |
| 3 | `swoop.ach.km5` | Long Haul | Fly 5 km in one flight. | Five kilometres, and the storm still behind you. / Five kilometers, and the storm still behind you. | 25 | No | `meters ≥ 5000` |
| 4 | `swoop.ach.km10` | Ocean Crossing | Fly 10 km in one flight. | Ten kilometres. The gulls are impressed. / Ten kilometers. The gulls are impressed. | 75 | No | `meters ≥ 10000` |
| 5 | `swoop.ach.chain5` | Skipping Stone | Make 5 perfect landings in a row. | Five perfect landings, one after another. | 50 | No | `bestChain ≥ 5` in one run |
| 6 | `swoop.ach.chain10` | Glass Water | Make 10 perfect landings in a row. | Ten in a row. Barely a ripple. | 100 | No | `bestChain ≥ 10` in one run |
| 7 | `swoop.ach.tailwind` | Tailwind | Catch a Tailwind: 3 perfect landings in a row. | The wind is on your side. | 25 | No | First `tailwindStarted` event (or `tailwinds ≥ 1`) |
| 8 | `swoop.ach.lighthouse` | Keeper's Light | Fly past a lighthouse. | The beam swept over you. | 25 | No | `lighthouses ≥ 1` in one run |
| 9 | `swoop.ach.lighthouse3` | Three Lights | Pass 3 lighthouses in one flight. | Three lighthouses, one flight. | 100 | No | `lighthouses ≥ 3` in one run (with the 4 / +5 / +6 km spacing that is about 15 km: check it with the balance harness) |
| 10 | `swoop.ach.cloud` | Head in the Clouds | Soar high enough to touch the clouds. | Up where the clouds are. | 50 | No | First `cloudTouched` event (≥ 900 pt above the water), or `cloudTouches ≥ 1` |
| 11 | `swoop.ach.daily3` | Three Dawns | Play the Daily Flight three days in a row. | Three days, three seas. | 50 | No | The Daily streak reaches 3 (scored tries on 3 consecutive Daily days) |
| 12 | `swoop.ach.allbirds` | Whole Flock | Unlock all eight birds. | Every bird in the flock is yours. | 100 | No | All 8 `BirdID`s unlocked (the last one comes with the top levels in Goals) |
| | | | | | **625** | | |

Points: 10 + 15 + 25 + 75 + 50 + 100 + 25 + 25 + 100 + 50 + 50 + 100 = **625**. **375 points stay in reserve** for later updates (new birds, skies or sea events), well under the 1,000 cap.

**Achievable more than once:** No, for all twelve. **Hidden:** none. Nothing in Swoop is secret, and every goal tells the player something to try.

**en-US** differs only in the kilometre/kilometer spelling in the earned descriptions of #2–#4. Everything else is identical: enter it once per locale.

## The ladder (does it feel right?)

Rough reach from the bible's physics (storm at 520 pt/s plus 9 pt/s every second, 10 pt = 1 m; to be confirmed by the balance harness):
- **First run:** First Flight, Open Water, usually Keeper's Light (the first lighthouse is at 4 km) and often Long Haul.
- **First few sessions:** Tailwind, Head in the Clouds, Skipping Stone, Ocean Crossing.
- **A good week:** Three Dawns, Three Lights.
- **The long tail:** Glass Water, Whole Flock.

If the harness shows a step is far off (for example casual players never reaching 15 km), change the **description and trigger** before the achievement is created. IDs can't change afterwards; descriptions can, but changing what an earned achievement meant is unfair.

## Copy rules
- Titles short (Game Center truncates long ones). Count each title in the App Store Connect form; Apple's help doesn't state a field limit.
- Nothing mentions speed of folding, slamming, flapping the phone or closing it.
- No Tiny Wings echoes: no "tiny", "island", "fever" or "sunset".

## Images (needed before you can save each achievement)

Twelve 1024 × 1024 PNGs, one per achievement, opaque (no alpha channel), in the app icon's style: a golden-hour sky over a dark swell with the fold crease as a faint vertical glint, a medallion whose ring shows the tier (sea-green for 10–25 points, deep teal with gold studs for 50–75, gold for 100) and one motif: wings spread (First Flight), a wake line with 1 / 5 / 10 km, a skipping stone with 5 / 10 rings (chains), a golden trail (Tailwind), a lighthouse beam, three beams, a cloud, three suns rising (Three Dawns), eight small silhouettes (Whole Flock). No words, only short numerals.

**Where they come from:** the app draws them itself, the way Brim does (`Brim/UI/AchievementArt.swift`, `AchievementBadge(id:)`). The demo key `screen=badges` (`design/ROUND-1.md`) renders all twelve into the app's Documents/badges/, and CI copies them into the `screenshots` artifact, folder `screenshots/badges/`, one file per achievement named by its ID (e.g. `swoop.ach.first.png`). Claude sends the founder the link to the latest green run; the founder uploads each file to its achievement in App Store Connect.

## Implementation checklist (App engineer)
- [ ] IDs in code match this file exactly (one constant per ID), including the two leaderboard IDs.
- [ ] Authenticate once at launch; if the player declines, never show the sign-in sheet again uninvited.
- [ ] Progress reported with `percentComplete` for #2–#4 (best distance / target), #5–#6 (best chain / target), #9 (lighthouses / 3), #11 (streak / 3), #12 (birds unlocked / 8).
- [ ] Banners never appear mid-flight: queue them until the result card.
- [ ] Daily: submit only the first scored run of the (UTC) day.
- [ ] Touch play (hold to tuck) can earn every achievement.

## Sources
- App Store Connect Help, *Achievements* (limits, hidden, images): https://developer.apple.com/help/app-store-connect/reference/game-center/achievements
- App Store Connect Help, *Leaderboards* (classic and recurring; start date, duration, restart): https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards
- Brim's Game Center plan (format mirrored): `C:\Users\59527\Fold\docs\appstore\achievements.md`
