# Swoop: App Store screenshot plan (v1.0)

*Written Mon 26 Oct 2026. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-swoopDemo "…"` (keys in `design/ROUND-1.md`) on the iPhone Duo simulator (`ci/duo.sh` store pass) and the iPhone simulators (`ci/screenshots.sh`), then captioned on the Mac runner. The scenario lines below go into **`ci/store-scenarios.txt`** (format `name|demo args|wait|caption|expect`, which `ci/duo.sh` and `ci/screenshots.sh` already read). Once that file exists it is the source of truth: change a caption there, not only here. The pipeline pieces still to port from Brim are listed in `DECISIONS.md` §2.*

## Sets and sizes

Swoop plays in **landscape** (the Duo held like a book: a 951 × 669 pt inner canvas with the fold running top to bottom). Every set is landscape.

| Set | Pixels (landscape) | Frames | Captured by | Upload |
|---|---|---|---|---|
| **iPhone Duo, inner display** (the hero set) | **2853 × 2007** (951 × 669 pt at 3×; Apple lists the slot as 2007 × 2853, and landscape is the same size turned sideways) | **6** (D1–D6) | `duo.yml` → `ci/duo.sh` store pass with `STORE_LIST=ci/store-scenarios.txt` and `STORE_FILTER=^D` | By hand in the web UI, **if** App Store Connect shows an iPhone Duo slot (`DECISIONS.md` #14) |
| **iPhone 6.9"** | **2868 × 1320** | **5** (P1–P5) | `ci/screenshots.sh` on the iPhone 18 Pro Max (fallback: newest `… Pro Max`) | Web UI, "6.9-inch Display" |
| **iPhone 6.1" class** | **2556 × 1179** (or 2532 × 1170); **2622 × 1206** when the runner has no 6.1-inch simulator | **5** (P1–P5) | `ci/screenshots.sh` on the newest simulator with that screen, else the iPhone 18 Pro (6.3") | Web UI: 2556 × 1179 and 2622 × 1206 go in the **6.3-inch** slot, 2532 × 1170 in the **6.1-inch** slot |

Rules: PNG or JPEG, **no alpha channel**, 1–10 per size. In search results a landscape set shows **only its first frame**, so **frame 1 has to sell the whole game on its own**, and frames 1–3 must each make sense alone on the product page.

**Check before upload:** open Apple's *Screenshot specifications* page and confirm the iPhone Duo slot accepts the landscape size. If it accepts portrait only, the Duo set ships with 1.0.1 (a rotated landscape frame on its side would be wrong).

## Frame 1 is the Duo held like a book, with the bird across the fold

The hero image is the whole pitch: **a real iPhone Duo held open like a book, and on its two halves the title bird whose wings span the fold**. A flat capture of the inner display can't show that (it reads as a wide picture, not a folded phone), so frame 1 is a **store shot**: CI captures the live title screen on the Duo simulator (the bird across both halves, wings part-tucked) and maps that capture onto a modelled Duo standing open at about 150° in book pose, seen from a 3/4 front eye. This is Squish's approach (`Squish/Scene/Fold/FoldStoreShot.swift`, renders `*-storeshot-*.png`), to be ported for book pose (request in `DECISIONS.md` §2).

- **Truthful:** the screen content is an unaltered capture of the app; the device is a model of the real Duo at an angle Swoop is played at. Nothing is drawn on the screen that the app doesn't render.
- **No hands drawn** in 1.0 (a modelled hand looks fake). The founder's real-hands photo of the same moment is the 1.0.1 upgrade, as with Squish.
- **Used in every set** as frame 1, including the iPhone sets: if App Store Connect has no Duo slot on upload day, the 6.9" set is the only one anyone sees, and its first frame must still say "Duo first". The caption's sub-line says other iPhones can play. It never shows a non-folding iPhone folded.
- **Fallback** if the store shot isn't ready by code freeze (Mon 16 Nov): D1/P1 = the raw title-screen capture (bird across the crease) with the caption "Hold your Duo like a *book*." Tell the founder; the store shot then ships with 1.0.1.

## Caption style (what the caption renderer draws)

- **Layout:** a dusk sweep (deep slate `#14212E` on the storm side → warm gold `#F6B73C` glow on the clear side), mirroring the game's own composition: storm left, clear sky right. Caption band across the top 4–22% of the frame. Below it the **screenshot itself, unaltered**, scaled to fit, rounded corners, hairline edge, soft shadow. The caption never covers the bird, the crease band or the lead meter.
- **No device frame** on frames 2–6 (D) or 2–5 (P): only frame 1 is a store shot.
- **Type:** SF Pro Rounded Heavy (plain system Heavy if unavailable), warm white `#FFF8EE`. Headline cap height starts at 5.5% of the image height and shrinks in 5% steps until it fits in ≤ 2 balanced lines (floor 4%: landscape frames are short). **One** highlighted word, written `*word*` in the scenario file (*in italics here*), drawn in ink `#13212E` on a gold `#F6B73C` marker swash. Optional sub-line after ` / ` in SF Pro Rounded Semibold at ~46%, `#E9DCC6`.
- **Seven words maximum** per headline. No logo on any frame.

