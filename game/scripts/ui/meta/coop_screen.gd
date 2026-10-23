class_name CoopScreen
extends MetaScreen
## Local co-op (M4, before the lobby): host on a port, or join a host by address. The run
## starts on both machines as soon as the client has joined. Online play with room codes
## replaces the address field in M5.

var session: NetSession
var name_edit: LineEdit
var address_edit: LineEdit
var port_edit: LineEdit
var host_button: Button
var join_button: Button
var cancel_button: Button
var status_label: Label


func build() -> void:
	add_header("Co-op")
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	form.position = Vector2(160, 56)
	form.size = Vector2(320, 0)
	add_child(form)
	name_edit = _field(form, "Your name", "")
	name_edit.max_length = Profile.MAX_NAME_LENGTH
	name_edit.text_changed.connect(_on_name_changed)
	address_edit = _field(form, "Host address", "127.0.0.1")
	port_edit = _field(form, "Port", str(Transport.DEFAULT_PORT))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.position = Vector2(160, 176)
	buttons.size = Vector2(320, 28)
	add_child(buttons)
	host_button = button("Host", host)
	join_button = button("Join", join)
	cancel_button = button("Cancel", cancel)
	for item: Button in [host_button, join_button, cancel_button]:
		item.size_flags_horizontal = SIZE_EXPAND_FILL
		buttons.add_child(item)
	status_label = label("", &"DimLabel")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.position = Vector2(40, 220)
	status_label.size = Vector2(SCREEN.x - 80, 96)
	add_child(status_label)
	if session != null:
		session.partner_joined.connect(_on_partner_joined)
		session.connection_failed.connect(_on_connection_failed)
		session.partner_left.connect(_on_partner_left)


func refresh() -> void:
	if name_edit.text.is_empty() and not name_edit.has_focus():
		name_edit.text = profile.display_name()
	var busy := session != null and session.is_active()
	var ready := profile.is_deck_valid(profile.active_deck)
	host_button.disabled = busy or not ready
	join_button.disabled = busy or not ready
	cancel_button.disabled = not busy
	if not ready:
		status_label.text = "Your active deck is not ready, fix it in Decks."
	elif not busy and status_label.text.is_empty():
		status_label.text = "One player hosts, the other joins with the host's address."


## What this player brings: name, wizard and active deck (CoopSetup.player_info).
func player_info() -> Dictionary:
	return CoopSetup.player_info(
		profile.display_name(), profile.hero, profile.deck_cards(profile.active_deck)
	)


func host() -> void:
	if session.host(_port()):
		status_label.text = (
			"Waiting for a partner on port %d.\nYour addresses: %s" % [_port(), _addresses()]
		)
	else:
		status_label.text = "Could not open port %d. Is another game hosting?" % _port()
	refresh()


func join() -> void:
	var address := address_edit.text.strip_edges()
	if session.join(address, _port(), player_info()):
		status_label.text = "Joining %s:%d ..." % [address, _port()]
	else:
		status_label.text = "Could not connect to %s:%d." % [address, _port()]
	refresh()


func cancel() -> void:
	session.close()
	status_label.text = ""
	refresh()


func _field(form: GridContainer, title: String, text: String) -> LineEdit:
	form.add_child(label(title))
	var edit := LineEdit.new()
	edit.text = text
	edit.custom_minimum_size = Vector2(180, 0)
	form.add_child(edit)
	return edit


func _port() -> int:
	var port := port_edit.text.strip_edges().to_int()
	return port if port > 0 and port < 65536 else Transport.DEFAULT_PORT


func _addresses() -> String:
	var found := PackedStringArray()
	for address in IP.get_local_addresses():
		if (
			address.count(".") == 3
			and not address.begins_with("127.")
			and not address.begins_with("169.254.")
		):
			found.append(address)
	return ", ".join(found) if not found.is_empty() else "127.0.0.1"


func _on_name_changed(text: String) -> void:
	if text.strip_edges() != profile.player_name:
		profile.set_player_name(text)


## Host: the client said hello, so start the run on both machines.
func _on_partner_joined(hello: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var infos: Array[Dictionary] = [player_info(), hello]
	session.start_run(CoopSetup.make(rng.randi(), infos))


func _on_connection_failed() -> void:
	status_label.text = "No host answered at %s:%d." % [address_edit.text, _port()]
	refresh()


func _on_partner_left() -> void:
	session.close()
	status_label.text = "The connection closed."
	refresh()
