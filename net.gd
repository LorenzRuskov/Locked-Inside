extends Node

# Multijoueur : un serveur dédié (Godot --headless, argument utilisateur --server).
# - Comptes : nom + mot de passe (haché avec un sel côté serveur). Chaque compte a un personnage
#   sauvegardé sur le serveur et une cellule PERMANENTE (2 comptes maximum par cellule ;
#   quand elle est pleine, le serveur en ouvre une nouvelle : 0001, 0002, 0003...).
# - Les pièces communes (couloir, infirmerie, atelier, cour) sont partagées, en instances de
#   ROOM_CAP détenus. La cellule est privée, le mitard solitaire.
# - La connexion est chiffrée (DTLS, certificat auto-signé généré par le serveur).
# Autoload "Net" : même script côté serveur et côté client (obligatoire pour les RPC).

signal connected()
signal auth_result(ok: bool, msg: String, payload: Dictionary)
signal joined(cell_id: int, slot: int)
signal cell_updated()
signal peers_list(list: Array)
signal peer_enter(id: int, ap: Dictionary)
signal peer_leave(id: int)
signal peer_pos(id: int, pos: Vector2, moving: bool, look: float)
signal lost()

const PORT := 7777
const CELL_CAPACITY := 2
const ROOM_CAP := 20
const KNOWN_ROOMS := ["cell", "allee", "salle_commune", "couloir", "infirmerie", "atelier", "cantine", "cour", "parloir", "administration", "isolement", "mitard"]
const ACCOUNTS_PATH := "user://accounts.json"
const KEY_PATH := "user://server.key"
const CERT_PATH := "user://server.crt"
const HASH_ROUNDS := 5000
const MAX_SAVE_BYTES := 60000
const SAVE_EVERY := 3.0
const MAX_FAILS := 5

# --- état client ---
var online := false
var failed := false
var authed := false
var entering := false
var entered := false
var account := ""
var cell_id := -1
var slot := 0
var inmate := 0          # matricule de détenu (unique, attribué à la création du compte)
var cell_members: Array = []
var save_dirty := false
var save_timer := 0.0

# --- état serveur ---
var is_server := false
var accounts := {}      # nom en minuscules -> {user, salt, hash, cell, slot, data}
var peers := {}         # peer_id -> {key, ap, room, group, last_save}
var online_keys := {}   # nom en minuscules -> peer_id
var groups := {}        # clé de groupe (qui se voit) -> Array de peer_id
var fails := {}         # peer_id -> échecs de connexion
var accounts_dirty := false
var accounts_timer := 0.0


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		_start_server()


func _process(delta: float) -> void:
	if is_server:
		accounts_timer += delta
		if accounts_dirty and accounts_timer >= 10.0:
			accounts_timer = 0.0
			_save_accounts()
	elif save_dirty and entered:
		save_timer += delta
		if save_timer >= SAVE_EVERY:
			flush_save()


# ---------------- Serveur : démarrage et comptes ----------------

