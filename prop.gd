extends Node2D

# Origine du noeud = milieu du bord avant, au sol.
# w = largeur, d = profondeur au sol, h = hauteur de la face avant.

var kind := ""
var w := 100.0
var d := 50.0
var h := 40.0
var interact_hint := ""
var interact_msg := ""
var menu: Array = []
var label := ""
var col := Color("#4a4f56")


func setup(p_kind: String, p_pos: Vector2, p_w: float, p_d: float, p_h: float, hint: String, msg: String, solid := true) -> void:
	kind = p_kind
	position = p_pos
	w = p_w
	d = p_d
	h = p_h
	interact_hint = hint
	interact_msg = msg
	if kind == "mat":
		z_index = -5   # tapis posé au sol : toujours sous le détenu
	if solid:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, d)
		shape.shape = rect
		shape.position = Vector2(0, -d / 2.0)
		body.add_child(shape)
		add_child(body)
	queue_redraw()


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _box(top_col: Color, front_col: Color, edge: Color) -> void:
	var front := Rect2(-w / 2.0, -h, w, h)
	var top := Rect2(-w / 2.0, -h - d, w, d)
	draw_rect(front, front_col)
	draw_rect(top, top_col)
	draw_rect(Rect2(front.position.x, front.end.y - h * 0.3, w, h * 0.3), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(front.end.x - w * 0.1, front.position.y, w * 0.1, h), Color(0, 0, 0, 0.12))
	draw_rect(Rect2(top.position.x, top.position.y, w, 2.0), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(top.position.x, top.end.y - 1.5, w, 1.5), Color(1, 1, 1, 0.10))
	draw_rect(front, edge, false, 1.5)
	draw_rect(top, edge, false, 1.5)


func _draw() -> void:
	if kind != "door" and kind != "mat" and kind != "board":
		for i in range(4):
			var g := float(i)
			draw_rect(Rect2(-w / 2.0 - 4.0 - g * 2.0, -d - g, w + 8.0 + g * 4.0, d + 6.0 + g * 2.0), Color(0, 0, 0, 0.07))
	match kind:
		"bunk":
			_draw_bunk()
		"toilet":
			_draw_toilet()
		"desk":
			_draw_desk()
		"locker":
			_draw_locker()
		"door":
			_draw_door()
		"guard_desk":
			_draw_guard_desk()
		"bench":
			_draw_bench()
		"board":
			_draw_board()
		"medbed":
			_draw_medbed()
		"cabinet":
			_draw_cabinet()
		"nurse_desk":
			_draw_nurse_desk()
		"workbench":
			_draw_workbench()
		"crates":
			_draw_crates()
		"weights":
			_draw_weights()
		"hoop":
			_draw_hoop()
		"slab":
			_draw_slab()
		"mat":
			_draw_mat()
		"mess_table":
			_draw_mess_table()
		"counter":
			_draw_counter()
		"tv":
			_draw_tv()
		"booth":
			_draw_booth()
		"filing":
			_draw_filing()
		"reception":
			_draw_reception()
		"gate":
			_draw_gate()
		"sofa":
			_draw_sofa()
		"phone":
			_draw_phone()


func _draw_bunk() -> void:
	_box(Color("#5b7fae"), Color("#3a3f4a"), Color("#1f2229"))
	var frame := Color("#2e333a")
	draw_rect(Rect2(-w / 2.0, -h, 6, h), frame)
	draw_rect(Rect2(w / 2.0 - 6, -h, 6, h), frame)
	draw_rect(Rect2(-w / 2.0 + 1, -h, 1.5, h), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(-w / 2.0 + 8, -h * 0.5, w - 16, 13), Color("#566f93"))
	draw_rect(Rect2(-w / 2.0 + 8, -h * 0.5, w - 16, 13), Color("#1f2229"), false, 1.0)
	draw_rect(Rect2(-w / 2.0 + 8, -h * 0.5 + 13, w - 16, 4), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-w / 2.0 + 60, -h - d + 5, w - 68, d - 10), Color("#4a6a97"))
	draw_line(Vector2(-w / 2.0 + 60, -h - d + 5), Vector2(-w / 2.0 + 60, -h - 5), Color(0, 0, 0, 0.3), 2.0)
	for k in range(4):
		var sx := -w / 2.0 + 75.0 + k * 26.0
		draw_line(Vector2(sx, -h - d + 9), Vector2(sx, -h - 9), Color(1, 1, 1, 0.08), 1.0)
	_ell(Vector2(-w / 2.0 + 34, -h - d / 2.0 + 3), 22, 14, Color(0, 0, 0, 0.18))
	_ell(Vector2(-w / 2.0 + 34, -h - d / 2.0), 22, 14, Color("#e8e6df"))
	_ell(Vector2(-w / 2.0 + 30, -h - d / 2.0 - 3), 12, 6, Color(1, 1, 1, 0.35))
	var lx := w / 2.0 - 18.0
	draw_line(Vector2(lx, -h), Vector2(lx, 0), Color("#8a8f98"), 3.0)
	draw_line(Vector2(lx + 12, -h), Vector2(lx + 12, 0), Color("#8a8f98"), 3.0)
	for r in range(1, 4):
		var ry := -h + r * (h / 4.0)
		draw_line(Vector2(lx, ry), Vector2(lx + 12, ry), Color("#8a8f98"), 2.0)


