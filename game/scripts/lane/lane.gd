class_name Lane
extends Node2D
## Draws the run's Sim: ground tiles from the path, one view node per enemy and tower, the
## crystal and the lures. Only reads the sim; configure `sim` before the lane enters the tree.

const TILE := 32

static var _light_texture: GradientTexture2D

## When false, nothing advances on its own; call sim.tick() manually.
@export var autorun := true

var sim := Sim.new()
## Sim entity -> its view node.
var _views: Dictionary[Object, Node2D] = {}

@onready var core: HeartCrystal = $HeartCrystal
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var ground: TileMapLayer = $Ground


func _ready() -> void:
	sim.enemy_spawned.connect(_on_enemy_spawned)
	sim.enemy_removed.connect(_free_view)
	sim.tower_placed.connect(_on_tower_placed)
	sim.tower_removed.connect(_free_view)
	sim.tower_fired.connect(_on_tower_fired)
	sim.run_lost.connect(set_physics_process.bind(false))
	sim.start()
	core.model = sim.core
	core.position = sim.core.position
	_build_ground()
	set_physics_process(autorun)


func _physics_process(delta: float) -> void:
	sim.tick(delta)


func _process(_delta: float) -> void:
	queue_redraw()


## The view drawing a sim enemy or tower; null once it is gone.
func view_of(entity: Object) -> Node2D:
	return _views.get(entity)


## A point light with hard-edged rings, so the light itself looks pixelated (PLAN: lighting).
static func make_light(color: Color, energy: float, size: float) -> PointLight2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
		gradient.colors = PackedColorArray(
			[Color(0.8, 0.8, 0.8), Color(0.35, 0.35, 0.35), Color(0, 0, 0)]
		)
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 160
		_light_texture.height = 160
	var light := PointLight2D.new()
	light.texture = _light_texture
	light.texture_scale = size
	light.color = color
	light.energy = energy
	return light


## Wang tiles by corner: a tile corner on the path is dirt. The source id is the corner bits
## NW NE SW SE read as a binary number (0 = all grass, 15 = all dirt).
func _build_ground() -> void:
	var cells := Vector2i(Sim.FIELD.size) / TILE
	for y in cells.y:
		for x in cells.x:
			var id := 0
			for corner: Vector2i in [
				Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)
			]:
				id = id * 2 + int(sim.distance_to_path(Vector2(corner * TILE)) < 1.0)
			ground.set_cell(Vector2i(x, y), id, Vector2i.ZERO)


func _on_enemy_spawned(enemy: SimEnemy) -> void:
	var view := Enemy.new()
	view.setup(enemy)
	_views[enemy] = view
	enemies_root.add_child(view)


func _on_tower_placed(tower: SimTower) -> void:
	var view := Tower.new()
	view.setup(tower)
	_views[tower] = view
	towers_root.add_child(view)


func _on_tower_fired(tower: SimTower, hits: Array[SimEnemy]) -> void:
	_views[tower].flash(hits)


func _free_view(entity: Object) -> void:
	var view: Node2D = _views.get(entity)
	if view != null:
		_views.erase(entity)
		view.queue_free()


func _draw() -> void:
	for lure in sim.lures:
		draw_arc(lure["position"], lure["radius"], 0.0, TAU, 32, Palette.LURE, 2.0)
		draw_rect(Rect2(lure["position"] - Vector2(4, 6), Vector2(8, 12)), Palette.LURE)
