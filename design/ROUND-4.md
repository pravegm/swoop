# Round 4: craft to launch quality (26 Oct 2026)

## The panel on the R3 build (`design/panel/REVIEW-3-*.md`, read your relevant ones in full)

| Critic | Score | Verdict |
|---|---|---|
| Apple Design Award juror | 6.5 | not yet; "Great on iPhone Duo" once the P0s are fixed |
| Mobile game UX | 7.0 | not yet, one focused round |
| First-time player | 7.0 | not yet; would leave 4★ |
| iPhone Duo specialist | 7.5 | not yet; the fallback scores 8 |

**The bar for this round is 9/10 from every critic.** The concept is right; craft holds it back.

The rules from ROUND-1 still apply:
- write only in your own folders;
- no commits;
- conservative Swift;
- leave notes in `design/notes/<role>-R4.md`;
- cross-module requests go in `design/NEEDS.md`.

## Consensus P0s (all must be fixed)

### 1. Results text clips (all four critics, for the third round running)
**Owner:** App.
- The Duo results card can't rely on a ScrollView that nobody will scroll.
  - On the Duo, move the rank-up, goals and logbook onto the bird page, which is currently empty.
  - On the iPhone, use two pages or a compact layout.
- Add a test that computes the content height for each results variant on 951×669, 874×402 and 667×375, and fails if
  it overflows.
- **Contradicting numbers** (player): "Pass 4 lighthouses ✓" next to "2 lighthouses". Every goal states "in one
  flight" or "in total". Core owns the goal text; App owns the display.

### 2. The storm (all four)
**Owner:** Scene.
- **Make the cloud wall look like weather.** It is still a "stack of pancakes under a flat disc". Replace it with a
  real shelf-cloud or roll-cloud wall: a soft, billowing, layered silhouette with a rain curtain under it, and no
  disc. If vector art can't get there, use gradient-filled lobes with noise or a texture.
- **Make it visibly chase.** At 77 % lead and at 9 % lead its edge sits at the same x. Map its screen x
  monotonically and visibly from the gap: a hint at the left edge at a full lead, and covering up to 40 % of the bird
  page under 15 %. The lead meter and the picture must tell the same story.

### 3. Text over the sun is illegible (juror, UX, player, Duo)
**Owner:** App.
- The Ready ring, countdown words, captions and the "Spread your wings" line sit at about 1.3:1 contrast.
- Put a navy `#0B2236` disc at 0.55 alpha behind the ring and pills behind the lines, or move them off the sun.
- Check contrast at 4.5:1 or better for all text that sits over the scene.

### 4. "Paused at 0.0 km" while the HUD shows 89 m (juror, UX, Duo)
**Owner:** App. Use one distance formatter everywhere (the cover's), with a test.

### 5. The tucked title bird is a stick figure with legs (juror)
**Owner:** Scene.
- This is the pitch frame (store-17, home-tucked).
- Redraw the tucked pose as a clean dart or teardrop with swept wings along the body, with no limbs.
- Also unify the bird mark: there are four different ones across the icon, cover, badges and glyphs. Make one mark
  in `BirdArt` that everyone uses.

### 6. Hinge comfort (Duo specialist)
**Owners:** Feel and App.
- **The rest angle.** Players who hold below 140° fly permanently tucked.
  - Open floor 132°.
  - Learn from 125°.
  - Stroke `clamp(open − 100, 30, 36)`.
  - Closing pause at 90°/98° with a 0.2 s dwell, using the smoothed angle; instant below 75°.
  - An end-stop tick when the tuck hits full.
  - A countdown nudge, "Open a little wider", if the open angle is near the floor. This one is App.
- **After a cover reopen**, the Ready hold is 2.5 s, counted from when the inner display is back. iOS's blur lasts
  1–2.5 s. App.

## Consensus P1s

7. **The lead meter** (UX, player). App.
   - Fill by `sqrt(gap / (leadMeterScale × fullLead))`, capped at 1.
   - A coral danger zone covers the first 17 %.
   - On the first run, a one-time label: "Storm ←→ you".
8. **Make Perfects special again** (UX). App, Scene and Feel.
   - The rule stays. The text callout and hit-stop come only at chain milestones (3, 5, 10, 15, 20…).
   - Ring colour escalates from foam to gold to reward gold.
   - The chime keeps playing every time, but a soft one; it is big only at milestones. Feel owns this.
9. **Splashes must read as mistakes** (player). Scene, Feel and App.
   - A heavier visual thud, a small "Splash" word near the bird, and the "×N lost" pill near the bird rather than top
     right.
10. **The sea is a featureless slab over 40–55 % of every frame** (juror). Scene.
    - Add depth: swell bands, a sun glitter path, foam streaks, subtle colour variation.
    - Fix the jagged "mountain ridge" storm chop and the Results sea.
    - Cloud streaks must not have hard rectangular ends.
    - Calm the spiky white Perfect burst and star confetti so they don't swamp the bird.
11. **The icon must read at 60 and 40 px** (juror). App.
    - Keep concept A, but give the gull a heavier stroke and bigger primaries, and render test sizes in CI.
12. **The iPhone fallback** (UX, player). App.
    - Hint pills move off the bird's path.
    - Redesign the touch wing glyph, which reads like a dropdown chevron, and move it from under the left thumb.
    - Fix the Daily card's blank button and its 180 pt of empty space.
    - "Free flight" needs a text label.
13. **The Daily** (player). App.
    - Celebrate beating your best.
    - Number from launch, so day one isn't "#298": display number = `day − DailySeed.dayNumber(2026-11-24) + 1`,
      minimum 1. The seed is unchanged.
14. **Fold-to-fly-again fill** (UX). App. It's invisible gold on gold on the Duo: use an amber `#E8A93A` fill plus a
    progress line.
15. **A TestFlight-only hinge readout** for the founder's device test (Duo specialist). App.
    - A Settings row "Hinge readout (TestFlight)", visible only in TestFlight or sandbox builds.
    - It overlays the live angle, open angle, tuck, report rate and pose.
16. **CI captures that didn't capture.** App owns the scenarios; the founder owns duo.sh.
    - store-21 is the same frame as store-20.
    - duo-01 and duo-06 caught the wrong moment.

## Founder (me)
- Correct the hinge-wear claims in `docs/` and the review notes. The real rate is about 38 strokes of 36° per minute
  for a casual player.
- `duo.sh` capture timing.
- Store composite frames.
