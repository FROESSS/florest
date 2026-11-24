class_name ControlsUI
extends Control
## Remapeamento de teclas: duas teclas por ação, detecção de conflito, troca, restaurar padrões.

signal closed

var rows: Dictionary = {}              # ação -> [Button, Button]
var msg: Label
var listening_action: String = ""
var listening_slot: int = -1
var pending: Dictionary = {}           # conflito aguardando decisão
var swap_btn: Button
var cancel_btn: Button
var back_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UIKit.panel(Vector2(60, 10), Vector2(520, 340))
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.05, 0.07, 1.0)))
	add_child(p)
	var t := UIKit.label("CONTROLES", 13, Color("e6d27a"), false)
	t.position = Vector2(12, 6)
	p.add_child(t)
	var hdr := UIKit.label("Ação                         Principal      Alternativa", 10, UIKit.DIM, false)
	hdr.position = Vector2(12, 24)
	p.add_child(hdr)
	var box := VBoxContainer.new()
	box.position = Vector2(12, 40)
	box.size = Vector2(496, 240)
	box.add_theme_constant_override("separation", 1)
	p.add_child(box)
	for a in SettingsManager.ACTION_ORDER:
		var h := HBoxContainer.new()
		var l := UIKit.label(SettingsManager.ACTION_LABELS[a], 11, UIKit.TEXT, false)
		l.custom_minimum_size = Vector2(230, 0)
		h.add_child(l)
		var btns: Array = []
		for slot in 2:
			var b := UIKit.button("", 11)
			_compact(b)
			b.custom_minimum_size = Vector2(110, 18)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			var act: String = a
			var sl: int = slot
			b.pressed.connect(func() -> void: begin_listen(act, sl))
			h.add_child(b)
			btns.append(b)
		box.add_child(h)
		rows[a] = btns
	msg = UIKit.label("Selecione uma tecla e pressione a nova. Esc cancela.", 10, UIKit.DIM)
	msg.position = Vector2(12, 286)
	msg.size = Vector2(496, 26)
	p.add_child(msg)
	var foot := HBoxContainer.new()
	foot.position = Vector2(12, 312)
	p.add_child(foot)
	swap_btn = UIKit.button("Trocar teclas", 11)
	swap_btn.visible = false
	swap_btn.pressed.connect(_confirm_swap)
	foot.add_child(swap_btn)
	cancel_btn = UIKit.button("Cancelar", 11)
	cancel_btn.visible = false
	cancel_btn.pressed.connect(_cancel_pending)
	foot.add_child(cancel_btn)
	var reset := UIKit.button("Restaurar padrões", 11)
	reset.pressed.connect(reset_defaults)
	foot.add_child(reset)
	back_btn = UIKit.button(LocalizationManager.t("menu.back"), 11)
	back_btn.pressed.connect(_close)
	foot.add_child(back_btn)
	refresh()
	(rows["move_up"][0] as Button).grab_focus()

## Botão compacto (margens menores) para caber a lista inteira de ações.
func _compact(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := b.get_theme_stylebox(st).duplicate() as StyleBoxFlat
		sb.set_content_margin_all(1)
		b.add_theme_stylebox_override(st, sb)

func refresh() -> void:
	for a in rows:
		for slot in 2:
			(rows[a][slot] as Button).text = SettingsManager.key_name(a, slot)

func begin_listen(action: String, slot: int) -> void:
	listening_action = action
	listening_slot = slot
	pending = {}
	swap_btn.visible = false
	cancel_btn.visible = false
	(rows[action][slot] as Button).text = "..."
	msg.text = "Pressione a nova tecla para '%s' (Esc cancela)." % SettingsManager.ACTION_LABELS[action]

func _input(event: InputEvent) -> void:
	if listening_action == "":
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if pending.is_empty():
				_close()
			else:
				_cancel_pending()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		on_key(k)

## Processa uma tecla durante a escuta (exposto para testes).
func on_key(k: int) -> void:
	if listening_action == "":
		return
	if k == KEY_ESCAPE and listening_action != "pause":
		listening_action = ""
		refresh()
		msg.text = "Alteração cancelada."
		return
	var r := SettingsManager.rebind(listening_action, listening_slot, k, false)
	if r["ok"]:
		msg.text = "'%s' agora usa %s." % [SettingsManager.ACTION_LABELS[listening_action], SettingsManager._keycode_text(k)]
		listening_action = ""
		SettingsManager.save_settings()
		refresh()
		AudioManager.play_sfx("confirm", -8.0)
	elif r["reason"] == "conflito":
		pending = {"action": listening_action, "slot": listening_slot, "key": k, "other": r["conflict"]}
		msg.text = "A tecla %s já está em '%s'. Trocar as teclas das duas ações ou cancelar?" % [SettingsManager._keycode_text(k), SettingsManager.ACTION_LABELS[r["conflict"]]]
		swap_btn.visible = true
		cancel_btn.visible = true
		listening_action = ""
		swap_btn.grab_focus()
		AudioManager.play_sfx("error", -8.0)
	elif r["reason"] == "reservada":
		msg.text = "A tecla Esc é reservada para pausa/voltar."
		listening_action = ""
		refresh()
	else:
		msg.text = "Não foi possível usar essa tecla (%s)." % r["reason"]
		listening_action = ""
		refresh()

func _confirm_swap() -> void:
	if pending.is_empty():
		return
	var r := SettingsManager.rebind(pending["action"], pending["slot"], pending["key"], true)
	msg.text = "Teclas trocadas." if r["ok"] else "Troca impossível: %s." % r["reason"]
	pending = {}
	swap_btn.visible = false
	cancel_btn.visible = false
	SettingsManager.save_settings()
	refresh()

func _cancel_pending() -> void:
	pending = {}
	swap_btn.visible = false
	cancel_btn.visible = false
	msg.text = "Alteração cancelada."
	refresh()

func reset_defaults() -> void:
	SettingsManager.reset_bindings(true)
	SettingsManager.save_settings()
	listening_action = ""
	pending = {}
	swap_btn.visible = false
	cancel_btn.visible = false
	msg.text = "Controles padrão restaurados."
	refresh()

func _close() -> void:
	SettingsManager.save_settings()
	closed.emit()
	queue_free()
