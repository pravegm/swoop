# Swoop: game design (v1, 26 Oct 2026)

*Store name: **Swoop: Tuck & Soar** (the name check is in `research/01-market.md`; "Fold to Fly" is already the tagline of Valley Run). The bundle ID is `com.pravegm.swoop`.*

## 1. The pitch in one breath

Hold your iPhone Duo open like a book. **The two halves are your bird's wings.** Fold them in a little and the bird
tucks and dives down the face of an ocean swell, picking up speed. Open them at the bottom and it soars off the next
crest. Keep skimming, keep launching, and **outfly the storm** that is chasing you across the sea.

- **Genre:** one-input momentum flyer (the family of Tiny Wings and Alto). Runs last 1–4 minutes and restart instantly.
- **Price:** £1.99 once. No ads, no in-app purchases, no data collected, rated 4+.
- **Why only on a Duo:** the gesture is the game. You fold the phone the way a bird folds its wings, and the phone's
  halves fold with the bird. A touch fallback ("hold to tuck") keeps it playable on any iPhone, but it is clearly the
  lesser way to play.

### Why this game, and not a third Squish or Brim

| | Squish | Brim | **Swoop** |
|---|---|---|---|
| Pose | tabletop, closing | flat → lid lifted | **book pose, held in two hands** |
| Verb | crush | pour | **dive and soar** |
| Hinge use | the gap between the plates | a container's tilt | **wing tuck = weight** |
| Loop | toy plus collection | precision levels | **endless momentum score chase** |

## 2. The bar (in order)

1. **The fold feels like flying.** Tucking has to feel heavy and fast, and opening has to feel like lift. Judge every
   change on a held Duo at 120–170°.
2. **Satisfying.** The skim, the launch and the "perfect" chain carry the game. Sound, haptics, spray, wind and light
   must all rise and fall with speed.
3. **Addictive.** The first run lasts about 60 s and is obviously improvable. "One more" restarts in under 1 s. A daily
   flight, goals and unlockable birds bring players back.
4. **Gentle on the hinge.** Strokes are short (about 30°) and slow (one swell every 2–3 s). Play never asks for slams,
   full closes, or fully flat.

## 3. The input

The hinge angle θ comes from `onHingeChange` (180° = flat). It is filtered with Brim's stack: a `HingePredictor` for
display rate, then a One-Euro filter on top.

- **Tuck** `u ∈ [0, 1]`: `u = smoothstep((θ_open − θ) / (θ_open − θ_full))`, with `θ_open = 158°` and `θ_full = 122°`.
  - Above 158° the wings are fully spread.
  - Below 122° they are fully tucked.
  - The 36° stroke is well above the ~5° sensor error and a comfortable squeeze for two hands.
- **Calibration, automatic and invisible:** the player's resting book angle varies. The "open" point follows the
  player's own resting angle: an exponential average of the angle while not tucking, clamped to 150–172°. `θ_full` is
  always `θ_open − 36°`.
- **Play band:** 100–178°.
  - **Below 95°**, the phone is closing: pause ("Open your wings to keep flying").
  - **At 10° and below**, it is shut: the app is on the cover display. Show the pause card there.
  - Fully flat is allowed. It reads as fully open. **Founder note on the real Duo:** starting a fold from fully flat
    blurs one half of the screen for about 2 s (an iOS effect). So we never ask for flat. The "ready" pose is a
    relaxed book (130–170°), and the run starts with a 3-2-1 countdown in that pose.
- **Touch fallback** (no hinge, or "Play with touch" in Settings): press and hold anywhere to tuck. `u` ramps to 1 in
  0.12 s and releases in 0.10 s, so a hold feels like folding rather than a switch.
- **Accessibility:** a VoiceOver-adjustable "wing" control. With Reduce Motion on, the camera shake and screen bloom
  are off.

## 4. The world

