class_name CardView
extends Control
## Draws a card from its parts at runtime: rarity frame, art, cost and text in the pixel font.
##
## Mini (96x64, the run's hand) shows an art crop and the cost; compact (96x128, the meta
## screens) adds the name; full (144x208, on hover) adds the whole art and the rules text. Numbers
## are never baked into art.

signal pressed(view: CardView)
signal cycle_requested(view: CardView)

const COMPACT_SIZE := Vector2(96, 128)
const FULL_SIZE := Vector2(144, 208)
const MINI_SIZE := Vector2(96, 64)
## Part of the 128x96 art shown on a compact card.
const COMPACT_CROP := Rect2(20, 16, 88, 60)
## Part of the art shown on a mini card.
const MINI_CROP := Rect2(20, 16, 88, 56)
## Width of the rarity frame and the cost badge outline.
const BORDER := 2.0

var card: CardData:
	set(value):
		card = value
		queue_redraw()
var full := false:
	set(value):
		full = value
		_update_size()
var mini := false:
	set(value):
		mini = value
		_update_size()
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
## Shows the card back (booster opening, cards not owned yet).
var face_down := false:
	set(value):
		face_down = value
		queue_redraw()


func _init() -> void:
	size = COMPACT_SIZE
	custom_minimum_size = size


func _update_size() -> void:
	size = FULL_SIZE if full else (MINI_SIZE if mini else COMPACT_SIZE)
	custom_minimum_size = size
	queue_redraw()


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


static func kind_color(kind: CardData.Kind) -> Color:
	match kind:
		CardData.Kind.TOWER:
			return Palette.KIND_TOWER
		CardData.Kind.BUFF:
			return Palette.KIND_BUFF
		CardData.Kind.HERO:
			return Palette.KIND_HERO
	return Palette.KIND_SPELL


static func kind_label(kind: CardData.Kind) -> String:
	match kind:
		CardData.Kind.TOWER:
			return "Tower"
		CardData.Kind.BUFF:
			return "Buff"
		CardData.Kind.HERO:
			return "Hero"
	return "Spell"


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if face_down:
		_draw_back(rect)
		return
	if card == null:
		draw_rect(rect, Palette.PANEL)
		draw_rect(rect.grow(-BORDER / 2.0), Palette.PATH_EDGE, false, BORDER)
		return
	draw_rect(rect, Palette.CARD_BG)
	if full:
		_draw_full()
	elif mini:
		_draw_mini()
	else:
		_draw_compact()
	var border := Palette.SHOT if selected else rarity_color(card.rarity)
	draw_rect(rect.grow(-BORDER / 2.0), border, false, BORDER)
	_draw_cost()
	_draw_kind()


func _draw_compact() -> void:
	if card.art != null:
		draw_texture_rect_region(card.art, Rect2(4, 4, 88, 60), COMPACT_CROP)
	UiFont.draw_wrapped(self, Vector2(4, 68), card.display_name, 88, 3, Palette.TEXT)


func _draw_mini() -> void:
	if card.art != null:
		draw_texture_rect_region(card.art, Rect2(4, 4, 88, 56), MINI_CROP)


func _draw_full() -> void:
	if card.art != null:
		draw_texture_rect(card.art, Rect2(8, 8, 128, 96), false)
	UiFont.draw_centered(self, 72, 106, card.display_name, Palette.TEXT)
	UiFont.draw_centered(self, 72, 122, kind_label(card.kind), kind_color(card.kind))
	UiFont.draw_wrapped(self, Vector2(8, 140), card.text, 128, 4, Palette.CARD_TEXT_DIM)


func _draw_cost() -> void:
	var cost := card.cost if shown_cost < 0 else shown_cost
	var badge := Rect2(2, 2, 20, 20)
	draw_rect(badge, Palette.PANEL)
	draw_rect(
		badge.grow(-BORDER / 2.0), Palette.ENERGY if affordable else Palette.INVALID, false, BORDER
	)
	UiFont.draw_centered(self, 12, 5, str(cost), Palette.ENERGY if affordable else Palette.INVALID)


## Kind badge in the top-right corner. The symbol's shape tells the kind without its color:
## turret = tower, sparkle = spell, up arrow = buff, crown = hero.
func _draw_kind() -> void:
	var color := kind_color(card.kind)
	var badge := Rect2(size.x - 22, 2, 20, 20)
	draw_rect(badge, Palette.PANEL)
	draw_rect(badge.grow(-BORDER / 2.0), color, false, BORDER)
	var c := badge.get_center()
	var points: PackedVector2Array
	match card.kind:
		CardData.Kind.TOWER:
			draw_rect(Rect2(c.x - 4, c.y - 3, 8, 9), color)
			for x in [-6.0, -1.5, 3.0]:
				draw_rect(Rect2(c.x + x, c.y - 6, 3, 3), color)
			return
		CardData.Kind.BUFF:
			points = [
				Vector2(0, -7),
				Vector2(6, -1),
				Vector2(2, -1),
				Vector2(2, 6),
				Vector2(-2, 6),
				Vector2(-2, -1),
				Vector2(-6, -1)
			]
		CardData.Kind.HERO:
			points = [
				Vector2(-6, 5),
				Vector2(-6, -4),
				Vector2(-3, 0),
				Vector2(0, -6),
				Vector2(3, 0),
				Vector2(6, -4),
				Vector2(6, 5)
			]
		_:
			points = [
				Vector2(0, -7),
				Vector2(2, -2),
				Vector2(7, 0),
				Vector2(2, 2),
				Vector2(0, 7),
				Vector2(-2, 2),
				Vector2(-7, 0),
				Vector2(-2, -2)
			]
	draw_colored_polygon(Transform2D(0.0, c) * points, color)


func _draw_back(rect: Rect2) -> void:
	draw_rect(rect, Palette.PLAYER_DARK)
	var inner := rect.grow(-8)
	draw_rect(inner, Palette.PANEL)
	var center := rect.get_center()
	var r := minf(inner.size.x, inner.size.y) * 0.3
	var diamond := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		]
	)
	draw_colored_polygon(diamond, Palette.PLAYER_DARK)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), Palette.CRYSTAL, BORDER)
	draw_rect(rect.grow(-BORDER / 2.0), Palette.PATH_EDGE, false, BORDER)
