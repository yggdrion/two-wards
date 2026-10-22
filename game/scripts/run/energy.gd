class_name Energy
extends RefCounted
## A player's energy: regenerates over time, capped, spent on cards and cycling.

const MAX := 10
const SECONDS_PER_POINT := 2.0
const START := 3
## Absorbs float drift so 2 s of 1/60 s steps really yields a full point.
const EPSILON := 0.000001

var value: float = START


func step(delta: float) -> void:
	value = minf(value + delta / SECONDS_PER_POINT, MAX)


func points() -> int:
	return floori(value + EPSILON)


func can_spend(amount: int) -> bool:
	return points() >= amount


func spend(amount: int) -> void:
	value = maxf(value - amount, 0.0)
