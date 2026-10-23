class_name UnitData
extends Resource
## Stats for a unit that walks the lane (goblins in the PoC).

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 10
## Movement speed in pixels per second.
@export var speed: float = 60.0
## Flat reduction applied to every hit; a hit always deals at least 1.
@export var armor: int = 0
## Damage dealt to the Heart Crystal when the unit reaches it.
@export var core_damage: int = 1
## Animations from build_assets ("walk_side" is used); empty keeps the gray-box drawing.
@export var frames: SpriteFrames
