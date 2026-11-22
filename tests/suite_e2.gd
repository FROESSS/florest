extends Node
## Etapa 2: estados de puzzle, releitura de documentos, morte/retorno seguro, save v2.
var t
var game: Game

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
	var g := 0
	while (game.runner.busy or game.changing_room) and g < 900:
		await get_tree().process_frame
		g += 1

func _use(id: String) -> void:
	var o := game.room.find_object(id)
	t.check(o != null, "objeto %s existe" % id)
	if o != null:
		await game.runner.interact(o)
		await _settle()

func _start(room_id: String) -> void:
	GameManager.new_game()
	GameManager.test_mode = true
	GameManager.test_puzzle_answers = {}
	GameManager.current_room = room_id
	GameManager.chapter = int(NarrativeManager.rooms_db[room_id]["chapter"])
	GameManager.last_spawn = NarrativeManager.rooms_db[room_id]["spawns"].keys()[0]
	NarrativeManager.set_flag("intro_shown", true)
	NarrativeManager.set_flag("trg:c1_quarto:intro", true)
	game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await _settle()
	for e in game.room.enemies:
		e.enabled = false

func _end() -> void:
	game.queue_free()
	await get_tree().process_frame

func run() -> void:
	await _test_puzzle_states()
	await _test_documents()
	await _test_death_and_recovery()
	await _test_save_v2()
	_test_recovery_all_rooms()

func _test_puzzle_states() -> void:
	await _start("c1_dormitorio")
	InventoryManager.add_item("lanterna")
	t.check(NarrativeManager.puzzle_state("p_caixa_musica") == "not_started", "puzzle começa 'não iniciado'")
	GameManager.test_puzzle_answers["p_caixa_musica"] = false   # jogador cancela/erra
	await _use("caixa")
	t.check(NarrativeManager.puzzle_state("p_caixa_musica") == "in_progress", "cancelar deixa 'em andamento'")
	t.check(not NarrativeManager.has_flag("done_c1_dormitorio:caixa"), "cancelar NÃO marca o objeto como concluído")
	await _use("caixa")
	await _use("caixa")
	t.check(NarrativeManager.puzzle_state("p_caixa_musica") != "solved" and NarrativeManager.puzzle_attempts.get("p_caixa_musica", 0) == 3, "pode tentar quantas vezes quiser (3 tentativas)")
	# sair da sala e voltar não bloqueia
	await game.load_room("c1_corredor", "porta_dorm")
	await game.load_room("c1_dormitorio", "porta")
	await _settle()
	for e in game.room.enemies:
		e.enabled = false
	GameManager.test_puzzle_answers["p_caixa_musica"] = true
	await _use("caixa")
	t.check(NarrativeManager.puzzle_state("p_caixa_musica") == "solved" and InventoryManager.has_item("chave_secretaria"), "depois de sair e voltar, resolve normalmente")
	await _use("caixa")
	t.check(InventoryManager.items.count("chave_secretaria") == 1, "reinteragir não duplica a recompensa")
	# bloqueado temporariamente
	NarrativeManager.set_puzzle_state("p_terminal", "blocked")
	t.check(NarrativeManager.puzzle_state("p_terminal") == "blocked", "estado 'bloqueado' existe")
	NarrativeManager.set_puzzle_state("p_caixa_musica", "in_progress")
	t.check(NarrativeManager.puzzle_state("p_caixa_musica") == "solved", "resolvido nunca regride")
	await _end()
	# todos os puzzles obrigatórios: cancelar nunca tranca (varre os objetos com puzzle)
	for rid in NarrativeManager.rooms_db:
		for o in NarrativeManager.rooms_db[rid].get("objects", []):
			if JSON.stringify(o.get("effects", [])).contains("\"puzzle\""):
				var once_explicit: bool = o.get("once", false)
				t.check(not once_explicit, "%s/%s: objeto de puzzle não é 'once'" % [rid, o["id"]])

func _test_documents() -> void:
	await _start("c1_secretaria")
	var before := GameManager.docs_opened
	for i in 3:
		await _use("arquivo")
	t.check(GameManager.docs_opened - before == 3, "documento pode ser aberto 3 vezes seguidas")
	t.check(NarrativeManager.docs_found.count("carta_inauguracao") == 1, "documento registrado uma única vez")
	var b2 := GameManager.docs_opened
	await _use("foto")
	await _use("foto")
	t.check(GameManager.docs_opened - b2 >= 2, "objeto inspecionável pode ser inspecionado de novo")
	t.check(InventoryManager.items.count("foto_antiga") == 1, "inspecionar de novo não duplica o item")
	await _end()
	await _start("c4_arquivos")
	NarrativeManager.set_flag("x")
	await _use("arq3")
	await _use("arq3")
	t.check(NarrativeManager.flags.has("choice_registro_elias") and NarrativeManager.docs_found.has("registro_elias"), "registro L-12: escolha feita uma vez")
	t.check(GameManager.docs_opened >= 2, "registro L-12 relido sem repetir a escolha")
	await _end()

