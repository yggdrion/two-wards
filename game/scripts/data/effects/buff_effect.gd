class_name BuffEffect
extends CardEffect
## Speeds up the fire rate of towers near the target point for a while.

@export var fire_rate: float = 1.5
@export var duration: float = 10.0
## Towers within this distance of the target are buffed.
@export var radius: float = 96.0


func can_apply(ctx: CardContext) -> bool:
	return not ctx.sim.towers_near(ctx.target, radius).is_empty()


func apply(ctx: CardContext) -> void:
	for tower in ctx.sim.towers_near(ctx.target, radius):
		tower.apply_buff(fire_rate, duration)
