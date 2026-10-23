extends SceneTree
## Records a scenario file by letting a simple bot play every player's hand, so co-op scenarios
## don't have to be written by hand. The bot plays the first affordable card every half second:
## towers on the next free spot of SPOTS, spells on the enemy furthest along the path, and it
## passes one card to the partner now and then. Pin the printed "expect" afterwards with the
## scenario test.
##
## Usage: godot --headless --path game --script res://tools/record_scenario.gd -- \
##   --in=res://tests/scenarios/<draft>.json --out=<file.json>
## The draft gives seed, wizards, decks and optional waves; its actions are replaced.

const SPOTS := [
	Vector2(300, 120),
	Vector2(344, 120),
	Vector2(280, 156),
	Vector2(360, 156),
	Vector2(320, 90),
	Vector2(260, 110),
	Vector2(380, 110),
	Vector2(320, 164),
	Vector2(160, 110),
	Vector2(240, 30),
	Vector2(480, 180),
	Vector2(500, 60),
]
const THINK := 0.5
const PASS_EVERY := 25.0

var _done := false


## Runs on the first frame: nodes added before that don't get _ready yet.
func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_record()
	return false


func _record() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args["in"]))
	var scenario := Scenario.load_file(args["in"])
	scenario.actions.clear()
	var lane := scenario.build_lane()
	root.add_child(lane)
	var actions: Array = []
	var next_think := 0.0
	var next_pass := PASS_EVERY
	while not lane.is_over() and lane.time < Scenario.MAX_SECONDS:
		if lane.time + Scenario.EPSILON >= next_think:
			next_think += THINK
			var t := snappedf(lane.time, 0.001)
			for p in lane.players.size():
				var action := _decide(lane, p, lane.time >= next_pass)
				if action.is_empty():
					continue
				action["t"] = t
				if p > 0:
					action["player"] = p
				if action.has("pass"):
					next_pass += PASS_EVERY
				var cmd := Scenario.command(lane, action)
				if NetCommand.apply(lane, cmd).is_empty():
					actions.append(action)
		lane.tick(Scenario.STEP)
	data["actions"] = actions
	var result := Scenario.result_of(lane, PackedStringArray())
	result.erase("errors")
	data["expect"] = result
	var file := FileAccess.open(args["out"], FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print(JSON.stringify(result))
	quit()


func _decide(lane: Lane, p: int, want_pass: bool) -> Dictionary:
	var player := lane.players[p]
	if want_pass and lane.players.size() == 2:
		for slot in PlayerState.HAND_SIZE:
			if player.can_pass(slot, lane.players[1 - p]):
				return {"pass": String(player.hand[slot].id)}
	for slot in player.hand.size():
		var card := player.hand[slot]
		if card == null:
			continue
		for at in _targets(lane, card):
			if lane.can_play_card(p, slot, at):
				var action := {"play": String(card.id)}
				if card.target == CardData.Target.POINT:
					action["at"] = [roundi(at.x), roundi(at.y)]
				return action
	return {}


func _targets(lane: Lane, card: CardData) -> Array:
	if card.target == CardData.Target.NONE:
		return [Vector2.ZERO]
	var targets: Array = []
	var lead: Enemy = null
	for enemy in lane.enemies:
		if lead == null or enemy.progress > lead.progress:
			lead = enemy
	if lead != null:
		targets.append(lead.position.round())
	targets.append(lane.core.position + Vector2(-24, 24))
	targets.append(Vector2(320, 128))
	targets.append_array(SPOTS)
	return targets
