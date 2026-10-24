class_name UpgradeData
extends Resource
## A run upgrade for one card in a player's deck, offered after a cleared wave. A new upgrade
## is one .tres in DIR.
##
## An upgrade changes numbers on the card's parts: the CardData itself (cost), its effects
## (amount, radius, duration, ...) and the TowerData its PlaceTowerEffect places (damage,
## fire_interval, attack_range, shots, ...). Every part that has a property in mults or adds
## gets it changed; the others are left alone.

const DIR := "res://resources/upgrades"

@export var id: StringName
@export var display_name: String
@export var rarity: CardData.Rarity = CardData.Rarity.COMMON
## Rules text, rendered at runtime with the pixel font.
@export_multiline var text: String
## Offered only for cards with one part where every property here is above its value,
## e.g. {"chain_count": 1} for chain towers. Empty fits every card.
@export var requires: Dictionary = {}
## Never offered for cards with a part where one of these properties is true, e.g. "area".
@export var excludes: Array[StringName] = []
## Property name -> factor.
@export var mults: Dictionary = {}
## Property name -> amount added after the factors.
@export var adds: Dictionary = {}


## Every upgrade in DIR, ordered by id.
static func load_all(dir: String = DIR) -> Array[UpgradeData]:
	var upgrades: Array[UpgradeData] = []
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() == "tres":
			var upgrade := load(dir.path_join(file)) as UpgradeData
			if upgrade != null:
				upgrades.append(upgrade)
	upgrades.sort_custom(
		func(a: UpgradeData, b: UpgradeData) -> bool: return String(a.id) < String(b.id)
	)
	return upgrades


func fits(card: CardData) -> bool:
	if card.level >= CardData.MAX_LEVEL:
		return false
	var parts := card.parts()
	for part in parts:
		for prop in excludes:
			if prop in part and part.get(prop):
				return false
	if requires.is_empty():
		return true
	return parts.any(
		func(part: Resource) -> bool:
			for prop: String in requires:
				if not prop in part or part.get(prop) <= requires[prop]:
					return false
			return true
	)


## Changes the card's parts in place; ints are rounded and nothing drops below 0.
func apply(card: CardData) -> void:
	for part in card.parts():
		for prop: String in mults:
			if prop in part:
				_set_number(part, prop, part.get(prop) * mults[prop])
		for prop: String in adds:
			if prop in part:
				_set_number(part, prop, part.get(prop) + adds[prop])
	card.level += 1


static func _set_number(part: Resource, prop: String, value: float) -> void:
	value = maxf(value, 0.0)
	part.set(prop, roundi(value) if typeof(part.get(prop)) == TYPE_INT else value)
