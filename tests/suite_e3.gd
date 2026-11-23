extends Node
## Etapa 3: estamina, ferimentos, kits médicos, armadilhas, golpes do Morador, persistência.
var t

func _arena(room_id: String, tile: Vector2i) -> Dictionary:
	GameManager.new_game()
	GameManager.test_mode = true
	return await TestHelpers.make_arena(self, room_id, tile)

func _cleanup(a: Dictionary) -> void:
	a["room"].queue_free()
	a["player"].queue_free()
	Input.action_release("move_right")
	Input.action_release("run")
	GameManager.chasers.clear()
	await get_tree().process_frame

func run() -> void:
	Engine.time_scale = 4.0
	await _test_stamina()
	await _test_wounds_and_kits()
	await _test_resident_hits()
	await _test_hazard_and_death()
	await _test_persistence()
	Engine.time_scale = 1.0
	_test_distribution()

func _test_stamina() -> void:
	var a := await _arena("c1_corredor", Vector2i(2, 8))
	var p: Player = a["player"]
	t.check(p.stamina == Player.STAMINA_MAX and not p.exhausted, "estamina começa cheia")
	Input.action_press("move_right")
	Input.action_press("run")
	await get_tree().create_timer(1.0).timeout
	t.check(p.running and p.stamina < 95.0, "correr consome estamina gradualmente (%.0f)" % p.stamina)
	var mid := p.stamina
	await get_tree().create_timer(0.5).timeout
	t.check(p.stamina < mid, "consumo contínuo")
	var guard := 0
	while not p.exhausted and guard < 20:
		await get_tree().create_timer(0.5).timeout
		p.position = a["room"].nav.center_of(Vector2i(2, 8))
		guard += 1
	t.check(p.exhausted and p.stamina == 0.0, "estamina acaba → exausto")
	await get_tree().create_timer(0.3).timeout
	t.check(not p.running and not p.can_run(), "exausto: corrida bloqueada mesmo segurando Shift")
	Input.action_release("run")
	Input.action_release("move_right")
	var s0 := p.stamina
	await get_tree().create_timer(1.5).timeout
	t.check(p.stamina > s0, "recupera ao descansar")
	guard = 0
	while p.exhausted and guard < 20:
		await get_tree().create_timer(0.5).timeout
		guard += 1
	t.check(not p.exhausted and p.stamina >= Player.EXHAUST_RECOVER, "volta a correr só após recuperar o mínimo")
	# recuperação mais lenta sob perigo
	p.stamina = 10.0
	p._regen_delay = 0.0
	await get_tree().create_timer(1.0).timeout
	var calm_gain := p.stamina - 10.0
	p.stamina = 10.0
	p._regen_delay = 0.0
	GameManager.set_chasing("teste", true)
	p._regen_delay = 0.0
	await get_tree().create_timer(1.0).timeout
	var chase_gain := p.stamina - 10.0
	GameManager.set_chasing("teste", false)
	t.check(chase_gain < calm_gain * 0.8, "recuperação mais lenta durante perigo (%.1f vs %.1f)" % [chase_gain, calm_gain])
	# sinais de fadiga
	p.stamina = 10.0
	p.exhausted = true
	var noise := [0.0]
	var cb := func(_p: Vector2, r: float, src: String) -> void:
		if src == "breath":
			noise[0] = r
	GameManager.noise_emitted.connect(cb)
	p._breath_t = 0.0
	await get_tree().create_timer(0.3).timeout
	GameManager.noise_emitted.disconnect(cb)
	t.check(noise[0] == 40.0, "respiração ofegante emite ruído baixo")
	await _cleanup(a)

func _test_wounds_and_kits() -> void:
	var a := await _arena("c1_corredor", Vector2i(2, 8))
	var p: Player = a["player"]
	t.check(p.wound == 0 and p.speed_mult() == 1.0 and p.can_run(), "saudável: sem penalidades")
	t.check(not p.hurt(1), "1º ferimento não é fatal")
	t.check(p.wound == 1 and p.can_run() and p.speed_mult() == 1.0, "leve: ainda corre, sem lentidão")
	p.hurt(1)
	t.check(p.wound == 2 and p.can_run() and p.speed_mult() < 1.0, "médio: movimentação prejudicada")
	p.hurt(1)
	t.check(p.wound == 3 and not p.can_run() and p.speed_mult() <= 0.8, "grave: sem corrida e mais lento — mas ainda anda")
	t.check(p.hurt(1), "golpe com ferimento grave é fatal")
	# kits: empilhamento e limite
	InventoryManager.reset()
	for i in 6:
		InventoryManager.add_item("kit_pequeno")
	t.check(InventoryManager.count("kit_pequeno") == InventoryManager.max_stack("kit_pequeno"), "kits respeitam o limite de pilha")
	InventoryManager.add_item("kit_grande")
	t.check(p.best_kit() == "kit_grande", "ferimento grave prefere o kit grande")
	var k0 := InventoryManager.count("kit_grande")
	t.check(p.start_heal("kit_grande") and p.heal_t > 0.0, "usar kit inicia tratamento com duração")
	var w0 := p.wound
	t.check(not p.start_heal("kit_pequeno"), "não usa dois kits ao mesmo tempo")
	await get_tree().create_timer(4.0).timeout
	t.check(p.wound == w0 - 2 and InventoryManager.count("kit_grande") == k0 - 1, "kit grande reduz 2 níveis e é consumido")
	t.check(p.start_heal("kit_pequeno"), "kit pequeno inicia")
	await get_tree().create_timer(2.5).timeout
	t.check(p.wound == 0, "kit pequeno trata o último ferimento")
	t.check(not p.start_heal("kit_pequeno"), "sem ferimento não gasta kit")
	InventoryManager.reset()
	t.check(not p.start_heal("kit_pequeno"), "sem kit não trata")
	# cura natural
	p.wound = 2
	p._wound_t = Player.NATURAL_HEAL_SECONDS - 0.1
	await get_tree().create_timer(0.5).timeout
	t.check(p.wound == 1, "ferimento melhora sozinho com o tempo (nunca bloqueia a progressão)")
	GameManager.set_chasing("x", true)
	p._wound_t = Player.NATURAL_HEAL_SECONDS - 0.1
	await get_tree().create_timer(0.5).timeout
	t.check(p.wound == 1, "não cura sozinho durante perseguição")
	GameManager.set_chasing("x", false)
	await _cleanup(a)

