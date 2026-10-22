extends GdUnitTestSuite


func test_loads_every_card_resource() -> void:
	var catalog := CardCatalog.load_dir()
	assert_int(catalog.all().size()).is_equal(12)
	assert_object(catalog.get_card("time_warp")).is_not_null()
	assert_object(catalog.get_card("missing")).is_null()


func test_rarity_split_matches_plan() -> void:
	var catalog := CardCatalog.load_dir()
	assert_int(catalog.of_rarity(CardData.Rarity.COMMON).size()).is_equal(6)
	assert_int(catalog.of_rarity(CardData.Rarity.RARE).size()).is_equal(4)
	assert_int(catalog.of_rarity(CardData.Rarity.EPIC).size()).is_equal(2)


func test_sorted_by_rarity_then_cost() -> void:
	var all := CardCatalog.load_dir().all()
	for i in range(1, all.size()):
		var a := all[i - 1]
		var b := all[i]
		assert_bool(a.rarity < b.rarity or (a.rarity == b.rarity and a.cost <= b.cost)).is_true()


func test_starter_cards_are_the_commons() -> void:
	var catalog := CardCatalog.load_dir()
	var commons := catalog.of_rarity(CardData.Rarity.COMMON).map(
		func(card: CardData) -> String: return String(card.id)
	)
	commons.sort()
	var starter := Profile.STARTER_CARDS.duplicate()
	starter.sort()
	assert_array(commons).is_equal(starter)
