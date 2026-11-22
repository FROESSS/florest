extends Node
## Sistemas: inventário, flags, condições, puzzles (UI real), jogador (movimento/colisão/lanterna/esconderijo), interação.
var t

func run() -> void:
	_test_inventory_flags()
	_test_puzzle_definitions()
	await _test_puzzle_ui()
	await _test_player_and_interaction()

func _test_inventory_flags() -> void:
	InventoryManager.reset()
	NarrativeManager.reset()
	t.check(InventoryManager.add_item("lanterna"), "adiciona item")
	t.check(not InventoryManager.add_item("lanterna"), "item não duplica")
	t.check(InventoryManager.has_item("lanterna"), "has_item")
	t.check(InventoryManager.remove_item("lanterna") and not InventoryManager.has_item("lanterna"), "remove item")
	NarrativeManager.set_flag("a")
	NarrativeManager.add_counter("c", 2)
	t.check(NarrativeManager.check({"flags": ["a"]}), "cond flags")
	t.check(not NarrativeManager.check({"flags": ["a", "b"]}), "cond flags faltando")
	t.check(NarrativeManager.check({"not_flags": ["b"]}), "cond not_flags")
	t.check(NarrativeManager.check({"any_flags": ["b", "a"]}), "cond any_flags")
	t.check(NarrativeManager.check({"counter": {"c": 2}}), "cond counter")
	t.check(not NarrativeManager.check({"counter": {"c": 3}}), "cond counter insuficiente")
	t.check(NarrativeManager.add_memory("ursinho") and not NarrativeManager.add_memory("ursinho"), "memória registrada uma vez")
	t.check(NarrativeManager.has_flag("mem_ursinho"), "flag da memória")
	t.check(NarrativeManager.add_document("carta_inauguracao") and not NarrativeManager.add_document("carta_inauguracao"), "documento registrado uma vez")
	InventoryManager.reset()
	NarrativeManager.reset()

func _test_puzzle_definitions() -> void:
	for pid in NarrativeManager.puzzles_db:
		var d: Dictionary = NarrativeManager.puzzles_db[pid]
		match str(d["type"]):
			"code":
				t.check(str(d["solution"]).length() == int(d["digits"]) and str(d["solution"]).is_valid_int(), "%s: solução numérica coerente" % pid)
			"order":
				var ids := (d["items"] as Array).map(func(i): return str(i["id"]))
				var sol := (d["solution"] as Array).map(func(i): return str(i))
				var a := ids.duplicate(); a.sort()
				var b := sol.duplicate(); b.sort()
				t.check(a == b, "%s: solução é permutação dos itens" % pid)
				t.check(ids != sol, "%s: ordem exibida não é a solução (sem solução trivial)" % pid)
			"toggles":
				t.check((d["solution"] as Array).size() == (d["labels"] as Array).size(), "%s: solução do mesmo tamanho dos interruptores" % pid)
		t.check(str(d.get("prompt", "")) != "", "%s: tem pista/enunciado" % pid)

func _test_puzzle_ui() -> void:
	GameManager.test_mode = false
	for pid in NarrativeManager.puzzles_db:
		var ui := PuzzleUI.new()
		add_child(ui)
		var res := [null]
		ui._closed.connect(func(ok: bool) -> void: res[0] = ok)
		ui.open(pid)
		await get_tree().process_frame
		var d: Dictionary = NarrativeManager.puzzles_db[pid]
		match str(d["type"]):
			"code":
				# tentativa errada
				ui.values[0] = (ui.values[0] + 1) % 10
				ui._check_code()
				await get_tree().create_timer(0.2).timeout
				t.check(res[0] == null, "%s: código errado não resolve" % pid)
				var sol := str(d["solution"])
				for i in sol.length():
					ui.values[i] = int(sol[i])
				ui._check_code()
			"order":
				var wrong := (d["solution"] as Array).duplicate()
				wrong.reverse()
				for id in wrong:
					ui._pick(str(id))
				await get_tree().create_timer(0.2).timeout
				t.check(res[0] == null, "%s: ordem errada não resolve" % pid)
				for id in d["solution"]:
					ui._pick(str(id))
			"toggles":
				ui._check_toggles()
				await get_tree().create_timer(0.2).timeout
				t.check(res[0] == null, "%s: combinação errada não resolve" % pid)
				var s: Array = d["solution"]
				for i in s.size():
					ui.toggles[i].button_pressed = int(s[i]) == 1
				ui._check_toggles()
		await get_tree().create_timer(0.9).timeout
		t.check(res[0] == true, "%s: solução correta resolve" % pid)
		ui.queue_free()
	GameManager.test_mode = true

