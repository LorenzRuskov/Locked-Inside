extends RefCounted

# Dessin du détenu (v2 : proportions réalistes, contours, ombrage).
# Origine = pieds. Appelé depuis le _draw() d'un CanvasItem.


static func _pick(arr: Array, i) -> Variant:
	return arr[clampi(int(i), 0, arr.size() - 1)]


static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, line: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, 1.0)


static func _cap(ci: CanvasItem, c: Vector2, rx: float, ry: float, off: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var a := PI + off + (PI - 2.0 * off) * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _shine(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(9):
		var a := PI + 0.9 + 1.0 * float(i) / 8.0
		pts.append(c + Vector2(cos(a) * rx * 0.8, sin(a) * ry * 0.82))
	ci.draw_polyline(pts, Color(1, 1, 1, 0.2), 1.4)


static func draw(ci: CanvasItem, ap: Dictionary, origin: Vector2, s: float, t: float, moving: bool, look: float) -> void:
	var skin: Color = _pick(GameState.SKINS, ap["skin"])
	var hair: Color = _pick(GameState.HAIR_COLORS, ap["hair_color"])
	var eye_col: Color = _pick(GameState.EYE_COLORS, ap["eyes"])
	var suit: Color = ap["suit_color"] if ap.has("suit_color") else _pick(GameState.SUITS, ap["suit"])
	var style := int(ap["hair_style"])
	var expr := int(ap["expression"])
	var beard := int(ap["beard"])
	var scar := int(ap["scar"])

	var swing := sin(t * 11.0) if moving else 0.0
	var bob := (absf(sin(t * 11.0)) * -1.6) if moving else sin(t * 2.0) * 0.5
	var lx := look * 1.3
	var skin_dark := skin.darkened(0.2)
	var skin_light := skin.lightened(0.15)
	var line := Color(0.07, 0.05, 0.04, 0.85)
	var suit_dark := suit.darkened(0.3)
	var brow_col := hair.darkened(0.3)
	var hy := -76.0 + bob
	var tb := bob

	# Ombre au sol (3 couches = bord adouci)
	ci.draw_set_transform(origin, 0.0, Vector2(s, s * 0.35))
	ci.draw_circle(Vector2.ZERO, 19.0, Color(0, 0, 0, 0.14))
	ci.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.18))
	ci.draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.22))
	ci.draw_set_transform(origin, 0.0, Vector2(s, s))

	# Cheveux (arrière)
	if style == 3:
		ci.draw_rect(Rect2(-9, hy - 8, 18, 22), hair)
	elif style == 5:
		_ell(ci, Vector2(0, hy - 3), 12.5, 12.0, hair)
	elif style == 6:
		_ell(ci, Vector2(9.5, hy + 6), 2.6, 8.0, hair)
		ci.draw_rect(Rect2(6.5, hy - 1, 3, 2), hair.darkened(0.3))

	# Jambes
	var l_dx := swing * 3.0
	var r_dx := -swing * 3.0
	var l_lift := maxf(swing, 0.0) * 3.0
	var r_lift := maxf(-swing, 0.0) * 3.0
	_poly(ci, PackedVector2Array([Vector2(-12, -34), Vector2(-0.5, -34), Vector2(-1.5 + l_dx, -5 - l_lift), Vector2(-10.5 + l_dx, -5 - l_lift)]), suit, line)
	_poly(ci, PackedVector2Array([Vector2(0.5, -34), Vector2(12, -34), Vector2(10.5 + r_dx, -5 - r_lift), Vector2(1.5 + r_dx, -5 - r_lift)]), suit, line)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -34), Vector2(-0.5, -34), Vector2(-1.5 + l_dx, -5 - l_lift), Vector2(-5 + l_dx, -5 - l_lift)]), Color(0, 0, 0, 0.16))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(6, -34), Vector2(12, -34), Vector2(10.5 + r_dx, -5 - r_lift), Vector2(6 + r_dx, -5 - r_lift)]), Color(0, 0, 0, 0.16))
	# Chaussures
	_poly(ci, PackedVector2Array([Vector2(-12 + l_dx, -5 - l_lift), Vector2(-0.5 + l_dx, -5 - l_lift), Vector2(1 + l_dx, -1 - l_lift), Vector2(1 + l_dx, -l_lift), Vector2(-13 + l_dx, -l_lift), Vector2(-13 + l_dx, -2 - l_lift)]), Color("#26201c"), line)
	_poly(ci, PackedVector2Array([Vector2(0.5 + r_dx, -5 - r_lift), Vector2(12 + r_dx, -5 - r_lift), Vector2(13 + r_dx, -2 - r_lift), Vector2(13 + r_dx, -r_lift), Vector2(-1 + r_dx, -r_lift), Vector2(-1 + r_dx, -1 - r_lift)]), Color("#26201c"), line)
	ci.draw_line(Vector2(-13 + l_dx, -0.6 - l_lift), Vector2(1 + l_dx, -0.6 - l_lift), Color(0.8, 0.8, 0.8, 0.35), 1.0)
	ci.draw_line(Vector2(-1 + r_dx, -0.6 - r_lift), Vector2(13 + r_dx, -0.6 - r_lift), Color(0.8, 0.8, 0.8, 0.35), 1.0)

	# Buste
	var torso := PackedVector2Array([
		Vector2(-15, -61 + tb), Vector2(-12, -63 + tb), Vector2(12, -63 + tb), Vector2(15, -61 + tb),
		Vector2(12.5, -36 + tb), Vector2(12, -31 + tb), Vector2(-12, -31 + tb), Vector2(-12.5, -36 + tb)])
	_poly(ci, torso, suit, line)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(3, -63 + tb), Vector2(12, -63 + tb), Vector2(15, -61 + tb), Vector2(12.5, -36 + tb), Vector2(12, -31 + tb), Vector2(3, -31 + tb)]), Color(0, 0, 0, 0.18))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -63 + tb), Vector2(-8, -63 + tb), Vector2(-8, -31 + tb), Vector2(-12, -31 + tb)]), Color(1, 1, 1, 0.07))
	ci.draw_line(Vector2(0, -58 + tb), Vector2(0, -31 + tb), suit_dark, 1.2)
	ci.draw_rect(Rect2(-10, -55 + tb, 7, 6), suit_dark, false, 1.0)
	ci.draw_line(Vector2(-12, -40 + tb), Vector2(12, -40 + tb), Color(0, 0, 0, 0.18), 1.0)
	ci.draw_line(Vector2(-8, -45 + tb), Vector2(-3, -38 + tb), Color(0, 0, 0, 0.12), 1.0)
	ci.draw_line(Vector2(6, -47 + tb), Vector2(9, -40 + tb), Color(0, 0, 0, 0.12), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -63 + tb), Vector2(0, -58 + tb), Vector2(5, -63 + tb)]), skin_dark)
	ci.draw_line(Vector2(-6, -63 + tb), Vector2(0, -57 + tb), suit_dark, 1.4)
	ci.draw_line(Vector2(6, -63 + tb), Vector2(0, -57 + tb), suit_dark, 1.4)
	ci.draw_rect(Rect2(3, -54 + tb, 8, 5), Color("#efeee8"))
	ci.draw_rect(Rect2(3, -54 + tb, 8, 5), line, false, 0.8)
	for k in range(3):
		ci.draw_line(Vector2(4.6 + k * 2.2, -52.8 + tb), Vector2(4.6 + k * 2.2, -50.2 + tb), Color("#333333"), 0.9)

	# Bras + mains
	var la := PackedVector2Array([Vector2(-15, -60 + tb), Vector2(-17.5, -46 + tb - swing), Vector2(-17, -32 + tb - swing * 3.0)])
	var ra := PackedVector2Array([Vector2(15, -60 + tb), Vector2(17.5, -46 + tb + swing), Vector2(17, -32 + tb + swing * 3.0)])
	ci.draw_polyline(la, line, 8.0)
	ci.draw_polyline(la, suit, 6.4)
	ci.draw_polyline(ra, line, 8.0)
	ci.draw_polyline(ra, suit, 6.4)
	ci.draw_polyline(ra, Color(0, 0, 0, 0.14), 3.0)
	ci.draw_circle(la[2] + Vector2(0, 3.5), 3.0, skin)
	ci.draw_circle(ra[2] + Vector2(0, 3.5), 3.0, skin_dark)

	# Cou, oreilles, tête
	ci.draw_rect(Rect2(-3.2, -68 + tb, 6.4, 7), skin_dark)
	_ell(ci, Vector2(-7.8, hy + 0.5), 1.7, 2.7, skin_dark)
	_ell(ci, Vector2(7.8, hy + 0.5), 1.7, 2.7, skin_dark)
	var head := PackedVector2Array([
		Vector2(-7.5, hy - 3), Vector2(-7.2, hy - 7), Vector2(-4.5, hy - 9), Vector2(0, hy - 9.5),
		Vector2(4.5, hy - 9), Vector2(7.2, hy - 7), Vector2(7.5, hy - 3), Vector2(7, hy + 3),
		Vector2(5, hy + 7), Vector2(2, hy + 9), Vector2(-2, hy + 9), Vector2(-5, hy + 7), Vector2(-7, hy + 3)])
	_poly(ci, head, skin, line)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(1.5, hy - 9.4), Vector2(4.5, hy - 9), Vector2(7.2, hy - 7), Vector2(7.5, hy - 3), Vector2(7, hy + 3), Vector2(5, hy + 7), Vector2(2, hy + 9), Vector2(1.5, hy + 9)]), Color(0, 0, 0, 0.14))
	_ell(ci, Vector2(-3.5, hy + 2.5), 2.2, 1.6, Color(1, 1, 1, 0.08))

	# Yeux
	var ey := hy - 0.5
	var eye_ry := 1.0 if expr == 1 else 1.3
	for sx in [-3.4, 3.4]:
		var e := Vector2(sx + lx, ey)
		_ell(ci, e, 2.1, eye_ry, Color("#f2f2ee"))
		var ip := e + Vector2(lx * 0.35, 0)
		ci.draw_circle(ip, 1.15, eye_col)
		ci.draw_circle(ip, 0.55, Color("#0b0b0b"))
		ci.draw_circle(ip + Vector2(-0.4, -0.4), 0.28, Color(1, 1, 1, 0.9))
		ci.draw_polyline(PackedVector2Array([e + Vector2(-2.2, 0.2), e + Vector2(-1, -eye_ry - 0.1), e + Vector2(1, -eye_ry - 0.1), e + Vector2(2.2, 0.2)]), line, 0.9)
		if expr == 3:
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-2.3, -1.7), e + Vector2(2.3, -1.7), e + Vector2(2.3, -0.1), e + Vector2(-2.3, 0.0)]), skin)
			ci.draw_line(e + Vector2(-2.3, 0.0), e + Vector2(2.3, -0.1), line, 0.9)
			ci.draw_arc(e + Vector2(0, 2.4), 2.4, 0.3, PI - 0.3, 6, skin_dark, 1.0)

	# Sourcils
	var bo := -4.2
	var bi := -4.2
	match expr:
		1:
			bo = -4.6
			bi = -5.2
		2:
			bo = -5.6
			bi = -3.2
		3:
			bo = -3.4
			bi = -4.8
	ci.draw_line(Vector2(-6.4 + lx, hy + bo), Vector2(-1.6 + lx, hy + bi), brow_col, 1.5)
	ci.draw_line(Vector2(6.4 + lx, hy + bo), Vector2(1.6 + lx, hy + bi), brow_col, 1.5)

	# Nez
	ci.draw_line(Vector2(lx * 0.8, hy - 1.0), Vector2(lx * 0.8 + 0.5, hy + 3.2), skin_dark, 1.1)
	ci.draw_line(Vector2(-1.4 + lx * 0.8, hy + 3.9), Vector2(1.4 + lx * 0.8, hy + 3.9), skin_dark, 1.3)
	ci.draw_circle(Vector2(lx * 0.8 - 0.3, hy + 2.4), 0.6, skin_light)

	# Barbe
	if beard == 1:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.8 + lx, hy + 4.2), Vector2(lx, hy + 3.8), Vector2(3.8 + lx, hy + 4.2), Vector2(3.2 + lx, hy + 5.6), Vector2(lx, hy + 4.8), Vector2(-3.2 + lx, hy + 5.6)]), hair)
	elif beard == 2:
		_ell(ci, Vector2(lx, hy + 8.4), 2.2, 2.6, hair)
	elif beard == 3:
		var o := lx * 0.3
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-7 + o, hy), Vector2(-6.5 + o, hy + 5), Vector2(-3.5 + o, hy + 9), Vector2(o, hy + 10.5),
			Vector2(3.5 + o, hy + 9), Vector2(6.5 + o, hy + 5), Vector2(7 + o, hy),
			Vector2(5 + o, hy + 3.2), Vector2(3 + o, hy + 4.5), Vector2(o, hy + 4.8),
			Vector2(-3 + o, hy + 4.5), Vector2(-5 + o, hy + 3.2)]), hair)

	# Bouche
	var lip := skin.lerp(Color("#a8503f"), 0.55)
	if beard == 3:
		lip = Color("#a05a4a")
	var my := hy + 6.4
	_ell(ci, Vector2(lx, my + 0.6), 2.4, 0.9, lip)
	match expr:
		1:
			ci.draw_arc(Vector2(lx, my - 1.2), 3.8, 0.3, PI - 0.3, 8, line, 1.1)
		2:
			ci.draw_line(Vector2(-3 + lx, my + 0.8), Vector2(lx, my - 0.2), line, 1.1)
			ci.draw_line(Vector2(lx, my - 0.2), Vector2(3 + lx, my + 0.8), line, 1.1)
		3:
			ci.draw_line(Vector2(-2.6 + lx, my), Vector2(2.6 + lx, my), line, 1.1)
		_:
			ci.draw_line(Vector2(-3.0 + lx, my), Vector2(3.0 + lx, my), line, 1.1)

	# Cicatrice
	var sc := Color("#b0504a")
	if scar == 1:
		ci.draw_line(Vector2(3.5 + lx, hy + 0.5), Vector2(6.2 + lx, hy + 5.5), sc, 1.3)
		ci.draw_line(Vector2(4.2 + lx, hy + 2.0), Vector2(6.0 + lx, hy + 1.2), sc, 0.9)
		ci.draw_line(Vector2(5.0 + lx, hy + 4.0), Vector2(6.8 + lx, hy + 3.2), sc, 0.9)
	elif scar == 2:
		ci.draw_line(Vector2(2.5 + lx, hy - 6.5), Vector2(4.8 + lx, hy - 1.2), sc, 1.3)

	# Cheveux (avant)
	var c := Vector2(0, hy - 0.5)
	match style:
		1:
			_cap(ci, c, 8.4, 10.2, 0.55, Color(hair.r, hair.g, hair.b, 0.5))
		2:
			_cap(ci, c, 8.4, 10.2, 0.55, hair)
			ci.draw_rect(Rect2(-8, hy - 5.8, 1.6, 5), hair)
			ci.draw_rect(Rect2(6.4, hy - 5.8, 1.6, 5), hair)
			_shine(ci, c, 8.4, 10.2)
		3:
			_cap(ci, c, 8.4, 10.2, 0.45, hair)
			ci.draw_rect(Rect2(-8.6, hy - 6, 2.2, 15), hair)
			ci.draw_rect(Rect2(6.4, hy - 6, 2.2, 15), hair)
			_shine(ci, c, 8.4, 10.2)
		4:
			_cap(ci, c, 8.2, 10.0, 0.75, Color(hair.r, hair.g, hair.b, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-2.5, hy - 8.5), Vector2(-3, hy - 17), Vector2(0, hy - 21),
				Vector2(3, hy - 17), Vector2(2.5, hy - 8.5)]), hair)
		5:
			_cap(ci, c, 9.5, 10.6, 0.7, hair)
			_shine(ci, Vector2(0, hy - 3), 12.5, 12.0)
		6:
			_cap(ci, c, 8.4, 10.2, 0.55, hair)
			_shine(ci, c, 8.4, 10.2)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
