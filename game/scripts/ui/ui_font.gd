class_name UiFont
## The UI pixel font: m5x7 at 1x, loaded from FONT_PATH without antialiasing.
## Until the font file is added, Godot's fallback font stands in.

const FONT_PATH := "res://assets/fonts/m5x7.ttf"
## m5x7 is drawn pixel-perfect at size 16 (5x7 glyphs).
const PIXEL_SIZE := 16
const FALLBACK_SIZE := 8
## Vertical distance between two text lines, in pixels.
const LINE := 8
## Baseline offset from the top of a line.
const BASELINE := 7

static var _font: Font
static var _size := FALLBACK_SIZE


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			var file: FontFile = load(FONT_PATH)
			file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			file.hinting = TextServer.HINTING_NONE
			file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font = file
			_size = PIXEL_SIZE
		else:
			_font = ThemeDB.fallback_font
	return _font


static func size() -> int:
	font()
	return _size


static func width(text: String) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size()).x


## Splits text into lines no wider than max_width, breaking at spaces.
static func wrap_lines(text: String, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if line.is_empty() or width(candidate) <= max_width:
			line = candidate
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines


## Draws text with its top-left corner at pos.
static func draw(canvas: CanvasItem, pos: Vector2, text: String, color: Color) -> void:
	canvas.draw_string(
		font(), pos + Vector2(0, BASELINE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size(), color
	)


## Draws text centered horizontally on center_x.
static func draw_centered(
	canvas: CanvasItem, center_x: float, top: float, text: String, color: Color
) -> void:
	draw(canvas, Vector2(roundf(center_x - width(text) / 2.0), top), text, color)


## Draws wrapped text, at most max_lines lines. Returns the y below the last line.
static func draw_wrapped(
	canvas: CanvasItem, pos: Vector2, text: String, max_width: float, max_lines: int, color: Color
) -> float:
	var y := pos.y
	var lines := wrap_lines(text, max_width)
	for i in mini(lines.size(), max_lines):
		draw(canvas, Vector2(pos.x, y), lines[i], color)
		y += LINE
	return y
