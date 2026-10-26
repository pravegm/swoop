# Review 3: first-time player (29, new iPhone Duo, paid £1.99 on the train)

**Score: 7/10.** **Launch verdict: not yet.** One polish pass of 2–3 days would get it there. The core is lovely. What
stops me leaving 5 stars is a handful of sloppy-looking bugs on the screens I see most often: clipped text, numbers
that contradict each other, and a storm that doesn't look like a storm.

I judged this by feel, from the Duo frames (`duo5/.../duo-screens`) and the iPhone fallback frames (`r5/screenshots`).

## My first 15 minutes, honestly

1. **Opening it** (`store-19-home-fresh`). I smiled straight away. It's a big gull, wings spread right across both
   halves, at sunset. "Hold your Duo like a book. These are your wings." I get it in one line, and there's only one
   thing to press: Fly. Then I fold a little (`store-17-home-folded`), the big gull's wings fold with my phone, and I
   actually said "oh" out loud. That's the moment that sells the £1.99. There's one catch: the dark stacked shape on
   the left looks like a rock stack or a cliff, not a storm. I genuinely thought it was scenery.
2. **Countdown** (`store-20`, `store-22`). "2 · Wings open, hold steady". It's clear and calm. But the bar at the top is
   already nearly empty (about 15 % gold) before I've done anything, and nobody tells me what it is. My first thought
   was "am I already losing?"
3. **First hint** (`duo-01`, `store-23`). "Fold on the way down" is perfect: short, and it arrives exactly on a
   downslope. On the iPhone, "Let go on the way up ✓" (`r5/hint-open`) sits right on top of the bird, so I can't see
   what I'm being taught.
4. **First flights** (`store-02/03`). The skim trail, the spray and the zoom-out look great. "Tailwind!" with the golden
   trail is a real reward. I understood Perfect by the third one.
5. **Messing up** (`r5/splash`, `store-24-chain-lost`). The splash barely looks different from a normal skim: a bit of
   spray, no word, no thud. The "×4 lost" pill appears top right, where I'm not looking. I didn't feel I'd made a
   mistake, so I didn't learn anything from it.
6. **Lighthouse** (`store-06`, `duo-03`). "Old Harry · 1st lighthouse · the storm falls back." This was the first time
   I understood that the storm is the thing chasing me and that the bar is my lead. It's a lovely beat, but it comes
   about 4 km in, and a novice may never get there.
7. **The storm closing in** (`store-07`). This is dramatic and finally reads as a storm: cloud wall, rain, red cloud
   icon. But in `duo-03`/`duo-04` my lead bar is almost empty (about 8 %) while the storm on screen is still a small,
   far-off pillar. The picture and the bar disagree, so I stopped trusting the picture.
8. **Caught** (`store-14`). The rain swallows the bird and it just bobs. It's calm, not punishing, and I liked that. A
   second of "Caught by the storm" text would help me understand what happened.
9. **Results** (`store-25-results-first`). The big number and the "Fly again" button are great, and "or fold and open"
   is a cool Duo touch. Then the rank-up box cuts its own text off mid-line ("flight · Chain 2 Perfects" is sliced off
   at the bottom). In a paid game, that's the first screenshot I'd make fun of. "New goals: Fly 3 km" after I flew
   12.8 km felt patronising. And "Daily Flight #298" on my first day made me wonder whether I'd missed 297 of
   something.
10. **Second run** (`store-08`/`store-28`). "NEW BEST! Previous best 6.4 km" made me happy. Then a gold tick on "Pass 4
    lighthouses" while the line above it says "2 lighthouses". I stared at that. Is it per flight or in total? It looks
    like a bug.
11. **Goals / Birds / Settings** (`duo-ui-*`). Goals is clean, and "Rank 6 of 15" gives me a ladder. Birds is charming,
    and "Every bird flies the same" is honest; I respect that. Settings reads well too: "Swoop collects no data" and
    "Bird on the other side" are nice. Small things: the top rank row is cut off under the top edge, "Tuck by
    Holding/Tapping" shows even when "Play with touch" is off, and on Home I don't know what the trophy button does
    when Goals already exists.
12. **Next day's Daily** (`store-29-daily-card`). I got 7.4 km against a best of 6.4 km, with no "NEW BEST", no Perfect
    count, and a big empty hole in the middle of the card. It felt like an anticlimax. "3-day streak · next Daily in
    8 h 7 m" is good and would bring me back.
13. **Closing the phone mid-run** (`duo-06/07`, `store-32`). The pause card on the outside screen is genuinely clever:
    "Open your wings to keep flying", the distance, how close the storm is. It's exactly what I'd want on a train
    when my stop comes. But "Storm 0.2 km behind" when I'm only 75 m into a run sounds like an alarm.
14. **Reopening** (`store-36-reopened-ready`, `duo-08`). The "Ready" ring is good, but "Spread your wings" under it is
    pale blue on the sun's glow and almost unreadable. The bird is also still splashing behind the ring, so I couldn't
    tell whether the game was paused or not.

**Would I tell a friend?** Yes, if they have a Duo: "the one where your phone is the bird's wings". **Review I'd leave
today (4★):** "Gorgeous, and the fold-to-dive actually feels like flying. Clipped text on the results screen and a
confusing storm bar knock off a star. Worth £1.99 if you own a Duo."

## Findings

