extends RefCounted

# Données des pièces de la prison (inspirées de l'ancien Locked Inside :
# aile B, infirmerie, atelier, mitard) + une cour de promenade.
# Chaque pièce : sol (floor), hauteur de mur, décor (theme), lampes, meubles (props).
# "arrive" = où apparaît le joueur selon la pièce d'où il vient.


const ORDER := ["cell", "allee", "salle_commune", "infirmerie", "atelier", "cantine", "cour", "parloir", "administration", "isolement", "mitard"]
const WING_SIZE := 10   # cellules par aile (= 20 détenus = taille d'une instance de pièce)


# Les anciennes sauvegardes parlent encore du « couloir » : c'est devenu la salle commune
static func canon(id: String) -> String:
	return "salle_commune" if id == "couloir" else id


# Numéro de la cellule du joueur (hors ligne : « 12B », 3e porte de l'aile A)
static func own_cell_id() -> int:
	if Net.online and Net.cell_id > 0:
		return Net.cell_id
	return 3


static func wing_of(cid: int) -> int:
	return int(floor(float(cid - 1) / float(WING_SIZE)))


static func wing_letter(cid: int) -> String:
	return char(65 + wing_of(cid))


static func floor_at(w: float, h: float) -> Rect2:
	return Rect2(640.0 - w / 2.0, 300.0, w, h)


static func get_room(id: String) -> Dictionary:
	match canon(id):
		"allee":
			return _allee()
		"salle_commune":
			return _salle_commune()
		"cantine":
			return _cantine()
		"parloir":
			return _parloir()
		"administration":
			return _administration()
		"isolement":
			return _isolement()
		"infirmerie":
			return _infirmerie()
		"atelier":
			return _atelier()
		"cour":
			return _cour()
		"mitard":
			return _mitard()
	return _cell()


# ---------- Outils de description ----------

static func _p(kind: String, x: float, y: float, w: float, d: float, h: float, hint: String, msg: String, menu: Array = [], solid: bool = true, extra: Dictionary = {}) -> Dictionary:
	return {"kind": kind, "pos": Vector2(x, y), "w": w, "d": d, "h": h, "hint": hint, "msg": msg, "menu": menu, "solid": solid, "extra": extra}


static func _go(room: String, label: String = "") -> Dictionary:
	return {"id": "go", "arg": room, "label": label}


static func _a(id: String) -> Dictionary:
	return {"id": id, "arg": "", "label": ""}


static func _lamp(kind: String, x: float, energy: float, radius: float, color: Color, length: float = 128.0, amp: float = 0.2, phase: float = 0.0, flicker: float = 0.0) -> Dictionary:
	return {"kind": kind, "x": x, "energy": energy, "radius": radius, "color": color, "length": length, "amp": amp, "phase": phase, "flicker": flicker}


# ---------- Les pièces ----------

static func _cell() -> Dictionary:
	return {
		"id": "cell", "title": "Cellule " + GameState.cell_label(), "floor": floor_at(400.0, 230.0), "wall_h": 120.0,
		"theme": {"tally": true, "drain": true, "patch": true, "pipes": true, "puddles": 1},
		"ambient": Color("#3f4558"), "vignette": 0.85,
		"window": true, "window_light": {"energy": 0.35, "radius": 230.0},
		"lamps": [_lamp("bulb", 640.0, 0.8, 300.0, Color(1.0, 0.86, 0.6))],
		"extra_lights": [],
		"spawns": [Vector2(600, 470), Vector2(690, 480)],
		"arrive": {"allee": Vector2(715, 350), "mitard": Vector2(715, 350), "isolement": Vector2(715, 350)},
		"props": [
			_p("bunk", 520, 370, 150, 70, 54, "Lit superposé", "@bunk", [_a("meditate"), _a("use_med")]),
			_p("toilet", 805, 340, 38, 34, 28, "Toilettes", "Rien d'intéressant... pour l'instant."),
			_p("desk", 790, 430, 90, 36, 30, "Table", "Une table scellée au mur. Un crayon cassé traîne dessus.", [_a("search")]),
			_p("locker", 625, 332, 42, 32, 66, "Casier", "Casier verrouillé. Il te faudrait une clé... ou de la force.", [_a("force_locker")]),
			_p("door", 715, 302, 70, 10, 104, "Porte de la cellule", "", [_go("allee", "Sortir dans l'allée")], false, {"label": GameState.cell_label()}),
		],
	}


