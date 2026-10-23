class_name Transport
## Creates the MultiplayerPeer under the game's high-level multiplayer API. Gameplay code only
## sees Godot's multiplayer signals and RPCs, so it doesn't care which transport carries them:
## ENet by address and port (LAN, tests) or WebRTC through the lobby (LobbyClient, online).

## The lobby's WebSocket URL; override in project settings for a local lobby.
const LOBBY_SETTING := "two_wards/network/lobby_url"
const DEFAULT_LOBBY_URL := "wss://twowards.r4b2.de:8443/ws"
const DEFAULT_PORT := 7777
## Co-op is two players: the host and one client.
const MAX_CLIENTS := 1


static func lobby_url() -> String:
	return str(ProjectSettings.get_setting(LOBBY_SETTING, DEFAULT_LOBBY_URL))


## A listening ENet host peer, or null (the error is logged).
static func create_host(port: int) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Hosting on port %d failed: %s" % [port, error_string(err)])
		return null
	return peer


## An ENet client peer connecting to address:port, or null (the error is logged).
static func create_client(address: String, port: int) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Connecting to %s:%d failed: %s" % [address, port, error_string(err)])
		return null
	return peer
