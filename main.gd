extends Node2D

const BackdropScript := preload("res://backdrop.gd")
const PropScript := preload("res://prop.gd")
const PlayerScript := preload("res://player.gd")
const TouchScript := preload("res://touch_controls.gd")
const EmissiveScript := preload("res://emissive.gd")
const RemoteScript := preload("res://remote_player.gd")
const GuardScript := preload("res://guard.gd")
const Rooms := preload("res://rooms.gd")
const Actions := preload("res://actions.gd")

const MSG_TIME := 3.5

var room_id := "cell"
var camera: Camera2D
var cam_follow := false
var room: Dictionary = {}
var floor_rect := Rect2()
var wall_h := 120.0

var player
var emissive
var props: Array = []
var guards: Array = []
var guard_watch := 0.0      # temps passé près d'un gardien avec de la contrebande
var guard_cooldown := 0.0
var remotes := {}
var lamp_lights: Array = []

var panel: PanelContainer
var label: Label
var touch: Control
var ui := 1.0            # échelle de l'interface : 1 sur ordinateur, plus grand au tactile
var help_label: Label
var title_node: Label
var stats_label: Label
var dossier_label: Label
var mitard_label: Label
var fade: ColorRect
var menu_panel: PanelContainer
var menu_box: VBoxContainer

var menu_open := false
var menu_options: Array = []
var menu_prop = null
var transitioning := false
var arrived_by_door := false
var msg_timer := 0.0
var net_timer := 0.0
var hud_timer := 0.0
var pending_back := ""   # phrase de restitution si la peine a été purgée hors jeu


func _ready() -> void:
	y_sort_enabled = true
	# Peine purgée pendant que le jeu était fermé : on rend les médicaments
	var back := GameState.settle_mitard()
	if back != "":
		pending_back = back
		GameState.flash = "Ta peine d'isolement est purgée." + back
	# Une sanction en cours ramène toujours au mitard
	if GameState.mitard_active():
		GameState.room = "mitard"
	GameState.room = Rooms.canon(GameState.room)   # l'ancien « couloir » est devenu la salle commune
	room_id = GameState.room
	room = Rooms.get_room(room_id)
	floor_rect = room["floor"]
	wall_h = float(room["wall_h"])
	_setup_inputs()
	_build_backdrop()
	_build_walls()
	_add_props()
	_add_guards()
	_add_player()
	_add_camera()
	_build_lighting()
	_build_hud()
	_setup_net()
	Net.send_room(room_id)
	GameState.prev_room = ""
	_fade_in()
	if GameState.flash != "":
		show_msg(GameState.flash, 4.5)
		GameState.flash = ""


