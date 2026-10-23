class_name CoopSetup
## The start of a co-op run as plain data, so it can cross the network:
##   {"seed": 42, "names": ["Rapha", "Kim"], "heroes": ["frost", "ember"],
##    "decks": [[8 card ids], [8 card ids]]}
## Everything is in player order, host first. Each player's part comes from their profile as
## {"name": ..., "hero": ..., "deck": [...]} (the client sends its part in the hello).


static func player_info(name: String, hero_id: String, deck: Array) -> Dictionary:
	return {"name": name, "hero": hero_id, "deck": deck.duplicate()}


## What this player brings into a co-op run: name, wizard and active deck.
static func from_profile(profile: Profile) -> Dictionary:
	return player_info(
		profile.display_name(), profile.hero, profile.deck_cards(profile.active_deck)
	)


## The setup for a run of the players in `infos` (host first), each from player_info().
static func make(rng_seed: int, infos: Array[Dictionary]) -> Dictionary:
	var setup := {"seed": rng_seed, "names": [], "heroes": [], "decks": []}
	for info in infos:
		setup["names"].append(str(info.get("name", "Wizard")))
		setup["heroes"].append(str(info.get("hero", "")))
		var deck: Array = []
		for card_id: Variant in info.get("deck", []):
			deck.append(str(card_id))
		setup["decks"].append(deck)
	return setup


## Sets up a lane (before it enters the tree) for the run: seed, wizards and one deck each.
## `find_card` maps a card id to its CardData; unknown ids are left out.
static func configure(lane: Lane, setup: Dictionary, find_card: Callable) -> void:
	lane.autorun = false
	lane.rng_seed = int(setup["seed"])
	var heroes: Array[HeroData] = []
	for hero_id: Variant in setup["heroes"]:
		heroes.append(HeroData.find(str(hero_id)))
	lane.heroes = heroes
	var decks: Array[DeckData] = []
	for ids: Array in setup["decks"]:
		var deck := DeckData.new()
		for card_id: Variant in ids:
			var card: CardData = find_card.call(str(card_id))
			if card != null:
				deck.cards.append(card)
		decks.append(deck)
	lane.decks = decks
