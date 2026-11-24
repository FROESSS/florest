class_name DialogueUI
extends CanvasLayer
## Caixa de diálogo com texto progressivo e escolhas. Pausa o mundo enquanto aberta.

signal _advance
signal _chosen(index: int)

var panel: Panel
var speaker: Label
var body: Label
var cont: Label
var choice_box: VBoxContainer
var _typing: bool = false
var _skip: bool = false
var _waiting_choice: bool = false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel = UIKit.panel(Vector2(24, 238), Vector2(592, 106))
	add_child(panel)
	speaker = UIKit.label("", 11, Color("e6d27a"), false)
	speaker.position = Vector2(12, 6)
	panel.add_child(speaker)
	body = UIKit.label("", 12)
	body.position = Vector2(12, 22)
	body.size = Vector2(568, 74)
	panel.add_child(body)
	cont = UIKit.label("[E]", 10, UIKit.DIM, false)
	cont.position = Vector2(560, 88)
	panel.add_child(cont)
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(24, 120)
	choice_box.size = Vector2(592, 100)
	choice_box.visible = false
	add_child(choice_box)

func _input(event: InputEvent) -> void:
	if not visible or _waiting_choice:
		return
	if UIKit.accept_pressed(event):
		get_viewport().set_input_as_handled()
		if _typing:
			_skip = true
		else:
			_advance.emit()

func run(lines: Array, who: String = "") -> void:
	if GameManager.test_mode:
		return
	visible = true
	for ln in lines:
		var w := who
		var txt := ""
		if ln is Dictionary:
			w = str(ln.get("who", who))
			txt = str(ln.get("text", ""))
		else:
			txt = str(ln)
		speaker.text = w
		body.text = txt
		body.visible_characters = 0
		cont.visible = false
		_typing = true
		_skip = false
		var total := txt.length()
		var t0 := Time.get_ticks_msec()
		while body.visible_characters < total and not _skip:
			await get_tree().process_frame
			body.visible_characters = mini(total, int((Time.get_ticks_msec() - t0) / 1000.0 * 55.0))
		body.visible_characters = -1
		_typing = false
		cont.text = "[%s]" % SettingsManager.key_name("interact")
		cont.visible = true
		await _advance
	visible = false

func choose(prompt: String, options: Array) -> int:
	if GameManager.test_mode:
		return 0
	visible = true
	speaker.text = ""
	body.text = prompt
	body.visible_characters = -1
	cont.visible = false
	_waiting_choice = true
	for c in choice_box.get_children():
		c.queue_free()
	var first: Button = null
	for i in options.size():
		var o: Dictionary = options[i]
		var b := UIKit.button("%d. %s" % [i + 1, str(o.get("text", ""))])
		b.disabled = bool(o.get("disabled", false))
		var idx := i
		b.pressed.connect(func() -> void: _chosen.emit(idx))
		choice_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	choice_box.visible = true
	if first:
		first.grab_focus()
	var result: int = await _chosen
	_waiting_choice = false
	choice_box.visible = false
	for c in choice_box.get_children():
		c.queue_free()
	visible = false
	AudioManager.play_sfx("confirm", -8.0)
	return result
