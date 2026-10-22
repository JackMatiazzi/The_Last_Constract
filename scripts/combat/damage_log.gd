class_name DamageLog
extends RefCounted

# dano e cura de uma vida, na ordem: vira o resumo da tela de morte e a conta do placar

const UNKNOWN_CAUSE := "Ferimentos"
const MAX_SHOWN := 8

var last_attacker_name := ""
var last_attacker_peer := 0
# jogadores que acertaram nesta vida; o ultimo leva o abate, os outros a assistencia
var player_hitters: Array[int] = []

var _entries: Array[Dictionary] = []


# golpe sem atacante conhecido nao herda o atacante anterior
func note_hit(cause: String, amount: float, attacker_name := "", attacker_peer := 0) -> void:
	last_attacker_name = attacker_name
	last_attacker_peer = attacker_peer
	if attacker_peer != 0 and attacker_peer not in player_hitters:
		player_hitters.append(attacker_peer)
	_entries.append({"label": cause, "amount": -amount})


func note_heal(amount: float) -> void:
	_entries.append({"label": "Cura", "amount": amount})


func clear() -> void:
	last_attacker_name = ""
	last_attacker_peer = 0
	player_hitters.clear()
	_entries.clear()


func death_cause() -> String:
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].amount < 0.0:
			return _entries[i].label
	return UNKNOWN_CAUSE


# golpes seguidos da mesma origem viram uma linha so
func recap(max_health: float, ended_dead: bool) -> String:
	var steps: Array[Dictionary] = []
	var taken := 0.0
	var healed := 0.0
	for entry in _entries:
		if entry.amount < 0.0:
			taken -= entry.amount
		else:
			healed += entry.amount
		if not steps.is_empty() and steps[-1].label == entry.label:
			steps[-1].amount += entry.amount
		else:
			steps.append(entry.duplicate())
	var lines := PackedStringArray(["Dano recebido: %d (vida máxima %d, curou %d)" % [roundi(taken), roundi(max_health), roundi(healed)]])
	if steps.size() > MAX_SHOWN:
		lines.append("...")
	var shown := steps.slice(-MAX_SHOWN)
	for i in shown.size():
		var is_final_blow: bool = ended_dead and i == shown.size() - 1 and shown[i].amount < 0.0
		lines.append("%s: %+d%s" % [shown[i].label, roundi(shown[i].amount), " (golpe final)" if is_final_blow else ""])
	return "\n".join(lines)
