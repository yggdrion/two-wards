class_name CardScript
extends RefCounted
## Base for ScriptedEffect handlers. Override both methods; read numbers from params.


func can_apply(_ctx: CardContext, _params: Dictionary) -> bool:
	return true


func apply(_ctx: CardContext, _params: Dictionary) -> void:
	pass
