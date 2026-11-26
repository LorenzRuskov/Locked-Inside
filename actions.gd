extends RefCounted

# Actions de jeu (reprises de l'ancien Locked Inside) : coûts en points d'action (PA),
# effets sur les stats, la santé, les cigarettes... Tout l'état vit dans GameState.

const INFO := {
	"examine": {"label": "Examiner", "pa": 0},
	"go": {"label": "Passer la porte", "pa": 0},
	"meditate": {"label": "Méditer", "pa": 3},
	"use_med": {"label": "Prendre un médicament", "pa": 10},
	"search": {"label": "Fouiller la cellule", "pa": 5},
	"force_locker": {"label": "Forcer le casier", "pa": 4},
	"talk": {"label": "Parler au codétenu", "pa": 2},
	"train": {"label": "S'entraîner aux haltères", "pa": 5},
	"hoops": {"label": "Jouer au basket", "pa": 3},
	"chat": {"label": "Discuter avec les détenus", "pa": 2},
	"work": {"label": "Travailler à la chaîne", "pa": 5},
	"heal_free": {"label": "Soin gratuit", "pa": 5},
	"heal_paid": {"label": "Soin complet (20 cigarettes)", "pa": 10},
	"steal_meds": {"label": "Voler des médicaments", "pa": 8},
	"observe": {"label": "Observer le gardien", "pa": 3},
	"provoke": {"label": "Provoquer le gardien", "pa": 2},
	"pushups": {"label": "Faire des pompes", "pa": 0},
	"bribe": {"label": "Corrompre le gardien (10 cigarettes)", "pa": 0},
	"eat": {"label": "Prendre un plateau-repas", "pa": 0},
	"trade": {"label": "Marchander avec les détenus", "pa": 3},
	"visit": {"label": "Voir ta famille au parloir", "pa": 4},
	"paperwork": {"label": "Remplir une demande", "pa": 3},
	"read_rules": {"label": "Lire le règlement", "pa": 0},
	"cell_door": {"label": "Regarder par le judas", "pa": 0},
}

# Les six gardiens de l'ancien jeu ; leurs valeurs d'intégrité/sadisme sont à réinventer ici.
const GUARDS := [
	{"name": "Dupont", "integrite": 22, "sadisme": 30},
	{"name": "Sanchez", "integrite": 65, "sadisme": 15},
	{"name": "Martin", "integrite": 50, "sadisme": 80},
	{"name": "Benali", "integrite": 70, "sadisme": 20},
	{"name": "Lefebvre", "integrite": 28, "sadisme": 45},
	{"name": "Roux", "integrite": 45, "sadisme": 72},
	{"name": "Garnier", "integrite": 55, "sadisme": 40},
	{"name": "Perrin", "integrite": 35, "sadisme": 60},
]

const RUMORS := [
	"On dit que Lefebvre ferme les yeux pour quelques cigarettes.",
	"Le mitard, certains en sortent changés. D'autres n'en sortent pas.",
	"Un détenu de l'aile C prépare quelque chose. Personne ne sait quoi.",
	"Les Anciens contrôlent le trafic de médicaments.",
	"Quelqu'un a gravé un plan derrière un casier de l'aile B.",
]


static func label(id: String, custom: String = "") -> String:
	var info: Dictionary = INFO.get(id, {"label": id, "pa": 0})
	var base: String = custom if custom != "" else str(info["label"])
	var pa: int = int(info["pa"])
	if pa > 0:
		return "%s  ·  %d PA" % [base, pa]
	return base


# Gardien de service au quartier d'isolement : change toutes les 2 h, le même pour tous
static func guard_on_duty() -> Dictionary:
	var block := int(Time.get_unix_time_from_system() / 7200.0)
	return GUARDS[block % GUARDS.size()]


static func _fmt_long(sec: float) -> String:
	var m: int = int(ceil(sec / 60.0))
	if m >= 60:
		return "%d h %02d" % [floori(m / 60.0), m % 60]
	return "%d min" % m


