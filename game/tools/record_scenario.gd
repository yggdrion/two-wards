extends SceneTree
## Records a scenario file by letting a simple bot play every player's hand, so co-op scenarios
## don't have to be written by hand. The bot plays the first affordable card every half second:
## towers on the free spot closest to the path (a 24 px grid over the field, like a player who
## keeps building), spells on the enemy furthest along the path, and it passes one card to the
## partner now and then. With "rewards" on it takes the first upgrade of
## every offer, like every scenario runner (Scenario.reward_pick). Pin the printed "expect"
## afterwards with the scenario test.
##
## Usage: godot --headless --path game --script res://tools/record_scenario.gd -- \
##   --in=res://tests/scenarios/<draft>.json --out=<file.json>
## The draft gives seed, wizards, decks and optional waves and rewards; its actions are replaced.

## Grid step for build spots.
const GRID := 24
const THINK := 0.5
const PASS_EVERY := 25.0

var _done := false
## Build spots, closest to the path first; filled once the sim exists.
var _spots: Array = []


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
	var sim := scenario.build_sim()
	for x in range(GRID / 2, int(Sim.FIELD.size.x), GRID):
		for y in range(GRID / 2, int(Sim.FIELD.size.y), GRID):
			_spots.append(Vector2(x, y))
	_spots.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return sim.distance_to_path(a) < sim.distance_to_path(b)
	)
	var actions: Array = []
	var next_think := 0.0
	var next_pass := PASS_EVERY
	var answered := {}
	while not sim.is_over() and sim.time < Scenario.MAX_SECONDS:
		for p in sim.players.size():
			var pick := Scenario.reward_pick(sim, p, answered)
			if not pick.is_empty():
				NetCommand.apply(sim, pick)
		if sim.time + Scenario.EPSILON >= next_think:
			next_think += THINK
			var t := snappedf(sim.time, 0.001)
			for p in sim.players.size():
				var action := _decide(sim, p, sim.time >= next_pass)
				if action.is_empty():
					continue
				action["t"] = t
				if p > 0:
					action["player"] = p
				if action.has("pass"):
					next_pass += PASS_EVERY
				var cmd := Scenario.command(sim, action)
				if NetCommand.apply(sim, cmd).is_empty():
					actions.append(action)
		sim.tick(Scenario.STEP)
	data["actions"] = actions
	var result := Scenario.result_of(sim, PackedStringArray())
	result.erase("errors")
	data["expect"] = result
	var file := FileAccess.open(args["out"], FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print(JSON.stringify(result))
	quit()


func _decide(sim: Sim, p: int, want_pass: bool) -> Dictionary:
	var player := sim.players[p]
	if want_pass and sim.players.size() == 2:
		for slot in PlayerState.HAND_SIZE:
			if player.can_pass(slot, sim.players[1 - p]):
				return {"pass": String(player.hand[slot].id)}
	for slot in player.hand.size():
		var card := player.hand[slot]
		if card == null:
			continue
		for at in _targets(sim, card):
			if sim.can_play_card(p, slot, at):
				var action := {"play": String(card.id)}
				if card.target == CardData.Target.POINT:
					action["at"] = [roundi(at.x), roundi(at.y)]
				return action
	return {}


func _targets(sim: Sim, card: CardData) -> Array:
	if card.target == CardData.Target.NONE:
		return [Vector2.ZERO]
	var targets: Array = []
	var lead: SimEnemy = null
	for enemy in sim.enemies:
		if lead == null or enemy.progress > lead.progress:
			lead = enemy
	if lead != null:
		targets.append(lead.position.round())
	targets.append(sim.core.position + Vector2(-24, 24))
	targets.append(Vector2(320, 128))
	targets.append_array(_spots)
	return targets
