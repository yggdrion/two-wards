# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

The PoC milestones M1–M5, M7 (full loop) and M8 (retro, `docs/RETRO.md`) are done; M6 (art) runs on the art track (A1 approved, A2 anchors in the game). Next is R1, the first real-game milestone from the retro: a pure sim core without the scene tree, and one Python script per tool instead of the `.sh`/`.ps1` twins (steps in `docs/PLAN.md`; R1a, the tooling, is in review). M3 is the meta system (save file, boosters, collection, deck builder); M3b (heroes) removes the field hero and adds two wizards (`HeroData` in `resources/heroes/`) with battlefield-wide buffs, picked in a hero select screen. M4 adds local co-op over ENet (`scripts/net/`: lockstep host/client, card commands, desync hashes; co-op screen in the camp; partner panel). M5 adds online play: the Bun lobby in `lobby/` (room codes, WebRTC signaling, coturn credentials), `LobbyClient` + `NetSession.host_online/join_online` over the pinned webrtc-native GDExtension, and `deploy/` (compose files for the gvm host, see `deploy/README.md`). M7 gives each player their own run deck, a 1-of-3 card reward after each wave (`RunRewards`), and the title, co-op lobby and run-end screens. The main scene is `scenes/main.tscn` (`App`: title and meta screens, then runs `scenes/game.tscn` with the active deck). Meta screens build their controls in code on `resources/ui/theme.tres`, so the art pass only swaps styleboxes. `docs/PLAN.md` is the source of truth for scope, architecture, card/meta numbers, style guide, testing and milestones; read it before starting work, together with `docs/HANDOFF.md` (current state, decisions and their reasons, working routine, PixelLab setup; reference mockups in `docs/art-reference/`). The plan's scope table is binding: anything listed as "out of scope" goes to a backlog, not into the PoC.

## Always run the local check

This applies to every session, human or Claude: GitHub CI runs on every push, and the local check catches the same failures before they cost a CI cycle.

- Before every push, run the full check, `python tools/check.py`, and push only when it ends with "All checks passed". If it fails, fix the cause and run it again; never push past a failure or use `git push --no-verify` to skip it.
- While iterating, run `python tools/check.py --quick` (lint and asset validator, no Godot) after each change to GDScript, assets or the manifest, and the gdUnit4 suite you touched (`python tools/run_tests.py -a res://tests/<suite>_test.gd`).
- In each PR description, say that the full check passed (test count) or what was not run and why.
- Playtest builds come from CI, but not on every push: exports (`two-wards-<platform>-<sha>` artifacts) only run for `v*` tags and manual runs. After a milestone or major step, start one on the branch (`gh workflow run ci.yml --ref <branch>`), and once it is green give Rapha the link to that run's page (its Artifacts section has the Windows build) and a short "what to try" list. Never build in the cloud container or on Rapha's PC for a playtest unless asked.

## Commands

Tooling: Godot 4.7.2 (GDScript), gdUnit4 v6.2.2, gdtoolkit 4.5.0, webrtc-native 1.2.2, Bun 1.4 (lobby), Python 3.12+ (tools).

    # Lobby (TypeScript on Bun, no runtime deps)
    cd lobby && bun install && bun test
    PORT=8080 bun lobby/src/server.ts      # local lobby; point the game at it with the
                                           # project setting two_wards/network/lobby_url

Every tool in `tools/` is one stdlib-only Python script, run as `python tools/<name>.py` on Linux and Windows alike (`py` on Windows works the same; no Git Bash needed). Shared bits (repo root, pinned versions, checked downloads, the Godot path) live in `tools/_common.py`.

First-time setup on a new machine (needs Python 3.12+ and git; safe to re-run): `python tools/setup.py`. It pip-installs `tools/requirements.txt` (gdtoolkit, pillow, pre-commit), the pinned Godot and gdUnit4, the pre-commit hook (asset validator) and the pre-push hook (full check), and runs the quick check.

