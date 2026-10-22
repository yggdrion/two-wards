extends GdUnitTestSuite
## Checks the card set as data: 12 cards, sane costs, art, text, and at most 3 scripted cards.

const CARD_DIR := "res://resources/cards"


func _cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for file in DirAccess.get_files_at(CARD_DIR):
		if file.ends_with(".tres"):
			cards.append(load(CARD_DIR.path_join(file)))
	return cards


func test_twelve_cards() -> void:
	assert_int(_cards().size()).is_equal(12)


func test_every_card_is_complete() -> void:
	for card in _cards():
		var path := card.resource_path
		assert_str(String(card.id)).override_failure_message(path).is_equal(
			path.get_file().get_basename()
		)
		assert_str(card.display_name).override_failure_message(path).is_not_empty()
		assert_str(card.text).override_failure_message(path).is_not_empty()
		assert_int(card.cost).override_failure_message(path).is_between(1, 7)
		assert_object(card.art).override_failure_message(path).is_not_null()
		assert_vector(card.art.get_size()).is_equal(Vector2(64, 48))
		assert_bool(card.effects.is_empty()).override_failure_message(path).is_false()


func test_at_most_three_cards_need_scripts() -> void:
	var scripted := _cards().filter(func(card: CardData) -> bool: return card.uses_script())
	assert_int(scripted.size()).is_less_equal(3)


func test_tower_cards_reference_tower_data() -> void:
	for card in _cards():
		if card.kind == CardData.Kind.TOWER:
			assert_object(card.effects[0]).is_instanceof(PlaceTowerEffect)
			assert_object(card.effects[0].tower).override_failure_message(card.id).is_not_null()


func test_all_three_rarities_used() -> void:
	var rarities := {}
	for card in _cards():
		rarities[card.rarity] = true
	assert_int(rarities.size()).is_equal(3)
