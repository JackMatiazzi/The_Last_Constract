class_name Hud
extends CanvasLayer

const ANNOUNCE_HOLD := 3.0
const ANNOUNCE_FADE := 0.6
const FEED_HOLD := 5.0
const FEED_MAX := 5
const SCORE_HEADERS := 5
const SHORT_FLASH := Color(1.0, 0.35, 0.3)

@export var player: Character
@export var feed_entry_scene: PackedScene
@export var score_cell_scene: PackedScene

@onready var attempt_label: Label = %AttemptLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var ability_icon: TextureRect = %AbilityIcon
@onready var ability_cost: Label = %AbilityCost
@onready var ability_name: Label = %AbilityName
@onready var secondary_slot: Control = %SecondarySlot
@onready var secondary_icon: TextureRect = %SecondaryIcon
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_count: Label = %ItemCount
@onready var item_hint: Label = %ItemHint
@onready var ability_progress: TextureProgressBar = %AbilityProgress
@onready var item_progress: TextureProgressBar = %ItemProgress
@onready var buff_list: VBoxContainer = %BuffList
@onready var crosshair: Control = %Crosshair
@onready var objective_label: Label = %ObjectiveLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_bar: ProgressBar = %BossBar
@onready var announcement: Label = %Announcement
@onready var feed: VBoxContainer = %Feed
@onready var score_layer: CanvasLayer = %ScoreLayer
@onready var score_grid: GridContainer = %ScoreGrid

var _bound_player: Character


func _ready() -> void:
	assert(feed_entry_scene and score_cell_scene, "Hud: aponte as cenas do aviso e do placar")
	attempt_label.text = "Tentativa %d" % RunState.attempt
	_show_buffs()
	if player:
		bind(player)
	RunState.feed_posted.connect(_post_feed)
	RunState.stats_changed.connect(_refresh_scoreboard)


func _process(_delta: float) -> void:
	var adventurer := player as Adventurer
	if adventurer:
		ability_progress.value = adventurer.heavy_progress()
		item_progress.value = adventurer.drink_progress()
	var holding := Input.is_action_pressed("scoreboard")
	if holding and not score_layer.visible:
		_refresh_scoreboard()
	score_layer.visible = holding


## ligar duas vezes no mesmo jogador dobraria cada sinal
func bind(new_player: Character) -> void:
	if new_player == _bound_player:
		return
	_bound_player = new_player
	player = new_player
	player.health_changed.connect(_on_health_changed)
	if player.is_node_ready():
		_on_health_changed(player.health, player.get_max_health())
	_bind_energy(player as Adventurer)
	_bind_quickbar(player as Adventurer)


func set_objective(text: String) -> void:
	objective_label.text = text


func show_boss(boss: Character) -> void:
	boss_panel.show()
	boss_bar.max_value = boss.get_max_health()
	boss_bar.value = boss.health
	boss.health_changed.connect(func(current: float, maximum: float) -> void:
		boss_bar.max_value = maximum
		boss_bar.value = current)
	boss.died.connect(boss_panel.hide)


func announce(text: String) -> void:
	announcement.text = text
	var fade := create_tween()
	fade.tween_property(announcement, "modulate:a", 1.0, ANNOUNCE_FADE)
	fade.tween_interval(ANNOUNCE_HOLD)
	fade.tween_property(announcement, "modulate:a", 0.0, ANNOUNCE_FADE)


func _bind_energy(adventurer: Adventurer) -> void:
	if adventurer == null:
		return
	_bind_pool(adventurer.stamina, stamina_bar)
	if adventurer.mana:
		_bind_pool(adventurer.mana, mana_bar)
	adventurer.energy_short.connect(func(pool: EnergyPool) -> void:
		_flash(mana_bar if pool == adventurer.mana else stamina_bar))


