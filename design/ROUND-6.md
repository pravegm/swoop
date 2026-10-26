# Round 6: clarity, from the founder's first real-Duo test (27 Oct 2026)

## What the founder said (TestFlight 1.0 (2), real iPhone Duo)

> "On first try, it was not very clear how it works. Do I need to continuously flap like Flappy Bird, or just once,
> and what does what do? Maybe a tutorial on first launch will be nice. Then the default way of the bird being on the
> left side was not good, because that screen always blurs out when we fold. Either find a way to disable this blur,
> or default the bird to the right side so that the blur is always on the left. Also the objective was not very
> clear. What is the storm, where are we going, what is success? I like the concept, but it feels very half baked
> and not well thought through right now. I can see this as a successful app and a very popular one, but only when
> the design and UX is really well thought through."

This round's bar: **a first-time player understands, without help, (1) what to do with their hands, (2) what the
storm is, (3) where they're going and (4) what success looks like, all within the first 60 seconds.** Fresh testers
who have never seen the game will check this.

## Founder decisions (binding for this round)

### D1. The bird lives on the sharp half
**What we know about the blur.** iOS blurs one *fixed physical half* of the Duo's inner display for ~2 s whenever a
fold starts from (near) flat. It happens in every app, Photos included. No API turns it off (research:
`iphone-duo-hinge-api`, and Brim builds 6–8). So:

1. **The bird goes on the sharp half.**
   - On the founder's Duo, held the way they hold it, the sharp half is the RIGHT half of the screen.
   - The bird sits on the sharp half, so the flight runs right-to-left: the sea ahead is on the left page and the
     storm comes from the right.
   - This is the existing `mirrored` layout, now the Duo default.
2. **Track the physical half, not the screen side.**
   - Store the sharp half as a *physical* half: a screen side plus the interface orientation at the time
     (landscapeLeft or landscapeRight).
   - If the player turns the phone round 180°, the bird swaps screen sides so it stays on the same physical half.
   - **Default before any check:** the founder's case, treating the screen-right half in the current orientation as
     sharp. Default `sharpPhysical` = the physical half that is on screen-right in `landscapeRight`. **The founder's
     orientation is unknown**, so the Wing check below confirms it.
3. **"Wing check" in Flight School.** This is a 1-tap question, asked once:
   - "iPhone Duo softens one half of the screen for a moment when it starts to fold from flat. Open your Duo flat,
     then fold it a little. Which side stayed sharp?"
   - Buttons: [This side ←] [This side →] [Neither / skip].
   - Skip keeps the default.
   - Settings gets "Bird side: Sharp side (auto) · Left · Right".
4. **Discourage flat.**
   - Full spread is reached at the calibrated open angle, never later, so opening flat gains nothing.
   - If a run sees 3 or more openings to ≥ 174°, show a one-time tip, at most once per session: "Tip: no need to open
     flat. A slight fold is wings fully spread (and keeps the screen sharp)."
   - Flight School teaches it too.

### D2. Flight School: an interactive first-launch tutorial (Duo and iPhone versions)
It runs on the very first Fly, takes about 45 s, and can be skipped after the first step. It can be replayed from
Settings. It's a **calm practice sea**: no storm, no score, slightly slowed time (0.8×), one swell at a time.
Teach by doing, with one short line of text per step, a live diagram of the phone, and the bird responding.

| Step | Prompt | Advances when |
|---|---|---|
| 0, Hold | "Hold your Duo open like a book." | Book pose is detected and the hinge is still. |
| 1, Wings | "These are your wings. Fold a little…" (the big title bird mirrors the fold) | One full tuck. |
| 2, Wing check | The D1.3 question. | One tap. |
| 3, Dive | "Hold the fold all the way down the wave." The bird accelerates, speed lines draw and a "faster!" meter fills. | The tuck is held over 70 % of a downslope. |
| 4, Soar | "Open at the bottom… and fly!" Slow motion in the air. | Launch. |
| 5, Land | "Land on the next downslope: Perfect!" (A guided swell makes it easy.) | A Perfect (or 3 attempts). |
| 6, Rhythm | "That's it: **one fold per wave. You never flap.** Fold down, open up." A 3-wave mini-run shows a rhythm bar under the bird. | The 3 waves are done. |
| 7, The storm | "A storm is chasing you out to sea. Stay ahead of it: Perfects push it back." The storm rolls in at the edge, then the real run starts. | — |

- **On iPhone:** "hold the screen" replaces "fold" throughout, and step 2 is skipped.
- **VoiceOver:** every step is spoken and the wing control is explained.