func _setup_inputs() -> void:
	# Touches physiques : W/A/S/D = Z/Q/S/D sur un clavier AZERTY
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
			for key in actions[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


func _build_backdrop() -> void:
	# Décor fixe : dessiné une fois dans une texture (léger pour un téléphone)
	var xs: Array = []
	for lp in room["lamps"]:
		xs.append(float(lp["x"]))
	BackdropScript.bake(self, floor_rect, wall_h, room["theme"], xs)
	emissive = EmissiveScript.new()
	emissive.floor_rect = floor_rect
	emissive.wall_h = wall_h
	emissive.window_on = bool(room["window"])
	emissive.lamps = room["lamps"]
	emissive.z_index = -90
	add_child(emissive)


func _build_walls() -> void:
	var f := floor_rect
	_wall(Rect2(f.position.x - 20, f.position.y - 40, f.size.x + 40, 40))
	_wall(Rect2(f.position.x - 20, f.position.y - 40, 20, f.size.y + 80))
	_wall(Rect2(f.end.x, f.position.y - 40, 20, f.size.y + 80))
	_wall(Rect2(f.position.x - 20, f.end.y, f.size.x + 40, 20))


func _wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size / 2.0
	body.add_child(shape)
	add_child(body)


func _add_props() -> void:
	var list: Array = room["props"]
	for d in list:
		var pd: Dictionary = d
		var p = PropScript.new()
		var pos: Vector2 = pd["pos"]
		p.setup(str(pd["kind"]), pos, float(pd["w"]), float(pd["d"]), float(pd["h"]), str(pd["hint"]), str(pd["msg"]), bool(pd["solid"]))
		p.menu = pd["menu"]
		var extra: Dictionary = pd["extra"]
		if extra.has("label"):
			p.label = str(extra["label"])
		if extra.has("col"):
			p.col = extra["col"]
		add_child(p)
		props.append(p)


# Gardiens qui patrouillent (définis par pièce)
func _add_guards() -> void:
	for gd in room.get("guards", []):
		var d: Dictionary = gd
		var g = GuardScript.new()
		g.setup(str(d["name"]), d["path"], float(d["speed"]), float(d["phase"]), GuardScript.appearance(str(d["name"])))
		g.title = str(d.get("title", "Gardien"))
		g.is_guard = bool(d.get("guard", true))
		g.menu = d.get("menu", [])
		add_child(g)
		guards.append(g)


# Un gardien qui reste collé à un détenu en possession de médicaments volés le fouille
func _check_contraband(delta: float) -> void:
	if guard_cooldown > 0.0:
		guard_cooldown -= delta
		return
	if GameState.meds <= 0:
		guard_watch = 0.0
		return
	var close = null
	for g in guards:
		if g.is_guard and player.position.distance_to(g.position) < 110.0:
			close = g
			break
	if close == null:
		guard_watch = maxf(0.0, guard_watch - delta)
		return
	guard_watch += delta
	if guard_watch < 2.0:
		return
	guard_watch = 0.0
	guard_cooldown = 45.0
	var info: Dictionary = {}
	for cand in Actions.GUARDS:
		if str(cand["name"]) == str(close.guard_name):
			info = cand
	var who := "Le gardien " + str(close.guard_name)
	var meds := GameState.meds
	if int(info.get("integrite", 50)) < 30 and GameState.cigs >= 5:
		GameState.cigs -= 5
		GameState.add_rep("gardiens", 1)
		show_msg(who + " te fouille du regard, puis tend la main. 5 cigarettes plus tard, il regarde ailleurs. Tu gardes tes médicaments.", 6.0)
	elif int(info.get("sadisme", 0)) > 70:
		GameState.meds = 0
		GameState.pv = maxi(5, GameState.pv - 8)
		GameState.add_rep("gardiens", -3)
		show_msg(who + " te plaque au mur et te fouille sans ménagement. Médicaments confisqués (%d). PV -8." % meds, 6.0)
	else:
		GameState.meds = 0
		GameState.add_rep("gardiens", -2)
		show_msg(who + " te fouille et confisque tes médicaments (%d). « Je n'ai rien vu, tu n'as rien dit. »" % meds, 6.0)
	refresh_hud()


# Texte affiché pour les éléments dont le message change (lit, porte du mitard)
func resolve_msg(msg: String) -> String:
	if msg == "@bunk":
		var text := "Ton lit. Le matelas est plus fin que ta patience."
		var item := str(GameState.story["item"])
		if item != "":
			text += " Sous le matelas, ta cachette : " + item.to_lower() + "."
		return text
	if msg == "@mitard":
		var left := GameState.mitard_left()
		return "Porte blindée. Encore %d:%02d d'isolement. Gardien de service : %s." % [floori(left / 60.0), int(ceil(left)) % 60, str(Actions.guard_on_duty()["name"])]
	return msg


func _slot_spawn(slot_i: int) -> Vector2:
	var s: Array = room["spawns"]
	return s[mini(slot_i, s.size() - 1)]


func _spawn_point() -> Vector2:
	var arrive: Dictionary = room["arrive"]
	if GameState.prev_room != "" and arrive.has(GameState.prev_room):
		arrived_by_door = true
		return arrive[GameState.prev_room]
	return _slot_spawn(Net.slot if Net.online else 0)


func _add_player() -> void:
	player = PlayerScript.new()
	player.position = _spawn_point()
	add_child(player)


func _add_camera() -> void:
	var f := floor_rect
	var cam := Camera2D.new()
	cam.position = Vector2(f.position.x + f.size.x / 2.0, f.position.y + f.size.y / 2.0 - wall_h * 0.4)
	var vps := get_viewport_rect().size
	var z := minf(1.6, minf((vps.x - 100.0) / (f.size.x + 80.0), (vps.y - 40.0) / (wall_h + f.size.y + 40.0)))
	cam_follow = bool(room.get("follow", false))
	if cam_follow:
		z = float(room.get("zoom", 1.3))
	cam.zoom = Vector2(z, z)
	add_child(cam)
	cam.make_current()
	camera = cam
	if cam_follow:
		_follow_camera(1.0)


# Caméra qui suit le détenu dans les pièces plus larges que l'écran (bloquée aux murs)
func _follow_camera(k: float) -> void:
	if camera == null or player == null:
		return
	var f := floor_rect
	var view_w := get_viewport_rect().size.x / camera.zoom.x
	var half := view_w / 2.0
	var lo := f.position.x - 30.0 + half
	var hi := f.end.x + 30.0 - half
	var tx := (f.position.x + f.size.x / 2.0) if lo >= hi else clampf(player.position.x, lo, hi)
	var ty := f.position.y + f.size.y / 2.0 - wall_h * 0.4
	camera.position = camera.position.lerp(Vector2(tx, ty), clampf(k, 0.0, 1.0))


func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _add_light(pos: Vector2, col: Color, energy: float, radius: float, tex: Texture2D) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.position = pos
	l.color = col
	l.energy = energy
	l.texture_scale = radius / 128.0
	add_child(l)
	return l


func _build_lighting() -> void:
	var cm := CanvasModulate.new()
	cm.color = room["ambient"]
	add_child(cm)
	var tex := _light_texture()
	var lamps: Array = room["lamps"]
	for i in range(lamps.size()):
		var l: Dictionary = lamps[i]
		var lc: Color = l["color"]
		lamp_lights.append(_add_light(emissive.lamp_light_pos(i), lc, float(l["energy"]), float(l["radius"]), tex))
	if emissive.window_on:
		var wl: Dictionary = room["window_light"]
		_add_light(emissive.window_rect().get_center(), Color(0.7, 0.82, 1.0), float(wl["energy"]), float(wl["radius"]), tex)
	var extras: Array = room["extra_lights"]
	for e in extras:
		var ed: Dictionary = e
		var ec: Color = ed["color"]
		var epos: Vector2 = ed["pos"]
		_add_light(epos, ec, float(ed["energy"]), float(ed["radius"]), tex)


func _build_hud() -> void:
	var touch_mode := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
	ui = 1.3 if touch_mode else 1.0
	# Vignette (assombrit les bords de l'écran)
	var vl := CanvasLayer.new()
	vl.layer = 1
	add_child(vl)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.85;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = dot(uv, uv);\n\tfloat v = smoothstep(0.05, 0.42, d);\n\tCOLOR = vec4(0.0, 0.0, 0.0, v * strength);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", float(room["vignette"]))
	var vr := ColorRect.new()
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vr.material = mat
	vl.add_child(vr)
	vr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	title_node = Label.new()
	title_node.position = Vector2(16, 10)
	title_node.add_theme_font_size_override("font_size", int(20 * ui))
	layer.add_child(title_node)

	stats_label = Label.new()
	stats_label.position = Vector2(16, 10 + 28 * ui)
	stats_label.add_theme_font_size_override("font_size", int(16 * ui))
	layer.add_child(stats_label)

	var help := Label.new()
	help.text = "ZQSD / flèches : bouger   ·   E : interagir   ·   Échap : quitter"
	help.position = Vector2(16, 64)
	help.add_theme_font_size_override("font_size", 14)
	help.modulate = Color(1, 1, 1, 0.6)
	layer.add_child(help)

	mitard_label = Label.new()
	mitard_label.position = Vector2(16, 88 if ui == 1.0 else 10 + 28 * ui + 30 * ui)
	mitard_label.add_theme_font_size_override("font_size", int(18 * ui))
	mitard_label.modulate = Color(1.0, 0.5, 0.4)
	layer.add_child(mitard_label)

	dossier_label = Label.new()
	dossier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dossier_label.add_theme_font_size_override("font_size", int(16 * (1.0 if ui == 1.0 else 1.05)))
	dossier_label.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(dossier_label)
	dossier_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dossier_label.offset_left = -560.0
	dossier_label.offset_right = -16.0
	dossier_label.offset_top = 12.0
	dossier_label.offset_bottom = 110.0

	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.78)
	sb.set_content_margin_all(12)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	label = Label.new()
	label.add_theme_font_size_override("font_size", int(20 * ui))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	panel.add_child(label)
	layer.add_child(panel)
	panel.visible = false
	panel.resized.connect(_layout_ui)

	# Menu d'actions (clic / toucher, ou touches 1-9)
	menu_panel = PanelContainer.new()
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	mb.set_content_margin_all(14)
	mb.set_corner_radius_all(8)
	mb.border_color = Color(1, 1, 1, 0.25)
	mb.set_border_width_all(1)
	menu_panel.add_theme_stylebox_override("panel", mb)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_box)
	layer.add_child(menu_panel)
	menu_panel.visible = false
	menu_panel.resized.connect(_layout_ui)

	touch = TouchScript.new()
	layer.add_child(touch)
	touch.set_ui(ui)
	get_viewport().size_changed.connect(_layout_ui)
	help.visible = not touch.visible

	var fl := CanvasLayer.new()
	fl.layer = 5
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_update_title()
	refresh_hud()
	_layout_ui()


