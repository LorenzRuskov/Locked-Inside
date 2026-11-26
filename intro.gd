extends Control

# Introduction narrative : arrivée à Fort-Noir, 5 questions qui forment le dossier du détenu.
# Touche / clic : continuer. Touches 1-4 : répondre. Les réponses modifient GameState.story.

const BgScript := preload("res://intro_bg.gd")
const TYPE_SPEED := 48.0

var ui: Control
var story_label: Label
var hint: Label
var title_label: Label
var sub_label: Label
var buttons: Array = []
var steps: Array = []
var step_i := -1
var typing := false
var chars := 0.0
var awaiting_choice := false
var in_reaction := false
var finished := false
var t := 0.0


func _ready() -> void:
	GameState.reset_story()
	steps = _build_steps()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#07080b")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	ui = Control.new()
	ui.size = Vector2(1280, 720)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	var scene_bg = BgScript.new()
	scene_bg.size = Vector2(1280, 720)
	scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(scene_bg)

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.position = Vector2(100, 100)
	panel.size = Vector2(1080, 540)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)

	story_label = Label.new()
	story_label.position = Vector2(140, 130)
	story_label.size = Vector2(1000, 180)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 30)
	story_label.add_theme_constant_override("line_spacing", 8)
	story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(story_label)

	title_label = Label.new()
	title_label.position = Vector2(0, 250)
	title_label.size = Vector2(1280, 110)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 84)
	title_label.visible = false
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_label)

	sub_label = Label.new()
	sub_label.position = Vector2(0, 370)
	sub_label.size = Vector2(1280, 40)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.visible = false
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(sub_label)

	hint = Label.new()
	hint.text = "Touche l'écran pour continuer  ▼"
	hint.position = Vector2(0, 656)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.visible = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hint)

	for i in range(4):
		var b := Button.new()
		b.position = Vector2(140, 330 + i * 76)
		b.size = Vector2(1000, 68)
		b.add_theme_font_size_override("font_size", 26)
		b.visible = false
		b.pressed.connect(_choose.bind(i))
		ui.add_child(b)
		buttons.append(b)

	var skip := Button.new()
	skip.text = "Passer ›"
	skip.position = Vector2(1090, 24)
	skip.size = Vector2(160, 48)
	skip.add_theme_font_size_override("font_size", 22)
	skip.pressed.connect(_finish)
	ui.add_child(skip)

	get_viewport().size_changed.connect(_center_ui)
	_center_ui()
	_next_step()


func _center_ui() -> void:
	var d := get_viewport_rect().size - Vector2(1280, 720)
	ui.position = Vector2(maxf(0.0, d.x), maxf(0.0, d.y)) / 2.0


func _process(delta: float) -> void:
	t += delta
	hint.modulate.a = 0.45 + 0.35 * sin(t * 4.0)
	if typing:
		chars += delta * TYPE_SPEED
		var n := int(chars)
		story_label.visible_characters = n
		if n >= story_label.text.length():
			_on_typed()


func _input(event: InputEvent) -> void:
	if finished:
		return
	if awaiting_choice:
		if event is InputEventKey and event.pressed and not event.echo:
			var idx := int(event.keycode) - int(KEY_1)
			if idx >= 0 and idx < steps[step_i]["options"].size():
				_choose(idx)
		return
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E):
		go = true
	if go:
		_advance()


func _advance() -> void:
	if typing:
		_on_typed()
		return
	_next_step()


func _show(text: String) -> void:
	story_label.visible = true
	title_label.visible = false
	sub_label.visible = false
	story_label.text = text.replace("{nom}", str(GameState.ap["name"]))
	story_label.visible_characters = 0
	chars = 0.0
	typing = true
	hint.visible = false


func _on_typed() -> void:
	typing = false
	story_label.visible_characters = -1
	var st: Dictionary = steps[step_i]
	if st["type"] == "choice" and not in_reaction:
		_show_choices(st)
	else:
		hint.visible = true


