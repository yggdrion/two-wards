class_name BoosterScreen
extends MetaScreen
## Buys and opens boosters: the pack tears open, then the cards flip one at a time and new
## cards are marked.

## Seconds between two card flips, and for one flip.
const FLIP_DELAY := 0.35
const FLIP_TIME := 0.16
const PACK_SIZE := Vector2(144, 208)
const CARD_GAP := 16.0
const CARDS_TOP := 72.0

## The last booster's pulls ({"card", "new"}), empty before the first one.
var pulls: Array = []
var open_button: Button
var pack: BoosterPack
var cards: Array[CardView] = []
var new_badges: Array[Label] = []
var _info: Label
var _rng := RandomNumberGenerator.new()
var _tween: Tween
var _opening := false


func build() -> void:
	_rng.randomize()
	add_header("Booster")
	pack = BoosterPack.new()
	pack.size = PACK_SIZE
	pack.pivot_offset = PACK_SIZE / 2.0
	pack.position = Vector2((SCREEN.x - PACK_SIZE.x) / 2.0, CARDS_TOP - 24)
	add_child(pack)
	var row_width := Booster.SLOTS * CardView.FULL_SIZE.x + (Booster.SLOTS - 1) * CARD_GAP
	for i in Booster.SLOTS:
		var view := CardView.new()
		view.full = true
		view.visible = false
		view.mouse_filter = MOUSE_FILTER_IGNORE
		view.pivot_offset = CardView.FULL_SIZE / 2.0
		var x := (SCREEN.x - row_width) / 2.0 + i * (CardView.FULL_SIZE.x + CARD_GAP)
		view.position = Vector2(x, CARDS_TOP)
		add_child(view)
		cards.append(view)
		var badge := label("NEW", &"GoldLabel")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.position = Vector2(x, CARDS_TOP - 26)
		badge.size = Vector2(CardView.FULL_SIZE.x, 24)
		badge.visible = false
		add_child(badge)
		new_badges.append(badge)
	open_button = button("", open_booster)
	open_button.position = Vector2(220, 296)
	open_button.size = Vector2(200, 28)
	add_child(open_button)
	_info = label("", &"DimLabel")
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.position = Vector2(0, 328)
	_info.size = Vector2(SCREEN.x, 24)
	add_child(_info)


func refresh() -> void:
	var opened := not pulls.is_empty()
	open_button.text = "%s (%d gold)" % ["Open another" if opened else "Open", Booster.COST]
	open_button.disabled = _opening or profile.gold < Booster.COST
	var left := Booster.PITY - profile.boosters_since_epic
	if profile.gold < Booster.COST:
		_info.text = "Win runs to earn gold"
	elif left <= 1:
		_info.text = "This booster holds an epic"
	else:
		_info.text = "Epic guaranteed within %d boosters" % left


## Buys a booster and starts the opening animation; does nothing if gold is short.
func open_booster() -> void:
	var opened := Booster.open(profile, catalog, _rng)
	if opened.is_empty():
		return
	pulls = opened
	_opening = true
	refresh()
	for i in cards.size():
		cards[i].card = pulls[i]["card"]
		cards[i].face_down = true
		cards[i].visible = false
		new_badges[i].visible = false
	pack.visible = true
	pack.scale = Vector2.ONE
	pack.modulate = Color.WHITE
	var tween := create_tween()
	_tween = tween
	tween.tween_property(pack, "scale", Vector2(1.15, 0.9), 0.12)
	tween.tween_property(pack, "scale", Vector2(1.3, 0.0), 0.12)
	tween.tween_callback(_deal)
	for i in cards.size():
		tween.tween_interval(FLIP_DELAY)
		tween.tween_property(cards[i], "scale:x", 0.0, FLIP_TIME / 2.0)
		tween.tween_callback(_turn_over.bind(i))
		tween.tween_property(cards[i], "scale:x", 1.0, FLIP_TIME / 2.0)
	tween.tween_callback(_finish_opening)


## Skips the animation: every card face up at once.
func reveal_all() -> void:
	if _tween != null:
		_tween.kill()
	_deal()
	for i in cards.size():
		cards[i].scale = Vector2.ONE
		_turn_over(i)
	_finish_opening()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and is_animating():
		reveal_all()


func is_animating() -> bool:
	return _opening


func _finish_opening() -> void:
	_opening = false
	refresh()


func _deal() -> void:
	pack.visible = false
	for view in cards:
		view.visible = true


func _turn_over(i: int) -> void:
	cards[i].face_down = false
	new_badges[i].visible = pulls[i]["new"]
