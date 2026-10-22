class_name CardData
extends Resource
## A card: cost, presentation and a list of effects that run in order when it is played.
##
## A simple new card is one .tres file built from existing effects, plus its art.

enum Rarity { COMMON, RARE, EPIC }
enum Kind { TOWER, SPELL, HERO, BUFF }
## NONE plays at once; POINT needs a target position on the field.
enum Target { NONE, POINT }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.SPELL
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 10) var cost: int = 1
@export var target: Target = Target.POINT
## Rules text, rendered at runtime with the pixel font. Never baked into art.
@export_multiline var text: String
## 64x48 card art.
@export var art: Texture2D
@export var effects: Array[CardEffect] = []


func can_play(ctx: CardContext) -> bool:
	for effect in effects:
		if not effect.can_apply(ctx):
			return false
	return true


func play(ctx: CardContext) -> void:
	for effect in effects:
		effect.apply(ctx)


## True if any effect is a ScriptedEffect (the plan allows at most 3 of 12 cards).
func uses_script() -> bool:
	for effect in effects:
		if effect is ScriptedEffect:
			return true
	return false