# ---------- Aile de cellules, salle commune et nouvelles pièces ----------

static func _allee() -> Dictionary:
	var own := own_cell_id()
	var wing := wing_of(own)
	var own_i := (own - 1) % WING_SIZE
	var props: Array = []
	for i in range(WING_SIZE):
		var x := 190.0 + 100.0 * i
		var cid := wing * WING_SIZE + i + 1
		var door_label := "%04d" % cid
		if i == own_i:
			door_label = GameState.cell_label()
			props.append(_p("door", x, 302, 60, 10, 100, "Ta cellule", "", [_go("cell", "Entrer dans ta cellule")], false, {"label": door_label, "col": Color("#7a8a6a")}))
		else:
			props.append(_p("door", x, 302, 60, 10, 100, "Cellule " + door_label, "Cellule %s. La porte est verrouillée. Derrière, une radio grésille." % door_label, [_a("cell_door")], false, {"label": door_label, "col": Color("#56606a")}))
	props.append(_p("gate", 128, 302, 52, 10, 104, "Grille vers la salle commune", "", [_go("salle_commune", "Aller à la salle commune")], false, {"label": "COMMUNE"}))
	props.append(_p("gate", 1152, 302, 52, 10, 104, "Grille du quartier d'isolement", "", [_go("isolement", "Aller au quartier d'isolement")], false, {"label": "ISOLEMENT"}))
	props.append(_p("board", 640, 392, 80, 20, 40, "Tableau d'affichage", "Planning des douches, liste des sanctions. Un nom est barré au feutre rouge."))
	props.append(_p("bench", 420, 400, 110, 26, 22, "Banc", "Un banc scellé au sol, poli par des années d'attente.", [_a("chat")]))
	props.append(_p("bench", 880, 400, 110, 26, 22, "Banc", "Un banc scellé au sol. On y murmure des choses qu'on ne répète pas.", [_a("chat")]))
	return {
		"id": "allee", "title": "Allée · Aile " + wing_letter(own), "floor": floor_at(1100.0, 170.0), "wall_h": 120.0,
		"theme": {"wall_a": "#8e9094", "wall_b": "#5d6066", "wall_line": "#34363a", "floor": "#6a6d72", "pilasters": 100.0, "pipes": true, "vents": true, "sheen": true, "puddles": 1, "dirt": 1.0, "stripe_y": 0.9, "stripe_col": Color(0.9, 0.78, 0.2, 0.35)},
		"ambient": Color("#3e4458"), "vignette": 0.8,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 270.0, 0.6, 260.0, Color(1.0, 0.95, 0.8), 0.0, 0.0, 0.0, 0.0),
			_lamp("tube", 520.0, 0.6, 260.0, Color(1.0, 0.95, 0.8), 0.0, 0.0, 1.1, 0.15),
			_lamp("tube", 770.0, 0.6, 260.0, Color(1.0, 0.95, 0.8), 0.0, 0.0, 2.2, 0.0),
			_lamp("tube", 1020.0, 0.6, 260.0, Color(1.0, 0.95, 0.8), 0.0, 0.0, 3.3, 0.5),
		],
		"extra_lights": [],
		"follow": true, "zoom": 1.4,
		"spawns": [Vector2(640, 380), Vector2(700, 400)],
		"guards": [
			{"name": "Dupont", "speed": 38.0, "phase": 0.0, "path": [Vector2(220, 360), Vector2(1060, 360), Vector2(1060, 440), Vector2(220, 440)]},
		],
		"arrive": {"cell": Vector2(190.0 + 100.0 * own_i, 350), "salle_commune": Vector2(190, 360), "isolement": Vector2(1090, 360)},
		"props": props,
	}


