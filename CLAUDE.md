# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

Planning only — no code yet. Next milestone is M1 (Skeleton). `docs/PLAN.md` is the source of truth for scope, architecture, card/meta numbers, style guide, testing and milestones; read it before starting work. Its scope table is binding: anything listed as "out of scope" goes to a backlog, not into the PoC.

There are no build, lint or test commands yet. When M1 adds them, document them here. Planned tooling: Godot 4.7.2 (GDScript), gdUnit4, gdtoolkit lint, `bun test` for the lobby, GitHub Actions CI.

## What this is

Two Wards: a real-time 2-player co-op tower defense roguelite with a card deck. The PoC's real deliverable is the pipeline (Godot structure, AI-assisted coding, tests, AI assets, networking, build/deploy), not the game.

## Planned layout

    game/          Godot project (scenes, scripts, resources, tests)
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