### D3. The objective: the route and the lighthouses
**Framing, one sentence everywhere:** *"Outfly the storm and reach the next lighthouse."*

**Lighthouses are the goals.** They're already spaced 4, 9, 15… km out, and the names are seeded.
- **HUD:** an always-visible goal chip at the top, on the sea-ahead page: "→ Gull Point · 1.2 km". It counts down,
  and a small lighthouse icon grows as you near it.
- **Passing one** is the big success moment: the beam sweeps, a bell rings, and "**Gull Point reached!**" appears.
  If it's a new lighthouse for this player, add "New on your route", and it lights up on the route map.

**The route map.** This upgrades the existing logbook. It's a coast with all the lighthouses on a line, showing the
ones you've reached and the next one you haven't, with its distance and your best.
- It's reachable from Home and from Results.
- Home shows "Next: Saltlight · 9 km (your best 6.4 km)" under Fly.

**Results lead with the objective:**
- "Caught 0.8 km short of Saltlight", or "Reached Kestrel Head!";
- then the best;
- then what to try next: "Land Perfects to push the storm back."

**The storm, explained once** in Flight School step 7, and in one line under the meter on the first real run:
"Storm behind you. Don't let it catch you."

### D4. "Half baked": the coherence pass
Every screen must answer *what do I do, why, and how am I doing* in one glance.

The UX Lead and Art Director audit the whole flow once more against this round's bar and cut anything that doesn't
serve it: clutter, jargon ("Tailwind", "Flocks"), unexplained icons.

- **Name things plainly:** Goals, Route, Birds, Daily.
- **Tailwind** keeps its name but is explained the first time it happens: "Tailwind! 3 Perfects in a row = a burst
  of speed."

## Who does what (resumed engineers, the ROUND-1 rules)

**UX Lead** writes `design/UX-FLIGHT-SCHOOL.md`:
- the exact Flight School spec (states, copy, timings, failure and retry, skip, replay, the touch and VoiceOver
  variants);
- the objective UI (goal chip, lighthouse reached, route map, Home "Next", Results framing);
- the D1 Wing check and Settings;
- the D4 audit list.

Precise enough to build without questions.

**Art Director** writes `design/ART-FLIGHT-SCHOOL.md`:
- the live phone diagram;
- the practice sea look;
- the goal chip and lighthouse icon;
- the lighthouse-reached moment;
- the route map illustration;
- the mirrored composition rules (bird on the right page: HUD placement, sun position, storm from the right).

**Then the engineers:**
- **Core:** a `practice` mode. It's a calm, scripted sea with no storm, a 0.8× time scale and a guided first swell,
  and it emits step-completion signals.
- **Feel:** sharp-half tracking with orientation, the flat-open counter, and the cues for each step.
- **Scene:** the practice sea, the mirrored default polish, the lighthouse-reached moment and the route-map art
  helpers.
- **App:** everything else (screens, flow, persistence, Settings, scenarios).

## Verification
- **CI scenarios** for every Flight School step on the iPhone and the Duo (mirrored), the Wing check, the goal chip,
  the lighthouse reached, the route map, Home "Next" and the new Results.
- **Three fresh first-time testers** (agents with no prior context) walk the frame sequence. Each answers the four
  questions above in their own words; any wrong answer is a P0.
- **Then the full panel.**

## Specs (27 Oct): build exactly these
- `design/UX-FLIGHT-SCHOOL.md` (flows, copy, states, the Wing check, the objective UI, the D4 audit, 25 CI scenarios)
- `design/ART-FLIGHT-SCHOOL.md` (the DuoDiagram, the practice sea, the goal chip, the lighthouse-reached moment, the
  route map, the mirrored composition, tasks SC1–SC8 and AP1–AP11)

**Founder decisions on the open points**
- Lighthouse names are **fixed by index in every mode**: Gull Point, Saltlight, Kestrel Head… A route only works if
  each name is a place. This is a Core change.
- The pause button stays visible during Flight School as the way out (quiet styling).
- Distance text size: Art's call.
- **The storm:** two critics still read it as "rows of river stones". This round, try a different technique: a
  noise-based SKShader (fbm billows with soft edges, lit from the sun side), or a pre-rendered soft texture, in place
  of stacked vector lobes. It must still follow `SceneStormMap`.
- **Correction to D1.2 (default sharp half):** don't assume an orientation. The default sharp half is the half on
  **screen-right in whatever interface orientation the app first runs in on a Duo**. Record that orientation as the
  physical reference, and track the physical half from then on. That's exactly the founder's request ("default the
  bird to the right side"), whichever way they hold the phone. The Wing check refines it.
