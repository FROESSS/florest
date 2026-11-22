extends Node
## Estado global da partida: capítulo, sala, bateria, lanterna, ruído, perseguição e testes.

signal noise_emitted(pos: Vector2, radius: float, source: String)
signal chase_changed(active: bool)
signal battery_changed(value: float)
signal flashlight_changed(on: bool)
signal player_captured(by: String)
signal chapter_changed(chapter: int)
signal toast(text: String)

const BATTERY_DRAIN_PER_SEC := 0.3     # ~5,5 min de lanterna contínua
const BATTERY_MAX := 100.0

var chapter: int = 1
var current_room: String = ""
var last_spawn: String = ""
var last_safe_pos: Vector2 = Vector2.ZERO
var battery: float = BATTERY_MAX
var flashlight_on: bool = false
var play_time: float = 0.0
var world = null                        # Game (scripts/world/game.gd)
var player = null                       # Player
var chasers: Dictionary = {}            # id -> true enquanto perseguindo
var ended: String = ""                  # id do final alcançado
var input_locked: bool = false
var pending_pos: Vector2 = Vector2.ZERO   # posição a restaurar ao carregar um save
var has_pending_pos: bool = false
var test_mode: bool = false             # usado por tests/ (puzzles/escolhas auto-resolvidos)
var test_choices: Dictionary = {}       # choice_id -> índice
var deaths: int = 0
var docs_opened: int = 0                # contador de aberturas de documento/inspeção (testes)
var test_puzzle_answers: Dictionary = {} # puzzle_id -> bool (modo de teste)
var world_state: Dictionary = {}        # estado persistente do mundo (buracos do Morador etc.)
var player_state: Dictionary = {}       # estamina, ferimentos, kits usados

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if world != null and not get_tree().paused:
		play_time += delta
		if flashlight_on:
			set_battery(battery - BATTERY_DRAIN_PER_SEC * delta)
			if battery <= 0.0:
				set_flashlight(false)
				toast.emit(LocalizationManager.t("hud.no_battery"))

func new_game() -> void:
	chapter = 1
	current_room = ""
	last_spawn = ""
	battery = BATTERY_MAX
	flashlight_on = false
	play_time = 0.0
	chasers.clear()
	ended = ""
	input_locked = false
	has_pending_pos = false
	world_state = {}
	player_state = {}
	NarrativeManager.reset()
	InventoryManager.reset()
	var ch: Dictionary = NarrativeManager.chapters_db.get(1, {})
	current_room = ch.get("start_room", "c1_quarto")
	last_spawn = ch.get("start_spawn", "cama")

func set_battery(v: float) -> void:
	battery = clampf(v, 0.0, BATTERY_MAX)
	battery_changed.emit(battery)

func has_flashlight() -> bool:
	return InventoryManager.has_item("lanterna")

func set_flashlight(on: bool) -> void:
	if on and (not has_flashlight() or battery <= 0.0):
		AudioManager.play_sfx("error", -8.0)
		return
	if on == flashlight_on:
		return
	flashlight_on = on
	AudioManager.play_sfx("flashlight", -4.0)
	flashlight_changed.emit(on)

func emit_noise(pos: Vector2, radius: float, source: String = "") -> void:
	noise_emitted.emit(pos, radius, source)

func set_chasing(id: String, active: bool) -> void:
	var before := is_chased()
	if active:
		chasers[id] = true
	else:
		chasers.erase(id)
	if before != is_chased():
		chase_changed.emit(is_chased())

func is_chased() -> bool:
	return not chasers.is_empty()

func set_chapter(n: int) -> void:
	chapter = n
	chapter_changed.emit(n)

func capture(by: String) -> void:
	player_captured.emit(by)