### P0 (fix before launch: they make it look unfinished)
- **`store-25`, `store-26`, `store-27`: rank-up and logbook text clipped.** The "New goals…" line and the "New in the
  logbook…" list are sliced off by the box. Fix: let the rank-up box grow to fit, with no fixed height. Cap it at 2
  goal lines and replace the rest with "+1 more". Cut the logbook to 3 names plus "+6 more".
- **`store-08`, `store-28`: the goal contradicts the stats.** A tick on "Pass 4 lighthouses" sits next to "2
  lighthouses". Fix: label the scope on every goal ("in one flight" or "in total"). If it's a total, show "4 / 4 in
  total" on the progress bar.
- **`duo-03`, `duo-04` vs `store-07`: the storm on screen doesn't follow the lead bar.** At about 8 % lead, the storm
  still looks far away. Fix: drive the cloud wall's screen x straight from the gap. At 100 % lead its edge should be
  at x ≈ 0–5 % of the screen; at 15 % lead it should reach x ≈ 25 %, with rain on. Tint the bar's fill toward
  #C2554A below 25 %.

### P1 (hurt my first impressions and how fast I learned)
- **Storm reads as a rock** (every in-run frame). The stacked dark "pancake" pillar with a flat cap looks like a sea
  stack. Fix: soft, billowing cloud edges, a lighter top (#5A6180 → #3A4058), constant slanting rain beneath, and a
  lightning flicker every 6–10 s even when far away.
- **Lead bar unexplained, and it starts almost empty** (`store-20`). Fix: start the fill at the designed 80 % (2400 of
  3000), and during the countdown show the label "Your lead on the storm" under the bar for 3 s on the first 3 runs.
- **Splash doesn't feel like a mistake** (`r5/splash`, `store-24`). Fix: a 0.25 s camera dip, 2× the spray
  particles, a grey "Splash" word at the bird in #C9D3DE, and a "chain lost" pop at the bird rather than top right.
- **Hint pill covers the bird** (`r5/hint-open`). Fix: place hints at least 120 pt from the bird, on the right half
  (the "what's coming" side), at y ≈ 60 %.
- **Reopen ring text unreadable** (`store-36`). Fix: "Spread your wings" in #FFFFFF at 90 % opacity, with a 2 pt dark
  shadow (#0E1A2B at 60 %). Move the ring off the sun, to x ≈ 60 %, y ≈ 35 %. Hold the bird still until "Go".
- **Daily result is flat** (`store-29`). 7.4 km beats a 6.4 km best but shows no celebration, and the middle of the
  card is about 400 px of empty space. Fix: show "Daily best" or "Today's #298 best", then Perfects, chain and
  lighthouses, and fill the gap with a 7-day streak row of dots.
- **Goals too easy after a big run** (`store-25`: "Fly 3 km" after 12.8 km). Fix: draw new goals at 1.2–1.5× the
  player's current best.

### P2 (polish)
- **"#298" on day one.** Number the Daily from launch day (#1), or show the date ("Sun 26 Oct").
- **Caught moment has no words** (`store-14`). Add "The storm caught you" in white at 70 % opacity, for 1.2 s, before
  the card.
- **Cover "Storm 0.2 km behind" at 75 m** (`store-32`) sounds alarming. Fix: say "Storm close" or "Storm far" and
  give the lead as a %, for example "Lead 80 %".
- **iPhone home: "Press and hold the bird"** (`r5/home-returning`). There are two birds on screen, and in the game
  you hold anywhere. Change it to "Press and hold anywhere to tuck." "Goals 1 of 3 · Crest…" is truncated: drop the
  rank name at this width.
- **Trophy button on Home** is unexplained next to Goals. Label it ("Game Center") or remove it.
- **Settings:** hide "Tuck by" unless "Play with touch" is on.
- **"Perfect ×4" text overlaps the trail and bird** at night (`store-13`). Offset it +80 pt above the bird.
- **Units jump from m to km** at 1 km (670 m, then 1.18 km). That's fine, but keep one decimal in-run ("1.2 km") so
  the number doesn't flicker.

## What would keep me playing for a week
1. Knowing why I died and how close I got. A "0.4 km from Wicklight" line is there; make it the headline when
   it's close.
2. Goals that sit just past my best, so each run has one clear target.
3. A Daily that feels like an event: a celebration, a streak row, and shareable text with my lighthouses.
4. Seeing the storm actually breathe down my neck, so that a Tailwind visibly pushes it back.
5. New skies and birds every 2–3 runs early on. Rank 7 needing 32 Perfects in one flight is a wall for a casual
   player.
6. The cover-screen pause card, which already makes this my train game. Keep it.

## Top 8 for Round 4
1. Fix the clipped rank-up and logbook text so the box grows or truncates with "+N more" (`store-25/26/27`).
2. Make goal scope explicit and fix the "4 lighthouses ✓ vs 2 lighthouses" contradiction (`store-08`).
3. Drive the storm's on-screen position from the gap, and tint the bar red below 25 % (`duo-03/04`).
4. Redraw the storm as a billowing cloud wall with constant rain, not a rock stack.
5. Start the lead at 80 %, and label the bar "Your lead on the storm" for the first 3 runs (`store-20`).
6. Make splashes feel wet and heavy: camera dip, "Splash" word, and "chain lost" shown at the bird.
7. Keep hints off the bird, and make "Spread your wings" readable (`r5/hint-open`, `store-36`).
8. Give the Daily result a "Daily best" celebration and stats, number it from launch day, and draw goals at 1.2–1.5×
   the player's best.
