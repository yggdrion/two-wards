class_name Scenario
extends RefCounted
## A scripted solo run: seed + deck + timed actions, played to the end with a fixed step.
##
## Scenario tests compare the result (outcome, crystal HP, gold, state hash) with the file's
## "expect" block; the M4 network test will replay the same files on host and client.
##
## JSON format (game/tests/scenarios/*.json):
##   {
##     "seed": 7,
##     "deck": ["arrow_tower", "arrow_tower", "mend"],
##     "waves": 3,                                   # optional: only the first N waves
##     "actions": [
##       {"t": 0.0, "hero": [160, 64]},              # hero position update
##       {"t": 1.5, "play": "arrow_tower", "at": [150, 60]},
##       {"t": 9.0, "play": "mend"},
##       {"t": 12.0, "cycle": "mend"}
##     ],
##     "expect": {"result": "won", "crystal_hp": 20, "gold": 55, "hash": "0123abcd..."}
##   }
## A play or cycle names a card id; it uses the first hand slot holding that card.

const STEP := 1.0 / 60.0
const LANE_SCENE := "res://scenes/lane.tscn"
const CARD_PATH := "res://resources/cards/%s.tres"
## A run that hasn't ended by then counts as "timeout".
const MAX_SECONDS := 900.0
## Absorbs float drift in the accumulated lane time.
const EPSILON := 0.000001

var name := ""
var rng_seed := 1
var deck_ids := PackedStringArray()
## Number of waves to play; -1 plays all waves of the lane scene.
var wave_count := -1
var actions: Array[Dictionary] = []
var expect: Dictionary = {}


static func load_file(path: String) -> Scenario:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var scenario := Scenario.new()
	scenario.name = path.get_file().get_basename()
	scenario.rng_seed = int(data.get("seed", 1))
	scenario.deck_ids = PackedStringArray(data.get("deck", []))
	scenario.wave_count = int(data.get("waves", -1))
	for action: Dictionary in data.get("actions", []):
		scenario.actions.append(action)
	scenario.actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	scenario.expect = data.get("expect", {})
	return scenario


## A lane set up for this scenario, not yet in the tree and with autorun off.
func build_lane() -> Lane:
	var lane: Lane = load(LANE_SCENE).instantiate()
	lane.autorun = false
	lane.rng_seed = rng_seed
	var deck := DeckData.new()
	for card_id in deck_ids:
		deck.cards.append(load(CARD_PATH % card_id))
	lane.deck = deck
	if wave_count >= 0:
		lane.waves = lane.waves.slice(0, wave_count)
	return lane


## Plays the scenario on a lane from build_lane() that is already in the tree.
func run(lane: Lane) -> Dictionary:
	var errors := PackedStringArray()
	var next := 0
	while not lane.is_over() and lane.time < MAX_SECONDS:
		while next < actions.size() and float(actions[next]["t"]) <= lane.time + EPSILON:
			var error := _apply(lane, actions[next])
			if not error.is_empty():
				errors.append("t=%.2f: %s" % [lane.time, error])
			next += 1
		lane.tick(STEP)
	if next < actions.size():
		errors.append("%d action(s) after the run ended" % (actions.size() - next))
	var result := "timeout"
	if lane.phase == Lane.Phase.WON:
		result = "won"
	elif lane.phase == Lane.Phase.LOST:
		result = "lost"
	return {
		"result": result,
		"waves_cleared": lane.waves_cleared,
		"crystal_hp": lane.core.hp,
		"gold": lane.gold,
		"hash": lane.state_hash(),
		"errors": errors,
	}


func _apply(lane: Lane, action: Dictionary) -> String:
	if action.has("hero"):
		lane.hero.position = lane.clamp_to_field(_vec(action["hero"]))
		return ""
	if action.has("cycle"):
		return _cycle(lane, action["cycle"])
	if action.has("play"):
		return _play(lane, action["play"], _vec(action.get("at", [0, 0])))
	return "unknown action %s" % action


func _cycle(lane: Lane, card_id: String) -> String:
	var slot := lane.players[0].find_in_hand(card_id)
	if slot < 0:
		return "cannot cycle %s, hand is %s" % [card_id, _hand(lane.players[0])]
	return "" if lane.cycle_card(0, slot) else "not enough energy to cycle"


func _play(lane: Lane, card_id: String, at: Vector2) -> String:
	var player := lane.players[0]
	var slot := player.find_in_hand(card_id)
	if slot < 0:
		return "%s not in hand %s" % [card_id, _hand(player)]
	if not lane.play_card(0, slot, at):
		return "could not play %s at %s (energy %d)" % [card_id, at, player.energy.points()]
	return ""


static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _hand(player: PlayerState) -> String:
	var ids := PackedStringArray()
	for card in player.hand:
		ids.append(String(card.id) if card != null else "-")
	return "[%s]" % ", ".join(ids)
