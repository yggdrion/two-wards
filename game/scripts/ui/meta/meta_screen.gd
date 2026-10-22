class_name MetaScreen
extends Control
## Base for the screens between runs. Builds its controls in code on top of the shared UI
## theme (resources/ui/theme.tres), so the art pass only swaps the theme's styleboxes.
##
## Screens never save; they change the Profile, and the App saves on its changed signal.

## Asks the App to show another screen (App.Screen) or to start a run.
signal navigate(screen: int)

const SCREEN := Vector2(640, 360)
const HEADER_HEIGHT := 36.0

var profile: Profile
var catalog: CardCatalog
var _gold_label: Label


func setup(meta_profile: Profile, card_catalog: CardCatalog) -> MetaScreen:
	profile = meta_profile
	catalog = card_catalog
	return self


func _ready() -> void:
	size = SCREEN
	var background := Panel.new()
	background.theme_type_variation = &"ScreenBackground"
	background.size = SCREEN
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	build()
	if profile != null:
		profile.changed.connect(_on_profile_changed)
		_on_profile_changed()


## Creates the screen's controls. Called once from _ready.
func build() -> void:
	pass


## Pulls the profile into the controls; called after every profile change.
func refresh() -> void:
	pass


## Title on the left, gold on the right and, unless this is the camp, a Back button.
func add_header(title: String, back := true) -> void:
	var header := label(title)
	header.position = Vector2(12, 6)
	add_child(header)
	_gold_label = label("", &"GoldLabel")
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.size = Vector2(160, 24)
	_gold_label.position = Vector2(SCREEN.x - (240 if back else 172), 6)
	add_child(_gold_label)
	if back:
		var back_button := button("Back", func() -> void: navigate.emit(App.Screen.CAMP))
		back_button.position = Vector2(SCREEN.x - 72, 4)
		back_button.size = Vector2(64, 28)
		add_child(back_button)


static func label(text: String, variation: StringName = &"") -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	result.mouse_filter = MOUSE_FILTER_IGNORE
	return result


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = FOCUS_NONE
	result.pressed.connect(on_pressed)
	return result


func _on_profile_changed() -> void:
	if _gold_label != null:
		_gold_label.text = "Gold %d" % profile.gold
	refresh()
