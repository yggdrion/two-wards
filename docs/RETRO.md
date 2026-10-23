# Two Wards PoC retro (M8)

Draft, 2026-10-23. Facts are filled in from git, GitHub and the code; lines marked **Rapha:** are open until Rapha answers them. The exit criterion is a go/no-go and an approach for the full game.

## Numbers

| | |
| --- | --- |
| Calendar time | 2026-10-22 16:31 → 2026-10-23 16:08, about 24 h wall clock, 20 merged PRs |
| Code | 4,631 lines of GDScript in `game/scripts`, 2,115 lines of tests, 403 lines of lobby TypeScript |
| Tests | 172 gdUnit4 tests in 23 suites, 4 co-op scenarios, 9 lobby tests |
| CI | 71 runs, 64 green, 7 red (6 on feature branches, 1 on `main` on 2026-10-22 before the local check existed) |
| Cards | 12, of which 2 (Time Warp, Mirror Image) need the `ScriptedEffect` escape hatch, as planned |
| Milestones | M1–M5, M3b, M7 done; M6 (art) started on the free PixelLab trial: A1 target frame in #21, awaiting approval |

PR timeline (open → merge):

| Milestone | PR | Opened | Lines |
| --- | --- | --- | --- |
| M1 skeleton, CI | #2, #3 | 10-22 18:35 | +1.4k |
| Asset pipeline | #4, #6 | 10-22 19:03 | +2.8k |
| M2 cards | #7 | 10-22 20:34 | +3.2k |
| M3 meta | #10 | 10-22 21:41 | +1.6k |
| M3b heroes | #14 | 10-22 23:19 | +0.6k |
| M4 ENet co-op | #15 | 10-23 08:58 | +1.9k |
| M5 lobby + WebRTC | #18 | 10-23 13:44 | +1.5k |
| M7 full loop | #20 | 10-23 15:25 | +0.8k |

**Rapha:** hands-on time (your own hours, not wall clock), and how much of it went to playtesting vs reviewing vs steering.

## Pillars

### 1. Godot project structure

- Worked: data-driven content held. 10 of 12 cards are pure `.tres` effect lists; the two scripted ones are the two the plan predicted. Meta screens built in code on one theme, so the art pass only swaps styleboxes.
- Worked: the Node-based sim (decided at the M4 checkpoint) was enough for lockstep; scenarios replay to identical hashes.
- Open: the plan deferred "pure sim core vs Node sim" to this retro.
- **Rapha:** keep the Node sim for the real game, or split out a pure core?

### 2. AI-assisted coding

- Worked: every milestone landed as one PR, most within an hour of opening, all with tests.
- Hurt: plan churn after playtests (hero redesign #12, fullscreen/field #11) — cheap to redo, but it came from playing, not from the plan.
- **Rapha:** where did you have to step in or redo work? What would you change about the working routine (CLAUDE.md, HANDOFF, plan-first PRs)?

### 3. Automated testing

- Worked: fixed-delta `Lane.tick` and seeded decks make the sim fully deterministic; scenario tests double as network tests.
- Worked: the local check (`tools/check.sh`, #13) arrived after a run of red CI on 10-22; after it, CI went red only once.
- Hurt: timed reward picks broke under client lag, so runners take the first card at once (`Scenario.reward_pick`). UI and screens are only playtested, not tested.
- **Rapha:** did any bug reach a playtest that a test should have caught?

### 4. AI asset generation

- Partly proven: validator, manifest, placeholder generator and `build_assets` run in CI; first PixelLab hero frames came back on-palette with clean alpha.
- A1 on the free trial (#21): goblin runner, Heart Crystal, arrow tower and a grass/path Wang tileset composed into a target frame in Godot. Pixflux with `direction: east` gave a usable side view where `rotate` had not. Tilesets cost several generations each, charged late; 14 of 40 left.
- Not proven: no bulk generation, no animation strips, no card art.
- **Rapha:** decide the real game's art route only after A1, or now?

### 5. Online co-op networking

- Worked: ENet lockstep (M4) and WebRTC via the Bun lobby and coturn (M5) share one `MultiplayerPeer` path; two-network playtest passed; per-wave desync hashes in CI.
- Hurt / missing: no reconnect, no host migration (both out of scope).
- **Rapha:** is lockstep with host-as-clock good enough for the real game's latency feel?

### 6. Build and deploy

- Worked: CI exports Linux and Windows on every push, artifacts used for every playtest; pinned Godot, gdUnit4, webrtc-native with checksums; every tool has a `.ps1` twin.
- Worked: the server stack runs from a repo clone on the gvm host with one Caddyfile block.
- Hurt: PowerShell 5.1 quirks (#17); keeping `.sh`/`.ps1` twins in sync is ongoing cost.
- **Rapha:** keep the twin scripts, or move tooling to one language (Python or Bun)?

## Decisions for the real game

**Rapha:** to fill in.

- Go / no-go:
- Engine and sim structure:
- Netcode:
- Art route:
- Scope of the first real milestone:
