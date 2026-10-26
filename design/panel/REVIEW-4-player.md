# Review 4: first-time player (same 29-year-old, same train, R4 build)

**Score: 8/10** (R3: 7). **Launch verdict: not yet, but about a day away.** Most of what annoyed me is fixed and
the game now feels finished while I'm flying. Two things still look broken on screens I see every day: the Home
button on the Daily result, and a splash that still doesn't tell me I made a mistake.

I judged by feel, from `duo6/.../duo-screens` (Duo) and `r8/screenshots` (iPhone fallback).

## My R3 P0s and P1s: what's fixed

| R3 item | Status | Evidence |
|---|---|---|
| P0 Rank-up and logbook text clipped | **Fixed** | `store-25/26/27`: the extras moved to the bird page, "+5 more" in the logbook |
| P0 "4 lighthouses ✓" vs "2 lighthouses" | **Fixed** | `store-08`: "Pass 3 lighthouses in one flight · Done in an earlier flight", "This flight: 11 of 25" |
| P0 Storm picture ignores the lead bar | **Fixed** | Small at the edge at about 80 % (`store-04`), half the page plus a coral bar at about 9 % (`store-07`) |
| P1 Storm reads as a rock stack | **Partly** | The pancakes are gone and close up it's a proper rain wall. But the hard-edged flat disc is still on top: at range it looks like a smoking surfboard or UFO (`store-23`, `store-40`) |
| P1 Lead bar unexplained, starts nearly empty | **Fixed** | `store-20`: starts at about 40 %, with a "Storm ←→ you" label |
| P1 Splash doesn't read as a mistake | **Not fixed (as seen)** | `store-43`, `store-24`, `r8/splash-mark`, `r8/chain-lost`: no "Splash" word and no "×N lost" anywhere. `app-R4.md` says it shows for 0.9 s, so either the capture missed it or it isn't firing |
| P1 Hint pill covers the bird | **Fixed** | `r8/hint-open`, `store-40`: the pill sits clear of the bird |
| P1 Reopen text unreadable over the sun | **Fixed** | `store-36`: a navy disc behind "Ready", a pill behind "Spread your wings" |
| P1 Daily result flat | **Partly** | `store-29`: "DAILY BEST!", a share card and a 7-day dot row are lovely. But the right card still has an empty middle (about 380 px), and the Home button is now broken (new P0 below) |
| P1 Goals too easy after a big run | **Not fixed** | `store-25`: "Fly 3 km in one flight" right after 12.16 km |

R3 P2s fixed:
- the Daily is now "#1" instead of "#298";
- "The storm caught you" now appears (`store-14`);
- the cover says "Storm far · lead 32 %" (`duo-07`);
- the iPhone Home copy now reads "Hold to dive. Let go to soar.";
- "Tuck by" is hidden when "Play with touch" is off.

Not fixed: the unexplained trophy button.

## Replaying it

1. **Home** (`store-19`, `store-17`). It's still the moment I'd show a friend. The tucked gull is now a clean,
   swept-wing shape (`store-17`) with no stick legs. It reads a little like a manta ray, but it's pretty. "Daily
   Flight #1" no longer makes me feel late.
2. **Countdown** (`store-20`, `store-42`). The number in a navy disc is easy to read, and "Open a little wider" in
   gold is a smart nudge: I'd actually open the phone wider. "Storm ←→ you" helped. I'd say "Your lead" instead,
   because the arrows read like "swap".
3. **First flights** (`store-23`, `store-40`, `store-02`). The hints sit clear of the bird. The sea has more depth,
   and Perfects now show a big word only at ×5 and ×10 (`store-04`, `store-06`), so they feel earned. I smiled at
   "Perfect ×10" plus Old Harry.
4. **Storm** (`store-07`). It finally chases me: the bar goes coral, the cloud fills half the page and the rain
   covers the bird. Tense in a good way. Further out, though, the flat grey blade with smoke under it still isn't a
   cloud.
5. **Splash** (`store-43`). It's still just spray and a grey ring. I wouldn't know I'd lost my chain.
6. **Caught, then results** (`store-14`, `store-25`, `store-08`). "The storm caught you" is exactly the beat that was
   missing. The results finally read cleanly across both halves, with the rank-up and goals on the left and my
   number and Fly again on the right. "Done in an earlier flight" answered my R3 confusion completely. The amber
   fold-to-fly fill (`store-28`) is visible now. It's a nice touch.
