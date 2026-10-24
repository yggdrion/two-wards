extends GdUnitTestSuite
## Booster odds and pity. The statistical test opens 10,000 boosters without pity and checks
## the slot rarities against Booster.ODDS.

const BOOSTERS := 10000
## Allowed difference between measured and expected rate (about 5 standard deviations).
const TOLERANCE := 0.013


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func test_drop_rates_match_odds() -> void:
	var rng := _rng(42)
	var counts := [0, 0, 0]
	for i in BOOSTERS:
		for rarity in Booster.roll_slots(rng, 0):
			counts[rarity] += 1
	var slots := float(BOOSTERS * Booster.SLOTS)
	for rarity in counts.size():
		var rate: float = counts[rarity] / slots
		assert_float(rate).is_equal_approx(Booster.ODDS[rarity], TOLERANCE)


func test_pity_forces_epic_on_tenth_booster() -> void:
	var rng := _rng(7)
	for i in 1000:
		assert_bool(Booster.roll_slots(rng, Booster.PITY - 1).has(CardData.Rarity.EPIC)).is_true()


func test_no_pity_before_tenth_booster() -> void:
	var rng := _rng(7)
	var without_epic := 0
	for i in 1000:
		if not Booster.roll_slots(rng, Booster.PITY - 2).has(CardData.Rarity.EPIC):
			without_epic += 1
	assert_int(without_epic).is_greater(0)


func test_never_ten_boosters_in_a_row_without_epic() -> void:
	var profile := Profile.create()
	var catalog := CardCatalog.load_dir()
	var rng := _rng(3)
	profile.gold = Booster.COST * BOOSTERS
	var streak := 0
	var longest := 0
	for i in BOOSTERS:
		var pulls := Booster.open(profile, catalog, rng)
		var epic := pulls.any(
			func(pull: Dictionary) -> bool: return pull["card"].rarity == CardData.Rarity.EPIC
		)
		streak = 0 if epic else streak + 1
		longest = maxi(longest, streak)
	assert_int(longest).is_equal(Booster.PITY - 1)


func test_open_pays_and_adds_cards() -> void:
	var profile := Profile.create()
	profile.collection = {"arrow_tower": 1}
	profile.gold = 60
	var before: int = profile.collection.values().reduce(func(a: int, b: int) -> int: return a + b)
	var pulls := Booster.open(profile, CardCatalog.load_dir(), _rng(1))
	assert_array(pulls).has_size(Booster.SLOTS)
	assert_int(profile.gold).is_equal(10)
	var after: int = profile.collection.values().reduce(func(a: int, b: int) -> int: return a + b)
	assert_int(after - before).is_equal(Booster.SLOTS)


func test_open_marks_new_cards() -> void:
	var profile := Profile.create()
	profile.gold = Booster.COST
	var seen := Profile.STARTER_CARDS.duplicate()
	for pull: Dictionary in Booster.open(profile, CardCatalog.load_dir(), _rng(5)):
		var card_id := String(pull["card"].id)
		assert_bool(pull["new"]).is_equal(not seen.has(card_id))
		seen.append(card_id)


func test_open_without_gold_does_nothing() -> void:
	var profile := Profile.create()
	profile.gold = Booster.COST - 1
	assert_array(Booster.open(profile, CardCatalog.load_dir(), _rng(1))).is_empty()
	assert_int(profile.gold).is_equal(Booster.COST - 1)
	assert_int(profile.boosters_since_epic).is_equal(0)


func test_copy_over_the_cap_pays_gold() -> void:
	var profile := Profile.create()
	var catalog := CardCatalog.load_dir()
	for card in catalog.all():
		profile.collection[String(card.id)] = DeckRules.MAX_COPIES
	profile.gold = Booster.COST
	var before := profile.collection.duplicate()
	var pulls := Booster.open(profile, catalog, _rng(2))
	var paid := 0
	for pull: Dictionary in pulls:
		assert_bool(pull["new"]).is_false()
		assert_int(pull["gold"]).is_equal(Booster.DUPE_GOLD[pull["card"].rarity])
		paid += pull["gold"]
	assert_dict(profile.collection).is_equal(before)
	assert_int(profile.gold).is_equal(paid)
