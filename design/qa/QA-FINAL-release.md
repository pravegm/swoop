# QA-FINAL: release compliance audit, Swoop: Tuck & Soar 1.0

*Release manager audit, Tue 27 Oct 2026, against `main` at `a4bc58d` (code as of `2f995ec`, "Fold deeper without pausing", the code in TestFlight 1.0 (10)). Read-only on code and CI. Everything below was checked in the files, or live with `gh` and a web fetch where noted.*

**Counts: P0 4 · P1 10 · P2 14.**

Severity key: **P0** = would be rejected, or is false or misleading. **P1** = fix before submission. **P2** = nice to have.

---

## P0

### P0-1. The Support, Privacy Policy and Marketing URLs return 404 (GitHub Pages is off)
- **Evidence:** `https://pravegm.github.io/swoop/site/support.html` and `https://pravegm.github.io/swoop/privacy.html` both returned **HTTP 404** on 27 Oct. `gh api repos/pravegm/swoop` → `"has_pages": false` (the repo itself is `"visibility": "public"`). `docs/HANDOVER.md:59` still lists runbook §0b as pending. `metadata.md:236-238`, `privacy.md:11`, runbook §5c/§6b and `featuring-nomination.md:28` all point at these addresses.
- **Why it matters:** App Store Connect won't let you save App Privacy until the policy URL loads. Guideline 5.1.1(i) needs a reachable policy, and 1.5 needs a working support URL. The featuring nomination's first supplemental URL is the same dead site.
- **Fix:** the founder does runbook §0b now (Settings → Pages → Deploy from a branch → `main` / `/docs` → Save), then checks that all three short URLs and the three `/site/` URLs load. In the runbook timeline, mark §0b as **overdue, blocking §1e and §5c**.

### P0-2. The pause threshold is still 95° in the review notes and the support page; the code pauses under 55°
- **Evidence:** `Swoop/Input/FeelFilters.swift:309-312`: `closeBelow = 55.0`, `reopenAbove = 65.0`, `instantBelow = 40.0` (dwell 0.2 s). This changed in `2f995ec`.
  - `docs/appstore/review-notes.md:30` says "e) Below about 95 degrees a flight pauses". The check table at `:73` says "Pause below ~95°".
  - `docs/site/support.html:62` says "(below about 95 degrees)".
  - `docs/appstore/asc-metadata.json` (untracked, generated) has the same text.
- **Fix:**
  - `review-notes.md:30` → `e) Folded below about 55 degrees (well past an L shape) a flight pauses ("Open your wings to keep flying") and carries on when reopened. Closed: the outer display shows "Open your wings". Portrait: a card asks to turn the Duo sideways, with "Play with touch".` (This is part of the full replacement block in P1-4.)
  - `review-notes.md:73` → `| Pause below ~55° (instant under 40°, resumes above 65°) "Open your wings to keep flying"; cover "Open your wings"; portrait card with "Play with touch" | \`Input/FeelFilters.swift\` (\`FeelClosingGate\`), \`UI/PoseCards.swift\` | [x] exact wording | [ ] |`
  - `support.html:62` → `<p>You folded the Duo much further than play needs (below about 55 degrees, well past an L shape). Open it back to your normal book pose and the flight carries on. If you close it fully, the outer screen shows "Open your wings" until you open it again.</p>`

### P0-3. "The hinge reading isn't stored" is false: the resting angle is saved to UserDefaults
- **Evidence:** `Swoop/Persistence/SettingsStore.swift:41-42`: `/// R5 P1-7: the player's resting book angle (Feel's calibrated "open"), restored at launch.` `var hingeOpenAngle: Double?` is part of the persisted settings snapshot. Docs that say otherwise:
  - `docs/site/privacy.html:14`: "That reading never leaves your iPhone and isn't stored."
  - `docs/appstore/privacy.md:63` (policy text) says the same. `privacy.md:21` says "It is never stored".
  - `review-notes.md:25`: "it is never stored or sent anywhere".
  - The in-app text (`SettingsView.swift:295`) is accurate ("never leaves your iPhone").
