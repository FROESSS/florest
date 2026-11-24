extends Node
## Capturas das telas de interface (desenvolvimento). Uso: godot --path . res://tools/UiShots.tscn

func snap(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ui/%s.png" % name)
	print("shot ", name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/ui")
	await AudioManager.warm_up()
	# menu
	var menu: Node = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await snap("menu")
	menu.queue_free()
	# jogo
	GameManager.new_game()
	InventoryManager.add_item("lanterna")
	InventoryManager.add_item("chave_servico")
	NarrativeManager.set_flag("intro_shown", true)
	NarrativeManager.set_flag("trg:c1_quarto:intro", true)
	NarrativeManager.add_document("carta_inauguracao")
	NarrativeManager.add_memory("ursinho")
	NarrativeManager.set_objective("Fugir pelo salão e sair pela porta de serviço.")
	var game: Game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().process_frame
	game.hud.show_hint("Dica de teste: esconda-se nos armários.", 30.0)
	game.hud.show_objective()
	game.hud.show_toast("Item coletado: Lanterna")
	game.hud.show_subtitle("[Cantiga distorcida]", 30.0)
	await snap("hud")
	game.dialogue.run(["Na última gaveta, enrolada num pano, há uma lanterna.", "Está pesada. Ainda funciona."], "")
	await get_tree().create_timer(1.5).timeout
	await snap("dialogue")
	game.dialogue._advance.emit()
	game.dialogue._advance.emit()
	game.dialogue.choose("Tomás pede de volta a caixa de música.", [{"text": "Entregar a caixa a Tomás.", "disabled": true}, {"text": "Ficar com a caixa por enquanto."}, {"text": "Ir embora."}])
	await snap("choice")
	game.dialogue._chosen.emit(1)
	await get_tree().process_frame
	game.puzzle.def = NarrativeManager.puzzles_db["p_caixa_musica"]
	game.puzzle._build(); game.puzzle.visible = true
	await snap("puzzle_code")
	game.puzzle.def = NarrativeManager.puzzles_db["p_prontuarios"]
	game.puzzle._build()
	await snap("puzzle_order")
	game.puzzle.def = NarrativeManager.puzzles_db["p_fusiveis"]
	game.puzzle._build()
	await snap("puzzle_toggles")
	game.puzzle.visible = false
	game.book.open_inventory()
	await snap("inventory")
	game.book.open_journal(0)
	await snap("journal")
	game.book.read_document("carta_inauguracao")
	await snap("document")
	game.book._close()
	game.memory.play_memory("foto")
	await get_tree().create_timer(2.0).timeout
	await snap("memory")
	game.memory._advance.emit()
	game.pause.open()
	await snap("pause")
	var cl := CanvasLayer.new()
	cl.layer = 80
	game.add_child(cl)
	game.memory.visible = false
	var su := SettingsUI.new()
	cl.add_child(su)
	await snap("settings")
	var cu := ControlsUI.new()
	cl.add_child(cu)
	await snap("controls")
	cu.begin_listen("run", 0)
	cu.on_key(KEY_Q)
	cu.begin_listen("flashlight", 0)
	cu.on_key(KEY_Q)
	await snap("controls_conflict")
	get_tree().quit()
