extends SceneTree
## Records a scenario file by letting ScenarioBot play every player's hand, so co-op scenarios
## don't have to be written by hand. Pin the printed "expect" afterwards with the scenario test.
##
## Usage: godot --headless --path game --script res://tools/record_scenario.gd -- \
##   --in=res://tests/scenarios/<draft>.json --out=<file.json>
## The draft gives seed, wizards, decks and optional waves, tier and rewards; its actions are
## replaced.

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
	var sim := scenario.build_sim()
	var actions: Array = []
	ScenarioBot.new(sim).play(actions.append)
	data["actions"] = actions
	var result := Scenario.result_of(sim, PackedStringArray())
	result.erase("errors")
	data["expect"] = result
	var file := FileAccess.open(args["out"], FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print(JSON.stringify(result))
	quit()
