class_name LockstepClient
extends RefCounted
## The client side of a co-op run: replays the host's frames on its own lane. The client never
## changes the lane on its own; its card plays go to the host as requests and come back in a
## frame. See LockstepHost.

var lane: Lane
## Ticks done so far.
var tick := 0
var hashes: DesyncLog
## Host commands that failed here. Any entry means the lanes have already drifted apart.
var errors := PackedStringArray()
var _frames: Array = []


func _init(run_lane: Lane) -> void:
	lane = run_lane
	hashes = DesyncLog.new(lane)


func receive(frames: Array) -> void:
	_frames.append_array(frames)


## Frames received but not played yet.
func backlog() -> int:
	return _frames.size()


## Plays up to `max_ticks` received frames; returns how many it played.
func advance(max_ticks: int = 1 << 30) -> int:
	var done := 0
	while done < max_ticks and not _frames.is_empty():
		var frame: Array = _frames.pop_front()
		for cmd: Dictionary in frame[1]:
			var error := NetCommand.apply(lane, cmd)
			if not error.is_empty():
				errors.append("tick %d: %s" % [frame[0], error])
		lane.tick(LockstepHost.STEP)
		tick = frame[0]
		done += 1
	return done
