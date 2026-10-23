class_name Hud
extends Control
## Slim bottom bar of the run screen: run status, the hand of 3 as mini cards and energy. The
## full card shows above the hand while the mouse is on a card, never while aiming one. In
## co-op a card passed by the partner shows as a fourth card, and the partner panel shows the
## partner's name, wizard and hand. After a cleared wave the reward offer shows as full cards
## over the field until the player picks one.

signal card_pressed(slot: int)
signal cycle_requested(slot: int)
## The partner panel was clicked: pass the selected card.
signal pass_requested
## A card of the reward offer was clicked.
signal reward_picked(card_id: String)

## Screen size in base pixels; everything below is laid out from it and Lane.FIELD.
const SCREEN := Vector2(640, 360)
const TOP := Lane.FIELD.end.y
const CARD_X := 184.0
const CARD_GAP := CardView.MINI_SIZE.x + 8.0
const RIGHT_X := 520.0
## Card spacing while the hand holds a gift card: four cards overlap to fit before RIGHT_X.
const CROWDED_GAP := (RIGHT_X - 8.0 - CARD_X - CardView.MINI_SIZE.x) / PlayerState.HAND_SIZE
const CONTINUE_HINT := "Click to continue"
const REWARD_GAP := 16.0
const REWARD_Y := 40.0

var lane: Lane
## The player this screen belongs to (co-op: 0 on the host, 1 on the client).
var player_index := 0
## Player names in co-op, host first; empty when playing solo.
var names: Array = []
## Shown as the banner when set, e.g. when the partner left.
var notice := ""
var partner_panel: PartnerPanel
## Slot of the card waiting for a target, or -1.
var selected := -1
var cards: Array[CardView] = []
## The reward offer, one full card per choice.
var rewards: Array[CardView] = []
var _preview: CardView
var _hovered := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in PlayerState.GIFT_SLOT + 1:
		var view := CardView.new()
		view.mini = true
		view.position = Vector2(CARD_X + i * CARD_GAP, TOP + 4)
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
	var row := RunRewards.CHOICES * (CardView.FULL_SIZE.x + REWARD_GAP) - REWARD_GAP
	for i in RunRewards.CHOICES:
		var view := CardView.new()
		view.full = true
		view.visible = false
		view.position = Vector2(
			(SCREEN.x - row) / 2.0 + i * (CardView.FULL_SIZE.x + REWARD_GAP), REWARD_Y
		)
		view.pressed.connect(func(v: CardView) -> void: reward_picked.emit(String(v.card.id)))
		add_child(view)
		rewards.append(view)
	partner_panel = PartnerPanel.new()
	partner_panel.visible = false
	partner_panel.pressed.connect(pass_requested.emit)
	add_child(partner_panel)


func _process(_delta: float) -> void:
	if lane == null or lane.players.is_empty():
		return
	refresh()


## The player this screen belongs to.
func own_player() -> PlayerState:
	return lane.players[player_index]


## Pulls the current run state into the views.
func refresh() -> void:
	var player := own_player()
	var gap := CROWDED_GAP if player.hand.size() > PlayerState.HAND_SIZE else CARD_GAP
	for i in cards.size():
		var view := cards[i]
		var card := player.card_at(i)
		view.card = card
		view.visible = i < PlayerState.HAND_SIZE or card != null
		view.selected = i == selected
		view.position = Vector2(CARD_X + i * gap, TOP + (-4 if i == selected else 4))
		if card != null:
			view.shown_cost = player.cost_of(card)
			view.affordable = player.energy.can_spend(view.shown_cost)
	var shown := _hovered if selected < 0 else -1
	_preview.visible = shown >= 0 and player.card_at(shown) != null
	if _preview.visible:
		_preview.card = player.card_at(shown)
		_preview.shown_cost = cards[shown].shown_cost
		_preview.affordable = cards[shown].affordable
		var x := clampf(cards[shown].position.x - 24, 0, SCREEN.x - CardView.FULL_SIZE.x)
		_preview.position = Vector2(x, TOP - CardView.FULL_SIZE.y - 4)
	var offer: Array = lane.rewards.offers[player_index]
	for i in rewards.size():
		rewards[i].visible = i < offer.size()
		if rewards[i].visible:
			rewards[i].card = offer[i]
	_refresh_partner()
	queue_redraw()


