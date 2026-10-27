# App R11: the seams (27 Oct 2026)

Scope: ROUND-11's App items (P0-2 to P0-8, P1-10 to P1-13, P1-15) plus the four asks in NEEDS "Scene → App
(Round 11)". Nothing is committed; CI hasn't compiled any of it.

## P0
- **2. Failure says why.**
  - The pill "Flight over" is now **"The storm caught you"**, at the big "Perfect"'s scale (black rounded, 52 / 40 pt,
    up to two lines). It sits on the bird page above the bird, or below it when there's no room, and always under the
    meter (`CaughtLine.center` / `size`). It shows 0.5 s into the catch (was 1.4 s), and VoiceOver says the same.
  - **The meter stays** through the catch, with the storm end on the knob (lead 0 = Scene's `stormMeterFill`). Only
    the tag line and the chain pill fade.
  - **Results:** the one quiet line is now the cause: "The storm caught you 2.2 km before Kestrel Head." (near a best:
    "…400 m short of your best."). That replaces "… is 2.2 km further.", so no new line was added. A cover-ended flight
    has no line. On a tight card the plan now drops the tracker strip before this line.
- **3. The rule before the miss.**
  - `FlightSchool.words` plus the new `subWords` (a muted second line, ≤ 7 words, drawn by `SchoolWord(sub:)`):
    - dive: "Fold down the wave" / "Hold down the wave", then "Open at the bottom" / "Let go at the bottom" once the
      ghost has shown it;
    - a miss: "Opened too soon" / "Let go too soon" + "Stay folded to the bottom" / "Keep holding to the bottom";
    - wings (the first move): "One fold per wave" / "One hold per wave" as the second line, and still on the rhythm
      step;
    - land: "Fold to come down" / "Hold to come down";
    - the iPhone's hold step now says "Hold it sideways".
  - Tapping has its own words.
  - **CI frame:** s1-05 is now `school=dive:turn` (both scenario files), so the frame shows the rule with its second
    line after the demonstration.
- **4. The fold diagram.**
  - `WingDiagram` is a side-on hinge: two plates meeting at the hinge. The open target is 174° and "Fold a little" is
    135°. Each target is dashed, with its wedge tinted (teal open, gold fold), and a chevron at each live tip points the
    way to move.
  - The live pose follows the calibrated tuck (`GameController.diagramTuck`), so it meets the targets exactly.
  - The done state is the reached pose with a gold tick.
  - The label always sits under the diagram, at sea (`SchoolRig.diagramCenter`/`placement`) and in the Studio (whose
    layout now uses the drawn, scaled size).
  - On iPhone the same slot shows a fingertip pressing, not a phone or a book.
  - Scene removed the book on the gull's back, so the diagram is the one indicator.
  - On the smallest iPhone with the bird at mid-height, there's only room for one line, so the second line is left out
    there (`SchoolRig.showsSub`).
- **5. "Land here".**
  - The words sit right above the ring's drop marker (`ringScreenRect`) from the step's start.
  - If they had to move, a dotted gold `RingPointer` with a chevron joins them to the ring.
  - Scene keeps the ring ≥ 200 pt inboard.
- **6. The storm step is never empty.**
  - The storm rolls in during the rhythm step's success. That success now holds 1.6 s
    (`FlightSchoolCopy.praiseSeconds(.rhythm)`), and the meter shows then too, so the step's first frame has the storm,
    the meter and "Stay ahead".
  - "Stay ahead" shows from 0 to 3 s, then "Land in the gold ring" by the ring. The storm step now asks Scene for
    `.landingAhead`, because R10's step had no ring to name.
  - The meter labels "Storm" in school.
- **7. The Perfect visibly pushes the storm. Why R10's s1-13b froze on "Stay ahead": both causes were real.**
  - The storm was never on screen. `rollInStorm()` was only called on `out.advanced` into the storm step, so a school
    started AT that step (every CI frame, and replays) never rolled it in. Scene only recoils a rolled-in storm, so
    `onPeak(.recoil)` never fired and the knob had nothing to follow. Scene also confirmed that a `scene.reset()` after
    the call cleared it.
  - The demo machine was held (`schoolHeld`), so it never saw the Perfect and `pushedAt` stayed nil. The capture was
    the unfrozen end of the 25 s budget.
  - **The fix:**
    - `publishSchoolWorld` asks for the roll-in **every frame** while `FlightSchool.stormRollsIn` (idempotent; it
      survives resets), with the `.schoolStorm` cue and Core's gap set once.
    - `school=storm:turn;freezeOn=recoil` now runs LIVE. The recoil peak freezes it, and there is a 0.6 s fallback
      after `out.pushed`.
    - The meter's knob jumps with `stormRecoil` (the push itself without a scene), and a gold **"+"** pops just ahead
      of the knob (`LeadMeter.gapPop`).
    - `FlightSchool.meterLead(_:recoil:)` and `showsGapPop` are the pure, tested forms.
  - The held storm frames (s1-11…13) now freeze at sea x 6300 (was 5000), so the 2 s roll-in has played, because a
    held frame stalls the scene's clock. `school=storm:1|2|3` = the first frame ("Stay ahead"), then by the ring.
- **8. One direction everywhere.**
  - `RouteLayout.make(…, mirrored:)` reflects the whole map in a mirrored flight: the harbour and the storm are at the
    right, the lighthouses lead left, and the next one opens at 40 %. `coastY`/`lineY` are reflected, so each tower
    stays on its headland.
  - `MiniRouteStrip(mirrored:)` does the same for the Results tracker.
  - The best pin, the tracker gull, the new bird on Results (`BirdSideView(facingLeft:)`) and the Birds preview and
    tiles face the flight direction.
  - The iPhone is unchanged.

## P1
- **10. Copy.**
  - "2 new lighthouses" (`ResultsHeadline.newChip`, from the new `RecordOutcome.newOnRouteCount`).
  - The duplicate "further" line is gone.
  - "Land in the gold ring".
  - "Stay ahead" never shows twice in a row.
  - **One distance format:** `hudDistance` / `distance` drop ".0" ("4 km", "1 km"). The share line's `ShareText.km`
    is unchanged.
  - The countdown no longer repeats Home's goal sentence (this fixes the iPhone's "lighthouses....").
  - **Goals:** "Level 2 of 15 · next: Coral trail" (one colon, via `rewardPhrase`), and Level 1 is "Starter bird:
    Gull · Sky: Golden Hour".
  - Results says "Level 2 reward".
  - Birds says "Reach level N".
