class_name TeleportEffect
extends CardEffect
## Moves the hero towards the target, at most max_distance, and makes it briefly invulnerable.

@export var max_distance: float = 128.0
@export var invulnerable: float = 1.0


func apply(ctx: CardContext) -> void:
	var hero := ctx.hero()
	var offset := (ctx.target - hero.position).limit_length(max_distance)
	hero.position = ctx.lane.clamp_to_field(hero.position + offset)
	hero.invulnerable = invulnerable
