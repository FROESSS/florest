extends Node
## Configurações persistentes (user://settings.cfg), mapa de entradas e barramentos de áudio.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const BASE_W := 640
const BASE_H := 360

var volume_master: float = 0.9
var volume_music: float = 0.8
var volume_sfx: float = 0.9
var volume_ambient: float = 0.8
var fullscreen: bool = false
var window_scale: int = 2          # 1..4 (múltiplos inteiros de 640x360)
var subtitles: bool = true
var reduce_flashes: bool = false
var reduce_shake: bool = false
var reduce_distortion: bool = false
var language: String = "pt-BR"
var walk_speed: float = 70.0       # px/s (configurável em settings.cfg)
var run_speed: float = 125.0

const ACTION_ORDER := ["move_up", "move_down", "move_left", "move_right", "interact", "run", "flashlight", "inventory", "journal", "heal", "pause"]
const ACTION_LABELS := {
	"move_up": "Mover para cima", "move_down": "Mover para baixo", "move_left": "Mover para a esquerda",
	"move_right": "Mover para a direita", "interact": "Interagir / confirmar", "run": "Correr",
	"flashlight": "Lanterna", "inventory": "Inventário", "journal": "Diário", "heal": "Usar kit médico", "pause": "Pausa / voltar",
}
const DEFAULT_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E, KEY_NONE], "run": [KEY_SHIFT, KEY_NONE], "flashlight": [KEY_F, KEY_NONE],
	"inventory": [KEY_TAB, KEY_NONE], "journal": [KEY_J, KEY_NONE], "heal": [KEY_H, KEY_NONE],
	"pause": [KEY_ESCAPE, KEY_NONE],
}
const RESERVED_KEYS := [KEY_ESCAPE]    # Esc fica sempre para "pausa/voltar"

var bindings: Dictionary = {}          # ação -> [tecla principal, tecla alternativa] (physical keycodes)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_bindings(false)
	_register_inputs()
	_ensure_buses()
	load_settings()
	apply_bindings()
	apply()

func _register_inputs() -> void:
	for action in ACTION_ORDER:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	# W/S/A/D também navegam nos menus (independente do remapeamento do jogo)
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev2)

func reset_bindings(apply_now: bool = true) -> void:
	bindings.clear()
	for a in ACTION_ORDER:
		bindings[a] = (DEFAULT_BINDINGS[a] as Array).duplicate()
	if apply_now:
		apply_bindings()

## Reconstrói o InputMap a partir de `bindings`.
func apply_bindings() -> void:
	for action in ACTION_ORDER:
		InputMap.action_erase_events(action)
		for k in bindings[action]:
			if int(k) != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = int(k)
				InputMap.action_add_event(action, ev)

func key_name(action: String, slot: int = -1) -> String:
	var arr: Array = bindings.get(action, [])
	var keys: Array = []
	if slot >= 0:
		keys = [arr[slot]] if slot < arr.size() else []
	else:
		for k in arr:
			if int(k) != KEY_NONE:
				keys.append(k)
	if keys.is_empty() or int(keys[0]) == KEY_NONE:
		return "—"
	return _keycode_text(int(keys[0]))

static func _keycode_text(k: int) -> String:
	var s := ""
	if DisplayServer.get_name() != "headless":
		s = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k as Key))
	if s == "":
		s = OS.get_keycode_string(k as Key)
	return s if s != "" else str(k)

## Ação que já usa esta tecla (diferente de `except_action`), ou "".
func find_conflict(keycode: int, except_action: String) -> String:
	for a in ACTION_ORDER:
		if a == except_action:
			continue
		if keycode in bindings[a]:
			return a
	return ""

