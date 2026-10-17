extends Node

# autoload porque a cena recarrega a cada Reviver e os buffs precisam continuar

const BUFF_DIR := "res://resources/buffs"
const ADVENTURERS: PackedStringArray = [
	"res://resources/adventurers/knight.tres",
	"res://resources/adventurers/barbarian.tres",
	"res://resources/adventurers/mage.tres",
	"res://resources/adventurers/rogue.tres",
]
const CHOICES_PER_DEATH := 2

var attempt := 1
var adventurer: AdventurerInfo
var buffs: Array[Buff] = []

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


# buff vem null quando todos ja estao no limite
func start_next_attempt(buff: Buff) -> void:
	if buff:
		buffs.append(buff)
	attempt += 1


func roster() -> Array[AdventurerInfo]:
	var infos: Array[AdventurerInfo] = []
	for path in ADVENTURERS:
		infos.append(load(path))
	return infos


# cena aberta direto no editor: ninguem escolheu, usa o primeiro
func current_adventurer() -> AdventurerInfo:
	if adventurer == null:
		adventurer = load(ADVENTURERS[0])
	return adventurer


func stacks_of(buff: Buff) -> int:
	return buffs.count(buff)


func reset() -> void:
	attempt = 1
	buffs.clear()
