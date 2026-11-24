extends Node
## Dados narrativos (JSON), flags persistentes, documentos, memórias, objetivos e finais.

signal flag_changed(id: String, value: Variant)
signal document_added(id: String)
signal memory_added(id: String)
signal objective_changed(text: String)

const DATA_ITEMS := "res://data/items/items.json"
const DATA_DOCS := "res://data/documents/documents.json"
const DATA_DIALOGUE := "res://data/dialogue/dialogue.json"
const DATA_PUZZLES := "res://data/puzzles/puzzles.json"
const CHAPTER_FILES := [
	"res://data/chapters/chapter_1.json", "res://data/chapters/chapter_2.json",
	"res://data/chapters/chapter_3.json", "res://data/chapters/chapter_4.json",
	"res://data/chapters/chapter_5.json",
]

var items_db: Dictionary = {}
var docs_db: Dictionary = {}
var memories_db: Dictionary = {}
var cutscenes_db: Dictionary = {}
var choices_db: Dictionary = {}
var puzzles_db: Dictionary = {}
var chapters_db: Dictionary = {}   # int -> {title, start_room, start_spawn, ...}
var rooms_db: Dictionary = {}      # room_id -> spec (com "chapter")
var load_errors: Array[String] = []

var flags: Dictionary = {}
var docs_found: Array[String] = []
var memories_found: Array[String] = []
var objective: String = ""
var puzzle_states: Dictionary = {}     # id -> not_started | in_progress | solved | blocked
var puzzle_attempts: Dictionary = {}

const PUZZLE_STATES := ["not_started", "in_progress", "solved", "blocked"]

func _ready() -> void:
	load_all()

# ---------- Carregamento ----------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_errors.append("Arquivo ausente: " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		load_errors.append("JSON inválido: " + path)
	return parsed

func load_all() -> void:
	load_errors.clear()
	var it = _read_json(DATA_ITEMS)
	if it is Dictionary:
		items_db = it
	var dc = _read_json(DATA_DOCS)
	if dc is Dictionary:
		docs_db = dc
	var dl = _read_json(DATA_DIALOGUE)
	if dl is Dictionary:
		memories_db = dl.get("memories", {})
		cutscenes_db = dl.get("cutscenes", {})
		choices_db = dl.get("choices", {})
	var pz = _read_json(DATA_PUZZLES)
	if pz is Dictionary:
		puzzles_db = pz
	chapters_db.clear()
	rooms_db.clear()
	for p in CHAPTER_FILES:
		var ch = _read_json(p)
		if ch is Dictionary:
			var num := int(ch.get("id", 0))
			chapters_db[num] = ch
			var rooms: Dictionary = ch.get("rooms", {})
			for rid in rooms:
				var spec: Dictionary = rooms[rid]
				spec["chapter"] = num
				spec["id"] = rid
				rooms_db[rid] = spec

# ---------- Estado ----------

func reset() -> void:
	flags.clear()
	docs_found.clear()
	memories_found.clear()
	objective = ""
	puzzle_states.clear()
	puzzle_attempts.clear()

func puzzle_state(pid: String) -> String:
	if has_flag("solved_" + pid):
		return "solved"
	return str(puzzle_states.get(pid, "not_started"))

func set_puzzle_state(pid: String, state: String) -> void:
	if state not in PUZZLE_STATES:
		return
	if puzzle_state(pid) == "solved" and state != "solved":
		return    # resolvido nunca regride
	puzzle_states[pid] = state
	if state == "solved":
		set_flag("solved_" + pid, true)

func add_attempt(pid: String) -> int:
	puzzle_attempts[pid] = int(puzzle_attempts.get(pid, 0)) + 1
	return int(puzzle_attempts[pid])

func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value
	flag_changed.emit(id, value)

func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)

func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))

func add_counter(id: String, n: int = 1) -> int:
	var v := int(flags.get(id, 0)) + n
	set_flag(id, v)
	return v

func counter(id: String) -> int:
	return int(flags.get(id, 0))

func add_document(id: String) -> bool:
	if id in docs_found or not docs_db.has(id):
		return false
	docs_found.append(id)
	set_flag("doc_" + id, true)
	document_added.emit(id)
	return true

