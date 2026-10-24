# Two Wards PoC retro (M8)

Drafted 2026-10-23, closed 2026-10-24. Facts come from git, GitHub and the code; lines marked **Rapha:** are Rapha's answers. The exit criterion is a go/no-go and an approach for the full game.

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

**Rapha:** under 4 hours of hands-on time over the whole PoC, mostly steering and playtesting.

## Pillars

### 1. Godot project structure

- Worked: data-driven content held. 10 of 12 cards are pure `.tres` effect lists; the two scripted ones are the two the plan predicted. Meta screens built in code on one theme, so the art pass only swaps styleboxes.
- Worked: the Node-based sim (decided at the M4 checkpoint) was enough for lockstep; scenarios replay to identical hashes.
- Open: the plan deferred "pure sim core vs Node sim" to this retro.
- **Rapha:** split out a pure sim core for the real game.

### 2. AI-assisted coding

- Worked: every milestone landed as one PR, most within an hour of opening, all with tests.
- Hurt: plan churn after playtests (hero redesign #12, fullscreen/field #11) — cheap to redo, but it came from playing, not from the plan.
- **Rapha:** stepped in only with playtest feedback (hero redesign, fullscreen). The routine (CLAUDE.md, HANDOFF, plan-first PRs) worked; keep it.

### 3. Automated testing

- Worked: fixed-delta `Lane.tick` and seeded decks make the sim fully deterministic; scenario tests double as network tests.
- Worked: the local check (`tools/check.sh`, #13) arrived after a run of red CI on 10-22; after it, CI went red only once.
- Hurt: timed reward picks broke under client lag, so runners take the first card at once (`Scenario.reward_pick`). UI and screens are only playtested, not tested.
- **Rapha:** no bug reached a playtest that a test should have caught; playtest findings were design and feel.

### 4. AI asset generation

- Partly proven: validator, manifest, placeholder generator and `build_assets` run in CI; first PixelLab hero frames came back on-palette with clean alpha.
- A1 on the free trial (#21): goblin runner, Heart Crystal, arrow tower and a grass/path Wang tileset composed into a target frame in Godot. Pixflux with `direction: east` gave a usable side view where `rotate` had not. Tilesets cost several generations each, charged late; 14 of 40 left.
- Not proven: no bulk generation, no animation strips, no card art.
- **Rapha:** decide the real game's art route after A1/M6, once bulk generation is proven.

### 5. Online co-op networking

- Worked: ENet lockstep (M4) and WebRTC via the Bun lobby and coturn (M5) share one `MultiplayerPeer` path; two-network playtest passed; per-wave desync hashes in CI.
- Hurt / missing: no reconnect, no host migration (both out of scope).
- **Rapha:** lockstep with host-as-clock is good enough for the real game's latency feel.

### 6. Build and deploy

- Worked: CI exports Linux and Windows on every push, artifacts used for every playtest; pinned Godot, gdUnit4, webrtc-native with checksums; every tool has a `.ps1` twin.
- Worked: the server stack runs from a repo clone on the gvm host with one Caddyfile block.
- Hurt: PowerShell 5.1 quirks (#17); keeping `.sh`/`.ps1` twins in sync is ongoing cost.
- **Rapha:** move tooling to Python, one cross-platform script per tool instead of `.sh`/`.ps1` twins.

## Decisions for the real game

- Go / no-go: go, confirmed once M6 proves bulk art generation.
- Engine and sim structure: Godot 4 and GDScript stay; split the simulation into a pure core (no scene tree) that the Node layer renders.
- Netcode: keep host-authoritative lockstep with the host as clock, card events only.
- Art route: decided after M6 (PixelLab pixel art is the working assumption).
- Scope of the first real milestone: pure sim core split plus tooling moved to Python, running beside the M6 art track.
