class_name DesyncLog
extends RefCounted
## Lane state hashes at fixed points of a run: "wave_<n>" after wave n (1-based) is cleared and
## "end" when the run is won or lost. Host and client keep one each; the host compares the
## client's entries with its own. Every hash is also printed, for debugging real games.

## This lane reached a point; the client sends the hash to the host.
signal recorded(key: String, hash: String)
## A point got both hashes and they differ.
signal mismatch(key: String, ours: String, theirs: String)

## key -> hash of this lane.
var own: Dictionary = {}
## key -> hash reported by the other side.
var remote: Dictionary = {}
var mismatches := PackedStringArray()
var _lane: Lane


func _init(lane: Lane) -> void:
	_lane = lane
	lane.wave_cleared.connect(func(index: int) -> void: _record("wave_%d" % (index + 1)))
	lane.run_won.connect(_record.bind("end"))
	lane.run_lost.connect(_record.bind("end"))


## A hash from the other side; compared at once if ours is known, else when it is.
func report(key: String, hash: String) -> void:
	remote[key] = hash
	_compare(key)


## Keys with a hash on both sides.
func compared() -> int:
	var count := 0
	for key: String in own:
		if remote.has(key):
			count += 1
	return count


func _record(key: String) -> void:
	own[key] = _lane.state_hash()
	print("[net] %s hash %s" % [key, own[key]])
	recorded.emit(key, own[key])
	_compare(key)


func _compare(key: String) -> void:
	if not own.has(key) or not remote.has(key):
		return
	if own[key] != remote[key]:
		mismatches.append(key)
		push_warning("[net] desync at %s: %s here, %s there" % [key, own[key], remote[key]])
		mismatch.emit(key, own[key], remote[key])
