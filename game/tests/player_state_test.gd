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


func test_pass_gives_the_card_to_the_partner_for_one_energy() -> void:
	var deck := Deck.new(_five_cards() + _five_cards(), 1)
	var me := PlayerState.new(deck, null)
	var mate := PlayerState.new(deck, null)
	var passed := me.hand[2]
	var next_draw: CardData = deck.draw_pile.back()
	assert_bool(me.pass_to(2, mate)).is_true()
	assert_int(me.energy.points()).is_equal(Energy.START - PlayerState.PASS_COST)
	assert_object(me.hand[2]).is_same(next_draw)
	assert_int(mate.hand.size()).is_equal(PlayerState.HAND_SIZE + 1)
	assert_object(mate.card_at(PlayerState.GIFT_SLOT)).is_same(passed)
	assert_bool(passed in deck.discard_pile).is_false()


func test_gift_slot_holds_one_card_and_goes_away_when_played() -> void:
	var deck := Deck.new(_five_cards() + _five_cards(), 1)
	var me := PlayerState.new(deck, null)
	var mate := PlayerState.new(deck, null)
	assert_bool(me.pass_to(0, mate)).is_true()
	assert_bool(me.can_pass(1, mate)).is_false()
	assert_bool(me.can_pass(1, me)).is_false()
	var gift := mate.card_at(PlayerState.GIFT_SLOT)
	assert_bool(mate.play(PlayerState.GIFT_SLOT, _ctx(mate))).is_true()
	assert_int(mate.hand.size()).is_equal(PlayerState.HAND_SIZE)
	assert_bool(gift in deck.discard_pile).is_true()
	assert_bool(me.can_pass(1, mate)).is_true()


func test_pass_needs_energy() -> void:
	var deck := Deck.new(_five_cards() + _five_cards(), 1)
	var me := PlayerState.new(deck, null)
	var mate := PlayerState.new(deck, null)
	me.energy.value = 0.0
	assert_bool(me.pass_to(0, mate)).is_false()
	assert_int(mate.hand.size()).is_equal(PlayerState.HAND_SIZE)


func test_used_gift_goes_back_to_the_givers_deck() -> void:
	var mine := Deck.new(_five_cards(), 1)
	var theirs := Deck.new(_five_cards(), 2)
	var me := PlayerState.new(mine, null)
	var mate := PlayerState.new(theirs, null)
	assert_bool(me.pass_to(0, mate)).is_true()
	var gift := mate.card_at(PlayerState.GIFT_SLOT)
	assert_bool(mate.cycle(PlayerState.GIFT_SLOT)).is_true()
	assert_bool(gift in mine.discard_pile).is_true()
	assert_bool(gift in theirs.discard_pile).is_false()


func test_gift_passed_back_stays_the_givers_card() -> void:
	var mine := Deck.new(_five_cards(), 1)
	var theirs := Deck.new(_five_cards(), 2)
	var me := PlayerState.new(mine, null)
	var mate := PlayerState.new(theirs, null)
	assert_bool(me.pass_to(0, mate)).is_true()
	assert_bool(mate.pass_to(PlayerState.GIFT_SLOT, me)).is_true()
	assert_object(me.gift_owner).is_same(me)
	assert_bool(me.cycle(PlayerState.GIFT_SLOT)).is_true()
	assert_int(mine.discard_pile.size()).is_equal(1)
	assert_int(theirs.discard_pile.size()).is_equal(0)
