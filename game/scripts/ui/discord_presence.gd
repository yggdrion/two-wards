class_name DiscordPresence
extends Node
## Shows "Playing Two Wards" and the current screen or wave in the player's Discord profile (Rich
## Presence over the desktop client's local IPC pipe). Does nothing without Discord, with an
## empty client id setting, or headless.
## ponytail: Windows named pipe only; Linux needs a Unix socket, add discord-rpc-gd if it matters.

## The Discord application id (Developer Portal); public, not a secret.
const CLIENT_ID_SETTING := "two_wards/discord/client_id"
const DEFAULT_CLIENT_ID := "1563509032348557382"
## \\?\ prefix: FileAccess rejects the usual \\.\ device path.
const PIPE := "\\\\?\\pipe\\discord-ipc-%d"
const OP_HANDSHAKE := 0
const OP_FRAME := 1
const OP_CLOSE := 2

var _pipe: FileAccess
var _start := 0


func _ready() -> void:
	var id := str(ProjectSettings.get_setting(CLIENT_ID_SETTING, DEFAULT_CLIENT_ID))
	if id.is_empty() or OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	for i in 10:
		_pipe = FileAccess.open(PIPE % i, FileAccess.READ_WRITE)
		if _pipe != null:
			break
	if _pipe == null:
		return
	_start = int(Time.get_unix_time_from_system())
	_send(OP_HANDSHAKE, {"v": 1, "client_id": id})


func _exit_tree() -> void:
	_pipe = null


func set_activity(details: String, state := "") -> void:
	if _pipe == null:
		return
	var activity := {"details": details, "timestamps": {"start": _start}}
	if not state.is_empty():
		activity["state"] = state
	var args := {"pid": OS.get_process_id(), "activity": activity}
	_send(OP_FRAME, {"cmd": "SET_ACTIVITY", "args": args, "nonce": str(Time.get_ticks_usec())})


## One IPC frame: little-endian u32 opcode, u32 payload length, JSON payload.
static func frame(op: int, payload: Dictionary) -> PackedByteArray:
	var json := JSON.stringify(payload).to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(8)
	out.encode_u32(0, op)
	out.encode_u32(4, json.size())
	out.append_array(json)
	return out


## Writes a frame and reads Discord's reply, so the pipe never backs up; drops the pipe when
## Discord closes it (quit, or a wrong client id).
func _send(op: int, payload: Dictionary) -> void:
	_pipe.store_buffer(frame(op, payload))
	var header := _pipe.get_buffer(8)
	if header.size() < 8:
		_pipe = null
		return
	var reply := _pipe.get_buffer(header.decode_u32(4)).get_string_from_utf8()
	if header.decode_u32(0) == OP_CLOSE:
		push_warning("Discord closed the presence pipe: %s" % reply)
		_pipe = null
