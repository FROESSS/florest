extends Control
## Menu principal: Novo jogo, Continuar, Carregar, Configurações, Créditos, Sair.

class Backdrop extends Control:
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		for i in 36:
			draw_rect(Rect2(0, i * 10, 640, 10), Color("0b1018").lerp(Color("1d2a2a"), i / 35.0))
		draw_circle(Vector2(500, 70), 22, Color("c9cdb8"))
		draw_circle(Vector2(508, 66), 20, Color("0f1620"))   # lua minguante
		for i in 40:
			draw_rect(Rect2(PixelArt.hash2(i, 1) % 640, PixelArt.hash2(i, 2) % 150, 1, 1), Color(1, 1, 1, 0.5 + 0.3 * sin(t * 2.0 + i)))
		draw_rect(Rect2(0, 270, 640, 90), Color("0a0d0a"))
		draw_rect(Rect2(150, 170, 220, 110), Color("11160f"))
		draw_colored_polygon(PackedVector2Array([Vector2(140, 172), Vector2(260, 120), Vector2(380, 172)]), Color("0e130d"))
		draw_rect(Rect2(330, 130, 20, 40), Color("11160f"))
		for w in [[170, 190], [210, 190], [300, 190], [340, 190], [170, 230], [300, 230]]:
			draw_rect(Rect2(w[0], w[1], 18, 22), Color("07090a"))
		draw_rect(Rect2(212, 192, 14, 18), Color("e6c36a") if fmod(t, 5.0) > 0.4 else Color("07090a"))
		draw_rect(Rect2(246, 236, 28, 44), Color("050605"))
		for k in 3:
			var fx := fmod(t * (6 + k * 3) + k * 200, 760.0) - 60
			draw_rect(Rect2(fx, 255 + k * 8, 140, 10), Color(0.6, 0.65, 0.6, 0.06))

var box: VBoxContainer
var sub: Control = null
var btn_continue: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bd := Backdrop.new()
	bd.size = Vector2(640, 360)
	add_child(bd)
	var title := UIKit.label(LocalizationManager.t("menu.title"), 20, Color("e6d27a"), false)
	title.position = Vector2(0, 28)
	title.size = Vector2(640, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)
	var sub_t := UIKit.label("survival horror · Godot 4.4.1", 10, UIKit.DIM, false)
	sub_t.position = Vector2(0, 58)
	sub_t.size = Vector2(640, 14)
	sub_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_t)
	box = VBoxContainer.new()
	box.position = Vector2(440, 118)
	box.size = Vector2(170, 180)
	add_child(box)
	_add("menu.new_game", _on_new)
	btn_continue = _add("menu.continue", _on_continue)
	btn_continue.disabled = not SaveManager.has_any()
	_add("menu.load", _on_load)
	_add("menu.settings", _on_settings)
	_add("menu.credits", _on_credits)
	_add("menu.quit", func() -> void: get_tree().quit())
	var hint := UIKit.label(SettingsManager.controls_hint(), 9, UIKit.DIM, false)
	hint.position = Vector2(0, 342)
	hint.size = Vector2(640, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	AudioManager.set_ambient("amb_house")
	_focus_first()

func _add(key: String, cb: Callable) -> Button:
	var b := UIKit.button(LocalizationManager.t(key), 13)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

func _focus_first() -> void:
	for c in box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			return

func _on_new() -> void:
	AudioManager.play_sfx("confirm")
	SceneManager.start_new_game()

func _on_continue() -> void:
	AudioManager.play_sfx("confirm")
	SceneManager.continue_game()

func _on_load() -> void:
	var sp := SlotPicker.new()
	sp.setup("load")
	sub = sp
	add_child(sp)
	sp.picked.connect(func(slot: String) -> void:
		sp.queue_free()
		SceneManager.continue_game(slot))
	sp.tree_exited.connect(func() -> void:
		sub = null
		_focus_first())

func _on_settings() -> void:
	var s := SettingsUI.new()
	sub = s
	add_child(s)
	s.tree_exited.connect(func() -> void:
		sub = null
		_focus_first())

func _on_credits() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var l := UIKit.label(LocalizationManager.t("credits.text"), 12)
	l.position = Vector2(120, 60)
	l.size = Vector2(400, 240)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	var back := UIKit.button(LocalizationManager.t("menu.back"))
	back.position = Vector2(260, 310)
	back.custom_minimum_size = Vector2(120, 22)
	back.pressed.connect(func() -> void: c.queue_free())
	c.add_child(back)
	add_child(c)
	sub = c
	c.tree_exited.connect(func() -> void:
		sub = null
		_focus_first())
	back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if sub != null and sub is Control and not (sub is SettingsUI) and not (sub is SlotPicker):
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			sub.queue_free()
