class_name Enemy
extends Node2D
## Draws one SimEnemy: sprite (or gray box), shadow, frost tint and HP bar.

## Values above 1 cancel part of the lane's dusk: units stay the highest-contrast thing on
## screen (STYLE_GUIDE section 5).
const UNIT_LIFT := Color(1.5, 1.5, 1.25)
## Frame anchor: feet on row 59 of the 64x64 frame stand on the enemy's position.
const SPRITE_OFFSET := Vector2(-32, -59)

var model: SimEnemy
var _sprite: AnimatedSprite2D


func setup(enemy: SimEnemy) -> void:
	model = enemy
	position = enemy.position
	modulate = UNIT_LIFT
	if enemy.data.frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = enemy.data.frames
		_sprite.centered = false
		_sprite.offset = SPRITE_OFFSET
		_sprite.play(&"walk_side")
		add_child(_sprite)


func _process(_delta: float) -> void:
	if _sprite != null and absf(model.position.x - position.x) > 0.01:
		_sprite.flip_h = model.position.x < position.x
	position = model.position
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		_draw_sprite_overlay()
		return
	var data := model.data
	var s := model.size()
	var half := s / 2.0
	var body := Palette.GOBLIN_ARMORED if data.armor > 0 else Palette.GOBLIN
	draw_rect(Rect2(-half, -half, s, s), body)
	draw_rect(Rect2(-4, -4, 2, 2), Palette.GOBLIN_ACCENT)
	draw_rect(Rect2(2, -4, 2, 2), Palette.GOBLIN_ACCENT)
	if model.is_slowed():
		draw_rect(Rect2(-half, -half, s, s), Palette.FROST, false, 2.0)
	if model.hp < model.max_hp:
		var ratio := float(model.hp) / model.max_hp
		draw_rect(Rect2(-half, -half - 6, s, 2), Palette.HP_BACK)
		draw_rect(Rect2(-half, -half - 6, s * ratio, 2), Palette.HP_FILL)


## Shadow under the feet, frost tint while slowed, HP bar over the head.
func _draw_sprite_overlay() -> void:
	var ellipse := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		ellipse.append(Vector2(cos(a) * 12.0, sin(a) * 4.0))
	draw_colored_polygon(ellipse, Palette.HP_BACK)
	_sprite.modulate = Palette.FROST if model.is_slowed() else Color.WHITE
	if model.hp < model.max_hp:
		var ratio := float(model.hp) / model.max_hp
		draw_rect(Rect2(-8, -34, 16, 2), Palette.HP_BACK)
		draw_rect(Rect2(-8, -34, 16 * ratio, 2), Palette.HP_FILL)
