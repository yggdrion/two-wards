class_name PlayerState
extends RefCounted
## One player's run state: hand of 3, energy, and the wizard whose buff they bring.
##
## A played or cycled card is replaced in the same hand slot at once. A card passed by the
## partner sits in a fourth slot (GIFT_SLOT) until it is played, cycled or passed back; that
## slot is never refilled.

const HAND_SIZE := 3
## Slot index of a card received from the partner; a hand holds at most one.
const GIFT_SLOT := HAND_SIZE
const CYCLE_COST := 1
const PASS_COST := 1

var deck: Deck
## The player's wizard; null plays without a buff (tests).
var hero: HeroData
var energy := Energy.new()
## Hand slots; a slot holds null only if the deck ran completely dry.
var hand: Array[CardData] = []
## Taken off the cost of the next card played (Arcane Focus).
var next_card_discount: int = 0
## Seconds left in which the wizard buff counts double (Empower).
var empowered := 0.0


func _init(run_deck: Deck, wizard: HeroData = null) -> void:
	deck = run_deck
	hero = wizard
	for i in HAND_SIZE:
		hand.append(deck.draw())


func step(delta: float) -> void:
	energy.step(delta)
	empowered = maxf(empowered - delta, 0.0)


## Doubles the wizard buff for `seconds`; a new Empower restarts the timer.
func empower(seconds: float) -> void:
	empowered = maxf(empowered, seconds)


## How many times this player's wizard buff counts right now: 0 without a wizard, 2 while
## empowered, else 1.
func buff_stacks() -> int:
	if hero == null:
		return 0
	return 2 if empowered > 0.0 else 1


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


## Gives the card in a hand slot to `partner` for PASS_COST energy. The slot refills from the
## deck; the partner keeps the card in their gift slot.
func pass_to(index: int, partner: PlayerState) -> bool:
	if not can_pass(index, partner):
		return false
	energy.spend(PASS_COST)
	var card := hand[index]
	_refill(index)
	partner.hand.append(card)
	return true


func can_pass(index: int, partner: PlayerState) -> bool:
	return (
		partner != null
		and partner != self
		and card_at(index) != null
		and partner.hand.size() <= GIFT_SLOT
		and energy.can_spend(PASS_COST)
	)


## Slot index of the first hand card with this id, or -1.
func find_in_hand(card_id: StringName) -> int:
	for i in hand.size():
		if hand[i] != null and hand[i].id == card_id:
			return i
	return -1


func _replace(index: int) -> void:
	deck.discard(hand[index])
	_refill(index)


## Draws into a hand slot; the gift slot goes away instead.
func _refill(index: int) -> void:
	if index >= GIFT_SLOT:
		hand.remove_at(index)
	else:
		hand[index] = deck.draw()
