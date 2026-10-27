# Swoop: Tuck & Soar - first session (tester 14, iPhone Duo)

36, senior product designer at a games studio. I love Monument Valley, Alto's Odyssey and Mini Metro, and I judge apps against Apple Design Award winners. I paid £1.99, I'm playing on an iPhone Duo held open like a book, and I came in knowing nothing about the game.

## Screen by screen

- **s1-01-home**: Title screen. A big top-down gull spans both halves, so the wing-per-half idea lands before I read a word. Good. Problems:
  - The text column is right-aligned and crammed into the lower right. "Swoop", the "TUCK & SOAR" rule and two lines of body copy are stacked too tightly. The tagline sits right on the rule with no breathing room.
  - The secondary line "Stay ahead of the storm. Reach the lighthouses." is pale blue-grey on an orange-to-mauve gradient, with rain streaks over it. The contrast is poor.
  - The yellow trail arc of the little side-view gull runs right behind "wings." and "lighthouses.".
  - The Fly button sits on the horizon line, with the white wave crest running just under its bottom edge.
  - The leaderboard and settings buttons float over rain. They are a different style (translucent circles) from the solid Fly slab, and they sit on the opposite half.
  - The black wingtips with two white dots each read a bit like eyes.
- **s1-02-school-hold**: "Hold it open", shown with a flat front-view book icon with a cyan dashed outline. It sits on top of the storm cloud, so the label competes with the cloud texture. The progress dots are tiny, at the bottom right, and nowhere near Skip, which is at the bottom left.
- **s1-03-school-wings**: "Fold a little". The icon is almost identical to s1-02: the same flat open book, only the dashed outline turns yellow and moves inward. Nothing shows a fold angle. I had to compare the two frames to see any difference, and it still doesn't tell me how far "a little" is.
- **s1-04-school-wings-done**: The wings tuck into a dart shape, which is lovely. But the confirmation icon is a beige, fully open book: the state I just left. It has no label, no tick and no "Nice". Dot 1 is still active after three frames.
- **s1-05-school-dive**: A new scene with a day sky and a side-view gull. The top-down bird is gone with no transition. The label "Fold" is now above the icon, where on s1-02 and s1-03 it was below. A second mini yellow book is stuck on the gull's back, so there are two fold icons stacked about 50 px apart, saying the same thing. The dots jump from 1 to 3.
- **s1-06-school-dive-fail**: "Opened too soon" over a ghosted dashed outline. It says what I did wrong, but not what to do instead. The ghost icon is white-on-pale-sky and nearly invisible. The gull's mini book icon is still on its back.
- **s1-07-school-soar**: "Open". The label overlaps the top edge of its own ghost icon, and the dashed white outline almost disappears into the sky. At the far left there is a clipped yellow sparkle shape with a dotted trail that is never explained.
- **s1-08-school-land**: "Land here" floats in empty water at the left with no pointer. The ring it refers to is clipped by the bottom-left edge of the screen and half hidden behind the Skip button. Meanwhile the brightest ring on screen is the one around my own bird, so "here" reads as "where I already am".
- **s1-09-school-perfect**: The best tutorial frame. A target ring with a chevron and dotted drop line, and a big yellow "Perfect". It is the only hint in the game that gets a pointer. Why don't s1-08 and the others have one?
- **s1-10-school-rhythm**: "One fold per wave" in plain text with no diagram, after five screens of diagrams. Splash particles are clipped at the right edge. A faint ring around the gull is left over from the previous step.
- **s1-11-school-storm-1**: An empty frame: no text, no storm and no HUD, while the dots say this is the final step. As a player I'm just watching the bird cruise.
- **s1-12-school-storm-2**: The storm meter appears top right: a track with a bird puck and a cloud icon. Problems:
  - Nothing on the meter is labelled. "Storm" only appears in the real run (s1-15).
  - The grey left part of the track means nothing to me, and the goal is not marked on the bar at all.
  - "Stay ahead" is a two-word label for a concept the tutorial never shows (no storm is visible in this frame).
  - "Gull Point" and its lighthouse sit top left on a translucent rectangular slab with dead-straight vertical edges. It looks like a placeholder blocking box rather than a rock.
