extends GdUnitTestSuite


func _make_unit(hp: int, speed: float, armor: int = 0) -> UnitData:
	var unit := UnitData.new()
	unit.max_hp = hp
	unit.speed = speed
	unit.armor = armor
	return unit


func _straight_curve(length: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(length, 0))
	return curve


func _make_enemy(unit: UnitData, length: float = 100.0) -> SimEnemy:
	return SimEnemy.new(unit, _straight_curve(length))


func test_walks_along_path_at_speed() -> void:
	var enemy := _make_enemy(_make_unit(10, 20.0))
	enemy.step(1.0)
	assert_float(enemy.progress).is_equal_approx(20.0, 0.01)
	assert_vector(enemy.position).is_equal_approx(Vector2(20, 0), Vector2(0.5, 0.5))


func test_reaches_core_at_path_end() -> void:
	var enemy := _make_enemy(_make_unit(10, 50.0), 100.0)
	var monitor := monitor_signals(enemy)
	enemy.step(1.0)
	await assert_signal(monitor).wait_until(50).is_not_emitted("reached_core")
	enemy.step(1.0)
	await assert_signal(monitor).wait_until(50).is_emitted("reached_core", [enemy])
	assert_bool(enemy.is_alive()).is_false()


func test_dies_when_hp_reaches_zero() -> void:
	var enemy := _make_enemy(_make_unit(10, 10.0))
	var monitor := monitor_signals(enemy)
	enemy.take_damage(6)
	assert_int(enemy.hp).is_equal(4)
	enemy.take_damage(6)
	assert_int(enemy.hp).is_equal(0)
	await assert_signal(monitor).wait_until(50).is_emitted("died", [enemy])
	assert_bool(enemy.is_alive()).is_false()


func test_armor_reduces_damage_to_minimum_one() -> void:
	var enemy := _make_enemy(_make_unit(10, 10.0, 3))
	enemy.take_damage(5)
	assert_int(enemy.hp).is_equal(8)
	enemy.take_damage(2)
	assert_int(enemy.hp).is_equal(7)


func test_dead_enemy_ignores_steps_and_damage() -> void:
	var enemy := _make_enemy(_make_unit(5, 10.0))
	enemy.take_damage(5)
	enemy.step(1.0)
	enemy.take_damage(5)
	assert_float(enemy.progress).is_equal(0.0)
	assert_int(enemy.hp).is_equal(0)


func test_slow_reduces_speed_until_it_wears_off() -> void:
	var enemy := _make_enemy(_make_unit(10, 20.0), 1000.0)
	enemy.apply_slow(0.5, 1.0)
	enemy.step(1.0)
	assert_float(enemy.progress).is_equal_approx(10.0, 0.01)
	enemy.step(1.0)
	assert_float(enemy.progress).is_equal_approx(30.0, 0.01)


func test_held_enemy_does_not_move() -> void:
	var enemy := _make_enemy(_make_unit(10, 20.0))
	enemy.held = true
	enemy.step(1.0)
	assert_float(enemy.progress).is_equal(0.0)
