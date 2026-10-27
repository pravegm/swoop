# Swoop: App Review notes (v1.0)

*Written Mon 26 Oct 2026; **rewritten Tue 27 Oct for the Round 6–9 build** (Flight School, the bird side, the lighthouse route, the plain words of `design/UX-ROUND-9.md`). The block between the markers is what you paste. Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes or symbols), so bytes = characters: **3,745 bytes** (counted with Node). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (typed straight into App Store Connect; never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s screen recording, or a phone video, of one flight on the Duo held like a book: a few folds, a take-off, a Perfect. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Swoop: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
You don't need a Duo. Everything works on any iPhone and in the Simulator, in landscape.
- Tap Fly. The first flight starts with Flight School, a short lesson on a calm practice sea (no storm, no score): a guide bird shows each move, then waits for you to copy it. Skip appears from step 2; Settings > Flight School replays it.
- Control: press and hold anywhere on the way down a wave (the wings fold, the bird dives faster), let go on the way up (it flies off the top). Land on the way down of the next wave for a "Perfect". One hold per wave; no flapping.
- A storm follows and speeds up; perfect landings push it back. The goal is the next lighthouse on a fixed route (Gull Point 4 km, Saltlight 9 km...), always shown at the top. When the storm catches up, "Flight over" appears and a card shows how far you got.
- Settings > "Wings by: Tapping": one tap folds, the next opens.

2. HOW THE HINGE IS USED (iPhone Duo)
Swoop reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. The angle only steers the bird while the game is on screen; it is never stored or sent anywhere.
a) Hold the Duo open like a book (landscape, fold top to bottom), one hand on each half, relaxed. The resting angle calibrates itself.
b) Fold the halves in a little (about 30 degrees) on the way down a wave; open back on the way up.
c) Bird side: iOS briefly softens one half of the inner screen when a fold starts from flat, so on a Duo the bird flies on the half that stays sharp: by default the right half, flying right to left. Flight School asks once which half stayed clear (one tap, or skip). Settings > Bird side: Sharp side (auto), Left or Right.
d) Settings > "Play with touch" gives the press-and-hold control on a Duo.
e) Below about 95 degrees a flight pauses ("Open your wings to keep flying") and carries on when reopened. Closed: the outer display shows "Open your wings". Portrait: a card asks to turn the Duo sideways, with "Play with touch".

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- Folds are short (about 30 degrees) and unhurried, about one per wave, in the middle of the hinge's range. The game eases the fold, so speed is never rewarded.
- Swoop never asks the user to close the phone, lay it flat, fold quickly or slam it. Opening flat gains nothing, and a one-time tip says so.
- No score, achievement or bonus rewards folding speed or fold count.
- During play the game reads the angle, never the closed state. Nothing is placed on the screens.

4. MODES AND UNLOCKS (nothing hidden, nothing to buy)
- Flight: endless, new waves every time. Lighthouses passed light up on the Route page.
- Daily Flight: the same waves for everyone that day, one try that counts, then practice. Shareable as text via the share sheet.
- Goals: three at a time, 15 levels. Levels unlock 8 cosmetic birds, 5 skies and trails. Every bird flies the same.

5. CONTENT
A bird over ocean waves. The storm is weather (cloud, rain, a soft rumble); nothing is harmed.

6. PRIVACY
No third-party SDKs, analytics, ads, accounts or tracking. Progress and settings stay on the device. App Privacy: Data Not Collected.

