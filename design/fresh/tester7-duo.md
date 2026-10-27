# Swoop: Tuck & Soar, first session (tester 7, UX designer, iPhone Duo)

## My four answers

1. **Hands.** I hold the Duo open like a book, and the two halves are the gull's wings. Folding it partly
   closed tucks the wings, so the gull dives down the face of a wave and picks up speed. Opening it at the
   bottom of the wave launches it into the air. I fold once per wave, and opening and closing over and over
   ("flapping") is wrong. I should open as the gull comes down onto the next slope, so it lands on a downhill
   stretch. Before the run starts there's a countdown, and I hold the wings open and steady until it ends.
2. **The storm.** It's a dark rain cloud on the right, behind me, chasing me. The bar at the top shows how close
   it is. Each Perfect landing pushes it back. If I'm slow, it catches me and the flight ends.
3. **Where I'm going.** I'm flying left along a coast of named lighthouses: Gull Point (4 km), Saltlight (9),
   Kestrel Head (15), Old Harry (22), Wren Ness (30), "and on". The Route map collects the ones I reach.
4. **Success and failure.** Success is distance, reaching the next lighthouse, and stringing Perfects together.
   Failure is "The storm caught you". It's an endless runner, so every flight ends that way. What changes is how
   far I got first. On my first flight I made 12.83 km, passed Saltlight, got 11 Perfects and ranked up.

## Is it finished? Mostly, but not yet premium

The core idea is lovely. The top-down gull whose wings fold with the hinge (s1, s3, s4) is the best moment in
the game, because it makes the Duo feel like the controller it was made for. The sunset palette and the water
splash are pleasant. Then it falls back on text and a busy interface, and the finish slips.

Unfinished, inconsistent, cluttered or wordy details, by screen:
- **s3 to s5**: the top-down gull and the hinge diagram disappear after step 2. They were the clearest teacher,
  and from then on I'm reading cards instead.
- **s3/s4 vs s5+**: the tutorial card jumps from the bottom of the screen to the top. The pause button is
  missing in s3 and s4, then appears in s5.
- **s5/s6**: the "Faster!" bar is never explained. The failure line ("You opened too soon. Stay folded.") repeats
  the heading above it.
- **s8**: "Land in the ring ahead", but the ring is already under the bird and reads as a flat ellipse, not a target.
- **s9**: "Land on a downslope = Perfect." An equals sign in game copy feels like a developer's note. This card
  also mentions the storm two steps before the storm is introduced.
- **s10**: "Never flap" uses a word nobody has defined. There's a new slider with three dots under the bird that is
  never explained.
- **s11**: "A storm is chasing you" over a clear blue, sunny sky with no storm in sight.
- **s11 to s13**: three different messages all labelled "Step 7 of 7". In s12 and s13 the step dots sit on top of
  the storm bar.
- **s1 vs s13 vs s14**: the goal is called "the next lighthouse", then "Gull Point · 4 km", then "the next
  lighthouse" again. The s14 toast repeats the home screen subtitle word for word.
- **s15**: the toast covers the gull while I'm playing. A strange pink contrail-like line runs across the sky.
  Distance switches from "63 m" to "3.94 km" in the same HUD. "Storm behind you. Don't let it catch you." repeats
  step 7 again.
- **s15b**: the storm bar and pause button vanish. "The storm caught you" has no full stop, unlike every other
  line in the game.
- **s16**: the busiest screen. It has a headline, a pill, a sentence, the big number, a tip, "Route ›", a line
  about the Route, a Perfects count, three buttons and a fold hint, plus a rank-up card. The rank-up card text is
  **truncated** ("Fly 15 km in t…"). The ticks sit oddly mid-sentence ("· ✓"), so I can't tell which goals are
  already done. Distances are shown to two decimals everywhere (12.83, 2.17), which is spreadsheet precision,
  not game feel.
- **s17**: seven controls on the home screen (Fly, Daily Flight, Goals, Route, Birds, Leaderboards, Settings).
  "Leaderboards" has a label and the gear doesn't. A decorative wave line runs behind the buttons.
  "Everyone's sea · one try" is cryptic.
- **s18**: a clear **text-overlap bug**: "…and on, as far as you can fly." prints on top of "30 km" under Wren
  Ness. The sky is a murky green that matches nothing else in the game. The title and back button sit oddly off
  centre. "Best 12.83 km" appears twice, and the bottom card repeats what the map already shows.
- **Throughout**: the tutorial is seven text cards, and I read more than I played in the first two minutes.

## Against Monument Valley and Alto

Monument Valley and Alto teach almost wordlessly. One gesture, one visual consequence, and a UI that gets out of
the way. Their typography and layouts are calm, consistent and never clipped. Swoop's control idea is just as
elegant as Alto's one-touch, and arguably more original. But it explains itself in words, stacks HUD elements, and
has visible layout bugs (s16, s18) those studios would never ship. For clarity it's about 6/10 next to their 9.
For polish, about 6/10 next to their 9.5. The art is pleasant but more generic flat-vector than authored.

## Three changes that would most improve it

1. **Teach with the wings, not words.** Keep the top-down gull and hinge gauge visible all through the tutorial.
   Cut the seven steps to about three (fold to dive, open to soar, land downhill) with three-word cues. Drop the
   "=", "flap" and the repeated storm toasts. Show the storm on screen when you first mention it.
2. **A polish pass on layout and consistency.** Fix the s18 overlap and the s16 truncation. Stop the step dots
   colliding with the storm bar (s12). Never put toasts over the bird (s15). Keep the HUD the same from screen to
   screen, use one distance unit with at most one decimal, and keep the card position, punctuation and the
   lighthouse naming consistent.
3. **Simplify results and home.** On results, show one hero number, one line of story ("Past Saltlight, 2 km
   short of Kestrel Head") and one call to action. Move rank-ups to a moment of their own. On home, group the
   secondary controls behind one entry point so the gull and the Fly button can breathe.

## Would I recommend it?

Yes, with a caveat. To another Duo owner I'd say "the folding is genuinely delightful, ignore the wordy bits". To
a design friend I'd wait for an update. It's a strong idea at about 80% finish.

## Scores

- Understood: **7/10**
- Feels finished/premium: **6/10**
- I'd keep playing: **7/10**
