class_name CardView
extends Control
## Draws a card from its parts at runtime: rarity frame, art, cost and text in the pixel font.
##
## Compact (48x64, the hand) shows an art crop, cost and name; full (72x104, on hover) adds the
## whole art and the rules text. Numbers are never baked into art.

signal pressed(view: CardView)
signal cycle_requested(view: CardView)

const COMPACT_SIZE := Vector2(48, 64)
const FULL_SIZE := Vector2(72, 104)
## Part of the 64x48 art shown on a compact card.
const COMPACT_CROP := Rect2(10, 8, 44, 30)

var card: CardData:
	set(value):
		card = value
		queue_redraw()
var full := false:
	set(value):
		full = value
		size = FULL_SIZE if full else COMPACT_SIZE
		custom_minimum_size = size
		queue_redraw()
## Cost to show (after discounts); -1 shows the card's own cost.
var shown_cost := -1:
	set(value):
		shown_cost = value
		queue_redraw()
var affordable := true:
	set(value):
		affordable = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _init() -> void:
	size = COMPACT_SIZE
	custom_minimum_size = size


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		cycle_requested.emit(self)
		accept_event()


static func rarity_color(rarity: CardData.Rarity) -> Color:
	match rarity:
		CardData.Rarity.RARE:
			return Palette.RARITY_RARE
		CardData.Rarity.EPIC:
			return Palette.RARITY_EPIC
	return Palette.RARITY_COMMON


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if card == null:
		draw_rect(rect, Palette.PANEL)
		draw_rect(rect.grow(-0.5), Palette.PATH_EDGE, false, 1.0)
		return
	draw_rect(rect, Palette.CARD_BG)
	if full:
		_draw_full()
	else:
		_draw_compact()
	var border := Palette.SHOT if selected else rarity_color(card.rarity)
	draw_rect(rect.grow(-0.5), border, false, 1.0)
	_draw_cost()


func _draw_compact() -> void:
	if card.art != null:
		draw_texture_rect_region(card.art, Rect2(2, 2, 44, 30), COMPACT_CROP)
	UiFont.draw_wrapped(self, Vector2(2, 34), card.display_name, 44, 3, Palette.TEXT)


func _draw_full() -> void:
	if card.art != null:
		draw_texture_rect(card.art, Rect2(4, 4, 64, 48), false)
	UiFont.draw_centered(self, 36, 53, card.display_name, Palette.TEXT)
	UiFont.draw_wrapped(self, Vector2(4, 63), card.text, 64, 5, Palette.CARD_TEXT_DIM)


func _draw_cost() -> void:
	var cost := card.cost if shown_cost < 0 else shown_cost
	var badge := Rect2(1, 1, 9, 9)
	draw_rect(badge, Palette.PANEL)
	draw_rect(badge.grow(-0.5), Palette.ENERGY if affordable else Palette.INVALID, false, 1.0)
	UiFont.draw_centered(self, 5.5, 1, str(cost), Palette.ENERGY if affordable else Palette.INVALID)
