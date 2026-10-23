class_name CardContext
extends RefCounted
## Everything an effect needs to resolve: the lane, the player who played the card and the target.

var lane: Lane
var player: PlayerState
## Target position on the field; ignored by cards with Target.NONE.
var target: Vector2


func _init(on_lane: Lane, by_player: PlayerState, at: Vector2 = Vector2.ZERO) -> void:
	lane = on_lane
	player = by_player
	target = at