- **Book-pose canvas:** landscape 951 × 669 pt, crease vertical at x ≈ 475 (a 40 pt band).
  - **World units = points.** One world for every device, shaped like the Duo's book canvas and aspect-filled
    (Brim's rule). Other phones crop the top and bottom.
- **Side view.** The sea is a continuous height field `h(x)`: smooth swells that are the sum of 3 seeded sine
  components, re-rolled at every "set" boundary with C¹ blending.
  - Wavelength 380–900 pt, amplitude 40–150 pt, the maximum slope always ≤ 1.1.
  - The sea gets bigger with distance: sets become longer and taller, and occasionally a "rogue" set gives a huge
    launch.
- **Camera:**
  - The bird sits at screen x = 30 % (on the left half, clear of the crease).
  - The camera zooms out smoothly as the bird climbs (scale 1.0 → 0.45), so the water always stays in view, as
    Tiny Wings does it.
  - Vertical framing keeps the bird in the upper 40 %.
- **The crease** is decorative: a faint horizon-glint band. Nothing critical sits in it. On a fold, each half shows
  its own content naturally. The left half is the bird and the storm behind it. **The right half is what's coming**:
  the clear golden sky, the swells ahead, the next lighthouse. That split is the composition of every store frame.

## 5. The physics (all in Core, deterministic, sub-stepped at ≤ 1/240 s)

**Constants** (initial values; the balance harness tunes them):

| | Value |
|---|---|
| gravity `g` | 1500 pt/s² |
| tuck gravity | `g · (1 + 1.9·u)` |
| air lift with spread wings | upward accel `(1 − u) · min(0.5·g, 0.012·vx²)`, **only while descending** (glide, never climb) |
| air drag | `0.04 · |v|` per second |
| water friction (skimming) | 0.2 % per second, small |
| minimum forward speed | 260 pt/s (the bird gives a little flap animation instead of stalling) |
| max speed | 2600 pt/s |

**Two states:**

1. **Skimming** (in contact with the water):
   - The bird moves along the surface tangent with speed `s`.
   - Each step adds `−g_eff · sin(φ)` along the tangent, where φ is the surface angle (a downslope accelerates it),
     then the friction.
   - If the surface curves away faster than the bird's path (a crest), the bird **launches**: it keeps its velocity
     vector, goes airborne, and fires the `launch` event with that speed.
2. **Airborne:** ballistic with the tuck gravity, the spread-wing lift and drag. When the bird's y reaches `h(x)`, it
   **touches down**. Let α be the angle between its velocity and the surface tangent:
   - **Perfect skim** (α ≤ 14° *and* the surface is going downhill, φ < −4°): keep 100 % of the speed and add a 6 %
     boost. Fires `perfect`.
   - **Good** (α ≤ 30°): keep `cos(α)` of the speed. Fires `land`.
   - **Splash** (α > 30°, usually a nose-dive into an upslope): keep `cos(α) · 0.75`, with a big spray. Fires
     `splash`. This is the mistake, and it should look and sound wet and heavy.

**The skill, in one line:** tuck while you're on a downslope (heavier = faster), open while you're going up and over
the crest (lighter = longer flight), and land on the next downslope. Tucking in the air makes you drop sooner, which
is how you pick a landing spot.

## 6. The run: outfly the storm

The market check found that a sunset timer would echo Tiny Wings, so our clock is a **storm front** chasing the bird
from behind. It is darker, louder and more dramatic, and it gives every run a visible chaser.

- **The storm** is a front that follows the bird from the left. It moves at `n(t) = 520 + 9·t` pt/s, capped at 1500.
  - Visually, the left edge of the screen is a wall of slate cloud with slanting rain and the odd lightning flicker.
  - The sea under it turns grey and choppy.
  - The sky ahead (to the right, across the fold) stays clear and golden.
- **The gap** `G = x_bird − x_storm` starts at 2400 pt. The storm caught you when `G ≤ 0`.
- **The lead meter** at the top shows `G` as a fraction of a 3000 pt "full lead" (`Tuning.fullLead`). It is a thin bar
  that is grey on the storm side and gold on the clear side.
- **Thunder warns you.** When the gap falls under 15 %, a low rumble plays, rain starts to streak the left half and
  the haptic rumble deepens.
- **Perfect chains push the storm back:**
  - every Perfect adds +120 pt to the gap;
  - a **Tailwind** (3 Perfects in a row) adds +600 pt and gives 2.5 s of +15 % speed with a golden trail. Each further
    Perfect during the Tailwind extends it.
- **Lighthouses** stand every 4 km (then 5, 6…). Passing one gives +800 pt of lead, a beam sweep, a bell, and a
  checkpoint name ("Gull Point", "Saltlight"…). They are the run's milestones and the share text.
- **End of run:** the storm overtakes the bird, and the bird tucks its head and rides the swell, bobbing under the
  rain. It is calm, never punishing. Then the result card: distance (km, one decimal), best, Perfects, longest chain,
  lighthouses.
- **Score:** distance in metres (1 m = 10 pt), plus a style bonus (Perfect = 25 m, Tailwind = 100 m). Show it as one
  number. Distance is the headline.

**Target run lengths** (harness-checked):

| Player | Run length |
|---|---|
| Novice: random tuck rhythm | 45–75 s |
| Casual: tucks on most downslopes | 2–3 min |
| Expert: harness optimal | 6+ min, and still ends (the storm accelerates) |

## 7. Moments of satisfaction (the juice list)

| Moment | Visual | Sound | Haptic |
|---|---|---|---|
| Tucking | wings sweep back, the bird narrows, speed lines start | wind rises in pitch and cutoff with speed | continuous rumble, intensity = speed |
| Skimming | the wingtip trails a spray line on the water, a foam wake | hiss of the skim, rising with speed | fine texture (sharp, light) |
| Launch | spray burst, the bird stretches, a camera pull-out | a "whump" of air, then quiet wind | one firm tap, scaled by speed |
| Perfect | white ring on the water, a chime on a rising pentatonic scale (one note per chain step), the trail turns gold | chime | crisp double tap |
| Tailwind | golden trail, a sun flare, the storm visibly pushed back | major chord swell | rising ramp |
| Splash | a big white splash, a camera bump, the bird shakes off water | heavy splash | heavy thud |
| Lighthouse | beam sweep, name card | distant bell | soft triple |
| Storm catches you | rain sweeps over, everything slows and calms, the bird rides the swell | the wind fades into rain and a soft pad | one long soft fade |

Sound is synthesized live (wind = filtered noise; chimes = sine plus bell partials; splash = noise bursts), using
Brim's audio approach. The audio session is `.playback` with mixing, so sound plays on silent, as the founder asked
for Squish. A setting can respect the silent switch.

## 8. Modes and progression

1. **Flight** (endless, the main mode): new seas every run, from a random seed.
2. **Daily Flight:** the same seed for everyone each day. One scored attempt (practice after that). Shows a streak of
   days, and a shareable result ("Swoop Daily #12: 7.4 km, 23 Perfects, Saltlight 🌅").
3. **Flocks (goals):** three goals at a time ("Reach Gull Point", "Chain 5 Perfects", "Touch a cloud", "Fly 2 km
   without a splash"…). Completing all three ranks you up (Fledgling → … → Storm Rider, 15 ranks). Ranks unlock:
   - **Birds** (cosmetic plus a tiny personality; all are balanced the same): Gull (start), Tern, Puffin, Swift,
     Albatross, Storm Petrel, Night Heron, Golden Gannet. The personality is wing shape and trail colour.
   - **Skies:** Golden Hour (start), Rose Dusk, Northern Lights, Monsoon, Moonrise.
4. **Game Center:** leaderboards for "Longest flight" and "Daily flight", and 12 achievements.

## 9. The first 10 seconds

1. The title shows a big bird whose wings span **both halves**, across the crease. Caption: "Hold your Duo like a
   book. These are your wings."
2. The player folds a little, and the title bird tucks *with them*: live, mirrored by the hinge. "Fold to dive. Open
   to soar."
3. A 3-2-1 countdown, then the bird drops onto the first swell. That swell is a gentle, long downslope, so the first
   tuck always produces a satisfying acceleration and launch.
4. During the first run, two contextual hints appear once each: "Fold on the way down" on the first downslope and
   "Open to fly" at the first crest. They disappear after the first Perfect.

## 10. Screens

- **Home:** the title bird (live-mirrors the hinge), Fly, Daily, Flocks (goals), Birds, Settings, Game Center.
  Book-pose layout: the bird across both halves, with the menu on the right half.
- **Play HUD:** the distance top-centre (on the right half if needed), the lead meter, a chain pip counter, and a
  pause button in the corner (not on the crease).
- **Result card** on the right half, with the calm floating bird on the left. Buttons: Fly again (big), Home, Share.
- **Settings:** Sound, Haptics, Respect silent switch, Play with touch, Reduce motion (follows the system), Bird on
  the other side (mirror the layout, in case the blur bug or handedness bites), Reset progress.
- **Pose cards:** in portrait or tabletop, "Turn your Duo sideways and hold it like a book" (with an animated
  diagram) and a "Play with touch" option. When the phone is closed, the cover display shows "Open your wings".

## 11. Out of scope for 1.0

Multiplayer, online ghosts beyond Game Center, more than 8 birds, accounts, analytics.
