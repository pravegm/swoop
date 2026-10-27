# Swoop: Featuring nomination (App Launch)

*Final copy, Mon 26 Oct 2026; last edited Tue 27 Oct. **The App Store Connect tool creates and submits it** (`asc.yml`, step `nomination`, `"submit": true`, from `docs/appstore/asc-metadata.json`); nobody pastes it. Change the text here, run `node tools/appstore/build-metadata.js`, and push the `nomination` step again.*

## Timing

**Launch date: on approval, expected about Thu 29 – Fri 30 Oct 2026** (the founder's decision, 27 Oct: Swoop goes live as soon as Apple approves it). Swoop now launches before Brim, which still launches on Tue 17 Nov, so the two games never share a week.

Apple asks for nominations as early as possible, ideally **at least 3 weeks before** the date. Swoop can't give that: the tool submits the nomination together with the listing, about 3 days before the expected launch, with the publish date **Fri 30 Oct 2026**. Shorter notice makes a launch feature less likely, but it still puts Swoop in front of the editors, and it can stay in place for later editorial picks. It needs only the app record (created), not a build.

Where to see it: App Store Connect → Apps → Swoop → **Featuring** → **Nominations**. A saved draft is not a nomination, which is why the tool submits it.

If approval comes much later than 30 Oct (for example after a rejection), tell Claude: the Publish Date changes in `build-metadata.js` and the tool pushes it (or edit it by hand on the same page).

## Fields

| Field | Value | Count / limit |
|---|---|---|
| Nomination Name | `Swoop - App Launch - iPhone Duo fold-to-dive flyer` | 50 / 60 |
| Nomination Type | **App Launch** | — |
| Description | the block below | **986 / 1,000** |
| Publish Date | **Specific day: 2026-10-30** | — |
| Related Apps | Swoop only (auto-filled). Don't add Brim or Squish: they have their own nominations | up to 10 |
| Platforms | iOS | — |
| Countries or Regions | leave the auto-selection (every territory the app is in) | — |
| Localizations | leave the auto-selection (English (U.K.), English (U.S.)) | — |
| In-App Events | none | — |
| Supplemental Materials | 1. `https://pravegm.github.io/swoop/` 2. the launch post URL (once posted, on the day it goes live; add it by editing the nomination) 3. the TestFlight public link (only if you open external testing) | up to 5 URLs |
| Helpful Details | the block below | **463 / 500** |

### Description
```
Swoop turns iPhone Duo into a pair of wings. Hold the Duo open like a book, one hand on each half: fold it a little and the bird dives down the face of an ocean wave; open it at the bottom and the bird flies off the top. The two halves of the phone fold with the bird.

The hinge is an analogue control, not a switch: how far you fold sets how heavy the bird is, so the skill is rhythm, one fold per wave. Land on the way down of the next wave for a Perfect; three in a row is a golden Tailwind. A storm chases you out to sea, and the goal is always the next lighthouse on a fixed route of named headlands.

A short Flight School teaches by showing: a guide gull does each move, then you copy it. The bird flies on the half of the screen that stays sharp when a fold starts from flat. A Daily Flight with the same waves for everyone, 15 levels of goals that unlock birds and skies, Game Center. Other iPhones play by pressing and holding. No ads, no in-app purchases, no data collected.
```

### Helpful Details
```
Optimized for iPhone Duo: built for book pose on the inner display. The bird stays on the half that doesn't blur when a fold starts from flat (Settings: Bird side). Uses the public iOS 27.1 hinge API with easy folds of about 30 degrees from a self-calibrating book pose; it never asks players to close the phone, lay it flat or fold fast. Taught by an interactive tutorial. Every sound is synthesized in the app. Also from us: Squish, and Brim (launching 17 Nov).
```

**Why this copy:**
- **New hardware first:** the opening line, and "Optimized for iPhone Duo" in Helpful Details (Apple's Duo guidance asks for exactly that phrase).
- **The fantasy in one image:** the phone's halves are the wings and fold with the bird. No other phone can do it.
- **Craft:** an analogue fold, a physics skill (rhythm on the waves), synthesized sound.
- **Built for the real device (updated 27 Oct, after the founder's real-Duo test):** the bird stays on the half that doesn't blur, and a Flight School that teaches by showing. Editors look for apps that handle the Duo's quirks, not just its hinge.
- **A clear goal:** the next lighthouse on a fixed route, in the app's own plain words (`design/UX-ROUND-9.md` §3).
- **Replayability:** endless flights, the Daily Flight, 15 levels of goals and unlocks, Game Center.
- **Accessibility and reach:** press and hold, or tap, on other iPhones (iOS 18 or later). No VoiceOver claim, because that label isn't earned (`accessibility.md`).
- **Kind to the hardware:** answers the wear question before an editor asks it.
- **No ads:** the last line.

## Later nominations (optional)
- **New Content**, for the first update with real new content (for example a new sea event or birds). Description: what's new, one line restating no ads and a free update. Submit 3 weeks ahead.
- An **In-App Event** (a "Storm week" Daily Flight, for example) needs a build that implements it first; don't create one for 1.0.

## Sources
- App Store Connect Help, *Nominations template* (name ≤ 60, description ≤ 1,000, helpful details ≤ 500, up to 5 URLs, types): https://developer.apple.com/help/app-store-connect/reference/nominations/nominations-template
- App Store Connect Help, *Nominate your app for featuring* (minimum 3 weeks' lead time; roles): https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring
- Brim's nomination (format mirrored): `C:\Users\59527\Fold\docs\appstore\featuring-nomination.md`
