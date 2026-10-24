extends CardScript
## Mirror Image: places a copy of the tower nearest the target, for `duration` seconds.


func can_apply(ctx: CardContext, _params: Dictionary) -> bool:
	return _source(ctx) != null and ctx.sim.can_place_tower(ctx.target)


func apply(ctx: CardContext, params: Dictionary) -> void:
	var source := _source(ctx)
	var copy := ctx.sim.place_tower(source.data, ctx.target, params.get("duration", 30.0))
	copy.is_copy = true


func _source(ctx: CardContext) -> SimTower:
	var best: SimTower = null
	for tower in ctx.sim.towers:
		if tower.is_copy:
			continue
		if (
			best == null
			or tower.position.distance_to(ctx.target) < best.position.distance_to(ctx.target)
		):
			best = tower
	return best
