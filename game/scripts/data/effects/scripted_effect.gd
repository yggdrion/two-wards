class_name ScriptedEffect
extends CardEffect
## Escape hatch for cards no generic effect covers. Runs a CardScript; numbers stay in params.

## A script extending CardScript.
@export var handler: Script
@export var params: Dictionary = {}


func can_apply(ctx: CardContext) -> bool:
	return _script().can_apply(ctx, params)


func apply(ctx: CardContext) -> void:
	_script().apply(ctx, params)


func _script() -> CardScript:
	return handler.new()
