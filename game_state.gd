extends Node

# Apparence du détenu, partagée entre l'écran de création et le jeu.
# Sauvegardée dans user://character.json (rechargée au lancement suivant).

const SAVE_PATH := "user://character.json"

var SKINS: Array = [Color("#f3d2b3"), Color("#e8b98f"), Color("#d49a6a"), Color("#a86f45"), Color("#7a4a2b"), Color("#4f2f1c")]
var HAIR_COLORS: Array = [Color("#14110f"), Color("#3b2418"), Color("#7a4a25"), Color("#c9a24a"), Color("#b5461f"), Color("#8f8f94"), Color("#e8e8ea"), Color("#2e5fa8"), Color("#a8326b")]
var EYE_COLORS: Array = [Color("#4a2c17"), Color("#3a78c9"), Color("#3f8f4f"), Color("#7d8794"), Color("#b8862f")]
var SUITS: Array = [Color("#e07a1f"), Color("#3a6fc2"), Color("#7d838c"), Color("#4f8a4e"), Color("#c0392b")]
var HAIR_STYLES: Array = ["Chauve", "Rasé", "Court", "Mi-long", "Crête", "Afro", "Queue"]
var EXPRESSIONS: Array = ["Neutre", "Souriant", "Sévère", "Fatigué"]
var BEARDS: Array = ["Aucune", "Moustache", "Barbiche", "Barbe"]
var SCARS: Array = ["Aucune", "Joue", "Sourcil"]

var ap := {
	"name": "Détenu 4512",
	"skin": 1,
	"hair_style": 2,
	"hair_color": 1,
	"eyes": 0,
	"expression": 0,
	"beard": 0,
	"scar": 0,
	"suit": 0,
}


func _ready() -> void:
	load_character()
	load_story()
	load_server()
	load_progress()


func save_character() -> void:
	_write_json(SAVE_PATH, ap)
	Net.queue_save()


func load_character() -> void:
	var data = _read_json(SAVE_PATH)
	if data is Dictionary:
		apply_ap(data)


func apply_ap(data: Dictionary) -> void:
	for k in ap.keys():
		if data.has(k):
			if k == "name":
				ap[k] = str(data[k]).substr(0, 16)
			else:
				ap[k] = int(data[k])


# ---------- Histoire / dossier du détenu (rempli par l'introduction) ----------

const STORY_PATH := "user://story.json"

var STAT_LABELS := {"force": "Force", "ruse": "Ruse", "sang_froid": "Sang-froid", "charisme": "Charisme"}

var story := {
	"stats": {"force": 3, "ruse": 3, "sang_froid": 3, "charisme": 3},
	"rep": {"detenus": 0, "gardiens": 0},
	"crime": "", "past": "", "attitude": "", "motivation": "", "item": "",
}


func reset_story() -> void:
	story = {
		"stats": {"force": 3, "ruse": 3, "sang_froid": 3, "charisme": 3},
		"rep": {"detenus": 0, "gardiens": 0},
		"crime": "", "past": "", "attitude": "", "motivation": "", "item": "",
	}


func apply_choice(opt: Dictionary) -> void:
	var stats: Dictionary = opt.get("stats", {})
	for k in stats:
		story["stats"][k] = int(story["stats"].get(k, 0)) + int(stats[k])
	var rep: Dictionary = opt.get("rep", {})
	for k in rep:
		story["rep"][k] = int(story["rep"].get(k, 0)) + int(rep[k])
	var vals: Dictionary = opt.get("set", {})
	for k in vals:
		story[k] = vals[k]


func save_story() -> void:
	_write_json(STORY_PATH, story)
	Net.queue_save()


func load_story() -> void:
	var data = _read_json(STORY_PATH)
	if data is Dictionary:
		apply_story(data)


func apply_story(data: Dictionary) -> void:
	for k in ["crime", "past", "attitude", "motivation", "item"]:
		if data.has(k):
			story[k] = str(data[k])
	var st = data.get("stats", {})
	if st is Dictionary:
		for k in story["stats"].keys():
			if st.has(k):
				story["stats"][k] = int(st[k])
	var rp = data.get("rep", {})
	if rp is Dictionary:
		for k in story["rep"].keys():
			if rp.has(k):
				story["rep"][k] = int(rp[k])


func dossier_text() -> String:
	var lines := PackedStringArray()
	if inmate_label() != "":
		lines.append("Détenu " + inmate_label())
	if mitard_count > 0:
		lines.append("Passages au mitard : %d" % mitard_count)
	if story["crime"] != "":
		lines.append("Motif : " + str(story["crime"]))
	if story["past"] != "":
		lines.append("Avant : " + str(story["past"]))
	var s: Dictionary = story["stats"]
	lines.append("Force %d · Ruse %d · Sang-froid %d · Charisme %d" % [s["force"], s["ruse"], s["sang_froid"], s["charisme"]])
	var r: Dictionary = story["rep"]
	lines.append("Respect détenus %+d · Gardiens %+d" % [r["detenus"], r["gardiens"]])
	if story["item"] != "":
		lines.append("Objet caché : " + str(story["item"]))
	return "\n".join(lines)


