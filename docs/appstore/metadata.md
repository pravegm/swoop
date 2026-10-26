# Swoop: App Store metadata (v1.0)

*Written Mon 26 Oct 2026 by the launch lead. Paste from the code blocks exactly. Counts are Unicode characters, except keywords, which Apple counts in bytes (all ASCII here, so the same). Each choice has a one-line reason in `DECISIONS.md`. Every feature claim comes from `design/GAME-DESIGN.md`. The build didn't exist yet when this was written, so the claims listed in §10 must be checked against the release-candidate build before submission.*

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

Alternative to A/B later (Product Page Optimization can't test the subtitle, so this would be a version change): `Fold to dive. Beat the storm.` (29).

## 3. Promotional text (limit 170; can change any time without a new version)

```
On iPhone Duo, hold it like a book: fold a little to dive, open to soar. On any other iPhone, hold to tuck. Outfly the storm. No ads, no in-app purchases.
```
**154 / 170**, both locales. It leads with the Duo, because if the Duo screenshot slot is missing on upload day, this line, frame 1 and the description carry the Duo pitch, and it says straight away that other iPhones can play.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Flight is live: the same sea for everyone, one scored try. How many lighthouses can you pass before the storm catches you?` (136)
- After a press mention: `"[real quote]" ([outlet]). ...` (only with a real quote).

## 4. Description (limit 4,000)

**en-GB 2,834 / 4,000; en-US 2,834 / 4,000.**

### en-GB (English U.K.)

```
The two halves of your iPhone Duo are a bird's wings.

Hold your Duo open like a book, one hand on each half. Fold it in a little and your bird tucks its wings and dives down the face of an ocean swell, picking up speed. Open it at the bottom and the bird soars off the next crest. Keep skimming, keep launching, and outfly the storm that's chasing you across the sea.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo, the hinge is the control: short, slow squeezes in a relaxed book pose, about one swell every two or three seconds. You never need to close the phone, lay it flat or fold fast. On any other iPhone, press and hold anywhere to tuck and let go to soar. Same sea, same leaderboards, but the fold is the best way to fly.

ONE MOVE, A LOT OF SKILL
• Tuck on the way down: heavier is faster
• Open on the way up: lighter flies further
• Land on the next downslope for a Perfect skim and a little extra speed
• Three Perfects in a row catch a Tailwind: a golden trail and a burst of speed
• Nose-dive into a rising wave and you'll know about it: a big, heavy splash

OUTFLY THE STORM
A storm front follows you from behind, a wall of slate cloud and slanting rain, and it gets faster the longer you fly. Ahead, across the fold, the sky stays clear and golden. Every Perfect pushes the storm back. When it catches you, your bird simply tucks its head and rides the swell. No crash, just one more go.

LIGHTHOUSES
Lighthouses stand along the way, each with its own name. Pass one for a sweep of its beam, a distant bell and a big lead over the storm. How many can you reach?

DAILY FLIGHT
The same sea for everyone, every day. One scored try, then practise as much as you like. Keep your streak going and share your result.

FLOCKS, BIRDS AND SKIES
Work through goals three at a time to rank up from Fledgling to Storm Rider. Ranks unlock eight birds, from Gull and Puffin to Albatross and Golden Gannet, and five skies, from Golden Hour to Northern Lights and Moonrise. Every bird flies exactly the same; only the look changes.

SOUND AND FEEL
The wind, the hiss of the skim, the chimes that climb with each Perfect and the splash are all synthesised live in the app as you fly, and the haptics rise with your speed. Sound plays with the silent switch on; a setting makes Swoop respect it instead. Sound and haptics each switch off in Settings. With Reduce Motion on, camera shake and screen bloom are turned off. Rather have the bird on the other side? There's a setting for that too.

GAME CENTER
Leaderboards for your longest flight and the Daily Flight, and 12 achievements. It's optional: Swoop works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except two spellings (same length): synthesised → synthesized, practise → practice. Full text, ready to paste:

```
The two halves of your iPhone Duo are a bird's wings.

Hold your Duo open like a book, one hand on each half. Fold it in a little and your bird tucks its wings and dives down the face of an ocean swell, picking up speed. Open it at the bottom and the bird soars off the next crest. Keep skimming, keep launching, and outfly the storm that's chasing you across the sea.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo, the hinge is the control: short, slow squeezes in a relaxed book pose, about one swell every two or three seconds. You never need to close the phone, lay it flat or fold fast. On any other iPhone, press and hold anywhere to tuck and let go to soar. Same sea, same leaderboards, but the fold is the best way to fly.

ONE MOVE, A LOT OF SKILL
• Tuck on the way down: heavier is faster
• Open on the way up: lighter flies further
• Land on the next downslope for a Perfect skim and a little extra speed
• Three Perfects in a row catch a Tailwind: a golden trail and a burst of speed
• Nose-dive into a rising wave and you'll know about it: a big, heavy splash

OUTFLY THE STORM
A storm front follows you from behind, a wall of slate cloud and slanting rain, and it gets faster the longer you fly. Ahead, across the fold, the sky stays clear and golden. Every Perfect pushes the storm back. When it catches you, your bird simply tucks its head and rides the swell. No crash, just one more go.

LIGHTHOUSES
Lighthouses stand along the way, each with its own name. Pass one for a sweep of its beam, a distant bell and a big lead over the storm. How many can you reach?

DAILY FLIGHT
The same sea for everyone, every day. One scored try, then practice as much as you like. Keep your streak going and share your result.

FLOCKS, BIRDS AND SKIES
Work through goals three at a time to rank up from Fledgling to Storm Rider. Ranks unlock eight birds, from Gull and Puffin to Albatross and Golden Gannet, and five skies, from Golden Hour to Northern Lights and Moonrise. Every bird flies exactly the same; only the look changes.

SOUND AND FEEL
The wind, the hiss of the skim, the chimes that climb with each Perfect and the splash are all synthesized live in the app as you fly, and the haptics rise with your speed. Sound plays with the silent switch on; a setting makes Swoop respect it instead. Sound and haptics each switch off in Settings. With Reduce Motion on, camera shake and screen bloom are turned off. Rather have the bird on the other side? There's a setting for that too.

GAME CENTER
Leaderboards for your longest flight and the Daily Flight, and 12 achievements. It's optional: Swoop works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Duo first, then "plays on every iPhone"** in the second section. The touch fallback is described honestly ("press and hold anywhere to tuck") and not oversold ("the fold is the best way to fly").
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **No hinge-wear bait.** Never "flap", "slam", "snap" or "close it fast"; the copy says what Swoop *doesn't* ask for.
- **Nothing that echoes Tiny Wings** (`research/01-market.md` §3): no "tiny", no "islands", no "fever", no "before sunset"/"nightfall". The clock is the storm.
- **No violence words.** The bird is never hurt: the storm "catches" it and it "rides the swell".

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
bird,glide,wings,dive,ocean,wave,sea,surf,storm,gull,flying,hinge,foldable,endless,momentum,sky,skim
```
**100 / 100 bytes**, both locales.
- Nothing repeats the name or subtitle: swoop, tuck, soar, fold, your, phone, fly are already indexed from them.
- Singular forms only ("wave", not "waves"): Apple matches plurals.
- No competitor names (Tiny Wings, Alto, Valley Run, Flappy Bird), no Apple marks ("iPhone", "Duo"). "wings" is the generic word for the game's own fantasy; it is never paired with "tiny".
- Apple combines words across fields, so "bird" + "fly", "fold" + "phone" + "foldable", "ocean" + "glide" and "endless" + "flying" form the searches people type.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `bird,glide,wings,dive,ocean,wave,seagull,storm,flying,hinge,foldable,endless,arcade,sky,lighthouse` (98)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
First flight. Hold your Duo like a book, fold a little to dive and open to soar. Outfly the storm. On other iPhones, hold to tuck.
```
Template for 1.0.1 (fill in only what actually shipped):
```
Smoother tucks on iPhone Duo, [one real change], and small fixes. Thanks for every Perfect.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Casual** | `GAMES_CASUAL` |
| Game subcategory 2 | **Arcade** | `GAMES_ARCADE` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Casual is where paid one-input games chart, and its paid chart is shallow enough for a launch spike to show. Arcade is what Swoop is underneath (endless score chase, chains, leaderboards), and it puts us next to the momentum flyers people already know. Entertainment (optional) catches people browsing for "look what my phone does" apps, the same choice as Brim.

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
- **Horror/Fear:** the storm is weather, not a monster: slate cloud, rain and a distant rumble, with an occasional soft lightning flicker. Nothing jumps out. Being caught is calm (the bird rides the swell under the rain).
- **Violence:** a splash is a splash. The bird is never hurt, never falls, never dies.
- **Simulated gambling / loot boxes:** no chance-based rewards and nothing to buy. Birds and skies unlock by rank, and the Daily seed is a fixed sea, not a prize draw.
- **Contests:** Game Center leaderboards are not prize contests.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Swoop is for everyone, not built for under-11s specifically.

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99**; Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland** (paid games there need a government ISBN licence) |
| Pre-order | **No** |
| Release | **Manually release this version**. The founder presses Release on **Tue 24 Nov 2026 at about 08:00 UK time** (runbook §7) |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | `© 2026 pravegm` |
| Support URL | `https://pravegm.github.io/swoop/support.html` |
| Marketing URL | `https://pravegm.github.io/swoop/` |
| Privacy Policy URL | `https://pravegm.github.io/swoop/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Reduced Motion**, **Sufficient Contrast**, **Differentiate Without Color Alone**, each only after its check passes, published on launch day (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` |
| Game Center | On; 2 leaderboards and 12 achievements, 625 points (`achievements.md`) |
| Sign-in required | No |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`) |

**About the three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/swoop/` (runbook §0b). The real pages are in `docs/site/`. `docs/index.html`, `docs/support.html` and `docs/privacy.html` are tiny forwarding pages, so the short addresses above work. If a reviewer or tool ever objects to the forward, use the direct addresses instead: `https://pravegm.github.io/swoop/site/`, `…/site/support.html`, `…/site/privacy.html`.

## 10. Claims to check against the release-candidate build

The build didn't exist when this was written. Before submission, Claude (or whoever cuts the release candidate) ticks each line or changes the copy, never the other way round.

| Claim (where) | Source today | Check |
|---|---|---|
| Book pose: fold a little = tuck and dive, open = soar (everywhere) | Bible §3, `HingeTuckSource` | [ ] |
| "Press and hold anywhere to tuck, let go to soar" on other iPhones (description, promo, review notes) | Bible §3, `TouchTuckSource` | [ ] |
| Never needs closing, flat or fast folds; one swell every 2–3 s | Bible §2.4, §3 (play band 100–178°, ready pose 130–170°) | [ ] |
| Perfect = a little extra speed; Tailwind = 3 Perfects, golden trail, burst of speed | Bible §5–6, `Tuning` | [ ] |
| Storm follows from behind, speeds up, Perfects push it back; caught = rides the swell | Bible §6 | [ ] |
| Lighthouses with names, beam, bell, lead | Bible §6, `Lighthouses` | [ ] |
| Daily Flight: one scored try, practice after, streak, share | Bible §8 | [ ] |
| Flocks: 3 goals at a time, Fledgling → Storm Rider (15 ranks) | Bible §8, `GoalCatalog` | [ ] |
| 8 birds (Gull, Puffin, Albatross, Golden Gannet named) and 5 skies (Golden Hour, Northern Lights, Moonrise named); all birds fly the same | Bible §8, `BirdCatalog`, `SkyCatalog` | [ ] |
| All sound synthesised live; no audio files in the bundle | Bible §7 | [ ] |
| Sound plays on silent; "respect silent switch" setting | Bible §7, §10 | [ ] |
| Separate Sound and Haptics switches; Reduce Motion turns off camera shake and bloom | Bible §3, §10 | [ ] |
| "Bird on the other side" setting | Bible §10 | [ ] |
| 2 leaderboards + 12 achievements report from the build | `achievements.md` | [ ] |
| No network code, no SDKs (privacy) | `privacy.md` grep | [ ] |