# Place le bandeau de message et le menu selon la taille réelle de l'écran
# (les téléphones modernes sont plus larges que 16:9)
func _layout_ui() -> void:
	if panel == null or menu_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var side := 270.0 * ui   # largeur réservée au joystick et au bouton AGIR
	label.custom_minimum_size.x = clampf(vp.x - 2.0 * side, 360.0, 820.0 * ui)
	panel.position = Vector2((vp.x - panel.size.x) / 2.0, vp.y - panel.size.y - 34.0)
	menu_panel.position = Vector2((vp.x - menu_panel.size.x) / 2.0, maxf(8.0, (vp.y - menu_panel.size.y) / 2.0 - 10.0))


func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.35)


func refresh_hud() -> void:
	GameState.tick_pa()
	if ui > 1.0:
		stats_label.text = "PV %d  ·  Mental %d  ·  PA %d/%d  ·  Cig. %d  ·  Méd. %d" % [
			GameState.pv, GameState.mental, GameState.pa, GameState.PA_MAX, GameState.cigs, GameState.meds]
	else:
		stats_label.text = "PV %d/100  ·  Mental %d/100  ·  PA %d/%d  ·  Cigarettes %d  ·  Médicaments %d" % [
			GameState.pv, GameState.mental, GameState.pa, GameState.PA_MAX, GameState.cigs, GameState.meds]
	dossier_label.text = GameState.dossier_text()
	if GameState.mitard_active():
		var left := GameState.mitard_left()
		mitard_label.text = "ISOLEMENT  %d:%02d" % [floori(left / 60.0), int(ceil(left)) % 60]
	else:
		mitard_label.text = ""


