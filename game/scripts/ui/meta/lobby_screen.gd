class_name LobbyScreen
extends MetaScreen
## Co-op lobby: both players' names, wizards and decks before the run. The client says ready,
## then the host starts the run on both machines. Back leaves the session.

const COLUMN_WIDTH := 260.0

var session: NetSession
var start_button: Button
var ready_button: Button
var status_label: Label
var _columns: Array[VBoxContainer] = []


func build() -> void:
	add_header("Lobby")
	for i in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.position = Vector2(40 + i * (COLUMN_WIDTH + 40), 48)
		column.size = Vector2(COLUMN_WIDTH, 0)
		add_child(column)
		_columns.append(column)
	start_button = button("Start run", start)
	ready_button = button("Ready", get_ready)
	for item: Button in [start_button, ready_button]:
		item.position = Vector2(SCREEN.x / 2.0 - 60, 284)
		item.size = Vector2(120, 28)
		add_child(item)
	status_label = label("", &"DimLabel")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, 318)
	status_label.size = Vector2(SCREEN.x, 24)
	add_child(status_label)
	if session != null:
		session.partner_joined.connect(func(_info: Dictionary) -> void: refresh())
		session.partner_ready.connect(refresh)
		session.partner_left.connect(_on_partner_left)
		if is_host():
			session.share_lobby(CoopSetup.from_profile(profile))


func is_host() -> bool:
	return session.role == NetSession.Role.HOST


## Both players' info, host first as in the run.
func infos() -> Array[Dictionary]:
	var result: Array[Dictionary] = [CoopSetup.from_profile(profile), session.partner_info]
	if not is_host():
		result.reverse()
	return result


func refresh() -> void:
	if session == null:
		return
	var all := infos()
	for i in _columns.size():
		_fill(_columns[i], all[i], i == 0)
	start_button.visible = is_host()
	start_button.disabled = not session.partner_is_ready
	ready_button.visible = not is_host()
	if is_host() and session.partner_is_ready:
		status_label.text = "Your partner is ready."
	elif is_host():
		status_label.text = "Waiting for your partner to get ready."
	elif session.partner_info.is_empty():
		status_label.text = "Waiting for the host ..."
	elif ready_button.disabled:
		status_label.text = "Waiting for the host to start."
	else:
		status_label.text = "Check both decks, then press Ready."


## Client: ready to start; the host's Start button unlocks.
func get_ready() -> void:
	session.send_ready()
	ready_button.disabled = true
	refresh()


## Host: starts the run on both machines once the partner is ready.
func start() -> void:
	if not session.partner_is_ready:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	session.start_run(CoopSetup.make(rng.randi(), infos()))


## The host's column (`host`) also shows the run's difficulty tier.
func _fill(column: VBoxContainer, info: Dictionary, host: bool) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	if info.is_empty():
		column.add_child(label("Waiting ...", &"DimLabel"))
		return
	var hero := HeroData.find(str(info.get("hero", "")))
	column.add_child(label(str(info.get("name", "Wizard"))))
	column.add_child(label(hero.display_name if hero != null else "No wizard", &"GoldLabel"))
	if host:
		column.add_child(label("Tier %d" % (int(info.get("tier", 0)) + 1), &"GoldLabel"))
	for card_id: Variant in info.get("deck", []):
		var card := catalog.get_card(str(card_id)) if catalog != null else null
		column.add_child(label(card.display_name if card != null else str(card_id), &"DimLabel"))


func _on_partner_left() -> void:
	session.close()
	navigate.emit(App.Screen.COOP)
