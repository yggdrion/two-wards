class_name RunScreen
extends Node2D
## Solo run screen: the hand picks a card, a click anywhere on the field targets it. Every
## action goes through Lane's play_card/cycle_card, as network input will.

## The run is over (won or lost) and earned this much gold.
signal run_ended(gold: int)
## The player left the end-of-run banner.
signal finished

const PLAYER := 0

var selected := -1

@onready var lane: Lane = $Lane
@onready var overlay: Node2D = $Overlay
@onready var hud: Hud = $HudLayer/Hud


func _ready() -> void:
	hud.lane = lane
	hud.card_pressed.connect(_select)
	hud.cycle_requested.connect(_cycle)
	overlay.draw.connect(_draw_targeting)
	lane.run_won.connect(_on_run_over)
	lane.run_lost.connect(_on_run_over)


func _process(_delta: float) -> void:
	if selected >= 0 and lane.players[PLAYER].card_at(selected) == null:
		selected = -1
	hud.selected = selected
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if lane.is_over():
		_input_after_run(event)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_select(key.physical_keycode - KEY_1)
			KEY_Q:
				if selected >= 0:
					_cycle(selected)
			KEY_ESCAPE:
				selected = -1
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		if click.button_index == MOUSE_BUTTON_LEFT and selected >= 0:
			var at := lane.get_local_mouse_position()
			if Lane.FIELD.has_point(at) and lane.play_card(PLAYER, selected, at):
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
	run_ended.emit(lane.gold)


func _select(slot: int) -> void:
	var card := lane.players[PLAYER].card_at(slot)
	if card == null:
		return
	if card.target == CardData.Target.NONE:
		lane.play_card(PLAYER, slot)
		selected = -1
	else:
		selected = -1 if selected == slot else slot


func _cycle(slot: int) -> void:
	if lane.cycle_card(PLAYER, slot) and selected == slot:
		selected = -1


## Shows where the selected card would land and whether it can be played there.
func _draw_targeting() -> void:
	var card := lane.players[PLAYER].card_at(selected) if selected >= 0 else null
	if card == null:
		return
	var at := lane.get_local_mouse_position()
	if not Lane.FIELD.has_point(at):
		return
	var ok := lane.can_play_card(PLAYER, selected, at)
	var color := Palette.VALID if ok else Palette.INVALID
	for effect in card.effects:
		if effect is PlaceTowerEffect:
			overlay.draw_arc(at, effect.tower.attack_range, 0.0, TAU, 48, color, 2.0)
		elif effect is LureEffect or effect is BuffEffect:
			overlay.draw_arc(at, effect.radius, 0.0, TAU, 32, color, 2.0)
	overlay.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), color, false, 2.0)