func _update_title() -> void:
	if title_node == null:
		return
	var where: String = str(room["title"])
	if room_id == "cell":
		where = "Cellule " + GameState.cell_label()
		if Net.online:
			if Net.entered:
				where += " · %d/2 détenus" % Net.cell_members.size()
			else:
				where = "Connexion…"
		elif Net.failed:
			where += " · hors ligne"
	elif room_id == "allee" and Net.entered:
		where += " · %d détenus ici" % (1 + remotes.size())
	elif Net.entered and room_id != "mitard":
		where += " · %d détenus ici" % (1 + remotes.size())
	if ui > 1.0:
		title_node.text = where   # écran de téléphone : on garde l'essentiel
	else:
		title_node.text = "LOCKED INSIDE — " + str(GameState.ap["name"]) + " · " + where


func show_msg(text: String, duration: float = MSG_TIME) -> void:
	label.text = text
	msg_timer = duration
	panel.visible = text != ""
	refresh_hud()


# Change de pièce : fondu au noir puis rechargement de la scène avec la nouvelle pièce
func go_room(target: String) -> void:
	if transitioning:
		return
	transitioning = true
	GameState.prev_room = room_id
	GameState.room = target
	GameState.save_progress()
	player.frozen = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func(): get_tree().reload_current_scene())


