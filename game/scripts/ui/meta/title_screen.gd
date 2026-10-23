class_name TitleScreen
extends MetaScreen
## The main menu the game opens on: play (on to the camp), fullscreen and quit.

## Optional; when set, the menu shows a fullscreen toggle.
var display: DisplaySettings
var play_button: Button
var fullscreen_button: Button
var quit_button: Button


func build() -> void:
	var title := label("Two Wards", &"GoldLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 72)
	title.size = Vector2(SCREEN.x, 24)
	add_child(title)
	var tagline := label("Two wizards, one crystal.", &"DimLabel")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(0, 100)
	tagline.size = Vector2(SCREEN.x, 24)
	add_child(tagline)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.position = Vector2(220, 160)
	menu.size = Vector2(200, 0)
	add_child(menu)
	play_button = button("Play", func() -> void: navigate.emit(App.Screen.CAMP))
	menu.add_child(play_button)
	if display != null:
		fullscreen_button = button("", display.toggle_fullscreen)
		menu.add_child(fullscreen_button)
		display.changed.connect(_refresh_fullscreen)
		_refresh_fullscreen()
	quit_button = button("Quit", func() -> void: get_tree().quit())
	menu.add_child(quit_button)


func _refresh_fullscreen() -> void:
	fullscreen_button.text = "Fullscreen: %s (F11)" % ("on" if display.fullscreen else "off")
