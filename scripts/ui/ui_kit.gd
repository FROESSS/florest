class_name UIKit
extends RefCounted
## Estilo compartilhado da interface (painéis escuros, foco visível por borda + marcador, não só por cor).

const BG := Color(0.05, 0.05, 0.07, 0.95)
const BORDER := Color(0.5, 0.46, 0.36)
const TEXT := Color(0.9, 0.88, 0.8)
const DIM := Color(0.6, 0.58, 0.52)

static func box(bg: Color = BG, border: Color = BORDER, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(6)
	return sb

static func panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", box())
	return p

static func label(text: String, font_size: int = 12, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func style_button(b: Button, font_size: int = 12) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", box(Color(0.09, 0.09, 0.11), Color(0.28, 0.27, 0.24), 1))
	b.add_theme_stylebox_override("hover", box(Color(0.14, 0.13, 0.12), BORDER, 2))
	b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.18, 0.14), BORDER, 2))
	b.add_theme_stylebox_override("disabled", box(Color(0.07, 0.07, 0.08), Color(0.2, 0.2, 0.2), 1))
	b.add_theme_stylebox_override("focus", box(Color(0.16, 0.14, 0.1), Color(0.95, 0.85, 0.5), 2))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.42))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL

static func button(text: String, font_size: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, font_size)
	b.focus_entered.connect(func() -> void: AudioManager.play_sfx("ui_move", -14.0))
	return b

static func accept_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		return true
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
