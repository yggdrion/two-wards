extends SceneTree
## One side of the headless network test: a host or a client that plays a scenario over ENet
## on localhost, or over WebRTC through a lobby, the same way the game does (NetSession,
## LockstepHost, LockstepClient).
## tools/run_network_test.py starts both sides for every scenario.
##
## The host plays the scenario's player 0 actions, the client those of player 1 (a solo
## scenario's client joins without a deck or wizard and only watches). Both compare lane hashes
## after every wave and at the end. Exit code: 0 in sync, 1 desync or failed commands, 2
## timeout or no connection.
##
## Usage: godot --headless --path game --script res://tools/net_test.gd -- \
##   --role=host|client --scenario=res://tests/scenarios/<name>.json [--port=17777]
## WebRTC: add --lobby=ws://127.0.0.1:<port>/ws; the host logs "room <code>", and the client
## needs --code=<code>.

## Ticks the host runs per frame, so a 10-wave run takes seconds instead of minutes.
const TICKS_PER_FRAME := 30
## How far the host may run ahead of the client.
const MAX_LEAD := 60
const TIMEOUT_MS := 180000
const CONNECT_ATTEMPTS := 40
const RETRY_MS := 250

var _role := ""
var _port := 17777
var _lobby := ""
var _code := ""
var _scenario: Scenario
var _session: NetSession
var _host: LockstepHost
var _client: LockstepClient
var _lane: Lane
var _next_action := 0
var _answered := {}
var _refused := 0
var _attempts := 0
var _retry_at := 0
var _started_ms := 0
var _exit := -1
var _started := false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"role":
				_role = value
			"port":
				_port = value.to_int()
			"lobby":
				_lobby = value
			"code":
				_code = value
			"scenario":
				_scenario = Scenario.load_file(value)
	if _scenario == null or not _role in ["host", "client"]:
		push_error("usage: --role=host|client --scenario=<file> [--port=N]")
		_exit = 2
		return
	_session = NetSession.new()
	_session.name = "Net"
	root.add_child(_session)


## Runs on the first frame: until then the session isn't in the tree and has no multiplayer.
func _start() -> void:
	_started = true
	_session.run_started.connect(_on_run_started)
	_session.partner_joined.connect(_on_partner_joined)
	_session.connection_failed.connect(_on_connection_failed)
	_session.partner_left.connect(_on_partner_left)
	_session.room_ready.connect(func(code: String) -> void: _log("room %s" % code))
	if _role == "host" and _lobby != "":
		_session.host_online(_lobby)
	elif _role == "host":
		if not _session.host(_port):
			_exit = 2
	elif _lobby != "":
		_session.join_online(_code, _player_info(1), _lobby)
	else:
		_retry_at = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _exit < 0 and Time.get_ticks_msec() - _started_ms > TIMEOUT_MS:
		_log("timeout")
		_exit = 2
	if _exit >= 0:
		if _session != null and _session.is_inside_tree():
			_session.close()
		quit(_exit)
		return true
	if not _started:
		_start()
	if _role == "client" and _retry_at > 0 and Time.get_ticks_msec() >= _retry_at:
		_connect()
	if _host != null:
		_step_host()
	elif _client != null:
		_step_client()
	return false


func _on_connection_failed() -> void:
	if _lobby != "":
		_log("connection failed: %s" % _session.last_error)
		_exit = 2
	else:
		_retry_at = Time.get_ticks_msec() + RETRY_MS


func _connect() -> void:
	_retry_at = 0
	_attempts += 1
	if _attempts > CONNECT_ATTEMPTS:
		_log("no host on port %d" % _port)
		_exit = 2
		return
	if not _session.join("127.0.0.1", _port, _player_info(1)):
		_retry_at = Time.get_ticks_msec() + RETRY_MS