# ---------- Serveur en ligne (adresse mémorisée ; vide = solo) ----------

const SERVER_PATH := "user://server.txt"

var server_address := ""


func save_server() -> void:
	var f := FileAccess.open(SERVER_PATH, FileAccess.WRITE)
	if f:
		f.store_string(server_address)


func load_server() -> void:
	if FileAccess.file_exists(SERVER_PATH):
		var f := FileAccess.open(SERVER_PATH, FileAccess.READ)
		if f:
			server_address = f.get_as_text().strip_edges()


# ---------- Progression : lieu, santé, points d'action, inventaire ----------
# Règles reprises de l'ancien Locked Inside (PA max 50, +1 PA toutes les 10 min).

const PROGRESS_PATH := "user://progress.json"
const PA_MAX := 50
const PA_REGEN_SECONDS := 600.0
const HEAL_FREE_COOLDOWN := 600.0   # l'ancien jeu : 1 h ; raccourci pour pouvoir tester
const MAX_SHIFTS := 5

var room := "cell"
var prev_room := ""
var flash := ""
var pv := 100
var mental := 100
var pa := 50
var pa_stamp := 0.0
var cigs := 0
var meds := 0
var shifts := 0
var workday := ""
var heal_stamp := 0.0
var meal_stamp := 0.0     # dernier repas pris à la cantine
var visit_stamp := 0.0    # dernier parloir
const MEAL_COOLDOWN := 14400.0   # un plateau toutes les 4 h
const VISIT_COOLDOWN := 21600.0  # un parloir toutes les 6 h
var locker_opened := false
var mitard_until := 0.0
var mitard_base_force := 0
var pushups := 0
var mitard_count := 0          # nombre de passages au mitard (le 3e et suivants doublent la peine)
var mitard_start := 0.0        # début de la peine en cours (0 = aucune)
var mitard_meds := 0           # médicaments confisqués à l'entrée, rendus à la sortie
var mitard_mental_stamp := 0.0 # horloge de la perte de mental

# Durées des sanctions (secondes), plafonnées à MITARD_MAX
const MITARD_PROVOKE := 1800.0
const MITARD_STEAL := 3600.0
const MITARD_MAX := 7200.0
const MITARD_MENTAL_FLOOR := 10


func reset_progress() -> void:
	room = "cell"
	prev_room = ""
	flash = ""
	pv = 100
	mental = 100
	pa = PA_MAX
	pa_stamp = Time.get_unix_time_from_system()
	cigs = 0
	meds = 0
	shifts = 0
	workday = ""
	heal_stamp = 0.0
	meal_stamp = 0.0
	visit_stamp = 0.0
	locker_opened = false
	mitard_until = 0.0
	mitard_base_force = 0
	pushups = 0
	mitard_count = 0
	mitard_start = 0.0
	mitard_meds = 0
	mitard_mental_stamp = 0.0
	save_progress()


func progress_dict() -> Dictionary:
	return {
		"room": room, "pv": pv, "mental": mental, "pa": pa, "pa_stamp": pa_stamp,
		"cigs": cigs, "meds": meds, "shifts": shifts, "workday": workday,
		"heal_stamp": heal_stamp, "meal_stamp": meal_stamp, "visit_stamp": visit_stamp, "locker_opened": locker_opened,
		"mitard_until": mitard_until, "mitard_base_force": mitard_base_force, "pushups": pushups,
		"mitard_count": mitard_count, "mitard_start": mitard_start, "mitard_meds": mitard_meds, "mitard_mental_stamp": mitard_mental_stamp,
	}


func save_progress() -> void:
	_write_json(PROGRESS_PATH, progress_dict())
	Net.queue_save()


func load_progress() -> void:
	var d = _read_json(PROGRESS_PATH)
	if d is Dictionary:
		apply_progress(d)
	else:
		pa_stamp = Time.get_unix_time_from_system()


func apply_progress(d: Dictionary) -> void:
	room = str(d.get("room", "cell"))
	pv = int(d.get("pv", 100))
	mental = int(d.get("mental", 100))
	pa = int(d.get("pa", PA_MAX))
	pa_stamp = float(d.get("pa_stamp", Time.get_unix_time_from_system()))
	cigs = int(d.get("cigs", 0))
	meds = int(d.get("meds", 0))
	shifts = int(d.get("shifts", 0))
	workday = str(d.get("workday", ""))
	heal_stamp = float(d.get("heal_stamp", 0.0))
	meal_stamp = float(d.get("meal_stamp", 0.0))
	visit_stamp = float(d.get("visit_stamp", 0.0))
	locker_opened = bool(d.get("locker_opened", false))
	mitard_until = float(d.get("mitard_until", 0.0))
	mitard_base_force = int(d.get("mitard_base_force", 0))
	pushups = int(d.get("pushups", 0))
	mitard_count = int(d.get("mitard_count", 0))
	mitard_start = float(d.get("mitard_start", 0.0))
	mitard_meds = int(d.get("mitard_meds", 0))
	mitard_mental_stamp = float(d.get("mitard_mental_stamp", 0.0))
	prev_room = ""
	flash = ""


