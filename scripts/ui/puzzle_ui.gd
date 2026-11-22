class_name PuzzleUI
extends CanvasLayer
## Interface dos puzzles: código numérico, ordenação e interruptores. Toda solução tem pistas visíveis em texto.

signal _closed(solved: bool)

var panel: Panel
var msg: Label
var def: Dictionary = {}
var digits: Array[Button] = []
var values: Array[int] = []
var picked: Array[String] = []
var toggles: Array[Button] = []
var order_buttons: Dictionary = {}
var _kind: String = ""
var _done: bool = false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)
		return
	if _kind == "code":
		var f := get_viewport().gui_get_focus_owner()
		var i := digits.find(f)
		if i >= 0:
			if event.is_action_pressed("ui_up"):
				_bump(i, 1)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				_bump(i, -1)
				get_viewport().set_input_as_handled()

func open(puzzle_id: String) -> bool:
	def = NarrativeManager.puzzles_db.get(puzzle_id, {})
	if def.is_empty():
		return false
	if GameManager.test_mode:
		return true
	_build()
	visible = true
	var res: bool = await _closed
	visible = false
	for c in get_children():
		c.queue_free()
	return res

func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	_closed.emit(ok)

func _build() -> void:
	_done = false
	for c in get_children():
		c.queue_free()
	digits.clear()
	values.clear()
	picked.clear()
	toggles.clear()
	order_buttons.clear()
	_kind = str(def.get("type", "code"))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIKit.panel(Vector2(120, 40), Vector2(400, 280))
	add_child(panel)
	var title := UIKit.label(str(def.get("title", "Puzzle")), 13, Color("e6d27a"), false)
	title.position = Vector2(12, 8)
	panel.add_child(title)
	var hint := UIKit.label(str(def.get("prompt", "")), 11, UIKit.TEXT)
	hint.position = Vector2(12, 28)
	hint.size = Vector2(376, 56)
	panel.add_child(hint)
	msg = UIKit.label("", 11, Color("e0705a"), false)
	msg.position = Vector2(12, 250)
	panel.add_child(msg)
	var esc := UIKit.label(LocalizationManager.t("puzzle.cancel"), 9, UIKit.DIM, false)
	esc.position = Vector2(300, 256)
	panel.add_child(esc)
	match _kind:
		"code": _build_code()
		"order": _build_order()
		"toggles": _build_toggles()

func _build_code() -> void:
	var n := int(def.get("digits", 4))
	var row := HBoxContainer.new()
	row.position = Vector2(200 - n * 22, 100)
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	for i in n:
		var b := UIKit.button("0", 20)
		b.custom_minimum_size = Vector2(36, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx := i
		b.pressed.connect(func() -> void: _bump(idx, 1))
		row.add_child(b)
		digits.append(b)
		values.append(0)
	var ok := UIKit.button(LocalizationManager.t("puzzle.confirm"))
	ok.position = Vector2(140, 160)
	ok.custom_minimum_size = Vector2(120, 24)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.pressed.connect(_check_code)
	panel.add_child(ok)
	digits[0].grab_focus()

func _bump(i: int, d: int) -> void:
	values[i] = posmod(values[i] + d, 10)
	digits[i].text = str(values[i])
	AudioManager.play_sfx("ui_move", -10.0)

func _check_code() -> void:
	var s := ""
	for v in values:
		s += str(v)
	if s == str(def.get("solution", "")):
		_success()
	else:
		_fail()

func _build_order() -> void:
	var items: Array = def.get("items", [])
	var box := VBoxContainer.new()
	box.position = Vector2(20, 88)
	box.size = Vector2(360, 100)
	panel.add_child(box)
	var first: Button = null
	for it in items:
		var b := UIKit.button(str(it["label"]))
		var id := str(it["id"])
		b.pressed.connect(func() -> void: _pick(id))
		box.add_child(b)
		order_buttons[id] = b
		if first == null:
			first = b
	var reset := UIKit.button("Refazer")
	reset.position = Vector2(290, 224)
	reset.pressed.connect(_reset_order)
	panel.add_child(reset)
	if first:
		first.grab_focus()

func _pick(id: String) -> void:
	if id in picked:
		return
	picked.append(id)
	var b: Button = order_buttons[id]
	b.text = "%d. %s" % [picked.size(), b.text]
	b.disabled = true
	AudioManager.play_sfx("ui_move", -8.0)
	if picked.size() == (def.get("items", []) as Array).size():
		if picked == (def.get("solution", []) as Array).map(func(x): return str(x)):
			_success()
		else:
			_fail()
			_reset_order()

func _reset_order() -> void:
	picked.clear()
	for it in def.get("items", []):
		var b: Button = order_buttons[str(it["id"])]
		b.text = str(it["label"])
		b.disabled = false
	var f: Button = order_buttons[str((def["items"] as Array)[0]["id"])]
	f.grab_focus()

func _build_toggles() -> void:
	var labels: Array = def.get("labels", [])
	var box := VBoxContainer.new()
	box.position = Vector2(100, 88)
	box.size = Vector2(200, 100)
	panel.add_child(box)
	for i in labels.size():
		var b := UIKit.button("%s: DESLIGADO" % labels[i])
		b.toggle_mode = true
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			b.text = "%s: %s" % [labels[idx], "LIGADO" if on else "DESLIGADO"]
			AudioManager.play_sfx("ui_move", -8.0))
		box.add_child(b)
		toggles.append(b)
	var ok := UIKit.button(LocalizationManager.t("puzzle.confirm"))
	ok.position = Vector2(140, 222)
	ok.custom_minimum_size = Vector2(120, 22)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.pressed.connect(_check_toggles)
	panel.add_child(ok)
	toggles[0].grab_focus()

func _check_toggles() -> void:
	var sol: Array = def.get("solution", [])
	for i in toggles.size():
		if toggles[i].button_pressed != (int(sol[i]) == 1):
			_fail()
			return
	_success()

func _success() -> void:
	msg.text = LocalizationManager.t("puzzle.solved")
	msg.add_theme_color_override("font_color", Color("a8e0a0"))
	AudioManager.play_sfx("confirm")
	await get_tree().create_timer(0.5, true).timeout
	_finish(true)

func _fail() -> void:
	msg.text = LocalizationManager.t("puzzle.wrong")
	AudioManager.play_sfx("error")
	if not SettingsManager.reduce_shake:
		var tw := create_tween()
		tw.tween_property(panel, "position:x", 126.0, 0.04)
		tw.tween_property(panel, "position:x", 114.0, 0.04)
		tw.tween_property(panel, "position:x", 120.0, 0.04)
