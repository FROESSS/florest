extends Node
## Transições de tela com fade.

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const GAME_SCENE := "res://scenes/main/Game.tscn"

var _layer: CanvasLayer
var _rect: ColorRect
var busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_layer.add_child(_rect)

func fade_out(t: float = 0.35) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if t <= 0.0 or GameManager.test_mode:
		_rect.modulate.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, t)
	await tw.finished

func fade_in(t: float = 0.35) -> void:
	if t <= 0.0 or GameManager.test_mode:
		_rect.modulate.a = 0.0
	else:
		var tw := create_tween()
		tw.tween_property(_rect, "modulate:a", 0.0, t)
		await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String, fade: bool = true) -> void:
	if busy:
		return
	busy = true
	if fade:
		await fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if fade:
		await fade_in()
	busy = false

func goto_menu(first: bool = false) -> void:
	GameManager.world = null
	GameManager.player = null
	AudioManager.set_ambient("")
	AudioManager.stop_music()
	await change_scene(MENU_SCENE, not first)

func start_new_game() -> void:
	GameManager.new_game()
	await change_scene(GAME_SCENE)

func continue_game(slot: String = "") -> bool:
	if slot == "":
		slot = SaveManager.latest_slot()
	if slot == "" or not SaveManager.load_slot(slot):
		return false
	await change_scene(GAME_SCENE)
	return true
