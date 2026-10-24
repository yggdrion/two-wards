class_name SimEnemy
extends RefCounted
## A goblin walking the lane path towards the Heart Crystal.

signal died(enemy: SimEnemy)
signal reached_core(enemy: SimEnemy)

var data: UnitData
var hp: int
var position: Vector2
## Distance travelled along the path, in pixels.
var progress: float = 0.0
## Set by the sim each tick while the enemy stands in a lure.
var held := false
var _slow_factor := 1.0
var _slow_timer := 0.0
var _curve: Curve2D
var _alive := true


func _init(unit: UnitData, curve: Curve2D) -> void:
	data = unit
	hp = unit.max_hp
	_curve = curve
	position = curve.sample_baked(0.0)


## speed_mult is the battlefield-wide multiplier from wizard buffs (Sim.enemy_speed_scale).
func step(delta: float, speed_mult: float = 1.0) -> void:
	if not _alive:
		return
	var speed := data.speed * speed_scale() * speed_mult
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	var length := _curve.get_baked_length()
	progress = minf(progress + speed * delta, length)
	position = _curve.sample_baked(progress)
	if progress >= length:
		_alive = false
		reached_core.emit(self)


## Current speed multiplier from slows and lures.
func speed_scale() -> float:
	return 0.0 if held else _slow_factor


## Keeps the strongest slow; refreshes the duration.
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)


func is_slowed() -> bool:
	return _slow_timer > 0.0


func take_damage(amount: int) -> void:
	if not _alive:
		return
	hp = maxi(hp - maxi(amount - data.armor, 1), 0)
	if hp == 0:
		_alive = false
		died.emit(self)


func is_alive() -> bool:
	return _alive


func size() -> float:
	return 16.0 + data.armor * 4.0