7. **Daily** (`store-29`, `store-27`). The "DAILY BEST!" badge and the share card made me want to post it. Then I
   saw a house icon floating above an empty little box next to "Practise today's sea" and thought something hadn't
   loaded. And "3-day streak" on Daily Flight #1 doesn't add up.
8. **Menus** (`duo-ui-*`). The new Haptics row is good. Birds and Goals are the same as before and still fine.
9. **Cover pause and reopen** (`duo-07`, `store-32`, `store-36`). It's the best train feature in the game. "Storm far ·
   lead 32 %" and "Beat 6.42 km to set a best" are calm and useful.

**The review I'd leave now (4★, and 5★ once the Home button and splash are fixed):**
> "The best reason to own a Duo. You fold the phone and the gull dives; you open it and it soars. The storm chasing
> you is genuinely tense, and closing the phone on the train pauses it with your stats on the front screen. A
> couple of rough edges (a broken-looking Home button on the Daily screen), but easily worth £1.99."

I would tell a friend, and I'd keep playing the Daily.

## Findings

### P0
- **Home button broken on every Daily result** (`store-29`, `store-27`, `r8/daily-card`). The house glyph sits about
  30 pt above an empty 120×110 pt button. Fix: put the icon inside its button, centred, and give the row a 1:1
  split ("Practise" | "Home"), or the same 2-up layout as the free-flight results (Home | Share).

### P1
- **Splash still invisible** (`store-43`, `r8/splash-mark`, `store-24`, `r8/chain-lost`). Verify that the "Splash ·
  ×N lost" word fires, and add a CI capture taken 0.2 s after a splash. Show it for at least 1.2 s, in #E6ECF2 on a
  #0B2236 pill at 0.7 alpha, 40 pt above the bird.
- **The storm's flat disc** (every in-run frame). Replace the hard elliptical cap with 4–6 overlapping soft lobes
  (#3A4058 → #5A6180), with no clean outline stroke. Keep the billowing body and rain; they work.
- **The storm cap overlaps the HUD** (`store-07`, `r8/storm-teach`): the pause button and bar sit on the cloud. Give
  them a #0B2236 plate at 0.6 alpha, or clip the cloud 24 pt below the HUD.
- **iPhone Home: the Goals tile lost the word "Goals"** (`r8/home-returning`: "Crest… / 1 of 3 goals"). Fix: title
  "Goals", subtitle "1 of 3 · Crest Hopper" truncated at the tail.
- **New goals still patronising** (`store-25`): "Fly 3 km" after 12.16 km. Draw distance goals at 1.2–1.5× the
  current best, and skip any goal already beaten.

### P2
- **Empty middle on the results card** (`store-08/25/28`, about 300 px; `store-29`, about 380 px). Move the Daily row
  up under the stats, or use the space for "Next lighthouse: Wicklight · 2.84 km".
- **Streak vs #1** (`store-29`): "3-day streak" on Daily #1. Before launch, show the date ("Sun 26 Oct") instead of
  "#1", or reset the streak.
- **"Storm ←→ you"** reads like "swap". Say "Your lead on the storm" instead.
- **Reopen "Ready"** (`store-36`): the bird is frozen mid-dive, so I can't tell whether it's paused. Dim the scene by
  25 % until "Go".
- **Trophy button** on Home is still unlabelled. Add "Game Center" as an accessibility label plus a long-press
  tooltip, or remove it.
- **Goals list**: the top rank row is cut by the top edge (`duo-ui-goals`). Add 24 pt of top inset.

## Top 8 for Round 5
1. Fix the Daily result's Home button: icon inside the button, with a 1:1 row.
2. Make the splash word and "×N lost" visible at the bird, with a CI capture that proves it.
3. Replace the storm's flat disc with soft lobes.
4. Put the iPhone Home Goals tile title back.
5. Draw goals at 1.2–1.5× the player's best.
6. Fill the empty middle of the results and Daily cards.
7. Fix the "3-day streak" on Daily #1.
8. Give the HUD a plate where the storm covers it.
