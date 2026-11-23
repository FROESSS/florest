class_name BookUI
extends CanvasLayer
## Inventário (Tab), Diário (J: documentos, memórias, objetivo) e leitor de documentos.

signal closed
signal use_item(id: String)

var panel: Panel
var list: ScrollContainer
var listbox: VBoxContainer
var desc: RichTextLabel
var inspect_tex: TextureRect
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
	list = ScrollContainer.new()
	list.position = Vector2(12, 34)
	list.size = Vector2(190, 252)
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(list)
	listbox = VBoxContainer.new()
	listbox.custom_minimum_size = Vector2(184, 0)
	listbox.add_theme_constant_override("separation", 2)
	list.add_child(listbox)
	desc = RichTextLabel.new()
	desc.position = Vector2(212, 34)
	desc.size = Vector2(336, 252)
	desc.add_theme_font_size_override("normal_font_size", 11)
	desc.add_theme_stylebox_override("normal", UIKit.box(Color(0.08, 0.08, 0.1), Color(0.3, 0.29, 0.26), 1))
	desc.bbcode_enabled = false
	desc.add_theme_color_override("default_color", UIKit.TEXT)
	panel.add_child(desc)
	inspect_tex = TextureRect.new()
	inspect_tex.position = Vector2(12, 34)
	inspect_tex.size = Vector2(190, 252)
	inspect_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspect_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspect_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inspect_tex.visible = false
	panel.add_child(inspect_tex)

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
	elif (mode == "doc" or mode == "inspect") and event.is_action_pressed("interact"):
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
	inspect_tex.visible = false
	title.text = LocalizationManager.t("inv.title")
	for b in tab_buttons:
		b.visible = false
	_refresh()
	_show()

func open_journal(start_tab: int = 0) -> void:
	mode = "journal"
	inspect_tex.visible = false
	title.text = LocalizationManager.t("journal.title")
	for i in tab_buttons.size():
		tab_buttons[i].visible = true
		tab_buttons[i].position.x = 130 + i * 96
	tab = start_tab
	_refresh()
	_show()

## Inspeção visual: mostra o sprite do objeto bem ampliado com a descrição.
func inspect_object(obj: Interactable, ttl: String, text: String) -> void:
	mode = "inspect"
	title.text = ttl
	for b in tab_buttons:
		b.visible = false
	_clear_list()
	ids.clear()
	list.visible = false
	inspect_tex.visible = true
	if obj.sprite != null and obj.sprite.texture != null:
		var t: Texture2D = obj.sprite.texture
		inspect_tex.texture = t
	else:
		inspect_tex.texture = null
	desc.position = Vector2(212, 34)
	desc.size = Vector2(336, 252)
	desc.text = text
	_open = true
	visible = true
	AudioManager.play_sfx("ui_move", -8.0)

func read_document(doc_id: String) -> void:
	mode = "doc"
	inspect_tex.visible = false
	var d: Dictionary = NarrativeManager.docs_db.get(doc_id, {})
	title.text = str(d.get("title", "Documento"))
	for b in tab_buttons:
		b.visible = false
	_clear_list()
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
		_focus_list()
	AudioManager.play_sfx("ui_move", -8.0)

func _set_tab(i: int) -> void:
	tab = i
	_refresh()

func _clear_list() -> void:
	for c in listbox.get_children():
		listbox.remove_child(c)
		c.queue_free()

func _add_entry(label: String) -> void:
	var idx := ids.size() - 1
	var b := UIKit.button(label, 11)
	b.focus_entered.connect(func() -> void: _on_selected(idx))
	b.pressed.connect(func() -> void:
		_on_selected(idx)
		if mode == "inventory" and idx < ids.size() and InventoryManager.item_info(ids[idx]).has("use"):
			use_item.emit(ids[idx]))
	listbox.add_child(b)

func _focus_list() -> void:
	if listbox.get_child_count() > 0:
		(listbox.get_child(0) as Button).grab_focus()
	elif tab_buttons.size() > 0 and tab_buttons[0].visible:
		tab_buttons[tab].grab_focus()

func _refresh() -> void:
	_clear_list()
	ids.clear()
	desc.text = ""
	if mode == "inventory":
		for id in InventoryManager.items:
			var info := InventoryManager.item_info(id)
			ids.append(id)
			_add_entry(str(info.get("name", id)))
		if ids.is_empty():
			desc.text = LocalizationManager.t("inv.empty")
	elif mode == "journal":
		match tab:
			0:
				for id in NarrativeManager.docs_found:
					ids.append(id)
					_add_entry(str(NarrativeManager.docs_db[id].get("title", id)))
			1:
				for id in NarrativeManager.memories_found:
					ids.append(id)
					_add_entry(str(NarrativeManager.memories_db[id].get("title", id)))
			2:
				desc.text = NarrativeManager.objective if NarrativeManager.objective != "" else LocalizationManager.t("journal.none")
		if tab != 2 and ids.is_empty():
			desc.text = LocalizationManager.t("journal.none")
	if not ids.is_empty():
		_on_selected(0)

func _on_selected(i: int) -> void:
	if i < 0 or i >= ids.size():
		return
	var id := ids[i]
	if mode == "inventory":
		var info := InventoryManager.item_info(id)
		var count_txt := "  (x%d)" % InventoryManager.count(id) if InventoryManager.is_stack(id) else ""
		desc.text = "%s%s\n\n%s%s" % [info.get("name", id), count_txt, info.get("desc", ""), "\n\n[Enter/clique] usar agora" if info.has("use") else ""]
	elif tab == 0:
		desc.text = str(NarrativeManager.docs_db[id].get("body", ""))
	elif tab == 1:
		var m: Dictionary = NarrativeManager.memories_db[id]
		desc.text = "%s\n\n%s" % [m.get("title", id), "\n".join(PackedStringArray(m.get("lines", [])))]
