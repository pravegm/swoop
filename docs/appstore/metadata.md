# Swoop: App Store metadata (v1.0)

*Written Mon 26 Oct 2026 by the launch lead; **rewritten Tue 27 Oct for the Round 6–9 build** (Flight School, the lighthouse route, the bird on the sharp half, and the plain words of `design/UX-ROUND-9.md` §3–4). Nobody pastes these any more: `node tools/appstore/build-metadata.js` turns the code blocks into `docs/appstore/asc-metadata.json`, and the App Store Connect tool (`asc.yml`, `tools/appstore/README.md`) pushes them, together with §7–§9. Change the text here, then regenerate. Counts are Unicode characters (counted with Node), except keywords, which Apple counts in bytes (all ASCII here, so the same). Each choice has a one-line reason in `DECISIONS.md`. Every feature claim was checked against the code on 27 Oct (§10); re-tick §10 on the release-candidate build before submission.*

**Words the copy uses** (the app's glossary, `UX-ROUND-9.md` §3–4): *fold / open* on the Duo and *hold / let go* on other iPhones (never "tuck" as an instruction; "Tuck & Soar" stays only in the name), *flight*, *the way down / the way up*, *Perfect* and *perfect landings*, *in a row*, *stay ahead of the storm*, *the next lighthouse*, *Route*, *Level n*, *Goals*, *top scores*, *same waves for everyone*. Never "Outfly", "downslope", "crest", "chain", "rank", "Flocks".

Localisations: **English (U.K.)** is the primary language, plus **English (U.S.)**. Every other storefront shows en-GB. Only the description differs between the two (§4); everything else is identical.

---

## 1. App name (limit 30)

```
Swoop: Tuck & Soar
```
**18 / 30.** Bare "Swoop" is crowded on the store (delivery, towing and courier apps, the airline, several bird games). "Swoop: Fold to Fly" is out because "Fold to Fly" is Valley Run's tagline (`research/01-market.md` §2). "Tuck & Soar" teaches the two inputs.

If App Store Connect says the name is taken when you create the record, use the first that works, and tell Claude:

| Order | Fallback | Count |
|---|---|---|
| 1 | `Swoop: Fold to Soar` | 19 |
| 2 | `Foldwing: Tuck & Soar` | 21 |
| 3 | `Swoop: Tuck and Soar` | 20 |

The home-screen name under the icon is **Swoop** (`CFBundleDisplayName` in `project.yml`), whichever store name is used.

## 2. Subtitle (limit 30)

```
Fold your phone. Fly.
```
**21 / 30**, the same in en-GB and en-US. Duo-first in four words, and it indexes "fold", "phone" and "fly" without spending keyword bytes. It is not Valley Run's "Fold to Fly". It has no price, superlative or Apple mark (Guideline 2.3.7).

Alternative to A/B later (Product Page Optimization can't test the subtitle, so this would be a version change): `Stay ahead of the storm` (23), the app's own goal line.

## 3. Promotional text (limit 170; can change any time without a new version)

```
On iPhone Duo, hold it like a book: fold going down a wave, open going up. On any other iPhone, hold and let go. Stay ahead of the storm. No ads, no in-app purchases.
```
**166 / 170**, both locales. It leads with the Duo, because if the Duo screenshot slot is missing on upload day, this line, frame 1 and the description carry the Duo pitch, and it says straight away that other iPhones can play.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Flight is live: same waves for everyone, one try that counts. How far along the route can you get before the storm catches up?` (140)
- After a press mention: `"[real quote]" ([outlet]). ...` (only with a real quote).

## 4. Description (limit 4,000)

**en-GB 3,458 / 4,000; en-US 3,457 / 4,000.**

### en-GB (English U.K.)

```
The two halves of your iPhone Duo are a bird's wings.

Hold your Duo open like a book, one hand on each half. Fold it a little and your bird folds its wings and dives down the face of an ocean wave, picking up speed. Open it at the bottom and the bird flies off the top. One fold per wave: you never flap. A storm is chasing you out to sea. Stay ahead of it and reach the lighthouses along the route.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

FLIGHT SCHOOL
Your first flight starts with a short lesson on a calm practice sea. A guide gull shows each move first, then you copy it: fold, open, land, and how the storm works. Skip it if you like, and replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, the hinge is the control: easy folds of about 30° from a relaxed book pose, roughly one per wave. You never need to close the phone, lay it flat or fold fast. iPhone Duo softens one half of the screen for a moment when a fold starts from flat, so your bird flies on the half that stays sharp, and Settings lets you pick the side. On any other iPhone, press and hold anywhere on the way down and let go on the way up. Same sea, same top scores, but the fold is the best way to fly.

ONE MOVE, A LOT OF SKILL
• Fold (or hold) on the way down: heavier is faster
• Open (or let go) on the way up: lighter flies further
• Land on the way down of the next wave for a Perfect and a little extra speed
• Three perfect landings in a row: Tailwind! A golden trail and a burst of speed
• Nose-dive into a rising wave and you'll know about it: a big, heavy splash

STAY AHEAD OF THE STORM
The storm follows you, a wall of slate cloud and slanting rain, and it gets faster the longer you fly. Ahead, across the fold, the sky stays clear and golden. Perfect landings push the storm back. Sooner or later it catches up and the flight is over: no crash, just one more go.

THE ROUTE
The lighthouses are fixed places on a route out to sea: Gull Point at 4 km, Saltlight at 9 km, Kestrel Head at 15 km, and on. The next one is always on screen with the distance to go. Fly past one for a sweep of its beam, a distant bell and a lead over the storm, and it lights up on your Route. How far out can you get?

DAILY FLIGHT
Same waves for everyone, every day, and one try that counts. Then practise as much as you like. Keep your streak going and share your result.

GOALS, BIRDS AND SKIES
Three goals at a time take you up 15 levels. Eight birds, from Gull and Puffin to Albatross and Golden Gannet, five skies, from Golden Hour to Northern Lights and Moonrise, and coloured trails, unlocked as you level up. Every bird flies exactly the same; only the look changes.

SOUND AND FEEL
The wind, the hiss of the water, the chimes that climb with every perfect landing and the splash are all synthesised live in the app as you fly, and the haptics rise with your speed. Sound plays with the silent switch on; a setting makes Swoop respect it instead. Sound switches off, and haptics can be Off, Normal or Strong. Swoop follows Reduce Motion: no camera shake or screen bloom. Rather tap than hold? One tap folds the wings, the next opens them.

GAME CENTER
Top scores for your longest flight and the Daily Flight, and 12 achievements. It's optional: Swoop works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except three spellings: synthesised → synthesized, practise → practice, coloured → colored. Full text, ready to paste:

```
The two halves of your iPhone Duo are a bird's wings.

Hold your Duo open like a book, one hand on each half. Fold it a little and your bird folds its wings and dives down the face of an ocean wave, picking up speed. Open it at the bottom and the bird flies off the top. One fold per wave: you never flap. A storm is chasing you out to sea. Stay ahead of it and reach the lighthouses along the route.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

FLIGHT SCHOOL
Your first flight starts with a short lesson on a calm practice sea. A guide gull shows each move first, then you copy it: fold, open, land, and how the storm works. Skip it if you like, and replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, the hinge is the control: easy folds of about 30° from a relaxed book pose, roughly one per wave. You never need to close the phone, lay it flat or fold fast. iPhone Duo softens one half of the screen for a moment when a fold starts from flat, so your bird flies on the half that stays sharp, and Settings lets you pick the side. On any other iPhone, press and hold anywhere on the way down and let go on the way up. Same sea, same top scores, but the fold is the best way to fly.

ONE MOVE, A LOT OF SKILL
• Fold (or hold) on the way down: heavier is faster
• Open (or let go) on the way up: lighter flies further
• Land on the way down of the next wave for a Perfect and a little extra speed
• Three perfect landings in a row: Tailwind! A golden trail and a burst of speed
• Nose-dive into a rising wave and you'll know about it: a big, heavy splash

STAY AHEAD OF THE STORM
The storm follows you, a wall of slate cloud and slanting rain, and it gets faster the longer you fly. Ahead, across the fold, the sky stays clear and golden. Perfect landings push the storm back. Sooner or later it catches up and the flight is over: no crash, just one more go.

THE ROUTE
The lighthouses are fixed places on a route out to sea: Gull Point at 4 km, Saltlight at 9 km, Kestrel Head at 15 km, and on. The next one is always on screen with the distance to go. Fly past one for a sweep of its beam, a distant bell and a lead over the storm, and it lights up on your Route. How far out can you get?

DAILY FLIGHT
Same waves for everyone, every day, and one try that counts. Then practice as much as you like. Keep your streak going and share your result.

GOALS, BIRDS AND SKIES
Three goals at a time take you up 15 levels. Eight birds, from Gull and Puffin to Albatross and Golden Gannet, five skies, from Golden Hour to Northern Lights and Moonrise, and colored trails, unlocked as you level up. Every bird flies exactly the same; only the look changes.

SOUND AND FEEL
The wind, the hiss of the water, the chimes that climb with every perfect landing and the splash are all synthesized live in the app as you fly, and the haptics rise with your speed. Sound plays with the silent switch on; a setting makes Swoop respect it instead. Sound switches off, and haptics can be Off, Normal or Strong. Swoop follows Reduce Motion: no camera shake or screen bloom. Rather tap than hold? One tap folds the wings, the next opens them.

GAME CENTER
Top scores for your longest flight and the Daily Flight, and 12 achievements. It's optional: Swoop works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Duo first, then "plays on other iPhone models too"** (not "every iPhone": the deployment target is iOS 18, so iPhone XS / XR and later). The touch way is described honestly ("press and hold anywhere on the way down and let go on the way up") and not oversold ("the fold is the best way to fly"). The store page may talk about the Duo; the *app* never shows a Duo line on a non-Duo iPhone, and nothing here promises that it does.
- **The blur is explained once, plainly** ("softens one half of the screen for a moment when a fold starts from flat"), as an iOS behaviour Swoop works around, never as a Swoop fault.
- **The app's glossary** (see the top of this file).
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **No hinge-wear bait.** Never "flap", "slam", "snap" or "close it fast"; the copy says what Swoop *doesn't* ask for.
- **Nothing that echoes Tiny Wings** (`research/01-market.md` §3): no "tiny", no "islands", no "fever", no "before sunset"/"nightfall". The clock is the storm.
- **No violence words.** The bird is never hurt: the storm "catches up" and the flight is over.

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
bird,glide,wings,dive,ocean,wave,sea,surf,storm,gull,flying,hinge,foldable,endless,sky,lighthouse
```
**97 / 100 bytes**, both locales. Changed 27 Oct: "momentum" and "skim" (game-designer words nobody searches) out, "lighthouse" (the route is now the goal) in.
- Nothing repeats the name or subtitle: swoop, tuck, soar, fold, your, phone, fly are already indexed from them.
- Singular forms only ("wave", not "waves"): Apple matches plurals.
- No competitor names (Tiny Wings, Alto, Valley Run, Flappy Bird), no Apple marks ("iPhone", "Duo"). "wings" is the generic word for the game's own fantasy; it is never paired with "tiny".
- Apple combines words across fields, so "bird" + "fly", "fold" + "phone" + "foldable", "ocean" + "glide" and "endless" + "flying" form the searches people type.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `bird,glide,wings,dive,ocean,wave,seagull,storm,flying,hinge,foldable,endless,arcade,sky,lighthouse` (98)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
First flight. Hold your Duo like a book: fold going down a wave, open going up. Stay ahead of the storm and reach the lighthouses. On other iPhones, hold and let go.
```
(165 characters.) Template for 1.0.1 (fill in only what actually shipped):
```
Smoother folds on iPhone Duo, [one real change], and small fixes. Thanks for every perfect landing.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Casual** | `GAMES_CASUAL` |
| Game subcategory 2 | **Arcade** | `GAMES_ARCADE` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Casual is where paid one-input games chart, and its paid chart is shallow enough for a launch spike to show. Arcade is what Swoop is underneath (an endless distance chase, perfect landings in a row, top scores), and it puts us next to the momentum flyers people already know. Entertainment (optional) catches people browsing for "look what my phone does" apps, the same choice as Brim. **If Apple's live list no longer offers Arcade** (it was missing on 26 Oct, Brim run 40340641267), the tool uses **Action** instead.

## 8. Age rating: 4+

Answer the questionnaire exactly like this (App Store Connect → the app → App Information → Age Rating → Edit):

| Section | Item | Answer |
|---|---|---|
| In-app controls | Parental Controls | **No** |
| | Age Assurance | **No** |
| Capabilities | Unrestricted Web Access | **No** |
| | User-Generated Content | **No** |
| | Messaging and Chat | **No** |
| | Advertising | **No** |
| Mature themes | Profanity or Crude Humor | **None** |
| | Horror/Fear Themes | **None** |
| | Alcohol, Tobacco, or Drug Use or References | **None** |
| | Mature or Suggestive Themes | **None** |
| Medical or wellness | Medical or Treatment Information | **None** |
| | Health or Wellness Topics | **No** |
| Sexuality or nudity | Sexual Content or Nudity | **None** |
| | Graphic Sexual Content and Nudity | **None** |
| Violence | Cartoon or Fantasy Violence | **None** |
| | Realistic Violence | **None** |
| | Prolonged Graphic or Sadistic Realistic Violence | **None** |
| | Guns or Other Weapons | **None** |
| Chance-based activities | Simulated Gambling | **None** |
| | Contests | **None** |
| | Gambling | **No** |
| | Loot Boxes | **No** |
| Kids | Made for Kids | **No** |

**Expected result: 4+.** If the form you see has extra or renamed items, the honest answer to each is None or No.

Why each risky item is None:
- **Horror/Fear:** the storm is weather, not a monster: slate cloud, rain and a distant rumble, with an occasional soft lightning flicker. Nothing jumps out. Being caught is calm: the storm passes over, "The storm caught you" appears, and the Results card follows.
- **Violence:** a splash is a splash. The bird is never hurt, never falls, never dies.
- **Simulated gambling / loot boxes:** no chance-based rewards and nothing to buy. Birds, skies and trails unlock by level, and the Daily Flight is the same fixed waves for everyone, not a prize draw.
- **Contests:** Game Center leaderboards are not prize contests.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Swoop is for everyone, not built for under-11s specifically.

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99**; Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam** (paid games there need a government game licence) |
| Pre-order | **No** |
| Release | **Automatically release this version after App Review approval** (live as soon as Apple approves; nothing to press. Founder's decision, 27 Oct, DECISIONS #12) |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | `© 2026 pravegm` |
| Support URL | `https://pravegm.github.io/swoop/support.html` |
| Marketing URL | `https://pravegm.github.io/swoop/` |
| Privacy Policy URL | `https://pravegm.github.io/swoop/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Reduced Motion**, **Sufficient Contrast**, **Differentiate Without Color Alone**, each only after its check passes, published on the day Swoop goes live (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` |
| Game Center | On; 2 leaderboards and 12 achievements, 625 points (`achievements.md`) |
| Sign-in required | No |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`) |

**About the three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/swoop/` once Pages is on (runbook step 1). The real pages are in `docs/site/`. `docs/index.html`, `docs/support.html` and `docs/privacy.html` are tiny forwarding pages, so the short addresses above work. If a reviewer or tool ever objects to the forward, use the direct addresses instead: `https://pravegm.github.io/swoop/site/`, `…/site/support.html`, `…/site/privacy.html`.

## 10. Claims to check against the release-candidate build

Checked against the release candidate on 27 Oct by QA-FINAL (commit `efdfdbf (CI run 40512902788, green)`). Before submission, Claude (or whoever cuts the release candidate) re-ticks each line on that build ("RC") or changes the copy, never the other way round.

| Claim (where) | Source in the code (27 Oct) | Code | RC |
|---|---|---|---|
| Duo: fold = the wings fold and the bird dives; open = it flies off the top; one fold per wave | `Input/HingeTuckSource.swift`; Flight School "One per wave" (`UX-ROUND-9` §1.2) | [x] | [ ] |
| Other iPhones: press and hold anywhere on the way down, let go on the way up | `Input/TouchTuckSource.swift`; Home caption "Hold going down. Let go going up." | [x] | [ ] |
| Tapping alternative: one tap folds, the next opens | `UI/SettingsView.swift` "Wings by: Holding · Tapping" | [x] | [ ] |
| Flight School on the first flight: calm practice sea, the guide gull shows each move, skippable, replay from Settings | `App/FlightSchool.swift`, `UI/FlightSchoolView.swift`, `Scene/SceneGuideGull.swift`, Settings "Flight School" | [x] | [ ] |
| Never needs closing, flat or fast folds; folds of about 30°, roughly one per wave | `Core/Tuning.swift`, stroke-rate fix 98595e2 | [x] | [ ] |
| The bird flies on the half that stays sharp; Settings → Bird side (Sharp side (auto) · Left · Right on a Duo) | `Input/SharpHalf.swift`, `UI/SettingsView.swift` `birdSideRow` | [x] | [ ] |
| Perfect = a little extra speed (`perfectBoost` 6 %); Tailwind at 3 in a row, +15 % speed | `Core/Tuning.swift` | [x] | [ ] |
| The storm speeds up; perfect landings push it back (`perfectGapBonus`); caught = "The storm caught you", then Results ("Flight over") | `Core/Tuning.swift`, `UX-ROUND-9` §2.1 | [x] | [ ] |
| Fixed route: Gull Point 4 km, Saltlight 9 km, Kestrel Head 15 km…; the next one always on screen; beam, bell, lead (`lighthouseGapBonus`); the Route page | `Core/Lighthouses.swift`, `UI/PlayHUD.swift`, `UI/RouteView.swift` | [x] | [ ] |
| Daily Flight: same waves for everyone, one try that counts, practice after, streak, share | `UI/HomeView.swift` ("Same waves for everyone · 1 try"), `UI/ShareText.swift` | [x] | [ ] |
| Goals: 3 at a time, 15 levels; 8 birds, 5 skies and trails, unlocked as you level up (Gull and Golden Hour from the start); every bird flies the same | `Core/Goals.swift`, `Core/Catalogs.swift` (`TrailCatalog`), `UI/FlocksView.swift` ("Level n of 15") | [x] | [ ] |
| All sound synthesised live; no audio files in the bundle | `Feedback/FeelSynth.swift` | [x] | [ ] |
| Sound on silent; "Respect silent switch"; Sound on/off; Haptics Off · Normal · Strong | `UI/SettingsView.swift` | [x] | [ ] |
| Follows iOS Reduce Motion: no camera shake or screen bloom | `UI/SettingsView.swift` (info row) | [x] | [ ] |
| 2 leaderboards (the "Scores" button on Home; VoiceOver "Top scores") + 12 achievements report from the build | `App/GameCenterManager.swift`, `Persistence/ProgressStore.swift` | [x] | [ ] |
| No network code, no SDKs (privacy) | `privacy.md` §3 grep: no `URLSession`, `URLRequest`, `NWConnection`, `import Network`, `WKWebView`, `SFSafari`, `openURL`, `Link(`, ATT, `ASIdentifier`, CloudKit or SDK in `Swoop/`; no `packages:` in `project.yml`; GameKit is the only outbound path | [x] | [ ] |