func _test_death_and_recovery() -> void:
	await _start("c1_corredor")
	InventoryManager.add_item("lanterna")
	InventoryManager.add_item("chave_secretaria")
	NarrativeManager.add_document("carta_inauguracao")
	NarrativeManager.set_puzzle_state("p_caixa_musica", "solved")
	NarrativeManager.set_flag("c1_alarm")
	game.player.position = game.room.nav.center_of(Vector2i(24, 5))
	var deaths := GameManager.deaths
	GameManager.capture("caretaker")
	for i in 6:
		await get_tree().process_frame
	await _settle()
	t.check(game.room != null and game.player != null and not game.player.captured, "jogador renasce ativo após a captura")
	t.check(InventoryManager.has_item("lanterna") and InventoryManager.has_item("chave_secretaria"), "morte preserva itens")
	t.check(NarrativeManager.docs_found.has("carta_inauguracao") and NarrativeManager.puzzle_state("p_caixa_musica") == "solved" and NarrativeManager.has_flag("c1_alarm"), "morte preserva documentos, puzzles e flags")
	t.check(GameManager.deaths == deaths + 1, "contador de mortes")
	var danger := Recovery.danger_points(game.room)
	var pos := game.player.position
	t.check(game.room.nav.is_free_point(pos), "renasce em tile livre (não preso)")
	var md := INF
	for d in danger:
		md = minf(md, pos.distance_to(d))
	t.check(md >= Recovery.MIN_SAFE_DIST, "renasce a ≥150 px dos inimigos (%.0f px)" % md)
	await _end()
	# salão: ponto de recuperação definido
	await _start("c1_saguao")
	NarrativeManager.set_flag("c1_alarm")
	game.player.position = game.room.nav.center_of(Vector2i(5, 16))
	GameManager.capture("caretaker")
	for i in 6:
		await get_tree().process_frame
	await _settle()
	var d2 := Vector2(2 * 16 + 8, 17 * 16 + 8)
	t.check(game.player.position.distance_to(d2) >= Recovery.MIN_SAFE_DIST and game.room.nav.is_free_point(game.player.position), "salão: retorno longe da Cuidadora")
	await _end()

func _test_save_v2() -> void:
	GameManager.new_game()
	NarrativeManager.set_puzzle_state("p_terminal", "in_progress")
	NarrativeManager.set_puzzle_state("p_cofre", "solved")
	NarrativeManager.add_attempt("p_terminal")
	GameManager.current_room = "c4_arquivos"
	GameManager.chapter = 4
	GameManager.world_state = {"holes": {"c3_tunel": [{"tile": [5, 5]}]}}
	GameManager.player_state = {"stamina": 55.0}
	t.check(SaveManager.save_to("slot1"), "salva v2")
	var raw := SaveManager.read_slot("slot1")
	t.check(int(raw["version"]) == 2 and raw.has("world") and raw.has("player"), "formato v2 com mundo e jogador")
	GameManager.new_game()
	t.check(SaveManager.load_slot("slot1"), "carrega v2")
	t.check(NarrativeManager.puzzle_state("p_terminal") == "in_progress" and NarrativeManager.puzzle_state("p_cofre") == "solved", "estados de puzzle persistem")
	t.check(int(NarrativeManager.puzzle_attempts.get("p_terminal", 0)) == 1, "tentativas persistem")
	t.check(GameManager.world_state.has("holes") and GameManager.player_state.get("stamina", 0) == 55.0, "estado de mundo/jogador persiste")
	# migração v1 → v2
	var v1 := SaveManager.build_state()
	v1["version"] = 1
	v1.erase("world")
	v1.erase("player")
	(v1["narrative"] as Dictionary).erase("puzzles")
	(v1["narrative"]["flags"] as Dictionary)["solved_p_cofre"] = true
	var f := FileAccess.open(SaveManager.path_for("slot2"), FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var mig := SaveManager.read_slot("slot2")
	t.check(not mig.is_empty() and int(mig["version"]) == 2, "save v1 é migrado para v2")
	t.check(FileAccess.file_exists(SaveManager.path_for("slot2") + ".premigration"), "backup .premigration criado")
	GameManager.new_game()
	t.check(SaveManager.load_slot("slot2") and NarrativeManager.puzzle_state("p_cofre") == "solved", "estado de puzzle derivado das flags da v1")
	for s in SaveManager.SLOTS:
		SaveManager.delete_slot(s)
	GameManager.new_game()

func _test_recovery_all_rooms() -> void:
	for rid in NarrativeManager.rooms_db:
		var room := Room.new()
		add_child(room)
		room.build(rid)
		var cands := Recovery.candidates(room)
		var has_danger := not Recovery.danger_points(room).is_empty()
		var first: Vector2 = room.spawn_position(room.spec["spawns"].keys()[0])
		for c in cands:
			t.check(room.nav.is_free_point(c), "%s: ponto de retorno em tile livre" % rid)
		var tests: Array[Vector2] = [first]
		for e in room.spec.get("enemies", []):
			if e.has("tile"):
				tests.append(room.nav.center_of(Vector2i(e["tile"][0], e["tile"][1])))
		for dp in tests:
			var r := Recovery.choose(room, dp)
			t.check(room.nav.is_free_point(r["pos"]) and room.nav.reachable(first, r["pos"]), "%s: retorno livre e alcançável" % rid)
			if has_danger:
				t.check(r["safe"], "%s: existe retorno seguro (≥150 px de inimigos)" % rid)
		room.queue_free()
