# Swoop: product page header and search results art

*Written 27 Oct 2026, ported from Brim's pipeline (`C:\Users\59527\Fold\docs\appstore\header-search.md`) and reworked for Swoop's landscape book pose. Owner: CI draws them, the founder approves, the App Store Connect tool places them. Both are optional (Guideline 2.3.14, App Store on iOS 27 and later, turned on 5 Oct 2026). Without them, search shows Swoop's first screenshot (a landscape set shows only frame 1) and the product page has no header; with them, nothing on either surface is left blank.*

## What they are

| Placement | Where people see it | Swoop's file | Size |
|---|---|---|---|
| **Product page header** | Across the top of Swoop's product page, above the icon, the name and the Get button. On an iPhone in portrait it keeps its full height and loses about 8 % on each side; the back and share buttons sit over its top corners | `store-placements/header-3840x1646.png` | 3840 × 1646 (21:9), opaque PNG |
| **Search results art** | Swoop's card in the Search tab, in place of the screenshots. Small: about 365 pt wide on an iPhone, next to other apps' cards. Shown whole on an iPhone | `store-placements/search-3840x2560.png` | 3840 × 2560 (3:2, the largest Apple takes), opaque PNG |

These are exactly the names `tools/appstore/asc.swift` looks for (`placementSpecs`: `header-3840x1646.png`, `search-3840x2560.png`), and it refuses the folder if its `MANIFEST.txt` reports problems.

Apple's templates also draw a smaller "safe area" in the middle for other devices (header x 1097–2743, y 493–1154; search x 836–3004, y 765–1795, as others measured them; Apple publishes no numbers). Swoop is on iPhones (the iPhone Duo included), so the iPhone view is the one that matters; the MANIFEST reports both. We make **two dedicated files**, not Apple's universal 5244 × 2950 asset, so each crop is designed rather than guessed.

## The designs

Both show **one idea, the same one as screenshot frame 1**: an iPhone Duo standing open like a book, the title bird's wings spanning its two halves. The book is drawn by `ci/store-banner.swift` with `ci/store-frame.swift`'s own model (the same angle, tilt, graphite bezel, hinge spine, drop and ground shadows; no hands, no logo, no buttons, no badge), on the screenshots' navy → dusk sweep with the Golden Hour glow behind the lit page, so header, search card and screenshots read as one set.

**Search results (3:2), `top` layout.** The headline across the top on one line, **The two halves are your *wings*.** (SF Pro Rounded Heavy in foam, "wings" as ink on the UI-gold swash), the sub-line **Hold your Duo like a book.** in Semibold mist under it, and the book big and centred below, filling the middle of Apple's safe area. The words are D01's own caption, read from `ci/duo-store-scenarios.txt` at render time, so the search card and frame 1 always say the same thing. By the layout's numbers (to be confirmed on the first render with `review/search-365pt@1x.png`), at 365 pt wide the headline's capitals are about 13 pt tall and the book about 58 % of the card's width, so the gull's wings across both pages still read.

Alternatives drawn for review (never uploaded): `review/search-side.png`, Brim's side layout (small wordmark, the headline in three lines on the left, the book on the right; smaller type and a smaller book at card size); `review/search-perfect.png` and `review/search-storm.png`, the same layout with the D02 (Perfect ×5 on the wave) and D03 (storm close behind) frames and their own captions. To ship one of those instead, re-render with `banner_args: search=--from D02-perfect` (or `--layout side`).

