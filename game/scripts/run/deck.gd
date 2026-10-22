class_name Deck
extends RefCounted
## The run deck: a seeded draw pile, plus a discard pile that is shuffled back in when the
## draw pile runs out.
##
## Shared by both players in co-op (M4). Every shuffle uses the deck's own RNG, so runs replay
## exactly.

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var _rng := RandomNumberGenerator.new()


func _init(cards: Array[CardData], rng_seed: int) -> void:
	_rng.seed = rng_seed
	draw_pile = cards.duplicate()
	_shuffle(draw_pile)


## Returns the top card, or null when both piles are empty.
func draw() -> CardData:
	if draw_pile.is_empty():
		draw_pile = discard_pile
		discard_pile = []
		_shuffle(draw_pile)
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


func discard(card: CardData) -> void:
	discard_pile.append(card)


func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := cards[i]
		cards[i] = cards[j]
		cards[j] = swap
