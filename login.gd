extends Control

# Écran de départ : connexion / création de compte (serveur) ou partie hors ligne.
# Un compte garde son personnage, sa progression et sa cellule sur le serveur.

const LAST_USER_PATH := "user://last_user.txt"

var ui: Control
var server_edit: LineEdit
var user_edit: LineEdit
var pass_edit: LineEdit
var status: Label
var busy_buttons: Array = []
var pending_mode := ""
var waiting := false
var wait_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#15171b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ui = Control.new()
	ui.size = Vector2(1280, 720)
	add_child(ui)
	_build_ui()
	get_viewport().size_changed.connect(_center_ui)
	_center_ui()
	Net.connected.connect(_on_connected)
	Net.auth_result.connect(_on_auth)
	Net.lost.connect(_on_lost)


func _center_ui() -> void:
	ui.position = (get_viewport_rect().size - Vector2(1280, 720)) / 2.0


func _label(text: String, pos: Vector2, width: float, font: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.modulate = col
	ui.add_child(l)
	return l


func _edit(pos: Vector2, placeholder: String, text: String, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.position = pos
	e.size = Vector2(500, 50)
	e.placeholder_text = placeholder
	e.text = text
	e.secret = secret
	e.add_theme_font_size_override("font_size", 22)
	ui.add_child(e)
	return e


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable, font: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("#2a2e36"), "hover": Color("#3a404b"), "pressed": Color("#4a515f"), "disabled": Color("#1d2026")}[state]
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.22)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(cb)
	ui.add_child(b)
	return b


func _build_ui() -> void:
	_label("LOCKED INSIDE", Vector2(240, 50), 800, 58)
	_label("Fort-Noir · Quartier de haute sécurité", Vector2(240, 125), 800, 20, Color(1, 1, 1, 0.55))

	server_edit = _edit(Vector2(390, 190), "Adresse du serveur (ex. 127.0.0.1)", GameState.server_address)
	user_edit = _edit(Vector2(390, 250), "Nom du détenu", _last_user())
	pass_edit = _edit(Vector2(390, 310), "Mot de passe (6 caractères minimum)", "", true)
	pass_edit.text_submitted.connect(func(_t): _go("login"))

	busy_buttons.append(_button("SE CONNECTER", Vector2(390, 378), Vector2(242, 54), func(): _go("login")))
	busy_buttons.append(_button("CRÉER UN COMPTE", Vector2(648, 378), Vector2(242, 54), func(): _go("register")))

	status = _label("", Vector2(390, 442), 500, 17, Color(1, 0.75, 0.55))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size = Vector2(500, 60)

	_label("— ou —", Vector2(390, 520), 500, 16, Color(1, 1, 1, 0.4))
	var offline_text := "JOUER HORS LIGNE"
	if GameState.has_saved_character():
		offline_text = "CONTINUER HORS LIGNE (%s)" % str(GameState.ap["name"])
	busy_buttons.append(_button(offline_text, Vector2(390, 552), Vector2(500, 50), func(): _offline(false)))
	if GameState.has_saved_character():
		busy_buttons.append(_button("Nouveau personnage hors ligne", Vector2(390, 612), Vector2(500, 40), func(): _offline(true), 16))


func _last_user() -> String:
	if FileAccess.file_exists(LAST_USER_PATH):
		var f := FileAccess.open(LAST_USER_PATH, FileAccess.READ)
		if f:
			return f.get_as_text().strip_edges()
	return ""


func _set_status(text: String, good: bool = false) -> void:
	status.text = text
	status.modulate = Color(0.7, 1, 0.7) if good else Color(1, 0.75, 0.55)


func _set_busy(b: bool) -> void:
	for x in busy_buttons:
		x.disabled = b


func _go(mode: String) -> void:
	if waiting:
		return
	var addr := server_edit.text.strip_edges()
	var user := user_edit.text.strip_edges()
	if addr == "":
		_set_status("Indique l'adresse du serveur, ou joue hors ligne.")
		return
	if user.length() < 3:
		_set_status("Le nom du détenu doit faire au moins 3 caractères.")
		return
	if pass_edit.text.length() < 6:
		_set_status("Le mot de passe doit faire au moins 6 caractères.")
		return
	GameState.server_address = addr
	GameState.save_server()
	pending_mode = mode
	waiting = true
	wait_time = 0.0
	_set_busy(true)
	if Net.is_connected_to_server():
		_set_status("Vérification…", true)
		Net.send_auth(mode, user, pass_edit.text)
	else:
		_set_status("Connexion au serveur…", true)
		Net.disconnect_from_server()
		Net.connect_to(addr)
		if Net.failed:
			waiting = false
			_set_busy(false)
			_set_status("Adresse invalide.")


func _process(delta: float) -> void:
	if waiting:
		wait_time += delta
		if wait_time > 12.0:
			waiting = false
			_set_busy(false)
			Net.disconnect_from_server()
			_set_status("Le serveur ne répond pas. Vérifie l'adresse et que le serveur est lancé.")


func _on_connected() -> void:
	if waiting:
		_set_status("Vérification…", true)
		Net.send_auth(pending_mode, user_edit.text.strip_edges(), pass_edit.text)


func _on_auth(ok: bool, msg: String, payload: Dictionary) -> void:
	waiting = false
	_set_busy(false)
	if not ok:
		_set_status(msg)
		return
	var f := FileAccess.open(LAST_USER_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(payload["user"]))
	var data: Dictionary = payload["data"]
	if GameState.data_has_character(data):
		GameState.import_data(data)
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		GameState.ap["name"] = str(payload["user"])
		get_tree().change_scene_to_file("res://creator.tscn")


func _on_lost() -> void:
	if waiting:
		waiting = false
		_set_busy(false)
		_set_status("Connexion impossible : serveur injoignable ou trop d'essais ratés.")
	else:
		_set_status("Connexion au serveur perdue.")


func _offline(new_character: bool) -> void:
	Net.disconnect_from_server()
	if not new_character and GameState.has_saved_character():
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://creator.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