static func _salle_commune() -> Dictionary:
	return {
		"id": "salle_commune", "title": "Salle commune", "floor": floor_at(900.0, 300.0), "wall_h": 130.0,
		"theme": {"wall_a": "#8b8e8c", "wall_b": "#5e615f", "wall_line": "#34363a", "floor": "#74777b", "pilasters": 220.0, "pipes": true, "vents": true, "sheen": true, "puddles": 2, "tile": 60.0, "dirt": 1.1},
		"ambient": Color("#424860"), "vignette": 0.7,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 330.0, 0.65, 300.0, Color(1.0, 0.95, 0.82)),
			_lamp("tube", 640.0, 0.65, 300.0, Color(1.0, 0.95, 0.82), 0.0, 0.0, 1.4, 0.15),
			_lamp("tube", 950.0, 0.65, 300.0, Color(1.0, 0.95, 0.82), 0.0, 0.0, 2.8, 0.0),
		],
		"extra_lights": [{"pos": Vector2(717, 258), "color": Color(0.55, 0.75, 1.0), "energy": 0.35, "radius": 170.0}],
		"follow": true, "zoom": 1.3,
		"spawns": [Vector2(640, 440), Vector2(680, 460)],
		"guards": [
			{"name": "Martin", "speed": 42.0, "phase": 0.0, "path": [Vector2(280, 360), Vector2(1000, 360), Vector2(1000, 540), Vector2(280, 540)]},
		],
		"arrive": {"allee": Vector2(235, 350), "infirmerie": Vector2(365, 350), "atelier": Vector2(495, 350), "cantine": Vector2(640, 350), "cour": Vector2(785, 350), "parloir": Vector2(915, 350)},
		"props": [
			_p("gate", 235, 302, 56, 10, 104, "Grille vers l'allée", "", [_go("allee", "Retourner à l'allée des cellules")], false, {"label": "ALLÉE"}),
			_p("door", 365, 302, 70, 10, 104, "Infirmerie", "", [_go("infirmerie", "Entrer à l'infirmerie")], false, {"label": "INFIRMERIE", "col": Color("#c9d3d2")}),
			_p("door", 495, 302, 70, 10, 104, "Atelier", "", [_go("atelier", "Entrer à l'atelier")], false, {"label": "ATELIER", "col": Color("#6b5d49")}),
			_p("door", 640, 302, 90, 10, 104, "Cantine", "", [_go("cantine", "Entrer à la cantine")], false, {"label": "CANTINE", "col": Color("#8a8f6a")}),
			_p("door", 785, 302, 70, 10, 104, "Cour de promenade", "", [_go("cour", "Sortir dans la cour")], false, {"label": "COUR", "col": Color("#4d5c6b")}),
			_p("door", 915, 302, 70, 10, 104, "Parloir", "", [_go("parloir", "Aller au parloir")], false, {"label": "PARLOIR", "col": Color("#6a5a7a")}),
			_p("tv", 717, 302, 50, 8, 60, "Télévision", "Un jeu télévisé sans le son. Tout le monde regarde quand même."),
			_p("phone", 562, 302, 34, 8, 52, "Téléphone", "Une file de détenus attend pour appeler. Le combiné est collant."),
			_p("board", 1040, 302, 60, 8, 40, "Règlement intérieur", "Le règlement intérieur, couvert de graffitis. Article 1 : le détenu obéit.", [_a("read_rules")]),
			_p("mess_table", 430, 450, 130, 40, 28, "Table de jeu", "Des cartes cornées, un échiquier sans reine.", [_a("chat"), _a("trade")]),
			_p("mess_table", 850, 450, 130, 40, 28, "Table de jeu", "Une partie de dames s'éternise ici depuis des années.", [_a("chat"), _a("trade")]),
			_p("bench", 640, 560, 160, 28, 22, "Banc", "Un banc scellé au sol, face à la télévision.", [_a("chat")]),
			_p("sofa", 250, 540, 120, 40, 30, "Canapé", "Un canapé éventré. Il garde l'odeur de dix mille après-midi."),
		],
	}