func _test_resident_hits() -> void:
	var a := await _arena("c3_tunel", Vector2i(22, 6))
	var room: Room = a["room"]
	var p: Player = a["player"]
	var r := Resident.new()
	room.y_layer.add_child(r)
	r.setup(room, p, {"zone": [10, 2, 22, 9], "vents": [[14, 3], [20, 9], [28, 4]]})
	r.position = p.position + Vector2(10, 0)
	r._enter(Resident.S.STALK)
	await get_tree().create_timer(0.6).timeout
	t.check(p.wound == 1, "golpe do Morador causa ferimento (não morte)")
	t.check(r.state == Resident.S.RETREAT or r.state == Resident.S.DORMANT or r.state == Resident.S.DIGGING, "Morador enfraquecido interrompe a perseguição e recua")
	var captured := [false]
	GameManager.player_captured.connect(func(_b: String) -> void: captured[0] = true)
	t.check(not captured[0], "primeiro golpe não captura")
	p.wound = 3
	r.position = p.position + Vector2(10, 0)
	r._hit_cd = 0.0
	r._enter(Resident.S.STALK)
	await get_tree().create_timer(0.6).timeout
	t.check(captured[0], "golpe com ferimento grave captura (morte)")
	r.queue_free()
	await _cleanup(a)

func _test_hazard_and_death() -> void:
	GameManager.new_game()
	GameManager.test_mode = true
	GameManager.current_room = "c2_alcapao"
	GameManager.chapter = 2
	GameManager.last_spawn = "entrada"
	var game: Game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	var trap := game.room.find_object("trap1")
	t.check(trap != null and trap.spec.has("hazard"), "armadilha existe e está sinalizada (objeto examinável)")
	game.player.position = trap.rect.get_center() + Vector2(0, 4)
	for i in 10:
		await get_tree().process_frame
	while game.runner.busy:
		await get_tree().process_frame
	t.check(game.player.wound == 1 and NarrativeManager.has_flag("sprung_" + trap.uid), "armadilha causa ferimento uma vez")
	game.player.position = trap.rect.get_center() + Vector2(0, 4)
	for i in 10:
		await get_tree().process_frame
	t.check(game.player.wound == 1, "armadilha já disparada não fere de novo")
	# morte cura ao menos parcialmente e restaura o fôlego
	game.player.wound = 3
	game.player.stamina = 5.0
	GameManager.capture("teste")
	for i in 8:
		await get_tree().process_frame
	while game.changing_room or game.runner.busy:
		await get_tree().process_frame
	t.check(game.player.wound <= 1 and game.player.stamina == Player.STAMINA_MAX, "após a morte: ferimento ≤ leve e estamina cheia")
	game.queue_free()
	await get_tree().process_frame

func _test_persistence() -> void:
	var a := await _arena("c1_corredor", Vector2i(2, 8))
	var p: Player = a["player"]
	p.stamina = 40.0
	p.wound = 2
	p._store()
	InventoryManager.add_item("kit_pequeno")
	InventoryManager.add_item("kit_pequeno")
	GameManager.current_room = "c1_corredor"
	t.check(SaveManager.save_to("slot3"), "salva com estamina/ferimento/kits")
	await _cleanup(a)
	GameManager.new_game()
	t.check(SaveManager.load_slot("slot3"), "carrega")
	t.check(float(GameManager.player_state.get("stamina", 0)) == 40.0 and int(GameManager.player_state.get("wound", 0)) == 2, "estamina e ferimento persistem no save")
	t.check(InventoryManager.count("kit_pequeno") == 2, "quantidade de kits persiste")
	var b := await TestHelpers.make_arena(self, "c1_corredor", Vector2i(2, 8))
	t.check(b["player"].wound == 2 and absf(b["player"].stamina - 40.0) < 2.0, "novo Player lê o estado salvo")
	await _cleanup(b)
	SaveManager.delete_slot("slot3")
	GameManager.new_game()

func _test_distribution() -> void:
	var per_chapter := {}
	var total_grande := 0
	for rid in NarrativeManager.rooms_db:
		var spec: Dictionary = NarrativeManager.rooms_db[rid]
		for o in spec.get("objects", []):
			for e in o.get("effects", []):
				if e is Dictionary and str(e.get("give", "")).begins_with("kit_"):
					var ch := int(spec["chapter"])
					per_chapter[ch] = int(per_chapter.get(ch, 0)) + (2 if e["give"] == "kit_grande" else 1)
					if e["give"] == "kit_grande":
						total_grande += 1
	t.check(int(per_chapter.get(1, 0)) == 0, "capítulo I (sem Morador) não precisa de kits")
	for ch in [2, 3, 4, 5]:
		t.check(int(per_chapter.get(ch, 0)) >= 3, "capítulo %d distribui kits suficientes (potência total %d)" % [ch, int(per_chapter.get(ch, 0))])
	t.check(total_grande >= 3, "há kits grandes para ferimentos graves")
