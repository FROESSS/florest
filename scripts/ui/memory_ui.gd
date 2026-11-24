class_name MemoryUI
extends CanvasLayer
## Memórias (flashbacks dessaturados) e cutscenes narrativas com ilustrações procedurais.

signal _advance

class Canvas extends Control:
	var scene: String = "black"
	var tint: Color = Color.WHITE
	var t: float = 0.0
	var calm: bool = false

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _grad(top: Color, bottom: Color) -> void:
		for i in 36:
			draw_rect(Rect2(0, i * 10, 640, 10), top.lerp(bottom, i / 35.0))

	func _kid(x: float, y: float, s: float, col: Color) -> void:
		draw_circle(Vector2(x, y - 14 * s), 4 * s, col)
		draw_rect(Rect2(x - 4 * s, y - 10 * s, 8 * s, 10 * s), col)
		draw_rect(Rect2(x - 4 * s, y, 3 * s, 6 * s), col)
		draw_rect(Rect2(x + 1 * s, y, 3 * s, 6 * s), col)

	func _adult(x: float, y: float, s: float, col: Color) -> void:
		draw_circle(Vector2(x + 2 * s, y - 40 * s), 5 * s, col)
		draw_rect(Rect2(x - 5 * s, y - 36 * s, 12 * s, 26 * s), col)
		draw_rect(Rect2(x - 7 * s, y - 36 * s, 3 * s, 20 * s), col)
		draw_rect(Rect2(x - 4 * s, y - 10 * s, 3 * s, 14 * s), col)
		draw_rect(Rect2(x + 2 * s, y - 10 * s, 3 * s, 14 * s), col)
		draw_rect(Rect2(x + 8 * s, y - 34 * s, 2 * s, 26 * s), col)

	func _fog() -> void:
		for k in 4:
			var fx := fmod(t * (5.0 + k * 3.0) + k * 170.0, 820.0) - 120.0
			draw_rect(Rect2(fx, 200 + k * 28, 220, 14), Color(0.6, 0.65, 0.6, 0.05))

	func _title_scene(sc: String) -> void:
		match sc:
			"title_1":
				_grad(Color("0b1018"), Color("1d2a2a"))
				draw_circle(Vector2(500, 80), 22, Color("c9cdb8"))
				draw_circle(Vector2(508, 76), 20, Color("0f1620"))
				draw_rect(Rect2(0, 270, 640, 90), Color("0a0d0a"))
				draw_rect(Rect2(170, 170, 240, 110), Color("11160f"))
				draw_colored_polygon(PackedVector2Array([Vector2(160, 172), Vector2(290, 118), Vector2(420, 172)]), Color("0e130d"))
				draw_rect(Rect2(236, 196, 14, 18), Color("e6c36a") if fmod(t, 4.0) > 0.3 else Color("07090a"))
			"title_2":
				_grad(Color("14110d"), Color("0a0907"))
				for i in 7:
					var x := 40.0 + i * 88.0
					draw_rect(Rect2(x, 120, 56, 130), Color("2a1f16"))
					draw_rect(Rect2(x + 4, 124, 48, 122), Color("1c150f"))
					draw_rect(Rect2(x + 10, 248, 36, 3), Color("e6c36a") if i == 3 else Color("0a0907"))
			"title_3":
				_grad(Color("1a060c"), Color("0a0204"))
				for i in 9:
					var y0 := 60.0 + i * 28.0
					var pts := PackedVector2Array()
					for k in 33:
						pts.append(Vector2(k * 20.0, y0 + sin(k * 0.5 + t * 1.5 + i) * 10.0))
					draw_polyline(pts, Color(0.5, 0.12, 0.22, 0.7), 3.0)
					draw_polyline(pts, Color(0.8, 0.4, 0.5, 0.35), 1.0)
			"title_4":
				_grad(Color("0c1012"), Color("050708"))
				for r in 4:
					for c in 8:
						draw_rect(Rect2(40 + c * 72, 70 + r * 52, 56, 38), Color("1a2226"))
						var on := int(t * 1.2 + r * 3 + c) % 5 == 0
						draw_rect(Rect2(46 + c * 72, 76 + r * 52, 6, 6), Color("e04040") if on else Color("401818"))
			"title_5":
				_grad(Color("200808"), Color("050202"))
				for i in 14:
					var ang := i * TAU / 14.0
					var pts2 := PackedVector2Array([Vector2(320, 180)])
					var pp := Vector2(320, 180)
					for k in 6:
						pp += Vector2(cos(ang + sin(k + i) * 0.4), sin(ang + sin(k + i) * 0.4)) * (24 + k * 6)
						pts2.append(pp)
					draw_polyline(pts2, Color(0.9, 0.25, 0.15, 0.6), 2.0)
				draw_circle(Vector2(320, 180), 20 + (0.0 if calm else 4.0 * sin(t * 4.0)), Color(0.9, 0.2, 0.1, 0.25))
			_:
				_grad(Color("050605"), Color("0e120d"))
		_fog()

	func _draw() -> void:
		var dark := Color(0.02, 0.02, 0.03)
		match scene:
			"lullaby":
				_grad(Color("0f1420"), Color("1b2233"))
				draw_rect(Rect2(420, 60, 90, 110), Color("0a0d14"))
				draw_rect(Rect2(426, 66, 78, 98), Color("24324e"))
				draw_circle(Vector2(480, 90), 12, Color("c9cdb8"))
				draw_rect(Rect2(0, 250, 640, 110), Color("1a1814"))
				draw_rect(Rect2(120, 220, 160, 50), Color("3a4a66"))
				_kid(220, 232, 1.4, Color("d8c8b0"))
				_adult(330, 290, 3.0, dark)
			"photo":
				_grad(Color("2a2318"), Color("171309"))
				draw_rect(Rect2(110, 50, 420, 240), Color("d8cfb0"))
				draw_rect(Rect2(122, 62, 396, 216), Color("7a705a"))
				for i in 12:
					_kid(150 + (i % 6) * 52, 150 + (i / 6) * 70, 1.5, Color(0.12, 0.1, 0.08, 0.9))
				_adult(480, 260, 2.2, Color(0.08, 0.07, 0.06))
				draw_rect(Rect2(448, 205, 26, 50), Color("7a705a"))
			"classroom":
				_grad(Color("1c2a24"), Color("0e1512"))
				draw_rect(Rect2(150, 40, 340, 90), Color("203428"))
				draw_rect(Rect2(170, 60, 160, 3), Color("c9d0c0"))
				draw_rect(Rect2(170, 80, 110, 3), Color("c9d0c0"))
				for r in 3:
					for c in 4:
						draw_rect(Rect2(110 + c * 110, 190 + r * 50, 56, 18), Color("3a2c1e"))
						if (r + c) % 3 != 1:
							_kid(138 + c * 110, 185 + r * 50, 1.0, dark)
			"hospital":
				_grad(Color("c8d0d0"), Color("5a6464"))
				draw_rect(Rect2(150, 190, 340, 60), Color("e6ecec"))
				draw_rect(Rect2(190, 160, 260, 34), Color("b8c0c0"))
				_adult(540, 300, 2.5, Color(0.1, 0.12, 0.12))
				draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.35))
			"toys":
				_grad(Color("3a3226"), Color("231d15"))
				draw_circle(Vector2(180, 240), 24, Color("9a6a3e"))
				draw_rect(Rect2(240, 224, 60, 28), Color("4a6fa5"))
				draw_rect(Rect2(330, 200, 24, 50), Color("d8c0a8"))
				draw_circle(Vector2(420, 236), 18, Color("a04848"))
			"lab":
				_grad(Color("201414"), Color("0a0505"))
				draw_rect(Rect2(270, 60, 100, 220), Color("3a5a58"))
				draw_rect(Rect2(280, 70, 80, 200), Color("5f8f88"))
				_kid(320, 250, 2.6, Color(0.1, 0.16, 0.15))
				draw_rect(Rect2(0, 0, 640, 360), Color(0.5, 0.05, 0.05, 0.12 + (0.0 if calm else 0.08 * sin(t * 6.0))))
			"chair":
				_grad(Color("14181c"), Color("0a0c0e"))
				draw_rect(Rect2(280, 180, 60, 80), Color("5a5048"))
				_kid(310, 240, 2.4, dark)
				draw_rect(Rect2(420, 110, 90, 70), Color("1a3a2a"))
				draw_rect(Rect2(430, 120, 70, 3), Color("8affc0"))
			"mirror":
				_grad(Color("1c1c20"), Color("0c0c0e"))
				draw_rect(Rect2(150, 40, 340, 250), Color("5a4a3a"))
				draw_rect(Rect2(160, 50, 320, 230), Color("6c8088"))
				_kid(260, 260, 3.0, dark)
				_adult(380, 270, 3.4, Color(0.05, 0.06, 0.07))
			"crib":
				_grad(Color("181a24"), Color("0c0d14"))
				draw_rect(Rect2(220, 170, 200, 100), Color("5a5a5a"))
				for x in range(228, 412, 16):
					draw_rect(Rect2(x, 150, 4, 120), Color("a8a8a0"))
				_adult(520, 300, 2.8, dark)
			"car":
				_grad(Color("05070c"), Color("12161e"))
				draw_rect(Rect2(0, 250, 640, 110), Color("0c0d10"))
				draw_rect(Rect2(380, 210, 150, 50), Color("1a1c22"))
				draw_rect(Rect2(410, 190, 80, 30), Color("14161a"))
				draw_rect(Rect2(520, 226, 12, 8), Color("f2e6a8"))
				draw_colored_polygon(PackedVector2Array([Vector2(530, 228), Vector2(640, 190), Vector2(640, 280)]), Color(0.95, 0.9, 0.65, 0.18))
				_kid(150, 300, 1.8, Color("d8c8b0"))
			"fire":
				_grad(Color("120804"), Color("3a1406"))
				draw_rect(Rect2(160, 80, 320, 220), Color("0a0705"))
				for i in 14:
					var fx := 160 + i * 24
					var fh := 40 + 30 * (0.5 + 0.5 * sin(t * (1.5 if calm else 7.0) + i))
					draw_rect(Rect2(fx, 300 - fh, 20, fh), Color("e06a1a") if i % 2 == 0 else Color("f2b030"))
			"voices":
				_grad(Color("0a0c14"), Color("04050a"))
				draw_rect(Rect2(220, 80, 200, 70), Color("1a2a22"))
				for i in 9:
					var a := t * 0.4 + i * 0.7
					_kid(320 + cos(a) * 200, 250 + sin(a) * 24, 1.4, Color(0.55, 0.62, 0.8, 0.6))
			"dawn":
				_grad(Color("2a2a3a"), Color("c0a070"))
				draw_circle(Vector2(320, 230), 40, Color("f0d090"))
				draw_rect(Rect2(0, 250, 640, 110), Color("1a1c14"))
				_kid(320, 300, 2.0, Color("0a0a0a"))
			"title", "title_1", "title_2", "title_3", "title_4", "title_5":
				_title_scene(scene)
			_:
				draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
		# grão e vinheta
		if not calm:
			for i in 60:
				var gx := fmod(float(PixelArt.hash2(i, int(t * 10.0))), 640.0)
				var gy := fmod(float(PixelArt.hash2(i * 3, int(t * 10.0))), 360.0)
				draw_rect(Rect2(gx, gy, 1, 1), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(0, 0, 640, 24), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(0, 336, 640, 24), Color(0, 0, 0, 0.5))

