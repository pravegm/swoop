# App Store Connect from GitHub Actions

`asc.swift` puts the whole Swoop 1.0 listing (`com.pravegm.swoop`, "Swoop: Tuck & Soar") into App Store Connect from `docs/appstore/asc-metadata.json`. It's a port of Brim's tool (`pravegm/brim`, the one that set up and submitted Brim 1.0 on the same Apple account), which was itself a port of Squish's. It is idempotent: it changes only what differs, and `push` resumes after a failure. It never submits anything for review and never releases the version.

Nobody pastes anything: the workflow pushes the listing. The few clicks with no API are in `docs/LAUNCH-RUNBOOK.md`.

## Run it

GitHub → **Actions** → **App Store Connect tool** → **Run workflow**:

| Input | Meaning |
|---|---|
| `asc` | Tick to contact App Store Connect. Unticked, the run only typechecks and validates |
| `mode` | `check`: read-only status. `plan`: check plus a dry run, still read-only. `push`: check, plan, then write |
| `only` | Optional step list, e.g. `nomination` or `gamecenter,attach` |
| `store_run` | A green **App Store screenshots** run (`store.yml`). Empty = `DEFAULT_STORE_RUN` in the workflow |
| `ci_run` | A green **CI** run whose `screenshots` artifact holds `badges/`. Empty = the latest green run on `main` |
| `placements_run` | A run with a `store-placements` artifact (product page header and search art). Swoop's `store.yml` makes none yet: leave it empty |
| `inherit_from` | Default `com.pravegm.squish`. See "Personal data" |
| `build` | The release build number to attach to 1.0 (the `build` step). Empty = leave it |

Every run uploads `asc-output` (check.txt, plan.txt, push.txt). Read `plan.txt` before running `push`.

```bash
gh workflow run asc.yml -R pravegm/swoop -f asc=true -f mode=plan
gh workflow run asc.yml -R pravegm/swoop -f asc=true -f mode=push -f only=nomination
```

