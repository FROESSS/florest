extends Node
## Inventário: itens-chave persistentes (sem duplicação).

signal item_added(id: String)
signal item_removed(id: String)

var items: Array[String] = []

func reset() -> void:
	items.clear()

func has_item(id: String) -> bool:
	return id in items

func add_item(id: String) -> bool:
	if id in items:
		return false  # nunca duplica
	items.append(id)
	item_added.emit(id)
	return true

func remove_item(id: String) -> bool:
	if id in items:
		items.erase(id)
		item_removed.emit(id)
		return true
	return false

func serialize() -> Array:
	return items.duplicate()

func deserialize(arr: Array) -> void:
	items.clear()
	for v in arr:
		var s := str(v)
		if NarrativeManager.items_db.has(s) and not (s in items):
			items.append(s)

func item_info(id: String) -> Dictionary:
	return NarrativeManager.items_db.get(id, {"name": id, "desc": "", "icon": "box"})
