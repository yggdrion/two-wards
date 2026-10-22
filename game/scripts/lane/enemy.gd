class_name Enemy
extends Node2D
## A goblin walking the lane path towards the Heart Crystal.

signal died(enemy: Enemy)
signal reached_core(enemy: Enemy)

var data: UnitData
var hp: int
## Distance travelled along the path, in pixels.
var progress: float = 0.0
## Set by the lane each tick while the enemy stands in a lure.
var held := false
var _slow_factor := 1.0
var _slow_timer := 0.0
var _curve: Curve2D
var _alive := true


func setup(unit: UnitData, curve: Curve2D) -> void:
	data = unit
	hp = unit.max_hp
	_curve = curve
	position = curve.sample_baked(0.0)


func step(delta: float) -> void:
	if not _alive:
		return
	var speed := data.speed * speed_scale()
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
			queue_redraw()
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
	queue_redraw()


func is_slowed() -> bool:
	return _slow_timer > 0.0


func take_damage(amount: int) -> void:
	if not _alive:
		return
	hp = maxi(hp - maxi(amount - data.armor, 1), 0)
	queue_redraw()
	if hp == 0:
		_alive = false
		died.emit(self)


func is_alive() -> bool:
	return _alive


func size() -> float:
	return 8.0 + data.armor * 2.0 if data != null else 8.0


func _draw() -> void:
	var s := size()
	var half := s / 2.0
	var body := Palette.GOBLIN_ARMORED if data != null and data.armor > 0 else Palette.GOBLIN
	draw_rect(Rect2(-half, -half, s, s), body)
	draw_rect(Rect2(-2, -2, 1, 1), Palette.GOBLIN_ACCENT)
	draw_rect(Rect2(1, -2, 1, 1), Palette.GOBLIN_ACCENT)
	if is_slowed():
		draw_rect(Rect2(-half, -half, s, s), Palette.FROST, false, 1.0)
	if data != null and hp < data.max_hp:
		var ratio := float(hp) / data.max_hp
		draw_rect(Rect2(-half, -half - 3, s, 1), Palette.HP_BACK)
		draw_rect(Rect2(-half, -half - 3, s * ratio, 1), Palette.HP_FILL)
