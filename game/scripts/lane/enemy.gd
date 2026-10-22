class_name Enemy
extends Node2D
## A goblin walking the lane path towards the Heart Crystal.

signal died(enemy: Enemy)
signal reached_core(enemy: Enemy)

const SIZE := 8.0

var data: UnitData
var hp: int
## Distance travelled along the path, in pixels.
var progress: float = 0.0
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
	var length := _curve.get_baked_length()
	progress = minf(progress + data.speed * delta, length)
	position = _curve.sample_baked(progress)
	if progress >= length:
		_alive = false
		reached_core.emit(self)


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


func _draw() -> void:
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Palette.GOBLIN)
	draw_rect(Rect2(-2, -2, 1, 1), Palette.GOBLIN_ACCENT)
	draw_rect(Rect2(1, -2, 1, 1), Palette.GOBLIN_ACCENT)
	if data != null and hp < data.max_hp:
		var ratio := float(hp) / data.max_hp
		draw_rect(Rect2(-half, -half - 3, SIZE, 1), Palette.HP_BACK)
		draw_rect(Rect2(-half, -half - 3, SIZE * ratio, 1), Palette.HP_FILL)
