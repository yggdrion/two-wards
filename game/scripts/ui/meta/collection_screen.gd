class_name CollectionScreen
extends MetaScreen
## Every card in the game with the owned count; cards not owned yet are dimmed. Hovering a
## card shows it full size.

const COLUMNS := 6
const GRID_POS := Vector2(12, 40)
const GAP := Vector2(8, 26)
const NOT_OWNED := Color(1, 1, 1, 0.35)

var views: Array[CardView] = []
var counts: Array[Label] = []
var _preview: CardView
var _summary: Label


func build() -> void:
	add_header("Collection")
	var all := catalog.all()
	for i in all.size():
		var view := CardView.new()
		view.card = all[i]
		var cell := Vector2(i % COLUMNS, i / COLUMNS) * (CardView.COMPACT_SIZE + GAP)
		view.position = GRID_POS + cell
		view.mouse_entered.connect(_show_preview.bind(view))
		view.mouse_exited.connect(_hide_preview.bind(view))
		add_child(view)
		views.append(view)
		var count := label("", &"DimLabel")
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.position = view.position + Vector2(0, CardView.COMPACT_SIZE.y)
		count.size = Vector2(CardView.COMPACT_SIZE.x, 24)
		add_child(count)
		counts.append(count)
	_summary = label("", &"DimLabel")
	_summary.position = Vector2(180, 6)
	add_child(_summary)
	_preview = CardView.new()
	_preview.full = true
	_preview.visible = false
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_preview)


func refresh() -> void:
	var kinds := 0
	var total := 0
	for i in views.size():
		var owned := profile.owned(String(views[i].card.id))
		views[i].modulate = Color.WHITE if owned > 0 else NOT_OWNED
		counts[i].text = "x%d" % owned
		kinds += 1 if owned > 0 else 0
		total += owned
	_summary.text = "%d/%d cards found, %d owned" % [kinds, views.size(), total]


func _show_preview(view: CardView) -> void:
	_preview.card = view.card
	var x := view.position.x + CardView.COMPACT_SIZE.x + 4
	if x + CardView.FULL_SIZE.x > SCREEN.x:
		x = view.position.x - CardView.FULL_SIZE.x - 4
	_preview.position = Vector2(x, clampf(view.position.y, 0, SCREEN.y - CardView.FULL_SIZE.y))
	_preview.visible = true


func _hide_preview(view: CardView) -> void:
	if _preview.card == view.card:
		_preview.visible = false
