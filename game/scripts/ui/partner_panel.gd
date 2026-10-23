class_name PartnerPanel
extends Control
## The partner in a co-op run: name, wizard portrait and buff, energy and hand. Clicking it
## while a card is selected passes that card to the partner.

signal pressed

const SIZE := Vector2(172, 104)
const PORTRAIT := Vector2(32, 32)
const PAD := 4.0

var player: PlayerState:
	set(value):
		player = value
		_update_portrait()
var player_name := "Partner"
## A card is selected and could be passed now; the frame lights up.
var can_receive := false
var _portrait: TextureRect


func _init() -> void:
	size = SIZE
	mouse_filter = MOUSE_FILTER_STOP
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.size = PORTRAIT
	_portrait.position = Vector2(PAD, PAD)
	_portrait.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_portrait)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _update_portrait() -> void:
	var hero := player.hero if player != null else null
	_portrait.texture = hero.portrait if hero != null else null
	_portrait.material = hero.portrait_material if hero != null else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PANEL)
	draw_rect(
		Rect2(Vector2.ONE, SIZE - Vector2(2, 2)),
		Palette.VALID if can_receive else Palette.PATH_EDGE,
		false,
		2.0
	)
	if player == null:
		return
	var x := PAD * 2 + PORTRAIT.x
	UiFont.draw(self, Vector2(x, PAD), player_name, Palette.TEXT)
	var wizard := player.hero.display_name if player.hero != null else "No wizard"
	UiFont.draw(self, Vector2(x, PAD + UiFont.LINE), wizard, Palette.CARD_TEXT_DIM)
	var energy := "E%d" % player.energy.points()
	UiFont.draw(self, Vector2(SIZE.x - PAD - UiFont.width(energy), PAD), energy, Palette.ENERGY)
	var y := PAD + PORTRAIT.y + 2
	for card in player.hand:
		var line := "-" if card == null else "%d %s" % [player.cost_of(card), card.display_name]
		UiFont.draw(
			self, Vector2(PAD * 2, y), line, Palette.TEXT if card != null else Palette.CARD_TEXT_DIM
		)
		y += UiFont.LINE
