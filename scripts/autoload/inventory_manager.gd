extends Node
## Inventário: itens-chave únicos (sem duplicação) e itens empilháveis (kits médicos, com limite).

signal item_added(id: String)
signal item_removed(id: String)

var items: Array[String] = []

func reset() -> void:
	items.clear()

func has_item(id: String) -> bool:
	return id in items

func count(id: String) -> int:
	return items.count(id)

func is_stack(id: String) -> bool:
	return bool(NarrativeManager.items_db.get(id, {}).get("stack", false))

func max_stack(id: String) -> int:
	return int(NarrativeManager.items_db.get(id, {}).get("max", 1))

func add_item(id: String) -> bool:
	if is_stack(id):
		if count(id) >= max_stack(id):
			return false
	elif id in items:
		return false  # itens-chave nunca duplicam
	items.append(id)
	item_added.emit(id)
	return true

func remove_item(id: String) -> bool:
	var i := items.find(id)
	if i >= 0:
		items.remove_at(i)
		item_removed.emit(id)
		return true
	return false

func serialize() -> Array:
	return items.duplicate()

func deserialize(arr: Array) -> void:
	items.clear()
	for v in arr:
		var s := str(v)
		if not NarrativeManager.items_db.has(s):
			continue
		if is_stack(s):
			if count(s) < max_stack(s):
				items.append(s)
		elif not (s in items):
			items.append(s)

func item_info(id: String) -> Dictionary:
	return NarrativeManager.items_db.get(id, {"name": id, "desc": "", "icon": "box"})
