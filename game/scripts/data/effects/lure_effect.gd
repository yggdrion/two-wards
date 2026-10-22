class_name LureEffect
extends CardEffect
## Puts down a lure: enemies inside its radius stop and wait until it expires.

@export var radius: float = 24.0
@export var duration: float = 5.0


func apply(ctx: CardContext) -> void:
	ctx.lane.add_lure(ctx.target, radius, duration)
