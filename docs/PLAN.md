# Two Wards PoC – Project Plan

Oct 22, 2026 · @Rapha

## Goal

The PoC proves that one person with AI tooling can build, test, network and ship a small co-op card game in Godot. The game is deliberately tiny; the pipeline behind it is the actual deliverable.

It validates six pillars end to end: Godot project structure, AI-assisted coding, automated testing, AI asset generation, online co-op networking, and build/deploy. The output is a playable full loop plus a retro that decides how the real game gets built.

## Game concept

A real-time co-op tower defense roguelite in a **dark-fantasy** setting, where towers, spells and hero abilities come from a shared card deck. Title: **Two Wards** — two wizards defend a Heart Crystal against waves of monsters.

- **In a run:** each player moves a hero, gains energy over time, and plays cards from a hand of 3. Towers can only be placed near your own hero.
- **Co-op:** both players bring their own 8-card deck; the decks merge into one shared run deck. Cards can be passed to the partner.
- **Between waves:** a short break and a card reward added to the run deck.
- **Meta:** runs earn gold, gold buys boosters, boosters grow the collection, the collection feeds the deck builder.

## Scope

The PoC is one map, two players, twelve cards and one full meta loop. Anything not needed to exercise a pillar is cut.

| Area | In scope | Out of scope (later) |
| --- | --- | --- |
| Map | 1 map, 1 lane, spawn → core | Multiple lanes, branching run map, map variety |
| Players | 2 players online co-op, host-authoritative | 3–4 players, host migration, dedicated servers |
| Units | 1 hero (idle + walk, 4 directions), 2 goblin types (fast runner, armored brute) | Hero classes, bosses, elites |
| Terrain | 1 tileset (ground, path, walls) with autotiling | Biomes, decoration sets |
| Cards | 12 cards, 3 rarities, energy, hand of 3, shared deck, card passing | Combo cards, card upgrades, keywords |
| Run | 10 waves, card reward after each wave | Events, shops, elites, branching paths |
| Meta | Gold, boosters, collection, deck builder, local save | Idle camp, server-side profiles, crafting |
| Networking | Lobby server with room codes, WebRTC P2P, STUN/TURN | Matchmaking, reconnect, Steam transport |
| Platforms | Windows + Linux desktop | Web, macOS, controller support |
| Polish | Pack-opening animation, minimal SFX | Music, juice, settings menu, localization |

## Success criteria

The PoC passes when every pillar meets its check below and two people on different networks complete the full loop.

| Pillar | Proven when |
| --- | --- |
| Godot | Cards, units and waves are data-driven `Resource` files; adding a simple card = one `.tres` file + art, no code change. At least 9 of the 12 cards are pure data; the rest use a `ScriptedEffect` |
| Coding | Claude Code implements a new card or enemy from a short description, and existing tests stay green |
| Testing | Unit tests cover cards, energy, waves, boosters, deck validation, saves; a headless host + client test verifies sync; all run in CI on every push |
| Asset generation | Assets made with the style guide + PixelLab + Aseprite pass the validation script and look consistent side by side in-game |
| Networking | Two players on different home networks join by room code and play 10 waves without desync |
| Build / deploy | CI produces Windows + Linux builds; lobby server and coturn run as containers in the cluster with metrics in Grafana |
| Full loop | Menu → deck builder → lobby → run → gold → booster → deck builder works in one session, and the save survives a restart |

## Architecture

The host player's game is the authority; the self-hosted lobby only introduces players and never sees gameplay. This keeps server cost and complexity near zero.

```
┌──────────────────────────── Kubernetes cluster ────────────────────────────┐
│  ┌──────────────────────┐  ┌──────────────────────────┐  ┌───────────────┐ │
│  │ coturn               │  │ Lobby / signaling server │─▶│ Monitoring    │ │
│  │ STUN: NAT traversal  │  │ Room codes, player list  │  │ Grafana, VM,  │ │
│  │ TURN: relay fallback │  │ Relays WebRTC offers+ICE │  │ Loki          │ │
│  └──────────▲───────────┘  └─────▲──────────────▲─────┘  └───────────────┘ │
└─────────────┼────────────────────┼──────────────┼──────────────────────────┘
              ┆ TURN if P2P fails  │  WebSocket   │
              ┆                    │  signaling   │
   ┌──────────┴─────────────┐      │              │   ┌────────────────────────┐
   │ Player A (host)        │──────┘              └───│ Player B (client)      │
   │ Simulates enemies,     │◀═══ WebRTC P2P ════════▶│ Sends inputs, card     │
   │ towers; validates plays│     (game traffic)      │ plays; renders state   │
   └────────────────────────┘                         └────────────────────────┘
```

