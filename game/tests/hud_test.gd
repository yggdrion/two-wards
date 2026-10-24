extends GdUnitTestSuite
## The run screen shows the player's hand as mini cards and plays cards through the sim.

const GAME_SCENE := preload("res://scenes/game.tscn")
const ARROW_TOWER := preload("res://resources/cards/arrow_tower.tres")
const DEV_DECK := preload("res://resources/decks/dev_all_cards.tres")


func _game() -> Node:
	var game := GAME_SCENE.instantiate()
	var lane: Lane = game.get_node("Lane")
	lane.autorun = false
	lane.sim.decks = [DEV_DECK]
	add_child(game)
	auto_free(game)
	return game


func test_hand_shows_three_mini_cards() -> void:
	var game := _game()
	var hud: Hud = game.get_node("HudLayer/Hud")
	var sim: Sim = game.get_node("Lane").sim
	hud.refresh()
	assert_int(hud.cards.size()).is_equal(PlayerState.HAND_SIZE + 1)
	for i in PlayerState.HAND_SIZE:
		assert_object(hud.cards[i].card).is_same(sim.players[0].hand[i])
		assert_vector(hud.cards[i].size).is_equal(CardView.MINI_SIZE)
	# The gift slot only shows in co-op, while it holds a passed card.
	assert_bool(hud.cards[PlayerState.GIFT_SLOT].visible).is_false()
	assert_bool(hud.partner_panel.visible).is_false()


func test_untargeted_card_plays_on_select() -> void:
	var game := _game()
	var sim: Sim = game.get_node("Lane").sim
	var player := sim.players[0]
	player.hand[0] = load("res://resources/cards/arcane_focus.tres")
	game._select(0)
	assert_int(player.next_card_discount).is_greater(0)


func test_targeted_card_waits_for_a_target() -> void:
	var game := _game()
	var sim: Sim = game.get_node("Lane").sim
	sim.players[0].hand[1] = ARROW_TOWER
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
	game.get_node("Lane").sim.players[0].hand[1] = ARROW_TOWER
	hud.cards[1].mouse_entered.emit()
	hud.refresh()
	assert_bool(hud.is_preview_shown()).is_true()
	hud.selected = 1
	hud.refresh()
	assert_bool(hud.is_preview_shown()).is_false()


func test_hud_bar_sits_below_the_field() -> void:
	assert_float(Hud.TOP).is_equal(Sim.FIELD.end.y)
	assert_float(Hud.SCREEN.y - Hud.TOP).is_equal(72.0)


func _coop_game(player: int) -> RunScreen:
	var game: RunScreen = GAME_SCENE.instantiate()
	var lane: Lane = game.get_node("Lane")
	lane.autorun = false
	var heroes: Array[HeroData] = [HeroData.find("frost"), HeroData.find("ember")]
	lane.sim.heroes = heroes
	lane.sim.decks = [DEV_DECK, DEV_DECK]
	game.player = player
	add_child(game)
	auto_free(game)
	game.hud.names = ["Ann", "Bo"]
	return game


func test_partner_panel_shows_the_other_player() -> void:
	var game := _coop_game(1)
	game.hud.refresh()
	var panel := game.hud.partner_panel
	assert_bool(panel.visible).is_true()
	assert_str(panel.player_name).is_equal("Ann")
	assert_object(panel.player).is_same(game.sim.players[0])
	assert_object(game.hud.cards[0].card).is_same(game.sim.players[1].hand[0])


func test_passed_card_shows_as_a_fourth_card_and_hand_squeezes() -> void:
	var game := _coop_game(0)
	var sim := game.sim
	game.selected = 0
	game.hud.selected = 0
	game.hud.refresh()
	assert_bool(game.hud.partner_panel.can_receive).is_true()
	var card := sim.players[0].hand[0]
	game.hud.pass_requested.emit()
	assert_object(sim.players[1].card_at(PlayerState.GIFT_SLOT)).is_same(card)
	assert_int(game.selected).is_equal(-1)
	var other := _coop_game(1)
	other.sim.players[1].hand.append(card)
	other.hud.refresh()
	var gift := other.hud.cards[PlayerState.GIFT_SLOT]
	assert_bool(gift.visible).is_true()
	assert_float(gift.position.x + gift.size.x).is_less_equal(Hud.RIGHT_X)


func test_reward_offer_shows_and_a_click_picks() -> void:
	var game: RunScreen = _game()
	var sim := game.sim
	var thrift: UpgradeData = load("res://resources/upgrades/thrift.tres")
	var card: CardData = sim.players[0].run_cards[0]
	var offer: Array = []
	for i in RunRewards.CHOICES:
		offer.append({"card": sim.players[0].run_cards[i], "upgrade": thrift})
	sim.rewards.offers[0] = offer
	sim.phase = Sim.Phase.BREAK
	game.hud.refresh()
	assert_bool(game.hud.rewards[0].visible).is_true()
	assert_object(game.hud.rewards[0].upgrade).is_same(thrift)
	assert_int(game.hud.rewards[0].shown_cost).is_equal(maxi(card.cost - 1, 0))
	var before := sim.players[0].run_cards[1].cost
	game.hud.rewards[1].pressed.emit(game.hud.rewards[1])
	assert_bool(sim.rewards.is_open()).is_false()
	assert_int(sim.players[0].run_cards[1].cost).is_equal(before - 1)
	game.hud.refresh()
	assert_bool(game.hud.rewards[1].visible).is_false()
