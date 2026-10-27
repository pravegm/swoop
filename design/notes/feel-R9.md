# Feel R9: the guide gull, the overtake, the new school beats (27 Oct 2026)

## Built
- **The guide gull's "watch" cues (UX-ROUND-9 §1.1, ART §1A).** `cue(.ghost(FeelGhostMove))`, with the moves
  dive / soar / land / rhythm (Scene's names).
  - **They can't be confused with the player's own cues.** They are breath only: band-passed noise at Q 1.6. They have
    no thump, chime, tick or drop, and no haptic. They peak at ≤ 0.04, which is under half the player's launch swish.
  - Each is shaped like its move: dive falls (1.6 s), soar rises (1.1 s), and land settles. The ghost Perfect stays
    silent, as ART asks. Rhythm is two down-up pairs over two swells.
  - Tested: breath only, the level, and the band.
- **The caught overtake (ART §2).** The `caught` event plays the new sequence. Nothing for the App to call.
  - **0–1.2 s, the sweep:** a wide rush that opens up as the wall passes the bird (`caughtSweep`), with the rain
    curtain arriving at the edge.
  - **0.9 s, one strike** (`caughtStrike`, the ART bolt ahead of the bird): a dry crack, a short roll, and a low body.
  - **From 1.2 s:** the calm A-major pad and the soft bell, as before.
  - The haptic is the front's roll (2 s) with exactly one jolt at 0.9 s.
  - Tested: one crack at 0.9 s, the pad starting at 1.2 s, and one haptic transient.
- **The redesigned school beats (UX §1.2):**
  - `.schoolMorph`: a falling swoosh and a water kiss as the title bird drops in, with a light tap.
  - `.waveDone(1…3)`: a tiny marimba tick that climbs per gold bead (rhythm is shown on the sea now).
  - `.stormPushedBack`: a rising gust and a receding rumble on step 6's Perfect.
  - `.lighthouseSighted`: Gull Point's bell, far away and quiet. It's below half the "reached" bell, so reaching it
    stays the big moment.
  - The step chime (`.schoolStep`), the rewind whoosh and `.schoolStorm` are unchanged.
- **Cut items:** no Feel cue was ever tied to the Faster! bar or the rhythm bar, so there was nothing to remove.

## Files
Feedback: FeelSoundBook (`caught` rewritten, `caughtSweep`/`caughtStrike`, `ghost`, `ghostPeak`, `schoolMorph`,
`waveDone`, `stormPushedBack`, `lighthouseSighted`), FeelHaptics (`caught`, `schoolMorph`, `waveDone`,
`stormPushedBack`), FeedbackDirector (`FeelGhostMove`, 5 new `FeelCue` cases). FeedbackTests has 34 tests (+3).
NEEDS.md ("Feel → App (Round 9)").

## Decisions
- **No haptic on any ghost cue.** A touch on the hands must always mean "you did that". The demo is something you
  hear, the answer something you feel.
- **One strike only in the overtake,** with no `stormClose` thunder repeat. The bed's rain swell rides under it, and
  the 1.4 s caught glide still fades the wind.

## Tune on a real Duo
- Is the ghost whoosh audible over the practice wind (× 0.6), yet clearly "not me"?
- Does the strike at 0.9 s land with the bolt on screen?
