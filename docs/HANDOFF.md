# Handoff

Everything a new session (human or Claude) needs to pick up Two Wards without the original Claude project. It collects the decisions, routines and state that used to live only in project notes. `docs/PLAN.md` stays the source of truth for scope, architecture and milestones; this file adds the "why" and the working habits around it.

Last updated: 2026-10-24, after the M8 retro (PR #22) was closed.

## Where things stand

| Milestone | State | PR |
|---|---|---|
| M1 Skeleton | Done | #2, CI #3 |
| Asset pipeline | Done | #4 |
| 640×360 switch + style guide | Done | #6 |
| M2 In-run cards | Done | #7 (font #8) |
| M3 Meta system | Done | #10 |
| Screen layout (slim bar, fullscreen) | Done | #11 |
| Local check script | Done | #13 |
| M3b Heroes | Done | #14 |
| M4 Local co-op over ENet | Done, merged 2026-10-23 | #15 |
| M5 Lobby + WebRTC | Done, merged 2026-10-23; two-network playtest passed | #18 |
| M7 Full loop | Done, merged 2026-10-23; two-person playtest passed | #20 |
| A1 Look target (art track) | Approved 2026-10-24 (`art-reference/target-frame/a1_v1.png`); PixelLab upgraded | #21 |
| A2 step 1: anchors in the game | Open: lane on the tile grid, Wang ground, dusk and lights, sprites for goblin runner, arrow tower, crystal | #25 |
| Release on `v*` tags | Done | #23 |
| M8 Retro | Done: go once M6 proves bulk art; first real-game milestone is the pure sim core plus Python tooling (`docs/RETRO.md`) | #22 |
| R1 plan (sim core + Python tooling) | Plan-only PR open; R1a tooling and R1b sim core follow as two PRs | — |

Plan-only PRs: #1 (CLAUDE.md, rename), #5 (revised plan), #9 (full pixel-art route), #12 (hero redesign).

## How we work

- **Rapha** owns the project and develops on Windows. Every script in `tools/` has a `.ps1` twin; keep them in sync.
- **New machine**: run `./tools/setup.sh` (Windows `.\tools\setup.ps1`) once; it installs everything the check needs.
- **Local check before every push**: `./tools/check.sh` (Windows `.\tools\check.ps1`), push only on "All checks passed", never `--no-verify`. Use `--quick` while iterating. Say in each PR that the full check passed (with the test count).
- **CI does all builds.** The repo is public (since 2026-10-23), so Actions minutes are free. Every push runs lint, Linux and Windows tests, the network test and both exports, and uploads `two-wards-<platform>-<sha>` artifacts. Don't build in a cloud container or on Rapha's PC for a playtest unless asked; don't attach executables.
- **Playtest after each milestone.** When a milestone or major step is ready, give Rapha the link to the green CI run (its Artifacts section has the Windows build) plus a short "what to try" list, and wait for their OK before merging. Docs-only changes need no playtest.
- **Ask before opening a PR or merging** unless Rapha already said to.
- **Hand-added files**: when Rapha adds a PNG or font by hand, its Godot `.import` file must be committed too, or CI goes red.
- **No secrets in the repo.** It is public.

## Decisions and why

### Goal (2026-10-22)

The PoC's real deliverable is the pipeline (project structure, AI coding, tests, AI assets, WebRTC co-op with a self-hosted lobby, build/deploy). On top of that, Rapha decided the game must end up a pretty, polished pixel-art game: full art route, no gray box left at the end. The art track A1–A4 runs beside M3–M7, and M6 became "Art and juice" (PR #9).

### Plan revision (PR #5)

- Keep scope; optimize for a solid foundation rather than cutting or reordering.
- Card effects are hybrid: composable effect resources on `CardData` plus a `ScriptedEffect` escape hatch (Time Warp, Mirror Image).
- Scenario tests (seed, deck, timed plays, N waves, asserted hash); the network test replays them.
- WebRTC stays at M5 with no early spike.

### Art direction (2026-10-22)

- Rapha found the first four code-drawn looks (`art-reference/art-direction/look_*.png`) "really ugly". The pick is **`art-reference/art-direction/evening_a_lit.png`**: natural, realistic ground (grass, dirt path, stone, trees, rocks), storybook-like but not too bright, in evening light with a little magic glow. The crystal and towers cast pools of light with Godot 2D lights. `evening_b_late_afternoon.png` was the brighter, unlit alternative.
- The final art must be more pixel-y and more detailed than these mockups.
- Check that goblins don't blend into the grass; shift them toward olive if needed.
- A1 starts with the PixelLab upgrade and ends with one 640×360 target frame Rapha approves before bulk generation.

### Screen layout (PR #11)

Layout A, the slim bottom bar: field 640×288, HUD bar 72 px with mini cards (96×64); the full card shows on hover. Fullscreen uses integer scaling (F11, Alt+Enter, or the camp button), saved in `user://settings.cfg`. Mockups in `art-reference/screen-layout/`.

### Hero redesign (PR #12, built in #14)

After the M3 playtest Rapha asked what the field hero was for (nothing targets it, walking felt like a tax). Decision: no wizard avatar on the field. Players click anywhere off the path to build and cast. Two wizards each give a passive battlefield-wide buff: **Frost** (enemies 15% slower) and **Ember** (towers +20% damage). Buffs stack (two Frost = 30%), enemies never drop below 10% speed. Hero select is in the camp and saved in the profile. Wizards only appear as portraits (hero select, partner panel). Empower replaces Blink; War Drums targets a clicked point. No hero position sync in the netcode. Hero classes (heroes limited to certain cards) are in the backlog.

The `art-reference/hero/` images are the first PixelLab hero frames from before the redesign. They are kept as a style reference (Frost's placeholder portrait is the idle-down frame).

### M4 netcode (PR #15)

Rapha kept the Node-based sim (no pure sim core). Lockstep with the host as the clock: `LockstepHost.step()` applies queued `NetCommand`s and ticks, frames go to the client, `LockstepClient` replays. Hashes after each wave and at the end; the headless network test fails on mismatch. Card passing costs 1 energy and lands in the partner's 4th gift slot (max one); the partner panel is bottom-left (click it or press E). Save v3 adds `player_name`; `--profile=<name>` runs two copies on one PC. ENet by address and port; M5 added the online path next to it.

## Asset pipeline and PixelLab

- Flow: PixelLab generates, Aseprite cleans up, `tools/validate_assets.py` enforces, `build_assets` writes the Godot resources. Full write-up in [ASSET_PIPELINE.md](ASSET_PIPELINE.md), style rules in [STYLE_GUIDE.md](STYLE_GUIDE.md).
- Rapha has a PixelLab account; Claude drives the API. The key is **never** in the repo or in chat. In Claude Code cloud sessions it is a cloud-environment network secret (Bearer header, allowed host exactly `api.pixellab.ai`) that the proxy injects, so calls go out without any key. Anywhere else, set it up the same way or keep it in a local, untracked env var.
- Working settings for the hero anchor: `POST /v2/create-image-pixflux`, 64×64, `no_background`, `color_image` = an Endesga 32 swatch for the unit, outline "single color black outline", shading "medium", view "high top-down", seed 1337. Output came back on-palette with 0/255 alpha. `POST /v2/rotate` gave a good north view but no true side profile, and it ignores `color_image` (snap the output to Endesga). The trial allows one job at a time (429 otherwise); use long timeouts (`curl -m 300`); a call that ended in a proxy 502 still cost a generation. Raw outputs are in `assets-src/units/hero/pixellab/`.
- Budget: trial, 14 of 40 generations left after #21 (2026-10-23). Rapha upgrades to a paid plan when A1 starts, so cost isn't a hard limit on quality, but ask before spending generations.

### M5 online co-op

- **Hosting**: no Kubernetes. Rapha's existing gvm box (`grafana.r4b2.de`, Hetzner, already runs Caddy, VictoriaMetrics, Grafana and vector) hosts the server stack, but Rapha wants it to stay in this repo and gvm untouched: `/root/two-wards` is a clone, `deploy/docker-compose.yml` builds the lobby from source and brings its own vector (remote-writes to `vm.r4b2.de`). The only gvm change is one Caddyfile block: gvm's Caddy terminates TLS for `twowards.r4b2.de` and proxies to the lobby, which joins `gvm_default` (a separate Caddy would have needed a Cloudflare token for a DNS challenge, since gvm has 80/443). Dashboard "Two Wards server" on grafana.r4b2.de. `twowards.r4b2.de` points at the host without Cloudflare proxy (TURN is UDP). The Hetzner firewall already lets 3478 and the relay range through (tested from outside). Steps in [deploy/README.md](../deploy/README.md).
- **Lobby** (`lobby/`, Bun, no runtime deps): 4-letter room codes, relays WebRTC offer/answer/candidates verbatim, mints time-limited coturn credentials (REST scheme, `TURN_SECRET` only on the host). Rooms end once the peers report `connected` or after 10 minutes. Its `PROTOCOL` must match `LobbyClient.PROTOCOL` (the signaling format); game messages have their own `NetSession.PROTOCOL`, checked by the host on hello, so a game-only change needs no lobby redeploy.
- **Game**: `LobbyClient` hands its `WebRTCMultiplayerPeer` to `NetSession` at once, so the existing hello/start handshake and lockstep run unchanged. The co-op screen has "Host online" / "Join code" and keeps the M4 LAN row as the fallback. The old `two_wards/network/transport` setting is gone; `two_wards/network/lobby_url` points at a different lobby.
- **WebRTC** comes from the pinned webrtc-native GDExtension, installed by `install_godot` into `game/addons/webrtc_native/` (gitignored), so it ships in every export.

### M7 full loop

- **Own decks** (Rapha, 2026-10-23): no shared run deck. Each player draws from their own deck (`Lane.decks`, one `Deck` per player seeded `rng_seed + i`). A passed card still goes to the partner's gift slot, but returns to its owner's discard once played or cycled (`PlayerState.gift_owner`).
- **Card reward**: after every cleared wave but the last, `RunRewards` offers each player 3 different cards from the whole catalog, rarity rolled with the booster odds from its own seeded RNG. The pick is a `reward` `NetCommand` and goes into the picker's discard pile. The break timer only runs once every offer is answered. In-run: the offer shows as full cards over the field, click or 1–3. Scenario files turn rewards on with `"rewards": true`; every runner (scenario test, lockstep test, network test, recorder) then takes the first card of each offer as soon as it opens (`Scenario.reward_pick`), because timed pick actions break as soon as client lag shifts a wave's end.
- **Screens**: the game opens on a title screen (play, fullscreen, quit). Co-op: once connected both players go to the lobby screen (names, wizards, deck lists); the client presses Ready, the host's Start unlocks. Game `NetSession.PROTOCOL` is 2; the lobby's stays 1. After a run, the run-end screen shows the result, waves and gold, with "Open a booster" (at 50 gold) or "Camp".

## Next

Two tracks side by side. Real game, first milestone R1 (from the M8 retro, steps in `docs/PLAN.md`): R1a replaces the `.sh`/`.ps1` tool twins with one Python script per tool; R1b splits the simulation into a pure `Sim` without the scene tree that `Lane` renders, with the four pinned scenario hashes unchanged. M6 (art and juice): A1 is approved and the anchors are in the game (`art-reference/a2/run_anchors.png`). Data drives the art: `UnitData.frames` and `TowerData.sprite` switch a unit or tower from gray box to sprite, so each new asset is a PNG, a manifest entry and one line in its `.tres`. The goblin runner's `walk_side` is the anchor frame with a 1 px bob; all directions use it until PixelLab animates it. Next is bulk generation (goblin walk cycles in 3 directions, brute, frost totem, ballista, storm spire, props such as trees and rocks), then particles and juice. Generation needs the PixelLab key: a cloud session with the network secret, or a local untracked env var. Card art and HUD skin are A3.

## Reference images

`docs/art-reference/` holds the mockups and screenshots made during the project. It lives outside the Godot project (`game/`), so Godot never imports it and the asset validator (which only checks `game/assets/`) ignores it.

| Folder | What |
|---|---|
| `art-direction/` | Look mockups. **`evening_a_lit.png` is the approved look.** `mockup_v2.py` is the generator (`python mockup_v2.py <out_dir> <hero.png>`) |
| `hero/` | First PixelLab hero frames (32×32 v1 and 64×64), upscaled previews, in-lane previews |
| `m1/` | M1 gray-box lane |
| `m2/` | M2 run screen, before and after the m5x7 font |
| `screen-layout/` | Layout options (A, the slim bar, was picked) and the result in game |
| `m3b/` | Camp, hero select and run after M3b |
