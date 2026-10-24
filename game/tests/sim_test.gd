extends GdUnitTestSuite
## The sim runs waves in order with breaks, pays gold, and ends in a win or a loss.

const ARROW := preload("res://resources/towers/arrow_tower.tres")
const WAVE_01 := preload("res://resources/waves/wave_01.tres")
const DEV_DECK := preload("res://resources/decks/dev_all_cards.tres")
const STEP := 1.0 / 60.0
const MAX_SECONDS := 120.0


func _make_sim(waves: Array[WaveData]) -> Sim:
	var sim := Sim.new()
	sim.waves = waves
	sim.start()
	return sim


func _run_until_over(sim: Sim) -> void:
	var elapsed := 0.0
	while not sim.is_over() and elapsed < MAX_SECONDS:
		sim.tick(STEP)
		elapsed += STEP


func test_tower_kills_the_whole_wave() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var sim := _make_sim(waves)
	sim.place_tower(ARROW, Vector2(260, 128))
	_run_until_over(sim)
	assert_int(sim.phase).is_equal(Sim.Phase.WON)
	assert_int(sim.core.hp).is_equal(sim.core.max_hp)
	assert_int(sim.gold).is_equal(Sim.GOLD_PER_WAVE + Sim.GOLD_FOR_WIN)


func test_without_towers_goblins_reach_the_core() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var sim := _make_sim(waves)
	_run_until_over(sim)
	var expected_damage := WAVE_01.count * WAVE_01.enemy.core_damage
	assert_int(sim.core.hp).is_equal(sim.core.max_hp - expected_damage)


func test_break_between_waves() -> void:
	var waves: Array[WaveData] = [WAVE_01, WAVE_01]
	var sim := _make_sim(waves)
	sim.place_tower(ARROW, Vector2(260, 128))
	while sim.waves_cleared == 0:
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.BREAK)
	assert_int(sim.gold).is_equal(Sim.GOLD_PER_WAVE)
	for i in roundi((Sim.WAVE_BREAK - 0.1) / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.BREAK)
	for i in roundi(0.2 / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.WAVE)
	assert_int(sim.wave_index).is_equal(1)


func test_run_is_lost_when_crystal_breaks() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var sim := _make_sim(waves)
	sim.core.hp = 1
	_run_until_over(sim)
	assert_int(sim.phase).is_equal(Sim.Phase.LOST)
	assert_bool(sim.play_card(0, 0, Vector2(260, 128))).is_false()


func test_default_run_has_ten_waves_in_order() -> void:
	var waves := Sim.default_waves()
	assert_int(waves.size()).is_equal(10)
	assert_object(waves[0]).is_same(WAVE_01)


func test_energy_regenerates_during_tick() -> void:
	var waves: Array[WaveData] = []
	var sim := _make_sim(waves)
	for i in 120:
		sim.tick(STEP)
	assert_int(sim.players[0].energy.points()).is_equal(Energy.START + 1)


func test_placement_rules() -> void:
	var waves: Array[WaveData] = []
	var sim := _make_sim(waves)
	assert_bool(sim.can_place_tower(Vector2(300, 120))).is_true()
	assert_bool(sim.can_place_tower(Vector2(320, 20))).is_true()
	assert_bool(sim.can_place_tower(Vector2(320, 240))).is_false()
	assert_bool(sim.can_place_tower(Vector2(320, 4))).is_false()
	assert_bool(sim.can_place_tower(sim.core.position + Vector2(0, -20))).is_false()
	sim.place_tower(ARROW, Vector2(300, 120))
	assert_bool(sim.can_place_tower(Vector2(310, 120))).is_false()


func _cleared_first_wave_with_rewards(rng_seed: int = 1, player_count: int = 1) -> Sim:
	var waves: Array[WaveData] = [WAVE_01, WAVE_01]
	var sim := Sim.new()
	sim.waves = waves
	sim.upgrade_pool = UpgradeData.load_all()
	for i in player_count:
		sim.decks.append(DEV_DECK)
	sim.rng_seed = rng_seed
	sim.heroes.resize(player_count)
	sim.start()
	sim.place_tower(ARROW, Vector2(260, 128))
	while sim.waves_cleared == 0:
		sim.tick(STEP)
	return sim


func test_cleared_wave_offers_upgrades_for_three_different_deck_cards() -> void:
	var sim := _cleared_first_wave_with_rewards()
	var offer: Array = sim.rewards.offers[0]
	assert_int(offer.size()).is_equal(RunRewards.CHOICES)
	var cards := offer.map(func(o: Dictionary) -> CardData: return o["card"])
	for card: CardData in cards:
		assert_int(cards.count(card)).is_equal(1)
		assert_bool(card in sim.players[0].run_cards).is_true()


func test_break_waits_for_the_pick() -> void:
	var sim := _cleared_first_wave_with_rewards()
	for i in roundi((Sim.WAVE_BREAK + 1.0) / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.BREAK)
	var card: CardData = sim.rewards.offers[0][1]["card"]
	assert_bool(sim.rewards.pick(0, 1)).is_true()
	assert_bool(sim.rewards.is_open()).is_false()
	assert_int(card.level).is_equal(1)
	for i in roundi((Sim.WAVE_BREAK + 0.1) / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.WAVE)


func test_coop_reward_is_auto_picked_after_timeout() -> void:
	var sim := _cleared_first_wave_with_rewards(1, 2)
	var first: CardData = sim.rewards.offers[1][0]["card"]
	NetCommand.apply(sim, NetCommand.reward(0, 0))
	for i in roundi((Sim.REWARD_TIMEOUT - 0.5) / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.BREAK)
	assert_bool(sim.rewards.is_open()).is_true()
	for i in roundi(1.0 / STEP):
		sim.tick(STEP)
	assert_bool(sim.rewards.is_open()).is_false()
	assert_int(first.level).is_equal(1)
	for i in roundi((Sim.WAVE_BREAK + 0.1) / STEP):
		sim.tick(STEP)
	assert_int(sim.phase).is_equal(Sim.Phase.WAVE)


func test_coop_upgrade_only_changes_the_pickers_card() -> void:
	var sim := _cleared_first_wave_with_rewards(1, 2)
	var card: CardData = sim.rewards.offers[0][0]["card"]
	NetCommand.apply(sim, NetCommand.reward(0, 0))
	for other in sim.players[1].run_cards:
		if other.id == card.id:
			assert_int(other.level).is_equal(0)
			assert_object(other).is_not_same(card)


func test_reward_must_be_an_open_offer() -> void:
	var sim := _cleared_first_wave_with_rewards()
	assert_str(NetCommand.apply(sim, NetCommand.reward(0, RunRewards.CHOICES))).is_not_empty()
	assert_str(NetCommand.apply(sim, NetCommand.reward(0, 0))).is_empty()
	assert_str(NetCommand.apply(sim, NetCommand.reward(0, 1))).is_not_empty()


func test_same_seed_gives_same_offer() -> void:
	var a := _cleared_first_wave_with_rewards(4)
	var b := _cleared_first_wave_with_rewards(4)
	assert_str(a.rewards.describe(0)).is_equal(b.rewards.describe(0))
	assert_str(a.state_hash()).is_equal(b.state_hash())


func test_last_wave_offers_nothing() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var sim := Sim.new()
	sim.waves = waves
	sim.upgrade_pool = UpgradeData.load_all()
	sim.decks = [DEV_DECK]
	sim.start()
	sim.place_tower(ARROW, Vector2(260, 128))
	_run_until_over(sim)
	assert_int(sim.phase).is_equal(Sim.Phase.WON)
	assert_bool(sim.rewards.is_open()).is_false()