static func _cantine() -> Dictionary:
	return {
		"id": "cantine", "title": "Cantine", "floor": floor_at(760.0, 260.0), "wall_h": 125.0,
		"theme": {"wall_a": "#a6a897", "wall_b": "#77796a", "wall_line": "#46473d", "floor": "#9a9d94", "checker": "#d8dad2", "tile": 50.0, "pipes": true, "vents": true, "sheen": true, "puddles": 1, "dirt": 0.7, "wall_text": "RÉFECTOIRE", "wall_text_x": 270.0},
		"ambient": Color("#555a66"), "vignette": 0.6,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 440.0, 0.75, 290.0, Color(1.0, 0.97, 0.88)),
			_lamp("tube", 640.0, 0.75, 290.0, Color(1.0, 0.97, 0.88), 0.0, 0.0, 1.0, 0.1),
			_lamp("tube", 840.0, 0.75, 290.0, Color(1.0, 0.97, 0.88)),
		],
		"extra_lights": [],
		"spawns": [Vector2(640, 400), Vector2(680, 420)],
		"guards": [
			{"name": "Bruno", "title": "Cuisinier", "guard": false, "speed": 0.0, "phase": 0.0, "path": [Vector2(860, 338)], "menu": [_a("eat")]},
			{"name": "Garnier", "speed": 30.0, "phase": 0.0, "path": [Vector2(300, 520), Vector2(980, 520), Vector2(980, 360), Vector2(300, 360)]},
		],
		"arrive": {"salle_commune": Vector2(640, 340)},
		"props": [
			_p("door", 640, 302, 70, 10, 104, "Porte vers la salle commune", "", [_go("salle_commune", "Retourner à la salle commune")], false, {"label": "COMMUNE", "col": Color("#8a8f6a")}),
			_p("counter", 860, 365, 170, 36, 34, "Comptoir de service", "Des bacs chauffants. Une louche attachée par une chaîne.", [_a("eat")]),
			_p("mess_table", 370, 440, 140, 38, 28, "Table", "Une table de réfectoire. Des plateaux, des miettes.", [_a("trade"), _a("chat")]),
			_p("mess_table", 560, 440, 140, 38, 28, "Table", "Une table de réfectoire. Des plateaux, des miettes.", [_a("trade"), _a("chat")]),
			_p("mess_table", 370, 530, 140, 38, 28, "Table", "Une table de réfectoire. Des initiales gravées dans l'inox.", [_a("trade"), _a("chat")]),
			_p("mess_table", 560, 530, 140, 38, 28, "Table", "Une table de réfectoire. Des initiales gravées dans l'inox.", [_a("trade"), _a("chat")]),
			_p("mess_table", 790, 500, 140, 38, 28, "Table", "La table des Anciens. Personne ne s'y assoit sans y être invité.", [_a("trade"), _a("chat")]),
			_p("board", 450, 302, 70, 8, 40, "Menu de la semaine", "Lundi : purée. Mardi : purée. Mercredi : une surprise (purée)."),
		],
	}


static func _parloir() -> Dictionary:
	return {
		"id": "parloir", "title": "Parloir", "floor": floor_at(720.0, 240.0), "wall_h": 120.0,
		"theme": {"wall_a": "#9a92a4", "wall_b": "#6d6578", "wall_line": "#3a3442", "floor": "#7c7a80", "tile": 60.0, "sheen": true, "dirt": 0.6, "puddles": 0},
		"ambient": Color("#4a4a62"), "vignette": 0.7,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 450.0, 0.65, 260.0, Color(0.95, 0.95, 1.0)),
			_lamp("tube", 700.0, 0.65, 260.0, Color(0.95, 0.95, 1.0), 0.0, 0.0, 1.5, 0.1),
			_lamp("tube", 900.0, 0.65, 260.0, Color(0.95, 0.95, 1.0)),
		],
		"extra_lights": [],
		"spawns": [Vector2(440, 400), Vector2(480, 420)],
		"guards": [
			{"name": "Perrin", "speed": 0.0, "phase": 0.0, "path": [Vector2(660, 475)]},
		],
		"arrive": {"salle_commune": Vector2(400, 350), "administration": Vector2(950, 350)},
		"props": [
			_p("door", 400, 302, 70, 10, 104, "Porte vers la salle commune", "", [_go("salle_commune", "Retourner à la salle commune")], false, {"label": "COMMUNE", "col": Color("#6a5a7a")}),
			_p("door", 950, 302, 70, 10, 104, "Administration", "", [_go("administration", "Aller à l'administration")], false, {"label": "ADMIN", "col": Color("#7a6a4a")}),
			_p("booth", 520, 395, 100, 30, 34, "Cabine de parloir", "Une vitre épaisse, un combiné. De l'autre côté, un tabouret vide.", [_a("visit")]),
			_p("booth", 680, 395, 100, 30, 34, "Cabine de parloir", "Une vitre épaisse, un combiné. De l'autre côté, un tabouret vide.", [_a("visit")]),
			_p("booth", 840, 395, 100, 30, 34, "Cabine de parloir", "Une vitre épaisse, un combiné. De l'autre côté, un tabouret vide.", [_a("visit")]),
			_p("bench", 470, 515, 110, 26, 22, "Banc d'attente", "On attend son tour, en regardant la porte."),
			_p("bench", 850, 515, 110, 26, 22, "Banc d'attente", "On attend son tour, en regardant la porte."),
		],
	}