Players find each other through the lobby by room code, then exchange game traffic directly. Both peers can fall back to the TURN relay when a direct connection fails.

### Key choices

- **Godot 4.7.2, GDScript.** Data in `Resource` files: `CardData`, `UnitData`, `WaveData`.
- **Host-authoritative netcode.** Clients send inputs and card events; the host validates and broadcasts results. Hero positions are the only continuous sync.
- **Each client owns its hero.** A client moves its own hero locally and streams the position (~20 Hz). The host checks plausibility (max speed, walkable tile) and validates tower placement against the last position it received. No client-side prediction needed.
- **Transport abstraction.** One setting switches ENet (local dev, tests) and WebRTC (online).
- **Local saves.** JSON per profile with a version field.
- **Lobby server** in TypeScript on Bun, one stateless-ish container; rooms expire after the game starts.

### Repo layout

```
game/          Godot project (scenes, scripts, resources, tests)
lobby/         Lobby/signaling server + tests + Dockerfile
deploy/        Kubernetes manifests: lobby, coturn, monitoring config
assets-src/    Aseprite source files, palette, anchors
tools/         Asset validation, import scripts, prompt templates
docs/          Style guide, design notes, this plan
```

## Cards and meta system

Twelve cards across three rarities cover every card type once or more; the meta loop runs on one currency and local saves. All numbers below are starting values for tuning.

### Card effects

`CardData` holds a list of effect resources; most cards are pure data, a few odd ones use a script.

- Effect types: `DamageEffect`, `SlowEffect`, `HealEffect`, `PlaceTowerEffect` (references a `TowerData`), `BuffEffect`, `CostModifierEffect`, `TeleportEffect`, `LureEffect`. Each carries its own targeting, radius and duration fields.
- `ScriptedEffect` is the escape hatch for cards no generic effect covers: Time Warp (needs crystal HP history) and Mirror Image (copies a tower).
- A new effect type is code; a new card built from existing effects is not. The retro counts how many cards needed the escape hatch.

### In-run rules

- Energy regenerates 1 per 2 s, max 10. Cards cost 1–7.
- Hand of 3; a played card is replaced from the deck at once. Cycling a card costs 1 energy.
- Towers can only be placed within a radius around your own hero.
- Passing a card to the partner costs 1 energy.
- Deck empty → discard pile is shuffled back in.

### Card list (draft)

| Card | Type | Rarity | Cost | Effect |
| --- | --- | --- | --- | --- |
| Arrow Tower | Tower | Common | 3 | Basic single-target archer tower |
| Frost Totem | Tower | Common | 2 | Slows enemies in range |
| Ballista | Tower | Common | 4 | Pierces, hits enemies in a line |
| Arcane Bolt | Spell | Common | 1 | Small damage to one enemy |
| Mend | Spell | Common | 2 | Heals the crystal and nearby towers |
| Blink | Hero | Common | 1 | Hero teleports a short distance, brief invulnerability |
| Storm Spire | Tower | Rare | 5 | Chain lightning across 3 targets |
| Decoy Effigy | Spell | Rare | 3 | Lures enemies to a point for 5 s |
| War Drums | Buff | Rare | 3 | Towers near hero +50% fire rate for 10 s |
| Arcane Focus | Buff | Rare | 2 | Next card costs 0 |
| Mirror Image | Spell | Epic | 6 | Copies a tower for 30 s |
| Time Warp | Spell | Epic | 7 | Restores crystal HP lost in the last 10 s |

### Collection and boosters

- New profile starts with the 6 commons.
- Gold per run = 10 per wave survived + 25 for a win.
- Booster costs 50 gold and holds 3 cards; each slot rolls 70% common, 25% rare, 5% epic.
- Pity: an epic is guaranteed after 10 boosters without one.
- Pack opening: cards flip one at a time; new cards are marked.

### Deck building

- Deck size exactly 8; max 2 copies per card; only owned copies count.
- Up to 3 saved decks per profile; one is marked active for the lobby.
- Lobby shows each player's deck; at run start both decks merge into a 16-card shared deck.