The Godot version is pinned in `.godot-version`. `python tools/install.py [godot|gdunit4|webrtc|templates]` installs the pinned tools: `godot` (the default) downloads Godot to `.tools/godot/<version>/` (gitignored), checks it against `tools/godot-<version>.sha512` and prints the binary path; it also puts the pinned webrtc-native GDExtension into `game/addons/webrtc_native/` (gitignored, sha256 in `install.py`), so every Godot script, test and export has WebRTC. To bump Godot, change `.godot-version` and add the matching `.sha512` file with the lines from the release's `SHA512-SUMS.txt`.

    # Run the editor/game with the pinned Godot (installs on first use)
    python tools/godot.py --path game -e
    python tools/godot.py --path game

    # Tests (headless). Uses the pinned Godot (or GODOT_BIN, which must match), installs pinned
    # gdUnit4 into game/addons/gdUnit4 (gitignored), imports, runs res://tests.
    python tools/run_tests.py
    # Single suite: append gdUnit4 args
    python tools/run_tests.py -a res://tests/tower_test.gd

    # Release export (Linux or Windows) to build/<platform>/. Installs the pinned export
    # templates (checksum in tools/godot-<version>.sha512) on first use; only the two
    # release templates are extracted from the ~1.3 GB .tpz.
    python tools/export.py linux
    python tools/export.py windows

    # Lint and format check (if gdlint is not on PATH: python -m gdtoolkit.linter / .formatter)
    gdlint game/scripts game/tests game/tools
    gdformat --check game/scripts game/tests game/tools

    # Assets
    python tools/validate_assets.py                          # size, palette, transparency, naming, manifest
    python -m unittest discover -s tools -p "test_*.py"      # validator tests
    python tools/make_placeholders.py                        # redraw PNGs for manifest entries with status "placeholder"
    python tools/build_assets.py                             # rebuild game/resources/generated/*.tres

After adding or changing a PNG or a manifest entry, run the validator and `build_assets`, then commit the PNG, its `.import` file and the regenerated `.tres`. Never edit `game/resources/generated/` by hand.

Run the local check before pushing; it mirrors CI and stops at the first failure. `setup.py` installs it as a pre-push hook (`.pre-commit-config.yaml`, skip once: `git push --no-verify`):

    python tools/check.py            # lint, format, asset validator, gdUnit4 tests, network test, generated-asset drift
    python tools/check.py --quick    # lint + asset validator only, no Godot
    python tools/check.py --export   # also export Linux and Windows builds to build/

CI (`.github/workflows/ci.yml`) runs on every push to any branch (and by hand with "Run workflow"): lint and asset validation, gdUnit4 tests on Linux and Windows, the network test, lobby tests and container build. Linux and Windows exports (uploaded as artifacts) only run for `v*` tags and manual runs. Every job calls the same `python tools/<name>.py` scripts. The Linux test job also fails if `build_assets` changes anything under `game/`. Pushing a `v*` tag (`git tag v0.1.0 && git push origin v0.1.0`) also publishes a GitHub Release with the Windows build as a zip. The repo is meant to be public, so Actions minutes are free. Export presets live in `game/export_presets.cfg` (`Linux`, `Windows Desktop`). Commit the `*.gd.uid` files Godot generates next to scripts.

The headless network test (`python tools/run_network_test.py [scenario.json ...]`) starts a host and a client Godot (`game/tools/net_test.gd`) over ENet on localhost for every scenario in `game/tests/scenarios/`, then one co-op scenario over WebRTC through a local lobby (needs `bun`; skipped locally without it, required in CI), and fails on any per-wave hash mismatch; the local check and CI run it. New co-op scenarios can be recorded with a bot: `godot --headless --path game --script res://tools/record_scenario.gd -- --in=<draft.json> --out=<file.json>`.

## Code conventions

