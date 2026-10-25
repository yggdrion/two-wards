# Two Wards PoC – Project Plan

Oct 22, 2026 · @Rapha

## Goal

The PoC proves that one person with AI tooling can build, test, network and ship a small co-op card game in Godot. The game is deliberately tiny; the pipeline behind it is the actual deliverable.

It validates six pillars end to end: Godot project structure, AI-assisted coding, automated testing, AI asset generation, online co-op networking, and build/deploy. The output is a playable full loop plus a retro that decides how the real game gets built.

Small does not mean ugly: the PoC has to end as a pretty, polished pixel-art game. The [Art direction](#art-direction) section sets the bar and the art track that gets there.

## Game concept

A real-time co-op tower defense roguelite in a **dark-fantasy** setting, where towers, spells and hero abilities come from each player's card deck. Title: **Two Wards** — two wizards defend a Heart Crystal against waves of monsters.

- **In a run:** each player gains energy over time and plays cards from a hand of 3 by clicking anywhere on the field. There is no avatar on the field.
- **Heroes:** before a run each player picks one of two wizards. A wizard never appears on the field; it gives a passive buff to the whole battlefield, and the two buffs add up in co-op. In the run, each player sees their partner's name, wizard portrait and hand of cards in a partner panel.
- **Co-op:** both players bring their own 8-card deck and each draws only from their own deck (decided 2026-10-23; before M7 the decks merged into one shared deck). Cards can be passed to the partner; a passed card goes back to its owner's deck once it is used.
- **Between waves:** each player picks 1 of 3 run upgrades, each for a different card of their own deck (Rapid Fire, Heavy Bolts, Twin Shot, Thrift, ...; rarity rolled like a booster slot). The deck stays the 8 cards the player built; the upgrade changes every copy and the towers already placed, for the rest of the run (decided 2026-10-24, replaces the card reward, which added cards from the whole catalog). The 5 s break starts once both have picked.
- **Meta:** runs earn gold, gold buys boosters, boosters grow the collection, the collection feeds the deck builder. Winning a run unlocks the next of 5 difficulty tiers, which has tougher enemies and pays more gold (decided 2026-10-25).

## Scope

The PoC is one map, two players, twelve cards and one full meta loop. Anything not needed to exercise a pillar is cut.

| Area | In scope | Out of scope (later) |
| --- | --- | --- |
| Map | 1 map, 1 lane, spawn → core | Multiple lanes, branching run map, map variety |
| Players | 2 players online co-op, host-authoritative | 3–4 players, host migration, dedicated servers |
| Units | 2 goblin types (fast runner, armored brute) with walk, attack, hit, death | Bosses, elites |
| Heroes | 2 wizards, each with one battlefield buff; hero select in the main menu; portraits only, never on the field | More heroes, hero classes (hero-specific card pools), hero leveling |
| Terrain | 1 tileset (ground, path, walls) with autotiling, about 12 props for one biome | More biomes |
| Cards | 12 cards, 3 rarities, energy, hand of 3, own deck per player, card passing, run-only card upgrades | Combo cards, permanent card levels, keywords |
| Run | 10 waves (mixed enemy groups), card upgrade after each wave, 5 difficulty tiers | Events, shops, elites, branching paths |
| Meta | Gold, boosters, collection, deck builder, local save | Idle camp, server-side profiles, crafting |
| Networking | Lobby server with room codes, WebRTC P2P, STUN/TURN | Matchmaking, reconnect, Steam transport |
| Platforms | Windows + Linux + macOS desktop | Web, controller support |
| Polish | Full pixel art for every screen, 2D lighting, shaders, VFX, juice (shake, hit flash, hit-stop, damage numbers), pack-opening animation, minimal SFX | Music, settings menu, localization |

## Success criteria

The PoC passes when every pillar meets its check below and two people on different networks complete the full loop.

| Pillar | Proven when |
| --- | --- |
| Godot | Cards, units and waves are data-driven `Resource` files; adding a simple card = one `.tres` file + art, no code change. At least 9 of the 12 cards are pure data; the rest use a `ScriptedEffect` |
| Coding | Claude Code implements a new card or enemy from a short description, and existing tests stay green |
| Testing | Unit tests cover cards, energy, waves, boosters, deck validation, saves; a headless host + client test verifies sync; all run locally with `tools/check` before a push and in CI on every PR |
| Asset generation | Assets made with the style guide + PixelLab + Aseprite pass the validation script and look consistent side by side in-game |
| Art | No gray box or placeholder is left on any screen, and a run looks like the approved target frame from A1 |
| Networking | Two players on different home networks join by room code and play 10 waves without desync |
| Build / deploy | CI produces Windows + Linux + macOS builds; lobby server and coturn run as containers on the self-hosted server with metrics in Grafana |
| Full loop | Menu → deck builder → lobby → run → gold → booster → deck builder works in one session, and the save survives a restart |

## Architecture

The host player's game is the authority; the self-hosted lobby only introduces players and never sees gameplay. This keeps server cost and complexity near zero.

```
┌──────────────────── Self-hosted server (docker compose) ───────────────────┐
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

- **Godot 4.7.2, GDScript.** Data in `Resource` files: `CardData`, `UnitData`, `WaveData`, `HeroData` (name, portrait, battlefield buff).
- **Host-authoritative netcode (lockstep).** Both machines run the same deterministic sim. The host is the clock: every tick it applies the card events (play, cycle, pass, with a target point) it has validated since the last tick, then broadcasts that tick with those events; the client replays the ticks in order and never changes its sim by itself. Clients send card events as requests; a request against a hand that has changed is refused. There is no state sync: each player's wizard is fixed at run start and has no position, and the partner panel reads the partner's hand from the replayed sim.
- **Pure sim core (R1b).** `Sim` and its entities (`game/scripts/sim/`) are plain objects without the scene tree; scenarios, lockstep and the network test build a `Sim` directly. `Lane` renders it: one view node per entity, created and freed from the sim's presentation signals.
- **Transport abstraction.** The same session runs over ENet (LAN, tests) or WebRTC through the lobby (online); gameplay only sees a `MultiplayerPeer`.
- **Local saves.** JSON per profile with a version field.
- **Lobby server** in TypeScript on Bun, one stateless-ish container; rooms expire after the game starts.

### Repo layout

```
game/          Godot project (scenes, scripts, resources, tests)
lobby/         Lobby/signaling server + tests + Dockerfile
deploy/        docker-compose for lobby + coturn, deploy notes
assets-src/    Aseprite source files, palette, anchors
tools/         Asset validation, import scripts, prompt templates
docs/          Style guide, design notes, this plan
```

## Cards and meta system

Twelve cards across three rarities cover every card type once or more; the meta loop runs on one currency and local saves. All numbers below are starting values for tuning.

### Card effects

`CardData` holds a list of effect resources; most cards are pure data, a few odd ones use a script.

- Effect types: `DamageEffect`, `SlowEffect`, `HealEffect`, `PlaceTowerEffect` (references a `TowerData`), `BuffEffect`, `CostModifierEffect`, `EmpowerEffect`, `LureEffect`. Each carries its own targeting, radius and duration fields.
- `ScriptedEffect` is the escape hatch for cards no generic effect covers: Time Warp (needs crystal HP history) and Mirror Image (copies a tower).
- A new effect type is code; a new card built from existing effects is not. The retro counts how many cards needed the escape hatch.

### In-run rules

- Energy regenerates 1 per 2 s, max 10. Cards cost 1–7.
- Hand of 3; a played card is replaced from the deck at once. Cycling a card costs 1 energy.
- Towers can be placed anywhere on the field that is off the path and keeps the minimum spacing to other towers.
- Wizard buffs apply to the whole battlefield for the whole run. Two players with the same wizard get its buff twice. Stacks add up (two Frost: enemies 30% slower; Empower turns one player's stack into two), enemies never drop below 10% of their speed, and boosted tower damage rounds to whole points.
- Passing a card to the partner costs 1 energy. The passed card goes into a fourth "gift" slot of the partner's hand (one at most) and leaves it when played, cycled or passed back; your own slot refills from the deck.
- Deck empty → discard pile is shuffled back in.
- Run upgrades (`UpgradeData`, one `.tres` each in `resources/upgrades/`) multiply or add to numbers on a card's parts: the card (cost), its effects (amount, radius, duration) and its tower (damage, fire_interval, attack_range, shots, chain_count, slow). `requires`/`excludes` decide which cards an upgrade fits. A card takes at most 5 upgrades.

### Card list (draft)

| Card | Type | Rarity | Cost | Effect |
| --- | --- | --- | --- | --- |
| Arrow Tower | Tower | Common | 3 | Basic single-target archer tower |
| Frost Totem | Tower | Common | 2 | Slows enemies in range |
| Ballista | Tower | Common | 4 | Pierces, hits enemies in a line |
| Arcane Bolt | Spell | Common | 1 | Small damage to one enemy |
| Mend | Spell | Common | 2 | Heals the crystal and nearby towers |
| Empower | Hero | Common | 1 | Your wizard's battlefield buff counts double for 8 s |
| Storm Spire | Tower | Rare | 5 | Chain lightning across 3 targets |
| Decoy Effigy | Spell | Rare | 3 | Lures enemies to a point for 5 s |
| War Drums | Buff | Rare | 3 | Towers near the target point +50% fire rate for 10 s |
| Arcane Focus | Buff | Rare | 2 | Next card costs 0 |
| Mirror Image | Spell | Epic | 6 | Copies a tower for 30 s |
| Time Warp | Spell | Epic | 7 | Restores crystal HP lost in the last 10 s |

### Collection and boosters

- New profile starts with 2 copies of each of the 6 commons and an 8-card starter deck (one copy each would not fill a deck).
- Gold per run = (10 + 5 × tier) per wave survived + (25 + 25 × tier) for a win; tier is 0 to 4 (shown as Tier 1–5).
- Difficulty tiers: a new profile has tier 0; winning on tier N unlocks N + 1, and the camp cycles through unlocked tiers. Co-op runs on the host's tier, and a win unlocks the next tier for both players. Enemy max HP = unit HP × 1.25^wave index × (1 + 0.5 × tier) × (1 + 0.8 per extra player); towers are unlimited, so the HP compounds per wave to outgrow a full field; each tier spawns 8% faster (`Sim.TIER_*`, `WAVE_HP`, `PLAYER_HP`).
- Booster costs 50 gold and holds 3 cards; each slot rolls 70% common, 25% rare, 5% epic.
- Pity: the 10th booster in a row without an epic holds one.
- A pulled card the profile already owns 2 copies of (the deck cap) pays gold instead: 10 common, 20 rare, 40 epic.
- Pack opening: cards flip one at a time; new cards are marked.

### Deck building

- Deck size exactly 8; max 2 copies per card; only owned copies count.
- Up to 3 saved decks per profile; one is marked active for the lobby.
- Lobby shows each player's name, wizard and deck; the client readies up, then the host starts the run. Each player keeps their own deck in the run.

### Persistence

- Local JSON save per profile: collection, gold, decks, selected wizard, pity counter, save version.
- Save on every meta change; load with a migration step keyed on the version. Version 2 (M3b) added the selected wizard (old saves get Frost) and turned owned Blink copies into Empower. Version 3 (M4) added the player name shown to the co-op partner. Version 4 added the unlocked and the selected difficulty tier (old saves start on tier 0).
- Server-side profiles are out of scope; the lobby server could host them later.

## Art direction

The PoC ends as a pretty, polished pixel-art game, not a gray box with sprites (decided 2026-10-22). Visual quality counts as much as the pipeline: a screenshot of a run should look like a finished indie game. The art track below runs beside the code milestones, so no milestone waits on art and art never waits on a milestone it doesn't need.

### Look

| Aspect | Decision |
| --- | --- |
| Mood | Evening in a natural meadow, lit by magic. Ground looks real (grass, dirt path, stone walls, trees, rocks) but is toned down to evening, never bright daylight. Everything the players own (crystal, towers, spells) glows and lights its surroundings. Approved by Rapha 2026-10-22 from the mockups in the project files (`art-direction/evening_a_lit.png`); the final art must be more detailed and more "pixel" than those code-drawn mockups. Reference: Stardew Valley and Sea of Stars for the ground, Hyper Light Drifter and Moonlighter at night for the light |
| Palette use | Endesga 32 only. Grass uses `193c3e` `265c42` `3e8948` (base `265c42`, lit `63c74d` only inside light pools), the dirt path `3e2731` `733e39` `b86f50` `e4a672`, walls and rocks the blue-gray stone ramp `262b44` `3a4466` `5a6988` `8b9bb4`. Players and their magic own teal and blue (`0099db` `2ce8f5`), plus warm gold (`feae34` `fee761`) for rewards. Goblins own green with red and orange accents. Red (`e43b44`) is reserved for damage and danger |
| Readability | Units are the highest-contrast thing on screen; terrain never uses `181425` outlines or the brightest ramp colors. Every unit gets the engine shadow ellipse. Goblins sit on green grass, so their skin uses the light green (`3e8948` `63c74d`) against the darker grass base, keeps the closed `181425` outline and gets red or orange eyes and gear; check this in the A1 target frame and shift the goblin hue toward olive if they blend in |
| Lighting | Godot 2D lights: a `CanvasModulate` dims the lane to evening (and edges a little darker), and `PointLight2D`s on the crystal, towers and spells light it back up. No normal maps (they would double the art). Lights are flat, hard-edged textures so the light itself looks pixelated |
| Palette on screen | Lights tint sprites off-palette. Try a full-screen shader that snaps the final image back to Endesga 32 in A2; keep it if it looks better, drop it if it bands |
| Motion | Everything alive moves: units idle, the crystal pulses, grass and banners sway (vertex shader), ambient motes drift. Nothing on screen is perfectly still for more than a second |
| VFX ambition | Pixel-crisp effects only: no soft particles, no blur, no additive glow textures with soft alpha. Hits get a 1-frame white flash, impacts a 4–6 frame sprite burst, deaths a short dissolve. Screen shake is small and snapped to whole pixels |

Juice is presentation only. VFX, screen shake, hit-stop and damage numbers react to signals from the simulation and never change sim timing or state, so tests, scenario hashes and netcode stay deterministic. Hit-stop freezes animation playback, not `Sim.tick`.

### Asset list

Sizes follow the style guide (64×64 unit frames, 32×32 tiles, 128×96 card art, 32×32 icons). New types (towers, props, VFX, UI) get naming and size rules in the style guide and the validator during A1.

| Group | Assets | Animations / variants | Made by |
| --- | --- | --- | --- |
| Wizards | Frost (the existing blue/teal hero) and Ember (new, warm) | Bust portrait for the HUD partner panel; full-body idle `down` for the hero select | PixelLab (Frost reuses the existing hero frames), Aseprite cleanup |
| Goblin runner | Small, fast | walk, attack, hit, death; 3 dirs | PixelLab + Aseprite |
| Goblin brute | Armored, slow | walk, attack, hit, death; 3 dirs | PixelLab + Aseprite |
| Towers | Arrow Tower, Frost Totem, Ballista, Storm Spire | idle (gem glow), fire; one direction, they don't rotate; build-up animation by shader | PixelLab base, Aseprite for frames |
| Card props | Decoy Effigy, Mirror Image copy | Effigy: idle. Mirror Image: any tower with a ghost shader | PixelLab (effigy), code (ghost) |
| Heart Crystal | 1, about 64×96 | idle pulse, hit crack, low-HP state | PixelLab base, Aseprite animation, light by code |
| Terrain | Ground, path, wall/cliff edge tileset with transitions; 1 ground variant set | Autotile set | PixelLab tileset tool, Aseprite seam fixes |
| Props | About 12: rocks, dead trees, ruins, torches, banners, bones, grass tufts, crystal shards, spawn portal | Torches and portal animated | PixelLab, Aseprite |
| VFX | Arrow, bolt, frost burst, lightning chain, heal, empower glow, lure aura, drum pulse, focus sparkle, time-warp rewind, hit spark, death puff, gold pop | 4–8 frame flipbooks | Mostly code (GPU particles with 1–2 px pixel textures, shaders, `Line2D` lightning); flipbooks hand-drawn or PixelLab where code looks cheap |
| Card frames | Common, rare, epic; full 144×208 and compact 96×128 | Static, epic gets a shimmer shader | Claude draws in code (Python, on-palette), Aseprite polish |
| Card art | 12 × 128×96 | Static | PixelLab with the card-art anchor as style reference, Aseprite cleanup |
| Icons | Energy, gold, crystal HP, deck, discard, wave, card types (tower, spell, hero, buff), rarity gems | Static | Hand-drawn in Aseprite or by Claude in code; 32×32 is small enough that AI saves little |
| HUD and UI | Panels, buttons, energy bar, wave banner, tooltip, 9-slice frames, cursor | Hover/press states | Claude in code (9-slice PNGs + Godot `Theme`), Aseprite polish |
| Meta screens | Booster pack (closed, tearing), collection grid, deck builder, gold counter | Pack-opening flipbook + tweens | PixelLab pack art, code for the rest |
| Menus | Title logo, main menu backdrop (built from game tiles and props), lobby screen, loading, run-end screen | Parallax and ambient particles | Logo hand-lettered in Aseprite, backdrop composed in Godot |
| Font | m5x7 for text; a chunkier display font for titles and damage numbers | — | Free-license pixel font, chosen in A1 |

### Who makes what

- **PixelLab** (Claude drives the API): first drafts of everything organic: units, rotations, animations, towers, crystal, tiles, props, card art, the booster pack.
- **Aseprite** (Rapha, with Claude preparing palette-snapped files): every PixelLab output gets a pass for outline, light, placement and stray colors; side profiles and timing of key animations are hand work. Sources live in `assets-src/`.
- **Claude in code**: geometric and repeated art (card frames, UI 9-slices, icons where simple), all shaders (hit flash, dissolve, palette swap, ghost, sway, shimmer, optional palette snap), particles, 2D lighting, screen shake, hit-stop, damage numbers, tweens and transitions.

### PixelLab budget

Counted in generation calls, with about 2.5 attempts per kept result (the first hero needed 7 calls for 2 kept frames).

| Group | Kept results | Calls |
| --- | --- | --- |
| Wizards (Ember idle, 2 portraits) | ~4 | ~10 |
| Two goblins (base, 2 rotations, 4 anims × 3 dirs each) | ~30 | ~75 |
| Towers, effigy, crystal | ~14 | ~35 |
| Tiles and props | ~18 | ~45 |
| Card art (12) and booster pack | ~14 | ~35 |
| VFX flipbooks where code isn't enough | ~8 | ~20 |
| Buffer for redos after the look review | | ~65 |
| **Total** | | **~285** |

The trial has 30 of 40 left (checked 2026-10-22). Rapha will upgrade when A1 starts; the budget is not a hard limit, so spend on quality (more attempts per asset) rather than settling. Animation calls on PixelLab's newer models cost more than one generation each; pick the tier from this table and the current pricing page. One or two months of the plan should cover the PoC; cancel afterwards (see Risks).

### Art track

| Step | Runs beside | Deliverables | Exit criteria |
| --- | --- | --- | --- |
| A1 Look target | M3 | Paid PixelLab plan; style guide v2 (new asset types, display font, light and VFX rules); validator and `build_assets` learn towers, props, VFX, UI; anchors: Frost wizard portrait, goblin runner, base tiles, one tower, crystal, one card art; one **target frame**: a 640×360 mockup of a run with HUD, composed from the anchors | Rapha approves the target frame. Everything after copies its look |
| A2 Run screen | M4, M5 | All units, towers, crystal, tileset, props; 2D lighting and dusk modulate; shaders; particles and juice; ambient motion | A run looks like the target frame in motion; tests still green |
| A3 Cards and UI | M5 | Card frames, 12 card arts, icons, HUD skin, the M3 meta screens skinned, pack-opening animation | The card and meta screens match the run screen |
| A4 Menus and polish | M7 | Title logo, main menu, lobby screen, run-end screen, transitions; a polish pass over everything in the side-by-side review | Full loop looks finished end to end |

Code milestones prepare for it: M3 builds its screens on a Godot `Theme` and 9-slice panels so A3 only swaps textures, and gray-box `_draw()` code stays only until A2 replaces it.

## Asset pipeline and style guide

Consistency comes from a written style guide, four hand-polished anchor assets, and a validation script that blocks off-style files. AI generates; Aseprite and the script enforce.

### Style guide (draft values)

The full rules (color count, placement in the frame, outline, camera, light, directions, review checklist and PixelLab settings) are in [STYLE_GUIDE.md](STYLE_GUIDE.md). This table is the summary.

| Rule | Decision |
| --- | --- |
| Base resolution | 640×360, integer scaling (3× at 1080p, 4× at 1440p, 6× at 4K), Nearest filter |
| Sizes | Per frame: units 64×64, tiles 32×32, card art 128×96, icons 32×32. Card frame 144×208 (full), 96×128 (compact) |
| Spritesheets | One PNG per unit, animation and direction: a horizontal strip of 64×64 frames (walk = 384×64) |
| Directions | `down`, `up`, `side` (facing right); left is `side` with `flip_h` |
| Transparency | Alpha is 0 or 255 only, no soft edges |
| Palette | Endesga 32 (Lospec); no other colors |
| Perspective | Top-down 3/4 for units, terrain and props |
| Light | From top-left; shadows bottom-right |
| Outlines | 1px dark outline on units and towers; none on terrain |
| Color coding | Players blue/teal; goblins green with red/orange accents (eyes, weapons); neutral gray |
| Contrast | Terrain desaturated and low contrast; units high contrast |
| Animation | Idle 4 frames, walk 6, attack 4–6, 8–12 fps. Frame count, fps and loop live in `game/assets/manifest.json`, not in file names |
| Naming | `units/<name>/unit_<name>_<anim>_<dir>.png`, `tiles/<set>/tile_<set>_<nn>.png`, `cards/card_art_<id>.png`, `icons/icon_<name>.png`, `towers/tower_<id>.png` (48×72), `props/prop_<name>.png` (size in the manifest) (all under `game/assets/`) |
| Font | m5x7 (free license), imported without antialiasing, drawn at 2× |
| Cards on screen | Hand shows compact cards (96×128: art crop, cost, name); hover or select shows the full 144×208 card |

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
| Asset manifest (id, type, frames, fps, loop, status `todo`/`placeholder`/`done`, optional `final` list of finished files inside a `placeholder` entry) | `game/assets/manifest.json` |
| Palette | `tools/endesga32.hex` (validator), `assets-src/palette/endesga-32.gpl` (Aseprite) |
| Validator (Python + Pillow, also checks the manifest) | `tools/validate_assets.py`, tests in `tools/test_validate_assets.py` |
| Placeholder art for `placeholder` entries | `tools/make_placeholders.py` |
| Import script → `game/resources/generated/*.tres` (committed; CI fails if stale) | `game/tools/build_assets.gd`, run via `tools/build_assets.py` |
| Pre-commit hook | `.pre-commit-config.yaml` |

All of it runs natively on Windows; no global texture atlas for the PoC (strips are small atlases already).

### Cards are composed, not baked

A card in-game = rarity frame (hand-made, 3 variants) + 128×96 art + cost, name and text rendered at runtime with a pixel font. Balance changes never need new art.

### Anchor assets first

The Frost wizard portrait, goblin runner, base tileset, one tower, the Heart Crystal and one card art are polished by hand before mass generation, then combined into the A1 target frame. All later assets reference them.

## Testing and CI

Every pull request runs lint, the unit tests, the headless network test and the asset validation on Linux; main and manual runs also run the Windows checks and build both exports. The same checks run locally with `python tools/check.py` (also as a pre-push hook), so CI is a safety net rather than the inner loop. Godot runs headless in CI, so no display is needed.

| Layer | Tool | What it covers |
| --- | --- | --- |
| Unit | gdUnit4 | Energy regen, hand/draw/cycle, card effects, wave spawning, deck validation, save load + migration |
| Scenario | gdUnit4, headless | Scripted runs: seed + deck + timed card plays, run N waves, assert crystal HP, gold earned and final state hash. Catches balance and behaviour regressions |
| Statistical | gdUnit4 | 10,000 simulated boosters match drop rates within tolerance; pity triggers at 10 |
| Network | 2 headless Godot instances (ENet, localhost) | Host + client connect, exchange decks, replay the scenario scripts (upgrade picks included), compare state hashes per wave |
| Lobby server | bun test | Room create/join, signaling relay, room cleanup |
| Assets | Validation script | Size, palette, transparency, naming for every PNG |
| Manual | Two real machines on different networks | WebRTC through NAT, TURN fallback, full loop playtest |

### CI pipeline

1. Lint GDScript (gdtoolkit) and run asset validation.
2. Unit, statistical and scenario tests.
3. Headless network test.
4. Lobby server tests and container build.
5. On main: Windows + Linux + macOS exports as build artifacts.

Desync detection: host and client hash the game state at the end of each wave; the network test fails on any mismatch. The same hash is logged in real games for debugging.

## Milestones

Eight milestones plus M3b (heroes, added after the M3 playtest); M4–M5 (networking) and M6 (assets) can run in parallel once M3b is done. The art track A1–A4 (see [Art direction](#art-direction)) runs beside them; M6 is where it must be finished. Each ends with green CI and a short playable check. R1 is the first milestone of the real game, decided in the M8 retro; it runs beside M6.

| # | Milestone | Deliverables | Exit criteria |
| --- | --- | --- | --- |
| M1 | Skeleton | Repo layout, Godot project, gray-box lane, 1 enemy, 1 tower, CI with first test | Enemy walks to core, tower kills it; CI green |
| M2 | In-run card system | Energy, hand, deck, cycling, effect resources + `ScriptedEffect`, 12 cards as resources, compact/full card UI, scenario test harness | All 12 cards playable solo; unit tests for each card; first scenario tests green |
| M3 | Meta system | Save file, collection, gold, boosters + pack opening, deck builder, pity | Booster distribution test passes; save survives restart |
| M3b | Heroes | Remove the field hero and its movement; `HeroData` with the two wizards and their battlefield buffs; hero select screen; selected wizard in the save (version bump + migration); Empower replaces Blink; War Drums targets a point; placement anywhere off the path | Buffs and Empower covered by unit tests; scenarios re-pinned; a solo run plays with either wizard |
| M4 | Local networking | Checkpoint first: decide pure sim core vs Node-based sim. Then ENet host/join, card events via RPC, deck merge, card passing, partner panel (name, wizard, hand) | Headless network test (replaying scenarios) passes with zero hash mismatches |
| M5 | Lobby + WebRTC | Lobby/signaling server, room codes, WebRTC transport, coturn, deployed to the gvm host | Two players on different networks complete 10 waves |
| M6 | Art and juice | A1–A3 of the art track finished: all units, towers, tiles, props, cards and UI in final art; lighting, shaders, VFX and juice | All assets pass validation; side-by-side review looks consistent; a run matches the A1 target frame |
| M7 | Full loop | Title screen, lobby screen with deck preview, card reward after each wave (now a card upgrade), run-end screen, run → rewards → gold → booster flow | Full loop completed in co-op by two people in one session |
| M8 | Retro | Notes per pillar: what worked, what hurt, time spent, decisions for the real game | Go/no-go and approach for the full game decided |
| R1 | Sim core + Python tooling (first real-game milestone, from the [M8 retro](RETRO.md#decisions-for-the-real-game); runs beside M6) | A pure simulation core with no scene tree that the Node layer renders; one cross-platform Python script per tool instead of the `.sh`/`.ps1` twins; CI, CLAUDE.md and HANDOFF updated. Steps in [R1](#r1-sim-core-and-python-tooling) | The four scenario files replay to their pinned hashes unchanged; the scenario, lockstep and network tests build no scene tree; no `.sh`/`.ps1` left in `tools/`; CI green on Linux and Windows with the Python scripts; a co-op playtest from the CI build plays like before |

### R1: sim core and Python tooling

Two PRs that touch different files, so they can run side by side: R1a (tooling) is smaller and goes first if they run one after the other, so R1b already uses the new check. Neither changes gameplay: every card, number and hash stays the same.

#### R1a: Python tooling

One stdlib-only Python script per tool (Python 3.12 as in CI, no new packages), so Windows and Linux run the same code. Today 11 tools exist twice (22 files, about 1,000 lines).

| Today (`.sh` + `.ps1`) | Becomes |
| --- | --- |
| `install_godot`, `install_gdunit4`, `install_webrtc`, `install_godot_templates` | `tools/install.py [godot\|gdunit4\|webrtc\|templates]`; prints the Godot path like `install_godot` does now. Same pins and checksums, `urllib` + `hashlib` + `zipfile` |
| `godot` | `tools/godot.py` (same import-first rule) |
| `run_tests` | `tools/run_tests.py [gdUnit4 args]`; calls Godot with gdUnit4's `GdUnitCmdTool.gd` directly instead of the addon's `runtest.sh`/`.cmd`, keeps the exit code |
| `run_network_test` | `tools/run_network_test.py [scenario.json ...]`; host, client and lobby via `subprocess.Popen`, logs in a temp dir, same ports, timeouts and "skip WebRTC without bun, except in CI" |
| `build_assets` | `tools/build_assets.py` |
| `export` | `tools/export.py linux\|windows` |
| `check` | `tools/check.py [--quick] [--export]` (same steps and order, same drift check) |
| `setup` | `tools/setup.py` |
| `pre-push` + `check --install-hook` | dropped: a `pre-push` stage hook in `.pre-commit-config.yaml` runs `python tools/check.py`, and `setup.py` installs it with `pre-commit install --hook-type pre-push` |

Shared bits (repo root, pinned versions, download with checksum, Godot path) live in one `tools/_common.py`. Scripts are run as `python tools/<name>.py` (`py` on Windows works the same).

Steps:

1. Port the installers and `godot.py`; check on Windows and Linux that they produce the same `.tools/` and `game/addons/` trees as the old scripts (byte-identical binaries, checksums verified).
2. Port `run_tests`, `run_network_test`, `build_assets`, `export`, `check`, `setup`; run the old and the new full check side by side once on each OS and compare the test count and network-test output.
3. CI: every job calls `python tools/<name>.py` (with `actions/setup-python` 3.12 on the Windows jobs too). The `detect` job and its gates go, because every gated entry point now exists. Exports keep running on their own OS.
4. Delete the 22 `.sh`/`.ps1` files and `tools/pre-push`; update CLAUDE.md (commands, "keep both in sync" rule), `docs/HANDOFF.md` ("How we work"), `docs/ASSET_PIPELINE.md`, the Testing and CI section here, and every script comment that names an old script.

Exit: `python tools/check.py` passes on Windows (PowerShell, no Git Bash needed) and Linux; CI green; no `.sh`/`.ps1` in `tools/`.

#### R1b: pure sim core

Today `Lane` (a `Node2D` in `scenes/lane.tscn`) is both the simulation and its drawing: enemies and towers are child nodes, the path is a `Path2D`, the crystal is a node, and every test, scenario and network run instantiates the scene. After R1b the simulation is plain `RefCounted` objects that run without a scene tree, and the Node layer only reads them and draws.

Target shape:

| Piece | Pure core (`game/scripts/sim/`) | Node layer (`game/scripts/lane/`) |
| --- | --- | --- |
| Run | `Sim`: everything `Lane` does today except drawing — phase, waves, gold, time, players, lures, rewards, damage log, buffs, placement rules, queries for card effects, `tick(delta)`, `state_hash()`; signals `wave_started`, `wave_cleared`, `run_won`, `run_lost` plus presentation signals (`enemy_spawned`, `enemy_removed`, `tower_placed`, `tower_removed`, `tower_fired`, `crystal_hit`) | `Lane` keeps its name and scene, holds a `sim`, builds the ground tiles, dusk and lights, creates and frees one view node per sim entity from the signals, draws lures; `_physics_process` calls `sim.tick` when `autorun` |
| Units | `SimEnemy` (hp, progress, position, slows, held) | `Enemy` view: sprite, shadow, HP bar, frost tint, `flip_h` |
| Towers | `SimTower` (cooldown, buffs, lifetime, targeting, hit patterns, `is_copy`) | `Tower` view: sprite, range ring, shot flash, lights |
| Crystal | `SimCrystal` (hp, heal, damage) | `HeartCrystal` view: sprite, light, HP bar |
| Path | a `Curve2D` in its own resource (`resources/maps/lane_01_path.tres`), offset baked in, used by the sim and drawn by the scene | `Path2D` in `lane.tscn` points at the same resource |
| Already pure | `WaveSpawner`, `PlayerState`, `Deck`, `Energy`, `RunRewards`, effects | — |

Rules that stay: the sim advances only through `tick(delta)`; `NetCommand.apply`, `LockstepHost`, `LockstepClient`, `DesyncLog` and `Scenario` take a `Sim` instead of a `Lane` and are otherwise unchanged; `CardContext.lane` becomes `CardContext.sim`; juice reacts to presentation signals and never feeds back into the sim. Entity order in the sim arrays is the order today's node children have (insertion order), so `state_hash()` stays byte-identical.

Steps:

1. Move the path into `lane_01_path.tres` and pin the test baseline: record the four scenario hashes and the per-wave network-test hashes before any code moves.
2. Add `Sim`, `SimEnemy`, `SimTower`, `SimCrystal` by moving the logic out of `lane.gd`, `enemy.gd`, `tower.gd`, `heart_crystal.gd`; `Lane` creates a `Sim` and forwards to it, so the game and all tests keep working in between. Hashes must match the baseline.
3. Switch `CardContext`, the effects, `mirror_image.gd`, `time_warp.gd`, `NetCommand`, the lockstep classes, `DesyncLog`, `Scenario`, `CoopSetup`, `net_test.gd` and `record_scenario.gd` to `Sim`; scenario, lockstep, card and network runs build a `Sim` directly, no scene.
4. Turn `Enemy`, `Tower`, `HeartCrystal` into views driven by the presentation signals; `game.gd`, `hud.gd` and the partner panel read `lane.sim`. Remove the forwarding methods from `Lane`.
5. Tests: unit tests for the sim classes run on `Sim` without `add_child`; one view test checks that spawning, firing, removal and expiry create and free the right nodes; the existing lane/HUD/screen tests stay green. Update the "Code conventions" and "Architecture rules" in CLAUDE.md and the "Key choices" here.
6. Playtest from the CI build (solo and co-op) before merge: it must look and play exactly as before.

Exit: as in the R1 row; also `grep` finds no `Node`, `get_tree`, `queue_free` or `add_child` in `game/scripts/sim/`.

Out of scope for R1: new gameplay, a different net model, a GDExtension or C# core, headless servers, any rebalancing.

## Risks and open decisions

The biggest risk was WebRTC on desktop; M5 retired it (webrtc-native GDExtension, two-network playtest passed). The ENet LAN path stays as the fallback.

| Risk | Impact | Mitigation |
| --- | --- | --- |
| WebRTC desktop setup (needs `webrtc-native` GDExtension) is fiddly | M5 slips | Transport abstraction from M4; ENet or WebSocket relay as fallback |
| AI art drifts in style | Inconsistent look | Anchors, palette lock, validation hook, Aseprite cleanup |
| AI art can't reach the polish bar | PoC looks cheap | A1 target frame is the gate before mass generation; more hand work in Aseprite on the assets that fill the screen (tiles, crystal, towers); code-made VFX and light carry a lot of the look |
| Art track eats the schedule | Networking slips | Art runs beside the code milestones; scope is the asset list above, and new art ideas go to the backlog |
| Real-time sync bugs | Desyncs in play | Host-authoritative model, event-based card plays, per-wave state hashes |
| Scope creep into "the real game" | PoC never ends | Scope table is binding; new ideas go to a backlog |
| Tool subscription costs | Small ongoing cost | One PixelLab plan for about 300 generations (see PixelLab budget), cancel after A3 |

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
- [x] Card UI: compact 96×128 hand, full 144×208 card on hover; font m5x7 at 2×
- [x] Resolution (2026-10-22, after the first hero sprite): 640×360 base with 64×64 units and 32×32 tiles, so sprites keep their on-screen size with twice the detail. Was 320×180 with 32×32 units
- [x] Hero role (2026-10-22, after the M3 playtest): no hero on the field. Each player picks one of two wizards that buffs the whole battlefield; wizards show only in the partner panel and the hero select. Replaces "each client owns its hero position", so there is no continuous sync
- [x] Sim structure (2026-10-23, M4 checkpoint): keep the Node-based sim. It already advances only through `Lane.tick`, takes all randomness from the seeded deck and replays scenarios to identical hashes, which is all lockstep needs; the retro can revisit a pure core for the real game
- [x] Real game (2026-10-24, M8 retro): go once M6 proves bulk art; split out a pure sim core; keep host-as-clock lockstep; one Python script per tool instead of `.sh`/`.ps1` twins. First milestone: R1
- [x] WebRTC: no early spike; proven in M5 with the ENet/WebSocket fallback
- [x] Art goal (2026-10-22): full pixel-art route, the PoC must end up pretty and polished; art track A1–A4 beside the code milestones
- [x] Look (2026-10-22): natural evening meadow lit by magic, more detailed than the mockups
- [ ] PixelLab paid tier: Rapha upgrades when A1 starts
