extends Node
## Salvamento versionado e validado em user:// (nunca na pasta do jogo).

const SAVE_DIR := "user://saves/"
const VERSION := 1
const SLOTS := ["auto", "slot1", "slot2", "slot3"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func path_for(slot: String) -> String:
	return SAVE_DIR + slot + ".json"

func build_state() -> Dictionary:
	var pos := GameManager.last_safe_pos
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"chapter": GameManager.chapter,
		"room": GameManager.current_room,
		"spawn": GameManager.last_spawn,
		"pos": [pos.x, pos.y],
		"battery": GameManager.battery,
		"flashlight_on": false,   # estado transitório não é salvo
		"play_time": GameManager.play_time,
		"inventory": InventoryManager.serialize(),
		"narrative": NarrativeManager.serialize(),
	}

func validate(d: Dictionary) -> String:
	if not d.has("version") or typeof(d["version"]) not in [TYPE_INT, TYPE_FLOAT]:
		return "sem versão"
	if int(d["version"]) > VERSION:
		return "versão futura"
	var ch := int(d.get("chapter", 0))
	if ch < 1 or ch > 5:
		return "capítulo inválido"
	if not NarrativeManager.rooms_db.has(str(d.get("room", ""))):
		return "sala inválida"
	if typeof(d.get("inventory", null)) != TYPE_ARRAY:
		return "inventário inválido"
	if typeof(d.get("narrative", null)) != TYPE_DICTIONARY:
		return "narrativa inválida"
	var b = d.get("battery", -1)
	if typeof(b) not in [TYPE_INT, TYPE_FLOAT] or b < 0 or b > 100:
		return "bateria inválida"
	var pos = d.get("pos", null)
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
		return "posição inválida"
	return ""

func _migrate(d: Dictionary) -> Dictionary:
	# Ponto de extensão: migra versões antigas para VERSION (hoje só existe a v1).
	d["version"] = VERSION
	return d

func save_to(slot: String) -> bool:
	if GameManager.current_room == "":
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := path_for(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Não foi possível escrever o save: " + tmp)
		return false
	f.store_string(JSON.stringify(build_state(), "\t"))
	f.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.copy(path, path + ".bak")
		dir.remove(slot + ".json")
	return dir.rename(slot + ".json.tmp", slot + ".json") == OK

func read_slot(slot: String) -> Dictionary:
	var path := path_for(slot)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var f := FileAccess.open(candidate, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var d: Dictionary = parsed
			if int(d.get("version", 0)) < VERSION and d.has("version"):
				DirAccess.copy_absolute(candidate, candidate + ".premigration")
				d = _migrate(d)
			if validate(d) == "":
				return d
	return {}

func has_slot(slot: String) -> bool:
	return not read_slot(slot).is_empty()

func apply_state(d: Dictionary) -> bool:
	if validate(d) != "":
		return false
	GameManager.chapter = int(d["chapter"])
	GameManager.current_room = str(d["room"])
	GameManager.last_spawn = str(d.get("spawn", ""))
	GameManager.battery = clampf(float(d["battery"]), 0.0, 100.0)
	GameManager.flashlight_on = false
	GameManager.play_time = float(d.get("play_time", 0.0))
	GameManager.chasers.clear()
	GameManager.ended = ""
	var pos: Array = d["pos"]
	GameManager.pending_pos = Vector2(float(pos[0]), float(pos[1]))
	GameManager.has_pending_pos = true
	InventoryManager.deserialize(d["inventory"])
	NarrativeManager.deserialize(d["narrative"])
	return true

func load_slot(slot: String) -> bool:
	var d := read_slot(slot)
	if d.is_empty():
		return false
	return apply_state(d)

func slot_info(slot: String) -> Dictionary:
	var d := read_slot(slot)
	if d.is_empty():
		return {"slot": slot, "exists": false}
	var room: Dictionary = NarrativeManager.rooms_db.get(str(d["room"]), {})
	return {
		"slot": slot, "exists": true, "chapter": int(d["chapter"]), "room_name": room.get("name", ""),
		"time": float(d.get("play_time", 0.0)), "saved_at": str(d.get("saved_at", "")),
	}

func list_slots() -> Array:
	var out: Array = []
	for s in SLOTS:
		out.append(slot_info(s))
	return out

func latest_slot() -> String:
	var best := ""
	var best_at := ""
	for s in SLOTS:
		var d := read_slot(s)
		if d.is_empty():
			continue
		var at := str(d.get("saved_at", ""))
		if best == "" or at > best_at:
			best = s
			best_at = at
	return best

func has_any() -> bool:
	return latest_slot() != ""

func delete_slot(slot: String) -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		for ext in [".json", ".json.bak", ".json.tmp", ".json.premigration"]:
			if dir.file_exists(slot + ext):
				dir.remove(slot + ext)
