class_name WaveData
extends Resource
## One wave: a number of identical enemies spawned at a fixed interval.

@export var id: StringName
@export var enemy: UnitData
@export var count: int = 1
## Seconds between two spawns.
@export var spawn_interval: float = 1.0
## Seconds before the first spawn.
@export var start_delay: float = 0.0
