extends Control

const PreviewScript := preload("res://char_preview.gd")

var ui: Control
var preview: Control
var name_edit: LineEdit
var rows: Array = []
var opts: Array = []


func _ready() -> void:
	opts = [
		{"key": "skin", "label": "Teint", "colors": GameState.SKINS},
		{"key": "hair_style", "label": "Coiffure", "names": GameState.HAIR_STYLES},
		{"key": "hair_color", "label": "Cheveux", "colors": GameState.HAIR_COLORS},
		{"key": "eyes", "label": "Yeux", "colors": GameState.EYE_COLORS},
		{"key": "expression", "label": "Expression", "names": GameState.EXPRESSIONS},
		{"key": "beard", "label": "Barbe", "names": GameState.BEARDS},
		{"key": "scar", "label": "Cicatrice", "names": GameState.SCARS},
		{"key": "suit", "label": "Combinaison", "colors": GameState.SUITS},
	]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#15171b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	ui = Control.new()
	ui.size = Vector2(1280, 720)
	add_child(ui)
	_build_ui()
	get_viewport().size_changed.connect(_center_ui)
	_center_ui()
	_refresh()


func _center_ui() -> void:
	var d := get_viewport_rect().size - Vector2(1280, 720)
	ui.position = Vector2(maxf(0.0, d.x), maxf(0.0, d.y)) / 2.0


func _label(text: String, pos: Vector2, px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", px)
	ui.add_child(l)
	return l


func _button(text: String, pos: Vector2, sz: Vector2, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", px)
	ui.add_child(b)
	return b


func _build_ui() -> void:
	_label("CRÉE TON DÉTENU", Vector2(40, 12), 36)

	preview = PreviewScript.new()
	preview.position = Vector2(40, 70)
	preview.size = Vector2(560, 470)
	ui.add_child(preview)

	name_edit = LineEdit.new()
	name_edit.position = Vector2(40, 556)
	name_edit.size = Vector2(560, 56)
	name_edit.placeholder_text = "Nom du détenu"
	name_edit.max_length = 16
	name_edit.text = str(GameState.ap["name"])
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.text_changed.connect(func(txt: String) -> void: GameState.ap["name"] = txt)
	ui.add_child(name_edit)

	var rnd := _button("Aléatoire", Vector2(40, 626), Vector2(270, 64), 26)
	rnd.pressed.connect(_randomize)


	var y := 70.0
	for o in opts:
		_make_row(o, y)
		y += 62.0

	var go := _button("COMMENCER", Vector2(660, 590), Vector2(580, 100), 38)
	go.pressed.connect(_start)


func _make_row(o: Dictionary, y: float) -> void:
	var x0 := 660.0
	_label(o["label"], Vector2(x0, y + 10), 24)
	var left := _button("◀", Vector2(x0 + 170, y), Vector2(72, 54), 26)
	var right := _button("▶", Vector2(x0 + 508, y), Vector2(72, 54), 26)
	var swatch := ColorRect.new()
	swatch.position = Vector2(x0 + 256, y + 7)
	swatch.size = Vector2(236, 40)
	ui.add_child(swatch)
	var val := _label("", Vector2(x0 + 256, y + 10), 24)
	val.size = Vector2(236, 40)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.pressed.connect(_shift.bind(o["key"], -1))
	right.pressed.connect(_shift.bind(o["key"], 1))
	rows.append({"o": o, "swatch": swatch, "val": val})


func _count(o: Dictionary) -> int:
	if o.has("colors"):
		return o["colors"].size()
	return o["names"].size()


func _shift(key: String, dir: int) -> void:
	for r in rows:
		if r["o"]["key"] == key:
			var n := _count(r["o"])
			GameState.ap[key] = (int(GameState.ap[key]) + dir + n) % n
	_refresh()


func _refresh() -> void:
	for r in rows:
		var o: Dictionary = r["o"]
		var idx := clampi(int(GameState.ap[o["key"]]), 0, _count(o) - 1)
		if o.has("colors"):
			r["swatch"].visible = true
			r["swatch"].color = o["colors"][idx]
			r["val"].visible = false
		else:
			r["swatch"].visible = false
			r["val"].visible = true
			r["val"].text = o["names"][idx]
	preview.queue_redraw()


func _randomize() -> void:
	for o in opts:
		GameState.ap[o["key"]] = randi_range(0, _count(o) - 1)
	_refresh()


func _start() -> void:
	GameState.save_character()
	get_tree().change_scene_to_file("res://intro.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
