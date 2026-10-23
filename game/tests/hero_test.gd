extends GdUnitTestSuite
## Wizard buffs: battlefield-wide, stacking per player, doubled by Empower.

const LANE_SCENE := preload("res://scenes/lane.tscn")
const STEP := 1.0 / 60.0
const RUNNER := preload("res://resources/units/goblin_runner.tres")
const ARROW := preload("res://resources/towers/arrow_tower.tres")
const FROST := preload("res://resources/heroes/frost.tres")
const EMBER := preload("res://resources/heroes/ember.tres")


func _lane(heroes: Array[HeroData]) -> Lane:
	var lane: Lane = LANE_SCENE.instantiate()
	lane.autorun = false
	lane.waves = []
	lane.heroes = heroes
	add_child(lane)
	auto_free(lane)
	return lane


func _add_player(lane: Lane, hero: HeroData) -> PlayerState:
	var player := PlayerState.new(Deck.new([], 1), hero)
	lane.players.append(player)
	return player


func _tick(lane: Lane, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		lane.tick(STEP)


func test_heroes_load_from_their_folder() -> void:
	var ids := HeroData.load_all().map(func(hero: HeroData) -> StringName: return hero.id)
	assert_array(ids).is_equal([&"ember", &"frost"])
	assert_object(HeroData.find("frost")).is_same(FROST)
	assert_object(HeroData.find("nobody")).is_null()


func test_no_wizard_means_no_buff() -> void:
	var lane := _lane([])
	assert_float(lane.enemy_speed_scale()).is_equal(1.0)
	assert_float(lane.tower_damage_scale()).is_equal(1.0)


func test_frost_slows_every_enemy() -> void:
	var lane := _lane([FROST])
	var enemy := lane.spawn_enemy(RUNNER)
	_tick(lane, 1.0)
	assert_float(enemy.progress).is_equal_approx(RUNNER.speed * 0.85, 0.01)
	assert_float(lane.tower_damage_scale()).is_equal(1.0)


func test_ember_raises_tower_damage() -> void:
	var lane := _lane([EMBER])
	var enemy := lane.spawn_enemy(RUNNER)
	enemy.progress = 200.0
	enemy.step(0.0)
	lane.place_tower(ARROW, enemy.position + Vector2(0, -40))
	lane.tick(STEP)
	assert_int(enemy.hp).is_equal(RUNNER.max_hp - roundi(ARROW.damage * 1.2))
	assert_float(lane.enemy_speed_scale()).is_equal(1.0)


func test_same_wizard_twice_counts_twice() -> void:
	var lane := _lane([FROST])
	_add_player(lane, FROST)
	assert_float(lane.enemy_speed_scale()).is_equal_approx(0.7, 0.0001)


func test_two_wizards_each_give_their_buff() -> void:
	var lane := _lane([FROST])
	_add_player(lane, EMBER)
	assert_float(lane.enemy_speed_scale()).is_equal_approx(0.85, 0.0001)
	assert_float(lane.tower_damage_scale()).is_equal_approx(1.2, 0.0001)


func test_empower_doubles_only_its_players_buff_for_8_seconds() -> void:
	var lane := _lane([FROST])
	var mate := _add_player(lane, EMBER)
	lane.players[0].empower(8.0)
	assert_float(lane.enemy_speed_scale()).is_equal_approx(0.7, 0.0001)
	assert_float(lane.tower_damage_scale()).is_equal_approx(1.2, 0.0001)
	_tick(lane, 7.9)
	assert_int(lane.players[0].buff_stacks()).is_equal(2)
	_tick(lane, 0.2)
	assert_int(lane.players[0].buff_stacks()).is_equal(1)
	assert_int(mate.buff_stacks()).is_equal(1)


func test_stacked_slows_keep_enemies_moving() -> void:
	var lane := _lane([FROST])
	for i in 6:
		_add_player(lane, FROST).empower(8.0)
	assert_float(lane.enemy_speed_scale()).is_equal(Lane.MIN_ENEMY_SPEED)


func test_buff_label() -> void:
	assert_str(FROST.buff_label()).is_equal("Enemies 15% slower")
	assert_str(EMBER.buff_label(2)).is_equal("Towers +40% damage")
