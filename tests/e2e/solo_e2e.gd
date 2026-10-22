extends "res://tests/e2e/e2e_driver.gd"

# um contrato solo do menu ate a segunda tentativa: escolher, assistir, jogar, cair, votar e voltar

const MAGE_INDEX := 2


func run() -> void:
	label = "solo"
	play_with_gamepad()
	if not await wait_scene("MainMenu"):
		return
	(get_tree().current_scene.get_node("%PlayButton") as Button).pressed.emit()

	if not await wait_scene("CharacterSelect"):
		return
	var picker := get_tree().current_scene.get_node("%AdventurerPicker") as AdventurerPicker
	picker.select(MAGE_INDEX)
	(picker.get_node("%AcceptButton") as Button).pressed.emit()

	if not await wait_scene("MissionIntro"):
		return
	await skip_cutscene()

	if not await wait_level():
		return
	calm_enemies()
	var game := session()
	check(game.player.scene_file_path.ends_with("mage.tscn"), "o mago escolhido entrou na fase")
	check(game.players.size() == 1, "solo e um grupo de um")
	check(game.player.mana != null and game.player.stamina != null, "mago com mana e estamina")
	check((get_tree().current_scene.get_node("Hud") as Hud).attempt_label.text == "Tentativa 1", "HUD mostra a tentativa 1")

	press_action(&"next_ability")
	if await wait_until(func() -> bool: return game.player.attack is PortalSpell, "troca de habilidade"):
		check(true, "a roda troca para o Portal")

	game.player.take_damage(999.0)
	await vote_for_first_blessing()
	if not await wait_until(func() -> bool: return RunState.attempt == 2, "segunda tentativa"):
		return
	if not await wait_level():
		return
	check(RunState.buffs.size() == 1, "a bencao escolhida acompanha a nova tentativa")
	check(not session().player.is_dead, "o mago volta vivo")
