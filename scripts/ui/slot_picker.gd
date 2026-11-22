class_name SlotPicker
extends Control
## Lista de slots de salvamento (modo "load" mostra também o autosave).

signal picked(slot: String)
signal closed

var mode: String = "load"

func setup(p_mode: String) -> void:
	mode = p_mode

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UIKit.panel(Vector2(120, 80), Vector2(400, 200))
	add_child(p)
	var t := UIKit.label(LocalizationManager.t("pause.save") if mode == "save" else LocalizationManager.t("menu.load"), 13, Color("e6d27a"), false)
	t.position = Vector2(12, 8)
	p.add_child(t)
	var box := VBoxContainer.new()
	box.position = Vector2(12, 30)
	box.size = Vector2(376, 160)
	p.add_child(box)
	var first: Button = null
	var names := {"auto": "Checkpoint automático", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}
	for s in SaveManager.SLOTS:
		if mode == "save" and s == "auto":
			continue
		var info := SaveManager.slot_info(s)
		var label := "%s — " % names[s]
		if info.exists:
			var secs := int(info.time)
			label += "Cap. %d · %s · %02d:%02d" % [info.chapter, info.room_name, secs / 3600, (secs / 60) % 60]
		else:
			label += LocalizationManager.t("menu.empty_slot")
		var b := UIKit.button(label)
		b.disabled = mode == "load" and not info.exists
		var slot: String = s
		b.pressed.connect(func() -> void: picked.emit(slot))
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := UIKit.button(LocalizationManager.t("menu.back"))
	back.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	box.add_child(back)
	(first if first != null else back).grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
