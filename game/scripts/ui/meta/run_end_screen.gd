class_name RunEndScreen
extends MetaScreen
## After a run: how it ended, its tier, waves cleared, the gold it earned and a newly unlocked
## tier, with the way on to a
## booster or back to the camp.

## RunScreen.summary() of the run that just ended.
var summary: Dictionary = {}
var booster_button: Button
var camp_button: Button


func build() -> void:
	add_header("Run over", false)
	var title := label(_title())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 88)
	title.size = Vector2(SCREEN.x, 24)
	add_child(title)
	var tier := int(summary.get("tier", 0))
	var text := (
		"Tier %d - waves cleared %d/%d\n+%d gold"
		% [
			tier + 1,
			summary.get("waves_cleared", 0),
			summary.get("waves", 0),
			summary.get("gold", 0)
		]
	)
	if summary.get("unlocked", false):
		text += "\nTier %d unlocked!" % (tier + 2)
	var details := label(text, &"GoldLabel")
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.position = Vector2(0, 124)
	details.size = Vector2(SCREEN.x, 64)
	add_child(details)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu.position = Vector2(220, 196)
	menu.size = Vector2(200, 0)
	add_child(menu)
	booster_button = button(
		"Open a booster (%d gold)" % Booster.COST, func() -> void: navigate.emit(App.Screen.BOOSTER)
	)
	camp_button = button("Camp", func() -> void: navigate.emit(App.Screen.CAMP))
	menu.add_child(booster_button)
	menu.add_child(camp_button)


func refresh() -> void:
	booster_button.disabled = profile.gold < Booster.COST


func _title() -> String:
	match str(summary.get("result", "")):
		"won":
			return "Victory! The crystal held."
		"lost":
			return "The crystal shattered."
		"partner_left":
			return "Your partner left."
	return "Run over"
