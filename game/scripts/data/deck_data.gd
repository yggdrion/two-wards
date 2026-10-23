class_name DeckData
extends Resource
## A list of cards a player brings into a run. Deck rules (size 8, max 2 copies) live in DeckRules.

@export var id: StringName
@export var display_name: String
@export var cards: Array[CardData] = []