7. GAME CENTER
Optional ("Top scores" on Home). 2 leaderboards (Longest Flight, Daily Flight), 12 achievements (625 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on (playback audio, mixing); Settings > "Respect silent switch" turns that off. All sound is synthesized in the app.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

Checked against the code on Tue 27 Oct (commit `a036bc4`). Re-tick the **RC** column on the release candidate.

| Claim in the block | Source in the code | Code | RC |
|---|---|---|---|
| The first button is **Fly**; the first Fly opens Flight School | `UI/HomeView.swift`, `App/FlightSchool.swift` | [x] | [ ] |
| Flight School: calm practice sea, no storm or score until its last step, a guide bird demonstrates, Skip from step 2, replay in Settings | `UI/FlightSchoolView.swift` (`canSkip`), `Scene/SceneGuideGull.swift`, `UI/SettingsView.swift` ("Flight School") | [x] | [ ] |
| Press and hold anywhere = fold; let go = open | `Input/TouchTuckSource.swift` | [x] | [ ] |
| Settings **"Wings by"**: Holding · Tapping | `UI/SettingsView.swift` | [x] exact label | [ ] |
| Fixed route Gull Point 4 km, Saltlight 9 km; next lighthouse always in the HUD; "Flight over" | `Core/Lighthouses.swift`, `UI/PlayHUD.swift`, `UX-ROUND-9` §2.1 | [x] | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle never persisted or sent | `Input/HingeReader.swift`, `Persistence/` | [x] | [ ] grep |
| Auto-calibrated resting angle, ~30° fold | `Input/HingeTuckSource.swift` | [x] | [ ] update if tuning moves them |
| Bird on the sharp half, default screen-right on a Duo, flight right to left; the one-tap clear-side check in Flight School; **Bird side**: Sharp side (auto) · Left · Right | `Input/SharpHalf.swift`, `UI/SettingsView.swift`, ROUND-6 D1 | [x] | [ ] |
| Settings **"Play with touch"** (Duo) | `UI/SettingsView.swift` | [x] exact label | [ ] |
| Pause below ~95° "Open your wings to keep flying"; cover "Open your wings"; portrait card with "Play with touch" | `Input/HingeTuckSource.swift` (`isClosing`), `UI/PoseCards.swift` | [x] exact wording | [ ] |
| One-time "no need to open flat" tip | ROUND-6 D1.4 | [ ] confirm in the RC | [ ] |
| Never uses `status == .closed` in play | `CLAUDE.md` hinge facts | [ ] grep | [ ] |
| Daily: one try that counts, then practice; share as text | `UI/HomeView.swift`, `UI/ShareText.swift` | [x] | [ ] |
| Goals: 3 at a time, 15 levels, 8 birds, 5 skies, trails, all birds identical in physics | `Core/Goals.swift`, `Core/Catalogs.swift`, `UI/FlocksView.swift` | [x] | [ ] |
| **"Top scores"** button on Home; 2 leaderboards, 12 achievements, 625 points, none hidden | `UI/HomeView.swift`, `App/GameCenterManager.swift`, `achievements.md` | [x] | [ ] |
| Setting **"Respect silent switch"**, default off | `UI/SettingsView.swift` | [x] exact label | [ ] |
| No notifications, no rating prompt | no `UNUserNotificationCenter` / `requestReview` in `Swoop/` | [ ] grep (if a rating prompt is added, add: "A one-time rating prompt may appear on a result card, never mid-flight.") | [ ] |
| Debug and demo modes disabled in Release | `App/DemoMode.swift` (`#if DEBUG`), `testflight.yml` `check_only` | [x] | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Swoop never asks users to close the phone, lay it flat, or fold quickly. Play uses short folds of about 30 degrees at the pace of the waves (about one per wave), in the middle of the hinge's range, from a relaxed book pose that calibrates itself to how the player holds the phone. Flight School teaches exactly this, with no time pressure. No score, achievement or bonus rewards folding speed or fold count. Nothing is ever placed on the device. Any iPhone without a hinge, and any Duo player who prefers it, plays the full game by pressing and holding the screen or by tapping."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable without a Duo, and on a Duo through Settings > Play with touch. Offer the screen recording attachment.

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to the modes in §4 and the 12 achievements: an endless mode with a route of named lighthouses, a daily mode, 15 levels of goals and unlockables, and a tutorial; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Brim's reviewed notes (structure mirrored): `C:\Users\59527\Fold\docs\appstore\review-notes.md`
