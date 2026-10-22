class_name DeckBuilderScreen
extends MetaScreen
## Builds the saved decks: click a card on the left to add a copy, click a deck row on the
## right to take one out. Deck rules are DeckRules; only owned copies can go in.

const LIST_TOP := 72.0
const LEFT := Rect2(8, LIST_TOP, 232, 280)
const RIGHT := Rect2(400, LIST_TOP, 232, 280)
const PREVIEW_POS := Vector2(248, LIST_TOP)

## The deck being edited.
var editing := 0
var deck_tabs: Array[Button] = []
## One row per catalog card, in catalog order.
var card_rows: Array[Button] = []
var deck_rows: VBoxContainer
var active_button: Button
var _deck_title: Label
var _status: Label
var _preview: CardView


func build() -> void:
	add_header("Decks")
	editing = profile.active_deck
	for i in DeckRules.MAX_DECKS:
		var tab := button("", select_deck.bind(i))
		tab.toggle_mode = true
		tab.position = Vector2(8 + i * 128, 36)
		tab.size = Vector2(120, 28)
		add_child(tab)
		deck_tabs.append(tab)
	var left := _list_panel(LEFT, label("Collection"))
	for card in catalog.all():
		var row := _row(card, add_card.bind(String(card.id)))
		left.add_child(row)
		card_rows.append(row)
	_deck_title = label("")
	deck_rows = _list_panel(RIGHT, _deck_title)
	_preview = CardView.new()
	_preview.full = true
	_preview.visible = false
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.position = PREVIEW_POS
	add_child(_preview)
	_status = label("", &"DimLabel")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.position = Vector2(PREVIEW_POS.x - 4, 284)
	_status.size = Vector2(CardView.FULL_SIZE.x + 8, 40)
	add_child(_status)
	active_button = button("Use this deck", func() -> void: profile.set_active_deck(editing))
	active_button.position = Vector2(PREVIEW_POS.x, 322)
	active_button.size = Vector2(CardView.FULL_SIZE.x, 28)
	add_child(active_button)


func select_deck(index: int) -> void:
	editing = index
	refresh()


func add_card(card_id: String) -> void:
	var cards := profile.deck_cards(editing).duplicate()
	if DeckRules.can_add(cards, card_id, profile.collection):
		cards.append(card_id)
		cards.sort_custom(_catalog_order)
		profile.set_deck_cards(editing, cards)


func remove_card(card_id: String) -> void:
	var cards := profile.deck_cards(editing).duplicate()
	cards.erase(card_id)
	profile.set_deck_cards(editing, cards)


func refresh() -> void:
	var cards := profile.deck_cards(editing)
	for i in deck_tabs.size():
		var marker := "*" if i == profile.active_deck else ""
		deck_tabs[i].text = "%s%s" % [profile.decks[i]["name"], marker]
		deck_tabs[i].set_pressed_no_signal(i == editing)
	var all := catalog.all()
	for i in all.size():
		var card_id := String(all[i].id)
		var row := card_rows[i]
		var owned := profile.owned(card_id)
		row.get_child(0).text = "%d/%d" % [cards.count(card_id), owned] if owned > 0 else "-"
		row.disabled = not DeckRules.can_add(cards, card_id, profile.collection)
	_rebuild_deck_rows(cards)
	_deck_title.text = "%s  %d/%d" % [profile.decks[editing]["name"], cards.size(), DeckRules.SIZE]
	var problems := DeckRules.errors(cards, profile.collection)
	if problems.is_empty():
		_status.text = "Ready" if editing != profile.active_deck else "Ready, in use"
	elif cards.size() != DeckRules.SIZE:
		_status.text = "Needs %d cards" % DeckRules.SIZE
	else:
		_status.text = "Not enough copies owned"
	active_button.disabled = editing == profile.active_deck or not problems.is_empty()


func _rebuild_deck_rows(cards: Array) -> void:
	for row in deck_rows.get_children():
		deck_rows.remove_child(row)
		row.queue_free()
	var counts := DeckRules.count(cards)
	for card in catalog.all():
		var card_id := String(card.id)
		if counts.has(card_id):
			var row := _row(card, remove_card.bind(card_id))
			row.get_child(0).text = "x%d" % counts[card_id]
			deck_rows.add_child(row)


## A panel with the title label over a scrolling column for rows. Returns the column.
func _list_panel(rect: Rect2, title: Label) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column


## A card row: cost and name on the left, a count label on the right.
func _row(card: CardData, on_pressed: Callable) -> Button:
	var row := button("%d %s" % [card.cost, card.display_name], on_pressed)
	row.theme_type_variation = &"ListRow"
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if card.rarity != CardData.Rarity.COMMON:
		row.add_theme_color_override("font_color", CardView.rarity_color(card.rarity))
	var count := label("")
	count.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	count.offset_left = -56
	count.offset_right = -6
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	row.mouse_entered.connect(_show_preview.bind(card))
	row.mouse_exited.connect(_hide_preview.bind(card))
	return row


func _show_preview(card: CardData) -> void:
	_preview.card = card
	_preview.visible = true


func _hide_preview(card: CardData) -> void:
	if _preview.card == card:
		_preview.visible = false


func _catalog_order(a: String, b: String) -> bool:
	return catalog.all().find(catalog.get_card(a)) < catalog.all().find(catalog.get_card(b))