# ---------------- Multijoueur ----------------

func _setup_net() -> void:
	Net.joined.connect(_on_joined)
	Net.cell_updated.connect(_update_title)
	Net.peers_list.connect(_on_peers_list)
	Net.peer_enter.connect(_on_peer_enter)
	Net.peer_leave.connect(_on_peer_leave)
	Net.peer_pos.connect(_on_peer_pos)
	Net.lost.connect(_on_net_lost)
	if Net.entered:
		_on_joined(Net.cell_id, Net.slot)
	else:
		Net.enter()


func _add_remote(id: int, ap: Dictionary) -> void:
	if remotes.has(id):
		return
	var r = RemoteScript.new()
	r.setup(ap, Vector2.ZERO)
	add_child(r)
	remotes[id] = r
	_update_title()


func _on_joined(_cid: int, slot_i: int) -> void:
	if room_id == "cell" and not arrived_by_door:
		player.position = _slot_spawn(slot_i)
	Net.send_room(room_id)
	_update_title()


func _on_peers_list(list: Array) -> void:
	for e in list:
		var d: Dictionary = e
		_add_remote(int(d["id"]), d["ap"])


func _on_peer_enter(id: int, ap: Dictionary) -> void:
	_add_remote(id, ap)


func _on_peer_leave(id: int) -> void:
	if remotes.has(id):
		remotes[id].queue_free()
		remotes.erase(id)
	_update_title()


func _on_peer_pos(id: int, pos: Vector2, moving: bool, look: float) -> void:
	if remotes.has(id):
		remotes[id].set_target(pos, moving, look)


func _on_net_lost() -> void:
	for id in remotes.keys():
		remotes[id].queue_free()
	remotes.clear()
	_update_title()


# ---------------- Menu d'actions ----------------

func _interact(p) -> void:
	var menu: Array = p.menu
	var opts: Array = []
	for m in menu:
		opts.append(m)
	if menu.size() > 0 and str(p.interact_msg) != "":
		opts.append({"id": "examine", "arg": "", "label": ""})
	if opts.is_empty():
		show_msg(resolve_msg(str(p.interact_msg)))
		return
	if opts.size() == 1:
		menu_prop = p
		_run_option(opts[0])
		return
	_open_menu(str(p.interact_hint), opts, p)


func _open_menu(title: String, opts: Array, p) -> void:
	menu_open = true
	menu_prop = p
	menu_options = opts
	player.frozen = true
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", int(22 * ui))
	menu_box.add_child(t)
	for i in range(opts.size()):
		var o: Dictionary = opts[i]
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, Actions.label(str(o["id"]), str(o.get("label", "")))]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(440.0 * ui, 46.0 * ui)
		b.add_theme_font_size_override("font_size", int(18 * ui))
		b.pressed.connect(_choose.bind(i))
		menu_box.add_child(b)
	var close := Button.new()
	close.text = "Fermer (Échap)"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(440.0 * ui, 40.0 * ui)
	close.add_theme_font_size_override("font_size", int(16 * ui))
	close.pressed.connect(_close_menu)
	menu_box.add_child(close)
	menu_panel.visible = true
	panel.visible = false


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	if player and not transitioning:
		player.frozen = false