var canvas: Canvas
var text_label: Label
var title_label: Label
var sub_label: Label
var bg: ColorRect
var _skip: bool = false
var _active: bool = false

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Canvas.new()
	canvas.size = Vector2(640, 360)
	add_child(canvas)
	title_label = UIKit.label("", 18, Color("e6d27a"), false)
	title_label.position = Vector2(0, 150)
	title_label.size = Vector2(640, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	sub_label = UIKit.label("", 11, Color("b8b4a0"))
	sub_label.position = Vector2(60, 186)
	sub_label.size = Vector2(520, 20)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_label)
	text_label = UIKit.label("", 13, Color("f0ead8"))
	text_label.position = Vector2(60, 286)
	text_label.size = Vector2(520, 44)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	text_label.add_theme_constant_override("outline_size", 5)
	add_child(text_label)

func _input(event: InputEvent) -> void:
	if _active and UIKit.accept_pressed(event):
		get_viewport().set_input_as_handled()
		_advance.emit()

func play_memory(id: String) -> void:
	var m: Dictionary = NarrativeManager.memories_db.get(id, {})
	if m.is_empty() or GameManager.test_mode:
		return
	AudioManager.play_sfx("memory", -4.0)
	AudioManager.play_sfx("music_box", -10.0)
	await _play(m.get("lines", []), str(m.get("scene", "black")), Color(0.86, 0.8, 0.7), str(m.get("title", "")), 0.5)