static func _administration() -> Dictionary:
	return {
		"id": "administration", "title": "Administration", "floor": floor_at(560.0, 200.0), "wall_h": 120.0,
		"theme": {"wall_a": "#cfc8b4", "wall_b": "#a39a80", "wall_line": "#625a45", "floor": "#6e5a49", "carpet": true, "dirt": 0.2, "puddles": 0},
		"ambient": Color("#6a5f58"), "vignette": 0.5,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("bulb", 520.0, 0.7, 260.0, Color(1.0, 0.88, 0.65)),
			_lamp("bulb", 760.0, 0.7, 260.0, Color(1.0, 0.88, 0.65), 80.0, 0.05, 1.0, 0.0),
		],
		"extra_lights": [],
		"spawns": [Vector2(430, 400), Vector2(470, 410)],
		"guards": [
			{"name": "Roche", "title": "Greffière", "guard": false, "speed": 0.0, "phase": 0.0, "path": [Vector2(640, 345)], "menu": [_a("paperwork")]},
		],
		"arrive": {"parloir": Vector2(420, 350)},
		"props": [
			_p("door", 420, 302, 70, 10, 104, "Retour au parloir", "", [_go("parloir", "Retourner au parloir")], false, {"label": "PARLOIR", "col": Color("#7a6a4a")}),
			_p("reception", 640, 380, 170, 44, 36, "Guichet de la greffe", "Un tampon, un registre, un regard fatigué.", [_a("paperwork")]),
			_p("filing", 820, 345, 60, 30, 78, "Classeurs", "Des dossiers de détenus. Le tien est quelque part là-dedans."),
			_p("filing", 890, 345, 60, 30, 78, "Classeurs", "Des dossiers d'incidents. Tous scellés."),
			_p("sofa", 520, 470, 110, 36, 28, "Banquette d'attente", "On y attend en tenant son dossier."),
			_p("board", 560, 302, 70, 8, 40, "Panneau d'information", "Les horaires de la greffe. Fermée de 12 h à 14 h."),
		],
	}


static func _isolement() -> Dictionary:
	return {
		"id": "isolement", "title": "Quartier d'isolement", "floor": floor_at(760.0, 180.0), "wall_h": 120.0,
		"theme": {"wall_a": "#55595a", "wall_b": "#3a3d3e", "wall_line": "#232526", "floor": "#4a4d52", "pilasters": 190.0, "pipes": true, "sheen": true, "puddles": 2, "emergency": true, "dirt": 1.6, "stripe_y": 0.9, "stripe_col": Color(0.85, 0.2, 0.15, 0.4)},
		"ambient": Color("#2b2f3c"), "vignette": 0.95,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 480.0, 0.5, 240.0, Color(1.0, 0.85, 0.7), 0.0, 0.0, 0.7, 0.6),
			_lamp("tube", 800.0, 0.5, 240.0, Color(1.0, 0.85, 0.7), 0.0, 0.0, 2.0, 0.2),
		],
		"extra_lights": [{"pos": Vector2(640, 312), "color": Color(1.0, 0.2, 0.15), "energy": 0.25, "radius": 360.0}],
		"spawns": [Vector2(300, 380), Vector2(340, 400)],
		"guards": [],
		"arrive": {"allee": Vector2(300, 360), "mitard": Vector2(560, 360)},
		"props": [
			_p("gate", 280, 302, 56, 10, 104, "Grille vers l'allée", "", [_go("allee", "Retourner à l'allée des cellules")], false, {"label": "ALLÉE"}),
			_p("door", 560, 302, 64, 10, 100, "Mitard", "La porte blindée du mitard 1. Elle ne s'ouvre que de l'extérieur.", [_a("cell_door")], false, {"label": "MITARD 1", "col": Color("#3a3d41")}),
			_p("door", 700, 302, 64, 10, 100, "Mitard", "Le mitard 2 est vide. Une odeur de désinfectant et de peur.", [_a("cell_door")], false, {"label": "MITARD 2", "col": Color("#3a3d41")}),
			_p("door", 840, 302, 64, 10, 100, "Mitard", "Le mitard 3 : quelqu'un frappe doucement, à intervalles réguliers.", [_a("cell_door")], false, {"label": "MITARD 3", "col": Color("#3a3d41")}),
			_p("guard_desk", 960, 400, 90, 36, 34, "Poste du gardien de service", "Le poste du gardien d'isolement. Un trousseau de clés pend à un clou."),
		],
	}


