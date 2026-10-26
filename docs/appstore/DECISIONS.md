# Swoop 1.0: launch decisions

*Made Mon 26 Oct 2026 by the launch lead, unsupervised, mirroring Brim's launch kit (`C:\Users\59527\Fold\docs\appstore\`), which itself mirrored Squish's reviewed one. Each line is the decision and the reason that settled it. The clicks are in `docs/LAUNCH-RUNBOOK.md`. Left to the founder: Apple and GitHub logins, the review contact details (typed into App Store Connect only), and the five sanity checks in §3.*

## 1. The decisions

| # | Topic | Decision | Reason |
|---|---|---|---|
| 1 | **App name** | `Swoop: Tuck & Soar` (18/30) | The design's name. Bare "Swoop" is crowded; "Fold to Fly" is Valley Run's tagline; "Tuck & Soar" teaches both inputs (`research/01-market.md` §2) |
| 2 | **Fallback names** | `Swoop: Fold to Soar` → `Foldwing: Tuck & Soar` → `Swoop: Tuck and Soar` | Research's second choice, then its unique fallback name; the home-screen name stays "Swoop" |
| 3 | **Subtitle** | `Fold your phone. Fly.` (21/30), both locales | Duo-first in four words, indexes fold/phone/fly, and it isn't "Fold to Fly". The risk: it sits close to Valley Run's tagline in spirit. Alternative ready: `Fold to dive. Beat the storm.` (29) |
| 4 | **Promotional text** | Duo first, then "hold to tuck" on other iPhones, then no ads/IAP (154/170) | If the Duo screenshot slot is missing, this, frame 1 and the description carry the Duo pitch; editable any time |
| 5 | **Description** | Opens "The two halves of your iPhone Duo are a bird's wings.", then the hold, then "plays on every iPhone"; 2,834/4,000; en-US differs in 2 spellings | The brief's order (Duo-first, honest about touch); every claim from the bible, with a check table (`metadata.md` §10) because the build didn't exist yet |
| 6 | **Keywords** | `bird,glide,wings,dive,ocean,wave,sea,surf,storm,gull,flying,hinge,foldable,endless,momentum,sky,skim` (100/100 bytes) | No repeats of name/subtitle words, no competitor or Apple marks, singulars only |
| 7 | **Categories** | Games → **Casual** + **Arcade**; secondary **Entertainment** | The brief's Casual + Arcade; Entertainment as for Brim (novelty browsers). Optional, harmless |
| 8 | **Age rating** | **4+**: every content item None, every capability No, not Made for Kids | A bird over the sea; the storm is weather; nothing is harmed, random or bought |
| 9 | **Price** | Base **UK £1.99**, Apple equalises the rest ($1.99). No launch discount | The brief's price; impulse-buy level, same as Brim |
| 10 | **Territories** | All **except China mainland** | Paid games there need an ISBN licence we don't have; account-level EU trader status is already handled for Squish |
| 11 | **Pre-order** | **No** | A pre-order needs an approved final build weeks ahead; the real-Duo feel tuning is the biggest quality lever left |
| 12 | **Release type** | **Manual release**, pressed by the founder on Tue 24 Nov at about 08:00 UK | The brief's choice, and Brim's critic's rule: the real-Duo TestFlight session decides the day. Manual also lets the founder hold the release if a late Duo problem shows up |
| 13 | **Launch date** | **Tue 24 Nov 2026**; submit Wed 18 Nov (hard cut Fri 20 Nov) | Brim launches Tue 17 Nov; one launch per week gives each its own news and featuring slot. Squish had planned 24 Nov but was submitted on 26 Oct to go live on approval, so the day is free. 29 days out: room for 3 weeks' featuring notice and two tuning rounds. Trade-off: it's US Thanksgiving week (Thu 26 Nov) — quieter US press, but heavy holiday downloads and new-phone owners; Squish's own research picked this same week |
| 14 | **Duo screenshots** | Upload the Duo set (D1–D8, 2853 × 2007, from `store.yml`) **if** App Store Connect shows the iPhone Duo slot (Apple lists it; required from Apr 2027); otherwise ship 1.0 with the 6.9" and 6.3" sets and add the Duo set in 1.0.1 | Apple's spec page lists a Duo inner slot, but forum 845505 reported no Duo device in App Store Connect in Oct 2026; screenshots lock at approval |
| 15 | **Frame 1** | A CI **book-pose composite** (`ci/store-frame.swift --book`): the real Duo capture split at the fold and warped onto a stylised Duo held open like a book (~140°), the bird's wings across the fold; used as frame 1 of **every** set, including the iPhone sets | Landscape sets show only frame 1 in search, and if there's no Duo slot the 6.9" set is all anyone sees; the store shot shows a real Duo pose with an unaltered capture, never a non-folding iPhone folded |
| 16 | **Screenshot sets** | 8 Duo (2853 × 2007) + 8 at 6.9" (2868 × 1320) + 8 at 6.3" (2622 × 1206, the only required iPhone size; Apple scales it for 6.5"/6.1"), all landscape; frames from `ci/store-scenarios.txt` and `ci/duo-store-scenarios.txt` via `store.yml` | The game is landscape-only in play; CI is the only truthful source of frames |
| 17 | **App Preview** | Optional; ships in 1.0 only if recorded and checked by code freeze (Mon 16 Nov) | Previews lock with the version; Swoop has no preview recorder yet |
| 18 | **Leaderboards** | `swoop.longest` Classic and `swoop.daily` Recurring daily (from 1 Nov 2026 00:00 UTC), both **distance in whole metres**, suffix " m" | The brief says "in metres"; the bible says distance is the headline; the style bonus stays in-game. Starting 1 Nov lets TestFlight testers see the board |
| 19 | **Daily Flight day boundary** | Recommend **00:00 UTC** for everyone (engineering change from the contract's local calendar) | Game Center's recurring board resets at one UTC moment; Brim made the same change |
| 20 | **Achievements** | 12 (`swoop.ach.*`), **625 points**, 375 held back; none hidden; none repeatable; none rewards fold speed or count | The brief's list; room for future content under the 1,000 cap; App Review 2.4.2 |
| 21 | **App Privacy** | **Data Not Collected** (confirm with the grep in `privacy.md` §3 on the release build) | No network, SDKs or accounts by design; the hinge angle never leaves the phone; Game Center data is Apple's to disclose |
| 22 | **Accessibility labels** | Claim **Reduced Motion**, **Sufficient Contrast**, **Differentiate Without Color Alone**, each only if its check passes; not VoiceOver, Voice Control, Larger Text; Dark Interface only if check D passes | Flying needs sight of the waves; HUD isn't built for 200% text; the play sky is bright gold. Labels go live on launch day |
| 23 | **Content Rights** | **No** third-party content | All art drawn in code, all sound synthesised, system fonts only |
| 24 | **Review notes** | Lead with "testing without a Duo", then the hinge (read only for gameplay, never stored or sent), then the wear answer (2.4.2/1.4.5); 3,708 bytes, ASCII | Reviewers may not have a Duo; hinge wear is the likeliest objection (Foldy Bird's "break your foldable" coverage) |
| 25 | **Fallback date** | **Tue 8 Dec** if 1.0 isn't submitted by Fri 20 Nov; never 1 Dec (Brim's fallback) or 17 Nov | Keeps the one-launch-per-week rule across the studio |
| 26 | **Featuring** | App Launch nomination, publish date 24 Nov, **submitted by Tue 3 Nov** (sooner is better); "Optimized for iPhone Duo" in Helpful Details | Apple asks for 3 weeks' notice and asks Duo apps to use that phrase |
| 27 | **Localisation** | en-GB primary, en-US added; English only | The founder is UK-based; US spelling is the only difference that matters for 1.0 |
| 28 | **Repo visibility** | **Public** (runbook §0a); GitHub reported it public at about 11:00 UTC on 26 Oct | Private-repo Actions are blocked by GitHub billing on this account, which stops every build; Brim and Squish are public; it also allows free Pages and public issues |
| 29 | **Website hosting** | GitHub Pages from `main` / `/docs` (`docs/.nojekyll` in place). Real pages in `docs/site/`; `docs/index.html`, `docs/support.html` and `docs/privacy.html` forward to them | Mirrors Brim's `docs/site/` layout (so the kit stays the same shape) while giving the short addresses `https://pravegm.github.io/swoop/`, `/support.html`, `/privacy.html`. The forwards are plain HTML (meta refresh plus a visible link), no scripts. Direct `/site/` addresses are the fallback |
| 30 | **Support contact** | **GitHub issues** (https://github.com/pravegm/swoop/issues), linked from the support and privacy pages; no email | The founder's choice for Squish; possible because the repo is public. The catch: filing needs a free GitHub account and issues are public, which both pages say |
| 31 | **Copyright** | `© 2026 pravegm` | No personal name invented; the GitHub handle is the studio's public name. The founder can change it to a legal name any time before submission |
| 32 | **Build and upload** | GitHub Actions → TestFlight with the **same App Store Connect API key** as Brim and Squish; signing with Apple's **cloud-managed distribution certificate** | Brim's fix for the "maximum number of certificates" failure: no development certificates are created on CI; the founder's Intel Mac can't run Xcode 27 |
| 33 | **Family Sharing** | **On** | Standard for a one-off paid game; costs nothing |
| 34 | **What's New** | None for 1.0 (App Store Connect has no field); the 1.0 line goes into TestFlight's "What to Test" | Apple's rule |
| 35 | **Social and press timing** | Swoop posts and emails on days between Brim's; nothing for Swoop on 17 Nov | Two launches from one founder must never compete on the same day |
| 36 | **No Tiny Wings echoes in copy** | No "tiny", "island", "fever", "sunset"/"nightfall" wording; the clock is "the storm" | `research/01-market.md` §3 clone and IP notes |

## 2. Requests to engineering (not mine to edit; must land before the release build)

| # | Priority | Owner | Request |
|---|---|---|---|
| 1 | **High** | Core (contract owner) | **Daily Flight on the UTC date** (`DailySeed.dayNumber(for:calendar: .current)` today), to match the recurring leaderboard (#19). Brim's version: `Brim/Core/LevelCatalog.swift`. If kept local, tell the launch lead so the support page and achievements note change |
| 2 | **High** | App | **Game Center IDs exactly as `achievements.md`**: `swoop.longest`, `swoop.daily`, the twelve `swoop.ach.*`. Leaderboards submit **distance in whole metres** |
| 3 | **High** | App + CI | **Achievement images**: twelve 1024 × 1024 PNGs, no alpha, via `screen=badges` into the `screenshots` artifact (`achievements.md` "Images"). App Store Connect won't save an achievement without one |
| 4 | **High** | Scene/App + CI | **Book-pose store shot** for frame 1 (port Squish's `FoldStoreShot` for book pose): demo key `storeshot=book` (plus `storeshotsize=phone` for the iPhone slots), logging `SWOOP-T storeshot done` |
| 5 | **High** | CI | **Store pipeline**: `store.yml`, `ci/store-scenarios.txt` (lines in `screenshots.md`), `ci/store-set.sh` and `ci/store-frame.swift` ported from Brim, for **landscape** slot sizes (2853 × 2007, 2868 × 1320, 2556 × 1179 / 2622 × 1206), with a MANIFEST and `_flagged/` |
| 6 | Medium | App/Scene | **Words on screen** for PERFECT (with the chain) and SPLASH, a Tailwind label, and lock glyphs on birds and skies (accessibility check A) |
| 7 | Medium | Scene | **HUD text outline or backing plate** so it passes 4.5:1 on every sky (check B) |
| 8 | Medium | App | **Exact labels** the store copy and review notes quote: "Fly", "Play with touch", "Respect silent switch", "Open your wings to keep flying", "Open your wings" (cover). If any label changes, tell the launch lead |
| 9 | Low | App | Achievement banners queued until the result card; never mid-flight |
| 10 | Low | CI | **App Preview recorder** (Squish's `preview.yml` approach), only if the preview is wanted for 1.0 |
| 11 | Low | Founder (`.github/`) | A GitHub issue template `support.yml` (device, iOS version, mode, what happened), as Squish has; the support page then links to `issues/new?template=support.yml` |
| 12 | Low | Design | Consider numbering the Daily from launch day (Daily #1 on 24 Nov) rather than days since 1 Jan 2026 (#327 on launch day) |

## 3. Five decisions for the founder to sanity-check

1. **Launch Tue 24 Nov** (a week after Brim), manual release at 08:00 UK, nomination **by Tue 3 Nov**, fallback Tue 8 Dec.
2. **Support through GitHub issues** (as for Squish) and copyright `© 2026 pravegm`. Say if you'd rather have a support email or your legal name.
3. **Daily Flight resets at 00:00 UTC** for everyone (midnight UK in winter, 4 pm California), to match Game Center's daily board.
4. **Store words:** subtitle `Fold your phone. Fly.` (or the alternative `Fold to dive. Beat the storm.`), Casual + Arcade.
5. **Frame 1 is a rendered Duo** held like a book (no hands) in every set, with a real-hands photo planned for 1.0.1.

## Sources
- Brim's decisions and kit (structure, Apple limits, sources): `C:\Users\59527\Fold\docs\appstore\DECISIONS.md`
- Squish's decisions (store-shot frame 1, support via issues, release on approval): `C:\Users\59527\Squish\docs\appstore\DECISIONS.md`, `C:\Users\59527\Squish\docs\marketing\PLAN.md`
- `research/01-market.md`, `design/GAME-DESIGN.md`, `design/ARCHITECTURE.md`, `design/ROUND-1.md`, `CLAUDE.md`
