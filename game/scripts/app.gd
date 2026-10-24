class_name App
extends Node
## Root of the game: loads the profile, opens on the camp, shows the meta screens and
## starts runs with the active deck and the chosen wizard. Saves the profile after every change,
## so nothing is lost on quit.

enum Screen { CAMP, BOOSTER, COLLECTION, DECKS, HEROES, COOP, LOBBY, RUN, RUN_END }

const GAME_SCENE := preload("res://scenes/game.tscn")
const THEME := preload("res://resources/ui/theme.tres")

## Where the profile is saved; tests point this at a temp file.
@export var save_path := SaveStore.path_for("default")
## Where display options are saved; tests point this at a temp file.
@export var settings_path := DisplaySettings.PATH

var profile: Profile
## Co-op connection; the same node path on both machines, so RPCs find it.
var net: NetSession
var display: DisplaySettings
var presence: DiscordPresence
var catalog: CardCatalog
var current: Screen = Screen.CAMP
## RunScreen.summary() of the last finished run, shown on the run-end screen.
var last_run: Dictionary = {}
var _ui: CanvasLayer
var _root: Control
var _screen: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	net.run_started.connect(func(_setup: Dictionary) -> void: show_screen(Screen.RUN))
	var overlay := DebugOverlay.new()
	overlay.session = net
	add_child(overlay)
	presence = DiscordPresence.new()
	add_child(presence)
	catalog = CardCatalog.load_dir()
	var profile_arg := profile_from_args(OS.get_cmdline_args() + OS.get_cmdline_user_args())
	if not profile_arg.is_empty():
		save_path = SaveStore.path_for(profile_arg)
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


## "--profile=<name>" picks another save, e.g. for two copies of the game on one PC.
static func profile_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--profile="):
			return arg.trim_prefix("--profile=").validate_filename()
	return ""


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
	presence.set_activity("In camp")
	if screen != Screen.COOP and screen != Screen.LOBBY:
		net.close()
	var view: MetaScreen
	match screen:
		Screen.BOOSTER:
			view = BoosterScreen.new()
		Screen.COLLECTION:
			view = CollectionScreen.new()
		Screen.DECKS:
			view = DeckBuilderScreen.new()
		Screen.HEROES:
			view = HeroSelectScreen.new()
		Screen.COOP:
			var coop := CoopScreen.new()
			coop.session = net
			view = coop
		Screen.LOBBY:
			var lobby := LobbyScreen.new()
			lobby.session = net
			view = lobby
		Screen.RUN_END:
			var run_end := RunEndScreen.new()
			run_end.summary = last_run
			view = run_end
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
	var sim := lane.sim
	if net.is_active() and not net.setup.is_empty():
		lane.autorun = false
		CoopSetup.configure(sim, net.setup, _find_card)
		sim.upgrade_pool = UpgradeData.load_all()
		game.session = net
		game.player = net.local_player()
		_add_run(game)
		return
	var decks: Array[DeckData] = [profile.deck_data(profile.active_deck, catalog)]
	sim.decks = decks
	sim.upgrade_pool = UpgradeData.load_all()
	var hero := HeroData.find(profile.hero)
	if hero == null:
		hero = HeroData.find(Profile.DEFAULT_HERO)
	var heroes: Array[HeroData] = [hero]
	sim.heroes = heroes
	sim.rng_seed = _rng.randi()
	sim.tier = profile.tier
	_add_run(game)


## Pays the run's gold when it ends, unlocks the next tier after a win, and shows the run-end
## screen when the player leaves it.
func _add_run(game: RunScreen) -> void:
	var sim: Sim = game.get_node("Lane").sim
	var unlocked := [false]
	game.run_ended.connect(
		func(gold: int) -> void:
			profile.add_gold(gold)
			if sim.phase == Sim.Phase.WON:
				unlocked[0] = profile.unlock_tier(sim.tier + 1)
	)
	game.left.connect(func() -> void: show_screen(Screen.CAMP))
	game.finished.connect(
		func() -> void:
			last_run = game.summary()
			last_run["unlocked"] = unlocked[0]
			show_screen(Screen.RUN_END)
	)
	var mode := "Co-op" if net.is_active() else "Solo"
	var lane: Lane = game.get_node("Lane")
	lane.sim.wave_started.connect(
		func(index: int) -> void: presence.set_activity("Wave %d" % (index + 1), mode)
	)
	presence.set_activity("Starting a run", mode)
	add_child(game)
	_screen = game


func _find_card(card_id: String) -> CardData:
	return catalog.get_card(card_id) if catalog.has(card_id) else null
