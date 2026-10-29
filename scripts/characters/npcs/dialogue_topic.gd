class_name DialogueTopic
extends Resource
## assunto que o NPC so puxa quando algo do mundo chegou a um ponto: um portao abriu, falta um selo, sobram
## poucos mortos-vivos. Observa uma propriedade (ou metodo sem argumento) do no em watch, relativo ao NPC;
## verdadeiro conta 1 e falso 0. {valor} nas falas vira o valor lido

## No observado, relativo ao NPC.
@export var watch: NodePath
## Propriedade ou metodo sem argumento lido no no observado.
@export var property: StringName
## O assunto vale a partir deste valor.
@export var at_least := 1
## negativo: sem teto
@export var below := -1
## Ditas em ordem, uma por conversa.
@export var lines := PackedStringArray()


func read(owner: Node) -> int:
	var node := owner.get_node_or_null(watch)
	if node == null:
		return 0
	var value: Variant = node.call(property) if node.has_method(property) else node.get(property)
	return int(value)


func holds(owner: Node) -> bool:
	var value := read(owner)
	return value >= at_least and (below < 0 or value < below)
