# Round 1: first playable (26 Oct 2026)

## Goal

A complete, compiling first build. It has to deliver:

- the real flight, driven by the hinge on a Duo and by touch elsewhere;
- the sea, the bird, the storm, juice, sound and haptics;
- the home, results, goals, birds and settings screens;
- persistence and Game Center;
- the demo modes CI needs for screenshots.

## Rules for every engineer

1. **Read first:**
   - `design/GAME-DESIGN.md`, the game;
   - `design/ARCHITECTURE.md`, the APIs you must provide or may use;
   - `Swoop/Shared/Contracts.swift`, the shared types. Don't edit it. If you need a change, write it in
     `design/NEEDS.md`.
2. **Where to write:** only inside your own folders (see ARCHITECTURE "Module ownership"), plus your test file
   `SwoopTests/<Module>Tests.swift`.
3. **No compiler on our side.** CI (Xcode 27.1, iOS 27.1 SDK, Swift 5 language mode, iOS 18 deployment target) is the
   only compiler. Write conservative, boring Swift that compiles the first time:
   - **Type-check everything mentally:** explicit types on closures and numeric literals where inference could be
     ambiguous, and `CGFloat` vs `Double` conversions written out (`CGFloat(x)`, `Double(y)`).
   - **No force-unwraps** except on constant literals.
   - **No third-party packages. No APIs newer than iOS 18** unless they're behind `if #available(iOS 27.1, *)`; the
     hinge is the only such API.
   - **Concurrency:** anything touching UIKit, SwiftUI, SpriteKit, AVAudioEngine or Core Haptics is `@MainActor`.
     Core is not actor-isolated.
   - `Contracts.swift` declares the protocols `TuckSource`, `SceneDriver` and `FeedbackSink` as `@MainActor`.
   - **Watch Swift 6-style diagnostics that Xcode 27 may treat as errors**, even in Swift 5 mode: sendability of
     captured state in `@Sendable` closures, and calling main-actor methods from non-isolated contexts. When in doubt,
     mark the class `@MainActor` and keep callbacks on the main queue.
   - **Avoid name clashes:** every type name must be unique across the whole app target. Prefix private helpers
     with your module, e.g. `SceneSpray`, `FeelNoise`, `CoreSpline`, `AppStrings`.
4. **Reference code.** The sister game Brim lives at `C:\Users\59527\Fold`. Treat it as read-only.
   - It has a battle-tested hinge pipeline, demo mode, Game Center, audio synth, haptics, the UI shell and CI.
   - Copy and adapt freely. Rename every `Brim`/`BRIM` to `Swoop`/`SWOOP`, and Brim's types (`TiltSource`…) to
     Swoop's (`TuckSource`…).
5. **Tests:** use Swift Testing (`import Testing`, `@Test`, `#expect`) with `@testable import Swoop`. Make them pure
   and fast, with no sleeps.
6. **Hand-off:**
   - Don't `git commit`; the founder integrates and pushes.
   - When you're done, write `design/notes/<role>-R1.md`: what you built, the files, any deviations, any `NEEDS`, and
     what to tune on a real device. Keep it under 60 lines.
7. **Quality bar:** this is a paid game whose whole point is *feel*. Juice matters as much as correctness. Put the
   numbers in named constants with a comment, and keep them easy to tune.

## Demo mode (DEBUG and CI): the launch argument `-swoopDemo "key=value;key;…"`

The App engineer implements these keys, and the others may rely on them.

| key | meaning |
|---|---|
| `screen=home\|play\|results\|goals\|birds\|settings\|pose\|icon\|badges` | which screen to open (`play` is implied by `mode=`) |
| `mode=flight\|daily\|attract` | start that run at once |
| `seed=<n>` | the sea seed (deterministic frames) |
| `autopilot=novice\|casual\|expert\|perfect` | `FlightPilot` drives the tuck |
| `touch` | force touch input even on a Duo |
| `duo` | pretend the canvas has a fold (draw the crease and Duo layout on a regular simulator) |
| `mirror` | Bird on the other side |
| `skipCountdown` | start flying immediately |
| `freezeOn=launch\|perfect\|tailwind\|lighthouse\|stormclose\|caught\|finished\|flying` | pause the simulation 0.25 s after the first such event *after* `freezeAfter` s of flight (default 4); print `SWOOP-T freeze <x>` |
| `freezeAt=<s>` | freeze at that flight time, printing `SWOOP-T freeze time` |
| `progress=fresh\|mid\|late` | seeded progress (ranks, unlocked birds and skies, bests) |
| `bird=<BirdID>`, `sky=<SkyID>` | the cosmetics for this run |
| `best=<m>` | the personal best marker |
| `chain=<n>` | start with this Perfect chain (store frames) |
| `hints=fresh` | first-run hints on |
| `lead=<0…1>` | start with this storm gap (as a fraction of a full lead): store frames with the storm close |

**Log lines CI greps** (stdout, flushed, only when `-swoopDemo` is present):

| line | when |
|---|---|
| `SWOOP-T frame 120` | the scene has drawn 120 frames |
| `SWOOP-T canvas <W>x<H> fold=<0\|1> mirrored=<0\|1>` | on each layout |
| `SWOOP-T input hinge\|touch\|autopilot` | on each input source choice |
| `SWOOP-T event <name> …` | every FlightEvent, e.g. `SWOOP-T event touchdown perfect speed=1234 chain=3` |
| `SWOOP-T tuck <u> angle <θ>` | at most 4 per second while flying, from the hinge |
| `SWOOP-T paused closing` / `SWOOP-T resumed` | closing the Duo below 95° pauses; reopening resumes |
| `SWOOP-T freeze <x>` | a freeze took hold |
| `SWOOP-T run meters=<m> perfects=<n> seconds=<s>` | a run finished |
| `SWOOP-H <t> <angle>` | hinge samples (Input, at most 10/s) |