static func _fmt(sec: float) -> String:
	var s: int = int(ceil(sec))
	return "%d:%02d" % [floori(s / 60.0), s % 60]


static func _pay(cost: int) -> bool:
	GameState.tick_pa()
	if GameState.pa < cost:
		return false
	GameState.pa -= cost
	return true


static func _nopa(cost: int) -> String:
	return "Pas assez de points d'action (%d requis, %d disponibles). Tu en regagnes 1 toutes les 10 minutes." % [cost, GameState.pa]


static func _done(msg: String) -> String:
	GameState.save_progress()
	GameState.save_story()
	return msg


static func run(id: String, arg: String, prop, ctx) -> String:
	var info: Dictionary = INFO.get(id, {"label": id, "pa": 0})
	var cost: int = int(info["pa"])
	match id:
		"examine":
			return ctx.resolve_msg(str(prop.interact_msg))
		"go":
			ctx.go_room(arg)
			return ""
		"talk":
			if not _pay(cost):
				return _nopa(cost)
			GameState.mental = mini(100, GameState.mental + 3)
			return _done("Tu discutes un moment avec %s. Ça fait du bien. Mental +3." % arg)
		"meditate":
			if not _pay(cost):
				return _nopa(cost)
			GameState.add_stat("sang_froid", 1)
			GameState.mental = mini(100, GameState.mental + 2)
			return _done("Tu fermes les yeux et respires lentement. Sang-froid +1, mental +2.")
		"use_med":
			if GameState.meds <= 0:
				return "Tu n'as aucun médicament. L'infirmerie en a... derrière une vitre."
			if GameState.pv >= 100:
				return "Tu es en pleine forme, inutile de gaspiller un médicament."
			if not _pay(cost):
				return _nopa(cost)
			GameState.meds -= 1
			var hp: int = randi_range(20, 30)
			GameState.pv = mini(100, GameState.pv + hp)
			return _done("Tu avales le comprimé. PV +%d." % hp)
		"search":
			if not _pay(cost):
				return _nopa(cost)
			if randf() < 0.3:
				var found: int = randi_range(1, 3)
				GameState.cigs += found
				return _done("Derrière une plaque descellée : %d cigarette(s) !" % found)
			return _done("Tu fouilles chaque recoin. Rien.")
		"force_locker":
			if GameState.locker_opened:
				return "Le casier est vide : tu l'as déjà forcé."
			var force: int = int(GameState.story["stats"]["force"])
			if force < 5:
				return "Le verrou ne bouge pas d'un millimètre. (Force 5 requise, tu as %d.)" % force
			if not _pay(cost):
				return _nopa(cost)
			GameState.locker_opened = true
			var loot: int = randi_range(2, 4)
			GameState.cigs += loot
			return _done("Le verrou cède dans un craquement. Dedans : %d cigarettes." % loot)
		"train":
			if not _pay(cost):
				return _nopa(cost)
			GameState.add_stat("force", 1)
			return _done("Série après série, les muscles brûlent. Force +1.")
		"hoops":
			if not _pay(cost):
				return _nopa(cost)
			GameState.mental = mini(100, GameState.mental + 3)
			GameState.add_rep("detenus", 1)
			return _done("Une partie de basket avec les autres. Mental +3, respect des détenus +1.")
		"chat":
			if not _pay(cost):
				return _nopa(cost)
			GameState.add_rep("detenus", 1)
			var rumor: String = RUMORS[randi() % RUMORS.size()]
			return _done("Tu traînes avec les détenus. Respect +1. Rumeur : %s" % rumor)
		"work":
			var today: String = Time.get_date_string_from_system()
			if GameState.workday != today:
				GameState.workday = today
				GameState.shifts = 0
			if GameState.shifts >= GameState.MAX_SHIFTS:
				return "Tu as déjà fait tes %d postes aujourd'hui. Le contremaître te renvoie." % GameState.MAX_SHIFTS
			if not _pay(cost):
				return _nopa(cost)
			GameState.shifts += 1
			var gain: int = randi_range(3, 8)
			GameState.cigs += gain
			return _done("Une heure à plier des uniformes. Salaire : %d cigarettes. (poste %d/%d)" % [gain, GameState.shifts, GameState.MAX_SHIFTS])
		"eat":
			var tnow: float = Time.get_unix_time_from_system()
			var twait: float = GameState.meal_stamp + GameState.MEAL_COOLDOWN - tnow
			if twait > 0.0:
				return "Le service est terminé. Prochain plateau dans %s." % _fmt_long(twait)
			GameState.meal_stamp = tnow
			GameState.pv = mini(100, GameState.pv + 12)
			GameState.mental = mini(100, GameState.mental + 4)
			return _done("Un plateau : purée grise, haricots, un fruit. PV +12, mental +4.")
		"trade":
			if not _pay(cost):
				return _nopa(cost)
			GameState.add_rep("detenus", 1)
			if randf() < 0.4:
				GameState.cigs += 2
				return _done("Tu échanges ton dessert contre un service. +2 cigarettes, respect +1.")
			return _done("Un détenu te vend une rumeur : %s Respect +1." % RUMORS[randi() % RUMORS.size()])
		"visit":
			var vnow: float = Time.get_unix_time_from_system()
			var vwait: float = GameState.visit_stamp + GameState.VISIT_COOLDOWN - vnow
			if vwait > 0.0:
				return "Pas de visite pour toi maintenant. Prochain créneau dans %s." % _fmt_long(vwait)
			if not _pay(cost):
				return _nopa(cost)
			GameState.visit_stamp = vnow
			GameState.mental = mini(100, GameState.mental + 25)
			GameState.cigs += 3
			return _done("Derrière la vitre, un visage connu. Vingt minutes qui comptent. Mental +25, un colis : +3 cigarettes.")
		"paperwork":
			if not _pay(cost):
				return _nopa(cost)
			GameState.add_rep("administration", 1)
			return _done("Tu remplis une demande en trois exemplaires. L'employé tamponne sans te regarder. Respect de l'administration +1.")
		"read_rules":
			return "Règlement intérieur : extinction des feux à 22 h, appels à 7 h et 17 h. Toute provocation envers le personnel est sanctionnée par l'isolement."
		"cell_door":
			return "Par le judas, une pénombre rouge. Quelqu'un tousse au fond du couloir."
		"heal_free":
			if GameState.pv >= 100:
				return "Tu n'as rien. L'infirmière te congédie."
			var now: float = Time.get_unix_time_from_system()
			var wait: float = GameState.heal_stamp + GameState.HEAL_FREE_COOLDOWN - now
			if wait > 0.0:
				return "Soin gratuit déjà reçu. Reviens dans %s." % _fmt(wait)
			if not _pay(cost):
				return _nopa(cost)
			var heal: int = randi_range(10, 15)
			GameState.pv = mini(100, GameState.pv + heal)
			GameState.heal_stamp = now
			return _done("Un pansement, deux mots secs. PV +%d." % heal)
		"heal_paid":
			if GameState.pv >= 100:
				return "Tu n'as rien. L'infirmière te congédie."
			if GameState.cigs < 20:
				return "Le soin complet coûte 20 cigarettes. Tu en as %d." % GameState.cigs
			if not _pay(cost):
				return _nopa(cost)
			GameState.cigs -= 20
			var big: int = randi_range(25, 35)
			GameState.pv = mini(100, GameState.pv + big)
			return _done("L'infirmière te recoud proprement. PV +%d, 20 cigarettes en moins." % big)
		"steal_meds":
			if not _pay(cost):
				return _nopa(cost)
			var ruse: int = int(GameState.story["stats"]["ruse"])
			var chance: float = clampf(0.15 + 0.08 * float(ruse), 0.1, 0.85)
			if randf() < chance:
				GameState.meds += 1
				return _done("Tu profites d'un instant d'inattention : une boîte glisse dans ta manche. Médicaments +1.")
			if ruse <= 3 and randf() < 0.5:
				GameState.pv = maxi(5, GameState.pv - 5)
				GameState.add_rep("gardiens", -3)
				var had: int = GameState.meds
				var secs: float = GameState.send_to_mitard(GameState.MITARD_STEAL)
				GameState.flash = "Pris la main dans le sac. L'infirmière appelle un gardien : direction le mitard (%s)." % _fmt(secs)
				if had > 0:
					GameState.flash += " Tes médicaments sont confisqués."
				_done("")
				ctx.go_room("mitard")
				return ""
			GameState.add_rep("gardiens", -2)
			return _done("L'infirmière lève les yeux au mauvais moment. Tu t'en tires avec un regard noir.")
		"observe":
			if not _pay(cost):
				return _nopa(cost)
			var g: Dictionary = GUARDS[randi() % GUARDS.size()]
			for cand in GUARDS:
				if str(cand["name"]) == arg:
					g = cand
			var clue: String = "se comporte normalement."
			if int(g["integrite"]) < 30:
				clue = "a l'air corruptible : son regard suit les paquets de cigarettes."
			elif int(g["sadisme"]) > 70:
				clue = "a un regard mauvais. Mieux vaut l'éviter."
			return _done("Tu observes le gardien %s. Il %s" % [g["name"], clue])
		"provoke":
			if not _pay(cost):
				return _nopa(cost)
			GameState.pv = maxi(5, GameState.pv - 10)
			GameState.add_rep("gardiens", -5)
			GameState.add_rep("detenus", 3)
			var had2: int = GameState.meds
			var secs2: float = GameState.send_to_mitard(GameState.MITARD_PROVOKE)
			var who := ("Le gardien " + arg + " : ") if arg != "" else ""
			GameState.flash = who + "La matraque s'abat. Tu finis au mitard (%s). PV -10, les détenus ont apprécié." % _fmt(secs2)
			if had2 > 0:
				GameState.flash += " Tes médicaments sont confisqués."
			_done("")
			ctx.go_room("mitard")
			return ""
		"bribe":
			if not GameState.mitard_active():
				return "Il n'y a plus personne à corrompre."
			var duty: Dictionary = guard_on_duty()
			for cand in GUARDS:   # arg non vide : gardien imposé (tests, futur choix d'un gardien précis)
				if arg != "" and str(cand["name"]) == arg:
					duty = cand
			if GameState.cigs < 10:
				return "Il faut 10 cigarettes pour tenter de corrompre %s. Tu en as %d." % [duty["name"], GameState.cigs]
			GameState.cigs -= 10
			var left: float = GameState.mitard_left()
			if int(duty["integrite"]) < 30:
				var cut: float = minf(left, maxf(300.0, left * 0.4))
				GameState.mitard_until -= cut
				return _done("%s glisse les cigarettes dans sa poche sans un mot. Ta peine est réduite de %s." % [duty["name"], _fmt(cut)])
			if int(duty["sadisme"]) > 70:
				var now: float = Time.get_unix_time_from_system()
				GameState.mitard_until = minf(GameState.mitard_until + 600.0, now + GameState.MITARD_MAX)
				return _done("%s rit, empoche tes cigarettes et ajoute 10 minutes pour « tentative de corruption »." % duty["name"])
			if randf() < 0.5:
				var cut2: float = minf(left, left * 0.2)
				GameState.mitard_until -= cut2
				return _done("%s hésite, puis accepte. Ta peine est réduite de %s." % [duty["name"], _fmt(cut2)])
			return _done("%s empoche les cigarettes et détourne le regard. Rien ne change." % duty["name"])
		"pushups":
			GameState.pushups += 1
			var cap: int = GameState.mitard_base_force + 5
			if GameState.pushups % 100 == 0:
				if int(GameState.story["stats"]["force"]) < cap:
					GameState.add_stat("force", 1)
					return _done("100 pompes. Tes bras tremblent, mais tu te sens plus fort. Force +1.")
				return _done("100 pompes. Tu as atteint ta limite ici (Force max %d au mitard)." % cap)
			return "Pompes : %d / 100" % (GameState.pushups % 100)
	return ""
