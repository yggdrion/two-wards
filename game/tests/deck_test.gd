extends GdUnitTestSuite


func _cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in count:
		var card := CardData.new()
		card.id = StringName("card_%d" % i)
		cards.append(card)
	return cards


func _ids(cards: Array[CardData]) -> Array:
	return cards.map(func(card: CardData) -> StringName: return card.id)


func test_same_seed_same_order() -> void:
	var cards := _cards(10)
	assert_array(_ids(Deck.new(cards, 5).draw_pile)).is_equal(_ids(Deck.new(cards, 5).draw_pile))


func test_different_seed_different_order() -> void:
	var cards := _cards(10)
	assert_array(_ids(Deck.new(cards, 5).draw_pile)).is_not_equal(
		_ids(Deck.new(cards, 6).draw_pile)
	)


func test_shuffle_keeps_every_card() -> void:
	var cards := _cards(10)
	var drawn := _ids(Deck.new(cards, 1).draw_pile)
	drawn.sort()
	var expected := _ids(cards)
	expected.sort()
	assert_array(drawn).is_equal(expected)


func test_discard_is_shuffled_back_when_empty() -> void:
	var deck := Deck.new(_cards(2), 1)
	deck.discard(deck.draw())
	deck.discard(deck.draw())
	assert_int(deck.draw_pile.size()).is_equal(0)
	assert_object(deck.draw()).is_not_null()
	assert_int(deck.draw_pile.size()).is_equal(1)
	assert_int(deck.discard_pile.size()).is_equal(0)


func test_draw_from_empty_deck_returns_null() -> void:
	var empty: Array[CardData] = []
	assert_object(Deck.new(empty, 1).draw()).is_null()
