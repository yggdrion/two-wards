extends GdUnitTestSuite
## The run screen shows the player's hand as mini cards and plays cards through the lane.

const GAME_SCENE := preload("res://scenes/game.tscn")
const ARROW_TOWER := preload("res://resources/cards/arrow_tower.tres")


func _game() -> Node:
	var game := GAME_SCENE.instantiate()
	game.get_node("Lane").autorun = false
	add_child(game)
	auto_free(game)
	return game


func test_hand_shows_three_mini_cards() -> void:
	var game := _game()
	var hud: Hud = game.get_node("HudLayer/Hud")
	var lane: Lane = game.get_node("Lane")
	hud.refresh()
	assert_int(hud.cards.size()).is_equal(PlayerState.HAND_SIZE)
	for i in hud.cards.size():
		assert_object(hud.cards[i].card).is_same(lane.players[0].hand[i])
		assert_vector(hud.cards[i].size).is_equal(CardView.MINI_SIZE)


func test_untargeted_card_plays_on_select() -> void:
	var game := _game()
	var lane: Lane = game.get_node("Lane")
	var player := lane.players[0]
	player.hand[0] = load("res://resources/cards/arcane_focus.tres")
	game._select(0)
	assert_int(player.next_card_discount).is_greater(0)


func test_targeted_card_waits_for_a_target() -> void:
	var game := _game()
	var lane: Lane = game.get_node("Lane")
	lane.players[0].hand[1] = ARROW_TOWER
	game._select(1)
	assert_int(game.selected).is_equal(1)
	game._select(1)
	assert_int(game.selected).is_equal(-1)


func test_full_card_view_size() -> void:
	var view: CardView = auto_free(CardView.new())
	view.full = true
	assert_vector(view.size).is_equal(CardView.FULL_SIZE)


func test_full_card_shows_on_hover_but_not_while_aiming() -> void:
	var game := _game()
	var hud: Hud = game.get_node("HudLayer/Hud")
	game.get_node("Lane").players[0].hand[1] = ARROW_TOWER
	hud.cards[1].mouse_entered.emit()
	hud.refresh()
	assert_bool(hud.is_preview_shown()).is_true()
	hud.selected = 1
	hud.refresh()
	assert_bool(hud.is_preview_shown()).is_false()


func test_hud_bar_sits_below_the_field() -> void:
	assert_float(Hud.TOP).is_equal(Lane.FIELD.end.y)
	assert_float(Hud.SCREEN.y - Hud.TOP).is_equal(72.0)
