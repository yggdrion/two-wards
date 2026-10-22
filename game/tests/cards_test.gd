extends GdUnitTestSuite
## One test per card: each of the 12 cards is played on a real lane through Lane.play_card.

const LANE_SCENE := preload("res://scenes/lane.tscn")
const STEP := 1.0 / 60.0
const HERO_AT := Vector2(160, 64)
## A free spot near HERO_AT, off the path.
const SPOT := Vector2(150, 60)
const RUNNER := preload("res://resources/units/goblin_runner.tres")
const ARROW := preload("res://resources/towers/arrow_tower.tres")

var lane: Lane
var player: PlayerState


func before_test() -> void:
	lane = LANE_SCENE.instantiate()
	lane.autorun = false
	lane.waves = []
	lane.deck = null
	add_child(lane)
	auto_free(lane)
	player = lane.players[0]
	player.energy.value = Energy.MAX
	lane.hero.position = HERO_AT


func _card(id: String) -> CardData:
	return load("res://resources/cards/%s.tres" % id)


## Puts the card in slot 0 and plays it.
func _play(id: String, at: Vector2 = Vector2.ZERO) -> bool:
	player.hand[0] = _card(id)
	return lane.play_card(0, 0, at)


func _enemy_at(progress: float) -> Enemy:
	var enemy := lane.spawn_enemy(RUNNER)
	enemy.progress = progress
	enemy.step(0.0)
	return enemy


func _tick(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		lane.tick(STEP)


func _tower_card_places(id: String) -> void:
	var card := _card(id)
	assert_bool(_play(id, SPOT)).is_true()
	assert_int(lane.get_towers().size()).is_equal(1)
	assert_object(lane.get_towers()[0].data).is_same(card.effects[0].tower)
	assert_int(player.energy.points()).is_equal(Energy.MAX - card.cost)


func test_arrow_tower() -> void:
	_tower_card_places("arrow_tower")


func test_frost_totem() -> void:
	_tower_card_places("frost_totem")
	var enemy := _enemy_at(0.0)
	enemy.position = SPOT + Vector2(10, 0)
	lane.get_towers()[0].step(STEP, lane.enemies)
	assert_bool(enemy.is_slowed()).is_true()


func test_ballista() -> void:
	_tower_card_places("ballista")
	assert_bool(lane.get_towers()[0].data.pierce).is_true()


func test_storm_spire() -> void:
	_tower_card_places("storm_spire")
	assert_int(lane.get_towers()[0].data.chain_count).is_equal(3)


func test_tower_cards_must_be_near_hero() -> void:
	assert_bool(_play("arrow_tower", HERO_AT + Vector2(0, -60))).is_false()
	assert_int(lane.get_towers().size()).is_equal(0)
	assert_int(player.energy.points()).is_equal(Energy.MAX)


func test_tower_cards_cannot_go_on_the_path() -> void:
	assert_bool(_play("arrow_tower", Vector2(130, 96))).is_false()


func test_arcane_bolt() -> void:
	var enemy := _enemy_at(50.0)
	assert_bool(_play("arcane_bolt", enemy.position + Vector2(3, 0))).is_true()
	assert_int(enemy.hp).is_equal(RUNNER.max_hp - 20)


func test_arcane_bolt_needs_a_target() -> void:
	assert_bool(_play("arcane_bolt", SPOT)).is_false()


func test_mend() -> void:
	lane.core.take_damage(8)
	assert_bool(_play("mend")).is_true()
	assert_int(lane.core.hp).is_equal(lane.core.max_hp - 3)


func test_blink() -> void:
	assert_bool(_play("blink", HERO_AT + Vector2(100, 0))).is_true()
	assert_vector(lane.hero.position).is_equal(HERO_AT + Vector2(64, 0))
	assert_bool(lane.hero.invulnerable > 0.0).is_true()


func test_decoy_effigy() -> void:
	var enemy := _enemy_at(20.0)
	assert_bool(_play("decoy_effigy", enemy.position)).is_true()
	var held_at := enemy.progress
	_tick(4.0)
	assert_float(enemy.progress).is_equal_approx(held_at, 0.01)
	_tick(1.5)
	assert_float(enemy.progress).is_greater(held_at)


func test_war_drums() -> void:
	var tower := lane.place_tower(ARROW, SPOT)
	var far := lane.place_tower(ARROW, Vector2(40, 90))
	assert_bool(_play("war_drums")).is_true()
	assert_bool(tower.is_buffed()).is_true()
	assert_bool(far.is_buffed()).is_false()


func test_war_drums_needs_a_tower_nearby() -> void:
	assert_bool(_play("war_drums")).is_false()


func test_arcane_focus() -> void:
	assert_bool(_play("arcane_focus")).is_true()
	var spent := Energy.MAX - player.energy.points()
	assert_bool(_play("ballista", SPOT)).is_true()
	assert_int(Energy.MAX - player.energy.points()).is_equal(spent)


func test_mirror_image() -> void:
	var original := lane.place_tower(ARROW, SPOT)
	assert_bool(_play("mirror_image", SPOT + Vector2(20, 0))).is_true()
	var towers := lane.get_towers()
	assert_int(towers.size()).is_equal(2)
	var copy := towers[1]
	assert_object(copy.data).is_same(original.data)
	assert_bool(copy.is_copy).is_true()
	_tick(30.5)
	assert_array(lane.get_towers()).contains_exactly([original])


func test_mirror_image_needs_a_tower() -> void:
	assert_bool(_play("mirror_image", SPOT)).is_false()


func test_time_warp() -> void:
	var enemy := _enemy_at(0.0)
	enemy.progress = lane.path.curve.get_baked_length()
	_tick(STEP)
	assert_int(lane.core.hp).is_equal(lane.core.max_hp - RUNNER.core_damage)
	assert_bool(_play("time_warp")).is_true()
	assert_int(lane.core.hp).is_equal(lane.core.max_hp)


func test_time_warp_forgets_old_damage() -> void:
	lane.time = 0.0
	var enemy := _enemy_at(0.0)
	enemy.progress = lane.path.curve.get_baked_length()
	_tick(STEP)
	_tick(10.5)
	assert_bool(_play("time_warp")).is_false()
