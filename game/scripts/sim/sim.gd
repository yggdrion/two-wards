class_name Sim
extends RefCounted
## The run's simulation: waves along the path, towers, the players' cards and wizard buffs.
##
## Plain objects, no scene tree: tests, scenarios and the co-op host build a Sim directly and
## step it with tick(delta). Lane draws it and reacts to the presentation signals; nothing the
## views do feeds back into the sim.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal run_won
signal run_lost
## Presentation signals: the Lane creates and frees one view per entity from these.
signal enemy_spawned(enemy: SimEnemy)
signal enemy_removed(enemy: SimEnemy)
signal tower_placed(tower: SimTower)
signal tower_removed(tower: SimTower)
signal tower_fired(tower: SimTower, hits: Array[SimEnemy])
signal crystal_hit(amount: int)

enum Phase { WAVE, BREAK, WON, LOST }

const PATH_RESOURCE := "res://resources/maps/lane_01_path.tres"
const WAVE_DIR := "res://resources/waves"
## The path runs along tile corners, so the ground tiles draw it one tile wide.
const PATH_WIDTH := 32.0
## Playable field above the card UI. Towers stay inside it.
const FIELD := Rect2(0, 0, 640, 288)
## Minimum distance between two towers.
const TOWER_SPACING := 24.0
## Seconds between a cleared wave and the next one.
const WAVE_BREAK := 5.0
## In co-op, seconds a player has to pick a reward before the first card is picked for them.
const REWARD_TIMEOUT := 60.0
const GOLD_PER_WAVE := 10
const GOLD_FOR_WIN := 25
## Crystal damage older than this is forgotten (Time Warp looks back 10 s).
const DAMAGE_MEMORY := 30.0
## Stacked slows never take enemies below this share of their speed.
const MIN_ENEMY_SPEED := 0.1

# --- Setup: set these before start() ---

var waves: Array[WaveData] = default_waves()
## One deck per player, in player order; each player draws only from their own.
var decks: Array[DeckData] = []
## One wizard per player, in player order (the host is player 0); its buff covers the whole
## battlefield. The run has one player per entry, and one player without a buff if empty.
var heroes: Array[HeroData] = []
## Cards a reward can offer (RunRewards); empty turns rewards off (most tests).
var reward_pool: Array[CardData] = []
## Seeds the deck shuffles and reward offers; same seed and inputs give the same run.
var rng_seed: int = 1
var path: Curve2D = load(PATH_RESOURCE)

# --- State ---

var phase := Phase.WAVE
var wave_index := 0
var waves_cleared := 0
var gold := 0
## Simulation time in seconds since the run started.
var time := 0.0
var enemies: Array[SimEnemy] = []
## In placement order.
var towers: Array[SimTower] = []
var core := SimCrystal.new()
var players: Array[PlayerState] = []
## Active lures: {position: Vector2, radius: float, remaining: float}.
var lures: Array[Dictionary] = []
## Reward offers after cleared waves; set up in start().
var rewards: RunRewards
## Seconds left on the co-op reward countdown while an offer is open.
var reward_time_left := 0.0
var _spawner: WaveSpawner
var _break_timer := 0.0
## Crystal hits: {time: float, amount: int}.
var _damage_log: Array[Dictionary] = []


## Every wave in the waves folder, in file name order.
static func default_waves() -> Array[WaveData]:
	var files := Array(ResourceLoader.list_directory(WAVE_DIR)).filter(
		func(file: String) -> bool: return file.get_extension() == "tres"
	)
	files.sort()
	var list: Array[WaveData] = []
	for file: String in files:
		list.append(load(WAVE_DIR.path_join(file)))
	return list


## Builds the players and starts the first wave.
func start() -> void:
	core.position = path.get_point_position(path.point_count - 1)
	core.destroyed.connect(_on_core_destroyed)
	for i in maxi(heroes.size(), 1):
		var hero: HeroData = heroes[i] if i < heroes.size() else null
		var cards: Array[CardData] = []
		if i < decks.size() and decks[i] != null:
			cards = decks[i].cards
		players.append(PlayerState.new(Deck.new(cards, rng_seed + i), hero))
	rewards = RunRewards.new(reward_pool, players.size(), rng_seed)
	if not waves.is_empty():
		_start_wave(0)


