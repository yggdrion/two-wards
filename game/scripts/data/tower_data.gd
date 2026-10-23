class_name TowerData
extends Resource
## Stats for a tower. Tower cards reference one of these through a PlaceTowerEffect.

@export var id: StringName
@export var display_name: String
## Targeting radius in pixels.
@export var attack_range: float = 96.0
## Damage per hit. 0 means the tower only applies its slow.
@export var damage: int = 5
## Seconds between shots.
@export var fire_interval: float = 1.0
## 48x72 sprite, base at the tower's position; empty keeps the gray-box drawing.
@export var sprite: Texture2D

@export_group("Hit pattern")
## Hit every enemy in range instead of one target.
@export var area := false
## Hit every enemy on the line from the tower through its target, up to attack_range.
@export var pierce := false
## Total enemies hit by one shot; each jump goes to the nearest enemy within chain_range.
@export var chain_count: int = 1
@export var chain_range: float = 64.0

@export_group("Slow")
## Speed multiplier applied to hit enemies; 1.0 means no slow.
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0
