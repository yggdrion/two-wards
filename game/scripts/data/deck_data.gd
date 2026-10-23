class_name DeckData
extends Resource
## A list of cards a player brings into a run. Deck rules (size 8, max 2 copies) live in DeckRules.

@export var id: StringName
@export var display_name: String
@export var cards: Array[CardData] = []


## One run deck from several players' decks, in player order (co-op: host first).
static func merged(decks: Array[DeckData]) -> DeckData:
	var result := DeckData.new()
	result.id = &"run"
	result.display_name = "Run deck"
	for deck in decks:
		if deck != null:
			result.cards.append_array(deck.cards)
	return result