The secrets are the shared Admin team key that Brim and Squish use: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`. The key is written to a temp file for the job and deleted at the end.

**`DEFAULT_STORE_RUN` is `40521302499`**: the final frames (27 Oct 2026, release build 1.0 (12), commit `c117b2d`, all three MANIFESTs `ok 10 flagged 0 missing 0`). If the game changes visibly, run `store.yml` again and put the new ID in `.github/workflows/asc.yml` (or pass `store_run`).

## Personal data (the repo is public)

The metadata file has no name, phone or email: `review.contact` is `null`. With `--inherit-from com.pravegm.squish` (or `ASC_INHERIT_FROM`), the tool reads Squish's newest version at run time, its `appStoreReviewDetail` contact, and uses it in memory for Swoop. Every value is masked in all output (`‹hidden›`, plus GitHub's `::add-mask::`), and `asc-output` gets only masked lines. Never put these values in a file.

The copyright is different from Brim's: Swoop's `DECISIONS.md` #31 sets `© 2026 pravegm` (the public GitHub handle, not a personal name), so it is in the metadata and pushed as is. If the founder wants a legal name instead, set `copyrightHolder` to `null` in `build-metadata.js`: the copyright is then inherited from Squish and masked like the contact.

## What `push` does, in order

| Step | What |
|---|---|
| `appinfo` | Name `Swoop: Tuck & Soar`, subtitle `Fold your phone. Fly.` and privacy URL for en-GB and en-US. Primary language en-GB. Content Rights: no third-party content |
| `categories` | Games: Casual and Arcade, then Entertainment (`metadata.md` §7, DECISIONS #7). The subcategories are checked against Apple's live list first. On 26 Oct it had dropped Arcade (Brim run 40340641267); a subcategory that isn't live is replaced by the first live entry of `categories.fallbackSubcategories`: **Action**. `check` and `plan` print what would be pushed |
| `agerating` | The questionnaire from `metadata.md` §8: every item None or No, including Contests. Result 4+ |
| `version` | 1.0: copyright `© 2026 pravegm`, release **automatic on approval** (DECISIONS #12: the founder releases as soon as Apple approves) |
| `build` | Only with `build`: attaches that processed build to 1.0. Never submits |
| `localizations` | Description (UK and US spellings), keywords, promotional text, support and marketing URLs |
| `review` | Review notes (3,964 bytes; validate fails over 4,000), "no sign-in", and the contact (inherited) |
| `gamecenter` | Enables Game Center for the app and version 1.0. Creates 12 achievements (`swoop.ach.*`, 625 points, none hidden, none repeatable) with en-GB and en-US text ("kilometer" in en-US) and a badge each. Creates 2 leaderboards: `swoop.longest` (classic) and `swoop.daily` (recurring daily from 28 Oct 2026 00:00 UTC), both Integer, High to Low, best score, range 0–1,000,000, suffix " m" (singular and plural) |
| `attach` | Adds every achievement and leaderboard version to the draft iOS review submission. It never adds the build and never submits |
| `screenshots` | 6.9" (2868 × 1320, `store-69`): P01–P08. 6.3" (2622 × 1206, `store-63`), which goes in Apple's required "Dynamic Island, medium" class, the tool's `APP_IPHONE_61` key: P01–P08. iPhone Duo inner (2853 × 2007, `store-duo`): D01–D08, only if the API offers a Duo placement group (`check` says). All landscape. P09/D09 (Route) and P10/D10 (Flight School) are "recommended" in `screenshots.md`: add them to `FRAMES` in `build-metadata.js` to upload them |
| `placements` | Only with `placements_run`. Swoop has no header or search art yet, so this step changes nothing (it shows as a gap) |
| `price` | £1.99, base territory United Kingdom; Apple equalises the rest ($1.99). Available everywhere except China mainland and Vietnam (DECISIONS #10: both need a local game licence) |
| `accessibility` | Nothing for 1.0: labels go on by hand on launch day |
| `nomination` | The App Launch featuring nomination from `featuring-nomination.md`, publish date 30 Oct 2026 (the expected go-live). It's **submitted** (`"submit": true`), not left as a draft. |

Badges: the app draws them (`Swoop/UI/AchievementArt.swift`). The CI scenario `badges` (`ci/scenarios.txt`, demo key `screen=badges`, log line `SWOOP-T badges done 12` in `logs/badges.txt`) renders them into the `screenshots` artifact. `badges.swift --from <that>/badges` checks the IDs against `GameCenterManager.achievementIDs` (which is `ProgressRules.allAchievements` in `Swoop/Persistence/ProgressStore.swift`), `achievements.md` and the metadata. It writes opaque RGB copies to `tools/appstore/badges/`, the `badges` artifact. Leaderboard images are optional and not pushed.

## Still by hand (no public API, or the founder's call)

- **Create the app record**: the API can't create apps. Use the name fallbacks in `metadata.md` §1 if the name is taken, then regenerate the metadata.
- **App Privacy**: Get Started → "Data Not Collected" → Publish.
- **Mac and Vision Pro**: Pricing and Availability → untick "iPhone and iPad Apps on Apple Silicon Macs" and "… on Apple Vision Pro".
- **Family Sharing**: on (permanent once on).
- **EU DSA trader status**: App Information → App Store Regulations and Permits. DECISIONS #10 says it's handled at account level, but Brim was asked again per app, so check it.
- **The build**: pick it on the 1.0 page (or use `build`), **Add for Review** (it joins the draft that holds the Game Center items), then **Submit to App Review**.
- **Release**: nothing to do. 1.0 goes live by itself as soon as App Review approves it.
- **Accessibility Nutrition Labels**: on launch day, only the labels `accessibility.md` marks as passed.
- **iPhone Duo screenshots**: upload by hand if the API offers no Duo group and App Store Connect shows the slot.
- **Promo codes** and the optional App Review screen recording.

## Notes

- **The daily leaderboard start** (28 Oct 2026 00:00 UTC): create it with `push --only gamecenter` before then. Whether App Store Connect accepts a start date already in the past is unconfirmed; once that date passes `validate` warns.

## Files

- `asc.swift`: the tool (Foundation and CryptoKit only). Commands: `validate`, `check`, `plan`, `push`, `upload-screenshots [dir]`, `upload-placements [dir]`. Run `xcrun swift tools/appstore/asc.swift help`. `upload-screenshots <dir>` takes a folder of downloaded `store-*` artifacts and uploads every clean frame (all ten, not just the eight in the metadata). It refuses a set whose MANIFEST isn't `flagged 0 missing 0`.
- `badges.swift`: collects and flattens the app-rendered badges.
- `build-metadata.js`: `node tools/appstore/build-metadata.js` regenerates `docs/appstore/asc-metadata.json` and `fixtures/asc-metadata.sample.json` from `metadata.md`, `review-notes.md`, `achievements.md` and `featuring-nomination.md`, with the rows of `DECISIONS.md` it names. It cross-checks the runbook's §4b table and Apple's limits, and exits 1 on any doc inconsistency. Regenerate whenever those docs change. Never edit the JSON by hand.
- `fixtures/asc-metadata.sample.json`: the validator's CI fixture (a placeholder URL, a partial en-US, missing images).
- `badges/`: written by CI (the `badges` artifact); not committed.
