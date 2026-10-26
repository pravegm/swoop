# Swoop: App Store screenshot plan (v1.0)

*Written Mon 26 Oct 2026, pipeline built the same day (Round 4, `design/notes/store-R4.md`). Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-swoopDemo "…"` (keys in the header of `Swoop/App/DemoMode.swift` and `design/ROUND-1.md`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. **The scenario files are the source of truth**: `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). Change a caption there, not only here.*

## How to make the sets

GitHub → Actions → **App Store screenshots** (`.github/workflows/store.yml`) → Run workflow. Inputs: which sets, an optional `duo_from_run` (reuse the Duo captures of an earlier run instead of the slow Duo job), the simulators, the name filters, and `book_angle`.

1. **phones** builds the app and captures P1–P8 on the iPhone 18 Pro Max and the iPhone 18 Pro (`ci/store-capture.sh` → `ci/screenshots.sh`, retrying missing or wrong-sized frames twice).
2. **duo** captures D1–D8 on the iPhone Duo's inner display (`ci/store-capture.sh` → `ci/duo.sh` store pass, hinge held at 150°).
3. **assemble** captions every set (`ci/store-set.sh` + `ci/store-frame.swift`) and turns D1's real Duo capture into the **book-pose composite** that is frame 1 of every set.

Artifacts: **`store-duo`**, **`store-69`**, **`store-63`**, each holding the upload-ready `*.png` (in name order), `MANIFEST.txt` / `MANIFEST.tsv` (file, size, slot match, caption, OK / FLAGGED / MISSING / FAILED and why) and `_flagged/`. The `raw-*` artifacts are the unframed captures and their app logs, for debugging. One bad frame never fails the run.

## Sets, sizes and slots (verified 26 Oct 2026 against Apple's *Screenshot specifications*)

Swoop plays in **landscape** (the Duo held like a book: a 951 × 669 pt inner canvas with the fold running top to bottom). Every set is landscape, and Apple lists landscape sizes for every iPhone row.

| Upload order | App Store Connect slot (Apple's row) | Pixels (landscape) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **2868 × 1320** (also accepted: 2796 × 1290, 2736 × 1260) | P1–P8 | `store-69` | Optional, but upload it: Apple scales it down for the 6.5" row, so 6.5" (2778 × 1284 / 2688 × 1242) needs nothing of its own |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **2622 × 1206** (also accepted: 2556 × 1179) | P1–P8 | `store-63` | **Required** (Apple's only required iPhone size); Apple scales it down for 6.1" and smaller |
| 3 | **iPhone Duo, inner display** | **2853 × 2007** (portrait 2007 × 2853 is the same slot) | D1–D8 | `store-duo` | Listed by Apple, no requirement stated. Apple: "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later", and submitting Duo screenshots shows the "optimized for iPhone Duo" badge on the product page |
| – | iPhone Duo, outer (cover) display | 2034 × 1398 (portrait 1398 × 2034) | none | – | Not made: Swoop is not played on the cover; Apple does not say both Duo sizes are needed |

**Does App Store Connect have an iPhone Duo slot?** Apple's specification page lists one (inner 2853 × 2007, outer 2034 × 1398). But in October 2026 developers reported that the version page's device selector and the API's `ScreenshotDisplayType` had no Duo entry yet (Apple Developer Forums 845505). So: **look for an "iPhone Duo" entry on upload day.** If it's there, upload `store-duo` (D1–D8). If it isn't, ship 1.0 with the 6.9" and 6.3" sets only: their frame 1 is the Duo book composite, so the Duo story is still the first thing anyone sees; add the Duo set with 1.0.1 (screenshots only change with a new version, and before April 2027).

Rules: PNG, **no alpha channel** (the compositor writes opaque sRGB; `store-set.sh` checks with `sips`), 1–10 per size (we use 8). In search results a landscape set shows **only its first frame**, so frame 1 has to sell the whole game on its own, and frames 1–3 must each make sense alone on the product page.

## Frame 1 is the Duo held like a book, with the bird across the fold

