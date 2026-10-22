class_name HeroData
extends Resource
## A wizard. It never appears on the field: it gives one passive buff to the whole battlefield
## for the whole run, and shows only as a portrait (hero select, later the partner panel).

## ENEMY_SLOW: enemies move `amount` slower (0.15 = 15%). TOWER_DAMAGE: towers deal `amount`
## more damage (0.2 = +20%).
enum Buff { ENEMY_SLOW, TOWER_DAMAGE }

const DIR := "res://resources/heroes"

@export var id: StringName
@export var display_name: String
@export var buff: Buff = Buff.ENEMY_SLOW
## Strength of one stack of the buff; see Buff.
@export var amount: float = 0.15
## Rules text, rendered at runtime with the pixel font.
@export_multiline var text: String
## Placeholder until the A1 portraits land.
@export var portrait: Texture2D
## Optional material for the portrait, e.g. a palette swap.
@export var portrait_material: Material


## Every hero in DIR, ordered by id. A new wizard is one .tres there.
static func load_all(dir: String = DIR) -> Array[HeroData]:
	var heroes: Array[HeroData] = []
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() == "tres":
			var hero := load(dir.path_join(file)) as HeroData
			if hero != null:
				heroes.append(hero)
	heroes.sort_custom(func(a: HeroData, b: HeroData) -> bool: return a.id < b.id)
	return heroes


## The hero with this id, or null.
static func find(hero_id: String, dir: String = DIR) -> HeroData:
	for hero in load_all(dir):
		if String(hero.id) == hero_id:
			return hero
	return null


## Short buff line for the HUD, with `stacks` applied (2 while empowered).
func buff_label(stacks: int = 1) -> String:
	var percent := roundi(amount * stacks * 100.0)
	match buff:
		Buff.TOWER_DAMAGE:
			return "Towers +%d%% damage" % percent
		_:
			return "Enemies %d%% slower" % percent