func _draw_toilet() -> void:
	_box(Color("#b9bec2"), Color("#8e959b"), Color("#4f565c"))
	_ell(Vector2(-w * 0.12, -h - d * 0.5), 11, 8, Color("#3a3f44"))
	_ell(Vector2(-w * 0.12, -h - d * 0.5), 8, 5.5, Color("#5d7280"))
	_ell(Vector2(w * 0.28, -h - d * 0.5), 6, 4.5, Color("#6f777d"))
	draw_rect(Rect2(w * 0.28 - 1, -h - d + 3, 2, 5), Color("#d0d4d6"))
	draw_circle(Vector2(0, -h * 0.55), 3.0, Color("#c9ced1"))
	draw_arc(Vector2(0, -h * 0.55), 3.0, 0.0, TAU, 12, Color("#4f565c"), 1.0)


func _draw_desk() -> void:
	_box(Color("#96999a"), Color("#6f7273"), Color("#3d3f40"))
	for k in range(5):
		_ell(Vector2(-w * 0.4 + k * 28.0, -h - d * 0.6), 4, 2, Color(0, 0, 0, 0.06))
	draw_line(Vector2(-26, -h - 16), Vector2(-6, -h - 11), Color("#e5c24a"), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -h - 30), Vector2(32, -h - 32), Vector2(34, -h - 14), Vector2(8, -h - 12)]), Color("#e4dfd0"))
	for k in range(3):
		draw_line(Vector2(11, -h - 26 + k * 5.0), Vector2(29, -h - 28 + k * 5.0), Color(0, 0, 0, 0.25), 1.0)
	draw_rect(Rect2(-w * 0.4, -h - 28, 10, 12), Color("#8f979c"))
	draw_rect(Rect2(-w * 0.4, -h - 28, 10, 12), Color("#3d3f40"), false, 1.0)


func _draw_locker() -> void:
	_box(Color("#7d9487"), Color("#5d7567"), Color("#33463c"))
	for v in range(3):
		draw_line(Vector2(-18, -h + 12 + v * 7), Vector2(18, -h + 12 + v * 7), Color("#33463c"), 2.0)
	draw_line(Vector2(0, -h + 28), Vector2(0, -6), Color(0, 0, 0, 0.3), 1.5)
	for k in range(3):
		draw_rect(Rect2(-w / 2.0 + 2, -h + 30 + k * 18.0, 3, 8), Color("#2b2f2d"))
	draw_rect(Rect2(8, -h * 0.5, 6, 14), Color("#c9c9c9"))
	draw_rect(Rect2(10, -h * 0.5 + 12, 8, 9), Color("#c9a24a"))
	draw_rect(Rect2(10, -h * 0.5 + 12, 8, 9), Color("#4a3b12"), false, 1.0)
	_ell(Vector2(-14, -h * 0.35), 6, 4, Color(0, 0, 0, 0.12))


