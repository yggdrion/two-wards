extends GdUnitTestSuite

const PATH := "user://test_saves/profile.json"


func before_test() -> void:
	for file in [PATH, PATH + ".bak", PATH + ".tmp"]:
		DirAccess.remove_absolute(file)


func _write(data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(data if data is String else JSON.stringify(data))
	file.close()


func test_save_and_load_round_trip() -> void:
	var profile := Profile.create()
	profile.add_gold(120)
	profile.add_card("storm_spire")
	assert_int(SaveStore.save(profile, PATH)).is_equal(OK)
	var loaded := SaveStore.load_profile(PATH)
	assert_dict(loaded.to_dict()).is_equal(profile.to_dict())
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()


func test_save_has_version_field() -> void:
	SaveStore.save(Profile.create(), PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_int(int(data["version"])).is_equal(SaveStore.VERSION)


func test_missing_file_creates_and_saves_new_profile() -> void:
	var profile := SaveStore.load_or_create(PATH)
	assert_bool(profile.is_deck_valid(0)).is_true()
	assert_bool(FileAccess.file_exists(PATH)).is_true()


func test_v0_save_is_migrated() -> void:
	_write({"name": "old", "gold": 30, "cards": ["mend", "mend", "blink"]})
	var profile := SaveStore.load_profile(PATH)
	assert_str(profile.profile_name).is_equal("old")
	assert_int(profile.gold).is_equal(30)
	assert_int(profile.owned("mend")).is_equal(2)
	assert_int(profile.owned("empower")).is_equal(1)
	assert_int(profile.decks.size()).is_equal(DeckRules.MAX_DECKS)
	assert_int(profile.boosters_since_epic).is_equal(0)
	assert_str(profile.hero).is_equal(Profile.DEFAULT_HERO)


func test_v1_save_gets_a_wizard_and_empower_for_blink() -> void:
	_write(
		{
			"version": 1,
			"name": "m3",
			"gold": 80,
			"collection": {"blink": 2, "mend": 2},
			"decks": [{"name": "Starter", "cards": ["blink", "mend", "blink"]}],
			"active_deck": 0,
			"boosters_since_epic": 3,
		}
	)
	var profile := SaveStore.load_profile(PATH)
	assert_str(profile.hero).is_equal("frost")
	assert_int(profile.owned("blink")).is_equal(0)
	assert_int(profile.owned("empower")).is_equal(2)
	assert_array(profile.deck_cards(0)).is_equal(["empower", "mend", "empower"])
	assert_int(profile.gold).is_equal(80)
	assert_int(profile.boosters_since_epic).is_equal(3)


func test_migrate_sets_current_version() -> void:
	var migrated := SaveStore.migrate({"cards": []})
	assert_int(int(migrated["version"])).is_equal(SaveStore.VERSION)


func test_newer_version_is_not_loaded() -> void:
	_write({"version": SaveStore.VERSION + 1, "gold": 999})
	assert_object(SaveStore.load_profile(PATH)).is_null()


func test_unreadable_save_is_kept_as_backup() -> void:
	_write("{not json")
	var profile := SaveStore.load_or_create(PATH)
	assert_int(profile.gold).is_equal(0)
	assert_str(FileAccess.get_file_as_string(PATH + ".bak")).is_equal("{not json")
