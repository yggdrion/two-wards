class_name Tower
extends Node2D
## Draws one SimTower: sprite (or gray box), range ring, lights, tints and the shot flash.

const SHOT_FLASH := 0.08
## The 48x72 sprite's base sits on the tower's position.
const SPRITE_OFFSET := Vector2(-24, -66)

var model: SimTower
var _shot_points := PackedVector2Array()
var _shot_timer := 0.0
var _sprite: Sprite2D


func setup(tower: SimTower) -> void:
	model = tower
	position = tower.position
	if tower.data.sprite != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tower.data.sprite
		_sprite.centered = false
		_sprite.offset = SPRITE_OFFSET
		add_child(_sprite)
	var top := Lane.make_light(tower.data.light_color, 0.5, 0.35)
	top.position = Vector2(0, -60)
	add_child(top)
	var base := Lane.make_light(Palette.LURE, 0.3, 0.3)
	base.position = Vector2(0, -28)
	add_child(base)


## Shows a shot at the enemies the tower just hit.
func flash(hits: Array[SimEnemy]) -> void:
	_shot_points = PackedVector2Array([Vector2.ZERO])
	for enemy in hits:
		_shot_points.append(enemy.position - position)
	_shot_timer = SHOT_FLASH


func is_flashing() -> bool:
	return _shot_timer > 0.0


func _process(delta: float) -> void:
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var data := model.data
	draw_arc(Vector2.ZERO, data.attack_range, 0.0, TAU, 48, Palette.PLAYER_DARK, 2.0)
	if _sprite != null:
		# Copies and buffed towers are tinted; the tint follows every redraw.
		_sprite.modulate = Palette.COPY if model.is_copy else Color.WHITE
		if model.is_buffed():
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
	var half := SimTower.SIZE / 2.0
	var body := Palette.FROST if model.data.slow_factor < 1.0 else Palette.PLAYER
	if model.is_copy:
		body = Palette.COPY
	draw_rect(Rect2(-half, -half, SimTower.SIZE, SimTower.SIZE), body)
	draw_rect(Rect2(-4, -4, 8, 8), Palette.SHOT if model.is_buffed() else Palette.PLAYER_DARK)