func _test_player_and_interaction() -> void:
	GameManager.new_game()
	GameManager.test_mode = true
	var arena := await TestHelpers.make_arena(self, "c1_quarto", Vector2i(5, 5))
	var room: Room = arena["room"]
	var player: Player = arena["player"]
	# movimento e normalização diagonal
	Input.action_press("move_right")
	Input.action_press("move_down")
	var start := player.position
	await get_tree().create_timer(0.3).timeout
	Input.action_release("move_right")
	Input.action_release("move_down")
	var delta := player.position - start
	t.check(delta.x > 5.0 and delta.y > 5.0, "jogador se move na diagonal")
	t.check(absf(delta.x - delta.y) < delta.length() * 0.15, "diagonal normalizada (dx≈dy)")
	# corrida mais rápida que caminhada
	player.position = room.nav.center_of(Vector2i(4, 10))
	await get_tree().physics_frame
	Input.action_press("move_right")
	var p0 := player.position
	await get_tree().create_timer(0.25).timeout
	var walk := player.position.x - p0.x
	Input.action_release("move_right")
	player.position = room.nav.center_of(Vector2i(4, 10))
	await get_tree().physics_frame
	Input.action_press("move_right")
	Input.action_press("run")
	p0 = player.position
	await get_tree().create_timer(0.25).timeout
	var run_d := player.position.x - p0.x
	Input.action_release("move_right")
	Input.action_release("run")
	t.check(run_d > walk * 1.3, "correr é mais rápido que andar (%.1f vs %.1f)" % [run_d, walk])
	# colisão com paredes: empurrar para a esquerda por 3s não atravessa
	player.position = room.nav.center_of(Vector2i(5, 8))
	await get_tree().physics_frame
	Input.action_press("move_left")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("move_left")
	t.check(player.position.x >= 16.0, "colisão com parede oeste (x=%.1f)" % player.position.x)
	Input.action_press("move_up")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("move_up")
	t.check(player.position.y >= 32.0, "colisão com parede norte (y=%.1f)" % player.position.y)
	# ruído de passos
	var noise := [0.0]
	var cb := func(_p: Vector2, r: float, _s: String) -> void: noise[0] = maxf(noise[0], r)
	GameManager.noise_emitted.connect(cb)
	player.running = false
	player._do_step()
	t.check(noise[0] == Player.NOISE_WALK, "andar emite ruído baixo")
	player.running = true
	player._do_step()
	t.check(noise[0] == Player.NOISE_RUN and Player.NOISE_RUN > Player.NOISE_WALK, "correr emite ruído alto")
	GameManager.noise_emitted.disconnect(cb)
	# lanterna
	t.check(not GameManager.has_flashlight(), "sem lanterna no início")
	GameManager.set_flashlight(true)
	t.check(not GameManager.flashlight_on, "não liga sem item")
	InventoryManager.add_item("lanterna")
	GameManager.set_flashlight(true)
	t.check(GameManager.flashlight_on and player.flash.enabled, "lanterna liga com item")
	var b0 := GameManager.battery
	GameManager.battery = 50.0
	GameManager.set_flashlight(false)
	t.check(not player.flash.enabled, "lanterna desliga")
	GameManager.set_battery(0.0)
	GameManager.set_flashlight(true)
	t.check(not GameManager.flashlight_on, "sem bateria não liga")
	GameManager.set_battery(b0)
	# esconderijo
	var wardrobe := room.find_object("armario")
	player.enter_hide(wardrobe)
	t.check(player.hiding and not player.sprite.visible, "entra no esconderijo (invisível)")
	player.exit_hide()
	t.check(not player.hiding and player.sprite.visible and room.nav.is_free_point(player.position), "sai do esconderijo em posição livre")
	# interações com dados reais via Game
	room.queue_free()
	player.queue_free()
	await get_tree().process_frame

	var game: Game = load("res://scenes/main/Game.tscn").instantiate()
	GameManager.new_game()
	add_child(game)
	await TestHelpers.sim(get_tree(), 0.3)
	t.check(game.room != null and game.room.id == "c1_quarto" and game.player != null, "Game inicia no quarto de Elias")
	var o := game.room.find_object("gaveta")
	await game.runner.interact(o)
	t.check(InventoryManager.has_item("lanterna"), "interação: gaveta entrega lanterna")
	await game.runner.interact(o)
	t.check(InventoryManager.items.count("lanterna") == 1, "item não duplica ao interagir de novo")
	var door := game.room.find_object("porta")
	NarrativeManager.set_flag("x")
	InventoryManager.remove_item("lanterna")
	await game.runner.interact(door)
	t.check(game.room.id == "c1_quarto", "porta trancada sem lanterna")
	InventoryManager.add_item("lanterna")
	await game.runner.interact(door)
	t.check(game.room.id == "c1_corredor", "porta abre com lanterna e muda de sala")
	game.queue_free()
	await get_tree().process_frame
