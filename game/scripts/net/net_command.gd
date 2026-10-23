class_name NetCommand
## Card events: what a player does with a hand slot. Solo runs, the co-op host and scenario
## replays all change the lane only through apply(), so every path validates the same way.
##
## A command is a plain Dictionary, so any transport can carry it:
##   {"player": 1, "kind": "play", "slot": 0, "card": "arrow_tower", "at": Vector2(150, 60)}
## "card" must still be in that slot when the command is applied; a command sent against an
## older hand is refused instead of playing whatever card took the slot's place. A reward pick
## has no slot: {"player": 0, "kind": "reward", "card": "ballista"}.

const PLAY := "play"
const CYCLE := "cycle"
const PASS := "pass"
const REWARD := "reward"


static func play(player: int, slot: int, card_id: String, at: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"player": player, "kind": PLAY, "slot": slot, "card": card_id, "at": at}


static func cycle(player: int, slot: int, card_id: String) -> Dictionary:
	return {"player": player, "kind": CYCLE, "slot": slot, "card": card_id}


static func pass_card(player: int, slot: int, card_id: String) -> Dictionary:
	return {"player": player, "kind": PASS, "slot": slot, "card": card_id}


static func reward(player: int, card_id: String) -> Dictionary:
	return {"player": player, "kind": REWARD, "card": card_id}


## Builds a command for the first hand slot holding `card_id`; empty if it isn't in the hand.
static func for_card(
	lane: Lane, player: int, kind: String, card_id: String, at: Vector2 = Vector2.ZERO
) -> Dictionary:
	if player < 0 or player >= lane.players.size():
		return {}
	var slot := lane.players[player].find_in_hand(card_id)
	if slot < 0:
		return {}
	return {"player": player, "kind": kind, "slot": slot, "card": card_id, "at": at}


## Applies the command to the lane. Returns "" on success, else why nothing changed.
static func apply(lane: Lane, cmd: Dictionary) -> String:
	var player := int(cmd.get("player", -1))
	if player < 0 or player >= lane.players.size():
		return "no player %d" % player
	if str(cmd.get("kind", "")) == REWARD:
		if lane.rewards.pick(player, str(cmd.get("card", "")), lane.players[player].deck):
			return ""
		return "%s is not offered to player %d" % [cmd.get("card", "?"), player]
	var slot := int(cmd.get("slot", -1))
	var card := lane.players[player].card_at(slot)
	if card == null or String(card.id) != str(cmd.get("card", "")):
		return "%s is not in slot %d" % [cmd.get("card", "?"), slot]
	var ok := false
	match str(cmd.get("kind", "")):
		PLAY:
			ok = lane.play_card(player, slot, cmd.get("at", Vector2.ZERO))
		CYCLE:
			ok = lane.cycle_card(player, slot)
		PASS:
			ok = lane.pass_card(player, slot)
		var kind:
			return "unknown command %s" % kind
	if not ok:
		return (
			"cannot %s %s (energy %d)"
			% [cmd["kind"], card.id, lane.players[player].energy.points()]
		)
	return ""
