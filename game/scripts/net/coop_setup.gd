class_name CoopSetup
## The start of a co-op run as plain data, so it can cross the network:
##   {"seed": 42, "tier": 1, "names": ["Rapha", "Kim"], "heroes": ["frost", "ember"],
##    "decks": [[8 card ids], [8 card ids]]}
## Everything is in player order, host first; the run takes the host's difficulty tier. Each
## player's part comes from their profile as {"name": ..., "hero": ..., "deck": [...],
## "tier": ...} (the client sends its part in the hello).


static func player_info(name: String, hero_id: String, deck: Array, tier: int = 0) -> Dictionary:
	return {"name": name, "hero": hero_id, "deck": deck.duplicate(), "tier": tier}


## What this player brings into a co-op run: name, wizard, active deck and difficulty tier.
static func from_profile(profile: Profile) -> Dictionary:
	return player_info(
		profile.display_name(), profile.hero, profile.deck_cards(profile.active_deck), profile.tier
	)


## The setup for a run of the players in `infos` (host first), each from player_info().
static func make(rng_seed: int, infos: Array[Dictionary]) -> Dictionary:
	var tier := int(infos[0].get("tier", 0)) if not infos.is_empty() else 0
	var setup := {"seed": rng_seed, "tier": tier, "names": [], "heroes": [], "decks": []}
	for info in infos:
		setup["names"].append(str(info.get("name", "Wizard")))
		setup["heroes"].append(str(info.get("hero", "")))
		var deck: Array = []
		for card_id: Variant in info.get("deck", []):
			deck.append(str(card_id))
		setup["decks"].append(deck)
	return setup


## Sets up a sim (before start()) for the run: seed, tier, wizards and one deck each.
## `find_card` maps a card id to its CardData; unknown ids are left out.
static func configure(sim: Sim, setup: Dictionary, find_card: Callable) -> void:
	sim.rng_seed = int(setup["seed"])
	sim.tier = clampi(int(setup.get("tier", 0)), 0, Sim.TIER_COUNT - 1)
	var heroes: Array[HeroData] = []
	for hero_id: Variant in setup["heroes"]:
		heroes.append(HeroData.find(str(hero_id)))
	sim.heroes = heroes
	var decks: Array[DeckData] = []
	for ids: Array in setup["decks"]:
		var deck := DeckData.new()
		for card_id: Variant in ids:
			var card: CardData = find_card.call(str(card_id))
			if card != null:
				deck.cards.append(card)
		decks.append(deck)
	sim.decks = decks
