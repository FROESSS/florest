extends Node
## IA da Cuidadora (todos os estados) e do Morador (aviso, spawn justo, luz, bloqueio/atração).
var t

func _caretaker(arena: Dictionary, tile: Vector2i, patrol: Array) -> Caretaker:
	var c := Caretaker.new()
	arena["room"].y_layer.add_child(c)
	c.setup(arena["room"], arena["player"], {"tile": [tile.x, tile.y], "patrol": patrol})
	return c

func run() -> void:
	Engine.time_scale = 4.0
	await _test_patrol_noise_search_return()
	await _test_vision_chase_capture()
	await _test_hiding_rules()
	await _test_resident()
	Engine.time_scale = 1.0

func _test_patrol_noise_search_return() -> void:
	var a := await TestHelpers.make_arena(self, "c1_corredor", Vector2i(37, 8))
	var room: Room = a["room"]
	var c := _caretaker(a, Vector2i(10, 6), [[4, 6], [11, 6]])
	var p0 := c.position
	await get_tree().create_timer(2.0).timeout
	t.check(c.state == Caretaker.S.PATROL and c.position.distance_to(p0) > 10.0, "Cuidadora patrulha (se move)")
	var seen := {}
	c.state_changed.connect(func(n: String) -> void: seen[n] = true)
	# ruído distante do jogador, perto dela: investiga
	GameManager.emit_noise(c.position + Vector2(40, 0), 150.0, "object")
	t.check(c.state == Caretaker.S.SUSPICIOUS, "ruído → SUSPICIOUS")
	await get_tree().create_timer(1.5).timeout
	t.check(seen.has("INVESTIGATE"), "SUSPICIOUS → INVESTIGATE")
	await get_tree().create_timer(15.0).timeout
	t.check(seen.has("SEARCH"), "INVESTIGATE → SEARCH")
	t.check(seen.has("RETURN") or c.state == Caretaker.S.PATROL, "SEARCH → RETURN")
	await get_tree().create_timer(12.0).timeout
	t.check(c.state == Caretaker.S.PATROL, "volta a PATROL (estado=%s)" % c.state_name())
	# ruído fora do alcance é ignorado
	var before := c.state
	GameManager.emit_noise(c.position + Vector2(400, 0), 55.0, "step")
	t.check(c.state == before, "ruído fora do raio é ignorado")
	# passo de caminhada atrás da parede não alcança; correr alcança perto
	c.queue_free()
	room.queue_free()
	a["player"].queue_free()
	await get_tree().process_frame

