class_name DebugOverlay
extends CanvasLayer
## F3 toggles a corner readout of fps and the co-op connection (NetSession.debug_lines) over
## every screen, in and out of runs. Off by default; release builds have it too, for playtests.

## How often the text refreshes, in seconds.
const REFRESH := 0.25

var session: NetSession
var _label := Label.new()
var _wait := 0.0


func _ready() -> void:
	layer = 100
	visible = false
	_label.position = Vector2(4, 4)
	_label.add_theme_font_override("font", UiFont.font())
	_label.add_theme_font_size_override("font_size", UiFont.size())
	_label.add_theme_color_override("font_color", Palette.TEXT)
	_label.add_theme_color_override("font_outline_color", Palette.PANEL)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		_wait = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	var lines := PackedStringArray(["FPS %d" % Engine.get_frames_per_second()])
	if session != null:
		lines.append_array(session.debug_lines())
	_label.text = "\n".join(lines)