func _draw_door() -> void:
	var door := Rect2(-w / 2.0, -h, w, h)
	draw_rect(Rect2(door.position.x - 7, door.position.y - 7, door.size.x + 14, door.size.y + 7), Color("#2a2c30"))
	draw_rect(door, col)
	draw_rect(Rect2(door.position.x, door.position.y, 6, h), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(door.end.x - 10, door.position.y, 10, h), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(door.position.x + 6, door.position.y + 8, w - 12, h * 0.42), Color(0, 0, 0, 0.10), false, 1.5)
	draw_rect(Rect2(door.position.x + 6, door.position.y + h * 0.55, w - 12, h * 0.38), Color(0, 0, 0, 0.10), false, 1.5)
	draw_rect(Rect2(-13, -h + 22, 26, 12), Color("#15171b"))
	for k in range(-1, 2):
		draw_line(Vector2(k * 6.0, -h + 22), Vector2(k * 6.0, -h + 34), Color("#6a6f77"), 1.5)
	draw_rect(Rect2(-13, -h + 22, 26, 12), Color("#2a2c30"), false, 1.5)
	draw_rect(Rect2(-15, -h * 0.45, 30, 9), Color("#2f3338"))
	draw_rect(Rect2(-15, -h * 0.45, 30, 9), Color("#1b1d20"), false, 1.5)
	for k in range(3):
		draw_rect(Rect2(door.position.x - 3, door.position.y + 14 + k * 38.0, 5, 12), Color("#2a2c30"))
	for gx in range(-1, 2):
		for gy in range(0, 3):
			draw_circle(Vector2(door.position.x + 14 + gx * 0.0 + (gx + 1) * 26.0, door.position.y + 48 + gy * 20.0), 1.2, Color(1, 1, 1, 0.18))
	draw_rect(Rect2(door.end.x - 22, -h * 0.5, 14, 22), Color("#2a2c30"))
	draw_circle(Vector2(door.end.x - 15, -h * 0.5 + 8), 3.0, Color("#b9bec2"))
	draw_circle(Vector2(0, -h + 8), 6.0, Color(0.9, 0.2, 0.2, 0.18))
	draw_circle(Vector2(0, -h + 8), 3.0, Color("#d33a3a"))
	if label != "":
		draw_rect(Rect2(-40, -h - 16, 80, 13), Color("#15171b"))
		draw_rect(Rect2(-40, -h - 16, 80, 13), Color("#6a6f77"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-40, -h - 6), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("#e8e2c0"))


