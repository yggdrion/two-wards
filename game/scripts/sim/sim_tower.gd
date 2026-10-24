class_name SimTower
extends RefCounted
## A tower that shoots the enemy furthest along the path within range.
##
## TowerData picks the hit pattern: one target, area, pierce (a line) or chain.

const SIZE := 20.0
## Half-width of a piercing shot's line.
const PIERCE_WIDTH := 12.0

var data: TowerData
var position: Vector2
## Seconds until the tower disappears; 0 means it stays.
var lifetime := 0.0
## Mirror Image copies can't be copied again.
var is_copy := false
var _timed := false
var _cooldown := 0.0
var _buff_rate := 1.0
var _buff_timer := 0.0


func _init(tower: TowerData, at: Vector2 = Vector2.ZERO, seconds: float = 0.0) -> void:
	data = tower
	position = at
	lifetime = seconds
	_timed = seconds > 0.0


## damage_mult is the battlefield-wide multiplier from wizard buffs (Sim.tower_damage_scale).
## Returns the enemies hit, empty if the tower didn't fire.
func step(delta: float, enemies: Array[SimEnemy], damage_mult: float = 1.0) -> Array[SimEnemy]:
	if lifetime > 0.0:
		lifetime = maxf(lifetime - delta, 0.0)
	var rate := 1.0
	if _buff_timer > 0.0:
		rate = _buff_rate
		_buff_timer -= delta
	_cooldown = maxf(_cooldown - delta * rate, 0.0)
	if _cooldown > 0.0:
		return []
	var target := find_target(enemies)
	if target == null:
		return []
	_cooldown = data.fire_interval
	var hits := _hits(target, enemies)
	var damage := roundi(data.damage * damage_mult)
	for enemy in hits:
		if damage > 0:
			enemy.take_damage(damage)
		if data.slow_factor < 1.0:
			enemy.apply_slow(data.slow_factor, data.slow_duration)
	return hits


func find_target(enemies: Array[SimEnemy]) -> SimEnemy:
	var best: SimEnemy = null
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


func is_buffed() -> bool:
	return _buff_timer > 0.0


## True for a timed tower whose time is up.
func is_expired() -> bool:
	return _timed and lifetime <= 0.0


func _hits(target: SimEnemy, enemies: Array[SimEnemy]) -> Array[SimEnemy]:
	var hits: Array[SimEnemy] = []
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


func _nearest_unhit(from: SimEnemy, hits: Array[SimEnemy], enemies: Array[SimEnemy]) -> SimEnemy:
	var best: SimEnemy = null
	var best_dist := data.chain_range
	for enemy in enemies:
		if not enemy.is_alive() or enemy in hits:
			continue
		var dist := from.position.distance_to(enemy.position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best
