class_name PauseUI
extends CanvasLayer
## Menu de pausa: continuar, salvar, carregar, configurações, menu principal.

signal closed

var panel: Panel
var box: VBoxContainer
var msg: Label
var _open: bool = false
var _sub: Control = null

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIKit.panel(Vector2(220, 70), Vector2(200, 220))
	add_child(panel)
	var t := UIKit.label(LocalizationManager.t("pause.title"), 13, Color("e6d27a"), false)
	t.position = Vector2(12, 8)
	panel.add_child(t)
	box = VBoxContainer.new()
	box.position = Vector2(12, 30)
	box.size = Vector2(176, 160)
	panel.add_child(box)
	var entries := [
		["pause.resume", _close], ["pause.save", _on_save], ["pause.load", _on_load],
		["pause.settings", _on_settings], ["pause.menu", _on_menu],
	]
	for e in entries:
		var b := UIKit.button(LocalizationManager.t(e[0]))
		b.pressed.connect(e[1])
		box.add_child(b)
	msg = UIKit.label("", 10, Color("e0705a"))
	msg.position = Vector2(12, 190)
	msg.size = Vector2(176, 26)
	panel.add_child(msg)

func is_open() -> bool:
	return _open

func open() -> void:
	_open = true
	visible = true
	msg.text = ""
	(box.get_child(0) as Button).grab_focus()

func _close() -> void:
	_open = false
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if _open and _sub == null and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close()

func _on_save() -> void:
	if GameManager.is_chased():
		msg.text = LocalizationManager.t("pause.cant_save")
		AudioManager.play_sfx("error")
		return
	var sp := SlotPicker.new()
	sp.setup("save")
	_sub = sp
	add_child(sp)
	sp.picked.connect(func(slot: String) -> void:
		var ok := SaveManager.save_to(slot)
		msg.text = LocalizationManager.t("pause.saved") if ok else "Falha ao salvar."
		sp.queue_free()
		_sub = null
		(box.get_child(1) as Button).grab_focus())
	sp.closed.connect(func() -> void:
		_sub = null
		(box.get_child(1) as Button).grab_focus())

func _on_load() -> void:
	var sp := SlotPicker.new()
	sp.setup("load")
	_sub = sp
	add_child(sp)
	sp.picked.connect(func(slot: String) -> void:
		sp.queue_free()
		_sub = null
		_open = false
		visible = false
		SceneManager.continue_game(slot))
	sp.closed.connect(func() -> void:
		_sub = null
		(box.get_child(2) as Button).grab_focus())

func _on_settings() -> void:
	var s := SettingsUI.new()
	_sub = s
	add_child(s)
	s.closed.connect(func() -> void:
		_sub = null
		(box.get_child(3) as Button).grab_focus())

func _on_menu() -> void:
	_open = false
	visible = false
	SceneManager.goto_menu()
