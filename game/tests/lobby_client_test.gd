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


func test_host_refuses_another_build_and_the_client_says_why() -> void:
	var host := NetSession.new()
	add_child(host)
	auto_free(host)
	host.role = NetSession.Role.HOST
	host._hello({"protocol": NetSession.PROTOCOL, "build": "abc1234", "name": "Kim"})
	assert_dict(host.partner_info).is_empty()
	assert_str(host.last_error).contains("dev").contains("abc1234")
	var client := NetSession.new()
	add_child(client)
	auto_free(client)
	var failures := [0]
	client.connection_failed.connect(func() -> void: failures[0] += 1)
	client.role = NetSession.Role.CLIENT
	client._refused(host.last_error)
	assert_int(failures[0]).is_equal(1)
	assert_str(client.last_error).is_equal(host.last_error)
	assert_bool(client.is_active()).is_false()


func test_host_accepts_the_same_build() -> void:
	var host := NetSession.new()
	add_child(host)
	auto_free(host)
	host.role = NetSession.Role.HOST
	host._hello({"protocol": NetSession.PROTOCOL, "build": NetSession.build_id(), "name": "Kim"})
	assert_str(host.partner_info.get("name", "")).is_equal("Kim")


func test_candidate_summary_reads_type_and_address() -> void:
	(
		assert_str(
			LobbyClient.candidate_summary(
				"candidate:1 1 UDP 2122317823 192.168.1.20 51234 typ host"
			)
		)
		. is_equal("host 192.168.1.20")
	)
	(
		assert_str(
			LobbyClient.candidate_summary(
				"a=candidate:2 1 UDP 1686052607 84.1.2.3 40000 typ srflx raddr 0.0.0.0 rport 0"
			)
		)
		. is_equal("srflx 84.1.2.3")
	)
	assert_str(LobbyClient.candidate_summary("garbage")).is_empty()


func test_private_addresses_count_as_lan() -> void:
	for ip in ["127.0.0.1", "10.0.0.5", "172.16.0.1", "172.31.255.1", "192.168.1.20", "::1"]:
		assert_bool(NetSession.is_private_ip(ip)).override_failure_message(ip).is_true()
	for ip in ["172.32.0.1", "84.1.2.3", "8.8.8.8", "2001:db8::1"]:
		assert_bool(NetSession.is_private_ip(ip)).override_failure_message(ip).is_false()


func test_debug_lines_offline() -> void:
	var session := NetSession.new()
	add_child(session)
	auto_free(session)
	assert_array(session.debug_lines()).is_equal(["Build dev", "Net  offline"])
