class_name App
extends Node
## Root of the game: loads the profile, shows the meta screens and starts runs with the active
## deck. Saves the profile after every change, so nothing is lost on quit.

enum Screen { CAMP, BOOSTER, COLLECTION, DECKS, RUN }

const GAME_SCENE := preload("res://scenes/game.tscn")
const THEME := preload("res://resources/ui/theme.tres")

## Where the profile is saved; tests point this at a temp file.
@export var save_path := SaveStore.path_for("default")
## Where display options are saved; tests point this at a temp file.
@export var settings_path := DisplaySettings.PATH

var profile: Profile
var display: DisplaySettings
var catalog: CardCatalog
var current: Screen = Screen.CAMP
var _ui: CanvasLayer
var _root: Control
var _screen: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	catalog = CardCatalog.load_dir()
	profile = SaveStore.load_or_create(save_path)
	profile.changed.connect(save)
	display = DisplaySettings.load_from(settings_path)
	display.apply()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.theme = THEME
	_root.size = MetaScreen.SCREEN
	_ui.add_child(_root)
	show_screen(Screen.CAMP)


## F11 and Alt+Enter work on every screen, in and out of runs.
func _input(event: InputEvent) -> void:
	if DisplaySettings.is_toggle_event(event):
		display.toggle_fullscreen()
		get_viewport().set_input_as_handled()


func save() -> void:
	var err := SaveStore.save(profile, save_path)
	if err != OK:
		push_error("Saving %s failed: %s" % [save_path, error_string(err)])


func show_screen(screen: Screen) -> void:
	if _screen != null:
		_screen.get_parent().remove_child(_screen)
		_screen.queue_free()
		_screen = null
	current = screen
	_ui.visible = screen != Screen.RUN
	if screen == Screen.RUN:
		_start_run()
		return
	var view: MetaScreen
	match screen:
		Screen.BOOSTER:
			view = BoosterScreen.new()
		Screen.COLLECTION:
			view = CollectionScreen.new()
		Screen.DECKS:
			view = DeckBuilderScreen.new()
		_:
			var camp := CampScreen.new()
			camp.display = display
			view = camp
	view.setup(profile, catalog)
	view.navigate.connect(func(next: int) -> void: show_screen(next as Screen))
	_root.add_child(view)
	_screen = view


func _start_run() -> void:
	var game: RunScreen = GAME_SCENE.instantiate()
	var lane: Lane = game.get_node("Lane")
	lane.deck = profile.deck_data(profile.active_deck, catalog)
	lane.rng_seed = _rng.randi()
	game.run_ended.connect(profile.add_gold)
	game.finished.connect(show_screen.bind(Screen.CAMP))
	add_child(game)
	_screen = game
