class_name Lane
extends Node2D
## Gray-box lane: spawns a wave along the path, ticks enemies and towers.
##
## All simulation runs through tick() so tests (and later the network host)
## can step it with a fixed delta instead of waiting for real frames.

signal wave_cleared
signal run_lost

const PATH_WIDTH := 12.0

@export var wave: WaveData
## When false, nothing advances on its own; call tick() manually.
@export var autorun := true

var enemies: Array[Enemy] = []
var _spawner: WaveSpawner
var _cleared := false

@onready var path: Path2D = $Path
@onready var core: HeartCrystal = $HeartCrystal
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var status_label: Label = $Status


func _ready() -> void:
	_spawner = WaveSpawner.new(wave)
	var curve := path.curve
	core.position = path.position + curve.get_point_position(curve.point_count - 1)
	core.hp_changed.connect(_on_core_hp_changed)
	core.destroyed.connect(_on_core_destroyed)
	set_physics_process(autorun)
	_update_status()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	for i in _spawner.step(delta):
		_spawn_enemy()
	for enemy in enemies.duplicate():
		enemy.step(delta)
	for tower in get_towers():
		tower.step(delta, enemies)
	if not _cleared and _spawner.is_done() and enemies.is_empty():
		_cleared = true
		_update_status()
		wave_cleared.emit()


func get_towers() -> Array[Tower]:
	var towers: Array[Tower] = []
	for child in towers_root.get_children():
		if child is Tower:
			towers.append(child)
	return towers


func is_cleared() -> bool:
	return _cleared


func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	enemy.setup(wave.enemy, path.curve)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_core.connect(_on_enemy_reached_core)
	enemies.append(enemy)
	enemies_root.add_child(enemy)


func _remove_enemy(enemy: Enemy) -> void:
	enemies.erase(enemy)
	enemy.queue_free()


func _on_enemy_died(enemy: Enemy) -> void:
	_remove_enemy(enemy)


func _on_enemy_reached_core(enemy: Enemy) -> void:
	core.take_damage(enemy.data.core_damage)
	_remove_enemy(enemy)


func _on_core_hp_changed(_hp: int) -> void:
	_update_status()


func _on_core_destroyed() -> void:
	set_physics_process(false)
	run_lost.emit()


func _update_status() -> void:
	var text := "Crystal %d/%d" % [core.hp, core.max_hp]
	if _cleared:
		text += "  Wave cleared"
	status_label.text = text


func _draw() -> void:
	draw_rect(get_viewport_rect(), Palette.GROUND)
	var points := path.curve.get_baked_points()
	for i in points.size():
		points[i] += path.position
	draw_polyline(points, Palette.PATH_EDGE, PATH_WIDTH + 2.0)
	draw_polyline(points, Palette.PATH, PATH_WIDTH)