### Persistence

- Local JSON save per profile: collection, gold, decks, pity counter, save version.
- Save on every meta change; load with a migration step keyed on the version.
- Server-side profiles are out of scope; the lobby server could host them later.

## Asset pipeline and style guide

Consistency comes from a written style guide, four hand-polished anchor assets, and a validation script that blocks off-style files. AI generates; Aseprite and the script enforce.

### Style guide (draft values)

| Rule | Decision |
| --- | --- |
| Base resolution | 320×180, integer scaling, Nearest filter |
| Sizes | Per frame: units 32×32, tiles 16×16, card art 64×48, icons 16×16. Card frame 72×104 (full), 48×64 (compact) |
| Spritesheets | One PNG per unit, animation and direction: a horizontal strip of 32×32 frames (walk = 192×32) |
| Directions | `down`, `up`, `side` (facing right); left is `side` with `flip_h` |
| Transparency | Alpha is 0 or 255 only, no soft edges |
| Palette | Endesga 32 (Lospec); no other colors |
| Perspective | Top-down 3/4 for units, terrain and props |
| Light | From top-left; shadows bottom-right |
| Outlines | 1px dark outline on units and towers; none on terrain |
| Color coding | Players blue/teal; goblins green with red/orange accents (eyes, weapons); neutral gray |
| Contrast | Terrain desaturated and low contrast; units high contrast |
| Animation | Idle 4 frames, walk 6, attack 4–6, 8–12 fps. Frame count, fps and loop live in `game/assets/manifest.json`, not in file names |
| Naming | `units/<name>/unit_<name>_<anim>_<dir>.png`, `tiles/<set>/tile_<set>_<nn>.png`, `cards/card_art_<id>.png`, `icons/icon_<name>.png` (all under `game/assets/`) |
| Font | m5x7 (free license), imported without antialiasing, used at 1× |
| Cards on screen | Hand shows compact cards (48×64: art crop, cost, name); hover or select shows the full 72×104 card. Base resolution stays 320×180 |

### Tools

- **PixelLab** (paid subscription): units, rotations, animations, tilesets. MCP support lets Claude Code script generation.
- **Aseprite** (one-time): cleanup, palette snapping, animation timing. Source files live in `assets-src/`.
- **Claude**: style guide, prompt templates, asset manifest, validation script, Godot import tooling, placeholder art, card text.

### Flow per asset

1. Pick the entry from the asset manifest; generate with the prompt template and an anchor as reference.
2. Clean up in Aseprite; save the `.aseprite` source.
3. Export PNG; pre-commit hook runs the validation script (size, palette, transparency, name).
4. Godot import script builds `SpriteFrames` and `TileSet` resources.
5. Mark the manifest entry done.

Implementation:

| Piece | Where |
| --- | --- |
| Asset manifest (id, type, frames, fps, loop, status `todo`/`placeholder`/`done`) | `game/assets/manifest.json` |
| Palette | `tools/endesga32.hex` (validator), `assets-src/palette/endesga-32.gpl` (Aseprite) |
| Validator (Python + Pillow, also checks the manifest) | `tools/validate_assets.py`, tests in `tools/test_validate_assets.py` |
| Placeholder art for `placeholder` entries | `tools/make_placeholders.py` |
| Import script → `game/resources/generated/*.tres` (committed; CI fails if stale) | `game/tools/build_assets.gd`, run via `tools/build_assets.sh` / `.ps1` |
| Pre-commit hook | `.pre-commit-config.yaml` |

All of it runs natively on Windows; no global texture atlas for the PoC (strips are small atlases already).

### Cards are composed, not baked

A card in-game = rarity frame (hand-made, 3 variants) + 64×48 art + cost, name and text rendered at runtime with a pixel font. Balance changes never need new art.

### Anchor assets first

Hero, one enemy, the base tileset and one card art are polished by hand before mass generation. All later assets reference them.

## Testing and CI

Every push runs unit tests, a headless network test and the asset validation; main branch also builds exports. Godot runs headless in CI, so no display is needed.

