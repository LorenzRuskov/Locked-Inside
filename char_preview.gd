extends Control

const Art := preload("res://character_art.gd")

var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#23262d"))
	draw_rect(Rect2(0, size.y - 70, size.x, 70), Color("#3a3d44"))
	Art.draw(self, GameState.ap, Vector2(size.x / 2.0, size.y - 40.0), 4.2, t, false, sin(t * 1.3))
