extends GdUnitTestSuite
## The lane runs waves in order with breaks, pays gold, and ends in a win or a loss.

const LANE_SCENE := preload("res://scenes/lane.tscn")
const ARROW := preload("res://resources/towers/arrow_tower.tres")
const WAVE_01 := preload("res://resources/waves/wave_01.tres")
const STEP := 1.0 / 60.0
const MAX_SECONDS := 120.0


func _make_lane(waves: Array[WaveData]) -> Lane:
	var lane: Lane = LANE_SCENE.instantiate()
	lane.autorun = false
	lane.waves = waves
	add_child(lane)
	auto_free(lane)
	return lane


func _run_until_over(lane: Lane) -> void:
	var elapsed := 0.0
	while not lane.is_over() and elapsed < MAX_SECONDS:
		lane.tick(STEP)
		elapsed += STEP


func test_tower_kills_the_whole_wave() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var lane := _make_lane(waves)
	lane.place_tower(ARROW, Vector2(260, 128))
	_run_until_over(lane)
	assert_int(lane.phase).is_equal(Lane.Phase.WON)
	assert_int(lane.core.hp).is_equal(lane.core.max_hp)
	assert_int(lane.gold).is_equal(Lane.GOLD_PER_WAVE + Lane.GOLD_FOR_WIN)


func test_without_towers_goblins_reach_the_core() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var lane := _make_lane(waves)
	_run_until_over(lane)
	var expected_damage := WAVE_01.count * WAVE_01.enemy.core_damage
	assert_int(lane.core.hp).is_equal(lane.core.max_hp - expected_damage)


func test_break_between_waves() -> void:
	var waves: Array[WaveData] = [WAVE_01, WAVE_01]
	var lane := _make_lane(waves)
	lane.place_tower(ARROW, Vector2(260, 128))
	while lane.waves_cleared == 0:
		lane.tick(STEP)
	assert_int(lane.phase).is_equal(Lane.Phase.BREAK)
	assert_int(lane.gold).is_equal(Lane.GOLD_PER_WAVE)
	for i in roundi((Lane.WAVE_BREAK - 0.1) / STEP):
		lane.tick(STEP)
	assert_int(lane.phase).is_equal(Lane.Phase.BREAK)
	for i in roundi(0.2 / STEP):
		lane.tick(STEP)
	assert_int(lane.phase).is_equal(Lane.Phase.WAVE)
	assert_int(lane.wave_index).is_equal(1)


func test_run_is_lost_when_crystal_breaks() -> void:
	var waves: Array[WaveData] = [WAVE_01]
	var lane := _make_lane(waves)
	lane.core.hp = 1
	_run_until_over(lane)
	assert_int(lane.phase).is_equal(Lane.Phase.LOST)
	assert_bool(lane.play_card(0, 0, Vector2(260, 128))).is_false()


func test_scene_has_ten_waves() -> void:
	var lane: Lane = auto_free(LANE_SCENE.instantiate())
	assert_int(lane.waves.size()).is_equal(10)


func test_energy_regenerates_during_tick() -> void:
	var waves: Array[WaveData] = []
	var lane := _make_lane(waves)
	for i in 120:
		lane.tick(STEP)
	assert_int(lane.players[0].energy.points()).is_equal(Energy.START + 1)


func test_placement_rules() -> void:
	var waves: Array[WaveData] = []
	var lane := _make_lane(waves)
	assert_bool(lane.can_place_tower(Vector2(300, 120))).is_true()
	assert_bool(lane.can_place_tower(Vector2(320, 20))).is_true()
	assert_bool(lane.can_place_tower(Vector2(320, 240))).is_false()
	assert_bool(lane.can_place_tower(Vector2(320, 4))).is_false()
	assert_bool(lane.can_place_tower(lane.core.position + Vector2(0, -20))).is_false()
	lane.place_tower(ARROW, Vector2(300, 120))
	assert_bool(lane.can_place_tower(Vector2(310, 120))).is_false()


func test_lane_scene_runs_with_autorun() -> void:
	var lane: Lane = auto_free(LANE_SCENE.instantiate())
	add_child(lane)
	await await_millis(200)
	assert_bool(lane.is_physics_processing()).is_true()
	assert_float(lane.time).is_greater(0.0)