| Layer | Tool | What it covers |
| --- | --- | --- |
| Unit | gdUnit4 | Energy regen, hand/draw/cycle, card effects, wave spawning, deck validation, save load + migration |
| Scenario | gdUnit4, headless | Scripted runs: seed + deck + timed card plays, run N waves, assert crystal HP, gold earned and final state hash. Catches balance and behaviour regressions |
| Statistical | gdUnit4 | 10,000 simulated boosters match drop rates within tolerance; pity triggers at 10 |
| Network | 2 headless Godot instances (ENet, localhost) | Host + client connect, merge decks, replay the scenario scripts, compare state hashes per wave |
| Lobby server | bun test | Room create/join, signaling relay, room cleanup |
| Assets | Validation script | Size, palette, transparency, naming for every PNG |
| Manual | Two real machines on different networks | WebRTC through NAT, TURN fallback, full loop playtest |

### CI pipeline

1. Lint GDScript (gdtoolkit) and run asset validation.
2. Unit, statistical and scenario tests.
3. Headless network test.
4. Lobby server tests and container build.
5. On main: Windows + Linux exports as build artifacts.

Desync detection: host and client hash the game state at the end of each wave; the network test fails on any mismatch. The same hash is logged in real games for debugging.

## Milestones

Eight milestones; M4–M5 (networking) and M6 (assets) can run in parallel once M3 is done. Each ends with green CI and a short playable check.

| # | Milestone | Deliverables | Exit criteria |
| --- | --- | --- | --- |
| M1 | Skeleton | Repo layout, Godot project, gray-box lane, 1 enemy, 1 tower, CI with first test | Enemy walks to core, tower kills it; CI green |
| M2 | In-run card system | Energy, hand, deck, cycling, effect resources + `ScriptedEffect`, 12 cards as resources, compact/full card UI, scenario test harness | All 12 cards playable solo; unit tests for each card; first scenario tests green |
| M3 | Meta system | Save file, collection, gold, boosters + pack opening, deck builder, pity | Booster distribution test passes; save survives restart |
| M4 | Local networking | Checkpoint first: decide pure sim core vs Node-based sim. Then ENet host/join, client-owned heroes, card events via RPC, deck merge, card passing | Headless network test (replaying scenarios) passes with zero hash mismatches |
| M5 | Lobby + WebRTC | Lobby/signaling server, room codes, WebRTC transport, coturn, deployed to cluster | Two players on different networks complete 10 waves |
| M6 | Asset pipeline | Style guide, palette, anchors, validation hook, import scripts, all gray boxes replaced | All assets pass validation; side-by-side review looks consistent |
| M7 | Full loop | Main menu, lobby screen with deck preview, run → rewards → gold → booster flow | Full loop completed in co-op by two people in one session |
| M8 | Retro | Notes per pillar: what worked, what hurt, time spent, decisions for the real game | Go/no-go and approach for the full game decided |

## Risks and open decisions

The biggest risk is WebRTC on desktop; the fallback is ENet with port forwarding or a WebSocket relay so M7 is never blocked.

| Risk | Impact | Mitigation |
| --- | --- | --- |
| WebRTC desktop setup (needs `webrtc-native` GDExtension) is fiddly | M5 slips | Transport abstraction from M4; ENet or WebSocket relay as fallback |
| AI art drifts in style | Inconsistent look | Anchors, palette lock, validation hook, Aseprite cleanup |
| Real-time sync bugs | Desyncs in play | Host-authoritative model, event-based card plays, per-wave state hashes |
| Scope creep into "the real game" | PoC never ends | Scope table is binding; new ideas go to a backlog |
| Tool subscription costs | Small ongoing cost | One PixelLab plan for the PoC duration, cancel if not used |

### Decisions

- [x] Lobby server: TypeScript on Bun
- [x] Enemy faction: goblins (fast runner + armored brute)
- [x] Mood: dark fantasy
- [x] Palette: Endesga 32
- [x] Test framework: gdUnit4
- [x] Repo: GitHub (yggdrion/two-wards)
- [x] CI: GitHub Actions hosted runners
- [x] Godot version: 4.7.2
- [x] Card effects: composable effect resources + `ScriptedEffect` escape hatch
- [x] Tests: scenario tests on top of unit tests; the network test reuses them
- [x] Card UI: compact 48×64 hand, full 72×104 card on hover; font m5x7 at 1×
- [x] Hero sync: each client owns its hero position, host checks plausibility
- [x] Sim structure: M1 stays Node-based; pure sim core vs Nodes decided at the start of M4
- [x] WebRTC: no early spike; proven in M5 with the ENet/WebSocket fallback
