class_name PlaceTowerEffect
extends CardEffect
## Places a tower at the target. The target must be near the player's hero and free.

@export var tower: TowerData
## Seconds until the tower disappears; 0 keeps it for the rest of the run.
@export var lifetime: float = 0.0


func can_apply(ctx: CardContext) -> bool:
	return ctx.lane.can_place_tower(ctx.target, ctx.hero())


func apply(ctx: CardContext) -> void:
	ctx.lane.place_tower(tower, ctx.target, lifetime)
