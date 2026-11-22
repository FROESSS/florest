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

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E],
	"run": [KEY_SHIFT],
	"flashlight": [KEY_F],
	"inventory": [KEY_TAB],
	"journal": [KEY_J],
	"pause": [KEY_ESCAPE],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_ensure_buses()
	load_settings()
	apply()

func _register_inputs() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# W/S também navegam nos menus
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev2)

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
	volume_master = clampf(volume_master, 0.0, 1.0)
	volume_music = clampf(volume_music, 0.0, 1.0)
	volume_sfx = clampf(volume_sfx, 0.0, 1.0)
	volume_ambient = clampf(volume_ambient, 0.0, 1.0)
	window_scale = clampi(window_scale, 1, 4)
	walk_speed = clampf(walk_speed, 30.0, 140.0)
	run_speed = clampf(run_speed, 60.0, 220.0)
