extends GdUnitTestSuite
## Hand, costs and cycling. Cards use a no-op effect list so only the rules are tested.


func _card(id: String, cost: int) -> CardData:
	var card := CardData.new()
	card.id = StringName(id)
	card.cost = cost
	card.target = CardData.Target.NONE
	return card


func _player(cards: Array[CardData]) -> PlayerState:
	return PlayerState.new(Deck.new(cards, 1), null)


func _ctx(player: PlayerState) -> CardContext:
	return CardContext.new(null, player)


func _five_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in 5:
		cards.append(_card("c%d" % i, 1))
	return cards


func test_starts_with_full_hand() -> void:
	var player := _player(_five_cards())
	assert_int(player.hand.size()).is_equal(PlayerState.HAND_SIZE)
	assert_int(player.deck.draw_pile.size()).is_equal(2)


func test_play_spends_energy_and_refills_same_slot() -> void:
	var player := _player(_five_cards())
	var next_draw: CardData = player.deck.draw_pile.back()
	var played := player.hand[1]
	assert_bool(player.play(1, _ctx(player))).is_true()
	assert_int(player.energy.points()).is_equal(Energy.START - 1)
	assert_object(player.hand[1]).is_same(next_draw)
	assert_array(player.deck.discard_pile).contains_exactly([played])


func test_cannot_play_without_energy() -> void:
	var cards: Array[CardData] = [_card("big", 5), _card("big", 5), _card("big", 5)]
	var player := _player(cards)
	assert_bool(player.play(0, _ctx(player))).is_false()
	assert_int(player.energy.points()).is_equal(Energy.START)
	assert_int(player.deck.discard_pile.size()).is_equal(0)


func test_cycle_costs_one_and_replaces_card() -> void:
	var player := _player(_five_cards())
	var next_draw: CardData = player.deck.draw_pile.back()
	assert_bool(player.cycle(0)).is_true()
	assert_int(player.energy.points()).is_equal(Energy.START - PlayerState.CYCLE_COST)
	assert_object(player.hand[0]).is_same(next_draw)


func test_cycle_needs_energy() -> void:
	var player := _player(_five_cards())
	player.energy.spend(Energy.START)
	assert_bool(player.cycle(0)).is_false()


func test_discount_applies_to_next_card_only() -> void:
	var cards: Array[CardData] = []
	for i in 6:
		cards.append(_card("c%d" % i, 2))
	var player := _player(cards)
	player.next_card_discount = 99
	assert_int(player.cost_of(player.hand[0])).is_equal(0)
	player.play(0, _ctx(player))
	assert_int(player.energy.points()).is_equal(Energy.START)
	assert_int(player.cost_of(player.hand[0])).is_equal(2)


func test_find_in_hand() -> void:
	var cards: Array[CardData] = [_card("a", 1), _card("b", 1), _card("c", 1)]
	var player := _player(cards)
	assert_int(player.find_in_hand(&"b")).is_equal(player.hand.find(cards[1]))
	assert_int(player.find_in_hand(&"zzz")).is_equal(-1)
