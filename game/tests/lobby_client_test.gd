extends GdUnitTestSuite
## LobbyClient's reaction to lobby messages, without a lobby or a socket. The full path (local
## lobby, WebRTC between two Godot processes) is the WebRTC pass of the network test.


func _client() -> LobbyClient:
	var client := LobbyClient.new()
	auto_free(client)
	return client


func test_created_opens_a_server_peer_and_reports_the_code() -> void:
	var client := _client()
	var events: Array = []
	client.peer_created.connect(func(peer: WebRTCMultiplayerPeer) -> void: events.append(peer))
	client.room_created.connect(func(code: String) -> void: events.append(code))
	client.handle({"type": "created", "code": "ABCD", "ice": []})
	assert_int(events.size()).is_equal(2)
	var peer: WebRTCMultiplayerPeer = events[0]
	assert_int(peer.get_unique_id()).is_equal(LobbyClient.HOST_ID)
	assert_str(events[1]).is_equal("ABCD")
	assert_str(client.code).is_equal("ABCD")


func test_joined_connects_a_client_peer_to_the_host() -> void:
	var client := _client()
	var peers: Array = []
	client.peer_created.connect(func(peer: WebRTCMultiplayerPeer) -> void: peers.append(peer))
	client.handle({"type": "joined", "code": "ABCD", "ice": []})
	var peer: WebRTCMultiplayerPeer = peers[0]
	assert_int(peer.get_unique_id()).is_equal(LobbyClient.CLIENT_ID)
	assert_bool(peer.has_peer(LobbyClient.HOST_ID)).is_true()


func test_lobby_errors_and_a_leaving_partner_fail_once() -> void:
	var client := _client()
	var reasons: Array = []
	client.failed.connect(func(reason: String) -> void: reasons.append(reason))
	client.handle({"type": "error", "reason": "no room with that code"})
	client.handle({"type": "peer_left"})
	assert_array(reasons).is_equal(["No room with that code"])


func test_session_reports_lobby_failures() -> void:
	var session := NetSession.new()
	add_child(session)
	auto_free(session)
	var failures := [0]
	session.connection_failed.connect(func() -> void: failures[0] += 1)
	session.join_online("ABCD", {}, "ws://127.0.0.1:1/ws")
	assert_int(session.role).is_equal(NetSession.Role.CLIENT)
	session._lobby.handle({"type": "error", "reason": "room is full"})
	assert_int(failures[0]).is_equal(1)
	assert_str(session.last_error).is_equal("Room is full")
	assert_bool(session.is_active()).is_false()
