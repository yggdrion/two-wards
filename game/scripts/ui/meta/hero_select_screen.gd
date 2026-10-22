class_name HeroSelectScreen
extends MetaScreen
## Picks the wizard for the next runs. Each wizard is a portrait, its name and its
## battlefield buff; the choice goes into the profile.

const PANEL_SIZE := Vector2(200, 264)
const PANEL_TOP := 44.0
const PANEL_GAP := 40.0
const PORTRAIT_SCALE := 2.0

var heroes: Array[HeroData] = []
## One Choose button per wizard, in heroes order.
var choose_buttons: Array[Button] = []
var _panels: Array[Panel] = []


func build() -> void:
	add_header("Wizard")
	heroes = HeroData.load_all()
	var total := heroes.size() * PANEL_SIZE.x + (heroes.size() - 1) * PANEL_GAP
	var x := (SCREEN.x - total) / 2.0
	for hero in heroes:
		_add_panel(hero, Vector2(x, PANEL_TOP))
		x += PANEL_SIZE.x + PANEL_GAP
	var hint := label("Your wizard never walks the field. Its buff covers it all.", &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, PANEL_TOP + PANEL_SIZE.y + 6)
	hint.size = Vector2(SCREEN.x, 24)
	add_child(hint)


func choose(hero_id: String) -> void:
	if hero_id != profile.hero:
		profile.set_hero(hero_id)


func refresh() -> void:
	for i in heroes.size():
		var chosen := String(heroes[i].id) == profile.hero
		choose_buttons[i].disabled = chosen
		choose_buttons[i].text = "Chosen" if chosen else "Choose"
		_panels[i].modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.75)


func _add_panel(hero: HeroData, pos: Vector2) -> void:
	var panel := Panel.new()
	panel.position = pos
	panel.size = PANEL_SIZE
	add_child(panel)
	_panels.append(panel)
	var portrait := TextureRect.new()
	portrait.texture = hero.portrait
	portrait.material = hero.portrait_material
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.size = Vector2(64, 64) * PORTRAIT_SCALE
	portrait.position = Vector2((PANEL_SIZE.x - portrait.size.x) / 2.0, 4)
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	var title := label(hero.display_name)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 136)
	title.size = Vector2(PANEL_SIZE.x, 24)
	panel.add_child(title)
	var text := label(hero.text, &"DimLabel")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.position = Vector2(8, 158)
	text.size = Vector2(PANEL_SIZE.x - 16, 48)
	panel.add_child(text)
	var choose_button := button("Choose", choose.bind(String(hero.id)))
	choose_button.position = Vector2(40, PANEL_SIZE.y - 36)
	choose_button.size = Vector2(PANEL_SIZE.x - 80, 28)
	panel.add_child(choose_button)
	choose_buttons.append(choose_button)
