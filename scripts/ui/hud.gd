class_name Hud
extends CanvasLayer

const ANNOUNCE_HOLD := 3.0
const ANNOUNCE_FADE := 0.6

@export var player: Character

@onready var attempt_label: Label = %AttemptLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var buff_list: VBoxContainer = %BuffList
@onready var crosshair: Control = %Crosshair
@onready var objective_label: Label = %ObjectiveLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_bar: ProgressBar = %BossBar
@onready var announcement: Label = %Announcement


func _ready() -> void:
	attempt_label.text = "Tentativa %d" % RunState.attempt
	_show_buffs()
	if player:
		bind(player)


func bind(new_player: Character) -> void:
	player = new_player
	crosshair.visible = player.attack is RangedAttack
	player.health_changed.connect(_on_health_changed)
	if player.is_node_ready():
		_on_health_changed(player.health, player.get_max_health())


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
