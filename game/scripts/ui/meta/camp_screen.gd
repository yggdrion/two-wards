class_name CampScreen
extends MetaScreen
## The hub between runs: start a run with the active deck, pick a wizard, open boosters,
## browse the collection, build decks.

## Optional; when set, the camp shows a fullscreen toggle.
var display: DisplaySettings
var start_button: Button
var fullscreen_button: Button
var booster_button: Button
var hero_button: Button
var _deck_label: Label


func build() -> void:
	add_header("Two Wards", false)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.position = Vector2(220, 56)
	menu.size = Vector2(200, 0)
	add_child(menu)
	start_button = button("Start run", func() -> void: navigate.emit(App.Screen.RUN))
	hero_button = button("", func() -> void: navigate.emit(App.Screen.HEROES))
	booster_button = button(
		"Booster (%d gold)" % Booster.COST, func() -> void: navigate.emit(App.Screen.BOOSTER)
	)
	for item: Button in [
		start_button,
		hero_button,
		booster_button,
		button("Collection", func() -> void: navigate.emit(App.Screen.COLLECTION)),
		button("Decks", func() -> void: navigate.emit(App.Screen.DECKS)),
	]:
		menu.add_child(item)
	if display != null:
		fullscreen_button = button("", display.toggle_fullscreen)
		menu.add_child(fullscreen_button)
		display.changed.connect(_refresh_fullscreen)
		_refresh_fullscreen()
	_deck_label = label("", &"DimLabel")
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_label.position = Vector2(0, 316)
	_deck_label.size = Vector2(SCREEN.x, 24)
	add_child(_deck_label)


func refresh() -> void:
	var index := profile.active_deck
	var deck_name: String = profile.decks[index]["name"]
	var ready := profile.is_deck_valid(index)
	var hero := HeroData.find(profile.hero)
	hero_button.text = "Wizard: %s" % (hero.display_name if hero != null else profile.hero)
	start_button.disabled = not ready
	if ready:
		_deck_label.text = "Deck: %s" % deck_name
	else:
		_deck_label.text = "Deck %s is not ready, fix it in Decks" % deck_name


func _refresh_fullscreen() -> void:
	fullscreen_button.text = "Fullscreen: %s (F11)" % ("on" if display.fullscreen else "off")
