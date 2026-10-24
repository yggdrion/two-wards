extends GdUnitTestSuite
## The lane scene draws its Sim: one view node per enemy and tower, created and freed from the
## sim's presentation signals.

const LANE_SCENE := preload("res://scenes/lane.tscn")
const ARROW := preload("res://resources/towers/arrow_tower.tres")
const RUNNER := preload("res://resources/units/goblin_runner.tres")
const STEP := 1.0 / 60.0


func _lane() -> Lane:
	var lane: Lane = LANE_SCENE.instantiate()
	lane.autorun = false
	lane.sim.waves = []
	add_child(lane)
	auto_free(lane)
	return lane


func test_lane_scene_runs_with_autorun() -> void:
	var lane: Lane = auto_free(LANE_SCENE.instantiate())
	add_child(lane)
	await await_millis(200)
	assert_bool(lane.is_physics_processing()).is_true()
	assert_float(lane.sim.time).is_greater(0.0)


func test_crystal_sits_at_the_path_end() -> void:
	var lane := _lane()
	assert_vector(lane.core.position).is_equal(lane.sim.core.position)
	assert_object(lane.core.model).is_same(lane.sim.core)


func test_views_follow_spawn_fire_and_death() -> void:
	var lane := _lane()
	var enemy := lane.sim.spawn_enemy(RUNNER)
	enemy.progress = 200.0
	enemy.step(0.0)
	var enemy_view := lane.view_of(enemy) as Enemy
	assert_object(enemy_view).is_not_null()
	assert_object(enemy_view.get_parent()).is_same(lane.enemies_root)
	var tower := lane.sim.place_tower(ARROW, enemy.position + Vector2(0, -40))
	var tower_view := lane.view_of(tower) as Tower
	assert_object(tower_view.get_parent()).is_same(lane.towers_root)
	lane.sim.tick(STEP)
	assert_bool(tower_view.is_flashing()).is_true()
	enemy.take_damage(enemy.hp + 99)
	assert_object(lane.view_of(enemy)).is_null()
	await await_idle_frame()
	assert_bool(is_instance_valid(enemy_view)).is_false()
	assert_bool(is_instance_valid(tower_view)).is_true()


func test_enemy_view_goes_when_it_reaches_the_crystal() -> void:
	var lane := _lane()
	var enemy := lane.sim.spawn_enemy(RUNNER)
	enemy.progress = lane.sim.path.get_baked_length()
	lane.sim.tick(STEP)
	assert_int(lane.sim.core.hp).is_less(lane.sim.core.max_hp)
	assert_object(lane.view_of(enemy)).is_null()
	await await_idle_frame()
	assert_int(lane.enemies_root.get_child_count()).is_equal(0)


func test_timed_tower_view_goes_when_it_expires() -> void:
	var lane := _lane()
	var tower := lane.sim.place_tower(ARROW, Vector2(300, 120), 1.0)
	var view := lane.view_of(tower)
	for i in roundi(1.1 / STEP):
		lane.sim.tick(STEP)
	assert_array(lane.sim.towers).is_empty()
	assert_object(lane.view_of(tower)).is_null()
	await await_idle_frame()
	assert_bool(is_instance_valid(view)).is_false()
