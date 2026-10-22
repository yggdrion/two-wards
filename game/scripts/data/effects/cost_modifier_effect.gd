class_name CostModifierEffect
extends CardEffect
## Makes the player's next card cheaper. A large discount makes it free.

@export var discount: int = 99


func apply(ctx: CardContext) -> void:
	ctx.player.next_card_discount = discount
