class_name TowerData
extends Resource
## Stats for a tower. Tower cards (M2) reference one of these.

@export var id: StringName
@export var display_name: String
## Targeting radius in pixels.
@export var attack_range: float = 48.0
@export var damage: int = 5
## Seconds between shots.
@export var fire_interval: float = 1.0
