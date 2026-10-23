class_name Transport
## Creates the MultiplayerPeer under the game's high-level multiplayer API. Gameplay code only
## sees Godot's multiplayer signals and RPCs, so switching transport is this one setting:
## ProjectSettings "two_wards/network/transport" ("enet" now, "webrtc" in M5).

enum Kind { ENET, WEBRTC }

const SETTING := "two_wards/network/transport"
const DEFAULT_PORT := 7777
## Co-op is two players: the host and one client.
const MAX_CLIENTS := 1


static func configured() -> Kind:
	var name := str(ProjectSettings.get_setting(SETTING, "enet")).to_lower()
	return Kind.WEBRTC if name == "webrtc" else Kind.ENET


## A listening host peer, or null (the error is logged).
static func create_host(port: int, kind: Kind = configured()) -> MultiplayerPeer:
	if kind != Kind.ENET:
		push_error("Transport %s is not available yet (M5)" % Kind.keys()[kind])
		return null
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Hosting on port %d failed: %s" % [port, error_string(err)])
		return null
	return peer


## A client peer connecting to address:port, or null (the error is logged).
static func create_client(address: String, port: int, kind: Kind = configured()) -> MultiplayerPeer:
	if kind != Kind.ENET:
		push_error("Transport %s is not available yet (M5)" % Kind.keys()[kind])
		return null
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Connecting to %s:%d failed: %s" % [address, port, error_string(err)])
		return null
	return peer
