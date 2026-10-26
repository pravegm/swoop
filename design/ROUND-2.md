# Round 2: make it satisfying (26 Oct 2026)

**Inputs:**
- `design/REVIEW-1.md`: the critic gave it 6/10. Satisfaction isn't there yet.
- `design/QA-1.md`: 0 P0, 6 P1, 15 P2.
- Duo CI run 40318165524, where the hinge drives the bird but the ready pose read as 30 % tucked. Fixed in `cbb2c8f`;
  QA-1 P1-3 and P1-4 refine that fix.

**The rules from ROUND-1 still apply:** own folders only, no commits, conservative Swift, and a note at the end
(`design/notes/<role>-R2.md`). Read REVIEW-1 and QA-1 in full; the numbers below refer to them.

**Goal:** every moment that should feel good, looks, sounds and feels good. Casual players get a steady drip of
Perfects. The bird and the storm are always readable.

## Core engineer
1. **Landings** (REVIEW-1 top-10 #1):
   - a 7° landing assist (rotate the velocity toward the tangent, up to 7°, on touchdown);
   - the Perfect window 14→18°, its slope test −4°→−2°;
   - Good ≤ 36°;
   - a splash keeps 0.82 of the speed;
   - after the storm reaches cruise speed it accelerates at 3.5 pt/s².

   Re-tune the balance with `tools/balance-sim.js` against these **new targets**:

   | Player | Run length | Perfects/min | Splashes/min |
   |---|---|---|---|
   | novice | 45–80 s | ≥ 2 | — |
   | casual | 130–170 s | ≥ 7 | ≤ 4 |
   | expert | 300–500 s | — | — |

   Perfect play must still end. Update the BalanceTests asserts to match.
2. **Chains** (#2): only a **splash** breaks a chain; a Good keeps it (but doesn't add to it).
3. **The tutorial swell guarantees the first Perfect.** A player who does nothing, or who tucks at any point on the
   first downslope, lands Perfect on the second swell. Add a test.
4. **Goals:** replace the speed goals with goals a player can see (REVIEW-1 #10). Make the rank count consistent
   (15, as in the design) and give the ranks that currently reward only "a new title" something real: a bird, a sky,
   or a trail colour. Trail colours as unlockables are fine; add them to the catalogue.
5. **QA-1 P2s that touch Core:** the Tailwind-end speed jolt (ease it out over 0.6 s) and cloud touches. Agree the
   cloud altitude with the Scene engineer via `Tuning.cloudHeight`; the scene must draw clouds at that height.

## Scene engineer
1. **Perfect visible** (#3): a growing gold ring and a 3 % camera punch-in. The "Perfect ×N" callout text is the
   App's. The 35 ms hit-stop is the App's too: during a hit-stop the scene receives the same snapshot, so FX must
   keep animating on wall time.
2. **The bird 30 % bigger** (`birdUnit` 64→84), with zoom resist 0.45→0.6 and a dark rim so dark birds read on dark
   skies. The camera keeps the bird below 22 % from the top of the visible rect (the HUD band) (#4).
3. **The title bird redrawn** from above and behind, so a full tuck folds it into a dart, not legs (#5).
   `BirdArt.titlePath` keeps its signature.
4. **Trails** (#6): tapered, fading, glowing; the Tailwind trail is a two-strand gold ribbon.
5. **The far swell** reads as sand dunes: recolour it to sea and horizon. The full-height crease light shaft becomes
   a band at the horizon (#7).
6. **The storm is always on screen** (#8): a crisp cloud wall scaled to the gap, rain sheets, and a dimmed world when
   caught.
7. **Lighthouses** must be drawn and visible at the moment you pass them (#9).
8. **QA-1 P1-6, frame rate:** remove the per-frame allocations, cache the colours, and cut the path rebuilds. Rebuild
   the sea fill only when the camera moved more than 0.5 pt, or use a cheaper fill.

## Feel engineer
1. **QA-1 P1-3:** calibration ratchets up after opening wide. Learn only from angles within +6° of the open angle,
   slow the upward rate (τ 10 s), and add a test.
2. **QA-1 P1-4:** `snapCalibration` in the resume hold. Snap only from the *filtered* angle and only while the hinge
   is still (speed < 3°/s), so a mid-reopen angle never becomes "open". Keep the countdown snap.
3. **Juice for the new Perfect moment:**
   - the chime gets brighter with the chain;
   - a soft "whoosh-pop" on the punch-in;
   - a haptic that lands exactly on the hit-stop;
   - a chain-break sound on a splash that isn't harsh.
   Check the whole mix for a 3-minute session at a casual Perfect rate of 7/min: it must not fatigue.

## App engineer
1. **QA-1 P1-1** (the caught window loses runs), **P1-2** (the Daily score is lost on kill), **P1-5** (the Game
   Center button does nothing when signed out), and the P2 "hinge input chosen from the stored flag before any live
   sample".
2. **The Perfect callout:** "Perfect ×N" pops near the bird on the left half, never on the fold. Add a 35 ms hit-stop
   on a Perfect (skip one session step; `reduceMotion` keeps it).
3. **The HUD:**
   - show km above 1 km ("1.2 km");
   - a "DAILY #298" tag during Daily runs;
   - give the lead meter headroom so it isn't always pinned full. Show gap / (1.3 × fullLead), or ask Core for a
     `Tuning` constant.
4. **Toasts and the results card:** the "4 km" milestone toast must not stack on the lighthouse card; suppress
   milestones within 0.5 km of a lighthouse. On iPhone the results card clips the lighthouse line and hides the
   goals: fix it for 667×375 up to Pro Max.
5. **Home:** keep the caption off the attract bird and trail, and keep the title bird and trail off the "Swoop"
   wordmark.
6. **Settings:** "Reset progress" goes at the bottom, as a plain destructive row, not a big coral button.
7. **Hints in touch mode:** "Hold on the way down" / "Let go to fly".
8. **Rank rewards UI:** follow Core's new rewards (trail colours), with a picker on the Birds screen.
9. **CI scenarios:**
   - fix `countdown`, which captured a blank portrait frame;
   - fix `storm-close`, whose capture failed;
   - add store frames with a visible Perfect callout and the storm in frame;
   - re-shoot store-04, -06 and -07 as the review asks.