## The scenario's part for one player; a solo scenario's client brings nothing.
func _player_info(player: int) -> Dictionary:
	var setup := _scenario.setup()
	if player >= setup["names"].size():
		return CoopSetup.player_info("Watcher", "", [])
	return CoopSetup.player_info(
		setup["names"][player], setup["heroes"][player], setup["decks"][player]
	)


func _on_partner_joined(hello: Dictionary) -> void:
	var infos: Array[Dictionary] = [_player_info(0), hello]
	_session.start_run(CoopSetup.make(_scenario.rng_seed, infos))


func _on_run_started(setup: Dictionary) -> void:
	_lane = _scenario.build_lane(setup)
	root.add_child(_lane)
	if _role == "host":
		_host = LockstepHost.new(_lane)
		_host.max_lead = MAX_LEAD
		_host.rejected.connect(_on_rejected)
		_session.command_received.connect(_host.request)
		_session.ack_received.connect(_host.ack)
		_session.hash_received.connect(_host.hashes.report)
	else:
		_client = LockstepClient.new(_lane)
		_session.frames_received.connect(_client.receive)
		_session.command_rejected.connect(_on_rejected)
		_client.hashes.recorded.connect(_session.send_hash)
	_log("run started, seed %d" % setup["seed"])


func _step_host() -> void:
	var frames: Array = []
	for i in TICKS_PER_FRAME:
		if not _host.can_step():
			break
		_queue_actions(0, _host.request)
		frames.append(_host.step())
	if not frames.is_empty():
		_session.send_frames(frames)
	if _lane.is_over() and _host.hashes.compared() == _host.hashes.own.size():
		_finish(_host.hashes.mismatches.is_empty())


func _step_client() -> void:
	while _client.backlog() > 0:
		_queue_actions(1, _session.send_command)
		_client.advance(1)
	_session.send_ack(_client.tick)
	# The client stops when the host is done and hangs up (see _on_partner_left).


## Sends this side's reward pick and the scenario actions due at the lane's current time.
func _queue_actions(player: int, send: Callable) -> void:
	if player < _lane.players.size():
		var pick := Scenario.reward_pick(_lane, player, _answered)
		if not pick.is_empty():
			send.call(pick)
	var actions := _scenario.actions
	while _next_action < actions.size() and Scenario.is_due(actions[_next_action], _lane.time):
		var action: Dictionary = actions[_next_action]
		_next_action += 1
		if Scenario.player_of(action) != player:
			continue
		var cmd := Scenario.command(_lane, action)
		if cmd.has("error"):
			_log("skipped t=%.2f: %s" % [action["t"], cmd["error"]])
		else:
			send.call(cmd)


func _on_rejected(cmd: Dictionary, reason: String) -> void:
	_refused += 1
	_log("refused %s %s: %s" % [cmd.get("kind"), cmd.get("card"), reason])


func _on_partner_left() -> void:
	if _role == "client" and _lane != null and _lane.is_over():
		_finish(_client.errors.is_empty())
	else:
		_log("partner left early")
		_exit = 2


func _finish(ok: bool) -> void:
	if _exit >= 0:
		return
	var hashes := _host.hashes if _host != null else _client.hashes
	var result := Scenario.result_of(
		_lane, _client.errors if _client != null else PackedStringArray()
	)
	_log(
		(
			"%s: %s, %d waves, crystal %d, %d hashes compared, %d mismatches, %d refused, %s"
			% [
				"in sync" if ok else "DESYNC",
				result["result"],
				result["waves_cleared"],
				result["crystal_hp"],
				hashes.compared() if _host != null else hashes.own.size(),
				hashes.mismatches.size(),
				_refused,
				result["hash"],
			]
		)
	)
	for error in result["errors"]:
		_log("client command failed: %s" % error)
	_exit = 0 if ok and result["result"] != "timeout" else 1


func _log(text: String) -> void:
	print("[%s %s] %s" % [_role, _scenario.name if _scenario != null else "?", text])
