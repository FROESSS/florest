extends Node
## Ferramenta de desenvolvimento: gera capturas de tela das salas (requer renderizador, ex.: xvfb).
## Uso: godot --path . res://tools/ShotRunner.tscn -- --rooms=c1_quarto,c1_corredor --out=/tmp/shots

func _ready() -> void:
	var rooms := ["c1_quarto"]
	var out := "/tmp/shots"
	var flash := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rooms="):
			rooms = a.substr(8).split(",")
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--flash":
			flash = true
	DirAccess.make_dir_recursive_absolute(out)
	GameManager.test_mode = true
	for rid in rooms:
		GameManager.new_game()
		GameManager.test_mode = true
		InventoryManager.add_item("lanterna")
		NarrativeManager.set_flag("clara_follows", false)
		NarrativeManager.set_flag("intro_shown", true)
		NarrativeManager.set_flag("trg:c1_quarto:intro", true)
		GameManager.current_room = rid
		GameManager.last_spawn = NarrativeManager.rooms_db[rid]["spawns"].keys()[0]
		GameManager.chapter = int(NarrativeManager.rooms_db[rid]["chapter"])
		var game: Game = load("res://scenes/main/Game.tscn").instantiate()
		add_child(game)
		for i in 20:
			await get_tree().process_frame
		for e in game.room.enemies:
			e.enabled = false
		if flash:
			GameManager.set_flashlight(true)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, rid])
		print("shot ", rid, " ", img.get_size())
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
