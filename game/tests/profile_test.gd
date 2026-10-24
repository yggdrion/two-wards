extends GdUnitTestSuite


func test_new_profile_owns_two_of_each_common_and_a_legal_deck() -> void:
	var profile := Profile.create()
	for card_id in Profile.STARTER_CARDS:
		assert_int(profile.owned(card_id)).is_equal(Profile.STARTER_COPIES)
	assert_int(profile.gold).is_equal(0)
	assert_str(profile.hero).is_equal("frost")
	assert_int(profile.decks.size()).is_equal(DeckRules.MAX_DECKS)
	assert_bool(profile.is_deck_valid(0)).is_true()
	assert_bool(profile.is_deck_valid(1)).is_false()


func test_spend_gold_refuses_when_short() -> void:
	var profile := Profile.create()
	profile.add_gold(40)
	assert_bool(profile.spend_gold(50)).is_false()
	assert_int(profile.gold).is_equal(40)
	assert_bool(profile.spend_gold(40)).is_true()
	assert_int(profile.gold).is_equal(0)


func test_every_change_emits_changed() -> void:
	var profile := Profile.create()
	var count := [0]
	profile.changed.connect(func() -> void: count[0] += 1)
	profile.add_gold(10)
	profile.add_card("mend")
	profile.set_deck_cards(1, ["mend"])
	profile.set_active_deck(1)
	profile.set_hero("ember")
	assert_int(count[0]).is_equal(5)


func test_dict_round_trip() -> void:
	var profile := Profile.create("alice")
	profile.add_gold(75)
	profile.add_card("time_warp")
	profile.set_deck_cards(2, ["mend", "empower"])
	profile.set_active_deck(2)
	profile.set_hero("ember")
	profile.boosters_since_epic = 4
	var copy := Profile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_dict(copy.to_dict()).is_equal(profile.to_dict())


func test_deck_data_builds_run_deck() -> void:
	var deck := Profile.create().deck_data(0, CardCatalog.load_dir())
	assert_int(deck.cards.size()).is_equal(DeckRules.SIZE)
	assert_str(String(deck.cards[0].id)).is_equal(Profile.STARTER_DECK[0])


func test_tiers_unlock_one_by_one_and_cap_at_the_last() -> void:
	var profile := Profile.create()
	profile.set_tier(2)
	assert_int(profile.tier).is_equal(0)
	assert_bool(profile.unlock_tier(1)).is_true()
	assert_bool(profile.unlock_tier(1)).is_false()
	profile.set_tier(2)
	assert_int(profile.tier).is_equal(1)
	profile.unlock_tier(99)
	assert_int(profile.tier_unlocked).is_equal(Sim.TIER_COUNT - 1)
	var loaded := Profile.from_dict(profile.to_dict())
	assert_int(loaded.tier_unlocked).is_equal(Sim.TIER_COUNT - 1)
	assert_int(loaded.tier).is_equal(1)