**Product page header (21:9).** A brand banner with air: the Swoop wordmark as the app draws it (`SwoopWordmark` in `Swoop/UI/SwoopTheme.swift`: "Swoop" in Rounded Black, the gold → ember capsule and **TUCK & SOAR** beside it) centred in the left column, the same book on the right, turned 5° toward the words. No icon, no app name repeated, no headline: the name "Swoop: Tuck & Soar" and the subtitle "Fold your phone. Fly." sit right under the art on the page (Brim's rule: no headline that repeats the subtitle). `review/header-perfect.png` is the D02 alternative.

**Light.** The Duo captures are mirrored (the bird on the sharp, screen-right half; the clear sky ahead on the left page), so the light comes from the left, exactly as `ci/store-set.sh` does for the screenshots: the dusk end of the sweep and the glow are on the left, and the left page's bezel is the lit one.

**Truthfulness.** The screen is the app's own D01 capture (Home, mid progress, the Gull, Golden Hour, the Duo held at its logged hinge angle, 146° in run 40521302499), only Lanczos-resampled and put in perspective; nothing is painted on the screen. `ci/store-placements.sh` uses a capture only if it is the 2853 × 2007 inner display (not turned, not the cover), its captioned frame passed every `ci/store-set.sh` check (it is in the `store-duo` artifact, not `_flagged/`) and its log shows the folded inner canvas (`SWOOP-T canvas 951x669 fold=1`). The device is the real Duo pose Swoop is played in; it never shows a non-folding iPhone folded. No prices, no "#1", no awards, no URLs, no Apple logos or the "Made for iPhone Duo" badge, nothing for 4+ to worry about. The captions go through the same glossary as the screenshots ("Outfly", "downslope", "crest", "chain", "rank", "Flocks", "Fold to Fly", "tuck" as an instruction: rejected, nothing drawn). "Tuck & Soar" appears only as the name, in the wordmark.

**The screen's own text.** D01 is Home, so the picture includes the app's menu (Fly, Daily Flight with that day's date, Goals, Route, Birds) and its small wordmark. That is the real first screen and the same picture as frame 1; the art's own text is two lines on the search card and the wordmark alone on the header, so neither is text-heavy. If App Review or the founder prefers a gameplay picture, use the D02 alternative.

## How they're made

`store.yml` job **`placements`** (after `assemble`, or on its own):

```bash
# Full store run: phones, Duo, assemble, then the placements from that run's Duo pass
gh workflow run store.yml -R pravegm/swoop --ref main
# Placements only, from an earlier run's raw-duo + store-duo (minutes; captures nothing, skips phones/duo/assemble
# whatever their ticks say, and runs in its own concurrency group, so it never cancels a capture run)
gh workflow run store.yml -R pravegm/swoop --ref main -f placements_from=40521302499
gh run list -R pravegm/swoop --workflow store.yml -L 1          # its run ID
gh run download <id> -R pravegm/swoop -n store-placements -D <empty folder>
```

The source run must be one that **captured** the Duo (a run that reused another's Duo with `duo_from_run` has no `raw-duo` artifact; use that earlier run instead). `raw-duo` artifacts are kept 30 days (run 40521302499's until 26 Nov 2026); `store-duo` 90.

- `ci/store-placements.sh <raw-duo dir> <out>` (the job unpacks `store-duo` into `<raw-duo dir>/store/`) picks the hero (`D01-book-hero`, else `D02-perfect`, noted as a FALLBACK), its light side and hinge angle from its log, the search caption from `ci/duo-store-scenarios.txt`, runs `ci/store-banner.swift`, checks size and alpha with `sips`, checks the text and the device stay inside the iPhone area and the text stays off the device, and writes `MANIFEST.txt` (`summary: ok 2  problems 0` when both are good). It never fails the job.
- `ci/store-banner.swift` (Core Graphics, Core Text, Core Image): the book model, warp self-test and caption system of `ci/store-frame.swift`, fitted into a device box and a text box per layout. Knobs, passed through the store.yml input **`banner_args`** as `header=<options>; search=<options>; <name>=<options>` (any other name renders a review-only `review/variant-<name>.png`; quotes work): `--from <D0x-name>` (another clean capture, with its own light, angle and, for search, caption), `--layout top|side`, `--caption "Head *word* / sub"` (after `--from`), `--yaw`, `--tilt`, `--angle`, `--device-box x0,y0,x1,y1`, `--text-box x0,y0,x1,y1` (fractions), `--cap`, `--mark`, `--glow-x`, `--snaps <dir>`. Example: `-f banner_args='header=--yaw -8; storm=--kind search --from D03-storm'`.
- `review/` (never upload): `*-guides.png` (red dashed = template safe area, blue = what an iPhone shows, white = centre lines), `search-365pt@1x.png` and `@3x` (the card at real size), `header-402pt@3x.png`, the alternatives above, `store-banner-build.log`.

**Current art:** run **40541082197** (27 Oct 2026, from the final store run 40521302499: release build 12, commit c117b2d). MANIFEST `ok 2  problems 0`; both inside the iPhone view (blue guide). Placed in App Store Connect with `asc.yml` `placements_run=40541082197`.

## Upload

### By API (the App Store Connect tool)

`tools/appstore/asc.swift` has a **`placements`** step (`tools/appstore/README.md`):

1. `gh workflow run asc.yml -R pravegm/swoop -f asc=true -f mode=plan -f only=placements -f placements_run=<placements run id>`: read `plan.txt` (the placement types and groups the API offers, then each placement it would make).
2. The same with `-f mode=push`. The tool uploads each PNG once as a `CREATIVE_ASSETS` image, then creates one `PRODUCT_PAGE_HEADER_ASSET` placement and one search results placement (the IDs are read from `GET /v1/appAssetLibraryRefData`) on the en-GB and en-US 1.0 version localizations. Re-running changes nothing; a new file replaces the old placement (delete + create). Locally: `xcrun swift tools/appstore/asc.swift upload-placements <downloaded store-placements folder>`.
3. They go to App Review **with version 1.0**. After 1.0 is live, changing them needs a new version or a separate review submission for the assets; the tool doesn't do that part.

### By hand (App Store Connect web)

1. App Store Connect → **Apps → Swoop: Tuck & Soar → (iOS App) 1.0 Prepare for Submission**.
2. Language menu (top right): **English (U.K.)**.
3. **Product Page Header** (above "Previews and Screenshots"): **Choose File** → `header-3840x1646.png`.
4. **Search Results**: **Choose File** → `search-3840x2560.png`.
5. Open the **product page preview** and look at the iPhone view: the header's sides are cropped about 8 %, the back and share buttons cover its top corners; nothing important should be under them. Then the search card.
6. **Save**. Switch to **English (U.S.)** and repeat 3–6 with the same files (the words are spelling-neutral).

If the page shows the assets under a separate **Creative Assets** or **Asset Library** section instead, upload there and place them on the 1.0 page for both languages.

## Review notes

- Guideline 2.3.14: the art pertains to the app's content (its real first screen, on the device pose it is played in) and brand, has no pricing, no references to other apps, no unverifiable claims, and is fine for all ages.
- Asset best practices: one focused idea, current UI, key content in the centre, no URLs, no © symbol, no Apple-designated recognitions, no other platforms.
- The drawn device is a plain folding-phone silhouette: no Apple logo, no product name, no buttons, no badge. If App Review objects, remove the placements: the search card falls back to the first screenshot and the page simply has no header.
- The text is the same in en-GB and en-US, so one file serves both localizations.
- The D01 picture shows that day's date on the Daily Flight card ("27 Oct" in run 40521302499). It is the app's own screen, as in frame 1; it isn't a claim. If it matters, re-render from a later store run.

## Later: a looping video version

Both placements also take video (header 3840 × 1646, search 3840 × 2560; 30 or 60 fps; 5–30 s; muted in search, loops in both). The idea: the same book, the camera still, the halves folding a little and opening while the title bird's wings sweep back and open with them (the gesture doubles, ART-DIRECTION §7), then cut to a Perfect on the wave. Poster frame (Apple takes 5 s) = this still. Make it from real captures: a `ci/duo.sh` pass recording the inner display (`simctl io recordVideo`) during a hinge sweep, composited per frame by `store-banner.swift` (the warp is already per-image).

## Sources

- App Store Connect Help, *Creative assets specifications* (sizes, formats, no alpha, video rules): https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/
- *App Store asset best practices* (one idea, safe areas in the templates, do's and don'ts): https://developer.apple.com/app-store/asset-best-practices/
- App Review Guideline 2.3.14: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect API, *Understanding the App Asset Library* and *Placing assets on your App Store surfaces*: https://developer.apple.com/documentation/appstoreconnectapi/understanding-the-app-asset-library
- Safe-area measurements and the iPhone preview crop (not Apple's numbers): as cited in Brim's `docs/appstore/header-search.md`.
- Brim's pipeline (ported): `C:\Users\59527\Fold\ci\store-banner.swift`, `ci/store-placements.sh`, `.github/workflows/store.yml` (job `placements`).
