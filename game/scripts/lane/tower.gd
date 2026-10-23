class_name Tower
extends Node2D
## A tower that shoots the enemy furthest along the path within range.
##
## TowerData picks the hit pattern: one target, area, pierce (a line) or chain.

signal fired(target: Enemy)

const SIZE := 20.0
const SHOT_FLASH := 0.08
## Half-width of a piercing shot's line.
const PIERCE_WIDTH := 12.0
## The 48x72 sprite's base sits on the tower's position.
const SPRITE_OFFSET := Vector2(-24, -66)

@export var data: TowerData

## Seconds until the tower disappears; 0 means it stays.
var lifetime := 0.0
## Mirror Image copies can't be copied again.
var is_copy := false
var _timed := false
var _cooldown := 0.0
var _buff_rate := 1.0
var _buff_timer := 0.0
var _shot_points := PackedVector2Array()
var _shot_timer := 0.0
var _sprite: Sprite2D


func setup(tower: TowerData, seconds: float = 0.0) -> void:
	data = tower
	lifetime = seconds
	_timed = seconds > 0.0
	if tower.sprite != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tower.sprite
		_sprite.centered = false
		_sprite.offset = SPRITE_OFFSET
		add_child(_sprite)
	var top := Lane.make_light(Palette.FROST, 0.5, 0.35)
	top.position = Vector2(0, -60)
	add_child(top)
	var base := Lane.make_light(Palette.LURE, 0.3, 0.3)
	base.position = Vector2(0, -28)
	add_child(base)


## damage_mult is the battlefield-wide multiplier from wizard buffs (Lane.tower_damage_scale).
func step(delta: float, enemies: Array[Enemy], damage_mult: float = 1.0) -> void:
	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			queue_redraw()
	if lifetime > 0.0:
		lifetime = maxf(lifetime - delta, 0.0)
	var rate := 1.0
	if _buff_timer > 0.0:
		rate = _buff_rate
		_buff_timer -= delta
		if _buff_timer <= 0.0:
			queue_redraw()
	_cooldown = maxf(_cooldown - delta * rate, 0.0)
	if _cooldown > 0.0:
		return
	var target := find_target(enemies)
	if target == null:
		return
	_cooldown = data.fire_interval
	var hits := _hits(target, enemies)
	_shot_points = PackedVector2Array([Vector2.ZERO])
	for enemy in hits:
		_shot_points.append(enemy.position - position)
	_shot_timer = SHOT_FLASH
	queue_redraw()
	var damage := roundi(data.damage * damage_mult)
	for enemy in hits:
		if damage > 0:
			enemy.take_damage(damage)
		if data.slow_factor < 1.0:
			enemy.apply_slow(data.slow_factor, data.slow_duration)
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


## Multiplies the fire rate for a while; a new buff replaces the old one.
func apply_buff(rate: float, duration: float) -> void:
	_buff_rate = rate
	_buff_timer = duration
	queue_redraw()


func is_buffed() -> bool:
	return _buff_timer > 0.0


## True for a timed tower whose time is up.
func is_expired() -> bool:
	return _timed and lifetime <= 0.0


func _hits(target: Enemy, enemies: Array[Enemy]) -> Array[Enemy]:
	var hits: Array[Enemy] = []
	if data.area:
		for enemy in enemies:
			if enemy.is_alive() and position.distance_to(enemy.position) <= data.attack_range:
				hits.append(enemy)
	elif data.pierce:
		var dir := (target.position - position).normalized()
		for enemy in enemies:
			var offset := enemy.position - position
			var along := offset.dot(dir)
			var across := absf(offset.cross(dir))
			if (
				enemy.is_alive()
				and along >= 0.0
				and along <= data.attack_range
				and across <= PIERCE_WIDTH
			):
				hits.append(enemy)
	else:
		hits.append(target)
		while hits.size() < data.chain_count:
			var next := _nearest_unhit(hits.back(), hits, enemies)
			if next == null:
				break
			hits.append(next)
	return hits


func _nearest_unhit(from: Enemy, hits: Array[Enemy], enemies: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_dist := data.chain_range
	for enemy in enemies:
		if not enemy.is_alive() or enemy in hits:
			continue
		var dist := from.position.distance_to(enemy.position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best


func _draw() -> void:
	if data == null:
		return
	draw_arc(Vector2.ZERO, data.attack_range, 0.0, TAU, 48, Palette.PLAYER_DARK, 2.0)
	if _sprite != null:
		# Copies and buffed towers are tinted; the tint follows every redraw.
		_sprite.modulate = Palette.COPY if is_copy else Color.WHITE
		if is_buffed():
			_sprite.modulate = Palette.SHOT
	else:
		_draw_gray_box()
	if _shot_timer > 0.0 and _shot_points.size() > 1:
		if data.area:
			draw_arc(Vector2.ZERO, data.attack_range, 0.0, TAU, 48, Palette.SHOT, 2.0)
		elif data.chain_count > 1:
			draw_polyline(_shot_points, Palette.SHOT, 2.0)
		else:
			for i in range(1, _shot_points.size()):
				draw_line(Vector2.ZERO, _shot_points[i], Palette.SHOT, 2.0)


func _draw_gray_box() -> void:
	var half := SIZE / 2.0
	var body := Palette.FROST if data.slow_factor < 1.0 else Palette.PLAYER
	if is_copy:
		body = Palette.COPY
	draw_rect(Rect2(-half, -half, SIZE, SIZE), body)
	draw_rect(Rect2(-4, -4, 8, 8), Palette.SHOT if is_buffed() else Palette.PLAYER_DARK)
