class_name Tower
extends Node2D
## A tower that shoots the enemy furthest along the path within range.

signal fired(target: Enemy)

const SIZE := 10.0
const SHOT_FLASH := 0.08

@export var data: TowerData

var _cooldown := 0.0
var _shot_target := Vector2.ZERO
var _shot_timer := 0.0


func setup(tower: TowerData) -> void:
	data = tower


func step(delta: float, enemies: Array[Enemy]) -> void:
	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			queue_redraw()
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	var target := find_target(enemies)
	if target == null:
		return
	_cooldown = data.fire_interval
	_shot_target = target.position - position
	_shot_timer = SHOT_FLASH
	queue_redraw()
	target.take_damage(data.damage)
	fired.emit(target)


func find_target(enemies: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		if position.distance_to(enemy.position) > data.attack_range:
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _draw() -> void:
	if data != null:
		draw_arc(Vector2.ZERO, data.attack_range, 0.0, TAU, 48, Palette.PLAYER_DARK, 1.0)
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Palette.PLAYER)
	draw_rect(Rect2(-2, -2, 4, 4), Palette.PLAYER_DARK)
	if _shot_timer > 0.0:
		draw_line(Vector2.ZERO, _shot_target, Palette.SHOT, 1.0)
