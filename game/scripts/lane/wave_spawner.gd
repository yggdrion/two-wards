class_name WaveSpawner
extends RefCounted
## Decides when enemies of a wave spawn, its extra groups included. Pure logic; the sim spawns
## the enemies.

var wave: WaveData
var spawned: int = 0
var _timer: float
## Multiplies every spawn interval (difficulty tiers spawn faster).
var _interval_scale: float
var _groups: Array[WaveSpawner] = []


func _init(wave_data: WaveData, interval_scale: float = 1.0) -> void:
	wave = wave_data
	_interval_scale = interval_scale
	_timer = wave_data.start_delay
	for group in wave_data.groups:
		_groups.append(WaveSpawner.new(group, interval_scale))


## Advances time and returns the units that spawn during this step, main group first.
func step(delta: float) -> Array[UnitData]:
	var units: Array[UnitData] = []
	if spawned < wave.count:
		_timer -= delta
		while _timer <= 0.0 and spawned < wave.count:
			spawned += 1
			units.append(wave.enemy)
			_timer += wave.spawn_interval * _interval_scale
	for group in _groups:
		units.append_array(group.step(delta))
	return units


func is_done() -> bool:
	return spawned >= wave.count and _groups.all(func(g: WaveSpawner) -> bool: return g.is_done())