The hero is the whole pitch: **an iPhone Duo standing open like a book, the title bird's wings spanning its two halves.** `store-frame --book` takes D1, a **real Duo inner-display capture** of Home (2853 × 2007), splits it at the fold (x = 1428 px; the crease band is x ≈ 1368–1488), and maps each half by a true perspective transform (Core Image `CIPerspectiveTransform`) onto one page of a stylised Duo open at **140°** (each page turned 20° toward the viewer; `book_angle=auto` uses the hinge angle in the capture's own log when it has one, which is the 150° the Duo was held at), tilted back 8° and seen from in front, slightly above. Around it: a thin graphite bezel lit from the right, the hinge spine (a metal barrel at the top and bottom, a seam in the bezel), a soft drop shadow and a ground shadow. **No hands.**

- **Truthful:** every screen pixel is the app's, only warped and clipped to the display's rounded corners. Nothing is drawn on the screen. The device is the real Duo pose Swoop is played in.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture), because without a Duo slot the 6.9" set is all anyone sees. The iPhone caption's sub-line says other iPhones can play. It never shows a non-folding iPhone folded.
- **Fallback, automatic:** if D1's capture is missing or isn't a 2853 × 2007 inner-display frame of the folded canvas (`SWOOP-T canvas 951x669 fold=1`), P1 is made flat from the iPhone's own Home capture and **FLAGGED**. Rerun the Duo job (or pass `duo_from_run`); don't upload a flat P1 without telling the founder.
- 1.0.1 upgrade: the founder's real-hands photo of the same moment, as with Squish.

## Caption style (what `ci/store-frame.swift` draws)

