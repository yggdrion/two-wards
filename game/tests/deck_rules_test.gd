extends GdUnitTestSuite

const OWNED := {"a": 2, "b": 2, "c": 2, "d": 2, "e": 1}


func _deck() -> Array:
	return ["a", "a", "b", "b", "c", "c", "d", "d"]


func test_full_legal_deck_is_valid() -> void:
	assert_array(Array(DeckRules.errors(_deck(), OWNED))).is_empty()


func test_deck_needs_exactly_eight_cards() -> void:
	var short := _deck().slice(0, 7)
	assert_bool(DeckRules.is_valid(short, OWNED)).is_false()
	var long := _deck() + ["e"]
	assert_bool(DeckRules.is_valid(long, OWNED)).is_false()


func test_at_most_two_copies() -> void:
	var cards := ["a", "a", "a", "b", "b", "c", "c", "d"]
	var errors := DeckRules.errors(cards, {"a": 3, "b": 2, "c": 2, "d": 2})
	assert_array(Array(errors)).has_size(1)
	assert_str(errors[0]).contains("max 2")


func test_only_owned_copies_count() -> void:
	var cards := ["a", "a", "b", "b", "c", "c", "e", "e"]
	var errors := DeckRules.errors(cards, OWNED)
	assert_array(Array(errors)).has_size(1)
	assert_str(errors[0]).contains("only 1 owned")


func test_can_add_respects_every_rule() -> void:
	assert_bool(DeckRules.can_add(["a"], "a", OWNED)).is_true()
	assert_bool(DeckRules.can_add(["a", "a"], "a", {"a": 3})).is_false()
	assert_bool(DeckRules.can_add(["e"], "e", OWNED)).is_false()
	assert_bool(DeckRules.can_add([], "x", OWNED)).is_false()
	assert_bool(DeckRules.can_add(_deck(), "e", OWNED)).is_false()
