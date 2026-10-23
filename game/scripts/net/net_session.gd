class_name NetSession
extends Node
## One co-op connection: hosting or joining, the start handshake and the run messages. Online
## play goes through the lobby (host_online/join_online, WebRTC via LobbyClient); host/join
## connect directly over ENet (LAN, tests). Everything after the connection is the same. It only
## moves plain Dictionaries and Arrays between the two machines; LockstepHost and
## LockstepClient decide what they mean.
##
## The node must sit at the same path on both machines (the App keeps it as its "Net" child),
## because Godot routes RPCs by node path.
##
## Handshake: the client connects and sends hello (name, wizard, deck); the host shows the
## lobby and sends its own info back (share_lobby), so both see both decks. The client says
## ready, the host answers with the run setup (seed, both names, wizards and decks, host first)
## and both start the run.

## The partner's info arrived: the client's hello on the host, the host's info on the client.
signal partner_joined(info: Dictionary)
## The client is ready to start (host only).
signal partner_ready
## The run starts with this setup; the local player is local_player().
signal run_started(setup: Dictionary)
## Host frames for the client's LockstepClient (client only).
signal frames_received(frames: Array)
## The client asks to play a card (host only).
signal command_received(cmd: Dictionary)
## The host refused one of our commands (client only).
signal command_rejected(cmd: Dictionary, reason: String)
## The client reached this tick (host only).
signal ack_received(tick: int)
## The client's lane hash at a desync check point (host only).
signal hash_received(key: String, hash: String)
## Hosting online: the lobby opened a room under this code for the partner to join.
signal room_ready(code: String)
## Connecting failed (client, or an online host whose room closed); see last_error.
signal connection_failed
## The other machine left or the connection dropped.
signal partner_left

enum Role { NONE, HOST, CLIENT }

## Bumped when game messages change; the host turns a mismatching client away after hello.
## The lobby has its own version (LobbyClient.PROTOCOL).
const PROTOCOL := 2

var role := Role.NONE
## The setup of the running game, empty before run_started.
var setup: Dictionary = {}
## The partner's name, wizard and deck (CoopSetup.player_info), empty until partner_joined.
var partner_info: Dictionary = {}
## Host: the client said it is ready.
var partner_is_ready := false
## Why the last connection failed or what the host refused, shown on the co-op screen.
var last_error := ""
var _hello_info: Dictionary = {}
var _lobby: LobbyClient
## Multiplayer signals this session listens to, so close() can let go of them.
var _connections: Array[Dictionary] = []


## Starts listening for a partner. Returns false if the port can't be opened.
func host(port: int = Transport.DEFAULT_PORT) -> bool:
	close()
	var peer := Transport.create_host(port)
	if peer == null:
		return false
	_use_peer(peer)
	role = Role.HOST
	return true


## Starts connecting; connected peers send hello at once with this info.
func join(address: String, port: int, hello: Dictionary) -> bool:
	close()
	var peer := Transport.create_client(address, port)
	if peer == null:
		return false
	_use_peer(peer)
	role = Role.CLIENT
	_set_hello(hello)
	return true


## Opens a room on the lobby; room_ready gives its code, partner_joined follows as with host().
func host_online(url: String = Transport.lobby_url()) -> void:
	close()
	role = Role.HOST
	_start_lobby().create(url)


## Joins the lobby room with this code; sends hello once connected, as with join().
func join_online(code: String, hello: Dictionary, url: String = Transport.lobby_url()) -> void:
	close()
	role = Role.CLIENT
	_set_hello(hello)
	_start_lobby().join(url, code)


