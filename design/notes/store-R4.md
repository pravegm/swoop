# Store frames, Round 4 (26 Oct 2026)

Owner: store frames engineer. Nothing committed. Nothing compiled or run: this host has no Mac. First proof is a
manual **App Store screenshots** run (`.github/workflows/store.yml`).

## Built
- `ci/store-frame.swift`: Brim's caption compositor ported to landscape, plus `--book`.
- `ci/store-set.sh`: frames one set, checks the app logs, lints captions, writes `MANIFEST.txt`/`.tsv` and `_flagged/`.
- `ci/store-capture.sh`: wraps `screenshots.sh`/`duo.sh` (unchanged) with timeouts; retries missing or wrong-sized frames twice.
- `ci/store-scenarios.txt` (P1–P8) and `ci/duo-store-scenarios.txt` (D1–D8). The optional 6th column `frame` (`book` or `book:<Duo name>`) is ignored by the capture scripts.
- `store.yml`: three jobs, phones, duo, then assemble (needs both). Artifacts `store-69`, `store-63`, `store-duo`, plus `raw-*`. `duo_from_run` reuses an earlier Duo capture.
- `docs/appstore/screenshots.md` rewritten: sizes, slots, order, captions.

## Decisions
- **Caption on top** for flat frames: the headline fits on one line and the capture keeps about 55 % of the frame (a side column leaves about 44 %). **Left column** only for the book frame on the 2.2 : 1 iPhone slots, where the book is about 1.25 : 1.
- **Sizes (Apple's page, read today):** 6.9" 2868×1320; 6.3" 2622×1206 (the one required iPhone size); 6.5" and 6.1" are scaled by Apple, so we make none. The Duo is listed at inner 2853×2007 and outer 2034×1398, but Forum 845505 says the selector and API had no Duo entry in October. If it's missing on upload day, upload the 6.9" and 6.3" sets, whose frame 1 is the Duo book; Duo set in 1.0.1. Apple requires Duo screenshots from April 2027 (27.1 SDK).
- **Book is CI-side**, not the app's `storeshot=book` key (DECISIONS §2 #4, never built). It uses D1's real capture, split at x=1428 and warped page by page. Defaults: 140°, tilted back 8°, a graphite bezel, a hinge barrel and seam, shadows, no hands, nothing drawn on the screen. `book_angle=auto` uses the hinge angle in the capture's log when there is one (150° in `duo.sh`).
- **Palette** from ART-DIRECTION: navy `#0B2236`/`#0A2B44` to dusk `#2E2A5E`/`#7A5C9E`, gold `#F7C75B` with ink `#0E2438`, foam/mist text, the sun glow added with plus-lighter. This replaces the plan's `#14212E`/`#F6B73C`.
- **Captions:** ART §8's "Fold your phone. Fly the bird." was not used (it is too close to "Fold to Fly"). Every claim was checked against `Tuning.swift`/`Contracts.swift`.

## Risks to watch on the first run
- The CI warp's corner order is self-tested on a 4-colour card and flipped if needed. A wrong extent flags the frame (`extent=mismatch`).
- If `simctl` returns portrait-shaped iPhone captures, the frames are FLAGGED "turned sideways". Set `STORE_ROTATE=90|270` and eyeball, or fix the capture.
- Duo frames need `SWOOP-T canvas 951x669 fold=1` in their log, so a cover-display capture can't pass.
- The demo keys come from today's DemoMode header. `Swoop/` is mid-edit by others, so re-check the freeze names if frames flag.
- For the leads: DECISIONS #14–16 still say 6 Duo + 5 + 5 frames and an app store shot. They are now 8 + 8 + 8 and a CI composite. That file isn't mine to edit.
