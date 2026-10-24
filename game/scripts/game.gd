class_name RunScreen
extends Node2D
## Run screen, solo or co-op: the hand picks a card, a click anywhere on the field targets it.
## Every action becomes a NetCommand. Solo applies it to the sim at once; in co-op it goes to
## the host's LockstepHost (the client sends it over the network), and the sim only moves
## through the host's frames.

## The run is over (won, lost, or the partner left) and earned this much gold.
signal run_ended(gold: int)
## The player left the end-of-run banner.
signal finished
## The player gave up the run (Leave run in the Esc menu); pays nothing.
signal left

## How many host frames the client plays per physics frame when it has fallen behind.
const MAX_CATCH_UP := 8

## Co-op connection; null plays solo. Set before the screen enters the tree, together with
## CoopSetup.configure on the sim.
var session: NetSession
## This machine's player: 0 solo and on the host, 1 on the client.
var player := 0
var selected := -1
var host: LockstepHost
var client: LockstepClient
var _ended := false
var _partner_left := false

@onready var lane: Lane = $Lane
@onready var sim: Sim = lane.sim
@onready var overlay: Node2D = $Overlay
@onready var hud: Hud = $HudLayer/Hud


func _ready() -> void:
	hud.sim = sim
	hud.player_index = player
	hud.card_pressed.connect(_select)
	hud.cycle_requested.connect(_cycle)
	hud.pass_requested.connect(func() -> void: _pass(selected))
	hud.reward_picked.connect(_pick_reward)
	hud.leave_requested.connect(left.emit)
	overlay.draw.connect(_draw_targeting)
	sim.run_won.connect(_on_run_over)
	sim.run_lost.connect(_on_run_over)
	if session != null:
		_start_coop()


func _start_coop() -> void:
	hud.names = session.setup.get("names", [])
	session.partner_left.connect(_on_partner_left)
	if session.role == NetSession.Role.HOST:
		host = LockstepHost.new(sim)
		host.rejected.connect(session.reject)
		session.command_received.connect(host.request)
		session.ack_received.connect(host.ack)
		session.hash_received.connect(host.hashes.report)
	else:
		client = LockstepClient.new(sim)
		session.frames_received.connect(client.receive)
		client.hashes.recorded.connect(session.send_hash)


func _physics_process(_delta: float) -> void:
	if _ended:
		return
	if host != null and host.can_step():
		session.send_frames([host.step()])
	elif client != null and client.advance(MAX_CATCH_UP) > 0:
		session.send_ack(client.tick)


func _process(_delta: float) -> void:
	if selected >= 0 and own().card_at(selected) == null:
		selected = -1
	hud.selected = selected
	overlay.queue_redraw()


func own() -> PlayerState:
	return sim.players[player]


func _unhandled_input(event: InputEvent) -> void:
	if sim.is_over() or _ended:
		_input_after_run(event)
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if hud.confirm_leave:
		if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
			hud.confirm_leave = false
		return
	if key != null and key.pressed and not key.echo:
		var choice := key.physical_keycode - KEY_1
		var offer: Array = sim.rewards.offers[player]
		if not offer.is_empty() and choice >= 0 and choice < offer.size():
			_pick_reward(String(offer[choice].id))
			return
		match key.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				_select(key.physical_keycode - KEY_1)
			KEY_Q:
				if selected >= 0:
					_cycle(selected)
			KEY_E:
				if selected >= 0:
					_pass(selected)
			KEY_ESCAPE:
				if selected >= 0:
					selected = -1
				else:
					hud.confirm_leave = true
	if click != null and click.pressed:
		if click.button_index == MOUSE_BUTTON_LEFT and selected >= 0:
			var at := lane.get_local_mouse_position()
			if Sim.FIELD.has_point(at) and _play(selected, at):
				selected = -1
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			selected = -1


func _input_after_run(event: InputEvent) -> void:
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if (
		(key != null and key.pressed and key.physical_keycode in [KEY_ENTER, KEY_SPACE])
		or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
	):
		finished.emit()


func _on_run_over() -> void:
	selected = -1
	if not _ended:
		_ended = true
		run_ended.emit(sim.gold)


func _on_partner_left() -> void:
	if sim.is_over() or _ended:
		return
	selected = -1
	hud.notice = "Your partner left. +%d gold" % sim.gold
	_ended = true
	_partner_left = true
	run_ended.emit(sim.gold)


## How the run went, for the run-end screen: result ("won", "lost", "partner_left" or
## "running"), waves cleared, waves in the run and gold earned.
func summary() -> Dictionary:
	var result := "running"
	if sim.phase == Sim.Phase.WON:
		result = "won"
	elif sim.phase == Sim.Phase.LOST:
		result = "lost"
	elif _partner_left:
		result = "partner_left"
	return {
		"result": result,
		"waves_cleared": sim.waves_cleared,
		"waves": sim.waves.size(),
		"gold": sim.gold,
	}


func _select(slot: int) -> void:
	var card := own().card_at(slot)
	if card == null:
		return
	if card.target == CardData.Target.NONE:
		_play(slot, Vector2.ZERO)
		selected = -1
	else:
		selected = -1 if selected == slot else slot


func _play(slot: int, at: Vector2) -> bool:
	var card := own().card_at(slot)
	if card == null or not sim.can_play_card(player, slot, at):
		return false
	return _submit(NetCommand.play(player, slot, card.id, at))


func _cycle(slot: int) -> void:
	var card := own().card_at(slot)
	if card != null and _submit(NetCommand.cycle(player, slot, card.id)) and selected == slot:
		selected = -1


func _pass(slot: int) -> void:
	var card := own().card_at(slot)
	if card == null or sim.players.size() != 2:
		return
	if not own().can_pass(slot, sim.players[1 - player]):
		return
	if _submit(NetCommand.pass_card(player, slot, card.id)) and selected == slot:
		selected = -1


func _pick_reward(card_id: String) -> void:
	_submit(NetCommand.reward(player, card_id))


## Solo applies the command now; co-op hands it to the host. True if it was applied or sent.
func _submit(cmd: Dictionary) -> bool:
	if host != null:
		host.request(cmd)
		return true
	if client != null:
		session.send_command(cmd)
		return true
	return NetCommand.apply(sim, cmd).is_empty()


## Shows where the selected card would land and whether it can be played there.
func _draw_targeting() -> void:
	var card := own().card_at(selected) if selected >= 0 else null
	if card == null:
		return
	var at := lane.get_local_mouse_position()
	if not Sim.FIELD.has_point(at):
		return
	var ok := sim.can_play_card(player, selected, at)
	var color := Palette.VALID if ok else Palette.INVALID
	for effect in card.effects:
		if effect is PlaceTowerEffect:
			overlay.draw_arc(at, effect.tower.attack_range, 0.0, TAU, 48, color, 2.0)
		elif effect is LureEffect or effect is BuffEffect:
			overlay.draw_arc(at, effect.radius, 0.0, TAU, 32, color, 2.0)
	overlay.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), color, false, 2.0)
