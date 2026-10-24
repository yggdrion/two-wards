class_name CampScreen
extends MetaScreen
## The hub the game opens on: start a run with the active deck (solo or co-op), pick a wizard,
## cycle the difficulty tier, open boosters, browse the collection, build decks, toggle
## fullscreen or quit.

## Optional; when set, the menu shows a fullscreen toggle.
var display: DisplaySettings
var fullscreen_button: Button
var start_button: Button
var coop_button: Button
var booster_button: Button
var hero_button: Button
## Cycles the difficulty tier through the unlocked ones.
var tier_button: Button
var menu: VBoxContainer
var deck_label: Label


func build() -> void:
	add_header("Two Wards", false)
	deck_label = label("", &"DimLabel")
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_label.position = Vector2(0, 34)
	deck_label.size = Vector2(SCREEN.x, 24)
	add_child(deck_label)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	menu.position = Vector2((SCREEN.x - 240) / 2, 60)
	menu.size = Vector2(240, 0)
	add_child(menu)
	start_button = button("Start run", func() -> void: navigate.emit(App.Screen.RUN))
	coop_button = button("Co-op", func() -> void: navigate.emit(App.Screen.COOP))
	tier_button = button("", _next_tier)
	hero_button = button("", func() -> void: navigate.emit(App.Screen.HEROES))
	booster_button = button(
		"Booster (%d gold)" % Booster.COST, func() -> void: navigate.emit(App.Screen.BOOSTER)
	)
	for item: Control in [
		start_button,
		coop_button,
		_row([hero_button, tier_button]),
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
	menu.add_child(button("Quit", func() -> void: get_tree().quit()))


## Buttons side by side in one menu row, sharing its width.
func _row(items: Array[Button]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for item in items:
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item)
	return row


func _next_tier() -> void:
	profile.set_tier((profile.tier + 1) % (profile.tier_unlocked + 1))


func _refresh_fullscreen() -> void:
	fullscreen_button.text = "Fullscreen: %s (F11)" % ("on" if display.fullscreen else "off")


func refresh() -> void:
	var index := profile.active_deck
	var deck_name: String = profile.decks[index]["name"]
	var ready := profile.is_deck_valid(index)
	var hero := HeroData.find(profile.hero)
	tier_button.text = "Tier %d/%d" % [profile.tier + 1, profile.tier_unlocked + 1]
	tier_button.disabled = profile.tier_unlocked == 0
	hero_button.text = "Wizard: %s" % (hero.display_name if hero != null else profile.hero)
	start_button.disabled = not ready
	coop_button.disabled = not ready
	if ready:
		deck_label.text = "Deck: %s" % deck_name
	else:
		deck_label.text = "Deck %s is not ready, fix it in Decks" % deck_name
