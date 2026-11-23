extends Node
## Etapa 4: buracos do Morador (criação segura, persistência, acúmulo, retorno justo, luz, limites).
var t

func _arena(room_id: String, tile: Vector2i) -> Dictionary:
	GameManager.new_game()
	GameManager.test_mode = true
	return await TestHelpers.make_arena(self, room_id, tile)

func _cleanup(a: Dictionary) -> void:
	a["room"].queue_free()
	a["player"].queue_free()
	GameManager.chasers.clear()
	await get_tree().process_frame

func _resident(a: Dictionary, delay: Array = [2.0, 3.0]) -> Resident:
	var r := Resident.new()
	a["room"].y_layer.add_child(r)
	r.setup(a["room"], a["player"], {"zone": [10, 2, 22, 9], "vents": [[14, 3], [20, 9], [28, 4]], "delay": delay})
	return r

func run() -> void:
	await _test_hole_rules()
	await _test_connectivity_property()
	await _test_persistence()
	await _test_cycle_and_accumulation()
	await _test_fair_return()
	await _test_light_weakens()

func _test_hole_rules() -> void:
	var a := await _arena("c3_tunel", Vector2i(3, 6))
	var room: Room = a["room"]
	t.check(room.can_add_hole(Vector2i(22, 3)), "buraco válido é aceito")
	t.check(room.add_hole(Vector2i(22, 3)) and room.holes.size() == 1, "buraco criado")
	t.check(room.nav.is_solid_cell(Vector2i(22, 3)), "buraco bloqueia a célula na navegação")
	t.check(not room.add_hole(Vector2i(22, 3)), "não duplica na mesma posição")
	t.check(not room.can_add_hole(Vector2i(23, 3)), "respeita espaçamento mínimo entre buracos")
	t.check(not room.can_add_hole(Vector2i(3, 6)), "não cria sobre o spawn")
	t.check(not room.can_add_hole(Vector2i(14, 3)), "não cria sobre abertura planejada")
	t.check(not room.can_add_hole(Vector2i(0, 0)) and not room.can_add_hole(Vector2i(5, 1)), "não cria na parede/fora da sala")
	t.check(GameManager.world_state["holes"]["c3_tunel"].size() == 1, "buraco registrado no estado do mundo")
	# limite técnico por sala
	var n := 1
	for y in range(3, 11, 2):
		for x in range(2, 33, 2):
			if room.add_hole(Vector2i(x, y)):
				n += 1
	t.check(room.holes.size() <= Room.MAX_HOLES, "limite por sala respeitado (%d ≤ %d)" % [room.holes.size(), Room.MAX_HOLES])
	t.check(room.holes.size() == Room.MAX_HOLES, "chega ao limite (%d)" % room.holes.size())
	var seen := {}
	var dup := false
	for h in GameManager.world_state["holes"]["c3_tunel"]:
		var k := str(h["tile"])
		if seen.has(k):
			dup = true
		seen[k] = true
	t.check(not dup, "estado do mundo sem buracos duplicados")
	await _cleanup(a)
	var b := await _arena("c3_refeitorio", Vector2i(2, 8))
	t.check(not b["room"].can_add_hole(Vector2i(18, 4)), "não cria buraco no corredor de 1 tile (cortaria a rota)")
	await _cleanup(b)

func _test_connectivity_property() -> void:
	for rid in ["c3_tunel", "c3_memoria", "c4_arquivos", "c5_colapso", "c1_corredor"]:
		GameManager.new_game()
		GameManager.test_mode = true
		var room := Room.new()
		add_child(room)
		room.build(rid)
		var first: Vector2 = room.spawn_position(room.spec["spawns"].keys()[0])
		var bad := 0
		var tested := 0
		for y in range(2, room.size_tiles.y - 1):
			for x in range(1, room.size_tiles.x - 1):
				var c := Vector2i(x, y)
				if not room.can_add_hole(c):
					continue
				tested += 1
				if tested > 25:
					continue
				room.nav.set_cell(c, true, false)
				room.nav.rebuild()
				for sname in room.spec["spawns"]:
					if not room.nav.reachable(first, room.spawn_position(sname)):
						bad += 1
				for o in room.objects:
					if o.spec.has("effects") or o.spec.has("door"):
						var ok := false
						for dy in range(-2, 3):
							for dx in range(-2, 3):
								var cc: Vector2i = room.nav.cell_of(o.rect.get_center()) + Vector2i(dx, dy)
								if not room.nav.is_solid_cell(cc) and room.nav.reachable(first, room.nav.center_of(cc)):
									ok = true
						if not ok:
							bad += 1
				room.refresh_dynamic()
		t.check(tested > 0 and bad == 0, "%s: buracos permitidos nunca isolam spawns/objetos (%d testados)" % [rid, tested])
		room.queue_free()
		await get_tree().process_frame
	GameManager.new_game()

