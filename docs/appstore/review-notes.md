# Swoop: App Review notes (v1.0)

*Written Mon 26 Oct 2026 from `design/GAME-DESIGN.md`, `design/ARCHITECTURE.md` and `design/ROUND-1.md`. The block between the markers is what you paste. Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes or symbols), so bytes = characters: **3,708 bytes**. Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (typed straight into App Store Connect; never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s screen recording, or a phone video, of one flight on the Duo held like a book: a few tucks, a launch, a Perfect. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Swoop: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
You don't need a Duo. Every mode, unlock and achievement works on any iPhone and in the Simulator, in landscape.
- Tap Fly. After a 3-2-1 countdown the bird drops onto the first wave.
- Press and hold anywhere on the screen: the bird tucks its wings and dives (falls faster). Let go: the wings spread and it glides.
- The skill: hold while going down a wave, let go as you climb over the crest, and land on the next downslope for a "Perfect".
- A storm follows from behind and speeds up over time. When it catches the bird, the run ends calmly and a result card appears. Fly again starts a new run.
- On iPhone Duo, Settings > "Play with touch" turns on the same press-and-hold control.

2. HOW THE HINGE IS USED (iPhone Duo)
Swoop reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API is used. The angle is used only to steer the bird while the game is on screen. It is never stored, never sent anywhere and never used for anything else.
a) Hold the Duo open like a book, in landscape, fold running top to bottom, one hand on each half, in a relaxed pose (about 130 to 170 degrees).
b) Fold the halves in a little (about 30 degrees) and the bird tucks; open them back to your resting angle and it spreads its wings. The resting angle calibrates itself. A run starts with a 3-2-1 countdown in that relaxed pose.
c) Below about 95 degrees the run pauses: "Open your wings to keep flying". It carries on when the phone is opened again.
d) Closed: the outer display shows a pause card ("Open your wings"). Nothing happens while closed.
e) Portrait or tabletop: a card asks the player to turn the Duo sideways and hold it like a book, with a "Play with touch" option.

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- Strokes are short (30 to 36 degrees) and unhurried: during active play a player folds and opens about once per wave, roughly 40 times a minute, always in the middle of the hinge's range (about 100 to 170 degrees). Folding faster gains nothing: the game eases the tuck, so speed is never rewarded.
- Swoop never asks the user to close the phone, lay it flat, fold quickly or slam it. Fully flat simply reads as "wings open".
- No score, achievement or bonus rewards folding speed or the number of folds. Folding at the wrong moment causes a splash, which costs speed.
- During play the game reads the angle, never the closed state.
- Nothing is placed on or between the screens.

4. MODES AND UNLOCKS (nothing hidden, nothing to buy)
- Flight: endless; a new sea every run.
- Daily Flight: the same sea for everyone that day, one scored try, then unscored practice. The result can be shared as text through the system share sheet.
- Flocks: three goals at a time; completing them ranks the player up (15 ranks). Ranks unlock 8 cosmetic birds and 5 skies. Every bird flies the same.

5. CONTENT
A bird skimming ocean waves at golden hour. The storm is weather (cloud, rain, a soft rumble); nothing is harmed. A mistake is a splash.

6. PRIVACY
No third-party SDKs, analytics, ads, accounts or tracking, and no network requests of our own. Progress and settings are stored only on the device. App Privacy: Data Not Collected.

7. GAME CENTER
Optional. 2 leaderboards (Longest Flight, Daily Flight) and 12 achievements (625 points), none hidden. If the player isn't signed in, Swoop works fully.

8. OTHER
- No notifications are requested.
- Sound plays when the silent switch is on (playback audio, mixing with other audio); Settings > "Respect silent switch" turns that off.
- All sound is synthesized in the app; there are no recorded or licensed assets.
- Debug and demo modes are disabled in Release builds.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

| Claim in the block | Source today | Check |
|---|---|---|
| The first button is labelled **Fly** | Bible §10 (Home: Fly, Daily, Flocks, Birds, Settings) | [ ] exact label |
| 3-2-1 countdown, then the drop onto a gentle first swell | Bible §9, ARCHITECTURE "Countdown" | [ ] |
| Press and hold anywhere = tuck; release = spread | Bible §3, `TouchTuckSource` | [ ] |
| Settings label **"Play with touch"** | Bible §10 | [ ] exact label |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle never persisted or sent | `Input/HingeReader.swift`, `ProgressStore` | [ ] grep |
| Book pose, ~30° stroke, auto-calibrated open angle (150–172°) | Bible §3, `HingeTuckSource.openAngle` | [ ] update if tuning moves them |
| Pause below ~95° with "Open your wings to keep flying"; resumes on reopening | Bible §3, `HingeTuckSource.isClosing`, `SWOOP-T paused closing` | [ ] exact wording |
| Cover display card "Open your wings" | Bible §3, §10 | [ ] exact wording |
| Portrait/tabletop pose card with "Play with touch" | Bible §10 | [ ] |
| Never uses `status == .closed` in play | `CLAUDE.md` hinge facts | [ ] grep |
| Daily: one scored try, then unscored practice; share as text | Bible §8 | [ ] |
| Flocks: 3 goals, 15 ranks, 8 birds, 5 skies, all birds identical in physics | Bible §8, `GoalCatalog`, `BirdCatalog` | [ ] |
| Setting name **"Respect silent switch"**, default off | Bible §7, §10 | [ ] exact label |
| No notifications, no rating prompt | no `UNUserNotificationCenter` / `requestReview` in `Swoop/` | [ ] if a rating prompt is added, add: "A one-time rating prompt may appear on a result card, never mid-flight." |
| Debug and demo modes disabled in Release | `App/DemoMode.swift` (`#if DEBUG`), `testflight.yml` `check_only` strings check | [ ] |
| 2 leaderboards, 12 achievements, 625 points, none hidden | `App/GameCenter…`, `achievements.md` | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Swoop never asks users to close the phone, lay it flat, or fold quickly or repeatedly at speed. Play uses short strokes of about 30 degrees at the pace of the waves (about one per wave, roughly 40 a minute in active play), in the middle of the hinge's range, from a relaxed book pose that calibrates itself to how the player holds the phone. No score, achievement or bonus rewards folding speed or fold count; folding at the wrong moment only causes a splash. Nothing is ever placed on the device. Any iPhone without a hinge, and any Duo player who prefers it, plays the full game by pressing and holding the screen. We're happy to add an on-screen line such as 'Small, slow folds fly best' to the first-run hints if that helps."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable without a Duo, and on a Duo through Settings > Play with touch. Offer the screen recording attachment.

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to the modes in §4 and the 12 achievements: the app is a complete game with an endless mode, a daily mode, 15 ranks of goals and unlockables, and the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Brim's reviewed notes (structure mirrored): `C:\Users\59527\Fold\docs\appstore\review-notes.md`
