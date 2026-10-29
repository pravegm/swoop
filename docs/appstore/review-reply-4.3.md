# Reply to App Review: Guidelines 4.3 and 4.2.6 (29 Oct 2026)

Apple's instruction: if the app already meets 4.3(a), 4.3(b) and 4.2.6, **don't resubmit**; reply and answer all nine
questions in full.

## What the research says (29 Oct)

1. **New-app 4.3 rejections in Oct 2026 look account- and volume-driven, not clone detection.**
   - One developer had 11 apps (built with AI agents, shared codebase) submitted in 15.5 h. All were rejected within
     30 s on the same day, and again a week later after resubmitting.
   - Others report the same: whole batches rejected "in the same minute", while updates to live apps still pass.
   - Their advice: **no more than one or two new apps per account per week**.
2. **Resubmitting without a change, or without waiting for Apple's answer, gets the same rejection.** On the forums
   this has escalated to an **account warning** ("removal for repeated noncompliance").
3. **Replies that work are specific and checkable:**
   - one sentence on what is different;
   - concrete features and where to find them;
   - a 30–60 s video going straight to the distinctive feature;
   - a specific question asking which app(s) Swoop is considered similar to;
   - and, where the account has similar apps, what you're doing about them.
4. **An App Review appointment** (developer account → Meet with Apple → App Review) is the only channel where a human
   is sure to look. Outcomes are mixed, but several 4.3 cases were cleared on a call.
5. **App Review Board appeals:** one per rejection, often unanswered for weeks. Use one only after the reply.

**Checked for Swoop:**
- The store text shares only boilerplate lines with your other apps ("No in-app purchases.", review-note section
  headings).
- About 10% of the app code is the shared in-house foundation (`scratchpad/overlap.js`, 29 Oct).
- The likely trigger is the account's pace: six Duo hinge games from one account within about four days.

## What to send

Attach a **30–60 s phone video** of you playing Swoop on the Duo: hands on both halves, a few folds down the waves, a
"Perfect". Record it with another phone, or use the Duo's screen recording with the microphone on. It's the strongest
evidence there is that the hinge is the game.

Check two lines before sending:
- Answer 4 describes your own testing.
- The last line says no new apps will be submitted until this is resolved. Keep it only if you agree to that pause
  (recommended).

```
Hello, and thank you for the questions. In one sentence: Swoop is an original game in which the iPhone Duo's two halves are a bird's wings, and the angle of the fold steers the flight continuously. Answers below.

1. WHAT IT DOES
Hold the Duo open like a book. Folding the halves in a little tucks the wings and the bird dives down the face of an ocean wave; opening them spreads the wings and it flies off the crest. One fold per wave, timed to land on the way down the next wave ("Perfect"), builds speed to stay ahead of a storm and reach named lighthouses along a fixed route. It gives Duo owners a game controlled by the hinge itself rather than by touch. Other iPhones play the same game by press-and-hold.

2. INTENDED USER
iPhone Duo owners who want a short, tactile game in 2-5 minute sessions, from casual players to score chasers (Daily Flight, Game Center). Rated 4+; a 60-second lesson teaches it.

3. THE GAP
Flying and momentum games are touch games; we found none that maps a foldable's hinge angle to a continuous control. Swoop is built around the hinge: the angle is filtered and calibrated to each player's resting pose, a full dive needs only about 30 degrees, play pauses if the phone is nearly closed, and the bird stays on the half of the screen iOS does not blur when a fold starts. To see it: Fly > Skip gives a real flight in under a minute.

4. BETA TESTING
TestFlight builds 1.0 (2) to (12) were played on a real iPhone Duo. Feedback applied:
- "Do I tap repeatedly or hold?" -> added Flight School, a guided first-launch lesson.
- "The bird's half of the screen blurs when folding" -> the bird now flies on the half that stays sharp.
- "What is the storm, where am I going?" -> a route of named lighthouses, a storm meter, clearer results.
- "Folding halfway paused the game" -> the pause moved from 90 to 55 degrees.

5. STANDALONE OR SUITE
Standalone. My account publishes a few separate iPhone Duo games; each is a different genre in a different pose, with its own rules, art and sound: Squish (close the phone to squash objects), Brim (lift the top half to pour), Hush (open a chest slowly without waking a mimic), Snapjaw (the halves are jaws that catch flies), Glint (the top half is a mirror aimed at shadows). Swoop is the only flying game, the only one in book pose, and the only one with continuous control, a storm chase and a route. They share no levels, characters, art or rules.

6. IN-APP PURCHASE OR ADDITION TO ANOTHER APP?
No. Swoop's wave physics, flight model, storm, route, Daily Flight, lesson, 8 birds, 5 skies, 12 achievements and 2 leaderboards are its own. Merging it with games played in other poses would make one app of unrelated games with conflicting controls.

7. SHARED CODE OR ASSETS
Yes, a small in-house foundation I reuse: the audio synthesizer (all sound is generated in code), haptics, the hinge reader and smoothing filter, a Game Center wrapper, orientation and settings plumbing - about 10% of Swoop's code. The game itself (simulation, rendering, all art drawn in code, lesson, route, goals, every screen) is written for Swoop. No images, sounds or content are shared.

8. THIRD-PARTY CODE
No. Only Apple frameworks (SwiftUI, SpriteKit, GameKit, AVFoundation, Core Haptics).

9. CLIENT OR APP GENERATION SERVICE
No client, partner, template or app generation service. I own the concept, design and content and submit under my own account. I built it with AI-assisted coding tools under my direction; the code is original to this app.

A short video of Swoop played on an iPhone Duo is attached. Could you tell me which app(s) Swoop was found similar to? I will not submit any new apps from this account until this is resolved. Thank you.
```

## After sending

- **Don't resubmit Swoop.** Wait for Apple's answer in this thread.
- **Book an App Review appointment** (developer account → Meet with Apple → App Review) for the next slot. Bring the
  video and the answers above.
- **Appeal to the App Review Board** only if the reply is turned down. One appeal, quoting these answers.

## Sources
- [Apple's 4.3 spam check is a 30-second batch job. 22 rejections prove it (DEV, Oct 2026)](https://dev.to/mattbusel/apples-43-spam-check-is-a-30-second-batch-job-22-rejections-prove-it-3nab)
- [Guideline 4.3(a): whether to respond, appeal or rebuild (DEV)](https://dev.to/tychelabs/guideline-43a-design-spam-whether-to-respond-appeal-or-rebuild-44gn)
- [Apple 4.3 spam rejection for AI-built apps (Convertix)](https://convertixdigital.com/en/blog/apple-guideline-4-3-spam-ai-built-apps)
- [Rejected for 4.3(a): looking for advice (Apple Developer Forums 842971)](https://developer.apple.com/forums/thread/842971?answerId=902713022)
- [Spam rejection, now an account warning (Apple Developer Forums 847013)](https://developer.apple.com/forums/thread/847013)
- [4.3 cleared after a call with App Review (Apple Developer Forums 780651)](https://developer.apple.com/forums/thread/780651), [769509](https://developer.apple.com/forums/thread/769509)
