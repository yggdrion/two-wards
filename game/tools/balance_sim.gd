extends SceneTree
## Headless balance sweep: ScenarioBot plays runs across decks, wizards, tiers and seeds with
## upgrades on, and a booster sim measures the meta loop. tools/balance_sim.py runs the parts in
## parallel and prints the tables; run this script directly only to debug one part.
##
## Usage: godot --headless --path game --script res://tools/balance_sim.gd -- \
##   --part=solo:frost|solo:ember|coop|meta [--quick]
## Prints "RUN mode,deck,wizards,tier,seed,result,waves,crystal,gold" per run and "META ..."
## lines for the booster sim.

## Solo decks, 8 card ids each. Edit freely: the sweep only needs legal-looking decks.
const DECKS := {
	"starter": Profile.STARTER_DECK,
	"towers":
	[
		"arrow_tower",
		"arrow_tower",
		"frost_totem",
		"frost_totem",
		"ballista",
		"ballista",
		"storm_spire",
		"storm_spire",
	],
	"balanced":
	[
		"arrow_tower",
		"arrow_tower",
		"frost_totem",
		"storm_spire",
		"ballista",
		"war_drums",
		"mend",
		"arcane_bolt",
	],
	"cheap":
	[
		"arrow_tower",
		"arrow_tower",
		"frost_totem",
		"frost_totem",
		"arcane_bolt",
		"arcane_bolt",
		"arcane_focus",
		"arcane_focus",
	],
	"spells":
	[
		"arrow_tower",
		"frost_totem",
		"arcane_bolt",
		"arcane_bolt",
		"mend",
		"decoy_effigy",
		"decoy_effigy",
		"empower",
	],
	"epics":
	[
		"arrow_tower",
		"arrow_tower",
		"storm_spire",
		"storm_spire",
		"mirror_image",
		"mirror_image",
		"time_warp",
		"war_drums",
	],
}
## Co-op pairs of DECKS keys; the host plays Ember, the client Frost.
const PAIRS := [
	["starter", "starter"],
	["balanced", "spells"],
	["towers", "cheap"],
	["epics", "balanced"],
]
const QUICK_DECKS := ["starter", "balanced", "towers"]
const QUICK_PAIRS := [["starter", "starter"], ["balanced", "spells"]]
const SEEDS := 4
const QUICK_SEEDS := 2
const META_PROFILES := 500

var _done := false


func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		var args := {}
		for arg in OS.get_cmdline_user_args():
			var parts := arg.trim_prefix("--").split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() > 1 else ""
		var part: String = args.get("part", "solo:frost")
		var quick := args.has("quick")
		if part == "meta":
			_meta()
		elif part == "coop":
			_coop(quick)
		else:
			_solo(part.trim_prefix("solo:"), quick)
		quit()
	return false


func _solo(wizard: String, quick: bool) -> void:
	var decks: Array = QUICK_DECKS if quick else DECKS.keys()
	for tier in Sim.TIER_COUNT:
		for deck: String in decks:
			for s in QUICK_SEEDS if quick else SEEDS:
				_run("solo", deck, [wizard], [DECKS[deck]], tier, 100 + s)


func _coop(quick: bool) -> void:
	for tier in Sim.TIER_COUNT:
		for pair: Array in QUICK_PAIRS if quick else PAIRS:
			for s in QUICK_SEEDS if quick else SEEDS:
				_run(
					"coop",
					"%s+%s" % pair,
					["ember", "frost"],
					[DECKS[pair[0]], DECKS[pair[1]]],
					tier,
					200 + s
				)


func _run(mode: String, deck: String, wizards: Array, decks: Array, tier: int, seed: int) -> void:
	var scenario := Scenario.new()
	scenario.rng_seed = seed
	scenario.wizards = PackedStringArray(wizards)
	for ids: Array in decks:
		scenario.decks.append(PackedStringArray(ids))
	scenario.rewards = true
	scenario.tier = tier
	var sim := scenario.build_sim()
	ScenarioBot.new(sim).play()
	var r := Scenario.result_of(sim, PackedStringArray())
	print(
		(
			"RUN %s,%s,%s,%d,%d,%s,%d,%d,%d"
			% [
				mode,
				deck,
				"+".join(wizards),
				tier,
				seed,
				r["result"],
				r["waves_cleared"],
				r["crystal_hp"],
				r["gold"],
			]
		)
	)


## Net gold (boosters bought minus dupe refunds) a new profile needs until it owns the deck cap
## of every card, and until its first epic.
func _meta() -> void:
	var catalog := CardCatalog.load_dir()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var full: Array[int] = []
	var first_epic: Array[int] = []
	for i in META_PROFILES:
		var profile := Profile.create()
		var start := 1000000
		profile.gold = start
		var epic_at := -1
		while not _complete(profile, catalog):
			Booster.open(profile, catalog, rng)
			if epic_at < 0:
				for card in catalog.of_rarity(CardData.Rarity.EPIC):
					if profile.owned(String(card.id)) > 0:
						epic_at = start - profile.gold
		full.append(start - profile.gold)
		first_epic.append(epic_at)
	full.sort()
	first_epic.sort()
	var n := META_PROFILES
	print(
		(
			"META gold_to_full_collection p10=%d median=%d p90=%d"
			% [full[n / 10], full[n / 2], full[n * 9 / 10]]
		)
	)
	print("META gold_to_first_epic median=%d p90=%d" % [first_epic[n / 2], first_epic[n * 9 / 10]])


func _complete(profile: Profile, catalog: CardCatalog) -> bool:
	for card in catalog.all():
		if profile.owned(String(card.id)) < DeckRules.MAX_COPIES:
			return false
	return true