- **Why it matters:** it is a false statement in the privacy policy. It doesn't change "Data Not Collected", because the value never leaves the device.
- **Fix:**
  - `privacy.html:14` and `privacy.md:63` → `On iPhone Duo, Swoop reads how far the phone is folded, only to steer the bird while you play. That reading never leaves your iPhone. The only thing kept is your usual resting angle, saved on this iPhone with your settings so the next flight starts calibrated.`
  - `privacy.md:21`, Hinge angle row, Why column → `Read through the public \`onHingeChange\` API to steer the bird while the game is on screen. Only the calibrated resting angle is saved, on the device, with the settings (\`SettingsStore.hingeOpenAngle\`). Nothing leaves the phone. Apple: "collect" means transmitting data off the device`
  - `privacy.md:41`, Result column → `[x] resting angle persisted on device only (SettingsStore.hingeOpenAngle); answer unchanged`
  - `review-notes.md:25`: see the block in P1-4.

### P0-4. App Review will see a "Device test · Hinge readout (TestFlight)" card in Settings
- **Evidence:** `Swoop/UI/SettingsView.swift:94-101` shows the card when `BuildChannel.isTestBuild`. `Swoop/App/BuildChannel.swift:61` sets that from `appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"`. App Review installs builds that run in the sandbox environment and carry a sandbox receipt, the same as TestFlight, so the reviewer gets the card (and the toggle turns on the `HingeReadoutOverlay` diagnostic, `RootView.swift:114`). It shows on a non-Duo iPhone too, where it does nothing useful.
- **Why it matters:** a user-visible "TestFlight" label and a debug tool in the reviewed binary invite a Guideline 2.2 (beta content) or 2.1 (unfinished) rejection. I'm calling it P0 because the string is shown to the reviewer as-is.
- **Fix (code, for the App engineer):** in `SettingsView.swift:94`, change `if BuildChannel.isTestBuild {` to `if BuildChannel.isTestBuild && controller.hasHinge {`. At `:96`, change `"Device test"` to `"Hinge"`. At `:98`, change `"Hinge readout (TestFlight)"` to `"Hinge readout"`. At `:95`, change the comment to `// The founder's device test (Duo only). Hidden in App Store builds.` Then a reviewer on a normal iPhone or iPad never sees it, and a Duo reviewer sees a neutral diagnostic with no "TestFlight". Optional hardening: make the card DEBUG-only and give the founder a hidden gesture instead (for example a long-press on the version line). If the code isn't changed, add to review-notes §8: `- Settings > Device test is a diagnostic for our own hardware testing; it does not appear in App Store builds.` (that costs bytes).

---

## P1

### P1-1. The Release demo-string check never runs on the builds that are uploaded
- **Evidence:** `.github/workflows/testflight.yml:58-61` (`strings … | grep -qx "freezeAfter"`) is only in the `release-check` job, which runs only with `check_only`. The `upload` job's "Check the archive" step (`:141-149`) checks the privacy manifest and the build number, but not the demo strings. `ci.yml`, `store.yml` and `duo.yml` have no Release checks at all. (The source is fine: `DemoMode.swift` and `DemoRunner.swift` are entirely `#if DEBUG`, and every other demo path is guarded. See "Clean".)
- **Fix (workflow, for the CI owner):** add these lines to the end of the upload job's "Check the archive" step:
  ```
  if strings "$APP/Swoop" | grep -qx "freezeAfter"; then echo "::error::demo-mode code found in the Release binary"; exit 1; else echo "no demo strings in Release"; fi
  ```
  Or run one `check_only` build on the release-candidate commit and keep its log.

