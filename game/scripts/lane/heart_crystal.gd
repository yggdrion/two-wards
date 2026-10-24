class_name HeartCrystal
extends Node2D
## Draws the SimCrystal: the Sprite child, a light and the HP bar.

var model: SimCrystal


func _ready() -> void:
	var light := Lane.make_light(Palette.CRYSTAL, 0.9, 0.9)
	light.position = Vector2(0, -30)
	add_child(light)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	var ratio := float(model.hp) / model.max_hp if model.max_hp > 0 else 0.0
	draw_rect(Rect2(-16, 22, 32, 4), Palette.HP_BACK)
	draw_rect(Rect2(-16, 22, 32 * ratio, 4), Palette.HP_FILL)
