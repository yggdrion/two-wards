extends CardScript
## Time Warp: restores the crystal HP lost in the last `window` seconds.


func can_apply(ctx: CardContext, params: Dictionary) -> bool:
	return ctx.sim.core_damage_since(params.get("window", 10.0)) > 0


func apply(ctx: CardContext, params: Dictionary) -> void:
	ctx.sim.core.heal(ctx.sim.core_damage_since(params.get("window", 10.0)))
