class_name EnergyPool
extends RefCounted
## reserva que gasta e volta sozinha depois de uma pausa; estamina e mana sao duas destas

signal changed(current: float, maximum: float)

## com menos que o custo o golpe sai mais fraco, mas abaixo disso nem sai
const MIN_FRACTION := 0.25

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


## quanto do custo da para pagar agora; o dano do golpe escala com isso
func affordable_power(cost: float) -> float:
	if cost <= 0.0:
		return 1.0
	var power := minf(current / cost, 1.0)
	return power if power >= MIN_FRACTION else 0.0