- **s1-13-school-storm-3**: "Land a Perfect". "Perfect" is used as a capitalised noun the game has never introduced as a thing you collect. The bird and meter positions are the same as s1-12, so it feels frozen.
- **s1-13b-school-storm-push**: "Stay ahead" again, word for word. The lighthouse has vanished, and the meter puck hasn't moved at all across three frames. What is the "push"? Nothing on screen shows it.
- **s1-14-run-countdown**: The countdown "2" sits in a large disc over the sun, with a caption pill: "Stay ahead of the storm. Reach the lighthouses. / Wings open, hold steady". That is the third time I've read the home tagline. The first line ends with a full stop and the second doesn't. Two different instructions are crammed into one centred pill of uneven line lengths. The meter puck has jumped right from where it was in the tutorial, with no explanation.
- **s1-15-run**: The HUD is clean: "64 m", a NEXT tag and a "Gull Point · 4.0 km" pill. But:
  - The NEXT tag collides with the top of the pill.
  - The home screen said "4 km" while this says "4.0 km".
  - "Storm" is now labelled, but it wasn't in the tutorial.
  - The bird flies left with the storm chasing from the right. A storm meter that reads left to right with the storm at the right end works against that.
- **s1-15b-caught**: "Flight over" is a small pill on a big, dramatic storm. Problems:
  - It doesn't say why. I infer the storm caught me, but the storm meter has vanished from the HUD at exactly the moment it matters.
  - Behind the cloud's lower-left there is a visible straight vertical seam where the storm sky tint stops.
  - "12.8 km" with a small grey "km" is a different unit treatment from "64 m" in s1-15.
- **s1-15c-flight-over**: Clear rendering defects:
  - The storm darkening has a hard vertical edge at roughly x=240, from the cloud base down into the water, so a rectangle is visible.
  - The cloud's right side smears into horizontal streaks, which looks like a texture clamped or stretched past its edge.
  - The gull is tiny, bobbing and greyed out. A sad moment, but it reads as a bug rather than as drama.
- **s1-16-results**: Two cards, one per half. That is a good use of the Duo, but:
  - The cards are different heights and both top-aligned, so the right card ends mid-screen with a gap below.
  - The headline "You made it past Gull Point and Saltlight!" is two lines of heavy yellow with an exclamation mark. The tracker directly above shows only Saltlight → Kestrel Head, with no Gull Point at all.
  - "NEW LIGHTHOUSE" is singular after two lighthouses.
  - "Kestrel Head · 2.2 km to go" and "Kestrel Head is 2.2 km further." say the same thing twice, 500 px apart.
  - "12.8 km" is indented a few px right of the text column, and there is a large dead band between it and Fly again.
  - On the right card, the Tern faces right while every gull in the game flies left. "Level 2" has no context (level of what?). "Choose Tern" is a dark-on-dark button with almost no emphasis.
  - "Or fold and open to fly again" is a nice Duo touch.
- **s1-17-home**: The home screen now has Fly, Daily Flight, Goals, Route and Birds, and the tagline has changed to the storm line. Problems:
  - The Birds tile breaks the tile pattern: it has a "New" badge stacked over the label and no icon, where Goals and Route both have icon and label inline.
  - The wave crest line passes visibly through the gaps between the tiles.
  - The Fly button says "Kestrel Head · 15 km" (absolute), but the results screen said "2.2 km further" (relative). Pick one.
  - The leaderboard and settings circles now sit on top of white spray and rain, which makes them harder to see.
- **s1-18-route**: A nice idea: a lighthouse chain on a wave profile with ticks. Problems:
  - The route runs left to right with the storm cloud and pier at the far left. In the run (s1-12, s1-15) I fly left with the storm on the right. The map is mirrored relative to the game.
  - About 50% of the screen, from y≈650 to 1080, is empty navy.
  - The Fly button is wrapped in a second dark container, a card inside a card.
  - "and on..." has no icon and sits on a different baseline feel from the labelled stops.
  - The lighthouse icon styles vary: striped filled, yellow outline, grey outline. That is fine as state, but nothing explains it.
