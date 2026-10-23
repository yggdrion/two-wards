class_name LobbyClient
extends Node
## Finds the partner through the lobby server (lobby/) and sets up the WebRTC connection.
## The lobby gives out a room code and relays the WebRTC offer, answer and ICE candidates;
## game traffic then goes peer to peer (or through the TURN relay). See lobby/src/rooms.ts for
## the message format.
##
## The WebRTCMultiplayerPeer is handed out as soon as it exists (`peer_created`), so the
## NetSession can put it under the multiplayer API, which polls it. Once the two peers are
## connected the lobby socket is closed: the lobby never sees gameplay.

## The multiplayer peer to use: a server (id 1) when hosting, a client (id 2) when joining.
signal peer_created(peer: WebRTCMultiplayerPeer)
## Host: the room is open under this code.
signal room_created(code: String)
## Something went wrong before the peers connected; `reason` is shown to the player.
signal failed(reason: String)

const HOST_ID := 1
## The lobby message format (lobby/src/server.ts PROTOCOL). Game messages have their own
## version, NetSession.PROTOCOL.
const PROTOCOL := 1
const CLIENT_ID := 2

var code := ""
var _ws := WebSocketPeer.new()
## The first message, sent once the socket is open.
var _hello: Dictionary = {}
var _rtc: WebRTCMultiplayerPeer
var _connection: WebRTCPeerConnection
var _ice: Array = []
var _done := false


## Opens a room. `protocol` must match the lobby's.
func create(url: String, protocol: int = PROTOCOL) -> void:
	_open(url, {"type": "create", "protocol": protocol})


## Joins the room with this code.
func join(url: String, room_code: String, protocol: int = PROTOCOL) -> void:
	_open(url, {"type": "join", "code": room_code.strip_edges().to_upper(), "protocol": protocol})


func _open(url: String, hello: Dictionary) -> void:
	_hello = hello
	var err := _ws.connect_to_url(url)
	if err != OK:
		_fail("Could not reach the lobby (%s)" % error_string(err))


func _process(_delta: float) -> void:
	if _done:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _hello.is_empty():
		_send(_hello)
		_hello = {}
	while _ws.get_available_packet_count() > 0:
		var msg: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if msg is Dictionary:
			handle(msg)
	if _done:
		return
	if (
		_connection != null
		and _connection.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED
	):
		# Tell the lobby the room is done, then let go of it.
		_send({"type": "connected"})
		_ws.close()
		_done = true
	elif (
		_connection != null
		and _connection.get_connection_state() == WebRTCPeerConnection.STATE_FAILED
	):
		_fail("No connection to the partner, even through the relay")
	elif state == WebSocketPeer.STATE_CLOSED:
		_fail("Lost the lobby connection" if code != "" else "Could not reach the lobby")


## One message from the lobby.
func handle(msg: Dictionary) -> void:
	match str(msg.get("type")):
		"created":
			code = str(msg.get("code"))
			_ice = msg.get("ice", [])
			_rtc = WebRTCMultiplayerPeer.new()
			_rtc.create_server()
			peer_created.emit(_rtc)
			room_created.emit(code)
		"joined":
			code = str(msg.get("code"))
			_ice = msg.get("ice", [])
			_rtc = WebRTCMultiplayerPeer.new()
			_rtc.create_client(CLIENT_ID)
			_connect_to(HOST_ID)
			peer_created.emit(_rtc)
		"peer_joined":
			# The host makes the offer.
			_connect_to(CLIENT_ID)
			_connection.create_offer()
		"signal":
			_on_signal(msg.get("data", {}))
		"peer_left":
			_fail("The partner left")
		"error":
			var reason := str(msg.get("reason", "lobby error"))
			_fail(reason.left(1).to_upper() + reason.substr(1))


func _connect_to(peer_id: int) -> void:
	_connection = WebRTCPeerConnection.new()
	var err := _connection.initialize({"iceServers": _ice})
	if err != OK:
		_fail("WebRTC is not available (%s)" % error_string(err))
		return
	_connection.session_description_created.connect(_on_description_created)
	_connection.ice_candidate_created.connect(_on_candidate_created)
	_rtc.add_peer(_connection, peer_id)


func _on_description_created(kind: String, sdp: String) -> void:
	_connection.set_local_description(kind, sdp)
	_send({"type": "signal", "data": {"kind": kind, "sdp": sdp}})


func _on_candidate_created(mid: String, index: int, sdp: String) -> void:
	_send(
		{
			"type": "signal",
			"data": {"kind": "candidate", "mid": mid, "index": index, "sdp": sdp},
		}
	)


func _on_signal(data: Variant) -> void:
	if not data is Dictionary or _connection == null:
		return
	match str(data.get("kind")):
		"offer", "answer":
			# Setting the remote offer makes the joiner create its answer.
			_connection.set_remote_description(str(data["kind"]), str(data.get("sdp")))
		"candidate":
			_connection.add_ice_candidate(
				str(data.get("mid")), int(data.get("index", 0)), str(data.get("sdp"))
			)


func _send(msg: Dictionary) -> void:
	_ws.send_text(JSON.stringify(msg))


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	_ws.close()
	failed.emit(reason)
