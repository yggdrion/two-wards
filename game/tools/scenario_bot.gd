class_name ScenarioBot
extends RefCounted
## A simple player for headless runs (record_scenario.gd, balance_sim.gd). Every half second it
## plays the first affordable card of each hand: towers on the free spot closest to the path (a
## 24 px grid over the field, like a player who keeps building), spells on the enemy furthest
## along the path, and it passes one card to the partner now and then. With rewards on it takes
## the first upgrade of every offer, like every scenario runner (Scenario.reward_pick).

## Grid step for build spots.
const GRID := 24
const THINK := 0.5
const PASS_EVERY := 25.0

var sim: Sim
## Build spots, closest to the path first.
var _spots: Array = []


func _init(run_sim: Sim) -> void:
	sim = run_sim
	for x in range(GRID / 2, int(Sim.FIELD.size.x), GRID):
		for y in range(GRID / 2, int(Sim.FIELD.size.y), GRID):
			_spots.append(Vector2(x, y))
	_spots.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return sim.distance_to_path(a) < sim.distance_to_path(b)
	)


## Plays the run to its end. `on_action` gets every applied action in scenario format
## ({"t": ..., "play"/"cycle"/"pass": ..., "at": ..., "player": ...}).
func play(on_action: Callable = Callable()) -> void:
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
				var action := _decide(p, sim.time >= next_pass)
				if action.is_empty():
					continue
				action["t"] = t
				if p > 0:
					action["player"] = p
				if action.has("pass"):
					next_pass += PASS_EVERY
				if NetCommand.apply(sim, Scenario.command(sim, action)).is_empty():
					if on_action.is_valid():
						on_action.call(action)
		sim.tick(Scenario.STEP)


func _decide(p: int, want_pass: bool) -> Dictionary:
	var player := sim.players[p]
	if want_pass and sim.players.size() == 2:
		for slot in PlayerState.HAND_SIZE:
			if player.can_pass(slot, sim.players[1 - p]):
				return {"pass": String(player.hand[slot].id)}
	for slot in player.hand.size():
		var card := player.hand[slot]
		if card == null:
			continue
		for at in _targets(card):
			if sim.can_play_card(p, slot, at):
				var action := {"play": String(card.id)}
				if card.target == CardData.Target.POINT:
					action["at"] = [roundi(at.x), roundi(at.y)]
				return action
	return {}


func _targets(card: CardData) -> Array:
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
