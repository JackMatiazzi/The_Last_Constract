extends "res://tests/e2e/e2e_driver.gd"

# uma partida em grupo com dois processos de verdade ligados pela rede local. Cada processo roda
# este mesmo roteiro com --role=host ou --role=client; o lobby e preenchido pela linha de comando

const HOST_PEER := 1
const POTION := preload("res://resources/items/health_potion.tres")

var role := ""


func run() -> void:
	role = _arg("--role=")
	label = "coop-%s" % role
	play_with_gamepad()
	if role == "host" and await wait_until(func() -> bool: return Net.is_online(), "host abrir a porta"):
		print("E2E host escutando")
	if not await wait_scene("MissionIntro"):
		return
	check(_allies_in_cutscene() == 1, "a cutscene mostra o aliado")
	await skip_cutscene()

	if not await wait_level():
		return
	calm_enemies()
	var game := session()
	check(game.players.size() == 2, "os dois aventureiros estao na fase")
	check(Net.player_count == 2, "a partida conta dois jogadores")
	var host := Adventurer.of_peer(get_tree(), HOST_PEER)
	var guest := game.players.filter(func(adventurer: Adventurer) -> bool: return adventurer != host)[0] as Adventurer
	check(host.get_display_name() == "Host" and guest.get_display_name() == "Cliente", "nomes do lobby sobre os bonecos")

	await _damage_crosses_the_network(host, guest)
	await _forged_damage_is_ignored()
	await _revive_through_the_network(host, guest)
	await _everyone_falls_and_votes()
	await _leave_together()


func _damage_crosses_the_network(host: Adventurer, guest: Adventurer) -> void:
	if role == "host":
		guest.take_damage(2.0, host)
	var hurt := guest.get_max_health() - 2.0
	if await wait_until(func() -> bool: return is_equal_approx(guest.health, hurt), "dano do host no cliente"):
		check(true, "golpe de um jogador chega na maquina do outro")


# o cliente manda um pedido de dano forjado; quando o marco chega ao host, ele ja foi processado
func _forged_damage_is_ignored() -> void:
	var enemy := get_tree().current_scene.find_children("*", "Enemy", true, false)[0] as Enemy
	if role == "client":
		enemy._request_damage.rpc_id(HOST_PEER, 5.0, NodePath())
		mark("forjado")
		await wait_mark("conferido")
	else:
		await wait_mark("forjado")
		mark("conferido")
	check(is_equal_approx(enemy.health, enemy.get_max_health()), "dano forjado e ignorado pelo host")


func _revive_through_the_network(host: Adventurer, guest: Adventurer) -> void:
	if role == "host":
		host.take_damage(999.0)
	if not await wait_until(func() -> bool: return host.is_dead, "host caido"):
		return
	if role == "client":
		guest.global_position = host.global_position + Vector3(1.0, 0.0, 0.0)
		guest.inventory.add(POTION)
		if not await wait_until(func() -> bool: return guest.revive_target == host, "aviso de reviver"):
			return
		# a posicao nova ainda precisa chegar no host, que confere o alcance
		await wait_physics(10)
		press_action(&"interact")
	if await wait_until(func() -> bool: return not host.is_dead, "host revivido"):
		check(true, "aliado revivido pela rede")
	if role == "client":
		check(guest.inventory.count_of(POTION) == 0, "a pocao de quem reviveu foi gasta")
	# o host so cai de novo depois que o cliente viu o reviver; senao as duas noticias chegam juntas
	mark("revivido")
	await wait_mark("revivido")


func _everyone_falls_and_votes() -> void:
	session().player.take_damage(999.0)
	await vote_for_first_blessing()
	if not await wait_until(func() -> bool: return RunState.attempt == 2, "segunda tentativa"):
		return
	if not await wait_level():
		return
	check(session().players.size() == 2, "o grupo volta inteiro na tentativa 2")
	var guest_peer := Net.peers_in_order().filter(func(peer_id: int) -> bool: return peer_id != HOST_PEER)[0] as int
	check(RunState.stats_of(HOST_PEER).deaths == 2, "placar: host caiu duas vezes")
	check(RunState.stats_of(guest_peer).deaths == 1, "placar: cliente caiu uma vez")


# o cliente avisa que terminou e so fecha depois que o host libera
func _leave_together() -> void:
	if role == "client":
		mark("fim")
		if await wait_mark("pode sair"):
			Net.leave()
	elif await wait_mark("fim"):
		mark("pode sair")
		await wait_until(func() -> bool: return multiplayer.get_peers().is_empty(), "cliente sair")


func _allies_in_cutscene() -> int:
	var count := 0
	for spot: Marker3D in get_tree().current_scene.party_spots:
		count += spot.get_child_count()
	return count


func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""
