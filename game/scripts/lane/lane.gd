class_name Lane
extends Node2D
## The run's simulation root: waves along the path, towers, the players' cards and wizard buffs.
##
## All simulation runs through tick() so tests (and later the network host)
## can step it with a fixed delta instead of waiting for real frames.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal run_won
signal run_lost

enum Phase { WAVE, BREAK, WON, LOST }

const PATH_WIDTH := 24.0
## Playable field above the card UI. Towers stay inside it.
const FIELD := Rect2(0, 0, 640, 288)
## Minimum distance between two towers.
const TOWER_SPACING := 24.0
## Seconds between a cleared wave and the next one.
const WAVE_BREAK := 5.0
const GOLD_PER_WAVE := 10
const GOLD_FOR_WIN := 25
## Crystal damage older than this is forgotten (Time Warp looks back 10 s).
const DAMAGE_MEMORY := 30.0
## Stacked slows never take enemies below this share of their speed.
const MIN_ENEMY_SPEED := 0.1

@export var waves: Array[WaveData] = []
## Cards the solo player brings; in co-op (M4) both decks merge into one.
@export var deck: DeckData
## One wizard per player, in player order; its buff covers the whole battlefield.
@export var heroes: Array[HeroData] = []
## Seeds the deck shuffle; same seed and inputs give the same run.
@export var rng_seed: int = 1
## When false, nothing advances on its own; call tick() manually.
@export var autorun := true

var phase := Phase.WAVE
var wave_index := 0
var waves_cleared := 0
var gold := 0
## Simulation time in seconds since the run started.
var time := 0.0
var enemies: Array[Enemy] = []
var players: Array[PlayerState] = []
## Active lures: {position: Vector2, radius: float, remaining: float}.
var lures: Array[Dictionary] = []
var _spawner: WaveSpawner
var _break_timer := 0.0
## Crystal hits: {time: float, amount: int}.
var _damage_log: Array[Dictionary] = []

@onready var path: Path2D = $Path
@onready var core: HeartCrystal = $HeartCrystal
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers


func _ready() -> void:
	var curve := path.curve
	core.position = path.position + curve.get_point_position(curve.point_count - 1)
	core.destroyed.connect(_on_core_destroyed)
	var cards: Array[CardData] = []
	if deck != null:
		cards = deck.cards
	var hero: HeroData = heroes[0] if not heroes.is_empty() else null
	players.append(PlayerState.new(Deck.new(cards, rng_seed), hero))
	if not waves.is_empty():
		_start_wave(0)
	set_physics_process(autorun)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_over():
		return
	time += delta
	for player in players:
		player.step(delta)
	if phase == Phase.BREAK:
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
	for tower in get_towers():
		tower.step(delta, enemies, damage)
		if tower.is_expired():
			towers_root.remove_child(tower)
			tower.queue_free()
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
	var margin := Tower.SIZE / 2.0
	if not FIELD.grow(-margin).has_point(pos):
		return false
	if distance_to_path(pos) < PATH_WIDTH / 2.0 + margin:
		return false
	if pos.distance_to(core.position) < TOWER_SPACING:
		return false
	return towers_near(pos, TOWER_SPACING).is_empty()


func place_tower(data: TowerData, pos: Vector2, lifetime: float = 0.0) -> Tower:
	var tower := Tower.new()
	tower.setup(data, lifetime)
	tower.position = pos
	towers_root.add_child(tower)
	return tower


func spawn_enemy(unit: UnitData) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(unit, path.curve)
	enemy.position += path.position
	enemy.died.connect(_on_enemy_died)
	enemy.reached_core.connect(_on_enemy_reached_core)
	enemies.append(enemy)
	enemies_root.add_child(enemy)
	return enemy


func get_towers() -> Array[Tower]:
	var towers: Array[Tower] = []
	for child in towers_root.get_children():
		if child is Tower:
			towers.append(child)
	return towers


func towers_near(pos: Vector2, radius: float) -> Array[Tower]:
	var found: Array[Tower] = []
	for tower in get_towers():
		if tower.position.distance_to(pos) <= radius:
			found.append(tower)
	return found


func enemies_near(pos: Vector2, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for enemy in enemies:
		if enemy.is_alive() and enemy.position.distance_to(pos) <= radius:
			found.append(enemy)
	return found


func nearest_enemy(pos: Vector2, radius: float) -> Enemy:
	var best: Enemy = null
	for enemy in enemies_near(pos, radius):
		if best == null or enemy.position.distance_to(pos) < best.position.distance_to(pos):
			best = enemy
	return best


func add_lure(pos: Vector2, radius: float, duration: float) -> void:
	lures.append({"position": pos, "radius": radius, "remaining": duration})
	queue_redraw()


func clamp_to_field(pos: Vector2) -> Vector2:
	return pos.clamp(FIELD.position, FIELD.end)


func distance_to_path(pos: Vector2) -> float:
	var local := pos - path.position
	return local.distance_to(path.curve.get_closest_point(local))


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
	for tower in get_towers():
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


func _step_lures(delta: float) -> void:
	if lures.is_empty():
		return
	for i in range(lures.size() - 1, -1, -1):
		lures[i]["remaining"] -= delta
		if lures[i]["remaining"] <= 0.0:
			lures.remove_at(i)
	queue_redraw()


func _in_lure(pos: Vector2) -> bool:
	for lure in lures:
		if pos.distance_to(lure["position"]) <= lure["radius"]:
			return true
	return false


func _remove_enemy(enemy: Enemy) -> void:
	enemies.erase(enemy)
	enemy.queue_free()


func _on_enemy_died(enemy: Enemy) -> void:
	_remove_enemy(enemy)


func _on_enemy_reached_core(enemy: Enemy) -> void:
	while not _damage_log.is_empty() and _damage_log[0]["time"] <= time - DAMAGE_MEMORY:
		_damage_log.pop_front()
	_damage_log.append({"time": time, "amount": enemy.data.core_damage})
	core.take_damage(enemy.data.core_damage)
	_remove_enemy(enemy)


func _on_core_destroyed() -> void:
	phase = Phase.LOST
	set_physics_process(false)
	run_lost.emit()


func _draw() -> void:
	draw_rect(FIELD, Palette.GROUND)
	var points := path.curve.get_baked_points()
	for i in points.size():
		points[i] += path.position
	draw_polyline(points, Palette.PATH_EDGE, PATH_WIDTH + 4.0)
	draw_polyline(points, Palette.PATH, PATH_WIDTH)
	for lure in lures:
		draw_arc(lure["position"], lure["radius"], 0.0, TAU, 32, Palette.LURE, 2.0)
		draw_rect(Rect2(lure["position"] - Vector2(4, 6), Vector2(8, 12)), Palette.LURE)