### P1-2. The runbook is out of date (builds exist, the founder has tested, the 55° gate, screenshot counts, Pages)
- **Evidence:** `docs/LAUNCH-RUNBOOK.md`:
  - `:19`: "Today, Mon 26 Oct: check the repo is public and turn on the website". The repo is public, but Pages is still off (P0-1).
  - `:23-24`: "When Claude says the build is ready (about Wed 28 – Fri 30 Oct) | Run the TestFlight build" and "Fri 30 Oct – Sun 1 Nov | First play on your Duo". TestFlight runs exist for builds up to 10 (`gh run list`: ten successful TestFlight runs, 26–27 Oct; build 10 = run 40493195525), and the founder has already played builds 2 and 10.
  - `:139`: "fold the Duo further than usual (towards an L shape) … Does it pause". With the 55° gate an L shape (90°) keeps flying by design.
  - `:245-247`: "drag in P1–P5 … add D1–D6". `screenshots.md` and both scenario files produce **8** frames (P01–P08, D01–D08), plus 2 recommended.
  - `:250` (§6f) doesn't tell the founder to pick a build whose run summary says the Game Center entitlement is present. Build 10's log shows `GC_ENT: yes`, archive mode `unsigned+adhoc-entitlements`.
- **Fix:**
  - `:19` → `| **Now (overdue)** | Turn on the website, §0b (5 minutes). The repo is already public. **The Support and Privacy URLs 404 until this is done** | §0 |`
  - `:23` → `| Done | TestFlight builds 1.0 (2)–(10) are uploaded; run §2c again only when Claude asks | §2c |`
  - `:24` → `| **Now, on 1.0 (10) and later** | Play on your Duo: the 10-minute check, then send Claude your scores | §3 |`
  - `:139` (Try this / Notice) → `| 6–7 | Mid-flight, fold deeper than usual, to an L shape and a bit past it: it should keep flying. Then fold much further (nearly closed), open again, then close it fully, look at the outer screen, and reopen | Did the L shape keep flying? Did the nearly-closed fold pause with "Open your wings to keep flying" and carry on when you opened? What does the outer screen show? Did closing ever cost you the flight? |`
  - `:245` → `1. **6.9" Display:** drag in P01–P08 in name order (P01–P10 if Claude says the Route and Flight School frames are clean).`
  - `:246` → `2. **6.3"/6.1" Display** (whichever "iPhone with Dynamic Island" slot it asks for): the same frames from \`store-63\`.`
  - `:247` → `3. Open the device list. **If you see iPhone Duo**, add D01–D08 (or D01–D10) from \`store-duo\` and check them in Apple's iPhone Duo preview. If there's no iPhone Duo entry, skip it (the Duo set comes with 1.0.1).`
  - `:250`, append → ` Only pick a build whose TestFlight run summary says "Game Center entitlement in the App Store signature: yes".`

