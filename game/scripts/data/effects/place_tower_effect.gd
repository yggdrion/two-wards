class_name PlaceTowerEffect
extends CardEffect
## Places a tower at the target. The target must be off the path and free.

@export var tower: TowerData
## Seconds until the tower disappears; 0 keeps it for the rest of the run.
@export var lifetime: float = 0.0


func can_apply(ctx: CardContext) -> bool:
	return ctx.sim.can_place_tower(ctx.target)


func apply(ctx: CardContext) -> void:
	ctx.sim.place_tower(tower, ctx.target, lifetime)