func _choose(i: int) -> void:
	if i < 0 or i >= menu_options.size():
		return
	var o: Dictionary = menu_options[i]
	_close_menu()
	_run_option(o)


func _run_option(o: Dictionary) -> void:
	var msg: String = Actions.run(str(o["id"]), str(o.get("arg", "")), menu_prop, self)
	if msg != "":
		show_msg(msg)


# ---------------- Boucle ----------------

func _process(delta: float) -> void:
	if cam_follow:
		_follow_camera(minf(1.0, delta * 6.0))
	for i in range(lamp_lights.size()):
		var pl: PointLight2D = lamp_lights[i]
		var l: Dictionary = room["lamps"][i]
		pl.position = emissive.lamp_light_pos(i)
		var base := float(l["energy"])
		pl.energy = base * emissive.flicker(i) * (1.0 + sin(Time.get_ticks_msec() * 0.013) * 0.04 + randf_range(-0.04, 0.04))

	hud_timer += delta
	if hud_timer >= 1.0:
		hud_timer = 0.0
		if GameState.mitard_active():
			GameState.tick_mitard()
		refresh_hud()

	if room_id == "mitard" and not GameState.mitard_active() and not transitioning:
		GameState.flash = "La porte s'ouvre. Un gardien te ramène en cellule." + GameState.settle_mitard() + pending_back
		go_room("cell")

	if Net.can_send():
		net_timer += delta
		if net_timer >= 0.066:
			net_timer = 0.0
			Net.srv_pos.rpc_id(1, player.position, player.moving, player.look)

	if menu_open or transitioning:
		return

	var nearest = null
	var best := INF
	for p in props:
		var c: Vector2 = p.position + Vector2(0, -p.d / 2.0)
		var dist: float = player.position.distance_to(c)
		var reach: float = maxf(p.w, p.d) / 2.0 + 60.0
		if dist < reach and dist < best:
			best = dist
			nearest = p
	var mate_id := -1
	for id in remotes:
		var dm: float = player.position.distance_to(remotes[id].position)
		if dm < 90.0 and dm < best:
			best = dm
			mate_id = id
			nearest = null

	_check_contraband(delta)

	var guard_near = null
	for g in guards:
		var dg: float = player.position.distance_to(g.position)
		if not g.is_guard:
			dg -= 45.0   # le personnel civil (infirmière) passe avant le meuble devant lequel il se tient
		if dg < 100.0 and dg < best:
			best = dg
			guard_near = g
			nearest = null
			mate_id = -1

	if msg_timer > 0.0:
		msg_timer -= delta

	if Input.is_action_just_pressed("interact"):
		if guard_near != null:
			var opts: Array = guard_near.menu
			if opts.is_empty():
				opts = [
					{"id": "observe", "arg": str(guard_near.guard_name), "label": ""},
					{"id": "provoke", "arg": str(guard_near.guard_name), "label": ""},
				]
			_open_menu(str(guard_near.title) + " " + str(guard_near.guard_name), opts, null)
			return
		if mate_id >= 0:
			var mate_name := str(remotes[mate_id].player_name)
			show_msg(Actions.run("talk", mate_name, null, self))
			return
		elif nearest != null:
			_interact(nearest)
			return

	if msg_timer <= 0.0:
		if guard_near != null:
			label.text = ("AGIR : " if touch.visible else "[E] ") + str(guard_near.title) + " " + str(guard_near.guard_name)
		elif mate_id >= 0:
			label.text = ("AGIR : " if touch.visible else "[E] ") + "Parler à " + str(remotes[mate_id].player_name)
		elif nearest == null:
			label.text = ""
		elif touch.visible:
			label.text = "AGIR : " + nearest.interact_hint
		else:
			label.text = "[E] " + nearest.interact_hint
	panel.visible = label.text != ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if menu_open:
				_close_menu()
			else:
				_quit_game()
		elif menu_open and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			_choose(event.physical_keycode - KEY_1)


# Quitte en envoyant d'abord la sauvegarde au serveur
func _quit_game() -> void:
	GameState.save_progress()
	Net.flush_save()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