func close() -> void:
	if (
		multiplayer.multiplayer_peer != null
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _lobby != null:
		_lobby.queue_free()
		_lobby = null
	for connection in _connections:
		if connection["signal"].is_connected(connection["callable"]):
			connection["signal"].disconnect(connection["callable"])
	_connections.clear()
	role = Role.NONE
	setup = {}
	partner_info = {}
	partner_is_ready = false


func is_active() -> bool:
	return role != Role.NONE


## 0 on the host, 1 on the client.
func local_player() -> int:
	return 1 if role == Role.CLIENT else 0


## Host: starts the run on both machines.
func start_run(run_setup: Dictionary) -> void:
	setup = run_setup
	_start.rpc(run_setup)
	run_started.emit(run_setup)


## Host: sends our own info to the client for its lobby.
func share_lobby(info: Dictionary) -> void:
	_lobby_info.rpc(info)


## Client: tells the host we are ready to start.
func send_ready() -> void:
	_ready_to_start.rpc_id(1)


func send_frames(frames: Array) -> void:
	_frames.rpc(frames)


func send_command(cmd: Dictionary) -> void:
	_command.rpc_id(1, cmd)


func send_ack(tick: int) -> void:
	_ack.rpc_id(1, tick)


func send_hash(key: String, hash: String) -> void:
	_hash.rpc_id(1, key, hash)


func reject(cmd: Dictionary, reason: String) -> void:
	_rejected.rpc(cmd, reason)


func _set_hello(hello: Dictionary) -> void:
	_hello_info = hello.duplicate()
	_hello_info["protocol"] = PROTOCOL


func _start_lobby() -> LobbyClient:
	_lobby = LobbyClient.new()
	_lobby.name = "Lobby"
	add_child(_lobby)
	_lobby.peer_created.connect(_use_peer)
	_lobby.room_created.connect(room_ready.emit)
	_lobby.failed.connect(_on_lobby_failed)
	return _lobby


func _on_lobby_failed(reason: String) -> void:
	last_error = reason
	close()
	connection_failed.emit()


func _use_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	_listen(multiplayer.peer_disconnected, _on_peer_disconnected)
	_listen(multiplayer.connected_to_server, _on_connected)
	_listen(multiplayer.connection_failed, _on_connection_failed)
	_listen(multiplayer.server_disconnected, _on_peer_disconnected.bind(1))


func _listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append({"signal": sig, "callable": callable})


func _on_connected() -> void:
	_hello.rpc_id(1, _hello_info)


func _on_connection_failed() -> void:
	last_error = "No host answered"
	close()
	connection_failed.emit()


func _on_peer_disconnected(_id: int) -> void:
	partner_left.emit()


@rpc("any_peer", "call_remote", "reliable")
func _hello(info: Dictionary) -> void:
	if role != Role.HOST or not setup.is_empty():
		return
	if int(info.get("protocol", 0)) != PROTOCOL:
		last_error = "Partner runs another game version"
		multiplayer.multiplayer_peer.disconnect_peer(multiplayer.get_remote_sender_id())
		return
	partner_info = info
	partner_joined.emit(info)


@rpc("authority", "call_remote", "reliable")
func _lobby_info(info: Dictionary) -> void:
	partner_info = info
	partner_joined.emit(info)


@rpc("any_peer", "call_remote", "reliable")
func _ready_to_start() -> void:
	if role == Role.HOST and not partner_info.is_empty():
		partner_is_ready = true
		partner_ready.emit()


@rpc("authority", "call_remote", "reliable")
func _start(run_setup: Dictionary) -> void:
	setup = run_setup
	run_started.emit(run_setup)


@rpc("authority", "call_remote", "reliable")
func _frames(frames: Array) -> void:
	frames_received.emit(frames)


@rpc("authority", "call_remote", "reliable")
func _rejected(cmd: Dictionary, reason: String) -> void:
	command_rejected.emit(cmd, reason)


@rpc("any_peer", "call_remote", "reliable")
func _command(cmd: Dictionary) -> void:
	if role != Role.HOST:
		return
	# The client may only act for its own player.
	cmd["player"] = 1
	command_received.emit(cmd)


@rpc("any_peer", "call_remote", "reliable")
func _ack(tick: int) -> void:
	if role == Role.HOST:
		ack_received.emit(tick)


@rpc("any_peer", "call_remote", "reliable")
func _hash(key: String, hash: String) -> void:
	if role == Role.HOST:
		hash_received.emit(key, hash)
