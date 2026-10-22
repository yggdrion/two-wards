class_name Booster
## Booster packs: COST gold for SLOTS cards, each slot rolling its rarity on its own.
##
## Pity: the PITY-th booster in a row without an epic turns its last slot into an epic.

const COST := 50
const SLOTS := 3
const PITY := 10
## Chance per slot, in CardData.Rarity order (common, rare, epic).
const ODDS: Array[float] = [0.70, 0.25, 0.05]


static func roll_rarity(rng: RandomNumberGenerator) -> CardData.Rarity:
	var roll := rng.randf()
	var total := 0.0
	for rarity in ODDS.size():
		total += ODDS[rarity]
		if roll < total:
			return rarity as CardData.Rarity
	return CardData.Rarity.COMMON


## The rarities of one booster's slots, with pity applied.
static func roll_slots(rng: RandomNumberGenerator, since_epic: int) -> Array[CardData.Rarity]:
	var rarities: Array[CardData.Rarity] = []
	for i in SLOTS:
		rarities.append(roll_rarity(rng))
	if since_epic >= PITY - 1 and not rarities.has(CardData.Rarity.EPIC):
		rarities[SLOTS - 1] = CardData.Rarity.EPIC
	return rarities


## Pays for and opens a booster: adds the cards to the collection and updates pity.
## Returns one {"card": CardData, "new": bool} per slot, or [] if gold is short.
static func open(profile: Profile, catalog: CardCatalog, rng: RandomNumberGenerator) -> Array:
	if not profile.spend_gold(COST):
		return []
	var pulls := []
	var rarities := roll_slots(rng, profile.boosters_since_epic)
	for rarity in rarities:
		var pool := catalog.of_rarity(rarity)
		var card: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		var card_id := String(card.id)
		pulls.append({"card": card, "new": profile.owned(card_id) == 0})
		profile.add_card(card_id)
	if rarities.has(CardData.Rarity.EPIC):
		profile.boosters_since_epic = 0
	else:
		profile.boosters_since_epic += 1
	profile.changed.emit()
	return pulls
