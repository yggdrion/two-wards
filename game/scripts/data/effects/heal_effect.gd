class_name HealEffect
extends CardEffect
## Heals the Heart Crystal, never above its max HP.

@export var amount: int = 5


func apply(ctx: CardContext) -> void:
	ctx.sim.core.heal(amount)