func _show_choices(st: Dictionary) -> void:
	var opts: Array = st["options"]
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		if i < opts.size():
			b.text = "%d.  %s" % [i + 1, opts[i]["label"]]
			b.visible = true
		else:
			b.visible = false
	awaiting_choice = true
	hint.visible = false


func _hide_choices() -> void:
	for b in buttons:
		b.visible = false


func _choose(i: int) -> void:
	if not awaiting_choice:
		return
	var opt: Dictionary = steps[step_i]["options"][i]
	GameState.apply_choice(opt)
	awaiting_choice = false
	_hide_choices()
	in_reaction = true
	_show(opt["react"])


func _next_step() -> void:
	step_i += 1
	in_reaction = false
	_hide_choices()
	if step_i >= steps.size():
		_finish()
		return
	var st: Dictionary = steps[step_i]
	match st["type"]:
		"text":
			_show(st["text"])
		"choice":
			_show(st["q"])
		"title":
			typing = false
			story_label.visible = false
			title_label.text = "LOCKED INSIDE"
			sub_label.text = "Fort-Noir · Cellule " + GameState.cell_label() + ((" · Détenu " + GameState.inmate_label()) if GameState.inmate_label() != "" else "")
			title_label.visible = true
			sub_label.visible = true
			hint.visible = true


func _finish() -> void:
	if finished:
		return
	finished = true
	GameState.save_story()
	GameState.reset_progress()
	get_tree().change_scene_to_file("res://main.tscn")


func _t(text: String) -> Dictionary:
	return {"type": "text", "text": text}


func _c(q: String, options: Array) -> Dictionary:
	return {"type": "choice", "q": q, "options": options}


func _o(label: String, react: String, stats: Dictionary, rep: Dictionary, set_vals: Dictionary) -> Dictionary:
	return {"label": label, "react": react, "stats": stats, "rep": rep, "set": set_vals}


