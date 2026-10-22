class_name PlayerState
extends RefCounted
## One player's run state: hand of 3, energy, and the hero they control.
##
## A played or cycled card is replaced in the same hand slot at once.

const HAND_SIZE := 3
const CYCLE_COST := 1

var deck: Deck
var hero: Hero
var energy := Energy.new()
## Hand slots; a slot holds null only if the deck ran completely dry.
var hand: Array[CardData] = []
## Taken off the cost of the next card played (Arcane Focus).
var next_card_discount: int = 0


func _init(run_deck: Deck, controlled_hero: Hero) -> void:
	deck = run_deck
	hero = controlled_hero
	for i in HAND_SIZE:
		hand.append(deck.draw())


func cost_of(card: CardData) -> int:
	return maxi(card.cost - next_card_discount, 0)


func can_play(index: int, ctx: CardContext) -> bool:
	var card := card_at(index)
	return card != null and energy.can_spend(cost_of(card)) and card.can_play(ctx)


## Pays for and resolves the card in a hand slot. Returns false (and changes nothing) if it can't.
func play(index: int, ctx: CardContext) -> bool:
	if not can_play(index, ctx):
		return false
	var card := hand[index]
	energy.spend(cost_of(card))
	next_card_discount = 0
	_replace(index)
	card.play(ctx)
	return true


## Discards a hand card for a new one, for CYCLE_COST energy.
func cycle(index: int) -> bool:
	if card_at(index) == null or not energy.can_spend(CYCLE_COST):
		return false
	energy.spend(CYCLE_COST)
	_replace(index)
	return true


func card_at(index: int) -> CardData:
	if index < 0 or index >= hand.size():
		return null
	return hand[index]


## Slot index of the first hand card with this id, or -1.
func find_in_hand(card_id: StringName) -> int:
	for i in hand.size():
		if hand[i] != null and hand[i].id == card_id:
			return i
	return -1


func _replace(index: int) -> void:
	deck.discard(hand[index])
	hand[index] = deck.draw()
