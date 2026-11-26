extends Node2D

# Décor statique d'une pièce : mur, sol, saletés.
# Les couleurs et options viennent du dictionnaire `theme` de la pièce (voir rooms.gd).
#
# MOBILE : ce décor contient des milliers de petits tracés. Il est donc dessiné UNE SEULE FOIS
# dans une texture (bake), puis affiché comme une simple image : le téléphone ne redessine plus
# rien à chaque image et les lumières n'ont qu'un rectangle à éclairer au lieu de milliers de tracés.

var floor_rect := Rect2()
var wall_h := 120.0
var theme := {}
var lamp_xs: Array = []     # abscisses des lampes (reflets sur le sol)
var rng := RandomNumberGenerator.new()

const MAX_TEX := 4096.0


# Fabrique le décor d'une pièce et l'ajoute à `parent` sous forme d'image fixe.
static func bake(parent: Node, f: Rect2, wh: float, th: Dictionary, xs: Array) -> void:
	var region := Rect2(f.position.x - 60.0, f.position.y - wh - 80.0, f.size.x + 120.0, f.size.y + wh + 80.0 + 60.0)
	var sc := minf(2.0, MAX_TEX / maxf(region.size.x, region.size.y))
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(region.size.x * sc), ceili(region.size.y * sc))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_DISABLED
	var bd = (load("res://backdrop.gd") as GDScript).new()
	bd.floor_rect = f
	bd.wall_h = wh
	bd.theme = th
	bd.lamp_xs = xs
	bd.position = -region.position * sc
	bd.scale = Vector2(sc, sc)
	vp.add_child(bd)
	parent.add_child(vp)
	var sp := Sprite2D.new()
	sp.texture = vp.get_texture()
	sp.centered = false
	sp.position = region.position
	sp.scale = Vector2(1.0 / sc, 1.0 / sc)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.z_index = -100
	parent.add_child(sp)


func _c(key: String, def: String) -> Color:
	if theme.has(key):
		var v = theme[key]
		if v is Color:
			return v
		return Color(str(v))
	return Color(def)


func _on(key: String) -> bool:
	return bool(theme.get(key, false))


func _num(key: String, def: float) -> float:
	return float(theme.get(key, def))


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	rng.seed = 1337
	var f := floor_rect
	draw_rect(Rect2(f.position.x - 80, f.position.y - wall_h - 120, f.size.x + 160, f.size.y + wall_h + 240), Color("#0c0d10"))
	_draw_back_wall(f)
	_draw_floor(f)
	_draw_side_walls(f)
	_draw_depth(f)


func _draw_back_wall(f: Rect2) -> void:
	var wall := Rect2(f.position.x - 20, f.position.y - wall_h, f.size.x + 40, wall_h)
	var split := wall.position.y + wall_h * 0.5
	draw_rect(wall, _c("wall_a", "#a9aba2"))
	draw_rect(Rect2(wall.position.x, split, wall.size.x, wall.end.y - split), _c("wall_b", "#55705f"))
	draw_rect(Rect2(wall.position.x, split - 2, wall.size.x, 4), _c("wall_line", "#2f4237"))

	var y := wall.position.y + 10.0
	var row := 0
	while y < wall.end.y:
		draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), Color(0, 0, 0, 0.10), 1.0)
		var x := wall.position.x + (26.0 if row % 2 == 0 else 0.0)
		while x < wall.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 20.0, wall.end.y)), Color(0, 0, 0, 0.08), 1.0)
			x += 52.0
		y += 20.0
		row += 1

	var dirt := _num("dirt", 1.0)
	for i in range(int(6.0 * dirt * wall.size.x / 440.0) + 3):
		var sx := rng.randf_range(wall.position.x + 20, wall.end.x - 20)
		var sy := rng.randf_range(wall.position.y + 10, wall.end.y - 10)
		_ell(Vector2(sx, sy), rng.randf_range(8, 24), rng.randf_range(5, 14), Color(0.2, 0.17, 0.1, rng.randf_range(0.04, 0.10)))
	for i in range(int(5.0 * wall.size.x / 440.0) + 2):
		var wx := rng.randf_range(wall.position.x + 10, wall.end.x - 10)
		var wy := wall.position.y + rng.randf_range(0, 16)
		draw_line(Vector2(wx, wy), Vector2(wx + rng.randf_range(-2, 2), wy + rng.randf_range(20, 60)), Color(0.1, 0.08, 0.05, 0.10), rng.randf_range(2, 4))

	_draw_wall_details(f, wall, split)

	if _on("tally"):
		for g in range(2):
			var tx := f.end.x - 72.0 + g * 26.0
			var ty := split + 8.0
			for k in range(4):
				draw_line(Vector2(tx + k * 4.0, ty), Vector2(tx + k * 4.0, ty + 14), Color(0.92, 0.92, 0.85, 0.4), 1.2)
			draw_line(Vector2(tx - 3, ty + 11), Vector2(tx + 15, ty + 3), Color(0.92, 0.92, 0.85, 0.4), 1.2)

	for i in range(16):
		draw_rect(Rect2(wall.position.x, wall.position.y + i * 2.0, wall.size.x, 2), Color(0, 0, 0, 0.34 * (1.0 - i / 16.0)))
	draw_rect(Rect2(f.position.x - 20, f.position.y - 8, f.size.x + 40, 8), Color("#2a2d2b"))
	draw_rect(Rect2(f.position.x - 20, f.position.y - 8, f.size.x + 40, 1.5), Color(1, 1, 1, 0.12))

	if _on("wire"):
		_draw_wire(wall)


