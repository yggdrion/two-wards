extends GdUnitTestSuite
## Run upgrades: which cards an upgrade fits, what it changes, and how offers are rolled.

const CARDS := "res://resources/cards/%s.tres"
const UPGRADES := "res://resources/upgrades/%s.tres"


func _card(id: String) -> CardData:
	return (load(CARDS % id) as CardData).run_copy()


func _upgrade(id: String) -> UpgradeData:
	return load(UPGRADES % id)


func _player(ids: Array) -> PlayerState:
	var cards: Array[CardData] = []
	for id: String in ids:
		cards.append(_card(id))
	var player := PlayerState.new(Deck.new(cards, 1))
	player.run_cards = cards
	return player


func test_upgrades_fit_only_matching_cards() -> void:
	assert_bool(_upgrade("forked_bolt").fits(_card("storm_spire"))).is_true()
	assert_bool(_upgrade("forked_bolt").fits(_card("arrow_tower"))).is_false()
	assert_bool(_upgrade("heavy_bolts").fits(_card("frost_totem"))).is_false()
	assert_bool(_upgrade("bitter_cold").fits(_card("frost_totem"))).is_true()
	assert_bool(_upgrade("wide_cast").fits(_card("arcane_bolt"))).is_false()
	assert_bool(_upgrade("rapid_fire").fits(_card("time_warp"))).is_false()
	assert_bool(_upgrade("thrift").fits(_card("time_warp"))).is_true()


func test_thrift_is_not_offered_at_cost_zero() -> void:
	var card := _card("arcane_bolt")
	card.cost = 0
	assert_bool(_upgrade("thrift").fits(card)).is_false()


func test_upgrade_changes_the_tower_and_counts_a_level() -> void:
	var card := _card("arrow_tower")
	var tower: TowerData = (card.effects[0] as PlaceTowerEffect).tower
	var interval := tower.fire_interval
	var damage := tower.damage
	_upgrade("heavy_bolts").apply(card)
	assert_int(tower.damage).is_equal(roundi(damage * 1.8))
	assert_float(tower.fire_interval).is_equal_approx(interval * 1.3, 0.001)
	assert_int(card.level).is_equal(1)
	_upgrade("twin_shot").apply(card)
	assert_int(tower.shots).is_equal(2)


func test_run_copy_leaves_the_catalog_card_alone() -> void:
	var original: CardData = load(CARDS % "arrow_tower")
	var damage := (original.effects[0] as PlaceTowerEffect).tower.damage
	_upgrade("heavy_bolts").apply(original.run_copy())
	assert_int((original.effects[0] as PlaceTowerEffect).tower.damage).is_equal(damage)
	assert_int(original.level).is_equal(0)


func test_max_level_cards_are_not_offered() -> void:
	var player := _player(["arrow_tower", "mend"])
	player.run_cards[0].level = CardData.MAX_LEVEL
	var rewards := RunRewards.new(UpgradeData.load_all(), 1, 1)
	var players: Array[PlayerState] = [player]
	rewards.open(players)
	assert_int(rewards.offers[0].size()).is_equal(1)
	assert_object(rewards.offers[0][0]["card"]).is_same(player.run_cards[1])


func test_offers_are_seeded() -> void:
	var ids := ["arrow_tower", "ballista", "frost_totem", "mend", "storm_spire"]
	var a := RunRewards.new(UpgradeData.load_all(), 1, 9)
	var b := RunRewards.new(UpgradeData.load_all(), 1, 9)
	var pa: Array[PlayerState] = [_player(ids)]
	var pb: Array[PlayerState] = [_player(ids)]
	a.open(pa)
	b.open(pb)
	assert_str(a.describe(0)).is_equal(b.describe(0))
