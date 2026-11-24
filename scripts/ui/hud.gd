class_name HUD
extends CanvasLayer
## HUD minimalista: interação contextual, bateria, avisos, legendas e indicador de perseguição.

var prompt_label: Label
var battery_box: Control
var battery_fill: ColorRect
var battery_text: Label
var toast_label: Label
var sub_label: Label
var chase_label: Label
var hidden_label: Label
var hint_label: Label
var objective_label: Label
var stamina_fill: ColorRect
var stamina_text: Label
var wound_label: Label
var vignette: TextureRect
var _toast_t: float = 0.0
var _sub_t: float = 0.0
var _obj_t: float = 0.0
var _hint_t: float = 0.0
var _toast_queue: Array[String] = []

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	vignette = TextureRect.new()
	vignette.texture = PixelArt.vignette()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	prompt_label = _mk(Vector2(120, 318), Vector2(400, 16), 12, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label = _mk(Vector2(120, 22), Vector2(400, 16), 12, HORIZONTAL_ALIGNMENT_CENTER)
	sub_label = _mk(Vector2(60, 292), Vector2(520, 24), 11, HORIZONTAL_ALIGNMENT_CENTER)
	sub_label.add_theme_color_override("font_color", Color("d8d4c0"))
	chase_label = _mk(Vector2(220, 6), Vector2(200, 16), 12, HORIZONTAL_ALIGNMENT_CENTER)
	chase_label.text = "! " + LocalizationManager.t("hud.chase") + " !"
	chase_label.add_theme_color_override("font_color", Color("ff7070"))
	chase_label.visible = false
	hidden_label = _mk(Vector2(120, 300), Vector2(400, 16), 11, HORIZONTAL_ALIGNMENT_CENTER)
	hidden_label.text = LocalizationManager.t("hud.hiding")
	hidden_label.visible = false
	objective_label = _mk(Vector2(340, 6), Vector2(296, 30), 10, HORIZONTAL_ALIGNMENT_RIGHT)
	hint_label = _mk(Vector2(70, 40), Vector2(500, 40), 10, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	battery_box = Control.new()
	battery_box.position = Vector2(8, 6)
	add_child(battery_box)
	var frame := ColorRect.new()
	frame.color = Color(0.8, 0.78, 0.7)
	frame.size = Vector2(38, 10)
	battery_box.add_child(frame)
	var inner := ColorRect.new()
	inner.color = Color(0.05, 0.05, 0.06)
	inner.position = Vector2(1, 1)
	inner.size = Vector2(36, 8)
	battery_box.add_child(inner)
	battery_fill = ColorRect.new()
	battery_fill.color = Color("e6d27a")
	battery_fill.position = Vector2(2, 2)
	battery_fill.size = Vector2(34, 6)
	battery_box.add_child(battery_fill)
	battery_text = _mk(Vector2(50, 4), Vector2(100, 14), 10, HORIZONTAL_ALIGNMENT_LEFT)
	remove_child(battery_text)
	battery_box.add_child(battery_text)
	battery_text.position = Vector2(42, -2)
	var sbox := Control.new()
	sbox.position = Vector2(8, 20)
	add_child(sbox)
	var sfr := ColorRect.new()
	sfr.color = Color(0.8, 0.78, 0.7)
	sfr.size = Vector2(38, 7)
	sbox.add_child(sfr)
	var sin_ := ColorRect.new()
	sin_.color = Color(0.05, 0.05, 0.06)
	sin_.position = Vector2(1, 1)
	sin_.size = Vector2(36, 5)
	sbox.add_child(sin_)
	stamina_fill = ColorRect.new()
	stamina_fill.color = Color("8fc0e0")
	stamina_fill.position = Vector2(2, 2)
	stamina_fill.size = Vector2(34, 3)
	sbox.add_child(stamina_fill)
	stamina_text = _mk(Vector2(50, 18), Vector2(120, 12), 9, HORIZONTAL_ALIGNMENT_LEFT)
	wound_label = _mk(Vector2(8, 32), Vector2(160, 12), 9, HORIZONTAL_ALIGNMENT_LEFT)
	GameManager.battery_changed.connect(func(_v: float) -> void: _update_battery())
	GameManager.flashlight_changed.connect(func(_o: bool) -> void: _update_battery())
	GameManager.chase_changed.connect(func(a: bool) -> void: chase_label.visible = a)
	GameManager.toast.connect(show_toast)
	AudioManager.subtitle.connect(show_subtitle)
	NarrativeManager.objective_changed.connect(func(t: String) -> void:
		if t != "":
			show_toast(LocalizationManager.t("hud.objective")))
	_update_battery()

func _mk(pos: Vector2, size: Vector2, fs: int, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align as HorizontalAlignment
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", UIKit.TEXT)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _update_battery() -> void:
	battery_box.visible = GameManager.has_flashlight()
	battery_fill.size.x = 34.0 * GameManager.battery / GameManager.BATTERY_MAX
	var low := GameManager.battery < 20.0
	battery_fill.color = Color("e0705a") if low else Color("e6d27a")
	var state := "ON" if GameManager.flashlight_on else "OFF"
	battery_text.text = "%d%% %s%s" % [int(GameManager.battery), state, " !" if low else ""]

func set_prompt(text: String) -> void:
	prompt_label.text = ("[%s] " % SettingsManager.key_name("interact") + text) if text != "" else ""

func set_hidden(h: bool) -> void:
	hidden_label.visible = h

func show_toast(text: String) -> void:
	_toast_queue.append(text)
	if _toast_t <= 0.0:
		_next_toast()

func _next_toast() -> void:
	if _toast_queue.is_empty():
		toast_label.text = ""
		return
	toast_label.text = _toast_queue.pop_front()
	_toast_t = 2.4

func show_subtitle(text: String, duration: float) -> void:
	if not SettingsManager.subtitles:
		return
	sub_label.text = text
	_sub_t = duration

func show_hint(text: String, duration: float = 6.0) -> void:
	hint_label.text = text
	_hint_t = duration

func show_objective() -> void:
	objective_label.text = NarrativeManager.objective
	_obj_t = 5.0

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_next_toast()
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			sub_label.text = ""
	if _obj_t > 0.0:
		_obj_t -= delta
		if _obj_t <= 0.0:
			objective_label.text = ""
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hint_label.text = ""
	var pl = GameManager.player
	if pl != null and is_instance_valid(pl):
		stamina_fill.size.x = 34.0 * pl.stamina / Player.STAMINA_MAX
		stamina_fill.color = Color("e0a060") if pl.exhausted else Color("8fc0e0")
		stamina_text.text = LocalizationManager.t("hud.exhausted") if pl.exhausted else (LocalizationManager.t("hud.stamina") if pl.stamina < 99.0 else "")
		var kits := InventoryManager.count("kit_pequeno") + InventoryManager.count("kit_grande")
		wound_label.text = ("+ %s: %s%s" % [LocalizationManager.t("hud.wound"), pl.wound_name(), ("  [%s] kits: %d" % [SettingsManager.key_name("heal"), kits]) if kits > 0 else ""]) if pl.wound > 0 else ("[%s] kits: %d" % [SettingsManager.key_name("heal"), kits] if kits > 0 else "")
	var chased := GameManager.is_chased()
	vignette.modulate = Color(1, 0.5, 0.5, 1.0) if chased and not SettingsManager.reduce_flashes else Color.WHITE