# Fil barbelé au sommet du mur (cour)
func _draw_wire(wall: Rect2) -> void:
	var top := wall.position.y
	var x := wall.position.x
	while x < wall.end.x:
		draw_line(Vector2(x, top), Vector2(x, top - 16), Color("#26282a"), 3.0)
		draw_line(Vector2(x, top - 16), Vector2(x + 8, top - 22), Color("#26282a"), 3.0)
		x += 60.0
	for k in range(3):
		var pts := PackedVector2Array()
		var xx := wall.position.x
		var yy := top - 6.0 - k * 5.0
		var s := 0
		while xx < wall.end.x:
			pts.append(Vector2(xx, yy + (3.0 if s % 2 == 0 else -3.0)))
			xx += 7.0
			s += 1
		draw_polyline(pts, Color(0.55, 0.57, 0.6, 0.8), 1.2)


func _draw_floor(f: Rect2) -> void:
	var ts := _num("tile", 60.0)
	draw_rect(f, _c("floor", "#8a8c8a"))
	_draw_floor_pattern(f, ts)
	var cols := int(ceil(f.size.x / ts))
	var rows := int(ceil(f.size.y / ts))
	for i in range(cols):
		for j in range(rows):
			var a := rng.randf_range(0.0, 0.10)
			var tone := Color(1, 1, 1, a) if rng.randf() > 0.5 else Color(0, 0, 0, a)
			var rx := f.position.x + i * ts + 2.0
			var ry := f.position.y + j * ts + 2.0
			draw_rect(Rect2(rx, ry, minf(ts - 4.0, f.end.x - rx), minf(ts - 4.0, f.end.y - ry)), tone)
	for i in range(cols + 1):
		var vx := minf(f.position.x + i * ts, f.end.x)
		draw_line(Vector2(vx, f.position.y), Vector2(vx, f.end.y), Color(0, 0, 0, 0.35), 2.0)
		draw_line(Vector2(vx + 1.5, f.position.y), Vector2(vx + 1.5, f.end.y), Color(1, 1, 1, 0.10), 1.0)
	for j in range(rows + 1):
		var hy := minf(f.position.y + j * ts, f.end.y)
		draw_line(Vector2(f.position.x, hy), Vector2(f.end.x, hy), Color(0, 0, 0, 0.35), 2.0)
		draw_line(Vector2(f.position.x, hy + 1.5), Vector2(f.end.x, hy + 1.5), Color(1, 1, 1, 0.10), 1.0)

	var dirt := _num("dirt", 1.0)
	var area := f.size.x * f.size.y / (400.0 * 230.0)
	for i in range(int(320.0 * area * minf(dirt, 1.5)) + 40):
		var p := Vector2(rng.randf_range(f.position.x, f.end.x), rng.randf_range(f.position.y, f.end.y))
		var sz := rng.randf_range(1.0, 3.0)
		if rng.randf() < 0.6:
			draw_rect(Rect2(p, Vector2(sz, sz)), Color(0, 0, 0, rng.randf_range(0.05, 0.14)))
		else:
			draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 1, 1, rng.randf_range(0.04, 0.10)))

	for i in range(int(3.0 * area * dirt) + 2):
		var q := Vector2(rng.randf_range(f.position.x + 20, f.end.x - 20), rng.randf_range(f.position.y + 20, f.end.y - 40))
		var pts := PackedVector2Array([q])
		for k in range(5):
			q += Vector2(rng.randf_range(-12, 12), rng.randf_range(4, 14))
			pts.append(q)
		draw_polyline(pts, Color(0, 0, 0, 0.28), 1.2)

	for i in range(int(4.0 * area * dirt) + 2):
		_ell(Vector2(rng.randf_range(f.position.x + 40, f.end.x - 40), rng.randf_range(f.position.y + 40, f.end.y - 30)), rng.randf_range(16, 38), rng.randf_range(7, 16), Color(0, 0, 0, rng.randf_range(0.06, 0.13)))

	if _on("drain"):
		var dc := Vector2(f.position.x + f.size.x * 0.62, f.position.y + f.size.y * 0.78)
		_ell(dc, 20, 9, Color("#1b1c1d"))
		_ell(dc, 16, 7, Color("#2e3032"))
		for k in range(-2, 3):
			draw_line(Vector2(dc.x + k * 5, dc.y - 6), Vector2(dc.x + k * 5, dc.y + 6), Color("#111213"), 1.5)

	if _on("patch"):
		_ell(Vector2(f.position.x + f.size.x * 0.69, f.position.y + 24), 46, 12, Color(1, 1, 1, 0.05))

	if theme.has("stripe_y"):
		var sy := f.position.y + f.size.y * _num("stripe_y", 0.5)
		draw_rect(Rect2(f.position.x, sy - 2.0, f.size.x, 4.0), _c("stripe_col", "#e5c733"))

	if _on("court"):
		_draw_court(f)

	for i in range(20):
		draw_rect(Rect2(f.position.x, f.position.y + i * 1.5, f.size.x, 1.5), Color(0, 0, 0, 0.30 * (1.0 - i / 20.0)))


