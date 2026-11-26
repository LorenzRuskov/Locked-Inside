extends Node2D

# Autre détenu présent dans la même pièce, position lissée. Caché jusqu'à la première position reçue.

const Art := preload("res://character_art.gd")
const BODY_SCALE := 1.15

var ap := {}
var target := Vector2.ZERO
var moving := false
var look := 0.0
var t := 0.0
var player_name := ""
var inmate := 0
var got_pos := false


func setup(p_ap: Dictionary, pos: Vector2) -> void:
	ap = p_ap
	position = pos
	target = pos
	player_name = str(ap.get("name", "Détenu"))
	inmate = int(ap.get("inmate", 0))
	visible = false


func set_target(pos: Vector2, p_moving: bool, p_look: float) -> void:
	target = pos
	moving = p_moving
	look = p_look
	if not got_pos:
		got_pos = true
		position = pos
		visible = true


func _process(delta: float) -> void:
	t += delta
	position = position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	Art.draw(self, ap, Vector2.ZERO, BODY_SCALE, t, moving, look)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -118), player_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.9))
	if inmate > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-60, -104), "N° %d" % inmate, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 0.85, 0.5, 0.8))
