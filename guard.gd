extends Node2D

# Gardien qui patrouille. Sa position ne dépend que de l'horloge : tous les joueurs
# de la pièce le voient au même endroit, sans aucun échange réseau.

const Art := preload("res://character_art.gd")
const BODY_SCALE := 1.2

var guard_name := ""
var title := "Gardien"   # affiché devant le nom
var is_guard := true      # false = personnel civil (ne fouille pas)
var menu: Array = []      # actions proposées ; vide = observer / provoquer
var fixed := false        # un seul point : le PNJ reste sur place
var path: Array = []     # points (Vector2) d'une boucle fermée
var speed := 55.0
var phase := 0.0         # décalage (0..1) sur la boucle
var ap := {}
var length := 1.0
var seg_len: Array = []
var moving := true
var look := 0.0
var t := 0.0


# Apparence de chaque gardien (uniforme bleu nuit)
static func appearance(who: String) -> Dictionary:
	var base := {"skin": 1, "hair_style": 1, "hair_color": 1, "eyes": 1, "expression": 0, "beard": 0, "scar": 0, "suit": 1, "suit_color": Color("#1d2a45")}
	match who:
		"Vidal":
			base.merge({"skin": 1, "hair_style": 3, "hair_color": 2, "eyes": 2, "expression": 0, "suit_color": Color("#d3e6e3")}, true)
		"Dupont":
			base.merge({"skin": 0, "hair_style": 0, "hair_color": 5, "expression": 1, "beard": 1}, true)
		"Martin":
			base.merge({"skin": 2, "hair_style": 2, "hair_color": 0, "expression": 2, "scar": 1}, true)
		"Benali":
			base.merge({"skin": 3, "hair_style": 1, "hair_color": 0, "expression": 0, "beard": 2}, true)
		"Lefebvre":
			base.merge({"skin": 1, "hair_style": 2, "hair_color": 3, "expression": 1, "beard": 1}, true)
		"Roux":
			base.merge({"skin": 0, "hair_style": 3, "hair_color": 4, "expression": 2, "scar": 1}, true)
		"Sanchez":
			base.merge({"skin": 2, "hair_style": 3, "hair_color": 1}, true)
		"Garnier":
			base.merge({"skin": 0, "hair_style": 1, "hair_color": 2, "expression": 1, "beard": 2}, true)
		"Perrin":
			base.merge({"skin": 3, "hair_style": 2, "hair_color": 0, "expression": 0}, true)
		"Bruno":
			base.merge({"skin": 2, "hair_style": 0, "hair_color": 1, "expression": 0, "beard": 1, "suit_color": Color("#e9e6dc")}, true)
		"Roche":
			base.merge({"skin": 1, "hair_style": 3, "hair_color": 4, "eyes": 2, "expression": 1, "suit_color": Color("#6d5a7a")}, true)
		_:
			pass
	return base


func setup(p_name: String, p_path: Array, p_speed: float, p_phase: float, p_ap: Dictionary) -> void:
	guard_name = p_name
	path = p_path
	speed = p_speed
	phase = p_phase
	ap = p_ap
	seg_len.clear()
	length = 0.0
	for i in range(path.size()):
		var a: Vector2 = path[i]
		var b: Vector2 = path[(i + 1) % path.size()]
		var l := a.distance_to(b)
		seg_len.append(l)
		length += l
	fixed = path.size() < 2
	moving = not fixed
	position = path[0] if fixed else _pos_at(0.0)


# Position sur la boucle au bout de d pixels
func _pos_at(d: float) -> Vector2:
	d = fposmod(d, length)
	for i in range(path.size()):
		var l: float = seg_len[i]
		if d <= l:
			var a: Vector2 = path[i]
			var b: Vector2 = path[(i + 1) % path.size()]
			return a.lerp(b, d / maxf(l, 0.001))
		d -= l
	return path[0]


func _process(delta: float) -> void:
	t += delta
	if fixed:
		queue_redraw()
		return
	var dist := Time.get_unix_time_from_system() * speed + phase * length
	var np := _pos_at(dist)
	var dx := np.x - position.x
	if absf(dx) > 0.01:
		look = clampf(dx * 40.0, -1.0, 1.0)
	position = np
	queue_redraw()


func _draw() -> void:
	Art.draw(self, ap, Vector2.ZERO, BODY_SCALE, t, true, look)
	var col := Color(0.95, 0.55, 0.5, 0.95) if is_guard else Color(0.65, 0.95, 0.9, 0.95)
	draw_string(ThemeDB.fallback_font, Vector2(-70, -124), title + " " + guard_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, col)