# Marquage d'un terrain de basket : cadre, raquette, demi-cercle
func _draw_court(f: Rect2) -> void:
	var line := Color(1, 1, 1, 0.45)
	draw_rect(Rect2(f.position.x + 30, f.position.y + 50, f.size.x - 60, f.size.y - 80), line, false, 3.0)
	var hc := Vector2(f.end.x - 150.0, f.position.y + f.size.y * 0.55)
	draw_rect(Rect2(hc.x - 20, hc.y - 60, 120, 120), line, false, 3.0)
	draw_arc(hc + Vector2(-20, 0), 60.0, PI * 0.5, PI * 1.5, 24, line, 3.0)
	draw_line(Vector2(f.position.x + f.size.x * 0.5, f.position.y + 50), Vector2(f.position.x + f.size.x * 0.5, f.end.y - 30), line, 2.0)


func _draw_side_walls(f: Rect2) -> void:
	var side_h := f.size.y + 20.0 + wall_h
	var side := _c("side", "#6f716c")
	draw_rect(Rect2(f.position.x - 20, f.position.y - wall_h, 20, side_h), side)
	draw_rect(Rect2(f.end.x, f.position.y - wall_h, 20, side_h), side)
	draw_rect(Rect2(f.position.x - 8, f.position.y - wall_h, 8, side_h), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(f.end.x, f.position.y - wall_h, 8, side_h), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(f.position.x - 20, f.end.y, f.size.x + 40, 20), _c("front", "#3a3d44"))
	draw_rect(Rect2(f.position.x - 20, f.end.y, f.size.x + 40, 2), Color(1, 1, 1, 0.12))


# ---------- Détails ajoutés : piliers, tuyaux, grilles, texte peint, sol ----------

