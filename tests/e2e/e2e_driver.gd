extends Node

# base dos testes de ponta a ponta: o jogo roda de verdade, da cena principal em diante, e o
# teste aperta os mesmos botoes que o jogador. Sai com codigo 1 se alguma conferencia falhar.
# O driver sai da cena de teste para a raiz, senao a primeira troca de cena o apagaria

const STEP_TIMEOUT := 20.0
const TOTAL_TIMEOUT := 120.0

var failures := PackedStringArray()
var label := "e2e"
# marcos que o outro processo ja passou; so o teste em grupo usa
var _marks := {}


func _ready() -> void:
	_take_over.call_deferred()


func _take_over() -> void:
	reparent(get_tree().root)
	get_tree().create_timer(TOTAL_TIMEOUT).timeout.connect(_give_up)
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	_run_and_report()


func _run_and_report() -> void:
	await run()
	if failures.is_empty():
		print("E2E OK %s" % label)
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("E2E FALHOU %s: %s" % [label, failure])
		get_tree().quit(1)


func run() -> void:
	pass


func check(condition: bool, what: String) -> void:
	if condition:
		print("E2E %s: %s" % [label, what])
	else:
		failures.append(what)


# espera a condicao em vez de um tempo fixo: em maquina lenta o jogo so demora mais
func wait_until(condition: Callable, what: String) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT * 1000.0
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			failures.append("tempo esgotado esperando: %s" % what)
			return false
		await get_tree().process_frame
	return true


func wait_scene(scene_name: String) -> bool:
	return await wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == scene_name and get_tree().current_scene.is_node_ready(), "cena %s" % scene_name)


# a fase so comeca de verdade depois da barreira de carregamento do grupo
func wait_level() -> bool:
	if not await wait_scene("VillageLevel"):
		return false
	return await wait_until(func() -> bool: return not Net.waiting_for_peers and get_tree().current_scene.has_node("GameSession"), "fase carregada")


func wait_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


# os dois processos tem um Driver na raiz, no mesmo caminho, entao a rpc acha o outro
func mark(step: String) -> void:
	_mark.rpc(step)


func wait_mark(step: String) -> bool:
	return await wait_until(func() -> bool: return _marks.has(step), "o outro processo chegar em %s" % step)


@rpc("any_peer", "reliable")
func _mark(step: String) -> void:
	_marks[step] = true


# a cutscene so aceita a tecla depois de comecar a tocar
func skip_cutscene() -> void:
	var intro := get_tree().current_scene
	if await wait_until(func() -> bool: return intro.timeline.is_playing(), "cutscene tocando"):
		press_any_key()


func press_any_key() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)


func press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func session() -> GameSession:
	return get_tree().current_scene.get_node("GameSession") as GameSession


# sem tela nao da para capturar o mouse; com controle o jogo aceita os comandos assim mesmo.
# Muda so a variavel, sem gravar nas configuracoes de quem roda o teste
func play_with_gamepad() -> void:
	Settings.input_device = Settings.InputDevice.GAMEPAD


# os inimigos ficam parados: o teste confere a partida, nao a luta
func calm_enemies() -> void:
	for enemy: Enemy in get_tree().current_scene.find_children("*", "Enemy", true, false):
		enemy.ai_enabled = false


# cair, abrir a votacao e escolher a primeira bencao, como o jogador faria na tela de morte
func vote_for_first_blessing() -> void:
	var death := get_tree().current_scene.get_node("DeathScreen") as DeathScreen
	if not await wait_until(func() -> bool: return death.visible and death.get_node("%ReviveButton").is_visible_in_tree(), "tela de morte"):
		return
	(death.get_node("%ReviveButton") as Button).pressed.emit()
	if not await wait_until(func() -> bool: return death.cards.get_child_count() > 0 and death.cards.get_child(0).has_focus(), "bencaos na tela"):
		return
	var card := death.cards.get_child(0) as BuffCard
	card.chosen.emit(card.buff)


func _give_up() -> void:
	printerr("E2E FALHOU %s: passou de %d s" % [label, TOTAL_TIMEOUT])
	get_tree().quit(1)