static func _infirmerie() -> Dictionary:
	return {
		"id": "infirmerie", "title": "Infirmerie", "floor": floor_at(520.0, 210.0), "wall_h": 120.0,
		"theme": {"wall_a": "#d6dcdb", "wall_b": "#79a3a0", "wall_line": "#3f6663", "floor": "#b4bab9", "checker": "#e6ecea", "sheen": true, "vents": true, "tile": 40.0, "dirt": 0.4},
		"ambient": Color("#586072"), "vignette": 0.55,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("tube", 520.0, 0.75, 280.0, Color(0.85, 1.0, 0.95)),
			_lamp("tube", 760.0, 0.75, 280.0, Color(0.85, 1.0, 0.95)),
		],
		"extra_lights": [],
		"spawns": [Vector2(780, 380), Vector2(800, 400)],
		"guards": [
			{"name": "Vidal", "title": "Infirmière", "guard": false, "speed": 0.0, "phase": 0.0, "path": [Vector2(760, 392)],
				"menu": [_a("heal_free"), _a("heal_paid")]},
			{"name": "Sanchez", "speed": 34.0, "phase": 0.0, "path": [Vector2(560, 372), Vector2(660, 372), Vector2(660, 480), Vector2(560, 480)]},
		],
		"arrive": {"salle_commune": Vector2(830, 360)},
		"props": [
			_p("door", 830, 302, 70, 10, 104, "Porte vers la salle commune", "", [_go("salle_commune", "Retourner à la salle commune")], false, {"label": "COMMUNE", "col": Color("#c9d3d2")}),
			_p("medbed", 450, 380, 110, 60, 34, "Lit médicalisé", "Un lit médicalisé aux draps trop blancs.", [_a("heal_free")]),
			_p("medbed", 450, 470, 110, 60, 34, "Lit médicalisé", "Un lit occupé par un détenu qui ronfle, perfusé."),
			_p("cabinet", 640, 330, 90, 30, 92, "Armoire à pharmacie", "Une armoire vitrée fermée à clé. Des boîtes de médicaments derrière la vitre.", [_a("steal_meds")]),
			_p("nurse_desk", 760, 440, 130, 44, 36, "Bureau de l'infirmière", "L'infirmière trie des dossiers. « Tu saignes ? Non ? Alors dehors. »", [_a("heal_paid")]),
		],
	}


static func _atelier() -> Dictionary:
	return {
		"id": "atelier", "title": "Atelier", "floor": floor_at(620.0, 220.0), "wall_h": 120.0,
		"theme": {"wall_a": "#8d897e", "wall_b": "#575346", "wall_line": "#2e2b24", "floor": "#6c6f71", "pilasters": 220.0, "pipes": true, "sheen": true, "puddles": 2, "stripe_y": 0.93, "stripe_col": Color(0.9, 0.78, 0.2, 0.45), "dirt": 1.4},
		"ambient": Color("#40445a"), "vignette": 0.75,
		"window": false, "window_light": {},
		"lamps": [
			_lamp("bulb", 520.0, 0.6, 240.0, Color(1.0, 0.88, 0.62), 80.0, 0.08, 0.0),
			_lamp("bulb", 700.0, 0.6, 240.0, Color(1.0, 0.88, 0.62), 80.0, 0.08, 1.7),
			_lamp("bulb", 880.0, 0.6, 240.0, Color(1.0, 0.88, 0.62), 80.0, 0.08, 3.4),
		],
		"extra_lights": [],
		"spawns": [Vector2(400, 380), Vector2(420, 400)],
		"guards": [
			{"name": "Lefebvre", "speed": 40.0, "phase": 0.0, "path": [Vector2(380, 335), Vector2(1000, 335), Vector2(1000, 425), Vector2(380, 425)]},
		],
		"arrive": {"salle_commune": Vector2(400, 350)},
		"props": [
			_p("door", 400, 302, 70, 10, 104, "Porte vers la salle commune", "", [_go("salle_commune", "Retourner à la salle commune")], false, {"label": "COMMUNE", "col": Color("#6b5d49")}),
			_p("workbench", 520, 380, 140, 50, 38, "Poste de travail", "Un établi couvert de tissu bleu.", [_a("work")]),
			_p("workbench", 720, 380, 140, 50, 38, "Poste de travail", "Un établi couvert de tissu bleu.", [_a("work")]),
			_p("workbench", 520, 470, 140, 50, 38, "Poste de travail", "Un établi couvert de tissu bleu.", [_a("work")]),
			_p("workbench", 720, 470, 140, 50, 38, "Poste de travail", "Un établi couvert de tissu bleu.", [_a("work")]),
			_p("crates", 900, 360, 70, 44, 46, "Caisses", "Des caisses d'uniformes. Rien à voler sous l'œil de la caméra."),
			_p("crates", 900, 460, 70, 44, 46, "Caisses", "Des caisses d'uniformes pliés."),
		],
	}


