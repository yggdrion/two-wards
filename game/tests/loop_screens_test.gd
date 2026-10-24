extends GdUnitTestSuite
## The full-loop screens around a run (co-op lobby, run end), driven through the App like the
## meta screen tests.

const APP_SCENE := preload("res://scenes/main.tscn")
const PATH := "user://test_saves/loop_profile.json"
const SETTINGS_PATH := "user://test_saves/loop_settings.cfg"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(SETTINGS_PATH)


func _app() -> App:
	var app: App = APP_SCENE.instantiate()
	app.save_path = PATH
	app.settings_path = SETTINGS_PATH
	add_child(app)
	auto_free(app)
	return app


func test_run_end_leads_to_a_booster_with_enough_gold() -> void:
	var app := _app()
	app.profile.add_gold(Booster.COST)
	app.last_run = {"result": "won", "waves_cleared": 10, "waves": 10, "gold": 125}
	app.show_screen(App.Screen.RUN_END)
	var end: RunEndScreen = app._screen
	assert_bool(end.booster_button.disabled).is_false()
	end.booster_button.pressed.emit()
	assert_int(app.current).is_equal(App.Screen.BOOSTER)


func test_host_goes_to_the_lobby_and_starts_once_the_partner_is_ready() -> void:
	var app := _app()
	app.show_screen(App.Screen.COOP)
	app.net.role = NetSession.Role.HOST
	app.net.partner_info = CoopSetup.player_info("Bo", "frost", app.profile.deck_cards(0))
	app.net.partner_joined.emit(app.net.partner_info)
	assert_int(app.current).is_equal(App.Screen.LOBBY)
	var lobby: LobbyScreen = app._screen
	assert_bool(lobby.start_button.visible).is_true()
	assert_bool(lobby.ready_button.visible).is_false()
	assert_bool(lobby.start_button.disabled).is_true()
	app.net.partner_is_ready = true
	app.net.partner_ready.emit()
	assert_bool(lobby.start_button.disabled).is_false()
	lobby.start_button.pressed.emit()
	assert_int(app.current).is_equal(App.Screen.RUN)
	var game: RunScreen = app._screen
	assert_array(game.session.setup["names"]).is_equal([app.profile.display_name(), "Bo"])
	app.net.role = NetSession.Role.NONE
	app.show_screen(App.Screen.CAMP)


func test_client_lobby_shows_host_first_and_a_ready_button() -> void:
	var app := _app()
	app.show_screen(App.Screen.COOP)
	app.net.role = NetSession.Role.CLIENT
	app.net.partner_info = CoopSetup.player_info("Ann", "ember", ["mend"])
	app.net.partner_joined.emit(app.net.partner_info)
	var lobby: LobbyScreen = app._screen
	assert_str(lobby.infos()[0]["name"]).is_equal("Ann")
	assert_bool(lobby.ready_button.visible).is_true()
	assert_bool(lobby.start_button.visible).is_false()
	app.net.partner_left.emit()
	assert_int(app.current).is_equal(App.Screen.COOP)
	assert_bool(app.net.is_active()).is_false()
	app.show_screen(App.Screen.CAMP)


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func test_escape_menu_leaves_the_run_without_gold() -> void:
	var app := _app()
	app.show_screen(App.Screen.RUN)
	var game: RunScreen = app._screen
	game.lane.set_physics_process(false)
	var gold := app.profile.gold
	game.sim.gold = 30
	game._unhandled_input(_key(KEY_ESCAPE))
	assert_bool(game.hud.confirm_leave).is_true()
	game._unhandled_input(_key(KEY_Q))
	assert_bool(game.hud.confirm_leave).is_true()
	game._unhandled_input(_key(KEY_ESCAPE))
	assert_bool(game.hud.confirm_leave).is_false()
	assert_int(app.current).is_equal(App.Screen.RUN)
	game._unhandled_input(_key(KEY_ESCAPE))
	game.hud.leave_button.pressed.emit()
	assert_int(app.current).is_equal(App.Screen.CAMP)
	assert_int(app.profile.gold).is_equal(gold)