# +1 PA toutes les 10 minutes (calculé d'après l'horloge : marche aussi jeu fermé)
func tick_pa() -> void:
	if mitard_active():
		return   # pas de régénération de PA pendant l'isolement
	var now := Time.get_unix_time_from_system()
	if pa >= PA_MAX:
		pa = PA_MAX
		pa_stamp = now
		return
	var gained := int((now - pa_stamp) / PA_REGEN_SECONDS)
	if gained > 0:
		pa = mini(PA_MAX, pa + gained)
		pa_stamp += float(gained) * PA_REGEN_SECONDS
		if pa >= PA_MAX:
			pa_stamp = now


func add_stat(k: String, v: int) -> void:
	story["stats"][k] = int(story["stats"].get(k, 0)) + v


func add_rep(k: String, v: int) -> void:
	story["rep"][k] = int(story["rep"].get(k, 0)) + v


func mitard_active() -> bool:
	return Time.get_unix_time_from_system() < mitard_until


func mitard_left() -> float:
	return maxf(0.0, mitard_until - Time.get_unix_time_from_system())


# Envoie au mitard et renvoie la durée réellement infligée (peine doublée dès le 3e passage, plafonnée)
func send_to_mitard(seconds: float) -> float:
	var now := Time.get_unix_time_from_system()
	var secs := seconds * (2.0 if mitard_count >= 2 else 1.0)
	secs = minf(secs, MITARD_MAX)
	mitard_count += 1
	mitard_start = now
	mitard_until = now + secs
	mitard_mental_stamp = now
	mitard_base_force = int(story["stats"]["force"])
	pushups = 0
	# Fouille à l'entrée : les médicaments sont confisqués (les cigarettes restent cachées sur toi)
	mitard_meds += meds
	meds = 0
	return secs


# Le mental s'use : -1 par minute d'isolement, jusqu'à un plancher (marche aussi jeu fermé)
func tick_mitard() -> void:
	if mitard_start <= 0.0:
		return
	var end_t := minf(Time.get_unix_time_from_system(), mitard_until)
	var n := int((end_t - mitard_mental_stamp) / 60.0)
	if n > 0:
		mitard_mental_stamp += float(n) * 60.0
		if mental > MITARD_MENTAL_FLOOR:
			mental = maxi(MITARD_MENTAL_FLOOR, mental - n)


# Fin de peine : rend les médicaments, relance l'horloge des PA. Renvoie une phrase pour le joueur.
func settle_mitard() -> String:
	if mitard_start <= 0.0 or mitard_active():
		return ""
	tick_mitard()
	pa_stamp += maxf(0.0, mitard_until - mitard_start)
	pa_stamp = minf(pa_stamp, Time.get_unix_time_from_system())
	var text := ""
	if mitard_meds > 0:
		meds += mitard_meds
		text = " Médicaments rendus : %d." % mitard_meds
	mitard_meds = 0
	mitard_start = 0.0
	save_progress()
	return text


# ---------- Sauvegarde : fichiers locaux + export/import pour le compte en ligne ----------

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


# Tout ce qui définit le personnage (envoyé au serveur, rendu à la reconnexion)
func export_data() -> Dictionary:
	return {"ap": ap.duplicate(), "story": story.duplicate(true), "progress": progress_dict()}


# Un compte a un personnage terminé quand l'intro a été passée (le motif du crime est rempli)
func data_has_character(d: Dictionary) -> bool:
	var st = d.get("story", {})
	return d.has("ap") and st is Dictionary and str(st.get("crime", "")) != ""


func import_data(d: Dictionary) -> void:
	var a = d.get("ap", {})
	if a is Dictionary:
		apply_ap(a)
	var st = d.get("story", {})
	if st is Dictionary:
		apply_story(st)
	var p = d.get("progress", {})
	if p is Dictionary:
		apply_progress(p)
	_write_json(SAVE_PATH, ap)
	_write_json(STORY_PATH, story)
	_write_json(PROGRESS_PATH, progress_dict())


func has_saved_character() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and str(story["crime"]) != ""


# Matricule du détenu : attribué par le serveur à la création du compte, "" hors ligne
func inmate_label() -> String:
	if Net.online and Net.inmate > 0:
		return "N° %d" % Net.inmate
	return ""


# Nom de la cellule : numéro attribué par le serveur (0001, 0002...), "12B" hors ligne
func cell_label() -> String:
	if Net.online and Net.cell_id > 0:
		return "%04d" % Net.cell_id
	return "12B"