- **s1-19-goals**: Problems:
  - "Level 2 of 15 · next: New trail: Coral" has a double colon.
  - "Puddle Hopper", "Fledgling" and the other rank titles appear with no explanation.
  - Level 1 says "You start with the Gull and Golden Hour", a full sentence, while every other level is a noun phrase.
  - "3 Perfects" again uses the capitalised noun.
  - The bottom 30% of the left half is empty.
  - On the right, Level 8's subtitle ("Tern Turner") is clipped at the bottom edge.
  - A faint gull silhouette from the background shows through the translucent Level 4 card.
  - There is a visible darker vertical band at the fold.

## The four questions

1. **What do my hands do?** I hold the Duo open flat like a book; the halves are the wings. I fold it partway shut to tuck the wings and dive down the face of a wave. I open it again to soar off the crest. The aim is to touch down in the gold ring on the next downslope for a "Perfect". No, I don't flap repeatedly. It's one fold and one open per wave ("One fold per wave", s1-10). What I still don't know is how far to fold. s1-03 says "a little" and s1-05 just says "Fold", and no diagram shows an angle.
2. **What is the storm?** It's a raincloud chasing me from behind (from the right), shown as the cloud icon at the right end of the top meter. If it reaches the bird, the flight ends. I worked that out from s1-15b/c, not from the tutorial. The tutorial's storm steps (s1-11 to s1-13b) never show the storm or the meter moving.
3. **Where am I going?** Along a coast of named lighthouses: Gull Point at 4 km, Saltlight at 9, Kestrel Head at 15, then Old Harry, Wren Ness "and on...". In the game I travel left. On the Route map I travel right. I genuinely don't know which way the world faces.
4. **What is success and failure?** Success is distance, passing lighthouses, landing Perfects, and completing goals that unlock birds, skies and trails (the Tern at level 2). Failure is the storm catching me ("Flight over"). Opening too early during a dive is also a mistake ("Opened too soon"), but from the screens I can't tell what that costs me: speed, distance, or nothing.

## Verdicts

**Is this ADA / featuring quality?** Not yet. The core idea is excellent and genuinely Duo-native: halves as wings, fold to dive. It's the kind of thing Apple's editorial team loves. The golden-hour palette on the home screen is attractive, and the two-card results layout uses the hinge sensibly. But the session is full of things an editor would notice in 30 seconds:
- a storm overlay with a hard rectangular edge and a smeared cloud (s1-15c)
- a placeholder-looking slab under the lighthouse (s1-12)
- a route map that is mirrored relative to the game (s1-18)
- results copy that contradicts its own graphic (s1-16)
- a tutorial whose icons don't actually depict the input (s1-02/03/04)

**What separates it from Monument Valley / Alto?**
- Those games teach with the world, not with labels. Alto shows the input once and then gets out of the way. Swoop has 12 tutorial frames of floating two-word captions ("Fold", "Open", "Stay ahead", "Land a Perfect"), and half of them aren't anchored to anything.
- Their art has one rendering language. Swoop mixes flat vector birds, a painterly photo-ish cumulus and translucent UI slabs.
- Their transitions are continuous. Swoop cuts from the top-down dusk bird to the side-view noon bird with no bridge (s1-04 to s1-05).
- Their failure moments are composed. Swoop's is a small pill over a glitchy cloud.
- The UI typography is competent but generic. There's no type personality like MV's spaced capitals or Alto's quiet serif-free minimalism, and copy repeats itself (the tagline three times, "2.2 km" twice, "Stay ahead" twice).

**Top 8 fixes (most important first)**

