class_name DamageEffect
extends CardEffect
## Damages enemies at the target: the nearest one, or all within radius.

## How close to the target an enemy must be for a single-target hit.
const PICK_RADIUS := 24.0

@export var amount: int = 10
## 0 hits only the enemy nearest the target.
@export var radius: float = 0.0


func can_apply(ctx: CardContext) -> bool:
	return not ctx.sim.enemies_near(ctx.target, maxf(radius, PICK_RADIUS)).is_empty()


func apply(ctx: CardContext) -> void:
	if radius > 0.0:
		for enemy in ctx.sim.enemies_near(ctx.target, radius):
			enemy.take_damage(amount)
		return
	var enemy := ctx.sim.nearest_enemy(ctx.target, PICK_RADIUS)
	if enemy != null:
		enemy.take_damage(amount)
