extends GdUnitTestSuite
## The App and its meta screens, driven through the same calls the buttons make.

const APP_SCENE := preload("res://scenes/main.tscn")
const PATH := "user://test_saves/app_profile.json"
const SETTINGS_PATH := "user://test_saves/app_settings.cfg"


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


func test_starts_on_camp_with_new_profile() -> void:
	var app := _app()
	assert_int(app.current).is_equal(App.Screen.CAMP)
	var camp: CampScreen = app._screen
	assert_bool(camp.start_button.disabled).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_true()


func test_save_survives_restart() -> void:
	var app := _app()
	app.profile.add_gold(70)
	app.profile.add_card("war_drums")
	app.free()
	var again := _app()
	assert_int(again.profile.gold).is_equal(70)
	assert_int(again.profile.owned("war_drums")).is_equal(1)


func test_camp_blocks_run_with_invalid_deck() -> void:
	var app := _app()
	app.profile.set_deck_cards(0, ["mend"])
	var camp: CampScreen = app._screen
	assert_bool(camp.start_button.disabled).is_true()


func test_booster_screen_opens_and_reveals() -> void:
	var app := _app()
	app.profile.add_gold(Booster.COST)
	app.show_screen(App.Screen.BOOSTER)
	var screen: BoosterScreen = app._screen
	screen.open_booster()
	assert_bool(screen.is_animating()).is_true()
	screen.reveal_all()
	assert_bool(screen.is_animating()).is_false()
	assert_int(app.profile.gold).is_equal(0)
	assert_bool(screen.open_button.disabled).is_true()
	for i in Booster.SLOTS:
		assert_bool(screen.cards[i].visible).is_true()
		assert_bool(screen.cards[i].face_down).is_false()
		assert_object(screen.cards[i].card).is_same(screen.pulls[i]["card"])
		assert_bool(screen.new_badges[i].visible).is_equal(screen.pulls[i]["new"])


func test_collection_dims_unowned_cards() -> void:
	var app := _app()
	app.show_screen(App.Screen.COLLECTION)
	var screen: CollectionScreen = app._screen
	assert_int(screen.views.size()).is_equal(12)
	for view in screen.views:
		var owned := app.profile.owned(String(view.card.id)) > 0
		assert_bool(view.modulate == Color.WHITE).is_equal(owned)


func test_deck_builder_adds_and_removes() -> void:
	var app := _app()
	app.show_screen(App.Screen.DECKS)
	var screen: DeckBuilderScreen = app._screen
	screen.select_deck(1)
	screen.add_card("mend")
	screen.add_card("mend")
	screen.add_card("mend")
	assert_array(app.profile.deck_cards(1)).is_equal(["mend", "mend"])
	screen.remove_card("mend")
	assert_array(app.profile.deck_cards(1)).is_equal(["mend"])
	assert_bool(screen.active_button.disabled).is_true()


func test_deck_builder_sets_active_deck() -> void:
	var app := _app()
	app.profile.set_deck_cards(1, Profile.STARTER_DECK)
	app.show_screen(App.Screen.DECKS)
	var screen: DeckBuilderScreen = app._screen
	screen.select_deck(1)
	assert_bool(screen.active_button.disabled).is_false()
	screen.active_button.pressed.emit()
	assert_int(app.profile.active_deck).is_equal(1)


func test_run_uses_active_deck_and_pays_gold() -> void:
	var app := _app()
	app.show_screen(App.Screen.RUN)
	var game: RunScreen = app._screen
	var lane: Lane = game.get_node("Lane")
	lane.autorun = false
	lane.set_physics_process(false)
	assert_int(lane.deck.cards.size()).is_equal(DeckRules.SIZE)
	lane.gold = 30
	lane.run_lost.emit()
	assert_int(app.profile.gold).is_equal(30)
	game.finished.emit()
	assert_int(app.current).is_equal(App.Screen.CAMP)