1. **Fix the storm rendering (s1-15b, s1-15c).** Replace the rectangular storm tint with a full-screen gradient mask whose leading edge is a soft horizontal alpha ramp, at least 300 pt wide, positioned from the storm's x-position. There must be no straight vertical edge anywhere. For the cloud sprite, stop the texture clamp smear on the right: use a texture wide enough for the max overscan, or tile and mirror it, or fade it out with alpha before its edge. Do the same for the seam behind the cloud in s1-15b.
2. **Make direction consistent everywhere (s1-12, s1-15, s1-16, s1-18).** The bird flies left with the storm on the right. Mirror the Route map so the pier and storm are on the right and lighthouses progress leftward. Do the same for the results tracker in s1-16 (or flip gameplay; just pick one). Also flip the Tern art on s1-16 to face left. On the storm meter, put a lighthouse/goal icon at the far left end and label both ends from the tutorial onwards, not just "Storm" in-run.
3. **Redraw the fold diagrams to show the angle (s1-02, s1-03, s1-04, s1-05).**
   - Replace the flat front-view books with a 3/4 or top-down hinge diagram whose two halves visibly close: 180° for "Hold it open", about 140° for "Fold a little". Drive it live from the hinge angle with a target wedge, so I can see "you're here, aim here".
   - On s1-04, show the folded pose with a tick, not a flat open book.
   - Keep the label in one position (below the icon) on every step.
   - Delete the duplicate mini book on the gull's back (s1-05, s1-06).
4. **Make failure explain itself (s1-15b, s1-06).**
   - On s1-15b, keep the storm meter on screen through the end and animate the storm puck reaching the bird. Change the pill to "The storm caught you" at a size that matches the moment, about the size of the "Perfect" text in s1-09.
   - On s1-06, add the remedy as a second line, e.g. "Stay folded until you reach the bottom", and say what it cost (speed or distance) if it costs anything.
5. **Fix the results screen (s1-16).**
   - Make the headline match the tracker: either show Gull Point → Saltlight → Kestrel Head on the line, or change the copy. Make the badge plural ("2 NEW LIGHTHOUSES").
   - Delete "Kestrel Head is 2.2 km further." since the tracker already says it.
   - Bottom-align or equal-height the two cards, and fill the right card's dead space or shrink it.
   - Change "Level 2" to "Level 2 reward".
   - Give "Choose Tern" a visible secondary style (light outline or tinted fill).
   - Align "12.8 km" to the text column's left edge.
6. **Anchor every tutorial hint to its target (s1-08, s1-02, s1-07).** Use the s1-09 treatment (chevron and dotted line to the ring) for "Land here". Spawn the tutorial ring at least 200 pt inboard so it's never clipped by the screen edge or hidden under Skip. Move hint labels off the storm cloud (s1-02) and off their own icons (s1-07, where "Open" overlaps its outline). Give the ghost outlines a dark 1 pt keyline or scrim so they read on a pale sky.
7. **Do a copy pass across all screens.**
   - s1-13: "Land a Perfect" → "Hit the gold ring".
   - s1-14: drop the repeated tagline from the countdown. Keep one instruction ("Wings open. Hold steady.") with consistent punctuation.
   - s1-01 vs s1-15: use one distance format ("4 km" everywhere, or "4.0 km" everywhere).
   - s1-16 vs s1-17: pick absolute or remaining distance and use it everywhere.
   - s1-19: "Level 2 of 15 · Next: Coral trail"; write Level 1 as a noun phrase like the others; lowercase "perfects" or name it properly.
   - s1-13b: never show "Stay ahead" twice in a row.
   - s1-11: either add content to the empty step or cut it.
8. **Replace placeholders and fix layout leftovers (s1-12, s1-18, s1-17, s1-01).**
   - s1-12/13: swap the translucent rectangular slab under the Gull Point lighthouse for a real rock/headland silhouette with an irregular edge.
   - s1-18: move the route profile down to the vertical middle, or use the empty band for a "best run" marker, and remove the second container around Fly.
   - s1-17: make the Birds tile match Goals/Route (icon plus inline label, badge as a corner dot).
   - s1-01: put a soft dark scrim behind the right-hand text block so the secondary line passes 4.5:1, and keep the gull's yellow trail arc out of the text box.

## Scores

- Understood: 6/10
- Feels finished: 5/10
- Keep playing: 6/10
