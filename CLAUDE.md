# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

M1 (Skeleton) is in progress: Godot project in `game/` with a gray-box lane, one goblin, one tower, gdUnit4 tests and CI. `docs/PLAN.md` is the source of truth for scope, architecture, card/meta numbers, style guide, testing and milestones; read it before starting work. Its scope table is binding: anything listed as "out of scope" goes to a backlog, not into the PoC.

## Commands

Tooling: Godot 4.7.2 (GDScript), gdUnit4 v6.2.2, gdtoolkit 4.5.0. Planned later: `bun test` for the lobby.

The Godot version is pinned in `.godot-version`. `tools/install_godot.sh` downloads it to `.tools/godot/<version>/` (gitignored), checks it against `tools/godot-<version>.sha512` and prints the binary path. To bump Godot, change `.godot-version` and add the matching `.sha512` file with the lines from the release's `SHA512-SUMS.txt`.

    # Run the editor/game with the pinned Godot (installs on first use)
    ./tools/godot.sh --path game -e
    ./tools/godot.sh --path game

    # Tests (headless). Uses the pinned Godot (or GODOT_BIN, which must match), installs pinned
    # gdUnit4 into game/addons/gdUnit4 (gitignored), imports, runs res://tests.
    ./tools/run_tests.sh
    # Single suite: append gdUnit4 args
    ./tools/run_tests.sh -a res://tests/tower_test.gd

    # Release export (Linux or Windows) to build/<platform>/. Installs the pinned export
    # templates (checksum in tools/godot-<version>.sha512) on first use; only the two
    # release templates are extracted from the ~1.3 GB .tpz.
    ./tools/export.sh linux
    ./tools/export.sh windows

Every script in `tools/` has a PowerShell twin (`.ps1`) for Windows; keep both in sync. CI runs the tests with the `.sh` scripts on Linux and the `.ps1` scripts on Windows.

    # Windows (PowerShell 5.1 or 7). If scripts are blocked, prefix with: powershell -ExecutionPolicy Bypass -File
    .\tools\godot.ps1 --path game -e
    .\tools\run_tests.ps1
    .\tools\run_tests.ps1 -a res://tests/tower_test.gd
    .\tools\export.ps1 windows

    # Lint and format check (pip install "gdtoolkit==4.5.0")
    gdlint game/scripts game/tests game/tools
    gdformat --check game/scripts game/tests game/tools

    # Assets (pip install -r tools/requirements.txt). Python scripts work the same on Windows (use `py`).
    python tools/validate_assets.py                          # size, palette, transparency, naming, manifest
    python -m unittest discover -s tools -p "test_*.py"      # validator tests
    python tools/make_placeholders.py                        # redraw PNGs for manifest entries with status "placeholder"
    ./tools/build_assets.sh                                  # rebuild game/resources/generated/*.tres (.ps1 on Windows)
    pre-commit install                                       # run the validator on every commit

After adding or changing a PNG or a manifest entry, run the validator and `build_assets`, then commit the PNG, its `.import` file and the regenerated `.tres`. Never edit `game/resources/generated/` by hand.

CI (`.github/workflows/ci.yml`) runs on every push: lint, the tests (Linux and Windows), and a Linux export (`export.sh`) plus a Windows export (`export.ps1` on a Windows runner). Builds are uploaded as artifacts only from `main` or manual runs. Export presets live in `game/export_presets.cfg` (`Linux`, `Windows Desktop`). Commit the `*.gd.uid` files Godot generates next to scripts.

Some CI jobs stay off until their entry point exists:

- `tools/run_network_test.sh`: headless host + client over ENet, exit non-zero on a per-wave hash mismatch (M4)
- `lobby/package.json` (+ `bun.lock`, `Dockerfile`): `bun test` and the container build (M5)
- `tools/validate_assets.py`: asset validation and its unittest suite in the lint job (active since the asset pipeline landed); the Linux test job also fails if `build_assets` changes anything under `game/`

## Code conventions

- Simulation advances only through explicit `step(delta)` / `Lane.tick(delta)` calls, never real time inside logic. Tests set `lane.autorun = false` and tick with a fixed delta; the network host will drive the same path.
- Gray-box drawing uses `_draw()` with colors from `scripts/palette.gd` (Endesga 32 only) until M6 replaces it with art.
- Test files live in `game/tests/` and are named `*_test.gd`.

## What this is

Two Wards: a real-time 2-player co-op tower defense roguelite with a card deck. The PoC's real deliverable is the pipeline (Godot structure, AI-assisted coding, tests, AI assets, networking, build/deploy), not the game.

## Planned layout

    game/          Godot project: scenes/, scripts/{data,lane}/, resources/, tests/
    lobby/         Lobby/signaling server (TypeScript on Bun) + tests + Dockerfile
    deploy/        Kubernetes manifests: lobby, coturn, monitoring config
    assets-src/    Aseprite sources, palette, anchors
    tools/         Asset validation, import scripts, prompt templates
    docs/          Style guide, design notes, plan

## Architecture rules

- **Data-driven content.** Cards, units and waves are `Resource` files (`CardData`, `UnitData`, `WaveData`). A simple new card must be one `.tres` + art, no code change. Card behaviour is a list of effect resources on `CardData`; `ScriptedEffect` is the escape hatch for odd cards (Time Warp, Mirror Image).
- **Host-authoritative netcode.** Host simulates enemies/towers and validates plays; clients send inputs and card events only. Hero positions are the only continuous sync. Each client owns its own hero position; the host checks plausibility and validates tower placement against it.
- **Transport abstraction.** One setting switches ENet (local dev, tests) and WebRTC (online). Keep gameplay code transport-agnostic.
- **Lobby never sees gameplay.** It only does room codes and WebRTC signaling; rooms expire once the game starts. coturn provides STUN/TURN.
- **Desync detection.** Host and client hash game state at the end of each wave; the headless network test fails on mismatch.
- **Saves.** Local JSON per profile with a version field; load runs a migration keyed on that version.
- **Cards are composed at runtime** (rarity frame + 64×48 art + text in a pixel font). Never bake numbers into art.

## Asset rules

Every PNG under `game/assets/` must pass `tools/validate_assets.py` (pre-commit + CI): Endesga 32 palette only, alpha 0 or 255, per-frame sizes units 32×32 / tiles 16×16 / card art 64×48 / icons 16×16, units as horizontal strips of frames, directions `down`/`up`/`side` (left = `flip_h`), and naming `units/<name>/unit_<name>_<anim>_<dir>.png`, `tiles/<set>/tile_<set>_<nn>.png`, `cards/card_art_<id>.png`, `icons/icon_<name>.png`. Every PNG needs an entry in `game/assets/manifest.json`, which also holds frame counts, fps and loop. Full style guide in `docs/PLAN.md`.
