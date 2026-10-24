class_name CardData
extends Resource
## A card: cost, presentation and a list of effects that run in order when it is played.
##
## A simple new card is one .tres file built from existing effects, plus its art.

enum Rarity { COMMON, RARE, EPIC }
enum Kind { TOWER, SPELL, HERO, BUFF }
## NONE plays at once; POINT needs a target position on the field.
enum Target { NONE, POINT }

## Run upgrades a card can take (UpgradeData).
const MAX_LEVEL := 5

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

## Upgrades taken this run; only on a player's run copy (run_copy()).
var level := 0


## A player's own copy for a run: effects and towers are copied too, so an upgrade changes
## this player's card (every copy in their deck and the towers already placed) and no other.
func run_copy() -> CardData:
	var copy: CardData = duplicate()
	var copied: Array[CardEffect] = []
	for effect in effects:
		var own: CardEffect = effect.duplicate()
		if own is PlaceTowerEffect:
			own.tower = own.tower.duplicate()
		copied.append(own)
	copy.effects = copied
	return copy


## The resources an upgrade can change: the card, its effects and the towers they place.
func parts() -> Array[Resource]:
	var found: Array[Resource] = [self]
	for effect in effects:
		found.append(effect)
		if effect is PlaceTowerEffect and effect.tower != null:
			found.append(effect.tower)
	return found


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
