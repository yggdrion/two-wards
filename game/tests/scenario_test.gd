extends GdUnitTestSuite
## Replays every scenario in res://tests/scenarios and checks its "expect" block.
##
## A pinned hash changes whenever simulation behaviour changes. If the change is intended,
## copy the new values from the failure message into the scenario file.

const SCENARIO_DIR := "res://tests/scenarios"


func _run(file: String) -> Dictionary:
	var scenario := Scenario.load_file(SCENARIO_DIR.path_join(file))
	return {"scenario": scenario, "result": scenario.run(scenario.build_sim())}


func _check(file: String) -> void:
	var run := _run(file)
	var scenario: Scenario = run["scenario"]
	var result: Dictionary = run["result"]
	var actual := "%s -> %s" % [file, JSON.stringify(result)]
	assert_array(Array(result["errors"])).override_failure_message(actual).is_empty()
	(
		assert_bool(scenario.expect.is_empty())
		. override_failure_message(file + " has no expect")
		. is_false()
	)
	for key: String in scenario.expect:
		var expected: Variant = scenario.expect[key]
		if expected is float:
			expected = int(expected)
		assert_str(str(result[key])).override_failure_message(actual).is_equal(str(expected))


func test_scenario_files_exist() -> void:
	assert_int(DirAccess.get_files_at(SCENARIO_DIR).size()).is_greater_equal(4)


func test_idle_run_is_lost() -> void:
	_check("idle_run_is_lost.json")


func test_tower_deck_wins_full_run() -> void:
	_check("tower_deck_wins_full_run.json")


func test_all_cards_four_waves() -> void:
	_check("all_cards_four_waves.json")


func test_coop_two_wizards_pass_cards() -> void:
	_check("coop_two_wizards_pass_cards.json")


func test_coop_scenario_gives_each_player_a_deck() -> void:
	var run := _run("coop_two_wizards_pass_cards.json")
	var scenario: Scenario = run["scenario"]
	assert_int(scenario.player_count()).is_equal(2)
	var sim := scenario.build_sim()
	assert_int(sim.players.size()).is_equal(2)
	assert_object(sim.players[0].deck).is_not_same(sim.players[1].deck)
	assert_int(sim.decks[0].cards.size()).is_equal(8)
	assert_int(sim.decks[1].cards.size()).is_equal(8)


func test_same_scenario_gives_same_hash() -> void:
	var first: Dictionary = _run("all_cards_four_waves.json")["result"]
	var second: Dictionary = _run("all_cards_four_waves.json")["result"]
	assert_str(second["hash"]).is_equal(first["hash"])


func test_other_seed_changes_the_run() -> void:
	var scenario := Scenario.load_file(SCENARIO_DIR.path_join("idle_run_is_lost.json"))
	var sim_a := scenario.build_sim()
	scenario.rng_seed += 1
	var sim_b := scenario.build_sim()
	var hands := []
	for sim: Sim in [sim_a, sim_b]:
		hands.append(sim.players[0].hand.map(func(card: CardData) -> StringName: return card.id))
	# Three different cards: some seed pair must order them differently; 1 and 2 do.
	assert_array(hands[0]).is_not_equal(hands[1])
