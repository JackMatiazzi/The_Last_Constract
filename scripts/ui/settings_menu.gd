class_name SettingsMenu
extends Control

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var invert_check: CheckButton = %InvertCheck
@onready var device_option: OptionButton = %DeviceOption
@onready var stick_slider: HSlider = %StickSlider
@onready var stick_value: Label = %StickValue


func _ready() -> void:
	hide()
	_bind_slider(master_slider, &"master_volume")
	_bind_slider(music_slider, &"music_volume")
	_bind_slider(sfx_slider, &"sfx_volume")
	_bind_slider(sensitivity_slider, &"mouse_sensitivity")
	_bind_check(fullscreen_check, &"fullscreen")
	_bind_check(vsync_check, &"vsync")
	_bind_check(invert_check, &"invert_y")
	_bind_slider(stick_slider, &"stick_sensitivity")
	device_option.selected = device_option.get_item_index(Settings.input_device)
	device_option.item_selected.connect(func(index: int) -> void:
		Settings.set_value(&"input_device", device_option.get_item_id(index)))
	_show_multiplier(sensitivity_slider, sensitivity_value)
	_show_multiplier(stick_slider, stick_value)
	%BackButton.pressed.connect(close)


func open() -> void:
	show()
	%Tabs.current_tab = 0
	%BackButton.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("menu_previous") or event.is_action_pressed("menu_next"):
		var step := -1 if event.is_action_pressed("menu_previous") else 1
		%Tabs.current_tab = wrapi(%Tabs.current_tab + step, 0, %Tabs.get_tab_count())
	else:
		return
	get_viewport().set_input_as_handled()


func _bind_slider(slider: HSlider, key: StringName) -> void:
	slider.value = Settings.get(key)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))


func _bind_check(check: CheckButton, key: StringName) -> void:
	check.button_pressed = Settings.get(key)
	check.toggled.connect(func(pressed: bool) -> void: Settings.set_value(key, pressed))


func _show_multiplier(slider: HSlider, label: Label) -> void:
	var show := func(value: float) -> void: label.text = "%.1fx" % value
	slider.value_changed.connect(show)
	show.call(slider.value)