func _start_server() -> void:
	is_server = true
	_load_accounts()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1000)
	if err != OK:
		push_error("Impossible de démarrer le serveur (port %d) : erreur %d" % [PORT, err])
		get_tree().quit(1)
		return
	err = peer.host.dtls_server_setup(_server_tls())
	if err != OK:
		push_error("Chiffrement DTLS impossible : erreur %d" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	print("Serveur Locked Inside prêt sur le port %d (connexion chiffrée) · %d compte(s)" % [PORT, accounts.size()])
	get_tree().change_scene_to_file.call_deferred("res://server.tscn")


# La clé privée reste côté serveur (server.key) ; le certificat public (server.crt) est livré
# avec le jeu et permet au client de vérifier qu'il parle bien à CE serveur.
func _server_tls() -> TLSOptions:
	var key_path := KEY_PATH
	var cert_path := CERT_PATH
	if FileAccess.file_exists("res://server.key") and FileAccess.file_exists("res://server.crt"):
		key_path = "res://server.key"
		cert_path = "res://server.crt"
	var key := CryptoKey.new()
	var cert := X509Certificate.new()
	if FileAccess.file_exists(key_path) and FileAccess.file_exists(cert_path):
		key.load(key_path)
		cert.load(cert_path)
	else:
		var crypto := Crypto.new()
		key = crypto.generate_rsa(2048)
		cert = crypto.generate_self_signed_certificate(key, "CN=locked-inside,O=LockedInside,C=CH")
		key.save(KEY_PATH)
		cert.save(CERT_PATH)
		print("Nouveau certificat créé dans %s : copie server.crt dans le dossier du jeu pour les clients." % OS.get_user_data_dir())
	return TLSOptions.server(key, cert)


func _client_tls() -> TLSOptions:
	if FileAccess.file_exists("res://server.crt"):
		var cert := X509Certificate.new()
		if cert.load("res://server.crt") == OK:
			return TLSOptions.client(cert, "locked-inside")
	return TLSOptions.client_unsafe()


func _load_accounts() -> void:
	if not FileAccess.file_exists(ACCOUNTS_PATH):
		return
	var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		accounts = d
		# Anciens comptes sans matricule : on leur en attribue un
		var migrated := false
		for k in accounts:
			if int(accounts[k].get("inmate", 0)) <= 0:
				accounts[k]["inmate"] = _new_inmate_id()
				migrated = true
		if migrated:
			_save_accounts()


# Matricule : 6 chiffres tirés au hasard, jamais deux fois le même
func _new_inmate_id() -> int:
	var used := {}
	for k in accounts:
		used[int(accounts[k].get("inmate", 0))] = true
	var n := 0
	while n == 0 or used.has(n):
		n = 100000 + int(Crypto.new().generate_random_bytes(4).decode_u32(0) % 900000)
	return n


func _save_accounts() -> void:
	accounts_dirty = false
	var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(accounts))


func _hash_pw(pw: String, salt: String) -> String:
	var pwb := pw.to_utf8_buffer()
	var h := (salt + pw).to_utf8_buffer()
	for i in range(HASH_ROUNDS):
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(h + pwb)
		h = ctx.finish()
	return h.hex_encode()


func _count_in_cell(cid: int) -> int:
	var n := 0
	for k in accounts:
		if int(accounts[k]["cell"]) == cid:
			n += 1
	return n


# Première cellule qui a de la place, sinon une nouvelle
func _assign_cell() -> int:
	var top := 0
	for k in accounts:
		top = maxi(top, int(accounts[k]["cell"]))
	for cid in range(1, top + 1):
		if _count_in_cell(cid) < CELL_CAPACITY:
			return cid
	return top + 1


func _cell_names(cid: int) -> Array:
	var names := []
	for k in accounts:
		if int(accounts[k]["cell"]) == cid:
			names.append(str(accounts[k]["user"]))
	return names


func _notify_cell(cid: int) -> void:
	var names := _cell_names(cid)
	for pid in peers:
		var acc: Dictionary = accounts[peers[pid]["key"]]
		if int(acc["cell"]) == cid:
			cl_cell_members.rpc_id(pid, names)


