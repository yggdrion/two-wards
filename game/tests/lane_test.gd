extends GdUnitTestSuite
## M1 exit criterion: a goblin walks to the core, and the tower kills it.

const LANE_SCENE := preload("res://scenes/lane.tscn")
const STEP := 1.0 / 60.0
const MAX_SECONDS := 60.0


func _make_lane(with_towers: bool) -> Lane:
	var lane: Lane = LANE_SCENE.instantiate()
	lane.autorun = false
	if not with_towers:
		for tower in lane.get_node("Towers").get_children():
			lane.get_node("Towers").remove_child(tower)
			tower.free()
	add_child(lane)
	auto_free(lane)
	return lane


func _run_until_cleared(lane: Lane) -> void:
	var elapsed := 0.0
	while not lane.is_cleared() and elapsed < MAX_SECONDS:
		lane.tick(STEP)
		elapsed += STEP


func test_tower_kills_the_whole_wave() -> void:
	var lane := _make_lane(true)
	_run_until_cleared(lane)
	assert_bool(lane.is_cleared()).is_true()
	assert_int(lane.core.hp).is_equal(lane.core.max_hp)


func test_without_towers_goblins_reach_the_core() -> void:
	var lane := _make_lane(false)
	_run_until_cleared(lane)
	assert_bool(lane.is_cleared()).is_true()
	var expected_damage := lane.wave.count * lane.wave.enemy.core_damage
	assert_int(lane.core.hp).is_equal(lane.core.max_hp - expected_damage)


func test_lane_scene_runs_with_autorun() -> void:
	var lane: Lane = auto_free(LANE_SCENE.instantiate())
	add_child(lane)
	await await_millis(200)
	assert_bool(lane.is_physics_processing()).is_true()
