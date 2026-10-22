# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

M1 (Skeleton) is in progress: Godot project in `game/` with a gray-box lane, one goblin, one tower, gdUnit4 tests and CI. `docs/PLAN.md` is the source of truth for scope, architecture, card/meta numbers, style guide, testing and milestones; read it before starting work. Its scope table is binding: anything listed as "out of scope" goes to a backlog, not into the PoC.

## Commands

Tooling: Godot 4.7.2 (GDScript), gdUnit4 v6.2.2, gdtoolkit 4.5.0. Planned later: `bun test` for the lobby.

    # Tests (headless). Installs pinned gdUnit4 into game/addons/gdUnit4 (gitignored), imports, runs res://tests.
    GODOT_BIN=/path/to/godot ./tools/run_tests.sh
    # Single suite: append gdUnit4 args, e.g. -a res://tests/tower_test.gd
    GODOT_BIN=/path/to/godot ./tools/run_tests.sh -a res://tests/tower_test.gd

    # Lint and format check (pip install "gdtoolkit==4.5.0")
    gdlint game/scripts game/tests
    gdformat --check game/scripts game/tests

    # Run the game
    godot --path game

CI (`.github/workflows/ci.yml`) runs lint and the tests on every push. Commit the `*.gd.uid` files Godot generates next to scripts.

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

- **Data-driven content.** Cards, units and waves are `Resource` files (`CardData`, `UnitData`, `WaveData`). A simple new card must be one `.tres` + art, no code change.
- **Host-authoritative netcode.** Host simulates enemies/towers and validates plays; clients send inputs and card events only. Hero positions are the only continuous sync.
- **Transport abstraction.** One setting switches ENet (local dev, tests) and WebRTC (online). Keep gameplay code transport-agnostic.
- **Lobby never sees gameplay.** It only does room codes and WebRTC signaling; rooms expire once the game starts. coturn provides STUN/TURN.
- **Desync detection.** Host and client hash game state at the end of each wave; the headless network test fails on mismatch.
- **Saves.** Local JSON per profile with a version field; load runs a migration keyed on that version.
- **Cards are composed at runtime** (rarity frame + 64×48 art + text in a pixel font). Never bake numbers into art.

## Asset rules

Every PNG must pass the validation script (pre-commit + CI): Endesga 32 palette only, sizes units 32×32 / tiles 16×16 / card art 64×48 / icons 16×16, transparency, and naming `unit_<name>_<anim>_<dir>.png`, `tile_<set>_<nn>.png`, `card_art_<id>.png`. Full style guide in `docs/PLAN.md`.
