class_name Buff
extends Resource

@export var title := ""
@export_multiline var flavor := ""
@export var modifiers: Array[StatModifier] = []
@export var max_stacks := 3


func describe() -> String:
	return "\n".join(modifiers.map(func(modifier: StatModifier) -> String: return modifier.describe()))
