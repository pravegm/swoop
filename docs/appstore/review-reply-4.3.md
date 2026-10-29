# Reply to App Review: Guidelines 4.3 and 4.2.6 (29 Oct 2026)

Apple's instruction: if the app already meets 4.3(a), 4.3(b) and 4.2.6, **don't resubmit**; reply and answer all nine
questions in full. Paste the block below into **Reply to App Review** on the rejection page, then wait for Apple's
answer. Don't resubmit until they reply.

**Every statement below is true and checked:**
- **The code-sharing figures** come from a line-by-line comparison of the shipped app source on 29 Oct
  (`scratchpad/overlap.js`).
- **The beta history** is the founder's own TestFlight testing on a real iPhone Duo (builds 2–12). The AI design
  reviews used during development are not described as user testing.
- **AI assistance is disclosed plainly** in answer 9. Apple asks specifically about app generation; an honest answer
  is safer than a misleading one.

Before sending, the founder should check two things: the description of their own testing in answer 4, and whether
to keep the sentence about AI-assisted development in answer 9 (recommended).

```
Hello, and thank you. Swoop is an original game; answers below.

1. WHAT THE APP DOES
Swoop is a game played with the iPhone Duo's hinge. Held open like a book, the two halves of the phone are a seabird's wings: folding the halves in a little tucks the wings and the bird dives down the face of an ocean wave; opening them spreads the wings and it flies off the crest. Timing one fold per wave (land on the way down the next wave for a "Perfect") builds speed to stay ahead of a storm and reach lighthouses along a fixed coastal route. The Duo's hinge is a new physical input with very few uses; Swoop makes the fold itself the controller, felt in the hands rather than tapped on glass. Other iPhones play it by press-and-hold.

2. INTENDED USER
iPhone Duo owners who want a short, tactile game that uses what makes their phone different, in 2-5 minute sessions, from casual players to score chasers (Daily Flight, Game Center). Rated 4+; a 60-second guided lesson teaches it. Secondary: any iPhone owner who likes one-touch momentum games.

3. THE GAP IT ADDRESSES
Existing momentum and flying games are touch games. We found no App Store game that maps a foldable's hinge angle to a continuous control. Swoop is built around the hinge: the angle is filtered and calibrated to each player's resting pose, a full dive needs only about 30 degrees, play pauses safely if the phone is nearly closed, and the bird stays on the half of the screen iOS does not blur when a fold starts.

4. BETA TESTING
TestFlight builds 1.0 (2) to (12) were played on a real iPhone Duo. Feedback applied:
- "Do I tap repeatedly or hold?" -> added Flight School, a guided first-launch lesson.
- "The bird's half of the screen blurs when folding" -> the bird now flies on the half that stays sharp.
- "What is the storm, where am I going?" -> a route of named lighthouses as the goal, a storm meter, clearer results.
- "Folding halfway paused the game" -> the pause moved from 90 to 55 degrees.

5. STANDALONE OR SUITE
Standalone. Our account publishes a few separate iPhone Duo games, each a different genre with its own rules, pose, art, sound and content:
- Squish: a pressing toy (close the phone to squash objects).
- Brim: pouring (lift the top half to tip a jug to a line).
- Hush: patience (open a chest slowly without waking a mimic).
- Snapjaw: reaction (the halves are jaws; catch flies, spare bees).
- Glint: light puzzle (the top half is a mirror aimed at shadows).
- Swoop: an endless momentum flyer (book pose, halves are wings, a storm chase along a lighthouse route).
They share no levels, characters, art or rules.

6. COULD IT BE AN IN-APP PURCHASE OR ADDITION TO ANOTHER APP?
No. Swoop's systems (wave physics, flight model, storm, route, Daily Flight, lesson, 8 birds, 5 skies, 12 achievements, 2 leaderboards) are its own. The others are different genres played in different poses; merging them would make one app of unrelated games with conflicting controls.

7. SHARED CODE OR ASSETS WITH OUR OTHER APPS
Yes, a small in-house foundation we wrote and reuse: the audio synthesizer and engine (all sound is generated in code), haptics, the hinge reader and smoothing filter, a Game Center wrapper, orientation and settings plumbing - about 10% of Swoop's code by line count. The game itself (flight and wave simulation, storm, rendering, all art drawn in code, lesson, route, goals, every screen) is written for Swoop. No images, sounds or content are shared.

8. SHARED CODE WITH THIRD-PARTY APPS
No. Only Apple frameworks (SwiftUI, SpriteKit, GameKit, AVFoundation, Core Haptics); no third-party SDKs, libraries, templates or content.

9. CLIENT, PARTNER OR APP GENERATION SERVICE
No client or partner, and no template or app generation service. I am the developer and own the concept, design and content, submitted under my own account. I built it with AI-assisted coding tools under my direction; the code is original to this app.

Thank you. Happy to send a screen recording of Swoop on iPhone Duo.
```
