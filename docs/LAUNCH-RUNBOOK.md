# Swoop launch runbook (for the founder)

*Written Mon 26 Oct 2026. This is the only document you need to follow. It lists **only the steps that need your own GitHub or Apple login**; Claude does everything else. It goes in order, and each step says exactly where to click and what to type. Everything you paste lives in `docs/appstore/`; the reason behind every choice is in `docs/appstore/DECISIONS.md`. Whenever a step says "tell Claude", a one-line message in chat is enough.*

**Launch: Tuesday 24 November 2026, about 08:00 UK time.** Brim launches the week before (Tue 17 Nov), so the two games never share a week.

A few words used below:
- **Repo** (repository): Swoop's project page on GitHub, `github.com/pravegm/swoop`. It holds the code and these documents.
- **Actions**: GitHub's build robot. It turns the code into an app on Apple's newest Xcode, because your Mac can't.
- **Secret**: a password-like value stored in the repo's settings, which only the build robot can read.
- **TestFlight**: Apple's app for installing test builds on your own phone before launch.

---

## Timeline

| When | What you do | Section |
|---|---|---|
| **Today, Mon 26 Oct** | Check the repo is public and turn on the website (5 minutes). **This unblocks everything else** | §0 |
| Mon 26 – Tue 27 Oct | Register Swoop with Apple and create the app record (20 minutes) | §1 |
| Mon 26 – Wed 28 Oct | Add the 4 GitHub secrets (10 minutes) | §2a–b |
| **By Tue 3 Nov** (sooner is better) | Submit the featuring nomination (Apple wants 3 weeks' notice) | §1e |
| When Claude says the build is ready (about Wed 28 – Fri 30 Oct) | Run the TestFlight build (2 clicks) | §2c |
| **Fri 30 Oct – Sun 1 Nov** | First play on your Duo: the 10-minute check, then send Claude your scores | §3 |
| Mon 2 – Fri 13 Nov | Claude tunes the feel from your notes; you repeat the 10-minute check on each new build | §3 |
| **Sat 14 – Sun 15 Nov** | Game Center items, price, privacy, age rating, and paste the listing (one evening) | §4, §5, §6a–d |
| Mon 16 Nov | Claude: code freeze, the final build and the screenshots | — |
| Tue 17 Nov | **Brim's launch day.** No Swoop work today | — |
| **Wed 18 Nov** | Pick the final build, upload screenshots, **submit for review** with manual release (last safe day: Fri 20 Nov) | §6e–g |
| ~Thu 19 – Fri 20 Nov | Apple approves (usually 24–48 hours). Swoop then waits for you | §6g |
| Sat 21 – Mon 23 Nov | Promo codes for creators; pre-launch posts | §7 |
| **Tue 24 Nov, ~08:00 UK** | Press **Release This Version**. Launch-day steps | §7 |

**If Swoop isn't submitted by Fri 20 Nov:** move the launch to **Tue 8 Dec** (never 17 Nov or 1 Dec, which are Brim's launch and fallback dates). Change the nomination's Publish Date (§1e) and tell Claude.

---

## §0. Make the repo public and turn on the website (do this first)

### 0a. Make the repo public

**Why:** this GitHub account's billing blocks GitHub Actions on **private** repos, which stops every build, test and TestFlight upload. Public repos build for free. Brim and Squish are already public for the same reason. Nothing personal is in the repo.

1. Go to **github.com/pravegm/swoop** and sign in.
2. Click **Settings** (the gear tab along the top of the repo, on the right).
3. Stay on **General** (left list) and scroll to the very bottom, to the red **Danger Zone** box.
4. Click **Change visibility** → **Change to public**.
5. GitHub asks you to confirm (it may ask you to type `pravegm/swoop` and to confirm with your password or phone). Confirm.

*Already done?* On 26 Oct at about 11:00 UTC GitHub already reported the repo as **public**. If the Danger Zone button says **Change to private**, it's public: skip to 0b. (Builds have been running again since then.)

### 0b. Turn on the website (support and privacy pages)

Apple needs a working support page and privacy page before it accepts the app. They're already written; this puts them online for free.

