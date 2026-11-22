class_name SettingsUI
extends Control
## Painel de configurações (usado no menu principal e na pausa).

signal closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UIKit.panel(Vector2(120, 20), Vector2(400, 320))
	add_child(p)
	var t := UIKit.label(LocalizationManager.t("settings.title"), 13, Color("e6d27a"), false)
	t.position = Vector2(12, 8)
	p.add_child(t)
	var box := VBoxContainer.new()
	box.position = Vector2(12, 30)
	box.size = Vector2(376, 280)
	box.add_theme_constant_override("separation", 3)
	p.add_child(box)
	var first: Control = null
	for row in [["settings.master", "volume_master"], ["settings.music", "volume_music"],
			["settings.sfx", "volume_sfx"], ["settings.ambient", "volume_ambient"]]:
		var h := HBoxContainer.new()
		var l := UIKit.label(LocalizationManager.t(row[0]), 11, UIKit.TEXT, false)
		l.custom_minimum_size = Vector2(150, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = SettingsManager.get(row[1])
		s.custom_minimum_size = Vector2(200, 16)
		s.focus_mode = Control.FOCUS_ALL
		var prop: String = row[1]
		s.value_changed.connect(func(v: float) -> void:
			SettingsManager.set(prop, v)
			SettingsManager.apply())
		h.add_child(s)
		box.add_child(h)
		if first == null:
			first = s
	for row in [["settings.fullscreen", "fullscreen"], ["settings.subtitles", "subtitles"],
			["settings.flashes", "reduce_flashes"], ["settings.shake", "reduce_shake"],
			["settings.distortion", "reduce_distortion"]]:
		var cb := CheckButton.new()
		cb.text = LocalizationManager.t(row[0])
		cb.button_pressed = SettingsManager.get(row[1])
		cb.add_theme_font_size_override("font_size", 11)
		cb.focus_mode = Control.FOCUS_ALL
		var prop2: String = row[1]
		cb.toggled.connect(func(on: bool) -> void:
			SettingsManager.set(prop2, on)
			SettingsManager.apply())
		box.add_child(cb)
	var hs := HBoxContainer.new()
	var sl := UIKit.label(LocalizationManager.t("settings.scale"), 11, UIKit.TEXT, false)
	sl.custom_minimum_size = Vector2(150, 0)
	hs.add_child(sl)
	var ob := OptionButton.new()
	for i in range(1, 5):
		ob.add_item("%dx  (%d×%d)" % [i, 640 * i, 360 * i], i)
	ob.select(SettingsManager.window_scale - 1)
	ob.add_theme_font_size_override("font_size", 11)
	ob.item_selected.connect(func(idx: int) -> void:
		SettingsManager.window_scale = idx + 1
		SettingsManager.apply())
	hs.add_child(ob)
	box.add_child(hs)
	var lang := UIKit.label(LocalizationManager.t("settings.language"), 11, UIKit.DIM, false)
	box.add_child(lang)
	var back := UIKit.button(LocalizationManager.t("menu.back"))
	back.pressed.connect(_close)
	box.add_child(back)
	if first:
		first.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	SettingsManager.save_settings()
	closed.emit()
	queue_free()
