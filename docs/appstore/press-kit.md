# Swoop: Press kit

*Updated Tue 27 Oct 2026 for the Round 6–9 build (Flight School, the lighthouse route, the bird on the sharp half, the app's plain words from `design/UX-ROUND-9.md` §3–4). Everything here is **embargo-free**: anyone may write about Swoop from the day they receive it. The public version of the fact sheet is the Press section of `docs/site/index.html`; keep the two in step. The founder sends every email by hand; nothing is automated.*

**Links to fill in:** `[App Store link]` = `https://apps.apple.com/app/id<Apple ID>` (App Store Connect → App Information → Apple ID, which exists once the record is created in runbook §1; it works from launch morning). `[clip link]`, `[press folder]`, `[TestFlight link]`, `[promo code]`, `[expiry]`, `[your name]`.

---

## The pitch (one paragraph)

**Swoop turns the iPhone Duo into a pair of wings.** Hold the Duo open like a book, one hand on each half. Fold it a little and the bird folds its wings and dives down the face of an ocean wave, picking up speed; open it at the bottom and it flies off the top. One fold per wave: you never flap. Land on the way down of the next wave for a Perfect, get three in a row for a golden Tailwind, and stay ahead of the storm that chases you out to sea, faster the longer you fly. The goal is always the next lighthouse on a fixed route: Gull Point at 4 km, Saltlight at 9 km, Kestrel Head at 15 km, and on. A short Flight School on the first flight has a guide gull show each move before you try it. There's also a Daily Flight with the same waves for everyone, and goals that take you up 15 levels and unlock eight birds, five skies and coloured trails. It plays on every other iPhone too: press and hold going down, let go going up. £1.99 / $1.99, no ads, no in-app purchases, no data collected, rated 4+.

**One-liner:** *The two halves of your iPhone Duo are a bird's wings: fold going down a wave, open going up, and stay ahead of the storm.*

**Short (for listings, ≤ 140 chars):** *A flying game for iPhone Duo: hold it like a book, fold going down a wave, open going up. Stay ahead of the storm. £1.99.* (121)

---

## Fact sheet

| | |
|---|---|
| **Name** | Swoop (App Store: "Swoop: Tuck & Soar") |
| **Developer** | An independent studio (GitHub `pravegm`), also making Squish and Brim |
| **Founder** | [Founder name] (left off the live page unless the founder chooses) |
| **Release** | **Tue 24 Nov 2026**, worldwide (except China mainland) |
| **Platform** | iPhone. Designed for iPhone Duo held like a book (the hinge is the control); press and hold on every other iPhone. Requires iOS 18 or later; hinge play uses iOS 27.1, which the Duo ships with |
| **Price** | £1.99 / $1.99 / €1.99 one-off. No ads, no in-app purchases. Family Sharing on |
| **Age rating** | 4+ |
| **Modes** | Flight (endless, along a route of named lighthouses) · Daily Flight (same waves for everyone, one try that counts, shareable) · Goals (15 levels) · Flight School (the first-flight lesson, replayable) |
| **Features** | Hinge-angle folding with automatic calibration · the bird flies on the Duo half that stays sharp · momentum physics on endless ocean waves · perfect landings and Tailwinds · a storm that chases you · a fixed route of lighthouses and a Route page · 8 cosmetic birds, 5 skies and trails · Game Center top scores (Longest Flight, Daily Flight) and 12 achievements |
| **Sound** | Every sound synthesised live in the app; no recordings or licensed assets |
| **Accessibility** | Plays fully with press and hold, or with taps (one tap folds, the next opens), and on a Duo via "Play with touch" · Flight School steps are spoken with VoiceOver · follows Reduce Motion · Sound on/off, Haptics Off / Normal / Strong · Bird side setting |
| **Privacy** | Data Not Collected. No accounts, no tracking, no third-party SDKs |
| **Languages** | English |
| **Size** | ~[XX] MB (fill in from App Store Connect after processing) |
| **Links** | App Store: [App Store link] · Site: https://pravegm.github.io/swoop/ · Support: https://pravegm.github.io/swoop/support.html |
| **Press contact** | GitHub issues (https://github.com/pravegm/swoop/issues), the same channel as support. [Founder to decide: a press email, which would replace this on the page] |

---

## Key features (for writers who want bullets)

- **The phone's halves are the wings.** Fold the Duo a little and the bird folds its wings; open it and they spread. On Home the bird's wings span both screens and fold *with you*.
- **Analogue, not a switch.** How far you fold sets how heavy the bird is. The skill is rhythm: one fold on the way down, open on the way up, one per wave.
- **Taught by showing.** Flight School, on the first flight, is a calm practice sea with no storm and no score. A guide gull does each move first, then waits for you to copy it. On a Duo it also asks, with one tap, which half of the screen stayed clear.
- **It works around the Duo's blur.** iPhone Duo softens one half of the screen for a moment when a fold starts from flat. Swoop keeps the bird on the half that stays sharp (the right half by default, flying right to left), and Settings → Bird side changes it.
- **A goal you can see.** The next lighthouse is always on screen with the distance to go. Pass one and its beam sweeps, a bell rings and it lights up on your Route. Results lead with how far you got: "You made it past Saltlight".
- **A storm with a face.** Slate cloud and slanting rain behind you, clear gold sky ahead across the fold. Perfect landings push it back; lighthouses buy you a lead. When it catches up, it's "Flight over" and one more go.
- **One more go.** The Daily Flight has the same waves for everyone, one try that counts, and a streak.
- **Kind to the hinge.** Easy folds of about 30° from a relaxed book pose, roughly one per wave. It never asks you to close the phone, lay it flat or fold fast.

## Founder quote (placeholder; founder writes it)

> "[Founder to write in their own words. Suggested angle: the first time the bird folded its wings when you folded the phone; what changed after your own first test; why no ads.]"
> — [Founder name], Swoop

*Draft to edit or replace:* "When you hold the Duo open, it already looks like a pair of wings. The first time I folded it and the bird folded with me, I didn't want to put it down. Then the storm caught up a few hundred metres short of Saltlight, and I had to have another go."

---

## Assets

Put these in one public folder (a GitHub Release named `press-kit` on the public repo, as Squish does, or a shared iCloud Drive or Google Drive folder), and paste its link wherever `[press folder]` appears.

| File | Spec | Source |
|---|---|---|
| `swoop-icon-1024.png` | 1024 × 1024 | CI `screenshots` artifact → `AppIcon-1024.png` (`screen=icon`) |
| `swoop-duo-01…08.png` | 2853 × 2007, **no captions** | the `raw-duo` artifact of the final App Store screenshots run (`screenshots.md` §B) |
| `swoop-iphone-01…08.png` | 2868 × 1320, no captions | the 6.9" raw frames (`raw-69`) |
| `swoop-teaser-15s.mp4` | 1080 × 1920, with sound | the founder's real-hands clip (`social-launch.md` §3A) |
| `swoop-preview.mp4` | 1920 × 886, with sound | the App Preview, if made (`social-launch.md` §3B) |
| `swoop-wings-loop.gif` | ≤ 8 MB, 600 px wide | the Home bird folding its wings with the hinge, looped |
| `swoop-factsheet.pdf` | 1 page | this fact sheet (print the site's Press section to PDF) |

**Never include:** frames from before the 27 Oct caption update (old words), frames with seeded impossible states, any clip of the phone being closed fast, slammed or flapped.

**Promo codes:** App Store Connect → the app → Promo Codes, available once 1.0 is approved. Check the current per-version cap and expiry there (historically 100 per version, valid 28 days). Log every code in a sheet: who, when, outlet.

---

## Pitch emails

Plain text, under 150 words, clip link in the first two lines, never attach video, one outlet per email (never CC). Check every address on the outlet's own contact page first. The send dates are in `social-launch.md` §4.

### 1. Tip line (MacRumors, 9to5Mac, TechCrunch)

**Subject:** Tip: an iPhone Duo game where the two halves are a bird's wings (15s clip)

> Hi there,
>
> 15-second clip, sound on: [clip link]
>
> I'm launching Swoop on Tue 24 Nov. Hold the iPhone Duo open like a book and the two halves are a bird's wings: fold a little and it dives down an ocean wave, open and it flies off the top. A storm chases you out to sea; the goal is the next lighthouse on the route.
>
> - Endless flights, a Daily Flight with the same waves for everyone, Game Center top scores.
> - It keeps the bird on the half of the Duo's screen that doesn't blur when you fold.
> - Plays on every iPhone (press and hold); £1.99/$1.99, no ads, no IAP, no data collected, 4+.
>
> TestFlight, more clips or a promo code on request. No embargo.
>
> [your name], Swoop
> https://pravegm.github.io/swoop/

### 2. Duo directories (FoldHunt, DuoDiscover): listing request

**Subject:** Listing request: Swoop, a fold-to-dive flying game for iPhone Duo

> Hi,
>
> Could you add Swoop to your iPhone Duo games list? The hinge is the control in book pose: fold the halves a little on the way down a wave and the bird dives; open them on the way up and it flies.
>
> - Uses the hinge angle continuously (easy folds of about 30° from a relaxed, self-calibrating book pose), never needs closing or flat; the bird flies on the half that stays sharp when a fold starts from flat.
> - A first-flight lesson, a route of named lighthouses, Game Center and a Daily Flight.
> - £1.99/$1.99, no ads, no IAP. Out Tue 24 Nov.
> - Clip: [clip link] · Screenshots and icon: [press folder]
>
> I'll send the App Store link the day it's live.
>
> Thanks,
> [your name], Swoop

### 3. Games press (PocketGamer, TouchArcade)

**Subject:** Swoop: a premium momentum flyer built on the iPhone Duo's hinge

> Hi,
>
> Swoop is a £1.99/$1.99 one-input flying game with no ads, no IAP and no energy timers, where the iPhone Duo's two halves are the bird's wings: fold going down a wave, open going up.
>
> - Momentum physics on endless ocean waves; land on the way down for a Perfect, three in a row for a Tailwind.
> - A storm chasing you out to sea and a fixed route of named lighthouses to reach, plus a Daily Flight that's the same for everyone.
> - Goals that unlock eight birds, five skies and trails; Game Center; press and hold on any iPhone.
>
> Out Tue 24 Nov. Clip: [clip link] · TestFlight: [TestFlight link] · promo code on request after approval.
>
> [your name], Swoop

*TouchArcade: also start a thread in its forums' upcoming-games section, saying you're the developer.*

### 4. Writers who covered Duo games (Digital Trends' Vikhyaat Vivek; Chonky Corgo blog; Fix Gaming Channel)

**Subject:** For your Duo games list: the hinge as a pair of wings

> Hi [name],
>
> I read your piece on [their article]. I liked [one specific thing they said]. Swoop is a game where the hinge is the whole control: hold the Duo like a book, fold it a little and the bird dives down a wave, open it and the bird flies. It's analogue (the angle sets how heavy the bird is), so it's a rhythm game rather than a fold-to-flap toy, and it keeps the bird on the half of the screen that stays sharp when you fold.
>
> 15 s clip: [clip link] · TestFlight: [TestFlight link]
>
> £1.99/$1.99, no ads, out Tue 24 Nov. It's from the studio behind Brim (17 Nov). Happy to explain how the angle maps to the fold.
>
> [your name], Swoop

### 5. Duo creators (TikTok, YouTube Shorts), after approval

**Subject:** A free code for Swoop: your Duo's halves become wings

> Hey,
>
> I make Swoop: hold your Duo open like a book, fold it a little and the bird dives, open it and the bird flies. It reads well on camera from just behind your shoulder, so you see the hands, the fold and the screen together.
>
> Here's a free code: [promo code] (redeem by [expiry]). No script, no obligation. If you post, a "gifted" tag keeps you right with the platform rules, and caption-free clips are here: [press folder].
>
> Thanks either way!
> [your name], Swoop

### 6. Launch-day note (reply in each earlier thread)

> Swoop is out today: [App Store link]. The iPhone Duo's two halves are the wings; on other iPhones you press and hold. £1.99/$1.99, no ads, no IAP, no data collected. Everything in [press folder] is free to use. Promo code on request.
>
> [your name]

Then stop. One more email only if a free update with real new content ships.

## Sources
- `research/01-market.md` (Duo directories, Valley Run and the "Fold to Fly" clash, hinge-wear press angle)
- `design/ROUND-6.md`, `design/ROUND-9.md`, `design/UX-ROUND-9.md` (what the game is now, and its words)
- Brim's press kit (structure and outlet list mirrored): `C:\Users\59527\Fold\docs\appstore\press-kit.md`
