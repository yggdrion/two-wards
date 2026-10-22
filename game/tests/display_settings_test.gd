extends GdUnitTestSuite
## Fullscreen setting: the toggle keys and saving it apart from the profile.

const PATH := "user://test_saves/settings.cfg"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	DirAccess.remove_absolute(PATH)


func _key(code: Key, alt := false, pressed := true, echo := false) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.alt_pressed = alt
	key.pressed = pressed
	key.echo = echo
	return key


func test_defaults_to_windowed_without_a_file() -> void:
	assert_bool(DisplaySettings.load_from(PATH).fullscreen).is_false()


func test_toggle_saves_and_loads_back() -> void:
	var settings := DisplaySettings.load_from(PATH)
	settings.toggle_fullscreen()
	assert_bool(DisplaySettings.load_from(PATH).fullscreen).is_true()
	settings.toggle_fullscreen()
	assert_bool(DisplaySettings.load_from(PATH).fullscreen).is_false()


func test_toggle_keys() -> void:
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_F11))).is_true()
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_ENTER, true))).is_true()
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_KP_ENTER, true))).is_true()
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_ENTER))).is_false()
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_F11, false, false))).is_false()
	assert_bool(DisplaySettings.is_toggle_event(_key(KEY_F11, false, true, true))).is_false()
