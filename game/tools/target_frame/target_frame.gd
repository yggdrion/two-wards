extends Node2D
## A1 target frame: the real run screen with its live HUD, the gray-box lane hidden, and the
## PixelLab anchors drawn on a Wang-tiled meadow under evening light. A mockup to approve the
## look before bulk generation; A2 replaces the gray-box drawing in the game itself.
##
## Run: godot --path game res://tools/target_frame/target_frame.tscn -- --shot=<file.png>
## With --shot it saves one 640x360 frame after SHOT_DELAY seconds and quits.

const GAME := preload("res://scenes/game.tscn")
const DIR := "res://tools/target_frame/"
const TILE := 32
const FIELD_CELLS := Vector2i(20, 9)
## The lane's path snapped to tile corners, so the Wang tiles draw it one tile wide. The real
## lane (lane.tscn) is off-grid; A2 moves it here and re-pins the scenario hashes.
const PATH: Array[Vector2] = [
	Vector2(-16, 64),
	Vector2(192, 64),
	Vector2(192, 224),
	Vector2(448, 224),
	Vector2(448, 96),
	Vector2(576, 96),
]
## A tile corner is path when it lies on the path line.
const PATH_REACH := 1.0
const DUSK := Color(0.38, 0.38, 0.58)
## Goblins are lifted back toward full brightness: units stay the highest-contrast thing on
## screen (STYLE_GUIDE section 5). Values above 1 cancel part of DUSK.
const UNIT_LIFT := Color(2.0, 2.0, 1.5)
const SHOT_DELAY := 3.0
const SHADOW := Color("181425")
## Path offsets (px along the lane) where goblins stand.
const GOBLINS: Array[float] = [70.0, 150.0, 260.0, 300.0, 520.0]
const TOWERS: Array[Vector2] = [Vector2(110, 176), Vector2(330, 170), Vector2(500, 190)]

var _art: Node2D
var _shadows: Array[Vector2] = []


func _ready() -> void:
	var game: RunScreen = GAME.instantiate()
	add_child(game)
	var lane := game.lane
	lane.visible = false  # hides the gray-box lane, enemies and towers; the sim still runs
	_art = Node2D.new()
	_art.y_sort_enabled = true
	_art.draw.connect(_draw_shadows)
	add_child(_art)
	move_child(_art, 0)
	add_child(CanvasModulate.new())
	get_child(-1).color = DUSK
	var curve := Curve2D.new()
	for point in PATH:
		curve.add_point(point)
	_build_ground(curve.get_baked_points())
	_place_goblins(curve)
	for pos in TOWERS:
		_add_sprite("arrow_tower.png", pos, Vector2(-24, -66))
		_add_light(pos + Vector2(0, -60), Color("2ce8f5"), 0.5, 0.35)
		_add_light(pos + Vector2(0, -28), Color("feae34"), 0.3, 0.3)
	var core: Vector2 = PATH[-1]
	_add_sprite("heart_crystal.png", core + Vector2(0, 20), Vector2(-32, -90))
	_add_light(core + Vector2(0, -30), Color("2ce8f5"), 0.9, 0.9)
	var shot := _arg("--shot=")
	if not shot.is_empty():
		await get_tree().create_timer(SHOT_DELAY).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _build_ground(points: PackedVector2Array) -> void:
	var ground := Node2D.new()
	ground.z_index = -1
	add_child(ground)
	for y in FIELD_CELLS.y:
		for x in FIELD_CELLS.x:
			var key := ""
			for corner in [
				Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y + 1)
			]:
				key += "1" if _near_path(corner * TILE, points) else "0"
			var tile := Sprite2D.new()
			tile.texture = load(DIR + "tiles/wang_%s.png" % key)
			tile.centered = false
			tile.position = Vector2(x, y) * TILE
			ground.add_child(tile)


func _near_path(p: Vector2, points: PackedVector2Array) -> bool:
	for i in points.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		if p.distance_to(q) <= PATH_REACH:
			return true
	return false


func _place_goblins(curve: Curve2D) -> void:
	for offset in GOBLINS:
		var pos := curve.sample_baked(offset)
		var ahead := curve.sample_baked(offset + 4.0)
		var goblin := _add_sprite("goblin_runner.png", pos, Vector2(-32, -58))
		goblin.flip_h = ahead.x < pos.x - 0.5
		goblin.modulate = UNIT_LIFT
		_shadows.append(pos)


func _add_sprite(file: String, pos: Vector2, offset: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIR + file)
	sprite.centered = false
	sprite.offset = offset
	sprite.position = pos
	_art.add_child(sprite)
	return sprite


func _add_light(pos: Vector2, color: Color, energy: float, size: float) -> void:
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = size
	light.color = color
	light.energy = energy
	light.position = pos
	add_child(light)


## Hard-edged rings so the light itself looks pixelated (PLAN: lighting).
func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	gradient.colors = PackedColorArray(
		[Color(0.8, 0.8, 0.8), Color(0.35, 0.35, 0.35), Color(0, 0, 0)]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 160
	texture.height = 160
	return texture


func _draw_shadows() -> void:
	for pos in _shadows:
		var ellipse := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			ellipse.append(pos + Vector2(cos(a) * 12.0, sin(a) * 4.0))
		_art.draw_colored_polygon(ellipse, SHADOW)


func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""
