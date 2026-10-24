extends GdUnitTestSuite


func _make_tower(attack_range: float, damage: int, interval: float) -> SimTower:
	var data := TowerData.new()
	data.attack_range = attack_range
	data.damage = damage
	data.fire_interval = interval
	return SimTower.new(data)


func _make_enemy_at(x: float, hp: int = 100) -> SimEnemy:
	var unit := UnitData.new()
	unit.max_hp = hp
	unit.speed = 0.0
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000, 0))
	var enemy := SimEnemy.new(unit, curve)
	enemy.progress = x
	enemy.position = Vector2(x, 0)
	return enemy


func test_ignores_enemies_out_of_range() -> void:
	var tower := _make_tower(30.0, 5, 1.0)
	var enemies: Array[SimEnemy] = [_make_enemy_at(50.0)]
	tower.step(0.1, enemies)
	assert_int(enemies[0].hp).is_equal(100)


func test_targets_enemy_furthest_along_path() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	var enemies: Array[SimEnemy] = [
		_make_enemy_at(10.0), _make_enemy_at(40.0), _make_enemy_at(200.0)
	]
	assert_object(tower.find_target(enemies)).is_same(enemies[1])


func test_fires_once_per_interval() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	var enemies: Array[SimEnemy] = [_make_enemy_at(10.0)]
	for i in 10:
		tower.step(0.25, enemies)
	# Shots at t=0.25, 1.25, 2.25.
	assert_int(enemies[0].hp).is_equal(85)


func test_skips_dead_enemies() -> void:
	var tower := _make_tower(100.0, 5, 0.1)
	var dead := _make_enemy_at(50.0, 1)
	dead.take_damage(1)
	var alive := _make_enemy_at(10.0)
	var enemies: Array[SimEnemy] = [dead, alive]
	assert_object(tower.find_target(enemies)).is_same(alive)


func test_area_hits_every_enemy_in_range() -> void:
	var tower := _make_tower(30.0, 5, 1.0)
	tower.data.area = true
	var enemies: Array[SimEnemy] = [
		_make_enemy_at(10.0), _make_enemy_at(25.0), _make_enemy_at(50.0)
	]
	tower.step(0.1, enemies)
	assert_array(enemies.map(func(e: SimEnemy) -> int: return e.hp)).is_equal([95, 95, 100])


func test_pierce_hits_the_line() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	tower.data.pierce = true
	var off_line := _make_enemy_at(20.0)
	off_line.position = Vector2(20, 30)
	var enemies: Array[SimEnemy] = [_make_enemy_at(10.0), _make_enemy_at(60.0), off_line]
	tower.step(0.1, enemies)
	assert_array(enemies.map(func(e: SimEnemy) -> int: return e.hp)).is_equal([95, 95, 100])


func test_chain_jumps_to_nearby_enemies() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	tower.data.chain_count = 3
	tower.data.chain_range = 20.0
	var enemies: Array[SimEnemy] = [
		_make_enemy_at(90.0), _make_enemy_at(75.0), _make_enemy_at(60.0), _make_enemy_at(45.0)
	]
	tower.step(0.1, enemies)
	assert_array(enemies.map(func(e: SimEnemy) -> int: return e.hp)).is_equal([95, 95, 95, 100])


func test_slow_without_damage() -> void:
	var tower := _make_tower(30.0, 0, 1.0)
	tower.data.slow_factor = 0.5
	tower.data.slow_duration = 1.0
	var enemies: Array[SimEnemy] = [_make_enemy_at(10.0)]
	tower.step(0.1, enemies)
	assert_int(enemies[0].hp).is_equal(100)
	assert_bool(enemies[0].is_slowed()).is_true()


func test_buff_speeds_up_fire_rate() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	tower.apply_buff(2.0, 10.0)
	var enemies: Array[SimEnemy] = [_make_enemy_at(10.0)]
	for i in 10:
		tower.step(0.25, enemies)
	# Shots at t=0.25, 0.75, 1.25, 1.75, 2.25.
	assert_int(enemies[0].hp).is_equal(75)


func test_timed_tower_expires() -> void:
	var tower := SimTower.new(TowerData.new(), Vector2.ZERO, 1.0)
	var none: Array[SimEnemy] = []
	tower.step(0.5, none)
	assert_bool(tower.is_expired()).is_false()
	tower.step(0.6, none)
	assert_bool(tower.is_expired()).is_true()
