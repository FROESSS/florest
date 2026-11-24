extends Node
## Etapa 7: remapeamento de teclas (InputMap), conflitos, restauração, persistência e UI.
var t

func _press(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k as Key
	ev.pressed = down
	Input.parse_input_event(ev)

func _has_key(action: String, k: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == k:
			return true
	return false

func run() -> void:
	SettingsManager.reset_bindings(true)
	_test_defaults()
	await _test_rebind_and_inputmap()
	_test_conflicts()
	_test_reserved_and_alternates()
	_test_persistence()
	await _test_ui()
	await _test_gameplay_with_remap()
	SettingsManager.reset_bindings(true)
	SettingsManager.save_settings()

func _test_defaults() -> void:
	var used := {}
	var dup := false
	for a in SettingsManager.ACTION_ORDER:
		t.check(InputMap.has_action(a), "ação '%s' registrada no InputMap" % a)
		t.check(SettingsManager.bindings[a][0] != KEY_NONE, "ação '%s' tem tecla principal" % a)
		for k in SettingsManager.bindings[a]:
			if k != KEY_NONE:
				if used.has(k):
					dup = true
				used[k] = true
	t.check(not dup, "controles padrão sem conflitos")
	t.check(_has_key("interact", KEY_E) and _has_key("move_left", KEY_A) and _has_key("move_left", KEY_LEFT), "padrão: E interage, A/← esquerda")
	t.check(_has_key("heal", KEY_H) and _has_key("run", KEY_SHIFT) and _has_key("flashlight", KEY_F), "padrão: H kit, Shift corre, F lanterna")

func _test_rebind_and_inputmap() -> void:
	var r := SettingsManager.rebind("interact", 0, KEY_Q)
	t.check(r["ok"], "interagir → Q")
	t.check(_has_key("interact", KEY_Q) and not _has_key("interact", KEY_E), "InputMap atualizado (Q sim, E não)")
	_press(KEY_Q, true)
	await get_tree().process_frame
	await get_tree().process_frame
	t.check(Input.is_action_pressed("interact"), "Q passa a acionar 'interagir'")
	_press(KEY_Q, false)
	await get_tree().process_frame
	_press(KEY_E, true)
	await get_tree().process_frame
	await get_tree().process_frame
	t.check(not Input.is_action_pressed("interact"), "E não aciona mais 'interagir'")
	_press(KEY_E, false)
	await get_tree().process_frame
	t.check(SettingsManager.key_name("interact") == "Q", "nome da tecla exibido: %s" % SettingsManager.key_name("interact"))
	for pair in [["move_up", KEY_I], ["move_down", KEY_K], ["run", KEY_Z], ["flashlight", KEY_G], ["inventory", KEY_B], ["journal", KEY_N], ["heal", KEY_V]]:
		t.check(SettingsManager.rebind(pair[0], 0, pair[1])["ok"], "%s → %s" % [pair[0], pair[1]])
		t.check(_has_key(pair[0], pair[1]), "InputMap tem a nova tecla de %s" % pair[0])
	SettingsManager.reset_bindings(true)

func _test_conflicts() -> void:
	SettingsManager.rebind("interact", 0, KEY_Q)
	var r := SettingsManager.rebind("flashlight", 0, KEY_Q)
	t.check(not r["ok"] and r["conflict"] == "interact", "conflito detectado: Q já está em 'interact'")
	t.check(SettingsManager.bindings["flashlight"][0] == KEY_F and SettingsManager.bindings["interact"][0] == KEY_Q, "conflito sem 'trocar' não altera nada")
	t.check(SettingsManager.find_conflict(KEY_Q, "flashlight") == "interact", "find_conflict informa a ação")
	var s := SettingsManager.rebind("flashlight", 0, KEY_Q, true)
	t.check(s["ok"] and SettingsManager.bindings["flashlight"][0] == KEY_Q and SettingsManager.bindings["interact"][0] == KEY_F, "trocar: as duas ações permutam as teclas")
	t.check(_has_key("flashlight", KEY_Q) and _has_key("interact", KEY_F) and not _has_key("flashlight", KEY_F), "InputMap reflete a troca")
	# nunca deixa uma ação sem tecla
	SettingsManager.reset_bindings(true)
	var bad := SettingsManager.rebind("heal", 1, KEY_J, true)   # J é a única tecla de 'journal'; heal[1] está vazio
	t.check(not bad["ok"], "troca que deixaria outra ação sem tecla é recusada")
	for a in SettingsManager.ACTION_ORDER:
		t.check(SettingsManager.bindings[a][0] != KEY_NONE, "'%s' mantém tecla principal" % a)
	SettingsManager.reset_bindings(true)

func _test_reserved_and_alternates() -> void:
	t.check(not SettingsManager.rebind("interact", 0, KEY_ESCAPE)["ok"], "Esc é reservada (não pode ir para outras ações)")
	t.check(SettingsManager.rebind("interact", 1, KEY_SPACE)["ok"] and _has_key("interact", KEY_SPACE) and _has_key("interact", KEY_E), "segunda tecla (alternativa) para interagir")
	t.check(not SettingsManager.rebind("interact", 0, KEY_SPACE)["ok"], "mesma tecla nos dois espaços da mesma ação é recusada")
	SettingsManager.clear_alternate("interact")
	t.check(not _has_key("interact", KEY_SPACE), "limpar alternativa")
	t.check(SettingsManager.rebind("pause", 0, KEY_ESCAPE)["ok"], "pausa pode manter Esc")
	SettingsManager.reset_bindings(true)

func _test_persistence() -> void:
	SettingsManager.rebind("interact", 0, KEY_Q)
	SettingsManager.rebind("move_right", 0, KEY_L)
	SettingsManager.rebind("heal", 1, KEY_R)
	SettingsManager.save_settings()
	SettingsManager.reset_bindings(true)
	t.check(SettingsManager.bindings["interact"][0] == KEY_E, "estado em memória foi restaurado ao padrão")
	SettingsManager.load_settings()   # equivale a fechar e abrir o jogo
	t.check(SettingsManager.bindings["interact"][0] == KEY_Q and SettingsManager.bindings["move_right"][0] == KEY_L and SettingsManager.bindings["heal"][1] == KEY_R, "controles persistem após recarregar")
	t.check(_has_key("interact", KEY_Q) and not _has_key("interact", KEY_E) and _has_key("move_right", KEY_L), "InputMap reconstruído ao carregar")
	# configuração corrompida/inconsistente volta ao padrão
	var cfg := ConfigFile.new()
	cfg.load(SettingsManager.SETTINGS_PATH)
	cfg.set_value("controls", "run", [KEY_Q, KEY_NONE])   # Q já usado por 'interact'
	cfg.save(SettingsManager.SETTINGS_PATH)
	SettingsManager.load_settings()
	t.check(SettingsManager.bindings["run"][0] == KEY_SHIFT and SettingsManager.bindings["interact"][0] == KEY_E, "configuração com tecla duplicada → padrão seguro")
	cfg.set_value("controls", "run", "lixo")
	cfg.save(SettingsManager.SETTINGS_PATH)
	SettingsManager.load_settings()
	t.check(SettingsManager.bindings["run"][0] == KEY_SHIFT, "configuração com tipo inválido → padrão seguro")
	SettingsManager.reset_bindings(true)
	SettingsManager.save_settings()

func _test_ui() -> void:
	var ui := ControlsUI.new()
	add_child(ui)
	await get_tree().process_frame
	t.check(ui.rows.size() == SettingsManager.ACTION_ORDER.size(), "UI lista todas as ações (%d)" % ui.rows.size())
	t.check((ui.rows["interact"][0] as Button).text == "E", "UI mostra a tecla atual")
	ui.begin_listen("run", 0)
	ui.on_key(KEY_Z)
	t.check(SettingsManager.bindings["run"][0] == KEY_Z and (ui.rows["run"][0] as Button).text == "Z", "UI: remapear correr → Z")
	ui.begin_listen("flashlight", 0)
	ui.on_key(KEY_Z)
	t.check(not ui.pending.is_empty() and ui.swap_btn.visible and ui.msg.text.contains("já está"), "UI: informa que a tecla já está atribuída")
	t.check(SettingsManager.bindings["flashlight"][0] == KEY_F, "UI: nada muda enquanto o conflito não é resolvido")
	ui._cancel_pending()
	t.check(SettingsManager.bindings["flashlight"][0] == KEY_F and ui.pending.is_empty(), "UI: cancelar mantém as teclas")
	ui.begin_listen("flashlight", 0)
	ui.on_key(KEY_Z)
	ui._confirm_swap()
	t.check(SettingsManager.bindings["flashlight"][0] == KEY_Z and SettingsManager.bindings["run"][0] == KEY_F, "UI: trocar permuta as teclas")
	ui.begin_listen("interact", 0)
	ui.on_key(KEY_ESCAPE)
	t.check(SettingsManager.bindings["interact"][0] == KEY_E and ui.listening_action == "", "UI: Esc cancela a escuta")
	t.check(SettingsManager.controls_hint().contains("Z") and SettingsManager.controls_hint().contains("F"), "dica de controles reflete as teclas")
	ui.reset_defaults()
	t.check(SettingsManager.bindings["run"][0] == KEY_SHIFT and (ui.rows["run"][0] as Button).text.length() > 0, "UI: restaurar padrões")
	t.check(SettingsManager.bindings["flashlight"][0] == KEY_F, "padrões restaurados (lanterna = F)")
	ui.queue_free()
	await get_tree().process_frame

func _test_gameplay_with_remap() -> void:
	GameManager.new_game()
	GameManager.test_mode = true
	SettingsManager.rebind("move_right", 0, KEY_L)
	SettingsManager.rebind("move_right", 1, KEY_NONE) if false else null
	var a := await TestHelpers.make_arena(self, "c1_corredor", Vector2i(2, 8))
	var p: Player = a["player"]
	var x0 := p.position.x
	_press(KEY_D, true)
	await get_tree().create_timer(0.3).timeout
	_press(KEY_D, false)
	t.check(absf(p.position.x - x0) < 1.0, "tecla antiga (D) não move mais")
	_press(KEY_L, true)
	await get_tree().create_timer(0.3).timeout
	_press(KEY_L, false)
	t.check(p.position.x - x0 > 5.0, "nova tecla (L) move para a direita")
	a["room"].queue_free()
	p.queue_free()
	await get_tree().process_frame
	SettingsManager.reset_bindings(true)
