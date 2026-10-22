class_name SlowEffect
extends CardEffect
## Slows every enemy within radius of the target.

## Speed multiplier while slowed.
@export var factor: float = 0.5
@export var duration: float = 2.0
@export var radius: float = 24.0


func apply(ctx: CardContext) -> void:
	for enemy in ctx.lane.enemies_near(ctx.target, radius):
		enemy.apply_slow(factor, duration)
