class_name Hud
extends Control
## Bottom strip of the run screen: run status, energy, the hand of 3 and the full card on hover.

signal card_pressed(slot: int)
signal cycle_requested(slot: int)

## Screen size in base pixels; everything below is laid out from it and Lane.FIELD.
const SCREEN := Vector2(640, 360)
const TOP := Lane.FIELD.end.y + 4.0
const CARD_X := 208.0
const CARD_GAP := CardView.COMPACT_SIZE.x + 8.0
const RIGHT_X := SCREEN.x - 116.0
const ENERGY_ICON := preload("res://assets/icons/icon_energy.png")

var lane: Lane
## Slot of the card waiting for a target, or -1.
var selected := -1
var cards: Array[CardView] = []
var _preview: CardView
var _hovered := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in PlayerState.HAND_SIZE:
		var view := CardView.new()
		view.position = Vector2(CARD_X + i * CARD_GAP, TOP + 2)
		view.pressed.connect(func(_v: CardView) -> void: card_pressed.emit(i))
		view.cycle_requested.connect(func(_v: CardView) -> void: cycle_requested.emit(i))
		view.mouse_entered.connect(func() -> void: _hovered = i)
		view.mouse_exited.connect(func() -> void: _hovered = -1 if _hovered == i else _hovered)
		add_child(view)
		cards.append(view)
	_preview = CardView.new()
	_preview.full = true
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.visible = false
	add_child(_preview)


func _process(_delta: float) -> void:
	if lane == null or lane.players.is_empty():
		return
	refresh()


## Pulls the current run state into the views.
func refresh() -> void:
	var player := lane.players[0]
	for i in cards.size():
		var view := cards[i]
		var card := player.card_at(i)
		view.card = card
		view.selected = i == selected
		view.position.y = TOP + (-6 if i == selected else 2)
		if card != null:
			view.shown_cost = player.cost_of(card)
			view.affordable = player.energy.can_spend(view.shown_cost)
	var shown := _hovered if _hovered >= 0 else selected
	_preview.visible = shown >= 0 and player.card_at(shown) != null
	if _preview.visible:
		_preview.card = player.card_at(shown)
		_preview.shown_cost = cards[shown].shown_cost
		_preview.affordable = cards[shown].affordable
		var x := clampf(cards[shown].position.x - 24, 0, SCREEN.x - CardView.FULL_SIZE.x)
		_preview.position = Vector2(x, TOP - CardView.FULL_SIZE.y - 4)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Palette.PANEL)
	draw_line(Vector2(0, TOP), Vector2(SCREEN.x, TOP), Palette.PATH_EDGE, 2.0)
	if lane == null or lane.players.is_empty():
		return
	var player := lane.players[0]
	UiFont.draw(
		self,
		Vector2(8, TOP + 6),
		"Wave %d/%d" % [lane.wave_index + 1, lane.waves.size()],
		Palette.TEXT
	)
	UiFont.draw(
		self, Vector2(8, TOP + 24), "Crystal %d/%d" % [lane.core.hp, lane.core.max_hp], Palette.TEXT
	)
	UiFont.draw(self, Vector2(8, TOP + 42), "Gold %d" % lane.gold, Palette.ENERGY)
	_draw_energy(player, Vector2(8, TOP + 68))
	UiFont.draw(
		self, Vector2(RIGHT_X, TOP + 6), "Deck %d" % player.deck.draw_pile.size(), Palette.TEXT
	)
	UiFont.draw(
		self, Vector2(RIGHT_X, TOP + 24), "Disc %d" % player.deck.discard_pile.size(), Palette.TEXT
	)
	UiFont.draw(self, Vector2(RIGHT_X, TOP + 60), "1-3 play", Palette.CARD_TEXT_DIM)
	UiFont.draw(self, Vector2(RIGHT_X, TOP + 78), "RMB/Q", Palette.CARD_TEXT_DIM)
	UiFont.draw(self, Vector2(RIGHT_X, TOP + 96), "cycle 1", Palette.CARD_TEXT_DIM)
	_draw_banner()


func _draw_energy(player: PlayerState, pos: Vector2) -> void:
	draw_texture(ENERGY_ICON, pos)
	var points := player.energy.points()
	for i in Energy.MAX:
		var cell := Rect2(pos.x + 36 + (i % 5) * 18, pos.y + 2 + (i / 5) * 16, 14, 12)
		draw_rect(cell, Palette.ENERGY if i < points else Palette.PATH)
	UiFont.draw(self, Vector2(pos.x, pos.y + 36), "Energy %d" % points, Palette.ENERGY)


func _draw_banner() -> void:
	var text := ""
	match lane.phase:
		Lane.Phase.BREAK:
			text = "Wave %d cleared" % (lane.wave_index + 1)
		Lane.Phase.WON:
			text = "Victory! +%d gold" % lane.gold
		Lane.Phase.LOST:
			text = "The crystal shattered"
	if text.is_empty():
		return
	var w := UiFont.width(text) + 16
	draw_rect(Rect2(SCREEN.x / 2.0 - w / 2.0, 4, w, 22), Palette.PANEL)
	UiFont.draw_centered(self, SCREEN.x / 2.0, 6, text, Palette.TEXT)
