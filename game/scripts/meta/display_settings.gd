class_name DisplaySettings
extends RefCounted
## Machine-wide display options (fullscreen), kept in a ConfigFile apart from the profile save,
## since they belong to the screen and not to the player.
##
## The picture always scales by whole multiples of 640x360 (project stretch settings), so pixels
## stay sharp in any window or fullscreen; the rest of the screen gets bars.

signal changed

const PATH := "user://settings.cfg"

var path := PATH
var fullscreen := false


static func load_from(settings_path: String = PATH) -> DisplaySettings:
	var settings := DisplaySettings.new()
	settings.path = settings_path
	var file := ConfigFile.new()
	if file.load(settings_path) == OK:
		settings.fullscreen = file.get_value("display", "fullscreen", false)
	return settings


## True for the keys that toggle fullscreen: F11 and Alt+Enter.
static func is_toggle_event(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_F11:
		return true
	return key.alt_pressed and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("display", "fullscreen", fullscreen)
	return file.save(path)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	var err := save()
	if err != OK:
		push_error("Saving %s failed: %s" % [path, error_string(err)])
	changed.emit()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


## Puts the window into the saved mode. Does nothing without a real window (headless tests).
func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
