class_name RunRewards
extends RefCounted
## Card rewards between waves: after a cleared wave every player gets an offer of CHOICES
## different cards from the pool, each rolling its rarity like a booster slot, and picks one into
## their own deck. The lane holds the next wave until every offer is answered.

const CHOICES := 3

## Cards an offer can hold; empty turns rewards off (most tests).
var pool: Array[CardData] = []
## Each player's open offer: CHOICES cards, or empty.
var offers: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _init(card_pool: Array[CardData], player_count: int, rng_seed: int) -> void:
	pool = card_pool
	_rng.seed = rng_seed
	for i in player_count:
		offers.append([])


func is_open() -> bool:
	return offers.any(func(offer: Array) -> bool: return not offer.is_empty())


## Rolls a new offer for every player.
func open() -> void:
	for i in offers.size():
		offers[i] = _roll()


## Puts the offered card into `deck` (discard pile) and closes the player's offer.
func pick(player: int, card_id: String, deck: Deck) -> bool:
	if player < 0 or player >= offers.size():
		return false
	for card: CardData in offers[player]:
		if String(card.id) == card_id:
			deck.discard(card)
			offers[player] = []
			return true
	return false


func _roll() -> Array:
	var offer := []
	for i in mini(CHOICES, pool.size()):
		var rarity := Booster.roll_rarity(_rng)
		var left := pool.filter(func(card: CardData) -> bool: return card not in offer)
		var bucket := left.filter(func(card: CardData) -> bool: return card.rarity == rarity)
		if bucket.is_empty():
			bucket = left
		offer.append(bucket[_rng.randi_range(0, bucket.size() - 1)])
	return offer