## Tenta atribuir. Retorna {"ok": bool, "conflict": String, "reason": String}.
## Se houver conflito e swap=false, nada muda (a UI informa e pergunta). Com swap=true, as ações trocam de tecla.
func rebind(action: String, slot: int, keycode: int, swap: bool = false) -> Dictionary:
	if not bindings.has(action) or slot < 0 or slot > 1:
		return {"ok": false, "conflict": "", "reason": "ação inválida"}
	if keycode in RESERVED_KEYS and action != "pause":
		return {"ok": false, "conflict": "", "reason": "reservada"}
	if keycode == KEY_NONE:
		return {"ok": false, "conflict": "", "reason": "tecla inválida"}
	var arr: Array = bindings[action]
	if arr[slot] == keycode:
		return {"ok": true, "conflict": "", "reason": "igual"}
	if arr[1 - slot] == keycode:
		return {"ok": false, "conflict": action, "reason": "mesma ação"}
	var other := find_conflict(keycode, action)
	if other != "" and not swap:
		return {"ok": false, "conflict": other, "reason": "conflito"}
	var old: int = arr[slot]
	if other != "":
		var oarr: Array = bindings[other]
		var oslot: int = oarr.find(keycode)
		# a outra ação recebe a tecla antiga; se estiver vazia, ela ficaria sem tecla principal: impedimos
		if old == KEY_NONE and (oarr[1 - oslot] == KEY_NONE):
			return {"ok": false, "conflict": other, "reason": "deixaria '%s' sem tecla" % other}
		oarr[oslot] = old
	arr[slot] = keycode
	# toda ação precisa ter ao menos uma tecla: se a principal ficou vazia, move a alternativa
	for a in ACTION_ORDER:
		var ar: Array = bindings[a]
		if ar[0] == KEY_NONE and ar[1] != KEY_NONE:
			ar[0] = ar[1]
			ar[1] = KEY_NONE
	apply_bindings()
	return {"ok": true, "conflict": other, "reason": ""}

func clear_alternate(action: String) -> void:
	var arr: Array = bindings[action]
	arr[1] = KEY_NONE
	apply_bindings()

func controls_hint() -> String:
	return "%s/%s: mover · %s: correr · %s: interagir · %s: lanterna · %s: inventário · %s: diário · %s: kit · %s: pausa" % [
		key_name("move_up", 0) + key_name("move_left", 0) + key_name("move_down", 0) + key_name("move_right", 0), "Setas" if bindings["move_up"][1] == KEY_UP else "alt.",
		key_name("run"), key_name("interact"), key_name("flashlight"), key_name("inventory"), key_name("journal"), key_name("heal"), key_name("pause")]

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)

func apply() -> void:
	var map := {"Master": volume_master, "Music": volume_music, "SFX": volume_sfx, "Ambient": volume_ambient}
	for b in map:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, _db(map[b]))
	if DisplayServer.get_name() != "headless":
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var s := clampi(window_scale, 1, 4)
			DisplayServer.window_set_size(Vector2i(BASE_W * s, BASE_H * s))
			var scr := DisplayServer.screen_get_size()
			DisplayServer.window_set_position((scr - Vector2i(BASE_W * s, BASE_H * s)) / 2)
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in ["volume_master", "volume_music", "volume_sfx", "volume_ambient", "fullscreen", "window_scale",
			"subtitles", "reduce_flashes", "reduce_shake", "reduce_distortion", "language", "walk_speed", "run_speed"]:
		cfg.set_value("settings", k, get(k))
	for a in ACTION_ORDER:
		cfg.set_value("controls", a, (bindings[a] as Array).duplicate())
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in ["volume_master", "volume_music", "volume_sfx", "volume_ambient", "fullscreen", "window_scale",
			"subtitles", "reduce_flashes", "reduce_shake", "reduce_distortion", "language", "walk_speed", "run_speed"]:
		if cfg.has_section_key("settings", k):
			var v = cfg.get_value("settings", k)
			var cur = get(k)
			if typeof(v) == typeof(cur) or (typeof(cur) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				set(k, v)
	_load_bindings(cfg)
	volume_master = clampf(volume_master, 0.0, 1.0)
	volume_music = clampf(volume_music, 0.0, 1.0)
	volume_sfx = clampf(volume_sfx, 0.0, 1.0)
	volume_ambient = clampf(volume_ambient, 0.0, 1.0)
	window_scale = clampi(window_scale, 1, 4)
	walk_speed = clampf(walk_speed, 30.0, 140.0)
	run_speed = clampf(run_speed, 60.0, 220.0)

## Lê os controles salvos; qualquer inconsistência (tipo, duplicata, ação sem tecla) volta ao padrão.
func _load_bindings(cfg: ConfigFile) -> void:
	if not cfg.has_section("controls"):
		return
	var loaded := {}
	var used := {}
	for a in ACTION_ORDER:
		var v = cfg.get_value("controls", a, null)
		if not (v is Array) or (v as Array).size() != 2:
			return reset_bindings(false)
		var pair: Array = []
		for k in v:
			if typeof(k) not in [TYPE_INT, TYPE_FLOAT]:
				return reset_bindings(false)
			pair.append(int(k))
		if pair[0] == KEY_NONE:
			return reset_bindings(false)
		for k in pair:
			if k != KEY_NONE:
				if used.has(k) or (k in RESERVED_KEYS and a != "pause"):
					return reset_bindings(false)
				used[k] = true
		loaded[a] = pair
	bindings = loaded
	apply_bindings()