1. github.com/pravegm/swoop → **Settings** → **Pages** (left list, under "Code and automation").
2. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
3. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
4. Wait 1–2 minutes, then open these on your phone. All three must load:
   - Home: **https://pravegm.github.io/swoop/**
   - Support: **https://pravegm.github.io/swoop/support.html**
   - Privacy: **https://pravegm.github.io/swoop/privacy.html**

   (Each short address forwards to the real page under `/site/`, which is fine.)

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

Support is through **GitHub issues** (`github.com/pravegm/swoop/issues`), the same choice you made for Squish, so there's no email address to set up. Issues are switched on already.

---

## §1. Register Swoop with Apple and create the app record (about 20 minutes, once)

**1a. Register the bundle ID** (Swoop's unique name inside Apple). Go to **developer.apple.com** → **Account** → **Certificates, IDs & Profiles** → **Identifiers** → the blue **+**.
1. Choose **App IDs** → Continue → **App** → Continue.
2. Description: `Swoop`
3. Bundle ID: choose **Explicit** and type `com.pravegm.swoop`
4. In the **Capabilities** list, tick **Game Center** (nothing else).
5. **Continue** → **Register**.

**1b. Create the app record.** Go to **appstoreconnect.apple.com** → **Apps** → the blue **+** → **New App**.

| Field | Type or pick |
|---|---|
| Platforms | **iOS** |
| Name | `Swoop: Tuck & Soar` (if it says the name is taken, try `Swoop: Fold to Soar`, then `Foldwing: Tuck & Soar`, and tell Claude which one worked) |
| Primary Language | **English (U.K.)** |
| Bundle ID | pick `com.pravegm.swoop` from the list (if it's missing, wait 5 minutes and reload) |
| SKU | `swoop-2026` |
| User Access | **Full Access** |

Click **Create**.

**1c. Tell Claude the Apple ID.** In the new app, open **App Information** (left list) and copy the **Apple ID** number (10 digits). Send it to Claude: it becomes the App Store link `https://apps.apple.com/app/id<that number>` in the press kit and posts.

**1d. Turn on Game Center:** in the app, open **Services** (in some layouts **Features**) → **Game Center** → turn it on. You'll add the leaderboards and achievements in §4.

**1e. Featuring nomination (by Tue 3 Nov; sooner is better).** In the app: **Featuring** → **Nominations** → **Create Nomination**. Copy every field from `docs/appstore/featuring-nomination.md`. Press **Submit** (a saved draft doesn't count).

---

## §2. Connect GitHub to Apple, then build for TestFlight

GitHub builds Swoop for you on Apple's newest Xcode. It needs four secrets: **the same four values you put into `pravegm/brim` and `pravegm/squish`**. One Apple key works for all your apps.

You don't need to make any certificate or profile. The build uses **Apple's cloud-managed distribution certificate** through the API key, so it never creates development certificates (the "maximum number of certificates" problem Brim hit is fixed in Swoop's workflow from the start).

**2a. Gather the four values.** GitHub never shows a saved secret again, so you can't copy them out of Brim's or Squish's settings. Get them from the source:

| Secret name | Where to find the value |
|---|---|
| `ASC_KEY_ID` | App Store Connect → **Users and Access** → **Integrations** → App Store Connect API → **Team Keys**: the "Key ID" column of the key you used for Brim and Squish |
| `ASC_ISSUER_ID` | Same page, the **Issuer ID** shown above the table |
| `ASC_PRIVATE_KEY` | The `.p8` file you downloaded when you made that key. Open it in TextEdit (or Notepad) and copy **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `APPLE_TEAM_ID` | developer.apple.com → Account → **Membership details** → Team ID (10 characters) |

*Can't find the `.p8` file?* Apple only lets you download it once. Make a new key on the same Team Keys page: **+**, name `Studio CI`, Access **Admin**, **Generate**, **Download** the file straight away, and use the new Key ID. Don't revoke the old key: Brim and Squish keep using it.

**2b. Add them to Swoop's repo.** github.com/pravegm/swoop → **Settings** → **Secrets and variables** (left list) → **Actions** → **New repository secret**. For each of the four: type the name exactly as above, paste the value, click **Add secret**.

**2c. Run a build (when Claude tells you the game is ready).** github.com/pravegm/swoop → **Actions** (tab along the top) → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → in "What to test" type anything (e.g. `first Duo test`) → leave "Only build…" unticked → **Run workflow**.
- About 20–30 minutes later the run shows a green tick. A red cross with "Missing repository secrets" means a name in 2b is misspelt; anything else, send Claude the link to the run.
- 10–30 minutes after the green tick, the build appears in App Store Connect → the app → **TestFlight**, first as "Processing". You won't be asked about encryption: that answer is already built in.

---

## §3. Play it on your Duo: the 10-minute check

**Set up (once).** App Store Connect → the app → **TestFlight** → **Internal Testing** → **+** → group name `Studio` → add yourself (your Apple Account email) → add the build. On the Duo, open Apple's **TestFlight** app (you have it from Brim), and tap **Install** next to Swoop. Later builds appear there automatically.

**Before you start:** ringer **on**, volume about half, sitting comfortably. Open the Duo and turn it sideways so the fold runs **top to bottom**, like a book, one hand on each half. Have a clock or timer nearby.

| Minute | Try this | Notice |
|---|---|---|
| 0–1 | Open Swoop. On the title screen, fold the halves in a little and open them again, slowly | Does the big bird fold its wings **with you**? Does it feel like your hands are the wings? |
| 1–3 | Tap **Fly**. After 3-2-1, fold a little on the way down each wave and open as you go over the top | Does folding feel **heavy and fast** (a dive)? Does opening feel like **lift**? How far did you fold before it felt like a full tuck? |
| 3–5 | Two more flights. Try to land on the downslope of the next wave for a **Perfect**, and get three in a row for a **Tailwind**. **Time each flight** from 3-2-1 to the result card | Did you get a Perfect in the first 5 minutes? A Tailwind? Did splashes feel fair? Write down each flight's time and distance |
| 5–6 | **Blur test.** Open the Duo completely flat, tap Fly, and start folding from flat. Then do it again starting from a relaxed book (slightly folded) | Did one half of the screen blur? Which half (left or right), for about how long, and **when** (only from flat, or also during normal play)? |
| 6–7 | Mid-flight, fold the Duo further than usual (towards an L shape), then open it again. Then close it fully, look at the outer screen, and reopen | Does it pause with "Open your wings to keep flying" and carry on when you open? What does the outer screen show? Did closing ever cost you the flight? |
| 7–8 | Play the **Daily Flight**, then tap **Share** and send it to yourself | Does the shared line look right? |
| 8–9 | Flip the **silent switch on**, play a few seconds, then open **Settings** and try Sound, Haptics, **Respect silent switch** and **Play with touch** (fly once with touch) | Is there still sound on silent? Do the switches work? How do the **haptics** feel: the rumble while tucking, the tap on take-off, the thud on a splash? |
| 9–10 | One last flight, however you like | Did you want "one more go" when it ended? |

**Comfort check (important):** at any point did your hands, wrists or thumbs get tired? Did you ever have to fold further or faster than felt natural, or worry about the hinge?

**Send Claude this (copy, fill in, paste in chat):**
```
Swoop build [number from TestFlight], iPhone Duo, iOS [version]
Scores 1-5:
  tuck feels like a dive [ ] / opening feels like lift [ ] / Perfect feels earned [ ]
  sound [ ] / haptics strength [ ] (too weak / right / too strong: ...)
  comfort [ ] / addictive, want one more go [ ]
Fold needed for a full tuck: [tiny / about right / too much]
Blur: did half the screen blur? [yes/no]  Which half: [left/right]  How long: [ ] s
  When: [only starting from flat / also in normal play / never]
Sound on silent: [yes/no]   "Respect silent switch" works: [yes/no]
Flights (time from 3-2-1 to result, distance): 1 [ ] 2 [ ] 3 [ ] 4 [ ]
Did closing the phone ever cost a flight? [ ] times
Did the screen ever dim or lock while flying? [yes/no]
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
A screen recording (Control Centre → Screen Recording, microphone on) or a phone video of your hands while you fly helps a lot: send it if you can. In TestFlight you can also take a screenshot in Swoop and tap **Share Beta Feedback**.

Repeat the check on each new build Claude sends (Mon 2 – Fri 13 Nov). The release build is the one where every score is 4 or 5 and comfort is 5.

---

## §4. Game Center (App Store Connect → the app → Services → Game Center)

Full details (both descriptions, triggers, why) are in `docs/appstore/achievements.md`. **IDs can never be changed once saved, so type them exactly.**

**4a. Leaderboards → +** (twice):

| Leaderboard ID | Type | Reference name | Display name | Score format | Suffix | Sort | Submission |
|---|---|---|---|---|---|---|---|
| `swoop.longest` | **Classic** | Longest flight | Longest Flight | Integer | ` m` (both singular and plural) | High to Low | Best score |
| `swoop.daily` | **Recurring**: start **1 Nov 2026 at 00:00 UTC** (midnight UK time in winter), lasts **1 day**, repeats every **1 day** | Daily Flight | Daily Flight | Integer | ` m` | High to Low | Best score |

Both are in **metres** flown. Fill in the display name and suffix for **English (U.K.)** and **English (U.S.)**.

**4b. Achievements → +** (twelve times). None is hidden, none can be earned more than once. Each needs its 1024 × 1024 image: Claude sends you a link to the twelve images.

| Achievement ID | Title | Description before earning | Description after earning | Points |
|---|---|---|---|---|
| `swoop.ach.firstflight` | First Flight | Finish your first flight. | Wings out, off you go. | 10 |
| `swoop.ach.km1` | Open Water | Fly 1 km in one flight. | One kilometre of open sea. | 15 |
| `swoop.ach.km5` | Long Haul | Fly 5 km in one flight. | Five kilometres, and the storm still behind you. | 25 |
| `swoop.ach.km10` | Ocean Crossing | Fly 10 km in one flight. | Ten kilometres. The gulls are impressed. | 75 |
| `swoop.ach.chain5` | Skipping Stone | Chain 5 Perfects in a row. | Five Perfect skims, one after another. | 50 |
| `swoop.ach.chain10` | Glass Water | Chain 10 Perfects in a row. | Ten in a row. Barely a ripple. | 100 |
| `swoop.ach.tailwind` | Tailwind | Catch a Tailwind with three Perfects in a row. | The wind is on your side. | 25 |
| `swoop.ach.lighthouse` | Keeper's Light | Fly past a lighthouse. | The beam swept over you. | 25 |
| `swoop.ach.lighthouse3` | Three Lights | Pass 3 lighthouses in one flight. | Three lighthouses, one flight. | 100 |
| `swoop.ach.cloud` | Head in the Clouds | Soar high enough to touch the clouds. | Up where the clouds are. | 50 |
| `swoop.ach.daily3` | Three Dawns | Play the Daily Flight three days in a row. | Three days, three seas. | 50 |
| `swoop.ach.allbirds` | Whole Flock | Unlock all eight birds. | Every bird in the flock is yours. | 100 |
| | | | **Total** | **625** (of 1,000 allowed) |

For **English (U.S.)**, use "kilometer" instead of "kilometre" in the three distance descriptions; everything else is the same.

**4c.** Later, on the **1.0 version page** (§6), in the **Game Center** section, switch it on and **+** add both leaderboards and all twelve achievements. They only go live with the version.

---

## §5. Price, availability, age rating and privacy

**5a. Pricing and Availability** (left list):
- **Price:** **Add Pricing** → base country **United Kingdom** → **£1.99**. Leave other countries on Apple's automatic prices; check the US shows **$1.99**.
- **Availability:** all countries or regions **except China mainland** (untick it).
- **Pre-order:** off. **Family Sharing:** on (it can't be turned off later).

**5b. Age rating:** **App Information** → **Age Rating** → **Edit**. Answer every question **None** or **No**, exactly as the table in `docs/appstore/metadata.md` §8. The result must say **4+**.

**5c. App Privacy** (left list):
1. **Privacy Policy URL:** `https://pravegm.github.io/swoop/privacy.html` → Save.
2. **Get Started** → "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app** → **Save** → **Publish**.
3. The page now says **Data Not Collected**. (Why it's true: `docs/appstore/privacy.md`.)

---

## §6. Paste the listing, then submit with manual release

Paste everything from `docs/appstore/metadata.md` (the code blocks are the exact text).

**6a. App Information** (left list):
- **Subtitle:** `Fold your phone. Fly.`
- **Category:** Primary **Games**, subcategories **Casual** and **Arcade**. Secondary **Entertainment**.
- **Content Rights:** "Does your app contain, show, or access third-party content?" → **No**.
- **Add English (U.S.):** the language menu at the top right → **Add Language** → English (U.S.) → fill in the same name and subtitle.

**6b. The 1.0 version page** (left list, under iOS App). Fill it in for **English (U.K.)**, then switch the language menu to **English (U.S.)** and repeat:
- **Promotional Text**, **Description** (the U.K. or U.S. block), **Keywords**: `metadata.md` §3–5.
- **Support URL:** `https://pravegm.github.io/swoop/support.html`
- **Marketing URL:** `https://pravegm.github.io/swoop/`
- **Copyright:** `© 2026 pravegm`

**6c. App Review Information** (same page): **Sign-in required** unticked; your first name, last name, phone and email (Apple's reviewers contact a real person; this goes only into App Store Connect, never into the repo); **Notes:** paste the block from `docs/appstore/review-notes.md`.

**6d. Version Release** (same page): choose **Manually release this version**.

**6e. Screenshots** (same page, Previews and Screenshots). Claude sends you the download link for the final set on Mon 16 Nov, with the order (`docs/appstore/screenshots.md`).
1. **6.9" Display:** drag in P1–P5, in order.
2. **6.3"/6.1" Display** (whichever "iPhone with Dynamic Island" slot it asks for): P1–P5.
3. Open the device list. **If you see iPhone Duo**, add D1–D6 there and check them with Apple's iPhone Duo preview. If there's no iPhone Duo entry, skip it (the Duo set comes with 1.0.1).
4. App Preview video: only if Claude says it's ready.

**6f. Build and Game Center** (same page): in **Build**, **+** → the build Claude names as the release build. In **Game Center**, add the 2 leaderboards and 12 achievements (§4c).

**6g. Submit (Wed 18 Nov; last safe day Fri 20 Nov).**
1. Click **Add for Review**. If App Store Connect lists anything missing, fix it and click again.
2. Click **Submit to App Review**.
3. Usually 24–48 hours. You'll get an email.
   - **Approved:** the status becomes **Pending Developer Release**. Do nothing until launch morning (§7).
   - **Rejected:** don't panic. Copy Apple's message to Claude. Ready-made replies are in `review-notes.md` ("If rejected under…"). Answer in the Resolution Center the same day.

---

## §7. Launch: Sat 21 – Tue 24 Nov

**Sat 21 – Mon 23 Nov:** App Store Connect → the app → **Promo Codes** → generate codes for the creators in `docs/appstore/social-launch.md` §4. Keep a list of who got which.

**Tue 24 Nov, about 08:00 UK:**
1. App Store Connect → the app → the 1.0 page → **Release This Version** → confirm. It can take a few hours to appear in every country.
2. Open Swoop's App Store page on your phone (UK) and check: price £1.99, **4+**, "Data Not Collected", the screenshots, Game Center. Ask a US friend, or switch storefront, for $1.99.
3. **Accessibility labels:** App Store Connect → the app → **App Accessibility** → Get Started → **iPhone**. Tick only the labels `docs/appstore/accessibility.md` marks as passed (planned: **Reduced Motion**, **Sufficient Contrast**, **Differentiate Without Color Alone**). Leave the rest unticked → **Publish**.
4. Post the launch posts from `social-launch.md` §2, and send the launch-day notes from `press-kit.md` #6 (as replies in your earlier email threads).
5. Tell Claude "Swoop is live": Claude swaps "On the App Store 24 November" on the website for the real App Store link.
6. Play the first Daily Flight yourself and check your distance appears on the Daily Flight leaderboard.
7. For the next few days: App Store Connect → the app → **Ratings and Reviews**, and the TestFlight / Xcode crash reports. Forward anything odd to Claude for 1.0.1.