## True while the full card covers part of the field.
func is_preview_shown() -> bool:
	return _preview.visible


func _draw() -> void:
	draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Palette.PANEL)
	draw_line(Vector2(0, TOP), Vector2(SCREEN.x, TOP), Palette.PATH_EDGE, 2.0)
	if lane == null or lane.players.is_empty():
		return
	var player := own_player()
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
	_draw_wizard(player)
	_draw_energy(player, Vector2(RIGHT_X, TOP + 4))
	UiFont.draw(
		self,
		Vector2(RIGHT_X, TOP + 34),
		"Deck %d" % player.deck.draw_pile.size(),
		Palette.CARD_TEXT_DIM
	)
	UiFont.draw(
		self,
		Vector2(RIGHT_X, TOP + 50),
		"Disc %d" % player.deck.discard_pile.size(),
		Palette.CARD_TEXT_DIM
	)
	_draw_banner()


## Wizard and its battlefield buff in the field's top-left corner; brighter while empowered.
func _draw_wizard(player: PlayerState) -> void:
	if player.hero == null:
		return
	var text := "%s: %s" % [player.hero.display_name, player.hero.buff_label(player.buff_stacks())]
	var color := Palette.TEXT
	if player.empowered > 0.0:
		text += " (x2, %d s)" % ceili(player.empowered)
		color = Palette.ENERGY
	draw_rect(Rect2(4, 4, UiFont.width(text) + 8, UiFont.LINE), Palette.PANEL)
	UiFont.draw(self, Vector2(8, 4), text, color)


func _draw_energy(player: PlayerState, pos: Vector2) -> void:
	var points := player.energy.points()
	UiFont.draw(self, pos, "Energy %d" % points, Palette.ENERGY)
	for i in Energy.MAX:
		var cell := Rect2(pos.x + i * 11, pos.y + 18, 8, 8)
		draw_rect(cell, Palette.ENERGY if i < points else Palette.PATH)


func _refresh_partner() -> void:
	partner_panel.visible = lane.players.size() == 2
	if not partner_panel.visible:
		return
	var partner := 1 - player_index
	partner_panel.player = lane.players[partner]
	partner_panel.player_name = str(names[partner]) if partner < names.size() else "Partner"
	partner_panel.position = Vector2(4, TOP - PartnerPanel.SIZE.y - 4)
	partner_panel.can_receive = (
		selected >= 0 and own_player().can_pass(selected, lane.players[partner])
	)
	partner_panel.queue_redraw()


func _draw_banner() -> void:
	var text := ""
	var hint := ""
	if not notice.is_empty() and not lane.is_over():
		text = notice
		hint = CONTINUE_HINT
	else:
		match lane.phase:
			Lane.Phase.BREAK:
				text = "Wave %d cleared" % (lane.wave_index + 1)
				if not lane.rewards.offers[player_index].is_empty():
					hint = (
						"Pick a card for your deck (1-%d)"
						% lane.rewards.offers[player_index].size()
					)
				elif lane.rewards.is_open():
					hint = "Waiting for your partner to pick"
			Lane.Phase.WON:
				text = "Victory! +%d gold" % lane.gold
				hint = CONTINUE_HINT
			Lane.Phase.LOST:
				text = "The crystal shattered. +%d gold" % lane.gold
				hint = CONTINUE_HINT
	if text.is_empty():
		return
	var w := maxf(UiFont.width(text), UiFont.width(hint)) + 16
	var h := 22.0 if hint.is_empty() else 22.0 + UiFont.LINE
	draw_rect(Rect2(SCREEN.x / 2.0 - w / 2.0, 4, w, h), Palette.PANEL)
	UiFont.draw_centered(self, SCREEN.x / 2.0, 6, text, Palette.TEXT)
	if not hint.is_empty():
		UiFont.draw_centered(self, SCREEN.x / 2.0, 6 + UiFont.LINE, hint, Palette.CARD_TEXT_DIM)
