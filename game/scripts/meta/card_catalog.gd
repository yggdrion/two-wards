class_name CardCatalog
extends RefCounted
## Every card in the game, keyed by id. Loaded from the card resources folder, so a new card
## is one .tres there and nothing else.

const CARD_DIR := "res://resources/cards"

var _cards: Dictionary[String, CardData] = {}
var _sorted: Array[CardData] = []


static func load_dir(dir: String = CARD_DIR) -> CardCatalog:
	var catalog := CardCatalog.new()
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() == "tres":
			var card := load(dir.path_join(file)) as CardData
			if card != null:
				catalog.add(card)
	return catalog


func add(card: CardData) -> void:
	_cards[String(card.id)] = card
	_sorted = _cards.values()
	_sorted.sort_custom(_before)


func get_card(card_id: String) -> CardData:
	return _cards.get(card_id)


func has(card_id: String) -> bool:
	return _cards.has(card_id)


## All cards, ordered by rarity, then cost, then name.
func all() -> Array[CardData]:
	return _sorted


func of_rarity(rarity: CardData.Rarity) -> Array[CardData]:
	return _sorted.filter(func(card: CardData) -> bool: return card.rarity == rarity)


static func _before(a: CardData, b: CardData) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	if a.cost != b.cost:
		return a.cost < b.cost
	return a.display_name < b.display_name
