class_name CardEffect
extends Resource
## One step of a card's behaviour. A card can be played only if every effect can apply.


func can_apply(_ctx: CardContext) -> bool:
	return true


func apply(_ctx: CardContext) -> void:
	pass
