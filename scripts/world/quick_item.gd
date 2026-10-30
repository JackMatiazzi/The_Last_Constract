class_name QuickItem
extends Resource
## item do slot de acesso rapido: pegar so guarda, o efeito vale ao usar

@export var title := ""
@export var icon: Texture2D
## vida que cura ao usar
@export var heal_amount := 0.0
## mana que devolve ao usar
@export var mana_amount := 0.0
## quantos cabem no inventario
@export var max_carried := 4
