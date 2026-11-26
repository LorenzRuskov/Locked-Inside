extends CharacterBody2D

const Art := preload("res://character_art.gd")
const SPEED := 200.0
const BODY_SCALE := 1.15

var t := 0.0
var moving := false
var look := 0.0
var look_target := 0.0
var frozen := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	moving = dir != Vector2.ZERO
	t += delta
	if absf(dir.x) > 0.2:
		look_target = signf(dir.x)
	look = lerpf(look, look_target, 0.2)
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	Art.draw(self, GameState.ap, Vector2.ZERO, BODY_SCALE, t, moving, look)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -118), str(GameState.ap["name"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.9))