func _draw_wall_details(f: Rect2, wall: Rect2, split: float) -> void:
	# Piliers de béton régulièrement espacés
	var sp := _num("pilasters", 0.0)
	if sp > 0.0:
		var px := wall.position.x + sp * 0.5 + 20.0
		while px < wall.end.x - 20.0:
			draw_rect(Rect2(px - 9, wall.position.y, 18, wall.size.y), Color(0, 0, 0, 0.16))
			draw_rect(Rect2(px - 9, wall.position.y, 3, wall.size.y), Color(1, 1, 1, 0.10))
			draw_rect(Rect2(px + 6, wall.position.y, 3, wall.size.y), Color(0, 0, 0, 0.20))
			px += sp
	# Tuyaux apparents le long du plafond
	if _on("pipes"):
		for k in range(2):
			var py := wall.position.y + 9.0 + k * 11.0
			draw_rect(Rect2(wall.position.x, py, wall.size.x, 7), Color("#4a4f55") if k == 0 else Color("#6b5b49"))
			draw_rect(Rect2(wall.position.x, py, wall.size.x, 2), Color(1, 1, 1, 0.22))
			draw_rect(Rect2(wall.position.x, py + 5, wall.size.x, 2), Color(0, 0, 0, 0.35))
			var bx := wall.position.x + 40.0 + k * 55.0
			while bx < wall.end.x:
				draw_rect(Rect2(bx, py - 2, 6, 11), Color("#22252a"))
				bx += 170.0
	# Grilles d'aération
	if _on("vents"):
		var vx := wall.position.x + 150.0
		while vx < wall.end.x - 90.0:
			var vy := wall.position.y + 30.0
			draw_rect(Rect2(vx, vy, 40, 22), Color("#2a2c30"))
			for j in range(5):
				draw_rect(Rect2(vx + 3, vy + 3 + j * 3.6, 34, 1.6), Color("#14161a"))
			draw_rect(Rect2(vx, vy, 40, 22), Color("#5a5e65"), false, 1.2)
			vx += 380.0
	# Texte peint au pochoir
	if theme.has("wall_text"):
		var tx := float(theme.get("wall_text_x", f.position.x + 70.0))
		draw_string(ThemeDB.fallback_font, Vector2(tx, split - 10.0), str(theme["wall_text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95, 0.95, 0.9, 0.32))
	# Bande rouge d'éclairage de secours (isolement)
	if _on("emergency"):
		draw_rect(Rect2(wall.position.x, wall.position.y + 4, wall.size.x, 3), Color(0.9, 0.15, 0.1, 0.55))
	# Plinthe peinte
	draw_rect(Rect2(wall.position.x, wall.end.y - 14, wall.size.x, 14), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(wall.position.x, wall.end.y - 14, wall.size.x, 1.5), Color(1, 1, 1, 0.12))


# Profondeur : ombres de bord, reflets sous les lampes, flaques
func _draw_depth(f: Rect2) -> void:
	# Ombres le long des murs latéraux et du bord avant
	for i in range(14):
		var a := 0.26 * (1.0 - float(i) / 14.0)
		draw_rect(Rect2(f.position.x + i * 2.0, f.position.y, 2, f.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(f.end.x - (i + 1) * 2.0, f.position.y, 2, f.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(f.position.x, f.end.y - (i + 1) * 2.0, f.size.x, 2), Color(0, 0, 0, a * 0.8))
	# Reflets des lampes sur le sol (sol humide / ciré)
	if _on("sheen"):
		for lx in lamp_xs:
			var cx := float(lx)
			if cx < f.position.x or cx > f.end.x:
				continue
			for k in range(6):
				var w := 70.0 - k * 9.0
				var h := f.size.y * (0.9 - k * 0.1)
				draw_rect(Rect2(cx - w * 0.5, f.position.y + 6.0, w, h), Color(1, 1, 1, 0.012))
	# Flaques brillantes
	var n := int(_num("puddles", 0.0))
	for i in range(n):
		var c := Vector2(rng.randf_range(f.position.x + 60, f.end.x - 60), rng.randf_range(f.position.y + 50, f.end.y - 40))
		_ell(c, rng.randf_range(22, 46), rng.randf_range(7, 13), Color(0.55, 0.65, 0.8, 0.16))
		_ell(c + Vector2(-5, -2), rng.randf_range(10, 20), rng.randf_range(3, 6), Color(1, 1, 1, 0.14))


# Damier de linoléum (cantine, infirmerie) et moquette (administration)
func _draw_floor_pattern(f: Rect2, ts: float) -> void:
	if theme.has("checker"):
		var c2 := _c("checker", "#cfd2cc")
		var cols := int(ceil(f.size.x / ts))
		var rows := int(ceil(f.size.y / ts))
		for i in range(cols):
			for j in range(rows):
				if (i + j) % 2 == 0:
					var rx := f.position.x + i * ts
					var ry := f.position.y + j * ts
					draw_rect(Rect2(rx, ry, minf(ts, f.end.x - rx), minf(ts, f.end.y - ry)), Color(c2.r, c2.g, c2.b, 0.35))
	if _on("carpet"):
		var y := f.position.y
		while y < f.end.y:
			draw_line(Vector2(f.position.x, y), Vector2(f.end.x, y), Color(0, 0, 0, 0.07), 1.0)
			y += 3.0
		draw_rect(Rect2(f.position.x + 40, f.position.y + 30, f.size.x - 80, f.size.y - 60), Color(1, 1, 1, 0.07), false, 3.0)
