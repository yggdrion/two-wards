class_name BuffEffect
extends CardEffect
## Speeds up the fire rate of towers near the player's hero for a while.

@export var fire_rate: float = 1.5
@export var duration: float = 10.0
## Towers within this distance of the hero are buffed.
@export var radius: float = 96.0


func can_apply(ctx: CardContext) -> bool:
	return not ctx.lane.towers_near(ctx.hero().position, radius).is_empty()


func apply(ctx: CardContext) -> void:
	for tower in ctx.lane.towers_near(ctx.hero().position, radius):
		tower.apply_buff(fire_rate, duration)