## A. iPhone Duo, inner display (2853 × 2007): 6 frames

| # | In-game moment | Caption: headline / sub-line | Scenario line (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **D1** | **Store shot:** the modelled Duo held open like a book at ~150°, the title bird's wings spanning both halves across the fold, Golden Hour sky | **The two halves are your *wings*.** / *Hold your Duo like a book.* | `D1-book-hero\|screen=home;bird=gull;sky=goldenHour;storeshot=book\|12\|The two halves are your *wings*. / Hold your Duo like a book.\|storeshot done` |
| **D2** | Mid-flight just after a launch: the bird stretched off a crest on the left half, spray burst, the swells and a lighthouse ahead on the right half | **Fold a little. *Dive.*** / *Open at the crest to soar.* | `D2-launch\|mode=flight;seed=7;autopilot=perfect;freezeOn=launch;freezeAfter=6\|20\|Fold a little. *Dive.* / Open at the crest to soar.\|freeze launch` |
| **D3** | A Perfect skim: white ring on the water, gold trail, PERFECT ×4 | **Land the downslope. *Perfect.*** / *Three in a row catch a Tailwind.* | `D3-perfect\|mode=flight;seed=7;autopilot=perfect;chain=3;freezeOn=perfect\|20\|Land the downslope. *Perfect.* / Three in a row catch a Tailwind.\|freeze perfect` |
| **D4** | The storm close: slate cloud and slanting rain on the left half, lead meter low, clear gold sky ahead across the fold | ***Outfly* the storm.** / *Every Perfect pushes it back.* | `D4-storm\|mode=flight;seed=11;autopilot=casual;lead=0.12;freezeOn=stormclose\|20\|*Outfly* the storm. / Every Perfect pushes it back.\|freeze stormclose` |
| **D5** | Passing a lighthouse: beam sweep, name card ("Gull Point" or whichever the seed gives) | **Reach the next *lighthouse*.** / *Each one buys you a lead.* | `D5-lighthouse\|mode=flight;seed=7;autopilot=expert;freezeOn=lighthouse\|60\|Reach the next *lighthouse*. / Each one buys you a lead.\|freeze lighthouse` |
| **D6** | Birds screen, mid progress: several birds unlocked, the rest locked with their rank | **Eight birds. Five *skies*.** / *No ads. No in-app purchases.* | `D6-birds\|screen=birds;progress=mid\|10\|Eight birds. Five *skies*. / No ads. No in-app purchases.\|` |

Reserves (capture with `STORE_FILTER=^(D\|R)`): `RD-tailwind` (`freezeOn=tailwind`), **Catch a *Tailwind*.** / *A golden burst of speed.*; `RD-daily` (`screen=results;mode=daily`), **One *Daily Flight*. Same sea for all.**

## B. iPhone 6.9" (2868 × 1320) and 6.1" class (2556 × 1179 / 2622 × 1206): 5 frames each

