extends GdUnitTestSuite

const STEP := 1.0 / 60.0


func _advance(energy: Energy, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		energy.step(STEP)


func test_starts_with_start_energy() -> void:
	assert_int(Energy.new().points()).is_equal(Energy.START)


func test_regenerates_one_point_per_two_seconds() -> void:
	var energy := Energy.new()
	_advance(energy, 1.9)
	assert_int(energy.points()).is_equal(Energy.START)
	_advance(energy, 0.1)
	assert_int(energy.points()).is_equal(Energy.START + 1)
	_advance(energy, 4.0)
	assert_int(energy.points()).is_equal(Energy.START + 3)


func test_caps_at_max() -> void:
	var energy := Energy.new()
	_advance(energy, 60.0)
	assert_int(energy.points()).is_equal(Energy.MAX)


func test_spend() -> void:
	var energy := Energy.new()
	assert_bool(energy.can_spend(3)).is_true()
	assert_bool(energy.can_spend(4)).is_false()
	energy.spend(2)
	assert_int(energy.points()).is_equal(1)