func _draw_guard_desk() -> void:
	_box(Color("#7a6a52"), Color("#54472f"), Color("#2c2418"))
	draw_rect(Rect2(-w * 0.32, -h - d * 0.9 - 16, 30, 20), Color("#1d2630"))
	draw_rect(Rect2(-w * 0.32 + 3, -h - d * 0.9 - 13, 24, 14), Color("#3d7ea6"))
	draw_rect(Rect2(-w * 0.32 + 12, -h - d * 0.9 + 4, 6, 6), Color("#2a2d31"))
	draw_rect(Rect2(w * 0.2, -h - d * 0.7 - 8, 10, 14), Color("#15171b"))
	draw_line(Vector2(w * 0.2 + 8, -h - d * 0.7 - 8), Vector2(w * 0.2 + 12, -h - d * 0.7 - 20), Color("#15171b"), 1.5)
	_ell(Vector2(w * 0.05, -h - d * 0.45), 13, 6, Color("#1f2d4a"))
	draw_rect(Rect2(w * 0.05 - 7, -h - d * 0.45 - 6, 14, 5), Color("#26385c"))
	draw_circle(Vector2(w * 0.05, -h - d * 0.45 - 4), 2.0, Color("#c9a24a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.1, -h - d * 0.35), Vector2(w * 0.0, -h - d * 0.4), Vector2(w * 0.0, -h - d * 0.2), Vector2(-w * 0.1, -h - d * 0.15)]), Color("#e4dfd0"))


func _draw_bench() -> void:
	_box(Color("#8d9196"), Color("#5e6268"), Color("#2e3236"))
	draw_rect(Rect2(-w / 2.0 + 6, -h, 6, h), Color("#3a3d42"))
	draw_rect(Rect2(w / 2.0 - 12, -h, 6, h), Color("#3a3d42"))
	for k in range(5):
		draw_line(Vector2(-w / 2.0 + 8 + k * (w - 16.0) / 4.0, -h - d + 3), Vector2(-w / 2.0 + 8 + k * (w - 16.0) / 4.0, -h - 3), Color(0, 0, 0, 0.10), 1.0)


func _draw_board() -> void:
	var r := Rect2(-w / 2.0, -h - 18, w, h)
	draw_rect(Rect2(r.position.x - 3, r.position.y - 3, r.size.x + 6, r.size.y + 6), Color("#2a2c30"))
	draw_rect(r, Color("#a07a4f"))
	var papers := [Color("#e4dfd0"), Color("#d8d2bf"), Color("#e9e4d6"), Color("#cfc9b4")]
	for k in range(4):
		var px := r.position.x + 5.0 + k * (w - 10.0) / 4.0
		draw_rect(Rect2(px, r.position.y + 6 + (k % 2) * 10, 11, 17), papers[k])
		draw_circle(Vector2(px + 5, r.position.y + 8 + (k % 2) * 10), 1.4, Color("#b8342b"))
	draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)


func _draw_medbed() -> void:
	_box(Color("#e8efef"), Color("#b9c4c8"), Color("#6c7a80"))
	_ell(Vector2(-w / 2.0 + 24, -h - d / 2.0), 16, 11, Color("#f7f9f9"))
	draw_rect(Rect2(-w / 2.0 + 44, -h - d + 6, w - 52, d - 12), Color("#7fb2b0"))
	draw_line(Vector2(-w / 2.0 + 44, -h - d + 6), Vector2(-w / 2.0 + 44, -h - 6), Color(0, 0, 0, 0.2), 2.0)
	draw_rect(Rect2(-w / 2.0, -h - d, 4, d + h), Color("#8a979c"))
	draw_rect(Rect2(w / 2.0 - 4, -h - d, 4, d + h), Color("#8a979c"))


func _draw_cabinet() -> void:
	_box(Color("#cfd6d8"), Color("#9fb0b6"), Color("#566468"))
	for k in range(2):
		var gx := -w / 2.0 + 6.0 + k * (w - 12.0) / 2.0
		draw_rect(Rect2(gx, -h + 8, (w - 18.0) / 2.0, h * 0.62), Color(0.75, 0.88, 0.92, 0.55))
		draw_rect(Rect2(gx, -h + 8, (w - 18.0) / 2.0, h * 0.62), Color("#566468"), false, 1.0)
		for sh in range(3):
			var sy := -h + 20.0 + sh * 16.0
			draw_line(Vector2(gx, sy), Vector2(gx + (w - 18.0) / 2.0, sy), Color("#566468"), 1.0)
			draw_rect(Rect2(gx + 4, sy - 9, 8, 8), Color("#e8e2c0") if (sh + k) % 2 == 0 else Color("#b86b4a"))
			draw_rect(Rect2(gx + 16, sy - 7, 10, 6), Color("#6d9bb8"))
	draw_rect(Rect2(-3, -h * 0.28, 6, 8), Color("#c9a24a"))
	draw_rect(Rect2(-w / 2.0, -h * 0.2, w, h * 0.2), Color(0, 0, 0, 0.1))


func _draw_nurse_desk() -> void:
	_box(Color("#dfe5e6"), Color("#9aa7ab"), Color("#4c585c"))
	draw_rect(Rect2(-8, -h * 0.75, 16, 5), Color("#b8342b"))
	draw_rect(Rect2(-3, -h * 0.75 - 5.5, 6, 16), Color("#b8342b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.35, -h - d * 0.7), Vector2(-w * 0.1, -h - d * 0.75), Vector2(-w * 0.08, -h - d * 0.35), Vector2(-w * 0.33, -h - d * 0.3)]), Color("#f1eee2"))
	draw_rect(Rect2(w * 0.2, -h - d * 0.8, 12, 12), Color("#8f979c"))
	draw_rect(Rect2(w * 0.2 + 2, -h - d * 0.8 - 8, 3, 8), Color("#b8342b"))


func _draw_workbench() -> void:
	_box(Color("#6f757b"), Color("#454a50"), Color("#23262a"))
	var cloth := [Color("#3a6fc2"), Color("#e07a1f"), Color("#3a6fc2")]
	for k in range(3):
		draw_rect(Rect2(-w / 2.0 + 8 + k * 30.0, -h - d * 0.8 + k * 2.0, 24, 12), cloth[k])
		draw_rect(Rect2(-w / 2.0 + 8 + k * 30.0, -h - d * 0.8 + k * 2.0, 24, 12), Color(0, 0, 0, 0.25), false, 1.0)
	draw_rect(Rect2(w / 2.0 - 38, -h - d * 0.9 - 12, 26, 18), Color("#2f353b"))
	draw_rect(Rect2(w / 2.0 - 38, -h - d * 0.9 - 12, 26, 18), Color("#14171a"), false, 1.0)
	draw_line(Vector2(w / 2.0 - 14, -h - d * 0.9 - 10), Vector2(w / 2.0 - 6, -h - d * 0.5), Color("#8a8f98"), 2.0)
	draw_circle(Vector2(w / 2.0 - 28, -h - d * 0.9 - 4), 3.0, Color("#b8342b"))
	draw_rect(Rect2(-w / 2.0 + 6, -h * 0.55, w - 12, 8), Color(0, 0, 0, 0.18))


func _draw_crates() -> void:
	_box(Color("#a07f4f"), Color("#7e6038"), Color("#3f2e18"))
	for k in range(1, 3):
		draw_line(Vector2(-w / 2.0 + 2, -h * k / 3.0), Vector2(w / 2.0 - 2, -h * k / 3.0), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-w / 2.0 + 4, -h + 3), Vector2(w / 2.0 - 4, -3), Color(0, 0, 0, 0.18), 3.0)
	draw_rect(Rect2(-w * 0.28, -h - d + 8, w * 0.56, d - 16), Color("#3a6fc2"))
	draw_rect(Rect2(-w * 0.28, -h - d + 8, w * 0.56, d - 16), Color(0, 0, 0, 0.25), false, 1.0)


func _draw_weights() -> void:
	draw_rect(Rect2(-w * 0.34, -h * 0.5 - d, w * 0.68, d * 0.6), Color("#2c2f35"))
	draw_rect(Rect2(-w * 0.34, -h * 0.5 - d, w * 0.68, d * 0.6), Color("#14161a"), false, 1.5)
	draw_rect(Rect2(-w * 0.34, -h * 0.5 - d, w * 0.68, 3), Color(1, 1, 1, 0.15))
	for sx in [-0.3, 0.3]:
		draw_rect(Rect2(w * sx - 3, -h, 6, h * 0.5), Color("#4a4e55"))
		draw_rect(Rect2(w * sx - 3, -h * 0.5 - d * 0.4, 6, h * 0.5 + d * 0.4), Color("#4a4e55"))
	draw_line(Vector2(-w * 0.5, -h - 4), Vector2(w * 0.5, -h - 4), Color("#8a8f98"), 4.0)
	for sx in [-0.46, -0.38, 0.38, 0.46]:
		var ph := 22.0 - absf(sx) * 20.0
		draw_rect(Rect2(w * sx - 4, -h - 4 - ph / 2.0, 8, ph), Color("#2a2d31"))
		draw_rect(Rect2(w * sx - 4, -h - 4 - ph / 2.0, 8, ph), Color("#6a6f77"), false, 1.0)


func _draw_hoop() -> void:
	draw_rect(Rect2(-3, -h, 6, h), Color("#5a5e65"))
	draw_rect(Rect2(-3, -h, 2, h), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(-24, -h - 4, 48, 34), Color("#e4e6e8"))
	draw_rect(Rect2(-24, -h - 4, 48, 34), Color("#2a2d31"), false, 2.0)
	draw_rect(Rect2(-9, -h + 8, 18, 14), Color("#b8342b"), false, 2.0)
	_ell(Vector2(0, -h + 34), 15, 5, Color("#e07a1f"))
	_ell(Vector2(0, -h + 34), 12, 3.5, Color("#5a5e65"))
	for k in range(-2, 3):
		draw_line(Vector2(k * 5.0, -h + 35), Vector2(k * 3.0, -h + 48), Color(1, 1, 1, 0.5), 1.0)


func _draw_slab() -> void:
	_box(Color("#7b7d78"), Color("#555753"), Color("#2a2b28"))
	draw_rect(Rect2(-w / 2.0 + 10, -h - d + 8, w - 20, d - 16), Color("#6a6e6b"))
	draw_rect(Rect2(-w / 2.0 + 10, -h - d + 8, w - 20, d - 16), Color(0, 0, 0, 0.2), false, 1.0)
	_ell(Vector2(-w / 2.0 + 28, -h - d / 2.0), 14, 9, Color("#a9aba2"))


func _draw_mat() -> void:
	draw_rect(Rect2(-w / 2.0, -d, w, d), Color("#4b5a6b"))
	draw_rect(Rect2(-w / 2.0, -d, w, d), Color("#2a323b"), false, 2.0)
	draw_rect(Rect2(-w / 2.0 + 5, -d + 5, w - 10, d - 10), Color(1, 1, 1, 0.08), false, 1.0)


# ---------- Mobilier ajouté pour les nouvelles pièces ----------

func _draw_mess_table() -> void:
	_box(Color("#a3a7ac"), Color("#6b6f75"), Color("#34373b"))
	# deux bancs scellés et des plateaux
	draw_rect(Rect2(-w / 2.0 + 4, -h - d - 9, w - 8, 7), Color("#555a60"))
	draw_rect(Rect2(-w / 2.0 + 4, 3, w - 8, 7), Color("#555a60"))
	for k in range(3):
		var tx := -w / 2.0 + 14.0 + k * (w - 30.0) / 2.0
		draw_rect(Rect2(tx, -h - d * 0.8, 22, d * 0.55), Color("#c9c4b0"))
		draw_rect(Rect2(tx + 3, -h - d * 0.72, 7, d * 0.38), Color("#9a6a43"))
		draw_rect(Rect2(tx + 12, -h - d * 0.72, 7, d * 0.38), Color("#7a9a58"))


func _draw_counter() -> void:
	_box(Color("#c4c8cb"), Color("#8b9196"), Color("#40454a"))
	# bacs chauffants et pile de plateaux
	for k in range(3):
		var bx := -w / 2.0 + 12.0 + k * (w - 24.0) / 3.0
		draw_rect(Rect2(bx, -h - d * 0.85, (w - 30.0) / 3.0, d * 0.65), Color("#5c6268"))
		draw_rect(Rect2(bx + 3, -h - d * 0.8, (w - 30.0) / 3.0 - 6, d * 0.5), [Color("#8a6a3f"), Color("#6f8a49"), Color("#b0a58c")][k])
	draw_rect(Rect2(w / 2.0 - 30, -h - d * 0.95, 22, 12), Color("#d6d9db"))
	draw_rect(Rect2(w / 2.0 - 30, -h - d * 0.95, 22, 12), Color("#40454a"), false, 1.0)
	# vitre pare-haleine
	draw_rect(Rect2(-w / 2.0, -h - d - 26, w, 22), Color(0.75, 0.9, 0.95, 0.18))
	draw_rect(Rect2(-w / 2.0, -h - d - 26, w, 22), Color("#40454a"), false, 1.0)


func _draw_tv() -> void:
	# téléviseur fixé en hauteur, derrière une cage
	draw_rect(Rect2(-w / 2.0, -h - 4, w, h * 0.7), Color("#1a1c20"))
	draw_rect(Rect2(-w / 2.0 + 4, -h, w - 8, h * 0.7 - 8), Color("#2d5a78"))
	draw_rect(Rect2(-w / 2.0 + 4, -h, w - 8, 4), Color(1, 1, 1, 0.18))
	for k in range(3):
		draw_line(Vector2(-w / 2.0 - 3, -h - 2 + k * 14.0), Vector2(w / 2.0 + 3, -h - 2 + k * 14.0), Color("#3a3d42"), 2.0)
	draw_line(Vector2(0, -h * 0.3), Vector2(0, 0), Color("#3a3d42"), 4.0)


func _draw_booth() -> void:
	# cabine de parloir : comptoir, vitre épaisse, tabouret scellé
	_box(Color("#8b8f94"), Color("#5a5e63"), Color("#2c2f33"))
	draw_rect(Rect2(-w / 2.0, -h - d - 58, w, 56), Color(0.7, 0.88, 0.95, 0.20))
	draw_rect(Rect2(-w / 2.0, -h - d - 58, w, 56), Color("#2c2f33"), false, 2.0)
	draw_line(Vector2(-w * 0.25, -h - d - 56), Vector2(-w * 0.1, -h - d - 8), Color(1, 1, 1, 0.22), 2.0)
	draw_rect(Rect2(-6, -h - d - 20, 12, 8), Color("#16181b"))
	_ell(Vector2(0, 14), 12, 5, Color("#3d4146"))
	draw_rect(Rect2(-9, 2, 18, 8), Color("#4a4f55"))


func _draw_filing() -> void:
	_box(Color("#8d949a"), Color("#6c747a"), Color("#30363a"))
	var rows := 4
	for r in range(rows):
		var ry := -h + 6.0 + r * (h - 10.0) / rows
		draw_rect(Rect2(-w / 2.0 + 4, ry, w - 8, (h - 10.0) / rows - 3), Color(0, 0, 0, 0.14))
		draw_rect(Rect2(-8, ry + 5, 16, 5), Color("#c9ced1"))
	draw_rect(Rect2(-w / 2.0, -h - d, w, 6), Color("#a9b0b5"))
	draw_rect(Rect2(-w / 2.0 + 8, -h - d - 8, 16, 9), Color("#e4dfd0"))


func _draw_reception() -> void:
	_box(Color("#8a6a45"), Color("#5e4529"), Color("#2c2012"))
	draw_rect(Rect2(-w * 0.35, -h - d * 0.85 - 14, 30, 20), Color("#1d2630"))
	draw_rect(Rect2(-w * 0.35 + 3, -h - d * 0.85 - 11, 24, 14), Color("#c9cfa8"))
	draw_rect(Rect2(w * 0.1, -h - d * 0.8, 26, 18), Color("#e4dfd0"))
	draw_rect(Rect2(w * 0.1 + 3, -h - d * 0.74, 20, 2), Color("#8a8f94"))
	draw_rect(Rect2(w * 0.1 + 3, -h - d * 0.64, 14, 2), Color("#8a8f94"))
	draw_rect(Rect2(w * 0.32, -h - d * 0.7 - 9, 9, 13), Color("#b8342b"))
	draw_circle(Vector2(-w * 0.05, -h - d * 0.35), 4.0, Color("#c9a24a"))


func _draw_gate() -> void:
	# grille d'accès : barreaux, sans porte pleine
	var g := Rect2(-w / 2.0, -h, w, h)
	draw_rect(Rect2(g.position.x - 7, g.position.y - 7, g.size.x + 14, g.size.y + 7), Color("#2a2c30"))
	draw_rect(g, Color(0.05, 0.06, 0.08, 0.85))
	var n := int(w / 9.0)
	for k in range(n + 1):
		var gx := g.position.x + 4.0 + k * (w - 8.0) / n
		draw_line(Vector2(gx, g.position.y), Vector2(gx, g.end.y), Color("#7a7f86"), 2.0)
	for ry in [0.2, 0.55, 0.9]:
		draw_line(Vector2(g.position.x, -h * ry), Vector2(g.end.x, -h * ry), Color("#5a5f66"), 2.5)
	draw_rect(Rect2(w / 2.0 - 16, -h * 0.5, 10, 14), Color("#2a2c30"))
	draw_circle(Vector2(0, -h + 8), 6.0, Color(0.9, 0.2, 0.2, 0.18))
	draw_circle(Vector2(0, -h + 8), 3.0, Color("#d33a3a"))
	if label != "":
		draw_rect(Rect2(-45, -h - 16, 90, 13), Color("#15171b"))
		draw_rect(Rect2(-45, -h - 16, 90, 13), Color("#6a6f77"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-45, -h - 6), label, HORIZONTAL_ALIGNMENT_CENTER, 90, 10, Color("#e8e2c0"))


func _draw_sofa() -> void:
	_box(Color("#6b4a3c"), Color("#563a2e"), Color("#2a1b14"))
	draw_rect(Rect2(-w / 2.0, -h - d - 12, w, 14), Color("#4a3228"))
	for k in range(1, 3):
		draw_line(Vector2(-w / 2.0 + k * w / 3.0, -h - d), Vector2(-w / 2.0 + k * w / 3.0, -h), Color(0, 0, 0, 0.25), 1.5)


func _draw_phone() -> void:
	draw_rect(Rect2(-w / 2.0, -h, w, h), Color("#2c3036"))
	draw_rect(Rect2(-w / 2.0 + 4, -h + 5, w - 8, 14), Color("#8fb08a"))
	for r in range(3):
		for c in range(3):
			draw_rect(Rect2(-w / 2.0 + 6 + c * 8, -h + 24 + r * 7, 5, 4), Color("#c9ced1"))
	draw_arc(Vector2(w / 2.0 + 2, -h * 0.55), 7, -1.0, 1.5, 8, Color("#15171b"), 2.0)