func _bind_quickbar(adventurer: Adventurer) -> void:
	if adventurer == null:
		return
	adventurer.ability_changed.connect(_show_ability.bind(adventurer))
	adventurer.inventory.changed.connect(_show_item.bind(adventurer))
	_show_ability(adventurer)
	_show_item(adventurer)
	_show_secondary(adventurer)


# o custo aparece em % da barra: da para usar a vontade, mas a barra mostra o peso
func _show_ability(adventurer: Adventurer) -> void:
	var pool := adventurer.attack_pool()
	var source := "mana" if pool == adventurer.mana else "estamina"
	ability_icon.texture = adventurer.attack.icon
	ability_cost.text = "%d%%" % roundi(adventurer.cost_of(adventurer.attack) / pool.maximum * 100.0)
	ability_name.text = "%s\n%s" % [adventurer.attack.title, source]
	crosshair.visible = adventurer.attack is RangedAttack or adventurer.attack is PortalSpell


func _show_item(adventurer: Adventurer) -> void:
	var item := adventurer.inventory.selected()
	item_icon.texture = item.icon if item else null
	item_count.text = "×%d" % adventurer.inventory.count_of(item) if item else ""
	var hold := "segure X" if Settings.uses_gamepad() else "segure E"
	item_hint.text = "%s\n%s" % [item.title, hold] if item else "Sem itens"


# sem botao direito (Rogue e Mage) o slot some, mas continua ocupando a celula: a cruz nao muda de lugar
func _show_secondary(adventurer: Adventurer) -> void:
	var icon: Texture2D = null
	if adventurer.block:
		icon = adventurer.block.icon
	elif adventurer.secondary_attack:
		icon = adventurer.secondary_attack.icon
	secondary_icon.texture = icon
	secondary_slot.self_modulate.a = 1.0 if icon else 0.0


func _bind_pool(pool: EnergyPool, bar: ProgressBar) -> void:
	bar.show()
	bar.max_value = pool.maximum
	bar.value = pool.current
	pool.changed.connect(func(current: float, maximum: float) -> void:
		bar.max_value = maximum
		bar.value = current)


func _flash(bar: ProgressBar) -> void:
	bar.modulate = SHORT_FLASH
	bar.create_tween().tween_property(bar, "modulate", Color.WHITE, 0.3)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _show_buffs() -> void:
	%BuffTitle.visible = not RunState.buffs.is_empty()
	var seen: Array[Buff] = []
	for buff in RunState.buffs:
		if buff in seen:
			continue
		seen.append(buff)
		var entry := Label.new()
		var stacks := RunState.stacks_of(buff)
		entry.text = "%s%s: %s" % [buff.title, " ×%d" % stacks if stacks > 1 else "", buff.describe().replace("\n", ", ")]
		entry.theme_type_variation = &"MutedLabel"
		buff_list.add_child(entry)


func _post_feed(text: String) -> void:
	var entry := feed_entry_scene.instantiate() as Label
	entry.text = text
	feed.add_child(entry)
	if feed.get_child_count() > FEED_MAX:
		feed.get_child(0).queue_free()
	var fade := entry.create_tween()
	fade.tween_interval(FEED_HOLD)
	fade.tween_property(entry, "modulate:a", 0.0, ANNOUNCE_FADE)
	fade.tween_callback(entry.queue_free)


func _refresh_scoreboard() -> void:
	for cell in score_grid.get_children().slice(SCORE_HEADERS):
		cell.queue_free()
	var peers: Array = Net.peers_in_order() if Net.is_online() else [multiplayer.get_unique_id()]
	for peer_id: int in peers:
		var line := RunState.stats_of(peer_id)
		var you := " (você)" if peer_id == multiplayer.get_unique_id() else ""
		for value in [Net.display_name(peer_id) + you, line.kills, line.assists, line.deaths, line.last_death if line.last_death != "" else "-"]:
			var cell := score_cell_scene.instantiate() as Label
			cell.text = str(value)
			if value is int:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			score_grid.add_child(cell)
