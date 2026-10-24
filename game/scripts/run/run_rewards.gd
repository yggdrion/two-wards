class_name RunRewards
extends RefCounted
## Run upgrades between waves: after a cleared wave every player gets CHOICES offers, each an
## upgrade for a different card of their own run deck, and picks one. Upgrades roll their
## rarity like a booster slot and change the player's card for the rest of the run (every copy,
## and the towers already placed). The sim holds the next wave until every offer is answered.

const CHOICES := 3

## Upgrades an offer can hold; empty turns rewards off (most tests).
var pool: Array[UpgradeData] = []
## Each player's open offers: up to CHOICES {"card": CardData, "upgrade": UpgradeData}, or empty.
var offers: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _init(upgrade_pool: Array[UpgradeData], player_count: int, rng_seed: int) -> void:
	pool = upgrade_pool
	_rng.seed = rng_seed
	for i in player_count:
		offers.append([])


func is_open() -> bool:
	return offers.any(func(offer: Array) -> bool: return not offer.is_empty())


## Rolls new offers for every player from the cards in their run deck.
func open(players: Array[PlayerState]) -> void:
	for i in offers.size():
		offers[i] = _roll(players[i].run_cards)


## Applies the player's offer at `index` and closes their offers.
func pick(player: int, index: int) -> bool:
	if player < 0 or player >= offers.size() or index < 0 or index >= offers[player].size():
		return false
	var offer: Dictionary = offers[player][index]
	(offer["upgrade"] as UpgradeData).apply(offer["card"])
	offers[player] = []
	return true


## Short text of a player's offers for the state hash.
func describe(player: int) -> String:
	var parts := PackedStringArray()
	for offer: Dictionary in offers[player]:
		parts.append("%s:%s" % [offer["card"].id, offer["upgrade"].id])
	return ",".join(parts)


func _roll(cards: Array[CardData]) -> Array:
	var offer := []
	var left := cards.duplicate()
	for i in CHOICES:
		var pairs := _pairs(left, Booster.roll_rarity(_rng))
		if pairs.is_empty():
			pairs = _pairs(left, -1)
		if pairs.is_empty():
			break
		var pair: Dictionary = pairs[_rng.randi_range(0, pairs.size() - 1)]
		left.erase(pair["card"])
		offer.append(pair)
	return offer


## Every {card, upgrade} that fits, for upgrades of `rarity` (-1: any).
func _pairs(cards: Array, rarity: int) -> Array:
	var pairs := []
	for card: CardData in cards:
		for upgrade in pool:
			if (rarity < 0 or upgrade.rarity == rarity) and upgrade.fits(card):
				pairs.append({"card": card, "upgrade": upgrade})
	return pairs
