extends Node
## autoload porque a cena recarrega a cada Reviver e os buffs precisam continuar

signal stats_changed
signal feed_posted(text: String)

const BUFF_DIR := "res://resources/buffs"
const ADVENTURERS: PackedStringArray = [
	"res://resources/adventurers/knight.tres",
	"res://resources/adventurers/barbarian.tres",
	"res://resources/adventurers/mage.tres",
	"res://resources/adventurers/rogue.tres",
]
const CHOICES_PER_DEATH := 2
const MAX_CAUSE_LENGTH := 40

var attempt := 1
var adventurer: AdventurerInfo
var buffs: Array[Buff] = []
## peer_id -> {kills, assists, deaths, last_death}; dura o contrato inteiro, atravessa os reviveres
var stats := {}

var _pool: Array[Buff] = []


func _ready() -> void:
	for file in ResourceLoader.list_directory(BUFF_DIR):
		if file.ends_with(".tres"):
			_pool.append(load(BUFF_DIR.path_join(file)))


func roll_choices() -> Array[Buff]:
	var available := _pool.filter(func(buff: Buff) -> bool: return stacks_of(buff) < buff.max_stacks)
	available.shuffle()
	var choices: Array[Buff] = []
	choices.assign(available.slice(0, CHOICES_PER_DEATH))
	return choices


## buff vem null quando todos ja estao no limite
func start_next_attempt(buff: Buff) -> void:
	if buff:
		buffs.append(buff)
	attempt += 1


func roster() -> Array[AdventurerInfo]:
	var infos: Array[AdventurerInfo] = []
	for path in ADVENTURERS:
		infos.append(load(path))
	return infos


## cena aberta direto no editor: ninguem escolheu, usa o primeiro
func current_adventurer() -> AdventurerInfo:
	if adventurer == null:
		adventurer = load(ADVENTURERS[0])
	return adventurer


func stacks_of(buff: Buff) -> int:
	return buffs.count(buff)


func reset() -> void:
	attempt = 1
	buffs.clear()
	stats.clear()


func stats_of(peer_id: int) -> Dictionary:
	return stats.get(peer_id, {"kills": 0, "assists": 0, "deaths": 0, "last_death": ""})


## quem tem autoridade sobre a vitima conta ao host, que fecha a conta e avisa todo mundo
func record_death(victim: Character) -> void:
	var report := {
		"victim_peer": victim.get_multiplayer_authority() if victim is Adventurer else 0,
		"victim": victim.get_display_name(),
		"killer_peer": victim.damage_log.last_attacker_peer,
		"killer": victim.damage_log.last_attacker_name,
		"cause": victim.damage_log.death_cause(),
		"helpers": Array(victim.damage_log.player_hitters),
	}
	if multiplayer.is_server():
		_apply_death(report)
	else:
		_report_death.rpc_id(1, report)


# cliente so relata a propria queda; o resto do relatorio o host monta sozinho
@rpc("any_peer", "reliable")
func _report_death(report: Dictionary) -> void:
	if multiplayer.is_server():
		count_reported_fall(multiplayer.get_remote_sender_id(), str(report.get("cause", "")))


## so conta quem esta no grupo, caido de fato, e uma vez por queda
func count_reported_fall(sender: int, raw_cause: String) -> void:
	var victim := Adventurer.of_peer(get_tree(), sender)
	if not Net.is_player(sender) or victim == null or not victim.is_dead or victim.fall_counted:
		return
	victim.fall_counted = true
	var cause := Net.clean_text(raw_cause, MAX_CAUSE_LENGTH)
	_apply_death({
		"victim_peer": sender,
		"victim": Net.display_name(sender),
		"killer_peer": 0,
		"killer": "",
		"cause": cause if not cause.is_empty() else "Ferimentos",
		"helpers": [],
	})


# jogador caido conta morte; inimigo caido conta abate e assistencias
func _apply_death(report: Dictionary) -> void:
	var updated := stats.duplicate(true)
	var text := ""
	if report.victim_peer != 0:
		text = _count_fall(updated, report)
	elif report.killer_peer != 0:
		text = _count_kill(updated, report)
	if not text.is_empty():
		_share_stats.rpc(updated, text)


func _count_fall(updated: Dictionary, report: Dictionary) -> String:
	var victim := stats_of(report.victim_peer).duplicate()
	victim.deaths += 1
	victim.last_death = report.cause
	updated[report.victim_peer] = victim
	return "%s caiu: %s" % [report.victim, report.cause]


func _count_kill(updated: Dictionary, report: Dictionary) -> String:
	var killer := stats_of(report.killer_peer).duplicate()
	killer.kills += 1
	updated[report.killer_peer] = killer
	var helper_names := PackedStringArray()
	for helper: int in report.helpers:
		if helper == report.killer_peer:
			continue
		var assist := stats_of(helper).duplicate()
		assist.assists += 1
		updated[helper] = assist
		helper_names.append(Net.display_name(helper))
	var text := "%s abateu %s" % [report.killer, report.victim]
	if not helper_names.is_empty():
		text += " (assistência: %s)" % ", ".join(helper_names)
	return text


@rpc("authority", "call_local", "reliable")
func _share_stats(shared: Dictionary, text: String) -> void:
	stats = shared
	stats_changed.emit()
	feed_posted.emit(text)
