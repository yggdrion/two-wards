class_name HeartCrystal
extends Node2D
## The core both players defend. The run is lost when its HP reaches 0.

signal hp_changed(hp: int)
signal destroyed

@export var max_hp: int = 20

var hp: int


func _ready() -> void:
	hp = max_hp


func take_damage(amount: int) -> void:
	if hp == 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp)
	queue_redraw()
	if hp == 0:
		destroyed.emit()


func _draw() -> void:
	var diamond := PackedVector2Array(
		[Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)]
	)
	draw_colored_polygon(diamond, Palette.CRYSTAL)
	var ratio := float(hp) / max_hp if max_hp > 0 else 0.0
	draw_rect(Rect2(-8, 11, 16, 2), Palette.HP_BACK)
	draw_rect(Rect2(-8, 11, 16 * ratio, 2), Palette.HP_FILL)