func tick(delta: float) -> void:
	if is_over():
		return
	time += delta
	for player in players:
		player.step(delta)
	if phase == Phase.BREAK and rewards.is_open() and players.size() > 1:
		reward_time_left -= delta
		if reward_time_left <= 0.0:
			_auto_pick_rewards()
	if phase == Phase.BREAK and not rewards.is_open():
		_break_timer -= delta
		if _break_timer <= 0.0:
			_start_wave(wave_index + 1)
	if phase == Phase.WAVE and _spawner != null:
		for i in _spawner.step(delta):
			spawn_enemy(waves[wave_index].enemy)
	_step_lures(delta)
	var speed := enemy_speed_scale()
	for enemy in enemies.duplicate():
		enemy.held = _in_lure(enemy.position)
		enemy.step(delta, speed)
	var damage := tower_damage_scale()
	for tower in towers.duplicate():
		var hits: Array[SimEnemy] = tower.step(delta, enemies, damage)
		if not hits.is_empty():
			tower_fired.emit(tower, hits)
		if tower.is_expired():
			towers.erase(tower)
			tower_removed.emit(tower)
	if phase == Phase.WAVE and _spawner != null and _spawner.is_done() and enemies.is_empty():
		_clear_wave()


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


# --- Cards ---


func play_card(player_index: int, slot: int, target: Vector2 = Vector2.ZERO) -> bool:
	if is_over():
		return false
	var player := players[player_index]
	return player.play(slot, CardContext.new(self, player, target))


func can_play_card(player_index: int, slot: int, target: Vector2 = Vector2.ZERO) -> bool:
	var player := players[player_index]
	return not is_over() and player.can_play(slot, CardContext.new(self, player, target))


func cycle_card(player_index: int, slot: int) -> bool:
	return not is_over() and players[player_index].cycle(slot)


## Gives a hand card to the other player of a two-player run.
func pass_card(player_index: int, slot: int) -> bool:
	if is_over() or players.size() != 2:
		return false
	return players[player_index].pass_to(slot, players[1 - player_index])


# --- Wizard buffs ---


## Enemy speed multiplier from every player's wizard: each Frost stack takes its amount off.
func enemy_speed_scale() -> float:
	return maxf(1.0 - _buff_total(HeroData.Buff.ENEMY_SLOW), MIN_ENEMY_SPEED)


## Tower damage multiplier from every player's wizard: each Ember stack adds its amount.
func tower_damage_scale() -> float:
	return 1.0 + _buff_total(HeroData.Buff.TOWER_DAMAGE)


func _buff_total(kind: HeroData.Buff) -> float:
	var total := 0.0
	for player in players:
		if player.hero != null and player.hero.buff == kind:
			total += player.hero.amount * player.buff_stacks()
	return total


# --- Queries and actions used by card effects ---


## Towers go anywhere on the field that is off the path and not too close to another tower
## or the crystal.
func can_place_tower(pos: Vector2) -> bool:
	var margin := SimTower.SIZE / 2.0
	if not FIELD.grow(-margin).has_point(pos):
		return false
	if distance_to_path(pos) < PATH_WIDTH / 2.0 + margin:
		return false
	if pos.distance_to(core.position) < TOWER_SPACING:
		return false
	return towers_near(pos, TOWER_SPACING).is_empty()


func place_tower(data: TowerData, pos: Vector2, lifetime: float = 0.0) -> SimTower:
	var tower := SimTower.new(data, pos, lifetime)
	towers.append(tower)
	tower_placed.emit(tower)
	return tower


func spawn_enemy(unit: UnitData) -> SimEnemy:
	var enemy := SimEnemy.new(unit, path)
	enemy.died.connect(_remove_enemy)
	enemy.reached_core.connect(_on_enemy_reached_core)
	enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func towers_near(pos: Vector2, radius: float) -> Array[SimTower]:
	var found: Array[SimTower] = []
	for tower in towers:
		if tower.position.distance_to(pos) <= radius:
			found.append(tower)
	return found


func enemies_near(pos: Vector2, radius: float) -> Array[SimEnemy]:
	var found: Array[SimEnemy] = []
	for enemy in enemies:
		if enemy.is_alive() and enemy.position.distance_to(pos) <= radius:
			found.append(enemy)
	return found