- **11. Collisions.**
  - The Studio passes its diagram + words rect as `homeTextRects`, so the attract gull keeps under "Hold anywhere".
  - Home's text block now covers both tagline lines (Scene trims the trail).
  - The step dots moved beside Skip on the sea page, away from where the Perfect ring lands.
  - Tests check text rects against the bird rect, the diagram and the controls (`RoundElevenTests`, and the updated
    `wingDiagramAndRig`).
- **12. Step dots.** There is one count of 5 on the Duo and the iPhone. The clear-side check is a question with no
  dot (the dots hide while it's asked), so they never jump from 1 to 3. The colours are unchanged: gold now, white
  done, dim to come.
- **13. Mystery UI.**
  - The round gull disc at the iPhone's bottom corner is gone (the vignette stays).
  - Home's corner buttons are labelled pills ("Settings", "Scores").
  - The Birds tile is laid out like Goals and Route, with "New" as a corner dot.
- **15. Results cards.** The two cards have one height and one bottom (`ResultsLayout.sideRect`), with the side
  content centred. "Choose Tern" has gold words and a gold outline.
- **14 (Scene's ask).** The "Perfect ×N" lettering uses Scene's drop-in: an opaque 8-way outline and a flat
  reward-gold fill.

## Tests
- **New `SwoopTests/AppTestsR11.swift`:**
  - the live push (words + meter lead + "+");
  - the live push frame;
  - the storm step never empty;
  - the rule before the miss;
  - the diagram wedge;
  - "Land here" by its ring and the pointer;
  - failure says why (on-screen and Results);
  - sequential dots;
  - text vs bird / controls;
  - copy;
  - the shared card bottom.
- **Updated in `AppTests.swift`, to the new intent:**
  - the distance format (`1 km`, `4 km`);
  - 5 dots with the check;
  - the storm guide;
  - the Results story lines;
  - the route test also runs mirrored, plus a new `routeFollowsTheFlightDirection`;
  - the diagram and rig (side-on targets, words under the diagram, dots by Skip);
  - `CaughtLine.text`, "Level 2 reward", the countdown and the Goals copy;
  - the school words.

## Uncertain (for CI)
- **`View`-isolation of statics.** New pure helpers on `View` types are marked `nonisolated` (`WingDiagram.size`,
  `plates`, `CaughtLine.size`, `fontSize`, `LeadMeter.gapPopCenter`, `MiniRouteStrip.ends`, `SchoolStudioView.textRects`).
  Tests read `CaughtLine.delay` (a static `let`, as R10's `CaughtLine.text`).
- **Tight fits.** The rig's words are 220 pt wide on compact canvases, and the iPhone SE's page leaves 3.5 pt of clamp
  room. `CaughtLine` on the SE falls back under the meter when the bird is mid-height.
- **Overlays.** `.overlay(alignment:content:)` is used on `Canvas` (the tick) and on the Home tiles (the dot).
  `RingPointer` draws two `Path`s in the rig's full-canvas coordinate space.
- **Live push frame.** s1-13b now depends on the autopilot landing a Perfect before the 15 s pass-anyway. The 0.6 s
  fallback freeze covers a missed peak but not a missed Perfect.
