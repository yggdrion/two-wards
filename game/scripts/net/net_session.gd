class_name NetSession
extends Node
## One co-op connection: hosting or joining, the start handshake and the run messages. It only
## moves plain Dictionaries and Arrays between the two machines; LockstepHost and
## LockstepClient decide what they mean.
##
## The node must sit at the same path on both machines (the App keeps it as its "Net" child),
## because Godot routes RPCs by node path.
##
## Handshake: the client connects and sends hello (name, wizard, deck); the host answers with
## the run setup (seed, both names, wizards and decks, host first) and both start the run.

## Client connected and said hello (host only).
signal partner_joined(hello: Dictionary)
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
## Connecting to a host failed (client only).
signal connection_failed
## The other machine left or the connection dropped.
signal partner_left

enum Role { NONE, HOST, CLIENT }

## Bumped when messages change; a mismatching client is turned away.
const PROTOCOL := 1

var role := Role.NONE
## The setup of the running game, empty before run_started.
var setup: Dictionary = {}
## What the host refused to start with, shown on the co-op screen.
var last_error := ""
var _hello_info: Dictionary = {}
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
	_hello_info = hello.duplicate()
	_hello_info["protocol"] = PROTOCOL
	return true


func close() -> void:
	if (
		multiplayer.multiplayer_peer != null
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for connection in _connections:
		if connection["signal"].is_connected(connection["callable"]):
			connection["signal"].disconnect(connection["callable"])
	_connections.clear()
	role = Role.NONE
	setup = {}


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
	partner_joined.emit(info)


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
