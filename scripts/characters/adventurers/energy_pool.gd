class_name EnergyPool
extends RefCounted
## reserva que gasta e volta sozinha depois de uma pausa; estamina e mana sao duas destas

signal changed(current: float, maximum: float)

var current: float
var maximum: float
var regen_per_second: float
var regen_delay: float
## zerada, recarrega sem esperar a pausa
var recovers_when_empty := false

var _wait := 0.0


func _init(max_value: float, regen: float, delay: float) -> void:
	maximum = max_value
	current = max_value
	regen_per_second = regen
	regen_delay = delay


func spend(amount: float) -> void:
	current = maxf(current - amount, 0.0)
	_wait = 0.0 if recovers_when_empty and current == 0.0 else regen_delay
	changed.emit(current, maximum)


func restore(amount: float) -> void:
	current = minf(current + amount, maximum)
	changed.emit(current, maximum)


func regenerate(delta: float) -> void:
	if current >= maximum:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	current = minf(current + regen_per_second * delta, maximum)
	changed.emit(current, maximum)


func refill() -> void:
	current = maximum
	_wait = 0.0
	changed.emit(current, maximum)


## da para pagar o custo inteiro agora
func can_afford(cost: float) -> bool:
	return current >= cost