### P1-3. `screenshots.md` tells the founder not to upload, because the captions are "still old". The scenario files are already updated.
- **Evidence:** `docs/appstore/screenshots.md:49`: "`ci/store-scenarios.txt` and `ci/duo-store-scenarios.txt` still carry the 26 Oct captions … Until then a fresh run produces frames with the old words: don't upload them." In fact both files carry exactly the 27 Oct captions in the tables at `:59-68` and `:80-86` (checked line by line: P01–P10, R1–R3, D01–D10, DR1–DR3). `DECISIONS.md:50` (#42) and `:71` (#13, "High") still list this as open.
- **Fix:** replace `screenshots.md:49` with `The game changed after the founder's real-Duo test (ROUND-6 to ROUND-12): Flight School with a guide gull, a fixed lighthouse route with a Route page and a "NEXT" goal chip, the bird on the Duo's sharp half (screen-right by default, flying right to left), and plain words (\`design/UX-ROUND-9.md\` §3–4). The captions below use the app's own words, and \`ci/store-scenarios.txt\` and \`ci/duo-store-scenarios.txt\` carry them exactly (checked 27 Oct).` Mark DECISIONS #13 done.

### P1-4. Review notes: stale details, no quick path to the core loop, and the false claims from P0-2 and P0-3
- **Evidence:**
  - `review-notes.md:19`: "Skip appears from step 2". `App/FlightSchool.swift:247-248` sets `canSkip = true` from the first step (R10), and Skip sits in the bottom trailing corner (`UI/FlightSchoolView.swift:25`).
  - `:21`: "'Flight over' appears". Since R11 the flight shows "The storm caught you" (`UI/PlayHUD.swift:1503`); "Flight over" is only the Results overline (`FlightSchool.swift:1150`).
  - `:50`: `"Top scores" on Home`. The visible label is **"Scores"**; "Top scores" is only the VoiceOver label (`UI/HomeView.swift:92`).
  - Nothing tells the reviewer that one tap (Fly → Skip) gets to a real flight in under a minute (`GameController.swift:1088-1096` starts a real flight on Skip).
  - Plus the 95° claim (P0-2) and "never stored" (P0-3).
- **Fix:** replace the block between the markers with the following. It is **3,933 bytes**, plain ASCII, counted with Node; the limit is 4,000. **Before pasting, check the iPad line on an iPad simulator (P1-8).**
```
Thanks for reviewing Swoop: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
You don't need a Duo. Everything works on any iPhone, on iPad (as an iPhone app) and in the Simulator, in landscape.
- Quickest look (under a minute): Fly > Skip (bottom corner) > a real flight.
- The first flight starts with Flight School, a short lesson on a calm practice sea (no storm, no score): a guide gull shows each move, then waits for you to copy it. Skip is there from the first step; Settings > Flight School replays it.
- Control: press and hold anywhere on the way down a wave (the wings fold, the bird dives faster), let go on the way up (it flies off the top). Land on the way down of the next wave for a "Perfect". One hold per wave; no flapping.
- A storm follows and speeds up; perfect landings push it back. The goal is the next lighthouse on a fixed route (Gull Point 4 km, Saltlight 9 km...), always shown at the top. When the storm catches up, "The storm caught you" appears and a card shows how far you got.
- Settings > "Wings by: Tapping": one tap folds, the next opens.

2. HOW THE HINGE IS USED (iPhone Duo)
Swoop reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. The angle steers the bird while the game is on screen; it is never sent anywhere (only the usual resting angle is saved, on the device).
a) Hold the Duo open like a book (landscape, fold top to bottom), one hand on each half, relaxed. The resting angle calibrates itself.
b) Fold the halves in a little (about 30 degrees) on the way down a wave; open back on the way up.
c) Bird side: iOS briefly softens one half of the inner screen when a fold starts from flat, so on a Duo the bird flies on the half that stays sharp: by default the right half, flying right to left. Flight School asks once which half stayed clear (one tap, or skip). Settings > Bird side: Sharp side (auto), Left or Right.
d) Settings > "Play with touch" gives the press-and-hold control on a Duo.
e) Folded below about 55 degrees (well past an L shape) a flight pauses ("Open your wings to keep flying") and carries on when reopened. Closed: the outer display shows "Open your wings". Portrait: a card asks to turn the Duo sideways, with "Play with touch".

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
Optional ("Scores" button on Home). 2 leaderboards (Longest Flight, Daily Flight), 12 achievements (625 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on (playback audio, mixing); Settings > "Respect silent switch" turns that off. All sound is synthesized in the app.
```
  Also change these places:
  - `review-notes.md:3`: "**3,745 bytes**" → "**3,933 bytes**".
  - `:65`: "Skip from step 2" → "Skip from step 1 (bottom trailing corner)".
  - `:68`: `"Flight over"` → `"The storm caught you" (in flight), "Flight over" (Results overline)`.
  - `:78`: `**"Top scores"** button` → `**"Scores"** button (VoiceOver: "Top scores")`.
  - Ticks I can make from the code: `:75` "Never uses `status == .closed`" `[x]`. Every `.closed` in `Swoop/` is `AppPose.closed`; `HingeReader.swift:33-38` reads only `hinge.angle`. `:80` "No notifications, no rating prompt" `[x]` (no `UNUserNotificationCenter` or `requestReview`/`SKStoreReview` in `Swoop/`).
  - Regenerate the untracked `docs/appstore/asc-metadata.json` from the fixed docs (it copies the stale block). It sits next to an untracked `tools/appstore/`; commit both or delete them.

### P1-5. The store frames were made before Round 12 and the deeper fold
- **Evidence:** the last App Store screenshots run is 40451917135 (27 Oct 04:50 UTC). Round 12 (`1a6049b`, Skip and the dots moved, ring framing, "Your wings" caption, Gull Point label) and `2f995ec` came after it.
- **Fix:** after code freeze, run `store.yml` on the release-candidate commit. Upload only from that run's `store-*` artifacts, after reading its MANIFEST (`screenshots.md:106`).

### P1-6. The release-candidate commit isn't CI-verified yet
- **Evidence:** CI run 40492044234 on `2f995ec` (the code in TestFlight 1.0 (10)) was still **in_progress**. The Round 12 push before it failed (40482728701); R12b fixed it (40484136130, green).
- **Fix:** submit only a build whose commit has a green `ci.yml` run. Record the run id in `metadata.md` §10 and in the review-notes check table.

### P1-7. The "checked against the code" tables point at an R9 commit, and their RC columns are empty
- **Evidence:** `metadata.md:251` and `review-notes.md:60` say "commit `a036bc4`" (Round 9). The code has moved through R10–R12 and the 55° gate. Every RC cell is `[ ]`. The last row of `metadata.md:270`, "No network code, no SDKs", isn't ticked even in the Code column.
- **Fix:** change both to "Checked against `2f995ec` (TestFlight 1.0 (10)) on 27 Oct by QA-FINAL". Tick `metadata.md:270` Code `[x]`. Evidence: no `URLSession`, `URLRequest`, `NWConnection`, `import Network`, `WKWebView`, `SFSafari`, `openURL`, `Link(`, ATT, `ASIdentifier`, CloudKit or any SDK in `Swoop/`, and no `packages:` in `project.yml`. The only outbound path is GameKit. Tick the `privacy.md` §3 rows the same way (see "Clean"). Re-tick the RC columns on the final build.

### P1-8. iPad compatibility mode has never been run, and the layout depends on screen-shape heuristics
- **Evidence:** the app is iPhone-only (`project.yml:54` `TARGETED_DEVICE_FAMILY: "1"`), so App Review may open it on an iPad in compatibility mode. No workflow runs on an iPad simulator. Duo detection without a hinge is by shape:
  - `UI/Layout.swift:26-31` `looksLikeDuoInner`: short/long > 0.62 and short side ≥ 600 pt. That drives `hasFold` (`:52-57`) and Duo copy (`RootView.swift:149-151`, `HomeView.swift:36`).
  - `App/OrientationLock.swift:30-34`: portrait allowed at a ratio over 0.6.
  - iPad compatibility normally presents an iPhone-sized canvas (ratio about 0.46–0.56, short side under 600), which would give the iPhone layout, landscape only and touch controls. But that hasn't been seen running.
  - Haptics are safe on iPad: `FeelHaptics.swift:323` checks `supportsHaptics`.
- **Fix:** run `ci/screenshots.sh` (Home, a flight, Results, Settings, the portrait pose) on an iPad simulator with the iPhone-only Debug build. Pass if the log shows `SWOOP-T canvas …x… fold=0 mirrored=0`, the play pose is landscape, Settings shows no "Play with touch" and no Device test card, and portrait shows "Turn your iPhone sideways". If the canvas ever looks Duo-shaped, gate `looksLikeDuoInner` on `UIDevice.current.userInterfaceIdiom == .phone && !ProcessInfo.processInfo.isiOSAppOnMac` plus a hinge actually reported.

### P1-9. Support page: FAQ answers say "Flight over"; the accessibility doc names the wrong end word
- **Evidence:** `support.html` is correct apart from P0-2. `accessibility.md:20` and `:51` list "Flight over" as the in-world end word; the run shows "The storm caught you" (`PlayHUD.swift:1503`). The contrast check B would then measure the wrong text.
- **Fix:** `accessibility.md:20`: `the end as "Flight over"` → `the end as "The storm caught you" (and "Flight over" on the Results card)`. `:51`: `"Flight over"` → `"The storm caught you"`.

### P1-10. Age-rating rationale and claim tables still describe the R9 ending
- **Evidence:** `metadata.md:219` ("the storm passes over and 'Flight over' appears") and `:262` ("caught = 'Flight over'"). Not false for the rating, but the §10 table is the truth check for the copy.
- **Fix:** `:219` → `Being caught is calm: the storm passes over, "The storm caught you" appears, and the Results card follows.` `:262`, claim column → `The storm speeds up; perfect landings push it back (\`perfectGapBonus\`); caught = "The storm caught you", then Results ("Flight over")`.

---

## P2

1. **The app icon PNG has an alpha channel**, although every pixel is opaque. Evidence: `Swoop/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` IHDR colour type 6 (RGBA); decoded, the minimum alpha is 255 and 0 pixels are non-opaque. TestFlight accepted builds 2–10 with it, so it is not blocking. `DemoMode.swift:434-443` (`opaquePNG`) says "no alpha channel", but its PNGs still come out RGBA. Fix: flatten once on the Mac runner: `sips -s format jpeg AppIcon-1024.png --out t.jpg && sips -s format png t.jpg --out AppIcon-1024.png`. Do the same for the 12 achievement badges before uploading them (`achievements.md:8` requires no transparency).
2. **"Plays on every iPhone" overclaims a little.** The deployment target is iOS 18 (`project.yml:7`), which means iPhone XS/XR and later. It appears in `metadata.md` description heading (`:64`, `:110`), frame P01's caption (`ci/store-scenarios.txt:22`, `screenshots.md:59`) and `docs/site/index.html` `<meta description>`. Fix: caption `The two halves are your *wings*. / Best on iPhone Duo. Plays on other iPhones too.`; heading `MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.` (keeps "iPhone" in its exact form); meta description `… Plays on other iPhones too. …`.
3. **"Levels unlock eight birds … five skies"**, but Gull and Golden Hour are starters (`Core/Catalogs.swift:21`, `:70`, `unlockRank: 0`). In `metadata.md:84`/`:130`, replace with `Three goals at a time take you up 15 levels. Eight birds, from Gull and Puffin to Albatross and Golden Gannet, five skies, from Golden Hour to Northern Lights and Moonrise, and coloured trails, unlocked as you level up. Every bird flies exactly the same; only the look changes.` (en-US: `colored`). Make the same change in `review-notes` §4, `support.html:77` and `site/index.html:121` if you want them identical.
4. **Subtitle "Fold your phone. Fly."** reads oddly on non-folding iPhones. The risk is low, because the promo text says other iPhones play. Keep it, or A/B `Stay ahead of the storm` with 1.0.1 (`metadata.md:35`).
5. **Privacy policy "Effective 24 November 2026"** (`site/privacy.html:6`, `privacy.md:53`), but the URL is live during TestFlight and review. Change to `Last updated 27 October 2026`.
6. **Support only through GitHub issues**, which needs a GitHub account (`support.html:25`, policy "If you contact us"). Guideline 1.5 asks for an easy way to contact the developer. Consider adding a contact email to the support page.
7. **Achievements checklist isn't implemented as written** (`achievements.md:79-82`). `GameCenterManager.swift:227-231` reports only `percentComplete = 100`, so there's no partial progress. A sign-in that completes mid-flight calls `flush()` (`:161-166`), so a banner could appear mid-run. Either untick the claims or queue banners until Results.
8. **"Three Dawns: three days in a row"**, but the streak bridges one missed day (`ProgressStore.swift:300-316`, `streakWithGrace`), so it can unlock with a gap. Description → `Keep a Daily Flight streak of three days.`
9. **VoiceOver says "Chain lost"** (`GameController.swift:1825`), an off-glossary word (DECISIONS #36). → `"In a row lost"` or `"Run of Perfects over"`.
10. **`launchDay` is hard-coded to 24 Nov 2026** (`Core/Lighthouses.swift:117-126`). It is correct for the planned release, and before launch every Daily shows "#1". If the launch moves to 8 Dec (runbook `:34`), share lines start at "Daily #15". Add to runbook `:34`: `…and tell Claude, who moves \`DailySeed.launchDay\` to the new date before the final build.`
11. **Build numbers come from `github.run_number`** (`testflight.yml:120`). "Re-run" of an old run reuses its number and the upload is rejected as a duplicate. Runbook §2c should say "use Run workflow, never Re-run".
12. **`UIRequiresFullScreen`** (`project.yml:39`) is deprecated and ignored on iPadOS 26+ for apps built with the iOS 26+ SDK. It is harmless for an iPhone-only app; leave it or drop it.
13. **CLAUDE.md:24-25** says the repo "was created private … making it public is the founder's call". It is public (verified with `gh`). Update the takeover doc.
14. **`social-launch.md:120` and `press-kit.md:49`** still use "Flight over" as the end beat. Not a store field, but for consistency use "The storm caught you".

---

## Checked and clean

**Build config (`project.yml`)**
- `MARKETING_VERSION "1.0"`; `CFBundleShortVersionString`/`CFBundleVersion` come from build settings, and CI checks that the build number equals the run number (`testflight.yml:145-149`). Bundle ID `com.pravegm.swoop`, display name "Swoop".
- iOS 18.0 deployment target; hinge code behind `#available(iOS 27.1, *)` (`HingeReader.swift:32`). `TARGETED_DEVICE_FAMILY "1"`.
- `UILaunchScreen` → `LaunchBackground` colour (exists, opaque). `UIStatusBarHidden`, `UIViewControllerBasedStatusBarAppearance false`, `UIUserInterfaceStyle Dark`.
- All four orientations in the plist, narrowed at runtime by `OrientationLock` (landscape-only on non-Duo).
- `ITSAppUsesNonExemptEncryption false`: there is no crypto, and the `GameKit` use is exempt.
- No `NS*UsageDescription` keys (none needed), no packages, no background modes.

**Entitlements, privacy manifest, icon**
- The entitlements file is generated with only `com.apple.developer.game-center: true` (`project.yml:45-48`). It is gitignored as intended. Build 10's App Store signature carries it (`GC_ENT: yes`).
- `PrivacyInfo.xcprivacy`: tracking false, no tracking domains, no collected data types. UserDefaults `CA92.1` is correct (app-only, no app group or suite). SystemBootTime `35F9.1` covers `CACurrentMediaTime` frame timing, which is fine even if not strictly required.
- No file-timestamp APIs (`creationDate`, `modificationDate`, `attributesOfItem`, `contentModificationDate`) and no disk-space APIs. The only `FileManager` and `write(to:)` calls are in the DEBUG-only `DemoMode.swift`. No `systemUptime` or `mach_absolute_time`, no active-keyboard APIs. The manifest is complete.
- App icon: one 1024 × 1024 universal entry. For the alpha channel, see P2-1.

**Release hygiene**
- Demo mode: `App/DemoMode.swift` and `App/DemoRunner.swift` are wrapped in `#if DEBUG` from the first line to the last. Every `DemoConfig` and demo use elsewhere is inside `#if DEBUG` (GameController, SwoopApp, AppModels, RootView, FlightScene).
- In Release, `AppTrace.enabled`, `FeelDemoLog.isEnabled` and `FeelHingeLog` are `false`, so `print` never runs. The only other logging is `os.Logger` `.error` on audio and haptics failures, which is not spam.
- Game Center skips itself only in DEBUG demo runs.
- No `TODO`, `FIXME`, placeholder or "Lorem" text. The one `fatalError` is the unused `init(coder:)`.
- No "beta", "Android" or other-platform strings. The only user-visible "TestFlight" is P0-4.
- No URLs in the app at all: the privacy text is in-app, and sharing is plain text with no link.
- Hard-coded dates: the epoch 2026-01-01 and `launchDay` 24 Nov, both consistent with `metadata.md` §9 (P2-10).

**App Review guidelines**
- **2.5.1:** public SwiftUI `onHingeChange` only, angle only (`hinge.angle.degrees`), never `status`.
- **5.1.1:** no networking, analytics, crash SDKs, ATT, CloudKit or notifications. GameKit is the only outbound path. Sharing goes through `ShareLink` with text and an image, only on tap. "Data Not Collected" is true.
- **Game Center:** quiet authentication (the sign-in view controller is shown only on tap), access point off, signed-out message, scores queued.
- Achievement and leaderboard IDs match exactly between `achievements.md`, runbook §4 and `ProgressStore.swift:321-338` / `GameCenterManager.swift:15-17`: `swoop.longest`, `swoop.daily`, and `swoop.ach.first/km1/km5/km10/chain5/chain10/tailwind/lighthouse/lighthouse3/cloud/daily3/allbirds`, 12 in all. Points add up to 625. 1 Nov 2026 is a Sunday, as the doc says.
- **2.3 metadata vs the game:** lighthouses (Gull Point 4 km, Saltlight 9, Kestrel Head 15: `Tuning.swift:275-278`, `Lighthouses.swift`), Tailwind at 3 in a row with +15 % speed, Perfect +6 %, Perfects push the storm back (`perfectGapBonus 120`), 15 levels (`maxRank 14`), 8 birds, 5 skies, 5 trails, Flight School with a guide gull (skippable, replay in Settings), the Daily Flight (UTC, one scored try, practice after, streak, share), "Wings by: Tapping", "Play with touch", "Respect silent switch" (off by default; `.playback`+`.mixWithOthers`), Haptics Off/Normal/Strong, Reduce Motion (camera shake, bloom, flare and lightning cut: `FlightScene`, `SceneEffects`, `SceneStorm`), folds of about 30° (stroke 30–36°), the bird on the sharp half (default screen-right). All true in the code.
- **Character and byte counts:** name 18, subtitle 21, promo 166, description 3,435 / 3,434, keywords 97 bytes, review notes 3,745 bytes ASCII. All inside Apple's limits.
- **Trademarks:** "iPhone" is kept in its exact form; "iPhone Duo" is used referentially and never in the name, subtitle or keywords; no Apple badge drawn in frames; the site carries a trademark notice.
- **Age rating 4+:** the §8 answers match the content (weather storm, no harm, no chance mechanics, no UGC, no web access).

**Store docs**
- `screenshots.md` caption tables match both scenario files word for word (apart from the stale paragraph, P1-3).
- The `docs/*.html` forwarders point at `site/` correctly, and internal links between the site pages resolve.
- The featuring nomination is consistent with the 24 Nov date.

---

## Top 5 before submission
1. **P0-1:** turn on GitHub Pages; the Support, Privacy and Marketing URLs are 404 today.
2. **P0-2 / P1-4:** replace the review-notes block (55° pause, Skip from step 1, quickest path, "Scores", "The storm caught you"; 3,933 bytes) and fix `support.html:62`.
3. **P0-4:** hide the "Device test · Hinge readout (TestFlight)" card from reviewers (non-Duo devices, no "TestFlight" label).
4. **P0-3:** correct "the hinge reading isn't stored" in the privacy policy, `privacy.md` and the review notes (the resting angle is saved on the device).
5. **P1-1 / P1-5 / P1-6:** on the release-candidate commit, get a green CI run, run the demo-string check on the uploaded Release binary, re-shoot the store frames after R12, and update the runbook's screenshot counts (P1-2).
