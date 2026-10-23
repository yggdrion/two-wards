class_name Scenario
extends RefCounted
## A scripted run: seed + deck(s) + timed actions, played to the end with a fixed step.
##
## Scenario tests compare the result (outcome, crystal HP, gold, state hash) with the file's
## "expect" block; the network test (tools/net_test.gd) replays the same files on a host and a
## client.
##
## JSON format (game/tests/scenarios/*.json):
##   {
##     "seed": 7,
##     "wizard": "ember",                            # optional: hero id, default frost
##     "deck": ["arrow_tower", "arrow_tower", "mend"],
##     "waves": 3,                                   # optional: only the first N waves
##     "actions": [
##       {"t": 1.5, "play": "arrow_tower", "at": [150, 60]},
##       {"t": 9.0, "play": "mend"},
##       {"t": 12.0, "cycle": "mend"}
##     ],
##     "expect": {"result": "won", "crystal_hp": 20, "gold": 55, "hash": "0123abcd..."}
##   }
## A co-op scenario gives "wizards" and "decks" (one per player, host first) instead of
## "wizard" and "deck", and its actions name a "player" (default 0); "pass" gives a card to the
## partner. A play, cycle or pass names a card id; it uses the first hand slot holding that card.
## With "rewards": true every card can be offered after a wave, and every runner picks the first
## card of each player's offer as soon as it opens (reward_pick), so picks need no timed actions.

const STEP := 1.0 / 60.0
const LANE_SCENE := "res://scenes/lane.tscn"
const CARD_PATH := "res://resources/cards/%s.tres"
const HERO_PATH := "res://resources/heroes/%s.tres"
## A run that hasn't ended by then counts as "timeout".
const MAX_SECONDS := 900.0
## Absorbs float drift in the accumulated lane time.
const EPSILON := 0.000001

var name := ""
var rng_seed := 1
## One wizard id per player.
var wizards := PackedStringArray(["frost"])
## One list of card ids per player.
var decks: Array[PackedStringArray] = []
## Number of waves to play; -1 plays all waves of the lane scene.
var wave_count := -1
var actions: Array[Dictionary] = []
var rewards := false
var expect: Dictionary = {}


static func load_file(path: String) -> Scenario:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var scenario := Scenario.new()
	scenario.name = path.get_file().get_basename()
	scenario.rng_seed = int(data.get("seed", 1))
	if data.has("wizards"):
		scenario.wizards = PackedStringArray(data["wizards"])
	else:
		scenario.wizards = PackedStringArray([str(data.get("wizard", "frost"))])
	for ids: Array in data.get("decks", [data.get("deck", [])]):
		scenario.decks.append(PackedStringArray(ids))
	scenario.wave_count = int(data.get("waves", -1))
	scenario.rewards = bool(data.get("rewards", false))
	var order := 0
	for action: Dictionary in data.get("actions", []):
		var copy := action.duplicate()
		copy["_order"] = order
		order += 1
		scenario.actions.append(copy)
	# Stable by time: actions at the same time keep their file order (sort_custom isn't stable).
	scenario.actions.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["t"] < b["t"] or (a["t"] == b["t"] and a["_order"] < b["_order"])
	)
	scenario.expect = data.get("expect", {})
	return scenario


## A lane set up for this scenario (or for `run_setup`, a CoopSetup such as the network test
## gets from its host), not yet in the tree and with autorun off.
func build_lane(run_setup: Dictionary = {}) -> Lane:
	var lane: Lane = load(LANE_SCENE).instantiate()
	CoopSetup.configure(lane, run_setup if not run_setup.is_empty() else setup(), find_card)
	if wave_count >= 0:
		lane.waves = lane.waves.slice(0, wave_count)
	if rewards:
		lane.reward_pool = CardCatalog.load_dir().all()
	return lane


## The scenario as a co-op run setup (CoopSetup format), one entry per player.
func setup() -> Dictionary:
	var infos: Array[Dictionary] = []
	for i in wizards.size():
		var deck: PackedStringArray = decks[i] if i < decks.size() else PackedStringArray()
		infos.append(CoopSetup.player_info("Player %d" % (i + 1), wizards[i], Array(deck)))
	return CoopSetup.make(rng_seed, infos)


func player_count() -> int:
	return wizards.size()


static func find_card(card_id: String) -> CardData:
	var path := CARD_PATH % card_id
	return load(path) if ResourceLoader.exists(path) else null


## Plays the scenario on a lane from build_lane() that is already in the tree.
func run(lane: Lane) -> Dictionary:
	var errors := PackedStringArray()
	var next := 0
	var answered := {}
	while not lane.is_over() and lane.time < MAX_SECONDS:
		for p in lane.players.size():
			var pick := reward_pick(lane, p, answered)
			if not pick.is_empty():
				NetCommand.apply(lane, pick)
		while next < actions.size() and is_due(actions[next], lane.time):
			var cmd := command(lane, actions[next])
			var error: String = cmd.get("error", "")
			if error.is_empty():
				error = NetCommand.apply(lane, cmd)
			if not error.is_empty():
				errors.append("t=%.2f: %s" % [lane.time, error])
			next += 1
		lane.tick(STEP)
	if next < actions.size():
		errors.append("%d action(s) after the run ended" % (actions.size() - next))
	return result_of(lane, errors)


static func result_of(lane: Lane, errors: PackedStringArray) -> Dictionary:
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


## The pick of the first offered card if `player` has an open offer that wasn't answered yet;
## `answered` keeps the wave of each player's last pick. Empty otherwise.
static func reward_pick(lane: Lane, player: int, answered: Dictionary) -> Dictionary:
	var offer: Array = lane.rewards.offers[player]
	if offer.is_empty() or answered.get(player, -1) == lane.wave_index:
		return {}
	answered[player] = lane.wave_index
	return NetCommand.reward(player, String(offer[0].id))


static func is_due(action: Dictionary, time: float) -> bool:
	return float(action["t"]) <= time + EPSILON


static func player_of(action: Dictionary) -> int:
	return int(action.get("player", 0))


## The NetCommand for an action on the lane as it is now, or {"error": why} if the card isn't
## in the player's hand.
static func command(lane: Lane, action: Dictionary) -> Dictionary:
	var player := player_of(action)
	var kind := ""
	for key in [NetCommand.PLAY, NetCommand.CYCLE, NetCommand.PASS]:
		if action.has(key):
			kind = key
	if kind.is_empty():
		return {"error": "unknown action %s" % action}
	var card_id := str(action[kind])
	var cmd := NetCommand.for_card(lane, player, kind, card_id, _vec(action.get("at", [0, 0])))
	if cmd.is_empty():
		var hand := _hand(lane.players[player]) if player < lane.players.size() else "-"
		return {"error": "%s not in hand %s of player %d" % [card_id, hand, player]}
	return cmd


static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _hand(player: PlayerState) -> String:
	var ids := PackedStringArray()
	for card in player.hand:
		ids.append(String(card.id) if card != null else "-")
	return "[%s]" % ", ".join(ids)
