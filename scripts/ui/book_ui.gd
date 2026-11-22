class_name BookUI
extends CanvasLayer
## Inventário (Tab), Diário (J: documentos, memórias, objetivo) e leitor de documentos.

signal closed

var panel: Panel
var list: ItemList
var desc: RichTextLabel
var title: Label
var tab_buttons: Array[Button] = []
var mode: String = "inventory"     # inventory | journal | doc
var tab: int = 0                   # 0 docs, 1 memórias, 2 objetivo
var ids: Array[String] = []
var _open: bool = false

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIKit.panel(Vector2(40, 30), Vector2(560, 300))
	add_child(panel)
	title = UIKit.label("", 13, Color("e6d27a"), false)
	title.position = Vector2(12, 8)
	panel.add_child(title)
	for i in 3:
		var b := UIKit.button(["Documentos", "Memórias", "Objetivo"][i], 11)
		b.position = Vector2(150 + i * 96, 6)
		b.custom_minimum_size = Vector2(92, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx := i
		b.pressed.connect(func() -> void: _set_tab(idx))
		panel.add_child(b)
		tab_buttons.append(b)
	list = ItemList.new()
	list.position = Vector2(12, 34)
	list.size = Vector2(190, 252)
	list.add_theme_font_size_override("font_size", 11)
	list.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.08, 0.1), Color(0.3, 0.29, 0.26), 1))
	list.add_theme_stylebox_override("focus", UIKit.box(Color(0.08, 0.08, 0.1), Color(0.95, 0.85, 0.5), 2))
	list.add_theme_color_override("font_selected_color", Color("fff0b0"))
	list.item_selected.connect(_on_selected)
	panel.add_child(list)
	desc = RichTextLabel.new()
	desc.position = Vector2(212, 34)
	desc.size = Vector2(336, 252)
	desc.add_theme_font_size_override("normal_font_size", 11)
	desc.add_theme_stylebox_override("normal", UIKit.box(Color(0.08, 0.08, 0.1), Color(0.3, 0.29, 0.26), 1))
	desc.bbcode_enabled = false
	panel.add_child(desc)

func is_open() -> bool:
	return _open

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") \
			or (mode == "inventory" and event.is_action_pressed("inventory")) \
			or (mode == "journal" and event.is_action_pressed("journal")):
		get_viewport().set_input_as_handled()
		_close()
	elif mode == "journal":
		if event.is_action_pressed("ui_left"):
			_set_tab(posmod(tab - 1, 3))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_set_tab(posmod(tab + 1, 3))
			get_viewport().set_input_as_handled()

func _close() -> void:
	_open = false
	visible = false
	closed.emit()

func open_inventory() -> void:
	mode = "inventory"
	title.text = LocalizationManager.t("inv.title")
	for b in tab_buttons:
		b.visible = false
	_refresh()
	_show()

func open_journal(start_tab: int = 0) -> void:
	mode = "journal"
	title.text = LocalizationManager.t("journal.title")
	for i in tab_buttons.size():
		tab_buttons[i].visible = true
		tab_buttons[i].position.x = 130 + i * 96
	tab = start_tab
	_refresh()
	_show()

func read_document(doc_id: String) -> void:
	mode = "doc"
	var d: Dictionary = NarrativeManager.docs_db.get(doc_id, {})
	title.text = str(d.get("title", "Documento"))
	for b in tab_buttons:
		b.visible = false
	list.clear()
	ids.clear()
	list.visible = false
	desc.position = Vector2(12, 34)
	desc.size = Vector2(536, 252)
	desc.text = str(d.get("body", ""))
	_show()

func _show() -> void:
	_open = true
	visible = true
	if mode != "doc":
		list.visible = true
		desc.position = Vector2(212, 34)
		desc.size = Vector2(336, 252)
		list.grab_focus()
	AudioManager.play_sfx("ui_move", -8.0)

func _set_tab(i: int) -> void:
	tab = i
	_refresh()

func _refresh() -> void:
	list.clear()
	ids.clear()
	desc.text = ""
	if mode == "inventory":
		for id in InventoryManager.items:
			var info := InventoryManager.item_info(id)
			list.add_item(str(info.get("name", id)))
			ids.append(id)
		if ids.is_empty():
			desc.text = LocalizationManager.t("inv.empty")
	elif mode == "journal":
		match tab:
			0:
				for id in NarrativeManager.docs_found:
					list.add_item(str(NarrativeManager.docs_db[id].get("title", id)))
					ids.append(id)
			1:
				for id in NarrativeManager.memories_found:
					list.add_item(str(NarrativeManager.memories_db[id].get("title", id)))
					ids.append(id)
			2:
				desc.text = NarrativeManager.objective if NarrativeManager.objective != "" else LocalizationManager.t("journal.none")
		if tab != 2 and ids.is_empty():
			desc.text = LocalizationManager.t("journal.none")
	if not ids.is_empty():
		list.select(0)
		_on_selected(0)

func _on_selected(i: int) -> void:
	if i < 0 or i >= ids.size():
		return
	var id := ids[i]
	if mode == "inventory":
		var info := InventoryManager.item_info(id)
		desc.text = "%s\n\n%s" % [info.get("name", id), info.get("desc", "")]
	elif tab == 0:
		desc.text = str(NarrativeManager.docs_db[id].get("body", ""))
	elif tab == 1:
		var m: Dictionary = NarrativeManager.memories_db[id]
		desc.text = "%s\n\n%s" % [m.get("title", id), "\n".join(PackedStringArray(m.get("lines", [])))]
