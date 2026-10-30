class_name CostTicks
extends Control
## marcas sobre a barra de energia, uma a cada custo do golpe atual: cada bloco cheio e um golpe

## largura de cada marca, em pixels
@export var line_width := 2.0
@export var color := Color(0.05, 0.04, 0.03, 0.85)

var _step := 0.0


## step: custo do golpe em fracao da barra; 0 tira as marcas
func set_step(step: float) -> void:
	_step = step
	queue_redraw()


## onde cada marca cai, em fracao da largura da barra
func tick_positions() -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	if _step <= 0.0:
		return positions
	var at := _step
	while at < 1.0 - 0.001:
		positions.append(at)
		at += _step
	return positions


func _draw() -> void:
	for fraction in tick_positions():
		var x := size.x * fraction
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, line_width)
