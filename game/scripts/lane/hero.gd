class_name Hero
extends Node2D
## The player's wizard. Moves only through step(); input sets move_dir.
##
## In co-op each client owns its hero's position and the host checks it (M4).

const SPEED := 120.0
const FRAMES := preload("res://resources/generated/unit_hero_frames.tres")

## Desired direction; normalized when used.
var move_dir := Vector2.ZERO
## Seconds of invulnerability left (Blink). Nothing damages heroes yet.
var invulnerable := 0.0
## Area the hero may walk in, in lane coordinates.
var bounds := Rect2(0, 0, 640, 360)
var _facing := "down"
var _flip := false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.offset = Vector2(0, -20)
	add_child(_sprite)
	_update_animation()


func step(delta: float) -> void:
	invulnerable = maxf(invulnerable - delta, 0.0)
	if move_dir != Vector2.ZERO:
		var dir := move_dir.normalized()
		position = (position + dir * SPEED * delta).clamp(bounds.position, bounds.end)
		if absf(dir.x) > absf(dir.y):
			_facing = "side"
			_flip = dir.x < 0.0
		else:
			_facing = "down" if dir.y > 0.0 else "up"
	_update_animation()


func _update_animation() -> void:
	if _sprite == null:
		return
	var anim := "%s_%s" % ["walk" if move_dir != Vector2.ZERO else "idle", _facing]
	_sprite.flip_h = _flip and _facing == "side"
	_sprite.modulate.a = 0.5 if invulnerable > 0.0 else 1.0
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
