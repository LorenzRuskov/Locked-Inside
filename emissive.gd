extends Node2D

# Éléments lumineux non affectés par l'éclairage : fenêtre, ampoules qui se balancent, néons.
# `lamps` : liste de dictionnaires {kind: "bulb"|"tube", x, length, amp, phase, flicker, color...}

var floor_rect := Rect2()
var wall_h := 120.0
var window_on := false
var lamps: Array = []
var t := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func window_rect() -> Rect2:
	return Rect2(floor_rect.position.x + 28.0, floor_rect.position.y - wall_h + 14.0, 84.0, 34.0)


func pivot(i: int) -> Vector2:
	var l: Dictionary = lamps[i]
	return Vector2(float(l["x"]), floor_rect.position.y - wall_h - 12.0)


# Ampoule suspendue : pendule lent + petite oscillation secondaire
func bulb_pos(i: int) -> Vector2:
	var l: Dictionary = lamps[i]
	var amp := float(l["amp"])
	var ph := float(l["phase"])
	var ang := amp * sin(t * 1.3 + ph) + amp * 0.25 * sin(t * 2.9 + 1.0 + ph)
	return pivot(i) + Vector2(sin(ang), cos(ang)) * float(l["length"])


func lamp_pos(i: int) -> Vector2:
	var l: Dictionary = lamps[i]
	if str(l["kind"]) == "bulb":
		return bulb_pos(i)
	return Vector2(float(l["x"]), floor_rect.position.y - wall_h + 26.0)


# Où placer la lumière (PointLight2D) associée à la lampe
func lamp_light_pos(i: int) -> Vector2:
	var l: Dictionary = lamps[i]
	if str(l["kind"]) == "bulb":
		return bulb_pos(i) + Vector2(0, 6)
	return lamp_pos(i) + Vector2(0, 46)


# Multiplicateur d'intensité : 1 = stable, coupures brèves si le néon est abîmé
func flicker(i: int) -> float:
	var l: Dictionary = lamps[i]
	var amt := float(l["flicker"])
	if amt <= 0.0:
		return 1.0
	var n := sin(t * 23.0 + float(i) * 3.1) * sin(t * 7.0 + float(i))
	return 1.0 - amt * (1.0 if n > 0.8 else 0.0)


func _draw() -> void:
	var f := floor_rect
	if window_on:
		_draw_window(f)
	for i in range(lamps.size()):
		var l: Dictionary = lamps[i]
		if str(l["kind"]) == "bulb":
			_draw_bulb(i, f)
		else:
			_draw_tube(i, f, l)


func _draw_window(f: Rect2) -> void:
	var win := window_rect()
	for k in range(4):
		var xa := win.position.x + k * (win.size.x / 4.0) + 3.0
		var xb := xa + win.size.x / 4.0 - 6.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(xa, f.position.y), Vector2(xb, f.position.y),
			Vector2(xb + 120.0, f.position.y + 190.0), Vector2(xa + 120.0, f.position.y + 190.0)]), Color(0.75, 0.85, 1.0, 0.07))

	draw_rect(Rect2(win.position.x - 4, win.end.y, win.size.x + 8, 4), Color("#9a9c98"))
	draw_rect(win, Color("#9fbad0"))
	draw_rect(Rect2(win.position.x, win.position.y, win.size.x, win.size.y * 0.5), Color(1, 1, 1, 0.2))
	for k in range(1, 4):
		var bx := win.position.x + k * (win.size.x / 4.0)
		draw_line(Vector2(bx, win.position.y), Vector2(bx, win.end.y), Color("#2a2c30"), 3.0)
	draw_line(Vector2(win.position.x, win.position.y + win.size.y * 0.5), Vector2(win.end.x, win.position.y + win.size.y * 0.5), Color("#2a2c30"), 2.5)
	draw_rect(win, Color("#2a2c30"), false, 4.0)


func _draw_bulb(i: int, f: Rect2) -> void:
	var bp := bulb_pos(i)
	var piv := pivot(i) - Vector2(0, 40)
	var sway := bp.x - pivot(i).x
	draw_colored_polygon(PackedVector2Array([
		bp + Vector2(-4, 6), bp + Vector2(4, 6),
		Vector2(bp.x + 110.0 + sway * 0.6, f.end.y - 10.0), Vector2(bp.x - 110.0 + sway * 0.6, f.end.y - 10.0)]), Color(1.0, 0.85, 0.55, 0.045))
	draw_line(piv, bp + Vector2(0, -9), Color("#151515"), 2.0)
	draw_rect(Rect2(bp.x - 4, bp.y - 13, 8, 8), Color("#2b2b2b"))
	draw_circle(bp, 24.0, Color(1.0, 0.85, 0.55, 0.06))
	draw_circle(bp, 15.0, Color(1.0, 0.85, 0.55, 0.12))
	draw_circle(bp, 7.0, Color("#fff1c9"))
	draw_circle(bp + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.9))


func _draw_tube(i: int, f: Rect2, l: Dictionary) -> void:
	var p := lamp_pos(i)
	var m := flicker(i)
	var lc: Color = l["color"]
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - 30, p.y + 4), Vector2(p.x + 30, p.y + 4),
		Vector2(p.x + 100, p.y + 150), Vector2(p.x - 100, p.y + 150)]), Color(lc.r, lc.g, lc.b, 0.035 * m))
	draw_rect(Rect2(p.x - 42, p.y - 6, 84, 12), Color(lc.r, lc.g, lc.b, 0.07 * m))
	draw_rect(Rect2(p.x - 38, p.y - 4, 76, 8), Color("#23262b"))
	draw_rect(Rect2(p.x - 34, p.y - 2, 68, 4), Color(lc.r, lc.g, lc.b, 0.25 + 0.75 * m))
