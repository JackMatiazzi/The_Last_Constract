class_name QuickInventory
extends Node
## itens na ordem em que chegaram; a roda do mouse para baixo troca o selecionado

signal changed

var _items: Array[QuickItem] = []
var _counts := {}
var _selected := 0


func add(item: QuickItem) -> bool:
	var count := count_of(item)
	if count >= item.max_carried:
		return false
	if count == 0:
		_items.append(item)
	_counts[item] = count + 1
	changed.emit()
	return true


func take(item: QuickItem) -> void:
	_counts[item] -= 1
	if _counts[item] == 0:
		var index := _items.find(item)
		_counts.erase(item)
		_items.remove_at(index)
		# tirar um item antes do selecionado nao pode mudar qual esta selecionado
		if index < _selected:
			_selected -= 1
		_selected = clampi(_selected, 0, maxi(_items.size() - 1, 0))
	changed.emit()


func selected() -> QuickItem:
	return _items[_selected] if not _items.is_empty() else null


func select_next() -> void:
	if _items.size() < 2:
		return
	_selected = (_selected + 1) % _items.size()
	changed.emit()


func count_of(item: QuickItem) -> int:
	return _counts.get(item, 0)


## qualquer item que cure serve para reviver um aliado
func first_healing() -> QuickItem:
	for item in _items:
		if item.heal_amount > 0.0:
			return item
	return null