func _valid_name(user: String) -> bool:
	if user.length() < 3 or user.length() > 16:
		return false
	for c in user:
		if not (c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"):
			return false
	return true


func _auth_fail(id: int, msg: String) -> void:
	fails[id] = int(fails.get(id, 0)) + 1
	cl_auth_result.rpc_id(id, false, msg, {})
	if int(fails[id]) >= MAX_FAILS:
		multiplayer.multiplayer_peer.disconnect_peer(id)


@rpc("any_peer", "reliable")
func srv_auth(mode: String, user: String, pw: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if peers.has(id):
		return
	user = user.strip_edges()
	if not _valid_name(user):
		_auth_fail(id, "Nom invalide : 3 à 16 caractères (lettres, chiffres, _ ou -).")
		return
	if pw.length() < 6 or pw.length() > 64:
		_auth_fail(id, "Mot de passe : 6 à 64 caractères.")
		return
	var key := user.to_lower()
	if mode == "register":
		if accounts.has(key):
			_auth_fail(id, "Ce nom est déjà pris.")
			return
		var cid := _assign_cell()
		var salt := Crypto.new().generate_random_bytes(16).hex_encode()
		accounts[key] = {"user": user, "salt": salt, "hash": _hash_pw(pw, salt), "cell": cid, "slot": _count_in_cell(cid), "inmate": _new_inmate_id(), "data": {}}
		_save_accounts()
		print("Nouveau compte « %s » -> matricule %d, cellule %04d" % [user, int(accounts[key]["inmate"]), cid])
	else:
		if not accounts.has(key):
			_auth_fail(id, "Nom ou mot de passe incorrect.")
			return
		var existing: Dictionary = accounts[key]
		if _hash_pw(pw, str(existing["salt"])) != str(existing["hash"]):
			_auth_fail(id, "Nom ou mot de passe incorrect.")
			return
	if online_keys.has(key):
		_auth_fail(id, "Ce compte est déjà connecté.")
		return
	var acc: Dictionary = accounts[key]
	peers[id] = {"key": key, "ap": {}, "room": "", "group": "", "last_save": 0.0}
	online_keys[key] = id
	var payload := {
		"user": str(acc["user"]), "cell": int(acc["cell"]), "slot": int(acc["slot"]), "inmate": int(acc["inmate"]),
		"members": _cell_names(int(acc["cell"])), "data": acc["data"],
	}
	cl_auth_result.rpc_id(id, true, "", payload)
	_notify_cell(int(acc["cell"]))
	print("« %s » connecté (cellule %04d)" % [acc["user"], int(acc["cell"])])


func _clean_ap(ap: Dictionary) -> Dictionary:
	var out := {"name": str(ap.get("name", "Détenu")).substr(0, 16)}
	for k in ["skin", "hair_style", "hair_color", "eyes", "expression", "beard", "scar", "suit"]:
		out[k] = clampi(int(ap.get(k, 0)), 0, 20)
	return out


# Le joueur entre dans le monde avec son apparence
@rpc("any_peer", "reliable")
func srv_join(ap: Dictionary) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	var acc: Dictionary = accounts[peers[id]["key"]]
	peers[id]["ap"] = _clean_ap(ap)
	peers[id]["ap"]["inmate"] = int(acc["inmate"])
	cl_joined.rpc_id(id, int(acc["cell"]), int(acc["slot"]))


# Sauvegarde du personnage (nom, histoire, progression)
@rpc("any_peer", "reliable")
func srv_save(data: Dictionary) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	var now := Time.get_unix_time_from_system()
	if now - float(peers[id]["last_save"]) < 1.5:
		return
	if JSON.stringify(data).length() > MAX_SAVE_BYTES:
		return
	peers[id]["last_save"] = now
	var acc: Dictionary = accounts[peers[id]["key"]]
	var clean := {}
	for k in ["ap", "story", "progress"]:
		if data.has(k) and data[k] is Dictionary:
			clean[k] = data[k]
	acc["data"] = clean
	if clean.has("ap"):
		peers[id]["ap"] = _clean_ap(clean["ap"])
		peers[id]["ap"]["inmate"] = int(acc["inmate"])
	accounts_dirty = true


# ---------------- Serveur : qui voit qui ----------------

# Cellule privée, mitard solitaire, pièces communes en instances de ROOM_CAP
func _group_key(id: int, room: String) -> String:
	if room == "cell":
		var acc: Dictionary = accounts[peers[id]["key"]]
		return "cell:%d" % int(acc["cell"])
	if room == "mitard":
		return "mitard:%d" % id
	if room == "couloir":
		room = "salle_commune"
	if room == "allee":
		# une allée par aile : on ne croise que ses voisins de couloir
		var acc2: Dictionary = accounts[peers[id]["key"]]
		return "allee:%d" % int(floor(float(int(acc2["cell"]) - 1) / 10.0))
	var n := 1
	var key := "%s#%d" % [room, n]
	while groups.has(key) and groups[key].size() >= ROOM_CAP:
		n += 1
		key = "%s#%d" % [room, n]
	return key


func _leave_group(id: int) -> void:
	var g: String = peers[id]["group"]
	if g == "" or not groups.has(g):
		return
	groups[g].erase(id)
	for pid in groups[g]:
		cl_peer_leave.rpc_id(pid, id)
	if groups[g].is_empty():
		groups.erase(g)
	peers[id]["group"] = ""


func _join_group(id: int, key: String) -> void:
	if not groups.has(key):
		groups[key] = []
	var list := []
	for pid in groups[key]:
		cl_peer_enter.rpc_id(pid, id, peers[id]["ap"])
		list.append({"id": pid, "ap": peers[pid]["ap"]})
	groups[key].append(id)
	peers[id]["group"] = key
	cl_peer_list.rpc_id(id, list)


# Le client annonce dans quelle pièce il se trouve
@rpc("any_peer", "reliable")
func srv_room(room: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id) or not KNOWN_ROOMS.has(room):
		return
	if peers[id]["room"] == room:
		return
	_leave_group(id)
	peers[id]["room"] = room
	_join_group(id, _group_key(id, room))


@rpc("any_peer", "unreliable")
func srv_pos(pos: Vector2, moving: bool, look: float) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	var g: String = peers[id]["group"]
	if g == "" or not groups.has(g):
		return
	for pid in groups[g]:
		if pid != id:
			cl_peer_pos.rpc_id(pid, id, pos, moving, look)


func _on_peer_left(id: int) -> void:
	fails.erase(id)
	if not peers.has(id):
		return
	_leave_group(id)
	online_keys.erase(peers[id]["key"])
	peers.erase(id)
	_save_accounts()
	print("Un détenu a quitté la prison (%d en ligne)" % peers.size())


# ---------------- Client ----------------

func connect_to(address: String) -> void:
	failed = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err == OK:
		err = peer.host.dtls_client_setup(address, _client_tls())
	if err != OK:
		failed = true
		online = false
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_server_lost)
	online = true


func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	online = false
	authed = false
	entering = false
	entered = false
	cell_id = -1
	inmate = 0
	account = ""
	cell_members = []
	save_dirty = false


func is_connected_to_server() -> bool:
	return online and multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func send_auth(mode: String, user: String, pw: String) -> void:
	srv_auth.rpc_id(1, mode, user, pw)


# Entre dans le monde (envoie l'apparence) une fois connecté au compte
func enter() -> void:
	if online and authed and not entered and not entering:
		entering = true
		srv_join.rpc_id(1, GameState.ap)


# Prévient le serveur de la pièce où on se trouve (les autres détenus de la pièce apparaissent)
func send_room(room: String) -> void:
	if can_send():
		srv_room.rpc_id(1, room)


func can_send() -> bool:
	return online and entered and multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func queue_save() -> void:
	if authed:
		save_dirty = true


func flush_save() -> void:
	save_timer = 0.0
	if can_send():
		save_dirty = false
		srv_save.rpc_id(1, GameState.export_data())


func _on_connected() -> void:
	connected.emit()


func _on_failed() -> void:
	online = false
	failed = true
	lost.emit()


func _on_server_lost() -> void:
	online = false
	failed = true
	authed = false
	entered = false
	entering = false
	lost.emit()


@rpc("authority", "reliable")
func cl_auth_result(ok: bool, msg: String, payload: Dictionary) -> void:
	if ok:
		authed = true
		account = str(payload["user"])
		cell_id = int(payload["cell"])
		slot = int(payload["slot"])
		inmate = int(payload.get("inmate", 0))
		cell_members = payload["members"]
	auth_result.emit(ok, msg, payload)


@rpc("authority", "reliable")
func cl_cell_members(names: Array) -> void:
	cell_members = names
	cell_updated.emit()


@rpc("authority", "reliable")
func cl_joined(cid: int, slot_i: int) -> void:
	cell_id = cid
	slot = slot_i
	entered = true
	entering = false
	joined.emit(cid, slot_i)


@rpc("authority", "reliable")
func cl_peer_list(list: Array) -> void:
	peers_list.emit(list)


@rpc("authority", "reliable")
func cl_peer_enter(id: int, ap: Dictionary) -> void:
	peer_enter.emit(id, ap)


@rpc("authority", "reliable")
func cl_peer_leave(id: int) -> void:
	peer_leave.emit(id)


@rpc("authority", "unreliable")
func cl_peer_pos(id: int, pos: Vector2, moving: bool, look: float) -> void:
	peer_pos.emit(id, pos, moving, look)