func _test_persistence() -> void:
	var a := await _arena("c3_tunel", Vector2i(3, 6))
	var room: Room = a["room"]
	room.add_hole(Vector2i(22, 3))
	room.add_hole(Vector2i(26, 8))
	await _cleanup(a)
	# recarrega a sala: buracos continuam
	var room2 := Room.new()
	add_child(room2)
	room2.build("c3_tunel")
	t.check(room2.holes.size() == 2 and room2.nav.is_solid_cell(Vector2i(22, 3)) and room2.nav.is_solid_cell(Vector2i(26, 8)), "buracos persistem ao sair e voltar à sala")
	var rp := Recovery.danger_points(room2)
	var near := false
	for p in rp:
		if p.distance_to(room2.nav.center_of(Vector2i(22, 3))) < 2.0:
			near = true
	t.check(near, "ponto de retorno após morte evita os buracos")
	room2.queue_free()
	await get_tree().process_frame
	# save/load
	GameManager.current_room = "c3_tunel"
	GameManager.chapter = 3
	t.check(SaveManager.save_to("slot1"), "salva com buracos")
	GameManager.new_game()
	t.check(GameManager.world_state.get("holes", {}).is_empty(), "novo jogo zera os buracos")
	t.check(SaveManager.load_slot("slot1"), "carrega")
	var room3 := Room.new()
	add_child(room3)
	room3.build("c3_tunel")
	t.check(room3.holes.size() == 2, "buracos restaurados após carregar o save (%d)" % room3.holes.size())
	room3.queue_free()
	SaveManager.delete_slot("slot1")
	await get_tree().process_frame
	GameManager.new_game()

func _test_cycle_and_accumulation() -> void:
	Engine.time_scale = 4.0
	var a := await _arena("c3_tunel", Vector2i(14, 8))
	var room: Room = a["room"]
	var p: Player = a["player"]
	var r := _resident(a, [10.0, 10.0])
	t.check(is_equal_approx(r._delay(), 10.0), "sem buracos o intervalo é o base")
	room.add_hole(Vector2i(22, 3))
	room.add_hole(Vector2i(26, 8))
	room.add_hole(Vector2i(8, 3))
	t.check(is_equal_approx(r._delay(), 10.0 * (1.0 - 0.07 * 3)), "mais buracos encurtam o intervalo de retorno")
	t.check(r.all_vents().size() == 3 + 3, "buracos viram novas aberturas de emergência (%d)" % r.all_vents().size())
	room.queue_free()
	r.queue_free()
	await _cleanup(a)
	# ciclo completo: fuga → cavar → buraco novo → volta só após o intervalo
	var b := await _arena("c3_tunel", Vector2i(14, 8))
	var room2: Room = b["room"]
	var pl: Player = b["player"]
	var r2 := _resident(b, [2.0, 3.0])
	var order: Array[String] = []
	r2.state_changed.connect(func(n: String) -> void: order.append(n))
	var dug := [0]
	r2.retreated.connect(func(_reason: String, made: bool) -> void:
		if made:
			dug[0] += 1)
	var t_sink := [0]
	var t_warn := [0]
	r2.retreated.connect(func(_r: String, _m: bool) -> void: t_sink[0] = Engine.get_physics_frames())
	r2.state_changed.connect(func(n: String) -> void:
		if n == "WARNING" and t_sink[0] != 0 and t_warn[0] == 0:
			t_warn[0] = Engine.get_physics_frames())
	var guard := 0
	while not order.has("STALK") and guard < 400:
		pl.position = room2.nav.center_of(Vector2i(14, 8))
		await get_tree().create_timer(0.25).timeout
		guard += 1
	t.check(order.has("WARNING") and order.has("EMERGE") and order.has("STALK"), "ciclo: aviso → surge → persegue")
	r2.begin_retreat("tempo")          # 1ª fuga (sem cavar se houver abertura por perto)
	guard = 0
	while r2.state != Resident.S.DORMANT and guard < 200:
		await get_tree().create_timer(0.25).timeout
		guard += 1
	t.check(r2.retreats == 1, "fuga contabilizada (retreats=1)")
	t.check(GameManager.world_state["resident"]["c3_tunel"]["retreats"] == 1, "contagem de fugas fica no estado do mundo")
	# 2ª fuga: deve cavar
	r2.position = room2.nav.center_of(Vector2i(18, 5))
	r2._enter(Resident.S.STALK)
	var holes_before := room2.holes.size()
	r2.begin_retreat("luz")
	t.check(r2.state == Resident.S.DIGGING, "2ª fuga: o Morador cava uma abertura")
	guard = 0
	while r2.state == Resident.S.DIGGING and guard < 100:
		await get_tree().create_timer(0.25).timeout
		guard += 1
	t.check(room2.holes.size() == holes_before + 1 and dug[0] == 1, "novo buraco permanece no cenário (%d → %d)" % [holes_before, room2.holes.size()])
	t.check(r2.state == Resident.S.DORMANT and not r2.visible, "desaparece pelo buraco")
	# retorno justo: só depois do intervalo mínimo
	pl.position = room2.nav.center_of(Vector2i(14, 8))
	var f0 := Engine.get_physics_frames()
	guard = 0
	while r2.state == Resident.S.DORMANT and guard < 400:
		pl.position = room2.nav.center_of(Vector2i(14, 8))
		await get_tree().create_timer(0.25).timeout
		guard += 1
	var waited := float(Engine.get_physics_frames() - f0) / 60.0 * Engine.time_scale
	t.check(r2.state == Resident.S.WARNING and waited >= Resident.MIN_COOLDOWN - 1.0, "retorna só após o intervalo mínimo (%.1f s) e sempre com aviso" % waited)
	# acúmulo: muitas fugas respeitam limite e unicidade
	for i in 30:
		r2.position = room2.nav.center_of(Vector2i(randi_range(3, 30), randi_range(3, 9)))
		r2._enter(Resident.S.STALK)
		r2.begin_retreat("tempo")
		r2._enter(Resident.S.DORMANT)
	t.check(room2.holes.size() <= Room.MAX_HOLES, "30 fugas não passam do limite (%d)" % room2.holes.size())
	var tiles := {}
	var dup := false
	for h in room2.holes:
		if tiles.has(h["tile"]):
			dup = true
		tiles[h["tile"]] = true
	t.check(not dup, "sem buracos duplicados após muitas fugas")
	var first: Vector2 = room2.spawn_position("inicio")
	var all_ok := true
	for s in room2.spec["spawns"]:
		all_ok = all_ok and room2.nav.reachable(first, room2.spawn_position(s))
	for o in room2.objects:
		if o.spec.has("effects") or o.spec.has("door"):
			var ok := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var cc: Vector2i = room2.nav.cell_of(o.rect.get_center()) + Vector2i(dx, dy)
					if not room2.nav.is_solid_cell(cc) and room2.nav.reachable(first, room2.nav.center_of(cc)):
						ok = true
			all_ok = all_ok and ok
	t.check(all_ok, "mesmo com buracos acumulados, tudo continua alcançável (sem soft-lock)")
	r2.queue_free()
	await _cleanup(b)
	Engine.time_scale = 1.0