func test_camp_toggles_fullscreen_and_remembers_it() -> void:
	var app := _app()
	var camp: CampScreen = app._screen
	assert_str(camp.fullscreen_button.text).contains("off")
	camp.fullscreen_button.pressed.emit()
	assert_bool(app.display.fullscreen).is_true()
	assert_str(camp.fullscreen_button.text).contains("on")
	app.free()
	assert_bool(_app().display.fullscreen).is_true()


func test_f11_toggles_fullscreen_on_any_screen() -> void:
	var app := _app()
	app.show_screen(App.Screen.COLLECTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F11
	key.pressed = true
	app._input(key)
	assert_bool(app.display.fullscreen).is_true()


func test_hero_select_saves_the_wizard_and_the_run_uses_it() -> void:
	var app := _app()
	var camp: CampScreen = app._screen
	assert_str(camp.hero_button.text).is_equal("Wizard: Frost")
	app.show_screen(App.Screen.HEROES)
	var screen: HeroSelectScreen = app._screen
	assert_int(screen.heroes.size()).is_equal(2)
	var ember := screen.heroes.find(HeroData.find("ember"))
	screen.choose_buttons[ember].pressed.emit()
	assert_str(app.profile.hero).is_equal("ember")
	assert_bool(screen.choose_buttons[ember].disabled).is_true()
	app.free()
	var again := _app()
	assert_str(again.profile.hero).is_equal("ember")
	again.show_screen(App.Screen.RUN)
	var lane: Lane = again._screen.get_node("Lane")
	lane.set_physics_process(false)
	assert_str(String(lane.players[0].hero.id)).is_equal("ember")


func test_coop_screen_hosts_and_cancels() -> void:
	var app := _app()
	var camp: CampScreen = app._screen
	assert_bool(camp.coop_button.disabled).is_false()
	app.show_screen(App.Screen.COOP)
	var screen: CoopScreen = app._screen
	screen.port_edit.text = "17790"
	screen.host_button.pressed.emit()
	assert_int(app.net.role).is_equal(NetSession.Role.HOST)
	assert_bool(screen.host_button.disabled).is_true()
	assert_str(screen.status_label.text).contains("17790")
	screen.cancel_button.pressed.emit()
	assert_bool(app.net.is_active()).is_false()
	app.show_screen(App.Screen.CAMP)


func test_coop_screen_saves_the_player_name() -> void:
	var app := _app()
	app.show_screen(App.Screen.COOP)
	var screen: CoopScreen = app._screen
	screen.name_edit.text_changed.emit("  Rapha ")
	assert_str(app.profile.player_name).is_equal("Rapha")
	assert_str(screen.player_info()["name"]).is_equal("Rapha")
	assert_int(screen.player_info()["deck"].size()).is_equal(DeckRules.SIZE)


func test_leaving_the_coop_screen_closes_the_connection() -> void:
	var app := _app()
	app.show_screen(App.Screen.COOP)
	var screen: CoopScreen = app._screen
	screen.port_edit.text = "17791"
	screen.host()
	app.show_screen(App.Screen.CAMP)
	assert_bool(app.net.is_active()).is_false()


func test_coop_run_starts_from_the_setup() -> void:
	var app := _app()
	var infos: Array[Dictionary] = [
		CoopSetup.player_info("Ann", "ember", app.profile.deck_cards(0)),
		CoopSetup.player_info("Bo", "frost", app.profile.deck_cards(0)),
	]
	app.net.role = NetSession.Role.HOST
	app.net.setup = CoopSetup.make(9, infos)
	app.show_screen(App.Screen.RUN)
	var game: RunScreen = app._screen
	assert_object(game.host).is_not_null()
	assert_int(game.lane.players.size()).is_equal(2)
	assert_int(game.lane.deck.cards.size()).is_equal(DeckRules.SIZE * 2)
	assert_bool(game.lane.autorun).is_false()
	app.net.role = NetSession.Role.NONE
	app.show_screen(App.Screen.CAMP)


func test_profile_arg_picks_another_save() -> void:
	assert_str(App.profile_from_args(PackedStringArray(["--profile=p2"]))).is_equal("p2")
	assert_str(App.profile_from_args(PackedStringArray(["--other"]))).is_empty()
