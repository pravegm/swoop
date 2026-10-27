# Swoop: Social launch, video storyboards and outreach

*For the founder to post by hand from their own accounts. Tone: warm, airy, a little proud of the bird ("one more go"). Never suggest closing the phone fast, flapping it, slamming it or "breaking your hinge". Never compare with or name Tiny Wings, Alto or Valley Run.*

**Links to fill in:** `[App Store link]` = `https://apps.apple.com/app/id<Apple ID>` (App Store Connect → App Information → Apple ID; exists once the record is created, live on launch day). `[site]` = `https://pravegm.github.io/swoop/`. `[clip]` = the 15 s teaser (§3A).

---

## 1. Schedule (fits around Brim, so the two launches never share a day)

Brim posts on Fri 6, Tue 10, Thu 12, Sat 14, Mon 16 Nov, launches **Tue 17 Nov**, then posts Daily rows on Wed 18, Fri 20 and Sun 22 Nov (`C:\Users\59527\Fold\docs\appstore\social-launch.md` §1). Swoop posts go on the days in between. Squish goes live on approval in late October and runs its own calendar from that day (`C:\Users\59527\Squish\docs\marketing\PLAN.md`); if a Squish post lands on a Swoop day, move the Swoop post by one day, never the launch.

| Date | What | Where |
|---|---|---|
| Wed 11 Nov | Teaser (only once the Duo feel check in runbook §3 is a "yes") | X, Bluesky, Mastodon, Threads; r/iPhoneDuo if the rules allow |
| Fri 13 Nov | Clip: the storm close behind, perfect landings pushing it back | X, Bluesky, Mastodon, Threads |
| Sun 15 Nov | Clip: Flight School, the guide gull showing the move and the player copying it | same |
| Tue 17 Nov | **Nothing for Swoop** (Brim launch day) | — |
| Thu 19 Nov | Clip: "Gull Point!", the beam and the bell, then the Route lighting up | same |
| Sat 21 Nov | Clip: three in a row, the Tailwind | same |
| Mon 23 Nov | "Out tomorrow" with the site link (there's no pre-order, so the App Store link only works from launch morning) | same |
| **Tue 24 Nov** | **Launch posts** (§2), after you press Release (runbook §7) and the page shows **Get** with the price, then your first Daily Flight result | all, plus r/iPhoneDuo if the rules allow |
| Wed 25, Fri 27, Sun 29 Nov | Your own Daily Flight result ("beat this") | X, Bluesky, Mastodon |
| From Tue 1 Dec | A Daily Flight result a few times a week, on days Brim doesn't post, if it's fun; stop if it isn't | — |

## 2. Launch-day posts (Tue 24 Nov)

Counted with Node, with the link as 23 characters on X and Mastodon and as 40 on Bluesky and Threads: X 228 / 280, Bluesky 268 / 300, Mastodon 493 / 500, Threads 171 / 500. Recount with the real link. Paste the text inside the quote blocks exactly, and always add the alt text. The words follow the app's glossary (`design/UX-ROUND-9.md` §3): fold / open, hold / let go, "stay ahead of the storm", "the next lighthouse".

### X (attach the 15 s clip)
> Swoop is out.
>
> Hold your iPhone Duo like a book. The two halves are a bird's wings: fold going down a wave, open going up. Stay ahead of the storm.
>
> £1.99 / $1.99 · no ads · no IAP · plays on every iPhone
> [App Store link]

*Alt text:* Two hands hold an iPhone Duo open like a book. On its screens a white seabird flies over golden ocean waves on the right half, a dark storm cloud close behind it, and clear sky ahead on the left half. The hands fold the phone in slightly and the bird folds its wings and dives down a wave; they open it and the bird flies off the top, and the word PERFECT appears with a white ring on the water.

### Bluesky (attach the clip)
> Swoop is out: your iPhone Duo's two halves are a bird's wings.
>
> Fold a little and it dives down a wave. Open at the bottom and it flies off the top. Land on the way down for a Perfect. Stay ahead of the storm.
>
> No ads, no IAP.
>
> [App Store link]

### Mastodon (attach the clip)
> Swoop is out. 🌅
>
> On iPhone Duo the hinge is the control: hold the phone open like a book, fold it a little and the bird dives down an ocean wave; open it and it flies off the top. The bird flies on the half of the screen that stays sharp when you fold.
>
> A storm chases you out to sea, the next lighthouse on the route is the goal, and there's a Daily Flight. Press and hold on any other iPhone.
>
> £1.99 / $1.99, no ads, no IAP, no tracking.
>
> [App Store link]
> #iPhoneDuo #iOSDev #IndieDev

### Threads (attach the clip)
> Made a game where your iPhone Duo is a pair of wings. Fold going down, open going up, stay ahead of the storm. Swoop is out today: [App Store link]

### r/iPhoneDuo (only if the rules allow a launch post; otherwise the megathread)
**Title:** [Dev] I made the Duo's two halves into a bird's wings: Swoop is out
> Developer here, so this is self-promo. Swoop is a momentum flyer for book pose: fold the halves in a little and the bird dives down a wave, open them and it flies off the top. The hinge angle sets how folded the wings are continuously (it's not an open/closed switch), the open position calibrates to however you naturally hold it, and it never asks you to close the phone, lay it flat or fold fast. Folds are about 30°, one per wave.
>
> The bird flies on the half of the screen that stays sharp (the Duo blurs one half for a moment when a fold starts from flat); Settings → Bird side if yours is the other one.
>
> £1.99/$1.99, no ads, no IAP, no data collected. There's a Daily Flight with the same waves for everyone, so post your result here if you like.
>
> Happy to answer anything about the hinge mapping. Link in the comments, per the rules.

### Daily Flight post format (any day)
> [the exact text the app's Share button produces]
> [App Store link]

The result line is whatever Share produces (`UI/ShareText.swift`, for example `Swoop Daily #3 7.4 km 🕊️ 23 perfect landings · past Gull Point 🌅 🔥3`; #1 is launch day, 24 Nov); never type one by hand.

### Teaser (Wed 11 Nov)
> I made a game where the two halves of your iPhone Duo are a bird's wings.
>
> Fold a little: it dives. Open: it flies.
>
> Swoop, out 24 Nov. [site]

---

## 3. Video storyboards

### 3A. Social teaser: "These are your wings" (15 s, vertical 1080 × 1920, 30 fps, sound on)

**Shot:** the founder's real iPhone Duo held open like a book in two hands, filmed **from just behind and above the left shoulder** (the bird flies on the right half by default, so this keeps it nearest the camera), so the hands, the fold and both screens are all in frame. Hold it in a relaxed book, never flat, so the iOS blur never shows. Soft daylight, plain background. Phone sound **on** (clip mic near the speaker). Real hands are fine here (not an App Store asset).

| Time | Picture | On-screen text (big, top third, clear of the phone) | Sound |
|---|---|---|---|
| 0.0–1.5 | Cold open: Home, the big bird's wings spanning both halves. The hands fold the phone in a little and the bird's wings fold **with them**, then open | **These are your wings.** | wind, soft |
| 1.5–4.0 | The countdown, the drop. A gentle fold down the first wave, the wind rising | **Fold going down.** | wind rising in pitch |
| 4.0–6.5 | Open at the bottom: off the top of the wave, spray burst, the camera pulls out | **Open going up.** | a "whump", then quiet wind |
| 6.5–9.0 | Land on the way down: white ring, PERFECT, chime; twice more, chimes climbing, then the golden Tailwind trail | **Perfect. Perfect. Tailwind!** | three rising chimes, a chord swell |
| 9.0–12.0 | Cut wider: the storm wall behind (right half), rain, the meter low; a Perfect pushes it back; the NEXT chip counts down to Gull Point | **Stay ahead of the storm.** | low rumble under the wind |
| 12.0–15.0 | "Gull Point!" and the beam; end card over Home: "Swoop" wordmark, "Tuck & Soar", "Out 24 Nov" (launch day: "Out now") | **Swoop · out 24 Nov** | the lighthouse bell |

Rules: no price in the video (it goes in the post text), no fast or repeated folding, never closed or slammed, folds small and at the pace of the waves. Export H.264, ≤ 60 MB (fits X, Bluesky, Mastodon, Threads, TikTok).

### 3B. App Preview: "Fold going down" (optional for 1.0; 25 s, landscape 1920 × 886, 30 fps)

Apple's rules: 15–30 s; captures of the app only (**no hands, no people, no device frame**); no prices; autoplays muted, so every beat has a caption on screen ≥ 1.5 s; poster frame chosen by us. The Duo's book canvas (aspect 1.42) doesn't fill 1920 × 886 (2.17), so scale the inner screen to 886 px tall (about 1,260 px wide), centre it, and put captions in the dusk bands left and right. Never crop into the game. The Duo capture is mirrored (bird on the right half), as the player sees it.

**Ships in 1.0 only if** it's recorded and checked by code freeze (Mon 16 Nov). Previews lock with the version, so a late one waits for 1.0.1. It needs a screen-recording step in CI (Squish has `preview.yml`; Swoop doesn't yet: `DECISIONS.md` §2).

| Time | Picture (app capture, Duo inner display, book pose) | Caption |
|---|---|---|
| 00.0–03.0 | Cold open: the Home bird folding its wings with the hinge. **Poster frame 00:01.5** | **The halves are your *wings*** |
| 03.0–07.0 | Flight School: the guide gull shows the fold down the wave, then the player's bird copies it | **A guide gull shows you *how*** |
| 07.0–10.0 | A real flight: fold going down, open going up, a long glide | **Fold going down. *Open* going up.** |
| 10.0–14.0 | Three perfect landings, the Tailwind | **Land on the way down: *Perfect*** |
| 14.0–18.0 | The storm close behind, pushed back | **Stay ahead of the *storm*** |
| 18.0–21.0 | "Gull Point!": beam, bell; the NEXT chip switches to Saltlight | **Reach the next *lighthouse*** |
| 21.0–25.0 | "Flight over"; the result card with the route strip | **One more *flight*?** |

**6.9" version:** the same beats captured on the iPhone 18 Pro Max (touch control, bird on the left), full-bleed 1920 × 886; change the third caption to **Hold going down. *Let go* going up.**

---

## 4. Outreach list (from `research/01-market.md` and Brim's list)

Send dates follow §1 and keep clear of Brim's sends (Brim emails on Fri 6, Sun 8, Tue 10 and Thu 12 Nov). Email texts are in `press-kit.md` (numbers below). **Verify every address on the outlet's own site before sending.**

| When | Outlet | Why them | Email |
|---|---|---|---|
| Wed 11 Nov | **FoldHunt** (foldhunt.com/iphone-duo) | The main Duo directory; it lists no glide, bird-flight or surf game | #2 |
| Wed 11 Nov | **DuoDiscover** (duodiscover.com) | Hand-reviewed Duo directory; its only flying game has no hinge control | #2 |
| Wed 18 Nov | **MacRumors**, **9to5Mac**, **TechCrunch** (tips) | Duo app roundups and developer stories; the "third Duo game from one studio" angle, the day after Brim's launch | #1 |
| Thu 19 Nov | **PocketGamer**, **TouchArcade** | Premium iOS games; momentum-flyer fans | #3 |
| Fri 20 Nov | **Digital Trends** (Vikhyaat Vivek), **Chonky Corgo blog**, **Fix Gaming Channel** | Covered Duo games and hinge input. Brim emails them on Thu 12 Nov, so Swoop goes a week later and mentions Brim in one line | #4 |
| Fri 20 Nov | **TechRadar**, **MacStories**, **PhoneArena**, **Stuff** | Duo reviews and app roundups | #1 |
| Sat 21 – Mon 23 Nov | 15–25 **Duo creators** (TikTok, YouTube Shorts) who already own a Duo and post "apps for your Duo" videos | Hands folding a phone and a bird folding with it is very watchable | #5 (needs promo codes, so after approval) |
| Tue 24 Nov | Everyone above who was emailed | Launch note, in the same thread | #6 |
| Tue 24 Nov | **r/iPhoneDuo**, **r/iPhoneduoapp** | Owners hunting for hinge apps; post only within the subs' rules, say you're the developer, reply to every comment for 2 hours | §2 |

## 5. Don'ts

- No "break your hinge", "fold as fast as you can" or wear jokes. No fast or repeated folding on camera, and never closing the phone shut as part of play.
- No competitor names (Tiny Wings, Alto, Valley Run, Flappy Bird), not even as "like X but".
- No "share to unlock", follow-for-codes giveaways or bought engagement.
- "iPhone Duo" only in referential use ("for iPhone Duo"), never as part of our product's name; no Apple logos.
- No price inside videos (keep it in the post text).