Same frames and captions at both sizes. Captured with the `touch` key so no Duo-only hint shows. In the scenario lines, `…` means "the same caption as the matching D frame": write it out in full in `ci/store-scenarios.txt`.

| # | In-game moment | Caption: headline / sub-line | Scenario line |
|---|---|---|---|
| **P1** | **The D1 store shot**, re-rendered at the phone slot size | **The two halves are your *wings*.** / *Best on iPhone Duo. Hold to tuck on any iPhone.* | `P1-book-hero\|screen=home;bird=gull;sky=goldenHour;storeshot=book;storeshotsize=phone\|12\|The two halves are your *wings*. / Best on iPhone Duo. Hold to tuck on any iPhone.\|storeshot done` |
| **P2** | Mid-flight after a launch (as D2), touch input | **Hold to *dive*. Let go to soar.** / *On any iPhone.* | `P2-launch\|mode=flight;seed=7;autopilot=perfect;touch;freezeOn=launch;freezeAfter=6\|20\|Hold to *dive*. Let go to soar. / On any iPhone.\|freeze launch` |
| **P3** | A Perfect skim, chain 4 (as D3) | **Land the downslope. *Perfect.*** / *Three in a row catch a Tailwind.* | `P3-perfect\|mode=flight;seed=7;autopilot=perfect;touch;chain=3;freezeOn=perfect\|20\|…\|freeze perfect` |
| **P4** | The storm close (as D4) | ***Outfly* the storm.** / *Every Perfect pushes it back.* | `P4-storm\|mode=flight;seed=11;autopilot=casual;touch;lead=0.12;freezeOn=stormclose\|20\|…\|freeze stormclose` |
| **P5** | Birds screen, mid progress | **Eight birds. Five *skies*.** / *No ads. No in-app purchases.* | `P5-birds\|screen=birds;progress=mid\|10\|…\|` |

The sub-line of P1 is longer than the usual one line; if it doesn't fit at ≥ 36% of the headline size, shorten it to *Or hold to tuck, on any iPhone.*

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture from the app; captions sit above it. No composited spray, rings, birds or skies.
- [ ] **Frame 1's device is a real iPhone Duo pose** (book, about 150°), never a non-folding iPhone drawn folded, never closed or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build:** "Three in a row catch a Tailwind" only if a Tailwind is 3 Perfects; "Every Perfect pushes it back" only if a Perfect adds lead; "Eight birds. Five skies." only if the Birds screen shows 8 birds and the skies exist; "Hold to tuck on any iPhone" only if press-and-hold is the touch control.
- [ ] **Seeded states are reachable states:** chain 3–4, a low lead and "mid progress" are things a real player sees. Never seed every bird unlocked or an impossible distance.
- [ ] **No stale hint text** that contradicts the caption (for example "Fold on the way down" on a touch frame: use `touch` and no `hints=fresh`).
- [ ] **Nothing important in the crease band** (x ≈ 456–496 pt) on the Duo frames, except the title bird's body in D1, which is the point.
- [ ] **No prices, dates, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha.** Captions readable at 25% zoom.

## Upload order and checks (founder, runbook §6e)
1. 6.9" slot: P1–P5. 2. 6.1"/6.3" slot: P1–P5. 3. If an **iPhone Duo** entry appears in the device list: D1–D6, then check them in App Store Connect's iPhone Duo preview. If there's no Duo entry, skip it; the Duo set ships with 1.0.1 (screenshots only change with a new version).

**Never upload** a frame from outside the captioned `store/` folder of the run Claude names, anything in `store/_flagged/`, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- App Store Connect Help, *Screenshot specifications* (iPhone Duo inner 2007 × 2853; 6.9" 1320 × 2868; 6.1"-class 1206 × 2622; landscape accepted for iPhone; 1–10 per size; no alpha): https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple Developer Forums 845505 (Duo slot not yet in the selector or API, Oct 2026), as recorded in Brim's plan
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Brim's and Squish's plans (rules mirrored): `C:\Users\59527\Fold\docs\appstore\screenshots.md`, `C:\Users\59527\Squish\docs\appstore\screenshots.md`
