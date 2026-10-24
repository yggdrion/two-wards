class_name Profile
extends RefCounted
## One player's persistent meta state: gold, owned cards, saved decks, the chosen wizard and
## the booster pity counter. SaveStore writes it to JSON after every change (see the changed
## signal).

## Emitted after every change, so the owner can save at once.
signal changed

## A new profile owns STARTER_COPIES of each of these and gets STARTER_DECK as its first deck.
const STARTER_CARDS: Array[String] = [
	"arrow_tower", "frost_totem", "ballista", "arcane_bolt", "mend", "empower"
]
const STARTER_COPIES := 2
const STARTER_DECK: Array[String] = [
	"arrow_tower",
	"arrow_tower",
	"frost_totem",
	"frost_totem",
	"ballista",
	"arcane_bolt",
	"arcane_bolt",
	"mend",
]
## Wizard of a new profile (and of saves from before hero select).
const DEFAULT_HERO := "frost"
## Longest co-op name; it has to fit the partner panel.
const MAX_NAME_LENGTH := 12

var profile_name := "default"
var gold := 0
## Owned copies per card id.
var collection: Dictionary = {}
## Saved decks: {"name": String, "cards": Array of card ids}. Up to DeckRules.MAX_DECKS.
var decks: Array[Dictionary] = []
## Index into decks of the deck taken into the next run.
var active_deck := 0
## Id of the wizard taken into the next run (a HeroData id).
var hero := DEFAULT_HERO
## Boosters opened since the last epic (Booster.PITY).
var boosters_since_epic := 0
## Name shown to the co-op partner; empty until the player sets one (see display_name()).
var player_name := ""
## Highest difficulty tier this profile may pick (Sim.tier); winning a run unlocks the next.
var tier_unlocked := 0
## Tier taken into the next run, 0 to tier_unlocked.
var tier := 0


static func create(name: String = "default") -> Profile:
	var profile := Profile.new()
	profile.profile_name = name
	for card_id in STARTER_CARDS:
		profile.collection[card_id] = STARTER_COPIES
	profile.decks.append({"name": "Starter", "cards": STARTER_DECK.duplicate()})
	for i in range(1, DeckRules.MAX_DECKS):
		profile.decks.append({"name": "Deck %d" % (i + 1), "cards": []})
	return profile


func owned(card_id: String) -> int:
	return int(collection.get(card_id, 0))


func add_card(card_id: String) -> void:
	collection[card_id] = owned(card_id) + 1
	changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Takes amount gold if there is enough; returns false and changes nothing otherwise.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true


func deck_cards(index: int) -> Array:
	return decks[index]["cards"]


func set_deck_cards(index: int, card_ids: Array) -> void:
	decks[index]["cards"] = card_ids.duplicate()
	changed.emit()


func set_active_deck(index: int) -> void:
	active_deck = clampi(index, 0, decks.size() - 1)
	changed.emit()


func set_hero(hero_id: String) -> void:
	hero = hero_id
	changed.emit()


func set_tier(value: int) -> void:
	tier = clampi(value, 0, tier_unlocked)
	changed.emit()


## Unlocks tiers up to value (never past the last one); returns true if that was new.
func unlock_tier(value: int) -> bool:
	value = mini(value, Sim.TIER_COUNT - 1)
	if value <= tier_unlocked:
		return false
	tier_unlocked = value
	changed.emit()
	return true


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().left(MAX_NAME_LENGTH)
	changed.emit()


## The co-op name: player_name, else the system user name, else "Wizard".
func display_name() -> String:
	if not player_name.is_empty():
		return player_name
	for key in ["USERNAME", "USER"]:
		var user := OS.get_environment(key).strip_edges()
		if not user.is_empty():
			return user.left(MAX_NAME_LENGTH)
	return "Wizard"


func is_deck_valid(index: int) -> bool:
	return DeckRules.is_valid(deck_cards(index), collection)


## The deck as a resource for the Sim, with ids the catalog doesn't know left out.
func deck_data(index: int, catalog: CardCatalog) -> DeckData:
	var deck := DeckData.new()
	deck.id = StringName("%s_%d" % [profile_name, index])
	deck.display_name = decks[index]["name"]
	for card_id: String in deck_cards(index):
		if catalog.has(card_id):
			deck.cards.append(catalog.get_card(card_id))
	return deck


func to_dict() -> Dictionary:
	return {
		"name": profile_name,
		"gold": gold,
		"collection": collection.duplicate(),
		"decks": decks.duplicate(true),
		"active_deck": active_deck,
		"hero": hero,
		"boosters_since_epic": boosters_since_epic,
		"player_name": player_name,
		"tier_unlocked": tier_unlocked,
		"tier": tier,
	}


## Reads the current save format (SaveStore migrates older ones first).
static func from_dict(data: Dictionary) -> Profile:
	var profile := Profile.new()
	profile.profile_name = str(data.get("name", "default"))
	profile.gold = int(data.get("gold", 0))
	var owned_cards: Dictionary = data.get("collection", {})
	for card_id: String in owned_cards:
		profile.collection[card_id] = int(owned_cards[card_id])
	for deck: Dictionary in data.get("decks", []):
		var cards: Array = []
		for card_id: Variant in deck.get("cards", []):
			cards.append(str(card_id))
		profile.decks.append({"name": str(deck.get("name", "Deck")), "cards": cards})
	while profile.decks.size() < DeckRules.MAX_DECKS:
		profile.decks.append({"name": "Deck %d" % (profile.decks.size() + 1), "cards": []})
	profile.decks.resize(DeckRules.MAX_DECKS)
	profile.active_deck = clampi(int(data.get("active_deck", 0)), 0, DeckRules.MAX_DECKS - 1)
	profile.hero = str(data.get("hero", DEFAULT_HERO))
	profile.boosters_since_epic = int(data.get("boosters_since_epic", 0))
	profile.player_name = str(data.get("player_name", ""))
	profile.tier_unlocked = clampi(int(data.get("tier_unlocked", 0)), 0, Sim.TIER_COUNT - 1)
	profile.tier = clampi(int(data.get("tier", 0)), 0, profile.tier_unlocked)
	return profile