static func _cour() -> Dictionary:
	return {
		"id": "cour", "title": "Cour de promenade", "floor": floor_at(760.0, 330.0), "wall_h": 140.0,
		"theme": {"wall_a": "#9b978c", "wall_b": "#8b877d", "wall_line": "#6b685f", "floor": "#74777a", "puddles": 3, "tile": 80.0, "court": true, "wire": true, "dirt": 1.0},
		"ambient": Color("#8e95a8"), "vignette": 0.35,
		"window": false, "window_light": {},
		"lamps": [],
		"extra_lights": [{"pos": Vector2(520, 230), "color": Color(1.0, 0.86, 0.66), "energy": 0.5, "radius": 560.0}],
		"spawns": [Vector2(640, 380), Vector2(680, 400)],
		"guards": [
			{"name": "Benali", "speed": 50.0, "phase": 0.0, "look": 2, "path": [Vector2(300, 338), Vector2(980, 338), Vector2(980, 600), Vector2(300, 600)]},
			{"name": "Roux", "speed": 44.0, "phase": 0.5, "look": 2, "path": [Vector2(300, 338), Vector2(980, 338), Vector2(980, 600), Vector2(300, 600)]},
		],
		"arrive": {"salle_commune": Vector2(640, 330)},
		"props": [
			_p("door", 640, 302, 70, 10, 104, "Retour à la salle commune", "", [_go("salle_commune", "Rentrer à la salle commune")], false, {"label": "COMMUNE", "col": Color("#4d5c6b")}),
			_p("weights", 400, 440, 130, 56, 40, "Banc de musculation", "Des haltères rouillés. Ça tient debout, c'est déjà ça.", [_a("train")]),
			_p("hoop", 900, 400, 24, 20, 130, "Panier de basket", "Un panier sans filet. Le ballon est crevé.", [_a("hoops")]),
			_p("bench", 640, 380, 130, 30, 24, "Banc", "Un banc au soleil couchant. Les autres détenus s'y retrouvent.", [_a("chat")]),
		],
	}


static func _mitard() -> Dictionary:
	return {
		"id": "mitard", "title": "Mitard", "floor": floor_at(240.0, 170.0), "wall_h": 110.0,
		"theme": {"wall_a": "#4a4c48", "wall_b": "#42443f", "wall_line": "#2a2b28", "floor": "#53555a", "tally": true, "dirt": 1.8},
		"ambient": Color("#262a35"), "vignette": 0.95,
		"window": false, "window_light": {},
		"lamps": [_lamp("tube", 640.0, 0.5, 210.0, Color(1.0, 0.9, 0.7), 0.0, 0.0, 0.7, 0.6)],
		"extra_lights": [],
		"spawns": [Vector2(640, 440), Vector2(620, 440)],
		"arrive": {"isolement": Vector2(640, 330)},
		"props": [
			_p("door", 640, 302, 70, 10, 92, "Porte blindée", "@mitard", [_a("bribe")], false, {"label": "ISOLEMENT", "col": Color("#3a3d41")}),
			_p("slab", 590, 390, 110, 50, 24, "Dalle de béton", "Une dalle de béton. Pas de matelas. Le froid remonte dans les os.", [_a("meditate")]),
			_p("toilet", 715, 345, 38, 34, 28, "Toilettes", "Une cuvette en inox. Tu évites de regarder."),
			_p("mat", 650, 462, 110, 56, 2, "Faire des pompes", "", [_a("pushups")], false),
		],
	}
