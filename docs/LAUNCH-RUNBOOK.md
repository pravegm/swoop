# Swoop launch runbook (for the founder)

*Rewritten Tue 27 Oct 2026, after the final QA. This is the only document you need. It lists **only the things you must do by hand**, in order, with the exact clicks. Claude does everything else, including putting the whole store listing into App Store Connect with the App Store Connect tool (`asc.yml`). Whenever a step says "tell Claude", a one-line message in chat is enough.*

**Launch: as soon as Apple approves it.** The release is set to **"Automatically release this version"**: the moment App Review approves Swoop (usually 24–48 hours after you submit), it goes live by itself. **There is nothing to press.** If you submit on Tue 27 or Wed 28 Oct, expect it live around **Thu 29 – Fri 30 Oct**.

**Already done, nothing for you to do:** the app record, the GitHub secrets, TestFlight builds 1.0 (2) to 1.0 (12), your Duo tests, and the final QA. The tool fills in the listing, categories, age rating, price and countries, the review notes and contact, Game Center, the screenshots and the featuring nomination (see "Reference" at the end).

---

## Your checklist

| # | Step | When | Time |
|---|---|---|---|
| 1 | Turn on the website (GitHub Pages) | **Now (overdue)**: the Support and Privacy links don't work until this is done | 5 min |
| 2 | App Privacy: "Data Not Collected" | After step 1, before step 5 | 3 min |
| 3 | Pricing and Availability: Mac and Vision Pro off, Family Sharing on | Before step 5 (the app goes live the moment it's approved) | 3 min |
| 4 | EU Digital Services Act trader status (only if asked) | Before step 5 | 2 min |
| 5 | Pick the build and submit for review | As soon as Claude says "ready" (the release-candidate build has passed its checks) | 5 min |
| 6 | If Apple rejects it: send Claude the message | If it happens | 1 min |
| 7 | Launch day (optional): check the page, posts, accessibility labels, promo codes | The day it goes live, and the days after | 30 min |

**If approval takes a lot longer** (for example after a rejection) and Swoop would go live close to **Brim's launch on Tue 17 Nov**, tell Claude: the two games shouldn't launch in the same week, so Claude would ask you to switch Swoop's Version Release to manual until after 17 Nov.

---

### 1. Turn on the website (do this now)

Apple needs a working support page and privacy page. They're written; this puts them online for free.

1. Go to **github.com/pravegm/swoop** and sign in.
2. Click **Settings** (the gear tab along the top of the repo, on the right).
3. In the left list, under "Code and automation", click **Pages**.
4. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
5. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
6. Wait 2 minutes, then open these three on your phone. **All three must load:**
   - Home: **https://pravegm.github.io/swoop/**
   - Support: **https://pravegm.github.io/swoop/support.html**
   - Privacy: **https://pravegm.github.io/swoop/privacy.html**

   (Each one forwards to the real page under `/site/`, which is fine.)

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

### 2. App Privacy: "Data Not Collected"

Do this after step 1 (Apple checks that the privacy page loads).

1. **appstoreconnect.apple.com** → **Apps** → **Swoop: Tuck & Soar**.
2. In the left list, click **App Privacy**.
3. **Privacy Policy URL:** the tool fills this in. If the box is empty, type `https://pravegm.github.io/swoop/privacy.html` → **Save**.
4. Click **Get Started**. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app** → **Save**.
5. Click **Publish** (top right) and confirm.
6. The page now says **Data Not Collected**. (Why that's true: `docs/appstore/privacy.md`.)

### 3. Pricing and Availability: Mac and Vision Pro off, Family Sharing on

The price (£1.99) and the countries (everywhere except China mainland and Vietnam) are set by the tool. Apple has no tool access for these three switches.

1. In the app's left list, click **Pricing and Availability**.
2. Under **iPhone and iPad Apps on Apple Silicon Macs**, untick **Make this app available**.
3. Under **Apple Vision Pro**, untick it too.
4. Click **Save**.
5. **Family Sharing:** click **App Information** in the left list (in some layouts it's on the Pricing and Availability page) → **Family Sharing** → **Turn On** → confirm. It can't be turned off later, which is fine.

### 4. EU Digital Services Act trader status (only if App Store Connect asks)

Apple asked again for Brim, even though your account answer was already set for Squish.

1. In the app's left list, click **App Information**.
2. Scroll to **App Store Regulations and Permits** → **Digital Services Act**.
3. If it asks for your trader status, give **the same answer as for Brim** (and Squish) → **Save**. If it already shows your status, there's nothing to do.

### 5. Pick the build and submit for review (when Claude says "ready")

The release build is **1.0 (12)**. The tool has already put it on the 1.0 page and attached the 2 leaderboards and 12 achievements to the draft submission.

1. In the app's left list, under **iOS App**, click **1.0 Prepare for Submission**.
2. Check that **Build** shows **1.0 (12)**. (If it's empty: click **+** → pick **1.0 (12)** → **Done** → **Save**.)
3. Click **Add for Review** (top right). If App Store Connect lists something missing, send Claude a screenshot.
4. Click **Submit to App Review**.

You don't need to touch anything else on that page: the description, screenshots, review notes, Game Center and the release setting are already filled in. Leave **Version Release** as it is: **Automatically release this version**.

Apple usually answers within 24–48 hours, by email. **Approved:** nothing to do; Swoop goes live by itself straight away (it can take a few hours to show in every country). That day is launch day: go to step 7.

### 6. If Apple rejects it

Don't worry: it's common for a first version. Copy Apple's whole message (App Store Connect → the app → **App Review**, or the email) and send it to Claude the same day. Claude writes the reply (ready-made answers are in `docs/appstore/review-notes.md`, "If rejected under…") and tells you exactly what to paste and where.

### 7. Launch day (optional): the day it goes live

- **Check the page:** open Swoop's App Store page on your phone: price £1.99, **4+**, "Data Not Collected", the screenshots, Game Center. Play today's Daily Flight and check your distance appears on the Daily Flight leaderboard. Then tell Claude "Swoop is live" (Claude swaps the website's "Coming soon to the App Store" for the real link).
- **Posts and emails:** everything is in `docs/appstore/social-launch.md` (§1 counts from the day it goes live, "Day 0"; the launch posts are in §2; the emails in §4). Post once the App Store page shows **Get** with the price. Nothing names a date in advance: before it's live, "coming to the App Store this week"; from then on, "out now".
- **Accessibility labels** (they can only be published once the app is live): App Store Connect → the app → **App Accessibility** → **Get Started** → **iPhone**. Tick **only** the labels that `docs/appstore/accessibility.md` marks as passed (planned: **Reduced Motion**, **Sufficient Contrast**, **Differentiate Without Color Alone**; Claude confirms which). **Never tick Larger Text**: Swoop doesn't scale its text. Leave every other box unticked → **Publish**.
- **Promo codes** (in the first few days, for the creators in `docs/appstore/social-launch.md` §4): App Store Connect → the app → **Promo Codes** → generate codes. Keep a list of who got which.
- **The days after:** App Store Connect → the app → **Ratings and Reviews**, and TestFlight's crash reports. Forward anything odd to Claude for 1.0.1.

---

## Appendix A: the 10-minute Duo check (for each new build Claude sends)

**Set up (once, already done).** App Store Connect → the app → **TestFlight** → **Internal Testing** → group `Studio` → add the build. On the Duo, open Apple's **TestFlight** app and tap **Install** (or **Update**) next to Swoop.

**Before you start:** ringer **on**, volume about half, sitting comfortably. Open the Duo and turn it sideways so the fold runs **top to bottom**, like a book, one hand on each half. Have a clock or timer nearby.

| Minute | Try this | Notice |
|---|---|---|
| 0–1 | Open Swoop. On the title screen, fold the halves in a little and open them again, slowly | Does the big bird fold its wings **with you**? Does it feel like your hands are the wings? |
| 1–3 | Tap **Fly**. After 3-2-1, fold a little on the way down each wave and open as you go over the top | Does folding feel **heavy and fast** (a dive)? Does opening feel like **lift**? How far did you fold before the wings felt fully folded? |
| 3–5 | Two more flights. Try to land on the way down of the next wave for a **Perfect**, and get three in a row for a **Tailwind**. **Time each flight** from 3-2-1 to the result card | Did you get a Perfect in the first 5 minutes? A Tailwind? Did splashes feel fair? Write down each flight's time and distance |
| 5–6 | **Blur test.** Open the Duo completely flat, tap Fly, and start folding from flat. Then do it again starting from a relaxed book (slightly folded) | Did one half of the screen blur? Which half (left or right), for about how long, and **when** (only from flat, or also during normal play)? |
| 6–7 | Mid-flight, fold deeper than usual, to an L shape and a bit past it: it should keep flying. Then fold much further (nearly closed), open again, then close it fully, look at the outer screen, and reopen | Did the L shape keep flying? Did the nearly-closed fold pause with "Open your wings to keep flying" and carry on when you opened? What does the outer screen show? Did closing ever cost you the flight? |
| 7–8 | Play the **Daily Flight**, then tap **Share** and send it to yourself | Does the shared line look right? |
| 8–9 | Flip the **silent switch on**, play a few seconds, then open **Settings** and try Sound, Haptics, **Respect silent switch** and **Play with touch** (fly once with touch) | Is there still sound on silent? Do the switches work? How do the **haptics** feel: the rumble while folded, the tap on take-off, the thud on a splash? |
| 9–10 | One last flight, however you like | Did you want "one more go" when it ended? |

**Comfort check (important):** at any point did your hands, wrists or thumbs get tired? Did you ever have to fold further or faster than felt natural, or worry about the hinge?

**Send Claude this (copy, fill in, paste in chat):**
```
Swoop build [number from TestFlight], iPhone Duo, iOS [version]
Scores 1-5:
  folding feels like a dive [ ] / opening feels like lift [ ] / Perfect feels earned [ ]
  sound [ ] / haptics strength [ ] (too weak / right / too strong: ...)
  comfort [ ] / addictive, want one more go [ ]
Fold needed for fully folded wings: [tiny / about right / too much]
Blur: did half the screen blur? [yes/no]  Which half: [left/right]  How long: [ ] s
  When: [only starting from flat / also in normal play / never]
L shape kept flying: [yes/no]   Nearly closed paused: [yes/no]
Sound on silent: [yes/no]   "Respect silent switch" works: [yes/no]
Flights (time from 3-2-1 to result, distance): 1 [ ] 2 [ ] 3 [ ] 4 [ ]
Did closing the phone ever cost a flight? [ ] times
Did the screen ever dim or lock while flying? [yes/no]
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
A screen recording (Control Centre → Screen Recording, microphone on) or a phone video of your hands while you fly helps a lot. In TestFlight you can also take a screenshot in Swoop and tap **Share Beta Feedback**.

**If Claude asks you to run a TestFlight build:** github.com/pravegm/swoop → **Actions** → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → type anything in "What to test" → leave "Only build…" unticked → **Run workflow**. **Always use Run workflow, never "Re-run" on an old run**: a re-run reuses the old build number, and Apple rejects the upload as a duplicate.

---

## Reference: what the tool sets (no action needed)

Claude runs the App Store Connect tool (GitHub → Actions → **App Store Connect tool**, `asc.yml`; details in `tools/appstore/README.md`). It reads `docs/appstore/asc-metadata.json`, which `node tools/appstore/build-metadata.js` builds from the docs, and changes only what differs. It never submits for review and never releases. You don't paste or create any of this:

| What | Value | Source |
|---|---|---|
| Name, subtitle, privacy URL (en-GB and en-US) | `Swoop: Tuck & Soar`, `Fold your phone. Fly.` | `metadata.md` §1–2 |
| Categories | Games: Casual + Arcade (Action if Apple's list has no Arcade); secondary Entertainment | `metadata.md` §7, DECISIONS #7 |
| Age rating | Every answer None / No: 4+ | `metadata.md` §8 |
| Version 1.0 | Copyright `© 2026 pravegm`; release **Automatically release this version** after App Review approval | `metadata.md` §9, DECISIONS #12, #31 |
| Description, keywords, promotional text, support and marketing URLs (en-GB and en-US) | | `metadata.md` §3–5, §9 |
| App Review notes, "no sign-in", the contact (copied from Squish's record, never in the repo) | | `review-notes.md` |
| Game Center | On; the 2 leaderboards and 12 achievements below, each achievement with its badge | `achievements.md` |
| Attach | Every leaderboard and achievement added to the 1.0 review submission (the build is yours, step 5) | |
| Screenshots | 6.9" and 6.3" sets (8 each), and the iPhone Duo set if Apple's API offers it | `screenshots.md` |
| Price and availability | £1.99 (UK base; Apple sets $1.99 and the rest); every country except China mainland and Vietnam | `metadata.md` §9, DECISIONS #9–10 |
| Featuring nomination | App Launch, publish date Fri 30 Oct 2026, **submitted** with the listing (shorter notice than Apple's preferred 3 weeks) | `featuring-nomination.md` |

### Game Center items (created by the tool)

IDs can never be changed once created. These are the exact values; `tools/appstore/build-metadata.js` checks this table against `achievements.md`.

**Leaderboards:**

| Leaderboard ID | Type | Reference name | Display name | Score format | Suffix | Sort | Submission |
|---|---|---|---|---|---|---|---|
| `swoop.longest` | **Classic** | Longest flight | Longest Flight | Integer | ` m` (both singular and plural) | High to Low | Best score |
| `swoop.daily` | **Recurring**: start **Wed 28 Oct 2026 at 00:00 UTC** (midnight UK time in winter; the game's Daily #1), lasts **1 day**, repeats every **1 day** | Daily Flight | Daily Flight | Integer | ` m` | High to Low | Best score |

Both are in **metres** flown, with the same names in English (U.K.) and English (U.S.).

**Achievements** (none hidden, none can be earned more than once, each with its 1024 × 1024 badge drawn by the app):

| Achievement ID | Title | Description before earning | Description after earning | Points |
|---|---|---|---|---|
| `swoop.ach.first` | First Flight | Finish your first flight. | Wings out, off you go. | 10 |
| `swoop.ach.km1` | Open Water | Fly 1 km in one flight. | One kilometre of open sea. | 15 |
| `swoop.ach.km5` | Long Haul | Fly 5 km in one flight. | Five kilometres, and the storm still behind you. | 25 |
| `swoop.ach.km10` | Ocean Crossing | Fly 10 km in one flight. | Ten kilometres. The gulls are impressed. | 75 |
| `swoop.ach.chain5` | Skipping Stone | Make 5 perfect landings in a row. | Five perfect landings, one after another. | 50 |
| `swoop.ach.chain10` | Glass Water | Make 10 perfect landings in a row. | Ten in a row. Barely a ripple. | 100 |
| `swoop.ach.tailwind` | Tailwind | Catch a Tailwind: 3 perfect landings in a row. | The wind is on your side. | 25 |
| `swoop.ach.lighthouse` | Keeper's Light | Fly past a lighthouse. | The beam swept over you. | 25 |
| `swoop.ach.lighthouse3` | Three Lights | Pass 3 lighthouses in one flight. | Three lighthouses, one flight. | 100 |
| `swoop.ach.cloud` | Head in the Clouds | Soar high enough to touch the clouds. | Up where the clouds are. | 50 |
| `swoop.ach.daily3` | Three Dawns | Play the Daily Flight three days in a row. | Three days, three seas. | 50 |
| `swoop.ach.allbirds` | Whole Flock | Unlock all eight birds. | Every bird in the flock is yours. | 100 |
| | | | **Total** | **625** (of 1,000 allowed) |

English (U.S.) uses "kilometer" instead of "kilometre" in the three distance descriptions; everything else is the same.

### Done earlier (kept for the record)

- **Repo public** (26 Oct): needed because this account's billing blocks GitHub Actions on private repos.
- **Bundle ID** `com.pravegm.swoop` with Game Center, and the **app record** (English (U.K.) primary, SKU `swoop-2026`).
- **The 4 GitHub secrets** (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `APPLE_TEAM_ID`): the same Apple key as Brim and Squish. Builds sign with Apple's cloud-managed distribution certificate, so no certificates are created.
- **TestFlight internal group** `Studio`, and builds 1.0 (2) to 1.0 (12).
- **Support** runs through GitHub issues (`github.com/pravegm/swoop/issues`), the same as Squish, so there's no support email to set up.
