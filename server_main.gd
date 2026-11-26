extends Node

var acc := 0.0


func _process(delta: float) -> void:
	acc += delta
	if acc >= 30.0:
		acc = 0.0
		print("En ligne : %d · comptes : %d · groupes actifs : %d" % [Net.peers.size(), Net.accounts.size(), Net.groups.size()])
