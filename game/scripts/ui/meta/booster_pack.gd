class_name BoosterPack
extends Control
## Gray-box booster pack, drawn in code until the A3 art replaces it.


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.PLAYER_DARK)
	draw_rect(Rect2(0, 0, size.x, 20), Palette.PATH_EDGE)
	for x in range(0, int(size.x), 8):
		draw_rect(Rect2(x, 18, 4, 4), Palette.PANEL)
	var center := rect.get_center()
	draw_circle(center, 28, Palette.PANEL)
	draw_arc(center, 28, 0.0, TAU, 32, Palette.CRYSTAL, 2.0)
	UiFont.draw_centered(self, center.x, center.y - 9, "TW", Palette.CRYSTAL)
	UiFont.draw_centered(self, center.x, size.y - 40, "Booster", Palette.TEXT)
	UiFont.draw_centered(self, center.x, size.y - 24, "3 cards", Palette.CARD_TEXT_DIM)
	draw_rect(rect.grow(-1), Palette.CRYSTAL, false, 2.0)
