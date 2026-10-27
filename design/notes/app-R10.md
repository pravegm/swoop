# App R10: the lesson states the rule, the pictures match the words (27 Oct 2026)

## P0
- **1. Perfect pushes the storm back, taught in the lesson.**
  - **Step 4 (land):** on the Perfect, the big gold word "Perfect" lands above the bird (`SchoolBigWord`, 40 / 52 pt,
    ≥ 80 pt off the bird), and the step holds 1.4 s.
  - **Step 6 (storm):**
    - No words until the storm and its meter are on screen (1.8 s), then "Stay ahead", then "Land a Perfect".
    - The Perfect sets `pushedAt`. "Perfect" shows big and "Perfect pushes it back" sits by the meter for 2.4 s
      before the real flight.
    - The meter's knob jumps away from the storm with Scene's `stormRecoil` (`AppRules.schoolMeterLead`, +0.3 at
      full recoil; the push flag is the fallback).
    - Feel's `.stormPushedBack` cue and a VoiceOver line go with it.
  - Scene does the wall's recoil.
- **2. The goal sentence early.**
  - "Stay ahead of the storm. Reach the lighthouses." heads the first real flight's countdown pill, above the hands
    line (one pill: `AppRules.countdownText`).
  - On Home before the first flight it sits under the caption.
- **3. One diagram, pictures that match their words, one cue on the rhythm step.**
  - The wing diagram is the only hint picture (Studio and sea). It shows hold / wings / dive / soar.
  - It always draws the pose its words ask for as a dashed target (gold folded, teal open) over the live hinge:
    "Hold it open" shows the open book, "Fold a little" the fold, "Now open" open again (`diagramTarget`).
  - **The rhythm step** has one cue: Scene's fold zone (`.foldPathAhead`), no guide gull, no diagram, and the words
    "One fold per wave" / "One hold per wave".
  - **A missed dive** says what happened: "Opened too soon" / "Let go too soon".
  - Skip is there from step 1.
- **4. Results, Home and Goals (tester 10's list).**
  - **Results:**
    - The headline counts every lighthouse passed: "You made it past Gull Point and Saltlight!", or "…past 3
      lighthouses, to Kestrel Head!".
    - "New lighthouse" uses the same pill as "New best!".
    - The new bird shows as its own side-view art.
    - Its card has "Choose Tern" (it selects the bird), so "Fly again" is the one way to fly.
    - The two cards share a top edge.
  - **Home:**
    - The "New" badge is laid out with the words (on the detail line, after the word, or in place of the icon), so it
      never covers "Birds".
    - The Birds tile names the newly unlocked bird.
    - Top scores uses a `list.number` icon, so it no longer reads as a second Goals.
  - **Goals:**
    - The page leads with plain progress, "Level 2 of 15 · next: New bird: Tern". The title (Puddle Hopper) is a
      small subtitle.
    - The ladder rows read "Level 3 · now" with their rewards named by kind ("New trail: Coral"); the word "rank" is
      gone.
    - Done goals show the check only, with no full bar.
  - **HUD:** the goal chip loses its "<" (it read as Back); the countdown moves off the bird.
  - **Route:** it draws the next lighthouse plus two more, with a narrow "and on…" slot, so nothing is cut at the
    Duo's right edge.
- **P1-5 peaks.**
  - Scene's `onPeak` freezes the `freezeOn=perfect|caught|recoil` frames on the moment's strongest frame. In school it
    shows that moment's words (the big "Perfect", "Perfect pushes it back").
  - The delay stays as a 1.5 s fallback, and an explicit longer `freezeDelay` still wins (the r9 caught timing frames).
  - New demo phase `school=storm:push`.
  - CI:
    - `s1-09` now freezes on the Perfect's peak;
    - `s1-13b` storm push;
    - `s1-15b` the caught peak, plus `s1-15c` "Flight over";
    - r10-* frames for the peaks, the wings target, the countdown goal, fresh Home and Goals.

## Tests
- `RoundTenTests`: the Perfect stated and shown, the early goal sentence, pictures matching their words, and plain
  Home and Goals.
- Updated: Skip from step 1, the storm push timing, every-lighthouse headlines, the Route node count, "Next level", and
  the word rules (≤ 3 words, 4 only for the two rules).

## Left to Scene (NEEDS "App → Scene (Round 10)")
- The book glyph on the gull's back.
- Rain over the Home icons.
- The sky band on Home.
- Gull Point's translucent rock in step 6.