func _test_vision_chase_capture() -> void:
	var a := await TestHelpers.make_arena(self, "c1_corredor", Vector2i(3, 6))
	var room: Room = a["room"]
	var player: Player = a["player"]
	var c := _caretaker(a, Vector2i(7, 6), [[7, 6]])
	c.facing = Vector2.LEFT
	t.check(c.can_see_player(), "vê Elias à frente, dentro do alcance e com linha de visão")
	c.facing = Vector2.RIGHT
	t.check(not c.can_see_player(), "não vê Elias fora do cone de visão")
	c.facing = Vector2.LEFT
	player.position = room.nav.center_of(Vector2i(16, 6))
	t.check(not c.can_see_player(), "não vê Elias fora do alcance")
	# parede bloqueia a visão: bloco A em x=13
	c.position = room.nav.center_of(Vector2i(11, 6))
	player.position = room.nav.center_of(Vector2i(15, 6))
	c.facing = Vector2.RIGHT
	t.check(not c.can_see_player(), "parede bloqueia linha de visão")
	# conscientização gradual → perseguição
	c.position = room.nav.center_of(Vector2i(7, 6))
	player.position = room.nav.center_of(Vector2i(3, 6))
	c.facing = Vector2.LEFT
	var seen := {}
	c.state_changed.connect(func(n: String) -> void: seen[n] = true)
	var captured := [false]
	GameManager.player_captured.connect(func(_by: String) -> void: captured[0] = true)
	await get_tree().create_timer(0.25).timeout
	t.check(c.state == Caretaker.S.SUSPICIOUS or c.state == Caretaker.S.CHASE, "avistar Elias → desconfia (não captura instantaneamente)")
	await get_tree().create_timer(2.5).timeout
	t.check(seen.has("CHASE"), "awareness completa → CHASE")
	t.check(GameManager.is_chased(), "GameManager registra perseguição")
	await get_tree().create_timer(4.0).timeout
	t.check(captured[0] or c.state == Caretaker.S.ATTACK, "perseguição alcança parado → captura")
	# fuga justa: jogador corre e perde o alvo
	c.queue_free()
	player.captured = false
	GameManager.chasers.clear()
	var c2 := _caretaker(a, Vector2i(5, 6), [[5, 6]])
	c2.last_known = player.position
	c2._enter(Caretaker.S.CHASE)
	player.position = room.nav.center_of(Vector2i(30, 6))
	await get_tree().create_timer(8.0).timeout
	t.check(c2.state != Caretaker.S.CHASE and c2.state != Caretaker.S.ATTACK, "perde o alvo de forma justa quando Elias foge (estado=%s)" % c2.state_name())
	t.check(not GameManager.is_chased(), "perseguição encerra")
	c2.queue_free()
	room.queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_hiding_rules() -> void:
	var a := await TestHelpers.make_arena(self, "c1_corredor", Vector2i(10, 4))
	var room: Room = a["room"]
	var player: Player = a["player"]
	var w1 := room.find_object("w1")
	# 1) Ela NÃO viu entrar: esconder-se com ela longe e sem perseguição → nunca captura
	var c := _caretaker(a, Vector2i(30, 7), [[30, 7], [32, 7]])
	player.enter_hide(w1)
	await get_tree().create_timer(3.0).timeout
	t.check(not c.can_see_player(), "escondido: não é visto")
	GameManager.emit_noise(w1.center(), 150.0, "step")
	await get_tree().create_timer(14.0).timeout
	t.check(c.state != Caretaker.S.CHASE and c.state != Caretaker.S.ATTACK, "escondido sem ser visto → não é capturado (estado=%s)" % c.state_name())
	player.exit_hide()
	c.queue_free()
	# 2) Em perseguição e fora de vista ao esconder → ela perde o alvo (SEARCH)
	player.position = room.nav.center_of(Vector2i(10, 4))
	var c2 := _caretaker(a, Vector2i(30, 7), [[30, 7]])
	c2.last_known = player.position
	c2._enter(Caretaker.S.CHASE)
	player.enter_hide(w1)
	await get_tree().create_timer(0.3).timeout
	t.check(c2.state == Caretaker.S.SEARCH, "perseguição + esconder sem ser visto → SEARCH (estado=%s)" % c2.state_name())
	player.exit_hide()
	c2.queue_free()
	# 3) Ela VIU entrar: abre o esconderijo e captura
	var wp := room.nav.center_of(Vector2i(10, 4))
	player.position = wp
	var c3 := _caretaker(a, Vector2i(14, 3), [[14, 3]])
	c3.facing = Vector2.LEFT
	c3.last_known = player.position
	c3._enter(Caretaker.S.CHASE)
	var captured := [false]
	GameManager.player_captured.connect(func(_by: String) -> void: captured[0] = true)
	player.enter_hide(w1)
	await get_tree().create_timer(5.0).timeout
	t.check(c3.saw_hide, "ela viu Elias entrar (saw_hide)")
	t.check(captured[0], "viu entrar → abre o esconderijo e captura")
	c3.queue_free()
	room.queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_resident() -> void:
	GameManager.chasers.clear()
	var a := await TestHelpers.make_arena(self, "c3_tunel", Vector2i(3, 6))
	var room: Room = a["room"]
	var player: Player = a["player"]
	var r := Resident.new()
	room.y_layer.add_child(r)
	r.setup(room, player, {"zone": [10, 2, 22, 9], "vents": [[14, 3], [20, 9], [28, 4]], "delay": [3, 4]})
	t.check(r.state == Resident.S.DORMANT and not r.visible, "Morador dormente e invisível fora da zona")
	await get_tree().create_timer(2.0).timeout
	t.check(r.state == Resident.S.DORMANT, "não ataca fora da zona contaminada")
	player.position = room.nav.center_of(Vector2i(14, 8))
	var order: Array[String] = []
	r.state_changed.connect(func(n: String) -> void: order.append(n))
	var spawn_ok := [true]
	r.state_changed.connect(func(n: String) -> void:
		if n == "EMERGE" and r.position.distance_to(player.position) < Resident.MIN_SPAWN_DIST:
			spawn_ok[0] = false)
	var t_warn := [0.0]
	var t_emerge := [0.0]
	r.state_changed.connect(func(n: String) -> void:
		if n == "WARNING":
			t_warn[0] = Time.get_ticks_msec()
		elif n == "EMERGE":
			t_emerge[0] = Time.get_ticks_msec())
	await get_tree().create_timer(10.0).timeout
	t.check(order.has("WARNING") and order.find("WARNING") < order.find("EMERGE"), "aviso (WARNING) sempre precede o surgimento: %s" % str(order))
	t.check(spawn_ok[0], "nunca surge a menos de 130 px de Elias")
	t.check(Resident.WARNING_TIME >= 3.0, "aviso dura pelo menos 3 s")
	t.check(r.speed < SettingsManager.walk_speed, "Morador é mais lento que a caminhada")
	t.check(order.has("STALK"), "Morador persegue após emergir")
	# luz reduz a velocidade
	player.position = room.nav.center_of(Vector2i(22, 6))
	r.position = player.position + Vector2(60, 0)
	player.facing = Vector2.RIGHT
	InventoryManager.add_item("lanterna")
	GameManager.set_battery(100.0)
	GameManager.set_flashlight(true)
	t.check(r.is_lit(), "Morador detecta que está sob a lanterna")
	GameManager.set_flashlight(false)
	t.check(not r.is_lit(), "sem lanterna não está iluminado")
	InventoryManager.reset()
	r.queue_free()
	# modo bloqueio + atração por ruído
	GameManager.chasers.clear()
	NarrativeManager.reset()
	room.queue_free()
	player.queue_free()
	await get_tree().process_frame
	var b := await TestHelpers.make_arena(self, "c3_refeitorio", Vector2i(5, 8))
	var room2: Room = b["room"]
	var blocker := Resident.new()
	room2.y_layer.add_child(blocker)
	blocker.setup(room2, b["player"], {"mode": "blocker", "tile": [18, 4], "done_flag": "resident_lured_1"})
	t.check(blocker.state == Resident.S.BLOCK and blocker.block_body != null and blocker.block_body.collision_layer == 1, "bloqueador sólido no corredor")
	GameManager.emit_noise(room2.nav.center_of(Vector2i(6, 11)), 100.0, "step")
	t.check(blocker.state == Resident.S.BLOCK, "ruído comum não o atrai")
	GameManager.emit_noise(room2.nav.center_of(Vector2i(6, 11)), 220.0, "lure")
	t.check(blocker.state == Resident.S.LURED and blocker.block_body.collision_layer == 0, "ruído planejado (lure) o atrai e libera o caminho")
	await get_tree().create_timer(12.0).timeout
	t.check(NarrativeManager.has_flag("resident_lured_1") and blocker.state == Resident.S.GONE, "bloqueador some e registra flag")
	room2.queue_free()
	b["player"].queue_free()
	NarrativeManager.reset()
	await get_tree().process_frame