func play_cutscene(id: String) -> void:
	var c: Dictionary = NarrativeManager.cutscenes_db.get(id, {})
	if c.is_empty() or GameManager.test_mode:
		return
	if str(c.get("sound", "")) != "":
		AudioManager.play_sfx(str(c["sound"]), -4.0)
	await _play(c.get("lines", []), str(c.get("scene", "black")), Color.WHITE, str(c.get("title", "")), 1.0, str(c.get("subtitle", "")))

func _play(lines: Array, scene: String, tint: Color, title: String, fade: float, subtitle: String = "") -> void:
	_active = true
	visible = true
	canvas.scene = scene
	canvas.modulate = tint
	canvas.calm = SettingsManager.reduce_distortion
	canvas.modulate.a = 0.0
	text_label.text = ""
	title_label.text = ""
	var tw := create_tween()
	tw.tween_property(canvas, "modulate:a", 1.0, fade)
	sub_label.text = ""
	if title != "":
		title_label.text = title
		title_label.modulate.a = 0.0
		sub_label.text = subtitle
		sub_label.modulate.a = 0.0
		create_tween().tween_property(sub_label, "modulate:a", 1.0, 1.4)
		var tw2 := create_tween()
		tw2.tween_property(title_label, "modulate:a", 1.0, 0.8)
		await get_tree().create_timer(2.4, true).timeout
		var tw3 := create_tween()
		tw3.tween_property(title_label, "modulate:a", 0.0, 0.5)
		create_tween().tween_property(sub_label, "modulate:a", 0.0, 0.5)
	for i in lines.size():
		text_label.text = str(lines[i])
		text_label.modulate.a = 0.0
		var t4 := create_tween()
		t4.tween_property(text_label, "modulate:a", 1.0, 0.5)
		if i == 1 and scene != "title":
			AudioManager.play_sfx("whisper", -10.0)
		await _wait_or_advance(3.8)
	text_label.text = ""
	var t5 := create_tween()
	t5.tween_property(canvas, "modulate:a", 0.0, fade)
	await t5.finished
	visible = false
	_active = false

func _wait_or_advance(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds, true)
	var done := [false]
	timer.timeout.connect(func() -> void:
		if not done[0]:
			done[0] = true
			_advance.emit())
	await _advance
	done[0] = true