func _test_fair_return() -> void:
	var a := await _arena("c3_tunel", Vector2i(14, 5))
	var room: Room = a["room"]
	var p: Player = a["player"]
	var r := _resident(a)
	room.add_hole(Vector2i(16, 8))
	room.add_hole(Vector2i(12, 8))
	var worst := INF
	for i in 60:
		var v := r._pick_vent()
		if v.x >= 0.0:
			worst = minf(worst, v.distance_to(p.position))
	t.check(worst >= Resident.MIN_SPAWN_DIST, "retorno nunca em abertura a < 130 px de Elias (mín. %.0f)" % worst)
	# jogador no meio das aberturas: nenhuma justa → não surge
	p.position = room.nav.center_of(Vector2i(20, 6))
	var all_near := true
	for v in r.all_vents():
		if v.distance_to(p.position) >= Resident.MIN_SPAWN_DIST:
			all_near = false
	if all_near:
		t.check(r._pick_vent().x < 0.0, "sem abertura justa, não há retorno")
	else:
		t.check(r._pick_vent().distance_to(p.position) >= Resident.MIN_SPAWN_DIST, "escolhe só aberturas justas")
	# sinal de atividade: a abertura escolhida é anunciada antes de surgir
	p.position = room.nav.center_of(Vector2i(12, 5))
	r.dormant_timer = r.threshold - 5.0
	await get_tree().create_timer(0.3).timeout
	t.check(r.has_next_vent and r.state == Resident.S.DORMANT, "abertura escolhida é sinalizada (pulsa/range) antes do aviso")
	r.queue_free()
	await _cleanup(a)

func _test_light_weakens() -> void:
	Engine.time_scale = 4.0
	var a := await _arena("c3_tunel", Vector2i(20, 6))
	var room: Room = a["room"]
	var p: Player = a["player"]
	InventoryManager.add_item("lanterna")
	GameManager.set_battery(100.0)
	GameManager.set_flashlight(true)
	p.facing = Vector2.RIGHT
	var r := _resident(a)
	r.position = p.position + Vector2(130, 0)
	r._enter(Resident.S.STALK)
	var reasons: Array[String] = []
	r.state_changed.connect(func(_n: String) -> void: reasons.append(r.retreat_reason))
	var g := 0
	while r.state == Resident.S.STALK and g < 100:
		p.facing = Vector2.RIGHT
		await get_tree().create_timer(0.25).timeout
		g += 1
	t.check(r.state != Resident.S.STALK and r.retreat_reason == "luz", "luz sustentada enfraquece o Morador e o faz recuar (%s)" % r.retreat_reason)
	t.check(r.retreats == 1, "conta como fuga")
	GameManager.set_flashlight(false)
	InventoryManager.reset()
	r.queue_free()
	await _cleanup(a)
	Engine.time_scale = 1.0
