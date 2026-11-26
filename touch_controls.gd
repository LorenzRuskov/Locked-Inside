extends Control

# Joystick flottant (moitié gauche de l'écran) + bouton AGIR (bas droite).
# Sur ordinateur : touche T pour afficher/masquer, la souris simule le doigt.

var ui := 1.0                 # facteur d'échelle de l'interface (plus grand sur téléphone)
var STICK_RADIUS := 90.0
var BUTTON_RADIUS := 64.0

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var button_id := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
	resized.connect(queue_redraw)


func set_ui(k: float) -> void:
	ui = k
	STICK_RADIUS = 90.0 * k
	BUTTON_RADIUS = 64.0 * k
	queue_redraw()


# Marge de sécurité : encoches, coins arrondis et barre de gestes des téléphones
func _safe() -> Rect2:
	var sa := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if sa.size.x <= 0 or win.x <= 0 or not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, size)
	var kx := size.x / float(win.x)
	var ky := size.y / float(win.y)
	return Rect2(Vector2(sa.position.x * kx, sa.position.y * ky), Vector2(sa.size.x * kx, sa.size.y * ky))


func _button_center() -> Vector2:
	var sf := _safe()
	return Vector2(sf.end.x - BUTTON_RADIUS - 70.0, sf.end.y - BUTTON_RADIUS - 62.0)


func _rest_stick() -> Vector2:
	var sf := _safe()
	return Vector2(sf.position.x + STICK_RADIUS + 70.0, sf.end.y - STICK_RADIUS - 56.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		visible = not visible
		_release_all()
		return
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if button_id == -1 and event.position.distance_to(_button_center()) <= BUTTON_RADIUS * 1.3:
				button_id = event.index
				Input.action_press("interact")
			elif stick_id == -1 and event.position.x < size.x * 0.5:
				stick_id = event.index
				stick_origin = event.position
				stick_pos = event.position
				_update_stick()
		else:
			if event.index == button_id:
				button_id = -1
				Input.action_release("interact")
			elif event.index == stick_id:
				stick_id = -1
				_release_move()
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_pos = event.position
			_update_stick()
			queue_redraw()


func _axis(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _update_stick() -> void:
	var v := (stick_pos - stick_origin) / STICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_axis("move_right", maxf(v.x, 0.0))
	_axis("move_left", maxf(-v.x, 0.0))
	_axis("move_down", maxf(v.y, 0.0))
	_axis("move_up", maxf(-v.y, 0.0))


func _release_move() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _release_all() -> void:
	stick_id = -1
	button_id = -1
	_release_move()
	Input.action_release("interact")
	queue_redraw()


func _draw() -> void:
	var active := stick_id != -1
	var base := stick_origin if active else _rest_stick()
	var knob := base
	if active:
		knob = base + (stick_pos - base).limit_length(STICK_RADIUS)
	var a := 0.35 if active else 0.18
	draw_circle(base, STICK_RADIUS, Color(1, 1, 1, a * 0.5))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, a + 0.1), 3.0)
	draw_circle(knob, 38.0 * ui, Color(1, 1, 1, a + 0.15))

	var bc := _button_center()
	var pressed := button_id != -1
	draw_circle(bc, BUTTON_RADIUS, Color(0.88, 0.48, 0.12, 0.7 if pressed else 0.4))
	draw_arc(bc, BUTTON_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)
	draw_string(ThemeDB.fallback_font, bc + Vector2(-40.0 * ui, 9.0 * ui), "AGIR", HORIZONTAL_ALIGNMENT_CENTER, 80.0 * ui, int(24.0 * ui), Color(1, 1, 1, 0.9))