- **Layout:** the caption band runs **across the top** (3.5–21.5 % of the height) with the screenshot under it (24–96.5 %). In a landscape frame a ≤ 7-word headline fits on one line at a size that still reads in a search thumbnail, the eye goes caption → picture, and the capture keeps ~55 % of the frame (a side column leaves ~44 %) with its storm-left / sun-right split intact. **Exception:** the book frame on the iPhone slots (2.2 : 1) puts the caption in a **left column** (left-aligned, up to three lines) with the book on the right, because a book is only ~1.25 : 1 and would fill under half the width under a top band.
- **Background:** a diagonal sweep from deep sea-navy (`#0B2236` UI surface, `#0A2B44` near-deep sea) to dusk (`#2E2A5E` Rose Dusk zenith → `#7A5C9E`), with the Golden Hour sun glow `#FFC46B` added on the right with plus-lighter blending (never gold at partial alpha over navy, ART-DIRECTION §2), and a soft shade along the bottom.
- **Flat frames (2–8):** the capture itself, unaltered, scaled to fit, rounded corners (9 % of the short side on iPhone, 5 % on Duo), a hairline edge and a soft shadow. No device frame.
- **Type:** SF Pro Rounded Heavy (plain system Heavy if missing), foam `#F2F7FA`. Headline cap height starts at 6 % of the image height and shrinks in 5 % steps until it fits in ≤ 2 balanced lines (floor 4 %; side column: 8.5 %, ≤ 3 lines, floor 5 %). **One** highlighted word, `*word*` in the scenario file, drawn as ink `#0E2438` letters on a UI-gold `#F7C75B` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold at ~46 %, mist `#B6CCDA` (top band: shrinks to stay on one line, floor 36 %).
- **Seven words maximum** per headline, no logo, never "Fold to Fly" (Valley Run's tagline) and none of DECISIONS #36's words. `store-set.sh` lints all three.

## A. iPhone 6.9" (2868 × 1320) and 6.3" (2622 × 1206): 8 frames each

Same frames and captions at both sizes, captured with the `touch` key so no Duo-only hint shows.

| # | In-game moment | Caption: headline / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P1** | **Book composite** of D1: the title bird's wings across the fold | **The two halves are your *wings*.** / Best on iPhone Duo. Hold to tuck on any iPhone. | frame `book:D1-book-hero` (fallback capture `screen=home;progress=mid;bird=gull;sky=goldenHour;touch`) |
| **P2** | A Perfect skim, chain 5: ring on the water, gold trail | **Land the downslope. *Perfect.*** / Three in a row catch a Tailwind. | `mode=flight;seed=7;autopilot=perfect;touch;chain=4;freezeOn=perfect;freezeAfter=0;freezeDelay=0.12` |
| **P3** | A Tailwind starting | **Chain three. Ride the *Tailwind*.** / A burst of speed. The storm falls back. | `…;chain=2;freezeOn=tailwind;freezeAfter=0;freezeDelay=0.12` |
| **P4** | The storm close, lead low | ***Outfly* the storm.** / Every Perfect pushes it back. | `mode=flight;seed=7;autopilot=casual;touch;lead=0.12;freezeOn=stormclose;freezeAfter=0` |
| **P5** | Passing the first lighthouse | **Reach the next *lighthouse*.** / The first is 4 km out. Can you make it? | `…;skipTo=3850;freezeOn=lighthouse;freezeAfter=0;freezeDelay=0.4` |
| **P6** | Flight under the Moonrise sky (heron) | **Fly on by *moonlight*.** / Earn new skies and birds as you rank up. | `mode=flight;seed=11;…;sky=moonrise;bird=heron;freezeAt=7` |
| **P7** | Results card, mid progress (a real headless run) | **One more *flight*?** / Goals to chase. Ranks to earn. | `screen=results;seed=7;progress=mid;autopilot=casual` |
| **P8** | Birds screen, mid progress | **Eight birds. Five *skies*.** / No ads. No in-app purchases. | `screen=birds;progress=mid` |

Reserves (run with `phone_filter` `^(P[0-9]|R[0-9])`): `R1-soar` **Hold to *dive*. Let go to soar.**; `R2-daily` **One *Daily Flight*. Same sea for all.**

## B. iPhone Duo, inner display (2853 × 2007): 8 frames

Same moments and captions as A (no `touch`: the Duo frames are the hinge game; the autopilot flies). D1 is the book composite of its own capture, captioned **The two halves are your *wings*.** / Hold your Duo like a book. The storm close uses `lead=0.06` (as proven in `ci/duo-scenarios.txt`). Every Duo frame must log the folded inner canvas (`SWOOP-T canvas 951x669 fold=1`), so a cover-display capture is FLAGGED, never uploaded. Reserves (`^(D[0-9]|DR)`): `DR1-soar` **Fold to dive. Open to *soar*.**; `DR2-countdown` **Hold your Duo like a *book*.**

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture from the app (frame 1: only warped onto the device); captions sit outside it. No composited spray, rings, birds or skies.
- [ ] **Frame 1's device is a real iPhone Duo pose** (book, 140–150°), never a non-folding iPhone drawn folded, never closed or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build** (checked in `Swoop/Core/Tuning.swift` on 26 Oct): a Tailwind at every 3rd Perfect in a chain (+15 % speed, storm pushed back); every Perfect pushes the storm back; the first lighthouse at 4 km, each one pushing the storm back; 8 birds and 5 skies, earned by rank; press and hold is the iPhone tuck. If any of these change, change the caption.
- [ ] **Seeded states are reachable states:** chain 2–5, a low lead and "mid progress" are things a real player sees. Never seed every bird unlocked or an impossible distance.
- [ ] **No stale hint text** that contradicts the caption (iPhone frames use `touch` and no `hints=fresh`).
- [ ] **Nothing important in the crease band** (x ≈ 456–496 pt) on the Duo frames, except the title bird's body in D1, which is the point.
- [ ] **No prices, dates, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Upload order and checks (founder, runbook §6e)

1. 6.9" slot: `store-69` P1–P8. 2. 6.3" slot: `store-63` P1–P8. 3. If an **iPhone Duo** entry appears in the device list: `store-duo` D1–D8, then check them in App Store Connect's preview. No Duo entry: skip it; the Duo set ships with 1.0.1.

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames). Upload only from the `store-*` artifact of the run Claude names, after reading its MANIFEST.

## Sources
- Apple, App Store Connect Help, *Screenshot specifications* (read 26 Oct 2026: iPhone Duo inner 2853 × 2007 / 2007 × 2853, outer 2034 × 1398 / 1398 × 2034; 6.9" 2868 × 1320, 2796 × 1290, 2736 × 1260; 6.3" 2622 × 1206, 2556 × 1179, the one required iPhone size; landscape accepted; 1–10 per size; no alpha; "highest required resolution" is scaled down): https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple Developer Forums 845505, *How do I upload iPhone Duo screenshots in App Store Connect?* (no Duo entry in the selector or `ScreenshotDisplayType`, Oct 2026): https://developer.apple.com/forums/thread/845505
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Brim's pipeline (ported and reworked for landscape): `C:\Users\59527\Fold\ci\store-*`, `C:\Users\59527\Fold\.github\workflows\store.yml`
