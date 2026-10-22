extends GdUnitTestSuite

const WAVE_01 := preload("res://resources/waves/wave_01.tres")


func _make_wave(count: int, interval: float, delay: float) -> WaveData:
	var wave := WaveData.new()
	wave.enemy = UnitData.new()
	wave.count = count
	wave.spawn_interval = interval
	wave.start_delay = delay
	return wave


func test_waits_for_start_delay() -> void:
	var spawner := WaveSpawner.new(_make_wave(3, 1.0, 2.0))
	assert_int(spawner.step(1.5)).is_equal(0)
	assert_int(spawner.step(0.5)).is_equal(1)


func test_spawns_at_interval_until_count() -> void:
	var spawner := WaveSpawner.new(_make_wave(3, 1.0, 0.0))
	var total := 0
	for i in 10:
		total += spawner.step(0.5)
	assert_int(total).is_equal(3)
	assert_bool(spawner.is_done()).is_true()
	assert_int(spawner.step(5.0)).is_equal(0)


func test_large_step_spawns_several() -> void:
	var spawner := WaveSpawner.new(_make_wave(5, 1.0, 0.0))
	assert_int(spawner.step(2.5)).is_equal(3)


func test_wave_01_resource_loads() -> void:
	assert_object(WAVE_01).is_instanceof(WaveData)
	assert_object(WAVE_01.enemy).is_instanceof(UnitData)
	assert_str(String(WAVE_01.enemy.id)).is_equal("goblin_runner")
	assert_int(WAVE_01.count).is_greater(0)
