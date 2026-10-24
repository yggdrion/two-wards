class_name CardContext
extends RefCounted
## Everything an effect needs to resolve: the sim, the player who played the card and the target.

var sim: Sim
var player: PlayerState
## Target position on the field; ignored by cards with Target.NONE.
var target: Vector2


func _init(on_sim: Sim, by_player: PlayerState, at: Vector2 = Vector2.ZERO) -> void:
	sim = on_sim
	player = by_player
	target = at
