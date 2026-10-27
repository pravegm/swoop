# Swoop: App Privacy answers and privacy policy (v1.0)

**Answer: Data Not Collected.** Based on the design (`design/GAME-DESIGN.md` §11: no accounts, no analytics) and the privacy manifest `Swoop/PrivacyInfo.xcprivacy` (no tracking, no tracking domains, no collected data types; required-reason APIs UserDefaults `CA92.1` and system boot time `35F9.1`). The grep in §3 was run on the release candidate on 27 Oct by QA-FINAL (commit `efdfdbf (CI run 40512902788, green)`) and passed; re-run it only if the code changes before submission.

The live policy page is `docs/site/privacy.html` (the text in §4 is the same; keep the two in step).

---

## 1. What to click (App Store Connect → the app → App Privacy)

1. **Privacy Policy URL:** `https://pravegm.github.io/swoop/privacy.html`. The page must load before you save.
2. Click **Get Started**. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
3. **Save**, then **Publish**. The product page shows **"Data Not Collected"**.

There's no tracking question once you choose "No". For the record, Swoop doesn't track: no advertising identifier, no `AppTrackingTransparency`, no data brokers.

## 2. Why these things don't change the answer

| Thing | Declare? | Why |
|---|---|---|
| **Hinge angle** | No | Read through the public `onHingeChange` API to steer the bird while the game is on screen. Only the calibrated resting angle is saved, on the device, with the settings (`SettingsStore.hingeOpenAngle`). Nothing leaves the phone. Apple: "collect" means transmitting data off the device |
| **Game Center** (sign-in, leaderboard scores, achievements) | No | Apple collects it under Apple's privacy policy. Apple: "You are not responsible for disclosing data collected by Apple." Swoop never sends it anywhere itself |
| **Daily Flight share** (result text) | No | Made on the phone and handed to the iOS share sheet only when the player taps Share. Where it goes is the player's choice; nothing comes to us |
| **Crash reports** via iOS "Share With App Developers" | No | Apple-collected and opt-in. We add no crash SDK. *If one is ever added, the label must declare Crash Data first* |
| **Rating prompt** (if added) | No | Apple's `requestReview` |
| **Support through GitHub issues** | No | Happens on GitHub, outside the app, under GitHub's privacy statement; covered by the policy |
| **Progress, levels, birds, bests, settings** | No | Stored only on the device (`ProgressStore`, `SettingsStore`, UserDefaults). Never transmitted |

**The limit to watch:** if a future version ever sends anything to our own server (Game Center IDs, analytics, online ghosts, a remote daily seed), this answer and the privacy manifest change **before** that build ships.

## 3. Evidence to collect on the release-candidate build (Claude runs this; paste the result here)

| Look for, in `Swoop/` | Expect | Result |
|---|---|---|
| Networking: `URLSession`, `URLRequest`, `NWConnection`, `import Network`, sockets | none | [x] none (GameKit is the only outbound path) |
| Web/links: `WKWebView`, `SFSafariViewController`, `openURL`, SwiftUI `Link(` | none, or only a link to the support/privacy page (opening Safari is not collection) | [x] none: no URLs in the app; the privacy text is in-app; sharing is plain text through `ShareLink`, only on tap |
| SDKs: Firebase, Crashlytics, Sentry, Mixpanel, Amplitude, AdSupport, `ASIdentifierManager` | none | [x] none |
| Tracking: `AppTrackingTransparency`, `ATTrackingManager` | none | [x] none |
| Cloud: `CloudKit`, `NSUbiquitousKeyValueStore` | none | [x] none |
| Notifications: `UNUserNotificationCenter` | none | [x] none |
| Hinge angle written to disk (`ProgressStore`, `SettingsStore`, files) | only the auto-calibrated resting angle, on the device with the settings (it never leaves the phone, so the answer is unchanged) | [x] resting angle persisted on device only (SettingsStore.hingeOpenAngle); answer unchanged |
| Packages in `project.yml` | none (true on 26 Oct) | [x] none |
| `NS*UsageDescription` keys in `project.yml` | none (true on 26 Oct) | [x] none |
| `Swoop/PrivacyInfo.xcprivacy` in the built app | present (`testflight.yml` `check_only` lints it) | [x] present: tracking false, no tracking domains, no collected data types; the upload job checks it in the archive |
| Required-reason APIs | UserDefaults `CA92.1`, system boot time `35F9.1` (declared). If the code uses file timestamps or disk space, add those reasons | [x] complete: no file-timestamp, disk-space, uptime or active-keyboard APIs outside the DEBUG-only demo code |

