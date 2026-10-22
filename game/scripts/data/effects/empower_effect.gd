class_name EmpowerEffect
extends CardEffect
## The playing player's wizard buff counts double for a while (Empower).

@export var duration: float = 8.0


func apply(ctx: CardContext) -> void:
	ctx.player.empower(duration)
