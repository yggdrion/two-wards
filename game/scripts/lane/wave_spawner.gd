class_name WaveSpawner
extends RefCounted
## Decides when enemies of a wave spawn. Pure logic; the sim spawns the enemies.

var wave: WaveData
var spawned: int = 0
var _timer: float


func _init(wave_data: WaveData) -> void:
	wave = wave_data
	_timer = wave_data.start_delay


## Advances time and returns how many enemies spawn during this step.
func step(delta: float) -> int:
	if is_done():
		return 0
	_timer -= delta
	var count := 0
	while _timer <= 0.0 and spawned < wave.count:
		spawned += 1
		count += 1
		_timer += wave.spawn_interval
	return count


func is_done() -> bool:
	return spawned >= wave.count
