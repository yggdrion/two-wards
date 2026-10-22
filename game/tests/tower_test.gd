extends GdUnitTestSuite


func _make_tower(attack_range: float, damage: int, interval: float) -> Tower:
	var data := TowerData.new()
	data.attack_range = attack_range
	data.damage = damage
	data.fire_interval = interval
	var tower: Tower = auto_free(Tower.new())
	tower.setup(data)
	return tower


func _make_enemy_at(x: float, hp: int = 100) -> Enemy:
	var unit := UnitData.new()
	unit.max_hp = hp
	unit.speed = 0.0
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000, 0))
	var enemy: Enemy = auto_free(Enemy.new())
	enemy.setup(unit, curve)
	enemy.progress = x
	enemy.position = Vector2(x, 0)
	return enemy


func test_ignores_enemies_out_of_range() -> void:
	var tower := _make_tower(30.0, 5, 1.0)
	var enemies: Array[Enemy] = [_make_enemy_at(50.0)]
	tower.step(0.1, enemies)
	assert_int(enemies[0].hp).is_equal(100)


func test_targets_enemy_furthest_along_path() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	var enemies: Array[Enemy] = [_make_enemy_at(10.0), _make_enemy_at(40.0), _make_enemy_at(200.0)]
	assert_object(tower.find_target(enemies)).is_same(enemies[1])


func test_fires_once_per_interval() -> void:
	var tower := _make_tower(100.0, 5, 1.0)
	var enemies: Array[Enemy] = [_make_enemy_at(10.0)]
	for i in 10:
		tower.step(0.25, enemies)
	# Shots at t=0.25, 1.25, 2.25.
	assert_int(enemies[0].hp).is_equal(85)


func test_skips_dead_enemies() -> void:
	var tower := _make_tower(100.0, 5, 0.1)
	var dead := _make_enemy_at(50.0, 1)
	dead.take_damage(1)
	var alive := _make_enemy_at(10.0)
	var enemies: Array[Enemy] = [dead, alive]
	assert_object(tower.find_target(enemies)).is_same(alive)
