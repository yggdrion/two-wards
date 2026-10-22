class_name DeckRules
## Deck building rules: exactly SIZE cards, at most MAX_COPIES of each, and only owned copies.

const SIZE := 8
const MAX_COPIES := 2
## Saved decks per profile.
const MAX_DECKS := 3


## Why a list of card ids is not a legal deck for this collection; empty when it is.
static func errors(card_ids: Array, collection: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if card_ids.size() != SIZE:
		problems.append("Needs %d cards, has %d" % [SIZE, card_ids.size()])
	var counts := count(card_ids)
	for card_id: String in counts:
		var copies: int = counts[card_id]
		if copies > MAX_COPIES:
			problems.append("%s: max %d copies" % [card_id, MAX_COPIES])
		elif copies > int(collection.get(card_id, 0)):
			problems.append("%s: only %d owned" % [card_id, int(collection.get(card_id, 0))])
	return problems


static func is_valid(card_ids: Array, collection: Dictionary) -> bool:
	return errors(card_ids, collection).is_empty()


## True if one more copy of card_id would still fit the rules.
static func can_add(card_ids: Array, card_id: String, collection: Dictionary) -> bool:
	var copies := card_ids.count(card_id)
	return (
		card_ids.size() < SIZE and copies < MAX_COPIES and copies < int(collection.get(card_id, 0))
	)


## Copies per card id.
static func count(card_ids: Array) -> Dictionary:
	var counts := {}
	for card_id: String in card_ids:
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts
