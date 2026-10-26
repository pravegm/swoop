# Swoop project log

*Times are UTC. Facts only; the reasoning lives in `design/` and `docs/appstore/DECISIONS.md`.*

## Mon 26 Oct 2026: day 1

- **Brief:** a third iPhone Duo-first paid game from the studio, after Squish and Brim, built unsupervised by Claude
  running the studio (founder, designer, developer, with parallel subagents per role and a design-critic loop).
  £1.99, no ads, no in-app purchases, no data collected, 4+. It must use the hinge and must not be a third Squish or
  Brim.
- **Research** (`research/01-market.md`):
  - No direct competitor: nobody on the Duo or other foldables makes a bird that dives on hills with the hinge. The
    closest is **Valley Run**, a fold-timed marble swing game whose website title is "Valley Run: Fold to Fly". Two
    Flappy Bird clones (DuoBird, Foldy Bird) use a discrete fold-as-flap.
  - Name check: bare "Swoop" is crowded; "Fold to Fly" is taken by Valley Run; Updraft and Glide clash. Recommended
    **"Swoop: Tuck & Soar"**, with "Foldwing" as the unique fallback.
  - Tiny Wings lessons and clone risk: mechanics are shared genre convention, expression isn't. Avoid a plump bird
    on pastel hills, "islands", "fever" and the sunset clock.
  - Book pose and the fold blur: starting a fold from fully flat blurs one half of the Duo's screen for about 2 s
    (seen on Brim's real-Duo test the same day; system-level, no opt-out). So the game must never rest at flat.
- **Concept chosen: Swoop, a one-input momentum flyer in book pose.** The Duo's two halves are the bird's wings:
  fold a little to tuck and dive down an ocean swell, open to soar off the crest. Chosen because it is a different
  pose (book, held in two hands), verb (dive and soar), hinge use (tuck = weight) and loop (endless score chase) from
  Squish and Brim, and the lane is open. The run clock became a **storm front** instead of a sunset, to stay clear
  of Tiny Wings.
- **Design** (`design/GAME-DESIGN.md` v1):
  - Tuck mapped over a 36° stroke (158° open → 122° fully tucked), with the open point auto-calibrated to the
    player's resting angle (150–172°).
  - Ready pose is a relaxed book (130–170°) with a 3-2-1 countdown, never flat; pause below 95°; cover-display card
    when shut; press-and-hold touch fallback.
  - Deterministic skim/launch/touchdown physics (Perfect, Good, Splash), the storm, Tailwinds, lighthouses, Flight,
    Daily Flight, Flocks (15 ranks), 8 birds, 5 skies, 2 leaderboards and 12 achievements.
- **Architecture** (`design/ARCHITECTURE.md`, `Swoop/Shared/Contracts.swift`): Core (simulation), Scene (SpriteKit),
  Input + Feedback (hinge, touch, autopilot, synth audio, haptics) and App (shell, UI, persistence, Game Center, demo
  mode), each with a fixed API so the engineers can compile against each other without a local compiler. Demo keys
  and `SWOOP-` log lines for CI are in `design/ROUND-1.md`.
- **Repo:** `pravegm/swoop`, local copy `C:\Users\59527\Wing`. It was **created private**, because the permission
  guard blocks creating public repos. First commit at about 10:51: research, game design, architecture, contracts
  and the CI skeleton (`ci.yml`, `duo.yml`, `testflight.yml` adapted from Brim; `testflight.yml` signs with Apple's
  cloud-managed distribution certificate from the start, so it never creates development certificates).
- **CI blocked by billing:** on this account, GitHub Actions on private repos is refused by billing (Brim hit the
  same block on 25 Oct). The first CI run, 40310741812, was created at 10:52 and sat queued. Making the repo public
  is the founder's call (`docs/LAUNCH-RUNBOOK.md` §0a).
- By about 11:00 the GitHub API reports the repo as **public** (GitHub Pages not yet enabled). Run 40310741812 then
  ran on the macOS runner and failed inside `build-test` (that commit holds only the skeleton, without the app modules).
  A job running at all shows Actions are no longer blocked.
- **Engineers dispatched for round 1** (`design/ROUND-1.md`, first playable): Core, Scene, Feel and App engineers,
  each writing only in their own folders, with hand-off notes due in `design/notes/<role>-R1.md`.
- **Launch lead:** the launch kit written from Brim's template: `docs/LAUNCH-RUNBOOK.md`, `docs/appstore/*.md`
  (metadata, review notes, privacy, accessibility, achievements, screenshots, press kit, social launch, featuring
  nomination, decisions) and the website `docs/site/` with forwarding pages in `docs/` for GitHub Pages. Proposed
  launch **Tue 24 Nov 2026** (Brim is Tue 17 Nov), manual release, featuring nomination by Tue 3 Nov.

### 26 Oct, afternoon: rounds 1–3, the design push

| Time | What happened |
|---|---|
| ~11:50 | **Round 1 build pushed.** The app compiled on the first CI try. One test error followed: `#expect` can't call a mutating method. The next push (run 40318086958) was green, with 99 tests, and balance matched the Node sim. |
| ~12:20 | **Duo sim run 40318165524.** The hinge drives the bird. But a 146.7° rest read as 31 % tucked, because the slow calibration took about 20 s. **Fix:** the ready pose (countdown or resume) snaps "wings open". Re-run 40321586583: READY-CALIB, HINGE-FLIGHT and CLOSE-PAUSE all PASS. |
| — | **REVIEW-1: 6/10.** Satisfaction wasn't there yet: rare, invisible Perfects, a tiny bird, flat trails. **QA-1:** 0 P0, 6 P1. |
| ~13:15 | **Round 2 green on the first compile, 128 tests.** Casual 162 s, 12.4 Perfects and 3.8 splashes per minute. **QA-2:** 0 P0, 0 P1. |
| — | **Founder:** "spend time on design and UX"; "optimise in all ways for iPhone Duo, with a fallback". Added an Art Director (`design/ART-DIRECTION.md`) and a UX Lead (`design/UX-SPEC.md`), plus a Duo-first section and an iPhone-fallback section in both. |
| ~15:30 | **Round 3** (built to the specs) compiled first time, 165 tests after 3 test fixes. **Duo checks:** all PASS. |
| — | **Critic panel on R3:** juror 6.5, UX 7.0, first-time player 7.0, Duo specialist 7.5. All four said "not yet". |
| — | **Round 4 dispatched** (`design/ROUND-4.md`). The store copy was corrected to the real stroke rate (about 40 × 30–36° per minute in active play). A store-frame pipeline is being built. |