func add_memory(id: String) -> bool:
	if id in memories_found or not memories_db.has(id):
		return false
	memories_found.append(id)
	set_flag("mem_" + id, true)
	memory_added.emit(id)
	return true

func memory_count() -> int:
	return memories_found.size()

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)

# ---------- Condições ----------

func check(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	for f in cond.get("flags", []):
		if not has_flag(str(f)):
			return false
	for f in cond.get("not_flags", []):
		if has_flag(str(f)):
			return false
	var any_list: Array = cond.get("any_flags", [])
	if not any_list.is_empty():
		var ok := false
		for f in any_list:
			if has_flag(str(f)):
				ok = true
		if not ok:
			return false
	for i in cond.get("items", []):
		if not InventoryManager.has_item(str(i)):
			return false
	for i in cond.get("not_items", []):
		if InventoryManager.has_item(str(i)):
			return false
	var counters: Dictionary = cond.get("counter", {})
	for c in counters:
		if counter(c) < int(counters[c]):
			return false
	if cond.has("memories_min") and memory_count() < int(cond["memories_min"]):
		return false
	if cond.has("chapter_min") and GameManager.chapter < int(cond["chapter_min"]):
		return false
	return true

# ---------- Finais ----------
# Tabela (documentada em docs/ENDINGS.md):
#  liberdade        -> opção disponível se flag escape_tunnel_open
#  silencio         -> opção disponível se reactor_primed OU equipment_destroyed
#  herdeiro         -> opção disponível se control_card
#  coisas_perdidas  -> secreto: >=10 de 13 memórias, mem_pre_inauguracao, clara_trust>=2,
#                      doc_registro_elias guardado (flag keep_elias_record) e equipamento NÃO destruído

func secret_available() -> bool:
	return memory_count() >= 10 \
		and has_flag("mem_pre_inauguracao") \
		and counter("clara_trust") >= 2 \
		and has_flag("keep_elias_record") \
		and not has_flag("equipment_destroyed")

func final_options() -> Array:
	var opts: Array = []
	if has_flag("escape_tunnel_open"):
		opts.append({"id": "liberdade", "text": "Fugir pelo túnel de serviço."})
	if has_flag("reactor_primed") or has_flag("equipment_destroyed"):
		opts.append({"id": "silencio", "text": "Destruir o laboratório."})
	if has_flag("control_card"):
		opts.append({"id": "herdeiro", "text": "Assumir o sistema."})
	if secret_available():
		opts.append({"id": "coisas_perdidas", "text": "Ouvir Clara até o fim."})
	return opts

func ending_cutscene(ending_id: String) -> String:
	return "ending_" + ending_id

# ---------- Serialização ----------

func serialize() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"docs": docs_found.duplicate(),
		"memories": memories_found.duplicate(),
		"objective": objective,
		"puzzles": puzzle_states.duplicate(),
		"attempts": puzzle_attempts.duplicate(),
	}

func deserialize(d: Dictionary) -> void:
	reset()
	var f: Dictionary = d.get("flags", {})
	for k in f:
		var v = f[k]
		if typeof(v) == TYPE_FLOAT and floorf(v) == v:
			v = int(v)  # JSON devolve números como float
		flags[str(k)] = v
	for v in d.get("docs", []):
		if docs_db.has(str(v)):
			docs_found.append(str(v))
	for v in d.get("memories", []):
		if memories_db.has(str(v)):
			memories_found.append(str(v))
	objective = str(d.get("objective", ""))
	var pz: Dictionary = d.get("puzzles", {})
	for k in pz:
		if str(pz[k]) in PUZZLE_STATES and puzzles_db.has(str(k)):
			puzzle_states[str(k)] = str(pz[k])
	for k in flags:
		if str(k).begins_with("solved_") and puzzles_db.has(str(k).substr(7)):
			puzzle_states[str(k).substr(7)] = "solved"
	var at: Dictionary = d.get("attempts", {})
	for k in at:
		puzzle_attempts[str(k)] = int(at[k])
