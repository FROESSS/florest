extends Node
## Salvamento: ida e volta, validação, backup, arquivo corrompido, versão futura, local no user://.
var t

func run() -> void:
	GameManager.new_game()
	GameManager.current_room = "c3_refeitorio"
	GameManager.chapter = 3
	GameManager.last_spawn = "oeste"
	GameManager.last_safe_pos = Vector2(100, 120)
	GameManager.battery = 42.5
	GameManager.play_time = 123.0
	GameManager.flashlight_on = true
	InventoryManager.add_item("lanterna")
	InventoryManager.add_item("chave_servico")
	NarrativeManager.set_flag("tissue_burned")
	NarrativeManager.add_counter("clara_trust", 2)
	NarrativeManager.add_memory("ursinho")
	NarrativeManager.add_document("diario_marta")
	NarrativeManager.set_objective("Teste")
	t.check(SaveManager.SAVE_DIR.begins_with("user://"), "saves ficam em user:// (não na pasta do jogo)")
	t.check(SaveManager.save_to("slot3"), "salva em slot3")
	var st := SaveManager.build_state()
	t.check(st["flashlight_on"] == false, "estado transitório (lanterna ligada) não é salvo")
	# muda tudo e recarrega
	GameManager.new_game()
	t.check(InventoryManager.items.is_empty() and not NarrativeManager.has_flag("tissue_burned"), "novo jogo zera o estado")
	t.check(SaveManager.load_slot("slot3"), "carrega slot3")
	t.check(GameManager.current_room == "c3_refeitorio" and GameManager.chapter == 3, "sala e capítulo restaurados")
	t.check(is_equal_approx(GameManager.battery, 42.5), "bateria restaurada")
	t.check(InventoryManager.has_item("lanterna") and InventoryManager.has_item("chave_servico"), "inventário restaurado")
	t.check(NarrativeManager.has_flag("tissue_burned") and NarrativeManager.counter("clara_trust") == 2, "flags e contadores restaurados (int, não float)")
	t.check(typeof(NarrativeManager.get_flag("clara_trust")) == TYPE_INT, "contador volta como inteiro")
	t.check(NarrativeManager.memories_found == ["ursinho"] and NarrativeManager.docs_found == ["diario_marta"], "memórias/documentos restaurados")
	t.check(NarrativeManager.objective == "Teste", "objetivo restaurado")
	t.check(GameManager.has_pending_pos and GameManager.pending_pos == Vector2(100, 120), "posição segura restaurada")
	# segundo save cria backup
	t.check(SaveManager.save_to("slot3"), "sobrescreve slot3")
	t.check(FileAccess.file_exists(SaveManager.path_for("slot3") + ".bak"), "backup criado antes de sobrescrever")
	# arquivo corrompido
	var f := FileAccess.open(SaveManager.path_for("slot2"), FileAccess.WRITE)
	f.store_string("{isto não é json")
	f.close()
	t.check(SaveManager.read_slot("slot2").is_empty(), "save corrompido é rejeitado")
	t.check(not SaveManager.load_slot("slot2"), "load de save corrompido falha sem alterar estado")
	# versão futura
	var future := SaveManager.build_state()
	future["version"] = 999
	var f2 := FileAccess.open(SaveManager.path_for("slot2"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(future))
	f2.close()
	t.check(SaveManager.read_slot("slot2").is_empty(), "save de versão futura é rejeitado")
	# sala inválida / bateria inválida
	var bad := SaveManager.build_state()
	bad["room"] = "sala_que_nao_existe"
	t.check(SaveManager.validate(bad) != "", "valida sala inexistente")
	bad = SaveManager.build_state()
	bad["battery"] = 500
	t.check(SaveManager.validate(bad) != "", "valida bateria fora do intervalo")
	bad = SaveManager.build_state()
	bad["inventory"] = "x"
	t.check(SaveManager.validate(bad) != "", "valida inventário inválido")
	# itens desconhecidos descartados
	var d := SaveManager.build_state()
	d["inventory"] = ["lanterna", "item_fantasma"]
	GameManager.new_game()
	SaveManager.apply_state(d)
	t.check(InventoryManager.items == ["lanterna"], "itens desconhecidos são descartados no load")
	# latest_slot / info
	t.check(SaveManager.latest_slot() != "", "latest_slot encontra o save mais recente")
	t.check(SaveManager.slot_info("slot3").exists, "slot_info")
	for s in SaveManager.SLOTS:
		SaveManager.delete_slot(s)
	t.check(not SaveManager.has_any(), "delete_slot remove saves")
	# configurações persistem
	SettingsManager.volume_music = 0.33
	SettingsManager.reduce_shake = true
	SettingsManager.save_settings()
	SettingsManager.volume_music = 0.8
	SettingsManager.reduce_shake = false
	SettingsManager.load_settings()
	t.check(is_equal_approx(SettingsManager.volume_music, 0.33) and SettingsManager.reduce_shake, "configurações persistem")
	SettingsManager.volume_music = 0.8
	SettingsManager.reduce_shake = false
	SettingsManager.save_settings()
	GameManager.new_game()