func _build_steps() -> Array:
	return [
		_t("Nuit noire. Le fourgon cellulaire s'arrête dans un long grincement de freins.\n\nDehors : des projecteurs, des aboiements, des ordres criés. L'air sent le métal froid et la pluie."),
		_t("La porte arrière s'ouvre à la volée. Une voix rauque te tire hors du fourgon :\n\n« Debout, {nom}. Bienvenue à Fort-Noir. Ici, personne ne vient te chercher. »"),
		_t("Au greffe, un surveillant au visage fermé ouvre ton dossier. Il lève à peine les yeux."),
		_c("« Motif de la condamnation ? »", [
			_o("Un braquage qui a mal tourné",
				"Le surveillant hoche la tête, comme s'il l'avait deviné. Dans la file, quelques regards se tournent vers toi : ici, on sait ce que ça veut dire.",
				{"force": 1, "sang_froid": 1}, {}, {"crime": "Braquage"}),
			_o("Une escroquerie à grande échelle",
				"Un sourire en coin dans ton dos. Ici, un cerveau vaut plus qu'un poing… à condition de savoir le cacher.",
				{"ruse": 2}, {}, {"crime": "Escroquerie"}),
			_o("Des coups mortels lors d'une bagarre",
				"Le silence tombe sur la salle. Tu viens de gagner du respect… et des ennemis.",
				{"force": 2}, {"detenus": 1, "gardiens": -1}, {"crime": "Homicide involontaire"}),
			_o("Rien. Je suis innocent.",
				"Personne ne rit. Mais personne ne te croit non plus.",
				{"charisme": 1, "sang_froid": 1}, {}, {"crime": "Se dit innocent"}),
		]),
		_t("Un tampon claque sur le papier. Tu n'es plus qu'un numéro de plus. On te remet une combinaison, une couverture usée et un savon fendu."),
		_c("« Et avant tout ça, tu faisais quoi ? »", [
			_o("J'étais militaire",
				"Le surveillant te regarde autrement. Les vieux réflexes ne se perdent pas.",
				{"force": 1, "sang_froid": 1}, {}, {"past": "Ancien militaire"}),
			_o("J'étais étudiant, plutôt brillant",
				"« Un intello… » marmonne quelqu'un. Tu retiens son visage.",
				{"ruse": 1, "charisme": 1}, {}, {"past": "Étudiant brillant"}),
			_o("Je vendais dans mon quartier",
				"Tu connais déjà les codes de la rue. Ceux de la prison ne sont pas si différents.",
				{"ruse": 1, "sang_froid": 1}, {}, {"past": "Dealer de quartier"}),
			_o("J'étais mécano",
				"Tes mains calleuses disent tout. Savoir réparer des choses sera utile ici.",
				{"force": 1, "ruse": 1}, {}, {"past": "Mécanicien"}),
		]),
		_t("On te pousse dans un long couloir. Les barreaux claquent sur ton passage. Des visages se collent aux grilles, t'observent, te jaugent."),
		_c("Un détenu te bouscule exprès, sous les rires de ses amis. Tu…", [
			_o("Baisses les yeux et avances",
				"Les rires s'étouffent. Tu as évité les ennuis… pour l'instant. Certains ont noté ta faiblesse.",
				{"sang_froid": 1}, {"detenus": -1, "gardiens": 1}, {"attitude": "Discret"}),
			_o("Soutiens son regard sans un mot",
				"Quelques secondes interminables. Il finit par s'écarter. Le couloir t'observe.",
				{"sang_froid": 2}, {"detenus": 1}, {"attitude": "Impassible"}),
			_o("Souris et lâches une blague",
				"Un rire éclate, puis un autre. L'ambiance se détend. Même le bousculeur esquisse un sourire.",
				{"charisme": 2}, {}, {"attitude": "Charmeur"}),
			_o("Le frappes en premier",
				"Il s'effondre. Le couloir se fige, une sirène retentit : tu viens de te faire remarquer de tous, détenus comme gardiens.",
				{"force": 1}, {"detenus": 2, "gardiens": -2}, {"attitude": "Violent"}),
		]),
		_t("Le surveillant ne dit rien. Il a tout vu. Il note quelque chose dans son carnet."),
		_t("Cellule " + GameState.cell_label() + ". Un lit superposé, des toilettes en inox, une fenêtre grillagée. La porte se referme derrière toi. Le verrou tourne deux fois."),
		_c("Cette nuit-là, une pensée t'empêche de dormir. Qu'est-ce qui t'attend dehors ?", [
			_o("Ma famille, qui m'attend",
				"Tu serres le poing. Pour eux, tu tiendras.",
				{"sang_froid": 1}, {}, {"motivation": "Famille"}),
			_o("Une dette à rembourser",
				"Le temps joue contre toi. Chaque jour ici coûte un peu plus cher.",
				{"ruse": 1}, {}, {"motivation": "Dette"}),
			_o("Quelqu'un à qui faire payer",
				"La colère te garde éveillé. Elle te gardera en vie.",
				{"force": 1}, {}, {"motivation": "Vengeance"}),
			_o("Personne. Et c'est peut-être pire",
				"Rien à perdre. L'idée est à la fois effrayante et étrangement libératrice.",
				{"sang_froid": 1}, {}, {"motivation": "Aucune attache"}),
		]),
		_c("Pendant la fouille, tu as réussi à cacher une chose. Laquelle ?", [
			_o("Une photo froissée",
				"Tu la glisses sous le matelas. Un visage pour tenir bon.",
				{"sang_froid": 1}, {}, {"item": "Photo froissée"}),
			_o("Une cuillère aiguisée",
				"Un bout de métal limé en pointe. Dangereux. Utile.",
				{"force": 1}, {}, {"item": "Cuillère aiguisée"}),
			_o("Un paquet de cigarettes",
				"Ici, c'est de la monnaie. Mieux vaut que personne ne le sache.",
				{"charisme": 1}, {}, {"item": "Paquet de cigarettes"}),
			_o("Un fragment de plan de la prison",
				"Un papier plié en huit. Il en manque la moitié, mais c'est un début.",
				{"ruse": 1}, {}, {"item": "Fragment de plan"}),
		]),
		_t("De l'autre côté du mur, une voix étouffée murmure :\n\n« Nouveau, hein ? Tu verras… On sort tous d'ici un jour. D'une manière ou d'une autre. »"),
		{"type": "title"},
	]
