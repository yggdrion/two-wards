class_name LockstepHost
extends RefCounted
## The host side of a co-op run. The host's lane is the authority and the host is the clock:
## each step() applies the card commands that arrived since the last step, ticks the lane once
## and returns a frame for the client. Frames are [tick, commands]; the client applies the
## same commands before the same tick, so both lanes stay identical without sending state.
##
## Desync check: both sides hash the lane after each cleared wave and at the end of the run
## (DesyncLog); the client reports its hashes and the host compares them.

## A command was refused; the network layer tells the player who sent it.
signal rejected(cmd: Dictionary, reason: String)

const STEP := 1.0 / 60.0

var lane: Lane
## Ticks done so far.
var tick := 0
## The client's last confirmed tick (see ack()).
var acked_tick := 0
## How many ticks the host may run ahead of the client; 0 never waits. The network test uses
## it so a fast headless host can't run away from its client.
var max_lead := 0
var hashes: DesyncLog
var _pending: Array[Dictionary] = []


func _init(run_lane: Lane) -> void:
	lane = run_lane
	hashes = DesyncLog.new(lane)


## Queues a card command (from this machine or from the client) for the next step.
func request(cmd: Dictionary) -> void:
	_pending.append(cmd)


func ack(client_tick: int) -> void:
	acked_tick = maxi(acked_tick, client_tick)


func can_step() -> bool:
	if lane.is_over():
		return false
	return max_lead <= 0 or tick - acked_tick < max_lead


## Applies the queued commands, ticks the lane once and returns the frame to send.
func step() -> Array:
	var applied: Array[Dictionary] = []
	for cmd in _pending:
		var error := NetCommand.apply(lane, cmd)
		if error.is_empty():
			applied.append(cmd)
		else:
			rejected.emit(cmd, error)
	_pending.clear()
	lane.tick(STEP)
	tick += 1
	return [tick, applied]
