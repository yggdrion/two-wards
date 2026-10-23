extends GdUnitTestSuite
## Co-op lockstep without a network: a host and a client lane in one process, with frames and
## requests delivered a few ticks late, must stay identical. The ENet version of the same
## check is the network test (tools/run_network_test.sh).

const SCENARIO := "res://tests/scenarios/coop_two_wizards_pass_cards.json"
## Ticks a message takes from one side to the other.
const DELAY := 3


class Link:
	extends RefCounted
	## Messages in flight: [deliver_at_tick, payload].
	var queue: Array = []

	func send(now: int, payload: Variant) -> void:
		queue.append([now + DELAY, payload])

	func receive(now: int) -> Array:
		var due: Array = []
		while not queue.is_empty() and queue[0][0] <= now:
			due.append(queue.pop_front()[1])
		return due


func _lane(scenario: Scenario) -> Lane:
	var lane := scenario.build_lane()
	add_child(lane)
	auto_free(lane)
	return lane


## Plays the scenario as host (player 0) and client (player 1). Returns host, client and the
## number of commands the host turned down.
func _play(scenario: Scenario) -> Dictionary:
	var host := LockstepHost.new(_lane(scenario))
	var client := LockstepClient.new(_lane(scenario))
	var to_client := Link.new()
	var to_host := Link.new()
	client.hashes.recorded.connect(
		func(key: String, hash: String) -> void: to_host.send(host.tick, [key, hash])
	)
	var refused := [0]
	host.rejected.connect(func(_cmd: Dictionary, _reason: String) -> void: refused[0] += 1)
	var host_next := 0
	var client_next := 0
	var actions := scenario.actions
	var answered := {}
	while not (host.lane.is_over() and client.lane.is_over()) and host.tick < 60 * 900:
		for message: Variant in to_host.receive(host.tick):
			if message is Dictionary:
				host.request(message)
			else:
				host.hashes.report(message[0], message[1])
		var pick := Scenario.reward_pick(host.lane, 0, answered)
		if not pick.is_empty():
			host.request(pick)
		pick = Scenario.reward_pick(client.lane, 1, answered)
		if not pick.is_empty():
			to_host.send(host.tick, pick)
		while host_next < actions.size() and Scenario.is_due(actions[host_next], host.lane.time):
			var action: Dictionary = actions[host_next]
			if Scenario.player_of(action) == 0:
				var cmd := Scenario.command(host.lane, action)
				if not cmd.has("error"):
					host.request(cmd)
			host_next += 1
		while (
			client_next < actions.size() and Scenario.is_due(actions[client_next], client.lane.time)
		):
			var action: Dictionary = actions[client_next]
			if Scenario.player_of(action) == 1:
				var cmd := Scenario.command(client.lane, action)
				if not cmd.has("error"):
					to_host.send(host.tick, cmd)
			client_next += 1
		if host.can_step():
			to_client.send(host.tick, [host.step()])
		for frames: Variant in to_client.receive(host.tick):
			client.receive(frames)
		client.advance()
		if host.lane.is_over():
			# Nothing else to send: let the last frames and hashes arrive.
			host.tick += 1
	for message: Variant in to_host.receive(1 << 30):
		if message is Array:
			host.hashes.report(message[0], message[1])
	return {"host": host, "client": client, "refused": refused[0]}


func test_host_and_client_stay_in_sync_through_a_coop_run() -> void:
	var run := _play(Scenario.load_file(SCENARIO))
	var host: LockstepHost = run["host"]
	var client: LockstepClient = run["client"]
	assert_bool(host.lane.is_over()).is_true()
	assert_array(Array(client.errors)).is_empty()
	assert_array(Array(host.hashes.mismatches)).is_empty()
	# Ten waves and the end of the run, each compared.
	assert_int(host.hashes.compared()).is_equal(11)
	assert_str(client.lane.state_hash()).is_equal(host.lane.state_hash())
	assert_int(client.lane.players[1].hand.size()).is_equal(host.lane.players[1].hand.size())


func test_mismatching_hash_is_reported() -> void:
	var lane := _lane(Scenario.load_file(SCENARIO))
	var log := DesyncLog.new(lane)
	var seen := []
	log.mismatch.connect(func(key: String, _a: String, _b: String) -> void: seen.append(key))
	log.report("wave_1", "not the real hash")
	lane.wave_cleared.emit(0)
	assert_array(seen).is_equal(["wave_1"])
	assert_int(log.compared()).is_equal(1)


func test_stale_command_is_refused() -> void:
	var lane := _lane(Scenario.load_file(SCENARIO))
	var player := lane.players[1]
	var other := "mend" if String(player.hand[0].id) != "mend" else "ballista"
	var cmd := NetCommand.cycle(1, 0, other)
	assert_str(NetCommand.apply(lane, cmd)).contains("not in slot")
	var real := NetCommand.cycle(1, 0, String(player.hand[0].id))
	assert_str(NetCommand.apply(lane, real)).is_empty()


func test_host_refuses_what_it_cannot_afford_and_tells_the_sender() -> void:
	var host := LockstepHost.new(_lane(Scenario.load_file(SCENARIO)))
	var player := host.lane.players[1]
	player.energy.value = 0.0
	var refused := []
	host.rejected.connect(func(cmd: Dictionary, _reason: String) -> void: refused.append(cmd))
	host.request(NetCommand.cycle(1, 0, String(player.hand[0].id)))
	var frame := host.step()
	assert_int(frame[0]).is_equal(1)
	assert_array(frame[1]).is_empty()
	assert_int(refused.size()).is_equal(1)


func test_host_waits_for_a_slow_client_when_lead_is_capped() -> void:
	var host := LockstepHost.new(_lane(Scenario.load_file(SCENARIO)))
	host.max_lead = 2
	host.step()
	host.step()
	assert_bool(host.can_step()).is_false()
	host.ack(1)
	assert_bool(host.can_step()).is_true()


func test_lobby_url_defaults_to_the_public_lobby() -> void:
	assert_str(Transport.lobby_url()).is_equal(Transport.DEFAULT_LOBBY_URL)


func test_setup_gives_each_player_their_deck() -> void:
	var infos: Array[Dictionary] = [
		CoopSetup.player_info("Ann", "frost", ["mend", "mend"]),
		CoopSetup.player_info("Bo", "ember", ["ballista"]),
	]
	var setup := CoopSetup.make(5, infos)
	assert_array(setup["names"]).is_equal(["Ann", "Bo"])
	var lane: Lane = load(Scenario.LANE_SCENE).instantiate()
	auto_free(lane)
	CoopSetup.configure(lane, setup, Scenario.find_card)
	var ids := lane.decks.map(
		func(deck: DeckData) -> Array:
			return deck.cards.map(func(c: CardData) -> String: return c.id)
	)
	assert_array(ids).is_equal([["mend", "mend"], ["ballista"]])
	assert_int(lane.heroes.size()).is_equal(2)
	assert_bool(lane.autorun).is_false()
