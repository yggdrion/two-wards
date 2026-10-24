class_name CoopScreen
extends MetaScreen
## Co-op: online through the lobby (one player hosts and reads out the room code, the other
## joins with it), or directly on a LAN by address and port. Once the partner is connected
## both go to the lobby screen.

var session: NetSession
var name_edit: LineEdit
var code_edit: LineEdit
var address_edit: LineEdit
var port_edit: LineEdit
var online_host_button: Button
var online_join_button: Button
var host_button: Button
var join_button: Button
var cancel_button: Button
var status_label: Label
## The code field shows our own room while we host online; it is cleared when that ends.
var _showing_own_code := false


func build() -> void:
	add_header("Co-op")
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	form.position = Vector2(160, 48)
	form.size = Vector2(320, 0)
	add_child(form)
	name_edit = _field(form, "Your name", "")
	name_edit.max_length = Profile.MAX_NAME_LENGTH
	name_edit.text_changed.connect(_on_name_changed)
	code_edit = _field(form, "Room code", "")
	code_edit.max_length = 4
	code_edit.placeholder_text = "partner's code"
	address_edit = _field(form, "LAN address", "127.0.0.1")
	port_edit = _field(form, "LAN port", str(Transport.DEFAULT_PORT))
	online_host_button = button("Host online", host_online)
	online_join_button = button("Join code", join_online)
	cancel_button = button("Cancel", cancel)
	_button_row(168, [online_host_button, online_join_button, cancel_button])
	host_button = button("Host LAN", host)
	join_button = button("Join LAN", join)
	_button_row(204, [host_button, join_button])
	status_label = label("", &"DimLabel")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.position = Vector2(40, 244)
	status_label.size = Vector2(SCREEN.x - 80, 80)
	add_child(status_label)
	if session != null:
		session.room_ready.connect(_on_room_ready)
		session.partner_joined.connect(_on_partner_joined)
		session.connection_failed.connect(_on_connection_failed)
		session.partner_left.connect(_on_partner_left)


func refresh() -> void:
	if name_edit.text.is_empty() and not name_edit.has_focus():
		name_edit.text = profile.display_name()
	var busy := session != null and session.is_active()
	var ready := profile.is_deck_valid(profile.active_deck)
	for item: Button in [online_host_button, online_join_button, host_button, join_button]:
		item.disabled = busy or not ready
	cancel_button.disabled = not busy
	code_edit.editable = not busy
	if not busy and _showing_own_code:
		_showing_own_code = false
		code_edit.text = ""
	if not ready:
		status_label.text = "Your active deck is not ready, fix it in Decks."
	elif not busy and status_label.text.is_empty():
		status_label.text = "One player hosts online, the other joins with the room code."


## What this player brings: name, wizard and active deck (CoopSetup.player_info).
func player_info() -> Dictionary:
	return CoopSetup.from_profile(profile)


func host_online() -> void:
	session.host_online()
	status_label.text = "Opening a room ..."
	refresh()


func join_online() -> void:
	var code := code_edit.text.strip_edges().to_upper()
	if code.length() != 4:
		status_label.text = "Enter the 4-letter room code from your partner."
		return
	session.join_online(code, player_info())
	status_label.text = "Joining room %s ..." % code
	refresh()


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


func _button_row(y: float, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(160, y)
	row.size = Vector2(320, 28)
	add_child(row)
	for item: Button in buttons:
		item.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(item)


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


## The partner is here (host: the client's hello; client: the host's lobby info).
func _on_partner_joined(_info: Dictionary) -> void:
	navigate.emit(App.Screen.LOBBY)


func _on_room_ready(code: String) -> void:
	_showing_own_code = true
	code_edit.text = code
	status_label.text = "Room code: %s\nTell your partner, then wait for them to join." % code


func _on_connection_failed() -> void:
	status_label.text = "%s." % session.last_error
	refresh()


func _on_partner_left() -> void:
	session.close()
	# Set when the host turned the partner away (another game version).
	status_label.text = (
		"%s." % session.last_error
		if not session.last_error.is_empty()
		else "The connection closed."
	)
	refresh()