func nearest_enemy(pos: Vector2, radius: float) -> SimEnemy:
	var best: SimEnemy = null
	for enemy in enemies_near(pos, radius):
		if best == null or enemy.position.distance_to(pos) < best.position.distance_to(pos):
			best = enemy
	return best


func add_lure(pos: Vector2, radius: float, duration: float) -> void:
	lures.append({"position": pos, "radius": radius, "remaining": duration})


func distance_to_path(pos: Vector2) -> float:
	return pos.distance_to(path.get_closest_point(pos))


## Crystal HP lost in the last `seconds` seconds.
func core_damage_since(seconds: float) -> int:
	var total := 0
	for hit in _damage_log:
		if hit["time"] > time - seconds:
			total += hit["amount"]
	return total


## Short hash of the simulation state. Host and client compare it after each wave (M4);
## scenario tests pin it to catch behaviour changes.
func state_hash() -> String:
	var parts := PackedStringArray(["%d %d %d %d %.3f" % [phase, wave_index, gold, core.hp, time]])
	for i in rewards.offers.size():
		if not rewards.offers[i].is_empty():
			var ids := rewards.offers[i].map(func(card: CardData) -> String: return String(card.id))
			parts.append("o %d %s" % [i, ",".join(ids)])
	for player in players:
		var hand_ids := PackedStringArray()
		for card in player.hand:
			hand_ids.append(String(card.id) if card != null else "-")
		(
			parts
			. append(
				(
					"p %.3f %d %s %d %d %s %.3f"
					% [
						player.energy.value,
						player.next_card_discount,
						",".join(hand_ids),
						player.deck.draw_pile.size(),
						player.deck.discard_pile.size(),
						String(player.hero.id) if player.hero != null else "-",
						player.empowered,
					]
				)
			)
		)
	for enemy in enemies:
		parts.append("e %s %d %.2f" % [enemy.data.id, enemy.hp, enemy.progress])
	for tower in towers:
		parts.append(
			(
				"t %s %.1f %.1f %.2f"
				% [tower.data.id, tower.position.x, tower.position.y, tower.lifetime]
			)
		)
	return "\n".join(parts).sha256_text().substr(0, 16)


# --- Internals ---


func _start_wave(index: int) -> void:
	wave_index = index
	phase = Phase.WAVE
	_spawner = WaveSpawner.new(waves[index])
	wave_started.emit(index)


func _clear_wave() -> void:
	waves_cleared += 1
	gold += GOLD_PER_WAVE
	wave_cleared.emit(wave_index)
	if wave_index == waves.size() - 1:
		gold += GOLD_FOR_WIN
		phase = Phase.WON
		run_won.emit()
	else:
		phase = Phase.BREAK
		_break_timer = WAVE_BREAK
		rewards.open()
		reward_time_left = REWARD_TIMEOUT


## Picks the first offered card for every player who has not picked yet.
func _auto_pick_rewards() -> void:
	for i in rewards.offers.size():
		if not rewards.offers[i].is_empty():
			rewards.pick(i, String(rewards.offers[i][0].id), players[i].deck)


func _step_lures(delta: float) -> void:
	for i in range(lures.size() - 1, -1, -1):
		lures[i]["remaining"] -= delta
		if lures[i]["remaining"] <= 0.0:
			lures.remove_at(i)


func _in_lure(pos: Vector2) -> bool:
	for lure in lures:
		if pos.distance_to(lure["position"]) <= lure["radius"]:
			return true
	return false


func _remove_enemy(enemy: SimEnemy) -> void:
	enemies.erase(enemy)
	enemy_removed.emit(enemy)


func _on_enemy_reached_core(enemy: SimEnemy) -> void:
	while not _damage_log.is_empty() and _damage_log[0]["time"] <= time - DAMAGE_MEMORY:
		_damage_log.pop_front()
	_damage_log.append({"time": time, "amount": enemy.data.core_damage})
	core.take_damage(enemy.data.core_damage)
	crystal_hit.emit(enemy.data.core_damage)
	_remove_enemy(enemy)


func _on_core_destroyed() -> void:
	phase = Phase.LOST
	run_lost.emit()
