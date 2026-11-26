extends Control

# Décor animé de l'introduction : fenêtre grillagée au clair de lune, poussière.

var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#07080b"))
	for i in range(18):
		draw_rect(Rect2(0, i * 40, 1280, 40), Color(0.06, 0.09, 0.15, 0.30 * (1.0 - i / 18.0)))

	var win := Rect2(880, 70, 240, 300)
	draw_rect(win, Color("#16212f"))
	draw_rect(Rect2(win.position.x, win.position.y, win.size.x, win.size.y * 0.5), Color(0.5, 0.65, 0.9, 0.18))
	draw_circle(Vector2(1010, 150), 52.0, Color(0.85, 0.9, 1.0, 0.10))
	draw_circle(Vector2(1010, 150), 36.0, Color(0.85, 0.9, 1.0, 0.55))
	for k in range(1, 6):
		var bx := win.position.x + k * (win.size.x / 6.0)
		draw_line(Vector2(bx, win.position.y), Vector2(bx, win.end.y), Color("#05060a"), 8.0)
	draw_rect(win, Color("#05060a"), false, 8.0)

	for k in range(6):
		var xa := win.position.x + k * (win.size.x / 6.0) + 6.0
		var xb := xa + win.size.x / 6.0 - 16.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(xa, win.end.y), Vector2(xb, win.end.y),
			Vector2(xb - 380.0, 640.0), Vector2(xa - 380.0, 640.0)]), Color(0.7, 0.8, 1.0, 0.05))

	for i in range(36):
		var ph := float(i) * 1.7
		var x := fposmod(120.0 + float(i) * 37.0 + t * (6.0 + float(i % 5)), 1280.0)
		var y := 120.0 + 480.0 * (0.5 + 0.5 * sin(ph + t * 0.35))
		draw_circle(Vector2(x, y), 1.5 + float(i % 3), Color(0.8, 0.88, 1.0, 0.10))

	draw_rect(Rect2(0, 620, 1280, 100), Color(0, 0, 0, 0.5))