- Simulation advances only through explicit `step(delta)` / `Sim.tick(delta)` calls, never real time inside logic. Tests build a `Sim` directly (configure it, `start()`, tick with a fixed delta), no scene tree; the co-op host (`LockstepHost`) drives the same path, and every card action goes through `NetCommand.apply`.
- The sim (`scripts/sim/`: `Sim`, `SimEnemy`, `SimTower`, `SimCrystal`) is plain `RefCounted`: no `Node`, `get_tree`, `queue_free` or `add_child` there. `Lane` and the `Enemy`/`Tower`/`HeartCrystal` views in `scripts/lane/` only read it and react to its presentation signals; nothing in a view feeds back into the sim. Configure `lane.sim` before the lane enters the tree; card effects reach the sim through `CardContext.sim`.
- Gray-box drawing uses `_draw()` with colors from `scripts/palette.gd` (Endesga 32 only) until M6 replaces it with art.
- Test files live in `game/tests/` and are named `*_test.gd`.

## What this is

Two Wards: a real-time 2-player co-op tower defense roguelite with a card deck. The PoC's real deliverable is the pipeline (Godot structure, AI-assisted coding, tests, AI assets, networking, build/deploy), not the game.

## Planned layout

    game/          Godot project: scenes/, scripts/{data,sim,lane}/, resources/, tests/
    lobby/         Lobby/signaling server (TypeScript on Bun) + tests + Dockerfile
    deploy/        server stack (lobby, coturn, vector) run from a clone on the gvm host
    assets-src/    Aseprite sources, palette, anchors
    tools/         Asset validation, import scripts, prompt templates
    docs/          Style guide, design notes, plan

## Architecture rules

- **Data-driven content.** Cards, units, waves and heroes are `Resource` files (`CardData`, `UnitData`, `WaveData`, `HeroData`). A simple new card must be one `.tres` + art, no code change. Card behaviour is a list of effect resources on `CardData`; `ScriptedEffect` is the escape hatch for odd cards (Time Warp, Mirror Image).
- **Host-authoritative netcode.** Host simulates enemies/towers and validates plays; clients send inputs and card events only. There is no continuous sync: heroes (wizards) are not on the field and only give battlefield buffs, so card events with a target point are the only player input.
- **Transport abstraction.** `NetSession` connects over ENet (`host`/`join`: LAN, tests) or WebRTC through the lobby (`host_online`/`join_online`); after that everything is the same `MultiplayerPeer`. Keep gameplay code transport-agnostic.
- **Lobby never sees gameplay.** It only does room codes and WebRTC signaling; rooms expire once the game starts. coturn provides STUN/TURN.
- **Desync detection.** Host and client hash game state at the end of each wave; the headless network test fails on mismatch.
- **Saves.** Local JSON per profile with a version field; load runs a migration keyed on that version.
- **Cards are composed at runtime** (rarity frame + 128×96 art + text in a pixel font). Never bake numbers into art.

## Asset rules

Every PNG under `game/assets/` must pass `tools/validate_assets.py` (pre-commit + CI): Endesga 32 palette only, alpha 0 or 255, base resolution 640×360, per-frame sizes units 64×64 / tiles 32×32 / card art 128×96 / icons 32×32 / towers 48×72 / props sized per manifest entry, units as horizontal strips of frames, directions `down`/`up`/`side` (left = `flip_h`), and naming `units/<name>/unit_<name>_<anim>_<dir>.png`, `tiles/<set>/tile_<set>_<nn>.png`, `cards/card_art_<id>.png`, `icons/icon_<name>.png`, `towers/tower_<id>.png`, `props/prop_<name>.png`. Ground tiles are a 16-tile Wang set: `tile_base_<nn>` with nn = the corner bits NW NE SW SE (1 = path) read as binary; `Lane` picks them from the path (`resources/maps/lane_01_path.tres`). Every PNG needs an entry in `game/assets/manifest.json`, which also holds frame counts, fps and loop. Full style guide in `docs/STYLE_GUIDE.md` (summary table in `docs/PLAN.md`).