One-line grep: `URLSession|URLRequest|NWConnection|WKWebView|SFSafari|openURL|Link\(|ATTrackingManager|ASIdentifier|CloudKit|NSUbiquitous|Firebase|Sentry|UNUserNotification`

---

## 4. Privacy policy (public text)

*Last updated 27 October 2026. Live at `https://pravegm.github.io/swoop/privacy.html`.*

> # Swoop Privacy Policy
>
> **The short version: Swoop doesn't collect any data about you.** There are no accounts, no ads, no analytics and no tracking, and the app makes no network requests of its own. Your progress stays on your iPhone.
>
> ## What Swoop collects
> Nothing. Swoop has no sign-up and no login. It contains no advertising, analytics, crash-reporting or tracking code from anyone, and it doesn't ask for your camera, microphone, photos, contacts or location.
>
> ## The hinge on iPhone Duo
> On iPhone Duo, Swoop reads how far the phone is folded, only to steer the bird while you play. To fit the game to the way you hold it, Swoop remembers your comfortable resting angle on your iPhone, with your other settings. That reading never leaves your iPhone, and deleting Swoop deletes it.
>
> ## What stays on your device
> Your best flights, levels, lighthouses passed, unlocked birds, skies and trails, your bird side, Daily streak and settings are saved only on your iPhone. We can't see them. If you delete the app, they're deleted too.
>
> ## Sharing your Daily Flight
> When you tap Share, Swoop makes a short text result (your distance, Perfects and the last lighthouse you passed) and hands it to the iOS share sheet. Where it goes next is up to you. Nothing is sent to us.
>
> ## Game Center (optional)
> If you're signed in to Game Center, your scores and achievements are handled by Apple under Apple's Privacy Policy (apple.com/legal/privacy). We don't receive your Game Center profile.
>
> ## Crash reports
> If you've chosen in iOS Settings to share analytics with app developers, Apple may pass us anonymous crash reports. We use them only to fix bugs. You can turn this off at any time in Settings > Privacy & Security > Analytics & Improvements.
>
> ## Tracking
> Swoop doesn't track you across apps or websites, and it never asks for tracking permission.
>
> ## Children
> Swoop is rated 4+ and collects no personal information from anyone, including children.
>
> ## This website
> These pages have no cookies, analytics, trackers, embedded media, external fonts or scripts. They are hosted by GitHub Pages, which may keep standard server logs (such as IP addresses) for security, under GitHub's own privacy statement.
>
> ## If you contact us
> Support happens through GitHub issues (github.com/pravegm/swoop/issues). Issues are public, so please don't include personal details. GitHub handles your GitHub account under its own privacy statement. We use what you write only to reply and fix the problem, and we'll delete or hide an issue if you ask.
>
> ## Changes
> If this policy ever changes, we'll update this page and its date before the change reaches the app.
>
> ## Contact
> Swoop, an independent game by pravegm. Privacy questions: open an issue at github.com/pravegm/swoop/issues.

*(Founder to decide: if a legal or trading name, an email address or a postal address is ever required, for example for EU trader status, add it to the Contact section and the live page. It is deliberately left off.)*

## Sources
- Apple, *App privacy details on the App Store* ("collect" means transmitting off the device beyond real-time servicing; "You are not responsible for disclosing data collected by Apple"): https://developer.apple.com/app-store/app-privacy-details/
- Apple, *Privacy manifest files* and required-reason APIs: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Brim's reviewed answers (structure mirrored): `C:\Users\59527\Fold\docs\appstore\privacy.md`
